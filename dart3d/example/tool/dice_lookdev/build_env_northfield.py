"""Northfield Relay environment: "Kitchen Table, 1986".

Round 2 (operator: "doesn't look like a kitchen table"): an actual 1980s
farmhouse kitchen table, read from straight above first. A wood-grain
laminate top with a ribbed aluminium edge band under a warm pendant lamp.
On it, around the beige instrument-case tray: a stoneware mug of coffee, a
plate with a toast crust and crumbs, the morning newspaper (abstract
columns, no words), a spiral notebook with a pencil, a pocket transistor
radio, a salt shaker. The retro-tech from round 1 stays: the chunky CRT
terminal and its keyboard at the head of the table, the teal field
instrument, a coiled cable, and the tray's calibration mat (now dark green,
so the warm-white dice separate from it). Invented hardware only.
"""
from __future__ import annotations

import math
import random

import bpy

import env_common as E
import env_props as P
import room_common as RC

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.8, 3.0
ABS = (0.78, 0.74, 0.64)


def mat_grid():
    m, k = E.material("Calibration mat")
    obj = k.coords().outputs["Object"]
    g1 = E.grid_lines(k, obj, 1.0, 0.035)
    g5 = E.grid_lines(k, obj, 5.0, 0.1)
    # dark green self-healing mat with pale grid lines
    col = k.mix(k.math("MAXIMUM", k.math("MULTIPLY", g1, 0.35), g5), (0.03, 0.075, 0.05, 1), (0.55, 0.62, 0.5, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.85, Normal=k.bump(k.noise(obj, 20.0, 2).outputs["Fac"], 0.1, 0.02)))
    return m


def laminate():
    """Wood-grain laminate: a printed, very regular grain under a satin coat."""
    m, k = E.material("Woodgrain laminate")
    obj = k.coords().outputs["Object"]
    mp = k.node("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (0.08, 1.0, 1.0)
    k.link(obj, mp.inputs["Vector"])
    n = k.noise(mp.outputs[0], 0.8, 6, 0.55, dist=0.6).outputs["Fac"]
    wave = k.node("ShaderNodeTexWave", wave_type="BANDS", bands_direction="Y")
    k.link(mp.outputs[0], wave.inputs["Vector"])
    k.set(wave, Scale=1.4, Distortion=4.0, Detail=3.0)
    grain = k.math("MULTIPLY", wave.outputs["Fac"], n)
    col = k.ramp(grain, [(0.1, (0.34, 0.19, 0.08)), (0.45, (0.52, 0.32, 0.15)), (0.7, (0.6, 0.39, 0.19))])
    k.surface(k.bsdf(Base_Color=col, Roughness=0.38, Coat_Weight=0.35, Coat_Roughness=0.2,
                     Normal=k.bump(grain, 0.04, 0.02)))
    return m


def newspaper():
    """Newsprint: headline bars, six columns of grey 'text' lines, a photo block."""
    m, k = E.material("Newsprint")
    obj = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    x, y = sep.outputs["X"], sep.outputs["Y"]
    col_f = k.math("FRACT", k.math("DIVIDE", k.math("ADD", x, 20.0), 3.3))
    in_col = k.math("LESS_THAN", col_f, 0.9)
    line = k.math("LESS_THAN", k.math("FRACT", k.math("DIVIDE", y, 0.3)), 0.42)
    ragged = k.math("GREATER_THAN", k.noise(obj, 1.3, 2).outputs["Fac"], 0.36)
    body = k.math("MULTIPLY", k.math("MULTIPLY", in_col, line), ragged)
    head = k.math("MULTIPLY", k.math("GREATER_THAN", y, 4.2),
                  k.math("LESS_THAN", k.math("FRACT", k.math("DIVIDE", y, 1.1)), 0.55))
    photo = k.math("MULTIPLY", k.math("MULTIPLY", k.math("GREATER_THAN", x, -9.5), k.math("LESS_THAN", x, -3.0)),
                   k.math("MULTIPLY", k.math("GREATER_THAN", y, -2.5), k.math("LESS_THAN", y, 3.4)))
    ink = k.math("MAXIMUM", k.math("MULTIPLY", body, 0.55), head)
    ink = k.math("MAXIMUM", k.math("MULTIPLY", ink, k.math("SUBTRACT", 1.0, photo)),
                 k.math("MULTIPLY", photo, k.math("ADD", 0.35, k.math("MULTIPLY",
                                                                      k.noise(obj, 0.6, 4).outputs["Fac"], 0.5))))
    col = k.mix(ink, (0.8, 0.78, 0.72, 1), (0.08, 0.08, 0.08, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.9))
    return m


def notebook_page():
    m, k = E.material("Notebook page")
    obj = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    ruled = k.math("LESS_THAN", k.math("FRACT", k.math("DIVIDE", sep.outputs["Y"], 0.72)), 0.06)
    margin = k.math("LESS_THAN", k.math("ABSOLUTE", k.math("ADD", sep.outputs["X"], 5.2)), 0.05)
    # a few pencilled tallies of rolls (strokes, not words)
    tally = k.math("MULTIPLY", k.math("LESS_THAN", k.math("FRACT", k.math("DIVIDE", sep.outputs["X"], 0.45)), 0.12),
                   k.math("MULTIPLY", k.math("GREATER_THAN", sep.outputs["Y"], 1.0),
                          k.math("LESS_THAN", sep.outputs["Y"], 1.55)))
    tally = k.math("MULTIPLY", tally, k.math("MULTIPLY", k.math("GREATER_THAN", sep.outputs["X"], -4.5),
                                             k.math("LESS_THAN", sep.outputs["X"], -1.0)))
    col = k.mix(ruled, (0.9, 0.88, 0.8, 1), (0.35, 0.5, 0.8, 1))
    col = k.mix(margin, col, (0.8, 0.25, 0.25, 1))
    col = k.mix(tally, col, (0.2, 0.2, 0.22, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.85))
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


def pencil(x, y, z, length=16.0, rot=0.0):
    yellow = E.simple("Pencil yellow", (0.9, 0.62, 0.05), 0.4, Coat_Weight=0.5)
    body = E.cylinder("pencil", 0.36, length, (0, 0, 0), yellow, segs=6)
    tip = E.cylinder("pencil_tip", 0.36, 1.6, (0, 0, length / 2 + 0.8), E.simple("Pencil wood", (0.8, 0.62, 0.4),
                                                                                 0.7), segs=6, r2=0.05)
    band = E.cylinder("pencil_band", 0.38, 0.8, (0, 0, -length / 2 - 0.4), E.simple("Ferrule", (0.7, 0.7, 0.65),
                                                                                    0.3, 1.0), segs=16)
    eraser = E.cylinder("pencil_eraser", 0.36, 0.8, (0, 0, -length / 2 - 1.2), E.simple("Eraser", (0.85, 0.4, 0.4),
                                                                                        0.8), segs=16)
    rig = bpy.data.objects.new("pencil_rig", None)
    bpy.context.scene.collection.objects.link(rig)
    for ob in (body, tip, band, eraser):
        ob.parent = rig
    # the pencil's axis is local Z; lay it flat along X, then turn it
    rig.rotation_euler = (0, math.radians(90), rot)
    rig.location = (x, y, z + 0.36)


def build(scene):
    E.world(scene, color=(0.03, 0.035, 0.045), strength=1.0)
    table = laminate()
    E.cube("table", (130, 110, 4), (0, 20, -2.0), table, bevel=0.3)
    E.cube("table_edge", (130.4, 110.4, 1.2), (0, 20, -0.9), E.simple("Aluminium band", (0.8, 0.8, 0.78), 0.3, 1.0),
           bevel=0.2)
    E.plane("mat", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.36), mat_grid())
    case = E.simple("Case ABS", ABS, 0.45, Coat_Weight=0.15)
    E.cube("case_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.7), (0, 0, 0), case, bevel=0.3)
    E.rim("rim", W + RIM_T, D + RIM_T, 4.0, RIM_H, RIM_T, case, z0=0.35)
    E.cube("rim_stripe", (W + 2 * RIM_T + 1.2, 0.5, 0.5), (0, -D / 2 - RIM_T - 0.3, 1.7),
           E.simple("Stripe orange", (0.85, 0.3, 0.05), 0.5))
    top = D / 2 + RIM_T
    bot = -D / 2 - RIM_T

    # --- head of the table: CRT terminal + keyboard (keyboard peeks in) ----
    cx, cy = -3.0, top + 22
    E.cube("crt_body", (26, 22, 22), (cx, cy + 3, 11), case, bevel=1.5)
    E.cube("crt_bezel", (22, 1.5, 17), (cx, cy - 8.2, 12.5), E.simple("Bezel", (0.3, 0.29, 0.27), 0.5), bevel=0.8)
    E.sphere("crt_glass", 1.0, (cx, cy - 8.6, 12.5), crt_screen(), subdiv=4, scale=(9.0, 1.0, 7.0))
    E.light(scene, "AREA", "crt_glow", (cx, cy - 10, 12.5), 400, color=(0.3, 1.0, 0.45), size=14,
            target=(cx, 0, 2), shadow=False)
    kx, ky = -1.0, top + 6.4
    E.cube("keyboard", (26, 9, 2), (kx, ky, 1.0), case, bevel=0.4).rotation_euler = (0.06, 0, 0.03)
    keys = E.simple("Keycaps", (0.35, 0.33, 0.3), 0.5)
    for r in range(3):
        for c in range(10):
            E.cube("key", (1.6, 1.6, 0.6), (kx - 10.3 + c * 2.25, ky - 2.4 + r * 2.3, 2.2), keys, bevel=0.15)
    E.cube("key_space", (10, 1.6, 0.6), (kx, ky - 4.1 + 0.1, 2.0), keys, bevel=0.15)

    # --- breakfast, top-left corner: plate, toast crust, crumbs ------------
    plate_m = E.simple("Plate ironstone", (0.88, 0.86, 0.8), 0.25, Coat_Weight=0.6)
    px, py = -W / 2 - 2.5, top + 4.2
    E.cylinder("plate", 7.0, 0.5, (px, py, 0.25), plate_m, segs=64, r2=7.6, bevel=0.15)
    E.cylinder("plate_band", 6.2, 0.05, (px, py, 0.52), E.simple("Plate band", (0.35, 0.5, 0.35), 0.4), segs=64)
    E.cylinder("plate_well", 5.8, 0.06, (px, py, 0.53), plate_m, segs=64)
    crust_m = E.simple("Toast crust", (0.42, 0.22, 0.07), 0.8)
    crust = E.cube("toast_crust", (6.5, 1.2, 0.7), (px + 3.0, py - 1.8, 0.9), crust_m, bevel=0.3)
    crust.rotation_euler = (0, 0, 0.6)
    rng = random.Random(3)
    crumb_m = E.simple("Crumb", (0.62, 0.42, 0.2), 0.8)
    for i in range(46):
        a, rr = rng.uniform(0, 6.28), rng.uniform(2.0, 11.0)
        cxr, cyr = px + 3 + math.cos(a) * rr, py - 3 + math.sin(a) * rr * 0.6
        if abs(cxr) < W / 2 + RIM_T and abs(cyr) < D / 2 + RIM_T:
            continue
        E.rock(f"crumb{i}", rng.uniform(0.08, 0.22), (cxr, cyr, 0.05), crumb_m, seed=i, squash=(1, 1, 0.6),
               subdiv=1, strength=0.3)

    # --- coffee, top-right corner -----------------------------------------
    mug_m = E.simple("Stoneware", (0.32, 0.18, 0.08), 0.35, Coat_Weight=0.8)
    mx, my = W / 2 + 3.4, top + 3.8
    mug = E.cylinder("mug", 4.0, 9.5, (mx, my, 4.75), mug_m, segs=48, bevel=0.3)
    mod = mug.modifiers.new("solid", "SOLIDIFY")
    mod.thickness = 0.45
    E.cylinder("mug_inner", 3.6, 0.1, (mx, my, 7.9), E.simple("Mug glaze", (0.85, 0.8, 0.68), 0.2), segs=48)
    E.cylinder("coffee", 3.58, 0.1, (mx, my, 8.0), E.simple("Coffee", (0.05, 0.02, 0.01), 0.05, Coat_Weight=1.0),
               segs=48)
    P.torus("mug_handle", 2.2, 0.55, (mx + 4.6, my, 5.0), mug_m, rot=(math.radians(90), 0, 0))
    E.cylinder("coaster", 5.2, 0.35, (mx, my, 0.17), E.simple("Cork", (0.55, 0.38, 0.2), 0.9), segs=48)

    # --- morning paper, bottom-left; notebook + pencil, bottom-right -------
    paper = E.plane("newspaper", 24, 16, (-W / 2 + 1.0, bot - 5.2, 0.06), newspaper())
    paper.rotation_euler = (0, 0, math.radians(8))
    fold = E.plane("newspaper_under", 24, 16, (-W / 2 + 0.2, bot - 5.6, 0.03),
                   E.simple("Newsprint back", (0.72, 0.7, 0.64), 0.9))
    fold.rotation_euler = (0, 0, math.radians(3))
    nb_x, nb_y = W / 2 + 1.0, bot - 10.8
    E.cube("notebook_back", (15.2, 20.2, 0.5), (nb_x, nb_y, 0.25), E.simple("Notebook card", (0.2, 0.3, 0.45), 0.7))
    page = E.plane("notebook_page", 14.5, 19.5, (nb_x, nb_y, 0.52), notebook_page())
    page.rotation_euler = (0, 0, 0)
    ring_m = E.simple("Spiral wire", (0.75, 0.75, 0.75), 0.25, 1.0)
    for i in range(18):
        P.torus("spiral", 0.45, 0.07, (nb_x - 7.2 + 0.8 * i + 0.4, nb_y + 9.8, 0.55), ring_m,
                rot=(0, math.radians(90), 0), major_seg=16, minor_seg=6)
    pencil(nb_x - 4.0, nb_y + 7.4, 0.55, length=15.0, rot=math.radians(-14))
    # salt shaker + pocket radio (hero framing, left side)
    E.cylinder("salt", 1.8, 7, (-W / 2 - 7.5, 6, 3.5), P.glass("Shaker glass"), segs=32)
    E.cylinder("salt_cap", 1.85, 1.4, (-W / 2 - 7.5, 6, 7.4), E.simple("Chrome cap", (0.9, 0.9, 0.9), 0.15, 1.0),
               segs=32)
    rx, ry = W / 2 + 10.5, -6.0
    E.cube("radio", (11, 6.5, 3.2), (rx, ry, 1.6), E.simple("Radio leatherette", (0.1, 0.07, 0.05), 0.7), bevel=0.6)
    E.cube("radio_grille", (6.2, 5.0, 0.2), (rx - 1.8, ry, 3.25), E.simple("Grille chrome", (0.8, 0.8, 0.78), 0.3,
                                                                           1.0), bevel=0.1)
    E.cylinder("radio_dial", 1.3, 0.4, (rx + 3.2, ry + 0.8, 3.3), E.simple("Dial cream", (0.9, 0.85, 0.7), 0.4),
               segs=32)

    # --- field instrument + coiled cable (round 1 props) ------------------
    ix, iy = -W / 2 - 13, -10
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
    cable = E.simple("Cable", (0.1, 0.1, 0.1), 0.5)
    for i in range(16):
        P.torus("coil", 1.2, 0.18, (ix + 3, iy + 10 + i * 0.5, 1.4), cable, rot=(math.radians(90), 0, 0),
                major_seg=24, minor_seg=6)

    # --- light: warm pendant over the table (behind the top-down camera),
    # grey-blue dusk from the window ---------------------------------------
    lamp = E.cylinder("lamp_shade", 3.0, 10, (6, 10, 68), E.simple("Lamp shade", (0.85, 0.35, 0.08), 0.5), segs=48,
                      r2=14.0, cap=False)
    lamp.rotation_euler = (math.radians(180), 0, 0)
    E.light(scene, "AREA", "lamp", (6, 10, 62), 30000, color=(1.0, 0.8, 0.55), size=24, target=(0, 0, 0))
    P.backdrop_window(0, top + 80, 45, 90, 70, sky_top=(0.2, 0.25, 0.35), sky_bot=(0.45, 0.45, 0.5), moon=False,
                      frame_mat=E.simple("Window white", (0.8, 0.8, 0.78), 0.5))
    E.light(scene, "AREA", "dusk", (0, top + 75, 45), 8000, color=(0.6, 0.7, 1.0), size=60, target=(0, 0, 0))
    rc = room(scene, table, top)
    return dict(
        samples=128, exposure=0.0, hero=dict(dist=32, elev=30, az=8, lens=65, fstop=2.8),
        topdown=dict(width=W + 2 * RIM_T + 3.0),
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene, table, top):
    """The 1986 countryside kitchen (concept: room-concepts/northfield-room).

    Striped wallpaper, a checkered lino floor, a run of cream kitchen units
    along the left and back walls (worktop, patterned tile splashback, wall
    cupboards, a cooker and a tall fridge), a radiator under the window with
    floral curtains, and outside the grey field with a tree line and a
    strange tall machine. Lights from four sides: the orange pendant over
    the table (warm key, above), the window (grey-blue daylight, back), the
    CRT (green accent, left) and a strip under the wall cupboards (warm,
    back-left).
    """
    wy = top + 80
    paper = RC.wallpaper("Kitchen wallpaper", (0.42, 0.36, 0.22), (0.3, 0.33, 0.2), stripes=0.08)
    RC.shell(half_w=180, back=wy, front=-170, height=250, wall=paper,
             floor=RC.tiles("Kitchen lino", (0.45, 0.4, 0.32), (0.1, 0.12, 0.08), scale=0.03),
             openings={"back": [(0, 45, 90, 70)]}, ceiling=RC.plaster("Kitchen ceiling", (0.5, 0.48, 0.44)))
    white = E.simple("Window white", (0.8, 0.8, 0.78), 0.5)
    RC.window("back", 0, 45, 90, 70, RC.sky("Field sky", (0.2, 0.25, 0.35), (0.45, 0.45, 0.5), strength=0.9),
              white, mullions=(2, 1), glow=(30000, (0.65, 0.72, 0.9)))
    # outside, flat against the grey sky: a tree line and the tall machine
    far = E.emissive("Far silhouette", (0.17, 0.19, 0.24), 1.0)
    rng = random.Random(3)
    for i in range(26):
        h = rng.uniform(4, 9)
        E.cylinder("far_tree", 1.4, h, (-45 + i * 3.6, wy + 28, 45 - 35 + 3 + h / 2), far, segs=6, r2=0.1)
    for a in (-0.25, 0.0, 0.25):
        leg = E.cylinder("machine_leg", 0.25, 26, (22 + a * 20, wy + 28, 45 - 35 + 16), far, segs=6)
        leg.rotation_euler = (0, a * 0.9, 0)
    E.sphere("machine_body", 2.4, (22, wy + 28, 45 - 35 + 30), far, subdiv=2, scale=(1.6, 0.5, 0.7))
    E.sphere("machine_eye", 0.35, (23.5, wy + 27, 45 - 35 + 30), E.emissive("Machine eye", (1.0, 0.1, 0.05), 6.0))
    # radiator under the window, floral curtains either side
    for i in range(14):
        E.cube("radiator_fin", (3, 8, 45), RC.to_world("back", -35 + i * 5.4, (0, -6, RC.FLOOR_Z + 40)), white,
               bevel=0.8)
    cur, k = E.material("Floral curtain")
    obj = k.coords().outputs["Object"]
    v = k.voronoi(RC.vertical_coords(k), 0.08)
    dot = k.math("LESS_THAN", v.outputs["Distance"], 0.25)
    k.surface(k.bsdf(Base_Color=k.mix(dot, (0.7, 0.66, 0.55, 1), (0.25, 0.35, 0.15, 1)), Roughness=0.9,
                     Transmission_Weight=0.2, Sheen_Weight=0.5))
    for sx in (-1, 1):
        c = E.cube("curtain", (30, 3, 110), RC.to_world("back", sx * 62, (0, -8, 52)), cur)
        c.modifiers.new("wave", "WAVE").height = 1.5
    E.cylinder("curtain_rod", 1.0, 170, RC.to_world("back", 0, (0, -8, 110)), P.brass("Rod brass"), segs=12
               ).rotation_euler = (0, math.radians(90), 0)
    # kitchen units: base cabinets + worktop along the left wall, cooker, fridge, wall cupboards
    cream = E.simple("Unit cream", (0.62, 0.58, 0.48), 0.45)
    wood_top = P.dark_wood("Worktop", c1=(0.12, 0.07, 0.035), c2=(0.3, 0.18, 0.09), varnish=0.4)
    for u in (-110, -50, 10):
        RC.cabinet("left", u, w=60, h=86, depth=58, mat=cream, top_mat=wood_top)
        RC.cabinet("left", u, w=60, h=70, depth=34, z0=RC.FLOOR_Z + 150, mat=cream, doors=2)
    stove = RC.cabinet("left", 70, w=60, h=86, depth=60, mat=E.simple("Cooker white", (0.8, 0.79, 0.75), 0.3),
                       doors=1)
    for dx in (-14, 14):
        for dy in (-12, 12):
            p = RC.to_world("left", 70 + dx, (0, -30 + dy, RC.FLOOR_Z + 90.5))
            E.cylinder("hob_ring", 8, 0.8, p, E.simple("Hob iron", (0.03, 0.03, 0.03), 0.4), segs=24)
    E.cylinder("kettle", 9, 18, RC.to_world("left", 76, (0, -32, RC.FLOOR_Z + 100)),
               E.simple("Kettle enamel", (0.7, 0.35, 0.1), 0.25), segs=24, r2=6)
    E.cube("fridge", (62, 65, 170), RC.to_world("left", 140, (0, -34, RC.FLOOR_Z + 85)), cream, bevel=3.0)
    tiles_m = RC.tiles("Splashback tiles", (0.75, 0.55, 0.25), (0.35, 0.2, 0.07), scale=0.07, checker=True)
    back_splash = E.plane("splashback", 240, 60, RC.to_world("left", -20, (0, -1.5, RC.FLOOR_Z + 118)), tiles_m)
    back_splash.rotation_euler = (math.radians(90), 0, math.radians(90))
    RC.wall_shelf("left", -50, RC.FLOOR_Z + 128, w=60, depth=10, seed=5, kind="jars", mat=wood_top,
                  palette=[(0.6, 0.5, 0.3), (0.3, 0.1, 0.05), (0.15, 0.25, 0.1)])
    E.light(scene, "AREA", "under_cupboard", RC.to_world("left", -40, (0, -25, RC.FLOOR_Z + 146)), 6000,
            color=(1.0, 0.8, 0.5), size=90, target=RC.to_world("left", -40, (0, -25, RC.FLOOR_Z + 50)))
    RC.chair(0, 95 - 40, rot=math.radians(180), mat=wood_top, seat_h=46, back_h=40)
    # the pendant's cord up to the ceiling; the CRT's green spills onto the left side
    E.cylinder("lamp_cord", 0.35, 250 - 76 - 73, (6, 10, 73 + (250 - 76 - 73) / 2), E.simple("Cord", (0.9, 0.9, 0.9),
               0.5), segs=6)
    E.light(scene, "AREA", "crt_spill", (-3.0, top + 10, 14), 2500, color=(0.3, 1.0, 0.45), size=20,
            target=(-60, -20, 0), shadow=False)
    return dict(loc=(26, -66, 36), target=(-10, 90, 6), lens=20, fstop=4.0, focus=(0, 0, 2))
