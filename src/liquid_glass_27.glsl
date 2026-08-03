// =============================================================================
// Liquid Glass — macOS 27 (build 26A5388g), faithful port
//
// This is not the macOS 26 shader with additions bolted on. It follows macOS
// 27's own structure: its exact 63-field uniform block in declaration order,
// and its pipeline in the order the disassembly performs it.
//
// Source: QuartzCore default.metallib, air64_v29 slice, pulled from the
// unencrypted cryptex volume of the IPSW (see ../ipsw27/MACOS27.md).
// Reference entry point: glass_background_all_lpf — 1527 lines, and the only
// variant that reads all 63 uniforms.
//
// TWO THINGS macOS 27 CHANGED STRUCTURALLY
//
//   1. Runtime bools became compile-time variants. 12 entry points became 36:
//      glass_background_{minimal,c,e,r,ce,cr,re,all}. `complex_refraction` is
//      gone from the struct entirely — the decision moved into the shader name.
//      Reproduced here with LG_R / LG_E / LG_C defines, which is worth copying
//      regardless of version: it removes per-fragment branching.
//
//   2. Order of operations. macOS 26 shaded the face and layered shadow on top.
//      macOS 27 computes shadow and ring shadow FIRST, then the face over them.
//      That is visible in the first-read order of the uniforms.
//
// Budget in the original: 21 texture samples, 9 log2 mip selects, 6 lens-curve
// sqrts, 2 fwidth, 2 discards.
//
// FIDELITY NOTE, stated plainly. The structure and math here are transcribed
// from macOS 27's disassembly. The default VALUES are not: macOS 27's material
// recipes live on the encrypted IPSW volume, and a macOS 26 host cannot boot a
// 27 guest to read them (Virtualization.framework refuses: a host cannot
// virtualise a guest newer than itself). So the shape is 27; the constants are
// carried over from the macOS 26 fit until 27's recipes can be read.
// =============================================================================

#version 330 core

#if defined(TARGET_VULKAN) || __VERSION__ >= 440
  #define LOC(n)  layout(location = n)
  #define BIND(n) layout(binding = n)
#else
  #define LOC(n)
  #define BIND(n)
#endif

// Feature set. Mirrors macOS 27's variant suffixes; define none for `minimal`.
// LG_R = refraction
// LG_E = edge bleed + shadow
// LG_C = ring shadow + key fill + blur fill (new in 27)
// Trailing // comments on a #define get folded into the macro body by glslang,
// which then breaks `#if LG_E`. Keep these lines bare.
#ifndef LG_R
#define LG_R 1
#endif
#ifndef LG_E
#define LG_E 1
#endif
#ifndef LG_C
#define LG_C 1
#endif

LOC(0) in  vec2 vUV;
LOC(1) in  vec2 vBackdropUV;
LOC(0) out vec4 fragColor;

BIND(0) uniform sampler2D uBackdrop;

// Field order and names are macOS 27's exactly, from air.struct_type_info.
// 63 fields. Do not reorder.
BIND(1) uniform GlassParams27 {
    vec4  displacement_mat;
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
    vec2  shadow_offset;
    float shadow_blur_radius;
    float shadow_inv_radius;
    vec4  face_cm0, face_cm1, face_cm2;
    vec4  bleed_cm0, bleed_cm1, bleed_cm2;
    vec4  shadow_cm0, shadow_cm1, shadow_cm2;
    float shadow_contribution;
    float shadow_face_opacity;
    float blur_alpha0, blur_alpha1, blur_alpha2, blur_alpha3;
    float blur_dist0,  blur_dist1,  blur_dist2,  blur_dist3;
    float edge_bleed_dist0, edge_bleed_dist1;
    float edge_bleed_opacity;
    float face_opacity;
    vec2  bleed_darken;
    float shadow_dist_offset;
    float shadow_opacity;
    float refraction_opacity;
    float holding_tone_opacity;
    float sdr_shadow_dist0;
    float sdr_shadow_inv;          // 27: replaces 26's sdr_shadow_dist1
    // --- new in macOS 27 ---
    vec2  ring_shadow_offset;
    float ring_shadow_stroke_width;
    float ring_shadow_radius;
    float ring_shadow_opacity;
    float ring_shadow_mask;
    vec2  key_fill_highlight_dir;
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
    vec2  aberration_dir;          // 27: a vec2, where 26 used two floats
    // --- host-side, not Apple's ---
    vec2  half_size;
    float exponent;
    float scale_ref;
};

const float EPS  = 1.0e-4;
const float TINY = 1.0e-6;

// Rec.709, decoded verbatim from tile_average_luma's fp16 immediates.
const vec3 LUMA709 = vec3(0.212646, 0.715332, 0.072205);

// -----------------------------------------------------------------------------
// Squircle SDF. Apple's supercircle_sdf; not a rounded rect. The inradius clamp
// guards the centre, where the gradient vanishes and f/|grad| would explode.
// -----------------------------------------------------------------------------
void supercircleSDF(vec2 p, vec2 halfSize, float n, out float dist, out vec2 nrm) {
    vec2  q = p / halfSize;
    vec2  a = max(abs(q), vec2(TINY));
    float s = pow(a.x, n) + pow(a.y, n);
    float f = pow(s, 1.0 / n) - 1.0;
    float k = pow(s, 1.0 / n - 1.0);
    vec2  g = k * sign(q) * vec2(pow(a.x, n - 1.0), pow(a.y, n - 1.0)) / halfSize;
    float gl = max(length(g), TINY);
    float inr = min(halfSize.x, halfSize.y);
    dist = clamp(f / gl, -inr, inr * 4.0);
    nrm  = g / gl;
}

// Upper arc of a unit circle, spelled sqrt((2-t)*t) as macOS 27 does.
float lensCurve(float t) {
    t = clamp(t, 0.0, 1.0);
    return clamp(sqrt(max((2.0 - t) * t, 0.0)), 0.0, 1.0);
}
float refractLobe(float d, float amount, float invH, float offset) {
    return amount - lensCurve(clamp((-d - offset) * invH, 0.0, 1.0)) * amount;
}

float blurLOD(float r) {
    r = (r < 2.0) ? (r * 0.5 + 1.0) : r;
    return max(0.0, log2(max(r, TINY)));
}
vec4 tap(vec2 uv, float radius) {
    return textureLod(uBackdrop, uv, blurLOD(radius));
}

// 4-point piecewise-linear ramp: distance -> blur radius.
float blurRamp(float d, float S) {
    // Same transposition as the 26 port: lo took dist1..3 (8,20,40) and hi took
    // dist0..2 (0,8,20), so hi < lo, every span was negative, and deep inside
    // the shape all three ramps saturated -- leaving (alpha0 - 0.9) = 0.1 of the
    // radius in the panel CENTRE. Measured on the 26 path with probeGlass: a
    // hard backdrop edge crossed in ~8px under a nominal 45px blur.
    //
    // CAVEAT, because this matters for fidelity claims: the DEFECT is measured,
    // but the FIX is not uniquely determined. Transposing lo/hi here and
    // reversing the blur_dist order in the preset are observationally identical.
    // I have not re-read the disassembly to see which one Apple actually has, so
    // treat the orientation as fitted, not decoded.
    vec3 lo = vec3(blur_dist0, blur_dist1, blur_dist2);
    vec3 hi = vec3(blur_dist1, blur_dist2, blur_dist3);
    vec3 sp = hi - lo;
    vec3 inv = 1.0 / mix(sp, vec3(TINY), step(abs(sp), vec3(TINY)));
    vec3 t = clamp((vec3(d) - lo) * inv, 0.0, 1.0);
    vec3 w = vec3(blur_alpha1, blur_alpha2, blur_alpha3) * t;
    return (blur_alpha0 - (w.x + w.y + w.z)) * blur_radius * S;
}

// Degree-7 minimax 0.5*erfc(x) over [-2,2]. Coefficients from the fp16
// immediates; identical in 26 and 27. Replaces a blur pass outright.
float erfcHalf(float d, float invR) {
    float u = clamp(0.25 * (d * invR) + 0.5, 0.0, 1.0);
    float x = 4.0 * u - 2.0, x2 = x * x;
    float p = 0.002954;
    p = p * x2 - 0.034460;
    p = p * x2 + 0.168210;
    p = p * x2 - 0.560550;
    return p * x + 0.5;
}

vec3 grade(vec4 c, vec4 r0, vec4 r1, vec4 r2) {
    float a = max(c.a, TINY);
    vec3 rgb = c.rgb / a;
    rgb *= step(vec3(TINY), abs(rgb));
    return vec3(dot(rgb, r0.xyz) + r0.w,
                dot(rgb, r1.xyz) + r1.w,
                dot(rgb, r2.xyz) + r2.w);
}

void main() {
    float S = (scale_ref > 0.0) ? min(half_size.x, half_size.y) / scale_ref : 1.0;
    vec2 texel = 1.0 / vec2(textureSize(uBackdrop, 0));

    float dist; vec2 nrm;
    supercircleSDF(vUV, half_size, exponent, dist, nrm);

    vec2 rot  = vec2(dot(nrm, vec2( 1.0, 0.0)), dot(nrm, vec2( 0.0, 1.0)));
    vec2 disp = vec2(dot(rot, displacement_mat.xy), dot(rot, displacement_mat.zw));

    vec3  outRGB = vec3(0.0);
    float cover  = 0.0;

    // ---- 1. shadow, then ring shadow -------------------------------------
    // macOS 27 computes these FIRST and shades the face over them. macOS 26
    // did the reverse. Matching the order matters: the face's colour matrix
    // then operates on a surface that already carries the shadow.
#if LG_E
    {
        float smag = refractLobe(dist, shadow_amount * S, shadow_inv_height / S,
                                 shadow_dist_offset);
        vec4  scol = tap(vBackdropUV + (smag * disp + shadow_offset) * texel,
                         shadow_blur_radius * S);
        vec3  sh   = grade(scol, shadow_cm0, shadow_cm1, shadow_cm2)
                   * shadow_contribution;
        float smask = erfcHalf(dist, shadow_inv_radius / S)
                    * shadow_opacity * step(0.0, dist);
        outRGB = mix(outRGB, sh, smask);
        cover  = max(cover, smask * shadow_face_opacity);
    }
#endif
#if LG_C
    if (ring_shadow_opacity > 0.0) {
        // erfc(inner) - erfc(outer): two soft steps subtracted give a soft band
        // with no second blur and no extra fetch.
        float invR  = 1.0 / max(ring_shadow_radius * S, TINY);
        float d     = (-dist - ring_shadow_offset.x);
        float inner = d * invR;
        float outer = inner + (ring_shadow_stroke_width * S) * invR;
        const float INV_SQRT2 = 0.70710678;
        float ring = clamp(erfcHalf(inner * INV_SQRT2, 1.0)
                         - erfcHalf(outer * INV_SQRT2, 1.0), 0.0, 1.0)
                   * ring_shadow_opacity * clamp(ring_shadow_mask, 0.0, 1.0);
        outRGB *= (1.0 - ring);
    }
#endif

    // ---- 2. face: inner refraction + blur ramp ----------------------------
    float faceLod = blurRamp(dist, S);
    vec2  faceUV  = vBackdropUV;
#if LG_R
    float innerMag = refractLobe(dist, inner_refraction_amount * S,
                                 inner_refraction_inv_height / S, 0.0);
    faceUV  = vBackdropUV + innerMag * disp * texel;
    faceLod = blurRamp(innerMag + dist, S);
#endif
    vec4 faceCol = tap(faceUV, faceLod);

    // ---- 3. chromatic aberration -----------------------------------------
    // 7 taps: 3 forward feeding R/G, 4 backward feeding G/B. Per-channel weight
    // sums are 2/3/2, normalised by (0.5, 1/3, 0.5) to exactly 1.0 — which is
    // how the transcription self-checks. Alpha sums over all 7, hence 1/7.
    // In 27 the direction is a vec2 in the BACKGROUND struct; 26 had it only in
    // the foreground path, as two separate angle floats.
    if (aberration_amount > 0.0) {
        vec2 rotA  = vec2(dot(nrm, vec2( aberration_dir.x, -aberration_dir.y)),
                          dot(nrm, vec2( aberration_dir.y,  aberration_dir.x)));
        vec2 dispA = vec2(dot(rotA, displacement_mat.zw),
                          dot(rotA, displacement_mat.xy));
        vec2 offA  = dispA * refractLobe(dist, aberration_amount * S,
                                         inner_refraction_inv_height / S, 0.0);
        vec3 acc = vec3(0.0); float aSum = 0.0;
        float w = 1.0;
        for (int i = 0; i < 3; ++i) {
            vec4 s = tap(faceUV + offA * w * texel, faceLod);
            float a = max(s.a, TINY);
            acc.r += (s.r / a) * w;
            acc.g += (s.g / a) * (1.0 - w);
            aSum  += s.a;  w -= 1.0 / 3.0;
        }
        float st = 0.0;
        for (int i = 0; i < 4; ++i) {
            vec4 s = tap(faceUV - offA * st * texel, faceLod);
            float a = max(s.a, TINY);
            acc.g += (s.g / a) * (1.0 - st);
            acc.b += (s.b / a) * st;
            aSum  += s.a;  st += 1.0 / 3.0;
        }
        acc *= vec3(0.5, 1.0 / 3.0, 0.5);
        faceCol = vec4(acc, aSum * (1.0 / 7.0));
    }

    // ---- 4. blur fill (new in 27) ----------------------------------------
    // lighten/darken/base are a partition of unity, then a lerp to normal
    // blend. One branch-free formula spans every combination.
#if LG_C
    if (blur_fill_normal_opacity > 0.0 || blur_fill_lighten_opacity > 0.0
        || blur_fill_darken_opacity > 0.0) {
        vec3 base = grade(faceCol, face_cm0, face_cm1, face_cm2);
        vec3 fill = grade(tap(vBackdropUV, blur_fill_blur_radius * S),
                          face_cm0, face_cm1, face_cm2);
        float wBase = 1.0 - blur_fill_lighten_opacity - blur_fill_darken_opacity;
        vec3 mixed  = blur_fill_lighten_opacity * max(base, fill)
                    + blur_fill_darken_opacity  * min(base, fill)
                    + wBase * base;
        faceCol.rgb = mix(mixed, fill, clamp(blur_fill_normal_opacity, 0.0, 1.0));
        faceCol.a = 1.0;
    }
#endif

    // ---- 5. outer refraction, cross-faded across the threshold band -------
#if LG_R
    if (refraction_opacity > 0.0) {
        float outerMag = refractLobe(dist, outer_refraction_amount * S,
                                     outer_refraction_inv_height / S, 0.0);
        vec4 outerCol = tap(vBackdropUV + outerMag * disp * texel,
                            blurRamp(outerMag + dist, S));
        float span = refraction_threshold1 - refraction_threshold0;
        float t = clamp((dist - refraction_threshold0)
                        / (abs(span) < TINY ? TINY : span), 0.0, 1.0);
        faceCol = mix(faceCol, outerCol, t * refraction_opacity);
    }
#endif

    vec3 face = grade(faceCol, face_cm0, face_cm1, face_cm2) * face_opacity;

    // ---- 6. key fill highlight (new in 27) -------------------------------
    // Two OPPOSING lobes summed, each through a rational soft-knee
    // x/(a(1-x)+1): identity at amount 0, lifting midtones without clipping.
    // Gate on AMOUNT only — gating on height runs it at amount 0, where the
    // curve degenerates to the raw lobes and paints a hard bowtie.
#if LG_C
    if (key_fill_highlight_amount > 0.0) {
        float hMask = clamp((-dist - key_fill_highlight_effect_offset * S)
                            / max(key_fill_highlight_height * S, TINY), 0.0, 1.0);
        float sp   = clamp(key_fill_highlight_spread, 0.0, 0.999);
        float nl   = dot(key_fill_highlight_dir, nrm);
        vec2 lobes = clamp((vec2(nl, -nl) - vec2(sp)) / max(1.0 - sp, TINY),
                           0.0, 1.0) * hMask;
        vec2 curved = lobes / max(key_fill_highlight_amount * (1.0 - lobes) + 1.0,
                                  vec2(TINY));
        face += vec3(curved.x + curved.y)
              * mix(1.0, 0.5, clamp(key_fill_highlight_color_bias, 0.0, 1.0));
    }
#endif

    // ---- 7. edge bleed ---------------------------------------------------
    // The band is INVERTED: -dist grows toward the centre, so a plain
    // smoothstep saturates in the body and washes the whole element.
#if LG_E
    if (edge_bleed_amount > 0.0) {
        float bt   = clamp((-dist) * (edge_bleed_inv_height / S), 0.0, 1.0);
        float bmag = (edge_bleed_amount - lensCurve(bt) * edge_bleed_amount) * S;
        vec3 bleed = grade(tap(vBackdropUV + bmag * disp * texel,
                               edge_bleed_blur_radius * S),
                           bleed_cm0, bleed_cm1, bleed_cm2);
        bleed = bleed * bleed_darken.x + vec3(bleed_darken.y);
        float band = 1.0 - smoothstep(edge_bleed_dist0 * S,
                                      edge_bleed_dist1 * S, -dist);
        face = mix(face, bleed, band * edge_bleed_opacity);
    }
#endif

    // ---- 8. composite over the shadow layer ------------------------------
    float aa = clamp(-dist / max(fwidth(dist), EPS) + 0.5, 0.0, 1.0);
    outRGB = mix(outRGB, face, aa);
    cover  = max(cover, aa);

    // ---- 9. SDR holding tone ---------------------------------------------
    // 27 dropped clamp_limit / preserve_hue / sdr_white_value and keeps only
    // holding_tone_opacity with a single sdr_shadow_dist0 / sdr_shadow_inv pair.
    if (holding_tone_opacity > 0.0) {
        float hold = erfcHalf(dist - sdr_shadow_dist0 * S, sdr_shadow_inv / S);
        float L = dot(outRGB, LUMA709);
        outRGB = mix(outRGB, vec3(L), holding_tone_opacity * hold);
    }

    if (cover < TINY) discard;
    fragColor = vec4(outRGB, cover);
}
