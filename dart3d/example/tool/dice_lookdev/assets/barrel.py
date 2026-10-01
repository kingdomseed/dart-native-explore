"""Coopered, bulging staves with separate hoops; optional open water tub."""

import bpy
import math
import random

import env_common as E
from . import geometry as G, materials as M


def build(name="Barrel", loc=(0, 0, 0), rot_z=0, radius=25, height=85,
          wood_tone=(0.14, 0.062, 0.024), metal_finish="iron", wear=0.6, seed=1, open_top=False, water=False,
          stave_thickness=1.4,hoop_thickness=.6,rivet_radius=.43,staves=20,
          hoops=(.075,.23,.77,.925),base_thickness=1.5,grain_scale=1.0) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    n, rings = staves, 10
    def r(t):
        return radius * (0.84 + 0.16 * math.sin(t * math.pi))
    woods = [M.oak(f"{name} stave tone {i}", tuple(c * (0.78 + i * 0.12) for c in wood_tone),
                   wear, seed + i, axis="Z",grain_scale=grain_scale) for i in range(4)]
    for i in range(n):
        aa, ab = (i + 0.025) * math.tau / n, (i + 0.975) * math.tau / n
        verts = []
        for j in range(rings + 1):
            t = j / rings
            for rad, angle in ((r(t), aa), (r(t), ab), (r(t) - stave_thickness, ab), (r(t) - stave_thickness, aa)):
                verts.append((rad * math.cos(angle), rad * math.sin(angle), t * height))
        faces = [(j * 4 + k, j * 4 + (k + 1) % 4, (j + 1) * 4 + (k + 1) % 4, (j + 1) * 4 + k)
                 for j in range(rings) for k in range(4)]
        faces += [(0, 3, 2, 1), tuple(range(rings * 4, rings * 4 + 4))]
        a.mesh("Shaped oak stave", verts, faces, rng.choice(woods), bevel=0.12)
    metal = M.metal(f"{name} hoops", metal_finish, wear, seed)
    hs=hoop_thickness/.6
    for t in hoops:
        rr, z, h = r(t) + 0.35*hs, t * height, height * 0.045
        a.lathe("Riveted hoop", [(rr - 0.35*hs, z - h / 2), (rr + 0.25*hs, z - h / 2),
                                (rr + 0.25*hs, z + h / 2), (rr - 0.35*hs, z + h / 2)], metal)
        for i in range(10):
            theta = i * math.tau / 10
            a.sphere("Hoop rivet", rivet_radius, ((rr + 0.35*hs) * math.cos(theta), (rr + 0.35*hs) * math.sin(theta), z), metal)
    if open_top:
        a.cylinder("Tub interior", radius * 0.82 - stave_thickness - .1, base_thickness, (0, 0, base_thickness*2), woods[0])
    else:
        lid = M.oak(f"{name} head", wood_tone, wear, seed)
        a.cylinder("Inset head", radius * 0.82, 2, (0, 0, height - 2), lid)
        for x in (-0.5, 0, 0.5):
            xx = x * radius
            length = math.sqrt((radius * 0.80) ** 2 - xx ** 2)
            a.tube("Head board joint", [(xx, -length, height - 0.95), (xx, length, height - 0.95)], 0.065, woods[0])
    if water:
        m, k = E.material(f"{name} water")
        n = k.noise(k.coords().outputs["Object"], 0.3, 2).outputs["Fac"]
        k.surface(k.bsdf(Base_Color=(0.006, 0.012, 0.016, 1), Roughness=0.16, Metallic=0,
                         IOR=1.333, Coat_Weight=0.6, Normal=k.bump(n, 0.1, 0.03)))
        a.cylinder("Still quench water", r(0.86) - 1.6, 0.3, (0, 0, height * 0.86), m)
    return a.root
