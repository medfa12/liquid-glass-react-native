#version 300 es
precision mediump float;
precision highp int;

layout(std140) uniform ScrollEdgeParams
{
    highp float uMaxRadius;
    highp float uThreshold;
    highp vec2 uTexel;
    highp float uStyle;
    highp float uOpacity;
    highp vec2 _pad;
} _166;

uniform highp sampler2D uContent;
uniform highp sampler2D uMask;

in highp vec2 vMaskUV;
layout(location = 0) out highp vec4 fragColor;
in highp vec2 vUV;

highp float blurLOD(inout highp float r)
{
    highp float _25;
    if (r < 2.0)
    {
        _25 = (r * 0.5) + 1.0;
    }
    else
    {
        _25 = r;
    }
    r = _25;
    return max(0.0, log2(max(r, 9.9999999747524270787835121154785e-07)));
}

highp vec4 crossTap(highp vec2 uv, highp vec2 step_, highp float lod)
{
    highp vec4 a = ((textureLod(uContent, uv + vec2(-step_.x, -step_.y), lod) + textureLod(uContent, uv + vec2(step_.x, -step_.y), lod)) + textureLod(uContent, uv + vec2(-step_.x, step_.y), lod)) + textureLod(uContent, uv + vec2(step_.x, step_.y), lod);
    a *= 0.25;
    highp vec4 b = ((textureLod(uContent, uv + vec2((-step_.x) * 2.0, 0.0), lod) + textureLod(uContent, uv + vec2(step_.x * 2.0, 0.0), lod)) + textureLod(uContent, uv + vec2(0.0, (-step_.y) * 2.0), lod)) + textureLod(uContent, uv + vec2(0.0, step_.y * 2.0), lod);
    b *= 0.25;
    return mix(a, b, vec4(0.5));
}

void main()
{
    highp float m = clamp(texture(uMask, vMaskUV).w, 0.0, 1.0);
    highp float _173;
    if (_166.uStyle > 0.5)
    {
        _173 = step(_166.uThreshold, m);
    }
    else
    {
        _173 = smoothstep(_166.uThreshold, 1.0, m);
    }
    highp float t = _173;
    highp float radius = _166.uMaxRadius * t;
    if (radius < 0.5)
    {
        fragColor = texture(uContent, vUV);
        return;
    }
    highp float param = radius;
    highp float _207 = blurLOD(param);
    highp float lod = _207;
    highp vec2 step_ = (_166.uTexel * radius) * 0.5;
    highp vec2 param_1 = vUV;
    highp vec2 param_2 = step_;
    highp float param_3 = lod;
    highp vec4 blurred = crossTap(param_1, param_2, param_3);
    fragColor = mix(texture(uContent, vUV), blurred, vec4(t * _166.uOpacity));
}

