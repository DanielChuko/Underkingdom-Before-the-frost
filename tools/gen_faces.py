#!/usr/bin/env python3
"""Paint the characters' face textures procedurally.

The head mesh (scripts/characters/mesh_lib.gd) is a sculpted latitude-longitude
sphere, so its UVs are simply (longitude / 360°, latitude / 180°). This script
works out where every texel lands on the head and paints the face there:
weathered skin with pores and blotches, brows, eyelid creases, bags under the
eyes, crow's feet, forehead lines, the folds from nose to mouth, lips, stubble,
broken veins and grime. Several faces are painted from parameters:

    python3 tools/gen_faces.py      # writes assets/textures/face_*.png

The albedo is near-neutral skin; each character's skin colour tints it in game.
"""
import pathlib

import numpy as np
from PIL import Image

W, H = 1024, 512
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "textures"
RX, RY, RZ = 0.074, 0.108, 0.095

FACES = {
    # A guard in his thirties: wind-burned, stubbled, tired.
    "weathered": dict(seed=21, age=0.45, stubble=0.75, ruddy=0.35, bags=0.6, scar=False, grime=0.35, brow=0.85),
    # An older soldier with a scar across the cheek.
    "scarred": dict(seed=22, age=0.7, stubble=0.55, ruddy=0.25, bags=0.75, scar=True, grime=0.4, brow=0.9),
    # The king: pale, deeply lined, heavy-lidded.
    "old": dict(seed=23, age=1.0, stubble=0.0, ruddy=0.15, bags=0.9, scar=False, grime=0.1, brow=0.6),
    # The cook: flushed from the fire, broken veins on the nose.
    "ruddy": dict(seed=24, age=0.6, stubble=0.35, ruddy=0.85, bags=0.5, scar=False, grime=0.25, brow=0.75),
}


def noise(rng, beta, stretch=(1.0, 1.0)):
    """1/f noise in [0, 1], periodic horizontally (around the head)."""
    white = rng.standard_normal((H, W))
    fy = np.fft.fftfreq(H)[:, None] * stretch[1] * (H / W)
    fx = np.fft.fftfreq(W)[None, :] * stretch[0]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    n = np.real(np.fft.ifft2(np.fft.fft2(white) / f ** (beta / 2.0)))
    n -= n.min()
    return n / n.max()


def head_coords():
    """Head-local position (x, y, z) of each texel, matching mesh_lib.head_point."""
    v, u = np.mgrid[0:H, 0:W].astype(float)
    theta = (v + 0.5) / H * np.pi
    phi = (u + 0.5) / W * 2 * np.pi
    x = np.sin(theta) * np.cos(phi) * RX
    y = np.cos(theta) * RY
    z = np.sin(theta) * np.sin(phi) * RZ
    k = np.clip((-y - 0.01) / 0.09, 0, 1)
    low = y < -0.01
    x = np.where(low, x * (1 - 0.2 * k ** 1.3), x)
    z = np.where(low & (z > 0), z * (1 - 0.4 * k), z)
    y = np.where(y < -0.065, -0.065 - (-0.065 - y) * 0.55, y)
    front = np.clip(-z / RZ * 1.6 - 0.3, 0, 1)
    return x, y, z, front


def blob(x, y, cx, cy, sx, sy):
    return np.exp(-((x - cx) / sx) ** 2 - ((y - cy) / sy) ** 2)


def line(x, y, pts, width):
    """Soft polyline mask through head-local (x, y) points."""
    d = np.full(x.shape, 1e9)
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        abx, aby = bx - ax, by - ay
        t = np.clip(((x - ax) * abx + (y - ay) * aby) / (abx * abx + aby * aby), 0, 1)
        px, py = ax + abx * t, ay + aby * t
        d = np.minimum(d, np.hypot(x - px, y - py))
    return np.exp(-(d / width) ** 2)


def paint(name, seed, age, stubble, ruddy, bags, scar, grime, brow):
    rng = np.random.default_rng(seed)
    x, y, z, front = head_coords()
    pores = noise(rng, 0.6)
    blotch = noise(rng, 2.6)
    fine = noise(rng, 1.2)
    hairs = noise(rng, 0.9, stretch=(1.0, 0.35))

    # Base skin, near-neutral so the look's skin colour can tint it.
    r = 0.9 + (blotch - 0.5) * 0.12
    g = 0.86 + (blotch - 0.5) * 0.08
    b = 0.83 + (blotch - 0.5) * 0.06
    lum = 1.0 - (pores - 0.5) * 0.08
    height = (pores - 0.5) * 0.6

    redness = np.zeros_like(x)
    dark = np.zeros_like(x)  # multiplies down toward a cool shadow colour
    brown = np.zeros_like(x)  # hair-coloured marks (brows, stubble)

    for s in (-1, 1):
        # Brows: an arch over each eye, thicker near the nose, broken into hairs.
        bx = s * 0.031
        arch = line(x, y, [(s * 0.012, 0.031), (s * 0.026, 0.036), (s * 0.042, 0.035), (s * 0.052, 0.029)], 0.0042)
        taper = np.clip(1.15 - np.abs(x - s * 0.012) / 0.05, 0.3, 1.0)
        brown = np.maximum(brown, arch * taper * brow * (0.55 + hairs * 0.6) * front)
        # Eyelid crease and the shadow under the brow.
        crease = line(x, y, [(s * 0.018, 0.022), (s * 0.031, 0.026), (s * 0.044, 0.021)], 0.0018)
        dark += crease * 0.35 * front
        dark += blob(x, y, s * 0.033, 0.017, 0.016, 0.008) * 0.25 * front
        # Bags under the eyes: a dark crescent with a crease below it.
        bag = line(x, y, [(s * 0.02, 0.006), (s * 0.032, 0.002), (s * 0.045, 0.007)], 0.0035)
        dark += bag * 0.3 * bags * front
        under = line(x, y, [(s * 0.022, -0.002), (s * 0.034, -0.006), (s * 0.046, 0.0)], 0.0013)
        dark += under * 0.35 * bags * age * front
        height -= (crease + under * age) * 1.2
        # Crow's feet fanning from the outer corner of the eye.
        for a in (-0.5, -0.15, 0.2):
            ex, ey = s * 0.048, 0.015
            cf = line(x, y, [(ex, ey), (ex + s * 0.014 * np.cos(a), ey + 0.014 * np.sin(a))], 0.0009)
            dark += cf * 0.3 * age * front
            height -= cf * age * 0.8
        # Nose-to-mouth folds.
        fold = line(x, y, [(s * 0.013, -0.024), (s * 0.022, -0.036), (s * 0.028, -0.048), (s * 0.029, -0.06)], 0.0022)
        dark += fold * (0.22 + 0.25 * age) * front
        height -= fold * (0.8 + age)
        # Ruddy cheeks and wind-burn.
        redness += blob(x, y, s * 0.045, -0.018, 0.02, 0.018) * ruddy * front
        # Temples a touch darker and cooler.
        dark += blob(x, y, s * 0.06, 0.03, 0.015, 0.025) * 0.12

    # Forehead lines.
    for i, fy in enumerate((0.05, 0.058, 0.066)):
        wob = 0.0012 * np.sin(x * 160 + i * 2.0)
        fl = np.exp(-((y - fy - wob) / 0.0011) ** 2) * np.clip(1 - np.abs(x) / 0.045, 0, 1)
        dark += fl * 0.22 * age * front
        height -= fl * age * 0.9
    # Frown lines between the brows.
    for s in (-1, 1):
        fr = line(x, y, [(s * 0.005, 0.026), (s * 0.007, 0.04)], 0.0009)
        dark += fr * 0.25 * age * front
    # Nose: redder tip and wings, a highlight down the bridge.
    redness += blob(x, y, 0.0, -0.026, 0.012, 0.01) * (0.4 + ruddy * 0.6) * front
    for s in (-1, 1):
        dark += blob(x, y, s * 0.012, -0.031, 0.004, 0.003) * 0.45 * front  # nostril shadow
    lum += blob(x, y, 0.0, 0.0, 0.004, 0.02) * 0.05 * front
    # Broken veins on the nose and cheeks for ruddy faces.
    veins = np.clip((noise(rng, 0.5, stretch=(1.0, 3.0)) - 0.62) * 6, 0, 1)
    redness += veins * (blob(x, y, 0.0, -0.024, 0.014, 0.012) + blob(x, y, 0.04, -0.015, 0.012, 0.01) + blob(x, y, -0.04, -0.015, 0.012, 0.01)) * ruddy * 0.6 * front

    # Lips: upper lip darker, lower lip fuller with a highlight.
    upper = blob(x, y, 0.0, -0.0505, 0.021, 0.004)
    lower = blob(x, y, 0.0, -0.059, 0.019, 0.005)
    lips = np.clip(upper + lower, 0, 1) * front
    mouth = line(x, y, [(-0.022, -0.0535), (0.0, -0.0545), (0.022, -0.0535)], 0.0011) * front
    # Chin dimple and the shadow under the lower lip.
    dark += blob(x, y, 0.0, -0.068, 0.012, 0.004) * 0.25 * front

    # Stubble: beard area (jaw, chin, upper lip) speckled with dark hairs.
    jaw_front = np.clip(-z / RZ * 2.2 + 0.9, 0, 1)
    beard = np.clip((-y - 0.028) / 0.02, 0, 1) * jaw_front * np.clip((y + 0.1) / 0.015, 0, 1)
    beard = np.maximum(beard, blob(x, y, 0.0, -0.042, 0.022, 0.006))  # moustache line
    beard *= 1 - np.clip(lips * 1.3, 0, 1)
    beard *= np.clip(1 - blob(x, y, 0.0, -0.028, 0.02, 0.012) * 2, 0, 1)  # not on the nose
    speck = np.clip((noise(rng, 0.7) - 0.4) * 3, 0, 1)
    brown = np.maximum(brown, beard * stubble * (0.35 + speck * 0.6))

    # Grime: dirt in the creases and a general uneven tone.
    dirt = np.clip(noise(rng, 2.2) - 0.45, 0, 1) * grime
    lum *= 1 - dirt * 0.5 - (fine - 0.5) * 0.05

    # Scar: a pale, raised line across the left cheek.
    scar_m = np.zeros_like(x)
    if scar:
        scar_m = line(x, y, [(-0.058, 0.006), (-0.04, -0.012), (-0.026, -0.03)], 0.0016) * front
        height += scar_m * 2.0

    # Compose.
    col = np.stack([r, g, b], axis=-1) * lum[..., None]
    red_tint = np.array([1.0, 0.72, 0.68])
    col = col * (1 - np.clip(redness, 0, 1)[..., None] * 0.35) + col * red_tint * np.clip(redness, 0, 1)[..., None] * 0.35
    shadow = np.array([0.55, 0.45, 0.45])
    dk = np.clip(dark, 0, 0.85)[..., None]
    col = col * (1 - dk) + col * shadow * dk
    lip_col = np.array([0.72, 0.46, 0.43])
    col = col * (1 - lips[..., None] * 0.6) + lip_col * lips[..., None] * 0.6
    col *= 1 - mouth[..., None] * 0.55
    hair_col = np.array([0.2, 0.16, 0.13])
    br = np.clip(brown, 0, 1)[..., None]
    col = col * (1 - br * 0.85) + hair_col * br * 0.85
    col = col * (1 - scar_m[..., None] * 0.5) + np.array([0.95, 0.82, 0.78]) * scar_m[..., None] * 0.5

    rough = 0.62 + (pores - 0.5) * 0.1 - blob(x, y, 0.0, 0.0, 0.03, 0.06) * 0.12 * front - lips * 0.15 + brown * 0.2
    save(f"face_{name}", col, height, rough)


def save(name, albedo, height, rough):
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8), "RGB").save(OUT / f"{name}_albedo.png", optimize=True)
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 1.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 1.5
    n = np.stack([-dx, dy, np.ones_like(height)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(OUT / f"{name}_normal.png", optimize=True)
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").save(OUT / f"{name}_rough.png", optimize=True)
    print("wrote", name)


if __name__ == "__main__":
    for face_name, params in FACES.items():
        paint(face_name, **params)
