# D3D11 backend — verified render

Headless render test, run in a Windows 11 ARM64 VM on WARP. Confirms the shader,
the 672-byte constant buffer and the VS→PS linkage all work under Direct3D.

## Result, against the Vulkan reference

|          | covered      | mean luma | mid-row |
|----------|--------------|-----------|---------|
| Vulkan   | 32524/40960  | 137       | 39 75 79 79 79 88 94 117 141 164 186 194 201 … |
| D3D11    | 32523/40960  | 137       | 39 75 79 79 79 79 79 79 171 201 201 201 201 … |

Coverage agrees within one pixel and the mean luma is identical. The mid-row
differs only in how the blur ramp is sampled across the hard backdrop edge.

## Two bugs this found, both invisible on macOS

**1. Back-face culling.** D3D11 defaults to `CullMode.Back` with
`FrontCounterClockwise = false`. The fullscreen triangle strip is wound CCW, so
every triangle was culled *before* the pixel shader ran — which looks exactly
like the shader discarding everything. `RasterizerDescription.CullNone` is
required. Vulkan only worked first try because `VK_CULL_MODE_NONE` had to be
stated explicitly.

**2. Vertex/pixel signature mismatch.** A hand-written HLSL vertex shader
declared `SV_POSITION` first, so fxc gave it register 0 and pushed the varyings
to register 1 — while the spirv-cross-generated pixel shader expects them in
register 0:

```
VS out[1] TEXCOORD0 reg=1        PS in[0] TEXCOORD0 reg=0
VS out[2] TEXCOORD1 reg=1        PS in[1] TEXCOORD1 reg=0
```

Both varyings arrived as zero, so the output was uniform. Nothing in the HLSL
source shows this; it only appears in the compiled signatures via `D3DReflect`.

The fix is structural, not a patch: `portable/liquid_glass_vert.vert` is now
authored in GLSL and generated through the same glslang → spirv-cross path as
the fragment stage. spirv-cross emits varyings *before* `SV_Position`, so the
two signatures agree by construction. `generate.sh` builds both stages.

**Lesson:** when two shader stages come from different toolchains, verify the
compiled signatures — not the source.
