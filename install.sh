#!/usr/bin/env bash
# Copia datitles a la carpeta de Fusion de DaVinci Resolve en macOS o Linux.
# Otra carpeta: FUSION_DIR=/ruta/a/Fusion ./install.sh
set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
case "$(uname -s)" in
  Darwin) fusion="$HOME/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion" ;;
  Linux) fusion="$HOME/.local/share/DaVinciResolve/Fusion" ;;
  *) echo "En Windows copia los archivos a mano: lo explica el README." >&2; exit 1 ;;
esac
fusion=${FUSION_DIR:-$fusion}

mkdir -p "$fusion/Fuses"
cp "$root"/Fuses/*.fuse "$fusion/Fuses/"
for dir in "$root"/Templates/Edit/*/Datitles; do
  dest="$fusion/Templates/Edit/$(basename "$(dirname "$dir")")/Datitles"
  mkdir -p "$dest"
  cp "$dir"/*.setting "$dest/"
done
# La 0.1 dejaba la plantilla suelta, junto a las de Resolve.
rm -f "$fusion/Templates/Edit/Titles/datitles.setting"
echo "Instalado en $fusion"
echo "Reinicia Resolve: los títulos quedan en Effects > Toolbox > Titles > Datitles y la película en Effects > Toolbox > Effects > Datitles."
