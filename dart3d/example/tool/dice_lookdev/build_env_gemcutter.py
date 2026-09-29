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

import env_common as E
import env_props as P

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
    vel = P.velvet("Teal velvet", color=(0.005, 0.06, 0.06), stars=False)
    E.plane("velvet", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.4), vel)
    E.cube("tray_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.8), (0, 0, 0),
           P.dark_wood("Tray walnut", varnish=0.9), bevel=0.3)
    E.rim("rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, vel, z0=0.4)
    top = D / 2 + RIM_T
    brass = P.brass("Bench brass", worn=0.3)
    # loupe
    P.torus("loupe_ring", 2.4, 0.4, (W / 2 + 9, -4, 0.5), brass)
    E.cylinder("loupe_lens", 2.2, 0.3, (W / 2 + 9, -4, 0.5), P.glass("Loupe lens", ior=1.6), segs=48)
    E.cylinder("loupe_barrel", 2.6, 2.2, (W / 2 + 9, -4, 1.6), E.simple("Loupe black", (0.02, 0.02, 0.02), 0.4),
               segs=48, r2=2.2)
    # tweezers
    steel = E.simple("Tweezer steel", (0.8, 0.8, 0.82), 0.2, 1.0)
    for i, a in enumerate((0.04, -0.04)):
        t = E.cube("tweezer", (0.5, 13, 0.2), (W / 2 + 13 + i * 0.6, 8, 0.3), steel, bevel=0.05)
        t.rotation_euler = (0, 0, 0.3 + a)
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
    P.paper(W / 2 + 12, top + 2, 0.0, 12, 12, rot=0.5, mat=E.simple("Gem paper", (0.92, 0.92, 0.95), 0.7),
            curl=0.3)
    for i in range(4):
        gem(f"loose{i}", 0.8, (W / 2 + 11 + i * 1.8, top + 1 + (i % 2) * 1.5, 0.9),
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
    E.light(scene, "AREA", "fill", (-40, -40, 40), 1500, color=(1.0, 0.85, 0.7), size=40, target=(0, 0, 0))
    E.light(scene, "AREA", "rim", (30, 60, 20), 2000, color=(0.7, 0.9, 1.0), size=30, target=(0, 0, 2))
    return dict(
        samples=128, exposure=0.8, hero=dict(dist=32, elev=30, az=-8, lens=65, fstop=2.8),
        roll=dict(settled={"d12": ((-4.5, -7.0), 12, 20), "d6": ((5.5, -3.0), 6, -10), "d10t": ((-2.0, 4.0), 0, 30),
                           "d4": ((6.0, 9.0), 4, 0)},
                  airborne={"d20": ((0.5, -2.5, 3.0), (1.2, 2.5, 0.2)), "d8": ((-5.5, 7.0, 5.0), (2.0, -1.0, -0.5)),
                            "d10u": ((4.0, 14.0, 2.2), (-1.5, -2.0, 0.3))}),
    )
