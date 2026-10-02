"""Beeswax candles, pooled wax, drips, wicks and small flame surfaces."""

import bpy
import math
import random

import env_common as E
from . import geometry as G, materials as M
from .forge import fire_tongue


def build(name="Candles", loc=(0, 0, 0), rot_z=0, height=12, radius=2, count=3,
          tone=(0.58, 0.35, 0.12), wear=0.6, seed=1, energy=1500, drips=5) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    wax = E.simple(f"{name} beeswax", tone, 0.72, Subsurface_Weight=0.08)
    iron = M.metal(f"{name} dish", wear=wear, seed=seed)
    flame = M.flame(f"{name} fire", 4)
    a.lathe("Candle drip pan", [(0, 0), (radius * 3.3, 0), (radius * 3.6, 0.8),
                              (radius * 3.5, 1.4), (radius * 3.2, 0.4), (0, 0.4)], iron)
    for i in range(count):
        t = math.tau * i / count
        x, y = (radius * 1.3 * math.cos(t), radius * 1.3 * math.sin(t)) if count > 1 else (0, 0)
        h = height * rng.uniform(0.6, 1)
        a.cylinder("Used candle", radius, h, (x, y, 0.5 + h / 2), wax, bevel=0.25)
        a.sphere("Wax pool", radius * 1.35, (x, y, 0.6), wax, scale=(1, 1, 0.13))
        for j in range(drips):
            angle = rng.uniform(0, math.tau)
            xx, yy = x + radius * math.cos(angle), y + radius * math.sin(angle)
            length = rng.uniform(1, h * 0.55)
            a.tube("Cooled wax drip", [(xx, yy, h + 0.3), (xx, yy, h + 0.3 - length)], 0.17, wax)
            a.sphere("Wax teardrop", 0.23, (xx, yy, h + 0.3 - length), wax, scale=(1, 1, 1.3))
        a.cylinder("Wick", 0.09, 0.9, (x, y, h + 0.7), iron, bevel=0)
        fire_tongue(a, "Small candle flame", (x, y, h + 0.7), 0.45, 2.6, flame, lean=0.3)
    a.light("Candle glow", (0, 0, height + 1), energy, (1, 0.51, 0.19), 3)
    return a.root
