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
import room_common as RC

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
    E.plane("map", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.36), P.parchment("Travel map", tone=((0.05, 0.034, 0.018), (0.075, 0.05, 0.027), (0.09, 0.062, 0.034)),
                                                             ink_color=(0.3, 0.22, 0.12), ink_amount=0.18, grain=0.5), subdiv=1)
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
    rc = room(scene, table, top)
    return dict(
        samples=128, exposure=0.9, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=30, az=-6, lens=65, fstop=2.8),
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene, table, top):
    """The wayfarer's inn corner (concept: room-concepts/oldroad-room).

    Timber-and-plaster walls, a small window at the back onto the blue hour,
    a fieldstone hearth on the right wall with a fur-covered stool before it,
    a travel pack on a chair and a walking staff leaning on the table, a
    barrel and a shelf of mugs and jugs. Lights from four sides: the tin
    lantern on the table (warm key, left), the hearth (warm side light,
    right), the window (cool dusk, back) and a candle on the side table
    (back-right); plus the tray's overhead and warm key.
    """
    wy = top + 75
    wall = RC.plaster("Inn plaster", (0.3, 0.24, 0.17))
    timber = P.dark_wood("Inn timber", c1=(0.03, 0.017, 0.008), c2=(0.09, 0.05, 0.022), rough=0.8, varnish=0.0)
    RC.shell(half_w=170, back=wy, front=-180, height=240, wall=wall, floor=RC.planks("Inn floor"),
             openings={"back": [(0, 45, 70, 80)]})
    RC.half_timber("back", (-165, -60, 60, 165), timber, rails=(RC.FLOOR_Z + 95,))
    RC.half_timber("left", (-150, -40, 70), timber, rails=(RC.FLOOR_Z + 95,))
    RC.half_timber("right", (-150, 70), timber, rails=(RC.FLOOR_Z + 170,), braces=False)
    RC.beams(timber, n=3, size=(18, 22))
    dusk = RC.sky("Inn dusk", (0.03, 0.06, 0.18), (0.35, 0.22, 0.3), strength=0.8, skyline=((0.02, 0.025, 0.05), 0.3))
    RC.window("back", 0, 45, 70, 80, dusk, timber, mullions=(1, 1), sill=True, glow=(18000, (0.55, 0.55, 1.0)))
    RC.work_table(200, 150, top_z=0.0, thick=6.0, mat=table, leg_r=7, y=20, top=False)
    RC.fireplace(scene, "right", -30, w=120, h=110, depth=45, energy=130000, seed=7,
                 mat=RC.stone("Inn fieldstone", (0.1, 0.085, 0.07), (0.26, 0.22, 0.17), scale=0.03))
    fur = E.simple("Stool fur", (0.25, 0.2, 0.15), 0.95, Sheen_Weight=1.0)
    E.cube("stool_seat", (40, 34, 6), (105, -40, RC.FLOOR_Z + 40), timber, bevel=0.8)
    for sx in (-1, 1):
        for sy in (-1, 1):
            E.cube("stool_leg", (4, 4, 38), (105 + sx * 16, -40 + sy * 13, RC.FLOOR_Z + 19), timber)
    E.rock("stool_fur", 22, (105, -40, RC.FLOOR_Z + 46), fur, seed=8, squash=(1.0, 0.85, 0.25), strength=0.25)
    # the travel pack on a chair behind the table, the staff leaning on the table edge
    RC.chair(60, 115, rot=math.radians(180), mat=timber)
    pack = leather("Pack canvas", (0.12, 0.1, 0.06))
    E.rock("pack", 22, (60, 110, RC.FLOOR_Z + 68), pack, seed=11, squash=(0.9, 0.6, 1.3), strength=0.15)
    E.cylinder("bedroll", 9, 44, (60, 110, RC.FLOOR_Z + 98), E.simple("Bedroll wool", (0.12, 0.14, 0.08), 0.9),
               segs=24).rotation_euler = (0, math.radians(90), 0)
    for sx in (-1, 1):
        E.cube("pack_strap", (3, 0.6, 40), (60 + sx * 10, 96, RC.FLOOR_Z + 70), leather("Pack strap"))
    staff = E.cylinder("staff", 2.0, 170, (95, 60, RC.FLOOR_Z + 82), timber, segs=12, r2=1.4)
    staff.rotation_euler = (math.radians(8), math.radians(-12), 0)
    RC.barrel(-140, 110, r=24, h=80, mat=timber)
    RC.wall_shelf("left", 40, 55, w=120, seed=21, kind="jars",
                  palette=[(0.25, 0.15, 0.08), (0.3, 0.28, 0.25), (0.12, 0.08, 0.05)], mat=timber)
    # side table with a candle, back-right
    E.cube("side_table", (45, 45, 4), (130, 120, RC.FLOOR_Z + 72), timber, bevel=0.5)
    E.cylinder("side_table_leg", 3, 70, (130, 120, RC.FLOOR_Z + 35), timber, segs=12)
    P.candle(scene, 130, 120, RC.FLOOR_Z + 74, h=10, r=1.8, seed=9, light=False)
    E.light(scene, "POINT", "side_candle", (130, 120, RC.FLOOR_Z + 90), 4000, color=(1.0, 0.6, 0.3), size=2)
    RC.rug(0, -40, 240, 160, (0.3, 0.08, 0.05), (0.12, 0.05, 0.03), name="Inn rug")
    return dict(loc=(18, -70, 40), target=(-2, 90, 4), lens=20, fstop=4.0, focus=(0, 0, 2))
