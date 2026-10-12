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

## DevKit (2026-10-12, solo DevKit cargado, juego vanilla con HDR on)

- `HDR004` (`0xDB12AC32`, paquete 13) es el draw 997 de 1024 y escribe **directo al backbuffer**
  (`b8g8r8x8`, 2560x1440). No hay RT intermedio de 8 bits. Entradas, todas FP16:
  `s1` escena 2560x1440, `s0` bloom 256x256, `s2` AvgLum 1x1.
- Fórmula real: `scene * x / max(sum(avg), x) + bloom * 0.5 / max(sum(avg), x)` (x = `HDRParam.x`); el
  factor de escena es ≤ 1, o sea que la adaptación solo oscurece.
- **El contenido casi no supera 1:** escena luma p50 0.358, p99 0.814, p99.9 0.991, máx 1.389; solo el 0.09%
  > 1, y es piedra/camino al sol (no el cielo). Bloom máx 0.91 luma. AvgLum (suma de canales) ≈ 1.11.
- El cielo no es brillante (< 0.9) porque el ini lo atenúa a propósito: `fSkyBrightness=0.5`,
  `fSunBrightness=0.0`, `fSunlightDimmer=1.3`, `fGrassDimmer=1.3`, `fTreeDimmer=1.2`, `fUpperLUMClamp=1.0`.
- Conclusión: la cadena backbuffer→proxy es la correcta; la falta de brillos es del contenido. El rango
  real tiene que salir del motor (parámetros de sol/cielo) o de los shaders de escena, no del final.
- Prueba ini 1 (`fSkyBrightness` 0.5→1.5, `fSunBrightness` 0→1, `fSunlightDimmer` 1.3→1.0): **no crea
  rango**. Cielo máx 0.872 → 0.883 (sigue < 1; el cielo está acotado en su shader o textura). Solo sube
  los medios (p50 0.36 → 0.53) y AvgLum (suma 1.11 → 1.48 > 1.2, así que la adaptación ahora oscurece ~0.81).
  Descartada (ini restaurado).
- Cielo (paquete 13): `SKY.vso` (`0xC5F76628`) mezcla 3 `BlendColor` (colores del clima, 8 bits) y los
  saca por **`oD0`, que en SM2 se clampa a [0,1] por hardware**; `SKY.pso` (`0x4F18027E`) solo hace
  `v0 * Params.y`. `SKYTEX.pso` (`0xCFD676B1`, sol/nubes) = textura DXT * `v0` * `Params.y`. El cielo es
  LDR por diseño: no hay dato HDR escondido. Cualquier brillo extra de cielo/sol es un realce (slider
  opcional, neutro por defecto), no una recuperación.
- Pendiente medir: fuego/magia/partículas (`PAR*`, blending aditivo en el RT FP16) de noche o en una
  mazmorra; ahí sí puede haber valores > 1 reales.
- Crash: build #5 sube `renodx-oblivion.pdb`; `D:\Oblivion AI\oblivion-crash-dumps.reg` activa
  LocalDumps en `D:\Oblivion AI\dumps` para simbolizar el crash con `llvm-symbolizer`.
- **Crash con DevKit resuelto (causa):** dump `Oblivion.exe.47460.dmp` → AV leyendo `0x15cd5000` en
  `renodx-oblivion.addon32+0x18AC0`, dentro de `DllMain` (`AddCallback` sobre `resource::SharedData`,
  vectores en +0x800/+0x80C/+0x818 con stride de 12 bytes = layout Release). El DevKit es Debug
  (`_ITERATOR_DEBUG_LEVEL=2`, vectores de 16 bytes) y crea el `SharedData` cross-addon primero, así que
  el addon Release lee basura. **Regla: addon y DevKit con el mismo tipo de build.** Desde el build #6, el
  artifact `renodx-devkit` incluye `renodx-oblivion.addon32` Debug y su PDB.
  El segundo dump (mismo PID) es un fallo secundario en `ntdll+0x5fbb3` escribiendo `0x14`; es la misma
  firma que el crash intermitente *sin* DevKit, que sigue sin explicar.
- `iLocation X/Y=-32000` aparece si el juego se cierra minimizado (ventana fuera de pantalla). Lanzador
  `D:\Oblivion AI\Jugar Oblivion.bat` lo resetea y evita abrir dos instancias.

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
