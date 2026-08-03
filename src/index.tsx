/**
 * Liquid Glass for React Native.
 *
 * Renders through a native view on each platform:
 *   iOS     — MTKView running liquid_glass.metal   (ios/LiquidGlassView.swift)
 *   Android — GLSurfaceView running ES 300         (android/.../LiquidGlassView.kt)
 *
 * Both consume the SAME uniform buffer layout as the web package — the std140
 * offsets come from SPIR-V reflection of the one canonical shader.
 *
 * BACKDROP: unlike the web, in RN you generally cannot read what is behind a
 * native view. Supply an image source explicitly. For the common case of glass
 * over a known background (a photo, a gradient, a video frame) this is what you
 * want anyway. See `backdrop` below.
 */

import React, { useMemo } from 'react';
import {
  requireNativeComponent, Platform, View, StyleSheet,
  type ViewStyle, type StyleProp, type ImageSourcePropType, UIManager,
} from 'react-native';

import { defaultParams, preset, packParams, PARAM_FLOATS } from './params';
import type { GlassParams, PresetName } from './params';

export * from './params';

const COMPONENT = 'LiquidGlassView';

const isAvailable =
  UIManager.getViewManagerConfig?.(COMPONENT) != null &&
  (Platform.OS === 'ios' || Platform.OS === 'android');

interface NativeProps {
  style?: StyleProp<ViewStyle>;
  backdrop?: ImageSourcePropType;
  /** Flat float array matching the std140 UBO. */
  uniforms: number[];
  liveBackdrop?: boolean;
}

const NativeLiquidGlass = isAvailable
  ? requireNativeComponent<NativeProps>(COMPONENT)
  : null;

export interface LiquidGlassProps {
  children?: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  /** Named preset to start from. */
  variant?: PresetName;
  /** Overrides merged over the preset. */
  params?: Partial<GlassParams>;
  /** Backdrop image. Required for the effect to show anything. */
  backdrop?: ImageSourcePropType;
  /** Re-upload every frame (animated / video sources). Costs a texture upload. */
  liveBackdrop?: boolean;
  /** 0 = absent, 1 = fully present. Animate for appear/disappear. */
  diffusion?: number;
  /** Width/height in points. Needed because the shader works in pixels. */
  width: number;
  height: number;
  /** Rendered when the native module is missing (e.g. Expo Go, web). */
  fallback?: React.ReactNode;
}

export const LiquidGlass: React.FC<LiquidGlassProps> = ({
  children, style, variant = 'regular', params, backdrop,
  liveBackdrop = false, diffusion, width, height, fallback,
}) => {
  const uniforms = useMemo(() => {
    const p: GlassParams = { ...(variant ? preset(variant) : defaultParams()), ...params };
    if (diffusion !== undefined) p.diffusion = diffusion;
    p.halfSize = [width / 2, height / 2];
    const buf = new Float32Array(PARAM_FLOATS);
    packParams(p, buf);
    return Array.from(buf);
  }, [variant, params, diffusion, width, height]);

  if (!NativeLiquidGlass) {
    return (
      <View style={[{ width, height }, style]}>
        {fallback ?? <View style={[StyleSheet.absoluteFill, styles.fallback]} />}
        {children}
      </View>
    );
  }

  return (
    <View style={[{ width, height }, style]}>
      <NativeLiquidGlass
        style={StyleSheet.absoluteFill}
        backdrop={backdrop}
        uniforms={uniforms}
        liveBackdrop={liveBackdrop}
      />
      {children}
    </View>
  );
};

const styles = StyleSheet.create({
  fallback: {
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderRadius: 24,
  },
});

/** True when the native view is registered on this platform/build. */
export function isLiquidGlassAvailable(): boolean {
  return isAvailable;
}
export * from './params27.generated';
export * from './ui.generated';
