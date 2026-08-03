# @liquid-glass/react-native

Liquid Glass for React Native — real native rendering on both platforms.
Reverse-engineered from macOS 26/27's QuartzCore shaders; see
[`../README.md`](../README.md).

- **iOS** — `MTKView` running `LiquidGlass.metal` (verified with `xcrun metal -c`)
- **Android** — `GLSurfaceView` running ES 300 (verified with `glslangValidator`)

Uses **no** platform blur API, so it looks identical across OS versions — and
works on iOS versions that predate Liquid Glass entirely.

```bash
npm i @liquid-glass/react-native
cd ios && pod install
```

Android: add `LiquidGlassPackage()` to your `MainApplication` package list.

```tsx
import { LiquidGlass } from '@liquid-glass/react-native';

<LiquidGlass
  width={320}
  height={120}
  variant="regular"
  backdrop={{ uri: 'https://example.com/bg.jpg' }}
>
  <Text style={{ padding: 16 }}>Hello</Text>
</LiquidGlass>
```

## Notes

- `width`/`height` are **required** — the SDF works in pixel space, so the
  element's size has to be known, not inferred from layout.
- `backdrop` is required for the effect to show anything. RN cannot read what is
  behind a native view on either platform.
- Android needs **GLES 3.0** (API 18+; the package targets minSdk 21). The blur
  is `textureLod` against a mip chain and GLES 2 cannot express it.
- Without the native module (Expo Go, web), the component renders a flat scrim.
  That is deliberate — an obviously-different fallback beats a broken-looking
  approximation.

## Adaptive tint (chameleon)

The material — and the content on it — shifts with the backdrop, so symbols stay
legible: **dark glyphs over a bright backdrop, light glyphs over a dark one.**

Apple implements this with a GPU reduction (`tile_average_luma` ->
`compute_sum_luma` -> `compute_average_luma`) using **exactly Rec.709 weights**
(0.212646 / 0.715332 / 0.072205 — decoded from the fp16 immediates 0xH32CE,
0xH39B9, 0xH2C9F). The average is remapped through `luminanceColorMap.png`, a
256-entry curve that is a **logistic centred at 0.5 with k = 10.25**, running
0.349 -> 0.800. That is fit here to a closed form (max error 1.4/255), so no
lookup texture ships.

This implementation skips the reduction pass entirely: the average comes from
the **top mip** of the backdrop, which already exists because the blur needs a
full mip chain. Same number, zero extra passes.

Verified: backdrop luma 0.085 -> glass 0.140; backdrop 0.938 -> glass 0.311.

```
backdrop 0.00-0.35  ->  symbol luma 0.94-0.81   light
backdrop 0.50       ->  symbol luma 0.25        flips to dark
backdrop 0.65-1.00  ->  symbol luma 0.12        dark
```

The flip lands at 0.5 because that is where Apple centred the logistic — the
curve's midpoint *is* the decision point.

Use `adaptiveContentLuma(avgLuma)` to tint your own labels and glyphs from the
same curve the material uses.

## Fidelity

Measured against a real `NSGlassEffectView` capture on macOS 26.5.2, fitted by
coordinate descent driving the actual Metal shader headlessly:

| | |
|---|---|
| MAE | 15.0/255 |
| PSNR | **17.53 dB** |
| scale invariance | 240x150 vs 480x300 agree to 1.7/255 |

**This is not 1:1 with Apple**, and two gaps are structural rather than a matter
of more tuning:

1. The corner curve differs — `exponent = 6.5` (superellipse, fitted to 1011
   boundary pixels) against Apple's continuous curve.
2. macOS 27's material recipes live on the **encrypted** IPSW volume, so the
   three subsystems added in 27 (ring shadow, key fill highlight, blur fill)
   have no ground truth to fit against; their values are modelled, not measured.
