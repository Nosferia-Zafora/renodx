// HDR004.pso (shaderpackage013): final HDR composite, drawn straight into the
// back buffer. Vanilla (verified against D3DDisassemble):
//   inv   = 1 / max(dot(AvgLum, 1), HDRParam.x)
//   color = scene * HDRParam.x * inv + max(bloom * 0.5 * inv, 0)
// The scene factor is <= 1, so eye adaptation only ever darkens. A bright sky
// raises AvgLum and darkens everything else; Eye Adaptation scales that back.
#include "./shared.h"

float4 HDRParam : register(c1);
sampler2D Src0 : register(s0);       // bloom (256x256 FP16)
sampler2D DestBlend : register(s1);  // scene (full-res FP16)
sampler2D AvgLum : register(s2);     // 1x1 FP16

float4 main(float2 texcoord0 : TEXCOORD0, float2 texcoord1 : TEXCOORD1) : COLOR {
  float adapted_inverse = 1.f / max(dot(tex2D(AvgLum, texcoord0).rgb, 1.f), HDRParam.x);
  // At full reduction, behave as if AvgLum never exceeded the target (HDRParam.x).
  float inverse = lerp(adapted_inverse, 1.f / HDRParam.x, OBLIVION_EYE_ADAPTATION_REDUCTION);

  float3 bloom = max(tex2D(Src0, texcoord0).rgb * (0.5f * inverse), 0.f);
  float3 scene = tex2D(DestBlend, texcoord1).rgb * (HDRParam.x * inverse);
  return float4(scene + bloom, 1.f);
}
