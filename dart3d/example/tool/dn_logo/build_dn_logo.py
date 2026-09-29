"""Builds the 3D DartNative logo for the dart3d Showcase (plan item P4).

Run headless from the repo root:

    /Applications/Blender.app/Contents/MacOS/Blender --background \
        --python dart3d/example/tool/dn_logo/build_dn_logo.py -- \
        [--debug-png out.png]

Inputs (committed): dart3d/example/assets_src/dn_logo/dn-logo.svg
Outputs:            dart3d/example/assets_src/dn_logo/dn_logo.glb
                    dart3d/example/assets_src/dn_logo/dn_logo_basecolor.png
Then `build.sh` converts the .glb to assets/showcase/dn_logo.fsceneb with
flutter_scene's own importer (same path as the other showcase assets).

Approach
--------
The logo is one brush stroke, so instead of extruding the outline we
sweep a round-ish profile along the stroke's centerline:

1. Read the SVG's path data and flatten it (cubics + elliptical arcs)
   into the outline polygon in SVG units. (Blender 5.2's own SVG
   importer turns the arcs into chords, squaring off the round ends,
   so the script parses the path itself.)
2. The centerline starts from a short list of hand-placed guide points
   (SVG units), smoothed with Catmull-Rom and resampled by arc length,
   then refined against the outline: rays along the in-plane normal
   find both walls, and each sample moves to their midpoint (see
   `build_stroke`). The stroke is split in two where the
   pen reverses at the bottom of the first stem: A = entry tail ->
   first arch -> first stem; B = first stem -> second arch -> second
   stem -> exit tail. Both start/end at the same point, so their caps
   merge into one rounded foot.
3. The tube radius at each sample is half the wall-to-wall width
   (clamped + smoothed, never past the outline), so the 3D stroke keeps the
   logo's brush-width variation. The profile is an ellipse: in-plane
   half-width r, depth half-thickness DEPTH_RATIO * r. Ends get
   ellipsoidal caps.
4. UVs: u runs along the stroke (caps included), v around the profile;
   stroke A lives in the bottom half of the texture, B in the top half.
5. The base-color texture is baked analytically: each texel maps back to
   a 3D surface point, whose SVG-plane (x, y) evaluates the logo's own
   four stacked linear gradients (pink->gold->green base, two yellow
   highlight bands, the yellow->cyan diagonal overlay) composited in
   sRGB exactly as the SVG paints them. A soft analytic sphere-AO term
   darkens the crease where the two strokes meet (and the texels
   buried inside the other stroke, which never show). The material is
   glTF PBR — glossy base (roughness 0.18) under a clear coat — so
   scene lights still shade it. (The showcase adds a faint emissive
   from the same texture.)
6. A 6 s looping clip ("Spin"): one full turn about the vertical axis
   plus a gentle upward bob and a small nod, sampled per frame.
"""

import math
import os
import re
import sys

import bpy
import numpy as np

# ── Paths ───────────────────────────────────────────────────────────
HERE = os.path.dirname(os.path.abspath(__file__))
EXAMPLE = os.path.normpath(os.path.join(HERE, "..", ".."))
SRC_DIR = os.path.join(EXAMPLE, "assets_src", "dn_logo")
SVG_PATH = os.path.join(SRC_DIR, "dn-logo.svg")
GLB_PATH = os.path.join(SRC_DIR, "dn_logo.glb")
TEX_PATH = os.path.join(SRC_DIR, "dn_logo_basecolor.png")

# ── Tunables ────────────────────────────────────────────────────────
TEX_SIZE = 1024
RING_SEGMENTS = 32          # vertices around the profile
SAMPLE_SPACING = 0.55       # centerline spacing, SVG units
CAP_RINGS = 8               # rings per end cap (last collapses to a pole)
DEPTH_RATIO = 0.85          # depth half-thickness / in-plane half-width
R_MIN, R_MAX = 1.6, 3.8     # clamp for the outline-derived radius
WALL_MAX = 4.6              # farther wall hit = overlap, not this stroke
PASSES = 4                  # centerline refinement passes
WORLD_WIDTH = 2.0           # logo width in scene units
HOVER = 0.18                # gap between rest pose and the ground plane
ROUGHNESS = 0.18            # glossy base lobe
CLEARCOAT = 1.0             # KHR_materials_clearcoat factor
CLEARCOAT_ROUGHNESS = 0.05  # crisp travelling highlights
CLIP_NAME = "Spin"
FPS = 30
CLIP_SECONDS = 6.0
BOB = 0.06                  # upward bob amplitude, scene units
NOD_DEG = 5.0               # forward/back nod amplitude

# Centerline guide points (SVG units, y down), traced through the
# middle of the stroke over the 56x56 viewBox.
STROKE_A = [
    (8.55, 25.05), (9.6, 22.7), (11.3, 19.9), (13.6, 17.4), (16.2, 16.1),
    (18.9, 16.4), (20.9, 18.3), (21.6, 21.3), (21.3, 25.0), (20.4, 29.6),
    (19.5, 34.0), (18.9, 37.6), (18.75, 40.0),
]
STROKE_B = [
    (18.75, 40.0), (19.5, 37.5), (21.0, 33.6), (22.9, 29.0), (25.0, 24.8),
    (27.4, 21.0), (30.2, 18.1), (33.2, 16.6), (36.0, 17.2), (37.6, 19.6),
    (37.8, 23.0), (36.9, 27.2), (35.6, 31.4), (34.5, 35.4), (34.5, 38.9),
    (36.0, 41.4), (38.9, 41.9), (42.0, 39.6), (44.4, 36.3), (46.1, 33.1),
    (46.9, 30.8),
]


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    debug_png = None
    if "--debug-png" in argv:
        debug_png = argv[argv.index("--debug-png") + 1]
    return debug_png


# ── 1. SVG outline ──────────────────────────────────────────────────
def import_outline():
    """The logo outline as a closed polygon in SVG units (y down).

    Parses the SVG's path data directly: Blender 5.2's SVG importer
    flattens elliptical-arc commands to chords, which squares off the
    stroke's round ends (all three caps are `a` arcs).
    """
    bpy.ops.wm.read_factory_settings(use_empty=True)
    svg = open(SVG_PATH, encoding="utf-8").read()
    d = re.search(r'<path class="cls-1" d="([^"]+)"', svg).group(1)
    return np.array(flatten_path(d), dtype=np.float64)


def flatten_path(d, steps=12):
    toks = re.findall(r"[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?", d)
    pts, i = [], 0
    cur = np.zeros(2)
    start = np.zeros(2)
    prev_ctrl = None
    cmd = None

    def num():
        nonlocal i
        v = float(toks[i])
        i += 1
        return v

    def cubic(p0, p1, p2, p3):
        for t in np.linspace(0, 1, steps + 1)[1:]:
            mt = 1 - t
            pts.append(mt ** 3 * p0 + 3 * mt * mt * t * p1
                       + 3 * mt * t * t * p2 + t ** 3 * p3)

    def arc(p0, rx, ry, phi, large, sweep, p1):
        # SVG 1.1 F.6.5 endpoint -> center parameterization.
        phi = math.radians(phi)
        cp, sp = math.cos(phi), math.sin(phi)
        dx, dy = (p0 - p1) / 2
        x1 = cp * dx + sp * dy
        y1 = -sp * dx + cp * dy
        rx, ry = abs(rx), abs(ry)
        lam = x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry)
        if lam > 1:
            rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
        num_ = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        co = math.sqrt(max(num_ / den, 0)) * (-1 if large == sweep else 1)
        cx1, cy1 = co * rx * y1 / ry, -co * ry * x1 / rx
        cx = cp * cx1 - sp * cy1 + (p0[0] + p1[0]) / 2
        cy = sp * cx1 + cp * cy1 + (p0[1] + p1[1]) / 2

        def ang(ux, uy, vx, vy):
            a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
            return a

        t1 = ang(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        dt = ang((x1 - cx1) / rx, (y1 - cy1) / ry,
                 (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if not sweep and dt > 0:
            dt -= 2 * math.pi
        elif sweep and dt < 0:
            dt += 2 * math.pi
        n = max(int(abs(dt) / (math.pi / 24)), 2)
        for k in range(1, n + 1):
            t = t1 + dt * k / n
            x, y = rx * math.cos(t), ry * math.sin(t)
            pts.append(np.array([cp * x - sp * y + cx, sp * x + cp * y + cy]))

    while i < len(toks):
        if toks[i].isalpha():
            cmd = toks[i]
            i += 1
        rel = cmd.islower()
        base = cur if rel else np.zeros(2)
        c = cmd.upper()
        if c == "M":
            cur = base + np.array([num(), num()])
            start = cur.copy()
            pts.append(cur.copy())
            cmd = "l" if rel else "L"
            prev_ctrl = None
        elif c == "L":
            cur = base + np.array([num(), num()])
            pts.append(cur.copy())
            prev_ctrl = None
        elif c == "H":
            cur = np.array([(cur[0] if rel else 0) + num(), cur[1]])
            pts.append(cur.copy())
            prev_ctrl = None
        elif c == "V":
            cur = np.array([cur[0], (cur[1] if rel else 0) + num()])
            pts.append(cur.copy())
            prev_ctrl = None
        elif c == "C":
            p1 = base + np.array([num(), num()])
            p2 = base + np.array([num(), num()])
            p3 = base + np.array([num(), num()])
            cubic(cur, p1, p2, p3)
            prev_ctrl, cur = p2, p3
        elif c == "S":
            p1 = 2 * cur - prev_ctrl if prev_ctrl is not None else cur
            p2 = base + np.array([num(), num()])
            p3 = base + np.array([num(), num()])
            cubic(cur, p1, p2, p3)
            prev_ctrl, cur = p2, p3
        elif c == "A":
            rx, ry, phi = num(), num(), num()
            large, sweep = int(num()), int(num())
            p1 = base + np.array([num(), num()])
            arc(cur, rx, ry, phi, large, sweep, p1)
            cur = p1
            prev_ctrl = None
        elif c == "Z":
            cur = start.copy()
            prev_ctrl = None
        else:
            raise ValueError("unsupported path command " + cmd)
    # drop duplicate closing point
    out = [pts[0]]
    for p in pts[1:]:
        if np.linalg.norm(p - out[-1]) > 1e-6:
            out.append(p)
    if np.linalg.norm(out[-1] - out[0]) < 1e-6:
        out.pop()
    return out


def seg_distance(points, poly):
    """Min distance from each point (N,2) to the closed polyline."""
    a = poly
    b = np.roll(poly, -1, axis=0)
    ab = b - a
    ab2 = np.maximum((ab * ab).sum(1), 1e-12)
    out = np.empty(len(points))
    for i, p in enumerate(points):
        t = np.clip(((p - a) * ab).sum(1) / ab2, 0, 1)
        d = a + ab * t[:, None] - p
        out[i] = np.sqrt((d * d).sum(1).min())
    return out


def inside(points, poly):
    """Even-odd point-in-polygon for (N,2) points."""
    x, y = points[:, 0][:, None], points[:, 1][:, None]
    x1, y1 = poly[:, 0][None], poly[:, 1][None]
    x2, y2 = np.roll(poly[:, 0], -1)[None], np.roll(poly[:, 1], -1)[None]
    cond = (y1 > y) != (y2 > y)
    xint = x1 + (y - y1) * (x2 - x1) / np.where(y2 == y1, 1e-12, y2 - y1)
    return ((cond & (x < xint)).sum(1) % 2) == 1


# ── 2-3. Centerline + radius ────────────────────────────────────────
def catmull_rom(pts, per_seg=24):
    p = np.array(pts, dtype=np.float64)
    p = np.vstack([2 * p[0] - p[1], p, 2 * p[-1] - p[-2]])
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for t in np.linspace(0, 1, per_seg, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t
                              + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(p[-2])
    return np.array(out)


def resample(curve, spacing):
    d = np.sqrt((np.diff(curve, axis=0) ** 2).sum(1))
    s = np.concatenate([[0], np.cumsum(d)])
    n = max(int(round(s[-1] / spacing)), 2)
    ss = np.linspace(0, s[-1], n + 1)
    return np.stack([np.interp(ss, s, curve[:, 0]),
                     np.interp(ss, s, curve[:, 1])], 1), ss


def smooth(v, k=5):
    pad = np.pad(v, k, mode="edge")
    ker = np.ones(2 * k + 1) / (2 * k + 1)
    return np.convolve(pad, ker, mode="valid")


def ray_hit(p, d, poly):
    """Distance along unit ray p + t*d to the first outline crossing."""
    a = poly
    e = np.roll(poly, -1, axis=0) - a
    w = a - p
    den = d[0] * e[:, 1] - d[1] * e[:, 0]
    ok = np.abs(den) > 1e-12
    den = np.where(ok, den, 1.0)
    t = (w[:, 0] * e[:, 1] - w[:, 1] * e[:, 0]) / den
    u = (w[:, 0] * d[1] - w[:, 1] * d[0]) / den
    hit = ok & (t > 1e-6) & (u >= 0) & (u <= 1)
    return t[hit].min() if hit.any() else np.inf


def tangents(c):
    tan = np.gradient(c, axis=0)
    return tan / np.linalg.norm(tan, axis=1)[:, None]


def fill_invalid(v, valid):
    idx = np.arange(len(v))
    return np.interp(idx, idx[valid], v[valid])


def build_stroke(guides, poly):
    """Centers the guide curve between the outline's walls.

    Each pass casts rays both ways along the in-plane normal: where both
    walls are near (a plain stroke section) the point moves to their
    midpoint and the radius is half the wall-to-wall width. Where one
    ray runs long (the V where the two strokes overlap) the sample is
    filled from its neighbours. The end points slide along the tangent
    until the cap tip meets the outline.
    """
    curve = catmull_rom(guides)
    for _ in range(PASSES):
        c, s = resample(curve, SAMPLE_SPACING)
        t = tangents(c)
        n = np.stack([-t[:, 1], t[:, 0]], 1)
        dp = np.array([ray_hit(p, d, poly) for p, d in zip(c, n)])
        dm = np.array([ray_hit(p, -d, poly) for p, d in zip(c, n)])
        valid = (dp < WALL_MAX) & (dm < WALL_MAX)
        shift = fill_invalid((dp - dm) / 2, valid)
        r = fill_invalid((dp + dm) / 2, valid)
        c = c + n * smooth(shift, 3)[:, None] * 0.8
        r = smooth(r, 3)
        # caps: tip of the ellipsoidal cap sits r past the end point
        for end, sign in ((0, -1.0), (-1, 1.0)):
            de = ray_hit(c[end], sign * t[end], poly)
            if de < WALL_MAX * 2:
                c[end] = c[end] + sign * t[end] * (de - r[end]) * 0.8
        curve = np.vstack([c[:1], np.stack(
            [smooth(c[:, 0], 2), smooth(c[:, 1], 2)], 1)[1:-1], c[-1:]])
    c, s = resample(curve, SAMPLE_SPACING)
    t = tangents(c)
    n = np.stack([-t[:, 1], t[:, 0]], 1)
    dp = np.array([ray_hit(p, d, poly) for p, d in zip(c, n)])
    dm = np.array([ray_hit(p, -d, poly) for p, d in zip(c, n)])
    valid = (dp < WALL_MAX) & (dm < WALL_MAX)
    r = np.clip(smooth(fill_invalid((dp + dm) / 2, valid), 3), R_MIN, R_MAX)
    # Never spill past the outline (end caps sit inside disk(c_end, r)).
    r = np.minimum(r, smooth(seg_distance(c, poly), 2) * 1.04)
    return {"c": c, "s": s, "r": r, "t": t}


def rings_for(stroke):
    """Ring list: (center_xy, tangent_xy, a, b) incl. both end caps."""
    c, r, t = stroke["c"], stroke["r"], stroke["t"]
    rings = []
    # start cap: pole first
    for k in range(CAP_RINGS, 0, -1):
        phi = k / CAP_RINGS * (math.pi / 2)
        a = r[0] * math.cos(phi)
        rings.append((c[0] - t[0] * r[0] * math.sin(phi), t[0], a,
                      a * DEPTH_RATIO))
    for i in range(len(c)):
        rings.append((c[i], t[i], r[i], r[i] * DEPTH_RATIO))
    for k in range(1, CAP_RINGS + 1):
        phi = k / CAP_RINGS * (math.pi / 2)
        a = r[-1] * math.cos(phi)
        rings.append((c[-1] + t[-1] * r[-1] * math.sin(phi), t[-1], a,
                      a * DEPTH_RATIO))
    return rings


def ring_u(rings):
    """u parameter per ring: arc length of the (cap-extended) path."""
    cs = np.array([r[0] for r in rings])
    d = np.sqrt((np.diff(cs, axis=0) ** 2).sum(1))
    # caps: add the profile arc so the pole regions get texels too
    s = np.concatenate([[0], np.cumsum(np.maximum(d, 1e-3))])
    return s / s[-1]


# ── Logo gradients (straight from the SVG <defs>) ───────────────────
def hexc(h):
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)])


G1 = [(0, "#fa60a6", 1), (0.32, "#ef388b", 1), (0.5, "#e99173", 1),
      (0.77, "#d7ba52", 1), (1, "#b5c75e", 1)]
G2 = [(0, "#f9d126", 0), (0.11, "#f7d128", 0.05), (0.31, "#f2d02c", 0.17),
      (0.52, "#eccf31", 0.32), (0.55, "#eacf33", 0.46),
      (0.6, "#e5ce37", 0.81), (0.63, "#e2ce39", 1), (0.69, "#d8cc41", 0.77),
      (0.77, "#cbca4c", 0.5), (0.85, "#c2c953", 0.28),
      (0.91, "#bbc859", 0.13), (0.97, "#b7c75d", 0.03),
      (1, "#b5c75e", 0)]
G3 = [(0, "#f9d126", 0), (0.17, "#f7d028", 0.04), (0.28, "#f5d02a", 0.08),
      (0.3, "#f4d02b", 0.15), (0.36, "#f0cf2e", 0.34),
      (0.43, "#eacf33", 0.64), (0.52, "#e2ce39", 1), (0.6, "#d8cc41", 0.77),
      (0.7, "#cbca4c", 0.5), (0.8, "#c2c953", 0.28),
      (0.89, "#bbc859", 0.13), (0.95, "#b7c75d", 0.03),
      (1, "#b5c75e", 0)]
G4 = [(0, "#f9d126", 0), (0.16, "#ebd031", 0.05), (0.24, "#e2d039", 0.08),
      (0.26, "#e4d037", 0.14), (0.29, "#eacf33", 0.3),
      (0.33, "#f4ce2c", 0.56), (0.36, "#fdcd25", 0.8),
      (0.5, "#bbca5b", 0.85), (0.82, "#17c4e0", 0.98),
      (0.86, "#03c3f0", 1)]


def eval_gradient(stops, t):
    offs = np.array([s[0] for s in stops])
    cols = np.array([hexc(s[1]) for s in stops])
    alph = np.array([s[2] for s in stops], dtype=np.float64)
    t = np.clip(t, 0, 1)
    rgb = np.stack([np.interp(t, offs, cols[:, i]) for i in range(3)], -1)
    return rgb, np.interp(t, offs, alph)


def logo_color(x, y):
    """sRGB color of the flat logo at SVG point(s) (x, y)."""
    tx = (x - 6.14) / (49.86 - 6.14)
    rgb, _ = eval_gradient(G1, tx)
    for stops, t in ((G2, tx), (G3, tx)):
        c, a = eval_gradient(stops, t)
        rgb = rgb * (1 - a[..., None]) + c * a[..., None]
    dx, dy = 47.39 - 8.02, 37.01 - 20.3
    t4 = ((x - 8.02) * dx + (y - 20.3) * dy) / (dx * dx + dy * dy)
    c, a = eval_gradient(G4, t4)
    return rgb * (1 - a[..., None]) + c * a[..., None]


# ── 4-5. Mesh + texture ─────────────────────────────────────────────
V_BANDS = ((0.02, 0.48), (0.52, 0.98))   # stroke A, stroke B
U_PAD = 0.01


def surface(ring_arr, theta):
    """3D point + normal (SVG units, z = depth) for ring params."""
    cx, cy, tx, ty, a, b = ring_arr.T
    nx, ny = -ty, tx                      # in-plane normal
    ct, st = np.cos(theta), np.sin(theta)
    px = cx + nx * a * ct
    py = cy + ny * a * ct
    pz = b * st
    # ellipse normal (ignores the cap's tangential tilt — AO only)
    en = np.stack([nx * ct * b, ny * ct * b, st * a], -1)
    en /= np.maximum(np.linalg.norm(en, axis=-1, keepdims=True), 1e-9)
    return np.stack([px, py, pz], -1), en


def bake_texture(strokes, ring_sets, u_sets):
    size = TEX_SIZE
    img = np.zeros((size, size, 3))
    # AO occluders: spheres along both centerlines.
    occ_c, occ_r, occ_id, occ_s, occ_w = [], [], [], [], []
    for sid, st in enumerate(strokes):
        for i in range(len(st["c"])):
            occ_c.append((st["c"][i][0], st["c"][i][1], 0.0))
            occ_r.append(st["r"][i] * (1 + DEPTH_RATIO) / 2)
            # neighbouring spheres overlap; weight by spacing / diameter
            # so a run of them integrates to roughly one tube's worth
            occ_w.append(SAMPLE_SPACING / (2 * occ_r[-1]))
            occ_id.append(sid)
            occ_s.append(st["s"][i])
    occ_c = np.array(occ_c)
    occ_r = np.array(occ_r)
    occ_id = np.array(occ_id)
    occ_s = np.array(occ_s)

    us = (np.arange(size) + 0.5) / size
    vs = (np.arange(size) + 0.5) / size
    for sid, (rings, u_r, (v0, v1)) in enumerate(
            zip(ring_sets, u_sets, V_BANDS)):
        rows = np.where((vs >= (v0 - 0.02 if sid == 0 else 0.5))
                        & (vs < (0.5 if sid == 0 else v1 + 0.02)))[0]
        vv = np.clip((vs[rows] - v0) / (v1 - v0), 0, 1)
        theta = vv * 2 * math.pi
        uu = np.clip((us - U_PAD) / (1 - 2 * U_PAD), 0, 1)
        arr = np.array([(r[0][0], r[0][1], r[1][0], r[1][1], r[2], r[3])
                        for r in rings])
        s_ring = np.concatenate([
            np.full(CAP_RINGS, strokes[sid]["s"][0]),
            strokes[sid]["s"],
            np.full(CAP_RINGS, strokes[sid]["s"][-1])])
        cols = np.stack([np.interp(uu, u_r, arr[:, k]) for k in range(6)], 1)
        s_col = np.interp(uu, u_r, s_ring)
        # renormalize interpolated tangents
        tl = np.linalg.norm(cols[:, 2:4], axis=1)[:, None]
        cols[:, 2:4] /= np.maximum(tl, 1e-9)
        # grid: rows x cols
        R = cols[None, :, :].repeat(len(rows), 0).reshape(-1, 6)
        TH = np.repeat(theta, size)
        P, N = surface(R, TH)
        rgb = logo_color(P[:, 0], P[:, 1])
        # analytic sphere AO
        S = np.tile(s_col, len(rows))
        occ = np.zeros(len(P))
        for j in range(len(occ_c)):
            d = occ_c[j] - P
            dist2 = (d * d).sum(1)
            dist = np.sqrt(dist2)
            cosn = np.clip((d * N).sum(1) / np.maximum(dist, 1e-9), 0, 1)
            term = occ_w[j] * cosn * (occ_r[j] ** 2) / np.maximum(dist2, 1e-6)
            if occ_id[j] == sid:
                term = np.where(np.abs(S - occ_s[j]) < 3.2 * occ_r[j],
                                0.0, term)
            occ += term
        ao = 1.0 - 0.5 * np.clip(occ, 0, 1) ** 1.2
        img[rows] = (rgb * ao[:, None]).reshape(len(rows), size, 3)
    return img


def build_mesh(strokes, poly_center, world_scale):
    verts, faces, uvs = [], [], []
    ring_sets, u_sets = [], []
    m = RING_SEGMENTS
    for sid, st in enumerate(strokes):
        rings = rings_for(st)
        u_r = ring_u(rings)
        ring_sets.append(rings)
        u_sets.append(u_r)
        v0, v1 = V_BANDS[sid]
        base = len(verts)
        n_r = len(rings)
        # ring 0 and ring n_r-1 are single poles (a == 0 up to fp).
        for ri, (c, t, a, b) in enumerate(rings):
            nx, ny = -t[1], t[0]
            if ri in (0, n_r - 1):
                verts.append((c[0], c[1], 0.0))
                continue
            for j in range(m):
                th = 2 * math.pi * j / m
                verts.append((c[0] + nx * a * math.cos(th),
                              c[1] + ny * a * math.cos(th),
                              b * math.sin(th)))

        def vid(ri, j):
            if ri == 0:
                return base
            if ri == n_r - 1:
                return base + 1 + (n_r - 2) * m
            return base + 1 + (ri - 1) * m + (j % m)

        def uv(ri, j):
            return (U_PAD + (1 - 2 * U_PAD) * u_r[ri],
                    v0 + (v1 - v0) * j / m)

        for ri in range(n_r - 1):
            for j in range(m):
                a_, b_ = vid(ri, j), vid(ri, j + 1)
                c_, d_ = vid(ri + 1, j + 1), vid(ri + 1, j)
                q = [a_, d_, c_, b_]
                quv = [uv(ri, j), uv(ri + 1, j), uv(ri + 1, j + 1),
                       uv(ri, j + 1)]
                # collapse pole quads to triangles
                keep = [k for k in range(4)
                        if q[k] not in q[:k]]
                faces.append([q[k] for k in keep])
                uvs.append([quv[k] for k in keep])

    # SVG (x right, y down, z depth) -> Blender (X right, Z up, -Y front)
    cx, cy = poly_center
    bverts = [((x - cx) * world_scale, -z * world_scale,
               -(y - cy) * world_scale) for x, y, z in verts]
    mesh = bpy.data.meshes.new("DartNativeLogo")
    mesh.from_pydata(bverts, [], faces)
    mesh.update()
    uvl = mesh.uv_layers.new(name="UVMap")
    li = 0
    for poly, fuv in zip(mesh.polygons, uvs):
        # winding check: from_pydata keeps the face order
        for k, loop in enumerate(poly.loop_indices):
            uvl.data[loop].uv = fuv[k]
        li += 1
    for p in mesh.polygons:
        p.use_smooth = True
    # Ensure outward normals.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    return mesh, ring_sets, u_sets


def debug_png(path, poly, strokes):
    size = 560
    xs = (np.arange(size) + 0.5) / size * 56
    X, Y = np.meshgrid(xs, xs)
    pts = np.stack([X.ravel(), Y.ravel()], 1)
    ins = inside(pts, poly).reshape(size, size)
    # Coverage check of the swept tube (incl. caps) against the logo:
    # logo color = matched, red = logo not covered, blue = tube spills.
    cov = np.zeros(size * size, dtype=bool)
    # Body disks only: a cap ring lies in the plane normal to the
    # tangent, so the caps project inside the end disks already.
    for st in strokes:
        for (x, y), a in zip(st["c"], st["r"]):
            cov |= ((pts[:, 0] - x) ** 2 + (pts[:, 1] - y) ** 2) <= a * a
    cov = cov.reshape(size, size)
    img = np.ones((size, size, 3))
    col = logo_color(X, Y)
    img[ins & cov] = col[ins & cov]
    img[ins & ~cov] = (0.9, 0.1, 0.1)
    img[~ins & cov] = (0.2, 0.3, 0.9)
    for st in strokes:
        for x, y in st["c"]:
            img[int(y * 10), int(x * 10)] = (0, 0, 0)
    save_png(path, img)


def save_png(path, rgb, top_down=True):
    """Writes rgb (rows top-down, or bottom-up = UV v order) as PNG."""
    h, w, _ = rgb.shape
    im = bpy.data.images.new("tmp_png", w, h, alpha=False)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(rgb, 0, 1)
    # Blender pixel rows run bottom-up (the same order as UV v).
    im.pixels.foreach_set((rgba[::-1] if top_down else rgba).ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def build_material():
    """Glossy lacquered plastic: PBR base under a clear coat.

    Exports as glTF metallic-roughness + KHR_materials_clearcoat, both
    realized on the dart3d natives (docs/texture-material-spec.md). The
    faint glow is NOT baked in here: binding the texture to emission
    makes flutter_scene's importer emit a second 1024² image payload,
    so the showcase entry reuses the base-color texture as its emissive
    map instead (showcase_loader.dart, `emissiveGlow`).
    """
    mat = bpy.data.materials.new("DartNativeLogo")
    if not mat.use_nodes:  # node trees are the default from Blender 5
        mat.use_nodes = True
    mat.use_backface_culling = True       # closed mesh: doubleSided off
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = ROUGHNESS
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Coat Weight"].default_value = CLEARCOAT
    bsdf.inputs["Coat Roughness"].default_value = CLEARCOAT_ROUGHNESS
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(TEX_PATH)
    tex.image.colorspace_settings.name = "sRGB"
    tex.interpolation = "Linear"
    tex.extension = "EXTEND"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def animate(obj, rest_z):
    scn = bpy.context.scene
    scn.render.fps = FPS
    frames = int(CLIP_SECONDS * FPS)
    scn.frame_start, scn.frame_end = 0, frames
    obj.rotation_mode = "XYZ"
    for f in range(frames + 1):
        t = f / frames
        w = 2 * math.pi * t
        obj.location = (0.0, 0.0, rest_z + BOB * 0.5 * (1 - math.cos(2 * w)))
        obj.rotation_euler = (math.radians(NOD_DEG) * math.sin(w), 0.0, w)
        obj.keyframe_insert("location", frame=f)
        obj.keyframe_insert("rotation_euler", frame=f)
    act = obj.animation_data.action
    act.name = CLIP_NAME
    try:
        fcurves = act.fcurves
    except AttributeError:  # layered actions (Blender 4.4+)
        fcurves = [fc for layer in act.layers for strip in layer.strips
                   for bag in strip.channelbags for fc in bag.fcurves]
    for fc in fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    scn.frame_set(0)


def main():
    dbg = parse_args()
    poly = import_outline()
    strokes = [build_stroke(STROKE_A, poly), build_stroke(STROKE_B, poly)]
    if dbg:
        debug_png(dbg, poly, strokes)
        print("dn_logo: debug png ->", dbg)
    lo, hi = poly.min(0), poly.max(0)
    center = (lo + hi) / 2
    world_scale = WORLD_WIDTH / (hi[0] - lo[0])
    mesh, ring_sets, u_sets = build_mesh(strokes, center, world_scale)
    img = bake_texture(strokes, ring_sets, u_sets)
    save_png(TEX_PATH, img, top_down=False)

    obj = bpy.data.objects.new("DartNativeLogo", mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(build_material())
    half_h = (hi[1] - lo[1]) / 2 * world_scale
    animate(obj, half_h + HOVER)

    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    print("dn_logo: %d verts, %d triangles, texture %dx%d" %
          (len(mesh.vertices), tris, TEX_SIZE, TEX_SIZE))
    print("dn_logo: stroke lengths A=%.1f B=%.1f (SVG units)" %
          (strokes[0]["s"][-1], strokes[1]["s"][-1]))

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_range=True,
        export_extras=False,
        export_cameras=False,
        export_lights=False,
    )
    print("dn_logo: wrote", GLB_PATH)


main()
