"""Aproxima un efecto hecho con nodos de Fusion sobre los cuadros que dejó render.py.

Uso: python pelicula.py EFECTO.json CARPETA

Lee los nodos con sus valores en cada cuadro (los deja efecto.lua) y los aplica a
CARPETA/cuadro-NNNNN.png. Es para ver la intención, no lo que dará Fusion: el tamaño de los blur,
el grano y el Shake se calculan a ojo. Necesita Pillow y numpy.
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def box(a, r, axis):
    """Promedio móvil de ancho 2r+1 a lo largo de un eje, con las orillas repetidas."""
    if r < 1:
        return a
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return (hi - lo) / (2 * r + 1)


def gaussian(a, sigma):
    """Tres pasadas de caja por eje, que se parecen a un gaussiano."""
    if sigma <= 0.3:
        return a
    r = max(1, int(round((np.sqrt(12 * sigma * sigma / 3 + 1) - 1) / 2)))
    for _ in range(3):
        a = box(box(a, r, 0), r, 1)
    return a


def smooth_random(seed, t, period):
    """Ruido suave entre 0 y 1: valores al azar cada period cuadros, unidos con coseno."""
    k, f = divmod(t / period, 1)
    a = np.random.default_rng([seed, int(k)]).random()
    b = np.random.default_rng([seed, int(k) + 1]).random()
    w = (1 - np.cos(np.pi * f)) / 2
    return a + (b - a) * w


class Graph:
    def __init__(self, tools, clip, time, width):
        self.tools, self.clip, self.time = tools, clip, time
        self.h, self.w = clip.shape[:2]
        self.px = width / 1920  # los tamaños de Fusion se toman en píxeles de un cuadro de 1920
        self.memo = {}

    def get(self, name):
        if name not in self.memo:
            t = self.tools[name]
            self.memo[name] = getattr(self, t["type"])(t["inputs"], name)
        return self.memo[name]

    def src(self, inputs, key):
        v = inputs.get(key)
        return self.get(v["from"]) if isinstance(v, dict) else None

    def finish(self, img, out, inputs):
        """Blend y EffectMask, como en cualquier nodo de Fusion."""
        k = inputs.get("Blend", 1)
        mask = self.src(inputs, "EffectMask")
        if mask is not None:
            k = k * mask[..., None]
        return img + (out - img) * k

    def PipeRouter(self, inputs, name):
        return self.clip if name == self.entry else self.src(inputs, "Input")

    def BrightnessContrast(self, inputs, name):
        img = self.src(inputs, "Input")
        out = img.copy()
        lo, hi = inputs.get("Low", 0), inputs.get("High", 1)
        for c, ch in enumerate(("Red", "Green", "Blue", "Alpha")):
            if not inputs.get(ch, 1):
                continue
            v = img[..., c] * inputs.get("Gain", 1)
            if lo != 0 or hi != 1:
                v = (v - lo) / (hi - lo)
            if inputs.get("ClipBlack", 0):
                v = np.maximum(v, 0)
            if inputs.get("ClipWhite", 0):
                v = np.minimum(v, 1)
            out[..., c] = v
        return self.finish(img, out, inputs)

    def Blur(self, inputs, name):
        img = self.src(inputs, "Input")
        out = img.copy()
        sigma = inputs.get("XBlurSize", 1) * self.px / 2
        for c, ch in enumerate(("Red", "Green", "Blue", "Alpha")):
            if inputs.get(ch, 1):
                out[..., c] = gaussian(img[..., c], sigma)
        return self.finish(img, out, inputs)

    def Merge(self, inputs, name):
        bg, fg = self.src(inputs, "Background"), self.src(inputs, "Foreground")
        gain = inputs.get("Gain", 1)
        if inputs.get("ApplyMode", "Normal") == "Screen":
            out = fg + bg - fg * bg
        else:
            out = fg + bg * (1 - fg[..., 3:4] * gain)
        return self.finish(bg, out, inputs)

    def FilmGrain(self, inputs, name):
        img = self.src(inputs, "Input")
        mono = inputs.get("Monochrome", 1)
        seed = int(inputs.get("Seed", 0)) + (0 if inputs.get("TimeLockSeed", 0) else self.time)
        rng = np.random.default_rng(seed)
        n = rng.standard_normal((self.h, self.w, 1 if mono else 3)).astype(np.float32)
        size = inputs.get("MasterXSize", 1)
        smooth = gaussian(n, size * self.px * 0.6)
        smooth /= smooth.std() + 1e-6
        rough = inputs.get("MasterRoughness", 0)
        n = smooth * (1 - rough) + n * rough
        # El grano se nota más en los medios tonos, como con Log Processing.
        rgb = img[..., :3]
        weight = 0.25 + 3 * np.clip(rgb, 0, 1) * (1 - np.clip(rgb, 0, 1))
        out = img.copy()
        out[..., :3] = rgb + n * inputs.get("MasterStrength", 0.25) * 0.5 * weight * img[..., 3:4]
        return self.finish(img, out, inputs)

    def Shake(self, inputs, name):
        period = max(1.0, inputs.get("Smoothness", 1) * 4)
        seed = int(inputs.get("RandomSeed", 0))
        x0, x1 = inputs.get("XMinimum", 0), inputs.get("XMaximum", 1)
        y0, y1 = inputs.get("YMinimum", 0), inputs.get("YMaximum", 1)
        return (x0 + (x1 - x0) * smooth_random(seed, self.time, period),
                y0 + (y1 - y0) * smooth_random(seed + 1, self.time, period))

    def Transform(self, inputs, name):
        img = self.src(inputs, "Input")
        center = inputs.get("Center", [0.5, 0.5])
        if isinstance(center, dict):
            center = self.get(center["from"])
        s = inputs.get("Size", 1)
        # En Fusion y crece hacia arriba; en la imagen, hacia abajo.
        dx, dy = (center[0] - 0.5) * self.w, -(center[1] - 0.5) * self.h
        data = (1 / s, 0, -(dx + self.w / 2) / s + self.w / 2, 0, 1 / s, -(dy + self.h / 2) / s + self.h / 2)
        out = np.stack([np.asarray(Image.fromarray(np.ascontiguousarray(img[..., c])).transform(
            (self.w, self.h), Image.AFFINE, data, resample=Image.BILINEAR)) for c in range(4)], axis=-1)
        return self.finish(img, out, inputs)

    def EllipseMask(self, inputs, name):
        w, h = inputs.get("Width", 0.5), inputs.get("Height", 0.5)
        soft = max(inputs.get("SoftEdge", 0), 1e-3)
        y, x = np.mgrid[0:self.h, 0:self.w]
        r = np.sqrt(((x + 0.5) / self.w - 0.5) ** 2 / (w / 2) ** 2 + ((y + 0.5) / self.h - 0.5) ** 2 / (h / 2) ** 2)
        mask = np.clip((1 + soft - r) / (2 * soft), 0, 1).astype(np.float32)
        return 1 - mask if inputs.get("Invert", 0) else mask


def main():
    effect_path, folder = sys.argv[1:3]
    data = json.loads(Path(effect_path).read_text(encoding="utf-8"))
    for frame in data["frames"]:
        path = Path(folder) / f"cuadro-{frame['time']:05d}.png"
        rgba = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255
        rgba[..., :3] *= rgba[..., 3:4]
        g = Graph(frame["tools"], rgba, frame["time"], rgba.shape[1])
        g.entry = data["input"]
        out = np.clip(g.get(data["output"]), 0, 1)
        alpha = np.maximum(out[..., 3:4], 1e-6)
        rgb = np.where(out[..., 3:4] > 0, out[..., :3] / alpha, 0)
        img = np.concatenate([rgb, out[..., 3:4]], axis=-1)
        Image.fromarray((img * 255 + 0.5).astype(np.uint8)).save(path)


if __name__ == "__main__":
    main()
