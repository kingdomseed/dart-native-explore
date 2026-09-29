"""Old Road environment: "The Wayfarer's Table".

A weathered inn table at dusk. The rolling surface is a hand-inked travel
map (an invented land) stretched inside a stitched leather rim. A tin
lantern, a clay pipe, a leather satchel strap, a few coins and a heel of
bread frame it; warm lantern light against the blue hour in the window.
"""
from __future__ import annotations

import math

import env_common as E
import env_props as P

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.4, 2.6


def leather(name="Saddle leather", color=(0.2, 0.08, 0.03)):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 2.0, 8, 0.6).outputs["Fac"]
    pores = k.voronoi(obj, 12.0).outputs["Distance"]
    col = k.mix(k.math("MULTIPLY", n, 0.6), (*color, 1), (0.05, 0.02, 0.01, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=k.math("ADD", k.math("MULTIPLY", n, 0.3), 0.4),
                     Normal=k.bump(pores, 0.15, 0.05), Coat_Weight=0.2, Coat_Roughness=0.3))
    return m


def build(scene):
    # a warm, dim room (not black): worn gold mirrors its surroundings, and
    # straight down most faces of a die see the room, not the ceiling
    E.world(scene, color=(0.1, 0.075, 0.05), strength=1.0)
    table = P.dark_wood("Inn table", c1=(0.05, 0.03, 0.015), c2=(0.18, 0.1, 0.05), rough=0.75, varnish=0.0)
    E.cube("table", (200, 150, 6), (0, 20, -3.0), table, bevel=0.5)
    E.plane("map", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.36), P.parchment("Travel map", tone=((0.08, 0.05, 0.022), (0.16, 0.1, 0.05), (0.2, 0.14, 0.07))), subdiv=1)
    E.cube("map_board", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.7), (0, 0, 0), leather("Board leather",
                                                                                    (0.1, 0.04, 0.02)), bevel=0.3)
    E.rim("rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, leather(), z0=0.35)
    top = D / 2 + RIM_T
    # tin lantern
    lx, ly = -12.0, top + 12
    iron = E.simple("Lantern tin", (0.08, 0.075, 0.07), 0.5, 1.0)
    E.cylinder("lantern_base", 4.0, 1.5, (lx, ly, 0.75), iron, segs=6, bevel=0.2)
    E.cylinder("lantern_glass", 3.5, 11, (lx, ly, 7.0), P.glass("Lantern glass", rough=0.12), segs=6)
    for i in range(6):
        a = 2 * math.pi * i / 6
        E.cylinder("lantern_bar", 0.2, 11, (lx + 3.6 * math.cos(a), ly + 3.6 * math.sin(a), 7.0), iron, segs=6)
    E.cylinder("lantern_roof", 4.4, 4, (lx, ly, 14.5), iron, segs=6, r2=0.6)
    P.torus("lantern_handle", 2.2, 0.2, (lx, ly, 17.5), iron, rot=(math.radians(90), 0, 0))
    P.candle(scene, lx, ly, 1.5, h=5, r=1.0, holder=False, energy=140)
    # clay pipe
    clay = E.simple("Clay pipe", (0.22, 0.12, 0.07), 0.45, Coat_Weight=0.3)
    px, py = W / 2 - 1.0, top + 3.4  # top-right strip of the phone frame
    E.cylinder("pipe_bowl", 1.1, 2.6, (px, py, 1.6), clay, segs=24, r2=1.3)
    stem = E.cylinder("pipe_stem", 0.3, 14, (px - 6.5, py + 1.0, 0.6), clay, segs=10)
    stem.rotation_euler = (0, math.radians(86), math.radians(172))
    # satchel strap + buckle
    strap = E.plane("strap", 4, 70, (W / 2 + 16, 10, 0.2), leather("Strap"), subdiv=30)
    strap.rotation_euler = (0, 0, 0.25)
    sol = strap.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.4
    P.torus("buckle", 2.2, 0.25, (W / 2 + 15.5, 2, 0.6), P.brass("Buckle brass", worn=0.8), minor_seg=8)
    E.rock("satchel", 12, (W / 2 + 24, top + 8, 6), leather("Satchel", (0.16, 0.07, 0.03)), seed=3,
           squash=(1.2, 0.8, 0.7), strength=0.12)
    bot = -D / 2 - RIM_T
    for i, (x, y) in enumerate(((-W / 2 + 1.5, bot - 3.0), (-W / 2 + 4.2, bot - 4.2), (-W / 2 + 2.6, bot - 5.6),
                                (W / 2 - 3.0, bot - 3.6))):
        P.coin(x, y, 0.0, r=1.4, tilt=(0.03 * i, -0.02 * i))
    E.rock("bread", 5.5, (-W / 2 - 13, 6, 3), E.simple("Bread crust", (0.35, 0.16, 0.05), 0.7), seed=6,
           squash=(1.3, 0.9, 0.7), strength=0.1)
    E.cylinder("mug", 3.8, 10, (-W / 2 - 12, top - 4, 5), P.dark_wood("Mug wood"), segs=32, bevel=0.3)
    P.backdrop_window(0, top + 75, 45, 70, 80, sky_top=(0.03, 0.06, 0.18), sky_bot=(0.25, 0.2, 0.3), moon=False)
    E.light(scene, "AREA", "blue_hour", (0, top + 70, 50), 9000, color=(0.5, 0.6, 1.0), size=50, target=(0, 0, 0))
    # side key (its reflection in the gold lands off the tray) + a soft warm
    # overhead: worn gold seen straight down mirrors whatever is above it
    E.light(scene, "AREA", "warm_key", (-44, -16, 38), 12000, color=(1.0, 0.75, 0.5), size=20, target=(0, 0, 0))
    E.overhead(scene, 20000, color=(1.0, 0.85, 0.65), size=90, height=110)
    E.cube("dagger_sheath", (1.6, 13, 0.9), (1.0, bot - 4.4, 0.45), leather("Sheath", (0.12, 0.05, 0.02)),
           bevel=0.3).rotation_euler = (0, 0, math.radians(84))
    E.haze_box("haze", (160, 180, 70), (0, 20, 34), 0.003, color=(1.0, 0.9, 0.8), noise_scale=0.03)
    return dict(
        samples=128, exposure=0.6, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=30, az=-6, lens=65, fstop=2.8),
    )
