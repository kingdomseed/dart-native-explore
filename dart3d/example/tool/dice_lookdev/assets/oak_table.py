"""Joiner's table: individual boards, breadboards, pegged mortises and stretchers."""

import bpy
import random
import math

import env_common as E

from . import geometry as G, materials as M


def build(name="Oak table", loc=(0, 0, 0), rot_z=0, width=150, depth=85, height=70,
          thickness=7, wood_tone=(0.095, 0.038, 0.013), wear=0.7, seed=1, scorch=0.4) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    boards = max(4, round(depth / 14))
    bread = 10
    for i in range(boards):
        mat = M.oak(f"{name} board {i}", tuple(c * (0.65 + (i * 0.37 % 0.85)) for c in wood_tone), wear, seed + i)
        a.block("Oak plank", (width - bread * 2, depth / boards - 0.23, thickness),
                (0, -depth / 2 + (i + 0.5) * depth / boards, height - thickness / 2), mat, 0.32)
    grime = M.leather(f"{name} seam grime", (0.013, 0.009, 0.005), seed=seed)
    a.block("Dark recessed plank joints", (width - bread * 2, depth - 0.2, 0.4),
            (0, 0, height - 0.65), grime, 0)
    marks, k = E.material(f"{name} softened scorch")
    coord = k.coords().outputs["Generated"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(coord, sep.inputs[0])
    x = k.math("MULTIPLY", k.math("SUBTRACT", sep.outputs["X"], 0.5), 2)
    y = k.math("MULTIPLY", k.math("SUBTRACT", sep.outputs["Y"], 0.5), 2)
    dist = k.math("ADD", k.math("MULTIPLY", x, x), k.math("MULTIPLY", y, y))
    opacity = k.math("MULTIPLY", k.math("MAXIMUM", k.math("SUBTRACT", 1, dist), 0), scorch)
    mottling = k.noise(k.coords().outputs["Object"], 0.9, 3, dist=0.5).outputs["Fac"]
    opacity = k.math("MULTIPLY", opacity, k.math("POWER", mottling, 0.65))
    transparent = k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(opacity, transparent, k.bsdf(Base_Color=(0.006, 0.004, 0.002, 1), Roughness=0.94)))
    for i in range(5):
        x, y = rng.uniform(-width * 0.39, width * 0.39), rng.uniform(-depth * 0.42, depth * 0.42)
        patch = a.add(E.plane("Old heat stain", rng.uniform(8, 18), rng.uniform(2, 4), (x, y, height + 0.015), marks))
        patch.rotation_euler.z = rng.uniform(-0.3, 0.3)
    scratch = M.oak(f"{name} cut grain", tuple(c * 1.5 for c in wood_tone), wear, seed)
    for i in range(round(45 * wear)):
        x, y = rng.uniform(-width * 0.4, width * 0.4), rng.uniform(-depth * 0.43, depth * 0.43)
        length = rng.uniform(0.7, 4.5)
        a.tube("Shallow work scar", [(x, y, height + 0.016), (x + length, y + rng.uniform(-0.3, 0.3), height + 0.016)],
               rng.uniform(0.012, 0.035), scratch, resolution=1)
    cross = M.oak(f"{name} end grain", wood_tone, wear, seed, axis="Y")
    upright = M.oak(f"{name} legs", wood_tone, wear, seed + 10, axis="Z")
    peg = M.oak(f"{name} pegs", tuple(c * 0.5 for c in wood_tone), wear, seed, axis="Z")
    for side in (-1, 1):
        a.block("Breadboard end", (bread - 0.12, depth, thickness),
                (side * (width - bread) / 2, 0, height - thickness / 2), cross, 0.35)
        for j in (-0.35, 0, 0.35):
            a.cylinder("Breadboard peg", 0.42, 0.12, (side * (width / 2 - bread / 2), depth * j, height - 0.03), peg)
    lx, ly = width / 2 - 16, depth / 2 - 12
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.block("Chamfered oak leg", (9, 9, height - thickness),
                    (sx * lx, sy * ly, (height - thickness) / 2), upright, 0.65)
            for z in (height - 16, 19):
                dowel = a.cylinder("Mortise peg", 0.6, 9.1, (sx * lx, sy * ly, z), peg)
                dowel.rotation_euler.x = 1.5708
        a.block("Short stretcher", (8, ly * 2, 10), (sx * lx, 0, 18), cross, 0.45)
        a.block("End apron", (5, ly * 2, 14), (sx * lx, 0, height - thickness - 7), cross, 0.4)
    long = M.oak(f"{name} stretchers", wood_tone, wear, seed + 2)
    a.block("Long through stretcher", (lx * 2 + 12, 7, 11), (0, 0, 20), long, 0.5)
    for sy in (-1, 1):
        a.block("Long apron", (lx * 2, 5, 14), (0, sy * ly, height - thickness - 7), long, 0.35)
    for sx in (-1, 1):
        a.block("Stretcher wedge", (2, 9, 15), (sx * (lx + 5), 0, 20), peg, 0.2)
    return a.root
