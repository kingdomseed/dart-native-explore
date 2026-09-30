"""Gemcutter environment: "The Jeweler's Bench".

A deep-teal velvet jeweler's tray with a padded rim on a walnut bench,
under a cool daylight bench lamp. Around it: a brass loupe, fine tweezers,
glass-lidded gem cases with loose cut stones, folded gem papers and a small
brass balance. Everything polished, so the swirled gems catch highlights.
"""
from __future__ import annotations

import math
import random

import bmesh
from mathutils import Vector

import env_common as E
import env_props as P
import room_common as RC

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.8, 2.6


def gem(name, r, loc, mat, seed):
    """A brilliant-ish cut stone: an 8-sided crown + pavilion."""
    bm = bmesh.new()
    top = [bm.verts.new((0.55 * r * math.cos(a), 0.55 * r * math.sin(a), 0.35 * r))
           for a in [i * math.pi / 4 for i in range(8)]]
    girdle = [bm.verts.new((r * math.cos(a), r * math.sin(a), 0.0)) for a in [i * math.pi / 8 for i in range(16)]]
    culet = bm.verts.new((0, 0, -0.9 * r))
    bm.faces.new(top)
    for i in range(8):
        a, b = top[i], top[(i + 1) % 8]
        g0, g1, g2 = girdle[2 * i], girdle[2 * i + 1], girdle[(2 * i + 2) % 16]
        bm.faces.new((a, g0, g1))
        bm.faces.new((a, g1, b))
        bm.faces.new((b, g1, g2))
    for i in range(16):
        bm.faces.new((girdle[(i + 1) % 16], girdle[i], culet))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    ob = E.mesh_object(name, bm, mat)
    rng = random.Random(seed)
    ob.location = loc
    ob.rotation_euler = (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), rng.uniform(0, 6))
    return ob


def build(scene):
    E.world(scene, color=(0.02, 0.022, 0.025), strength=1.0)
    E.cube("bench", (200, 150, 6), (0, 20, -3.0), P.dark_wood("Walnut bench", c1=(0.05, 0.025, 0.012),
                                                            c2=(0.16, 0.08, 0.04), varnish=0.7), bevel=0.5)
    # Round 2: jeweler's dove-grey velvet (round 1's deep teal matched the
    # emerald dice at top-down)
    vel = P.velvet("Grey velvet", color=(0.42, 0.43, 0.43), stars=False)
    E.plane("velvet", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.41), vel)
    E.cube("tray_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.8), (0, 0, 0),
           P.dark_wood("Tray walnut", varnish=0.9), bevel=0.3)
    E.rim("rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, vel, z0=0.4)
    top = D / 2 + RIM_T
    brass = P.brass("Bench brass", worn=0.3)
    # loupe
    bot = -D / 2 - RIM_T
    lx, ly = W / 2 - 1.5, bot - 3.4  # bottom-right strip of the phone frame
    P.torus("loupe_ring", 2.4, 0.4, (lx, ly, 0.5), brass)
    E.cylinder("loupe_lens", 2.2, 0.3, (lx, ly, 0.5), P.glass("Loupe lens", ior=1.6), segs=48)
    E.cylinder("loupe_barrel", 2.6, 2.2, (lx, ly, 1.6), E.simple("Loupe black", (0.02, 0.02, 0.02), 0.4),
               segs=48, r2=2.2)
    # tweezers
    steel = E.simple("Tweezer steel", (0.8, 0.8, 0.82), 0.2, 1.0)
    for i, a in enumerate((0.04, -0.04)):
        t = E.cube("tweezer", (0.5, 13, 0.2), (-3.0 + i * 0.6, bot - 3.0, 0.3), steel, bevel=0.05)
        t.rotation_euler = (0, 0, 1.5 + a)
    # gem cases
    rng = random.Random(3)
    colors = [(0.02, 0.5, 0.2), (0.6, 0.02, 0.08), (0.05, 0.15, 0.7), (0.9, 0.7, 0.1), (0.5, 0.1, 0.6)]
    for c in range(2):
        cx, cy = -W / 2 - 12, 10 - c * 20
        E.cube("case", (12, 14, 2.4), (cx, cy, 1.2), E.simple("Case black", (0.02, 0.02, 0.025), 0.3,
                                                             Coat_Weight=0.5), bevel=0.3)
        E.cube("case_lid", (11.2, 13.2, 0.3), (cx, cy, 2.55), P.glass("Case lid"), bevel=0.1)
        E.plane("case_velvet", 11, 13, (cx, cy, 2.41), P.velvet("Case velvet", color=(0.9, 0.9, 0.88), stars=False))
        for i in range(6):
            col = colors[(i + c) % len(colors)]
            gm = P.glass(f"Gem {i}{c}", color=col, rough=0.0, ior=1.7)
            gem(f"gem{c}{i}", rng.uniform(0.7, 1.1), (cx - 3 + (i % 2) * 6, cy - 4 + (i // 2) * 4, 3.2), gm,
                seed=i * 7 + c)
    # loose stones on a gem paper
    P.paper(-W / 2 + 3.0, top + 3.8, 0.0, 12, 12, rot=0.5, mat=E.simple("Gem paper", (0.92, 0.92, 0.95), 0.7),
            curl=0.3)
    for i in range(4):
        gem(f"loose{i}", 0.8, (-W / 2 + 1.0 + i * 1.8, top + 2.6 + (i % 2) * 1.5, 0.9),
            P.glass(f"Loose {i}", color=colors[i], ior=1.7), seed=40 + i)
    # small balance
    bx, by = -8, top + 14
    E.cylinder("balance_base", 4.5, 1.2, (bx, by, 0.6), P.dark_wood("Balance base"), segs=48, bevel=0.2)
    E.cylinder("balance_post", 0.4, 14, (bx, by, 7.8), brass, segs=16)
    beam = E.cylinder("balance_beam", 0.25, 16, (bx, by, 14.5), brass, segs=12)
    beam.rotation_euler = (0, math.radians(90), 0)
    for sx in (-1, 1):
        E.cylinder("balance_pan", 2.8, 0.4, (bx + sx * 7.5, by, 8.5), brass, segs=40, r2=3.2)
    # bench lamp
    E.cylinder("lamp_head", 5.5, 4, (12, top + 18, 40), E.simple("Lamp enamel", (0.05, 0.25, 0.25), 0.4),
               segs=48, r2=7.0, cap=False).rotation_euler = (math.radians(200), 0, 0)
    E.light(scene, "AREA", "bench_lamp", (12, top + 14, 36), 20000, color=(0.95, 0.97, 1.0), size=10,
            target=(0, 0, 0))
    E.light(scene, "AREA", "fill", (-35, -45, 35), 10000, color=(1.0, 0.85, 0.7), size=40, target=(0, 0, 0))
    E.overhead(scene, 9000, color=(0.95, 0.97, 1.0), size=90, height=110)  # gold enamel reads top-down
    E.light(scene, "AREA", "rim", (30, 60, 20), 2000, color=(0.7, 0.9, 1.0), size=30, target=(0, 0, 2))
    rc = room(scene, top)
    return dict(
        samples=128, exposure=0.5, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=30, az=-8, lens=65, fstop=2.8),
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene, top):
    """The jeweler's workshop (concept: room-concepts/gemcutter-room).

    Dark panelled walls, a tall window at the back-right onto a spired city
    at sunset, a many-drawered gem chest and a tool rack on the right, glass
    display shelves of cut stones on the left, a brass balance on the bench.
    Lights from four sides: the bench lamp (cool white key, from the back,
    now on a proper arm), the sunset window (warm orange, back-right), an
    emerald-glass lamp on the gem chest (green accent, right) and a brass
    wall lamp on the left (warm); plus the tray's fill, overhead and rim.
    """
    panel = P.dark_wood("Atelier panel", c1=(0.025, 0.014, 0.01), c2=(0.07, 0.04, 0.025), varnish=0.5)
    walnut = P.dark_wood("Atelier walnut", c1=(0.05, 0.025, 0.012), c2=(0.16, 0.08, 0.04), varnish=0.7)
    brass = P.brass("Atelier brass", worn=0.4)
    RC.shell(half_w=180, back=150, front=-180, height=260, wall=panel, floor=RC.planks("Atelier floor"),
             openings={"back": [(70, 80, 110, 170)]})
    RC.work_table(200, 150, top_z=0.0, thick=6.0, mat=walnut, leg_r=6, y=20, top=False)
    sunset = RC.sky("Atelier sunset", (0.1, 0.1, 0.3), (1.0, 0.55, 0.25), strength=0.9,
                    skyline=((0.03, 0.025, 0.05), 0.35))
    RC.window("back", 70, 80, 110, 170, sunset, brass, mullions=(3, 4), bar=1.2,
              glow=(35000, (1.0, 0.62, 0.35)))
    # the bench lamp's arm (its head and light come from the tray environment)
    E.cylinder("lamp_arm", 0.8, 42, (12, top + 22, 20), brass, segs=12)
    E.cylinder("lamp_base", 6, 2, (12, top + 22, 1), brass, segs=32)
    # a many-drawered gem chest on the right with an emerald lamp on it
    chest = RC.cabinet("right", 60, w=90, h=110, depth=45, mat=walnut, top_mat=walnut, doors=1)
    knob = E.simple("Drawer brass", (0.8, 0.6, 0.3), 0.3, 1.0)
    for i in range(4):
        for j in range(6):
            p = RC.to_world("right", 60 - 33 + i * 22, (0, -46, RC.FLOOR_Z + 14 + j * 16))
            E.cube("drawer_front", (1.2, 20, 14), p, walnut, bevel=0.3)
            E.sphere("drawer_knob", 1.0, p + Vector((-1.5, 0, 0)), knob, subdiv=1)
    lp = RC.to_world("right", 60, (0, -25, RC.FLOOR_Z + 112))
    E.cube("emerald_lamp", (14, 14, 24), (lp.x, lp.y, lp.z + 14), P.glass("Emerald lamp glass",
           color=(0.2, 0.9, 0.4), rough=0.15)).visible_shadow = False
    E.cylinder("emerald_lamp_cap", 9, 5, (lp.x, lp.y, lp.z + 28), brass, segs=4, r2=2)
    E.sphere("emerald_core", 4, (lp.x, lp.y, lp.z + 13), E.emissive("Emerald glow", (0.1, 1.0, 0.35), 8.0))
    E.light(scene, "POINT", "emerald_light", (lp.x, lp.y, lp.z + 13), 12000, color=(0.2, 1.0, 0.4), size=6,
            shadow=False)
    # tool rack on the right wall: pliers, files and gravers standing in a block
    rng = random.Random(33)
    steel = E.simple("Tool steel", (0.6, 0.6, 0.62), 0.25, 1.0)
    for i in range(16):
        p = RC.to_world("right", -20 + i * 4, (0, -6, RC.FLOOR_Z + 150 + rng.uniform(-4, 4)))
        E.cylinder("tool", 0.5, rng.uniform(16, 26), p, steel, segs=8)
    E.cube("tool_rack", (6, 70, 4), RC.to_world("right", 10, (0, -6, RC.FLOOR_Z + 142)), walnut)
    # glass display shelves of cut stones on the left wall
    gem_cols = [(0.1, 0.8, 0.3), (0.8, 0.1, 0.15), (0.15, 0.3, 0.9), (0.9, 0.9, 0.95), (0.7, 0.5, 0.1)]
    for j, z in enumerate((RC.FLOOR_Z + 110, RC.FLOOR_Z + 150, RC.FLOOR_Z + 190)):
        E.cube("display_shelf", (30, 160, 2), RC.to_world("left", 30, (0, -15, z)), P.glass("Shelf glass"))
        for i in range(8):
            p = RC.to_world("left", -40 + i * 20, (0, -15, z + 4))
            E.sphere("display_gem", 2.8, p, P.glass(f"Gem {j} {i}", color=gem_cols[(i + j) % 5], ior=1.7),
                     subdiv=1, scale=(1, 1, 0.8))
    RC.sconce(scene, "left", -60, 90, energy=12000, mat=brass)
    # a brass balance on the bench, behind-left of the tray
    bx, by = -45, 70
    E.cylinder("balance_base", 7, 2, (bx, by, 1), brass, segs=32)
    E.cylinder("balance_post", 0.8, 34, (bx, by, 18), brass, segs=12)
    E.cube("balance_beam", (36, 1, 1), (bx, by, 35), brass)
    for sx in (-1, 1):
        for a in range(3):
            ang = a * 2.09
            ch = E.cylinder("balance_chain", 0.15, 16, (bx + sx * 17 + math.cos(ang) * 2.5, by + math.sin(ang) * 2.5,
                                                        27), brass, segs=4)
        E.cylinder("balance_pan", 6, 1, (bx + sx * 17, by, 19), brass, segs=32, r2=4)
    return dict(loc=(-20, -72, 42), target=(18, 100, 6), lens=20, fstop=4.0, focus=(0, 0, 2))
