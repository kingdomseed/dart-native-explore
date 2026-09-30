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
import room_common as RC
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
    col = k.ramp(grime, [(0.3, (0.4, 0.38, 0.35)), (0.7, (0.6, 0.57, 0.52))])
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
    k.link(k.math("ADD", k.math("MULTIPLY", n, 0.5), k.math("MULTIPLY", b, 1.5)), v.inputs["Emission Strength"])
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
    core = E.sphere("core", 2.4, (0, cy, cz), E.emissive("Core", TEAL, 2.5), subdiv=4)
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
    E.light(scene, "AREA", "key", (-48, -18, 40), 26000, color=(1.0, 0.72, 0.46), size=25, target=(0, 0, 0))
    E.overhead(scene, 9000, color=(1.0, 0.82, 0.6), size=90, height=110)
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
    rc = room(scene)
    return dict(
        samples=128, exposure=0.1, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=28, az=-6, lens=65, fstop=2.8),
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene):
    """The inventor's workshop (concept: room-concepts/fateengine-room).

    Brick walls run with copper pipes, big wall gears, a tall arched-top
    window onto a spired city at night, a workbench with bottle shelves on
    the left, and a glass tesla column with a teal coil on the right.
    Lights from four sides: an industrial pendant (warm key, above-left),
    the window (cool, back-right), the tesla column (teal accent, right) and
    a caged work lamp on the back wall (warm, back-left); plus the tray's key.
    """
    brick = RC.stone("Workshop brick", (0.09, 0.04, 0.025), (0.2, 0.1, 0.06), scale=0.05)
    RC.shell(half_w=190, back=150, front=-190, height=290, wall=brick, floor=RC.planks(),
             openings={"back": [(70, 70, 90, 170)]})
    wood = P.dark_wood("Workshop table")
    RC.work_table(220, 160, top_z=0.0, thick=6.0, mat=wood, leg_r=6, y=20, top=False)
    copper = P.brass("Workshop copper", worn=0.7, color=(0.8, 0.42, 0.28))
    brass = P.brass("Workshop brass", worn=0.5)
    iron = E.simple("Workshop iron", (0.04, 0.04, 0.045), 0.4, 0.9)
    city = RC.sky("Workshop city", (0.02, 0.03, 0.07), (0.1, 0.12, 0.2), stars=1.0, strength=0.7,
                  skyline=((0.012, 0.014, 0.025), 0.4))
    RC.window("back", 70, 70, 90, 170, city, iron, mullions=(3, 6), bar=1.2, glow=(40000, (0.55, 0.65, 1.0)))
    RC.pipes("back", -190, 20, (120, 150), r=5, mat=copper, drops=(-150, -40))
    RC.pipes("left", -190, 150, (160,), r=6, mat=copper, drops=(60,))
    RC.wall_gear("back", -95, 95, 38, 24, brass, thick=5)
    RC.wall_gear("back", -40, 140, 22, 16, copper, thick=4, off=12)
    RC.wall_gear("left", 90, 110, 45, 28, brass, thick=5)
    # workbench along the left wall with shelves of bottles and a vice
    E.cube("side_bench", (60, 170, 6), (-160, 40, -12), wood, bevel=0.5)
    for sy in (-1, 1):
        E.cube("side_bench_leg", (50, 6, 58), (-160, 40 + sy * 78, RC.FLOOR_Z + 29), wood)
    RC.wall_shelf("left", 40, 40, w=150, seed=11, kind="bottles",
                  palette=[(0.05, 0.25, 0.2), (0.3, 0.15, 0.05), (0.1, 0.1, 0.2), (0.25, 0.22, 0.1)])
    RC.wall_shelf("left", 40, 85, w=150, seed=12, kind="mixed",
                  palette=[(0.2, 0.12, 0.06), (0.12, 0.1, 0.08), (0.3, 0.2, 0.1)])
    # the tesla column: a glass cylinder with a teal coil on a brass base (right)
    tx, ty = 118, 105
    E.cylinder("tesla_base", 22, 20, (tx, ty, RC.FLOOR_Z + 10), brass, segs=32, bevel=1.0)
    E.cylinder("tesla_glass", 16, 150, (tx, ty, RC.FLOOR_Z + 95), P.glass("Tesla glass"), segs=32,
               cap=False).visible_shadow = False
    E.cylinder("tesla_cap", 20, 12, (tx, ty, RC.FLOOR_Z + 176), brass, segs=32, bevel=1.0)
    for i in range(18):  # coil turns: short tube segments around a helix
        a0, a1 = i * 0.9, (i + 1) * 0.9
        z0, z1 = RC.FLOOR_Z + 30 + i * 7.5, RC.FLOOR_Z + 30 + (i + 1) * 7.5
        RC.neon_bar(scene, (tx + 9 * math.cos(a0), ty + 9 * math.sin(a0), z0),
                    (tx + 9 * math.cos(a1), ty + 9 * math.sin(a1), z1), TEAL, strength=12.0, energy=0, r=0.8)
    E.light(scene, "POINT", "tesla_light", (tx, ty, RC.FLOOR_Z + 100), 25000, color=TEAL, size=12, shadow=False)
    # cogs, rolled plans and tools on the big table around the tray (beyond the phone frame)
    for i, (x, y, r) in enumerate(((-55, -20, 6), (-70, 10, 4), (60, -30, 5), (75, 50, 7))):
        P.gear(f"table_cog{i}", r, 10 + i * 2, 1.2, (x, y, 0.0), brass, hole=0)
    for i, (x, y) in enumerate(((-75, 60), (-60, 75))):
        E.cylinder("plan_roll", 3.0, 45, (x, y, 3.0), P.parchment(f"Plan roll {i}"), segs=24).rotation_euler = \
            (0, math.radians(90), 0.3 * i)
    # warm key: an industrial pendant above-left of the table, and a caged lamp on the back wall
    RC.pendant_lamp(scene, -45, -10, 80, energy=60000, color=(1.0, 0.72, 0.42), shade=(0.4, 0.28, 0.12), r=24,
                    spot_deg=95)
    RC.hanging_lantern(scene, -120, 130, 110, energy=40000, mat=iron)
    return dict(loc=(20, -82, 50), target=(4, 90, 0), lens=20, fstop=4.0, focus=(0, 0, 2))
