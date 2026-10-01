"""Chrome pedestal stool with dished base, foot ring and a button-tufted vinyl seat."""
import bpy
import math
from . import geometry as G, materials as M


def build(name="Diner stool", loc=(0, 0, 0), rot_z=0, height=70, radius=17,
          tone=(0.27, 0.012, 0.022), metal_tone=(0.65, 0.68, 0.72), wear=0.45, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    chrome = M.polished_metal(f"{name} chrome", metal_tone, wear, seed)
    vinyl = M.vinyl(f"{name} red upholstery", tone, wear, seed)
    seam = M.vinyl(f"{name} piping", tuple(c * 0.55 for c in tone), wear, seed)
    a.lathe("Spun weighted base", [(0, 0), (radius * 0.95, 0), (radius, 1), (radius * 0.94, 2.4),
                                 (radius * 0.68, 3.7), (radius * 0.2, 5), (radius * 0.16, 6)], chrome, segments=64)
    a.cylinder("Pedestal", radius * 0.14, height - 14, (0, 0, (height - 14) / 2 + 4), chrome, bevel=0.3)
    a.lathe("Seat bearing", [(0, height - 9), (5, height - 9), (7, height - 7), (radius * 0.96, height - 6),
                            (radius, height - 4.5), (radius, height - 3.5)], chrome, segments=64)
    a.ring("Foot ring", radius * 0.8, 0.95, (0, 0, height * 0.36), chrome, segments=64)
    for i in range(3):
        t = math.tau * i / 3
        a.beam("Foot ring support", (0, 0, height * 0.28),
               (radius * 0.79 * math.cos(t), radius * 0.79 * math.sin(t), height * 0.36), 1.1, 1.1, chrome, 0.2)
    buttons = [(0, 0)] + [(radius * 0.48 * math.cos(t), radius * 0.48 * math.sin(t)) for t in [math.tau * i / 6 for i in range(6)]]
    verts = []
    rings, sides = 22, 72
    for j in range(rings):
        r = radius * (j + 0.02) / (rings - 0.98)
        for i in range(sides):
            t = i * math.tau / sides
            x, y = r * math.cos(t), r * math.sin(t)
            z = height - 1.4 * (r / radius) ** 8
            z -= sum(1.15 * math.exp(-((x - bx) ** 2 + (y - by) ** 2) / 3.1) for bx, by in buttons)
            z -= 0.13 * math.cos(t * 12) ** 16 * (r / radius) ** 2
            verts.append((x, y, z))
    faces = [(j * sides + i, j * sides + (i + 1) % sides,
              (j + 1) * sides + (i + 1) % sides, (j + 1) * sides + i) for j in range(rings - 1) for i in range(sides)]
    a.mesh("Tufted cushion crown", verts, faces, vinyl, smooth=True)
    a.lathe("Padded vinyl bolster", [(radius * 0.94, height - 4.5), (radius, height - 3.6),
                                    (radius * 1.015, height - 2.5), (radius, height - 1.4)], vinyl, segments=72)
    for z in (height - 4.4, height - 1.45): a.ring("Sewn seat piping", radius * 0.995, 0.10, (0, 0, z), seam, segments=72)
    for x, y in buttons: a.sphere("Upholstered button", 0.43, (x, y, height - 1.0), seam, scale=(1, 1, 0.3))
    for z in (height - 6.1, height - 7): a.ring("Seat chrome bead", radius * 0.955, 0.22, (0, 0, z), chrome, segments=64)
    return a.root
