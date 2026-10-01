"""Unlettered leather binding, sewn signatures, raised spine and metal corners."""

import bpy
import math

import env_common as E
from . import geometry as G, materials as M


def build(name="Leather book", loc=(0, 0, 0), rot_z=0, width=17, depth=24, thickness=5,
          tone=(0.075, 0.022, 0.009), metal_finish="brass", wear=0.7, seed=2, gilt_spine=False) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    leather = M.leather(f"{name} calfskin", tone, wear, seed)
    metal = M.metal(f"{name} mounts", metal_finish, wear, seed)
    page, k = E.material(f"{name} parchment")
    vec = M.mapped(k, (0.08, 0.08, 18), seed)
    n = k.noise(vec, 1, 2).outputs["Fac"]
    col = k.ramp(n, [(0.3, (0.19, 0.12, 0.058)), (0.7, (0.53, 0.39, 0.19))])
    k.surface(k.bsdf(Base_Color=col, Roughness=0.94, Normal=k.bump(n, 0.2, 0.018)))
    a.block("Page block", (width - 0.8, depth - 1.2, thickness - 0.9), (0.1, 0, thickness / 2), page, 0.18)
    for z in (0.25, thickness - 0.25):
        a.block("Leather cover board", (width, depth, 0.5), (0, 0, z), leather, 0.2)
    a.block("Rounded spine", (1, depth - 0.15, thickness), (-width / 2 + 0.4, 0, thickness / 2), leather, 0.45)
    for y in (-depth * 0.35, -depth * 0.18, depth * 0.18, depth * 0.35):
        a.tube("Raised binding cord", [(-width / 2 + 1.6, y, thickness), (-width / 2 + 0.15, y, thickness - 0.1),
                                       (-width / 2 - 0.15, y, thickness * 0.7),
                                       (-width / 2 - 0.15, y, thickness * 0.3), (-width / 2 + 0.2, y, 0.1)],
               0.22, leather)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (width / 2 - 0.15), sy * (depth / 2 - 0.15)
            verts = [(x, y, thickness + 0.04), (x - sx * 3.3, y, thickness + 0.04),
                     (x, y - sy * 3.3, thickness + 0.04)]
            ob = a.mesh("Triangular corner mount", verts, [(0, 1, 2)], metal)
            mod = ob.modifiers.new("Corner metal thickness", "SOLIDIFY")
            mod.thickness = 0.14
            a.tube("Embossed corner border", [(x - sx * 0.5, y - sy * 2.4, thickness + 0.15),
                                             (x - sx * 0.5, y - sy * 0.5, thickness + 0.15),
                                             (x - sx * 2.4, y - sy * 0.5, thickness + 0.15)], 0.08, metal)
            a.sphere("Corner stud", 0.16, (x - sx * 0.65, y - sy * 0.65, thickness + 0.18), metal)
    for y in (-depth * 0.26, depth * 0.26):
        a.block("Leather clasp strap", (4, 1.6, 0.25), (width / 2 - 1, y, thickness + 0.1), leather, 0.1)
        a.block("Brass clasp", (2, 1.85, 0.25), (width / 2 - 0.7, y, thickness + 0.32), metal, 0.12)
    a.tube("Blind tooled border", [(-width / 2 + 2, -depth / 2 + 2, thickness + 0.02),
                                  (width / 2 - 2, -depth / 2 + 2, thickness + 0.02),
                                  (width / 2 - 2, depth / 2 - 2, thickness + 0.02),
                                  (-width / 2 + 2, depth / 2 - 2, thickness + 0.02)], 0.06, metal, cyclic=True)
    if gilt_spine:
        x=-width/2-.17
        for y in (-depth*.40,-depth*.30,depth*.30,depth*.40):
            a.tube("Gilt spine rule",[(x,y,.65),(x,y,thickness-.65)],.045,metal)
        for y in (-depth*.17,0,depth*.17):
            pts=[]
            for j in range(8):
                t=j*math.tau/8; r=min(.85,thickness*.22) if j%2==0 else thickness*.075
                pts.append((x-.015,y+r*math.cos(t),thickness/2+r*math.sin(t)))
            a.tube("Unlettered gilt spine star",pts,.047,metal,cyclic=True,resolution=1)
    return a.root
