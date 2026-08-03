/**
 * Liquid Glass parameter presets.
 *
 * Values marked FITTED were recovered by least-squares against a real
 * NSGlassEffectView capture on macOS 26.5.2, not copied from Apple's shipped
 * material recipes. Applying the recipe values directly renders ~2.09x too
 * bright, because the recipe is only the first of several composited layers.
 * See portable/README.md.
 */

export * from './params.generated';
import { GlassParams } from './params.generated';

/** Base preset — a neutral glass panel. */
export function defaultParams(): GlassParams {
  return {
    // FITTED: superellipse fit to 1011 boundary pixels of a real capture.
    // Apple's corner is squarer than a naive 4.5 squircle. NOT a rounded rect —
    halfSize: [120, 40],
    exponent: 6.5,

    // The lobes must have OPPOSITE signs. Matching signs give you a lens;
    innerRefractAmount: 4,
    innerRefractInvHeight: 1 / 18,
    outerRefractAmount: -13,
    outerRefractInvHeight: 1 / 10,
    refractOpacity: 0.65,
    complexRefraction: 1,
    refractThreshold: [-30, 0],
    displacementMat: [1, 0, 0, 1],
    refractAngle: [1, 0],

    aberrationAmount: 3,
    aberrationInvHeight: 1 / 14,
    aberrationOffset: 0,
    aberrationAngle: [1, 0],

    // FITTED: effective gaussian sigma ~8 (radius ~16). The material recipe
    blurRadius: 28,
    blurDist: [0, 8, 20, 40],
    blurAlpha: [1, 0.6, 0.3, 0],

    edgeBleedAmount: 24,
    edgeBleedInvHeight: 1 / 12,
    edgeBleedBlurRadius: 32,
    edgeBleedDist: [0, 14],
    edgeBleedOpacity: 0.15,
    bleedDarken: [0.92, 0],

    edgeRange: [0, 8],
    edgeOpacity: [0, 0],

    lightDir: [0, -1],
    highlightThreshold: 0.35,
    highlightHeight: 10,
    highlightSoftness: 0.5,
    highlightIntensity: 0,

    shadowAmount: 10,
    shadowInvHeight: 1 / 20,
    shadowOffset: [0, 0.004],
    shadowInvRadius: 1 / 26,
    shadowOpacity: 0,
    shadowContribution: 0.5,
    shadowDistOffset: 6,

    // FITTED from the rim residual: 0.0856 * exp(-d / 1.50) — a very sharp
    // because a glint is emissive and must not be attenuated by antialiasing.
    rimGlintGain: 0.1,
    rimGlintTau: 1.5,

    // FITTED. The off-diagonals match Apple's shipped recipe to +/-0.008 —
    faceCM0: [0.3545, -0.1604, -0.0150, 0.1283],
    faceCM1: [-0.0368, 0.2329, -0.0158, 0.1297],
    faceCM2: [-0.0438, -0.1498, 0.3705, 0.1263],
    bleedCM0: [1, 0, 0, 0],
    bleedCM1: [0, 1, 0, 0],
    bleedCM2: [0, 0, 1, 0],
    shadowCM0: [0.2, 0, 0, 0],
    shadowCM1: [0, 0.2, 0, 0],
    shadowCM2: [0, 0, 0.2, 0],
    faceOpacity: 1,

    clampLimit: 0,
    preserveHue: 1,
    sdrWhite: 1,
    edrScale: 1,

    diffusion: 1,

    extraCount: 0,
    mergeK: 45,
    shape2: [0, 0, 0, 0],
    shape3: [0, 0, 0, 0],
    shape4: [0, 0, 0, 0],

    ringShadowOffset: [0, 0],
    ringShadowStrokeWidth: 9,
    ringShadowRadius: 30,
    ringShadowOpacity: 0,
    ringShadowMask: 1,
    keyFillDir: [0.35, -0.94],
    keyFillHeight: 70,
    keyFillSpread: 0.55,
    keyFillAmount: 0,
    keyFillEffectOffset: 4,
    keyFillColorBias: 0,
    blurFillBlurRadius: 48,
    blurFillLightenOpacity: 0,
    blurFillDarkenOpacity: 0,
    blurFillNormalOpacity: 0,

    // Pixel-denominated params were fitted at a 240x150 panel, so
    // min(halfSize) = 75. Everything in pixels scales from here.
    scaleRef: 75,
    adaptiveAmount: 0.6,
    luminanceValues: [0.8, 0.9, 1.1, 0.825],
    adaptiveTintDark: 0.12,
    adaptiveTintLight: 0.95,
  };
}

export type PresetName = 'regular' | 'clear' | 'macos27';

/** Named presets. `macos27` enables the three subsystems added in macOS 27. */
export function preset(name: PresetName): GlassParams {
  const p = defaultParams();
  switch (name) {
    case 'clear':
      p.faceCM0 = [0.78, -0.15, -0.02, 0.06];
      p.faceCM1 = [-0.05, 0.62, -0.02, 0.06];
      p.faceCM2 = [-0.04, -0.14, 0.80, 0.06];
      p.blurRadius = 10;
      p.edgeBleedOpacity = 0.3;
      return p;
    case 'macos27':
      p.ringShadowOpacity = 0.3;
      p.keyFillAmount = 0.7;
      p.blurFillLightenOpacity = 0.3;
      p.blurFillDarkenOpacity = 0.22;
      p.blurFillNormalOpacity = 0.15;
      return p;
    default:
      return p;
  }
}
