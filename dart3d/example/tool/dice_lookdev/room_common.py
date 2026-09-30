"""Game rooms around the trays (look-dev round 4): the shared room kit.

Units are cm like everything else. The tray sits on a table/desk whose top
is z = 0 (each environment's own base slab sits on that table); the room
floor is at FLOOR_Z. The top-down phone camera never sees the room, only
its light; the room is for the cinematic intro's establishing shot
(`render_set.py --shots room`) and for multi-directional, motivated light
on the tray (render_set's play-view grade then subdues everything outside
the tray in the top-down view).

Conventions
- The room is a box: back wall at y = `back`, side walls at x = +-half_w,
  the front (the camera side) is open.
- Wall-mounted pieces take `wall="back" | "left" | "right"` and a position
  along it (`u`: x for the back wall, y for the side walls). They are built
  in a local frame (wall plane at local y = 0, room interior towards -y,
  outside towards +y) and rotated onto their wall.
- Every piece is procedural and original (no text, no logos).

A room = `shell` + openings (`window`, `arch_opening`) + light sources
that are also props (`fireplace`, `hanging_lantern`, `pendant_lamp`,
`sconce`, `paper_lantern`, `neon_bar`) + furniture (`work_table`,
`bookshelf`, `wall_shelf`, `chair`, `cabinet`, `rug`, `beams`).
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

_ROOM = dict(half_w=220.0, back=260.0, front=-160.0, height=300.0)


# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------

def vertical_coords(k):
    """Object coords remapped so 2D textures (brick, stripes) run along any
    vertical surface: (x + y, z, 0). Walls and piers use this; floors use
    plain object coords."""
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(k.coords().outputs["Object"], sep.inputs[0])
    comb = k.node("ShaderNodeCombineXYZ")
    k.link(k.math("ADD", sep.outputs["X"], sep.outputs["Y"]), comb.inputs["X"])
    k.link(sep.outputs["Z"], comb.inputs["Y"])
    return comb.outputs[0]


def stone(name="Stone", c1=(0.06, 0.055, 0.05), c2=(0.16, 0.14, 0.12), scale=0.04, blocks=True, rough=0.85,
          vertical=True):
    """Coursed stone / brick (brick texture + noise), or rubble if blocks=False.
    vertical=False for floors (flagstones)."""
    m, k = E.material(name)
    obj = vertical_coords(k) if vertical else k.coords().outputs["Object"]
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


def tiles(name="Tiles", c1=(0.5, 0.5, 0.48), c2=(0.1, 0.1, 0.1), scale=0.033, checker=True, rough=0.35):
    """Floor / wall tiles: a checkerboard (lino) or a plain grid with grout."""
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    if checker:
        ch = k.node("ShaderNodeTexChecker")
        k.link(obj, ch.inputs["Vector"])
        k.set(ch, Scale=scale * 100, Color1=(*c1, 1), Color2=(*c2, 1))
        col = ch.outputs["Color"]
        fac = ch.outputs["Fac"]
    else:
        b = k.node("ShaderNodeTexBrick")
        k.link(obj, b.inputs["Vector"])
        k.set(b, Scale=scale, Mortar_Size=0.01, Offset=0.0, Color1=(*c1, 1), Color2=(*c1, 1), Mortar=(*c2, 1),
              Squash=1.0, Bias=0.0)
        col = b.outputs["Color"]
        fac = b.outputs["Fac"]
    n = k.noise(obj, 0.3, 4).outputs["Fac"]
    col = k.mix(k.math("MULTIPLY", n, 0.25), col, (0.0, 0.0, 0.0, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=rough, Normal=k.bump(fac, 0.2, 0.3)))
    return m


def wallpaper(name="Wallpaper", c1=(0.3, 0.22, 0.12), c2=(0.18, 0.12, 0.07), stripes=0.1):
    """Vertical-stripe wallpaper (1980s kitchen / study)."""
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    u = k.math("ADD", sep.outputs["X"], sep.outputs["Y"])  # runs along either wall orientation
    s = k.math("GREATER_THAN", k.math("SINE", k.math("MULTIPLY", u, stripes * 6.283)), 0.3)
    n = k.noise(obj, 0.05, 5).outputs["Fac"]
    col = k.mix(s, (*c1, 1), (*c2, 1))
    col = k.mix(k.math("MULTIPLY", n, 0.3), col, (0, 0, 0, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.85))
    return m


def fire_material(strength=18.0, name="Flame"):
    """Surface flame (emission + transparency): reads as fire at a fraction of a volume's cost."""
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    warp = k.noise(obj, 1.2, 3, 0.5, dims="4D", w=0.3).outputs["Color"]
    vec = k.mix(0.4, obj, warp, "LINEAR_LIGHT")
    n = k.noise(vec, 2.2, 6, 0.6, dist=0.6).outputs["Fac"]
    up = k.math("SUBTRACT", 1.0, k.math("MULTIPLY", k.math("ADD", sep.outputs["Z"], 1.0), 0.5), clamp=True)
    lw = k.node("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.5
    core = k.math("SUBTRACT", 1.0, lw.outputs["Fresnel"])
    heat = k.math("MULTIPLY", k.math("MULTIPLY", k.math("POWER", n, 1.6), up), core)
    heat = k.math("MULTIPLY", heat, 4.0, clamp=True)
    col = k.ramp(heat, [(0.0, (0.3, 0.02, 0.0)), (0.4, (1.0, 0.25, 0.02)), (0.8, (1.0, 0.65, 0.2)),
                        (1.0, (1.0, 0.95, 0.75))])
    em = k.emission(col, k.math("MULTIPLY", heat, strength * 0.5))
    tr = k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(k.math("POWER", heat, 0.5), tr, em))
    return m


# --------------------------------------------------------------------------
# Architecture
# --------------------------------------------------------------------------

def _wall_frame(wall, u):
    """(location of the local origin, z rotation) for a point u along `wall`, at the floor."""
    r = _ROOM
    if wall == "back":
        return Vector((u, r["back"], 0.0)), 0.0
    if wall == "left":
        return Vector((-r["half_w"], u, 0.0)), math.radians(90)
    if wall == "right":
        return Vector((r["half_w"], u, 0.0)), math.radians(-90)
    raise ValueError(wall)


def _group(name, objs, loc, rot_z):
    """Parent `objs` (built in a local frame) to an empty at loc, rotated about z."""
    g = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(g)
    for o in objs:
        o.parent = g
    g.location = loc
    g.rotation_euler = (0, 0, rot_z)
    return g


def to_world(wall, u, local):
    """World position of `local` (x along the wall, y into the room is -y, z) on `wall` at u."""
    loc, rz = _wall_frame(wall, u)
    v = Vector(local)
    c, s = math.cos(rz), math.sin(rz)
    return loc + Vector((v.x * c - v.y * s, v.x * s + v.y * c, v.z))


def wall_plane(name, length, height, openings, mat, thickness=18.0):
    """A wall in local x/z (x centred on 0, z from 0 to height) with rectangular
    holes (openings: (x, z_centre, w, h)), solidified outwards (+y) so the
    openings get real reveals."""
    xs = sorted({-length / 2, length / 2, *[o[0] + s * o[2] / 2 for o in openings for s in (-1, 1)]})
    zs = sorted({0.0, height, *[o[1] + s * o[3] / 2 for o in openings for s in (-1, 1)]})
    bm = bmesh.new()
    verts = {}

    def v(x, z):
        key = (round(x, 3), round(z, 3))
        if key not in verts:
            verts[key] = bm.verts.new((x, 0.0, z))
        return verts[key]

    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            cx, cz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
            if any(abs(cx - o[0]) < o[2] / 2 and abs(cz - o[1]) < o[3] / 2 for o in openings):
                continue
            bm.faces.new((v(xs[i], zs[j]), v(xs[i + 1], zs[j]), v(xs[i + 1], zs[j + 1]), v(xs[i], zs[j + 1])))
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    ob = E.mesh_object(name, bm, mat)
    sol = ob.modifiers.new("thickness", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = -1.0
    return ob


def shell(half_w=220, back=260, front=-160, height=300, wall=None, floor=None, ceiling=None, side_walls=True,
          openings=None, side_mats=None, floor_z=-76.0, back_wall=True):
    """Floor, back wall, side walls (optional) and ceiling (optional); the front is open.

    openings: {"back"|"left"|"right": [(u, z, w, h), ...]} holes in the walls
    (u along the wall as in `_wall_frame`, z in world cm). Put a `window` or
    `arch_opening` in each. floor_z: the room floor (default -76, a table
    room; an altar/ground environment passes its own ground height)."""
    global FLOOR_Z
    FLOOR_Z = floor_z  # every kit piece reads it at call time (default: table rooms)
    _ROOM.update(half_w=half_w, back=back, front=front, height=height)
    wall = wall or plaster()
    openings = openings or {}
    side_mats = side_mats or {}
    if floor is not False:  # False: the environment already has its own ground
        E.plane("room_floor", 2 * half_w + 40, back - front + 40, (0, (back + front) / 2, FLOOR_Z),
                floor or planks())

    def local(ops, centre):
        return [(u - centre, z - FLOOR_Z, w, h) for (u, z, w, h) in ops]

    if back_wall:  # False: an open loggia / balcony
        bw = wall_plane("wall_back", 2 * half_w, height, local(openings.get("back", []), 0.0), wall)
        _group("wall_back_g", [bw], Vector((0, back, FLOOR_Z)), 0.0)
    if side_walls:
        mid = (back + front) / 2
        for side, sx in (("left", -1), ("right", 1)):
            # local x runs along +y on the left wall and -y on the right wall
            ops = [((u - mid) * (1 if side == "left" else -1), z, w, h) for (u, z, w, h) in openings.get(side, [])]
            sw = wall_plane(f"wall_{side}", back - front, height, local(ops, 0.0), side_mats.get(side, wall))
            _group(f"wall_{side}_g", [sw], Vector((sx * half_w, mid, FLOOR_Z)), math.radians(90 if sx < 0 else -90))
    if ceiling:
        E.plane("ceiling", 2 * half_w + 40, back - front + 40, (0, (back + front) / 2, FLOOR_Z + height), ceiling)


def beams(mat, n=4, size=(22, 26), z=None, along="x"):
    """Heavy ceiling beams (timber frame)."""
    r = _ROOM
    z = (FLOOR_Z + r["height"] - size[1] / 2) if z is None else z
    if along == "x":
        for i in range(n):
            y = r["front"] + (i + 0.5) * (r["back"] - r["front"]) / n
            E.cube("beam", (2 * r["half_w"], size[0], size[1]), (0, y, z), mat, bevel=1.0)
    else:
        for i in range(n):
            x = -r["half_w"] + (i + 0.5) * 2 * r["half_w"] / n
            E.cube("beam", (size[0], r["back"] - r["front"], size[1]), (x, (r["back"] + r["front"]) / 2, z), mat,
                   bevel=1.0)


def sky(name, top, bottom, stars=0.0, moon=None, nebula=None, strength=1.0, skyline=None):
    """Emissive sky material for window/arch openings (a plane's Generated
    coords: y runs bottom to top). skyline=(colour, height 0..1) adds a dark
    silhouette band of roofs/hills at the bottom; (colour, height, False)
    leaves out the lit windows (mountains)."""
    m, k = E.material(name)
    tc = k.coords().outputs["Generated"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(tc, sep.inputs[0])
    col = k.ramp(sep.outputs["Y"], [(0.0, bottom), (1.0, top)])
    em = k.emission(col, strength)
    if nebula:
        obj = k.coords().outputs["Object"]
        n = k.noise(obj, 0.012, 8, 0.65, dist=1.0).outputs["Fac"]
        neb = k.ramp(n, [(0.45, (0, 0, 0)), (0.62, nebula[0]), (0.75, nebula[1])])
        em = k.add_shader(em, k.emission(neb, 1.4))
    if stars:
        st = k.math("LESS_THAN", k.voronoi(tc, 260.0).outputs["Distance"], 0.045)
        st = k.math("MULTIPLY", st, k.math("GREATER_THAN", sep.outputs["Y"], 0.35))
        em = k.add_shader(em, k.emission((1, 1, 1, 1), k.math("MULTIPLY", st, stars)))
    if skyline:
        # a stepped roofline: blocky noise along x decides each column's height
        sx = k.node("ShaderNodeSeparateXYZ")
        k.link(tc, sx.inputs[0])
        step = k.math("FLOOR", k.math("MULTIPLY", sx.outputs["X"], 40.0))
        hn = k.node("ShaderNodeTexWhiteNoise")
        hn.noise_dimensions = "1D"
        k.link(step, hn.inputs["W"])
        hgt = k.math("ADD", k.math("MULTIPLY", hn.outputs["Value"], skyline[1] * 0.6), skyline[1] * 0.5)
        if len(skyline) >= 3 and not skyline[2]:  # mountains: a smooth ridge line instead of roofs
            rn = k.node("ShaderNodeTexNoise")
            rn.noise_dimensions = "1D"
            k.link(k.math("MULTIPLY", sx.outputs["X"], 3.0), rn.inputs["W"])
            k.set(rn, Detail=6.0, Roughness=0.6)
            hgt = k.math("MULTIPLY", k.math("POWER", rn.outputs["Fac"], 1.5), skyline[1] * 2.2)
        below = k.math("LESS_THAN", sep.outputs["Y"], hgt)
        # a few lit windows in the silhouette
        lit = k.math("LESS_THAN", k.voronoi(tc, 90.0).outputs["Distance"], 0.06)
        lit = k.math("MULTIPLY", lit, k.math("LESS_THAN", sep.outputs["Y"], k.math("SUBTRACT", hgt, 0.03)))
        sil = k.emission((*skyline[0], 1), 1.0)
        if len(skyline) < 3 or skyline[2]:
            sil = k.add_shader(sil, k.emission((1.0, 0.6, 0.25, 1), k.math("MULTIPLY", lit, 3.0)))
        em = k.mix_shader(below, em, sil)
    k.surface(em)
    return m


def window(wall, u, z, w, h, sky_mat, frame_mat, mullions=(3, 2), moon=None, sill=True, bar=1.6, glow=None):
    """A window set into an opening of `wall` (make the opening with shell(openings=...)):
    an emissive sky card outside, a frame and mullions in the reveal.

    moon=(r, du, dz) puts a moon disc outside. glow=(energy, colour) adds
    an area light in the opening pointing into the room (moonlight/daylight
    pouring in); returns that light (or the sky card)."""
    zl = z - FLOOR_Z
    parts = [E.plane("window_sky", w * 3.0, h * 2.4, (0, 90, zl), sky_mat)]
    parts[0].rotation_euler = (math.radians(90), 0, 0)
    parts[0].visible_shadow = False
    fm = frame_mat
    for sx in (-1, 1):
        parts.append(E.cube("window_frame", (4, 6, h), (sx * (w / 2 - 2), 9, zl), fm))
    parts.append(E.cube("window_frame", (w, 6, 4), (0, 9, zl - h / 2 + 2), fm))
    parts.append(E.cube("window_frame", (w, 6, 4), (0, 9, zl + h / 2 - 2), fm))
    if sill:
        parts.append(E.cube("window_sill", (w + 14, 10, 4), (0, -3, zl - h / 2 - 2), fm, bevel=0.6))
    nx, nz = mullions
    for i in range(1, nx):
        parts.append(E.cube("mullion_v", (bar, 2, h), (-w / 2 + i * w / nx, 9, zl), fm))
    for j in range(1, nz):
        parts.append(E.cube("mullion_h", (w, 2, bar), (0, 9, zl - h / 2 + j * h / nz), fm))
    if moon:
        mo = E.sphere("moon", moon[0], (moon[1], 85, zl + moon[2]), E.emissive("Moon", (0.85, 0.9, 1.0), 10.0), subdiv=3)
        mo.visible_shadow = False
        parts.append(mo)
    loc, rz = _wall_frame(wall, u)
    _group("window", parts, loc + Vector((0, 0, FLOOR_Z)), rz)
    if glow:
        return E.light(bpy.context.scene, "AREA", "window_light", to_world(wall, u, (0, -4, zl + FLOOR_Z)),
                       glow[0], color=glow[1], size=max(w, h) * 0.8,
                       target=to_world(wall, u, (0, -200, FLOOR_Z + 20)))
    return parts[0]


def arch_opening(wall, u, z_bottom, w, h, mat, depth=24, sky_mat=None, columns=True):
    """A wide opening (balcony / arcade) with posts at its sides and a lintel;
    sky_mat puts a sky card behind it."""
    parts = []
    zl = z_bottom - FLOOR_Z
    if columns:
        for sx in (-1, 1):
            parts.append(E.cylinder("arch_post", 9, h, (sx * w / 2, 0, zl + h / 2), mat, segs=24))
    parts.append(E.cube("arch_lintel", (w + 30, depth, 16), (0, 4, zl + h + 8), mat, bevel=1.0))
    if sky_mat:
        c = E.plane("arch_sky", w * 4, h * 3, (0, 250, zl + h / 2), sky_mat)
        c.rotation_euler = (math.radians(90), 0, 0)
        c.visible_shadow = False
        parts.append(c)
    loc, rz = _wall_frame(wall, u)
    return _group("arch", parts, loc + Vector((0, 0, FLOOR_Z)), rz)


def column(x, y, h, r, mat, base=True):
    E.cylinder("column", r, h, (x, y, FLOOR_Z + h / 2), mat, segs=24)
    if base:
        E.cube("column_base", (r * 2.6, r * 2.6, 10), (x, y, FLOOR_Z + 5), mat, bevel=1.0)
        E.cube("column_cap", (r * 2.6, r * 2.6, 8), (x, y, FLOOR_Z + h - 4), mat, bevel=1.0)


# --------------------------------------------------------------------------
# Light sources that are also props
# --------------------------------------------------------------------------

def fireplace(scene, wall, u, w=120, h=110, depth=45, mat=None, energy=90000, mantel=True, breast=True,
              opening=(0.56, 0.52), color=(1.0, 0.45, 0.14), fire_scale=1.0, seed=0, flame=None):
    """A fireplace / forge mouth against `wall` at u: surround with a real
    opening, sooty firebox, flames and coals, a warm light at the mouth and
    a dimmer one inside (so the reveal glows and the light spills out in a
    wedge, not from a point)."""
    mat = mat or stone("Hearth stone", (0.05, 0.045, 0.04), (0.14, 0.12, 0.1), scale=0.05)
    soot = E.simple("Firebox soot", (0.012, 0.009, 0.007), 0.95)
    ow, oh = w * opening[0], h * opening[1]
    pw = (w - ow) / 2
    y0 = -depth / 2  # body centre (local); the front face is at -depth
    parts = [E.cube("hearth_pier", (pw, depth, h), (sx * (ow / 2 + pw / 2), y0, h / 2), mat) for sx in (-1, 1)]
    parts.append(E.cube("hearth_lintel", (w, depth, h - oh), (0, y0, oh + (h - oh) / 2), mat))
    parts.append(E.cube("firebox_back", (ow, 4, oh), (0, -3, oh / 2), soot))
    for sx in (-1, 1):
        parts.append(E.cube("firebox_side", (2, depth - 4, oh), (sx * (ow / 2 - 1), y0, oh / 2), soot))
    parts.append(E.cube("firebox_top", (ow, depth - 4, 2), (0, y0, oh - 1), soot))
    parts.append(E.cube("hearth_floor", (w * 1.1, depth * 1.5, 5), (0, -depth * 0.75 + 4, 2.5), mat))
    if mantel:
        parts.append(E.cube("mantel", (w * 1.12, depth * 0.35 + 8, 7), (0, -depth - 2, h - 3), mat, bevel=1.0))
    if breast:
        top = _ROOM["height"]
        parts.append(E.cube("chimney_breast", (w * 0.8, depth * 0.8, top - h), (0, -depth * 0.4, h + (top - h) / 2),
                            mat))
    fm = flame or fire_material(8.0, "Hearth fire")
    rng = random.Random(seed + int(u))
    fz = 5 + 4
    for i in range(6):
        fx = rng.uniform(-ow * 0.3, ow * 0.3)
        fl = E.sphere("hearth_flame", 1.0, (fx, -depth * 0.45 + rng.uniform(-4, 4), fz + 12 * fire_scale), fm,
                      subdiv=3, scale=(rng.uniform(5, 8) * fire_scale, rng.uniform(4, 6) * fire_scale,
                                       rng.uniform(14, 24) * fire_scale))
        fl.visible_shadow = False
        parts.append(fl)
    coal = E.emissive("Hearth coals", (1.0, 0.25, 0.04), 8.0)
    for i in range(14):
        parts.append(E.rock(f"hearth_coal{i}", rng.uniform(3, 5) * fire_scale,
                            (rng.uniform(-ow * 0.35, ow * 0.35), -depth * 0.45 + rng.uniform(-8, 8), fz), coal,
                            seed=i + seed, subdiv=2))
    for i in range(3):  # logs
        lg = E.cylinder("hearth_log", 4 * fire_scale, ow * 0.6, (rng.uniform(-6, 6), -depth * 0.45 + (i - 1) * 7,
                                                                  fz + 2), soot, segs=12)
        lg.rotation_euler = (0, math.radians(90), rng.uniform(-0.3, 0.3))
        parts.append(lg)
    glow_in = E.emissive("Firebox glow", (1.0, 0.3, 0.06), 1.5)
    parts.append(E.plane("firebox_glow", ow * 0.9, oh * 0.6, (0, -5.5, oh * 0.3), glow_in))
    parts[-1].rotation_euler = (math.radians(90), 0, 0)
    loc, rz = _wall_frame(wall, u)
    _group("fireplace", parts, loc + Vector((0, 0, FLOOR_Z)), rz)
    E.light(scene, "POINT", "hearth_inner", to_world(wall, u, (0, -depth * 0.4, FLOOR_Z + 30 * fire_scale)),
            energy * 0.25, color=color, size=15, shadow=False)
    return E.light(scene, "AREA", "hearth_mouth", to_world(wall, u, (0, -depth - 6, FLOOR_Z + oh * 0.45)), energy,
                   color=color, size=ow * 0.8, target=to_world(wall, u, (0, -depth - 200, FLOOR_Z + 40)))


def hanging_lantern(scene, x, y, z, energy=20000, color=(1.0, 0.62, 0.3), mat=None, size=1.0, chain_to=None,
                    glass_color=(1.0, 0.7, 0.35)):
    """A cage lantern on a chain: four posts, a peaked cap, warm glass and a flame."""
    mat = mat or E.simple("Lantern iron", (0.03, 0.028, 0.026), 0.45, 0.9)
    s = size
    top = chain_to if chain_to is not None else FLOOR_Z + _ROOM["height"]
    E.cylinder("lantern_chain", 0.5 * s, top - (z + 14 * s), (x, y, (top + z + 14 * s) / 2), mat, segs=8)
    for sx in (-1, 1):
        for sy in (-1, 1):
            E.cube("lantern_post", (1.2 * s, 1.2 * s, 20 * s), (x + sx * 6 * s, y + sy * 6 * s, z), mat)
    E.cube("lantern_base", (15 * s, 15 * s, 2.5 * s), (x, y, z - 10 * s), mat, bevel=0.4 * s)
    E.cube("lantern_top", (15 * s, 15 * s, 2 * s), (x, y, z + 10 * s), mat, bevel=0.4 * s)
    E.cylinder("lantern_cap", 10 * s, 7 * s, (x, y, z + 14 * s), mat, segs=4, r2=1.5 * s).rotation_euler = \
        (0, 0, math.radians(45))
    gm = E.material(f"Lantern glass {glass_color}")
    m, k = gm
    k.surface(k.mix_shader(0.5, k.bsdf(Base_Color=(*glass_color, 1), Transmission_Weight=1.0, Roughness=0.3),
                           k.emission((*glass_color, 1), 1.5)))
    for sx in (-1, 1):
        E.cube("lantern_pane", (0.3 * s, 11 * s, 18 * s), (x + sx * 6 * s, y, z), m).visible_shadow = False
        E.cube("lantern_pane", (11 * s, 0.3 * s, 18 * s), (x, y + sx * 6 * s, z), m).visible_shadow = False
    fl = E.sphere("lantern_flame", 1.2 * s, (x, y, z - 2 * s), P.flame_mat(40.0, color), subdiv=3,
                  scale=(0.7, 0.7, 2.0))
    fl.visible_shadow = False
    return E.light(scene, "POINT", "lantern_light", (x, y, z - 1 * s), energy, color=color, size=4 * s)


def pendant_lamp(scene, x, y, z, energy=40000, color=(1.0, 0.78, 0.5), shade=(0.35, 0.25, 0.1), r=22, cord_to=None,
                 spot_deg=80):
    """An industrial / library pendant: a metal cone shade with a glowing bulb."""
    top = cord_to if cord_to is not None else FLOOR_Z + _ROOM["height"]
    E.cylinder("pendant_cord", 0.4, top - z - 16, (x, y, (top + z + 16) / 2), E.simple("Cord", (0.02, 0.02, 0.02), 0.5),
               segs=8)
    sh = E.cylinder("pendant_shade", 4, 16, (x, y, z + 8), E.simple("Shade metal", shade, 0.35, 0.9), segs=48,
                    r2=r, cap=False)
    sh.rotation_euler = (math.radians(180), 0, 0)
    sh.modifiers.new("solid", "SOLIDIFY").thickness = 0.6
    E.sphere("bulb", 3.5, (x, y, z + 2), E.emissive("Bulb", color, 20.0), subdiv=2).visible_shadow = False
    return E.light(scene, "SPOT", "pendant_light", (x, y, z), energy, color=color, size=4, target=(x, y, z - 100),
                   spot_deg=spot_deg, blend=0.5)


def sconce(scene, wall, u, z, energy=3000, color=(1.0, 0.6, 0.3), mat=None):
    """A wall candle sconce (brass plate, arm, candle) with its glow."""
    mat = mat or P.brass("Sconce brass", worn=0.5)
    wx = to_world(wall, u, (0, -1, z))
    E.cube("sconce_plate", (6, 6, 12), wx, mat, bevel=0.5)
    c = to_world(wall, u, (0, -10, z))
    E.cylinder("sconce_arm", 0.6, 10, to_world(wall, u, (0, -5, z + 3)), mat, segs=8)
    P.candle(scene, c.x, c.y, z + 3, h=8, r=1.2, holder=True, light=False, seed=int(u))
    return E.light(scene, "POINT", "sconce_glow", to_world(wall, u, (0, -12, z + 14)), energy, color=color, size=5)


def paper_lantern(scene, x, y, z, r=18, color=(1.0, 0.25, 0.08), energy=15000, light_color=(1.0, 0.5, 0.25),
                  cord_to=None):
    """A round paper lantern (ribbed, glowing through) on a cord."""
    top = cord_to if cord_to is not None else FLOOR_Z + _ROOM["height"]
    m, k = E.material(f"Paper lantern {color}")
    obj = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    rib = k.math("GREATER_THAN", k.math("SINE", k.math("MULTIPLY", sep.outputs["Z"], 22.0)), 0.85)
    col = k.mix(rib, (*color, 1), tuple(c * 0.25 for c in color) + (1,))
    k.surface(k.add_shader(k.bsdf(Base_Color=col, Roughness=0.8), k.emission(col, 3.0)))
    lan = E.sphere("paper_lantern", 1.0, (x, y, z), m, subdiv=4, scale=(r, r, r * 1.15))
    lan.visible_shadow = False
    cap = E.simple("Lantern lacquer", (0.02, 0.01, 0.008), 0.3)
    E.cylinder("lantern_cap_top", r * 0.35, 3, (x, y, z + r * 1.12), cap, segs=24)
    E.cylinder("lantern_cap_bot", r * 0.35, 3, (x, y, z - r * 1.12), cap, segs=24)
    E.cylinder("lantern_cord", 0.35, top - z - r, (x, y, (top + z + r) / 2), cap, segs=6)
    return E.light(scene, "POINT", "paper_lantern_light", (x, y, z), energy, color=light_color, size=r * 0.8)


def fire_bowl(scene, x, y, z_top, r=18, energy=60000, mat=None, pedestal=None, color=(1.0, 0.5, 0.18),
              seed=0, flame=None):
    """A fire bowl (brazier) on a stone pedestal whose top is at z_top."""
    mat = mat or P.brass("Fire bowl bronze", worn=0.6, color=(0.7, 0.45, 0.2))
    rng = random.Random(seed)
    if pedestal is not None:
        E.cube("bowl_pedestal", (r * 1.6, r * 1.6, z_top - FLOOR_Z), (x, y, (z_top + FLOOR_Z) / 2), pedestal,
               bevel=1.0)
    b = E.cylinder("fire_bowl", r * 0.5, r * 0.6, (x, y, z_top + r * 0.3), mat, segs=40, r2=r)
    b.modifiers.new("solid", "SOLIDIFY").thickness = 1.0
    coal = E.emissive("Bowl coals", (1.0, 0.3, 0.05), 6.0)
    for i in range(10):
        a, rr = rng.uniform(0, 6.28), rng.uniform(0, r * 0.7)
        E.rock(f"bowl_coal{i}", r * 0.12, (x + math.cos(a) * rr, y + math.sin(a) * rr, z_top + r * 0.55), coal,
               seed=i + seed, subdiv=2)
    fm = flame or fire_material(8.0, "Bowl fire")
    for i in range(4):
        a, rr = rng.uniform(0, 6.28), rng.uniform(0, r * 0.35)
        h = r * rng.uniform(0.8, 1.3)
        fl = E.sphere("bowl_flame", 1.0, (x + math.cos(a) * rr, y + math.sin(a) * rr, z_top + r * 0.6 + h * 0.5), fm,
                      subdiv=3, scale=(r * 0.3, r * 0.3, h))
        fl.visible_shadow = False
    return E.light(scene, "POINT", "fire_bowl_light", (x, y, z_top + r * 1.3), energy, color=color, size=r * 0.5)


def banner(wall, u, z_top, w=50, h=150, color=(0.03, 0.05, 0.2), trim=(0.6, 0.45, 0.2), pattern=None):
    """A hanging cloth banner with a trimmed border, a pole and a swallowtail
    hem (plain geometry: no emblem unless `pattern` = a mask image)."""
    m, k = E.material(f"Banner {color}")
    obj = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    edge = k.math("GREATER_THAN", k.math("ABSOLUTE", sep.outputs["X"]), w / 2 - 3)
    col = k.mix(edge, (*color, 1), (*trim, 1))
    if pattern is not None:
        # a gold diamond lattice on the field: sin(x+z) * sin(x-z)
        d1 = k.math("SINE", k.math("MULTIPLY", k.math("ADD", sep.outputs["X"], sep.outputs["Z"]), 0.35))
        d2 = k.math("SINE", k.math("MULTIPLY", k.math("SUBTRACT", sep.outputs["X"], sep.outputs["Z"]), 0.35))
        lat = k.math("LESS_THAN", k.math("ABSOLUTE", k.math("MULTIPLY", d1, d2)), 0.04)
        col = k.mix(lat, col, (*trim, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.8, Sheen_Weight=0.8))
    bm = bmesh.new()
    pts = [(-w / 2, 0), (w / 2, 0), (w / 2, -h), (0, -h + w * 0.35), (-w / 2, -h)]
    vs = [bm.verts.new((px, 0, pz)) for px, pz in pts]
    bm.faces.new(vs)
    cloth = E.mesh_object("banner", bm, m)
    cloth.location = (0, -3, z_top - FLOOR_Z)
    cloth.modifiers.new("solid", "SOLIDIFY").thickness = 0.4
    pole = E.cylinder("banner_pole", 1.2, w + 10, (0, -3, z_top - FLOOR_Z + 1.5), P.brass("Banner brass"), segs=12)
    pole.rotation_euler = (0, math.radians(90), 0)
    loc, rz = _wall_frame(wall, u)
    return _group("banner", [cloth, pole], loc + Vector((0, 0, FLOOR_Z)), rz)


def neon_bar(scene, p0, p1, color, strength=25.0, energy=4000, r=0.9):
    """A straight neon tube from p0 to p1 with a soft area light along it."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    tube = E.cylinder("neon", r, d.length, (p0 + p1) / 2, E.emissive(f"Neon {color}", color, strength), segs=12)
    tube.rotation_mode = "QUATERNION"
    tube.rotation_quaternion = d.to_track_quat("Z", "Y")
    tube.visible_shadow = False
    if energy:
        E.light(scene, "POINT", "neon_light", (p0 + p1) / 2, energy, color=color, size=d.length * 0.5,
                shadow=False)
    return tube


# --------------------------------------------------------------------------
# Furniture
# --------------------------------------------------------------------------

def work_table(w, d, top_z=-6.0, thick=8.0, mat=None, leg_r=5.0, x=0.0, y=0.0, square_legs=True, apron=True,
               top=True):
    """A table centred at (x, y) whose top surface is at top_z (the env's base
    slab / tray sits on it). top=False: legs and apron only, under a table
    top the environment already has (top_z is then its underside + thick)."""
    mat = mat or P.dark_wood("Table oak", c1=(0.035, 0.018, 0.009), c2=(0.11, 0.055, 0.028))
    if top:
        E.cube("table_top", (w, d, thick), (x, y, top_z - thick / 2), mat, bevel=1.0)
    h = top_z - thick - FLOOR_Z
    for sx in (-1, 1):
        for sy in (-1, 1):
            p = (x + sx * (w / 2 - leg_r * 2), y + sy * (d / 2 - leg_r * 2), FLOOR_Z + h / 2)
            if square_legs:
                E.cube("table_leg", (leg_r * 2, leg_r * 2, h), p, mat, bevel=0.6)
            else:
                E.cylinder("table_leg", leg_r, h, p, mat, segs=16)
    if apron:
        E.cube("table_apron", (w - leg_r * 4, d - leg_r * 4, 10), (x, y, top_z - thick - 5), mat)


def table_legs(half_w, half_d, top_z=-6.0, mat=None, r=5.0):
    """Four legs under a table whose top slab sits at top_z..0."""
    mat = mat or P.dark_wood("Table legs", c1=(0.03, 0.015, 0.008), c2=(0.1, 0.05, 0.025))
    h = top_z - FLOOR_Z
    for sx in (-1, 1):
        for sy in (-1, 1):
            E.cylinder("table_leg", r, h, (sx * (half_w - 12), sy * (half_d - 12), FLOOR_Z + h / 2), mat, segs=16)


def chair(x, y, rot=0.0, mat=None, seat_h=46, back_h=50, w=44):
    """A plain chair (seat, four legs, back) facing -y before rotation."""
    mat = mat or P.dark_wood("Chair wood", c1=(0.03, 0.015, 0.008), c2=(0.1, 0.05, 0.025))
    parts = [E.cube("chair_seat", (w, w, 4), (0, 0, seat_h), mat, bevel=0.6)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(E.cube("chair_leg", (3.5, 3.5, seat_h), (sx * (w / 2 - 3), sy * (w / 2 - 3), seat_h / 2), mat))
        parts.append(E.cube("chair_post", (3.5, 3.5, back_h), (sx * (w / 2 - 3), w / 2 - 3, seat_h + back_h / 2), mat))
    parts.append(E.cube("chair_rail", (w, 3, 12), (0, w / 2 - 3, seat_h + back_h - 8), mat, bevel=0.5))
    parts.append(E.cube("chair_rail", (w, 3, 6), (0, w / 2 - 3, seat_h + back_h * 0.45), mat, bevel=0.5))
    return _group("chair", parts, Vector((x, y, FLOOR_Z)), rot)


def cabinet(wall, u, w=90, h=90, depth=55, z0=None, mat=None, top_mat=None, doors=2):
    """A base cabinet / counter / chest of drawers against a wall."""
    mat = mat or P.dark_wood("Cabinet wood")
    z0 = FLOOR_Z if z0 is None else z0
    parts = [E.cube("cabinet_body", (w, depth, h), (0, -depth / 2, z0 - FLOOR_Z + h / 2), mat, bevel=0.5)]
    parts.append(E.cube("cabinet_top", (w + 3, depth + 3, 4), (0, -depth / 2 - 1, z0 - FLOOR_Z + h + 2),
                        top_mat or mat, bevel=0.5))
    knob = E.simple("Knob", (0.5, 0.45, 0.4), 0.3, 1.0)
    for i in range(doors):
        cx = -w / 2 + (i + 0.5) * w / doors
        parts.append(E.cube("cabinet_door", (w / doors - 3, 1.2, h - 12), (cx, -depth - 0.4, z0 - FLOOR_Z + h / 2),
                            mat, bevel=0.3))
        parts.append(E.sphere("cabinet_knob", 1.3, (cx + (w / doors / 2 - 6) * (1 if i % 2 else -1), -depth - 1.5,
                                                    z0 - FLOOR_Z + h * 0.7), knob, subdiv=2))
    loc, rz = _wall_frame(wall, u)
    return _group("cabinet", parts, loc + Vector((0, 0, FLOOR_Z)), rz)


def wall_shelf(wall, u, z, w=100, depth=22, mat=None, seed=0, palette=None, kind="jars"):
    """A plank shelf with brackets on `wall`, loaded with jars/bottles/boxes
    (kind: jars | bottles | boxes | mixed)."""
    mat = mat or P.dark_wood("Shelf wood", c1=(0.03, 0.015, 0.008), c2=(0.09, 0.045, 0.02))
    rng = random.Random(seed)
    zl = z - FLOOR_Z
    parts = [E.cube("shelf_plank", (w, depth, 3), (0, -depth / 2, zl), mat, bevel=0.4)]
    for sx in (-1, 1):
        parts.append(E.cube("shelf_bracket", (2.5, depth * 0.8, 12), (sx * w * 0.38, -depth * 0.4, zl - 7.5), mat))
    palette = palette or [(0.2, 0.12, 0.05), (0.08, 0.1, 0.05), (0.3, 0.25, 0.18), (0.05, 0.05, 0.08)]
    xx = -w / 2 + 5
    while xx < w / 2 - 6:
        c = rng.choice(palette)
        k = kind if kind != "mixed" else rng.choice(("jars", "bottles", "boxes"))
        cm = E.simple(f"Shelf item {c}", c, rng.uniform(0.2, 0.7), 0.0)
        if k == "jars":
            r_, h_ = rng.uniform(3, 5.5), rng.uniform(8, 16)
            parts.append(E.cylinder("jar", r_, h_, (xx + r_, -depth / 2, zl + 1.5 + h_ / 2), cm, segs=20, bevel=0.5))
            parts.append(E.cylinder("jar_lid", r_ * 0.9, 1.5, (xx + r_, -depth / 2, zl + 2.2 + h_), mat, segs=20))
            xx += r_ * 2 + rng.uniform(1, 3)
        elif k == "bottles":
            r_, h_ = rng.uniform(2.5, 3.5), rng.uniform(16, 24)
            gm = P.glass(f"Bottle glass {c}", color=tuple(min(1.0, v * 2.5) for v in c), rough=0.1)
            parts.append(E.cylinder("bottle", r_, h_, (xx + r_, -depth / 2, zl + 1.5 + h_ / 2), gm, segs=20))
            parts.append(E.cylinder("bottle_neck", r_ * 0.35, 6, (xx + r_, -depth / 2, zl + 1.5 + h_ + 3), gm, segs=12))
            xx += r_ * 2 + rng.uniform(1, 3)
        else:
            bw, bh = rng.uniform(10, 18), rng.uniform(6, 14)
            parts.append(E.cube("box", (bw, depth * 0.7, bh), (xx + bw / 2, -depth / 2, zl + 1.5 + bh / 2), cm,
                                bevel=0.3))
            xx += bw + rng.uniform(1, 3)
    loc, rz = _wall_frame(wall, u)
    return _group("wall_shelf", parts, loc + Vector((0, 0, FLOOR_Z)), rz)


def bookshelf(wall, u, w=120, h=200, depth=30, rows=6, seed=0, mat=None):
    """A wooden bookcase against `wall`, full of standing books (original: no titles)."""
    mat = mat or P.dark_wood("Shelf wood", c1=(0.03, 0.015, 0.008), c2=(0.09, 0.045, 0.02))
    rng = random.Random(seed)
    yc = -depth / 2 - 1
    parts = [E.cube("shelf_back", (w, 2, h), (0, -1, h / 2), mat)]
    for sx in (-1, 1):
        parts.append(E.cube("shelf_side", (3, depth, h), (sx * (w / 2 - 1.5), yc, h / 2), mat))
    row_h = h / rows
    cols = [(0.25, 0.04, 0.03), (0.05, 0.09, 0.2), (0.06, 0.12, 0.06), (0.3, 0.2, 0.08), (0.12, 0.05, 0.12),
            (0.35, 0.28, 0.18)]
    for r in range(rows + 1):
        parts.append(E.cube("shelf_board", (w - 3, depth, 2.4), (0, yc, r * row_h + 1.2), mat))
        if r == rows:
            break
        xx = -w / 2 + 4
        while xx < w / 2 - 6:
            bw = rng.uniform(2.5, 5.5)
            bh = rng.uniform(row_h * 0.55, row_h * 0.85)
            bd = rng.uniform(depth * 0.6, depth * 0.85)
            if rng.random() < 0.08:  # a gap
                xx += bw * 2
                continue
            c = rng.choice(cols)
            c = tuple(v * rng.uniform(0.6, 1.1) for v in c)
            parts.append(E.cube("shelf_book", (bw, bd, bh), (xx + bw / 2, -2 - bd / 2, r * row_h + 2.4 + bh / 2),
                                _book_mat(c), bevel=0.3))
            xx += bw + rng.uniform(0.1, 0.5)
    loc, rz = _wall_frame(wall, u)
    return _group("bookshelf", parts, loc + Vector((0, 0, FLOOR_Z)), rz)


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


def pipes(wall, u0, u1, zs, r=4.0, mat=None, drops=(), off=8.0):
    """Horizontal pipe runs along `wall` from u0 to u1 at heights zs, with
    flanges every ~60 cm and vertical drops at the u positions in `drops`
    (from the top run to the floor)."""
    mat = mat or P.brass("Pipe copper", worn=0.7, color=(0.8, 0.45, 0.3))
    parts = []
    L = abs(u1 - u0)
    uc = (u0 + u1) / 2
    for z in zs:
        p_ = E.cylinder("pipe", r, L, (0, -off, z - FLOOR_Z), mat, segs=16)
        p_.rotation_euler = (0, math.radians(90), 0)
        parts.append(p_)
        for i in range(int(L // 60) + 1):
            fl = E.cylinder("pipe_flange", r * 1.35, 2.0, (-L / 2 + i * 60, -off, z - FLOOR_Z), mat, segs=16)
            fl.rotation_euler = (0, math.radians(90), 0)
            parts.append(fl)
    top = max(zs) - FLOOR_Z
    for du in drops:
        parts.append(E.cylinder("pipe_drop", r, top, (du - uc, -off, top / 2), mat, segs=16))
        parts.append(E.cylinder("pipe_valve", r * 2.2, 1.5, (du - uc, -off - r - 2, top * 0.45), mat, segs=24))
        parts[-1].rotation_euler = (math.radians(90), 0, 0)
    loc, rz = _wall_frame(wall, uc)
    return _group("pipes", parts, loc + Vector((0, 0, FLOOR_Z)), rz)


def wall_gear(wall, u, z, r, teeth, mat, thick=4.0, off=6.0):
    """A big gear mounted flat on a wall (machinery / clockwork backdrop)."""
    g = P.gear("wall_gear", r, teeth, thick, (0, 0, 0), mat, hole=0)
    g.rotation_euler = (math.radians(90), 0, 0)
    g.location = (0, -off, z - FLOOR_Z)
    hub = E.cylinder("wall_gear_hub", r * 0.18, thick * 2.5, (0, -off - thick, z - FLOOR_Z), mat, segs=24)
    hub.rotation_euler = (math.radians(90), 0, 0)
    loc, rz = _wall_frame(wall, u)
    return _group("wall_gear_g", [g, hub], loc + Vector((0, 0, FLOOR_Z)), rz)


def barrel(x, y, r=20, h=70, mat=None, band=None):
    mat = mat or P.dark_wood("Barrel wood")
    band = band or E.simple("Barrel band", (0.03, 0.03, 0.03), 0.4, 0.9)
    E.cylinder("barrel", r, h, (x, y, FLOOR_Z + h / 2), mat, segs=32, bevel=2.0)
    for z in (0.15, 0.85):
        E.cylinder("barrel_band", r + 0.4, 3, (x, y, FLOOR_Z + h * z), band, segs=32)


def room_camera(scene, loc, target, lens=24, fstop=5.6, focus=None):
    return E.camera(scene, "room", loc, target, lens=lens, fstop_real=fstop, focus=focus or target)
