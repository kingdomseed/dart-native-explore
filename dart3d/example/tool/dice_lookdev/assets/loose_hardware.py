"""Loose forged chain and blank hammered counters for tabletop dressing."""
import math
import random
import bpy
from . import geometry as G, materials as M


def build(name="Loose iron hardware", loc=(0, 0, 0), rot_z=0, length=16,
          metal_finish="iron", wear=0.8, seed=8, coins=5) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    iron = M.metal(f"{name} worn iron", metal_finish, wear, seed)
    for i in range(round(length / 2.1)):
        x, y = -length / 2 + i * 2.1, math.sin(i * 0.5) * 0.45
        tilt = math.pi / 4 * (1 if i % 2 else -1)
        pts = [(x + 1.32 * math.cos(t), y + 0.74 * math.sin(t) * math.cos(tilt),
                0.18 + 0.74 * math.sin(math.pi / 4) + 0.74 * math.sin(t) * math.sin(tilt))
               for t in (j * math.tau / 24 for j in range(24))]
        a.tube("Resting interlocked chain link", pts, 0.18, iron, cyclic=True)
    for i in range(coins):
        x, y = rng.uniform(-length * 0.45, length * 0.45), rng.uniform(3, 6)
        coin = a.cylinder("Blank hammered iron counter", rng.uniform(0.9, 1.3), 0.17, (x, y, 0.085), iron, 0.07, 24)
        coin.rotation_euler.z = rng.random() * math.tau
    return a.root
