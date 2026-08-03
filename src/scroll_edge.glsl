// =============================================================================
// Scroll edge effect — the thing that makes a glass panel read as a nav bar.
//
// Ported from QuartzCore's `variable_blur_frag`, the primitive behind
// NSScrollEdgeEffectStyle / scrollEdgeEffectThreshold. Content scrolling under
// a bar gets progressively blurred toward the edge, so the bar materialises out
// of the content instead of sitting on top of it as a hard rectangle.
//
// WHAT THE DISASSEMBLY SHOWS
//
//   1. The radius is MASK-DRIVEN, not geometric. A second texture is sampled at
//      texcoord0, its .a taken and saturated, then multiplied by a scale. So the
//      ramp is painted, which is why one shader serves top/bottom/left/right
//      edges and any custom falloff.
//
//   2. The mip trick is the SAME one the glass uses: radius*0.5 + 1.0, log2,
//      explicit LOD. Apple reuses a single blur idiom across the whole system.
//
//   3. The kernel is a 4-tap box at that LOD, summed and * 0.25, repeated for a
//      second offset row — a separable cross over the mip chain, not a wide
//      gaussian. Cheap because the mip already did the heavy lifting.
//
// Apple runs a dedicated mip pipeline for this
// (variable_blur_copy_base_mip_compute -> variable_blur_downsample_compute).
// Here the source is expected to arrive already mipmapped, as with the glass.
// =============================================================================

#version 330 core

#if defined(TARGET_VULKAN) || __VERSION__ >= 440
  #define LOC(n)  layout(location = n)
  #define BIND(n) layout(binding = n)
#else
  #define LOC(n)
  #define BIND(n)
#endif

LOC(0) in  vec2 vUV;        // where to sample the content, normalized
LOC(1) in  vec2 vMaskUV;    // where to sample the radius mask
LOC(0) out vec4 fragColor;

BIND(0) uniform sampler2D uContent;   // scrolling content, WITH a mip chain
BIND(1) uniform sampler2D uMask;      // .a drives blur strength per pixel

BIND(2) uniform ScrollEdgeParams {
    float uMaxRadius;     // radius in pixels where the mask reads 1.0
    float uThreshold;     // scrollEdgeEffectThreshold: mask below this is clamped off
    vec2  uTexel;         // 1 / content size
    float uStyle;         // 0 = soft (ramp), 1 = hard (step at the threshold)
    float uOpacity;
    vec2  _pad;
};

const float TINY = 1.0e-6;

// Identical to the glass path — see liquid_glass.glsl blurLOD().
float blurLOD(float r) {
    r = (r < 2.0) ? (r * 0.5 + 1.0) : r;
    return max(0.0, log2(max(r, TINY)));
}

// 4-tap box at an explicit LOD, then a second offset row: Apple's cross pattern.
vec4 crossTap(vec2 uv, vec2 step_, float lod) {
    vec4 a = textureLod(uContent, uv + vec2(-step_.x, -step_.y), lod)
           + textureLod(uContent, uv + vec2( step_.x, -step_.y), lod)
           + textureLod(uContent, uv + vec2(-step_.x,  step_.y), lod)
           + textureLod(uContent, uv + vec2( step_.x,  step_.y), lod);
    a *= 0.25;
    vec4 b = textureLod(uContent, uv + vec2(-step_.x * 2.0, 0.0), lod)
           + textureLod(uContent, uv + vec2( step_.x * 2.0, 0.0), lod)
           + textureLod(uContent, uv + vec2(0.0, -step_.y * 2.0), lod)
           + textureLod(uContent, uv + vec2(0.0,  step_.y * 2.0), lod);
    b *= 0.25;
    return mix(a, b, 0.5);
}

void main() {
    // Mask alpha -> blur strength. saturate() matches the original; without it
    // an overshooting mask drives the LOD past the mip chain and the edge
    // flattens to a single colour.
    float m = clamp(texture(uMask, vMaskUV).a, 0.0, 1.0);

    // `hard` style snaps at the threshold; `soft` ramps from it. This is the
    // whole visible difference between NSScrollEdgeEffectStyle cases.
    float t = (uStyle > 0.5)
            ? step(uThreshold, m)
            : smoothstep(uThreshold, 1.0, m);

    float radius = uMaxRadius * t;
    if (radius < 0.5) {                 // below half a pixel, skip the taps
        fragColor = texture(uContent, vUV);
        return;
    }

    float lod = blurLOD(radius);
    vec2 step_ = uTexel * radius * 0.5;
    vec4 blurred = crossTap(vUV, step_, lod);

    // Cross-fade sharp -> blurred by the same ramp, so the transition has no
    // seam at the threshold.
    fragColor = mix(texture(uContent, vUV), blurred, t * uOpacity);
}
