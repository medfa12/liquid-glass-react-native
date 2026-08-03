#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct GlassParams
{
    float2 uHalfSize;
    float uExponent;
    float uInnerRefractAmount;
    float uInnerRefractInvHeight;
    float uOuterRefractAmount;
    float uOuterRefractInvHeight;
    float uRefractOpacity;
    float uComplexRefraction;
    float2 uRefractThreshold;
    float4 uDisplacementMat;
    float2 uRefractAngle;
    float uAberrationAmount;
    float uAberrationInvHeight;
    float uAberrationOffset;
    float2 uAberrationAngle;
    float4 uBlurDist;
    float4 uBlurAlpha;
    float uBlurRadius;
    float uEdgeBleedAmount;
    float uEdgeBleedInvHeight;
    float uEdgeBleedBlurRadius;
    float2 uEdgeBleedDist;
    float uEdgeBleedOpacity;
    float2 uBleedDarken;
    float2 uEdgeRange;
    float2 uEdgeOpacity;
    float2 uLightDir;
    float uHighlightThreshold;
    float uHighlightHeight;
    float uHighlightSoftness;
    float uHighlightIntensity;
    float uShadowAmount;
    float uShadowInvHeight;
    float2 uShadowOffset;
    float uShadowInvRadius;
    float uShadowOpacity;
    float uShadowContribution;
    float uShadowDistOffset;
    float4 uFaceCM0;
    float4 uFaceCM1;
    float4 uFaceCM2;
    float4 uBleedCM0;
    float4 uBleedCM1;
    float4 uBleedCM2;
    float4 uShadowCM0;
    float4 uShadowCM1;
    float4 uShadowCM2;
    float uFaceOpacity;
    float uClampLimit;
    float uPreserveHue;
    float uSDRWhite;
    float uEDRScale;
    float uDiffusion;
    float uExtraCount;
    float4 uShape2;
    float4 uShape3;
    float4 uShape4;
    float uMergeK;
    float uRimGlintGain;
    float uRimGlintTau;
    float2 uRingShadowOffset;
    float uRingShadowStrokeWidth;
    float uRingShadowRadius;
    float uRingShadowOpacity;
    float uRingShadowMask;
    float2 uKeyFillDir;
    float uKeyFillHeight;
    float uKeyFillSpread;
    float uKeyFillAmount;
    float uKeyFillEffectOffset;
    float uKeyFillColorBias;
    float uBlurFillBlurRadius;
    float uBlurFillLightenOpacity;
    float uBlurFillDarkenOpacity;
    float uBlurFillNormalOpacity;
    float uScaleRef;
    float uAdaptiveAmount;
    float4 uLuminanceValues;
    float uAdaptiveTintDark;
    float uAdaptiveTintLight;
};

struct main0_out
{
    float4 fragColor [[color(0)]];
};

struct main0_in
{
    float2 vUV [[user(locn0)]];
    float2 vBackdropUV [[user(locn1)]];
};

static inline __attribute__((always_inline))
float diffusionCurve(thread const float& d, thread const float& power)
{
    return powr(fast::clamp(d, 0.0, 1.0), power);
}

static inline __attribute__((always_inline))
void supercircleSDF(thread const float2& p, thread const float2& halfSize, thread const float& n, thread float& dist, thread float2& normal)
{
    float2 q = p / halfSize;
    float2 a = fast::max(abs(q), float2(9.9999999747524270787835121154785e-07));
    float xn = powr(a.x, n);
    float yn = powr(a.y, n);
    float s = xn + yn;
    float f = powr(s, 1.0 / n) - 1.0;
    float k = powr(s, (1.0 / n) - 1.0);
    float2 g = (sign(q) * k) * float2(powr(a.x, n - 1.0), powr(a.y, n - 1.0));
    g /= halfSize;
    float gl = fast::max(length(g), 9.9999999747524270787835121154785e-07);
    float inradius = fast::min(halfSize.x, halfSize.y);
    dist = fast::clamp(f / gl, -inradius, inradius * 4.0);
    normal = g / float2(gl);
}

static inline __attribute__((always_inline))
void smoothUnion(thread const float& d1, thread const float2& n1, thread const float& d2, thread const float2& n2, thread float& k, thread float& d, thread float2& n)
{
    k = fast::max(k, 9.9999997473787516355514526367188e-05);
    float h = fast::clamp(0.5 + ((0.5 * (d2 - d1)) / k), 0.0, 1.0);
    d = mix(d2, d1, h) - ((k * h) * (1.0 - h));
    n = fast::normalize(mix(n2, n1, float2(h)) + float2(9.9999997473787516355514526367188e-05, 0.0));
}

static inline __attribute__((always_inline))
float lensCurve(thread float& t)
{
    t = fast::clamp(t, 0.0, 1.0);
    return fast::clamp(sqrt((2.0 - t) * t), 0.0, 1.0);
}

static inline __attribute__((always_inline))
float refractLobe(thread const float& dist, thread const float& amount, thread const float& invHeight, thread const float& offset)
{
    float t = fast::clamp(((-dist) - offset) * invHeight, 0.0, 1.0);
    float param = t;
    float _244 = lensCurve(param);
    return amount - (_244 * amount);
}

static inline __attribute__((always_inline))
float blurRampRadius(thread const float& dist, thread const float& blurScale, thread const float& uScaleFactor, constant GlassParams& _284)
{
    float3 lo = _284.uBlurDist.yzw;
    float3 hi = float3(_284.uBlurDist.x, _284.uBlurDist.y, _284.uBlurDist.z);
    float3 span = hi - lo;
    float3 degen = step(abs(span), float3(9.9999999747524270787835121154785e-07));
    float3 inv = float3(1.0) / mix(span, float3(9.9999999747524270787835121154785e-07), degen);
    float3 t = fast::clamp((float3(dist) - lo) * inv, float3(0.0), float3(1.0));
    float3 w = _284.uBlurAlpha.yzw * t;
    return (((_284.uBlurAlpha.x - ((w.x + w.y) + w.z)) * _284.uBlurRadius) * blurScale) * uScaleFactor;
}

static inline __attribute__((always_inline))
float blurLOD(thread const float& radius)
{
    float _254;
    if (radius < 2.0)
    {
        _254 = (radius * 0.5) + 1.0;
    }
    else
    {
        _254 = radius;
    }
    float r = _254;
    return fast::max(0.0, log2(fast::max(r, 9.9999999747524270787835121154785e-07)));
}

static inline __attribute__((always_inline))
float4 sampleBackdrop(thread const float2& uv, thread const float& radius, texture2d<float> uBackdrop, sampler uBackdropSmplr)
{
    float param = radius;
    return uBackdrop.sample(uBackdropSmplr, uv, level(blurLOD(param)));
}

static inline __attribute__((always_inline))
float3 gradeUnpremultiplied(thread const float4& c, thread const float4& r0, thread const float4& r1, thread const float4& r2)
{
    float a = fast::max(c.w, 9.9999999747524270787835121154785e-07);
    float3 rgb = c.xyz / float3(a);
    rgb *= step(float3(9.9999999747524270787835121154785e-07), abs(rgb));
    return float3(dot(rgb, r0.xyz) + r0.w, dot(rgb, r1.xyz) + r1.w, dot(rgb, r2.xyz) + r2.w);
}

static inline __attribute__((always_inline))
float shadowFalloff(thread const float& d, thread const float& invRadius)
{
    float u = fast::clamp((0.25 * (d * invRadius)) + 0.5, 0.0, 1.0);
    float x = (4.0 * u) - 2.0;
    float x2 = x * x;
    float p = 0.00295399990864098072052001953125;
    p = (p * x2) - 0.034460000693798065185546875;
    p = (p * x2) + 0.1682099997997283935546875;
    p = (p * x2) - 0.5605499744415283203125;
    return (p * x) + 0.5;
}

static inline __attribute__((always_inline))
float3 blurFill(thread const float3& base, thread const float3& fill, constant GlassParams& _284)
{
    float3 lighten = fast::max(base, fill);
    float3 darken = fast::min(base, fill);
    float wBase = (1.0 - _284.uBlurFillLightenOpacity) - _284.uBlurFillDarkenOpacity;
    float3 mixed = ((lighten * _284.uBlurFillLightenOpacity) + (darken * _284.uBlurFillDarkenOpacity)) + (base * wBase);
    return mix(mixed, fill, float3(fast::clamp(_284.uBlurFillNormalOpacity, 0.0, 1.0)));
}

static inline __attribute__((always_inline))
float keyFillHighlight(thread const float2& normal, thread const float& heightMask, constant GlassParams& _284)
{
    float spread = fast::clamp(_284.uKeyFillSpread, 0.0, 0.999000012874603271484375);
    float invS = 1.0 / fast::max(1.0 - spread, 9.9999999747524270787835121154785e-07);
    float nl = dot(_284.uKeyFillDir, normal);
    float2 lobes = fast::clamp((float2(nl, -nl) - float2(spread)) * invS, float2(0.0), float2(1.0)) * heightMask;
    float2 curved = lobes / fast::max(((float2(1.0) - lobes) * _284.uKeyFillAmount) + float2(1.0), float2(9.9999999747524270787835121154785e-07));
    return curved.x + curved.y;
}

static inline __attribute__((always_inline))
float glassHighlight(thread const float& dist, thread const float2& normal, thread const float& S, constant GlassParams& _284)
{
    float t = fast::clamp(dist / fast::max(_284.uHighlightHeight, 9.9999999747524270787835121154785e-07), 0.0, 1.0);
    float hard = float(t < 1.0);
    float band = mix(hard, 1.0 - t, fast::clamp(_284.uHighlightSoftness, 0.0, 1.0));
    float w = fast::max(fwidth(dist), 9.9999997473787516355514526367188e-05);
    float inner = fast::clamp((dist / w) + 0.5, 0.0, 1.0);
    float outer = fast::clamp(((_284.uHighlightHeight - dist) / w) + 0.5, 0.0, 1.0);
    float mask = (inner * band) * outer;
    float ndotl = dot(_284.uLightDir, normal);
    float spec = fast::clamp((ndotl - _284.uHighlightThreshold) / fast::max(1.0 - _284.uHighlightThreshold, 9.9999997473787516355514526367188e-05), 0.0, 1.0);
    float _462;
    if (dist < (-5.0))
    {
        _462 = 0.0;
    }
    else
    {
        _462 = mask * spec;
    }
    float v = _462;
    return v * _284.uHighlightIntensity;
}

static inline __attribute__((always_inline))
float ringShadow(thread const float& dist, constant GlassParams& _284)
{
    float invR = 1.0 / fast::max(_284.uRingShadowRadius, 9.9999999747524270787835121154785e-07);
    float inner = dist * invR;
    float outer = inner + (_284.uRingShadowStrokeWidth * invR);
    float param = inner * 0.707106769084930419921875;
    float param_1 = 1.0;
    float a = shadowFalloff(param, param_1);
    float param_2 = outer * 0.707106769084930419921875;
    float param_3 = 1.0;
    float b = shadowFalloff(param_2, param_3);
    return fast::clamp(a - b, 0.0, 1.0) * _284.uRingShadowOpacity;
}

static inline __attribute__((always_inline))
float aaStep(thread const float& x)
{
    float w = fast::max(fwidth(x), 9.9999997473787516355514526367188e-05);
    return fast::clamp((x / w) + 0.5, 0.0, 1.0);
}

fragment main0_out main0(main0_in in [[stage_in]], constant GlassParams& _284 [[buffer(0)]], texture2d<float> uBackdrop [[texture(0)]], sampler uBackdropSmplr [[sampler(0)]])
{
    main0_out out = {};
    float d01 = fast::clamp(_284.uDiffusion, 0.0, 1.0);
    if (d01 <= 0.0)
    {
        discard_fragment();
    }
    float param = d01;
    float param_1 = 0.550000011920928955078125;
    float dRefract = diffusionCurve(param, param_1);
    float param_2 = d01;
    float param_3 = 1.2999999523162841796875;
    float dBlur = diffusionCurve(param_2, param_3);
    float param_4 = d01;
    float param_5 = 1.60000002384185791015625;
    float dBody = diffusionCurve(param_4, param_5);
    float param_6 = d01;
    float param_7 = 0.800000011920928955078125;
    float2 animHalf = _284.uHalfSize * mix(0.959999978542327880859375, 1.0, diffusionCurve(param_6, param_7));
    float2 texel = float2(1.0) / float2(int2(uBackdrop.get_width(), uBackdrop.get_height()));
    float _710;
    if (_284.uScaleRef > 0.0)
    {
        _710 = fast::min(_284.uHalfSize.x, _284.uHalfSize.y) / _284.uScaleRef;
    }
    else
    {
        _710 = 1.0;
    }
    float S = _710;
    float2 param_8 = in.vUV;
    float2 param_9 = animHalf;
    float param_10 = _284.uExponent;
    float param_11;
    float2 param_12;
    supercircleSDF(param_8, param_9, param_10, param_11, param_12);
    float dist = param_11;
    float2 normal = param_12;
    int extras = int(fast::clamp(_284.uExtraCount, 0.0, 3.0));
    float4 _766;
    float4 _775;
    float param_16;
    float2 param_17;
    float param_23;
    float2 param_24;
    for (int i = 0; i < 3; i++)
    {
        if (i >= extras)
        {
            break;
        }
        if (i == 0)
        {
            _766 = _284.uShape2;
        }
        else
        {
            if (i == 1)
            {
                _775 = _284.uShape3;
            }
            else
            {
                _775 = _284.uShape4;
            }
            _766 = _775;
        }
        float4 sh = _766;
        float2 param_13 = in.vUV - sh.xy;
        float2 param_14 = sh.zw * mix(0.959999978542327880859375, 1.0, d01);
        float param_15 = _284.uExponent;
        supercircleSDF(param_13, param_14, param_15, param_16, param_17);
        float d2 = param_16;
        float2 n2 = param_17;
        float param_18 = dist;
        float2 param_19 = normal;
        float param_20 = d2;
        float2 param_21 = n2;
        float param_22 = _284.uMergeK;
        smoothUnion(param_18, param_19, param_20, param_21, param_22, param_23, param_24);
        dist = param_23;
        normal = param_24;
    }
    float2 rot = float2(dot(normal, float2(_284.uRefractAngle.x, -_284.uRefractAngle.y)), dot(normal, float2(_284.uRefractAngle.y, _284.uRefractAngle.x)));
    float2 disp = float2(dot(rot, _284.uDisplacementMat.xy), dot(rot, _284.uDisplacementMat.zw));
    float param_25 = dist;
    float param_26 = (_284.uInnerRefractAmount * dRefract) * S;
    float param_27 = _284.uInnerRefractInvHeight / S;
    float param_28 = 0.0;
    float innerMag = refractLobe(param_25, param_26, param_27, param_28);
    float innerDist = innerMag + dist;
    float2 innerUV = in.vBackdropUV + ((disp * innerMag) * texel);
    float param_29 = innerDist;
    float param_30 = dBlur;
    float param_31 = S;
    float faceLod = blurRampRadius(param_29, param_30, param_31, _284);
    float2 param_32 = innerUV;
    float param_33 = faceLod;
    float4 faceCol = sampleBackdrop(param_32, param_33, uBackdrop, uBackdropSmplr);
    bool _906 = _284.uRefractOpacity > 0.0;
    bool _913;
    if (_906)
    {
        _913 = _284.uComplexRefraction > 0.5;
    }
    else
    {
        _913 = _906;
    }
    if (_913)
    {
        float param_34 = dist;
        float param_35 = (_284.uOuterRefractAmount * dRefract) * S;
        float param_36 = _284.uOuterRefractInvHeight / S;
        float param_37 = 0.0;
        float outerMag = refractLobe(param_34, param_35, param_36, param_37);
        float outerDist = outerMag + dist;
        float2 outerUV = in.vBackdropUV + ((disp * outerMag) * texel);
        float param_38 = outerDist;
        float param_39 = dBlur;
        float param_40 = S;
        float2 param_41 = outerUV;
        float param_42 = blurRampRadius(param_38, param_39, param_40, _284);
        float4 outerCol = sampleBackdrop(param_41, param_42, uBackdrop, uBackdropSmplr);
        float span = _284.uRefractThreshold.y - _284.uRefractThreshold.x;
        float t = fast::clamp((dist - _284.uRefractThreshold.x) / ((abs(span) < 9.9999999747524270787835121154785e-07) ? 9.9999999747524270787835121154785e-07 : span), 0.0, 1.0);
        faceCol = mix(faceCol, outerCol, float4(t * _284.uRefractOpacity));
    }
    float aberrAlpha = 1.0;
    if (_284.uAberrationAmount > 0.0)
    {
        float2 rotA = float2(dot(normal, float2(_284.uAberrationAngle.x, -_284.uAberrationAngle.y)), dot(normal, float2(_284.uAberrationAngle.y, _284.uAberrationAngle.x)));
        float2 dispA = float2(dot(rotA, _284.uDisplacementMat.zw), dot(rotA, _284.uDisplacementMat.xy));
        float param_43 = dist;
        float param_44 = _284.uAberrationAmount;
        float param_45 = _284.uAberrationInvHeight;
        float param_46 = _284.uAberrationOffset;
        float2 offA = dispA * refractLobe(param_43, param_44, param_45, param_46);
        float3 acc = float3(0.0);
        float aSum = 0.0;
        float w = 1.0;
        for (int i_1 = 0; i_1 < 3; i_1++)
        {
            float2 param_47 = innerUV + ((offA * w) * texel);
            float param_48 = faceLod;
            float4 s = sampleBackdrop(param_47, param_48, uBackdrop, uBackdropSmplr);
            float a = fast::max(s.w, 9.9999999747524270787835121154785e-07);
            acc.x += ((s.x / a) * w);
            acc.y += ((s.y / a) * (1.0 - w));
            aSum += s.w;
            w -= 0.3333333432674407958984375;
        }
        float sstep = 0.0;
        for (int i_2 = 0; i_2 < 4; i_2++)
        {
            float2 param_49 = innerUV - ((offA * sstep) * texel);
            float param_50 = faceLod;
            float4 s_1 = sampleBackdrop(param_49, param_50, uBackdrop, uBackdropSmplr);
            float a_1 = fast::max(s_1.w, 9.9999999747524270787835121154785e-07);
            acc.y += ((s_1.y / a_1) * (1.0 - sstep));
            acc.z += ((s_1.z / a_1) * sstep);
            aSum += s_1.w;
            sstep += 0.3333333432674407958984375;
        }
        acc *= float3(0.5, 0.3333333432674407958984375, 0.5);
        aberrAlpha = aSum * 0.14285714924335479736328125;
        faceCol = float4(acc, aberrAlpha);
    }
    float4 param_51 = faceCol;
    float4 param_52 = _284.uFaceCM0;
    float4 param_53 = _284.uFaceCM1;
    float4 param_54 = _284.uFaceCM2;
    float3 face = gradeUnpremultiplied(param_51, param_52, param_53, param_54) * (_284.uFaceOpacity * dBody);
    float3 bleed = float3(0.0);
    float bleedMask = 0.0;
    if (_284.uEdgeBleedAmount > 0.0)
    {
        float bt = fast::clamp((-dist) * (_284.uEdgeBleedInvHeight / S), 0.0, 1.0);
        float param_55 = bt;
        float _1209 = lensCurve(param_55);
        float bmag = (_284.uEdgeBleedAmount - (_1209 * _284.uEdgeBleedAmount)) * S;
        float2 param_56 = in.vBackdropUV + ((disp * bmag) * texel);
        float param_57 = _284.uEdgeBleedBlurRadius * S;
        float4 bcol = sampleBackdrop(param_56, param_57, uBackdrop, uBackdropSmplr);
        float4 param_58 = bcol;
        float4 param_59 = _284.uBleedCM0;
        float4 param_60 = _284.uBleedCM1;
        float4 param_61 = _284.uBleedCM2;
        bleed = gradeUnpremultiplied(param_58, param_59, param_60, param_61);
        bleed = (bleed * _284.uBleedDarken.x) + float3(_284.uBleedDarken.y);
        float band = 1.0 - smoothstep(_284.uEdgeBleedDist.x * S, _284.uEdgeBleedDist.y * S, -dist);
        bleedMask = band * _284.uEdgeBleedOpacity;
    }
    float3 shadow = float3(0.0);
    float shadowMask = 0.0;
    if (_284.uShadowContribution > 9.9999999747524270787835121154785e-07)
    {
        float param_62 = dist;
        float param_63 = _284.uShadowAmount;
        float param_64 = _284.uShadowInvHeight;
        float param_65 = _284.uShadowDistOffset;
        float smag = refractLobe(param_62, param_63, param_64, param_65);
        float2 suv = in.vBackdropUV + (((disp * smag) + _284.uShadowOffset) * texel);
        float2 param_66 = suv;
        float param_67 = _284.uShadowAmount;
        float4 scol = sampleBackdrop(param_66, param_67, uBackdrop, uBackdropSmplr);
        float4 param_68 = scol;
        float4 param_69 = _284.uShadowCM0;
        float4 param_70 = _284.uShadowCM1;
        float4 param_71 = _284.uShadowCM2;
        shadow = gradeUnpremultiplied(param_68, param_69, param_70, param_71) * _284.uShadowContribution;
        float param_72 = dist;
        float param_73 = _284.uShadowInvRadius / S;
        shadowMask = (shadowFalloff(param_72, param_73) * _284.uShadowOpacity) * step(0.0, dist);
    }
    float3 rgb = mix(face, bleed, float3(bleedMask));
    rgb = mix(rgb, shadow, float3(shadowMask));
    if (_284.uClampLimit > 0.0)
    {
        float peak = fast::max(fast::max(rgb.x, rgb.y), rgb.z) / fast::max(_284.uSDRWhite * _284.uEDRScale, 9.9999999747524270787835121154785e-07);
        if (peak > _284.uClampLimit)
        {
            float k = _284.uClampLimit / peak;
            rgb = mix(fast::min(rgb, float3(_284.uClampLimit)), rgb * k, float3(_284.uPreserveHue));
        }
    }
    bool _1413 = _284.uBlurFillNormalOpacity > 0.0;
    bool _1420;
    if (!_1413)
    {
        _1420 = _284.uBlurFillLightenOpacity > 0.0;
    }
    else
    {
        _1420 = _1413;
    }
    bool _1427;
    if (!_1420)
    {
        _1427 = _284.uBlurFillDarkenOpacity > 0.0;
    }
    else
    {
        _1427 = _1420;
    }
    if (_1427)
    {
        float2 param_74 = in.vBackdropUV;
        float param_75 = _284.uBlurFillBlurRadius;
        float4 fillSample = sampleBackdrop(param_74, param_75, uBackdrop, uBackdropSmplr);
        float4 param_76 = fillSample;
        float4 param_77 = _284.uFaceCM0;
        float4 param_78 = _284.uFaceCM1;
        float4 param_79 = _284.uFaceCM2;
        float3 fill = gradeUnpremultiplied(param_76, param_77, param_78, param_79);
        float3 param_80 = rgb;
        float3 param_81 = fill;
        rgb = blurFill(param_80, param_81, _284);
    }
    if (_284.uKeyFillAmount > 0.0)
    {
        float hMask = fast::clamp(((-dist) - _284.uKeyFillEffectOffset) / fast::max(_284.uKeyFillHeight, 9.9999999747524270787835121154785e-07), 0.0, 1.0);
        float2 param_82 = normal;
        float param_83 = hMask;
        float key = keyFillHighlight(param_82, param_83, _284);
        rgb += (float3(key) * mix(1.0, 0.5, fast::clamp(_284.uKeyFillColorBias, 0.0, 1.0)));
    }
    if (_284.uHighlightIntensity > 0.0)
    {
        float param_84 = -dist;
        float2 param_85 = normal;
        float param_86 = S;
        rgb += float3(glassHighlight(param_84, param_85, param_86, _284));
    }
    if (_284.uRingShadowOpacity > 0.0)
    {
        float param_87 = (-dist) - _284.uRingShadowOffset.x;
        float ring = ringShadow(param_87, _284) * fast::clamp(_284.uRingShadowMask, 0.0, 1.0);
        rgb *= (1.0 - ring);
    }
    float edgeSpan = _284.uEdgeRange.y - _284.uEdgeRange.x;
    float edgeT = fast::clamp((dist - _284.uEdgeRange.x) / ((abs(edgeSpan) < 9.9999999747524270787835121154785e-07) ? 9.9999999747524270787835121154785e-07 : edgeSpan), 0.0, 1.0);
    float edgeFade = 1.0 - mix(_284.uEdgeOpacity.x, _284.uEdgeOpacity.y, edgeT);
    float param_88 = -dist;
    float coverage = (aaStep(param_88) * edgeFade) * dBody;
    if (coverage < 9.9999999747524270787835121154785e-07)
    {
        discard_fragment();
    }
    if (_284.uRimGlintGain > 0.0)
    {
        float glint = (exp((-abs(dist)) / fast::max(_284.uRimGlintTau * S, 9.9999997473787516355514526367188e-05)) * step(dist, 2.0)) * dBody;
        rgb += float3((glint * _284.uRimGlintGain) / fast::max(coverage, 0.25));
    }
    out.fragColor = float4(rgb, coverage);
    return out;
}

