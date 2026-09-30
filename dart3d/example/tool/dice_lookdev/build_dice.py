"""Dice look-development: polyhedral set geometry, glyph atlases and materials.

Plan item P3 (docs/design/demo-program.md §5). Look-dev only: nothing here is
loaded by the app. Everything is generated from code, so the set can be rebuilt
bit-for-bit from this file plus Blender 5.2.

What it builds
  * d4 (long crystal "shard", read from the top face), d6, d8, d10 units
    (0-9), d10 tens (00-90), d12, d20. Standard opposite-face sums (d4 5,
    d6 7, d8 9, d10 9, d%-tens 90, d12 13, d20 21) are asserted at build
    time. 6 and 9 carry a dot.
  * Bevelled low-poly bodies (every die < 1.5k triangles) with one UV set that
    maps every face into a cell of a 9x9 **glyph atlas** shared by the set.
  * One RGB atlas per theme: R = numerals, G = theme decor (runes, borders,
    circuit traces, frost dendrites, ...), B = engrave height (blurred R|G).
    That single texture drives number colour/emission and the inset
    (bump in Cycles, a baked normal map in real time).
  * The per-theme Cycles materials (see THEMES below and docs/design/dice-lookdev.md).
  * A face map in the same format as assets/dice/dice_faces.json (glTF Y-up).

CLI (from the repo root):
  Blender --background --python dart3d/example/tool/dice_lookdev/build_dice.py -- \
      [--theme emberforged] [--faces-json out.json] [--atlas-dir dir] \
      [--export-glb dir] [--save-blend out.blend] [--stats]

Most callers import it instead (render_set.py).
"""
from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
PHI = (1.0 + 5.0 ** 0.5) / 2.0
BLENDER_FONTS = Path(bpy.utils.resource_path("LOCAL")) / "datafiles" / "fonts"
FONTS = {
    # Only fonts we can ship: Blender's bundled Inter (OFL) and DejaVu Sans
    # Mono (Bitstream Vera licence), plus EB Garamond (OFL, vendored in fonts/).
    "sans": BLENDER_FONTS / "Inter.woff2",
    "mono": BLENDER_FONTS / "DejaVuSansMono.woff2",
    "serif": HERE / "fonts" / "EBGaramond-VariableFont_wght.ttf",
}
ATLAS_GRID = 9  # 9 x 9 cells >= 78 faces (the d4 shard has 4 numbered + 8 cap faces)
KINDS = ("d4", "d6", "d8", "d10u", "d10t", "d12", "d20")

# --------------------------------------------------------------------------
# Geometry
# --------------------------------------------------------------------------

# Base sizes in centimetres (1 Blender unit = 1 cm) are a standard set;
# SIZE_SCALE brings them to the in-app size (dice_table_scene.dart: dice
# ~23-33 mm across in a 132 mm wide tray; here a d20 is ~2.9 cm across in
# the 15 cm tray).
SIZE_SCALE = 1.3
# em: glyph font size as a multiple of the face inradius. Every top-face
# numeral is >= 40% of the face's inscribed width and its strokes are a
# medium weight, ~10-14% of the numeral height (round 2.1: the fonts are no
# longer emboldened; em went up 13% to keep the height), measured from the
# rendered atlas, see numeral_stats().
DIE_PARAMS = {
    #        size     bevel  segs  glyph em (x face inradius)
    "d4": dict(size=1.00, bevel=0.07, segs=3, em=1.78),  # shard: size = square section
    "d6": dict(size=1.60, bevel=0.13, segs=4, em=1.67),
    "d8": dict(size=1.05, bevel=0.07, segs=3, em=1.76),
    "d10u": dict(size=1.00, bevel=0.06, segs=3, em=1.65),
    "d10t": dict(size=1.00, bevel=0.06, segs=3, em=1.54),
    "d12": dict(size=0.66, bevel=0.07, segs=3, em=1.67),
    "d20": dict(size=1.18, bevel=0.055, segs=3, em=1.60),
}
# d4 shard proportions (x square section): prism half-length, cap length.
SHARD_HALF, SHARD_CAP = 0.62, 0.62


def _hull(points):
    """Convex hull -> list of faces (ordered outward CCW point lists)."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(Vector(p))
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    bmesh.ops.dissolve_limit(bm, angle_limit=0.001, verts=bm.verts[:], edges=bm.edges[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    faces = [[v.co.copy() for v in f.verts] for f in bm.faces]
    bm.free()
    return faces


def _rotate_face_up(points, pick):
    """Rotate `points` so the hull face chosen by `pick(faces)` points +Z."""
    faces = _hull(points)
    f = pick(faces)
    n = _normal(f)
    q = n.rotation_difference(Vector((0, 0, 1)))
    return [q @ Vector(p) for p in points]


def _normal(pts):
    c = sum(pts, Vector()) / len(pts)
    n = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
    return n if n.dot(c) > 0 else -n


def _raw_points(kind):
    s = DIE_PARAMS[kind]["size"] * SIZE_SCALE
    if kind == "d4":
        # Long crystal: square prism along X with pyramid caps. It rests on
        # one of its four long faces, so the result is the face pointing up.
        a, L, c = s / 2, s * SHARD_HALF, s * SHARD_CAP
        pts = [Vector((x, y, z)) for x in (-L, L) for y in (-a, a) for z in (-a, a)]
        return pts + [Vector((-(L + c), 0, 0)), Vector((L + c, 0, 0))]
    if kind == "d6":
        h = s / 2
        return [Vector((x, y, z)) * h for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    if kind == "d8":
        pts = [Vector(v) * s for v in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))]
        return _rotate_face_up(pts, lambda fs: fs[0])
    if kind in ("d10u", "d10t"):
        r, h = s, s * 1.08
        z0 = h * (1 - math.cos(math.radians(36))) / (1 + math.cos(math.radians(36)))
        pts = [Vector((0, 0, h)), Vector((0, 0, -h))]
        for k in range(5):
            a = math.radians(72 * k)
            b = math.radians(72 * k + 36)
            pts.append(Vector((r * math.cos(a), r * math.sin(a), z0)))
            pts.append(Vector((r * math.cos(b), r * math.sin(b), -z0)))
        return pts
    if kind == "d12":
        ip = 1 / PHI
        pts = [Vector((x, y, z)) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        for a in (-1, 1):
            for b in (-1, 1):
                pts += [Vector((0, a * ip, b * PHI)), Vector((a * ip, b * PHI, 0)), Vector((a * PHI, 0, b * ip))]
        pts = [p * s for p in pts]
        return _rotate_face_up(pts, lambda fs: fs[0])
    if kind == "d20":
        pts = []
        for a in (-1, 1):
            for b in (-1, 1):
                pts += [Vector((0, a, b * PHI)), Vector((a, b * PHI, 0)), Vector((a * PHI, 0, b))]
        pts = [p * (s / 2) for p in pts]  # edge = size
        return _rotate_face_up(pts, lambda fs: fs[0])
    raise ValueError(kind)


# Values for the "seed" hemisphere (faces with n.z > 0, sorted top-down then
# by angle); the opposite face gets (sum - v).
SEEDS = {
    "d8": ([8, 3, 5, 2], 9),
    "d10u": ([1, 7, 3, 9, 5], 9),
    "d10t": ([10, 70, 30, 90, 50], 90),
    "d12": ([12, 2, 10, 4, 8, 6], 13),
    "d20": ([20, 8, 14, 2, 18, 4, 12, 6, 16, 10], 21),
}
OPPOSITE_SUM = {"d4": 5, "d6": 7, "d8": 9, "d10u": 9, "d10t": 90, "d12": 13, "d20": 21}


def _label(kind, v):
    if kind == "d10t":
        return "00" if v == 0 else str(v)
    if v in (6, 9) and kind in ("d10u", "d12", "d20"):
        return f"{v}."
    return str(v)


def _angle(n):
    return math.atan2(n.y, n.x) % (2 * math.pi)


def _face_frame(kind, pts, n, c, all_pts):
    """Glyph 'up' direction in the face plane."""
    def proj(v):
        v = v - n * v.dot(n)
        return v.normalized() if v.length > 1e-6 else None

    if kind in ("d10u", "d10t"):
        pole = max(pts, key=lambda p: abs(p.z))
        return proj(pole - c)
    if kind == "d4":
        # long faces read along the crystal; cap facets point at their tip
        return proj(Vector((1, 0, 0))) or proj(max(pts, key=lambda p: abs(p.x)) - c)
    ref = proj(Vector((0, 0, 1))) or Vector((0, 1, 0))
    if kind == "d6":
        return ref
    best = max(pts, key=lambda p: (p - c).dot(ref))
    return proj(best - c)


def _inradius(pts2):
    """Distance from origin (anchor) to the nearest polygon edge, 2D."""
    best = 1e9
    for i in range(len(pts2)):
        a, b = pts2[i], pts2[(i + 1) % len(pts2)]
        e = (b - a)
        t = max(0.0, min(1.0, (-a).dot(e) / e.length_squared))
        best = min(best, (a + e * t).length)
    return best


def die_spec(kind):
    """Faces with values, labels, local 2D frames and glyph placements."""
    pts = _raw_points(kind)
    hull = _hull(pts)
    faces = []
    for fp in hull:
        n = _normal(fp)
        c = sum(fp, Vector()) / len(fp)
        faces.append(dict(pts=fp, n=n, c=c))

    # --- numbering -------------------------------------------------------
    if kind == "d4":
        table = {(0, 0, 1): 4, (0, 0, -1): 1, (0, 1, 0): 2, (0, -1, 0): 3}
        for f in faces:
            key = tuple(int(round(x)) for x in f["n"])
            f["value"] = table.get(key)  # None on the 8 cap facets
            f["cap"] = f["value"] is None
    elif kind == "d6":
        table = {(0, 0, 1): 1, (0, 0, -1): 6, (0, -1, 0): 2, (0, 1, 0): 5, (1, 0, 0): 3, (-1, 0, 0): 4}
        for f in faces:
            key = tuple(int(round(x)) for x in f["n"])
            f["value"] = table[key]
    else:
        seeds, total = SEEDS[kind]
        upper = [f for f in faces if f["n"].z > 1e-4]
        upper.sort(key=lambda f: (-round(f["n"].z, 4), _angle(f["n"])))
        assert len(upper) * 2 == len(faces), (kind, len(upper), len(faces))
        for f, v in zip(upper, seeds):
            f["value"] = v
            opp = min(faces, key=lambda g: g["n"].dot(f["n"]))
            opp["value"] = total - v

    # --- glyph layout ----------------------------------------------------
    p = DIE_PARAMS[kind]
    for f in faces:
        n, c = f["n"], f["c"]
        up = _face_frame(kind, f["pts"], n, c, pts)
        right = up.cross(n).normalized()
        f["up"], f["right"] = up, right
        f["p2"] = [Vector(((q - c).dot(right), (q - c).dot(up))) for q in f["pts"]]
        anchor = Vector((0.0, 0.0))
        if kind in ("d10u", "d10t"):
            # Kite: sit the numeral toward the wide (equator) end.
            far = min(f["p2"], key=lambda q: q.y)
            anchor = far * 0.16
        f["anchor"] = anchor
        rin = _inradius([q - anchor for q in f["p2"]])
        f["rin"] = rin
        if f.get("cap"):
            f["glyphs"] = []
        else:
            f["label"] = _label(kind, f["value"])
            f["glyphs"] = [dict(text=f["label"], pos=anchor, rot=0.0, em=p["em"] * rin)]

    # --- checks ----------------------------------------------------------
    numbered = [f for f in faces if not f.get("cap")]
    if kind == "d4":
        assert len(faces) == 12 and len(numbered) == 4, len(faces)
    if True:
        faces_all, faces = faces, numbered
        vals = sorted(f["value"] for f in faces)
        expect = {"d4": range(1, 5), "d6": range(1, 7), "d8": range(1, 9), "d10u": range(0, 10),
                  "d10t": range(0, 100, 10), "d12": range(1, 13), "d20": range(1, 21)}[kind]
        assert vals == list(expect), (kind, vals)
        for f in faces:
            opp = min(faces, key=lambda g: g["n"].dot(f["n"]))
            assert f["value"] + opp["value"] == OPPOSITE_SUM[kind], (kind, f["value"], opp["value"])
        faces = faces_all

    extent = max(q.length for f in faces for q in f["p2"])
    spec = dict(kind=kind, points=pts, faces=faces, cell_span=2 * extent * 1.1)
    spec["inradius"] = min(f["n"].dot(f["c"]) for f in faces if not f.get("cap"))
    return spec


def face_map(specs):
    """dice_faces.json-compatible map in glTF (Y-up) coordinates."""
    def gl(v):
        return [round(v.x, 6), round(v.z, 6), round(-v.y, 6)]

    out = {}
    for kind in KINDS:
        s = specs[kind]
        # The d4 shard lists only its four long faces: it cannot rest on a
        # cap facet, and "most aligned with up" over these four is the result.
        out[kind] = {"resultSide": "up",
                     "faces": [{"n": gl(f["n"]), "v": f["value"]} for f in s["faces"] if not f.get("cap")]}
        if kind == "d4":
            out[kind]["shape"] = "shard"
    return out


def build_die_mesh(spec, name, cell_base):
    """Bevelled body with atlas UVs. Returns (mesh, triangle count)."""
    kind = spec["kind"]
    p = DIE_PARAMS[kind]
    bm = bmesh.new()
    vmap = {}
    for f in spec["faces"]:
        vs = []
        for q in f["pts"]:
            key = tuple(round(x, 5) for x in q)
            if key not in vmap:
                vmap[key] = bm.verts.new(q)
            vs.append(vmap[key])
        bm.faces.new(vs)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=p["bevel"] * SIZE_SCALE, offset_type="OFFSET",
                    segments=p["segs"], profile=0.5, affect="EDGES", clamp_overlap=True)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    uv = bm.loops.layers.uv.new("UVMap")
    edge_layer = bm.faces.layers.float.new("bevel") if hasattr(bm.faces.layers, "float") else None
    span = spec["cell_span"]
    cs = 1.0 / ATLAS_GRID
    for bf in bm.faces:
        bf.normal_update()
        best_i = max(range(len(spec["faces"])), key=lambda i: bf.normal.dot(spec["faces"][i]["n"]))
        f = spec["faces"][best_i]
        col, row = divmod(cell_base + best_i, ATLAS_GRID)[::-1]
        u0 = col * cs
        v0 = 1.0 - (row + 1) * cs
        for loop in bf.loops:
            d = loop.vert.co - f["c"]
            x, y = d.dot(f["right"]), d.dot(f["up"])
            loop[uv].uv = (u0 + (x / span + 0.5) * cs, v0 + (y / span + 0.5) * cs)
        bf.smooth = True
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.set_sharp_from_angle(angle=math.radians(38))
    tris = sum(len(poly.vertices) - 2 for poly in mesh.polygons)
    return mesh, tris


def build_core_mesh(spec, name, scale=0.72):
    """A softened inner hull for 'glowing core' themes (volume/emissive)."""
    bm = bmesh.new()
    for q in spec["points"]:
        bm.verts.new(q * scale)
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def cell_bases():
    bases, i = {}, 0
    for kind in KINDS:
        bases[kind] = i
        i += {"d4": 12, "d6": 6, "d8": 8, "d10u": 10, "d10t": 10, "d12": 12, "d20": 20}[kind]
    return bases


# --------------------------------------------------------------------------
# Glyph atlas (rendered with Workbench, combined with numpy)
# --------------------------------------------------------------------------

def _stroke(coll, name, polylines, width, closed=False):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = width / 2
    cu.bevel_resolution = 2
    for line in polylines:
        sp = cu.splines.new("POLY")
        sp.points.add(len(line) - 1)
        for i, (x, y) in enumerate(line):
            sp.points[i].co = (x, y, 0.0, 1.0)
        sp.use_cyclic_u = closed
    ob = bpy.data.objects.new(name, cu)
    coll.objects.link(ob)
    return ob


def _circle(cx, cy, r, n=14):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def _rune(rng, cx, cy, h, rot):
    """An original, stave-and-bowl mark with an 'elvish' cadence (not a real script)."""
    lines = []
    stem = [(0, -h / 2), (0, h / 2)]
    lines.append(stem)
    side = rng.choice((-1, 1))
    kind = rng.randrange(4)
    if kind in (0, 1):  # bowl
        y0 = h / 2 if kind == 0 else -h / 2
        arc = [(side * 0.32 * h * math.sin(t), y0 - 0.25 * h + 0.25 * h * math.cos(t) * (1 if kind == 0 else -1))
               for t in [i * math.pi / 8 for i in range(9)]]
        lines.append(arc)
    if kind in (1, 2):  # branch
        lines.append([(0, 0.05 * h), (side * 0.34 * h, 0.35 * h)])
    if kind == 3:  # double tick + curl
        lines.append([(0, 0.15 * h), (-side * 0.3 * h, 0.4 * h)])
        lines.append([(side * 0.05 * h, -0.2 * h), (side * 0.3 * h, -0.05 * h), (side * 0.32 * h, 0.12 * h)])
    if rng.random() < 0.5:
        lines.append(_circle(side * 0.25 * h, -0.42 * h, 0.05 * h, 8))
    ca, sa = math.cos(rot), math.sin(rot)
    return [[(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in ln] for ln in lines]


def _inset(p2, k, anchor=Vector((0, 0))):
    return [tuple(anchor + (q - anchor) * k) for q in p2]


def decor_strokes(theme, kind, f, rng):
    """Face-local (x, y) polylines + stroke widths for the atlas G channel."""
    style = THEMES[theme]["decor"]
    rin = f["rin"]
    p2 = f["p2"]
    out = []  # (polylines, width, closed)
    if style == "none" or f.get("cap"):
        return out
    if style in ("runes", "lacquer", "circuit", "ticks"):
        k = {"runes": 0.9, "lacquer": 0.84, "circuit": 0.9, "ticks": 0.0}[style]
        if k:
            out.append(([_inset(p2, k)], rin * (0.035 if style != "circuit" else 0.05), True))
    if style == "lacquer":
        out.append(([_inset(p2, 0.78)], rin * 0.018, True))
        for q in p2:
            d = q * 0.8
            out.append(([_circle(d.x, d.y, rin * 0.045, 10)], rin * 0.04, True))
    if style == "runes":
        # three little marks tucked into the corners (or two on quads)
        corners = sorted(p2, key=lambda q: -q.y)[:3]
        for q in corners:
            d = q * 0.62
            if d.length < rin * 0.9:
                continue
            out.append((_rune(rng, d.x, d.y, rin * 0.26, math.atan2(-d.x, d.y)), rin * 0.03, False))
    if style == "ticks":
        for q in p2:
            d = q.normalized()
            a, b = q * 0.70, q * 0.80
            out.append(([[tuple(a), tuple(b)]], rin * 0.05, False))
        # a tiny index notch under the numeral
        out.append(([[(-rin * 0.18, -rin * 0.78), (rin * 0.18, -rin * 0.78)]], rin * 0.035, False))
    if style == "circuit":
        for q in p2:
            a = q * 0.84
            b = q * 0.62
            pad = q * 0.56
            out.append(([[tuple(a), tuple(b)]], rin * 0.035, False))
            out.append(([_circle(pad.x, pad.y, rin * 0.05, 10)], rin * 0.03, True))
    if style == "stars":
        for q in p2:
            d = q * 0.66
            r = rin * 0.09
            out.append(([[(d.x - r, d.y), (d.x + r, d.y)], [(d.x, d.y - r * 1.6), (d.x, d.y + r * 1.6)]],
                        rin * 0.025, False))
    if style == "sigil":
        out.append(([_inset(p2, 0.8)], rin * 0.022, True))
        for q in p2:
            d = q * 0.62
            out.append(([_circle(d.x, d.y, rin * 0.07, 12)], rin * 0.025, True))
            out.append(([[tuple(q * 0.8), tuple(q * 0.69)]], rin * 0.025, False))
    if style == "dartnative":
        out.append(([_inset(p2, 0.8)], rin * 0.03, True))
    if style == "frost":
        for q in p2:
            base = q * 0.92
            tip = q * 0.55
            out.append(([[tuple(base), tuple(tip)]], rin * 0.022, False))
            axis = (tip - base)
            for t in (0.3, 0.55, 0.78):
                o = base + axis * t
                perp = Vector((-axis.y, axis.x)).normalized() * axis.length * 0.22 * (1.1 - t)
                fw = axis.normalized() * axis.length * 0.12
                out.append(([[tuple(o), tuple(o + perp + fw)], [tuple(o), tuple(o - perp + fw)]], rin * 0.016, False))
    return out


def build_atlas(theme, specs, out_dir, res=4096):
    """Render the theme's RGB glyph atlas to out_dir/<theme>_atlas.png."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{theme}_atlas.png"
    t = THEMES[theme]
    scene = bpy.data.scenes.new(f"atlas_{theme}")
    num_coll = bpy.data.collections.new("numerals")
    dec_coll = bpy.data.collections.new("decor")
    scene.collection.children.link(num_coll)
    scene.collection.children.link(dec_coll)
    edge_coll = bpy.data.collections.new("edge")
    scene.collection.children.link(edge_coll)
    font = bpy.data.fonts.load(str(FONTS[t["font"]]), check_existing=True)
    bases = cell_bases()
    cs = 1.0 / ATLAS_GRID
    rng = random.Random(1234)
    for kind in KINDS:
        spec = specs[kind]
        span = spec["cell_span"]
        for i, f in enumerate(spec["faces"]):
            col, row = (bases[kind] + i) % ATLAS_GRID, (bases[kind] + i) // ATLAS_GRID
            u0, v0 = col * cs, 1.0 - (row + 1) * cs

            def to_atlas(x, y):
                return (u0 + (x / span + 0.5) * cs, v0 + (y / span + 0.5) * cs)

            for g in f["glyphs"]:
                cu = bpy.data.curves.new(f"g_{kind}_{i}", "FONT")
                cu.body = g["text"]
                cu.font = font
                cu.align_x = "CENTER"
                cu.align_y = "CENTER"
                cu.size = g["em"] / span * cs * t.get("em_scale", 1.0)
                cu.offset = cu.size * t.get("weight", 0.0)
                if t.get("tracking") is not None:
                    cu.space_character = t["tracking"]
                ob = bpy.data.objects.new(cu.name, cu)
                ax, ay = to_atlas(g["pos"].x, g["pos"].y)
                ob.location = (ax, ay, 0.0)
                ob.rotation_euler = (0, 0, g["rot"])
                num_coll.objects.link(ob)
            # Metal-edge frame: the bevel strip projects into a band inside the
            # face outline, so a stroke on the outline covers bevel + a lip.
            lip = DIE_PARAMS[kind]["bevel"] * 1.15 + f["rin"] * 0.07
            _stroke(edge_coll, f"e_{kind}_{i}", [[to_atlas(q.x, q.y) for q in f["p2"]]],
                    2 * lip / span * cs, closed=True)
            for polys, width, closed in decor_strokes(theme, kind, f, rng):
                lines = [[to_atlas(x, y) for x, y in ln] for ln in polys]
                _stroke(dec_coll, f"d_{kind}_{i}", lines, width / span * cs, closed)

    cam = bpy.data.objects.new("atlas_cam", bpy.data.cameras.new("atlas_cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.0
    cam.location = (0.5, 0.5, 5.0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.single_color = (1, 1, 1)
    scene.display.render_aa = "16"
    scene.world = bpy.data.worlds.new("atlas_world")
    scene.world.color = (0, 0, 0)
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "BW"

    layers = {}
    colls = {"num": num_coll, "dec": dec_coll, "edge": edge_coll}
    for name in colls:
        for other, c in colls.items():
            c.hide_render = other != name
        tmp = out_dir / f".{theme}_{name}.png"
        scene.render.filepath = str(tmp)
        bpy.ops.render.render(write_still=True, scene=scene.name)
        img = bpy.data.images.load(str(tmp))
        a = np.array(img.pixels[:], dtype=np.float32).reshape(res, res, 4)[:, :, 0]
        layers[name] = a
        bpy.data.images.remove(img)
        tmp.unlink()

    both = np.maximum(layers["num"], layers["dec"])
    height = _blur(both, max(2, res // 1024))
    rgba = np.stack([layers["num"], layers["dec"], height, layers["edge"]], axis=-1)
    _save_rgba(rgba, path)
    # Readability helpers, same UV layout: R = keyline (the numeral dilated
    # by ~0.15 face inradius, hard edge), G = soft outer glow (wider falloff).
    # Real time: bake the keyline into baseColor, the glow into emissive.
    num = layers["num"]
    key = np.clip(_blur(num, max(2, int(res * 0.0028))) * 6.0, 0, 1)
    glow = np.clip(_blur(num, max(3, int(res * 0.006))) * 2.5, 0, 1)
    _save_rgba(np.stack([key, glow, np.zeros_like(num), np.ones_like(num)], axis=-1),
               out_dir / f"{theme}_halo.png")
    numeral_stats(specs, num, res)
    # Leave no stray datablocks in the caller's file.
    for ob in list(scene.collection.all_objects):
        bpy.data.objects.remove(ob)
    bpy.data.scenes.remove(scene)
    return path


def numeral_stats(specs, num, res):
    """Numeral size and stroke weight, per numbered face (from the atlas).

    f["numeral_ratio"]: numeral height / face inscribed width (rule >= 0.40);
    spec["numeral_ratio_min"] is the die's worst face.
    f["stroke_ratio"]: mean stroke width / numeral height (rule ~0.10-0.14,
    a medium weight with open counters). Stroke width = 2 * area / boundary
    length, exact for thin strokes; spec["stroke_ratio"] is the die's median.
    """
    bases = cell_bases()
    cpx = res / ATLAS_GRID
    for kind in KINDS:
        spec = specs[kind]
        ratios, strokes = [], []
        for i, f in enumerate(spec["faces"]):
            if f.get("cap"):
                continue
            col, row = (bases[kind] + i) % ATLAS_GRID, (bases[kind] + i) // ATLAS_GRID
            # atlas rows are stored bottom-up (Blender pixel order)
            y0 = int(round(res - (row + 1) * cpx))
            x0 = int(round(col * cpx))
            cell = num[y0:y0 + int(cpx), x0:x0 + int(cpx)] > 0.5
            ys = np.nonzero(cell.any(axis=1))[0]
            h = (ys[-1] - ys[0] + 1) if len(ys) else 0
            f["numeral_ratio"] = (h / cpx * spec["cell_span"]) / (2 * f["rin"])
            ratios.append(f["numeral_ratio"])
            inner = cell.copy()
            inner[1:, :] &= cell[:-1, :]
            inner[:-1, :] &= cell[1:, :]
            inner[:, 1:] &= cell[:, :-1]
            inner[:, :-1] &= cell[:, 1:]
            boundary = max(1, int((cell & ~inner).sum()))
            f["stroke_ratio"] = (2.0 * cell.sum() / boundary) / max(1, h)
            strokes.append(f["stroke_ratio"])
        spec["numeral_ratio_min"] = min(ratios)
        spec["stroke_ratio"] = float(np.median(strokes))


def _blur(a, r):
    """Separable box blur x2 (approximately Gaussian)."""
    for _ in range(2):
        for axis in (0, 1):
            c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(2)], mode="edge"), axis=axis)
            if axis == 0:
                a = (c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1)
            else:
                a = (c[:, 2 * r + 1:] - c[:, :-2 * r - 1]) / (2 * r + 1)
    return a


def _save_rgba(rgba, path):
    h, w, _ = rgba.shape
    img = bpy.data.images.new(Path(path).stem, w, h, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "CHANNEL_PACKED"
    px = np.clip(rgba, 0, 1).astype(np.float32)
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


# --------------------------------------------------------------------------
# Node helpers
# --------------------------------------------------------------------------

class NodeKit:
    """Tiny helper to keep material code readable."""

    def __init__(self, mat, output="ShaderNodeOutputMaterial"):
        if hasattr(mat, "use_nodes") and not mat.use_nodes:
            mat.use_nodes = True
        self.nt = mat.node_tree
        self.nt.nodes.clear()
        self.out = self.node(output)
        self.x = 0

    def node(self, t, **props):
        n = self.nt.nodes.new(t)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def link(self, a, b):
        self.nt.links.new(a, b)

    def set(self, node, **inputs):
        for k, v in inputs.items():
            key = k.replace("_", " ")
            sock = node.inputs[key]
            if isinstance(v, bpy.types.NodeSocket):
                self.link(v, sock)
            else:
                sock.default_value = v
        return node

    def math(self, op, a, b=None, c=None, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        for i, v in enumerate((a, b, c)):
            if v is None:
                continue
            if isinstance(v, bpy.types.NodeSocket):
                self.link(v, n.inputs[i])
            else:
                n.inputs[i].default_value = v
        return n.outputs[0]

    def mix(self, fac, a, b, blend="MIX"):
        n = self.node("ShaderNodeMix", data_type="RGBA", blend_type=blend)
        ins = [s for s in n.inputs if s.type == "RGBA"]
        facs = [s for s in n.inputs if s.name == "Factor" and s.type == "VALUE"]
        for sock, v in ((facs[0], fac), (ins[0], a), (ins[1], b)):
            if isinstance(v, bpy.types.NodeSocket):
                self.link(v, sock)
            else:
                sock.default_value = v
        return [s for s in n.outputs if s.type == "RGBA"][0]

    def ramp(self, fac, stops, interp="LINEAR"):
        n = self.node("ShaderNodeValToRGB")
        n.color_ramp.interpolation = interp
        els = n.color_ramp.elements
        while len(els) < len(stops):
            els.new(0.5)
        for el, (pos, col) in zip(els, stops):
            el.position = pos
            el.color = col if len(col) == 4 else (*col, 1.0)
        self.link(fac, n.inputs[0])
        return n.outputs[0]

    def noise(self, vec, scale, detail=4.0, rough=0.5, dist=0.0, dims="3D", w=0.0):
        n = self.node("ShaderNodeTexNoise", noise_dimensions=dims)
        if vec is not None:
            self.link(vec, n.inputs["Vector"])
        self.set(n, Scale=scale, Detail=detail, Roughness=rough, Distortion=dist)
        if dims == "4D":
            n.inputs["W"].default_value = w
        return n

    def voronoi(self, vec, scale, feature="F1", rand=1.0, dims="3D"):
        n = self.node("ShaderNodeTexVoronoi", feature=feature, voronoi_dimensions=dims)
        if vec is not None:
            self.link(vec, n.inputs["Vector"])
        n.inputs["Scale"].default_value = scale
        n.inputs["Randomness"].default_value = rand
        return n

    def coords(self):
        return self.node("ShaderNodeTexCoord")

    def bsdf(self, **inputs):
        return self.set(self.node("ShaderNodeBsdfPrincipled"), **inputs).outputs[0]

    def bump(self, height, strength, distance, normal=None, invert=False):
        n = self.node("ShaderNodeBump", invert=invert)
        self.set(n, Strength=strength, Distance=distance)
        self.link(height, n.inputs["Height"])
        if normal is not None:
            self.link(normal, n.inputs["Normal"])
        return n.outputs["Normal"]

    def mix_shader(self, fac, a, b):
        n = self.node("ShaderNodeMixShader")
        if isinstance(fac, bpy.types.NodeSocket):
            self.link(fac, n.inputs[0])
        else:
            n.inputs[0].default_value = fac
        self.link(a, n.inputs[1])
        self.link(b, n.inputs[2])
        return n.outputs[0]

    def add_shader(self, a, b):
        n = self.node("ShaderNodeAddShader")
        self.link(a, n.inputs[0])
        self.link(b, n.inputs[1])
        return n.outputs[0]

    def emission(self, color, strength):
        n = self.node("ShaderNodeEmission")
        self.set(n, Color=color, Strength=strength)
        return n.outputs[0]

    def surface(self, sock):
        self.link(sock, self.out.inputs["Surface"])

    def volume(self, sock):
        self.link(sock, self.out.inputs["Volume"])

    def atlas(self, image):
        tex = self.node("ShaderNodeTexImage", image=image, interpolation="Cubic")
        sep = self.node("ShaderNodeSeparateColor")
        self.link(tex.outputs["Color"], sep.inputs["Color"])
        self.edge = tex.outputs["Alpha"]
        # Glass dice: seen through the body, a far face's numeral would read
        # mirrored under the near one (a "4" becomes "4ε"). Glyphs only print
        # on the outside of the shell. (Real time: back faces are culled.)
        geo = self.node("ShaderNodeNewGeometry")
        front = self.math("SUBTRACT", 1.0, geo.outputs["Backfacing"])
        num = self.math("MULTIPLY", sep.outputs["Red"], front)
        dec = self.math("MULTIPLY", sep.outputs["Green"], front)
        self.key = self.glow = None
        if HALO is not None:  # readability keyline (R) + outer glow (G), same UVs
            ht = self.node("ShaderNodeTexImage", image=HALO, interpolation="Cubic")
            hs = self.node("ShaderNodeSeparateColor")
            self.link(ht.outputs["Color"], hs.inputs["Color"])
            # keyline excludes the numeral itself
            self.key = self.math("MULTIPLY", self.math("MULTIPLY", hs.outputs["Red"], front),
                                 self.math("SUBTRACT", 1.0, sep.outputs["Red"]), clamp=True)
            self.glow = hs.outputs["Green"]
        return num, dec, sep.outputs["Blue"]

    def keyline(self, shader, color, rough=0.5, normal=None):
        """Lay an opaque dark keyline under/around the numerals."""
        ink = self.bsdf(Base_Color=(*color, 1), Roughness=rough, Normal=normal) if normal is not None else \
            self.bsdf(Base_Color=(*color, 1), Roughness=rough)
        return self.mix_shader(self.key, shader, ink)


HALO = None  # the current set's halo image (set by make_set)


def load_atlas(path):
    img = bpy.data.images.load(str(path), check_existing=True)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "CHANNEL_PACKED"
    return img


# --------------------------------------------------------------------------
# Themes
# --------------------------------------------------------------------------

THEMES = {
    "emberforged": dict(
        env="The Forge Hearth",
        title="Emberforged",
        concept="Smoked amber glass around a live coal: a banked fire you can hold.",
        font="sans", weight=0.0, decor="none", core=True,
        treatment="glowing: white-hot emissive numerals in a soot keyline"),
    "frostbound": dict(
        env="The Frozen Altar",
        title="Frostbound",
        concept="Clear glacial ice, fractured inside, with a cold blue heart and rime-frosted numerals.",
        font="sans", weight=0.0, decor="frost", core=True,
        treatment="glowing: emissive rime numerals on a deep-blue keyline"),
    "oldroad": dict(
        env="The Wayfarer's Table",
        title="Old Road",
        concept="Worn wayfarer's gold, numerals and flowing runes cut and filled with black niello.",
        font="serif", weight=0.006, em_scale=1.15, decor="runes",
        treatment="enamel fill: oxblood-black enamel in bright polished gold"),
    "northfield": dict(
        env="Kitchen Table, 1986",
        title="Northfield Relay",
        concept="80s Nordic lab hardware: warm-white ABS, instrument numerals, calibration ticks.",
        font="mono", weight=0.0, decor="ticks",
        treatment="inked: near-black instrument print on warm-white ABS"),
    "voltline": dict(
        env="Rain Counter",
        title="Voltline",
        concept="Black mirror chrome with neon-lit numerals and glowing circuit rims.",
        font="mono", weight=0.0, decor="circuit",
        treatment="glowing: magenta neon numerals in a black keyline"),
    "vermilion": dict(
        env="Lantern Pavilion",
        title="Vermilion Court",
        concept="Deep urushi-red lacquer, gold-leaf numerals and fine gold inlay borders.",
        font="serif", weight=0.006, em_scale=1.15, decor="lacquer",
        treatment="bright metal: pale gold leaf on deep urushi red, gilt edges (thin keyline)"),
    "arcane": dict(
        env="The Night Study",
        title="Arcane Study",
        concept="Gold-framed midnight dice: deep-blue star-glitter inlay under raised gilt edges and numerals.",
        font="serif", weight=0.006, em_scale=1.1, decor="stars",
        treatment="glowing: warm spell-lit gilt numerals, thin midnight keyline"),
    "fateengine": dict(
        env="The Fate Engine",
        title="Fate Engine",
        concept="Machined gunmetal in brass frames; numerals and sigils lit teal by the engine's charge.",
        font="serif", weight=0.006, em_scale=1.1, decor="sigil",
        treatment="glowing: aqua-charged numerals in a dark keyline"),
    "celestial": dict(
        env="The Star Balcony",
        title="Celestial Observatory",
        concept="A night sky caught in resin: violet nebula, pin-point stars, silver-rimmed edges.",
        font="sans", weight=0.0, decor="stars",
        treatment="glowing: starlight-silver numerals in an indigo keyline"),
    "hearthside": dict(
        env="Fireside Reading",
        title="Hearthside Tome",
        concept="Old bone and ivory, sepia-inked numerals worn soft by years of firelit play.",
        font="serif", weight=0.006, em_scale=1.12, decor="none",
        treatment="inked: engraved, filled with sepia-black ink"),
    "dartnative": dict(
        env="Launch Tray",
        title="DartNative",
        concept="The example app's own set: #090E12 dice with brand-gradient glowing edges and a cyan inlay.",
        font="sans", weight=0.0, decor="dartnative",
        treatment="glowing: white numerals in a thin keyline, brand-gradient edges"),
    "gemcutter": dict(
        env="The Jeweler's Bench",
        title="Gemcutter",
        concept="Classic swirled-gem polyhedrals: emerald and pearl ribbons under a glassy polish.",
        font="sans", weight=0.0, decor="none",
        treatment="bright enamel: ivory-gold enamel on emerald (thin keyline)"),
}


def _engrave(k, height, normal=None, strength=0.8, dist=0.05):
    return k.bump(height, strength, dist, normal=normal, invert=True)


def material_emberforged(img):
    m = bpy.data.materials.new("Emberforged shell")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    tc = k.coords()
    # Smoky amber glass; the core (separate object) supplies the fire.
    grime = k.noise(tc.outputs["Object"], 3.0, 6, 0.6).outputs["Fac"]
    rough = k.math("MULTIPLY_ADD", grime, 0.12, 0.02)
    nrm = _engrave(k, h, strength=0.9, dist=0.06)
    glass = k.bsdf(Base_Color=(0.55, 0.24, 0.08, 1), Transmission_Weight=1.0, IOR=1.52,
                   Roughness=rough, Coat_Weight=0.4, Coat_Roughness=0.03, Normal=nrm)
    # Readability: white-hot numerals (emissive) inside a soot keyline, so the
    # fire behind the glass never sits right against the digit.
    hot = k.emission(k.ramp(num, [(0.0, (1.0, 0.35, 0.02)), (1.0, (1.0, 0.78, 0.36))]), 9.0)
    numeral = k.add_shader(k.bsdf(Base_Color=(0.05, 0.01, 0.0, 1), Roughness=0.45, Normal=nrm), hot)
    glass = k.keyline(glass, (0.012, 0.006, 0.004), rough=0.7, normal=nrm)
    k.surface(k.mix_shader(num, glass, numeral))
    vol = k.node("ShaderNodeVolumeAbsorption")
    k.set(vol, Color=(0.32, 0.1, 0.035, 1), Density=1.1)  # round 2: a little less smoke than round 1 (1.6)
    k.volume(vol.outputs[0])
    return m


def material_ember_core():
    m = bpy.data.materials.new("Emberforged core")
    k = NodeKit(m)
    tc = k.coords()
    obj = tc.outputs["Object"]
    warp = k.noise(obj, 1.6, 3, 0.5).outputs["Color"]
    vec = k.mix(0.55, obj, warp, "LINEAR_LIGHT")
    flame = k.noise(vec, 4.5, 8, 0.62, dist=0.4, dims="4D", w=1.7).outputs["Fac"]
    # radial falloff: hotter at the heart
    dist = k.node("ShaderNodeVectorMath", operation="LENGTH")
    k.link(obj, dist.inputs[0])
    fall = k.math("SUBTRACT", 1.0, k.math("MULTIPLY", dist.outputs["Value"], 1.25), clamp=True)
    heat = k.math("MULTIPLY", k.math("POWER", flame, 3.0), fall)
    heat = k.math("MULTIPLY", heat, 4.0, clamp=True)
    col = k.ramp(heat, [(0.0, (0, 0, 0)), (0.25, (0.4, 0.03, 0.0)), (0.55, (1.0, 0.22, 0.0)),
                        (0.85, (1.0, 0.45, 0.03)), (1.0, (1.0, 0.62, 0.12))])
    # ember flecks
    vor = k.voronoi(obj, 22.0)
    fleck = k.math("LESS_THAN", vor.outputs["Distance"], 0.07)
    fleck = k.math("MULTIPLY", fleck, k.math("GREATER_THAN", k.noise(obj, 5.0, 2).outputs["Fac"], 0.55))
    vol = k.node("ShaderNodeVolumePrincipled")
    k.set(vol, Density=0.0)  # emission-only: no scattering, ~3x cheaper to render
    strength = k.math("ADD", k.math("MULTIPLY", heat, 26.0), k.math("MULTIPLY", fleck, 45.0))
    k.link(col, vol.inputs["Emission Color"])
    k.link(strength, vol.inputs["Emission Strength"])
    k.volume(vol.outputs[0])
    return m


def material_frostbound(img):
    m = bpy.data.materials.new("Frostbound shell")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    tc = k.coords()
    obj = tc.outputs["Object"]
    frost_n = k.noise(obj, 4.0, 8, 0.7).outputs["Fac"]
    frosty = k.math("MAXIMUM", k.ramp(frost_n, [(0.45, (0, 0, 0)), (0.75, (1, 1, 1))]), dec)
    rough = k.math("MULTIPLY_ADD", frosty, 0.45, 0.015)
    micro = k.noise(obj, 60.0, 4, 0.6).outputs["Fac"]
    nrm = k.bump(micro, 0.05, 0.01)
    nrm = _engrave(k, h, normal=nrm, strength=0.7, dist=0.05)
    ice = k.bsdf(Base_Color=(0.9, 0.97, 1.0, 1), Transmission_Weight=1.0, IOR=1.31,
                 Roughness=rough, Coat_Weight=0.6, Coat_Roughness=0.02, Normal=nrm)
    sparkle_v = k.voronoi(obj, 70.0)
    spark = k.math("LESS_THAN", sparkle_v.outputs["Distance"], 0.045)
    spark = k.math("MULTIPLY", spark, k.math("GREATER_THAN", k.noise(obj, 9.0, 1).outputs["Fac"], 0.62))
    glint = k.emission((0.85, 0.95, 1.0, 1), k.math("MULTIPLY", spark, 9.0))
    # Readability: glowing rime numerals on a deep-blue keyline (like ink
    # frozen under the frost), so clear ice over a bright floor can't wash
    # them out.
    rime = k.bsdf(Base_Color=(0.93, 0.97, 1.0, 1), Roughness=0.7, Subsurface_Weight=0.4,
                  Normal=nrm, Emission_Color=(0.7, 0.9, 1.0, 1), Emission_Strength=7.0)
    body = k.keyline(k.add_shader(ice, glint), (0.008, 0.03, 0.09), rough=0.45, normal=nrm)
    surf = k.mix_shader(num, body, rime)
    k.surface(surf)
    vol = k.node("ShaderNodeVolumeAbsorption")
    k.set(vol, Color=(0.72, 0.9, 1.0, 1), Density=0.55)
    k.volume(vol.outputs[0])
    return m


def material_frost_core():
    m = bpy.data.materials.new("Frostbound core")
    k = NodeKit(m)
    obj = k.coords().outputs["Object"]
    warp = k.noise(obj, 1.2, 2).outputs["Color"]
    vec = k.mix(0.35, obj, warp, "LINEAR_LIGHT")
    cracks = k.voronoi(vec, 2.4, feature="DISTANCE_TO_EDGE")
    sheet = k.math("LESS_THAN", cracks.outputs["Distance"], 0.035)
    cracks2 = k.voronoi(vec, 5.5, feature="DISTANCE_TO_EDGE")
    sheet2 = k.math("LESS_THAN", cracks2.outputs["Distance"], 0.02)
    sheets = k.math("MAXIMUM", sheet, k.math("MULTIPLY", sheet2, 0.6))
    cloud = k.noise(obj, 3.0, 6, 0.6).outputs["Fac"]
    dist = k.node("ShaderNodeVectorMath", operation="LENGTH")
    k.link(obj, dist.inputs[0])
    heart = k.math("SUBTRACT", 1.0, k.math("MULTIPLY", dist.outputs["Value"], 1.6), clamp=True)
    density = k.math("ADD", k.math("MULTIPLY", sheets, 14.0),
                     k.math("MULTIPLY", k.math("POWER", cloud, 3.0), 1.2))
    vol = k.node("ShaderNodeVolumePrincipled")
    k.set(vol, Color=(0.92, 0.97, 1.0, 1), Anisotropy=0.3, Emission_Color=(0.18, 0.55, 1.0, 1))
    k.link(density, vol.inputs["Density"])
    k.link(k.math("MULTIPLY", k.math("POWER", heart, 1.6), 6.0), vol.inputs["Emission Strength"])
    k.volume(vol.outputs[0])
    return m


def material_oldroad(img):
    m = bpy.data.materials.new("Old Road gold")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    obj = k.coords().outputs["Object"]
    wear = k.noise(obj, 5.0, 8, 0.65).outputs["Fac"]
    stretch = k.node("ShaderNodeMapping")
    stretch.inputs["Scale"].default_value = (1.0, 14.0, 1.0)
    k.link(obj, stretch.inputs["Vector"])
    scratches = k.noise(stretch.outputs[0], 30.0, 2, 0.5).outputs["Fac"]
    ao = k.node("ShaderNodeAmbientOcclusion", samples=8)
    ao.inputs["Distance"].default_value = 0.25
    # Round 2.1: bright, clean polished gold on the faces (round 2's wear and
    # AO read as gold-on-gold at phone size); the grime stays in the recesses.
    col = k.mix(k.math("MULTIPLY", k.math("SUBTRACT", 1.0, ao.outputs["AO"]), 0.6), (1.0, 0.8, 0.42, 1),
                (0.45, 0.28, 0.1, 1))
    col = k.mix(k.math("MULTIPLY", wear, 0.12), col, (0.8, 0.64, 0.36, 1))
    rough = k.math("ADD", k.math("MULTIPLY", wear, 0.12), 0.14)
    nrm = k.bump(scratches, 0.05, 0.01)
    nrm = _engrave(k, h, normal=nrm, strength=1.0, dist=0.05)
    gold = k.bsdf(Base_Color=col, Metallic=1.0, Roughness=rough, Normal=nrm)
    # Readability: numerals cut crisp and filled with deep oxblood-black
    # enamel on the bright gold; the runes are a shallow engraving now (no
    # enamel), so they stay ornament and never compete with the numeral.
    enamel = k.bsdf(Base_Color=(0.012, 0.003, 0.003, 1), Roughness=0.3, Coat_Weight=0.6, Coat_Roughness=0.1,
                    Normal=nrm)
    etched = k.bsdf(Base_Color=k.mix(0.12, col, (0.3, 0.2, 0.08, 1)), Metallic=1.0, Roughness=0.3, Normal=nrm)
    s = k.mix_shader(k.math("MULTIPLY", dec, 0.8), gold, etched)
    k.surface(k.mix_shader(num, s, enamel))
    return m


def material_northfield(img):
    m = bpy.data.materials.new("Northfield ABS")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    obj = k.coords().outputs["Object"]
    tex = k.noise(obj, 90.0, 2, 0.5).outputs["Fac"]
    nrm = k.bump(tex, 0.04, 0.01)
    nrm = _engrave(k, h, normal=nrm, strength=0.6, dist=0.03)
    body = k.bsdf(Base_Color=(0.86, 0.82, 0.72, 1), Roughness=0.42, Subsurface_Weight=0.15,
                  Subsurface_Radius=(0.3, 0.2, 0.1), Normal=nrm, Coat_Weight=0.15)
    # Readability: numerals printed in near-black instrument ink (orange on
    # warm white was 1.9:1); the orange survives in the calibration ticks.
    ink = k.bsdf(Base_Color=(0.012, 0.012, 0.014, 1), Roughness=0.55, Normal=nrm)
    tick = k.bsdf(Base_Color=(0.9, 0.3, 0.04, 1), Roughness=0.5, Normal=nrm)
    s = k.mix_shader(dec, body, tick)
    k.surface(k.mix_shader(num, s, ink))
    return m


def material_voltline(img):
    m = bpy.data.materials.new("Voltline chrome")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    obj = k.coords().outputs["Object"]
    smudge = k.noise(obj, 6.0, 6, 0.6).outputs["Fac"]
    rough = k.math("MULTIPLY_ADD", smudge, 0.1, 0.03)
    nrm = _engrave(k, h, strength=0.6, dist=0.03)
    chrome = k.bsdf(Base_Color=(0.06, 0.06, 0.075, 1), Metallic=1.0, Roughness=rough, Normal=nrm,
                    Coat_Weight=0.35, Coat_Roughness=0.05)  # round 2: less mirror, darker silhouette on the lightbox
    cyan = k.emission((0.05, 0.85, 1.0, 1), 11.0)
    pink = k.emission((1.0, 0.08, 0.6, 1), 9.0)
    s = k.mix_shader(dec, chrome, cyan)
    # round 2: a thin neon line along every edge (atlas A = bevel strip), so
    # the black dice keep a lit outline on the glowing holo tray
    s = k.mix_shader(k.math("MULTIPLY", k.edge, 0.7), s, k.emission((0.05, 0.85, 1.0, 1), 4.0))
    s = k.keyline(s, (0.004, 0.004, 0.005), rough=0.6)  # neon glyph, black keyline
    k.surface(k.mix_shader(num, s, pink))
    return m


def material_vermilion(img):
    m = bpy.data.materials.new("Vermilion lacquer")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    obj = k.coords().outputs["Object"]
    depth = k.noise(obj, 2.5, 5, 0.55).outputs["Fac"]
    # Round 2.1: a deep urushi red, so the gold numerals read on the plain
    # face (the gate no longer counts the keyline for non-glowing sets)
    col = k.ramp(depth, [(0.3, (0.14, 0.008, 0.004)), (0.7, (0.26, 0.022, 0.009))])
    flake = k.voronoi(obj, 55.0)
    flakes = k.math("MULTIPLY", k.math("LESS_THAN", flake.outputs["Distance"], 0.03),
                    k.math("GREATER_THAN", k.noise(obj, 4.0, 1).outputs["Fac"], 0.58))
    nrm = _engrave(k, h, strength=0.5, dist=0.02)
    lac = k.bsdf(Base_Color=col, Roughness=0.35, Coat_Weight=1.0, Coat_Roughness=0.05, Coat_IOR=1.55,
                 Normal=nrm)
    gold = k.bsdf(Base_Color=(1.0, 0.74, 0.3, 1), Metallic=1.0, Roughness=0.22, Normal=nrm,
                  Coat_Weight=0.6, Coat_Roughness=0.02)
    s = k.mix_shader(flakes, lac, gold)
    # Readability: gold-leaf numerals (part diffuse, so they catch the key
    # light even when the camera looks straight down) inside a black-lacquer
    # keyline; the red alone was only ~2.5:1 against gold.
    leaf = k.bsdf(Base_Color=(1.0, 0.93, 0.72, 1), Metallic=0.1, Roughness=0.32, Normal=nrm,
                  Coat_Weight=0.4, Coat_Roughness=0.05)
    s = k.mix_shader(dec, s, gold)
    # round 2.1: gilt edges (maki-e style), so the deep-red dice keep a lit
    # outline on the black-lacquer tray
    s = k.mix_shader(k.edge, s, gold)
    s = k.keyline(s, (0.006, 0.003, 0.002), rough=0.3, normal=nrm)
    k.surface(k.mix_shader(num, s, leaf))
    return m


def _framed(k, h, edge, lip=0.5, engrave=0.8, normal=None):
    """Raised metal frame (atlas alpha) + engraved glyphs (atlas blue)."""
    raised = k.math("SUBTRACT", k.math("MULTIPLY", edge, lip), k.math("MULTIPLY", h, engrave))
    return k.bump(raised, 0.9, 0.05, normal=normal)


def _glitter(k, obj, scale=80.0, amount=0.62):
    v = k.voronoi(obj, scale)
    cell = k.math("LESS_THAN", v.outputs["Distance"], 0.32)
    rnd = k.node("ShaderNodeSeparateColor")
    k.link(v.outputs["Color"], rnd.inputs[0])
    return k.math("MULTIPLY", cell, k.math("GREATER_THAN", rnd.outputs["Red"], amount)), v.outputs["Color"]


def material_arcane(img):
    m = bpy.data.materials.new("Arcane Study midnight")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    edge = k.edge
    obj = k.coords().outputs["Object"]
    swirl = k.noise(obj, 1.6, 6, 0.6, dist=1.5).outputs["Fac"]
    # a touch lighter than round 1 (the body still reads midnight, the
    # silhouette now separates from the lighter brass field under it)
    deep = k.ramp(swirl, [(0.3, (0.008, 0.018, 0.1)), (0.7, (0.035, 0.1, 0.46))])
    flake, fcol = _glitter(k, obj, 110.0, 0.78)
    nrm = _framed(k, h, edge)
    flake_n = k.bump(k.math("MULTIPLY", flake, k.noise(obj, 200.0, 1).outputs["Fac"]), 0.6, 0.01, normal=nrm)
    body = k.bsdf(Base_Color=deep, Roughness=0.12, Coat_Weight=1.0, Coat_Roughness=0.02, Normal=nrm,
                  Transmission_Weight=0.04)  # round 1: 0.25 showed the far-side numerals
    sparkle = k.bsdf(Base_Color=k.mix(0.35, (0.35, 0.55, 1.0, 1), fcol), Metallic=1.0, Roughness=0.15,
                     Normal=flake_n, Emission_Color=(0.3, 0.5, 1.0, 1), Emission_Strength=0.6)
    body = k.mix_shader(flake, body, sparkle)
    body = k.keyline(body, (0.003, 0.006, 0.03), rough=0.6, normal=nrm)
    gold = k.bsdf(Base_Color=(1.0, 0.73, 0.33, 1), Metallic=1.0, Roughness=0.24, Normal=nrm)
    # Readability: gilt numerals that glow warm (a spell-lit gold), so they
    # read even where the metal mirrors a dark ceiling.
    gilt = k.add_shader(k.bsdf(Base_Color=(1.0, 0.7, 0.28, 1), Metallic=0.8, Roughness=0.3, Normal=nrm),
                        k.emission((1.0, 0.55, 0.14, 1), 0.6))
    s = k.mix_shader(k.math("MAXIMUM", edge, dec), body, gold)
    k.surface(k.mix_shader(num, s, gilt))
    return m


def material_fateengine(img):
    m = bpy.data.materials.new("Fate Engine gunmetal")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    edge = k.edge
    obj = k.coords().outputs["Object"]
    brush = k.node("ShaderNodeMapping")
    brush.inputs["Scale"].default_value = (1.0, 30.0, 1.0)
    k.link(obj, brush.inputs["Vector"])
    streak = k.noise(brush.outputs[0], 25.0, 3).outputs["Fac"]
    nrm = _framed(k, h, edge, lip=0.6, engrave=0.9, normal=k.bump(streak, 0.05, 0.01))
    grime = k.noise(obj, 3.0, 8, 0.6).outputs["Fac"]
    body = k.bsdf(Base_Color=k.ramp(grime, [(0.3, (0.05, 0.055, 0.058)), (0.7, (0.14, 0.15, 0.155))]),
                  Metallic=1.0, Roughness=k.math("ADD", k.math("MULTIPLY", streak, 0.15), 0.3), Normal=nrm)
    brass = k.bsdf(Base_Color=k.mix(k.math("MULTIPLY", grime, 0.6), (0.95, 0.68, 0.3, 1), (0.35, 0.2, 0.08, 1)),
                   Metallic=1.0, Roughness=0.3, Normal=nrm)
    # Sigil marks are brass now (round 1 lit them teal too: too green); only
    # the numerals carry the engine's charge. Readability: glowing aqua
    # numerals in a dark keyline.
    s = k.mix_shader(k.math("MAXIMUM", edge, dec), body, brass)
    s = k.keyline(s, (0.008, 0.01, 0.01), rough=0.55, normal=nrm)
    teal = k.add_shader(k.bsdf(Base_Color=(0.02, 0.1, 0.1, 1), Roughness=0.3, Normal=nrm),
                        k.emission((0.35, 1.0, 0.85, 1), 6.0))
    k.surface(k.mix_shader(num, s, teal))
    return m


def material_celestial(img):
    m = bpy.data.materials.new("Celestial nebula")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    edge = k.edge
    obj = k.coords().outputs["Object"]
    warp = k.noise(obj, 1.2, 4).outputs["Color"]
    vec = k.mix(0.5, obj, warp, "LINEAR_LIGHT")
    neb = k.noise(vec, 1.8, 10, 0.65, dist=0.8).outputs["Fac"]
    # Round 2: saturated indigo -> violet -> magenta with cyan wisps (round 1
    # read grey-violet).
    col = k.ramp(neb, [(0.3, (0.006, 0.002, 0.04)), (0.5, (0.09, 0.012, 0.36)), (0.66, (0.42, 0.03, 0.62)),
                       (0.8, (0.12, 0.42, 0.95)), (0.94, (0.9, 0.62, 1.0))])
    stars, _ = _glitter(k, obj, 60.0, 0.8)
    nrm = _framed(k, h, edge, lip=0.5)
    body = k.bsdf(Base_Color=col, Roughness=0.05, Coat_Weight=1.0, Coat_Roughness=0.01, Normal=nrm,
                  Transmission_Weight=0.3, Emission_Color=col,
                  Emission_Strength=k.math("MULTIPLY", k.math("POWER", neb, 4.0), 3.0))
    body = k.add_shader(body, k.emission((0.9, 0.9, 1.0, 1), k.math("MULTIPLY", stars, 8.0)))
    body = k.keyline(body, (0.004, 0.002, 0.018), rough=0.55, normal=nrm)
    silver = k.bsdf(Base_Color=(0.9, 0.92, 0.96, 1), Metallic=1.0, Roughness=0.18, Normal=nrm)
    s = k.mix_shader(k.math("MAXIMUM", edge, dec), body, silver)
    # Readability: starlight numerals (emissive silver-white) in an indigo keyline.
    star = k.add_shader(k.bsdf(Base_Color=(0.9, 0.92, 0.96, 1), Metallic=0.6, Roughness=0.25, Normal=nrm),
                        k.emission((0.85, 0.9, 1.0, 1), 3.2))
    k.surface(k.mix_shader(num, s, star))
    return m


def material_hearthside(img):
    m = bpy.data.materials.new("Hearthside bone")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    obj = k.coords().outputs["Object"]
    mp = k.node("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0, 1.0, 8.0)
    k.link(obj, mp.inputs["Vector"])
    grain = k.noise(mp.outputs[0], 4.0, 8, 0.6).outputs["Fac"]
    ao = k.node("ShaderNodeAmbientOcclusion", samples=8)
    ao.inputs["Distance"].default_value = 0.2
    col = k.ramp(grain, [(0.3, (0.74, 0.66, 0.5)), (0.7, (0.92, 0.88, 0.76))])
    col = k.mix(k.math("MULTIPLY", k.math("SUBTRACT", 1.0, ao.outputs["AO"]), 0.8), col, (0.3, 0.2, 0.1, 1))
    nrm = _engrave(k, h, normal=k.bump(grain, 0.1, 0.02), strength=0.8, dist=0.05)
    bone = k.bsdf(Base_Color=col, Roughness=0.38, Subsurface_Weight=0.35, Subsurface_Radius=(0.5, 0.35, 0.2),
                  Normal=nrm, Coat_Weight=0.25, Coat_Roughness=0.2)
    # Readability: engraved and inked with dense sepia-black.
    ink = k.bsdf(Base_Color=(0.012, 0.005, 0.003, 1), Roughness=0.6, Normal=nrm)
    k.surface(k.mix_shader(num, bone, ink))
    return m


def material_gemcutter(img):
    m = bpy.data.materials.new("Gemcutter swirl")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    obj = k.coords().outputs["Object"]
    # Round 2: a domain-warped noise swirl instead of wave bands (round 1
    # showed regular stripes): deep emerald with soft jade ribbons and thin
    # pearl wisps.
    warp = k.noise(obj, 0.9, 3, 0.5).outputs["Color"]
    vec = k.mix(0.7, obj, warp, "LINEAR_LIGHT")
    sw = k.noise(vec, 1.3, 6, 0.55, dist=2.5).outputs["Fac"]
    # round 2.1: pale-jade wisps instead of pearl-white, so the bright
    # numerals keep their contrast wherever a wisp passes behind them
    col = k.ramp(sw, [(0.28, (0.0, 0.045, 0.022)), (0.46, (0.01, 0.16, 0.08)), (0.58, (0.02, 0.26, 0.14)),
                      (0.63, (0.12, 0.34, 0.24)), (0.67, (0.015, 0.2, 0.1)), (0.8, (0.0, 0.08, 0.04))])
    nrm = _engrave(k, h, strength=0.8, dist=0.05)
    body = k.bsdf(Base_Color=col, Roughness=0.04, Transmission_Weight=0.55, IOR=1.55, Subsurface_Weight=0.3,
                  Coat_Weight=1.0, Coat_Roughness=0.01, Normal=nrm)
    body = k.keyline(body, (0.0, 0.025, 0.012), rough=0.35, normal=nrm)
    # Readability: warm-gold enamel numerals (part diffuse) in a deep-green keyline.
    paint = k.bsdf(Base_Color=(1.0, 0.95, 0.8, 1), Metallic=0.15, Roughness=0.3, Normal=nrm)
    k.surface(k.mix_shader(num, body, paint))
    return m


def _srgb(hexcode):
    h = hexcode.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


DN_GRADIENT = [_srgb(c) for c in ("#FA60A6", "#EF388B", "#E99173", "#D7BA52", "#B5C75E")]


def material_dartnative(img):
    """The app's own set: #090E12 body, brand-gradient glowing edges (like
    the 3D logo), a cyan inlay line, white numerals (lime is the tray's one accent)."""
    m = bpy.data.materials.new("DartNative")
    k = NodeKit(m)
    num, dec, h = k.atlas(img)
    edge = k.edge
    obj = k.coords().outputs["Object"]
    nrm = _engrave(k, h, strength=0.5, dist=0.02)
    body = k.bsdf(Base_Color=(*_srgb("#090E12"), 1), Roughness=0.28, Coat_Weight=1.0, Coat_Roughness=0.04,
                  Normal=nrm)
    # the gradient runs around the die (object-space angle, drifting with height)
    ang = k.node("ShaderNodeTexGradient", gradient_type="RADIAL")
    k.link(obj, ang.inputs["Vector"])
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    fac = k.math("FRACT", k.math("ADD", ang.outputs["Fac"], k.math("MULTIPLY", sep.outputs["Z"], 0.12)))
    stops = [(i / len(DN_GRADIENT), c) for i, c in enumerate(DN_GRADIENT)] + [(1.0, DN_GRADIENT[0])]
    grad = k.emission(k.ramp(fac, stops), 2.4)
    s = k.mix_shader(k.math("MULTIPLY", edge, 0.85), body, grad)
    # decor atlas G: a thin cyan inlay line just inside each face edge
    cyan = k.emission((*_srgb("#03C3F0"), 1), 3.0)
    s = k.mix_shader(dec, s, cyan)
    s = k.keyline(s, (0.002, 0.003, 0.004), rough=0.5, normal=nrm)
    white = k.add_shader(k.bsdf(Base_Color=(0.9, 0.95, 1.0, 1), Roughness=0.3, Normal=nrm),
                         k.emission((0.88, 0.96, 1.0, 1), 4.0))
    k.surface(k.mix_shader(num, s, white))
    return m


SHELL_MATERIALS = {
    "arcane": material_arcane,
    "fateengine": material_fateengine,
    "celestial": material_celestial,
    "hearthside": material_hearthside,
    "gemcutter": material_gemcutter,
    "emberforged": material_emberforged,
    "frostbound": material_frostbound,
    "oldroad": material_oldroad,
    "northfield": material_northfield,
    "voltline": material_voltline,
    "vermilion": material_vermilion,
    "dartnative": material_dartnative,
}
CORE_MATERIALS = {"emberforged": material_ember_core, "frostbound": material_frost_core}


# --------------------------------------------------------------------------
# Set assembly
# --------------------------------------------------------------------------

def all_specs():
    return {kind: die_spec(kind) for kind in KINDS}


def make_set(theme, atlas_dir, collection=None, specs=None):
    """Create the seven dice for `theme`. Returns {kind: object}, specs, stats."""
    specs = specs or all_specs()
    atlas = build_atlas(theme, specs, atlas_dir)
    img = load_atlas(atlas)
    global HALO
    HALO = load_atlas(Path(atlas).with_name(f"{theme}_halo.png"))
    shell = SHELL_MATERIALS[theme](img)
    core_mat = CORE_MATERIALS[theme]() if theme in CORE_MATERIALS else None
    coll = collection or bpy.context.scene.collection
    bases = cell_bases()
    objs, stats = {}, {}
    for kind in KINDS:
        mesh, tris = build_die_mesh(specs[kind], f"{theme}_{kind}", bases[kind])
        mesh.materials.append(shell)
        ob = bpy.data.objects.new(f"{theme}_{kind}", mesh)
        ob.rotation_mode = "QUATERNION"
        coll.objects.link(ob)
        stats[kind] = tris
        if core_mat is not None:
            cm = build_core_mesh(specs[kind], f"{theme}_{kind}_core")
            cm.materials.append(core_mat)
            core = bpy.data.objects.new(f"{theme}_{kind}_core", cm)
            coll.objects.link(core)
            core.parent = ob
            stats[kind + "_core"] = len(cm.polygons)
        objs[kind] = ob
    stats["numeral_ratio_min"] = {kind: round(specs[kind]["numeral_ratio_min"], 3) for kind in KINDS}
    stats["stroke_ratio"] = {kind: round(specs[kind]["stroke_ratio"], 3) for kind in KINDS}
    return objs, specs, stats, atlas


def face_quaternion(spec, value, up=Vector((0, 0, 1)), facing=Vector((0, 1, 0))):
    """Rotation that puts `value` on top, its numeral reading toward `facing`."""
    f = next(f for f in spec["faces"] if f["value"] == value)
    n_src, u_src = f["n"], f["up"]
    r_src = u_src.cross(n_src).normalized()
    u_src = n_src.cross(r_src).normalized()
    facing = (facing - up * facing.dot(up)).normalized()
    r_dst = facing.cross(up).normalized()
    src = Matrix((r_src, u_src, n_src)).transposed()
    dst = Matrix((r_dst, facing, up)).transposed()
    return (dst @ src.transposed()).to_quaternion()


def rest_height(spec):
    """Centre height above the table when resting on a face."""
    return spec["inradius"]


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def _args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--theme", default="emberforged", choices=sorted(THEMES))
    ap.add_argument("--faces-json")
    ap.add_argument("--atlas-dir", default=str(HERE / "out"))
    ap.add_argument("--export-glb")
    ap.add_argument("--save-blend")
    ap.add_argument("--stats", action="store_true")
    return ap.parse_args(argv)


def main():
    a = _args()
    specs = all_specs()
    if a.faces_json:
        Path(a.faces_json).write_text(json.dumps(face_map(specs), indent=2) + "\n")
        print(f"dice_lookdev: wrote {a.faces_json}")
    if a.stats or a.export_glb or a.save_blend:
        for ob in list(bpy.data.objects):
            bpy.data.objects.remove(ob)
        objs, specs, stats, atlas = make_set(a.theme, a.atlas_dir, specs=specs)
        print("dice_lookdev: triangles", json.dumps(stats))
        print(f"dice_lookdev: atlas {atlas}")
        if a.export_glb:
            out = Path(a.export_glb)
            out.mkdir(parents=True, exist_ok=True)
            for kind, ob in objs.items():
                bpy.ops.object.select_all(action="DESELECT")
                ob.select_set(True)
                bpy.context.view_layer.objects.active = ob
                bpy.ops.export_scene.gltf(filepath=str(out / f"{a.theme}_{kind}.glb"), use_selection=True,
                                          export_yup=True, export_apply=True)
            print(f"dice_lookdev: glb -> {out}")
        if a.save_blend:
            bpy.ops.wm.save_as_mainfile(filepath=a.save_blend)


if __name__ == "__main__":
    main()
