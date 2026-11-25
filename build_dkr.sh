#!/bin/bash
# build_dkr.sh BASEROM.z64 [OUT.bin]
#
# Diddy Kong Racing para la NAOMI 2 (mueble del Crazy Taxi), a partir del port a Dreamcast de la decompilación
# de N64:  https://github.com/Bruceleeto/Diddy-Kong-Racing  (commit c405d21d, 2026-11-24)
# compilado contra KallistiOS 680d1862 con el parche NAOMI_HOST de dc2naomi y empaquetado por dc2naomi
# (perfil "dkr" de tools/games.py, disco reconstruido). Mismo método que Mario Kart 64
# (dc2naomi/homebrew/mk64/build_mk64.sh).
#
# En este repositorio no hay nada con copyright: hace falta tu ROM, Diddy Kong Racing (U) 1.0 .z64,
# SHA1 0cb115d8716dbbc2922fda38e533b9fe63bb9670 (la que pide el port). El código del juego se descarga del
# repositorio de su autor; lo que sale de la ROM se queda en $WORK.
#
# Necesita: sh-elf GCC 14-15 en /opt/toolchains/dc/sh-elf (dc-chain de KallistiOS; el port usa -std=gnu23),
# una KallistiOS con KOS_SUBARCH=naomi para el loader de dc2naomi (KOS_NAOMI_ENV), un clon de dc2naomi (D2N),
# git, python3 >= 3.10 con venv, cmake, un compilador C/C++ del host. Pensado para Ubuntu 22.04 (WSL).
#
# Variables (todas opcionales):
#   WORK          dónde se clona y compila todo                 (por defecto: $HOME/dkr-build)
#   D2N           clon de dc2naomi                              (por defecto: ../dc2naomi junto a este repo)
#   KOS_NAOMI_ENV environ.sh del árbol KOS_SUBARCH=naomi         (por defecto: /opt/toolchains/dc/kos-naomi/environ.sh)
#   JOBS          trabajos en paralelo                          (por defecto: 3)
#   PROFILE       perfil de dc2naomi: dkr, o dkr_dbg (log en pantalla y diagnóstico)
#   MAKEARGS      opciones para el Makefile.dc del port (p. ej. "FSAA=0 FRAME_FIELDS=2")
set -eo pipefail   # (sin -u: el environ.sh de KallistiOS lee variables sin definir)

BASEROM=$(realpath "${1:?uso: build_dkr.sh BASEROM.z64 [OUT.bin]}")
HERE=$(cd "$(dirname "$0")" && pwd)
D2N=$(realpath "${D2N:-$HERE/../dc2naomi}")
PROFILE=${PROFILE:-dkr}
OUT=$(realpath -m "${2:-$HERE/build/${PROFILE}_dc2naomict.bin}")
WORK=${WORK:-$HOME/dkr-build}
KOS_NAOMI_ENV=${KOS_NAOMI_ENV:-/opt/toolchains/dc/kos-naomi/environ.sh}
JOBS=${JOBS:-3}

DKR_URL=https://github.com/Bruceleeto/Diddy-Kong-Racing.git
DKR_REV=c405d21d0e79a2178ffea1c2732f691692d2eddf
KOS_URL=https://github.com/KallistiOS/KallistiOS.git
KOS_REV=680d1862
KOS_PATCH=$D2N/homebrew/mk64/kos-680d1862-naomi_host.patch
PORTS_URL=https://github.com/KallistiOS/kos-ports.git
PORTS_REV=f4faacc42faaf552625777b7709e871a827e1055

say() { echo; echo "== $*"; }
fail() { echo "build_dkr.sh: $*" >&2; exit 1; }

[ "$(sha1sum "$BASEROM" | cut -c1-40)" = 0cb115d8716dbbc2922fda38e533b9fe63bb9670 ] ||
    fail "$BASEROM no es Diddy Kong Racing (U) 1.0 .z64 (SHA1 0cb115d8...)"
[ -f "$KOS_PATCH" ] || fail "no está $KOS_PATCH (D2N=$D2N debe ser un clon de dc2naomi)"
[ -f "$KOS_NAOMI_ENV" ] || fail "no está $KOS_NAOMI_ENV (KallistiOS con KOS_SUBARCH=naomi, para el loader)"
python3 -c 'import sys, venv, ensurepip; sys.exit(sys.version_info < (3, 10))' 2>/dev/null ||
    fail "hace falta python3 >= 3.10 con venv (apt install python3-venv); make setup instala el resto en .venv"
mkdir -p "$WORK"

# 1. KallistiOS 680d1862 con el parche NAOMI_HOST, en su propio árbol (nunca el del loader)
KOS=$WORK/kos-dkr
if [ ! -f "$KOS/lib/dreamcast/libkallisti.a" ] || ! git -C "$KOS" apply -R --check "$KOS_PATCH" 2>/dev/null; then
    # árbol nuevo, o compilado con una versión anterior del parche: vuelta a $KOS_REV, parche y recompilar
    say "KallistiOS $KOS_REV + NAOMI_HOST"
    [ -d "$KOS/.git" ] || git clone -q "$KOS_URL" "$KOS"
    git -C "$KOS" checkout -q -f "$KOS_REV"
    git -C "$KOS" apply "$KOS_PATCH"
    rm -f "$KOS/lib/dreamcast/libkallisti.a"
fi
# el environ.sh de ejemplo de KOS, apuntado a estos árboles, más -DNAOMI_HOST (lo ven KOS y el juego)
sed -e "s#KOS_BASE=\"/opt/toolchains/dc/kos\"#KOS_BASE=\"$KOS\"#" \
    -e "s#KOS_PORTS=\"\${KOS_BASE}/../kos-ports\"#KOS_PORTS=\"$WORK/kos-ports-dkr\"#" \
    "$KOS/doc/environ.sh.sample" > "$KOS/environ.sh"
grep -q "KOS_BASE=\"$KOS\"" "$KOS/environ.sh" || fail "no se pudo fijar KOS_BASE en $KOS/environ.sh"
grep -q "kos-ports-dkr" "$KOS/environ.sh" || fail "no se pudo fijar KOS_PORTS en $KOS/environ.sh"
echo 'export KOS_CFLAGS="${KOS_CFLAGS} -DNAOMI_HOST"' >> "$KOS/environ.sh"
if [ ! -f "$KOS/lib/dreamcast/libkallisti.a" ]; then
    (cd "$KOS" && source ./environ.sh && make -j"$JOBS")
fi
# utilidades de KOS que usa el port (pvrtex) y la que hace el IP.BIN (makeip)
[ -x "$KOS/utils/pvrtex/pvrtex" ] || (source "$KOS/environ.sh" && make -C "$KOS/utils/pvrtex")
[ -x "$KOS/utils/makeip/makeip" ] || (source "$KOS/environ.sh" && make -C "$KOS/utils/makeip")

# 2. kos-ports: solo sh4zam (la librería de matemáticas del port)
if [ ! -f "$WORK/kos-ports-dkr/lib/libsh4zam.a" ]; then
    say "kos-ports: sh4zam"
    [ -d "$WORK/kos-ports-dkr/.git" ] || git clone -q "$PORTS_URL" "$WORK/kos-ports-dkr"
    git -C "$WORK/kos-ports-dkr" checkout -q "$PORTS_REV"
    (source "$KOS/environ.sh" && cd "$WORK/kos-ports-dkr/sh4zam" && make install)
fi

# 3. el port, en su commit, con sus submódulos (enDjinn, AICAflow y las herramientas del decomp)
G=$WORK/dkr-dc
[ -d "$G/.git" ] || git clone -q "$DKR_URL" "$G"
git -C "$G" checkout -q "$DKR_REV"
git -C "$G" submodule update --init --recursive
mkdir -p "$G/baseroms"
cp "$BASEROM" "$G/baseroms/baserom.us.v77.z64"

# 4. assets de la ROM y el juego, con los assets en /cd (el disco que sirve el loader de dc2naomi).
#    La regla "cdi" del port llena cdrom/ y luego llama a mkdcdisc: aquí mkdcdisc es un sustituto que no hace
#    nada, porque el disco lo monta dc2naomi.
source "$KOS/environ.sh"
cd "$G"
say "make setup / extract / build_assets"
make setup
make extract
make build_assets
mkdir -p "$WORK/bin"
printf '#!/bin/sh\necho "(mkdcdisc: no hace falta, el disco lo monta dc2naomi)"\n' > "$WORK/bin/mkdcdisc"
chmod +x "$WORK/bin/mkdcdisc"
say "el juego (make -f Makefile.dc cdi $MAKEARGS)"
# shellcheck disable=SC2086
PATH=$WORK/bin:$PATH make -f Makefile.dc -j"$JOBS" cdi $MAKEARGS
ELF=$G/bin/dkracing.elf
[ -f "$ELF" ] || fail "no se ha generado $ELF"
END=$("$KOS_CC_BASE/bin/$KOS_CC_PREFIX-nm" "$ELF" | awk '/ _end$/{print $1}')
printf "%s: _end = 0x%s (el residente empieza en 0x8dc00000)\n" "$ELF" "$END"
printf "naomi_live en 0x%s\n" "$("$KOS_CC_BASE/bin/$KOS_CC_PREFIX-nm" "$ELF" | awk '/ _naomi_live$/{print $1}')"

# 5. el disco como ficheros (disposición "rebuild" de dc2naomi): IP.BIN, 1ST_READ.BIN sin codificar
#    (la ruta GD-ROM no lo codifica) y el árbol cdrom/ del port
DISC=$WORK/disc
rm -rf "$DISC"; mkdir -p "$DISC"
"$KOS/utils/makeip/makeip" "$HERE/ip.txt" "$DISC/IP.BIN"
"$KOS_CC_BASE/bin/$KOS_CC_PREFIX-objcopy" -O binary "$ELF" "$DISC/1ST_READ.BIN"
cp -r "$G/cdrom/." "$DISC/"
ls -la "$DISC"

# 6. la imagen de NAOMI (el loader de dc2naomi se compila con el árbol KOS_SUBARCH=naomi)
say "dc2naomi: $PROFILE -> $OUT"
cd "$D2N"
mkdir -p "$(dirname "$OUT")"
(source "$KOS_NAOMI_ENV" && REBUILD=1 ./build.sh "$PROFILE" "$DISC" "$OUT")
python3 -I - "$OUT" <<'PY'
import gzip, os, sys
src = sys.argv[1]; name = os.path.basename(src)
with open(src + ".gz", "wb") as raw, gzip.GzipFile(filename=name, mode="wb", fileobj=raw, compresslevel=6, mtime=0) as gz:
    with open(src, "rb") as f:
        while (b := f.read(1 << 20)): gz.write(b)
print(src + ".gz", os.path.getsize(src + ".gz"), "bytes")
PY
echo "Para la WiPi: /boot/roms/dc-${PROFILE}_dc2naomict.bin.gz y una fila en romsinfo.csv (ver el HANDOFF de dc2naomi)."
