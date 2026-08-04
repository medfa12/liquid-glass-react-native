// Apple's `Glass` value type, ported.
//
//   SwiftUI            Glass.regular / .clear / .identity, .tint(_:), .interactive(_:)
//   AppKit             NSGlassEffectView.style / .tintColor / .effectIsInteractive
//
// Everything here that came out of a shipped .materialrecipe is marked DECODED.
// Everything fitted by eye is marked FITTED, because the two are not the same
// kind of claim and the difference matters if someone tries to verify this.

// DECODED — platformContentGlass.materialrecipe, byte-identical on macOS 26 and
// 27, and identical across the Lighter/Darker/UltraDarker names (same md5).
// The recipe is only this: a blur radius and one colour matrix.
export const GLASS_RECIPE = {
  blurRadius: 45,
  faceCM: [[0.921, -0.265, -0.027, 0.235],
           [-0.079, 0.735, -0.027, 0.235],
           [-0.079, -0.265, 0.973, 0.235]],
};

// DECODED — luminanceColorMap.png as a closed form. Drives CONTENT colour, not
// the panel: this is the curve that decides whether symbols go light or dark.
const LUM_LO = 0.3490, LUM_HI = 0.8000, LUM_K = 10.25, LUM_MID = 0.5;
export const LUMA709 = [0.212646, 0.715332, 0.072205];

export function adaptiveLumaCurve(L: number): number {
  const t = 1 / (1 + Math.exp(-LUM_K * (L - LUM_MID)));
  const t0 = 1 / (1 + Math.exp(LUM_K * LUM_MID));
  const t1 = 1 / (1 + Math.exp(-LUM_K * (1 - LUM_MID)));
  return LUM_LO + (LUM_HI - LUM_LO) * Math.min(Math.max((t - t0) / (t1 - t0), 0), 1);
}

/** The luma a symbol should be drawn at, given the mean luma behind it. */
export function adaptiveContentLuma(avgLuma: number, dark = 0.12, light = 0.95): number {
  const c = adaptiveLumaCurve(avgLuma);
  const s = Math.min(Math.max((c - 0.35) / 0.30, 0), 1);
  return light + (dark - light) * (s * s * (3 - 2 * s));
}

// FITTED — no `clear` recipe ships on disk, so this is built from the HIG's
// description: "highly translucent ... allows color to pass through from
// background to foreground". Less bias so the backdrop is not lifted, RGB left
// near identity so hue passes, and a shorter blur so detail survives.
// DECODED — least-squares solve of a real NSGlassEffectView style=.clear on
// macOS 27.0 (26A5388g) over a known test pattern; max residual 0.0016 (~0.4/255).
// Dark and light appearance differ materially (mainly bias + luma weights).
const CLEAR_CM_DARK  = [[0.8297, -0.0967, -0.0183, 0.0967],
                        [-0.0493, 0.7821, -0.0179, 0.0965],
                        [-0.0496, -0.0967, 0.8611, 0.0967]];
const CLEAR_CM_LIGHT = [[0.8557, -0.1618, -0.0167, 0.2795],
                        [-0.0481, 0.7419, -0.0167, 0.2795],
                        [-0.0481, -0.1618, 0.8870, 0.2795]];

const BASE = {
  adaptiveAmount: 0,          // DECODED: the glass recipe ships no luminanceAmount
  adaptiveTintDark: 0.12,
  adaptiveTintLight: 0.95,
  luminanceValues: [0, 0, 0, 0],
  saturation: 0,              // 0 = unset; the glass recipe ships no saturation
  tintAmount: 0,
  tintColor: [1, 1, 1],
  reduceTransparency: 0,
  // macOS 27 edge contour. Measured: interior luma 57 -> boundary luma 15, a
  // factor of 0.26, so the darkening is 1 - 0.26 = 0.74 over roughly one pixel.
  edgeLineOpacity: 0.74,
  edgeLineWidth: 1.0,
};

/**
 * Immutable, like Apple's. Every configurator returns a copy, so
 * `Glass.regular.tint([1,.6,.2]).interactive()` reads the same as the Swift.
 */
export class Glass {
  static regular: Glass;
  static clear: Glass;
  static identity: Glass;
  [k: string]: any;
  constructor(p: Record<string, any>) { Object.assign(this, p); Object.freeze(this); }
  #with(d: Record<string, any>) { return new Glass({ ...this, ...d }); }

  /** Glass.tint(_:) — rgb in 0..1. null clears it. */
  tint(rgb: [number, number, number] | null, amount = 0.5): Glass {
    return rgb ? this.#with({ tintColor: rgb, tintAmount: amount })
               : this.#with({ tintAmount: 0 });
  }

  /** Glass.interactive(_:) — enables the press/hover response. */
  interactive(on = true): Glass { return this.#with({ isInteractive: !!on }); }

  /**
   * Not an Apple API: the accessibility state Apple reads for you. Named to
   * avoid shadowing the `reduceTransparency` uniform this object also carries.
   * Mirrors the
   * platformChrome*ReduceTransparency recipes, which drop blurRadius entirely,
   * set averageColorEnabled, and pull saturation 1.1 -> 0.8 (DECODED).
   */
  withReducedTransparency(on = true): Glass {
    return on ? this.#with({ reduceTransparency: 1, saturation: 0.8 })
              : this.#with({ reduceTransparency: 0, saturation: this.saturation });
  }

  /**
   * Increase Contrast. Unlike Reduce Transparency there is no *IncreaseContrast
   * recipe on disk, so this is FITTED, not decoded: the material goes more
   * opaque and the rim glint is pushed up so the edge of the panel is
   * unambiguous against whatever is behind it.
   */
  withIncreasedContrast(on = true): Glass {
    return on ? this.#with({ faceOpacity: 1.0, rimGlintGain: 0.22, saturation: 0.9 })
              : this;
  }

  /**
   * Press/hover response. Apple scales the shape slightly and lifts the rim;
   * both ramp on the same curve so the glass reads as compressing, not fading.
   * FITTED.
   */
  pressed(t = 0): Glass {
    if (!this.isInteractive || t <= 0) return this;
    const k = Math.min(Math.max(t, 0), 1);
    return this.#with({ pressScale: 1 - 0.035 * k, pressGlint: 1 + 0.55 * k });
  }

  /** Uniform overrides to merge into the per-frame parameter object. */
  uniforms(): Record<string, any> {
    const u: Record<string, any> = {
      adaptiveAmount: this.adaptiveAmount,
      adaptiveTintDark: this.adaptiveTintDark,
      adaptiveTintLight: this.adaptiveTintLight,
      luminanceValues: this.luminanceValues,
      saturation: this.saturation,
      tintAmount: this.tintAmount,
      tintColor: this.tintColor,
      reduceTransparency: this.reduceTransparency,
      edgeLineOpacity: this.edgeLineOpacity ?? 0,
      edgeLineWidth: this.edgeLineWidth ?? 1,
      // 0 is "unset" for the scale; the shader reads that as 1.0.
      pressScale: this.pressScale ?? 0,
      pressGlint: this.pressGlint ?? 0,
    };
    if (this.faceCM) {
      u.faceCM0 = this.faceCM[0]; u.faceCM1 = this.faceCM[1]; u.faceCM2 = this.faceCM[2];
    }
    if (this.blurRadius != null) u.blurRadius = this.blurRadius;
    if (this.faceOpacity != null) u.faceOpacity = this.faceOpacity;
    if (this.rimGlintGain != null) u.rimGlintGain = this.rimGlintGain;
    return u;
  }
}

Glass.regular = new Glass({
  ...BASE, ...GLASS_RECIPE, variant: 'regular', isInteractive: false,
});

// DECODED: clear blurs MORE than regular, not less — measured edge-transition
// sigma 19.6px vs regular's 13.9px, a 1.41x ratio -> 45 * 1.41 ~= 63.
Glass.clear = new Glass({
  ...BASE, variant: 'clear', isInteractive: false,
  blurRadius: 63, faceCM: CLEAR_CM_DARK, faceCMLight: CLEAR_CM_LIGHT,
});

// Glass.identity — "your content remains unaffected as if no glass effect was
// applied". Callers should skip the draw entirely rather than render this.
Glass.identity = new Glass({ ...BASE, variant: 'identity', isInteractive: false });

/**
 * HIG: with clear Liquid Glass, "if the underlying content is bright, consider
 * adding a dark dimming layer of 35% opacity". Returns the alpha to use, or 0
 * when the backdrop is already dark enough to skip it.
 */
export function clearDimAlpha(avgLuma: number, threshold = 0.5): number {
  return avgLuma > threshold ? 0.35 : 0;
}

/**
 * Applies whatever the system is currently asking for. Apple does this for you
 * inside .glassEffect; here it is one explicit call.
 */
export function applySystemState(glass: Glass, state: SystemGlassState = systemGlassState()): Glass {
  let g = glass;
  if (state.reduceTransparency) g = g.withReducedTransparency();
  if (state.increaseContrast) g = g.withIncreasedContrast();
  return g;
}

export interface SystemGlassState {
  reduceTransparency: boolean;
  increaseContrast: boolean;
  dark: boolean;
}

/** Live accessibility state, so a caller can pick the variant Apple would. */
export function systemGlassState(): SystemGlassState {
  // matchMedia only exists on the web. On React Native the caller supplies the
  // state from AccessibilityInfo (isReduceTransparencyEnabled /
  // isHighTextContrastEnabled) and passes it to applySystemState directly.
  const mm = (globalThis as any).matchMedia;
  const q = (s: string) => typeof mm === 'function' && !!mm(s).matches;
  return {
    reduceTransparency: q('(prefers-reduced-transparency: reduce)'),
    increaseContrast: q('(prefers-contrast: more)'),
    dark: q('(prefers-color-scheme: dark)'),
  };
}
