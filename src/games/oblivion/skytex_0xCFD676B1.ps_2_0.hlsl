// SKYTEX.pso (shaderpackage013): textured sky layers (clouds, sun, moons).
// Vanilla: lerp(TexMap, TexMapBlend, Params.x) * v0, rgb scaled by Params.y.
#include "./shared.h"

float4 Params : register(c4);
sampler2D TexMap : register(s0);
sampler2D TexMapBlend : register(s1);

float4 main(float2 texcoord0 : TEXCOORD0, float2 texcoord1 : TEXCOORD1, float4 color : COLOR0) : COLOR {
  float4 sky = lerp(tex2D(TexMap, texcoord0), tex2D(TexMapBlend, texcoord1), Params.x) * color;

  float sky_brightness = OBLIVION_SKY_BRIGHTNESS;
  sky_brightness = (sky_brightness > 0.f) ? sky_brightness : 1.f;

  return float4(sky.rgb * Params.y * sky_brightness, sky.a);
}
