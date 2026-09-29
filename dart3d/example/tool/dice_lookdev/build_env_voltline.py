"""Voltline environment: "Rain Counter".

A late-night diner counter by a rain-streaked window. The tray is a holo
tray: smoked black glass with a faint hex grid of light, its rim a neon
tube in cyan with a magenta inner line. Wet black counter top with
puddles reflects the neon; abstract signage (shapes, no words) glows
outside; a chrome napkin box and a paper cup sit at the edges.
"""
from __future__ import annotations

import math

import bpy
from mathutils import Vector

import env_common as E
import env_props as P

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 1.6, 1.8
CYAN, MAGENTA = (0.05, 0.85, 1.0), (1.0, 0.08, 0.6)


def holo_floor():
    m, k = E.material("Holo floor")
    obj = k.coords().outputs["Object"]
    # hex grid from voronoi on a regular lattice is costly; a triangle-ish grid of 3 line families reads close
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    lines = None
    for ang in (0, 60, 120):
        a = math.radians(ang)
        proj = k.math("ADD", k.math("MULTIPLY", sep.outputs["X"], math.cos(a)),
                      k.math("MULTIPLY", sep.outputs["Y"], math.sin(a)))
        f = k.math("ABSOLUTE", k.math("SUBTRACT", k.math("FRACT", k.math("DIVIDE", proj, 2.0)), 0.5))
        l = k.math("GREATER_THAN", f, 0.48)
        lines = l if lines is None else k.math("MAXIMUM", lines, l)
    pulse = k.noise(obj, 0.08, 2).outputs["Fac"]
    s = k.bsdf(Base_Color=(0.005, 0.006, 0.01, 1), Roughness=0.08, Coat_Weight=1.0, Coat_Roughness=0.02,
               Emission_Color=(*CYAN, 1), Emission_Strength=k.math("MULTIPLY", lines, k.math("MULTIPLY", pulse, 1.2)))
    k.surface(s)
    return m


def wet_counter():
    m, k = E.material("Wet counter")
    obj = k.coords().outputs["Object"]
    puddle = k.math("GREATER_THAN", k.noise(obj, 0.05, 4, 0.6).outputs["Fac"], 0.52)
    speck = k.noise(obj, 3.0, 4).outputs["Fac"]
    rough = k.math("SUBTRACT", 0.45, k.math("MULTIPLY", puddle, 0.43))
    drops = k.voronoi(obj, 1.5)
    dr = k.math("LESS_THAN", drops.outputs["Distance"], 0.12)
    nrm = k.bump(k.math("MULTIPLY", dr, k.math("SUBTRACT", 1.0, puddle)), 0.3, 0.1)
    k.surface(k.bsdf(Base_Color=k.mix(k.math("MULTIPLY", speck, 0.3), (0.012, 0.012, 0.015, 1),
                                      (0.05, 0.05, 0.06, 1)), Roughness=rough, Normal=nrm,
                     Coat_Weight=k.math("MULTIPLY", puddle, 1.0), Coat_Roughness=0.01))
    return m


def neon_tube(name, pts, color, strength=30.0, r=0.35):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 3
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (*p, 1)
    ob = bpy.data.objects.new(name, cu)
    ob.data.materials.append(E.emissive(name, color, strength))
    return E.link(ob)


def build(scene):
    E.world(scene, color=(0.004, 0.004, 0.008), strength=1.0)
    E.cube("counter", (220, 70, 6), (0, 8, -3.0), wet_counter(), bevel=0.6)
    E.plane("holo_floor", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.25), holo_floor())
    E.cube("holo_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.5), (0, 0, 0),
           E.simple("Anodized black", (0.01, 0.01, 0.012), 0.3, 1.0), bevel=0.2)
    E.rim("rim_body", W + RIM_T, D + RIM_T, 2.5, RIM_H, RIM_T,
          E.simple("Rim black chrome", (0.03, 0.03, 0.035), 0.12, 1.0), z0=0.25)
    E.rim("rim_neon", W + RIM_T, D + RIM_T, 2.5, 0.35, 0.35, E.emissive("Rim cyan", CYAN, 25.0), z0=RIM_H + 0.25)
    E.rim("rim_inner", W + 0.2, D + 0.2, 1.6, 0.2, 0.2, E.emissive("Rim magenta", MAGENTA, 15.0), z0=0.3)
    top = D / 2 + RIM_T
    # window + signage outside
    E.cube("window_frame", (220, 2, 3), (0, top + 38, 0), E.simple("Frame", (0.02, 0.02, 0.02), 0.4, 1.0))
    glass, k = E.material("Rain glass")
    obj = k.coords().outputs["Object"]
    mp = k.node("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0, 1.0, 0.15)
    k.link(obj, mp.inputs["Vector"])
    rain = k.voronoi(mp.outputs[0], 2.0)
    k.surface(k.bsdf(Base_Color=(0.9, 0.95, 1.0, 1), Transmission_Weight=1.0, Roughness=0.05,
                     Normal=k.bump(rain.outputs["Distance"], 0.6, 0.2)))
    win = E.plane("window", 220, 90, (0, top + 40, 44), glass)
    win.rotation_euler = (math.radians(90), 0, 0)
    neon_tube("sign_arc", [(math.cos(t) * 14 - 22, top + 90, 50 + math.sin(t) * 14)
                           for t in [i * math.pi / 20 for i in range(31)]], MAGENTA, 40)
    neon_tube("sign_bars", [(10, top + 100, 40), (10, top + 100, 70), (22, top + 100, 70), (22, top + 100, 55),
                            (34, top + 100, 55)], CYAN, 40)
    neon_tube("sign_tri", [(-50, top + 120, 30), (-35, top + 120, 60), (-20, top + 120, 30), (-50, top + 120, 30)],
              (1.0, 0.55, 0.05), 30)
    E.cube("far_wall", (400, 2, 200), (0, top + 160, 60), E.simple("Far wall", (0.01, 0.01, 0.015), 0.8))
    E.scatter("rain", 500, ((-80, top + 42, 0), (80, top + 140, 110)), 0.05,
              E.emissive("Rain", (0.6, 0.8, 1.0), 1.5), seed=40,
              stretch=lambda p, r: Vector((0.1, 0, -1)) * r.uniform(15, 30))
    # counter props
    chrome = E.simple("Chrome", (0.9, 0.9, 0.92), 0.08, 1.0)
    E.cube("napkin_box", (8, 5, 9), (-W / 2 - 10, top - 2, 4.5), chrome, bevel=0.6)
    E.cylinder("cup", 3.4, 10, (W / 2 + 10, top - 6, 5), E.simple("Paper cup", (0.85, 0.85, 0.82), 0.6),
               segs=40, r2=4.2)
    E.cylinder("cup_band", 4.0, 3, (W / 2 + 10, top - 6, 6), E.simple("Cup band", (0.9, 0.1, 0.4), 0.5), segs=40,
               r2=4.15)
    E.cube("phone", (7.5, 15.5, 0.8), (W / 2 + 12, -8, 0.4), E.simple("Phone black", (0.01, 0.01, 0.01), 0.1,
                                                                       Coat_Weight=1.0), bevel=0.6).rotation_euler = (0, 0, -0.3)
    E.light(scene, "AREA", "neon_m", (-22, top + 60, 50), 12000, color=MAGENTA, size=30, target=(0, 0, 0))
    E.light(scene, "AREA", "neon_c", (22, top + 60, 50), 12000, color=CYAN, size=30, target=(0, 0, 0))
    E.light(scene, "AREA", "key", (0, -40, 50), 1800, color=(0.8, 0.85, 1.0), size=25, target=(0, 0, 0))
    E.haze_box("haze", (200, 200, 80), (0, 60, 40), 0.004, color=(0.9, 0.9, 1.0), noise_scale=0.03)
    return dict(
        samples=128, exposure=0.2, hero=dict(dist=32, elev=28, az=6, lens=65, fstop=2.8),
        roll=dict(settled={"d12": ((-4.5, -7.0), 12, 20), "d6": ((5.5, -3.0), 6, -10), "d10t": ((-2.0, 4.0), 0, 30),
                           "d4": ((6.0, 9.0), 4, 0)},
                  airborne={"d20": ((0.5, -2.5, 3.0), (1.2, 2.5, 0.2)), "d8": ((-5.5, 7.0, 5.0), (2.0, -1.0, -0.5)),
                            "d10u": ((4.0, 14.0, 2.2), (-1.5, -2.0, 0.3))}),
    )
