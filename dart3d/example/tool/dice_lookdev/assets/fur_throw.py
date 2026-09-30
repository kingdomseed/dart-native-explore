"""Continuous folded pelt over a bench edge, with inexpensive tapered guard hairs."""

import bpy
import math
import random

import env_common as E
from . import geometry as G


def build(name="Fur throw", loc=(0, 0, 0), rot_z=0, width=62, length=88, drop=38,
          tone=(0.115, 0.078, 0.043), wear=0.5, seed=3, strands=10000) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    m, k = E.material(f"{name} underfur")
    n = k.noise(k.coords().outputs["Object"], 0.08, 3).outputs["Fac"]
    col = k.ramp(n, [(0.25, tuple(c * 0.24 for c in tone)), (0.55, tuple(c * 0.5 for c in tone)),
                     (0.8, tone)])
    k.surface(k.bsdf(Base_Color=col, Roughness=0.95, Sheen_Weight=0.8,
                     Normal=k.bump(k.noise(k.coords().outputs["Object"], 3, 2).outputs["Fac"], 0.3, 0.13)))
    hair, hk = E.material(f"{name} silver tipped guard hairs")
    attr = hk.node("ShaderNodeAttribute")
    attr.attribute_name = "FurTip"
    n = hk.noise(hk.coords().outputs["Object"], 0.13, 3).outputs["Fac"]
    root_col = hk.ramp(n, [(0.2, tuple(c * 0.3 for c in tone)), (0.55, tone), (0.8, tuple(c * 1.7 for c in tone))])
    tip = hk.ramp(attr.outputs["Fac"], [(0.3, (0, 0, 0)), (0.85, (0.68, 0.68, 0.68)), (1, (0.9, 0.9, 0.9))])
    col = hk.mix(tip, root_col, (0.36, 0.29, 0.19, 1))
    hk.surface(hk.bsdf(Base_Color=col, Roughness=0.7, Sheen_Weight=0.65, Sheen_Roughness=0.45))
    def point(u, v):
        taper = 0.72 + 0.19 * math.sin(v * 7 + 0.3) ** 2 + 0.035 * math.sin(v * 31)
        x = u * width * 0.5 * taper
        travel = v * length
        edge = length - drop
        fold = (0.8 + 0.35 * math.sin(v * 8)) * math.sin(u * 17 + v * 2)
        if travel < edge:
            return (x, edge / 2 - travel, 1.1 + fold)
        bend = 4.0
        arc = min(math.pi / 2, (travel - edge) / bend)
        fall = max(0, travel - edge - bend * math.pi / 2)
        return (x, -edge / 2 - bend * math.sin(arc) + fold * 0.3,
                1.1 - bend * (1 - math.cos(arc)) - fall + math.cos(arc) * fold)
    nx, ny = 32, 44
    verts = [point(-1 + 2 * i / nx, j / ny) for j in range(ny + 1) for i in range(nx + 1)]
    faces = [(j * (nx + 1) + i, j * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i + 1,
              (j + 1) * (nx + 1) + i) for j in range(ny) for i in range(nx)]
    a.mesh("Draped hide", verts, faces, m, smooth=True)
    hair_verts, hair_faces, tips = [], [], []
    clumps = [(rng.uniform(-1.02, 1.02), rng.random(), rng.uniform(-1.8, 1.8), rng.uniform(3, 5.8))
              for _ in range(max(1, strands // 18))]
    for i in range(strands + 8000):
        cu, cv, lean, h = clumps[i % len(clumps)]
        short = i >= strands
        if short:
            cu, cv, lean, h = rng.uniform(-1, 1), rng.random(), rng.uniform(-0.3, 0.3), rng.uniform(1, 2.1)
        u, v = max(-1.06, min(1.06, cu + rng.gauss(0, 0.026))), max(0, min(1, cv + rng.gauss(0, 0.012)))
        x, y, z = point(u, v)
        edge = length - drop
        bend = max(0, min(math.pi / 2, (v * length - edge) / 4))
        normal_y, normal_z = -math.sin(bend), math.cos(bend)
        flow_y, flow_z = -math.cos(bend), -math.sin(bend)
        h *= rng.uniform(0.75, 1.13)
        w = rng.uniform(0.065, 0.12) if short else rng.uniform(0.035, 0.075)
        lean += (cu - u) * width * 0.4
        turn = rng.uniform(-0.6, 0.6)
        start = len(hair_verts)
        steps = 3 if short else 6
        for j in range(steps):
            t = j / (steps - 1)
            lift = math.sin(t * math.pi * 0.85) * h * 0.54
            flow = t * h * 0.88
            px = x + lean * t
            py = y + normal_y * lift + flow_y * flow
            pz = z + normal_z * lift + flow_z * flow
            ww = w * (1 - t) + 0.001
            tips.extend((t * (0.65 if short else 1),) * 2)
            hair_verts += [(px - ww, py - turn * ww * flow_y, pz - turn * ww * flow_z),
                           (px + ww, py + turn * ww * flow_y, pz + turn * ww * flow_z)]
        hair_faces += [(start + j * 2, start + j * 2 + 1, start + j * 2 + 3, start + j * 2 + 2)
                       for j in range(steps - 1)]
    ob = a.mesh("Clumped silver tipped guard hairs", hair_verts, hair_faces, hair, smooth=True)
    attr = ob.data.attributes.new("FurTip", "FLOAT", "POINT")
    attr.data.foreach_set("value", tips)
    return a.root
