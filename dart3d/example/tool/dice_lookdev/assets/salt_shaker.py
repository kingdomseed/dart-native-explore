"""Fluted clear-glass shaker, granular salt and perforated polished cap."""
import bpy
import math
import random
import env_common as E
from . import geometry as G, materials as M


def build(name="Salt shaker", loc=(0, 0, 0), rot_z=0, height=11, radius=2.1, wear=0.3, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    glass = M.clear_glass(f"{name} glass")
    chrome = M.polished_metal(f"{name} cap", wear=wear, seed=seed)
    profile = [(0, 0), (radius * 0.9, 0), (radius, 0.3), (radius, height * 0.64),
               (radius * 0.83, height * 0.76), (radius * 0.7, height * 0.82),
               (radius * 0.61, height * 0.82), (radius * 0.76, height * 0.71),
               (radius * 0.87, 0.65), (0, 0.65)]
    a.lathe("Fluted glass vessel", profile, glass, segments=12)
    for i in range(12):
        t = math.tau * i / 12
        a.tube("Glass flute", [(radius * 0.96 * math.cos(t), radius * 0.96 * math.sin(t), 0.6),
                                (radius * 0.96 * math.cos(t), radius * 0.96 * math.sin(t), height * 0.63)], 0.065, glass)
    salt, k = E.material(f"{name} salt")
    n = k.noise(k.coords().outputs["Object"], 11, 2).outputs["Fac"]
    k.surface(k.bsdf(Base_Color=(0.76, 0.74, 0.66, 1), Roughness=0.92, Normal=k.bump(n, 0.4, 0.018)))
    a.cylinder("Salt fill", radius * 0.83, height * 0.52, (0, 0, height * 0.3), salt, segments=32)
    a.lathe("Domed screw cap", [(0, height * 0.98), (radius * 0.35, height), (radius * 0.78, height * 0.96),
                                (radius * 0.81, height * 0.86), (radius * 0.78, height * 0.8)], chrome)
    dark = E.simple(f"{name} cap holes", (0.002, 0.002, 0.002), 1)
    for i in range(7):
        t = i * math.tau / 6
        r = radius * 0.42 if i < 6 else 0
        a.sphere("Dispensing hole", radius * 0.066, (r * math.cos(t), r * math.sin(t), height * 0.988), dark, scale=(1, 1, 0.18))
    for z in (height * 0.82, height * 0.86):
        a.ring("Cap rolled seam", radius * 0.8, 0.045, (0, 0, z), chrome)
    for ob in a.root.children_recursive:
        if ob.type == "MESH" and glass in ob.data.materials[:]: ob.visible_shadow = False
    return a.root
