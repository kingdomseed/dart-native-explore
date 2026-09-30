"""Iron-bound oak coffer with curved lid boards, hinges and hasp."""

import bpy
import math

from . import geometry as G, materials as M


def build(name="Strongbox", loc=(0, 0, 0), rot_z=0, width=38, depth=25, height=26,
          wood_tone=(0.075, 0.027, 0.012), metal_finish="iron", wear=0.6, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    wood = M.oak(f"{name} timber", wood_tone, wear, seed)
    iron = M.metal(f"{name} straps", metal_finish, wear, seed)
    brass = M.metal(f"{name} studs", "brass", wear, seed)
    h = height * 0.68
    a.block("Coffer bottom", (width - 4, depth - 4, 2), (0, 0, 1), wood, 0.2)
    for side in (-1, 1):
        for j in range(3):
            a.block("Coffer front plank", (width, 2, h / 3 - 0.12),
                    (0, side * (depth / 2 - 1), (j + 0.5) * h / 3), wood, 0.22)
        a.block("Coffer end", (2, depth - 4, h), (side * (width / 2 - 1), 0, h / 2), wood, 0.3)
    rise = height - h
    profile = [(-depth / 2 + depth * i / 12, h + rise * math.sin(math.pi * i / 12)) for i in range(13)]
    verts = [(x, y, z) for x in (-width / 2, width / 2) for y, z in profile]
    faces = [(i, i + 1, i + 14, i + 13) for i in range(12)]
    lid = a.mesh("Curved lid", verts, faces, wood, bevel=0.15, smooth=True)
    solid = lid.modifiers.new("Lid board thickness", "SOLIDIFY")
    solid.thickness = 1.3
    for side in (-1, 1):
        a.mesh("Arched lid end", [(side * width / 2, y, z) for y, z in profile],
               [tuple(range(len(profile)))], wood)
    for i in range(1, 12):
        y, z = profile[i]
        a.tube("Lid plank joint", [(-width / 2 + 0.2, y, z + 0.02), (width / 2 - 0.2, y, z + 0.02)], 0.045, iron)
    for x in (-width * 0.37, width * 0.37):
        a.block("Front iron strap", (2.8, 0.4, h), (x, -depth / 2 - 0.2, h / 2), iron, 0.18)
        a.block("Back iron strap", (2.8, 0.4, h), (x, depth / 2 + 0.2, h / 2), iron, 0.18)
        for y, z in profile:
            if z > h + 0.2:
                a.sphere("Lid band stud", 0.35, (x, y, z + 0.15), brass)
        band_verts = [(xx, y, z + 0.12) for y, z in profile for xx in (x - 1.4, x + 1.4)]
        a.mesh("Curved lid iron band", band_verts, [(i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2)
                                                  for i in range(12)], iron)
        for z in (2, h * 0.5, h - 2):
            a.sphere("Front strap rivet", 0.42, (x, -depth / 2 - 0.45, z), brass, scale=(1, 0.5, 1))
    a.block("Lock plate", (6, 0.8, 9), (0, -depth / 2 - 0.4, h - 3), iron, 0.5)
    a.block("Hinged hasp", (2.4, 1.1, 7), (0, -depth / 2 - 1, h), brass, 0.25)
    a.ring("Lock shackle", 1, 0.3, (0, -depth / 2 - 1.8, h - 3), iron, plane="XZ", ellipse=1.3)
    for side in (-1, 1):
        a.ring("Lifting ring", 3.4, 0.5, (side * (width / 2 + 0.6), 0, h * 0.55), iron, plane="YZ")
    return a.root
