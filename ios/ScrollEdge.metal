#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct ScrollEdgeParams
{
    float uMaxRadius;
    float uThreshold;
    float2 uTexel;
    float uStyle;
    float uOpacity;
    float2 _pad;
};

struct main0_out
{
    float4 fragColor [[color(0)]];
};

struct main0_in
{
    float2 vUV [[user(locn0)]];
    float2 vMaskUV [[user(locn1)]];
};

static inline __attribute__((always_inline))
float blurLOD(thread float& r)
{
    float _25;
    if (r < 2.0)
    {
        _25 = (r * 0.5) + 1.0;
    }
    else
    {
        _25 = r;
    }
    r = _25;
    return fast::max(0.0, log2(fast::max(r, 9.9999999747524270787835121154785e-07)));
}

static inline __attribute__((always_inline))
float4 crossTap(thread const float2& uv, thread const float2& step_, thread const float& lod, texture2d<float> uContent, sampler uContentSmplr)
{
    float4 a = ((uContent.sample(uContentSmplr, (uv + float2(-step_.x, -step_.y)), level(lod)) + uContent.sample(uContentSmplr, (uv + float2(step_.x, -step_.y)), level(lod))) + uContent.sample(uContentSmplr, (uv + float2(-step_.x, step_.y)), level(lod))) + uContent.sample(uContentSmplr, (uv + float2(step_.x, step_.y)), level(lod));
    a *= 0.25;
    float4 b = ((uContent.sample(uContentSmplr, (uv + float2((-step_.x) * 2.0, 0.0)), level(lod)) + uContent.sample(uContentSmplr, (uv + float2(step_.x * 2.0, 0.0)), level(lod))) + uContent.sample(uContentSmplr, (uv + float2(0.0, (-step_.y) * 2.0)), level(lod))) + uContent.sample(uContentSmplr, (uv + float2(0.0, step_.y * 2.0)), level(lod));
    b *= 0.25;
    return mix(a, b, float4(0.5));
}

fragment main0_out main0(main0_in in [[stage_in]], constant ScrollEdgeParams& _166 [[buffer(0)]], texture2d<float> uContent [[texture(0)]], texture2d<float> uMask [[texture(1)]], sampler uContentSmplr [[sampler(0)]], sampler uMaskSmplr [[sampler(1)]])
{
    main0_out out = {};
    float m = fast::clamp(uMask.sample(uMaskSmplr, in.vMaskUV).w, 0.0, 1.0);
    float _173;
    if (_166.uStyle > 0.5)
    {
        _173 = step(_166.uThreshold, m);
    }
    else
    {
        _173 = smoothstep(_166.uThreshold, 1.0, m);
    }
    float t = _173;
    float radius = _166.uMaxRadius * t;
    if (radius < 0.5)
    {
        out.fragColor = uContent.sample(uContentSmplr, in.vUV);
        return out;
    }
    float param = radius;
    float _207 = blurLOD(param);
    float lod = _207;
    float2 step_ = (_166.uTexel * radius) * 0.5;
    float2 param_1 = in.vUV;
    float2 param_2 = step_;
    float param_3 = lod;
    float4 blurred = crossTap(param_1, param_2, param_3, uContent, uContentSmplr);
    out.fragColor = mix(uContent.sample(uContentSmplr, in.vUV), blurred, float4(t * _166.uOpacity));
    return out;
}

