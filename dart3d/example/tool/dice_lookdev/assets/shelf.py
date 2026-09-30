"""Bracketed wall shelves populated with varied turned vessels."""

import bpy
import random

from . import geometry as G, materials as M, vessel


def build(name="Shelf", loc=(0, 0, 0), rot_z=0, width=85, depth=22, levels=2, spacing=35,
          wood_tone=(0.1, 0.038, 0.013), metal_finish="iron", wear=0.6, seed=3, count=None) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    wood = M.oak(f"{name} oak", wood_tone, wear, seed)
    iron = M.metal(f"{name} brackets", metal_finish, wear, seed)
    rng = random.Random(seed)
    count = count if count is not None else max(3, round(width / 18))
    for level in range(levels):
        z = level * spacing
        a.block("Shelf board", (width, depth, 3.5), (0, -depth / 2, z), wood, 0.4)
        a.block("Shelf front moulding", (width + 1, 2, 4), (0, -depth + 0.3, z - 0.3), wood, 0.35)
        for x in (-width * 0.37, width * 0.37):
            a.beam("Shelf bracket", (x, -2, z - 19), (x, -depth + 2, z - 2), 2, 2, iron, 0.3)
            a.block("Wall bracket plate", (3, 1.5, 21), (x, -1, z - 9), iron, 0.2)
        for i in range(count):
            kind = ("tankard", "jar", "bottle", "jar", "bottle")[(i + level) % 5]
            h = rng.uniform(13, 22) if kind != "bottle" else rng.uniform(21, 27)
            tone = rng.choice(((0.08, 0.12, 0.055), (0.16, 0.065, 0.022), (0.09, 0.072, 0.04)))
            a.add(vessel.build(f"{name} {kind} {level}-{i}", loc=((i - (count - 1) / 2) * width / (count + 0.5), -depth * 0.53, z + 1.75),
                               rot_z=rng.uniform(-1, 1), kind=kind, height=h, radius=rng.uniform(3.3, 5),
                               metal_finish="pewter", tone=tone, wear=wear, seed=seed + i + level * 8))
    return a.root
