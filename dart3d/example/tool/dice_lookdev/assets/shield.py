"""Dished round shield with boss, rolled rim and riveted radial straps."""

import bpy
import math

from . import geometry as G, materials as M


def build(name="Iron shield", loc=(0, 0, 0), rot_z=0, radius=27, metal_finish="iron", wear=0.8, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    iron = M.metal(f"{name} plate", metal_finish, wear, seed)
    bright = M.metal(f"{name} edge", "steel", wear, seed)
    dish = a.lathe("Dished shield", [(0, 4), (radius * 0.2, 4), (radius * 0.7, 2),
                                    (radius, 0), (radius, -0.7), (radius * 0.7, 1.3), (0, 3.3)], iron)
    dish.rotation_euler.x = math.pi / 2
    a.ring("Rolled shield rim", radius, 0.9, (0, 0, 0), bright, plane="XZ")
    a.sphere("Shield boss", radius * 0.21, (0, -4.2, 0), bright, scale=(1, 0.5, 1), subdiv=3)
    for i in range(12):
        t = math.tau * i / 12
        a.sphere("Shield rim rivet", 0.65, (radius * 0.92 * math.cos(t), -1.1, radius * 0.92 * math.sin(t)), bright)
        if i % 3 == 0:
            a.beam("Raised shield rib", (radius * 0.25 * math.cos(t), -3.7, radius * 0.25 * math.sin(t)),
                   (radius * 0.9 * math.cos(t), -1, radius * 0.9 * math.sin(t)), 2.2, 0.65, bright, 0.2)
    return a.root
