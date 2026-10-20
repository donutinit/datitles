"""Dibuja los cuadros que dejó preview.lua.

Uso: python render.py METRICAS.lua CUADROS.json CARPETA [--negro]

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
    # Sin fondo sólido, --negro pinta negro en lugar de cuadros grises (para probar la película).
    black = "--negro" in sys.argv[4:]
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
                f.set_variation_by_name(face.split("/")[1])
            except (OSError, ValueError):
                pass
            cache[key] = f
        return cache[key]

    for frame in data["frames"]:
        if frame["fill"]:
            img = Image.new("RGBA", (w, h), tuple(round(c * 255) for c in frame["fill"]))
        elif black:
            img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
        else:
            img = checker(w, h)
        for group in frame["draws"]:
            # El color llega premultiplicado, como en Fusion.
            r, g, b, a = group["color"]
            if a <= 0:
                continue
            color = tuple(round(c / a * 255) for c in (r, g, b)) + (round(a * 255),)
            layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            draw = ImageDraw.Draw(layer)
            for cp, face, em, x, y in group["glyphs"]:
                # Unidades de salida: 1 = ancho del cuadro, y hacia arriba desde abajo.
                f = font(face, max(1, round(em * w)))
                left = x * w - f.getlength(chr(cp)) / 2
                draw.text((left, h - y * w), chr(cp), font=f, fill=color, anchor="ls")
            img.alpha_composite(layer)
        img.save(out / f"cuadro-{frame['time']:05d}.png")


def checker(w, h, size=40):
    """Sin fondo sólido el título es transparente: se pinta sobre cuadros grises para notarlo."""
    img = Image.new("RGBA", (w, h), (52, 52, 52, 255))
    draw = ImageDraw.Draw(img)
    for row in range(0, h, size):
        for col in range(0, w, size):
            if (row // size + col // size) % 2:
                draw.rectangle((col, row, col + size - 1, row + size - 1), fill=(64, 64, 64, 255))
    return img


if __name__ == "__main__":
    main()
