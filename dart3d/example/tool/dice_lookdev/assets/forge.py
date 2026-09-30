"""Masonry forge with a deep arched firebox, voussoirs and tapered chimney."""

import bpy
import bmesh
from mathutils import noise, Vector
import math
import random

import env_common as E
from . import geometry as G, materials as M


def fire_tongue(a, name, loc, radius, height, mat, lean=0, phase=0):
    verts = []
    n, rows = 12, 13
    for j in range(rows):
        t = j / (rows - 1)
        r = radius * (math.sin(math.pi * (0.22 + t * 0.78)) ** 1.2) + 0.015
        for i in range(n):
            angle = math.tau * i / n
            verts.append((loc[0] + lean * t * t + math.sin(t * 6 + phase) * radius * t * 0.55 + r * (1 + 0.18 * math.sin(angle * 3 + t * 8 + phase)) * math.cos(angle),
                          loc[1] + radius * math.sin(t * 7 + phase) * t * 0.6 + r * math.sin(angle) * 0.8, loc[2] + t * height))
    faces = [(j * n + i, j * n + (i + 1) % n, (j + 1) * n + (i + 1) % n, (j + 1) * n + i)
             for j in range(rows - 1) for i in range(n)]
    ob = a.mesh(name, verts, faces, mat, smooth=True)
    ob.visible_shadow = False
    return ob


def build(name="Stone forge", loc=(0, 0, 0), rot_z=0, width=150, depth=65, height=230,
          stone_tone=(0.09, 0.085, 0.072), wear=0.85, seed=2, energy=380000,
          hearth_height=65, mouth_spring=43) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    scale = width / 150
    radius, hearth = 41 * scale, hearth_height
    spring = hearth + mouth_spring * scale
    stones = [M.stone(f"{name} basalt {i}", tuple(c * (0.62 + 0.16 * i) for c in stone_tone), wear, seed + i)
              for i in range(6)]
    soot = [M.stone(f"{name} soot {i}", stone_tone, wear, seed + i, soot=0.42 + 0.14 * i) for i in range(5)]
    mortar = M.stone(f"{name} lime and ash mortar", (0.032, 0.029, 0.024), 0.9, seed)
    a.block("Firebox back", (width - 4, 9, spring + radius - hearth),
            (0, depth / 2 - 4.5, (spring + radius + hearth) / 2), soot[4], 1)
    a.block("Hearth core", (width - 2, depth - 3, hearth - 4), (0, 1, (hearth - 4) / 2), mortar, 1)
    for row in range(4):
        x = -width / 2
        while x < width / 2 - 1:
            w = min(rng.uniform(24, 36) * scale, width / 2 - x)
            a.hewn_block("Hearth ashlar", (w - 0.8, 12, (hearth - 4) / 4 - rng.uniform(0.5, 1.2)),
                         (x + w / 2, -depth / 2 + rng.uniform(-0.7, 0.7), (row + 0.5) * (hearth - 4) / 4),
                         rng.choice(stones), 1.0, wear, rng.randrange(100000))
            x += w
    a.hewn_block("Worn hearth lip", (width + 10, depth + 14, 5), (0, -4, hearth - 1.5), stones[3], 1.2, wear, seed)
    side_w = width / 2 - radius
    for side in (-1, 1):
        a.block("Recessed pier mortar", (side_w - 2, depth - 3, spring - hearth),
                (side * (radius + side_w / 2), 1, (spring + hearth) / 2), mortar, 0.1)
        z = hearth + 1
        while z < spring - 0.5:
            h = min(rng.uniform(14, 20) * scale, spring - z)
            a.hewn_block("Arch pier stone", (side_w - 0.7, depth, h - 0.75),
                         (side * (radius + side_w / 2), rng.uniform(-0.5, 0.5), z + h / 2),
                         rng.choice(soot[:2] if z > hearth else stones), 1.0, wear, rng.randrange(100000))
            z += h
    for row in range(4):
        for col in range(7):
            a.hewn_block("Blackened firebrick", (radius * 2 / 7 - 0.45, 4, 10),
                         ((col - 3) * radius * 2 / 7, depth / 2 - 10, hearth + 5 + row * 10.5),
                         soot[rng.choice((2, 3, 4))], 0.4, wear, rng.randrange(100000))
    count = 13
    for i in range(count):
        mat = soot[4 if 4 <= i <= 8 else 2]
        ob = G.arch_block(a, "Soot blackened voussoir", radius + rng.uniform(-0.35, 0.35),
                         radius + side_w + rng.uniform(-0.6, 0.6),
                         i * math.pi / count + 0.004, (i + 1) * math.pi / count - 0.004,
                         depth + rng.uniform(-1.5, 1.5), (0, 0, spring), mat, rng.uniform(0.6, 1.15))
        bpy.context.view_layer.objects.active = ob
        for modifier in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
        bm.normal_update()
        for v in bm.verts:
            n = noise.noise_vector(v.co * 0.24 + Vector((seed, i * 9, 3)))
            v.co += v.normal * n.x * 1.1 * wear
        bm.to_mesh(ob.data)
        bm.free()
    top, outer = spring + radius + side_w, radius + side_w
    for side in (-1, 1):
        outline = [(side * outer, top), (side * outer, spring)]
        outline += [(side * outer * math.cos(i * math.pi / 32),
                     spring + outer * math.sin(i * math.pi / 32)) for i in range(1, 17)]
        a.extrude("Arch spandrel masonry", outline, depth - 1, soot[1], bevel=0.8)
    z = top
    while z < height - 0.5:
        h = min(rng.uniform(14, 21), height - z)
        t = (z + h / 2 - top) / (height - top)
        w = width * (1 - t * 0.34)
        front = -depth / 2 + t * depth * 0.38
        a.block("Recessed hood mortar", (w - 2, depth / 2 - front - 2, h),
                (0, (depth / 2 + front) / 2 + 1, z + h / 2), mortar, 0.1)
        n = 4 if int(z) % 2 else 5
        for j in range(n):
            x = -w / 2 + (j + 0.5) * w / n
            a.hewn_block("Smoke stained chimney stone", (w / n - 0.6, depth / 2 - front, h - 0.7),
                         (x, (depth / 2 + front) / 2, z + h / 2),
                         soot[3] if abs(x) < w * 0.26 else rng.choice(soot[:2]),
                         0.9, wear, rng.randrange(100000))
        z += h
    coal, k = E.material(f"{name} cracked coke")
    vec = k.coords().outputs["Generated"]
    veins = k.node("ShaderNodeTexVoronoi")
    veins.feature = "DISTANCE_TO_EDGE"
    k.link(vec, veins.inputs["Vector"])
    veins.inputs["Scale"].default_value = 1.8
    crack = k.math("LESS_THAN", veins.outputs["Distance"], 0.011)
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(vec, sep.inputs[0])
    crust = k.ramp(sep.outputs["Z"], [(0.1, (1, 1, 1)), (0.5, (0.18, 0.18, 0.18)), (0.8, (0.015, 0.015, 0.015))])
    n = k.noise(vec, 5, 3).outputs["Fac"]
    col = k.ramp(n, [(0.15, (0.001, 0.0008, 0.0006)), (0.7, (0.004, 0.003, 0.002)), (0.9, (0.012, 0.010, 0.008))])
    glow = k.math("MULTIPLY", k.math("MULTIPLY", crack, k.math("ADD", 0.04, crust)), 5)
    k.surface(k.bsdf(Base_Color=col, Roughness=0.92, Normal=k.bump(n, 0.6, 0.35),
                     Emission_Color=(1, 0.16, 0.007, 1), Emission_Strength=glow))
    cold_coal = coal.copy()
    cold_coal.name = f"{name} cooled coal crust"
    for node in cold_coal.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            emission = node.inputs["Emission Strength"]
            for link in list(emission.links):
                cold_coal.node_tree.links.remove(link)
            emission.default_value = 0
    ember = E.emissive(f"{name} buried ember cores", (1, 0.08, 0.002), 3.2)
    for layer in range(3):
        for row in range(6 - layer):
            for col in range(11 - layer * 2):
                if layer and abs(col - (10 - layer * 2) / 2) > (4 - layer) + rng.uniform(-1, 1):
                    continue
                x = (col - (10 - layer * 2) / 2) * 6.1 * scale + rng.uniform(-2.2, 2.2)
                y = (row - (5 - layer) / 2) * 6.3 + 1 + layer * 1.7 + rng.uniform(-2, 2)
                z = hearth + 2.6 + layer * 3.5 + rng.uniform(-1.1, 1.1)
                r = rng.uniform(3.2, 4.6) * scale
                coal_finish = cold_coal if rng.random() < 0.1 + layer * 0.30 else coal
                a.add(E.rock("Heaped charcoal crust", r, (x, y, z), coal_finish, seed=seed * 1000 + col + row * 20 + layer * 200,
                             subdiv=2, squash=(1.15, 1, 0.8), strength=0.35))
                if layer == 0:
                    a.sphere("Buried hot core", r * 0.65, (x, y, z - 0.5), ember, subdiv=1)
    fire = M.flame(f"{name} flame", 4.5)
    for i, (x, y, h, r) in enumerate(((-22, 0, 13, 4.6), (-12, 5, 26, 6), (1, 1, 38, 6.8),
                                    (13, 6, 21, 5), (25, 0, 12, 3.9), (-3, -8, 16, 4))):
        fire_tongue(a, "Twisting fire tongue", (x * scale, y, hearth + 8), r * scale, h * scale,
                    fire, rng.uniform(-8, 8), rng.uniform(0, 6))
    spark = E.emissive(f"{name} spark", (1, 0.28, 0.012), 5)
    for i in range(6):
        x, y, z = rng.uniform(-23, 23) * scale, rng.uniform(-8, 8), hearth + rng.uniform(23, 58)
        a.tube("Rising spark", [(x, y, z), (x + 0.2, y, z + rng.uniform(0.35, 0.9))], 0.06, spark, resolution=1)
    a.light("Forge mouth glow", (0, -depth * 0.20, hearth + 20), energy, (1, 0.34, 0.07), 11)
    a.light("Forge warm spill", (0, -depth * 0.7, hearth + 15), energy * 0.5, (1, 0.45, 0.17),
            38, target=(20, -130, 10), kind="AREA")
    return a.root
