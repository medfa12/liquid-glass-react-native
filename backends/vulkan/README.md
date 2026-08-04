# Vulkan backend

Headless reference renderer that consumes `portable/generated/liquid_glass.spv`
**verbatim** — no transpile between the canonical GLSL and what executes.

```
brew install molten-vk vulkan-loader vulkan-headers glslang
cd backends/vulkan
glslangValidator -V fullscreen.vert -o fullscreen.vert.spv
cp ../../portable/generated/liquid_glass.spv .
cc -O2 -o vkglass vkglass.c -I/opt/homebrew/include -L/opt/homebrew/lib -lvulkan
VK_ICD_FILENAMES=/opt/homebrew/Cellar/molten-vk/*/etc/vulkan/icd.d/MoltenVK_icd.json \
  ./vkglass liquid_glass.spv
```

## Why this exists

The D3D11 path runs GLSL → SPIR-V → HLSL → fxc → DXBC. Four representations,
four opportunities for a silent divergence, and no way to pin fxc's optimiser.
Vulkan is GLSL → SPIR-V → done.

That is not theoretical. Verified on an Apple M4 via MoltenVK, first run:

```
covered pixels: 32524 / 40960
mid-row luma: 39 75 79 79 79 88 94 117 141 164 186 194 201 201 201 201
```

The mid-row is a hard 0x20|0xE0 backdrop edge resolving into a smooth ramp —
the mip-based blur working through a real sampler. The same SPIR-V, the same
672-byte block and the same parameter values discard every fragment under D3D11,
which localises that bug to the D3D harness or the DXBC, **not** to the shader.

## Fidelity note

Precision matters here — the `f/|grad|` SDF normalisation, the degree-7 erfc
polynomial and the `sqrt((2-t)*t)` lens curve are all sensitive to reassociation.
SPIR-V lets precision be pinned per-operation; fxc does not expose that.

## Not done

* No swapchain/windowing — offscreen only. WinUI embedding still needs D3D,
  because XAML's SwapChainPanel is D3D-backed.
* Not run on Windows: the test VM's VirtIO GPU is display-only and Windows-on-ARM
  has no software Vulkan ICD (lavapipe does not ship for it). D3D at least had
  WARP.
* `params_init.h` is generated from the SPIR-V reflection; regenerate it whenever
  the uniform block changes.
