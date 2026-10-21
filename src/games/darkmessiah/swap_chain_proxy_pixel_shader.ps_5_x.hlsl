#include "./shared.h"

// Final pass on the D3D11 display proxy.
//
// Input: Dark Messiah's upgraded (FP16) D3D9 back buffer. The world shaders
// end with `color * cLinearLightScale.x` and no saturate(), so highlights
// above 1.0 survive here. The HUD is drawn on top in the 0-1 range.

Texture2D t0 : register(t0);
SamplerState s0 : register(s0);

float4 main(float4 vpos: SV_POSITION, float2 uv: TEXCOORD0)
    : SV_TARGET {
  float3 color = t0.Sample(s0, uv).rgb;

  [branch]
  if (RENODX_TONE_MAP_TYPE == renodx::draw::TONE_MAP_TYPE_VANILLA) {
    // Reproduce the 8-bit back buffer clip of the original game.
    color = saturate(color);
  }

  float3 linear_color = (shader_injection.input_encoding == 0.f)
                            ? renodx::color::srgb::DecodeSafe(color)
                            : color;

  [branch]
  if (RENODX_TONE_MAP_TYPE != renodx::draw::TONE_MAP_TYPE_VANILLA) {
    linear_color = renodx::draw::ToneMapPass(linear_color);
  }

  float3 intermediate = renodx::draw::RenderIntermediatePass(linear_color);
  return float4(renodx::draw::SwapChainPass(intermediate), 1.f);
}
