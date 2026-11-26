# Plan del port a NAOMI 2

Análisis del port a Dreamcast en el commit `c405d21d` (Bruceleeto/Diddy-Kong-Racing, 2026-11-24): qué toca del
hardware o de KallistiOS y qué puede fallar en la NAOMI. "Probado" = funciona en la placa real; Flycast es solo el
primer paso.

## Estado (2026-11-26)

- **Compila** con `build_dkr.sh` (Ubuntu 22.04 en WSL, sh-elf GCC 15.3). El juego ocupa ~6 MB (`_end` 0x8c5be948).
- **Flycast (NAOMI):** espiral, logo de Rareware y la demo de presentación (carreras con Timber, Conker, Drumstick,
  Banjo) a ~60 fps. El residente le da mando (A0) y VMU (A1). Sin probar: mandos, partida, sonido. **Sin probar en
  placa.**
- **KallistiOS:** el port pide KOS master (cambian `genwait_wait`, los callbacks de maple, `purupuru`,
  `g2_lock_scoped`, `pvr_dr_addr`, las cabeceras de caché y temporizador), no 680d1862. El parche `NAOMI_HOST` de
  dc2naomi está llevado a **KOS 9926b70a** (`kos/kos-9926b70a-naomi_host.patch`): 7 conflictos resueltos a mano,
  tipos `uint32` → `uint32_t` y uno nuevo: **sin streams de CD en `fs_iso9660`**. Con streams cada trozo de 32 bytes
  espera la interrupción de fin de DMA del G1, que el residente no da: "Previous DMA request is in progress", lecturas
  cortas y pantalla negra. Sin ellos lee por DMA de sectores enteros, como Mario Kart 64 (flags `0x9404`).
- **Host:** hacen falta clang (AICAforge) y, con el gcc 11 / xxd de 2021 de Ubuntu 22.04, el script compila
  `font_enj` con `-std=gnu2x` y pone un `xxd` sustituto que entiende `-n`.
- **Pruebas en Flycast:** la pantalla virtual `:99` la puede estar usando otra sesión; usar otra (`:98`).

## Lo que ya sabemos

| Área | Qué hace el port | Riesgo en NAOMI | Qué hacer |
|---|---|---|---|
| KallistiOS | API de KOS master de 2026 | resuelto | KOS 9926b70a + `kos/kos-9926b70a-naomi_host.patch` |
| Compilador | `-std=gnu23`, LTO con una sola partición, `-mfsrra -mfsca` | bajo | GCC 14-15 (tenemos 15.3) |
| Sonido | **AICAflow**: firmware ARM7 propio, interrupción AICA→SH4 (`ASIC_EVT_SPU_IRQ`, MCIEB/MCIRE), subida por DMA G2 (`spu_dma_transfer`, llamado directamente desde `driver/sh4/src/dma.c`: en NAOMI esa DMA no acaba nunca, y el parche de KOS solo la evita dentro de `spu_memload_dma`), escrituras directas al DSP (`0xa0702000`, `0xa0703000`…), 2 MB de RAM de sonido como mucho | **alto** | Es lo primero que puede colgar. Comprobar que el residente no pisa la RAM ni los canales del AICA que usa AICAflow (el residente toca dos canales para CD-DA: sin el flag CDDA no debería). Ver si la interrupción del AICA llega igual en NAOMI |
| Vídeo | 640×480, `PM_RGB888P`, FSAA horizontal (1280 de ancho), 60 fps; la FSAA se quita en los mapas más pesados; el PVR se reinicia para cambiarla | medio | El ritmo lo marca un manejador de vblank (`enj_pacing.c`). En MK64 la imagen salía 1 o 2 vblanks después según el cuadro: aquí, a 60 fps, medir y si hace falta `pvr_naomi_hold_flip(1)`. La NAOMI tiene 16 MB de VRAM: quizá FSAA en todos los mapas y más búfer de vértices |
| Mandos | Mando de Dreamcast por maple (enDjinn `enj_ctrl.c`); vibración (`purupuru`) | bajo | El residente traduce JVS a mando DC, como en MK64. Perfil de mandos propio (empezar por `mk64`: A gas, B freno, R salto, Z objeto) |
| VMU / partidas | Guarda con `enj_vmu` y anima la pantalla de la VMU | bajo | VMU emulada de dc2naomi (flag `0x8000`); la pantalla de la VMU no existe, debe ignorarse sin colgar |
| Disco | `DKR_ASSET_MOUNT=/cd`: `assets/assets.bin`, `build/dc/…` (texturas, escenas, bancos de AICAflow) con nombres en minúsculas | bajo | Disco reconstruido con Rock Ridge, como MK64 |
| Memoria | Build de 16 MB (por medir) | bajo | El residente vive en 0x8dc00000 y la VMU en 0x8de00000: el `_end` del juego (y su montón) debe quedar por debajo. Si hace falta, `__KOS_GCC_32MB__` |
| Medidas | `GFX_PROFILE`, `SHP` (muestreo de PC, PMU), TMU1 | — | Apagadas por defecto. Útiles para medir en placa |

## Fases

1. **Compilar** (`build_dkr.sh`): KOS 680d1862 + `NAOMI_HOST`, sh4zam, el port en `c405d21d` con assets en `/cd`,
   disco reconstruido y perfil `dkr` de dc2naomi. Mirar `_end` y el tamaño de `1ST_READ.BIN`.
2. **Primer arranque en Flycast (NAOMI)** con `dkr_dbg` (log en pantalla). Si el sonido cuelga: aislar AICAflow.
3. **Sonido**: AICAflow en Flycast y luego en placa (interrupción, DMA G2, FIFO).
4. **Mandos y partidas**: perfil de mandos propio y VMU emulada.
5. **Ritmo de imagen en placa** a 60 fps: medidas como `naomi_med` de MK64; `pvr_naomi_hold_flip` si hace falta.
6. **FSAA y memoria de vídeo**: aprovechar los 16 MB de VRAM.
7. **Probarlo jugando en el mueble** y subir la imagen a la WiPi.

## Dudas abiertas

- ¿La versión de sh4zam de kos-ports `f4faacc4` vale para el port, o pide una más nueva?
- ¿Compila enDjinn contra KOS 680d1862 sin cambios? (lo dirá la fase 1)
