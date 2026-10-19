"""Dibuja los cuadros que dejó preview.lua.

Uso: python render.py METRICAS.lua CUADROS.json CARPETA

Cada glifo se pinta con su fuente real, centrado en su avance sobre la línea base, que es como
lo deja GetCharacterShape en Fusion (el anchor "m" de Pillow centra la caja, no el avance). Necesita Pillow.
"""

import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def font_files(metrics_path):
    src = Path(metrics_path).read_text(encoding="utf-8")
    return dict(re.findall(r'\["([^"]+)"\] = \{ file = "([^"]+)"', src))


def main():
    metrics_path, frames_path, out_dir = sys.argv[1:4]
    files = font_files(metrics_path)
    data = json.loads(Path(frames_path).read_text(encoding="utf-8"))
    w, h = data["width"], data["height"]
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    cache = {}

    def font(face, px):
        key = (face, px)
        if key not in cache:
            f = ImageFont.truetype(files[face], px)
            try:
                f.set_variation_by_name("Regular")
            except (OSError, ValueError):
                pass
            cache[key] = f
        return cache[key]

    for frame in data["frames"]:
        fill = frame["fill"] or [0, 0, 0, 0]
        img = Image.new("RGBA", (w, h), tuple(round(c * 255) for c in fill))
        draw = ImageDraw.Draw(img)
        for group in frame["draws"]:
            color = tuple(round(c * 255) for c in group["color"]) + (255,)
            for cp, face, em, x, y in group["glyphs"]:
                # Unidades de salida: 1 = ancho del cuadro, y hacia arriba desde abajo.
                f = font(face, max(1, round(em * w)))
                left = x * w - f.getlength(chr(cp)) / 2
                draw.text((left, h - y * w), chr(cp), font=f, fill=color, anchor="ls")
        img.save(out / f"cuadro-{frame['time']:05d}.png")


if __name__ == "__main__":
    main()
