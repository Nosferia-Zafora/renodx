#ifndef SRC_GAMES_OBLIVION_SHARED_H_
#define SRC_GAMES_OBLIVION_SHARED_H_

// Oblivion (2006) is D3D9. Its HDR composite (HDR004.pso) never saturates,
// so once the back buffer is upgraded to FP16 the scene keeps values > 1.
// All tone mapping happens in the D3D11 display-proxy pass, which has no
// SM2 instruction or constant-register limits.

// Must be 32bit aligned
// Should be 4x32
struct ShaderInjectData {
  float peak_white_nits;
  float diffuse_white_nits;
  float tone_map_type;
  float tone_map_exposure;

  float tone_map_highlights;
  float tone_map_shadows;
  float tone_map_contrast;
  float tone_map_saturation;

  float tone_map_highlight_saturation;
  float tone_map_blowout;
  float tone_map_flare;
  float gamma_correction;

  float swap_chain_custom_color_space;
  float custom_flip_uv_y;
  float padding0;
  float padding1;
};

#ifndef __cplusplus
#if ((__SHADER_TARGET_MAJOR == 5 && __SHADER_TARGET_MINOR >= 1) || __SHADER_TARGET_MAJOR >= 6)
cbuffer shader_injection : register(b13, space50) {
#else
cbuffer shader_injection : register(b13) {
#endif
  ShaderInjectData shader_injection : packoffset(c0);
}

#define RENODX_PEAK_WHITE_NITS                 shader_injection.peak_white_nits
#define RENODX_DIFFUSE_WHITE_NITS              shader_injection.diffuse_white_nits
// Scene and UI share one buffer before the proxy pass, so they share one brightness.
#define RENODX_GRAPHICS_WHITE_NITS             shader_injection.diffuse_white_nits
#define RENODX_TONE_MAP_TYPE                   shader_injection.tone_map_type
#define RENODX_TONE_MAP_EXPOSURE               shader_injection.tone_map_exposure
#define RENODX_TONE_MAP_HIGHLIGHTS             shader_injection.tone_map_highlights
#define RENODX_TONE_MAP_SHADOWS                shader_injection.tone_map_shadows
#define RENODX_TONE_MAP_CONTRAST               shader_injection.tone_map_contrast
#define RENODX_TONE_MAP_SATURATION             shader_injection.tone_map_saturation
#define RENODX_TONE_MAP_HIGHLIGHT_SATURATION   shader_injection.tone_map_highlight_saturation
#define RENODX_TONE_MAP_BLOWOUT                shader_injection.tone_map_blowout
#define RENODX_TONE_MAP_FLARE                  shader_injection.tone_map_flare
#define RENODX_GAMMA_CORRECTION                shader_injection.gamma_correction
#define RENODX_SWAP_CHAIN_CUSTOM_COLOR_SPACE   shader_injection.swap_chain_custom_color_space
#define RENODX_SWAP_CHAIN_ENCODING             renodx::draw::ENCODING_SCRGB
#define RENODX_SWAP_CHAIN_ENCODING_COLOR_SPACE color::convert::COLOR_SPACE_BT709
#define RENODX_RENO_DRT_TONE_MAP_METHOD        renodx::tonemap::renodrt::config::tone_map_method::REINHARD

#include "../../shaders/renodx.hlsl"

#endif  // __cplusplus

#endif  // SRC_GAMES_OBLIVION_SHARED_H_
