# Notas de desarrollo: RenoDX Dark Messiah

Bitácora para retomar el trabajo sin depender de ninguna sesión.

## Setup de la PC (2026-10-20)

- Repack en `D:\Dark Messiah` (Source 2006, D3D9, 32-bit, `mm.exe`).
- ReShade 6.8.0 x32 como `bin\d3dv.dll`: `bin\shaderapidx9.dll` está parcheado (2 bytes, import
  `d3d9.dll` → `d3dv.dll`; original en `shaderapidx9.dll.bak`). Con un `d3d9.dll` en la raíz el
  arranque tardaba ~10 minutos.
- Luma + dgVoodoo descartados (genérico = inverse tonemapping; artefactos con texture upgrades).

## DevKit (2026-10-20, DevKit Debug solo, juego vanilla)

- Device D3D9 (no Ex), backbuffer `b8g8r8a8_unorm` 1024x768, pantalla completa exclusiva.
- Frame de un pasillo (106 draws): la escena se dibuja **directo al backbuffer** (draws 0–82),
  draw 83 = `StretchRect` backbuffer → `_rt_FullFrameFB` (mismo tamaño), 84–88 bloom en 256x192 y
  suma al backbuffer (`0xDAE244BF`, gauss 13 taps * `scale_factor`), 89–105 HUD.
- Lightmaps `r16g16b16a16_unorm` (HDR de Source activo).
- Shader del mundo `0x116C0195` (lightmapped bump, ps_2_0): termina en `mul r0.xyz, r0, c31.x`
  (`cLinearLightScale`) → `mov oC0, r0`, **sin saturate**. Lo único que recorta es el backbuffer.
- Las capturas salen vacías si la ventana está minimizada (pantalla completa + alt-tab).

## Build #1 (prueba)

- Sin reemplazar shaders del juego. Upgrade a FP16 de todo render target `b8g8r8a8`/`b8g8r8x8`
  con el aspecto del backbuffer (backbuffer, FullFrameFB, bloom). Proxy D3D11 + tonemap.
- Duda abierta: Source puede escribir con `SRGBWRITEENABLE`; en FP16 eso se ignora y el buffer
  queda lineal. Setting "Game Output Encoding" (sRGB/Linear) para decidirlo en el juego:
  elegir el que con Tone Mapper = Vanilla se vea igual al original.
- Build: `gh workflow run build-oblivion.yml --ref darkmessiah-dev` (en esta rama ese workflow compila
  Dark Messiah; un workflow nuevo solo se puede despachar si está en `main`).
- **No cargar el DevKit junto con el addon** (comparten el device proxy; ver notas de Oblivion).

## Prueba build #1 (2026-10-20 23:43): crash al cargar

- El log termina en `utils::swapchain attached.`, igual que el crash intermitente de Oblivion.
- Dump `mm.exe.18184.dmp`: `c0000005` en `renodx-darkmessiah.addon32+0x6A8FD`, dentro de `DllMain`
  (attach de `resource::upgrade` vía `device_proxy::Use`): `movaps %xmm0, 0x40(%eax)` con
  `eax = 0x0570E978`, que no está alineado a 16.
- Causa: `platform::CreateSharedObject` y `ProcessAllocator` usan `HeapAlloc`, que en x86 solo
  garantiza 8 bytes de alineación; el compilador asume 16 para ese tipo (stores SSE). En x64
  `HeapAlloc` da 16, por eso upstream no lo ve. Es intermitente: depende de la dirección que toque.
  Probablemente es el mismo crash intermitente de Oblivion.
- Build #2: `AllocateProcessMemory`/`FreeProcessMemory` en `src/utils/platform.hpp` rellenan y
  alinean cuando `alignof(T) > MEMORY_ALLOCATION_ALIGNMENT` (sin cambios en x64 para tipos ≤ 16).
