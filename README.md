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
