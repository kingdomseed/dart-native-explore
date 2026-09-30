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
import room_common as RC

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
    # Round 2: the tray is a lightbox under smoked glass: a soft indigo glow
    # everywhere, so the black-chrome dice read as crisp silhouettes.
    field = k.emission((0.14, 0.1, 0.42, 1), k.math("ADD", 0.62, k.math("MULTIPLY", pulse, 0.3)))
    k.surface(k.add_shader(s, field))
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
    E.plane("holo_floor", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.26), holo_floor())
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
    bot = -D / 2 - RIM_T
    E.cube("phone_low", (7.5, 15.5, 0.8), (W / 2 - 0.5, bot - 8.6, 0.4), E.simple("Phone low black", (0.01, 0.01, 0.01),
                                                                                  0.1, Coat_Weight=1.0),
           bevel=0.6).rotation_euler = (0, 0, 1.35)
    scr = E.cube("phone_screen", (6.6, 14.2, 0.05), (W / 2 - 0.5, bot - 8.6, 0.82),
                 E.emissive("Phone screen", (0.2, 0.35, 0.9), 1.2))
    scr.rotation_euler = (0, 0, 1.35)
    rc = P.paper(-W / 2 + 2.5, top + 3.5, 0.0, 5, 12, rot=1.45, mat=E.simple("Receipt", (0.85, 0.84, 0.8), 0.7),
                 curl=0.3, seed=51)
    E.cylinder("straw", 0.25, 14, (-1.0, bot - 2.4, 0.3), E.simple("Straw", (1.0, 0.1, 0.5), 0.3),
               segs=10).rotation_euler = (0, math.radians(90), 0.08)
    E.cube("phone", (7.5, 15.5, 0.8), (W / 2 + 12, -8, 0.4), E.simple("Phone black", (0.01, 0.01, 0.01), 0.1,
                                                                       Coat_Weight=1.0), bevel=0.6).rotation_euler = (0, 0, -0.3)
    E.light(scene, "AREA", "neon_m", (-22, top + 60, 50), 12000, color=MAGENTA, size=30, target=(0, 0, 0))
    E.light(scene, "AREA", "neon_c", (22, top + 60, 50), 12000, color=CYAN, size=30, target=(0, 0, 0))
    E.light(scene, "AREA", "key", (0, -40, 50), 1800, color=(0.8, 0.85, 1.0), size=25, target=(0, 0, 0))
    E.haze_box("haze", (200, 200, 80), (0, 60, 40), 0.004, color=(0.9, 0.9, 1.0), noise_scale=0.03)
    rc = room(scene, top, chrome)
    return dict(
        samples=128, exposure=0.2, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=28, az=6, lens=65, fstop=2.8),
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene, top, chrome):
    """The late-night diner (concept: room-concepts/voltline-room).

    The tray is on the window counter; the rain window is the whole back
    wall. To the left the diner runs away from camera: a long chrome-edged
    bar with red stools, a back bar of bottles, warm pendants over it and a
    magenta neon strip along the ceiling; black-and-white checker floor,
    dark panelled walls; across the street, lit windows in the far block.
    Lights from four sides: the street neon through the window (magenta and
    cyan, back), the bar pendants (warm, left), the ceiling neon strip
    (magenta, above-left) and the tray's cool key from the front.
    """
    wy = top + 41
    panel = P.dark_wood("Diner panel", c1=(0.02, 0.012, 0.01), c2=(0.05, 0.03, 0.02), varnish=0.6)
    RC.shell(half_w=200, back=wy, front=-240, height=210, wall=panel, floor_z=-105.0,
             floor=RC.tiles("Diner floor", (0.6, 0.58, 0.55), (0.02, 0.02, 0.02), scale=0.025, rough=0.2),
             openings={"back": [(0, 44, 220, 90)]}, ceiling=E.simple("Diner ceiling", (0.02, 0.02, 0.025), 0.6))
    E.cube("window_counter_front", (220, 4, 99), (0, -27, -55.5), chrome, bevel=0.5)
    # lit windows across the street (a card just in front of the far wall)
    city, k = E.material("Street block")
    tc = k.coords().outputs["Object"]
    b = k.node("ShaderNodeTexBrick")
    k.link(tc, b.inputs["Vector"])
    k.set(b, Scale=0.08, Mortar_Size=0.25, Color1=(1, 1, 1, 1), Color2=(1, 1, 1, 1), Mortar=(0, 0, 0, 1))
    lit = k.math("MULTIPLY", k.math("SUBTRACT", 1.0, b.outputs["Fac"]),
                 k.math("GREATER_THAN", k.noise(tc, 0.3, 2).outputs["Fac"], 0.52))
    col = k.mix(k.noise(tc, 0.05, 2).outputs["Fac"], (1.0, 0.75, 0.45, 1), (0.5, 0.7, 1.0, 1))
    k.surface(k.emission(col, k.math("MULTIPLY", lit, 1.2)))
    card = E.plane("street_block", 400, 200, (0, top + 158, 60), city)
    card.rotation_euler = (math.radians(90), math.radians(180), 0)
    # the bar on the left: counter, chrome edge, stools, back bar, pendants
    red = E.simple("Stool vinyl", (0.4, 0.02, 0.03), 0.3, Coat_Weight=0.6)
    bar_top = E.simple("Bar top", (0.03, 0.03, 0.035), 0.1, Coat_Weight=1.0)
    E.cube("bar", (60, 220, 100), (-150, -100, -55), panel, bevel=0.5)
    E.cube("bar_top", (66, 224, 5), (-150, -100, -3), bar_top, bevel=0.8)
    E.cube("bar_chrome", (2, 224, 6), (-117, -100, -8), chrome)
    for i in range(5):
        y = -190 + i * 45
        E.cylinder("stool_post", 2.5, 70, (-100, y, -70), chrome, segs=16)
        E.cylinder("stool_seat", 17, 9, (-100, y, -32), red, segs=32, bevel=2.0)
        E.cylinder("stool_foot", 16, 3, (-100, y, -103), chrome, segs=32)
    RC.wall_shelf("left", -100, -10 + 25, w=200, depth=18, seed=14, kind="bottles", mat=chrome,
                  palette=[(0.05, 0.2, 0.05), (0.3, 0.12, 0.02), (0.2, 0.2, 0.25), (0.25, 0.02, 0.05)])
    RC.wall_shelf("left", -100, 20 + 25, w=200, depth=18, seed=15, kind="bottles", mat=chrome,
                  palette=[(0.05, 0.2, 0.05), (0.3, 0.12, 0.02), (0.2, 0.2, 0.25), (0.25, 0.02, 0.05)])
    for y in (-170, -100, -30):
        RC.pendant_lamp(scene, -145, y, 55, energy=20000, color=(1.0, 0.72, 0.45), shade=(0.8, 0.8, 0.82), r=16,
                        spot_deg=100)
    RC.neon_bar(scene, (-190, -235, 100), (-190, wy - 5, 100), MAGENTA, strength=18.0, energy=15000)
    RC.neon_bar(scene, (-195, wy - 4, 96), (195, wy - 4, 96), CYAN, strength=14.0, energy=12000)
    # a booth bench behind the camera side on the right, with a table lamp glow
    E.cube("booth_seat", (60, 130, 45), (170, -130, -82), red, bevel=4)
    E.cube("booth_back", (15, 130, 70), (195, -130, -40), red, bevel=4)
    return dict(loc=(22, -62, 34), target=(-24, 80, 4), lens=20, fstop=4.0, focus=(0, 0, 2))
