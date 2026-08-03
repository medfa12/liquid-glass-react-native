// GlassEffectContainer, glassEffectUnion and GlassEffectTransition, ported.
//
// The semantics here are Apple's, from "Applying Liquid Glass to custom views":
//
//   * "The larger the spacing value on the container, the sooner the Liquid
//     Glass effects behind views blend together and merge the shapes during a
//     transition."  -> spacing IS the smooth-union k. It is not a layout gap.
//   * Shapes merge "when the nearest edge is less than or equal to the
//     container's spacing".  -> the test is edge distance, not centre distance.
//   * glassEffectUnion(id:namespace:) merges shapes with the same id "even when
//     your content is at rest", independent of distance.
//   * matchedGeometry is the default for effects "positioned within the
//     container's assigned spacing"; materialize is for effects "farther from
//     each other than the container's assigned spacing".
//
// One draw per group, so a merged group is shaded ONCE — which is the whole
// reason a merge looks like one body of glass instead of two overlapping ones.

export const GlassEffectTransition = {
  matchedGeometry: 'matchedGeometry',
  materialize: 'materialize',
};

/** Edge-to-edge distance between two rects; 0 when they touch or overlap. */
export interface Rect { x: number; y: number; w: number; h: number; }

export function edgeGap(a: Rect, b: Rect): number {
  const dx = Math.max(0, Math.max(a.x - (b.x + b.w), b.x - (a.x + a.w)));
  const dy = Math.max(0, Math.max(a.y - (b.y + b.h), b.y - (a.y + a.h)));
  return Math.hypot(dx, dy);
}

// The shader carries a primary shape plus uShape2..4.
const MAX_PER_DRAW = 4;

export class GlassEffectContainer {
  /**
   * @param renderer  something with .render(params, backdropRect)
   * @param spacing   merge distance in CSS px
   */
  [k: string]: any;
  constructor(renderer: any, { spacing = 0, onOverflow = null }: { spacing?: number; onOverflow?: ((n: number, max: number) => void) | null } = {}) {
    this.renderer = renderer;
    this.spacing = spacing;
    this.onOverflow = onOverflow;
    this.effects = new Map();
  }

  /**
   * @param id  the glassEffectID
   * @param e   {rect:{x,y,w,h}, glass, unionId?, diffusion?, exponent?, press?}
   *            rect is in container-canvas CSS px, origin top-left.
   */
  set(id: string, e: Record<string, any>) { this.effects.set(id, { diffusion: 1, unionId: null, ...e }); return this; }
  delete(id: string) { this.effects.delete(id); }
  get(id: string) { return this.effects.get(id); }

  /**
   * Explicit unions first, then transitive proximity merging. Apple's rule is
   * pairwise, so A-B and B-C merging implies A-B-C; union-find gets that right
   * where a single pass would not.
   */
  groups() {
    const items = [...this.effects.entries()]
      .filter(([, e]) => e.diffusion > 0.001);
    const parent: number[] = items.map((_, i) => i);
    const find = (i: number): number => (parent[i] === i ? i : (parent[i] = find(parent[i])));
    const join = (i: number, j: number) => { const a = find(i), b = find(j); if (a !== b) parent[a] = b; };

    for (let i = 0; i < items.length; i++) {
      for (let j = i + 1; j < items.length; j++) {
        const [, A] = items[i], [, B] = items[j];
        const sameUnion = A.unionId != null && A.unionId === B.unionId;
        if (sameUnion || edgeGap(A.rect, B.rect) <= this.spacing) join(i, j);
      }
    }
    const byRoot = new Map<number, any[]>();
    items.forEach((it, i) => {
      const r = find(i);
      if (!byRoot.has(r)) byRoot.set(r, []);
      byRoot.get(r)!.push(it);
    });
    return [...byRoot.values()];
  }

  /**
   * The transition Apple would pick for an effect: matchedGeometry if it has a
   * neighbour within spacing (so there is a shape to flow into), otherwise
   * materialize.
   */
  transitionFor(id: string): string {
    const e = this.effects.get(id);
    if (!e) return GlassEffectTransition.materialize;
    for (const [oid, o] of this.effects) {
      if (oid === id) continue;
      if (edgeGap(e.rect, o.rect) <= this.spacing) return GlassEffectTransition.matchedGeometry;
    }
    return GlassEffectTransition.materialize;
  }

  /**
   * @param canvas  {w,h} of the container canvas in CSS px
   * @param base    baseParams() for this frame
   * @param toBackdropRect  (paddedRectInCanvasSpace) -> normalized backdrop rect
   */
  render(canvas: { w: number; h: number }, base: Record<string, any>, toBackdropRect: (r: Rect) => number[]) {
    let drawn = 0;
    for (const group of this.groups()) {
      for (let i = 0; i < group.length; i += MAX_PER_DRAW) {
        const chunk = group.slice(i, i + MAX_PER_DRAW);
        if (group.length > MAX_PER_DRAW && i === 0 && this.onOverflow) {
          // Never truncate silently: a dropped shape looks like a layout bug.
          this.onOverflow(group.length, MAX_PER_DRAW);
        }
        // Only the first draw clears; the rest accumulate into the same canvas.
        this.#draw(chunk, canvas, base, toBackdropRect, drawn++ > 0);
      }
    }
    if (drawn === 0) this.renderer.clear?.();
  }

  #draw(chunk: any[], canvas: { w: number; h: number }, base: Record<string, any>, toBackdropRect: (r: Rect) => number[], keep: boolean) {
    const [, primary] = chunk[0];
    const p = Object.assign({}, base, primary.glass.uniforms());

    // The primary defines the draw's own geometry; the shader centres it, so
    // extras are expressed as offsets from the CANVAS centre.
    p.halfSize = [primary.rect.w / 2, primary.rect.h / 2];
    p.exponent = primary.exponent ?? 2.0;
    p.diffusion = primary.diffusion;
    // Apple's rule is that shapes merge when their nearest edges are within
    // `spacing`. The polynomial smin only produces material between two
    // surfaces once d = g/2 - k/4 <= 0, i.e. gap <= k/2 -- so passing spacing
    // straight through as k puts the visible meniscus at half the documented
    // distance. k = 2*spacing makes the bridge appear exactly at the stated
    // threshold. Verified: at spacing 40 the bridge now forms at a 40px gap.
    p.mergeK = this.spacing * 2;

    // vUV is pixel space with Y UP; rects are Y DOWN. Flipping the sign here is
    // the difference between a shape merging upward and merging into the wrong
    // side of the bar.
    const cx = (r: Rect) => (r.x + r.w / 2) - canvas.w / 2;
    const cy = (r: Rect) => -((r.y + r.h / 2) - canvas.h / 2);

    const px = cx(primary.rect), py = cy(primary.rect);
    p.extraCount = chunk.length - 1;
    for (let k = 1; k < MAX_PER_DRAW; k++) {
      const slot = ['shape2', 'shape3', 'shape4'][k - 1];
      const ent = chunk[k];
      p[slot] = ent
        ? [cx(ent[1].rect) - px, cy(ent[1].rect) - py, ent[1].rect.w / 2, ent[1].rect.h / 2]
        : [0, 0, 0, 0];
    }

    // The draw covers the whole canvas; the shader discards outside coverage.
    this.renderer.render(p, toBackdropRect({ x: 0, y: 0, w: canvas.w, h: canvas.h }), {
      centerOffset: [px, py], keep,
    });
  }
}
