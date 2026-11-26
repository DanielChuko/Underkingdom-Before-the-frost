#!/usr/bin/env python3
"""Generate the game's tileable surface textures procedurally.

Every texture in assets/textures/ is produced by this script from seeded
random noise, so the art is fully original and reproducible:

    python3 tools/gen_textures.py            # writes assets/textures/*.png

Each surface gets <name>_albedo.png, <name>_normal.png (OpenGL / Y+ convention,
as Godot expects) and <name>_rough.png. All textures tile seamlessly because
every pattern is built on a periodic grid (noise is filtered in the frequency
domain, cell layouts wrap around the edges).
"""
import pathlib

import numpy as np
from PIL import Image

SIZE = 512
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "textures"


# --- Building blocks ---------------------------------------------------------

def fractal_noise(rng, size=SIZE, beta=2.0, stretch=(1.0, 1.0)):
    """Tileable 1/f^beta noise in [0, 1]. stretch=(sx, sy) elongates features."""
    white = rng.standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None] * stretch[1]
    fx = np.fft.fftfreq(size)[None, :] * stretch[0]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spectrum = np.fft.fft2(white) / f ** (beta / 2.0)
    spectrum[0, 0] = 0.0
    n = np.real(np.fft.ifft2(spectrum))
    n -= n.min()
    return n / n.max()


def band_noise(rng, lo, hi, size=SIZE):
    """Tileable noise containing only spatial frequencies between lo and hi cycles."""
    white = rng.standard_normal((size, size))
    fy = np.fft.fftfreq(size)[:, None] * size
    fx = np.fft.fftfreq(size)[None, :] * size
    f = np.sqrt(fx * fx + fy * fy)
    mask = ((f >= lo) & (f <= hi)).astype(float)
    n = np.real(np.fft.ifft2(np.fft.fft2(white) * mask))
    n -= n.min()
    return n / max(n.max(), 1e-9)


def periodic_voronoi(rng, count, size=SIZE, jitter=1.0):
    """Returns (cell_id, edge_distance_px) for a seamlessly wrapping Voronoi diagram."""
    grid = int(np.sqrt(count))
    cell = size / grid
    pts = []
    for gy in range(grid):
        for gx in range(grid):
            pts.append(((gx + 0.5 + (rng.random() - 0.5) * jitter) * cell,
                        (gy + 0.5 + (rng.random() - 0.5) * jitter) * cell))
    pts = np.array(pts)
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    d1 = np.full((size, size), np.inf)
    d2 = np.full((size, size), np.inf)
    ids = np.zeros((size, size), dtype=int)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dx = np.minimum(dx, size - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, size - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        ids = np.where(closer, i, ids)
        d1 = np.where(closer, d, d1)
    return ids, (d2 - d1) * 0.5


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * strength
    n = np.stack([-dx, dy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def save(name, albedo, height, rough, normal_strength):
    OUT.mkdir(parents=True, exist_ok=True)
    rgb = np.clip(albedo, 0, 1)
    Image.fromarray((rgb * 255).astype(np.uint8), "RGB").save(OUT / f"{name}_albedo.png", optimize=True)
    nrm = normal_from_height(height, normal_strength)
    Image.fromarray((nrm * 255).astype(np.uint8), "RGB").save(OUT / f"{name}_normal.png", optimize=True)
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").save(OUT / f"{name}_rough.png", optimize=True)
    print("wrote", name)


def tint(gray, color):
    return gray[..., None] * np.array(color)[None, None, :]


def bevel(dist, width):
    """0 at an edge rising smoothly to 1 at `width` pixels inside."""
    t = np.clip(dist / width, 0, 1)
    return t * t * (3 - 2 * t)


# --- Surfaces --------------------------------------------------------------------

def blocks_layout(rng, rows, min_w, max_w, size=SIZE, row_offset=True):
    """Running-bond blocks that wrap seamlessly. Returns (block_id, edge_distance)."""
    row_h = size // rows
    ids = np.zeros((size, size), dtype=int)
    dist = np.zeros((size, size))
    xs = np.arange(size)
    next_id = 0
    for r in range(rows):
        cuts = []
        x = rng.integers(0, max_w) if row_offset else 0
        start = x
        while True:
            w = int(rng.integers(min_w, max_w + 1))
            if x + w >= start + size - min_w:
                break
            x += w
            cuts.append(x % size)
        cuts.append(start % size)
        cuts = sorted(set(cuts))
        # distance to nearest cut, wrapping
        dc = np.min([np.minimum(np.abs(xs - c), size - np.abs(xs - c)) for c in cuts], axis=0)
        seg = np.searchsorted(cuts, xs, side="right") % len(cuts)
        y0, y1 = r * row_h, (r + 1) * row_h
        ys = np.arange(y0, y1)
        dy = np.minimum(ys - y0, y1 - 1 - ys)
        dist[y0:y1] = np.minimum(dc[None, :], dy[:, None])
        ids[y0:y1] = next_id + seg[None, :]
        next_id += len(cuts)
    return ids, dist


def stone_wall(seed=1):
    rng = np.random.default_rng(seed)
    ids, dist = blocks_layout(rng, rows=6, min_w=110, max_w=200)
    coarse = fractal_noise(rng, beta=2.2)
    fine = band_noise(rng, 40, 200)
    chips = band_noise(rng, 8, 30)
    tints = rng.uniform(-0.09, 0.09, ids.max() + 1)
    warm = rng.uniform(-0.03, 0.03, ids.max() + 1)
    edge = dist + (chips - 0.5) * 6.0
    mortar = edge < 3.5
    face = bevel(edge - 3.5, 9.0)
    height = np.where(mortar, 0.0, 0.55 + 0.45 * face) + coarse * 0.25 + fine * 0.12
    base = 0.48 + tints[ids] + (coarse - 0.5) * 0.18 + (fine - 0.5) * 0.12
    stone = np.stack([base + warm[ids] + 0.035, base + 0.012, base - warm[ids] - 0.02], axis=-1)
    stone *= (0.82 + 0.18 * face)[..., None]
    mortar_col = tint(0.33 + fine * 0.08, (1.0, 0.94, 0.84))
    albedo = np.where(mortar[..., None], mortar_col, stone)
    rough = np.where(mortar, 0.97, 0.78 + fine * 0.15)
    save("stone_wall", albedo, height * 40.0, rough, 0.06)


def flagstone(seed=2):
    rng = np.random.default_rng(seed)
    ids, edge = periodic_voronoi(rng, 16, jitter=0.8)
    coarse = fractal_noise(rng, beta=2.0)
    fine = band_noise(rng, 50, 220)
    wear = fractal_noise(rng, beta=3.0)
    tints = rng.uniform(-0.08, 0.08, ids.max() + 1)
    gap = edge < 4.0
    face = bevel(edge - 4.0, 14.0)
    height = np.where(gap, 0.0, 0.5 + 0.5 * face) + coarse * 0.2 + fine * 0.1
    base = 0.4 + tints[ids] + (coarse - 0.5) * 0.15 + (fine - 0.5) * 0.08 + (wear - 0.5) * 0.1
    stone = np.stack([base + 0.03, base + 0.015, base - 0.01], axis=-1) * (0.85 + 0.15 * face)[..., None]
    dirt = tint(0.18 + fine * 0.06, (1.0, 0.85, 0.65))
    albedo = np.where(gap[..., None], dirt, stone)
    rough = np.where(gap, 1.0, 0.7 + wear * 0.2)
    save("flagstone", albedo, height * 40.0, rough, 0.06)


def planks(name, seed, color, plank_count, darkness=1.0, joints=True):
    rng = np.random.default_rng(seed)
    size = SIZE
    pw = size // plank_count
    grain = fractal_noise(rng, beta=2.0, stretch=(1.0, 14.0))
    rings = band_noise(rng, 20, 60)
    knots_n = band_noise(rng, 3, 8)
    xs = np.arange(size)
    plank = xs // pw
    dx = np.minimum(xs % pw, pw - 1 - xs % pw)
    dist = np.tile(dx[None, :].astype(float), (size, 1))
    ids = np.tile(plank[None, :], (size, 1))
    if joints:
        ys = np.arange(size)
        for p in range(plank_count):
            # Two butt joints per column so the piece crossing the texture edge
            # keeps one id (and one tint) on both sides of the wrap.
            c1 = int(rng.integers(0, size // 2))
            c2 = c1 + int(rng.integers(size // 4, size // 2))
            cols = slice(p * pw, (p + 1) * pw)
            for cut in (c1, c2):
                dy = np.minimum(np.abs(ys - cut), size - np.abs(ys - cut))
                dist[:, cols] = np.minimum(dist[:, cols], dy[:, None])
            ids[:, cols] = np.where(((ys >= c1) & (ys < c2))[:, None], p + plank_count, p)
    tints = rng.uniform(-0.12, 0.12, 2 * plank_count + 1)
    # Grain: streaks along Y, offset per plank so neighbours differ.
    g = np.zeros((size, size))
    for p in range(2 * plank_count):
        shift = int(rng.integers(0, size))
        g = np.where(ids == p, np.roll(grain, shift, axis=1), g)
    streak = 0.5 + 0.5 * np.sin(g * 40.0 + rings * 3.0)
    knot = np.clip((knots_n - 0.85) * 8.0, 0, 1)
    gap = dist < 2.0
    face = bevel(dist - 2.0, 5.0)
    lum = (0.75 + tints[ids] + (streak - 0.5) * 0.22 - knot * 0.35) * darkness
    albedo = tint(lum, color) * (0.85 + 0.15 * face)[..., None]
    albedo = np.where(gap[..., None], tint(np.full((size, size), 0.12), color), albedo)
    height = np.where(gap, 0.0, 0.6 + 0.4 * face) + streak * 0.08 - knot * 0.1
    rough = np.where(gap, 1.0, 0.68 + streak * 0.12)
    save(name, albedo, height * 30.0, rough, 0.08)


def cloth(seed=5):
    """Neutral woven cloth; tinted per material (banners, carpet, bedding)."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(float)
    threads = 128  # cycles across the texture
    warp = 0.5 + 0.5 * np.sin(xx / SIZE * 2 * np.pi * threads)
    weft = 0.5 + 0.5 * np.sin(yy / SIZE * 2 * np.pi * threads)
    checker = ((np.floor(xx / SIZE * threads * 2) + np.floor(yy / SIZE * threads * 2)) % 2)
    weave = np.where(checker > 0, warp, weft)
    blotch = fractal_noise(rng, beta=2.5)
    fuzz = band_noise(rng, 100, 256)
    lum = 0.78 + (weave - 0.5) * 0.18 + (blotch - 0.5) * 0.12 + (fuzz - 0.5) * 0.06
    albedo = tint(lum, (1.0, 1.0, 1.0))
    save("cloth", albedo, (weave * 0.6 + blotch * 0.4) * 6.0, 0.92 + fuzz * 0.08, 0.15)


def plaster(seed=6):
    rng = np.random.default_rng(seed)
    coarse = fractal_noise(rng, beta=2.6)
    fine = band_noise(rng, 60, 256)
    cracks = band_noise(rng, 10, 24)
    crack = np.clip(1.0 - np.abs(cracks - 0.5) * 60.0, 0, 1) * (coarse > 0.6)
    lum = 0.74 + (coarse - 0.5) * 0.12 + (fine - 0.5) * 0.05 - crack * 0.25
    albedo = tint(lum, (1.0, 0.95, 0.86))
    height = coarse * 0.6 + fine * 0.3 - crack * 0.5
    save("plaster", albedo, height * 25.0, 0.9 + fine * 0.1, 0.05)


def mud(seed=7):
    rng = np.random.default_rng(seed)
    coarse = fractal_noise(rng, beta=2.4)
    mid = band_noise(rng, 12, 60)
    fine = band_noise(rng, 80, 256)
    wet = np.clip((coarse - 0.62) * 6.0, 0, 1)
    lum = 0.42 + (mid - 0.5) * 0.2 + (fine - 0.5) * 0.1 - wet * 0.18
    albedo = tint(lum, (0.62, 0.48, 0.33))
    height = coarse * 0.5 + mid * 0.4 + fine * 0.2 - wet * 0.3
    rough = 0.95 - wet * 0.55
    save("mud", albedo, height * 30.0, rough, 0.06)


def cobbles(seed=8):
    rng = np.random.default_rng(seed)
    ids, edge = periodic_voronoi(rng, 64, jitter=0.9)
    fine = band_noise(rng, 60, 220)
    coarse = fractal_noise(rng, beta=2.2)
    tints = rng.uniform(-0.1, 0.1, ids.max() + 1)
    dome = np.sqrt(np.clip(edge / 18.0, 0, 1))
    gap = edge < 2.5
    height = np.where(gap, 0.0, dome) + fine * 0.1
    lum = 0.46 + tints[ids] + (fine - 0.5) * 0.1 + (coarse - 0.5) * 0.1
    stone = np.stack([lum + 0.02, lum, lum - 0.02], axis=-1) * (0.8 + 0.2 * dome)[..., None]
    dirt = tint(0.22 + fine * 0.05, (0.9, 0.75, 0.55))
    albedo = np.where(gap[..., None], dirt, stone)
    save("cobbles", albedo, height * 40.0, np.where(gap, 1.0, 0.75), 0.08)


if __name__ == "__main__":
    stone_wall()
    flagstone()
    planks("wood_floor", 3, (0.62, 0.43, 0.27), plank_count=6)
    planks("wood_dark", 4, (0.45, 0.3, 0.18), plank_count=4, darkness=0.85)
    cloth()
    plaster()
    mud()
    cobbles()
