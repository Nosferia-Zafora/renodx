// HDR004.pso (shaderpackage013): final HDR composite, drawn straight into the
// back buffer. Vanilla (verified against D3DDisassemble):
//   inv   = 1 / max(dot(AvgLum, 1), HDRParam.x)
//   color = scene * HDRParam.x * inv + max(bloom * 0.5 * inv, 0)
// The scene factor is <= 1, so eye adaptation only ever darkens. A bright sky
// raises AvgLum and darkens everything else. Eye Adaptation pulls AvgLum
// toward a fixed daylight reference in log space, which damps how strongly
// exposure reacts without moving the base exposure. HDRParam.x is not used
// as a reference: its value is game-driven and unmeasured.
#include "./shared.h"

// AvgLum (sum of channels) measured in a vanilla daylight scene with the DevKit.
static const float AVG_LUM_REFERENCE = 1.11f;

float4 HDRParam : register(c1);
sampler2D Src0 : register(s0);       // bloom (256x256 FP16)
sampler2D DestBlend : register(s1);  // scene (full-res FP16)
sampler2D AvgLum : register(s2);     // 1x1 FP16

float4 main(float2 texcoord0 : TEXCOORD0, float2 texcoord1 : TEXCOORD1) : COLOR {
  float avg_lum = max(dot(tex2D(AvgLum, texcoord0).rgb, 1.f), 1e-4f);
  // Only damp views brighter than the reference (sky, sun); night and
  // interiors keep vanilla exposure.
  float damped_avg_lum = exp2(lerp(log2(avg_lum), log2(AVG_LUM_REFERENCE), OBLIVION_EYE_ADAPTATION_REDUCTION));
  avg_lum = (avg_lum > AVG_LUM_REFERENCE) ? damped_avg_lum : avg_lum;
  float inverse = 1.f / max(avg_lum, HDRParam.x);

  float3 bloom = max(tex2D(Src0, texcoord0).rgb * (0.5f * inverse), 0.f);
  float3 scene = tex2D(DestBlend, texcoord1).rgb * (HDRParam.x * inverse);
  return float4(scene + bloom, 1.f);
}
