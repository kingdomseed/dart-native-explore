"""Hearthside Tome environment: "Fireside Reading".

The rolling surface is a huge open illustrated tome lying spine-across
(portrait friendly): sepia-inked plates and ruled text blocks, pages
bowed toward the gutter, a ribbon marker. A low hearth glows behind;
a stoneware mug, velvet dice pouch, wax seals and dried lavender sit
around the book on a worn oak table.
"""
from __future__ import annotations

import math
import random

import bmesh
import bpy

import env_common as E
import env_props as P

W, D = E.TRAY_W, E.TRAY_D


def page_mat():
    m, k = E.material("Tome page")
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.3, 8, 0.6).outputs["Fac"]
    # Round 2: tea-stained vellum, a few steps darker than the bone dice so
    # they separate at top-down (round 1's cream pages matched the dice).
    col = k.ramp(n, [(0.3, (0.33, 0.24, 0.13)), (0.7, (0.5, 0.39, 0.24))])
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    # ruled text blocks: rows of short dashes, leaving an illustration window
    rows = k.math("LESS_THAN", k.math("FRACT", k.math("DIVIDE", sep.outputs["Y"], 0.42)), 0.22)
    wm = k.node("ShaderNodeMapping")
    wm.inputs["Scale"].default_value = (1.0, 6.0, 1.0)
    k.link(obj, wm.inputs["Vector"])
    words = k.math("GREATER_THAN", k.noise(wm.outputs[0], 2.2, 1).outputs["Fac"], 0.42)
    ax, ay = k.math("ABSOLUTE", sep.outputs["X"]), k.math("ABSOLUTE", sep.outputs["Y"])
    margin = k.math("MULTIPLY", k.math("LESS_THAN", ax, W / 2 + 1.5), k.math("LESS_THAN", ay, D / 2 + 1.0))
    margin = k.math("MULTIPLY", margin, k.math("GREATER_THAN", ay, 1.8))
    illus_c = k.math("LESS_THAN", k.math("ABSOLUTE", sep.outputs["X"]), W / 2 - 1.0)
    illus = k.math("MULTIPLY", illus_c, k.math("LESS_THAN", k.math("ABSOLUTE", k.math("SUBTRACT", ay, D / 4 + 2.0)),
                                               D / 8))
    text = k.math("MULTIPLY", k.math("MULTIPLY", rows, words), margin)
    text = k.math("MULTIPLY", text, k.math("SUBTRACT", 1.0, illus))
    # the 'plate': an ink-wash landscape made of layered noise contours
    c = k.noise(obj, 0.25, 5, 0.6).outputs["Fac"]
    hatch = k.math("LESS_THAN", k.math("FRACT", k.math("MULTIPLY", c, 14.0)), 0.25)
    plate = k.math("MULTIPLY", illus, k.math("MAXIMUM", hatch, k.math("MULTIPLY", c, 0.4)))
    ink = k.math("MAXIMUM", k.math("MULTIPLY", text, 0.8), k.math("MULTIPLY", plate, 0.7))
    col = k.mix(ink, col, (0.18, 0.1, 0.05, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.8, Subsurface_Weight=0.15))
    return m


def open_book(scene):
    cover_m = E.simple("Tome cover", (0.12, 0.035, 0.02), 0.55, Coat_Weight=0.2)
    E.cube("tome_cover", (W + 8, D + 12, 0.8), (0, 0, 0.4), cover_m, bevel=0.3)
    pm = page_mat()
    for s in (1, -1):  # two page blocks; spine runs along x at y=0
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=40, y_segments=40, size=0.5)
        for v in bm.verts:
            x, y = v.co.x * (W + 6), (v.co.y + 0.5) * (D / 2 + 4)
            t = y / (D / 2 + 4)
            z = 3.0 + 0.4 * math.sin(math.pi * t) - 1.2 * math.exp(-t * 14)
            v.co = (x, s * y, z)
        ob = E.mesh_object(f"pages{s}", bm, pm, smooth=True)
        sol = ob.modifiers.new("block", "SOLIDIFY")
        sol.thickness = 1.6
    rib = E.cube("ribbon", (1.2, 20, 0.05), (6, -D / 2 - 2, 0.9), E.simple("Ribbon", (0.35, 0.02, 0.03), 0.5,
                                                                           Sheen_Weight=1.0))
    rib.rotation_euler = (0, 0, 0.15)


def build(scene):
    E.world(scene, color=(0.012, 0.006, 0.003), strength=1.0)
    E.cube("table", (200, 150, 6), (0, 20, -3.0), P.dark_wood("Oak table", c1=(0.07, 0.035, 0.015),
                                                          c2=(0.2, 0.11, 0.05), varnish=0.2), bevel=0.5)
    open_book(scene)
    top = D / 2 + 6
    # stoneware mug
    mug_m = E.simple("Stoneware", (0.25, 0.2, 0.16), 0.5, Coat_Weight=0.6)
    mx, my = W / 2 + 5.5, top + 1.5  # top-right corner of the phone frame
    mug = E.cylinder("mug", 4.0, 9, (mx, my, 4.5), mug_m, segs=48, bevel=0.4)
    P.torus("mug_handle", 2.4, 0.6, (mx + 4.5, my, 5), mug_m, rot=(math.radians(90), 0, 0))
    E.cylinder("tea", 3.6, 0.2, (mx, my, 8.2), E.simple("Tea", (0.1, 0.04, 0.01), 0.05))
    # velvet pouch
    pouch = E.rock("pouch", 5.0, (-W / 2 - 5.5, top + 0.5, 3.5), P.velvet("Pouch velvet", color=(0.12, 0.02, 0.1),
                                                                         stars=False), seed=4,
                   squash=(1, 1, 0.9), strength=0.2)
    E.cylinder("pouch_neck", 1.8, 3, (-W / 2 - 5.5, top + 0.5, 8.5), P.velvet("Pouch velvet"), segs=24, r2=2.6)
    # wax seals + lavender
    wax = E.simple("Seal wax", (0.35, 0.02, 0.02), 0.35, Coat_Weight=0.5)
    for i, (x, y) in enumerate(((W / 2 + 1.5, -D / 2 - 7.8), (W / 2 + 5.0, -D / 2 - 9.0))):
        E.cylinder("seal", 1.8, 0.5, (x, y, 0.25), wax, segs=32, bevel=0.15)
    rng = random.Random(8)
    stem = E.simple("Lavender stem", (0.18, 0.25, 0.12), 0.6)
    bud = E.simple("Lavender bud", (0.35, 0.22, 0.6), 0.6)
    for i in range(9):
        a = rng.uniform(-0.2, 0.2)
        x0, y0 = -W / 2 - 16 + i * 0.6, -D / 2 + 5
        s = E.cylinder("stem", 0.12, 22, (x0, y0, 0.5), stem, segs=6)
        s.rotation_euler = (math.radians(90), 0, a)
        for j in range(8):
            E.sphere("bud", 0.35, (x0 - math.sin(a) * (-11 - j * 0.7), y0 - 11 - j * 0.7, 0.55), bud, subdiv=1,
                     scale=(1, 1.4, 1))
    P.candle(scene, W / 2 + 10, top + 8, 0.0, h=10, seed=4, energy=45)
    # the hearth: a warm glow + ember light behind the table
    E.cube("hearth", (80, 10, 40), (0, top + 55, 20), E.simple("Hearth stone", (0.08, 0.06, 0.05), 0.9))
    E.cube("hearth_mouth", (40, 3, 22), (0, top + 49.5, 12), E.emissive("Hearth fire", (1.0, 0.38, 0.08), 6.0))
    E.light(scene, "AREA", "fire", (0, top + 45, 12), 16000, color=(1.0, 0.5, 0.2), size=35, target=(0, 0, 0))
    E.light(scene, "AREA", "cool_fill", (-50, -40, 40), 1200, color=(0.55, 0.65, 1.0), size=40, target=(0, 0, 0))
    # reading key from the side (its hotspot misses the top faces), strong
    # enough that the bone reads bright against the tea-stained vellum
    E.light(scene, "AREA", "reading_key", (40, -20, 40), 11000, color=(1.0, 0.9, 0.8), size=20, target=(0, 0, 0))
    E.haze_box("haze", (160, 180, 70), (0, 20, 34), 0.004, color=(1.0, 0.85, 0.7), noise_scale=0.03)
    return dict(
        samples=128, exposure=0.9, surface_z=3.3, centre=(0, 9.0, 4.3),
        topdown=dict(width=W + 9.0),
        # keep the dice off the gutter's slope (the physics floor is flat)
        topdown_layout={"d20": ((0.4, -4.2), 18, 8), "d12": ((-3.9, 4.6), 11, -14), "d10u": ((3.7, 4.2), 9, 12),
                        "d10t": ((-0.3, 9.0), 40, -6), "d8": ((-3.8, -8.6), 5, 16), "d6": ((3.8, -8.4), 3, -9),
                        "d4": ((0.4, 13.0), 3, 22)},
        hero=dict(dist=32, elev=30, az=-8, lens=65, fstop=2.8),
    )
