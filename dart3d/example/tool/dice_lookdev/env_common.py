"""Shared helpers for the dice look-dev environments (build_env_*.py).

Units: 1 Blender unit = 1 cm. The tray's inner play area is portrait
(15 x 31 cm, ~phone aspect; a 2 cm die is ~15% of the screen width,
close to upstream's 70 px die on a ~400 px wide phone) because in the app the tray walls are the
screen edges (demo-program §5.4); the hero cameras look down its long axis.
"""
from __future__ import annotations

import math
import random
import struct
import zlib
from pathlib import Path

import bmesh
import bpy
import numpy as np
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
    "d20": ((0.2, -1.8), 20, 0),
    "d12": ((-3.0, 0.1), 12, 12),
    "d10u": ((2.8, 0.0), 0, -15),
    "d10t": ((4.7, 2.7), 0, 20),
    "d8": ((-4.8, 2.9), 8, -10),
    "d6": ((1.1, 3.1), 6, 18),
    "d4": ((-1.8, 4.2), 4, -8),
}


def place_hero(objs, specs, cam_loc, centre=(0, 0), surface_z=0.0, layout=None):
    from build_dice import face_quaternion, rest_height
    layout = layout or HERO_LAYOUT
    for kind, ob in objs.items():
        (dx, dy), value, yaw = layout[kind]
        p = Vector((centre[0] + dx, centre[1] + dy, 0))
        facing = (p - Vector(cam_loc)).to_2d().to_3d().normalized()
        facing = Quaternion((0, 0, 1), math.radians(yaw)) @ facing
        q = face_quaternion(specs[kind], value, facing=facing)
        ob.rotation_mode = "QUATERNION"
        ob.rotation_quaternion = q
        ob.location = (p.x, p.y, surface_z + rest_height(specs[kind]))
        ob.animation_data_clear()


def place_roll(objs, specs, settled, airborne, surface_z=0.0, seed=7, frame=1):
    """Some dice settled, the rest tumbling in the air with motion blur keys.

    settled: {kind: ((x, y), value, yaw_deg)}; airborne: {kind: ((x, y, z), (vx, vy, vz))}
    """
    from build_dice import face_quaternion, rest_height
    rng = random.Random(seed)
    for kind, ((x, y), value, yaw) in settled.items():
        ob = objs[kind]
        ob.animation_data_clear()
        q = face_quaternion(specs[kind], value,
                            facing=Quaternion((0, 0, 1), math.radians(yaw)) @ Vector((0, 1, 0)))
        ob.rotation_quaternion = q
        ob.location = (x, y, surface_z + rest_height(specs[kind]))
    for kind, (pos, vel) in airborne.items():
        ob = objs[kind]
        ob.animation_data_clear()
        axis = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized()
        q0 = Quaternion(axis, rng.uniform(0, 6.28))
        spin = Quaternion(Vector((vel[1], -vel[0], 0.3)).normalized(), 0.9)
        p = Vector(pos)
        v = Vector(vel)
        for f, t in ((frame - 1, -1), (frame + 1, 1)):
            ob.location = p + v * t
            ob.rotation_quaternion = (spin if t > 0 else spin.inverted()) @ q0
            ob.keyframe_insert("location", frame=f)
            ob.keyframe_insert("rotation_quaternion", frame=f)
    bpy.context.scene.frame_set(frame)


# --------------------------------------------------------------------------
# Output: palette PNG (keeps the committed renders small)
# --------------------------------------------------------------------------

def _bayer(n=8):
    m = np.array([[0]])
    while m.shape[0] < n:
        m = np.block([[4 * m, 4 * m + 2], [4 * m + 3, 4 * m + 1]])
    return (m + 0.5) / (n * n) - 0.5


def quantize_png(src, dst, colors=256, dither=3.0, max_width=1600, seed=0):
    """8-bit palette PNG via k-means + light ordered dither. Pure numpy/zlib."""
    img = bpy.data.images.load(str(src))
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3] * 255.0
    bpy.data.images.remove(img)
    if w > max_width:
        f = w // max_width if w % max_width == 0 else None
        if f:
            a = a.reshape(h // f, f, w // f, f, 3).mean(axis=(1, 3))
            h, w = a.shape[:2]
    rng = np.random.default_rng(seed)
    flat = a.reshape(-1, 3)
    sample = flat[rng.choice(len(flat), size=min(80000, len(flat)), replace=False)]
    pal = sample[rng.choice(len(sample), size=colors, replace=False)].copy()
    for _ in range(12):
        idx = _nearest(sample, pal)
        for c in range(colors):
            sel = sample[idx == c]
            if len(sel):
                pal[c] = sel.mean(axis=0)
            else:
                pal[c] = sample[rng.integers(len(sample))]
    b = _bayer(8)
    noise = np.tile(b, (h // 8 + 1, w // 8 + 1))[:h, :w, None] * dither
    idx = _nearest((a + noise).reshape(-1, 3), pal).astype(np.uint8).reshape(h, w)
    pal8 = np.clip(np.round(pal), 0, 255).astype(np.uint8)
    _write_indexed_png(dst, idx, pal8)
    return Path(dst).stat().st_size


def _nearest(px, pal, chunk=65536):
    out = np.empty(len(px), dtype=np.int32)
    pp = (pal ** 2).sum(axis=1)
    for i in range(0, len(px), chunk):
        c = px[i:i + chunk]
        d = pp[None, :] - 2.0 * c @ pal.T
        out[i:i + chunk] = d.argmin(axis=1)
    return out


def _write_indexed_png(path, idx, pal):
    h, w = idx.shape

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + idx[y].tobytes() for y in range(h))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 3, 0, 0, 0))
    png += chunk(b"PLTE", pal.tobytes())
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    Path(path).write_bytes(png)


def render_to(scene, cam, path_tmp, path_out, colors=256, dither=3.0):
    import time
    scene.camera = cam
    scene.render.filepath = str(path_tmp)
    t0 = time.time()
    bpy.ops.render.render(write_still=True)
    t1 = time.time()
    size = quantize_png(path_tmp, path_out, colors=colors, dither=dither)
    print(f"dice_lookdev: {path_out} {size // 1024} KB render {t1 - t0:.0f}s", flush=True)
    return size
