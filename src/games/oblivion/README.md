# RenoDX: The Elder Scrolls IV: Oblivion (2006)

Status: **untested in-game**. Built from static analysis of the game's shader
packages; needs in-game verification before release.

Static checks done:
- Disassembly used for the analysis matches Microsoft's `D3DDisassemble`
  for all 12 HDR shaders (39/39 sampled shaders identical).
- `swap_chain_proxy_*` compile with `d3dcompiler_47` (`ps_5_0`/`vs_5_0`,
  `/Gec /O3`), same as the Alice: Madness Returns control.

## How it works

Oblivion is D3D9 and its shaders ship precompiled in
`Data\Shaders\shaderpackage0NN.sdp`. The HDR pipeline is `HDR000`–`HDR007`:

| Shader | Role (from bytecode + CTAB names) |
| --- | --- |
| HDR000–002 | Separable blurs (`BlurOffsets`, `BlurScale`) |
| HDR003 | Copy |
| HDR005 | Bright pass (`max(color - HDRParam.x, 0) * HDRParam.y`) |
| HDR006 | Eye adaptation, lerps luminance over time (`TimingData`) |
| HDR007 | Luminance clamp |
| **HDR004** | **Final composite**: `scene * HDRParam.x / AvgLum + bloom * 0.5 / AvgLum` |

HDR004 (`0xDB12AC32`, and `0xD32BC79A` for the manual-bilinear variant)
never saturates; highlights only clip because the back buffer is 8-bit.

This addon therefore replaces **no** D3D9 shaders. It:

1. Upgrades back-buffer-sized `B8G8R8X8`/`B8G8R8A8` targets to `R16G16B16A16_FLOAT`.
2. Presents through the D3D11 display proxy (`use_device_proxy`), like Alice: Madness Returns.
3. Tone maps in `swap_chain_proxy_pixel_shader.ps_5_x.hlsl` (sRGB decode,
   `ToneMapPass`, `RenderIntermediatePass`, `SwapChainPass`).

Why not replace HDR004: a `ps_3_0` replacement must pair with a `vs_3_0`, and
`HDR004.vso` (`0xE71D993F`) is shared with `REFRACT2000`, `ISBLUR1002`,
`ISBLUR2003` and `ISHIT2002`.

Known limitation: the HUD and menus are composited into the same buffer
before the proxy pass, so they share the game brightness and pass through the
tone mapper (mostly unchanged below diffuse white).

## Build

`cmake --preset clang-x86` then `cmake --build --preset clang-x86-release --target oblivion`
→ `renodx-oblivion.addon32`.

## Manual verification

1. Install ReShade (full add-on support) on `Oblivion.exe`, API Direct3D 9.
2. Copy `renodx-oblivion.addon32` next to `Oblivion.exe`.
3. In-game: HDR on, antialiasing off, Windows HDR on.
4. Check with the devkit or ReShade's resource list that the back buffer is
   `R16G16B16A16_FLOAT` and that HDR004 output exceeds 1.0 at the sun/sky.
5. Compare `Vanilla` (must match the unmodded game) against `RenoDRT`.
