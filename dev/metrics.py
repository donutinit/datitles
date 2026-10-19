"""Métricas de las fuentes instaladas para el simulador de Fusion.

Uso: python metrics.py SALIDA.lua TEXTO...

Escribe una tabla de Lua con, por fuente: archivo, ascendente y descendente, avance de cada
carácter que aparece en los textos (y en mayúsculas) y el kerning de cada par. Todo en em.
Necesita Pillow y fontconfig (fc-match).
"""

import subprocess
import sys

from PIL import ImageFont

FACES = ["League Gothic/Regular", "Newsreader/Regular", "IBM Plex Mono/Regular"]
EM = 1000


def font_file(face):
    family, style = face.split("/")
    return subprocess.run(
        ["fc-match", "-f", "%{file}", f"{family}:style={style}"],
        check=True, capture_output=True, text=True,
    ).stdout


def load(path):
    font = ImageFont.truetype(path, EM)
    try:
        font.set_variation_by_name("Regular")
    except (OSError, ValueError):
        pass
    return font


def main():
    out, texts = sys.argv[1], sys.argv[2:]
    chars = {chr(c) for c in range(32, 127)}
    for path in texts:
        text = open(path, encoding="utf-8").read()
        chars |= set(text) | set(text.upper())
    chars = sorted(c for c in chars if c >= " ")

    lines = ["return {"]
    for face in FACES:
        path = font_file(face)
        font = load(path)
        asc, desc = font.getmetrics()
        adv = {c: font.getlength(c) for c in chars}
        lines.append(f'  ["{face}"] = {{ file = "{path}", asc = {asc / EM}, desc = {desc / EM},')
        lines.append("    adv = {" + ", ".join(f"[{ord(c)}] = {adv[c] / EM:.5f}" for c in chars) + "},")
        kern = []
        for a in chars:
            for b in chars:
                k = font.getlength(a + b) - adv[a] - adv[b]
                if abs(k) > 0.5:
                    kern.append(f'["{ord(a)},{ord(b)}"] = {k / EM:.5f}')
        lines.append("    kern = {" + ", ".join(kern) + "} },")
    lines.append("}")
    open(out, "w", encoding="utf-8").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
