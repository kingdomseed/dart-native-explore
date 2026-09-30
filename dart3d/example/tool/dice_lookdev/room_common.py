"""Game rooms around the trays (look-dev round 4): architecture + furniture helpers.

Units are cm like everything else. The tray sits on a table/desk whose top
is z = 0; the room floor is at FLOOR_Z. The top-down phone camera never
sees the room (only its light); the room is for the cinematic intro's
establishing shot (`render_set.py --shots room`) and for multi-directional,
motivated light on the tray.

Every piece is procedural and original (no text, no logos).
"""
from __future__ import annotations

import math
import random

import bmesh
import bpy
from mathutils import Vector

import env_common as E
import env_props as P

FLOOR_Z = -76.0


# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------

def stone(name="Stone", c1=(0.06, 0.055, 0.05), c2=(0.16, 0.14, 0.12), scale=0.04, blocks=True, rough=0.85):
    """Coursed stone / brick (brick texture + noise), or rubble if blocks=False."""
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.2, 8, 0.6).outputs["Fac"]
    col = k.ramp(n, [(0.3, c1), (0.7, c2)])
    nrm = k.bump(n, 0.4, 0.5)
    if blocks:
        b = k.node("ShaderNodeTexBrick")
        k.link(obj, b.inputs["Vector"])
        k.set(b, Scale=scale, Mortar_Size=0.015, Color1=(1, 1, 1, 1), Color2=(0.8, 0.8, 0.8, 1),
              Mortar=(0.2, 0.2, 0.2, 1))
        col = k.mix(0.9, col, b.outputs["Color"], "MULTIPLY")
        nrm = k.bump(b.outputs["Fac"], 0.8, 1.2, normal=nrm)
    k.surface(k.bsdf(Base_Color=col, Roughness=rough, Normal=nrm))
    return m


def plaster(name="Plaster", color=(0.3, 0.26, 0.2)):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.05, 6, 0.6).outputs["Fac"]
    col = k.mix(k.math("MULTIPLY", n, 0.4), (*color, 1), tuple(c * 0.6 for c in color) + (1,))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.9, Normal=k.bump(k.noise(obj, 0.8, 4).outputs["Fac"], 0.1, 0.3)))
    return m


def planks(name="Floor planks", c1=(0.04, 0.02, 0.01), c2=(0.12, 0.065, 0.03)):
    return P.dark_wood(name, scale=0.03, c1=c1, c2=c2, rough=0.6, varnish=0.25)


# --------------------------------------------------------------------------
# Architecture
# --------------------------------------------------------------------------

def shell(half_w=220, back=260, front=-160, height=300, wall=None, floor=None, ceiling=None, side_walls=True):
    """Floor, back wall and (optionally) side walls and ceiling. The front is open."""
    wall = wall or plaster()
    floor = floor or planks()
    E.plane("room_floor", 2 * half_w, back - front, (0, (back + front) / 2, FLOOR_Z), floor)
    bw = E.plane("wall_back", 2 * half_w, height, (0, back, FLOOR_Z + height / 2), wall)
    bw.rotation_euler = (math.radians(90), 0, 0)
    if side_walls:
        for sx in (-1, 1):
            sw = E.plane("wall_side", back - front, height, (sx * half_w, (back + front) / 2, FLOOR_Z + height / 2),
                         wall)
            sw.rotation_euler = (math.radians(90), 0, math.radians(90))
    if ceiling:
        E.plane("ceiling", 2 * half_w, back - front, (0, (back + front) / 2, FLOOR_Z + height), ceiling)


def sky(name, top, bottom, stars=0.0, moon=None, nebula=None):
    """Emissive night sky material for window/arch openings."""
    m, k = E.material(name)
    tc = k.coords().outputs["Generated"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(tc, sep.inputs[0])
    col = k.ramp(sep.outputs["Y"], [(0.0, bottom), (1.0, top)])
    em = k.emission(col, 1.0)
    if nebula:
        obj = k.coords().outputs["Object"]
        n = k.noise(obj, 0.012, 8, 0.65, dist=1.0).outputs["Fac"]
        neb = k.ramp(n, [(0.45, (0, 0, 0)), (0.62, nebula[0]), (0.75, nebula[1])])
        em = k.add_shader(em, k.emission(neb, 1.4))
    if stars:
        st = k.math("LESS_THAN", k.voronoi(tc, 260.0).outputs["Distance"], 0.045)
        em = k.add_shader(em, k.emission((1, 1, 1, 1), k.math("MULTIPLY", st, stars)))
    k.surface(em)
    return m


def window(x, y, z, w, h, sky_mat, frame_mat, mullions=(3, 2), depth=14, arch=False, moon=None):
    """A window in a wall at y (facing -y): an emissive sky card set behind a frame."""
    card = E.plane("window_sky", w * 1.6, h * 1.6, (x, y + depth + 40, z), sky_mat)
    card.rotation_euler = (math.radians(90), 0, 0)
    # the wall around the opening (four jamb blocks) so the wall reads as having a hole
    jm = frame_mat
    E.cube("window_sill", (w + 16, depth + 6, 6), (x, y + depth / 2, z - h / 2 - 3), jm)
    E.cube("window_head", (w + 16, depth + 6, 10), (x, y + depth / 2, z + h / 2 + 5), jm)
    for sx in (-1, 1):
        E.cube("window_jamb", (8, depth + 6, h + 16), (x + sx * (w / 2 + 4), y + depth / 2, z), jm)
    nx, nz = mullions
    for i in range(1, nx):
        E.cube("mullion_v", (1.6, 2, h), (x - w / 2 + i * w / nx, y + depth, z), jm)
    for j in range(1, nz):
        E.cube("mullion_h", (w, 2, 1.6), (x, y + depth, z - h / 2 + j * h / nz), jm)
    if moon:
        E.sphere("moon", moon[0], (x + moon[1], y + depth + 38, z + moon[2]),
                 E.emissive("Moon", (0.85, 0.9, 1.0), 8.0), subdiv=3)
    return card


def column(x, y, h, r, mat, base=True):
    E.cylinder("column", r, h, (x, y, FLOOR_Z + h / 2), mat, segs=24)
    if base:
        E.cube("column_base", (r * 2.6, r * 2.6, 10), (x, y, FLOOR_Z + 5), mat, bevel=1.0)
        E.cube("column_cap", (r * 2.6, r * 2.6, 8), (x, y, FLOOR_Z + h - 4), mat, bevel=1.0)


def fireplace(scene, x, y, w=120, h=110, depth=40, mat=None, energy=90000, facing=-1):
    """A stone fireplace against a wall at y, fire and coals glowing, one warm light."""
    mat = mat or stone("Hearth stone", (0.05, 0.045, 0.04), (0.14, 0.12, 0.1), scale=0.05)
    dark = E.simple("Firebox soot", (0.01, 0.008, 0.006), 0.95)
    E.cube("hearth_back", (w, depth, h), (x, y, FLOOR_Z + h / 2), mat)
    E.cube("firebox", (w * 0.6, depth * 0.8, h * 0.55), (x, y + facing * depth * 0.15, FLOOR_Z + h * 0.3), dark)
    E.cube("mantel", (w * 1.15, depth * 1.2, 8), (x, y + facing * depth * 0.1, FLOOR_Z + h * 0.62), mat, bevel=1.0)
    E.cube("hearth_stone", (w * 1.1, depth * 1.6, 4), (x, y + facing * depth * 0.4, FLOOR_Z + 2), mat)
    fm = P.flame_mat(strength=40.0, color=(1.0, 0.5, 0.15))
    rng = random.Random(int(x * 7 + y))
    for i in range(5):
        fx = x + rng.uniform(-w * 0.2, w * 0.2)
        fl = E.sphere("hearth_flame", 1.0, (fx, y + facing * depth * 0.45, FLOOR_Z + 18), fm, subdiv=3,
                      scale=(rng.uniform(5, 8), rng.uniform(5, 8), rng.uniform(14, 22)))
        fl.visible_shadow = False
    coal = E.emissive("Hearth coals", (1.0, 0.25, 0.04), 6.0)
    for i in range(10):
        E.rock(f"hearth_coal{i}", rng.uniform(3, 5), (x + rng.uniform(-w * 0.22, w * 0.22),
                                                      y + facing * depth * 0.4 + rng.uniform(-4, 4), FLOOR_Z + 5),
               coal, seed=i, subdiv=2)
    return E.light(scene, "POINT", "hearth_light", (x, y + facing * depth * 0.8, FLOOR_Z + 30), energy,
                   color=(1.0, 0.48, 0.16), size=20)


def bookshelf(x, y, w=120, h=200, depth=30, rows=6, seed=0, facing=-1, mat=None, rot=0.0):
    """A wooden bookcase full of standing books (original: no titles)."""
    mat = mat or P.dark_wood("Shelf wood", c1=(0.03, 0.015, 0.008), c2=(0.09, 0.045, 0.02))
    rng = random.Random(seed)
    parent = bpy.data.objects.new("bookshelf", None)
    bpy.context.scene.collection.objects.link(parent)
    parts = [E.cube("shelf_back", (w, 2, h), (0, depth / 2 - 1, h / 2), mat)]
    for sx in (-1, 1):
        parts.append(E.cube("shelf_side", (3, depth, h), (sx * (w / 2 - 1.5), 0, h / 2), mat))
    row_h = h / rows
    cols = [(0.25, 0.04, 0.03), (0.05, 0.09, 0.2), (0.06, 0.12, 0.06), (0.3, 0.2, 0.08), (0.12, 0.05, 0.12),
            (0.35, 0.28, 0.18)]
    for r in range(rows + 1):
        parts.append(E.cube("shelf_board", (w - 3, depth, 2.4), (0, 0, r * row_h + 1.2), mat))
        if r == rows:
            break
        xx = -w / 2 + 4
        while xx < w / 2 - 6:
            bw = rng.uniform(2.5, 5.5)
            bh = rng.uniform(row_h * 0.55, row_h * 0.85)
            bd = rng.uniform(depth * 0.6, depth * 0.85)
            if rng.random() < 0.08:  # a gap / a leaning book
                xx += bw * 2
                continue
            c = rng.choice(cols)
            c = tuple(v * rng.uniform(0.6, 1.1) for v in c)
            bk = E.cube("shelf_book", (bw, bd, bh), (xx + bw / 2, -depth / 2 + bd / 2 + 1, r * row_h + 2.4 + bh / 2),
                        _book_mat(c), bevel=0.3)
            parts.append(bk)
            xx += bw + rng.uniform(0.1, 0.5)
    for p_ in parts:
        p_.parent = parent
    parent.location = (x, y, FLOOR_Z)
    parent.rotation_euler = (0, 0, rot + (0 if facing < 0 else math.pi))
    return parent


_BOOK_MATS = {}


def _book_mat(c):
    key = tuple(round(v, 2) for v in c)
    if key not in _BOOK_MATS or _BOOK_MATS[key].name not in bpy.data.materials:
        m, k = E.material(f"Spine {key}")
        obj = k.coords().outputs["Object"]
        n = k.noise(obj, 2.0, 4).outputs["Fac"]
        k.surface(k.bsdf(Base_Color=k.mix(k.math("MULTIPLY", n, 0.3), (*key, 1), tuple(v * 0.5 for v in key) + (1,)),
                         Roughness=0.6))
        _BOOK_MATS[key] = m
    return _BOOK_MATS[key]


def pendant_lamp(scene, x, y, z, energy=40000, color=(1.0, 0.78, 0.5), shade=(0.35, 0.25, 0.1), r=22):
    """An industrial / library pendant: a metal cone shade with a glowing bulb."""
    E.cylinder("pendant_cord", 0.4, 120, (x, y, z + 60 + 10), E.simple("Cord", (0.02, 0.02, 0.02), 0.5), segs=8)
    sh = E.cylinder("pendant_shade", 4, 16, (x, y, z + 8), E.simple("Shade metal", shade, 0.35, 0.9), segs=48,
                    r2=r, cap=False)
    sh.rotation_euler = (math.radians(180), 0, 0)
    sh.modifiers.new("solid", "SOLIDIFY").thickness = 0.6
    E.sphere("bulb", 3.5, (x, y, z + 2), E.emissive("Bulb", color, 20.0), subdiv=2)
    return E.light(scene, "SPOT", "pendant_light", (x, y, z), energy, color=color, size=4, target=(x, y, z - 100),
                   spot_deg=80, blend=0.5)


def sconce(scene, x, y, z, energy=3000, color=(1.0, 0.6, 0.3), mat=None, facing=-1):
    mat = mat or P.brass("Sconce brass", worn=0.5)
    E.cube("sconce_plate", (6, 2, 12), (x, y, z), mat, bevel=0.5)
    E.cylinder("sconce_arm", 0.6, 10, (x, y + facing * 5, z + 3), mat, segs=8).rotation_euler = (math.radians(90), 0, 0)
    P.candle(scene, x, y + facing * 10, z + 3, h=8, r=1.2, holder=True, light=True, energy=energy / 40, seed=int(x))
    return E.light(scene, "POINT", "sconce_glow", (x, y + facing * 12, z + 16), energy, color=color, size=6)


def rug(x, y, w, d, c1, c2, name="Rug"):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    bx = k.math("LESS_THAN", k.math("ABSOLUTE", sep.outputs["X"]), w / 2 - 12)
    by = k.math("LESS_THAN", k.math("ABSOLUTE", sep.outputs["Y"]), d / 2 - 12)
    inner = k.math("MULTIPLY", bx, by)
    pat = k.math("GREATER_THAN", k.noise(obj, 0.05, 3).outputs["Fac"], 0.55)
    col = k.mix(inner, (*c2, 1), k.mix(pat, (*c1, 1), (*c2, 1)))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.95, Sheen_Weight=0.6))
    return E.plane("rug", w, d, (x, y, FLOOR_Z + 0.3), m)


def table_legs(half_w, half_d, top_z=-6.0, mat=None, r=5.0):
    """Four legs under a table whose top slab sits at top_z..0."""
    mat = mat or P.dark_wood("Table legs", c1=(0.03, 0.015, 0.008), c2=(0.1, 0.05, 0.025))
    h = top_z - FLOOR_Z
    for sx in (-1, 1):
        for sy in (-1, 1):
            E.cylinder("table_leg", r, h, (sx * (half_w - 12), sy * (half_d - 12), FLOOR_Z + h / 2), mat, segs=16)


def room_camera(scene, loc, target, lens=24, fstop=5.6, focus=None):
    return E.camera(scene, "room", loc, target, lens=lens, fstop_real=fstop, focus=focus or target)
