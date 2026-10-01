"""Turned chrome pie stand, fluted crust and lattice under a glass cloche."""
import bpy
import math
import env_common as E
from . import geometry as G, materials as M


def build(name="Pie stand", loc=(0, 0, 0), rot_z=0, radius=15, height=16, wear=0.3, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    chrome = M.polished_metal(f"{name} metal", wear=wear, seed=seed)
    a.lathe("Pedestal platter", [(0, 0), (radius * 0.58, 0), (radius * 0.61, 1), (radius * 0.48, 2),
                                (radius * 0.12, height - 4), (radius * 0.25, height - 2),
                                (radius, height - 1), (radius * 1.02, height), (0, height)], chrome)
    pastry = M.pastry(f"{name} pastry", seed=seed)
    filling = E.simple(f"{name} fruit", (0.12, 0.017, 0.008), 0.32)
    a.lathe("Baked pie", [(0, height), (radius * 0.74, height), (radius * 0.83, height + 4),
                         (radius * 0.83, height + 5), (0, height + 5)], pastry)
    a.cylinder("Fruit filling", radius * 0.77, 0.8, (0, 0, height + 4.8), filling)
    for i in range(36):
        t = i * math.tau / 36
        a.sphere("Crimped crust", 0.72, (radius * 0.81 * math.cos(t), radius * 0.81 * math.sin(t), height + 4.8), pastry, scale=(1, 1, 0.65))
    for d in (-1, 1):
        for i in range(-4, 5):
            y = i * radius * 0.16
            reach = math.sqrt((radius * 0.76) ** 2 - y ** 2)
            pts = [(x, y, height + 5.4 + 0.15 * math.sin(x)) if d == 1 else (y, x, height + 5.6 + 0.15 * math.sin(x))
                   for x in [-reach + 2 * reach * j / 12 for j in range(13)]]
            a.tube("Woven pastry lattice", pts, 0.36, pastry)
    glass = M.glass(f"{name} clear cloche", (0.85, 0.9, 1), reflection=0.13)
    profile = [(radius * 0.97, height + 0.2), (radius * 0.99, height + 1)]
    profile += [(radius * 0.98 * math.cos(t), height + 2 + radius * 0.86 * math.sin(t)) for t in [math.pi * 0.5 * i / 28 for i in range(29)]]
    a.lathe("Blown glass cloche", profile, glass, segments=64)
    a.sphere("Cloche knob", 1.9, (0, 0, height + 3 + radius * 0.86), glass, scale=(1, 1, 1.3), subdiv=3)
    return a.root
