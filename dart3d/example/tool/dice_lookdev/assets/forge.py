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



def flame_sheet(a, loc, width, height, mat, lean, phase, angle):
    rows, columns = 21, 7
    verts, uv = [], []
    for j in range(rows):
        t = j / (rows - 1)
        breadth = width * (0.48 + 0.7 * math.sin(math.pi * t)) * (1 - t) ** 0.7 + 0.005
        curl = lean * t * t + width * math.sin(t * 9 + phase) * t * 0.65
        for i in range(columns):
            u = i / (columns - 1)
            x = curl + (u * 2 - 1) * breadth
            y = width * (math.sin(t * 7 + phase) * t * 0.5 + math.sin(u * math.pi) * 0.45)
            verts.append((loc[0] + x * math.cos(angle) - y * math.sin(angle),
                          loc[1] + x * math.sin(angle) + y * math.cos(angle), loc[2] + t * height))
            uv.append((u, t))
    faces = [(j * columns + i, j * columns + i + 1,
              (j + 1) * columns + i + 1, (j + 1) * columns + i)
             for j in range(rows - 1) for i in range(columns - 1)]
    ob = a.mesh("Licking flame sheet", verts, faces, mat, smooth=True)
    layer = ob.data.uv_layers.new(name="Flame height and edge")
    for loop in ob.data.loops:
        layer.data[loop.index].uv = uv[loop.vertex_index]
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
    a.hewn_block("Worn hearth lip", (width + 10, depth + 14, 5), (0, -4, hearth - 1.5), soot[3], 1.2, wear, seed)
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
    stone_receivers = bpy.data.collections.new(f"{name} firelit masonry")
    for ob in a.root.children_recursive:
        if ob.type == "MESH":
            stone_receivers.objects.link(ob)
    rng = random.Random(seed + 403)
    coal_materials = [M.coal(f"{name} coke heat {i}", heat) for i, heat in enumerate((0, 0.24, 0.65, 1))]
    ember_materials = [E.emissive(f"{name} buried heat {i}", color, strength)
                       for i, (color, strength) in enumerate((((1, 0.025, 0.001), 2.5),
                                                              ((1, 0.16, 0.006), 7),
                                                              ((1, 0.38, 0.016), 9)))]
    bed_radius, bed_depth = radius * 0.91, depth * 0.31
    spacing = width * 0.042
    for row in range(-5, 6):
        for col in range(-6, 7):
            x = (col + (row % 2) * 0.5) * spacing + rng.uniform(-0.25, 0.25) * spacing
            y = row * spacing + 2 + rng.uniform(-0.25, 0.25) * spacing
            distance = (x / bed_radius) ** 2 + ((y - 2) / bed_depth) ** 2
            if distance > 1:
                continue
            mound = max(0, 1 - distance) * 3.2 * scale
            z = hearth + 2.1 + mound
            r = spacing * rng.uniform(0.64, 0.9)
            hot = 2 if distance < 0.34 else 1 if distance < 0.72 else 0
            a.add(E.rock("Buried incandescent coke", r * 0.86, (x, y, z - 0.55), ember_materials[hot],
                         seed=seed * 1000 + row * 20 + col, subdiv=1, squash=(1, 1, 0.42), strength=0.3))
            material = coal_materials[0 if rng.random() < 0.2 else hot + 1]
            ob = a.add(E.rock("Black fractured coal crust", r, (x, y, z + 0.45), material,
                             seed=seed * 2000 + row * 20 + col, subdiv=1,
                             squash=(rng.uniform(0.85, 1.3), rng.uniform(0.8, 1.25), rng.uniform(0.38, 0.62)), strength=0.42))
            for face in ob.data.polygons:
                face.use_smooth = False
    fire = M.forge_flame(f"{name} furnace flame", 20)
    for i in range(30):
        x = rng.uniform(-0.76, 0.76) * radius
        y = rng.uniform(-depth * 0.20, depth * 0.19)
        arch_height = mouth_spring * scale + math.sqrt(max(0, radius ** 2 - x ** 2))
        h = (arch_height - 5) * (rng.uniform(0.57, 0.98) if i < 12 else rng.uniform(0.18, 0.55))
        flame_sheet(a, (x, y, hearth + 3.1 + scale), rng.uniform(2.1, 4.2) * scale, h,
                    fire, rng.uniform(-4.5, 4.5) * scale, rng.uniform(0, math.tau), rng.uniform(-0.7, 0.7))
    spark = E.emissive(f"{name} spark", (1, 0.38, 0.016), 12)
    for i in range(7):
        x, y = rng.uniform(-0.65, 0.65) * radius, rng.uniform(-depth * 0.25, 0)
        z = hearth + rng.uniform(8, 18) * scale + mouth_spring * scale
        a.tube("Rising spark", [(x, y, z), (x + 0.3 * scale, y, z + rng.uniform(0.7, 1.8) * scale)],
               0.085 * scale, spark, resolution=1)
    a.light("Forge mouth glow", (0, -depth * 0.10, hearth + 5), energy, (1, 0.24, 0.022), 3.5 * scale)
    a.light("Forge inner arch glow", (0, -depth * 0.22, hearth + 10 * scale), energy * 0.35,
            (1, 0.37, 0.055), 5 * scale, target=(0, 0, spring + radius), kind="AREA")
    a.light("Forge warm spill", (0, -depth * 0.62, hearth + 7), energy * 0.5, (1, 0.28, 0.04),
            16 * scale, target=(20, -130, 10), kind="AREA")
    for ob in a.root.children_recursive:
        if ob.type == "LIGHT":
            ob.light_linking.receiver_collection = stone_receivers
    return a.root
