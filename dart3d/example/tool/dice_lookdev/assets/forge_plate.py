"""Thin forged support plate with a softly hammered rolled edge."""
import random
import bpy
import env_common as E
from . import geometry as G, materials as M


def build(name="Forge plate", loc=(0, 0, 0), rot_z=0, width=19.8, depth=35.8,
          thickness=1.2, metal_finish="iron", wear=0.7, seed=5) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    outline = E.rounded_rect(width, depth, 2.5, seg=12)
    verts = []
    for scale, z in ((0.98, -thickness), (1, -thickness + 0.22), (1, -0.22), (0.985, 0)):
        for x, y in outline:
            verts.append((x * scale + rng.uniform(-0.035, 0.035) * wear,
                          y * scale + rng.uniform(-0.035, 0.035) * wear, z))
    n = len(outline)
    faces = [tuple(reversed(range(n))), tuple(range(n * 3, n * 4))]
    faces += [(j * n + i, j * n + (i + 1) % n, (j + 1) * n + (i + 1) % n, (j + 1) * n + i)
              for j in range(3) for i in range(n)]
    a.mesh("forge_slab", verts, faces, M.metal(f"{name} hammered edge", metal_finish, wear, seed), bevel=0.04)
    return a.root
