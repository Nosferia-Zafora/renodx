// SKY.pso (shaderpackage013): sky gradient.
// Vanilla: color = v0 * Params.y. v0 comes through oD0, which SM2 clamps to
// [0, 1], so the sky can never exceed SDR white on its own.
#include "./shared.h"

float4 Params : register(c4);

float4 main(float4 color : COLOR0) : COLOR {
  float sky_brightness = OBLIVION_SKY_BRIGHTNESS;
  // Without the injected constant (e.g. addon disabled) keep vanilla.
  sky_brightness = (sky_brightness > 0.f) ? sky_brightness : 1.f;

  return float4(color.rgb * Params.y * sky_brightness, color.a);
}
