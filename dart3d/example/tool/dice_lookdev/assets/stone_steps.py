"""Broad dressed-stone steps connecting two true-scale floor levels."""
import random
import bpy
from . import geometry as G, materials as M


def build(name="Stone steps", loc=(0, 0, 0), rot_z=0, width=180, tread=15,
          rise=10, count=3, tone=(0.065, 0.06, 0.05), wear=0.7, seed=5) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    mats = [M.stone(f"{name} flag {i}", tuple(c * (0.8 + i * 0.13) for c in tone), wear, seed + i) for i in range(4)]
    mortar = M.stone(f"{name} mortar", (0.018, 0.016, 0.013), wear, seed)
    stones = max(2, round(width / 36))
    for step in range(count):
        h = (count - step) * rise
        a.block("Step core", (width - 0.4, tread - 2.7, h - 2),
                (0, (step + 0.5) * tread - 1.35, (h - 2) / 2), mortar, 0.1)
        for i in range(stones):
            x = -width / 2 + (i + 0.5) * width / stones
            a.block("Worn stone tread", (width / stones - 0.3, tread - 0.15, 2.5),
                    (x, (step + 0.5) * tread, h - 1.25), rng.choice(mats), 0.45)
            a.hewn_block("Dressed riser", (width / stones - 0.4, 2.5, h - 2.7),
                         (x, (step + 1) * tread - 1.4, (h - 2.7) / 2), rng.choice(mats),
                         bevel=0.45, wear=wear * 0.25, seed=seed * 100 + step * 20 + i)
    return a.root
