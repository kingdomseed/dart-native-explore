"""Thick diner porcelain, rolled lip, swept handle, coffee and soft steam sheets."""
import bpy
import math
import env_common as E
from . import geometry as G, materials as M


def build(name="Diner coffee", loc=(0, 0, 0), rot_z=0, height=10, radius=4.2,
          tone=(0.7, 0.64, 0.49), wear=0.3, seed=1, steam_height=12,
          steam_strength=1.2, steam_width=1, steam_drift=0) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    glaze = M.ceramic(f"{name} glaze", tone, wear, seed)
    profile = [(0, 0.12), (radius * 0.68, 0.12), (radius * 0.74, 0), (radius * 0.87, 0),
               (radius * 0.92, 0.5), (radius * 0.98, height * 0.7), (radius, height - 0.2),
               (radius * 0.97, height), (radius * 0.89, height), (radius * 0.86, height - 0.3),
               (radius * 0.82, 1), (0, 1)]
    a.lathe("Thick porcelain cup", profile, glaze, segments=64)
    pts = [(radius * 0.9 + radius * 0.73 * math.sin(t), 0,
            height * 0.51 + height * 0.33 * math.cos(t)) for t in [math.pi * i / 40 for i in range(41)]]
    a.tube("Rounded ear handle", pts, radius * 0.16, glaze, resolution=3)
    coffee = E.simple(f"{name} dark roast", (0.019, 0.007, 0.002), 0.16, Coat_Weight=1, IOR=1.33)
    a.cylinder("Coffee meniscus", radius * 0.86, 0.09, (0, 0, height - 0.85), coffee, bevel=0.03, segments=64)
    ring = E.simple(f"{name} crema", (0.09, 0.033, 0.009), 0.35)
    a.ring("Coffee edge", radius * 0.845, 0.055, (0, 0, height - 0.8), ring)
    if steam_height:
        steam = M.steam(f"{name} steam", steam_strength)
        for layer in range(2):
            verts, uv = [], []
            for j in range(25):
                t = j / 24
                center = math.sin(t * 8 + layer * 2) * (0.3 + t * 1.2) + steam_drift * t
                width = (0.35 + t * 1.2) * steam_width
                for i in range(7):
                    u = i / 6
                    verts.append((center + (u * 2 - 1) * width, layer * 0.6 + math.sin(t * 5) * 0.5, height + t * steam_height))
                    uv.append((u, t))
            faces = [(j * 7 + i, j * 7 + i + 1, (j + 1) * 7 + i + 1, (j + 1) * 7 + i) for j in range(24) for i in range(6)]
            ob = a.mesh("Faint curling steam", verts, faces, steam, smooth=True)
            tex = ob.data.uv_layers.new()
            for loop in ob.data.loops: tex.data[loop.index].uv = uv[loop.vertex_index]
            ob.visible_shadow = False
    return a.root
