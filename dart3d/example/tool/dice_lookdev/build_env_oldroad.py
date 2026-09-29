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
    E.world(scene, color=(0.01, 0.012, 0.02), strength=1.0)
    table = P.dark_wood("Inn table", c1=(0.05, 0.03, 0.015), c2=(0.18, 0.1, 0.05), rough=0.75, varnish=0.0)
    E.cube("table", (200, 150, 6), (0, 20, -3.0), table, bevel=0.5)
    E.plane("map", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.35), P.parchment("Travel map"), subdiv=1)
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
    E.cylinder("pipe_bowl", 1.1, 2.6, (W / 2 + 9, -6, 1.6), clay, segs=24, r2=1.3)
    stem = E.cylinder("pipe_stem", 0.3, 14, (W / 2 + 9 + 6.5, -6 - 2.0, 0.6), clay, segs=10)
    stem.rotation_euler = (0, math.radians(86), math.radians(-18))
    # satchel strap + buckle
    strap = E.plane("strap", 4, 70, (W / 2 + 16, 10, 0.2), leather("Strap"), subdiv=30)
    strap.rotation_euler = (0, 0, 0.25)
    sol = strap.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.4
    P.torus("buckle", 2.2, 0.25, (W / 2 + 15.5, 2, 0.6), P.brass("Buckle brass", worn=0.8), minor_seg=8)
    E.rock("satchel", 12, (W / 2 + 24, top + 8, 6), leather("Satchel", (0.16, 0.07, 0.03)), seed=3,
           squash=(1.2, 0.8, 0.7), strength=0.12)
    for i, (x, y) in enumerate(((-W / 2 - 6, -D / 2 + 3), (-W / 2 - 8.5, -D / 2 + 6), (-W / 2 - 5, -D / 2 + 8))):
        P.coin(x, y, 0.0, r=1.4, tilt=(0.03 * i, -0.02 * i))
    E.rock("bread", 5.5, (-W / 2 - 13, 6, 3), E.simple("Bread crust", (0.35, 0.16, 0.05), 0.7), seed=6,
           squash=(1.3, 0.9, 0.7), strength=0.1)
    E.cylinder("mug", 3.8, 10, (-W / 2 - 12, top - 4, 5), P.dark_wood("Mug wood"), segs=32, bevel=0.3)
    P.backdrop_window(0, top + 75, 45, 70, 80, sky_top=(0.03, 0.06, 0.18), sky_bot=(0.25, 0.2, 0.3), moon=False)
    E.light(scene, "AREA", "blue_hour", (0, top + 70, 50), 9000, color=(0.5, 0.6, 1.0), size=50, target=(0, 0, 0))
    E.light(scene, "AREA", "warm_key", (-25, -20, 40), 6000, color=(1.0, 0.75, 0.5), size=20, target=(0, 0, 0))
    E.haze_box("haze", (160, 180, 70), (0, 20, 34), 0.003, color=(1.0, 0.9, 0.8), noise_scale=0.03)
    return dict(
        samples=128, exposure=1.0, hero=dict(dist=32, elev=30, az=-6, lens=65, fstop=2.8),
        roll=dict(settled={"d12": ((-4.5, -7.0), 12, 20), "d6": ((5.5, -3.0), 6, -10), "d10t": ((-2.0, 4.0), 0, 30),
                           "d4": ((6.0, 9.0), 4, 0)},
                  airborne={"d20": ((0.5, -2.5, 3.0), (1.2, 2.5, 0.2)), "d8": ((-5.5, 7.0, 5.0), (2.0, -1.0, -0.5)),
                            "d10u": ((4.0, 14.0, 2.2), (-1.5, -2.0, 0.3))}),
    )
