"""Deep stone reveal, clipped diamond cames, and a procedural night exterior."""

import bpy
import math
import random

import env_common as E
from . import geometry as G, materials as M


def build(name="Leaded window", loc=(0, 0, 0), rot_z=0, width=75, height=115, reveal=18,
          stone_tone=(0.12, 0.105, 0.09), metal_finish="iron", wear=0.6, seed=4, energy=70000,
          moon_height=0.78, sky_strength=1.4, moon_strength=1.8, exterior_slope=0.0, moon_offset=0.14) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    stones = [M.stone(f"{name} reveal {i}", tuple(c * (0.72 + i * 0.13) for c in stone_tone), wear, seed + i) for i in range(4)]
    metal = M.metal(f"{name} lead", metal_finish, wear, seed)
    mortar = M.stone(f"{name} recessed mortar", (0.026, 0.023, 0.019), wear, seed)
    for sx in (-1, 1):
        a.block("Jamb mortar bedding", (12, reveal - 5, height),
                (sx * (width / 2 + 6), reveal / 2 + 2.5, height / 2), mortar, 0.1)
        for j in range(7):
            a.hewn_block("Window jamb stone", (12, reveal, height / 7 - 0.65),
                         (sx * (width / 2 + 6), reveal / 2, (j + 0.5) * height / 7),
                         stones[(j + int(sx)) % 4], 0.8, wear, seed * 100 + j + int(sx) * 17)
    for z in (0, height):
        a.hewn_block("Deep stone sill" if z == 0 else "Lintel", (width + 30, reveal + 10, 9),
                     (0, reveal / 2 - 3, z), stones[2], 1, wear, seed + int(z))
    glass = M.glass(f"{name} old blue glass", (0.33, 0.45, 0.64), reflection=0.008)
    a.mesh("Window glazing", [(-width / 2, reveal, 0), (width / 2, reveal, 0),
                              (width / 2, reveal, height), (-width / 2, reveal, height)], [(0, 1, 2, 3)], glass)
    for slope in (-1.4, 1.4):
        for b in range(-int(width * 2), int(height + width * 2), 15):
            pts = []
            for x in (-width / 2, width / 2):
                z = slope * x + b
                if 0 <= z <= height:
                    pts.append((x, reveal - 0.6, z))
            for z in (0, height):
                x = (z - b) / slope
                if -width / 2 < x < width / 2:
                    pts.append((x, reveal - 0.6, z))
            if len(pts) == 2:
                a.tube("Diamond lead came", pts, 0.32, metal, resolution=1)
    for x in (-width / 2, 0, width / 2):
        a.block("Iron window mullion", (2.3, 3, height), (x, reveal - 1, height / 2), metal, 0.3)
    a.block("Window transom", (width, 3, 2), (0, reveal - 1, height * 0.39), metal, 0.25)
    sky, k = E.material(f"{name} night sky")
    vec = k.coords().outputs["Generated"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(vec, sep.inputs[0])
    clouds = k.noise(vec, 4, 3).outputs["Fac"]
    col = k.ramp(clouds, [(0.2, (0.012, 0.022, 0.065)), (0.8, (0.045, 0.08, 0.17))])
    k.surface(k.emission(col, sky_strength))
    a.block("Night backdrop", (width * 3, 1, height * 2.3), (0, reveal + 80, height * 0.65 - 80 * exterior_slope), sky, 0)
    moon, k = E.material(f"{name} cratered moon")
    n = k.noise(k.coords().outputs["Generated"], 8, 4).outputs["Fac"]
    col = k.ramp(n, [(0.25, (0.17, 0.25, 0.46)), (0.75, (0.55, 0.68, 1))])
    k.surface(k.emission(col, moon_strength))
    a.sphere("Moon", width * 0.083, (width * moon_offset, reveal + 62, height * moon_height - 62 * exterior_slope), moon, subdiv=4)
    rng = random.Random(seed)
    silhouette = E.simple(f"{name} distant roofs", (0.012, 0.018, 0.038), 1)
    lit = E.emissive(f"{name} distant candle windows", (1, 0.3, 0.07), 0.8)
    for i in range(11):
        x = (i - 5) * width * 0.19
        w, h = width * rng.uniform(0.13, 0.21), height * rng.uniform(0.12, 0.27)
        roof = h + w * rng.uniform(0.45, 0.9)
        drop = (45 + i % 3) * exterior_slope
        a.extrude("Town gable silhouette", [(x - w / 2, -20 - drop), (x + w / 2, -20 - drop),
                                           (x + w / 2, h - drop), (x, roof - drop), (x - w / 2, h - drop)], 1,
                  silhouette, y=reveal + 45 + i % 3, bevel=0)
        if i % 2 == 0:
            for z in (h * 0.35, h * 0.66):
                a.block("Distant lit slit", (1.1, 0.15, 2.5), (x, reveal + 44.3 + i % 3, z - (44.3 + i % 3) * exterior_slope), lit, 0.15)
    a.light("Moon through window", (0, reveal - 4, height * 0.7), energy, (0.3, 0.46, 1),
            width * 0.7, target=(-40, -180, -30), kind="AREA")
    return a.root
