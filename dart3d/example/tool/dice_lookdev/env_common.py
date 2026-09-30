"""Shared helpers for the dice look-dev environments (build_env_*.py).

Units: 1 Blender unit = 1 cm. The tray's inner play area is portrait
(15 x 31 cm, ~phone aspect; a 2 cm die is ~15% of the screen width,
close to upstream's 70 px die on a ~400 px wide phone) because in the app the tray walls are the
screen edges (demo-program §5.4); the hero cameras look down its long axis.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

from build_dice import NodeKit

TRAY_W, TRAY_D = 15.0, 31.0  # inner play area (x, y), cm: dice ~15% of a phone's width
CHEAP_HAZE = True  # homogeneous haze (no ray marching); set False for noisy smoke
HAZE = False  # room-scale haze costs ~5x render time with many lights; off unless essential
TMP = None  # scratch dir for generated masks (set by render_set.py)


# --------------------------------------------------------------------------
# Scene / render
# --------------------------------------------------------------------------

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.scale_length = 0.01  # 1 BU reads as 1 cm
    scene.unit_settings.length_unit = "CENTIMETERS"
    return scene


def setup_cycles(scene, samples=256, res=(1600, 900), look=None, exposure=0.0, view="Khronos PBR Neutral"):
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        scene.cycles.device = "GPU"
    except Exception:  # pragma: no cover - CPU fallback
        scene.cycles.device = "CPU"
    scene.render.engine = "CYCLES"
    c = scene.cycles
    c.samples = samples
    c.use_adaptive_sampling = True
    c.adaptive_threshold = 0.015
    c.use_denoising = True
    c.denoiser = "OPENIMAGEDENOISE"
    c.max_bounces = 16
    c.transmission_bounces = 16
    c.glossy_bounces = 6
    c.volume_bounces = 2
    c.transparent_max_bounces = 16
    c.caustics_reflective = False
    c.caustics_refractive = False
    c.blur_glossy = 1.0
    c.sample_clamp_indirect = 12.0
    # Procedural volumes dominate render time; coarse steps are fine for the
    # smooth noise used here (measured: ~6x faster than the default).
    for prop, val in (("volume_step_rate", 6.0), ("volume_max_steps", 96)):
        if hasattr(c, prop):
            setattr(c, prop, val)
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    # Khronos PBR Neutral keeps emissive hues saturated (AgX bleaches fire to
    # white) and matches the tone mapper the real-time path can use.
    scene.view_settings.view_transform = view
    if look and view == "AgX":
        scene.view_settings.look = look
    scene.view_settings.exposure = exposure
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "8"


def world(scene, color=(0.01, 0.01, 0.012), strength=1.0, volume_density=0.0, volume_color=(1, 1, 1),
          anisotropy=0.2):
    w = bpy.data.worlds.new("World")
    scene.world = w
    k = NodeKit(w, output="ShaderNodeOutputWorld")
    bg = k.node("ShaderNodeBackground")
    k.set(bg, Color=(*color, 1), Strength=strength)
    k.link(bg.outputs[0], k.out.inputs["Surface"])
    if volume_density > 0:
        v = k.node("ShaderNodeVolumePrincipled")
        k.set(v, Density=volume_density, Color=(*volume_color, 1), Anisotropy=anisotropy)
        k.link(v.outputs[0], k.out.inputs["Volume"])
    return w


def haze_box(name, size, loc, density, color=(1, 1, 1), anisotropy=0.3, noise_scale=0.0, emission=None,
             essential=False):
    """Local participating medium (cheaper and more controllable than world volume)."""
    if not (HAZE or essential):
        return None
    ob = cube(name, size, loc)
    m = bpy.data.materials.new(name)
    k = NodeKit(m)
    v = k.node("ShaderNodeVolumePrincipled")
    k.set(v, Color=(*color, 1), Anisotropy=anisotropy)
    if noise_scale and not CHEAP_HAZE:
        n = k.noise(k.coords().outputs["Object"], noise_scale, 3, 0.55).outputs["Fac"]
        k.link(k.math("MULTIPLY", k.math("POWER", n, 2.5), density * 3.0), v.inputs["Density"])
    else:
        v.inputs["Density"].default_value = density
    if emission:
        k.set(v, Emission_Color=(*emission[0], 1), Emission_Strength=emission[1])
    k.volume(v.outputs[0])
    ob.data.materials.append(m)
    ob.visible_shadow = False
    return ob


def camera(scene, name, loc, target, lens=70, fstop_real=None, focus=None, sensor=36):
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    scene.collection.objects.link(cam)
    cam.data.lens = lens
    cam.data.sensor_width = sensor
    cam.data.clip_start = 0.5
    cam.data.clip_end = 5000
    look_at(cam, loc, target)
    if fstop_real:
        cam.data.dof.use_dof = True
        cam.data.dof.aperture_fstop = fstop_real
        cam.data.dof.aperture_blades = 7
        cam.data.dof.focus_distance = (Vector(focus or target) - Vector(loc)).length
    return cam


def look_at(ob, loc, target, roll=0.0):
    ob.location = Vector(loc)
    d = Vector(target) - Vector(loc)
    q = d.to_track_quat("-Z", "Y")
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = q @ Quaternion((0, 0, 1), roll)


def orbit(target, dist, elev_deg, az_deg):
    """Camera position around target; az 0 = camera on -Y looking +Y."""
    e, a = math.radians(elev_deg), math.radians(az_deg)
    t = Vector(target)
    return t + Vector((math.sin(a) * math.cos(e) * dist, -math.cos(a) * math.cos(e) * dist, math.sin(e) * dist))


def light(scene, kind, name, loc, energy, color=(1, 1, 1), size=1.0, target=None, spot_deg=45, blend=0.3,
          shadow_soft=None, shadow=True):
    ld = bpy.data.lights.new(name, kind)
    ld.use_shadow = shadow  # low back-glows off: their wall shadows would black out half the tray
    ld.energy = energy
    ld.color = color
    if kind == "AREA":
        ld.size = size
        ld.shape = "DISK"
    elif kind in ("POINT", "SPOT"):
        ld.shadow_soft_size = size
    elif kind == "SUN":
        ld.angle = math.radians(shadow_soft or 2.0)
    if kind == "SPOT":
        ld.spot_size = math.radians(spot_deg)
        ld.spot_blend = blend
    ob = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(ob)
    if target is not None:
        look_at(ob, loc, target)
    else:
        ob.location = loc
    return ob


# --------------------------------------------------------------------------
# Geometry
# --------------------------------------------------------------------------

def link(ob, coll=None):
    (coll or bpy.context.scene.collection).objects.link(ob)
    return ob


def mesh_object(name, bm, mat=None, smooth=False, coll=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    if mat:
        me.materials.append(mat)
    return link(ob, coll)


def cube(name, size, loc, mat=None, bevel=0.0, segs=3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=segs, affect="EDGES",
                        clamp_overlap=True)
    ob = mesh_object(name, bm, mat, smooth=bool(bevel))
    ob.location = loc
    if bevel:
        ob.data.set_sharp_from_angle(angle=math.radians(35))
    return ob


def cylinder(name, r, h, loc, mat=None, segs=48, r2=None, bevel=0.0, cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=h)
    if bevel:
        edges = [e for e in bm.edges if not e.is_boundary and abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-5]
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=3, affect="EDGES", clamp_overlap=True)
    ob = mesh_object(name, bm, mat, smooth=True)
    ob.data.set_sharp_from_angle(angle=math.radians(40))
    ob.location = loc
    return ob


def sphere(name, r, loc, mat=None, subdiv=3, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    ob = mesh_object(name, bm, mat, smooth=True)
    ob.location = loc
    ob.scale = scale
    return ob


def plane(name, sx, sy, loc, mat=None, subdiv=0):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=max(1, subdiv), y_segments=max(1, subdiv), size=0.5)
    bmesh.ops.scale(bm, vec=(sx, sy, 1), verts=bm.verts)
    ob = mesh_object(name, bm, mat)
    ob.location = loc
    return ob


def rounded_rect(w, d, r, seg=10):
    pts = []
    for cx, cy, a0 in ((w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180),
                       (w / 2 - r, -d / 2 + r, 270)):
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def rim(name, w, d, corner, height, thickness, mat, z0=0.0, profile=None):
    """Closed rounded-rectangle wall around the play area (centre-line w x d)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "NONE"
    sp = cu.splines.new("POLY")
    pts = rounded_rect(w, d, corner)
    sp.points.add(len(pts) - 1)
    for i, (x, y) in enumerate(pts):
        sp.points[i].co = (x, y, 0, 1)
    sp.use_cyclic_u = True
    if profile is None:
        cu.bevel_mode = "ROUND"
        cu.bevel_depth = thickness / 2
        cu.bevel_resolution = 6
        cu.extrude = max(0.0, height / 2 - thickness / 2)
    else:
        cu.bevel_mode = "OBJECT"
        cu.bevel_object = profile
        cu.use_fill_caps = False
    ob = bpy.data.objects.new(name, cu)
    ob.location = (0, 0, z0 + height / 2)
    ob.data.materials.append(mat)
    return link(ob)


def profile_curve(name, pts):
    """A closed 2D profile (x = outward, y = up) for rim(profile=...)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "2D"
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, (x, y) in enumerate(pts):
        sp.points[i].co = (x, y, 0, 1)
    sp.use_cyclic_u = True
    ob = bpy.data.objects.new(name, cu)
    return ob  # not linked: only used as a bevel object


def rock(name, r, loc, mat, seed=0, squash=(1, 1, 0.7), detail=4, strength=0.35, subdiv=4):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    rng = random.Random(seed)
    off = Vector((rng.uniform(-50, 50), rng.uniform(-50, 50), rng.uniform(-50, 50)))
    from mathutils import noise
    for v in bm.verts:
        p = v.co / r
        n = noise.fractal(p * 1.3 + off, 0.55, 2.0, detail)
        cut = noise.voronoi(p * 1.7 + off)[0][0]
        v.co += v.co.normalized() * r * (strength * n - 0.18 * cut)
        v.co.x *= squash[0]
        v.co.y *= squash[1]
        v.co.z *= squash[2]
    ob = mesh_object(name, bm, mat, smooth=True)
    ob.location = loc
    ob.rotation_euler = (0, 0, rng.uniform(0, 6.28))
    return ob


def scatter(name, n, bounds, radius, mat, seed=1, stretch=None, subdiv=1, avoid=None, scale_range=(0.4, 1.0)):
    """Many small blobs merged into one mesh (motes, snow, sparks, embers).

    stretch: optional callable(pos) -> Vector velocity; blobs get elongated
    along it (spark streaks / rain).
    """
    rng = random.Random(seed)
    bm = bmesh.new()
    (x0, y0, z0), (x1, y1, z1) = bounds
    placed = 0
    while placed < n:
        p = Vector((rng.uniform(x0, x1), rng.uniform(y0, y1), rng.uniform(z0, z1)))
        if avoid and avoid(p):
            continue
        s = radius * rng.uniform(*scale_range)
        if stretch:
            v = stretch(p, rng)
            L = max(1.0, v.length)
            rot = v.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
            M = Matrix.Translation(p) @ rot @ Matrix.Diagonal((s, s, s * L, 1))
        else:
            M = Matrix.Translation(p) @ Euler((rng.random() * 6, rng.random() * 6, 0)).to_matrix().to_4x4() @ \
                Matrix.Diagonal((s, s, s * rng.uniform(0.5, 1.0), 1))
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0, matrix=M)
        placed += 1
    ob = mesh_object(name, bm, mat, smooth=True)
    ob.visible_shadow = False
    return ob


# --------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------

def material(name):
    m = bpy.data.materials.new(name)
    return m, NodeKit(m)


def emissive(name, color, strength):
    m, k = material(name)
    k.surface(k.emission((*color, 1), strength))
    return m


def simple(name, color, rough=0.5, metal=0.0, **kw):
    m, k = material(name)
    k.surface(k.bsdf(Base_Color=(*color, 1), Roughness=rough, Metallic=metal, **kw))
    return m


def grid_lines(k, vec_socket, spacing, width):
    """1 on thin lines of an XY grid in object space, else 0."""
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(vec_socket, sep.inputs[0])
    acc = None
    for axis in ("X", "Y"):
        f = k.math("FRACT", k.math("DIVIDE", sep.outputs[axis], spacing))
        d = k.math("ABSOLUTE", k.math("SUBTRACT", f, 0.5))
        line = k.math("GREATER_THAN", d, 0.5 - width / spacing / 2)
        acc = line if acc is None else k.math("MAXIMUM", acc, line)
    return acc


# --------------------------------------------------------------------------
# Dice placement
# --------------------------------------------------------------------------

# Hero arrangement (x, y offsets in cm around the set centre) and value shown.
HERO_LAYOUT = {
    "d20": ((0.3, -2.4), 20, 0),
    "d12": ((-3.9, 0.2), 12, 12),
    "d10u": ((3.6, -0.2), 0, -15),
    "d10t": ((4.9, 3.9), 0, 20),
    "d8": ((-4.9, 4.2), 8, -10),
    "d6": ((1.4, 4.1), 6, 18),
    "d4": ((-1.6, 7.2), 4, 58),
}

# The in-app top-down result: every die settled, its number up. Yaw = numeral
# rotation away from reading upright on the phone (small, like a real roll).
# Values include two-digit and dotted numerals (the hardest to read).
TOPDOWN_LAYOUT = {
    "d20": ((0.4, -1.6), 18, 8),
    "d12": ((-3.9, 2.2), 11, -14),
    "d10u": ((3.7, 1.9), 9, 12),
    "d10t": ((-0.3, 6.4), 40, -6),
    "d8": ((-3.8, -6.2), 5, 16),
    "d6": ((3.8, -6.0), 3, -9),
    "d4": ((0.4, 11.0), 3, 22),
}
REST_GAP = 0.004  # cm between a die's lowest point and the surface it rests on


def place_layout(objs, specs, layout, centre=(0, 0), facing_from=None):
    """Orient each die (value up, numeral facing the viewer) and put it at its xy.

    facing_from: a camera location to face the numerals towards (hero);
    None faces them up the screen (+Y, the top-down phone view).
    Heights are set by settle(), which rests every die on whatever is under it.
    """
    from build_dice import face_quaternion
    for kind, ob in objs.items():
        (dx, dy), value, yaw = layout[kind]
        p = Vector((centre[0] + dx, centre[1] + dy, 0))
        if facing_from is not None:
            facing = (p - Vector(facing_from)).to_2d().to_3d().normalized()
        else:
            facing = Vector((0, 1, 0))
        facing = Quaternion((0, 0, 1), math.radians(yaw)) @ facing
        ob.animation_data_clear()
        ob.rotation_mode = "QUATERNION"
        ob.rotation_quaternion = face_quaternion(specs[kind], value, facing=facing)
        ob.location = (p.x, p.y, 50.0)
    settle(objs)


def _dice_set(objs):
    s = set(objs.values())
    for ob in objs.values():
        s.update(ob.children)
    return s


def _ignored(ob, dice):
    # dice, and the shadowless scatter (motes, snow, embers) never support a die
    return ob in dice or not ob.visible_shadow or ob.hide_render


def floor_below(scene, x, y, z_top, dice):
    """Height of the first solid surface under (x, y) starting at z_top."""
    dg = bpy.context.evaluated_depsgraph_get()
    origin = Vector((x, y, z_top))
    for _ in range(64):
        hit, loc, _n, _i, ob, _m = scene.ray_cast(dg, origin, Vector((0, 0, -1)))
        if not hit:
            return None
        if not _ignored(ob, dice):
            return loc.z
        origin = loc - Vector((0, 0, 1e-3))
    return None


def _world_verts(ob):
    M = ob.matrix_world
    return [M @ v.co for v in ob.data.vertices]


def settle(objs, gap=REST_GAP):
    """Drop every die straight down until its lowest vertex rests on the surface.

    The surface is ray-cast at the die's centre and at its lowest vertices, and
    the highest hit wins, so a die never sinks into a floor, a bowed page or a
    rim lip. Faces stay flat (the orientation comes from the face map).
    """
    scene = bpy.context.scene
    dice = _dice_set(objs)
    for ob in objs.values():
        bpy.context.view_layer.update()
        vs = _world_verts(ob)
        minz = min(v.z for v in vs)
        z_top = max(v.z for v in vs) + 3.0
        # every vertex in the lower third: how far must the die rise so that
        # none of them is below the surface directly under it?
        need = []
        for v in vs:
            if v.z < minz + 0.35:
                f = floor_below(scene, v.x, v.y, z_top, dice)
                if f is not None:
                    need.append(f - v.z)
        ob.location.z += (max(need) if need else -minz) + gap
    bpy.context.view_layer.update()


def contact_report(objs):
    """Per die: gap to the surface below its lowest point, and any interpenetration.

    Returns {kind: {"gap_cm": float, "overlaps": [names]}}. A settled die should
    have 0 <= gap < 0.01 and no overlaps (dice or environment).
    """
    scene = bpy.context.scene
    dice = _dice_set(objs)
    trees = {kind: world_tree(ob) for kind, ob in objs.items()}
    env = []
    for ob in scene.objects:
        if ob.type not in ("MESH", "CURVE") or _ignored(ob, dice):
            continue
        env.append(ob)
    out = {}
    for kind, ob in objs.items():
        vs = _world_verts(ob)
        minz = min(v.z for v in vs)
        z_top = max(v.z for v in vs) + 3.0
        gaps = []
        for v in vs:
            if v.z < minz + 0.35:
                f = floor_below(scene, v.x, v.y, z_top, dice)
                if f is not None:
                    gaps.append(v.z - f)
        gap = min(gaps) if gaps else float("nan")
        bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        mn = Vector((min(c.x for c in bb), min(c.y for c in bb), min(c.z for c in bb)))
        mx = Vector((max(c.x for c in bb), max(c.y for c in bb), max(c.z for c in bb)))
        hits = []
        for k2, t2 in trees.items():
            if k2 != kind and trees[kind].overlap(t2):
                hits.append(k2)
        for e in env:
            eb = [e.matrix_world @ Vector(c) for c in e.bound_box]
            if (min(c.x for c in eb) > mx.x or max(c.x for c in eb) < mn.x or min(c.y for c in eb) > mx.y
                    or max(c.y for c in eb) < mn.y or min(c.z for c in eb) > mx.z or max(c.z for c in eb) < mn.z):
                continue
            t = world_tree(e)
            if t is not None and trees[kind].overlap(t):
                hits.append(e.name)
        out[kind] = {"gap_cm": round(gap, 4), "overlaps": hits}
    return out


def world_tree(ob):
    """BVH of the evaluated object in world space (None if it has no faces)."""
    from mathutils.bvhtree import BVHTree
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    try:
        me = ev.to_mesh()
    except RuntimeError:
        return None
    if me is None or not len(me.polygons):
        ev.to_mesh_clear()
        return None
    M = ob.matrix_world
    verts = [M @ v.co for v in me.vertices]
    polys = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    return BVHTree.FromPolygons(verts, polys)


# --------------------------------------------------------------------------
# Lighting helpers
# --------------------------------------------------------------------------

def overhead(scene, energy, color=(1.0, 0.95, 0.88), size=45.0, height=90.0, y=0.0, name="overhead"):
    """A big soft source above the tray: the thing top-down metal reflects.

    Viewed straight down, a metal numeral mirrors whatever is above the
    camera; without this it mirrors a black ceiling and goes dark. Real time:
    the zenith of the IBL / a large unshadowed area or directional fill.
    """
    return light(scene, "AREA", name, (0, y, height), energy, color=color, size=size, target=(0, y, 0),
                 shadow=True)


# --------------------------------------------------------------------------
# Output: full-colour JPEG (q 90) for the committed renders
# --------------------------------------------------------------------------

JPEG_QUALITY = 90


def save_jpeg(src_png, dst, quality=JPEG_QUALITY):
    """Re-encode a display-referred PNG as a JPEG without changing its pixels.

    save_render() applies the scene's colour management, so it is switched to
    a neutral Standard / exposure 0 / gamma 1 for the save (otherwise the view
    transform and exposure would be applied a second time).
    """
    img = bpy.data.images.load(str(src_png))
    sc = bpy.context.scene
    st, vs = sc.render.image_settings, sc.view_settings
    old = (st.file_format, st.quality, st.color_mode, vs.view_transform, vs.look, vs.exposure, vs.gamma)
    st.file_format, st.quality, st.color_mode = "JPEG", quality, "RGB"
    vs.view_transform, vs.exposure, vs.gamma = "Standard", 0.0, 1.0
    vs.look = "None"
    try:
        img.save_render(str(dst), scene=sc)
    finally:
        st.file_format, st.quality, st.color_mode = old[:3]
        vs.view_transform = old[3]
        try:
            vs.look = old[4]
        except TypeError:
            pass
        vs.exposure, vs.gamma = old[5], old[6]
        bpy.data.images.remove(img)
    return Path(dst).stat().st_size


def bloom_png(path, threshold=0.8, strength=0.35, radius_frac=0.012):
    """A plain screen-space bloom on the display-referred PNG (what a phone's
    post pass does): bright pixels, blurred wide, added back."""
    import numpy as np
    from build_dice import _blur
    img = bpy.data.images.load(str(path))
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = a[..., :3]
    bright = np.clip(rgb - threshold, 0, None) / (1 - threshold)
    r = max(2, int(radius_frac * max(w, h)))
    glow = np.stack([_blur(_blur(bright[..., c], r), r * 2) for c in range(3)], axis=-1)
    a[..., :3] = np.clip(rgb + glow * strength, 0, 1)
    img.pixels.foreach_set(a.ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def play_view_grade(path, scene, cam, half, z, darken=0.35, desat=0.4, blur_frac=0.004, feather_frac=0.02):
    """The in-app play view: outside the tray (its rim included) the room is
    darker, less saturated and softly defocused, so the dice stay the
    brightest, sharpest thing on screen. In the app: a vignette/grade pass
    masked by the tray's screen rect, or the same baked into the prop atlas."""
    import numpy as np
    from bpy_extras.object_utils import world_to_camera_view
    from build_dice import _blur
    img = bpy.data.images.load(str(path))
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    pts = [world_to_camera_view(scene, cam, Vector((sx * half[0], sy * half[1], z)))
           for sx in (-1, 1) for sy in (-1, 1)]
    x0, x1 = min(p.x for p in pts) * w, max(p.x for p in pts) * w
    y0, y1 = min(p.y for p in pts) * h, max(p.y for p in pts) * h
    f = max(2.0, feather_frac * w)
    xs, ys = np.arange(w)[None, :] + 0.5, np.arange(h)[:, None] + 0.5
    dx = np.maximum(np.maximum(x0 - xs, xs - x1), 0)
    dy = np.maximum(np.maximum(y0 - ys, ys - y1), 0)
    out = np.clip(np.sqrt(dx ** 2 + dy ** 2) / f, 0, 1)[..., None]  # 0 inside the tray, 1 outside
    rgb = a[..., :3]
    r = max(2, int(blur_frac * w))
    soft = np.stack([_blur(rgb[..., c], r) for c in range(3)], axis=-1)
    gray = (0.2126 * soft[..., 0] + 0.7152 * soft[..., 1] + 0.0722 * soft[..., 2])[..., None]
    graded = (soft * (1 - desat) + gray * desat) * (1 - darken)
    a[..., :3] = rgb * (1 - out) + graded * out
    img.pixels.foreach_set(a.ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def render_to(scene, cam, path_tmp, path_out, quality=JPEG_QUALITY, bloom=False, grade=None):
    """Render `cam` to a lossless PNG at path_tmp (+ bloom for the real-time
    variant), then a JPEG at path_out."""
    import time
    scene.camera = cam
    scene.render.filepath = str(path_tmp)
    scene.render.image_settings.file_format = "PNG"
    t0 = time.time()
    bpy.ops.render.render(write_still=True)
    t1 = time.time()
    if bloom:
        bloom_png(path_tmp)
    if grade:
        play_view_grade(path_tmp, scene, cam, *grade)
    size = save_jpeg(path_tmp, path_out, quality)
    print(f"dice_lookdev: {path_out} {size // 1024} KB render {t1 - t0:.0f}s", flush=True)
    return size
