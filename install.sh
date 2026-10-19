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

mkdir -p "$fusion/Fuses" "$fusion/Templates/Edit/Titles"
cp "$root/Fuses/datitles.fuse" "$fusion/Fuses/"
cp "$root/Templates/Edit/Titles/datitles.setting" "$fusion/Templates/Edit/Titles/"
echo "Instalado en $fusion"
echo "Reinicia Resolve: queda en Effects > Toolbox > Titles > Fusion Titles > datitles."
