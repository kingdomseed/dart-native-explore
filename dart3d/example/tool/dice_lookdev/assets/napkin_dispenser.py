"""Pressed stainless napkin dispenser with a curved crown and inset paper stack."""
import bpy
import math
import env_common as E
from . import geometry as G, materials as M


def build(name="Napkin dispenser", loc=(0, 0, 0), rot_z=0, width=10.5, depth=9, height=15,
          metal_tone=(0.67, 0.7, 0.74), wear=0.35, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    chrome = M.polished_metal(f"{name} chrome", metal_tone, wear, seed)
    dark = E.simple(f"{name} opening shadow", (0.006, 0.008, 0.009), 0.48)
    paper = E.simple(f"{name} ivory tissue", (0.73, 0.7, 0.62), 0.9)
    outline = [(-width / 2, 0.5), (width / 2, 0.5), (width / 2, height - width * 0.3)]
    outline += [(width / 2 * math.cos(t), height - width * 0.3 + width * 0.3 * math.sin(t)) for t in [math.pi * i / 24 for i in range(25)]]
    a.extrude("Pressed curved shell", outline, depth, chrome, bevel=0.35)
    a.block("Rolled bottom flange", (width + 0.5, depth + 0.5, 0.7), (0, 0, 0.65), chrome, 0.22)
    for side in (-1, 1):
        y = side * (depth / 2 + 0.015)
        a.block("Recessed paper opening", (width * 0.74, 0.04, height * 0.64), (0, y, height * 0.46), dark, 0.35)
        a.block("Folded napkins", (width * 0.65, 0.04, height * 0.57), (0, y + side * 0.04, height * 0.46), paper, 0.16)
        for i in range(9):
            a.tube("Paper fold", [(-width * 0.31, y + side * 0.066, height * 0.20 + i * 0.08),
                                   (width * 0.31, y + side * 0.066, height * 0.20 + i * 0.08)], 0.009, dark, resolution=0)
        for x in (-width * 0.45, width * 0.45):
            a.sphere("Cover rivet", 0.15, (x, y + side * 0.05, height * 0.4), chrome, scale=(1, 0.35, 1))
    rubber = E.simple(f"{name} rubber feet", (0.008, 0.008, 0.009), 0.9)
    for x in (-width * 0.34, width * 0.34):
        for y in (-depth * 0.33, depth * 0.33):
            a.cylinder("Rubber foot", 0.6, 0.3, (x, y, 0.15), rubber)
    return a.root
