"""Glazed six-sided iron cage, pierced peaked cap, candle and suspension."""

import bpy
import math

import env_common as E
from . import geometry as G, materials as M
from .forge import fire_tongue


def build(name="Cage lantern", loc=(0, 0, 0), rot_z=0, height=36, radius=9,
          metal_finish="iron", wear=0.5, seed=1, chain_length=35, energy=18000,
          glass_tone=(.65,.33,.095), glow_color=(1,.29,.055),
          light_color=(1,.57,.23)) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    iron = M.metal(f"{name} frame", metal_finish, wear, seed)
    trim = M.metal(f"{name} worn rims", "brass", wear, seed)
    glass, k = E.material(f"{name} warm imperfect glass")
    vec = k.coords().outputs["Generated"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(vec, sep.inputs[0])
    glow = k.ramp(sep.outputs["Z"], [(0, (0.12, 0.12, 0.12)), (0.4, (0.6, 0.6, 0.6)), (1, (0.08, 0.08, 0.08))])
    pane = k.bsdf(Base_Color=(*glass_tone, 1), Roughness=0.19, Transmission_Weight=1, IOR=1.46)
    tr = k.node("ShaderNodeBsdfTransparent").outputs[0]
    clear = k.mix_shader(0.1, tr, pane)
    add = k.node("ShaderNodeAddShader")
    k.link(clear, add.inputs[0])
    k.link(k.emission((*glow_color, 1), glow), add.inputs[1])
    k.surface(add.outputs[0])
    lower, upper = height * 0.15, height * 0.75
    a.lathe("Lantern foot", [(0, 0), (radius * 0.8, 0), (radius, height * 0.05),
                            (radius, lower), (radius * 0.78, lower + 1), (0, lower + 1)], iron, segments=6)
    for z in (lower, upper):
        a.ring("Cage hexagonal rail", radius, 0.45, (0, 0, z), trim, segments=6)
    for i in range(6):
        t, t2 = math.tau * i / 6, math.tau * (i + 1) / 6
        x, y, xx, yy = radius * math.cos(t), radius * math.sin(t), radius * math.cos(t2), radius * math.sin(t2)
        a.beam("Corner frame", (x, y, lower), (x, y, upper), 0.75, 0.75, iron, 0.12)
        a.mesh("Amber glass pane", [(x, y, lower + 0.5), (xx, yy, lower + 0.5),
                                    (xx, yy, upper - 0.5), (x, y, upper - 0.5)], [(0, 1, 2, 3)], glass)
        midx, midy, midz = (x + xx) / 2, (y + yy) / 2, (lower + upper) / 2
        a.tube("Diamond cage", [(midx, midy, lower + 1), (xx, yy, midz),
                               (midx, midy, upper - 1), (x, y, midz)], 0.24, iron, cyclic=True)
    a.lathe("Peaked vent cap", [(radius * 1.1, upper), (radius * 1.12, upper + 1),
                                (radius * 0.3, height * 0.96), (radius * 0.27, height), (0, height)], iron, segments=6)
    a.ring("Suspension ring", radius * 0.23, 0.38, (0, 0, height + radius * 0.22), iron, plane="XZ")
    wax = E.simple(f"{name} beeswax", (0.67, 0.43, 0.16), 0.7, Subsurface_Weight=0.07)
    candle_h = height * 0.28
    a.cylinder("Candle", radius * 0.24, candle_h, (0, 0, lower + candle_h / 2), wax, bevel=0.25)
    a.cylinder("Wick", 0.12, 1, (0, 0, lower + candle_h + 0.2), iron, bevel=0)
    fire_tongue(a, "Candle flame", (0, 0, lower + candle_h), radius * 0.11, height * 0.16,
                M.flame(f"{name} flame", 15), lean=0.4)
    glow_light = a.light("Lantern glow", (0, 0, lower + candle_h + 1.5), energy, light_color, radius * 0.25)
    glow_light.visible_glossy = False
    glow_light.visible_transmission = False
    glow_light.data.specular_factor = 0
    if chain_length:
        G.chain(a, "Suspension chain", (0, 0, height + chain_length), chain_length - 1, iron, radius=1.05)
        a.tube("Forged ceiling hook", [(0, 0, height + chain_length - 1), (0, -2, height + chain_length + 1),
                                      (0, -3, height + chain_length + 4), (0, -1, height + chain_length + 6),
                                      (0, 1, height + chain_length + 5)], 0.6, iron)
    return a.root
