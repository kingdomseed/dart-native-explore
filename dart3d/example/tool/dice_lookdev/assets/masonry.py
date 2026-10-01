"""Coursed stone wall with a real opening and restrained hewn block relief."""

import bpy
import random

from . import geometry as G, materials as M


def build(name="Masonry wall", loc=(0, 0, 0), rot_z=0, width=440, height=260, thickness=18,
          tone=(0.15, 0.135, 0.12), wear=0.7, seed=8, openings=(), block_width=(23,49), course_height=(14,24),
          arris=(.7,1.5), relief=1.0) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    mats = [M.stone(f"{name} stone {i}", tuple(c * (0.74 + i * 0.13) for c in tone), wear, seed + i)
            for i in range(5)]
    mortar = M.stone(f"{name} recessed mortar", tuple(c * 0.27 for c in tone), wear, seed)
    z0 = 0
    while z0 < height - 0.1:
        z1 = min(height, z0 + rng.uniform(*course_height))
        cuts_z = sorted({z0, z1, *[z for _, z, _, _ in openings if z0 < z < z1],
                         *[z + h for _, z, _, h in openings if z0 < z + h < z1]})
        x0 = -width / 2
        while x0 < width / 2 - 0.1:
            x1 = min(width / 2, x0 + rng.uniform(*block_width))
            cuts_x = sorted({x0, x1, *[x - w / 2 for x, _, w, _ in openings if x0 < x - w / 2 < x1],
                             *[x + w / 2 for x, _, w, _ in openings if x0 < x + w / 2 < x1]})
            for left, right in zip(cuts_x[:-1], cuts_x[1:]):
                for bottom, top in zip(cuts_z[:-1], cuts_z[1:]):
                    cx, cz = (left + right) / 2, (bottom + top) / 2
                    if any(abs(cx - x) < w / 2 and z < cz < z + h for x, z, w, h in openings):
                        continue
                    if right - left < 1 or top - bottom < 1:
                        continue
                    a.block("Recessed rough mortar", (right - left + 0.05, thickness - 3, top - bottom + 0.05),
                            (cx, thickness / 2 + 1.5, cz), mortar, 0)
                    a.hewn_block("Hand dressed ashlar", (right - left - 0.85, thickness + rng.uniform(-1.1, 1.1)*relief, top - bottom - 0.65),
                                 (cx, thickness / 2 + rng.uniform(-0.7, 0.7)*relief, cz), rng.choice(mats),
                                 rng.uniform(*arris), wear, rng.randrange(100000))
            x0 = x1
        z0 = z1
    return a.root
