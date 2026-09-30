"""London-pattern anvil with pierced heel and swept horn, on a banded stump."""
import math

import bpy
from . import geometry as G, materials as M


def build(name="Anvil", loc=(0, 0, 0), rot_z=0, length=70,
          stump_height=48, wood_tone=(0.1, 0.042, 0.016), metal_finish="iron", wear=0.8, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    s = length / 70
    iron = M.metal(f"{name} forged scale", metal_finish, wear, seed)
    steel = M.metal(f"{name} worn face", "steel", wear, seed)
    wood = M.oak(f"{name} stump", wood_tone, wear, seed, axis="Z")
    a.lathe("Stump", [(0, 0), (23 * s, 0), (24 * s, 3), (22 * s, stump_height - 4),
                     (21 * s, stump_height), (0, stump_height)], wood, segments=40)
    for z in (7, stump_height - 8):
        rr = (24 - 2 * (z - 3) / (stump_height - 7)) * s
        a.lathe("Stump iron band", [(rr + 0.15, z - 2), (rr + 0.45, z - 2),
                                  (rr + 0.25, z + 2), (rr - 0.05, z + 2)], iron)
    z = stump_height
    body = [(-18, 0), (-18, 5), (-13, 7), (-9, 13), (-8, 19), (-13, 23),
            (-20, 26), (-20, 29), (24, 29), (24, 23), (15, 20), (10, 15), (10, 10),
            (15, 6), (20, 4), (20, 0)]
    a.extrude("Sculpted anvil body", [(x * s, z + zz * s) for x, zz in body], 17 * s, iron, bevel=0.65 * s)
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.block("Splayed foot", (15 * s, 10 * s, 5 * s), (sx * 13 * s, sy * 9 * s, z + 2.5 * s), iron, 0.75 * s)
    face = a.block("Polished working face", (45 * s, 18 * s, 2 * s), (2.5 * s, 0, z + 30 * s), steel, 0.3 * s)
    body_ob = next(o for o in a.root.children if o.name.startswith("Sculpted anvil body"))
    for shape, x, y, radius in (("square", 17, 1.5, 1.6), ("round", 22, -5, 0.9)):
        if shape == "square":
            cutter = a.block("Hardy bore tool", (radius * 2 * s, radius * 2 * s, 18 * s),
                             (x * s, y * s, z + 28 * s), iron, 0.12)
        else:
            cutter = a.cylinder("Pritchel bore tool", radius * s, 18 * s, (x * s, y * s, z + 28 * s), iron)
        bpy.context.view_layer.update()
        for ob in (face, body_ob):
            mod = ob.modifiers.new("Pierced heel", "BOOLEAN")
            mod.operation = "DIFFERENCE"
            mod.object = cutter
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.modifier_apply(modifier=mod.name)
        cutter.hide_render = True
        cutter.hide_viewport = True
    a.block("Cutting step", (9 * s, 16 * s, 3.5 * s), (-23.5 * s, 0, z + 25.8 * s), iron, 0.4)
    verts = []
    stations = [(-25, 7.8, 4.8, 24), (-29, 7, 4.5, 24), (-36, 5.2, 3.8, 24.2),
                (-42, 3.2, 2.6, 24.8), (-47, 1.6, 1.5, 25.4), (-50, 0.15, 0.15, 26)]
    n = 24
    for x, ry, rz, zz in stations:
        for j in range(n):
            t = math.tau * j / n
            verts.append((x * s, ry * math.cos(t) * s, z + (zz + rz * math.sin(t)) * s))
    faces = [(i * n + j, i * n + (j + 1) % n, (i + 1) * n + (j + 1) % n, (i + 1) * n + j)
             for i in range(len(stations) - 1) for j in range(n)]
    faces += [tuple(reversed(range(n))), tuple(range((len(stations) - 1) * n, len(stations) * n))]
    a.mesh("Drawn tapered horn", verts, faces, steel, smooth=True)
    for x in (-15, 15):
        a.block("Holdfast foot strap", (4, 29 * s, 1.2), (x * s, 0, z + 0.6), iron, 0.2)
        for y in (-13, 13):
            a.cylinder("Holdfast bolt", 1.1, 2, (x * s, y * s, z + 1.4), iron, segments=6)
    return a.root
