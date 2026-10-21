# RenoDX: Dark Messiah of Might and Magic

HDR for Dark Messiah (2006, Source engine, D3D9, 32-bit).

The world shaders never saturate their output; the 8-bit back buffer is what clips highlights.
The addon upgrades the back buffer, the full-frame copy and the bloom targets to FP16 and
presents through a D3D11 display proxy where tone mapping happens. No game shader is replaced.

## Build

`cmake --build --preset clang-x86-release --target darkmessiah` → `renodx-darkmessiah.addon32`.

## Verify

1. Video options: High Dynamic Range = Full, antialiasing off, windowed.
2. Load ReShade (full add-on build) and `renodx-darkmessiah.addon32` without the DevKit.
3. Tone Mapper = Vanilla must look like the unmodded game; pick the matching Game Output Encoding.
4. With RenoDRT, torches, magic and sky should get brighter as Peak Brightness rises.
