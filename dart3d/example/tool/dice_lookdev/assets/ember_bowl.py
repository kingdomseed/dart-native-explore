"""Hammered bowl containing a small nest of glowing faceted ember crystals."""

import bpy
import math
import random

import env_common as E
from . import geometry as G, materials as M


def build(name="Ember bowl", loc=(0, 0, 0), rot_z=0, radius=9, height=5,
          metal_finish="copper", wear=0.6, seed=2, energy=160) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    metal = M.metal(f"{name} hammered copper", metal_finish, wear, seed)
    a.lathe("Spun bowl", [(0, 0), (radius * 0.36, 0), (radius * 0.48, height * 0.15),
                         (radius * 0.82, height * 0.55), (radius, height), (radius * 0.94, height),
                         (radius * 0.75, height * 0.55), (radius * 0.35, height * 0.15), (0, height * 0.15)], metal)
    a.ring("Rolled bowl lip", radius * 0.97, 0.16, (0, 0, height), metal)
    facets = []
    for i, tone in enumerate(((0.22, 0.017, 0.003), (0.4, 0.055, 0.008), (0.085, 0.004, 0.001))):
        m, k = E.material(f"{name} garnet facet {i}")
        k.surface(k.bsdf(Base_Color=(*tone, 1), Roughness=0.12 + i * 0.04, Metallic=0,
                         Transmission_Weight=0.72, IOR=1.72, Coat_Weight=0.35, Coat_Roughness=0.09))
        facets.append(m)
    core, k = E.material(f"{name} molten crystal heart")
    n = k.noise(k.coords().outputs["Generated"], 4, 3, dist=0.6).outputs["Fac"]
    col = k.ramp(n, [(0.25, (0.12, 0.003, 0.001)), (0.52, (1, 0.07, 0.002)), (0.8, (1, 0.55, 0.055))])
    k.surface(k.emission(col, 5))
    rng = random.Random(seed)
    for i in range(13):
        t, r = rng.uniform(0, math.tau), math.sqrt(rng.random()) * radius * 0.61
        x, y = r * math.cos(t), r * math.sin(t)
        cr, h = rng.uniform(1.15, 1.85), rng.uniform(3.6, 6.0)
        verts = [(cr * rr * math.cos(j * math.tau / 6), cr * rr * math.sin(j * math.tau / 6), zz)
                 for rr, zz in ((0.6, 0), (1, h * 0.22), (0.95, h * 0.65)) for j in range(6)]
        verts += [(cr * 0.2, 0, h)]
        faces = [tuple(reversed(range(6)))]
        faces += [(row * 6 + j, row * 6 + (j + 1) % 6, (row + 1) * 6 + (j + 1) % 6, (row + 1) * 6 + j)
                  for row in range(2) for j in range(6)]
        faces += [(12 + j, 12 + (j + 1) % 6, 18) for j in range(6)]
        ob = a.mesh("Faceted crystal shell", verts, faces, facets[0])
        for mat in facets[1:]:
            ob.data.materials.append(mat)
        for face in ob.data.polygons:
            face.material_index = rng.choices((0, 1, 2), (6, 2, 2))[0]
        ob.location = (x, y, height * 0.30 + (r / radius) ** 2 * height * 0.7)
        ob.rotation_euler = (rng.uniform(-0.28, 0.28), rng.uniform(-0.28, 0.28), t)
        inner = a.mesh("Incandescent inner inclusion", [(xx * 0.45, yy * 0.45, h * 0.25 + zz * 0.43) for xx, yy, zz in verts], faces, core)
        inner.location = ob.location
        inner.rotation_euler = ob.rotation_euler
    a.light("Crystal bowl glow", (0, 0, height + 2), energy, (1, 0.18, 0.02), radius * 0.5)
    return a.root
