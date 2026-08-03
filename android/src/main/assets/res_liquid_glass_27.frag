#version 300 es
precision mediump float;
precision highp int;

layout(std140) uniform GlassParams27
{
    highp vec4 displacement_mat;
    highp float inner_refraction_amount;
    highp float inner_refraction_inv_height;
    highp float outer_refraction_amount;
    highp float outer_refraction_inv_height;
    highp float refraction_threshold0;
    highp float refraction_threshold1;
    highp float blur_radius;
    highp float edge_bleed_blur_radius;
    highp float edge_bleed_amount;
    highp float edge_bleed_inv_height;
    highp float shadow_amount;
    highp float shadow_inv_height;
    highp vec2 shadow_offset;
    highp float shadow_blur_radius;
    highp float shadow_inv_radius;
    highp vec4 face_cm0;
    highp vec4 face_cm1;
    highp vec4 face_cm2;
    highp vec4 bleed_cm0;
    highp vec4 bleed_cm1;
    highp vec4 bleed_cm2;
    highp vec4 shadow_cm0;
    highp vec4 shadow_cm1;
    highp vec4 shadow_cm2;
    highp float shadow_contribution;
    highp float shadow_face_opacity;
    highp float blur_alpha0;
    highp float blur_alpha1;
    highp float blur_alpha2;
    highp float blur_alpha3;
    highp float blur_dist0;
    highp float blur_dist1;
    highp float blur_dist2;
    highp float blur_dist3;
    highp float edge_bleed_dist0;
    highp float edge_bleed_dist1;
    highp float edge_bleed_opacity;
    highp float face_opacity;
    highp vec2 bleed_darken;
    highp float shadow_dist_offset;
    highp float shadow_opacity;
    highp float refraction_opacity;
    highp float holding_tone_opacity;
    highp float sdr_shadow_dist0;
    highp float sdr_shadow_inv;
    highp vec2 ring_shadow_offset;
    highp float ring_shadow_stroke_width;
    highp float ring_shadow_radius;
    highp float ring_shadow_opacity;
    highp float ring_shadow_mask;
    highp vec2 key_fill_highlight_dir;
    highp float key_fill_highlight_height;
    highp float key_fill_highlight_spread;
    highp float key_fill_highlight_amount;
    highp float key_fill_highlight_effect_offset;
    highp float key_fill_highlight_color_bias;
    highp float blur_fill_blur_radius;
    highp float blur_fill_lighten_opacity;
    highp float blur_fill_darken_opacity;
    highp float blur_fill_normal_opacity;
    highp float aberration_amount;
    highp vec2 aberration_dir;
    highp vec2 half_size;
    highp float exponent;
    highp float scale_ref;
} _197;

uniform highp sampler2D uBackdrop;

in highp vec2 vUV;
in highp vec2 vBackdropUV;
layout(location = 0) out highp vec4 fragColor;

void supercircleSDF(highp vec2 p, highp vec2 halfSize, highp float n, out highp float dist, out highp vec2 nrm)
{
    highp vec2 q = p / halfSize;
    highp vec2 a = max(abs(q), vec2(9.9999999747524270787835121154785e-07));
    highp float s = pow(a.x, n) + pow(a.y, n);
    highp float f = pow(s, 1.0 / n) - 1.0;
    highp float k = pow(s, (1.0 / n) - 1.0);
    highp vec2 g = ((sign(q) * k) * vec2(pow(a.x, n - 1.0), pow(a.y, n - 1.0))) / halfSize;
    highp float gl = max(length(g), 9.9999999747524270787835121154785e-07);
    highp float inr = min(halfSize.x, halfSize.y);
    dist = clamp(f / gl, -inr, inr * 4.0);
    nrm = g / vec2(gl);
}

highp float lensCurve(inout highp float t)
{
    t = clamp(t, 0.0, 1.0);
    return clamp(sqrt(max((2.0 - t) * t, 0.0)), 0.0, 1.0);
}

highp float refractLobe(highp float d, highp float amount, highp float invH, highp float offset)
{
    highp float param = clamp(((-d) - offset) * invH, 0.0, 1.0);
    highp float _156 = lensCurve(param);
    return amount - (_156 * amount);
}

highp float blurLOD(inout highp float r)
{
    highp float _165;
    if (r < 2.0)
    {
        _165 = (r * 0.5) + 1.0;
    }
    else
    {
        _165 = r;
    }
    r = _165;
    return max(0.0, log2(max(r, 9.9999999747524270787835121154785e-07)));
}

highp vec4 tap(highp vec2 uv, highp float radius)
{
    highp float param = radius;
    highp float _189 = blurLOD(param);
    return textureLod(uBackdrop, uv, _189);
}

highp vec3 grade(highp vec4 c, highp vec4 r0, highp vec4 r1, highp vec4 r2)
{
    highp float a = max(c.w, 9.9999999747524270787835121154785e-07);
    highp vec3 rgb = c.xyz / vec3(a);
    rgb *= step(vec3(9.9999999747524270787835121154785e-07), abs(rgb));
    return vec3(dot(rgb, r0.xyz) + r0.w, dot(rgb, r1.xyz) + r1.w, dot(rgb, r2.xyz) + r2.w);
}

highp float erfcHalf(highp float d, highp float invR)
{
    highp float u = clamp((0.25 * (d * invR)) + 0.5, 0.0, 1.0);
    highp float x = (4.0 * u) - 2.0;
    highp float x2 = x * x;
    highp float p = 0.00295399990864098072052001953125;
    p = (p * x2) - 0.034460000693798065185546875;
    p = (p * x2) + 0.1682099997997283935546875;
    p = (p * x2) - 0.5605499744415283203125;
    return (p * x) + 0.5;
}

highp float blurRamp(highp float d, highp float S)
{
    highp vec3 lo = vec3(_197.blur_dist1, _197.blur_dist2, _197.blur_dist3);
    highp vec3 hi = vec3(_197.blur_dist0, _197.blur_dist1, _197.blur_dist2);
    highp vec3 sp = hi - lo;
    highp vec3 inv = vec3(1.0) / mix(sp, vec3(9.9999999747524270787835121154785e-07), step(abs(sp), vec3(9.9999999747524270787835121154785e-07)));
    highp vec3 t = clamp((vec3(d) - lo) * inv, vec3(0.0), vec3(1.0));
    highp vec3 w = vec3(_197.blur_alpha1, _197.blur_alpha2, _197.blur_alpha3) * t;
    return ((_197.blur_alpha0 - ((w.x + w.y) + w.z)) * _197.blur_radius) * S;
}

void main()
{
    highp float _360;
    if (_197.scale_ref > 0.0)
    {
        _360 = min(_197.half_size.x, _197.half_size.y) / _197.scale_ref;
    }
    else
    {
        _360 = 1.0;
    }
    highp float S = _360;
    highp vec2 texel = vec2(1.0) / vec2(textureSize(uBackdrop, 0));
    highp vec2 param = vUV;
    highp vec2 param_1 = _197.half_size;
    highp float param_2 = _197.exponent;
    highp float param_3;
    highp vec2 param_4;
    supercircleSDF(param, param_1, param_2, param_3, param_4);
    highp float dist = param_3;
    highp vec2 nrm = param_4;
    highp vec2 rot = vec2(dot(nrm, vec2(1.0, 0.0)), dot(nrm, vec2(0.0, 1.0)));
    highp vec2 disp = vec2(dot(rot, _197.displacement_mat.xy), dot(rot, _197.displacement_mat.zw));
    highp vec3 outRGB = vec3(0.0);
    highp float cover = 0.0;
    highp float param_5 = dist;
    highp float param_6 = _197.shadow_amount * S;
    highp float param_7 = _197.shadow_inv_height / S;
    highp float param_8 = _197.shadow_dist_offset;
    highp float smag = refractLobe(param_5, param_6, param_7, param_8);
    highp vec2 param_9 = vBackdropUV + (((disp * smag) + _197.shadow_offset) * texel);
    highp float param_10 = _197.shadow_blur_radius * S;
    highp vec4 scol = tap(param_9, param_10);
    highp vec4 param_11 = scol;
    highp vec4 param_12 = _197.shadow_cm0;
    highp vec4 param_13 = _197.shadow_cm1;
    highp vec4 param_14 = _197.shadow_cm2;
    highp vec3 sh = grade(param_11, param_12, param_13, param_14) * _197.shadow_contribution;
    highp float param_15 = dist;
    highp float param_16 = _197.shadow_inv_radius / S;
    highp float smask = (erfcHalf(param_15, param_16) * _197.shadow_opacity) * step(0.0, dist);
    outRGB = mix(outRGB, sh, vec3(smask));
    cover = max(cover, smask * _197.shadow_face_opacity);
    if (_197.ring_shadow_opacity > 0.0)
    {
        highp float invR = 1.0 / max(_197.ring_shadow_radius * S, 9.9999999747524270787835121154785e-07);
        highp float d = (-dist) - _197.ring_shadow_offset.x;
        highp float inner = d * invR;
        highp float outer = inner + ((_197.ring_shadow_stroke_width * S) * invR);
        highp float param_17 = inner * 0.707106769084930419921875;
        highp float param_18 = 1.0;
        highp float param_19 = outer * 0.707106769084930419921875;
        highp float param_20 = 1.0;
        highp float ring = (clamp(erfcHalf(param_17, param_18) - erfcHalf(param_19, param_20), 0.0, 1.0) * _197.ring_shadow_opacity) * clamp(_197.ring_shadow_mask, 0.0, 1.0);
        outRGB *= (1.0 - ring);
    }
    highp float param_21 = dist;
    highp float param_22 = S;
    highp float faceLod = blurRamp(param_21, param_22);
    highp vec2 faceUV = vBackdropUV;
    highp float param_23 = dist;
    highp float param_24 = _197.inner_refraction_amount * S;
    highp float param_25 = _197.inner_refraction_inv_height / S;
    highp float param_26 = 0.0;
    highp float innerMag = refractLobe(param_23, param_24, param_25, param_26);
    faceUV = vBackdropUV + ((disp * innerMag) * texel);
    highp float param_27 = innerMag + dist;
    highp float param_28 = S;
    faceLod = blurRamp(param_27, param_28);
    highp vec2 param_29 = faceUV;
    highp float param_30 = faceLod;
    highp vec4 faceCol = tap(param_29, param_30);
    if (_197.aberration_amount > 0.0)
    {
        highp vec2 rotA = vec2(dot(nrm, vec2(_197.aberration_dir.x, -_197.aberration_dir.y)), dot(nrm, vec2(_197.aberration_dir.y, _197.aberration_dir.x)));
        highp vec2 dispA = vec2(dot(rotA, _197.displacement_mat.zw), dot(rotA, _197.displacement_mat.xy));
        highp float param_31 = dist;
        highp float param_32 = _197.aberration_amount * S;
        highp float param_33 = _197.inner_refraction_inv_height / S;
        highp float param_34 = 0.0;
        highp vec2 offA = dispA * refractLobe(param_31, param_32, param_33, param_34);
        highp vec3 acc = vec3(0.0);
        highp float aSum = 0.0;
        highp float w = 1.0;
        for (int i = 0; i < 3; i++)
        {
            highp vec2 param_35 = faceUV + ((offA * w) * texel);
            highp float param_36 = faceLod;
            highp vec4 s = tap(param_35, param_36);
            highp float a = max(s.w, 9.9999999747524270787835121154785e-07);
            acc.x += ((s.x / a) * w);
            acc.y += ((s.y / a) * (1.0 - w));
            aSum += s.w;
            w -= 0.3333333432674407958984375;
        }
        highp float st = 0.0;
        for (int i_1 = 0; i_1 < 4; i_1++)
        {
            highp vec2 param_37 = faceUV - ((offA * st) * texel);
            highp float param_38 = faceLod;
            highp vec4 s_1 = tap(param_37, param_38);
            highp float a_1 = max(s_1.w, 9.9999999747524270787835121154785e-07);
            acc.y += ((s_1.y / a_1) * (1.0 - st));
            acc.z += ((s_1.z / a_1) * st);
            aSum += s_1.w;
            st += 0.3333333432674407958984375;
        }
        acc *= vec3(0.5, 0.3333333432674407958984375, 0.5);
        faceCol = vec4(acc, aSum * 0.14285714924335479736328125);
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
        highp vec4 param_39 = faceCol;
        highp vec4 param_40 = _197.face_cm0;
        highp vec4 param_41 = _197.face_cm1;
        highp vec4 param_42 = _197.face_cm2;
        highp vec3 base = grade(param_39, param_40, param_41, param_42);
        highp vec2 param_43 = vBackdropUV;
        highp float param_44 = _197.blur_fill_blur_radius * S;
        highp vec4 param_45 = tap(param_43, param_44);
        highp vec4 param_46 = _197.face_cm0;
        highp vec4 param_47 = _197.face_cm1;
        highp vec4 param_48 = _197.face_cm2;
        highp vec3 fill = grade(param_45, param_46, param_47, param_48);
        highp float wBase = (1.0 - _197.blur_fill_lighten_opacity) - _197.blur_fill_darken_opacity;
        highp vec3 mixed = ((max(base, fill) * _197.blur_fill_lighten_opacity) + (min(base, fill) * _197.blur_fill_darken_opacity)) + (base * wBase);
        highp vec3 _890 = mix(mixed, fill, vec3(clamp(_197.blur_fill_normal_opacity, 0.0, 1.0)));
        faceCol.x = _890.x;
        faceCol.y = _890.y;
        faceCol.z = _890.z;
        faceCol.w = 1.0;
    }
    if (_197.refraction_opacity > 0.0)
    {
        highp float param_49 = dist;
        highp float param_50 = _197.outer_refraction_amount * S;
        highp float param_51 = _197.outer_refraction_inv_height / S;
        highp float param_52 = 0.0;
        highp float outerMag = refractLobe(param_49, param_50, param_51, param_52);
        highp float param_53 = outerMag + dist;
        highp float param_54 = S;
        highp vec2 param_55 = vBackdropUV + ((disp * outerMag) * texel);
        highp float param_56 = blurRamp(param_53, param_54);
        highp vec4 outerCol = tap(param_55, param_56);
        highp float span = _197.refraction_threshold1 - _197.refraction_threshold0;
        highp float t = clamp((dist - _197.refraction_threshold0) / ((abs(span) < 9.9999999747524270787835121154785e-07) ? 9.9999999747524270787835121154785e-07 : span), 0.0, 1.0);
        faceCol = mix(faceCol, outerCol, vec4(t * _197.refraction_opacity));
    }
    highp vec4 param_57 = faceCol;
    highp vec4 param_58 = _197.face_cm0;
    highp vec4 param_59 = _197.face_cm1;
    highp vec4 param_60 = _197.face_cm2;
    highp vec3 face = grade(param_57, param_58, param_59, param_60) * _197.face_opacity;
    if (_197.key_fill_highlight_amount > 0.0)
    {
        highp float hMask = clamp(((-dist) - (_197.key_fill_highlight_effect_offset * S)) / max(_197.key_fill_highlight_height * S, 9.9999999747524270787835121154785e-07), 0.0, 1.0);
        highp float sp = clamp(_197.key_fill_highlight_spread, 0.0, 0.999000012874603271484375);
        highp float nl = dot(_197.key_fill_highlight_dir, nrm);
        highp vec2 lobes = clamp((vec2(nl, -nl) - vec2(sp)) / vec2(max(1.0 - sp, 9.9999999747524270787835121154785e-07)), vec2(0.0), vec2(1.0)) * hMask;
        highp vec2 curved = lobes / max(((vec2(1.0) - lobes) * _197.key_fill_highlight_amount) + vec2(1.0), vec2(9.9999999747524270787835121154785e-07));
        face += (vec3(curved.x + curved.y) * mix(1.0, 0.5, clamp(_197.key_fill_highlight_color_bias, 0.0, 1.0)));
    }
    if (_197.edge_bleed_amount > 0.0)
    {
        highp float bt = clamp((-dist) * (_197.edge_bleed_inv_height / S), 0.0, 1.0);
        highp float param_61 = bt;
        highp float _1082 = lensCurve(param_61);
        highp float bmag = (_197.edge_bleed_amount - (_1082 * _197.edge_bleed_amount)) * S;
        highp vec2 param_62 = vBackdropUV + ((disp * bmag) * texel);
        highp float param_63 = _197.edge_bleed_blur_radius * S;
        highp vec4 param_64 = tap(param_62, param_63);
        highp vec4 param_65 = _197.bleed_cm0;
        highp vec4 param_66 = _197.bleed_cm1;
        highp vec4 param_67 = _197.bleed_cm2;
        highp vec3 bleed = grade(param_64, param_65, param_66, param_67);
        bleed = (bleed * _197.bleed_darken.x) + vec3(_197.bleed_darken.y);
        highp float band = 1.0 - smoothstep(_197.edge_bleed_dist0 * S, _197.edge_bleed_dist1 * S, -dist);
        face = mix(face, bleed, vec3(band * _197.edge_bleed_opacity));
    }
    highp float aa = clamp(((-dist) / max(fwidth(dist), 9.9999997473787516355514526367188e-05)) + 0.5, 0.0, 1.0);
    outRGB = mix(outRGB, face, vec3(aa));
    cover = max(cover, aa);
    if (_197.holding_tone_opacity > 0.0)
    {
        highp float param_68 = dist - (_197.sdr_shadow_dist0 * S);
        highp float param_69 = _197.sdr_shadow_inv / S;
        highp float hold = erfcHalf(param_68, param_69);
        highp float L = dot(outRGB, vec3(0.21264599263668060302734375, 0.715331971645355224609375, 0.072204999625682830810546875));
        outRGB = mix(outRGB, vec3(L), vec3(_197.holding_tone_opacity * hold));
    }
    if (cover < 9.9999999747524270787835121154785e-07)
    {
        discard;
    }
    fragColor = vec4(outRGB, cover);
}

