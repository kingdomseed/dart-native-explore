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
import room_common as RC

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
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=room(scene, lac),
    )


def room(scene, lac):
    """The lantern pavilion (concept: room-concepts/vermilion-room).

    A tatami room (the tray sits on the mats; floor z = 0) with lacquered
    posts, shoji walls glowing on the left, the gold-leaf folding screen
    behind the tray, and the back open onto a veranda railing over dusk
    mountains, a pagoda silhouette and a cherry tree. Lights from four
    sides: a paper andon floor lantern (warm, left), a big vermilion paper
    lantern (red accent, right), the dusk sky through the opening (cool
    violet, back) and the tray's warm key and overhead.
    """
    wood = P.dark_wood("Pavilion wood", c1=(0.03, 0.012, 0.008), c2=(0.1, 0.04, 0.02), varnish=0.7)
    red = E.simple("Vermilion lacquer", (0.45, 0.04, 0.02), 0.25, Coat_Weight=1.0)
    RC.shell(half_w=200, back=180, front=-200, height=230, wall=RC.plaster("Pavilion plaster", (0.35, 0.3, 0.24)),
             floor=False, floor_z=0.0, openings={"back": [(0, 105, 300, 190)]},
             ceiling=P.dark_wood("Pavilion ceiling", c1=(0.03, 0.015, 0.01), c2=(0.07, 0.035, 0.02)))
    dusk = RC.sky("Pavilion dusk", (0.08, 0.07, 0.2), (0.5, 0.3, 0.4), stars=0.8, strength=0.8,
                  skyline=((0.06, 0.05, 0.12), 0.35, False))
    RC.window("back", 0, 105, 300, 190, dusk, wood, mullions=(1, 1), sill=False, glow=(30000, (0.6, 0.55, 1.0)))
    # the veranda beyond: posts and a railing, a pagoda and a cherry tree against the sky
    for x in (-150, -50, 50, 150):
        E.cube("veranda_post", (12, 12, 230), (x, 230, 115), red, bevel=1.0)
    E.cube("veranda_rail", (320, 6, 5), (0, 230, 55), red, bevel=0.5)
    E.cube("veranda_rail_low", (320, 6, 4), (0, 230, 25), red, bevel=0.5)
    E.plane("veranda_deck", 360, 100, (0, 230, -0.5), wood)
    far = E.emissive("Pagoda silhouette", (0.05, 0.04, 0.09), 1.0)
    px, py = 90, 262
    for i, (wd, z) in enumerate(((46, 120), (38, 145), (30, 168), (22, 188))):
        E.cube("pagoda_body", (wd * 0.6, 8, 20), (px, py, z), far)
        E.cylinder("pagoda_roof", wd * 0.75, 7, (px, py, z + 12), far, segs=4, r2=wd * 0.25).rotation_euler = \
            (0, 0, math.radians(45))
    E.cylinder("pagoda_spire", 0.8, 25, (px, py, 210), far, segs=6)
    E.cube("pagoda_hill", (160, 8, 110), (px + 10, py + 2, 50), far)
    bark = E.simple("Cherry bark", (0.03, 0.02, 0.02), 0.8)
    blossom = E.simple("Blossom", (0.95, 0.6, 0.7), 0.6, Subsurface_Weight=0.4, Emission_Color=(1.0, 0.6, 0.7, 1),
                       Emission_Strength=0.15)
    tr = E.cylinder("cherry_trunk", 6, 200, (-110, 250, 100), bark, segs=12, r2=3)
    tr.rotation_euler = (0, math.radians(8), 0)
    rng = random.Random(12)
    for i in range(22):
        E.rock(f"blossom{i}", rng.uniform(12, 22), (-110 + rng.uniform(-70, 60), 250 + rng.uniform(-10, 15),
                                                    rng.uniform(150, 230)), blossom, seed=300 + i,
               squash=(1.2, 0.8, 0.8), strength=0.4, subdiv=3)
    # lacquered posts at the corners of the room, a lintel over the opening
    for x in (-160, 160):
        E.cube("post", (14, 14, 230), (x, 170, 115), wood, bevel=1.0)
    # shoji along the left wall, glowing
    for u in (-140, -60, 20, 100):
        RC.shoji("left", u, 78, 190, wood, glow=0.35)
    # a tansu chest on the right wall, cushions on the mats
    RC.cabinet("right", 60, w=110, h=70, depth=45, mat=wood, top_mat=red, doors=3)
    cush = E.simple("Zabuton", (0.05, 0.05, 0.14), 0.8, Sheen_Weight=0.8)
    for x, y in ((-70, -10), (70, -30)):
        E.cube("zabuton", (55, 55, 9), (x, y, 4.5), cush, bevel=3.5)
    # the andon: a paper floor lantern on the left (warm)
    ax, ay = -110, 70
    for sx in (-1, 1):
        for sy in (-1, 1):
            E.cube("andon_leg", (2.5, 2.5, 70), (ax + sx * 12, ay + sy * 12, 35), wood)
    E.cube("andon_paper", (23, 23, 45), (ax, ay, 45), E.simple("Andon paper", (0.9, 0.8, 0.6), 0.9,
           Emission_Color=(1.0, 0.72, 0.4, 1), Emission_Strength=2.0)).visible_shadow = False
    E.light(scene, "POINT", "andon_light", (ax, ay, 45), 9000, color=(1.0, 0.7, 0.4), size=10)
    # a big vermilion paper lantern hung on the right (the red accent)
    RC.paper_lantern(scene, 120, 40, 130, r=26, color=(1.0, 0.18, 0.06), energy=14000,
                     light_color=(1.0, 0.35, 0.15))
    return dict(loc=(-12, -78, 48), target=(8, 120, 8), lens=20, fstop=4.0, focus=(0, 0, 2))
