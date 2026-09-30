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
import room_common as RC
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
    E.plane("disc_field", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.31), lapis)
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
              seed=31, scale_range=(0.3, 1.0), avoid=lambda p: abs(p.x) < W / 2 + 6 and abs(p.y) < D / 2 + 10)
    E.overhead(scene, 2500, color=(0.85, 0.85, 1.0), size=90, height=110)  # silver frames read top-down
    # Top-down framing: a star chart, a silver compass and loose amethyst.
    bot = -D / 2 - RIM_T
    chart_m, k = E.material("Star chart")
    o2 = k.coords().outputs["Object"]
    st2 = k.math("LESS_THAN", k.voronoi(o2, 0.9).outputs["Distance"], 0.05)
    k.surface(k.bsdf(Base_Color=k.mix(st2, (0.05, 0.07, 0.2, 1), (0.9, 0.85, 0.6, 1)), Roughness=0.8))
    P.paper(-2.0, top + 4.0, 0.0, 17, 8, rot=-0.05, mat=chart_m, curl=0.25, seed=41)
    silver = E.simple("Compass silver", (0.88, 0.9, 0.95), 0.2, 1.0)
    P.torus("compass_ring", 2.6, 0.25, (W / 2 - 1.5, bot - 3.3, 0.25), silver)
    E.cylinder("compass_face", 2.4, 0.2, (W / 2 - 1.5, bot - 3.3, 0.15), E.simple("Compass face", (0.05, 0.06, 0.18),
                                                                                  0.3), segs=48)
    ndl = E.cube("compass_needle", (0.3, 4.0, 0.1), (W / 2 - 1.5, bot - 3.3, 0.35), silver)
    ndl.rotation_euler = (0, 0, 0.5)
    crystal_cluster(-W / 2 + 2.0, bot - 3.0, 0, 3, 17, am, 0.3)
    rc = room(scene, am)
    return dict(
        samples=128, exposure=0.3, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=30, az=8, lens=65, fstop=2.8),
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene, am):
    """The observatory loggia (concept: room-concepts/celestial-room).

    An open marble arcade on the star balcony: columns and a lintel frame the
    nebula sky over the balustrade, marble side walls with deep-violet
    hangings, a brass telescope on its tripod, a great floor armillary and
    an amethyst geode. Lights from four sides: the moon (cool, back-left),
    a brass lantern hung on the left (warm), the amethyst glow (violet,
    right) and two sconces on the side walls; plus the tray's soft front.
    """
    mar = marble("Loggia marble")
    RC.shell(half_w=200, back=95, front=-200, height=320, wall=mar, floor=marble("Loggia floor"), floor_z=-60.0,
             back_wall=False)
    RC.work_table(180, 140, top_z=-6.0, thick=0.1, mat=mar, leg_r=7, y=20, top=False)
    # the arcade: columns at the balustrade and a lintel under the open sky
    for x in (-190, -95, 95, 190):
        RC.column(x, 100, 320, 14, mar)
    E.cube("arcade_lintel", (420, 30, 30), (0, 100, RC.FLOOR_Z + 305), mar, bevel=1.5)
    # violet hangings on the side walls
    for side, u in (("left", -20), ("right", -20), ("left", -130), ("right", -130)):
        RC.banner(side, u, 230, w=55, h=180, color=(0.08, 0.02, 0.14), trim=(0.6, 0.48, 0.25), pattern=True)
    brass = P.brass("Observatory brass", worn=0.35)
    # a brass telescope on a tripod, back-left, aimed at the sky
    tx, ty = -125, 55
    for i in range(3):
        a = math.radians(120 * i + 20)
        leg = E.cylinder("tripod_leg", 1.4, 120, (tx + math.cos(a) * 18, ty + math.sin(a) * 18, RC.FLOOR_Z + 58),
                         P.dark_wood("Tripod wood"), segs=10)
        leg.rotation_euler = (-math.sin(a) * 0.3, math.cos(a) * 0.3, 0)
    tube = E.cylinder("telescope", 6, 110, (tx + 12, ty + 25, RC.FLOOR_Z + 135), brass, segs=32, r2=4.5)
    tube.rotation_euler = (math.radians(-60), 0, math.radians(-25))
    # a great floor armillary on the right
    P.armillary(125, 40, RC.FLOOR_Z, R=38.0, mat=brass)
    # an amethyst geode with its violet glow (right, front of the armillary)
    import build_env_frostbound as F
    F.crystal_cluster(110, -30, RC.FLOOR_Z + 0.5, 11, 31, am, 3.2)
    E.light(scene, "POINT", "geode_glow", (110, -30, RC.FLOOR_Z + 40), 30000, color=(0.65, 0.3, 1.0), size=15,
            shadow=False)
    # a warm lantern hung on the left and sconces on the side walls
    RC.hanging_lantern(scene, -80, -20, 70, energy=35000, mat=brass, glass_color=(1.0, 0.75, 0.45))
    for side in ("left", "right"):
        RC.sconce(scene, side, 40, 120, energy=9000)
    return dict(loc=(16, -80, 48), target=(0, 120, 20), lens=20, fstop=4.0, focus=(0, 0, 2))
