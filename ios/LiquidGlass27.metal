#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct GlassParams27
{
    float4 displacement_mat;
    float inner_refraction_amount;
    float inner_refraction_inv_height;
    float outer_refraction_amount;
    float outer_refraction_inv_height;
    float refraction_threshold0;
    float refraction_threshold1;
    float blur_radius;
    float edge_bleed_blur_radius;
    float edge_bleed_amount;
    float edge_bleed_inv_height;
    float shadow_amount;
    float shadow_inv_height;
    float2 shadow_offset;
    float shadow_blur_radius;
    float shadow_inv_radius;
    float4 face_cm0;
    float4 face_cm1;
    float4 face_cm2;
    float4 bleed_cm0;
    float4 bleed_cm1;
    float4 bleed_cm2;
    float4 shadow_cm0;
    float4 shadow_cm1;
    float4 shadow_cm2;
    float shadow_contribution;
    float shadow_face_opacity;
    float blur_alpha0;
    float blur_alpha1;
    float blur_alpha2;
    float blur_alpha3;
    float blur_dist0;
    float blur_dist1;
    float blur_dist2;
    float blur_dist3;
    float edge_bleed_dist0;
    float edge_bleed_dist1;
    float edge_bleed_opacity;
    float face_opacity;
    float2 bleed_darken;
    float shadow_dist_offset;
    float shadow_opacity;
    float refraction_opacity;
    float holding_tone_opacity;
    float sdr_shadow_dist0;
    float sdr_shadow_inv;
    float2 ring_shadow_offset;
    float ring_shadow_stroke_width;
    float ring_shadow_radius;
    float ring_shadow_opacity;
    float ring_shadow_mask;
    float2 key_fill_highlight_dir;
    float key_fill_highlight_height;
    float key_fill_highlight_spread;
    float key_fill_highlight_amount;
    float key_fill_highlight_effect_offset;
    float key_fill_highlight_color_bias;
    float blur_fill_blur_radius;
    float blur_fill_lighten_opacity;
    float blur_fill_darken_opacity;
    float blur_fill_normal_opacity;
    float aberration_amount;
    float2 aberration_dir;
    float2 half_size;
    float exponent;
    float scale_ref;
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
void supercircleSDF(thread const float2& p, thread const float2& halfSize, thread const float& n, thread float& dist, thread float2& nrm)
{
    float2 q = p / halfSize;
    float2 a = fast::max(abs(q), float2(9.9999999747524270787835121154785e-07));
    float s = powr(a.x, n) + powr(a.y, n);
    float f = powr(s, 1.0 / n) - 1.0;
    float k = powr(s, (1.0 / n) - 1.0);
    float2 g = ((sign(q) * k) * float2(powr(a.x, n - 1.0), powr(a.y, n - 1.0))) / halfSize;
    float gl = fast::max(length(g), 9.9999999747524270787835121154785e-07);
    float inr = fast::min(halfSize.x, halfSize.y);
    dist = fast::clamp(f / gl, -inr, inr * 4.0);
    nrm = g / float2(gl);
}

static inline __attribute__((always_inline))
float lensCurve(thread float& t)
{
    t = fast::clamp(t, 0.0, 1.0);
    return fast::clamp(sqrt(fast::max((2.0 - t) * t, 0.0)), 0.0, 1.0);
}

static inline __attribute__((always_inline))
float refractLobe(thread const float& d, thread const float& amount, thread const float& invH, thread const float& offset)
{
    float param = fast::clamp(((-d) - offset) * invH, 0.0, 1.0);
    float _156 = lensCurve(param);
    return amount - (_156 * amount);
}

static inline __attribute__((always_inline))
float blurLOD(thread float& r)
{
    float _165;
    if (r < 2.0)
    {
        _165 = (r * 0.5) + 1.0;
    }
    else
    {
        _165 = r;
    }
    r = _165;
    return fast::max(0.0, log2(fast::max(r, 9.9999999747524270787835121154785e-07)));
}

static inline __attribute__((always_inline))
float4 tap(thread const float2& uv, thread const float& radius, texture2d<float> uBackdrop, sampler uBackdropSmplr)
{
    float param = radius;
    float _189 = blurLOD(param);
    return uBackdrop.sample(uBackdropSmplr, uv, level(_189));
}

static inline __attribute__((always_inline))
float3 grade(thread const float4& c, thread const float4& r0, thread const float4& r1, thread const float4& r2)
{
    float a = fast::max(c.w, 9.9999999747524270787835121154785e-07);
    float3 rgb = c.xyz / float3(a);
    rgb *= step(float3(9.9999999747524270787835121154785e-07), abs(rgb));
    return float3(dot(rgb, r0.xyz) + r0.w, dot(rgb, r1.xyz) + r1.w, dot(rgb, r2.xyz) + r2.w);
}

static inline __attribute__((always_inline))
float erfcHalf(thread const float& d, thread const float& invR)
{
    float u = fast::clamp((0.25 * (d * invR)) + 0.5, 0.0, 1.0);
    float x = (4.0 * u) - 2.0;
    float x2 = x * x;
    float p = 0.00295399990864098072052001953125;
    p = (p * x2) - 0.034460000693798065185546875;
    p = (p * x2) + 0.1682099997997283935546875;
    p = (p * x2) - 0.5605499744415283203125;
    return (p * x) + 0.5;
}

static inline __attribute__((always_inline))
float blurRamp(thread const float& d, thread const float& S, constant GlassParams27& _197)
{
    float3 lo = float3(_197.blur_dist1, _197.blur_dist2, _197.blur_dist3);
    float3 hi = float3(_197.blur_dist0, _197.blur_dist1, _197.blur_dist2);
    float3 sp = hi - lo;
    float3 inv = float3(1.0) / mix(sp, float3(9.9999999747524270787835121154785e-07), step(abs(sp), float3(9.9999999747524270787835121154785e-07)));
    float3 t = fast::clamp((float3(d) - lo) * inv, float3(0.0), float3(1.0));
    float3 w = float3(_197.blur_alpha1, _197.blur_alpha2, _197.blur_alpha3) * t;
    return ((_197.blur_alpha0 - ((w.x + w.y) + w.z)) * _197.blur_radius) * S;
}

fragment main0_out main0(main0_in in [[stage_in]], constant GlassParams27& _197 [[buffer(0)]], texture2d<float> uBackdrop [[texture(0)]], sampler uBackdropSmplr [[sampler(0)]])
{
    main0_out out = {};
    float _360;
    if (_197.scale_ref > 0.0)
    {
        _360 = fast::min(_197.half_size.x, _197.half_size.y) / _197.scale_ref;
    }
    else
    {
        _360 = 1.0;
    }
    float S = _360;
    float2 texel = float2(1.0) / float2(int2(uBackdrop.get_width(), uBackdrop.get_height()));
    float2 param = in.vUV;
    float2 param_1 = _197.half_size;
    float param_2 = _197.exponent;
    float param_3;
    float2 param_4;
    supercircleSDF(param, param_1, param_2, param_3, param_4);
    float dist = param_3;
    float2 nrm = param_4;
    float2 rot = float2(dot(nrm, float2(1.0, 0.0)), dot(nrm, float2(0.0, 1.0)));
    float2 disp = float2(dot(rot, _197.displacement_mat.xy), dot(rot, _197.displacement_mat.zw));
    float3 outRGB = float3(0.0);
    float cover = 0.0;
    float param_5 = dist;
    float param_6 = _197.shadow_amount * S;
    float param_7 = _197.shadow_inv_height / S;
    float param_8 = _197.shadow_dist_offset;
    float smag = refractLobe(param_5, param_6, param_7, param_8);
    float2 param_9 = in.vBackdropUV + (((disp * smag) + _197.shadow_offset) * texel);
    float param_10 = _197.shadow_blur_radius * S;
    float4 scol = tap(param_9, param_10, uBackdrop, uBackdropSmplr);
    float4 param_11 = scol;
    float4 param_12 = _197.shadow_cm0;
    float4 param_13 = _197.shadow_cm1;
    float4 param_14 = _197.shadow_cm2;
    float3 sh = grade(param_11, param_12, param_13, param_14) * _197.shadow_contribution;
    float param_15 = dist;
    float param_16 = _197.shadow_inv_radius / S;
    float smask = (erfcHalf(param_15, param_16) * _197.shadow_opacity) * step(0.0, dist);
    outRGB = mix(outRGB, sh, float3(smask));
    cover = fast::max(cover, smask * _197.shadow_face_opacity);
    if (_197.ring_shadow_opacity > 0.0)
    {
        float invR = 1.0 / fast::max(_197.ring_shadow_radius * S, 9.9999999747524270787835121154785e-07);
        float d = (-dist) - _197.ring_shadow_offset.x;
        float inner = d * invR;
        float outer = inner + ((_197.ring_shadow_stroke_width * S) * invR);
        float param_17 = inner * 0.707106769084930419921875;
        float param_18 = 1.0;
        float param_19 = outer * 0.707106769084930419921875;
        float param_20 = 1.0;
        float ring = (fast::clamp(erfcHalf(param_17, param_18) - erfcHalf(param_19, param_20), 0.0, 1.0) * _197.ring_shadow_opacity) * fast::clamp(_197.ring_shadow_mask, 0.0, 1.0);
        outRGB *= (1.0 - ring);
    }
    float param_21 = dist;
    float param_22 = S;
    float faceLod = blurRamp(param_21, param_22, _197);
    float2 faceUV = in.vBackdropUV;
    float param_23 = dist;
    float param_24 = _197.inner_refraction_amount * S;
    float param_25 = _197.inner_refraction_inv_height / S;
    float param_26 = 0.0;
    float innerMag = refractLobe(param_23, param_24, param_25, param_26);
    faceUV = in.vBackdropUV + ((disp * innerMag) * texel);
    float param_27 = innerMag + dist;
    float param_28 = S;
    faceLod = blurRamp(param_27, param_28, _197);
    float2 param_29 = faceUV;
    float param_30 = faceLod;
    float4 faceCol = tap(param_29, param_30, uBackdrop, uBackdropSmplr);
    if (_197.aberration_amount > 0.0)
    {
        float2 rotA = float2(dot(nrm, float2(_197.aberration_dir.x, -_197.aberration_dir.y)), dot(nrm, float2(_197.aberration_dir.y, _197.aberration_dir.x)));
        float2 dispA = float2(dot(rotA, _197.displacement_mat.zw), dot(rotA, _197.displacement_mat.xy));
        float param_31 = dist;
        float param_32 = _197.aberration_amount * S;
        float param_33 = _197.inner_refraction_inv_height / S;
        float param_34 = 0.0;
        float2 offA = dispA * refractLobe(param_31, param_32, param_33, param_34);
        float3 acc = float3(0.0);
        float aSum = 0.0;
        float w = 1.0;
        for (int i = 0; i < 3; i++)
        {
            float2 param_35 = faceUV + ((offA * w) * texel);
            float param_36 = faceLod;
            float4 s = tap(param_35, param_36, uBackdrop, uBackdropSmplr);
            float a = fast::max(s.w, 9.9999999747524270787835121154785e-07);
            acc.x += ((s.x / a) * w);
            acc.y += ((s.y / a) * (1.0 - w));
            aSum += s.w;
            w -= 0.3333333432674407958984375;
        }
        float st = 0.0;
        for (int i_1 = 0; i_1 < 4; i_1++)
        {
            float2 param_37 = faceUV - ((offA * st) * texel);
            float param_38 = faceLod;
            float4 s_1 = tap(param_37, param_38, uBackdrop, uBackdropSmplr);
            float a_1 = fast::max(s_1.w, 9.9999999747524270787835121154785e-07);
            acc.y += ((s_1.y / a_1) * (1.0 - st));
            acc.z += ((s_1.z / a_1) * st);
            aSum += s_1.w;
            st += 0.3333333432674407958984375;
        }
        acc *= float3(0.5, 0.3333333432674407958984375, 0.5);
        faceCol = float4(acc, aSum * 0.14285714924335479736328125);
    }
    bool _803 = _197.blur_fill_normal_opacity > 0.0;
    bool _811;
    if (!_803)
    {
        _811 = _197.blur_fill_lighten_opacity > 0.0;
    }
    else
    {
        _811 = _803;
    }
    bool _819;
    if (!_811)
    {
        _819 = _197.blur_fill_darken_opacity > 0.0;
    }
    else
    {
        _819 = _811;
    }
    if (_819)
    {
        float4 param_39 = faceCol;
        float4 param_40 = _197.face_cm0;
        float4 param_41 = _197.face_cm1;
        float4 param_42 = _197.face_cm2;
        float3 base = grade(param_39, param_40, param_41, param_42);
        float2 param_43 = in.vBackdropUV;
        float param_44 = _197.blur_fill_blur_radius * S;
        float4 param_45 = tap(param_43, param_44, uBackdrop, uBackdropSmplr);
        float4 param_46 = _197.face_cm0;
        float4 param_47 = _197.face_cm1;
        float4 param_48 = _197.face_cm2;
        float3 fill = grade(param_45, param_46, param_47, param_48);
        float wBase = (1.0 - _197.blur_fill_lighten_opacity) - _197.blur_fill_darken_opacity;
        float3 mixed = ((fast::max(base, fill) * _197.blur_fill_lighten_opacity) + (fast::min(base, fill) * _197.blur_fill_darken_opacity)) + (base * wBase);
        float3 _890 = mix(mixed, fill, float3(fast::clamp(_197.blur_fill_normal_opacity, 0.0, 1.0)));
        faceCol.x = _890.x;
        faceCol.y = _890.y;
        faceCol.z = _890.z;
        faceCol.w = 1.0;
    }
    if (_197.refraction_opacity > 0.0)
    {
        float param_49 = dist;
        float param_50 = _197.outer_refraction_amount * S;
        float param_51 = _197.outer_refraction_inv_height / S;
        float param_52 = 0.0;
        float outerMag = refractLobe(param_49, param_50, param_51, param_52);
        float param_53 = outerMag + dist;
        float param_54 = S;
        float2 param_55 = in.vBackdropUV + ((disp * outerMag) * texel);
        float param_56 = blurRamp(param_53, param_54, _197);
        float4 outerCol = tap(param_55, param_56, uBackdrop, uBackdropSmplr);
        float span = _197.refraction_threshold1 - _197.refraction_threshold0;
        float t = fast::clamp((dist - _197.refraction_threshold0) / ((abs(span) < 9.9999999747524270787835121154785e-07) ? 9.9999999747524270787835121154785e-07 : span), 0.0, 1.0);
        faceCol = mix(faceCol, outerCol, float4(t * _197.refraction_opacity));
    }
    float4 param_57 = faceCol;
    float4 param_58 = _197.face_cm0;
    float4 param_59 = _197.face_cm1;
    float4 param_60 = _197.face_cm2;
    float3 face = grade(param_57, param_58, param_59, param_60) * _197.face_opacity;
    if (_197.key_fill_highlight_amount > 0.0)
    {
        float hMask = fast::clamp(((-dist) - (_197.key_fill_highlight_effect_offset * S)) / fast::max(_197.key_fill_highlight_height * S, 9.9999999747524270787835121154785e-07), 0.0, 1.0);
        float sp = fast::clamp(_197.key_fill_highlight_spread, 0.0, 0.999000012874603271484375);
        float nl = dot(_197.key_fill_highlight_dir, nrm);
        float2 lobes = fast::clamp((float2(nl, -nl) - float2(sp)) / float2(fast::max(1.0 - sp, 9.9999999747524270787835121154785e-07)), float2(0.0), float2(1.0)) * hMask;
        float2 curved = lobes / fast::max(((float2(1.0) - lobes) * _197.key_fill_highlight_amount) + float2(1.0), float2(9.9999999747524270787835121154785e-07));
        face += (float3(curved.x + curved.y) * mix(1.0, 0.5, fast::clamp(_197.key_fill_highlight_color_bias, 0.0, 1.0)));
    }
    if (_197.edge_bleed_amount > 0.0)
    {
        float bt = fast::clamp((-dist) * (_197.edge_bleed_inv_height / S), 0.0, 1.0);
        float param_61 = bt;
        float _1082 = lensCurve(param_61);
        float bmag = (_197.edge_bleed_amount - (_1082 * _197.edge_bleed_amount)) * S;
        float2 param_62 = in.vBackdropUV + ((disp * bmag) * texel);
        float param_63 = _197.edge_bleed_blur_radius * S;
        float4 param_64 = tap(param_62, param_63, uBackdrop, uBackdropSmplr);
        float4 param_65 = _197.bleed_cm0;
        float4 param_66 = _197.bleed_cm1;
        float4 param_67 = _197.bleed_cm2;
        float3 bleed = grade(param_64, param_65, param_66, param_67);
        bleed = (bleed * _197.bleed_darken.x) + float3(_197.bleed_darken.y);
        float band = 1.0 - smoothstep(_197.edge_bleed_dist0 * S, _197.edge_bleed_dist1 * S, -dist);
        face = mix(face, bleed, float3(band * _197.edge_bleed_opacity));
    }
    float aa = fast::clamp(((-dist) / fast::max(fwidth(dist), 9.9999997473787516355514526367188e-05)) + 0.5, 0.0, 1.0);
    outRGB = mix(outRGB, face, float3(aa));
    cover = fast::max(cover, aa);
    if (_197.holding_tone_opacity > 0.0)
    {
        float param_68 = dist - (_197.sdr_shadow_dist0 * S);
        float param_69 = _197.sdr_shadow_inv / S;
        float hold = erfcHalf(param_68, param_69);
        float L = dot(outRGB, float3(0.21264599263668060302734375, 0.715331971645355224609375, 0.072204999625682830810546875));
        outRGB = mix(outRGB, float3(L), float3(_197.holding_tone_opacity * hold));
    }
    if (cover < 9.9999999747524270787835121154785e-07)
    {
        discard_fragment();
    }
    out.fragColor = float4(outRGB, cover);
    return out;
}

