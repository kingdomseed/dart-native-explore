"""Emberforged environment: "The Forge Hearth".

A cast-iron tray bolted onto a basalt forge slab. Faint lava seams in the
tray floor, a coal brazier and an ember bowl behind the back wall, a sooty
brick forge wall, rising sparks and warm smoke. The play area itself stays
dark and matte so the glowing dice own the frame.
"""
from __future__ import annotations

import math
import random

from mathutils import Vector

import env_common as E
import env_props as P

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.4, 3.4


def basalt_floor():
    m, k = E.material("Forge floor basalt")
    obj = k.coords().outputs["Object"]
    grain = k.noise(obj, 0.9, 10, 0.62).outputs["Fac"]
    base = k.ramp(grain, [(0.3, (0.018, 0.016, 0.015)), (0.7, (0.05, 0.045, 0.04))])
    seams = k.voronoi(k.mix(0.25, obj, k.noise(obj, 0.2, 3).outputs["Color"], "LINEAR_LIGHT"), 0.06,
                      feature="DISTANCE_TO_EDGE")
    seam = k.math("LESS_THAN", seams.outputs["Distance"], 0.005)
    mask = k.math("GREATER_THAN", k.noise(obj, 0.05, 2).outputs["Fac"], 0.5)
    glow = k.math("MULTIPLY", seam, mask)
    bump = k.bump(grain, 0.5, 0.2)
    bump = k.bump(k.math("SUBTRACT", 1.0, seam), 0.6, 0.15, normal=bump)
    s = k.bsdf(Base_Color=base, Roughness=0.86, Normal=bump,
               Emission_Color=(1.0, 0.22, 0.02, 1), Emission_Strength=k.math("MULTIPLY", glow, 1.0))
    k.surface(s)
    return m


def iron(name="Blackened iron", heat=True):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    ham = k.voronoi(obj, 1.6)
    n = k.noise(obj, 3.0, 8, 0.6).outputs["Fac"]
    col = k.ramp(n, [(0.35, (0.02, 0.018, 0.017)), (0.75, (0.09, 0.07, 0.06))])
    bump = k.bump(ham.outputs["Distance"], 0.35, 0.3)
    s = k.bsdf(Base_Color=col, Metallic=0.85, Roughness=k.math("ADD", k.math("MULTIPLY", n, 0.3), 0.32),
               Normal=bump)
    k.surface(s)
    return m


def coal():
    m, k = E.material("Live coal")
    obj = k.coords().outputs["Object"]
    cr = k.voronoi(obj, 3.0, feature="DISTANCE_TO_EDGE")
    crack = k.math("LESS_THAN", cr.outputs["Distance"], 0.06)
    heat = k.noise(obj, 0.8, 3).outputs["Fac"]
    col = k.ramp(heat, [(0.35, (0.9, 0.12, 0.01)), (0.7, (1.0, 0.5, 0.08))])
    strength = k.math("MULTIPLY", k.math("ADD", crack, k.math("MULTIPLY", heat, 0.25)), 14.0)
    s = k.bsdf(Base_Color=(0.02, 0.018, 0.017, 1), Roughness=0.9, Emission_Color=col, Emission_Strength=strength)
    k.surface(s)
    return m


def flame_volume(strength=18.0):
    """Surface flame (emission + transparency): reads as fire at a fraction of a volume's cost."""
    m, k = E.material("Flame")
    obj = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    warp = k.noise(obj, 1.2, 3, 0.5, dims="4D", w=0.3).outputs["Color"]
    vec = k.mix(0.4, obj, warp, "LINEAR_LIGHT")
    n = k.noise(vec, 2.2, 6, 0.6, dist=0.6).outputs["Fac"]
    up = k.math("SUBTRACT", 1.0, k.math("MULTIPLY", k.math("ADD", sep.outputs["Z"], 1.0), 0.5), clamp=True)
    lw = k.node("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.5
    core = k.math("SUBTRACT", 1.0, lw.outputs["Fresnel"])
    heat = k.math("MULTIPLY", k.math("MULTIPLY", k.math("POWER", n, 1.6), up), core)
    heat = k.math("MULTIPLY", heat, 4.0, clamp=True)
    col = k.ramp(heat, [(0.0, (0.3, 0.02, 0.0)), (0.4, (1.0, 0.25, 0.02)), (0.8, (1.0, 0.65, 0.2)),
                        (1.0, (1.0, 0.95, 0.75))])
    em = k.emission(col, k.math("MULTIPLY", heat, strength * 0.5))
    tr = k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(k.math("POWER", heat, 0.5), tr, em))
    return m


def brick_wall():
    m, k = E.material("Forge brick")
    obj = k.coords().outputs["Object"]
    b = k.node("ShaderNodeTexBrick")
    k.link(obj, b.inputs["Vector"])
    k.set(b, Scale=0.06, Mortar_Size=0.02, Color1=(0.12, 0.05, 0.03, 1), Color2=(0.07, 0.03, 0.02, 1),
          Mortar=(0.01, 0.01, 0.01, 1))
    n = k.noise(obj, 0.3, 8, 0.6).outputs["Fac"]
    soot = k.mix(k.math("MULTIPLY", n, 0.9), b.outputs["Color"], (0.005, 0.005, 0.005, 1))
    bump = k.bump(b.outputs["Fac"], 0.7, 0.8)
    k.surface(k.bsdf(Base_Color=soot, Roughness=0.9, Normal=bump))
    return m


def brazier(scene, x, y, z, r=5.5, seed=3, coals=26, flames=5):
    im = iron("Brazier iron")
    bowl = E.cylinder("brazier_bowl", r * 0.55, r * 0.7, (x, y, z + 8.5), im, r2=r, cap=True)
    mod = bowl.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = 0.5
    for i in range(3):
        a = math.radians(120 * i + 30)
        leg = E.cylinder(f"brazier_leg{i}", 0.35, 9.5, (x + math.cos(a) * r * 0.55, y + math.sin(a) * r * 0.55,
                                                        z + 4.6), im, segs=12)
        leg.rotation_euler = (math.sin(a) * 0.18, -math.cos(a) * 0.18, 0)
    E.cylinder("brazier_ring", r * 0.62, 0.5, (x, y, z + 3.0), im, segs=48)
    cm = coal()
    rng = random.Random(seed)
    for i in range(coals):
        a, rr = rng.uniform(0, 6.28), r * 0.78 * math.sqrt(rng.random())
        E.rock(f"coal{i}", rng.uniform(0.9, 1.6), (x + math.cos(a) * rr, y + math.sin(a) * rr,
                                                   z + 8.8 + rng.uniform(0, 1.0)), cm, seed=i + seed * 100,
               squash=(1, 1, 0.75), subdiv=2)
    fm = flame_volume()
    for i in range(flames):
        a, rr = rng.uniform(0, 6.28), rng.uniform(0, r * 0.4)
        h = rng.uniform(5, 9)
        fl = E.sphere(f"flame{i}", 1.0, (x + math.cos(a) * rr, y + math.sin(a) * rr, z + 9.5 + h * 0.45), fm, subdiv=3,
                 scale=(rng.uniform(1.8, 2.8), rng.uniform(1.8, 2.8), h))
        fl.visible_shadow = False
    E.light(scene, "POINT", "brazier_light", (x, y, z + 13), 9000, color=(1.0, 0.45, 0.14), size=3.0)
    E.light(scene, "POINT", "brazier_coal_light", (x, y, z + 10), 2500, color=(1.0, 0.3, 0.06), size=4.0)


def build(scene):
    E.world(scene, color=(0.004, 0.003, 0.003), strength=1.0)
    # Basalt forge slab and the room floor.
    slab_m = basalt_floor()
    E.cube("forge_slab", (W + 46, D + 36, 6), (0, 0, -3.0), slab_m, bevel=0.6)
    E.plane("room_floor", 600, 600, (0, 0, -30), E.simple("Floor", (0.015, 0.012, 0.01), 0.9))
    # Tray: forged iron plate with an engraved forge sigil, ringed by a molten channel.
    sigil = P.mask_texture("forge_sigil", P.sigil_strokes(seed=5, points=5, runes=20,
                                                          rings=(0.47, 0.455, 0.37, 0.2), w=0.003),
                           E.TMP, res=2048)
    floor_m, k = E.material("Tray forged iron")
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 1.3, 10, 0.6).outputs["Fac"]
    ham = k.voronoi(obj, 0.9).outputs["Distance"]
    ash = k.ramp(n, [(0.35, (0.028, 0.025, 0.024)), (0.75, (0.07, 0.062, 0.058))])
    sm = k.node("ShaderNodeMapping")
    sm.inputs["Scale"].default_value = (1 / (W * 0.92), 1 / (W * 0.92), 1)
    sm.inputs["Location"].default_value = (0.5, 0.5, 0)
    k.link(obj, sm.inputs["Vector"])
    tex = k.node("ShaderNodeTexImage", image=sigil, extension="CLIP", interpolation="Cubic")
    k.link(sm.outputs[0], tex.inputs["Vector"])
    groove = tex.outputs["Color"]
    bump = k.bump(ham, 0.25, 0.2)
    bump = k.bump(groove, 0.8, 0.15, normal=bump, invert=True)
    flick = k.noise(obj, 0.15, 2).outputs["Fac"]
    k.surface(k.bsdf(Base_Color=ash, Roughness=k.math("ADD", k.math("MULTIPLY", n, 0.25), 0.5), Metallic=0.6,
                     Normal=bump, Emission_Color=(1.0, 0.18, 0.01, 1),
                     Emission_Strength=k.math("MULTIPLY", groove, k.math("MULTIPLY", flick, 0.9))))
    lava, k = E.material("Molten channel")
    obj = k.coords().outputs["Object"]
    cr = k.voronoi(obj, 0.7, feature="DISTANCE_TO_EDGE")
    crust = k.math("GREATER_THAN", cr.outputs["Distance"], 0.07)
    heat = k.noise(obj, 0.5, 4, 0.6).outputs["Fac"]
    col = k.ramp(heat, [(0.35, (0.9, 0.06, 0.0)), (0.7, (1.0, 0.3, 0.02))])
    k.surface(k.bsdf(Base_Color=(0.02, 0.015, 0.01, 1), Roughness=0.9, Emission_Color=col,
                     Emission_Strength=k.math("MULTIPLY", k.math("SUBTRACT", 1.0, k.math("MULTIPLY", crust, 0.8)),
                                              2.2)))
    E.rim("molten_channel", W - 1.6, D - 1.6, 2.2, 0.55, 0.55, lava, z0=-0.35)
    E.plane("tray_floor", W + RIM_T * 2, D + RIM_T * 2, (0, 0, 0.001), floor_m)
    im = iron()
    E.rim("tray_rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, im)
    rv = E.simple("Rivet", (0.12, 0.1, 0.09), 0.35, 1.0)
    for i, (x, y) in enumerate(E.rounded_rect(W + RIM_T, D + RIM_T, 3.0, seg=2)[::1]):
        E.sphere(f"rivet{i}", 0.35, (x, y, RIM_H + 0.05), rv, subdiv=2, scale=(1, 1, 0.6))

    # Props behind the back wall.
    brazier(scene, -13.0, D / 2 + 13, 0.0, r=5.8)
    brazier(scene, 17.0, D / 2 + 8, 0.0, r=3.6, seed=9, coals=12, flames=3)
    E.cube("forge_wall", (140, 4, 90), (0, D / 2 + 42, 30), brick_wall())
    # anvil beside the tray
    ax, ay = W / 2 + 9, -6
    E.cube("anvil_foot", (5.5, 7, 3.5), (ax, ay, 1.75), im2 := iron("Anvil iron"), bevel=0.4)
    E.cube("anvil_waist", (3.6, 5, 3), (ax, ay, 4.8), im2, bevel=0.3)
    E.cube("anvil_face", (5, 11, 2.5), (ax, ay, 7.5), im2, bevel=0.3)
    horn = E.cylinder("anvil_horn", 1.25, 5.5, (ax, ay - 8.2, 7.5), im2, segs=24, r2=0.15)
    horn.rotation_euler = (math.radians(90), 0, 0)
    E.light(scene, "POINT", "anvil_glint", (ax - 6, ay - 4, 20), 300, color=(1.0, 0.5, 0.2), size=2)
    # tongs + ingots on the slab edge
    for i in range(3):
        E.cube(f"ingot{i}", (5.0, 2.2, 1.4), (-16.5 + i * 0.4, -D / 2 - 6.5 + i * 2.5 * 0, 0.7 + i * 1.4), im2,
               bevel=0.3).rotation_euler = (0, 0, 0.12 * i)
    t1 = E.cylinder("tong_a", 0.25, 26, (19.5, -4, 0.6), im2, segs=8)
    t1.rotation_euler = (math.radians(90), 0, math.radians(8))
    t2 = E.cylinder("tong_b", 0.25, 26, (20.5, -4, 0.6), im2, segs=8)
    t2.rotation_euler = (math.radians(90), 0, math.radians(-4))

    # Atmosphere: sparks rising off the brazier, drifting embers, warm smoke.
    spark = E.emissive("Spark", (1.0, 0.45, 0.08), 60.0)
    E.scatter("sparks", 140, ((-22, D / 2 + 4, 14), (-4, D / 2 + 22, 55)), 0.06, spark, seed=4,
              stretch=lambda p, r: Vector((r.uniform(-0.3, 0.3), r.uniform(-0.3, 0.3), 1)) * r.uniform(4, 12))
    ember = E.emissive("Drift ember", (1.0, 0.35, 0.05), 30.0)
    E.scatter("embers", 90, ((-30, -30, 4), (30, 40, 30)), 0.09, ember, seed=5,
              avoid=lambda p: abs(p.x) < W / 2 and abs(p.y) < D / 2 and p.z < 9)
    E.haze_box("smoke", (150, 150, 70), (0, 10, 35), 0.0035, color=(1.0, 0.8, 0.65), noise_scale=0.03)

    # Lights: warm soft key over the tray, cold rim for separation.
    E.light(scene, "AREA", "key", (-18, -30, 40), 3200, color=(1.0, 0.85, 0.72), size=22, target=(0, 0, 0))
    E.light(scene, "AREA", "cold_rim", (26, 30, 18), 2200, color=(0.35, 0.5, 1.0), size=18, target=(0, 0, 0))
    E.light(scene, "AREA", "fill", (10, -40, 8), 250, color=(0.6, 0.55, 0.9), size=30, target=(0, 0, 2))

    return dict(
        samples=160, exposure=0.1, hero=dict(dist=32, elev=26, az=-8, lens=70, fstop=2.8),
        d20=dict(dist=11, elev=52, az=-18, lens=100, fstop=4.0),
        env=dict(target=(0, 10, 4), dist=100, elev=30, az=22, lens=35, fstop=8.0, focus=(0, 2, 2)),
        roll=dict(
            settled={"d12": ((-5.0, -9.0), 12, 20), "d6": ((6.0, -4.0), 6, -10), "d10t": ((-2.0, 3.0), 0, 30),
                     "d4": ((7.0, 8.5), 4, 0)},
            airborne={"d20": ((0.5, -3.0, 3.2), (1.2, 2.5, 0.2)), "d8": ((-6.5, 6.0, 5.5), (2.0, -1.0, -0.5)),
                      "d10u": ((4.5, 14.0, 2.4), (-1.5, -2.0, 0.3))}),
    )
