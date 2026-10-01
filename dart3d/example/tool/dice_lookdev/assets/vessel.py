"""Turned goblets, tankards, ceramic jars and stoppered glass bottles."""

import bpy
import math

import env_common as E
from . import geometry as G, materials as M


def build(name="Vessel", loc=(0, 0, 0), rot_z=0, kind="goblet", height=18, radius=5,
          metal_finish="pewter", tone=(0.11, 0.06, 0.025), wear=0.5, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    metal = M.metal(f"{name} metal", metal_finish, wear, seed)
    if kind == "goblet":
        profile = [(0, 0), (0.7, 0), (0.85, 0.035), (0.84, 0.07), (0.55, 0.10),
                   (0.23, 0.15), (0.14, 0.26), (0.17, 0.32), (0.26, 0.35), (0.25, 0.39),
                   (0.16, 0.43), (0.22, 0.48), (0.49, 0.53), (0.7, 0.63), (0.91, 0.82),
                   (1, 0.96), (1, 1), (0.95, 1.01), (0.91, 0.96), (0.86, 0.83),
                   (0.65, 0.64), (0.43, 0.56), (0, 0.55)]
        a.lathe("Raised goblet", [(r * radius, z * height) for r, z in profile], metal, segments=64)
        dark = M.metal(f"{name} tarnished recesses", "iron", wear, seed)
        def cup_radius(z):
            return radius * (0.7 + (z - 0.63) / 0.19 * 0.21 if z <= 0.82 else 0.91 + (z - 0.82) / 0.14 * 0.09)
        a.lathe("Recessed ornamental girdle", [(cup_radius(z) + 0.014, height * z) for z in (0.675, 0.82, 0.925)], dark, segments=64)
        a.sphere("Gadrooned stem knop", radius * 0.32, (0, 0, height * 0.365), metal,
                 scale=(1, 1, 0.75), subdiv=3)
        for z, r in ((0.065, 0.82), (0.11, 0.5), (0.31, 0.18), (0.415, 0.19), (0.675, 0.765), (0.93, 0.967), (0.992, 0.998)):
            a.ring("Moulded silver bead", radius * r, 0.12, (0, 0, height * z), metal)
        for i in range(12):
            t = math.tau * i / 12
            for side in (-1, 1):
                pts = []
                for j in range(25):
                    f = j / 24
                    z = height * (0.69 + 0.23 * f)
                    rad = cup_radius(0.69 + 0.23 * f) + 0.085
                    angle = t + side * math.sin(f * math.pi) * 0.21
                    pts.append((rad * math.cos(angle), rad * math.sin(angle), z))
                a.tube("Raised interlaced silver lozenge", pts, 0.095, metal, resolution=2)
            a.sphere("Chased central boss", 0.19, ((cup_radius(0.815) + 0.08) * math.cos(t), (cup_radius(0.815) + 0.08) * math.sin(t), height * 0.815), metal)
            a.sphere("Knop fluting", radius * 0.1,
                     (radius * 0.27 * math.cos(t), radius * 0.27 * math.sin(t), height * 0.365), metal,
                     scale=(0.9, 0.9, 1.6))
    elif kind == "tankard":
        a.lathe("Pewter tankard", [(0, 0), (radius, 0), (radius, 1), (radius * 0.86, height - 0.5),
                                   (radius * 0.9, height), (radius * 0.81, height),
                                   (radius * 0.77, 1.5), (0, 1.5)], metal)
        for z in (1.3, height - 1):
            a.ring("Tankard lip", radius * (1 - z / height * 0.13), 0.17, (0, 0, z), metal)
        a.tube("Scrolled handle", [(radius * 0.88, 0, height * 0.8), (radius * 1.55, 0, height * 0.86),
                                   (radius * 1.8, 0, height * 0.65), (radius * 1.78, 0, height * 0.38),
                                   (radius * 1.42, 0, height * 0.2), (radius * 0.96, 0, height * 0.25)], 0.65, metal)
    elif kind == "wooden_tankard":
        from . import barrel
        a.add(barrel.build(name+" coopered cup",radius=radius,height=height,wood_tone=tone,
                          metal_finish=metal_finish,wear=wear,seed=seed,open_top=True,
                          stave_thickness=.55,hoop_thickness=.24,rivet_radius=.17,staves=14,
                          hoops=(.13,.84),base_thickness=.8,grain_scale=4))
        pts=[(radius*(.89+.95*math.sin(t)),0,height*(.49+.32*math.cos(t))) for t in (math.pi*i/32 for i in range(33))]
        verts=[(x,y+side*.7,z+dz) for x,y,z in pts for side,dz in ((-1,-.2),(1,-.2),(1,.2),(-1,.2))]
        faces=[(i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j) for i in range(32) for j in range(4)]
        a.mesh("Bent strap handle",verts,faces,metal,bevel=.14,smooth=True)
    elif kind == "jug":
        glaze=M.stoneware(name+" salt glaze",tone,wear,seed)
        profile=[(0,0),(.61,0),(.72,.035),(.91,.15),(1,.38),(.94,.59),(.71,.76),
                 (.49,.86),(.48,.97),(.56,1),(.49,1.02),(.41,.97),(.42,.86),(.62,.72),(.85,.56),(.9,.33),(.66,.08),(0,.08)]
        ob=a.lathe("Open thrown jug",[(r*radius,z*height) for r,z in profile],glaze,segments=64)
        for v in ob.data.vertices:
            if v.co.z>height*.88 and v.co.x<0:
                lip=max(0,(-v.co.x/radius-.15)/.4)*((v.co.z/height-.88)/.14)
                v.co.x-=lip*radius*.22
                v.co.z+=lip*height*.035
        pts=[(radius*(.5+1.07*math.sin(t)),0,height*(.60+.28*math.cos(t))) for t in [math.pi*i/40 for i in range(41)]]
        a.tube("Pulled ceramic handle",pts,radius*.13,glaze,resolution=3)
    else:
        if kind == "bottle":
            m, k = E.material(f"{name} green glass")
            k.surface(k.bsdf(Base_Color=(*tone, 1), Roughness=0.2, Transmission_Weight=0.35, IOR=1.46,
                             Coat_Weight=0.4))
            profile = [(0, 0), (0.82, 0), (1, 0.07), (1, 0.6), (0.85, 0.69),
                       (0.32, 0.78), (0.3, 0.94), (0.38, 0.96), (0.38, 1), (0.22, 1), (0.22, 0.83)]
        else:
            m, k = E.material(f"{name} glaze")
            n = k.noise(k.coords().outputs["Object"], 1.2, 2).outputs["Fac"]
            col = k.ramp(n, [(0.25, tuple(c * 0.5 for c in tone)), (0.8, tone)])
            k.surface(k.bsdf(Base_Color=col, Roughness=0.3, Coat_Weight=0.35, Normal=k.bump(n, 0.1, 0.025)))
            profile = [(0, 0), (0.7, 0), (0.9, 0.06), (1, 0.35), (0.95, 0.64),
                       (0.65, 0.83), (0.55, 0.88), (0.6, 0.93), (0.6, 1), (0.5, 1), (0.47, 0.89)]
        a.lathe("Thrown jar" if kind == "jar" else "Blown bottle", [(r * radius, z * height) for r, z in profile], m)
        cork = M.oak(f"{name} cork", (0.2, 0.12, 0.05), seed=seed)
        a.cylinder("Stopper", radius * (0.25 if kind == "bottle" else 0.48), height * 0.075,
                   (0, 0, height * 1.02), cork, bevel=0.2)
    return a.root
