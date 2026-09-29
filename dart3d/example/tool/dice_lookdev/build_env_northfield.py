"""Northfield Relay environment: "Kitchen Table, 1986".

A pale birch kitchen table in a countryside house under a low pendant lamp.
The tray is a beige instrument case lined with a sage rubber mat printed
with a calibration grid. A chunky CRT terminal glows green, an odd boxy
field instrument with dials and toggles sits beside a coffee cup and a
coiled cable; grey-blue dusk through the window. Invented hardware only.
"""
from __future__ import annotations

import math

import env_common as E
import env_props as P

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.8, 3.0
ABS = (0.78, 0.74, 0.64)


def mat_grid():
    m, k = E.material("Sage mat")
    obj = k.coords().outputs["Object"]
    g1 = E.grid_lines(k, obj, 1.0, 0.04)
    g5 = E.grid_lines(k, obj, 5.0, 0.12)
    col = k.mix(k.math("MAXIMUM", k.math("MULTIPLY", g1, 0.35), g5), (0.24, 0.32, 0.26, 1), (0.85, 0.88, 0.8, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.85, Normal=k.bump(k.noise(obj, 20.0, 2).outputs["Fac"], 0.1, 0.02)))
    return m


def crt_screen():
    m, k = E.material("CRT screen")
    obj = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    scan = k.math("SINE", k.math("MULTIPLY", sep.outputs["Z"], 40.0))
    scan = k.math("MULTIPLY_ADD", scan, 0.25, 0.75)
    rows = k.math("LESS_THAN", k.math("FRACT", k.math("MULTIPLY", sep.outputs["Z"], 0.9)), 0.45)
    chars = k.math("GREATER_THAN", k.noise(obj, 3.0, 1).outputs["Fac"], 0.5)
    text = k.math("MULTIPLY", rows, chars)
    lum = k.math("MULTIPLY", k.math("ADD", k.math("MULTIPLY", text, 1.0), 0.12), scan)
    em = k.emission((0.3, 1.0, 0.45, 1), k.math("MULTIPLY", lum, 5.0))
    glass = k.bsdf(Base_Color=(0.02, 0.03, 0.02, 1), Roughness=0.05, Coat_Weight=1.0)
    k.surface(k.add_shader(glass, em))
    return m


def build(scene):
    E.world(scene, color=(0.03, 0.035, 0.045), strength=1.0)
    birch = P.dark_wood("Birch table", c1=(0.55, 0.45, 0.32), c2=(0.72, 0.62, 0.46), rough=0.5, varnish=0.3)
    E.cube("table", (200, 150, 6), (0, 20, -3.0), birch, bevel=0.5)
    E.plane("mat", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.35), mat_grid())
    case = E.simple("Case ABS", ABS, 0.45, Coat_Weight=0.15)
    E.cube("case_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.7), (0, 0, 0), case, bevel=0.3)
    E.rim("rim", W + RIM_T, D + RIM_T, 4.0, RIM_H, RIM_T, case, z0=0.35)
    E.cube("rim_stripe", (W + 2 * RIM_T + 1.2, 0.5, 0.5), (0, -D / 2 - RIM_T - 0.3, 1.7),
           E.simple("Stripe orange", (0.85, 0.3, 0.05), 0.5))
    top = D / 2 + RIM_T
    # CRT terminal
    cx, cy = -8.0, top + 16
    E.cube("crt_body", (26, 22, 22), (cx, cy + 3, 11), case, bevel=1.5)
    E.cube("crt_bezel", (22, 1.5, 17), (cx, cy - 8.2, 12.5), E.simple("Bezel", (0.3, 0.29, 0.27), 0.5), bevel=0.8)
    scr = E.sphere("crt_glass", 1.0, (cx, cy - 8.6, 12.5), crt_screen(), subdiv=4, scale=(9.0, 1.0, 7.0))
    E.light(scene, "AREA", "crt_glow", (cx, cy - 10, 12.5), 400, color=(0.3, 1.0, 0.45), size=14,
            target=(cx, 0, 2))
    E.cube("keyboard", (24, 9, 2), (cx + 1, top + 1.5, 1.0), case, bevel=0.4).rotation_euler = (0.08, 0, 0.05)
    keys = E.simple("Keycaps", (0.35, 0.33, 0.3), 0.5)
    for r in range(3):
        for c in range(10):
            E.cube("key", (1.6, 1.6, 0.6), (cx + 1 - 10.3 + c * 2.25, top - 1 + r * 2.3, 2.2), keys, bevel=0.15)
    # field instrument with dials and toggles
    ix, iy = W / 2 + 13, 6
    E.cube("instrument", (12, 16, 7), (ix, iy, 3.5), E.simple("Instrument teal", (0.08, 0.25, 0.26), 0.5), bevel=0.5)
    for i, dy in enumerate((-4, 3)):
        E.cylinder("dial", 2.2, 0.4, (ix - 1.5, iy + dy, 7.2), E.simple("Dial face", (0.9, 0.88, 0.8), 0.4),
                   segs=32)
        E.cylinder("dial_needle", 0.08, 2.0, (ix - 1.5, iy + dy, 7.5), E.simple("Needle", (0.8, 0.1, 0.02), 0.4),
                   segs=6).rotation_euler = (math.radians(90), 0, 0.4 + i)
    for j in range(3):
        E.cylinder("toggle", 0.25, 1.8, (ix + 3.5, iy - 4 + j * 3, 8.0), E.simple("Chrome", (0.9, 0.9, 0.9), 0.15,
                                                                               1.0), segs=10)
        E.sphere("led", 0.4, (ix + 3.5, iy - 5.5 + j * 3, 7.1), E.emissive("LED", (1.0, 0.35, 0.05), 8.0),
                 subdiv=2)
    # coffee cup + coiled cable
    E.cylinder("cup", 3.5, 7, (W / 2 + 12, top + 2, 3.5), E.simple("Cup enamel", (0.9, 0.9, 0.85), 0.3,
                                                                   Coat_Weight=0.8), segs=40, bevel=0.3)
    E.cylinder("coffee", 3.2, 0.2, (W / 2 + 12, top + 2, 6.6), E.simple("Coffee", (0.05, 0.02, 0.01), 0.05))
    cable = E.simple("Cable", (0.1, 0.1, 0.1), 0.5)
    for i in range(16):
        P.torus("coil", 1.2, 0.18, (-W / 2 - 9, -10 + i * 0.5, 1.4), cable, rot=(math.radians(90), 0, 0),
                major_seg=24, minor_seg=6)
    P.paper(-W / 2 - 12, -D / 2 + 2, 0.0, 16, 22, rot=0.2, mat=E.simple("Printout", (0.9, 0.9, 0.85), 0.8),
            curl=0.4)
    # pendant lamp + dusk window
    lamp = E.cylinder("lamp_shade", 3.0, 10, (4, 4, 60), E.simple("Lamp shade", (0.85, 0.35, 0.08), 0.5), segs=48,
                      r2=14.0, cap=False)
    lamp.rotation_euler = (math.radians(180), 0, 0)
    E.light(scene, "SPOT", "lamp", (4, 4, 56), 90000, color=(1.0, 0.82, 0.6), size=4, target=(0, 0, 0),
            spot_deg=95, blend=0.6)
    P.backdrop_window(0, top + 80, 45, 90, 70, sky_top=(0.2, 0.25, 0.35), sky_bot=(0.45, 0.45, 0.5), moon=False,
                      frame_mat=E.simple("Window white", (0.8, 0.8, 0.78), 0.5))
    E.light(scene, "AREA", "dusk", (0, top + 75, 45), 8000, color=(0.6, 0.7, 1.0), size=60, target=(0, 0, 0))
    return dict(
        samples=128, exposure=0.0, hero=dict(dist=32, elev=30, az=8, lens=65, fstop=2.8),
        roll=dict(settled={"d12": ((-4.5, -7.0), 12, 20), "d6": ((5.5, -3.0), 6, -10), "d10t": ((-2.0, 4.0), 0, 30),
                           "d4": ((6.0, 9.0), 4, 0)},
                  airborne={"d20": ((0.5, -2.5, 3.0), (1.2, 2.5, 0.2)), "d8": ((-5.5, 7.0, 5.0), (2.0, -1.0, -0.5)),
                            "d10u": ((4.0, 14.0, 2.2), (-1.5, -2.0, 0.3))}),
    )
