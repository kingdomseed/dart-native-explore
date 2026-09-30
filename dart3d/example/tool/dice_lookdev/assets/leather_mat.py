"""Supple embossed leather mat with a curled end and unlettered tooling."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Tooled leather mat", loc=(0, 0, 0), rot_z=0, width=25, depth=34,
          roll=3.2, tone=(0.09, 0.033, 0.009), wear=0.7, seed=3) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    leather = M.leather(f"{name} worn hide", tone, wear, seed, tooling_rings=(5.4, 6, 8.2))
    cut = M.leather(f"{name} recessed tooling", tuple(c * 0.26 for c in tone), wear, seed)
    thread = M.leather(f"{name} waxed stitch", tuple(c * 1.75 for c in tone), wear, seed)
    def surface(x, y):
        z = 0.15 + 0.07 * math.sin(x * 0.28 + y * 0.35)
        edge = depth / 2 - roll * 1.6
        if y > edge:
            angle = (y - edge) / roll
            return x, edge + roll * math.sin(angle), z + roll * (1 - math.cos(angle))
        return x, y, z
    nx, ny = 22, 48
    verts = [surface(-width / 2 + width * i / nx, -depth / 2 + depth * j / ny) for j in range(ny + 1) for i in range(nx + 1)]
    faces = [(j * (nx + 1) + i, j * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i)
             for j in range(ny) for i in range(nx)]
    ob = a.mesh("Curled leather", verts, faces, leather, smooth=True)
    solid = ob.modifiers.new("Hide thickness", "SOLIDIFY")
    solid.thickness = 0.22
    solid.offset = 0
    for inset in (0.65, 1.2):
        pts = []
        for side in range(4):
            for i in range(33):
                t = i / 32
                x, y = ((-width / 2 + inset + t * (width - 2 * inset), -depth / 2 + inset) if side == 0 else
                        (width / 2 - inset, -depth / 2 + inset + t * (depth - 2 * inset)) if side == 1 else
                        (width / 2 - inset - t * (width - 2 * inset), depth / 2 - inset) if side == 2 else
                        (-width / 2 + inset, depth / 2 - inset - t * (depth - 2 * inset)))
                px, py, pz = surface(x, y)
                pts.append((px, py, pz + 0.105))
        a.tube("Blind tooled border", pts, 0.025, cut, cyclic=True, resolution=1)
    for side in (-1, 1):
        for j in range(42):
            y = -depth / 2 + 1 + j * (depth - 2) / 42
            p = surface(side * (width / 2 - 0.35), y)
            q = surface(side * (width / 2 - 0.35), y + 0.22)
            a.tube("Edge saddle stitch", [(p[0], p[1], p[2] + 0.135), (q[0], q[1], q[2] + 0.135)], 0.018, thread, resolution=1)
    return a.root
