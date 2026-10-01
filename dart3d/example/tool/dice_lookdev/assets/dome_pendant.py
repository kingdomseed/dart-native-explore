"""Spun chrome dome pendant with a rolled lip, porcelain interior and warm bulb."""
import bpy
import math
import env_common as E
from . import geometry as G, materials as M


def build(name="Dome pendant", loc=(0, 0, 0), rot_z=0, radius=17, height=21, drop=75,
          tone=(0.65, 0.68, 0.72), wear=0.25, seed=1, energy=50000, color=(1, 0.55, 0.23), finish="chrome",
          recessed_bulb=False) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    chrome = (M.ceramic if finish == "enamel" else M.polished_metal)(f"{name} shade", tone, wear, seed)
    lining = M.ceramic(f"{name} enamel lining", (0.7, 0.65, 0.5), wear, seed)
    profile = [(radius * math.cos(t), height * math.sin(t)) for t in [math.pi * 0.5 * i / 24 for i in range(25)]]
    a.lathe("Spun metal dome", profile, chrome, segments=64)
    a.lathe("Warm enamel reflector", [(max(0, r - 0.28), z - 0.22) for r, z in profile], lining, segments=64)
    a.ring("Rolled shade lip", radius, 0.35, (0, 0, 0), chrome, segments=64)
    a.cylinder("Cable socket", 2.8, 6, (0, 0, height + 2), chrome, bevel=0.4)
    rubber = E.simple(f"{name} cord", (0.004, 0.004, 0.006), 0.6)
    a.cylinder("Flex cable", 0.22, drop, (0, 0, height + 5 + drop / 2), rubber, bevel=0)
    bulb = E.emissive(f"{name} tungsten bulb", (1, 0.65, 0.28), 9)
    a.cylinder("Porcelain bulb socket", 1.6, 9, (0, 0, height*.62 if recessed_bulb else -1), lining, bevel=0.3)
    a.sphere("Warm globe", radius * 0.23, (0, 0, radius*.27 if recessed_bulb else -radius * 0.42), bulb, scale=(1, 1, 1.28), subdiv=3)
    a.light("Pendant pool", (0, 0, -1), energy, color, radius * 0.62, target=(0, 0, -100), kind="AREA")
    return a.root
