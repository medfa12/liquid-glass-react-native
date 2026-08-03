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
    float _241 = lensCurve(param);
    return amount - (_241 * amount);
}

static inline __attribute__((always_inline))
float blurRampRadius(thread const float& dist, thread const float& blurScale, constant GlassParams& _281)
{
    float3 lo = _281.uBlurDist.yzw;
    float3 hi = float3(_281.uBlurDist.x, _281.uBlurDist.y, _281.uBlurDist.z);
    float3 span = hi - lo;
    float3 degen = step(abs(span), float3(9.9999999747524270787835121154785e-07));
    float3 inv = float3(1.0) / mix(span, float3(9.9999999747524270787835121154785e-07), degen);
    float3 t = fast::clamp((float3(dist) - lo) * inv, float3(0.0), float3(1.0));
    float3 w = _281.uBlurAlpha.yzw * t;
    return ((_281.uBlurAlpha.x - ((w.x + w.y) + w.z)) * _281.uBlurRadius) * blurScale;
}

static inline __attribute__((always_inline))
float blurLOD(thread const float& radius)
{
    float _251;
    if (radius < 2.0)
    {
        _251 = (radius * 0.5) + 1.0;
    }
    else
    {
        _251 = radius;
    }
    float r = _251;
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
float3 blurFill(thread const float3& base, thread const float3& fill, constant GlassParams& _281)
{
    float3 lighten = fast::max(base, fill);
    float3 darken = fast::min(base, fill);
    float wBase = (1.0 - _281.uBlurFillLightenOpacity) - _281.uBlurFillDarkenOpacity;
    float3 mixed = ((lighten * _281.uBlurFillLightenOpacity) + (darken * _281.uBlurFillDarkenOpacity)) + (base * wBase);
    return mix(mixed, fill, float3(fast::clamp(_281.uBlurFillNormalOpacity, 0.0, 1.0)));
}

static inline __attribute__((always_inline))
float keyFillHighlight(thread const float2& normal, thread const float& heightMask, constant GlassParams& _281)
{
    float spread = fast::clamp(_281.uKeyFillSpread, 0.0, 0.999000012874603271484375);
    float invS = 1.0 / fast::max(1.0 - spread, 9.9999999747524270787835121154785e-07);
    float nl = dot(_281.uKeyFillDir, normal);
    float2 lobes = fast::clamp((float2(nl, -nl) - float2(spread)) * invS, float2(0.0), float2(1.0)) * heightMask;
    float2 curved = lobes / fast::max(((float2(1.0) - lobes) * _281.uKeyFillAmount) + float2(1.0), float2(9.9999999747524270787835121154785e-07));
    return curved.x + curved.y;
}

static inline __attribute__((always_inline))
float glassHighlight(thread const float& dist, thread const float2& normal, constant GlassParams& _281)
{
    float t = fast::clamp(dist / fast::max(_281.uHighlightHeight, 9.9999999747524270787835121154785e-07), 0.0, 1.0);
    float hard = float(t < 1.0);
    float band = mix(hard, 1.0 - t, fast::clamp(_281.uHighlightSoftness, 0.0, 1.0));
    float w = fast::max(fwidth(dist), 9.9999997473787516355514526367188e-05);
    float inner = fast::clamp((dist / w) + 0.5, 0.0, 1.0);
    float outer = fast::clamp(((_281.uHighlightHeight - dist) / w) + 0.5, 0.0, 1.0);
    float mask = (inner * band) * outer;
    float ndotl = dot(_281.uLightDir, normal);
    float spec = fast::clamp((ndotl - _281.uHighlightThreshold) / fast::max(1.0 - _281.uHighlightThreshold, 9.9999997473787516355514526367188e-05), 0.0, 1.0);
    float _457;
    if (dist < (-5.0))
    {
        _457 = 0.0;
    }
    else
    {
        _457 = mask * spec;
    }
    float v = _457;
    return v * _281.uHighlightIntensity;
}

static inline __attribute__((always_inline))
float ringShadow(thread const float& dist, constant GlassParams& _281)
{
    float invR = 1.0 / fast::max(_281.uRingShadowRadius, 9.9999999747524270787835121154785e-07);
    float inner = dist * invR;
    float outer = inner + (_281.uRingShadowStrokeWidth * invR);
    float param = inner * 0.707106769084930419921875;
    float param_1 = 1.0;
    float a = shadowFalloff(param, param_1);
    float param_2 = outer * 0.707106769084930419921875;
    float param_3 = 1.0;
    float b = shadowFalloff(param_2, param_3);
    return fast::clamp(a - b, 0.0, 1.0) * _281.uRingShadowOpacity;
}

static inline __attribute__((always_inline))
float aaStep(thread const float& x)
{
    float w = fast::max(fwidth(x), 9.9999997473787516355514526367188e-05);
    return fast::clamp((x / w) + 0.5, 0.0, 1.0);
}

fragment main0_out main0(main0_in in [[stage_in]], constant GlassParams& _281 [[buffer(0)]], texture2d<float> uBackdrop [[texture(0)]], sampler uBackdropSmplr [[sampler(0)]])
{
    main0_out out = {};
    float d01 = fast::clamp(_281.uDiffusion, 0.0, 1.0);
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
    float2 animHalf = _281.uHalfSize * mix(0.959999978542327880859375, 1.0, diffusionCurve(param_6, param_7));
    float2 texel = float2(1.0) / float2(int2(uBackdrop.get_width(), uBackdrop.get_height()));
    float2 param_8 = in.vUV;
    float2 param_9 = animHalf;
    float param_10 = _281.uExponent;
    float param_11;
    float2 param_12;
    supercircleSDF(param_8, param_9, param_10, param_11, param_12);
    float dist = param_11;
    float2 normal = param_12;
    int extras = int(fast::clamp(_281.uExtraCount, 0.0, 3.0));
    float4 _743;
    float4 _752;
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
            _743 = _281.uShape2;
        }
        else
        {
            if (i == 1)
            {
                _752 = _281.uShape3;
            }
            else
            {
                _752 = _281.uShape4;
            }
            _743 = _752;
        }
        float4 sh = _743;
        float2 param_13 = in.vUV - sh.xy;
        float2 param_14 = sh.zw * mix(0.959999978542327880859375, 1.0, d01);
        float param_15 = _281.uExponent;
        supercircleSDF(param_13, param_14, param_15, param_16, param_17);
        float d2 = param_16;
        float2 n2 = param_17;
        float param_18 = dist;
        float2 param_19 = normal;
        float param_20 = d2;
        float2 param_21 = n2;
        float param_22 = _281.uMergeK;
        smoothUnion(param_18, param_19, param_20, param_21, param_22, param_23, param_24);
        dist = param_23;
        normal = param_24;
    }
    float2 rot = float2(dot(normal, float2(_281.uRefractAngle.x, -_281.uRefractAngle.y)), dot(normal, float2(_281.uRefractAngle.y, _281.uRefractAngle.x)));
    float2 disp = float2(dot(rot, _281.uDisplacementMat.xy), dot(rot, _281.uDisplacementMat.zw));
    float param_25 = dist;
    float param_26 = _281.uInnerRefractAmount * dRefract;
    float param_27 = _281.uInnerRefractInvHeight;
    float param_28 = 0.0;
    float innerMag = refractLobe(param_25, param_26, param_27, param_28);
    float innerDist = innerMag + dist;
    float2 innerUV = in.vBackdropUV + ((disp * innerMag) * texel);
    float param_29 = innerDist;
    float param_30 = dBlur;
    float faceLod = blurRampRadius(param_29, param_30, _281);
    float2 param_31 = innerUV;
    float param_32 = faceLod;
    float4 faceCol = sampleBackdrop(param_31, param_32, uBackdrop, uBackdropSmplr);
    bool _877 = _281.uRefractOpacity > 0.0;
    bool _884;
    if (_877)
    {
        _884 = _281.uComplexRefraction > 0.5;
    }
    else
    {
        _884 = _877;
    }
    if (_884)
    {
        float param_33 = dist;
        float param_34 = _281.uOuterRefractAmount * dRefract;
        float param_35 = _281.uOuterRefractInvHeight;
        float param_36 = 0.0;
        float outerMag = refractLobe(param_33, param_34, param_35, param_36);
        float outerDist = outerMag + dist;
        float2 outerUV = in.vBackdropUV + ((disp * outerMag) * texel);
        float param_37 = outerDist;
        float param_38 = dBlur;
        float2 param_39 = outerUV;
        float param_40 = blurRampRadius(param_37, param_38, _281);
        float4 outerCol = sampleBackdrop(param_39, param_40, uBackdrop, uBackdropSmplr);
        float span = _281.uRefractThreshold.y - _281.uRefractThreshold.x;
        float t = fast::clamp((dist - _281.uRefractThreshold.x) / ((abs(span) < 9.9999999747524270787835121154785e-07) ? 9.9999999747524270787835121154785e-07 : span), 0.0, 1.0);
        faceCol = mix(faceCol, outerCol, float4(t * _281.uRefractOpacity));
    }
    float aberrAlpha = 1.0;
    if (_281.uAberrationAmount > 0.0)
    {
        float2 rotA = float2(dot(normal, float2(_281.uAberrationAngle.x, -_281.uAberrationAngle.y)), dot(normal, float2(_281.uAberrationAngle.y, _281.uAberrationAngle.x)));
        float2 dispA = float2(dot(rotA, _281.uDisplacementMat.zw), dot(rotA, _281.uDisplacementMat.xy));
        float param_41 = dist;
        float param_42 = _281.uAberrationAmount;
        float param_43 = _281.uAberrationInvHeight;
        float param_44 = _281.uAberrationOffset;
        float2 offA = dispA * refractLobe(param_41, param_42, param_43, param_44);
        float3 acc = float3(0.0);
        float aSum = 0.0;
        float w = 1.0;
        for (int i_1 = 0; i_1 < 3; i_1++)
        {
            float2 param_45 = innerUV + ((offA * w) * texel);
            float param_46 = faceLod;
            float4 s = sampleBackdrop(param_45, param_46, uBackdrop, uBackdropSmplr);
            float a = fast::max(s.w, 9.9999999747524270787835121154785e-07);
            acc.x += ((s.x / a) * w);
            acc.y += ((s.y / a) * (1.0 - w));
            aSum += s.w;
            w -= 0.3333333432674407958984375;
        }
        float sstep = 0.0;
        for (int i_2 = 0; i_2 < 4; i_2++)
        {
            float2 param_47 = innerUV - ((offA * sstep) * texel);
            float param_48 = faceLod;
            float4 s_1 = sampleBackdrop(param_47, param_48, uBackdrop, uBackdropSmplr);
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
    float4 param_49 = faceCol;
    float4 param_50 = _281.uFaceCM0;
    float4 param_51 = _281.uFaceCM1;
    float4 param_52 = _281.uFaceCM2;
    float3 face = gradeUnpremultiplied(param_49, param_50, param_51, param_52) * (_281.uFaceOpacity * dBody);
    float3 bleed = float3(0.0);
    float bleedMask = 0.0;
    if (_281.uEdgeBleedAmount > 0.0)
    {
        float bt = fast::clamp((-dist) * _281.uEdgeBleedInvHeight, 0.0, 1.0);
        float param_53 = bt;
        float _1172 = lensCurve(param_53);
        float bmag = _281.uEdgeBleedAmount - (_1172 * _281.uEdgeBleedAmount);
        float2 param_54 = in.vBackdropUV + ((disp * bmag) * texel);
        float param_55 = _281.uEdgeBleedBlurRadius;
        float4 bcol = sampleBackdrop(param_54, param_55, uBackdrop, uBackdropSmplr);
        float4 param_56 = bcol;
        float4 param_57 = _281.uBleedCM0;
        float4 param_58 = _281.uBleedCM1;
        float4 param_59 = _281.uBleedCM2;
        bleed = gradeUnpremultiplied(param_56, param_57, param_58, param_59);
        bleed = (bleed * _281.uBleedDarken.x) + float3(_281.uBleedDarken.y);
        float band = 1.0 - smoothstep(_281.uEdgeBleedDist.x, _281.uEdgeBleedDist.y, -dist);
        bleedMask = band * _281.uEdgeBleedOpacity;
    }
    float3 shadow = float3(0.0);
    float shadowMask = 0.0;
    if (_281.uShadowContribution > 9.9999999747524270787835121154785e-07)
    {
        float param_60 = dist;
        float param_61 = _281.uShadowAmount;
        float param_62 = _281.uShadowInvHeight;
        float param_63 = _281.uShadowDistOffset;
        float smag = refractLobe(param_60, param_61, param_62, param_63);
        float2 suv = in.vBackdropUV + (((disp * smag) + _281.uShadowOffset) * texel);
        float2 param_64 = suv;
        float param_65 = _281.uShadowAmount;
        float4 scol = sampleBackdrop(param_64, param_65, uBackdrop, uBackdropSmplr);
        float4 param_66 = scol;
        float4 param_67 = _281.uShadowCM0;
        float4 param_68 = _281.uShadowCM1;
        float4 param_69 = _281.uShadowCM2;
        shadow = gradeUnpremultiplied(param_66, param_67, param_68, param_69) * _281.uShadowContribution;
        float param_70 = dist;
        float param_71 = _281.uShadowInvRadius;
        shadowMask = (shadowFalloff(param_70, param_71) * _281.uShadowOpacity) * step(0.0, dist);
    }
    float3 rgb = mix(face, bleed, float3(bleedMask));
    rgb = mix(rgb, shadow, float3(shadowMask));
    if (_281.uClampLimit > 0.0)
    {
        float peak = fast::max(fast::max(rgb.x, rgb.y), rgb.z) / fast::max(_281.uSDRWhite * _281.uEDRScale, 9.9999999747524270787835121154785e-07);
        if (peak > _281.uClampLimit)
        {
            float k = _281.uClampLimit / peak;
            rgb = mix(fast::min(rgb, float3(_281.uClampLimit)), rgb * k, float3(_281.uPreserveHue));
        }
    }
    bool _1366 = _281.uBlurFillNormalOpacity > 0.0;
    bool _1373;
    if (!_1366)
    {
        _1373 = _281.uBlurFillLightenOpacity > 0.0;
    }
    else
    {
        _1373 = _1366;
    }
    bool _1380;
    if (!_1373)
    {
        _1380 = _281.uBlurFillDarkenOpacity > 0.0;
    }
    else
    {
        _1380 = _1373;
    }
    if (_1380)
    {
        float2 param_72 = in.vBackdropUV;
        float param_73 = _281.uBlurFillBlurRadius;
        float4 fillSample = sampleBackdrop(param_72, param_73, uBackdrop, uBackdropSmplr);
        float4 param_74 = fillSample;
        float4 param_75 = _281.uFaceCM0;
        float4 param_76 = _281.uFaceCM1;
        float4 param_77 = _281.uFaceCM2;
        float3 fill = gradeUnpremultiplied(param_74, param_75, param_76, param_77);
        float3 param_78 = rgb;
        float3 param_79 = fill;
        rgb = blurFill(param_78, param_79, _281);
    }
    if (_281.uKeyFillAmount > 0.0)
    {
        float hMask = fast::clamp(((-dist) - _281.uKeyFillEffectOffset) / fast::max(_281.uKeyFillHeight, 9.9999999747524270787835121154785e-07), 0.0, 1.0);
        float2 param_80 = normal;
        float param_81 = hMask;
        float key = keyFillHighlight(param_80, param_81, _281);
        rgb += (float3(key) * mix(1.0, 0.5, fast::clamp(_281.uKeyFillColorBias, 0.0, 1.0)));
    }
    if (_281.uHighlightIntensity > 0.0)
    {
        float param_82 = -dist;
        float2 param_83 = normal;
        rgb += float3(glassHighlight(param_82, param_83, _281));
    }
    if (_281.uRingShadowOpacity > 0.0)
    {
        float param_84 = (-dist) - _281.uRingShadowOffset.x;
        float ring = ringShadow(param_84, _281) * fast::clamp(_281.uRingShadowMask, 0.0, 1.0);
        rgb *= (1.0 - ring);
    }
    float edgeSpan = _281.uEdgeRange.y - _281.uEdgeRange.x;
    float edgeT = fast::clamp((dist - _281.uEdgeRange.x) / ((abs(edgeSpan) < 9.9999999747524270787835121154785e-07) ? 9.9999999747524270787835121154785e-07 : edgeSpan), 0.0, 1.0);
    float edgeFade = 1.0 - mix(_281.uEdgeOpacity.x, _281.uEdgeOpacity.y, edgeT);
    float param_85 = -dist;
    float coverage = (aaStep(param_85) * edgeFade) * dBody;
    if (coverage < 9.9999999747524270787835121154785e-07)
    {
        discard_fragment();
    }
    if (_281.uRimGlintGain > 0.0)
    {
        float glint = (exp((-abs(dist)) / fast::max(_281.uRimGlintTau, 9.9999997473787516355514526367188e-05)) * step(dist, 2.0)) * dBody;
        rgb += float3((glint * _281.uRimGlintGain) / fast::max(coverage, 0.25));
    }
    out.fragColor = float4(rgb, coverage);
    return out;
}

