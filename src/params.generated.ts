// Generated from portable/liquid_glass_params.h (SPIR-V reflection).
// std140 offsets are exact. Do not reorder.

export const PARAM_BYTES = 560;
export const PARAM_FLOATS = 140;

export interface GlassParams {
  halfSize: [number, number];
  exponent: number;
  innerRefractAmount: number;
  innerRefractInvHeight: number;
  outerRefractAmount: number;
  outerRefractInvHeight: number;
  refractOpacity: number;
  complexRefraction: number;
  refractThreshold: [number, number];
  displacementMat: [number, number, number, number];
  refractAngle: [number, number];
  aberrationAmount: number;
  aberrationInvHeight: number;
  aberrationOffset: number;
  aberrationAngle: [number, number];
  blurDist: [number, number, number, number];
  blurAlpha: [number, number, number, number];
  blurRadius: number;
  edgeBleedAmount: number;
  edgeBleedInvHeight: number;
  edgeBleedBlurRadius: number;
  edgeBleedDist: [number, number];
  edgeBleedOpacity: number;
  bleedDarken: [number, number];
  edgeRange: [number, number];
  edgeOpacity: [number, number];
  lightDir: [number, number];
  highlightThreshold: number;
  highlightHeight: number;
  highlightSoftness: number;
  highlightIntensity: number;
  shadowAmount: number;
  shadowInvHeight: number;
  shadowOffset: [number, number];
  shadowInvRadius: number;
  shadowOpacity: number;
  shadowContribution: number;
  shadowDistOffset: number;
  faceCM0: [number, number, number, number];
  faceCM1: [number, number, number, number];
  faceCM2: [number, number, number, number];
  bleedCM0: [number, number, number, number];
  bleedCM1: [number, number, number, number];
  bleedCM2: [number, number, number, number];
  shadowCM0: [number, number, number, number];
  shadowCM1: [number, number, number, number];
  shadowCM2: [number, number, number, number];
  faceOpacity: number;
  clampLimit: number;
  preserveHue: number;
  sdrWhite: number;
  edrScale: number;
  diffusion: number;
  extraCount: number;
  shape2: [number, number, number, number];
  shape3: [number, number, number, number];
  shape4: [number, number, number, number];
  mergeK: number;
  rimGlintGain: number;
  rimGlintTau: number;
  ringShadowOffset: [number, number];
  ringShadowStrokeWidth: number;
  ringShadowRadius: number;
  ringShadowOpacity: number;
  ringShadowMask: number;
  keyFillDir: [number, number];
  keyFillHeight: number;
  keyFillSpread: number;
  keyFillAmount: number;
  keyFillEffectOffset: number;
  keyFillColorBias: number;
  blurFillBlurRadius: number;
  blurFillLightenOpacity: number;
  blurFillDarkenOpacity: number;
  blurFillNormalOpacity: number;
  scaleRef: number;
}

export const OFFSETS: Record<string, number> = {
  halfSize: 0,
  exponent: 8,
  innerRefractAmount: 12,
  innerRefractInvHeight: 16,
  outerRefractAmount: 20,
  outerRefractInvHeight: 24,
  refractOpacity: 28,
  complexRefraction: 32,
  refractThreshold: 40,
  displacementMat: 48,
  refractAngle: 64,
  aberrationAmount: 72,
  aberrationInvHeight: 76,
  aberrationOffset: 80,
  aberrationAngle: 88,
  blurDist: 96,
  blurAlpha: 112,
  blurRadius: 128,
  edgeBleedAmount: 132,
  edgeBleedInvHeight: 136,
  edgeBleedBlurRadius: 140,
  edgeBleedDist: 144,
  edgeBleedOpacity: 152,
  bleedDarken: 160,
  edgeRange: 168,
  edgeOpacity: 176,
  lightDir: 184,
  highlightThreshold: 192,
  highlightHeight: 196,
  highlightSoftness: 200,
  highlightIntensity: 204,
  shadowAmount: 208,
  shadowInvHeight: 212,
  shadowOffset: 216,
  shadowInvRadius: 224,
  shadowOpacity: 228,
  shadowContribution: 232,
  shadowDistOffset: 236,
  faceCM0: 240,
  faceCM1: 256,
  faceCM2: 272,
  bleedCM0: 288,
  bleedCM1: 304,
  bleedCM2: 320,
  shadowCM0: 336,
  shadowCM1: 352,
  shadowCM2: 368,
  faceOpacity: 384,
  clampLimit: 388,
  preserveHue: 392,
  sdrWhite: 396,
  edrScale: 400,
  diffusion: 404,
  extraCount: 408,
  shape2: 416,
  shape3: 432,
  shape4: 448,
  mergeK: 464,
  rimGlintGain: 468,
  rimGlintTau: 472,
  ringShadowOffset: 480,
  ringShadowStrokeWidth: 488,
  ringShadowRadius: 492,
  ringShadowOpacity: 496,
  ringShadowMask: 500,
  keyFillDir: 504,
  keyFillHeight: 512,
  keyFillSpread: 516,
  keyFillAmount: 520,
  keyFillEffectOffset: 524,
  keyFillColorBias: 528,
  blurFillBlurRadius: 532,
  blurFillLightenOpacity: 536,
  blurFillDarkenOpacity: 540,
  blurFillNormalOpacity: 544,
  scaleRef: 548,
};

export function packParams(p: GlassParams, out: Float32Array): Float32Array {
  out[0] = p.halfSize[0];
  out[1] = p.halfSize[1];
  out[2] = p.exponent;
  out[3] = p.innerRefractAmount;
  out[4] = p.innerRefractInvHeight;
  out[5] = p.outerRefractAmount;
  out[6] = p.outerRefractInvHeight;
  out[7] = p.refractOpacity;
  out[8] = p.complexRefraction;
  out[10] = p.refractThreshold[0];
  out[11] = p.refractThreshold[1];
  out[12] = p.displacementMat[0];
  out[13] = p.displacementMat[1];
  out[14] = p.displacementMat[2];
  out[15] = p.displacementMat[3];
  out[16] = p.refractAngle[0];
  out[17] = p.refractAngle[1];
  out[18] = p.aberrationAmount;
  out[19] = p.aberrationInvHeight;
  out[20] = p.aberrationOffset;
  out[22] = p.aberrationAngle[0];
  out[23] = p.aberrationAngle[1];
  out[24] = p.blurDist[0];
  out[25] = p.blurDist[1];
  out[26] = p.blurDist[2];
  out[27] = p.blurDist[3];
  out[28] = p.blurAlpha[0];
  out[29] = p.blurAlpha[1];
  out[30] = p.blurAlpha[2];
  out[31] = p.blurAlpha[3];
  out[32] = p.blurRadius;
  out[33] = p.edgeBleedAmount;
  out[34] = p.edgeBleedInvHeight;
  out[35] = p.edgeBleedBlurRadius;
  out[36] = p.edgeBleedDist[0];
  out[37] = p.edgeBleedDist[1];
  out[38] = p.edgeBleedOpacity;
  out[40] = p.bleedDarken[0];
  out[41] = p.bleedDarken[1];
  out[42] = p.edgeRange[0];
  out[43] = p.edgeRange[1];
  out[44] = p.edgeOpacity[0];
  out[45] = p.edgeOpacity[1];
  out[46] = p.lightDir[0];
  out[47] = p.lightDir[1];
  out[48] = p.highlightThreshold;
  out[49] = p.highlightHeight;
  out[50] = p.highlightSoftness;
  out[51] = p.highlightIntensity;
  out[52] = p.shadowAmount;
  out[53] = p.shadowInvHeight;
  out[54] = p.shadowOffset[0];
  out[55] = p.shadowOffset[1];
  out[56] = p.shadowInvRadius;
  out[57] = p.shadowOpacity;
  out[58] = p.shadowContribution;
  out[59] = p.shadowDistOffset;
  out[60] = p.faceCM0[0];
  out[61] = p.faceCM0[1];
  out[62] = p.faceCM0[2];
  out[63] = p.faceCM0[3];
  out[64] = p.faceCM1[0];
  out[65] = p.faceCM1[1];
  out[66] = p.faceCM1[2];
  out[67] = p.faceCM1[3];
  out[68] = p.faceCM2[0];
  out[69] = p.faceCM2[1];
  out[70] = p.faceCM2[2];
  out[71] = p.faceCM2[3];
  out[72] = p.bleedCM0[0];
  out[73] = p.bleedCM0[1];
  out[74] = p.bleedCM0[2];
  out[75] = p.bleedCM0[3];
  out[76] = p.bleedCM1[0];
  out[77] = p.bleedCM1[1];
  out[78] = p.bleedCM1[2];
  out[79] = p.bleedCM1[3];
  out[80] = p.bleedCM2[0];
  out[81] = p.bleedCM2[1];
  out[82] = p.bleedCM2[2];
  out[83] = p.bleedCM2[3];
  out[84] = p.shadowCM0[0];
  out[85] = p.shadowCM0[1];
  out[86] = p.shadowCM0[2];
  out[87] = p.shadowCM0[3];
  out[88] = p.shadowCM1[0];
  out[89] = p.shadowCM1[1];
  out[90] = p.shadowCM1[2];
  out[91] = p.shadowCM1[3];
  out[92] = p.shadowCM2[0];
  out[93] = p.shadowCM2[1];
  out[94] = p.shadowCM2[2];
  out[95] = p.shadowCM2[3];
  out[96] = p.faceOpacity;
  out[97] = p.clampLimit;
  out[98] = p.preserveHue;
  out[99] = p.sdrWhite;
  out[100] = p.edrScale;
  out[101] = p.diffusion;
  out[102] = p.extraCount;
  out[104] = p.shape2[0];
  out[105] = p.shape2[1];
  out[106] = p.shape2[2];
  out[107] = p.shape2[3];
  out[108] = p.shape3[0];
  out[109] = p.shape3[1];
  out[110] = p.shape3[2];
  out[111] = p.shape3[3];
  out[112] = p.shape4[0];
  out[113] = p.shape4[1];
  out[114] = p.shape4[2];
  out[115] = p.shape4[3];
  out[116] = p.mergeK;
  out[117] = p.rimGlintGain;
  out[118] = p.rimGlintTau;
  out[120] = p.ringShadowOffset[0];
  out[121] = p.ringShadowOffset[1];
  out[122] = p.ringShadowStrokeWidth;
  out[123] = p.ringShadowRadius;
  out[124] = p.ringShadowOpacity;
  out[125] = p.ringShadowMask;
  out[126] = p.keyFillDir[0];
  out[127] = p.keyFillDir[1];
  out[128] = p.keyFillHeight;
  out[129] = p.keyFillSpread;
  out[130] = p.keyFillAmount;
  out[131] = p.keyFillEffectOffset;
  out[132] = p.keyFillColorBias;
  out[133] = p.blurFillBlurRadius;
  out[134] = p.blurFillLightenOpacity;
  out[135] = p.blurFillDarkenOpacity;
  out[136] = p.blurFillNormalOpacity;
  out[137] = p.scaleRef;
  return out;
}
