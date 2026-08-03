// =============================================================================
// Liquid Glass — portable GLSL implementation
//
// Reimplemented from the decoded macOS 26 QuartzCore shaders. Runs anywhere you
// can bind the backdrop as a texture: OpenGL 3.3+, OpenGL ES 3.0+, WebGL2,
// Vulkan (via glslang), and — with trivial syntax swaps — HLSL and WGSL.
//
// Nothing Apple-specific remains. No Metal, no CoreAnimation, no AIR.
//
// WHAT YOU MUST SUPPLY
//   uBackdrop  — the composited pixels BEHIND this element, as a texture with a
//                full mip chain. This is the only hard requirement and the only
//                part that differs per platform. See portable/README.md.
//
// The two tricks that make this cheap enough to ship (both lifted from Apple's
// implementation, both platform-neutral):
//
//   1. BLUR VIA MIPMAPS. There is no blur loop anywhere. Blur radius is turned
//      into a mip level with log2() and one trilinear tap does the work. Cost is
//      constant regardless of radius.
//
//   2. SHADOW VIA ANALYTIC erfc. The drop shadow is not blurred either — a
//      degree-7 polynomial evaluates the Gaussian integral directly. Exact
//      coefficients recovered from the shipping binary, reproduced below.
//
// Precision note: Apple runs an fp16 path (_lph) and an fp32 path (_lpf) with
// identical math. This is the fp32 path. On mobile you can drop most of this to
// mediump without visible difference.
// =============================================================================

#version 330 core

// One file, three targets. Fragment-input `location` qualifiers require GLSL
// 440+ or Vulkan; `binding` on a sampler requires 420+. Both are mandatory for
// SPIR-V and illegal on GL 330 / ES 3.0, so gate them.
//
//   Desktop GL : glslangValidator -S frag liquid_glass.glsl
//   Vulkan     : glslangValidator -V -S frag -DTARGET_VULKAN ... (with #version 450)
//   WebGL2/ES  : swap #version to `300 es` + precision qualifiers
#if defined(TARGET_VULKAN) || __VERSION__ >= 440
  #define LOC(n)  layout(location = n)
  #define BIND(n) layout(binding = n)
#else
  #define LOC(n)
  #define BIND(n)
#endif

LOC(0) in  vec2 vUV;         // position in the element, pixels, origin at center
LOC(1) in  vec2 vBackdropUV; // where to sample the backdrop, normalized [0,1]
LOC(0) out vec4 fragColor;

BIND(0) uniform sampler2D uBackdrop;

// All non-opaque uniforms live in a block. Required by Vulkan, and valid on
// GL 330 and ES 300 too, so one declaration covers every target.
//
// Color matrices are stored as three vec4 rows with the bias in .w — exactly
// how Apple packs them (half4 face_cm0/1/2). That also dodges std140's mat3
// padding rules, which are a classic source of silent corruption.
BIND(1) uniform GlassParams {

// ---- shape ----------------------------------------------------------------
 vec2  uHalfSize;      // half extents of the element, pixels
 float uExponent;      // superellipse power. 2 = ellipse, 4-5 = Apple squircle,
                       // large = rectangle. Apple's corners are NOT circular.

// ---- refraction (two-sided) -----------------------------------------------
// The rim bends light one way on its outer face and the other way just inside.
// That opposed pair is what reads as thick glass instead of a blurred rectangle.
 float uInnerRefractAmount;
 float uInnerRefractInvHeight;   // 1/height, pre-reciprocated (Apple does this)
 float uOuterRefractAmount;
 float uOuterRefractInvHeight;
 float uRefractOpacity;          // 0 disables the outer lobe entirely
 float uComplexRefraction;       // 0 = cheap single-sided, 1 = true two-sided
 vec2  uRefractThreshold;        // (threshold0, threshold1) — distance band over
                                 // which inner cross-fades into outer
 vec4  uDisplacementMat;         // 2x2 packed: row0 = .xy, row1 = .zw
 vec2  uRefractAngle;            // (cos, sin)

// ---- chromatic aberration -------------------------------------------------
// A fully independent second displacement with its own angle. This is the
// colored fringing on the rim.
 float uAberrationAmount;
 float uAberrationInvHeight;
 float uAberrationOffset;
 vec2  uAberrationAngle;         // (cos, sin)

// ---- blur ramp ------------------------------------------------------------
// Four (distance, weight) control points defining a piecewise-linear curve that
// maps distance-from-edge to blur radius. Hand-authored, not a real Gaussian.
 vec4  uBlurDist;                // dist0..3
 vec4  uBlurAlpha;               // alpha0..3
 float uBlurRadius;


// ---- edge bleed -----------------------------------------------------------
// A second, WIDER blur sampled only near the rim. This is the thing that makes
// glass read as wet rather than merely curved. Skipping it is the most common
// reason a reimplementation looks flat.
 float uEdgeBleedAmount;
 float uEdgeBleedInvHeight;
 float uEdgeBleedBlurRadius;
 vec2  uEdgeBleedDist;           // (start, end)
 float uEdgeBleedOpacity;
 vec2  uBleedDarken;             // (scale, bias)

// ---- edge fade (foreground path) ------------------------------------------
// Note the INVERSION in main(): the shader multiplies by (1 - mix(...)), so
// these are opacities being removed, not added.
 vec2  uEdgeRange;               // (edge_start, edge_end)
 vec2  uEdgeOpacity;             // (edge_opacity_start, edge_opacity_end)

// ---- specular highlight ---------------------------------------------------
 vec2  uLightDir;                // (x, y) light direction for the rim glint
 float uHighlightThreshold;      // below this n.l contributes nothing
 float uHighlightHeight;         // band width, distance units
 float uHighlightSoftness;       // 0 = hard step, 1 = linear ramp
 float uHighlightIntensity;

// ---- shadow ---------------------------------------------------------------
 float uShadowAmount;
 float uShadowInvHeight;
 vec2  uShadowOffset;
 float uShadowInvRadius;
 float uShadowOpacity;
 float uShadowContribution;
 float uShadowDistOffset;

// ---- color matrices (3x4: 3x3 matrix + bias in .w) ------------------------
// Face, bleed and shadow are graded independently — light through the body,
// light smeared at the rim, and the shadow each get their own matrix.
 vec4  uFaceCM0,   uFaceCM1,   uFaceCM2;    // .xyz = matrix row, .w = bias
 vec4  uBleedCM0,  uBleedCM1,  uBleedCM2;
 vec4  uShadowCM0, uShadowCM1, uShadowCM2;
 float uFaceOpacity;

// ---- HDR ------------------------------------------------------------------
 float uClampLimit;
 float uPreserveHue;
 float uSDRWhite;
 float uEDRScale;

// ---- diffusion (appear / disappear) ---------------------------------------
// Apple's term for the grow-in / fade-out transition is "diffusion"
// (NSGlassDiffusionSetting, NSGlassEffectDiffusionDidChangeNotification).
// That animation is driven by higher-level AppKit/SwiftUI code, NOT by the
// fragment shader — so this parameter is OUR construction, not a decoded curve.
// It is modelled on the observable behaviour: glass does not fade in as flat
// opacity, it *thickens* — refraction and blur ramp up together while the body
// resolves, so it reads as material condensing rather than an image dissolving.
//
//   0 = fully absent, 1 = fully present. Animate it; everything below follows.
 float uDiffusion;

// ---- morphing / element merge (SwiftUI glassEffectID) ---------------------
// Two glass elements flowing into one as they approach. Apple does this in the
// CONTAINER, not per element: GlassGroupDescriptor / GlassGroupLayerView /
// NSGlassEffectContainerViewAutomaticallySplitsGroups all point at "group the
// shapes, rasterize once". There is no smin anywhere in QuartzCore's AIR — the
// combined shape is handed to the same shader as a single field.
//
// So: union the shapes here, then shade the result once. Set uShape2Enable to 0
// for a single element.
// Up to 3 extra shapes (4 total), folded one at a time. Apple's container
// handles N and splits groups automatically; a fold is the same operation
// repeated, and smin is associative enough that fold order does not matter
// visually for typical layouts.
 float uExtraCount;        // 0..3
 vec4  uShape2;            // (center.xy, halfSize.xy), pixels, relative to center
 vec4  uShape3;
 vec4  uShape4;
 float uMergeK;            // meniscus width in px. 0 = hard union (visible seam).
                           // Keep CONSTANT — scaling it with the gap bridges
                           // shapes that should still be apart.

// ---- outer rim glint ------------------------------------------------------
// FITTED from a real capture: the residual (real - ours) along the rim is
//     0.0856 * exp(-d / 1.50)
// i.e. a very SHARP bright edge, ~1.5px, not a soft 4px glow.
//
// This is applied AFTER compositing (see main). A glint is emissive; multiplying
// it by coverage — which is ~0.5 at the outermost pixel — cancels it exactly
// where it should be strongest. Applying it pre-composite is why raising the
// gain never landed.
 float uRimGlintGain;      // ~0.10 for the fitted look
 float uRimGlintTau;       // ~1.5 px falloff

// ===========================================================================
// macOS 27 additions. Decoded from build 26A5388g's QuartzCore metallib,
// extracted straight from the IPSW (see ../ipsw27/MACOS27.md). Field names are
// exact; these three groups do not exist in macOS 26 at all.
// ===========================================================================

// ---- ring shadow ----------------------------------------------------------
// An inner stroked shadow: a soft band between `radius` and
// `radius + stroke_width`. Computed as erfc(inner) - erfc(outer) using the SAME
// polynomial as the drop shadow — a difference of two Gaussian-integrated
// edges. No blur pass, same as everything else here.
 vec2  uRingShadowOffset;
 float uRingShadowStrokeWidth;
 float uRingShadowRadius;
 float uRingShadowOpacity;
 float uRingShadowMask;

// ---- key fill highlight ---------------------------------------------------
// A directional key light on the FILL, separate from the rim specular. Two
// opposing lobes (+n.l and -n.l) are lit independently and summed, so the
// far side picks up a counter-light rather than going flat.
 vec2  uKeyFillDir;
 float uKeyFillHeight;
 float uKeyFillSpread;      // threshold; remap is (x - spread)/(1 - spread)
 float uKeyFillAmount;      // drives the rational tone curve, see below
 float uKeyFillEffectOffset;
 float uKeyFillColorBias;

// ---- blur fill ------------------------------------------------------------
// A blur-driven fill composited through THREE blend modes at once. The
// lighten/darken/base weights form a partition of unity, then the result lerps
// toward straight normal blend. One formula spans every mix.
 float uBlurFillBlurRadius;
 float uBlurFillLightenOpacity;
 float uBlurFillDarkenOpacity;
 float uBlurFillNormalOpacity;

};

const float EPS    = 1.0e-4;   // Apple: 0x3F1A36E2E0000000
const float TINY   = 1.0e-6;   // Apple: 0x3EB0C6F7A0000000

// =============================================================================
// Superellipse (squircle) SDF.
//
// Apple's symbol is CA::OGL::Metal::ShaderUtils_<T>::supercircle_sdf. Using
// border-radius geometry instead will not match at the corners — a squircle's
// curvature is continuous, a rounded rect's is not, and the eye catches it.
//
// The implicit function is not unit-gradient, so we divide by |grad| to recover
// a true distance. Apple does exactly this in sdf_glass_highlight (and notably
// does NOT do it in sdf_glass_displacement).
// =============================================================================
void supercircleSDF(vec2 p, vec2 halfSize, float n, out float dist, out vec2 normal)
{
    vec2  q  = p / halfSize;
    vec2  a  = max(abs(q), vec2(TINY));

    float xn = pow(a.x, n);
    float yn = pow(a.y, n);
    float s  = xn + yn;

    float f  = pow(s, 1.0 / n) - 1.0;               // <0 inside, >0 outside

    // Analytic gradient: d/dq (s^(1/n)) = q^(n-1) * s^(1/n - 1)
    float k  = pow(s, 1.0 / n - 1.0);
    vec2  g  = k * sign(q) * vec2(pow(a.x, n - 1.0), pow(a.y, n - 1.0));
    g /= halfSize;                                   // chain rule into pixel space

    float gl = max(length(g), TINY);

    // GUARD: the gradient vanishes at the exact center of the element, so the
    // naive f/|grad| normalization blows up to ~-1e6 there. Found by rendering,
    // not by compiling — it produces garbage `dist` across the whole interior
    // and silently kills the blur ramp (every LOD saturates).
    //
    // Clamp to the inradius: you cannot be deeper inside a shape than its
    // narrowest half-extent, so this is exact everywhere it matters and merely
    // sane in the degenerate center.
    float inradius = min(halfSize.x, halfSize.y);
    dist   = clamp(f / gl, -inradius, inradius * 4.0);
    normal = g / gl;                                 // unit outward normal
}

// =============================================================================
// Smooth union — the morph.
//
// Polynomial smin. The `- k*h*(1-h)` term is what creates the meniscus: the
// bridge of material that forms between two shapes before they touch, exactly
// like surface tension pulling two droplets together. A plain min() gives a
// hard union with a visible seam and reads as two overlapping shapes, not one
// merging body.
//
// The NORMAL must be blended by the same factor h, or the refraction will still
// trace the original two silhouettes through a shape that has visually fused —
// the single most common way a morph looks wrong while the outline looks right.
// =============================================================================
void smoothUnion(float d1, vec2 n1, float d2, vec2 n2, float k,
                 out float d, out vec2 n)
{
    k = max(k, EPS);
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    d = mix(d2, d1, h) - k * h * (1.0 - h);
    n = normalize(mix(n2, n1, h) + vec2(EPS, 0.0));
}

// One-pixel analytic antialiasing. Resolution independent, no AA texture, no
// supersampling. Apple uses this everywhere; it is the whole AA strategy.
float aaStep(float x)
{
    float w = max(fwidth(x), EPS);
    return clamp(x / w + 0.5, 0.0, 1.0);
}

// =============================================================================
// The lens curve.
//
//     curve(t) = sqrt(1 - (1-t)^2)  ==  sqrt((2-t)*t)
//
// The upper arc of a unit circle. Displacement is driven by (amount - curve*amount),
// so it is STRONGEST at the rim and decays to zero toward the center along a
// circular arc — which is how a real chamfered glass edge bends light.
//
// Apple ships the sqrt((2-t)*t) spelling (one subtract cheaper). Both appear in
// the binary; they are algebraically identical.
// =============================================================================
float lensCurve(float t)
{
    t = clamp(t, 0.0, 1.0);
    return clamp(sqrt((2.0 - t) * t), 0.0, 1.0);
}

// Displacement magnitude for one refraction lobe.
float refractLobe(float dist, float amount, float invHeight, float offset)
{
    float t = clamp((-dist - offset) * invHeight, 0.0, 1.0);
    return amount - lensCurve(t) * amount;   // == amount * (1 - curve)
}

// =============================================================================
// Blur radius -> mip level.
//
//     lod = max(0, log2(r < 2 ? r*0.5 + 1 : r))
//
// The r<2 branch keeps the curve smooth near zero instead of diving to -inf.
// Verbatim from the shipping shader. This is why the blur costs nothing.
// =============================================================================
float blurLOD(float radius)
{
    float r = (radius < 2.0) ? (radius * 0.5 + 1.0) : radius;
    return max(0.0, log2(max(r, TINY)));
}

vec4 sampleBackdrop(vec2 uv, float radius)
{
    return textureLod(uBackdrop, uv, blurLOD(radius));
}

// Piecewise-linear remap of distance through the 4 blur control points,
// producing an effective blur radius.
float blurRampRadius(float dist, float blurScale)
{
    vec3 lo   = uBlurDist.yzw;
    vec3 hi   = vec3(uBlurDist.x, uBlurDist.y, uBlurDist.z);
    vec3 span = hi - lo;
    // Guard degenerate spans without vector comparison operators (not valid in
    // GLSL 330 / ES 3.0): step() gives 1.0 where |span| <= TINY.
    vec3 degen = step(abs(span), vec3(TINY));
    vec3 inv   = 1.0 / mix(span, vec3(TINY), degen);
    vec3 t    = clamp((vec3(dist) - lo) * inv, 0.0, 1.0);
    vec3 w    = uBlurAlpha.yzw * t;
    return (uBlurAlpha.x - (w.x + w.y + w.z)) * uBlurRadius * blurScale;
}

// =============================================================================
// Analytic shadow falloff.
//
// A degree-7 minimax polynomial approximating 0.5*erfc(x) over x in [-2,2] —
// i.e. the exact convolution of a step edge with a Gaussian. This replaces a
// blur pass entirely.
//
// Coefficients decoded from fp16 immediates in the shipping binary:
//   0xH1A0D =  0.002954   0xHA869 = -0.034460
//   0xH3162 =  0.168210   0xHB87C = -0.560550   0xH3800 = 0.5
//
// The leading 0.56055 is a fitted stand-in for 1/sqrt(pi) = 0.564190.
// =============================================================================
float shadowFalloff(float d, float invRadius)
{
    float u = clamp(0.25 * (d * invRadius) + 0.5, 0.0, 1.0);
    float x = 4.0 * u - 2.0;                    // remap to [-2, 2]
    float x2 = x * x;

    float p = 0.002954;
    p = p * x2 - 0.034460;
    p = p * x2 + 0.168210;
    p = p * x2 - 0.560550;
    return p * x + 0.5;
}

// Unpremultiply, then apply a 3x4 color matrix. Apple guards against denormals
// by flushing components below ~1e-6 to zero before the matrix — without it,
// division by a near-zero alpha produces fireflies on the rim.
// =============================================================================
// Specular rim highlight — port of sdf_glass_highlight.
//
// Three things here are load-bearing and easy to get wrong:
//
//  1. `dist` must already be TRUE-distance normalized (divided by |grad|).
//     supercircleSDF() does this. Apple's displacement path deliberately skips
//     the normalization; the highlight does not, because a specular band is far
//     more sensitive to width error — skip it and the glint visibly fattens at
//     the squircle corners.
//
//  2. The n.l remap `saturate((ndotl - thr) / (1 - thr))` is what turns a broad
//     Lambert wash into a tight glint. Without it the rim just looks bright.
//
//  3. Contributions below epsilon are discarded, not blended.
// =============================================================================
float glassHighlight(float dist, vec2 normal)
{
    float t = clamp(dist / max(uHighlightHeight, TINY), 0.0, 1.0);

    // Blend a hard step against a linear ramp — controls band-edge softness.
    float hard = (t < 1.0) ? 1.0 : 0.0;
    float band = mix(hard, 1.0 - t, clamp(uHighlightSoftness, 0.0, 1.0));

    // Same 1px analytic AA on both sides of the band.
    float w     = max(fwidth(dist), EPS);
    float inner = clamp(dist / w + 0.5, 0.0, 1.0);
    float outer = clamp((uHighlightHeight - dist) / w + 0.5, 0.0, 1.0);
    float mask  = inner * band * outer;

    float ndotl = dot(uLightDir, normal);
    float spec  = clamp((ndotl - uHighlightThreshold)
                        / max(1.0 - uHighlightThreshold, EPS), 0.0, 1.0);

    float v = (dist < -5.0) ? 0.0 : mask * spec;
    return v * uHighlightIntensity;
}

// =============================================================================
// macOS 27: ring shadow.
//
// A soft stroked band, as the DIFFERENCE OF TWO erfc EDGES:
//
//     ring = erfc(d / radius) - erfc((d + stroke) / radius)
//
// Both evaluated with the same degree-7 polynomial as shadowFalloff(), and both
// pre-scaled by 1/sqrt(2) (0x3FE6A09020000000 in the binary) — the standard
// conversion between erf and the normal CDF.
//
// Subtracting two soft steps is how you get a soft *band* for free. No second
// blur, no extra texture read.
// =============================================================================
float ringShadow(float dist)
{
    float invR   = 1.0 / max(uRingShadowRadius, TINY);
    float inner  = dist * invR;
    float outer  = inner + uRingShadowStrokeWidth * invR;
    const float INV_SQRT2 = 0.70710678;
    // shadowFalloff() already folds in the /sqrt(2) remap via its own scaling,
    // so feed it the pre-scaled distances with unit inverse-radius.
    float a = shadowFalloff(inner * INV_SQRT2, 1.0);
    float b = shadowFalloff(outer * INV_SQRT2, 1.0);
    return clamp(a - b, 0.0, 1.0) * uRingShadowOpacity;
}

// =============================================================================
// macOS 27: key fill highlight.
//
// Two OPPOSING lobes from one direction vector:
//
//     lobe = saturate((±dot(dir, n) - spread) / (1 - spread)) * height
//     out  = sum over both lobes of  lobe / (amount*(1 - lobe) + 1)
//
// The +/- pair means the surface facing away from the key still receives a
// counter-lobe, so the fill reads as lit from both sides rather than falling to
// black. Summing (not maxing) is what the binary does.
//
// That rational curve is a soft-knee compressor: identity at amount = 0, and as
// amount rises it lifts midtones while asymptotically approaching 1, so the
// highlight never clips. Cheaper than a pow() and monotonic.
// =============================================================================
float keyFillHighlight(vec2 normal, float heightMask)
{
    float spread = clamp(uKeyFillSpread, 0.0, 0.999);
    float invS   = 1.0 / max(1.0 - spread, TINY);
    float nl     = dot(uKeyFillDir, normal);

    vec2 lobes = clamp((vec2(nl, -nl) - vec2(spread)) * invS, 0.0, 1.0) * heightMask;
    vec2 curved = lobes / max(uKeyFillAmount * (1.0 - lobes) + 1.0, vec2(TINY));
    return curved.x + curved.y;
}

// =============================================================================
// macOS 27: blur fill.
//
//     mixed = lightenOp*max(base,fill) + darkenOp*min(base,fill)
//           + (1 - lightenOp - darkenOp)*base
//     out   = mix(mixed, fill, normalOp)
//
// The three weights are a partition of unity, so any combination of
// lighten/darken/normal is expressible without branching or mode switching.
// =============================================================================
vec3 blurFill(vec3 base, vec3 fill)
{
    vec3 lighten = max(base, fill);
    vec3 darken  = min(base, fill);
    float wBase  = 1.0 - uBlurFillLightenOpacity - uBlurFillDarkenOpacity;
    vec3 mixed   = uBlurFillLightenOpacity * lighten
                 + uBlurFillDarkenOpacity  * darken
                 + wBase                   * base;
    return mix(mixed, fill, clamp(uBlurFillNormalOpacity, 0.0, 1.0));
}

vec3 gradeUnpremultiplied(vec4 c, vec4 r0, vec4 r1, vec4 r2)
{
    float a   = max(c.a, TINY);
    vec3  rgb = c.rgb / a;
    // Flush denormals to zero. step(TINY, |rgb|) is 1.0 where the component is
    // large enough to keep. Avoids mix()-with-bvec, which needs GLSL 4.5.
    rgb *= step(vec3(TINY), abs(rgb));
    // Row-major 3x4: each row's .xyz dots the color, .w is the additive bias.
    return vec3(dot(rgb, r0.xyz) + r0.w,
                dot(rgb, r1.xyz) + r1.w,
                dot(rgb, r2.xyz) + r2.w);
}

// =============================================================================
// Diffusion — the appear/disappear transition.
//
// Modelled, not decoded: the shader has no animation state, and Apple drives
// this from AppKit/SwiftUI. What makes it read as *glass* appearing rather than
// an image cross-fading is that the optical properties ramp at DIFFERENT rates:
//
//   - refraction leads       (d^0.55) — the rim bends light before the body fills
//   - blur follows           (d^1.30) — sharp -> blurred as it thickens
//   - body opacity lags      (d^1.60) — tint arrives last
//   - the shape also scales slightly, so it grows into place
//
// Fading all of them together gives a ghost of the final frame. Staggering them
// gives condensation. That stagger is the whole trick.
// =============================================================================
float diffusionCurve(float d, float power)
{
    return pow(clamp(d, 0.0, 1.0), power);
}

void main()
{
    float d01 = clamp(uDiffusion, 0.0, 1.0);
    if (d01 <= 0.0) discard;                 // fully absent: nothing to draw

    float dRefract = diffusionCurve(d01, 0.55);
    float dBlur    = diffusionCurve(d01, 1.30);
    float dBody    = diffusionCurve(d01, 1.60);

    // Grow into place: 96% -> 100% of final size. Subtle on purpose; more than
    // a few percent reads as a zoom rather than as material forming.
    vec2  animHalf = uHalfSize * mix(0.96, 1.0, diffusionCurve(d01, 0.8));

    // Pixels -> normalized UV. Every displacement below is authored in pixels.
    vec2 texel = 1.0 / vec2(textureSize(uBackdrop, 0));

    float dist;
    vec2  normal;
    supercircleSDF(vUV, animHalf, uExponent, dist, normal);

    // Merge the second shape in before ANY shading happens. Everything
    // downstream — refraction, bleed, shadow, highlight — then operates on one
    // combined field and cannot tell it was ever two shapes. That ordering is
    // the whole reason the merge looks like one body of glass.
    int extras = int(clamp(uExtraCount, 0.0, 3.0));
    for (int i = 0; i < 3; ++i) {
        if (i >= extras) break;
        vec4 sh = (i == 0) ? uShape2 : ((i == 1) ? uShape3 : uShape4);
        float d2;
        vec2  n2;
        supercircleSDF(vUV - sh.xy, sh.zw * mix(0.96, 1.0, d01),
                       uExponent, d2, n2);
        smoothUnion(dist, normal, d2, n2, uMergeK, dist, normal);
    }

    // Push the normal through the rotation, then the 2x2 displacement matrix.
    // Two chained transforms: the angle spins it, the matrix can scale/skew for
    // non-uniform lensing.
    vec2 rot = vec2(dot(normal, vec2( uRefractAngle.x, -uRefractAngle.y)),
                    dot(normal, vec2( uRefractAngle.y,  uRefractAngle.x)));
    vec2 disp = vec2(dot(rot, uDisplacementMat.xy),
                     dot(rot, uDisplacementMat.zw));

    // ---- inner lobe -------------------------------------------------------
    float innerMag  = refractLobe(dist, uInnerRefractAmount * dRefract, uInnerRefractInvHeight, 0.0);
    float innerDist = innerMag + dist;
    vec2  innerUV   = vBackdropUV + innerMag * disp * texel;
    float faceLod   = blurRampRadius(innerDist, dBlur);
    vec4  faceCol   = sampleBackdrop(innerUV, faceLod);

    // ---- outer lobe (the two-sided part) ----------------------------------
    if (uRefractOpacity > 0.0 && uComplexRefraction > 0.5) {
        float outerMag  = refractLobe(dist, uOuterRefractAmount * dRefract, uOuterRefractInvHeight, 0.0);
        float outerDist = outerMag + dist;
        vec2  outerUV   = vBackdropUV + outerMag * disp * texel;
        vec4  outerCol  = sampleBackdrop(outerUV, blurRampRadius(outerDist, dBlur));

        // EXACT: the blend is not flat. It ramps across [threshold0, threshold1]
        // in distance, then scales by refraction_opacity. A constant mix() puts
        // the lobe crossover in the wrong place and flattens the rim.
        float span = uRefractThreshold.y - uRefractThreshold.x;
        float t    = clamp((dist - uRefractThreshold.x)
                           / (abs(span) < TINY ? TINY : span), 0.0, 1.0);
        faceCol = mix(faceCol, outerCol, t * uRefractOpacity);
    }

    // ---- chromatic aberration --------------------------------------------
    // Four taps stepping by exactly 1/3 along an independently-rotated vector,
    // each weighted toward a different part of the spectrum. A cheap stand-in
    // for a real dispersion integral.
    // EXACT — transcribed from the shipping IR, not approximated.
    //
    // Two loops walking in OPPOSITE directions along the aberration vector.
    // Red is dragged one way, blue the other, green straddles both. That
    // opposition is real dispersion; a single-direction smear is not.
    //
    //   Loop A: 3 taps FORWARD  at uv + w*offA,  w = 1, 2/3, 1/3
    //             R += (r/a)*w        G += (g/a)*(1-w)     A += a
    //   Loop B: 4 taps BACKWARD at uv - s*offA,  s = 0, 1/3, 2/3, 1
    //             G += (g/a)*(1-s)    B += (b/a)*s         A += a
    //
    // Per-channel weight sums are 2 (R), 3 (G), 2 (B). The final normalizer
    // (0.5, 1/3, 0.5) takes each to exactly 1.0 — which is how we know the
    // transcription is right. Alpha sums over all 7 taps, hence the 1/7.
    float aberrAlpha = 1.0;
    if (uAberrationAmount > 0.0) {
        vec2 rotA = vec2(dot(normal, vec2( uAberrationAngle.x, -uAberrationAngle.y)),
                         dot(normal, vec2( uAberrationAngle.y,  uAberrationAngle.x)));
        // note the swap: aberration pushes along a different axis than refraction
        vec2 dispA = vec2(dot(rotA, uDisplacementMat.zw),
                          dot(rotA, uDisplacementMat.xy));
        vec2 offA = dispA * refractLobe(dist, uAberrationAmount,
                                        uAberrationInvHeight, uAberrationOffset);

        vec3  acc  = vec3(0.0);
        float aSum = 0.0;

        // Loop A — forward, 3 taps. Feeds R and G.
        float w = 1.0;
        for (int i = 0; i < 3; ++i) {
            vec4  s  = sampleBackdrop(innerUV + offA * w * texel, faceLod);
            float a  = max(s.a, TINY);
            acc.r   += (s.r / a) * w;
            acc.g   += (s.g / a) * (1.0 - w);
            aSum    += s.a;
            w -= 1.0 / 3.0;
        }
        // Loop B — backward, 4 taps. Feeds G and B.
        float sstep = 0.0;
        for (int i = 0; i < 4; ++i) {
            vec4  s  = sampleBackdrop(innerUV - offA * sstep * texel, faceLod);
            float a  = max(s.a, TINY);
            acc.g   += (s.g / a) * (1.0 - sstep);
            acc.b   += (s.b / a) * sstep;
            aSum    += s.a;
            sstep += 1.0 / 3.0;
        }

        // Normalizers that take each channel's weight sum to exactly 1.0.
        acc *= vec3(0.5, 1.0 / 3.0, 0.5);
        aberrAlpha = aSum * (1.0 / 7.0);
        faceCol = vec4(acc, aberrAlpha);
    }

    vec3 face = gradeUnpremultiplied(faceCol, uFaceCM0, uFaceCM1, uFaceCM2) * (uFaceOpacity * dBody);

    // ---- edge bleed -------------------------------------------------------
    // Wider blur, sampled only within a band near the rim, tinted separately and
    // darkened. This is what sells "wet".
    vec3 bleed = vec3(0.0);
    float bleedMask = 0.0;
    if (uEdgeBleedAmount > 0.0) {
        float bt = clamp((-dist) * uEdgeBleedInvHeight, 0.0, 1.0);
        float bmag = uEdgeBleedAmount - lensCurve(bt) * uEdgeBleedAmount;
        vec4 bcol = sampleBackdrop(vBackdropUV + bmag * disp * texel, uEdgeBleedBlurRadius);
        bleed = gradeUnpremultiplied(bcol, uBleedCM0, uBleedCM1, uBleedCM2);
        bleed = bleed * uBleedDarken.x + vec3(uBleedDarken.y);

        // INVERTED on purpose. `-dist` grows large toward the centre, so a
        // plain smoothstep saturates to 1 in the BODY and 0 at the rim — the
        // exact opposite of an edge bleed. Un-inverted, it washes the whole
        // element with the wide rim blur instead of hugging the edge.
        float band = 1.0 - smoothstep(uEdgeBleedDist.x, uEdgeBleedDist.y, -dist);
        bleedMask  = band * uEdgeBleedOpacity;
    }

    // ---- shadow -----------------------------------------------------------
    // The shadow is REFRACTED too — displaced by the same circular profile, not
    // just offset. Easy to miss, and it is why the shadow tracks the glass
    // instead of sliding under it.
    vec3  shadow    = vec3(0.0);
    float shadowMask = 0.0;
    if (uShadowContribution > TINY) {
        float smag = refractLobe(dist, uShadowAmount, uShadowInvHeight, uShadowDistOffset);
        vec2  suv  = vBackdropUV + (smag * disp + uShadowOffset) * texel;
        vec4  scol = sampleBackdrop(suv, uShadowAmount);
        shadow     = gradeUnpremultiplied(scol, uShadowCM0, uShadowCM1, uShadowCM2)
                   * uShadowContribution;
        // Gated to OUTSIDE the shape. A drop shadow falls on what is behind the
        // element, not through its face; without step(0.0, dist) the falloff
        // saturates across the whole interior and darkens the body uniformly.
        shadowMask = shadowFalloff(dist, uShadowInvRadius)
                   * uShadowOpacity * step(0.0, dist);
    }

    // ---- composite --------------------------------------------------------
    vec3 rgb = mix(face, bleed, bleedMask);
    rgb = mix(rgb, shadow, shadowMask);

    // ---- HDR tone holding -------------------------------------------------
    // Glass over HDR content blows out at the rim without this. Clamp toward
    // SDR white while optionally preserving hue by scaling all three channels
    // by the same factor rather than clipping each independently.
    if (uClampLimit > 0.0) {
        float peak = max(max(rgb.r, rgb.g), rgb.b) / max(uSDRWhite * uEDRScale, TINY);
        if (peak > uClampLimit) {
            float k = uClampLimit / peak;
            rgb = mix(min(rgb, vec3(uClampLimit)), rgb * k, uPreserveHue);
        }
    }

    // ---- macOS 27: blur fill ----------------------------------------------
    // A second, independently-blurred sample of the backdrop, composited
    // through lighten/darken/normal simultaneously.
    if (uBlurFillNormalOpacity > 0.0 || uBlurFillLightenOpacity > 0.0
        || uBlurFillDarkenOpacity > 0.0) {
        vec4 fillSample = sampleBackdrop(vBackdropUV, uBlurFillBlurRadius);
        vec3 fill = gradeUnpremultiplied(fillSample, uFaceCM0, uFaceCM1, uFaceCM2);
        rgb = blurFill(rgb, fill);
    }

    // ---- macOS 27: key fill highlight -------------------------------------
    // Directional light on the fill. Height-masked so it lives in the body,
    // not the rim — that is what separates it from the specular below.
    // Gate on AMOUNT only. Gating on `|| uKeyFillHeight > 0.0` runs the block
    // whenever a height is configured, and at amount 0 the rational curve
    // x/(a(1-x)+1) degenerates to x — i.e. the two opposing lobes at FULL
    // strength. That paints a hard bowtie across the element's normal field
    // even though the effect is nominally disabled.
    if (uKeyFillAmount > 0.0) {
        float hMask = clamp((-dist - uKeyFillEffectOffset)
                            / max(uKeyFillHeight, TINY), 0.0, 1.0);
        float key = keyFillHighlight(normal, hMask);
        rgb += vec3(key) * mix(1.0, 0.5, clamp(uKeyFillColorBias, 0.0, 1.0));
    }

    // ---- specular rim -----------------------------------------------------
    // Added, not blended — a glint is emissive, so it should blow past the
    // face rather than replace it.
    if (uHighlightIntensity > 0.0) {
        rgb += vec3(glassHighlight(-dist, normal));
    }

    // ---- macOS 27: ring shadow --------------------------------------------
    // Inner stroked shadow. Darkens rather than adds, and is masked so it can
    // be confined to part of the shape.
    if (uRingShadowOpacity > 0.0) {
        float ring = ringShadow(-dist - uRingShadowOffset.x)
                   * clamp(uRingShadowMask, 0.0, 1.0);
        rgb *= (1.0 - ring);
    }

    // ---- edge fade --------------------------------------------------------
    // EXACT, including the inversion: the shader multiplies by
    // (1 - mix(start, end, t)), so these uniforms REMOVE opacity across the
    // band rather than adding it. Getting the sign backwards here silently
    // inverts the whole rim falloff.
    float edgeSpan = uEdgeRange.y - uEdgeRange.x;
    float edgeT    = clamp((dist - uEdgeRange.x)
                           / (abs(edgeSpan) < TINY ? TINY : edgeSpan), 0.0, 1.0);
    float edgeFade = 1.0 - mix(uEdgeOpacity.x, uEdgeOpacity.y, edgeT);

    // Same coverage/AA the original uses, and the same early-out: fragments
    // contributing nothing are discarded rather than blended.
    float coverage = aaStep(-dist) * edgeFade * dBody;
    if (coverage < TINY) discard;

    // ---- outer rim glint, POST-coverage -----------------------------------
    // Premultiplied by nothing and added on top: emissive, so it must not be
    // attenuated by coverage. Fitted gain/falloff — see the uniform block.
    if (uRimGlintGain > 0.0) {
        float glint = exp(-abs(dist) / max(uRimGlintTau, EPS))
                    * step(dist, 2.0) * dBody;
        rgb += vec3(glint * uRimGlintGain / max(coverage, 0.25));
    }

    fragColor = vec4(rgb, coverage);
}
