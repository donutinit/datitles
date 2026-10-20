"""Métricas de las fuentes instaladas para el simulador de Fusion.

Uso: python metrics.py SALIDA.lua TEXTO...

Escribe una tabla de Lua con, por fuente: archivo, ascendente y descendente, avance de cada
carácter que aparece en los textos (y en mayúsculas) y el kerning de cada par. Todo en em.
Las fuentes son las de siempre más las que fijan las plantillas (.setting) entre los textos.
Necesita Pillow y fontconfig (fc-match).
"""

import re
import subprocess
import sys

from PIL import ImageFont

FACES = ["League Gothic/Regular", "Newsreader/Regular", "IBM Plex Mono/Regular"]
EM = 1000


def template_faces(text):
    """Las parejas XFont/XStyle que una plantilla le pone al Fuse."""
    found = dict(re.findall(r'(\w+(?:Font|Style)) = Input \{ Value = "([^"]*)"', text))
    return [f"{found[k]}/{found[k[:-4] + 'Style']}" for k in found
            if k.endswith("Font") and k[:-4] + "Style" in found]


def font_file(face):
    family, style = face.split("/")
    got, path = subprocess.run(
        ["fc-match", "-f", "%{family}\t%{file}", f"{family}:style={style}"],
        check=True, capture_output=True, text=True,
    ).stdout.split("\t")
    # fc-match siempre devuelve algo: si no es la familia pedida, la fuente no está instalada.
    if family not in got.split(","):
        sys.exit(f"metrics.py: {face} no está instalada (fc-match da {got})")
    return path


def load(path, style):
    font = ImageFont.truetype(path, EM)
    try:
        font.set_variation_by_name(style)
    except (OSError, ValueError):
        pass
    return font


def main():
    out, texts = sys.argv[1], sys.argv[2:]
    chars = {chr(c) for c in range(32, 127)}
    faces = list(FACES)
    for path in texts:
        text = open(path, encoding="utf-8").read()
        chars |= set(text) | set(text.upper())
        if path.endswith(".setting"):
            faces += [f for f in template_faces(text) if f not in faces]
    chars = sorted(c for c in chars if c >= " ")

    lines = ["return {"]
    for face in faces:
        path = font_file(face)
        font = load(path, face.split("/")[1])
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
