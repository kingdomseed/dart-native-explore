"""Celestial Observatory environment: "The Star Balcony".

A veined marble table on an open balcony at night. The rolling surface is
an inlaid silver astrolabe disc (moon-phase ring, star-chart dots). Around
it: amethyst clusters, a brass-and-glass lantern, a silver armillary and a
star globe; beyond the balustrade a violet, star-dusted sky.
"""
from __future__ import annotations

import math
import random

import env_common as E
import env_props as P
from build_dice import _circle
from build_env_frostbound import crystal_cluster

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.2, 2.4


def astrolabe_strokes(w=0.0035, seed=3):
    rng = random.Random(seed)
    s = [([P.ring(r)], w * (1.5 if r > 0.46 else 1.0), True) for r in (0.475, 0.46, 0.4, 0.33, 0.15)]
    for i in range(8):  # moon phases in the outer band
        a = 2 * math.pi * i / 8 + math.pi / 2
        cx, cy = 0.5 + 0.43 * math.cos(a), 0.5 + 0.43 * math.sin(a)
        s.append(([_circle(cx, cy, 0.022, 24)], w, True))
        k = math.cos(math.pi * i / 4)
        arc = [(cx + 0.022 * k * math.cos(t), cy + 0.022 * math.sin(t))
               for t in [math.pi / 2 + j * math.pi / 12 for j in range(13)]]
        s.append(([arc], w, False))
    for i in range(180):
        a = 2 * math.pi * i / 180
        r0 = 0.46 - (0.008 if i % 5 else 0.016)
        s.append(([[(0.5 + r0 * math.cos(a), 0.5 + r0 * math.sin(a)),
                    (0.5 + 0.46 * math.cos(a), 0.5 + 0.46 * math.sin(a))]], w * 0.6, False))
    stars = []
    for i in range(40):  # an invented star chart
        r, a = 0.32 * math.sqrt(rng.random()), rng.uniform(0, 6.28)
        p = (0.5 + r * math.cos(a), 0.5 + r * math.sin(a))
        stars.append(p)
        s.append(([_circle(p[0], p[1], rng.uniform(0.002, 0.006), 10)], w * 1.3, True))
    for i in range(0, 30, 3):
        s.append(([[stars[i], stars[i + 1], stars[i + 2]]], w * 0.5, False))
    # the rete: an eccentric ring and pointer
    s.append(([P.ring(0.24, cx=0.5, cy=0.56)], w * 1.2, True))
    s.append(([[(0.5, 0.5), (0.5, 0.86)]], w * 1.5, False))
    return s


def marble(name):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    warp = k.noise(obj, 0.05, 6, 0.6).outputs["Color"]
    vec = k.mix(0.6, obj, warp, "LINEAR_LIGHT")
    wave = k.node("ShaderNodeTexWave", bands_direction="DIAGONAL")
    k.link(vec, wave.inputs["Vector"])
    k.set(wave, Scale=0.06, Distortion=12.0, Detail=8.0)
    vein = k.math("POWER", wave.outputs["Fac"], 6.0)
    col = k.mix(vein, (0.82, 0.8, 0.84, 1), (0.25, 0.2, 0.32, 1))
    s = k.bsdf(Base_Color=col, Roughness=0.12, Subsurface_Weight=0.2, Coat_Weight=0.5, Coat_Roughness=0.05)
    k.surface(s)
    return m


def sky():
    m, k = E.material("Violet sky")
    tc = k.coords().outputs["Generated"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(tc, sep.inputs[0])
    neb = k.noise(tc, 3.0, 10, 0.65, dist=0.6).outputs["Fac"]
    col = k.ramp(k.math("MULTIPLY", neb, sep.outputs["Z"]), [(0.1, (0.01, 0.005, 0.03)), (0.35, (0.12, 0.03, 0.25)),
                                                             (0.5, (0.35, 0.12, 0.5))])
    stars = k.voronoi(tc, 400.0)
    st = k.math("LESS_THAN", stars.outputs["Distance"], 0.04)
    k.surface(k.add_shader(k.emission(col, 1.5), k.emission((1, 1, 1, 1), k.math("MULTIPLY", st, 6.0))))
    return m


def build(scene):
    E.world(scene, color=(0.01, 0.005, 0.02), strength=1.0)
    inlay = P.mask_texture("astrolabe", astrolabe_strokes(), E.TMP, res=4096)
    E.cube("table", (180, 140, 6), (0, 20, -3.0), marble("Table marble"), bevel=0.8)
    lapis, k = E.material("Lapis field")
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.4, 8, 0.6).outputs["Fac"]
    fleck = k.math("LESS_THAN", k.voronoi(obj, 3.0).outputs["Distance"], 0.07)
    base = k.bsdf(Base_Color=k.ramp(n, [(0.3, (0.01, 0.015, 0.07)), (0.7, (0.03, 0.04, 0.16))]), Roughness=0.2,
                  Coat_Weight=0.8, Coat_Roughness=0.03)
    gold = k.bsdf(Base_Color=(1.0, 0.8, 0.4, 1), Metallic=1.0, Roughness=0.3)
    field = k.mix_shader(fleck, base, gold)
    mp = k.node("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / (W * 0.97), 1 / (W * 0.97), 1)
    mp.inputs["Location"].default_value = (0.5, 0.5, 0)
    k.link(obj, mp.inputs["Vector"])
    tex = k.node("ShaderNodeTexImage", image=inlay, extension="CLIP", interpolation="Cubic")
    k.link(mp.outputs[0], tex.inputs["Vector"])
    silver = k.bsdf(Base_Color=(0.85, 0.87, 0.92, 1), Metallic=1.0, Roughness=0.2,
                    Normal=k.bump(tex.outputs["Color"], 0.4, 0.05))
    k.surface(k.mix_shader(tex.outputs["Color"], field, silver))
    E.plane("disc_field", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.3), lapis)
    E.cube("slab", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.6), (0, 0, 0), marble("Slab marble"), bevel=0.2)
    E.rim("rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, marble("Rim marble"), z0=0.3)
    E.rim("rim_cap", W + RIM_T, D + RIM_T, 3.0, 0.4, 0.6, E.simple("Silver", (0.9, 0.9, 0.95), 0.2, 1.0),
          z0=RIM_H + 0.1)
    top = D / 2 + RIM_T
    am = P.glass("Amethyst", color=(0.6, 0.3, 0.9), rough=0.05, ior=1.55)
    crystal_cluster(-W / 2 - 9, top + 2, 0, 7, 11, am, 1.1)
    crystal_cluster(W / 2 + 8, -D / 2 + 4, 0, 5, 12, am, 0.8)
    E.light(scene, "POINT", "amethyst_glow", (-W / 2 - 9, top + 2, 6), 600, color=(0.7, 0.35, 1.0), size=3)
    P.armillary(W / 2 + 12, top + 10, 0.0, R=6.0, mat=E.simple("Armillary silver", (0.85, 0.87, 0.92), 0.2, 1.0))
    globe_m, k = E.material("Star globe")
    obj = k.coords().outputs["Object"]
    st = k.math("LESS_THAN", k.voronoi(obj, 2.5).outputs["Distance"], 0.06)
    k.surface(k.mix_shader(st, k.bsdf(Base_Color=(0.02, 0.03, 0.12, 1), Roughness=0.3, Coat_Weight=1.0),
                           k.bsdf(Base_Color=(1.0, 0.8, 0.4, 1), Metallic=1.0, Roughness=0.3)))
    E.cylinder("globe_stand", 2.5, 1.0, (-W / 2 - 14, 16, 0.5), P.brass())
    E.cylinder("globe_post", 0.3, 6, (-W / 2 - 14, 16, 3.5), P.brass(), segs=12)
    E.sphere("star_globe", 5.0, (-W / 2 - 14, 16, 11), globe_m, subdiv=4)
    P.torus("globe_ring", 5.6, 0.2, (-W / 2 - 14, 16, 11), P.brass(), rot=(math.radians(70), 0, 0.4))
    # lantern
    lx, ly = 10.0, top + 18
    E.cylinder("lantern_base", 3.2, 1.2, (lx, ly, 0.6), P.brass(), segs=8, bevel=0.2)
    E.cylinder("lantern_glass", 2.8, 8, (lx, ly, 5.2), P.glass("Lantern glass", rough=0.08), segs=8)
    E.cylinder("lantern_roof", 3.4, 3, (lx, ly, 10.7), P.brass(), segs=8, r2=0.5)
    P.torus("lantern_ring", 1.0, 0.15, (lx, ly, 12.8), P.brass(), rot=(math.radians(90), 0, 0))
    P.candle(scene, lx, ly, 1.2, h=4, r=0.9, holder=False, energy=70)
    # balustrade + sky
    for i in range(-9, 10):
        E.cylinder("baluster", 1.6, 60, (i * 9, 95, -30), marble("Baluster marble"), segs=24, r2=1.2)
    E.cube("balustrade_top", (190, 6, 3), (0, 95, 1.5), marble("Rail marble"), bevel=0.4)
    sky_ob = E.plane("sky", 1200, 500, (0, 450, 100), sky())
    sky_ob.rotation_euler = (math.radians(90), 0, 0)
    E.light(scene, "AREA", "moon", (-40, 120, 90), 22000, color=(0.65, 0.7, 1.0), size=40, target=(0, 0, 0))
    E.light(scene, "AREA", "violet_rim", (40, 60, 20), 3500, color=(0.6, 0.35, 1.0), size=30, target=(0, 0, 3))
    E.light(scene, "AREA", "soft_front", (0, -60, 40), 1500, color=(0.85, 0.85, 1.0), size=40, target=(0, 0, 0))
    E.scatter("stardust", 160, ((-40, -30, 3), (40, 60, 40)), 0.04, E.emissive("Stardust", (0.8, 0.75, 1.0), 6.0),
              seed=31, scale_range=(0.3, 1.0))
    return dict(
        samples=128, exposure=0.3, hero=dict(dist=32, elev=30, az=8, lens=65, fstop=2.8),
        roll=dict(settled={"d12": ((-4.5, -7.0), 12, 20), "d6": ((5.5, -3.0), 6, -10), "d10t": ((-2.0, 4.0), 0, 30),
                           "d4": ((6.0, 9.0), 4, 0)},
                  airborne={"d20": ((0.5, -2.5, 3.0), (1.2, 2.5, 0.2)), "d8": ((-5.5, 7.0, 5.0), (2.0, -1.0, -0.5)),
                            "d10u": ((4.0, 14.0, 2.2), (-1.5, -2.0, 0.3))}),
    )
