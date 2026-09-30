"""Frostbound environment: "The Frozen Altar".

A frost-rimed granite altar tray in an ice cave: a carved ward-circle in
the floor with faint cold light in its grooves, snow-capped walls, ice
crystal clusters and rime-covered boulders framing the edges, falling snow,
low cold mist and a blue glow through the cave ice behind.
"""
from __future__ import annotations

import math
import random

import bpy
from mathutils import Euler, Matrix, Vector

import env_common as E
import env_props as P
import room_common as RC

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.6, 3.2


def granite(name, snow=0.0, frost_lines=None, size=None, dark=False):
    m, k = E.material(name)
    tc = k.coords()
    obj = tc.outputs["Object"]
    n = k.noise(obj, 0.8, 10, 0.62).outputs["Fac"]
    speck = k.voronoi(obj, 9.0).outputs["Distance"]
    # dark=True: the altar's play field is blue-black slate (round 2), so
    # the clear-ice dice and their glowing numerals separate at top-down
    col = k.ramp(n, [(0.2, (0.02, 0.028, 0.045)), (0.8, (0.06, 0.075, 0.1))] if dark else
                 [(0.2, (0.2, 0.24, 0.3)), (0.8, (0.38, 0.42, 0.5))])
    col = k.mix(k.math("LESS_THAN", speck, 0.08), col, (0.25, 0.28, 0.33, 1))
    nrm = k.bump(n, 0.5, 0.3)
    rough = 0.7
    frost = k.ramp(k.noise(obj, 2.5, 6, 0.6).outputs["Fac"], [(0.5, (0, 0, 0)), (0.72, (1, 1, 1))])
    col = k.mix(k.math("MULTIPLY", frost, 0.1 if dark else 0.35), col, (0.6, 0.7, 0.8, 1))
    emis = (0, 0, 0, 1)
    estr = 0.0
    if frost_lines is not None:
        mp = k.node("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / size, 1 / size, 1)
        mp.inputs["Location"].default_value = (0.5, 0.5, 0)
        k.link(obj, mp.inputs["Vector"])
        tex = k.node("ShaderNodeTexImage", image=frost_lines, extension="CLIP")
        k.link(mp.outputs[0], tex.inputs["Vector"])
        groove = tex.outputs["Color"]
        nrm = k.bump(groove, 0.9, 0.25, normal=nrm, invert=True)
        col = k.mix(groove, col, (0.55, 0.75, 0.95, 1))
        emis = (0.25, 0.6, 1.0, 1)
        estr = k.math("MULTIPLY", groove, 1.6)
    s = k.bsdf(Base_Color=col, Roughness=rough, Normal=nrm, Emission_Color=emis, Emission_Strength=estr)
    if snow:
        geo = k.node("ShaderNodeNewGeometry")
        sep = k.node("ShaderNodeSeparateXYZ")
        k.link(geo.outputs["Normal"], sep.inputs[0])
        cap = k.math("MULTIPLY", k.math("SUBTRACT", sep.outputs["Z"], 0.55), 4.0, clamp=True)
        patch = k.math("MULTIPLY", k.math("SUBTRACT", k.noise(obj, 0.6, 4).outputs["Fac"], 1.0 - snow), 6.0,
                       clamp=True)
        cap = k.math("MULTIPLY", cap, patch)
        snow_s = k.bsdf(Base_Color=(0.9, 0.94, 1.0, 1), Roughness=0.6, Subsurface_Weight=0.6,
                        Subsurface_Radius=(0.6, 0.8, 1.2), Normal=k.bump(k.noise(obj, 4.0, 4).outputs["Fac"], 0.3, 0.2))
        s = k.mix_shader(cap, s, snow_s)
    k.surface(s)
    return m


def ice(name="Cave ice", glow=0.0):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.5, 6).outputs["Fac"]
    s = k.bsdf(Base_Color=(0.6, 0.85, 1.0, 1), Transmission_Weight=1.0, IOR=1.31,
               Roughness=k.math("ADD", k.math("MULTIPLY", n, 0.2), 0.03),
               Normal=k.bump(k.noise(obj, 2.0, 5).outputs["Fac"], 0.25, 0.3))
    if glow:
        s = k.add_shader(s, k.emission((0.2, 0.6, 1.0, 1), k.math("MULTIPLY", k.math("POWER", n, 3.0), glow)))
    k.surface(s)
    vol = k.node("ShaderNodeVolumeAbsorption")
    k.set(vol, Color=(0.55, 0.85, 1.0, 1), Density=0.05)
    k.volume(vol.outputs[0])
    return m


def crystal_cluster(x, y, z, n, seed, mat, scale=1.0):
    rng = random.Random(seed)
    for i in range(n):
        h = rng.uniform(4, 13) * scale
        r = h * rng.uniform(0.1, 0.16)
        body = E.cylinder("crystal", r, h, (0, 0, h / 2), mat, segs=6, cap=True)
        tip = E.cylinder("crystal_tip", r, r * 2.2, (0, 0, h + r * 1.1), mat, segs=6, r2=0.0)
        tilt = (rng.uniform(-0.55, 0.55), rng.uniform(-0.55, 0.55), rng.uniform(0, 6.28))
        base = Vector((x + rng.uniform(-1.5, 1.5) * scale, y + rng.uniform(-1.5, 1.5) * scale, z - 0.5))
        R = Euler(tilt).to_matrix().to_4x4()
        for ob in (body, tip):
            ob.data.set_sharp_from_angle(angle=math.radians(20))
            ob.matrix_world = Matrix.Translation(base) @ R @ Matrix.Translation(ob.location)


def build(scene):
    E.world(scene, color=(0.004, 0.008, 0.018), strength=1.0)
    size = W + 2 * RIM_T
    circle = P.mask_texture("frost_circle", P.sigil_strokes(seed=21, points=6, runes=24,
                                                            rings=(0.47, 0.455, 0.37, 0.18), w=0.0035),
                            E.TMP)
    E.plane("altar_floor", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.01),
            granite("Altar granite", frost_lines=circle, size=W * 0.95, dark=True))
    E.cube("altar_block", (W + 30, D + 26, 14), (0, 0, -7.0), granite("Altar block", snow=0.6), bevel=1.2)
    prof = E.profile_curve("altar_rim_profile", [(-1.3, -1.6), (1.3, -1.6), (1.3, 0.9), (0.8, 1.6),
                                                 (-0.8, 1.6), (-1.3, 0.9)])
    E.rim("altar_rim", W + RIM_T, D + RIM_T, 2.5, RIM_H, RIM_T, granite("Rim granite", snow=0.8), profile=prof)
    # ground: snow drifts over rock
    snow_m, k = E.material("Snow")
    obj = k.coords().outputs["Object"]
    k.surface(k.bsdf(Base_Color=(0.8, 0.86, 0.95, 1), Roughness=0.55, Subsurface_Weight=0.7,
                     Subsurface_Radius=(0.6, 0.9, 1.4),
                     Normal=k.bump(k.noise(obj, 0.3, 6).outputs["Fac"], 0.5, 1.0)))
    ground = E.plane("snow_ground", 500, 500, (0, 0, -14), snow_m, subdiv=60)
    for poly in ground.data.polygons:
        poly.use_smooth = True
    ground.modifiers.new("smooth", "SUBSURF").levels = 1
    tex = bpy.data.textures.new("drift", "CLOUDS")
    tex.noise_scale = 25.0
    dm = ground.modifiers.new("drift", "DISPLACE")
    dm.texture = tex
    dm.strength = 6.0
    # boulders + crystals framing the altar
    rock_m = granite("Boulder", snow=0.7)
    ice_m = ice("Crystal ice", glow=6.0)
    rng = random.Random(3)
    for i, (x, y, r) in enumerate(((-24, 30, 9), (22, 34, 11), (-24, -8, 7), (23, 4, 8), (-20, -30, 6),
                                   (21, -27, 7), (0, 40, 10))):
        E.rock(f"boulder{i}", r, (x, y, -8 + r * 0.3), rock_m, seed=i + 40, squash=(1.2, 1, 0.8))
    crystal_cluster(-W / 2 - 8, D / 2 + 6, 0.3, 9, 1, ice_m, 1.0)
    crystal_cluster(W / 2 + 8, D / 2 + 7, 0.3, 7, 2, ice_m, 0.85)
    crystal_cluster(W / 2 + 9, -D / 2 - 3, 0.3, 5, 3, ice_m, 0.6)
    crystal_cluster(-W / 2 - 9, -D / 2 - 5, 0.3, 4, 4, ice_m, 0.5)
    crystal_cluster(-W / 2 - 10, 2, 0.3, 3, 5, ice_m, 0.45)
    # low shards in the strips above/below the tray (read at top-down)
    crystal_cluster(-W / 2 + 1.5, D / 2 + RIM_T + 3.4, 0.3, 4, 11, ice_m, 0.28)
    crystal_cluster(W / 2 - 1.0, -D / 2 - RIM_T - 3.2, 0.3, 5, 12, ice_m, 0.3)
    crystal_cluster(W / 2 + 1.5, D / 2 + RIM_T + 4.0, 0.3, 3, 13, ice_m, 0.22)
    # cave wall of ice behind
    for i, (x, y, r) in enumerate(((-150, 215, 60), (150, 225, 70), (190, 120, 55), (-195, 110, 50))):  # flank the hall arch
        E.rock(f"ice_wall{i}", r, (x, y, 10), ice("Cave wall ice", glow=1.2), seed=99 + i, squash=(1.0, 0.7, 1.4),
               strength=0.45)
    E.light(scene, "AREA", "cave_glow", (0, 260, 40), 90000, color=(0.25, 0.55, 1.0), size=120,
            target=(0, 100, 10), shadow=False)
    # crystals glow
    for x, y in ((-W / 2 - 8, D / 2 + 6), (W / 2 + 8, D / 2 + 7)):
        E.light(scene, "POINT", "crystal_light", (x, y, 8), 1800, color=(0.3, 0.65, 1.0), size=3)
    # moon key + soft cold fill; a very faint warm bounce keeps it from going monochrome
    E.light(scene, "AREA", "moon_key", (-20, -18, 60), 9000, color=(0.75, 0.85, 1.0), size=25, target=(0, 0, 0))
    E.light(scene, "AREA", "fill", (25, -45, 15), 700, color=(0.55, 0.65, 1.0), size=30, target=(0, 0, 2))
    E.light(scene, "AREA", "warm_bounce", (0, -60, 5), 150, color=(1.0, 0.75, 0.55), size=40, target=(0, 0, 0))
    # atmosphere: falling snow + ground mist
    flake = E.simple("Snowflake", (0.95, 0.97, 1.0), 0.5, Emission_Color=(0.8, 0.9, 1.0, 1),
                     Emission_Strength=0.6)
    E.scatter("snow", 700, ((-60, -60, 1), (60, 90, 70)), 0.09, flake, seed=8, scale_range=(0.4, 1.2),
              avoid=lambda p: abs(p.x) < W / 2 + 4 and abs(p.y) < D / 2 + 6)  # none between camera and dice
    E.haze_box("mist", (170, 200, 12), (0, 20, -8), 0.02, color=(0.8, 0.9, 1.0), essential=True)
    E.haze_box("air", (160, 220, 80), (0, 30, 45), 0.0015, color=(0.7, 0.85, 1.0))
    rc = room(scene, ice_m)
    return dict(
        samples=160, exposure=0.2, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=26, az=10, lens=70, fstop=2.8),
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene, ice_m):
    """The frozen altar chamber (concept: room-concepts/frostbound-room).

    A pillared hall of frost-rimed stone on the snow floor, a tall arch at the
    back open onto a glacier valley at dusk, ice formations along the walls,
    icicles, deep-blue banners. Lights from four sides: two fire bowls
    (warm key, front-left and right), the arch (cool sky fill from the back),
    blue ice glows at the sides (accent rim), plus the tray's moon key.
    """
    wall = RC.stone("Frost stone", (0.09, 0.11, 0.14), (0.28, 0.32, 0.38), scale=0.012)
    RC.shell(half_w=230, back=260, front=-170, height=330, wall=wall, floor=False, floor_z=-14.0,
             openings={"back": [(0, 96, 150, 220)]})
    glacier = RC.sky("Glacier dusk", (0.12, 0.25, 0.55), (0.55, 0.72, 0.95), stars=1.5, strength=0.55,
                     skyline=((0.16, 0.24, 0.38), 0.45, False))
    RC.window("back", 0, 96, 150, 220, glacier, wall, mullions=(1, 1), sill=False,
              glow=(90000, (0.55, 0.72, 1.0)))
    col_m = granite("Pillar granite", snow=0.5)
    for sx in (-1, 1):
        for y in (20, 150):
            RC.column(sx * 125, y, 330, 17, col_m)
    # warm key: fire bowls on carved pedestals, front-left and back-right
    ped = granite("Pedestal granite", snow=0.4)
    RC.fire_bowl(scene, -75, -25, 45, r=16, energy=45000, pedestal=ped, seed=1)
    RC.fire_bowl(scene, 85, 95, 50, r=16, energy=35000, pedestal=ped, seed=2)
    RC.fire_bowl(scene, -110, 215, 60, r=14, energy=30000, pedestal=ped, seed=3)
    # deep-blue banners with a gold lattice between the pillars
    for u in (-150, 150):
        RC.banner("back", u, 250, w=60, h=170, color=(0.02, 0.04, 0.16), trim=(0.55, 0.42, 0.2), pattern=True)
    # ice formations along the side walls, glowing blue: the accent rim
    wall_ice = ice("Hall ice", glow=0.5)
    for i, (x, y, r) in enumerate(((-200, 60, 45), (-190, 170, 55), (200, 20, 50), (195, 140, 45),
                                   (-205, -60, 35), (205, -80, 40))):
        E.rock(f"hall_ice{i}", r, (x, y, -14 + r * 0.6), wall_ice, seed=200 + i, squash=(0.6, 1.0, 1.8),
               strength=0.4)
    for sx in (-1, 1):
        E.light(scene, "AREA", "ice_glow", (sx * 175, 60, 60), 9000, color=(0.25, 0.6, 1.0), size=80,
                target=(0, 0, 0), shadow=False)
    # icicles along the arch lintel and the wall tops
    rng = random.Random(9)
    for i in range(40):
        x = rng.uniform(-220, 220)
        y = 250 if abs(x) > 80 else 252
        z_top = 316 - 14 if abs(x) > 80 else 96 + 110 - 14 + 14
        L = rng.uniform(10, 45)
        E.cylinder("icicle", 0.05, L, (x, y - rng.uniform(0, 6), z_top - L / 2), ice_m, segs=6,
                   r2=rng.uniform(1.0, 2.5))
    return dict(loc=(16, -62, 50), target=(-4, 80, 4), lens=16, fstop=4.0, focus=(0, 0, 2))

