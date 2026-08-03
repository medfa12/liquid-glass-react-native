// Generated from portable/liquid_glass_27_params.h (SPIR-V reflection).
// macOS 27 (build 26A5388g) field order. std140 offsets are exact.

export const PARAM27_BYTES = 416;
export const PARAM27_FLOATS = 104;

export interface GlassParams27 {
  displacementMat: [number, number, number, number];
  innerRefractionAmount: number;
  innerRefractionInvHeight: number;
  outerRefractionAmount: number;
  outerRefractionInvHeight: number;
  refractionThreshold0: number;
  refractionThreshold1: number;
  blurRadius: number;
  edgeBleedBlurRadius: number;
  edgeBleedAmount: number;
  edgeBleedInvHeight: number;
  shadowAmount: number;
  shadowInvHeight: number;
  shadowOffset: [number, number];
  shadowBlurRadius: number;
  shadowInvRadius: number;
  faceCm0: [number, number, number, number];
  faceCm1: [number, number, number, number];
  faceCm2: [number, number, number, number];
  bleedCm0: [number, number, number, number];
  bleedCm1: [number, number, number, number];
  bleedCm2: [number, number, number, number];
  shadowCm0: [number, number, number, number];
  shadowCm1: [number, number, number, number];
  shadowCm2: [number, number, number, number];
  shadowContribution: number;
  shadowFaceOpacity: number;
  blurAlpha0: number;
  blurAlpha1: number;
  blurAlpha2: number;
  blurAlpha3: number;
  blurDist0: number;
  blurDist1: number;
  blurDist2: number;
  blurDist3: number;
  edgeBleedDist0: number;
  edgeBleedDist1: number;
  edgeBleedOpacity: number;
  faceOpacity: number;
  bleedDarken: [number, number];
  shadowDistOffset: number;
  shadowOpacity: number;
  refractionOpacity: number;
  holdingToneOpacity: number;
  sdrShadowDist0: number;
  sdrShadowInv: number;
  ringShadowOffset: [number, number];
  ringShadowStrokeWidth: number;
  ringShadowRadius: number;
  ringShadowOpacity: number;
  ringShadowMask: number;
  keyFillHighlightDir: [number, number];
  keyFillHighlightHeight: number;
  keyFillHighlightSpread: number;
  keyFillHighlightAmount: number;
  keyFillHighlightEffectOffset: number;
  keyFillHighlightColorBias: number;
  blurFillBlurRadius: number;
  blurFillLightenOpacity: number;
  blurFillDarkenOpacity: number;
  blurFillNormalOpacity: number;
  aberrationAmount: number;
  aberrationDir: [number, number];
  halfSize: [number, number];
  exponent: number;
  scaleRef: number;
}

export const OFFSETS27: Record<string, number> = {
  displacementMat: 0,
  innerRefractionAmount: 16,
  innerRefractionInvHeight: 20,
  outerRefractionAmount: 24,
  outerRefractionInvHeight: 28,
  refractionThreshold0: 32,
  refractionThreshold1: 36,
  blurRadius: 40,
  edgeBleedBlurRadius: 44,
  edgeBleedAmount: 48,
  edgeBleedInvHeight: 52,
  shadowAmount: 56,
  shadowInvHeight: 60,
  shadowOffset: 64,
  shadowBlurRadius: 72,
  shadowInvRadius: 76,
  faceCm0: 80,
  faceCm1: 96,
  faceCm2: 112,
  bleedCm0: 128,
  bleedCm1: 144,
  bleedCm2: 160,
  shadowCm0: 176,
  shadowCm1: 192,
  shadowCm2: 208,
  shadowContribution: 224,
  shadowFaceOpacity: 228,
  blurAlpha0: 232,
  blurAlpha1: 236,
  blurAlpha2: 240,
  blurAlpha3: 244,
  blurDist0: 248,
  blurDist1: 252,
  blurDist2: 256,
  blurDist3: 260,
  edgeBleedDist0: 264,
  edgeBleedDist1: 268,
  edgeBleedOpacity: 272,
  faceOpacity: 276,
  bleedDarken: 280,
  shadowDistOffset: 288,
  shadowOpacity: 292,
  refractionOpacity: 296,
  holdingToneOpacity: 300,
  sdrShadowDist0: 304,
  sdrShadowInv: 308,
  ringShadowOffset: 312,
  ringShadowStrokeWidth: 320,
  ringShadowRadius: 324,
  ringShadowOpacity: 328,
  ringShadowMask: 332,
  keyFillHighlightDir: 336,
  keyFillHighlightHeight: 344,
  keyFillHighlightSpread: 348,
  keyFillHighlightAmount: 352,
  keyFillHighlightEffectOffset: 356,
  keyFillHighlightColorBias: 360,
  blurFillBlurRadius: 364,
  blurFillLightenOpacity: 368,
  blurFillDarkenOpacity: 372,
  blurFillNormalOpacity: 376,
  aberrationAmount: 380,
  aberrationDir: 384,
  halfSize: 392,
  exponent: 400,
  scaleRef: 404,
};

export function packParams27(p: GlassParams27, out: Float32Array): Float32Array {
  out[0] = p.displacementMat[0];
  out[1] = p.displacementMat[1];
  out[2] = p.displacementMat[2];
  out[3] = p.displacementMat[3];
  out[4] = p.innerRefractionAmount;
  out[5] = p.innerRefractionInvHeight;
  out[6] = p.outerRefractionAmount;
  out[7] = p.outerRefractionInvHeight;
  out[8] = p.refractionThreshold0;
  out[9] = p.refractionThreshold1;
  out[10] = p.blurRadius;
  out[11] = p.edgeBleedBlurRadius;
  out[12] = p.edgeBleedAmount;
  out[13] = p.edgeBleedInvHeight;
  out[14] = p.shadowAmount;
  out[15] = p.shadowInvHeight;
  out[16] = p.shadowOffset[0];
  out[17] = p.shadowOffset[1];
  out[18] = p.shadowBlurRadius;
  out[19] = p.shadowInvRadius;
  out[20] = p.faceCm0[0];
  out[21] = p.faceCm0[1];
  out[22] = p.faceCm0[2];
  out[23] = p.faceCm0[3];
  out[24] = p.faceCm1[0];
  out[25] = p.faceCm1[1];
  out[26] = p.faceCm1[2];
  out[27] = p.faceCm1[3];
  out[28] = p.faceCm2[0];
  out[29] = p.faceCm2[1];
  out[30] = p.faceCm2[2];
  out[31] = p.faceCm2[3];
  out[32] = p.bleedCm0[0];
  out[33] = p.bleedCm0[1];
  out[34] = p.bleedCm0[2];
  out[35] = p.bleedCm0[3];
  out[36] = p.bleedCm1[0];
  out[37] = p.bleedCm1[1];
  out[38] = p.bleedCm1[2];
  out[39] = p.bleedCm1[3];
  out[40] = p.bleedCm2[0];
  out[41] = p.bleedCm2[1];
  out[42] = p.bleedCm2[2];
  out[43] = p.bleedCm2[3];
  out[44] = p.shadowCm0[0];
  out[45] = p.shadowCm0[1];
  out[46] = p.shadowCm0[2];
  out[47] = p.shadowCm0[3];
  out[48] = p.shadowCm1[0];
  out[49] = p.shadowCm1[1];
  out[50] = p.shadowCm1[2];
  out[51] = p.shadowCm1[3];
  out[52] = p.shadowCm2[0];
  out[53] = p.shadowCm2[1];
  out[54] = p.shadowCm2[2];
  out[55] = p.shadowCm2[3];
  out[56] = p.shadowContribution;
  out[57] = p.shadowFaceOpacity;
  out[58] = p.blurAlpha0;
  out[59] = p.blurAlpha1;
  out[60] = p.blurAlpha2;
  out[61] = p.blurAlpha3;
  out[62] = p.blurDist0;
  out[63] = p.blurDist1;
  out[64] = p.blurDist2;
  out[65] = p.blurDist3;
  out[66] = p.edgeBleedDist0;
  out[67] = p.edgeBleedDist1;
  out[68] = p.edgeBleedOpacity;
  out[69] = p.faceOpacity;
  out[70] = p.bleedDarken[0];
  out[71] = p.bleedDarken[1];
  out[72] = p.shadowDistOffset;
  out[73] = p.shadowOpacity;
  out[74] = p.refractionOpacity;
  out[75] = p.holdingToneOpacity;
  out[76] = p.sdrShadowDist0;
  out[77] = p.sdrShadowInv;
  out[78] = p.ringShadowOffset[0];
  out[79] = p.ringShadowOffset[1];
  out[80] = p.ringShadowStrokeWidth;
  out[81] = p.ringShadowRadius;
  out[82] = p.ringShadowOpacity;
  out[83] = p.ringShadowMask;
  out[84] = p.keyFillHighlightDir[0];
  out[85] = p.keyFillHighlightDir[1];
  out[86] = p.keyFillHighlightHeight;
  out[87] = p.keyFillHighlightSpread;
  out[88] = p.keyFillHighlightAmount;
  out[89] = p.keyFillHighlightEffectOffset;
  out[90] = p.keyFillHighlightColorBias;
  out[91] = p.blurFillBlurRadius;
  out[92] = p.blurFillLightenOpacity;
  out[93] = p.blurFillDarkenOpacity;
  out[94] = p.blurFillNormalOpacity;
  out[95] = p.aberrationAmount;
  out[96] = p.aberrationDir[0];
  out[97] = p.aberrationDir[1];
  out[98] = p.halfSize[0];
  out[99] = p.halfSize[1];
  out[100] = p.exponent;
  out[101] = p.scaleRef;
  return out;
}
