"""Vermilion Court environment: "Lantern Pavilion".

A black-lacquer shrine tray with a fine gold-dust wave pattern and gilt
rim, set on tatami inside a pavilion at night. Paper lanterns glow at the
corners, a folding screen with gold-leaf panels stands behind, and a few
petals drift down through incense haze. Ties to the M18 diorama palette.
"""
from __future__ import annotations

import math
import random

import env_common as E
import env_props as P

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.2, 2.4


def lacquer_floor():
    m, k = E.material("Black lacquer + gold dust")
    obj = k.coords().outputs["Object"]
    wave = k.node("ShaderNodeTexWave", wave_type="RINGS", rings_direction="SPHERICAL")
    k.link(obj, wave.inputs["Vector"])
    k.set(wave, Scale=0.12, Distortion=1.5, Detail=2.0)
    band = k.math("LESS_THAN", k.math("ABSOLUTE", k.math("SUBTRACT", wave.outputs["Fac"], 0.5)), 0.03)
    dust = k.math("LESS_THAN", k.voronoi(obj, 6.0).outputs["Distance"], 0.05)
    gold_amt = k.math("MAXIMUM", k.math("MULTIPLY", band, 0.8), k.math("MULTIPLY", dust, 0.5))
    # coat a little softer than round 1 so the lanterns don't mirror as big
    # white discs in the play area at top-down
    lac = k.bsdf(Base_Color=(0.006, 0.004, 0.004, 1), Roughness=0.5, Coat_Weight=0.5, Coat_Roughness=0.35)
    gold = k.bsdf(Base_Color=(1.0, 0.75, 0.32, 1), Metallic=1.0, Roughness=0.3)
    k.surface(k.mix_shader(gold_amt, lac, gold))
    return m


def tatami():
    m, k = E.material("Tatami")
    obj = k.coords().outputs["Object"]
    wv = k.node("ShaderNodeTexWave", bands_direction="X")
    k.link(obj, wv.inputs["Vector"])
    k.set(wv, Scale=2.5, Distortion=0.3)
    border = E.grid_lines(k, obj, 45.0, 3.0)
    col = k.mix(k.math("MULTIPLY", wv.outputs["Fac"], 0.5), (0.5, 0.45, 0.25, 1), (0.35, 0.3, 0.15, 1))
    col = k.mix(border, col, (0.03, 0.05, 0.03, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.75, Normal=k.bump(wv.outputs["Fac"], 0.3, 0.1)))
    return m


def lantern(scene, x, y, z, h=16.0, r=5.0):
    paper, k = E.material("Lantern paper")
    obj = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    ribs = k.math("GREATER_THAN", k.math("ABSOLUTE", k.math("SINE", k.math("MULTIPLY", sep.outputs["Z"], 3.0))),
                  0.96)
    glow = k.emission((1.0, 0.55, 0.25, 1), k.math("SUBTRACT", 3.0, k.math("MULTIPLY", ribs, 2.8)))
    trans = k.bsdf(Base_Color=(0.9, 0.5, 0.3, 1), Roughness=0.8, Transmission_Weight=0.3)
    k.surface(k.add_shader(trans, glow))
    E.sphere("lantern", 1.0, (x, y, z + h / 2 + 3), paper, subdiv=4, scale=(r, r, h / 2))
    lac = E.simple("Lantern lacquer", (0.02, 0.01, 0.01), 0.25, Coat_Weight=1.0)
    E.cylinder("lantern_top", r * 0.55, 1.2, (x, y, z + h + 3), lac, segs=32)
    E.cylinder("lantern_bottom", r * 0.55, 1.2, (x, y, z + 3), lac, segs=32)
    E.cylinder("lantern_post", 0.4, 3, (x, y, z + 1.5), lac, segs=12)
    E.light(scene, "POINT", "lantern_light", (x, y, z + h / 2 + 3), 1500, color=(1.0, 0.55, 0.25), size=r * 0.8)


def build(scene):
    E.world(scene, color=(0.006, 0.004, 0.006), strength=1.0)
    E.plane("tatami", 400, 400, (0, 0, -0.01), tatami())
    E.plane("tray_floor", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 1.21), lacquer_floor())
    lac = E.simple("Tray lacquer", (0.008, 0.005, 0.005), 0.2, Coat_Weight=1.0, Coat_Roughness=0.01)
    E.cube("tray_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 1.2), (0, 0, 0.6), lac, bevel=0.3)
    E.rim("rim", W + RIM_T, D + RIM_T, 1.5, RIM_H, RIM_T, lac, z0=1.2)
    E.rim("rim_gilt", W + RIM_T, D + RIM_T, 1.5, 0.3, 0.5, P.brass("Gilt", worn=0.1, color=(1.0, 0.78, 0.35)),
          z0=RIM_H + 1.25)
    top = D / 2 + RIM_T
    lantern(scene, -W / 2 - 12, top + 6, 0)
    lantern(scene, W / 2 + 12, top + 2, 0, h=12, r=4.0)
    lantern(scene, W / 2 + 16, -D / 2 - 2, 0, h=10, r=3.5)
    # folding screen with gold-leaf panels + painted waves (procedural)
    screen, k = E.material("Screen gold leaf")
    obj = k.coords().outputs["Object"]
    leaf = k.voronoi(obj, 0.18).outputs["Color"]
    wave = k.node("ShaderNodeTexWave", bands_direction="Z")
    k.link(obj, wave.inputs["Vector"])
    k.set(wave, Scale=0.06, Distortion=6.0, Detail=3.0)
    ink = k.math("LESS_THAN", k.math("ABSOLUTE", k.math("SUBTRACT", wave.outputs["Fac"], 0.5)), 0.04)
    gold = k.bsdf(Base_Color=k.mix(0.15, (1.0, 0.75, 0.35, 1), leaf), Metallic=1.0, Roughness=0.35)
    k.surface(k.mix_shader(ink, gold, k.bsdf(Base_Color=(0.02, 0.05, 0.1, 1), Roughness=0.6)))
    for i in range(6):
        p = E.cube("screen_panel", (22, 1.0, 60), (-55 + i * 22, top + 45 + (i % 2) * 5, 30), screen)
        p.rotation_euler = (0, 0, 0.22 if i % 2 else -0.22)
    # low table edge + tea cup
    E.cylinder("tea_cup", 3.0, 5.5, (-W / 2 - 10, -8, 2.75), E.simple("Celadon", (0.45, 0.6, 0.5), 0.2,
                                                                       Coat_Weight=1.0), segs=40, r2=3.8)
    E.cylinder("tea", 2.9, 0.1, (-W / 2 - 10, -8, 5.1), E.simple("Green tea", (0.2, 0.3, 0.05), 0.05))
    # petals + incense haze
    petal = E.simple("Petal", (0.95, 0.55, 0.62), 0.5, Subsurface_Weight=0.5)
    E.scatter("petals", 90, ((-40, -40, 0.2), (40, 60, 45)), 0.45, petal, seed=19, scale_range=(0.6, 1.0),
              avoid=lambda p: abs(p.x) < W / 2 + 4 and abs(p.y) < D / 2 + 6)
    E.haze_box("incense", (160, 180, 70), (0, 20, 34), 0.005, color=(1.0, 0.85, 0.8), noise_scale=0.04)
    # moon: unshadowed (round 1: the folding screen shadowed half the tray)
    E.light(scene, "AREA", "moon", (40, 60, 80), 2500, color=(0.55, 0.6, 1.0), size=40, target=(0, 0, 0),
            shadow=False)
    # key from the side: its mirror image in the lacquer lands off the tray
    E.light(scene, "AREA", "key", (-46, -12, 36), 16000, color=(1.0, 0.75, 0.55), size=25, target=(0, 0, 0))
    # Round 2: soft warm overhead (a paper ceiling lamp) for the gold leaf,
    # which mirrors the ceiling when seen straight down.
    E.overhead(scene, 1500, color=(1.0, 0.82, 0.62), size=90, height=110)
    # Top-down framing: a folding fan, a tea cup on its saucer and fallen
    # petals in the strips above and below the tray.
    bot = -D / 2 - RIM_T
    fan_m = E.simple("Fan paper", (0.85, 0.12, 0.08), 0.6)
    rib_m = E.simple("Fan ribs", (0.12, 0.07, 0.04), 0.5, Coat_Weight=0.8)
    fx, fy = -3.0, bot - 4.6
    for i in range(9):
        a = math.radians(-50 + i * 12.5)
        seg = E.cube("fan_leaf", (1.6, 9.0, 0.08), (fx + math.sin(a) * 4.5, fy + math.cos(a) * 4.5, 0.2 + 0.01 * i),
                     fan_m if i % 2 == 0 else E.simple("Fan gold", (0.95, 0.72, 0.3), 0.35, 0.8))
        seg.rotation_euler = (0, 0, -a)
        rib = E.cube("fan_rib", (0.2, 9.4, 0.1), (fx + math.sin(a) * 4.7, fy + math.cos(a) * 4.7, 0.3), rib_m)
        rib.rotation_euler = (0, 0, -a)
    E.cylinder("saucer", 5.2, 0.5, (W / 2 + 2.0, top + 4.2, 0.25), E.simple("Saucer lacquer", (0.02, 0.01, 0.01), 0.2,
                                                                            Coat_Weight=1.0), segs=48)
    E.cylinder("tea_cup_top", 3.0, 4.5, (W / 2 + 2.0, top + 4.2, 2.75), E.simple("Celadon top", (0.45, 0.6, 0.5), 0.2,
                                                                                Coat_Weight=1.0), segs=40, r2=3.6)
    E.cylinder("tea_top", 3.45, 0.1, (W / 2 + 2.0, top + 4.2, 4.6), E.simple("Green tea top", (0.2, 0.3, 0.05), 0.05))
    rng = random.Random(4)
    for i in range(22):
        x = rng.uniform(-W / 2 - 3, W / 2 + 3)
        y = rng.choice((rng.uniform(top + 0.5, top + 6), rng.uniform(bot - 6, bot - 0.5)))
        pt = E.sphere("fallen_petal", 1.0, (x, y, 0.08), petal, subdiv=2, scale=(0.5, 0.32, 0.04))
        pt.rotation_euler = (0, 0, rng.uniform(0, 6.28))
    return dict(
        samples=128, exposure=1.3, topdown=dict(width=W + 2 * RIM_T + 1.0), surface_z=1.2, centre=(0, 2.0, 2.2),
        hero=dict(dist=32, elev=30, az=8, lens=65, fstop=2.8),
    )
