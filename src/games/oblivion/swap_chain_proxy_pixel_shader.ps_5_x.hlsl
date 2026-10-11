#include "./shared.h"

// Final pass on the D3D11 display proxy.
//
// Input: Oblivion's upgraded (FP16) D3D9 back buffer. HDR004.pso writes
//   scene * (HDRParam.x / AvgLum) + bloom * 0.5 / AvgLum
// without saturate(), so highlights above 1.0 survive here. The values are
// gamma-encoded (the game lights and blends in display space). Menus and HUD
// are drawn on top in the 0-1 range.

Texture2D t0 : register(t0);
SamplerState s0 : register(s0);

float4 main(float4 vpos: SV_POSITION, float2 uv: TEXCOORD0)
    : SV_TARGET {
  uv.y = lerp(uv.y, 1.0 - uv.y, shader_injection.custom_flip_uv_y);

  float3 color = t0.Sample(s0, uv).rgb;

  [branch]
  if (RENODX_TONE_MAP_TYPE == renodx::draw::TONE_MAP_TYPE_VANILLA) {
    // Reproduce the 8-bit back buffer clip of the original game.
    color = saturate(color);
  }

  float3 linear_color = renodx::color::srgb::DecodeSafe(color);

  [branch]
  if (RENODX_TONE_MAP_TYPE != renodx::draw::TONE_MAP_TYPE_VANILLA) {
    linear_color = renodx::draw::ToneMapPass(linear_color);
  }

  float3 intermediate = renodx::draw::RenderIntermediatePass(linear_color);
  return float4(renodx::draw::SwapChainPass(intermediate), 1.f);
}
