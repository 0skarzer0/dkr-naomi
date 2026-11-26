# dkr-naomi

Diddy Kong Racing en la **NAOMI 2** (mueble del Crazy Taxi), a partir del port a Dreamcast de la decompilación de N64.
Es el mismo método que usamos con Mario Kart 64 en [dc2naomi](https://github.com/0skarzer0/dc2naomi) (`homebrew/mk64/`): el juego se
compila contra una KallistiOS parcheada para NAOMI (`NAOMI_HOST`) y dc2naomi lo empaqueta como imagen de NAOMI.

**Estado:** en la placa (NAOMI 2) la demo se ve y suena bien; falta probarlo jugando. Ver [docs/plan.md](docs/plan.md).

## Qué hace falta

- Tu ROM: **Diddy Kong Racing (U) 1.0**, `.z64`, SHA1 `0cb115d8716dbbc2922fda38e533b9fe63bb9670`. En este repositorio
  no hay nada con copyright: ni ROM, ni assets sacados de ella, ni discos, BIOS o imágenes.
- Un clon de dc2naomi junto a este (`../dc2naomi`) o en `D2N`, con los perfiles `dkr`/`dkr_dbg`: hace el empaquetado. El
  parche de KallistiOS (`kos/`) es el `NAOMI_HOST` de dc2naomi llevado a la KOS que pide el port (9926b70a).
- Ubuntu 22.04 (vale WSL) con el dc-chain de KallistiOS (sh-elf GCC 14 o 15) en `/opt/toolchains/dc/sh-elf`, una
  KallistiOS con `KOS_SUBARCH=naomi` para el loader de dc2naomi, git, python3 ≥ 3.10 con venv, clang, cmake y un compilador
  del host.

## Compilar

Desde un clon con saltos de línea LF (en WSL, no el de Windows):

```bash
./build_dkr.sh "/ruta/Diddy Kong Racing (U) (V1.0).z64"
```

Deja `build/dkr_dc2naomict.bin` y `.bin.gz`. Opciones en la cabecera del script (`WORK`, `D2N`, `KOS_NAOMI_ENV`,
`JOBS`, `PROFILE`, `MAKEARGS`).

## Agradecimientos

- [DavidSM64](https://github.com/DavidSM64/Diddy-Kong-Racing) y el resto de la decompilación de Diddy Kong Racing.
- [Bruceleeto](https://github.com/Bruceleeto/Diddy-Kong-Racing): el port a Dreamcast.
- [dfchil](https://github.com/dfchil): enDjinn y AICAflow, el marco y el sonido del port.
- [KallistiOS](https://github.com/KallistiOS/KallistiOS) y [sh4zam](https://github.com/gyrovorbis/sh4zam).
