"""Gathered soft leather coin pouch with eyelets, drawstring and loose ends."""

import bpy
import math

from . import geometry as G, materials as M


def build(name="Coin pouch", loc=(0, 0, 0), rot_z=0, radius=6, height=11,
          tone=(0.09, 0.036, 0.012), metal_finish="brass", wear=0.6, seed=1, fabric="leather") -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    leather = (M.velvet(f"{name} velvet", tone, wear, seed, sheen_tone=tuple(c*1.4 for c in tone))
               if fabric == "velvet" else M.leather(f"{name} leather", tone, wear, seed))
    cord = (M.wool(f"{name} gold cord",(.35,.18,.035),seed) if fabric == "velvet"
            else M.leather(f"{name} thong", tuple(c * 2 for c in tone), wear, seed))
    metal = M.metal(f"{name} eyelets", metal_finish, wear, seed)
    profile = [(0.2, 0), (0.75, 0.04), (1, 0.2), (0.98, 0.42), (0.82, 0.67),
               (0.35, 0.84), (0.45, 0.93), (0.59, 1), (0.45, 1), (0.26, 0.85)]
    n = 64
    verts = []
    for r, z in profile:
        for j in range(n):
            t = math.tau * j / n
            fold = 1 + (0.03 + z * 0.12) * math.sin(t * 12 + z * 2 + seed)
            verts.append((r * radius * math.cos(t) * fold, r * radius * 0.85 * math.sin(t) * fold,
                          z * height + z * 0.24 * math.sin(t * 5)))
    faces = [(j * n + i, j * n + (i + 1) % n, (j + 1) * n + (i + 1) % n, (j + 1) * n + i)
             for j in range(len(profile) - 1) for i in range(n)]
    body=a.mesh("Gathered leather bag", verts, faces, leather, smooth=True)
    if fabric == "velvet":
        sub=body.modifiers.new("Soft velvet folds","SUBSURF")
        sub.levels=2;sub.render_levels=2
    a.ring("Tied drawstring", radius * (0.49 if fabric == "velvet" else 0.36), 0.16, (0, 0, height * 0.85), cord, ellipse=0.9)
    for i in range(10):
        t = math.tau * i / 10
        a.sphere("Small brass eyelet", 0.17, (radius * 0.38 * math.cos(t), radius * 0.32 * math.sin(t), height * 0.86), metal)
    if fabric == "velvet":
        for side in (-1,1):
            points=[(0,-radius*.50,height*.85),(side*1.7,-radius*.80,height*.69),
                    (side*2.7,-radius*.88,height*.44),(side*1.9,-radius*.84,height*.22)]
            a.tube("Hanging velvet bag cord",points,.15,cord)
            a.sphere("Cord tassel knot",.27,points[-1],cord)
        a.sphere("Drawstring bow knot",.38,(0,-radius*.50,height*.85),cord)
        return a.root
    for side in (-1, 1):
        a.tube("Drawstring end", [(0, -radius * 0.34, height * 0.85), (side * 2, -radius * 0.5, height * 0.65),
                                  (side * 2.7, -radius * 0.8, height * 0.44),
                                  (side * 1.9, -radius * 0.9, height * 0.22)], 0.15, cord)
        a.sphere("Cord knot", 0.26, (side * 1.9, -radius * 0.9, height * 0.22), cord)
    return a.root
