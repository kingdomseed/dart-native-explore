"""Fate Engine environment: the machine *is* the environment.

A brass dice engine stands at the head of the tray: twin glass charge
tubes full of teal light, a gyroscopic cradle with a glowing core, gear
trains, a pull lever and riveted plating. The rolling area is its output
tray: a dark steel plate engraved with a gear-and-orbit pattern whose
grooves carry a faint teal charge, walled by a riveted brass rail.
"""
from __future__ import annotations

import math
import random

import env_common as E
import env_props as P
from build_dice import _circle

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.2, 3.0
TEAL = (0.1, 1.0, 0.85)


def plate_strokes(w=0.004):
    s = []
    for r in (0.47, 0.44, 0.3, 0.12):
        s.append(([P.ring(r)], w, True))
    teeth = 36
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        r = 0.41 if (i % 4) in (1, 2) else 0.385
        pts.append((0.5 + r * math.cos(a), 0.5 + r * math.sin(a)))
    s.append(([pts], w * 1.2, True))
    for i in range(6):
        a = 2 * math.pi * i / 6
        s.append(([[(0.5 + 0.12 * math.cos(a), 0.5 + 0.12 * math.sin(a)),
                    (0.5 + 0.3 * math.cos(a), 0.5 + 0.3 * math.sin(a))]], w * 1.5, False))
    for i in range(3):  # orbits with 'planets'
        a = 0.6 + i * 2.1
        r = 0.2 + i * 0.03
        s.append(([_circle(0.5 + r * math.cos(a), 0.5 + r * math.sin(a), 0.018, 16)], w, True))
    for i in range(72):
        a = 2 * math.pi * i / 72
        s.append(([[(0.5 + 0.44 * math.cos(a), 0.5 + 0.44 * math.sin(a)),
                    (0.5 + 0.47 * math.cos(a), 0.5 + 0.47 * math.sin(a))]], w * 0.7, False))
    # long channels running to the machine
    for x in (0.3, 0.7):
        s.append(([[(x, 0.9), (x, 1.02)]], w * 1.6, False))
    return s


def steel_plate(mask, size):
    m, k = E.material("Engine plate")
    obj = k.coords().outputs["Object"]
    brush = k.node("ShaderNodeMapping")
    brush.inputs["Scale"].default_value = (1.0, 25.0, 1.0)
    k.link(obj, brush.inputs["Vector"])
    streak = k.noise(brush.outputs[0], 3.0, 3).outputs["Fac"]
    grime = k.noise(obj, 0.3, 8, 0.6).outputs["Fac"]
    sm = k.node("ShaderNodeMapping")
    sm.inputs["Scale"].default_value = (1 / size, 1 / size, 1)
    sm.inputs["Location"].default_value = (0.5, 0.5, 0)
    k.link(obj, sm.inputs["Vector"])
    tex = k.node("ShaderNodeTexImage", image=mask, extension="CLIP", interpolation="Cubic")
    k.link(sm.outputs[0], tex.inputs["Vector"])
    g = tex.outputs["Color"]
    nrm = k.bump(streak, 0.08, 0.02)
    nrm = k.bump(g, 0.8, 0.12, normal=nrm, invert=True)
    # Round 2: bright brushed steel with the pattern inlaid in brass (round
    # 1's dark plate + teal grooves read green and swallowed the dice); the
    # grooves keep only a whisper of charge.
    col = k.ramp(grime, [(0.3, (0.36, 0.36, 0.35)), (0.7, (0.55, 0.54, 0.52))])
    steel = k.bsdf(Base_Color=col, Metallic=0.65, Roughness=k.math("ADD", k.math("MULTIPLY", streak, 0.15), 0.42),
                   Normal=nrm)
    inlay = k.bsdf(Base_Color=(0.9, 0.64, 0.28, 1), Metallic=1.0, Roughness=0.3, Normal=nrm,
                   Emission_Color=(*TEAL, 1), Emission_Strength=0.12)
    k.surface(k.mix_shader(g, steel, inlay))
    return m


def charge_fluid():
    m, k = E.material("Charge fluid")
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.5, 4, 0.5, dims="4D", w=2.0).outputs["Fac"]
    bub = k.voronoi(obj, 1.2)
    b = k.math("LESS_THAN", bub.outputs["Distance"], 0.12)
    v = k.node("ShaderNodeVolumePrincipled")
    k.set(v, Density=0.15, Color=(0.6, 1.0, 0.95, 1), Emission_Color=(*TEAL, 1))
    k.link(k.math("ADD", k.math("MULTIPLY", n, 1.2), k.math("MULTIPLY", b, 3.5)), v.inputs["Emission Strength"])
    k.volume(v.outputs[0])
    return m


def build(scene):
    E.world(scene, color=(0.004, 0.006, 0.008), strength=1.0)
    mask = P.mask_texture("engine_plate", plate_strokes(), E.TMP, res=4096)
    brass = P.brass("Engine brass", worn=0.55)
    dark_brass = P.brass("Engine dark brass", worn=0.9, color=(0.55, 0.38, 0.18))
    E.cube("table", (220, 160, 6), (0, 20, -3.0), P.dark_wood("Workshop table"), bevel=0.5)
    E.plane("plate", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.31), steel_plate(mask, W * 0.98))
    E.cube("plate_base", (W + 2 * RIM_T + 1.4, D + 2 * RIM_T + 1.4, 0.6), (0, 0, 0.0), dark_brass, bevel=0.2)
    E.rim("rail", W + RIM_T, D + RIM_T, 3.5, RIM_H, RIM_T, brass, z0=0.3)
    rv = P.brass("Rivet", worn=0.8)
    for i, (x, y) in enumerate(E.rounded_rect(W + RIM_T, D + RIM_T, 3.5, seg=2)):
        E.sphere(f"rivet{i}", 0.3, (x, y, RIM_H + 0.3), rv, subdiv=2, scale=(1, 1, 0.6))
    for t in range(-4, 5):
        for sx in (-1, 1):
            E.sphere("rail_rivet", 0.22, (sx * (W / 2 + RIM_T + 0.1), t * D / 9.5, RIM_H * 0.55), rv, subdiv=2)

    # The machine at the head of the tray.
    top = D / 2 + RIM_T
    cy = top + 18
    E.cylinder("engine_plinth", 17, 5, (0, cy, 2.5), dark_brass, segs=64, bevel=0.5)
    E.cylinder("engine_plinth_ring", 17.4, 1.0, (0, cy, 5.2), brass, segs=64, bevel=0.3)
    E.cylinder("engine_deck", 13, 2.5, (0, cy, 6.6), brass, segs=64, bevel=0.3)
    fluid = charge_fluid()
    glass = P.glass("Tube glass")
    for sx in (-1, 1):
        x = sx * 11.5
        E.cylinder("tube_foot", 3.4, 2.5, (x, cy, 9.0), brass, segs=40, bevel=0.3)
        E.cylinder("tube_glass", 2.8, 20, (x, cy, 20.3), glass, segs=48, cap=True)
        E.cylinder("tube_fluid", 2.5, 18.5, (x, cy, 20.3), fluid, segs=32)
        E.cylinder("tube_cap", 3.4, 2.5, (x, cy, 31.5), brass, segs=40, bevel=0.3)
        for zz in (13, 20, 27):
            P.torus("tube_band", 2.95, 0.18, (x, cy, zz), brass, minor_seg=8)
        E.light(scene, "POINT", "tube_light", (x, cy - 3.2, 20), 120, color=TEAL, size=2.5)
    # gyroscopic cradle with a glowing core
    cz = 21.0
    P.torus("cradle_outer", 8.0, 0.55, (0, cy, cz), brass, rot=(math.radians(90), 0, 0))
    P.torus("cradle_mid", 6.6, 0.4, (0, cy, cz), dark_brass, rot=(math.radians(90), 0, math.radians(90)))
    P.torus("cradle_inner", 5.4, 0.35, (0, cy, cz), brass, rot=(math.radians(35), math.radians(20), 0))
    core = E.sphere("core", 2.4, (0, cy, cz), E.emissive("Core", TEAL, 5.0), subdiv=4)
    E.sphere("core_glass", 3.4, (0, cy, cz), glass, subdiv=4)
    E.light(scene, "POINT", "core_light", (0, cy - 3, cz), 200, color=TEAL, size=3.0)
    for sx in (-1, 1):
        post = E.cylinder("cradle_post", 0.7, 15, (sx * 8.0, cy, 14.0), brass, segs=16)
    E.cylinder("crown", 12.5, 2.2, (0, cy, 33.5), brass, segs=64, bevel=0.3)
    E.cylinder("crown_top", 9, 3, (0, cy, 36.0), dark_brass, segs=64, r2=6.0, bevel=0.3)
    E.cube("nameplate", (16, 1.0, 4.5), (0, cy - 12.6, 37.5), brass, bevel=0.3)  # left blank: no slogans
    # gear trains
    rng = random.Random(4)
    for i, (x, z, r, t) in enumerate(((-14, 12, 4.5, 24), (-15.5, 19.5, 3.0, 16), (14.5, 11, 5.0, 28),
                                      (16.0, 19.0, 3.2, 18), (13.0, 26, 2.4, 14))):
        P.gear(f"gear{i}", r, t, 1.0, (x, cy - 3 + rng.uniform(-0.5, 0.5), z), brass if i % 2 else dark_brass,
               rot=(math.radians(90), rng.uniform(0, 1), 0))
    # lever
    lever = E.cylinder("lever", 0.5, 18, (24, cy - 1, 18), brass, segs=16)
    lever.rotation_euler = (0, math.radians(-25), 0)
    E.sphere("lever_knob", 1.6, (27.8, cy - 1, 26.2), P.dark_wood("Knob wood"), subdiv=3, scale=(1, 1, 1.6))
    # output chute into the tray
    E.cube("chute", (10, 7, 1.2), (0, top + 1.5, 3.6), brass, bevel=0.3).rotation_euler = (math.radians(-18), 0, 0)

    # Workshop props framing the sides.
    P.hourglass(W / 2 + 10, 8, 0.0, h=13, sand=TEAL, glow=1.5)
    P.book_stack(-W / 2 - 16, 16, 0.0, 5, seed=5)
    P.candle(scene, -W / 2 - 10, top + 2, 0.0, h=11, seed=6, energy=45)
    P.paper(-W / 2 - 13, -12, 0.0, 22, 28, rot=0.2, curl=0.7, seed=7)
    P.paper(W / 2 + 14, -14, 0.0, 20, 26, rot=-0.3, curl=0.7, seed=8)
    for i, sx in enumerate((0, 1)):  # calipers
        arm = E.cylinder("caliper", 0.22, 16, (-W / 2 - 9 + i * 1.2, -D / 2 + 6, 0.35), brass, segs=8)
        arm.rotation_euler = (math.radians(90), 0, math.radians(8 - i * 16))
    E.cylinder("caliper_hinge", 0.8, 0.8, (-W / 2 - 8.4, -D / 2 + 13.8, 0.4), brass, segs=20)
    P.armillary(W / 2 + 22, top + 6, 0.0, R=5.0)

    # Light: warm workshop key, teal machine glow, cool rim.
    # side key: its mirror image in the steel plate lands off the tray
    E.light(scene, "AREA", "key", (-48, -18, 40), 14000, color=(1.0, 0.78, 0.55), size=25, target=(0, 0, 0))
    E.overhead(scene, 6000, color=(1.0, 0.88, 0.7), size=90, height=110)
    # Top-down framing: loose gears, screws and a schematic in the strips.
    bot = -D / 2 - RIM_T
    P.paper(3.0, bot - 4.0, 0.0, 18, 8, rot=0.05, curl=0.2, seed=31)
    for i, (x, y, r, t) in enumerate(((-5.5, bot - 3.0, 2.4, 14), (-2.2, bot - 5.0, 1.5, 10), (8.8, bot - 3.4, 1.8, 12))):
        P.gear(f"loose_gear{i}", r, t, 0.5, (x, y, 0.25), brass if i % 2 else dark_brass)
    screw_m = E.simple("Screw steel", (0.6, 0.6, 0.62), 0.3, 1.0)
    rng2 = random.Random(9)
    for i in range(9):
        E.cylinder("screw", 0.18, 1.2, (rng2.uniform(-7, 7), bot - rng2.uniform(1.0, 5.5), 0.18), screw_m,
                   segs=8).rotation_euler = (math.radians(90), 0, rng2.uniform(0, 3.1))
    E.light(scene, "AREA", "rim", (20, 70, 40), 3000, color=(0.5, 0.7, 1.0), size=30, target=(0, 0, 5))
    E.light(scene, "AREA", "tray_teal", (0, top - 4, 12), 10, color=TEAL, size=12, target=(0, 0, 0))
    E.scatter("motes", 120, ((-35, -25, 3), (35, 50, 40)), 0.05, E.emissive("Mote", (1.0, 0.9, 0.7), 3.0),
              seed=21, scale_range=(0.3, 1.0), avoid=lambda p: abs(p.x) < W / 2 + 6 and abs(p.y) < D / 2 + 10)
    E.haze_box("haze", (160, 180, 70), (0, 20, 34), 0.004, color=(0.85, 1.0, 0.95), noise_scale=0.03)
    return dict(
        samples=128, exposure=0.1, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=28, az=-6, lens=65, fstop=2.8),
    )
