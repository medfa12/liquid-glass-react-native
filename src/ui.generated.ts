/**
 * Liquid Glass — UI kit layer.
 *
 * Everything a nav bar or toolbar needs on top of the material itself:
 * vibrancy roles for content, concentric corner radii for nesting, group
 * splitting, and press states.
 */

export type Vibrancy = "primary" | "secondary" | "tertiary" | "quaternary" | "separator" | "highlight";
export type Appearance = "light" | "dark";

/**
 * Content tint matrices, extracted verbatim from Apple's
 * platformFill{Light,Dark}.visualstyleset. Each row is [r, g, b, bias].
 *
 * These are what labels, glyphs and separators on glass are tinted with —
 * light `primary` lands mid-grey at 0.250 (dark content on light glass), dark
 * `primary` at 0.750. Using flat black/white instead is the usual reason
 * content on glass looks wrong.
 */
export const VIBRANCY: Record<Appearance, Record<Vibrancy, number[][]>> = {
  light: {
    primary: [
    [1.5141, -0.9548, -0.1844, 0.0625],
    [-0.4856, 1.0462, -0.1856, 0.0625],
    [-0.4868, -0.9529, 1.8148, 0.0625]
    ],
    secondary: [
    [1.2355, -0.3235, -0.0621, 0.0000],
    [-0.1643, 1.0772, -0.0629, 0.0000],
    [-0.1651, -0.3222, 1.3373, 0.0000]
    ],
    tertiary: [
    [1.1776, -0.1426, -0.0270, -0.0840],
    [-0.0722, 1.1080, -0.0278, -0.0840],
    [-0.0729, -0.1415, 1.2224, -0.0840]
    ],
    quaternary: [
    [1.4076, -0.5748, -0.1107, 0.0190],
    [-0.2922, 1.1260, -0.1118, 0.0190],
    [-0.2932, -0.5733, 1.5885, 0.0190]
    ],
    separator: [
    [1.4076, -0.5748, -0.1107, 0.0190],
    [-0.2922, 1.1260, -0.1118, 0.0190],
    [-0.2932, -0.5733, 1.5885, 0.0190]
    ],
    highlight: [
    [1.1776, -0.1426, -0.0270, -0.0840],
    [-0.0722, 1.1080, -0.0278, -0.0840],
    [-0.0729, -0.1415, 1.2224, -0.0840]
    ],
  },
  dark: {
    primary: [
    [1.3762, -0.7345, -0.1417, 0.5000],
    [-0.3735, 1.0163, -0.1428, 0.5000],
    [-0.3746, -0.7329, 1.6075, 0.5000]
    ],
    secondary: [
    [1.2266, -0.3411, -0.0655, 0.1800],
    [-0.1732, 1.0596, -0.0664, 0.1800],
    [-0.1741, -0.3398, 1.3339, 0.1800]
    ],
    tertiary: [
    [1.0605, -0.0780, -0.0146, 0.1200],
    [-0.0393, 1.0225, -0.0152, 0.1200],
    [-0.0400, -0.0770, 1.0850, 0.1200]
    ],
    quaternary: [
    [1.3962, -0.5971, -0.1151, 0.2980],
    [-0.3036, 1.1037, -0.1161, 0.2980],
    [-0.3046, -0.5956, 1.5842, 0.2980]
    ],
    separator: [
    [1.3962, -0.5971, -0.1151, 0.2980],
    [-0.3036, 1.1037, -0.1161, 0.2980],
    [-0.3046, -0.5956, 1.5842, 0.2980]
    ],
    highlight: [
    [1.0605, -0.0780, -0.0146, 0.1200],
    [-0.0393, 1.0225, -0.0152, 0.1200],
    [-0.0400, -0.0770, 1.0850, 0.1200]
    ],
  },
};

/** Apply a vibrancy role to a colour. */
export function applyVibrancy(rgb: [number, number, number], appearance: Appearance, role: Vibrancy): [number, number, number] {
  const m = VIBRANCY[appearance][role];
  return [
    rgb[0] * m[0][0] + rgb[1] * m[0][1] + rgb[2] * m[0][2] + m[0][3],
    rgb[0] * m[1][0] + rgb[1] * m[1][1] + rgb[2] * m[1][2] + m[1][3],
    rgb[0] * m[2][0] + rgb[1] * m[2][1] + rgb[2] * m[2][2] + m[2][3],
  ];
}

/**
 * Concentric corner radius for nested glass (NSContainerConcentricGlassEffectView).
 *
 * A child inset by `inset` inside a parent of radius `outer` must use
 * `outer - inset`, not `outer`. Reusing the parent's radius makes the gap
 * between the curves visibly non-uniform — the corners look pinched. Clamped at
 * 0 so a deep inset degrades to a square corner rather than inverting.
 */
export function concentricRadius(outer: number, inset: number): number {
  return Math.max(0, outer - inset);
}

/**
 * Group-splitting policy (NSGlassEffectContainerViewAutomaticallySplitsGroups).
 *
 * Elements closer than `spacing` merge into one glass body; beyond it they
 * stay separate. Returns index groups, so a container can decide how many
 * SDF unions to run rather than merging everything unconditionally.
 */
export function splitGroups(
  rects: { x: number; y: number; w: number; h: number }[],
  spacing: number
): number[][] {
  const groups: number[][] = [];
  const seen = new Set<number>();
  const gap = (a: typeof rects[0], b: typeof rects[0]) => {
    const dx = Math.max(0, Math.max(a.x - (b.x + b.w), b.x - (a.x + a.w)));
    const dy = Math.max(0, Math.max(a.y - (b.y + b.h), b.y - (a.y + a.h)));
    return Math.hypot(dx, dy);
  };
  for (let i = 0; i < rects.length; i++) {
    if (seen.has(i)) continue;
    const g = [i];
    seen.add(i);
    for (let k = 0; k < g.length; k++) {
      for (let j = 0; j < rects.length; j++) {
        if (seen.has(j)) continue;
        if (gap(rects[g[k]], rects[j]) <= spacing) { g.push(j); seen.add(j); }
      }
    }
    groups.push(g);
  }
  return groups;
}

/**
 * Press state. Apple's glass squishes slightly and the specular lifts under a
 * press; releasing overshoots before settling. Feed `t` from your gesture
 * (0 released, 1 held) and apply the result to the glass params.
 */
export function pressState(t: number): { scale: number; highlightBoost: number; blurBoost: number } {
  const e = Math.min(Math.max(t, 0), 1);
  const s = e * e * (3 - 2 * e);
  return {
    scale: 1 - 0.035 * s,        // subtle: more than ~4% reads as a bounce, not a press
    highlightBoost: 1 + 0.45 * s,
    blurBoost: 1 + 0.20 * s,
  };
}

