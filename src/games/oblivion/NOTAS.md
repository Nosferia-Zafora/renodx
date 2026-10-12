# Notas de desarrollo: RenoDX Oblivion

Bitácora para retomar el trabajo sin depender de ninguna sesión. Se actualiza en cada paso.

## Estado (2026-10-11)

- `renodx-oblivion.addon32` compila (workflow **Build Oblivion**, run #3, commit `07c5c64`).
- Prueba 1 en el juego (21:28): carga, sin crash, ventana chica. El proxy falló:
  `CloneResource(Failed to clone)` en cada frame. Causa: backbuffer con **MSAA 8x**
  (`MultiSampleType 8` en el log); D3D9 no tiene texturas multisample, así que no se puede clonar.
- Prueba 2 (21:39), con AA off, HDR on y ventana: **crash al cargar el addon**. El log se corta tras
  `[RenoDX] utils::swapchain attached.` (el log de ReShade es write-through, así que el corte es real).
  Informe WER (copia en `D:\Oblivion AI`): `c0000005` en `ntdll.dll` +0x5fbb3 (10.0.19041.7725, 32-bit),
  último módulo cargado `renodx-oblivion.addon32`; también se cargaron `apphelp`/`AcLayers` (shims de compatibilidad).
  **Intermitente**: hay otro crash a las 21:28:21 (antes de la prueba 1, que sí arrancó) con el mismo
  hash de firma WER (`c614971f…`), o sea el mismo bug.

- Prueba 3 (21:47), ventana 2560x1440, abriendo `Oblivion.exe` directo: arrancó al **3er intento** (los
  otros dos son el crash intermitente). Device D3D9Ex, proxy D3D11 OK, sin errores de clonado, cierre limpio.
  **Pero la imagen sigue recortada en SDR**: Peak Brightness cambia la imagen solo hasta ~140 nits; de 200
  a 1000 se ve igual (Game Brightness 203). El log no muestra ninguna ampliación de recursos de 8 bits.
  Hipótesis: `HDR004` escribe en un render target intermedio de 8 bits, no en el backbuffer. Para probarlo
  se usa el DevKit (build #4 de la rama `oblivion-dev` incluye `renodx-devkit.addon32` y
  `renodx-mcp-bridge.exe`).

## Hallazgos verificados

- Pipeline HDR de Oblivion: `HDR000`–`HDR007` en `shaderpackage010`–`019`. Los paquetes con HDR son
  el paquete base + 16 shaders (p. ej. 004 = 637 → 012/013/016–019 = 653).
- Compositor final `HDR004.pso` (`0xDB12AC32` / `0xD32BC79A`): `escena * HDRParam.x / AvgLum + bloom * 0.5 / AvgLum`,
  **sin saturate**. Desensamblado verificado contra `D3DDisassemble` de Microsoft (39/39 idénticos).
- `HDR004.vso` (`0xE71D993F`) es compartido con REFRACT2000, ISBLUR1002, ISBLUR2003 e ISHIT2002, así que
  no se reemplaza ningún shader D3D9.
- Shaders del proxy (`ps_5_0`/`vs_5_0`) compilan con `d3dcompiler_47`, igual que el control (Alice).

## Build (gotchas)

- Hay que declarar `deploy.architecture: ["x86"]` en `metadata.json`; si no, CMake saltea el target en x86.
- El preset `clang-x86` del upstream no define `CMAKE_C_COMPILER_TARGET` (upstream PR #701), así que el
  workflow pasa `-DCMAKE_C_COMPILER_TARGET=i686-pc-windows-msvc`.
- Los cambios van a la rama `oblivion-dev`, no a `main`: un push a `main` dispara los workflows del upstream.

## PC de prueba

- Carpeta de trabajo en la PC: `D:\Oblivion AI` (nada de archivos auxiliares en `D:\Oblivion`).

- GOG, `D:\Oblivion`, RTX 3060, Samsung G50SF QD-OLED (pico 400 nits), ReShade 6.8.0 (full add-on).
- Ini activo: `Documents\My Games\Oblivion\Oblivion.ini` (MO2 con `LocalSettings=false`).
  Backup: `Oblivion.ini.backup-antes-renodx`.
- Cambios aplicados: `iMultiSample=0`, `bDoHighDynamicRange=1`, `bFull Screen=0`.
- El juego se movió de `N:` a `D:`. El registro se corrigió con un .reg (`Installed Path`).
  `ModOrganizer.ini` todavía apunta a `n:/oblivion` (pendiente).

## Pendiente

1. Crash intermitente al cargar el addon: reproducir abriendo `Oblivion.exe` directo varias veces;
   si sigue, build con logging de debug para ubicar el punto exacto.
2. Modo ventana funciona; la ruta "fake fullscreen" deja una ventana chica (pendiente).
3. Con DevKit: ubicar el render target de `HDR004` y su formato; ampliarlo o reemplazar el shader.
