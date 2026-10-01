"""Low-poly parked saloon with a shaped body, glazed cabin, tires, bumpers and lamps."""
import bpy
import math
import env_common as E
from . import geometry as G, materials as M


def build(name="Parked saloon", loc=(0, 0, 0), rot_z=0, length=420, width=174, height=140,
          tone=(0.015, 0.023, 0.038), wear=0.4, seed=1, tail_lights=True) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    paint = M.ceramic(f"{name} paint", tone, wear, seed)
    chrome = M.polished_metal(f"{name} trim", wear=wear, seed=seed)
    rubber = E.simple(f"{name} rubber", (0.007, 0.008, 0.009), 0.76)
    glass = E.simple(f"{name} smoky glazing", (0.009, 0.018, 0.035), 0.12, metal=0.18, Coat_Weight=1)
    outline = [(-length * 0.49, height * 0.27), (length * 0.47, height * 0.27),
               (length * 0.5, height * 0.41), (length * 0.47, height * 0.52),
               (length * 0.28, height * 0.55), (-length * 0.38, height * 0.55), (-length * 0.5, height * 0.45)]
    a.extrude("Shaped car body", outline, width * 0.96, paint, bevel=6)
    sections = [(-0.31, 0.55, 0.46), (-0.17, 0.95, 0.35), (0.12, 1, 0.35), (0.32, 0.56, 0.46)]
    verts = [(x * length, side * w * width, z * height) for x, z, w in sections for side in (-1, 1)]
    faces = [(0, 1, 3, 2), (2, 3, 5, 4), (4, 5, 7, 6), (0, 2, 4, 6), (1, 7, 5, 3)]
    a.mesh("Glazed cabin", verts, faces, glass, bevel=2)
    roof_vertices = []
    for j in range(9):
        t = j / 8
        for i in range(13):
            u = i / 6 - 1
            roof_vertices.append((length * (-0.17 + 0.29 * t), u * width * 0.353,
                                  height * (0.95 + 0.05 * t) + 1 + 2.5 * math.sin(t * math.pi) + width * 0.013 * (1 - u * u)))
    roof = a.mesh("Pressed curved roof", roof_vertices,
                  [(j * 13 + i, j * 13 + i + 1, (j + 1) * 13 + i + 1, (j + 1) * 13 + i) for j in range(8) for i in range(12)], paint, smooth=True)
    shell = roof.modifiers.new("Roof sheet", "SOLIDIFY")
    shell.thickness = 2
    shell.offset = -1
    for side in (-1, 1):
        for x, z, w in sections[1:3]:
            a.beam("Window pillar", (x * length, side * width * 0.46, height * 0.56),
                   (x * length, side * width * w, height * z), 4, 4, paint, 1)
        a.beam("Sill brightwork", (-length * 0.4, side * width * 0.485, height * 0.42),
               (length * 0.4, side * width * 0.485, height * 0.42), 1.6, 1.6, chrome, 0.4)
        for x in (-length * 0.14, length * 0.14):
            a.block("Door handle", (12, 2, 2), (x, side * width * 0.49, height * 0.56), chrome, 0.7)
        for x in (-length * 0.31, length * 0.31):
            ob = a.cylinder("Tire", height * 0.235, width * 0.105, (x, side * width * 0.43, height * 0.235), rubber, bevel=4, segments=32)
            ob.rotation_euler.x = math.pi / 2
            ob = a.cylinder("Wheel hub", height * 0.145, 1.2, (x, side * width * 0.488, height * 0.235), chrome, bevel=0.9, segments=32)
            ob.rotation_euler.x = math.pi / 2
    red = E.emissive(f"{name} rear lamps", (1, 0.007, 0.003), 3.5 if tail_lights else 0)
    white = E.emissive(f"{name} headlights", (1, 0.74, 0.4), 4)
    for end in (-1, 1):
        a.block("Chrome bumper", (4, width * 0.95, 8), (end * length * 0.495, 0, height * 0.31), chrome, 2)
        for side in (-1, 1):
            a.block("Tail lamp" if end == -1 else "Headlamp", (2, 25, 10),
                    (end * length * 0.497, side * width * 0.32, height * 0.47), red if end == -1 else white, 2)
    return a.root
