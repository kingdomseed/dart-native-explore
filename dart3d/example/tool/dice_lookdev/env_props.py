"""Reusable, fully procedural props for the dice environments.

Everything is modelled from primitives so the environments stay
reproducible and IP-clean (no downloaded assets, no text on props).
Units: cm.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

import env_common as E
from build_dice import _circle, _rune, _stroke


# --------------------------------------------------------------------------
# Procedural masks (engraved surfaces) rendered with Workbench
# --------------------------------------------------------------------------

def mask_texture(name, strokes, out_dir, res=2048):
    """strokes: [(polylines in [0,1]^2, width, closed)] -> Non-Color image."""
    path = Path(out_dir) / f"{name}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    main = bpy.context.window.scene if bpy.context.window else bpy.context.scene
    sc = bpy.data.scenes.new(f"mask_{name}")
    coll = sc.collection
    for i, (polys, width, closed) in enumerate(strokes):
        _stroke(coll, f"m_{name}_{i}", polys, width, closed)
    cam = bpy.data.objects.new("mask_cam", bpy.data.cameras.new("mask_cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.0
    cam.location = (0.5, 0.5, 5.0)
    coll.objects.link(cam)
    sc.camera = cam
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "SINGLE"
    sc.display.shading.single_color = (1, 1, 1)
    sc.display.render_aa = "8"
    sc.world = bpy.data.worlds.new("mask_world")
    sc.world.color = (0, 0, 0)
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "BW"
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True, scene=sc.name)
    for ob in list(coll.all_objects):
        bpy.data.objects.remove(ob)
    bpy.data.scenes.remove(sc)
    img = bpy.data.images.load(str(path), check_existing=True)
    img.colorspace_settings.name = "Non-Color"
    return img


def ring(r, n=160, cx=0.5, cy=0.5):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def sigil_strokes(seed=11, points=7, runes=28, rings=(0.47, 0.455, 0.37, 0.215, 0.1), w=0.004):
    """An original summoning-circle style sigil in [0,1]^2 (no real-world symbols)."""
    rng = random.Random(seed)
    s = []
    for r in rings:
        s.append(([ring(r)], w * (1.4 if r > 0.46 else 1.0), True))
    # star polygon {points/3}
    star = [(0.5 + 0.37 * math.cos(math.pi / 2 + 2 * math.pi * i * 3 / points),
             0.5 + 0.37 * math.sin(math.pi / 2 + 2 * math.pi * i * 3 / points)) for i in range(points)]
    s.append(([star], w, True))
    for i in range(points):
        a = math.pi / 2 + 2 * math.pi * i / points
        x, y = 0.5 + 0.37 * math.cos(a), 0.5 + 0.37 * math.sin(a)
        s.append(([_circle(x, y, 0.022, 20)], w, True))
        s.append(([_circle(x, y, 0.008, 12)], w * 0.8, True))
    # radial ticks
    for i in range(120):
        a = 2 * math.pi * i / 120
        r0 = 0.455 - (0.012 if i % 5 else 0.022)
        s.append(([[(0.5 + r0 * math.cos(a), 0.5 + r0 * math.sin(a)),
                    (0.5 + 0.455 * math.cos(a), 0.5 + 0.455 * math.sin(a))]], w * 0.7, False))
    # rune band between 0.37 and 0.455
    for i in range(runes):
        a = 2 * math.pi * (i + 0.5) / runes
        x, y = 0.5 + 0.412 * math.cos(a), 0.5 + 0.412 * math.sin(a)
        s.append((_rune(rng, x, y, 0.045, a - math.pi / 2), w * 0.8, False))
    # inner compass rose
    for i in range(8):
        a = 2 * math.pi * i / 8
        L = 0.2 if i % 2 == 0 else 0.13
        tip = (0.5 + L * math.cos(a), 0.5 + L * math.sin(a))
        l1 = (0.5 + 0.03 * math.cos(a + 0.8), 0.5 + 0.03 * math.sin(a + 0.8))
        l2 = (0.5 + 0.03 * math.cos(a - 0.8), 0.5 + 0.03 * math.sin(a - 0.8))
        s.append(([[l1, tip, l2]], w * 0.9, False))
    return s


# --------------------------------------------------------------------------
# Materials used by several environments
# --------------------------------------------------------------------------

def brass(name="Brass", worn=0.5, color=(0.95, 0.68, 0.32)):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.8, 8, 0.6).outputs["Fac"]
    col = k.mix(k.math("MULTIPLY", n, worn), (*color, 1), (0.25, 0.15, 0.06, 1))
    k.surface(k.bsdf(Base_Color=col, Metallic=1.0, Roughness=k.math("ADD", k.math("MULTIPLY", n, 0.3), 0.22),
                     Normal=k.bump(k.noise(obj, 6.0, 4).outputs["Fac"], 0.08, 0.1)))
    return m


def dark_wood(name="Dark wood", scale=0.05, c1=(0.05, 0.025, 0.012), c2=(0.12, 0.06, 0.03), rough=0.55,
              varnish=0.3):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    mp = k.node("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0, 0.12, 1.0)
    k.link(obj, mp.inputs["Vector"])
    wave = k.node("ShaderNodeTexWave", wave_type="BANDS", bands_direction="X")
    k.link(mp.outputs[0], wave.inputs["Vector"])
    k.set(wave, Scale=scale * 10, Distortion=8.0, Detail=6.0, Detail_Scale=1.5)
    n = k.noise(mp.outputs[0], 2.0, 6).outputs["Fac"]
    grain = k.math("MULTIPLY", wave.outputs["Fac"], n)
    col = k.ramp(grain, [(0.1, c1), (0.6, c2)])
    planks = k.node("ShaderNodeTexBrick")
    k.link(obj, planks.inputs["Vector"])
    k.set(planks, Scale=0.012, Mortar_Size=0.004, Bias=0.0)
    gap = k.math("SUBTRACT", 1.0, planks.outputs["Fac"])
    col = k.mix(k.math("MULTIPLY", planks.outputs["Fac"], 0.8), col, (0.01, 0.005, 0.003, 1))
    nrm = k.bump(grain, 0.25, 0.1)
    nrm = k.bump(gap, 0.6, 0.3, normal=nrm)
    k.surface(k.bsdf(Base_Color=col, Roughness=rough, Normal=nrm, Coat_Weight=varnish, Coat_Roughness=0.25))
    return m


def parchment(name="Parchment", ink=True):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.25, 10, 0.65).outputs["Fac"]
    col = k.ramp(n, [(0.25, (0.42, 0.3, 0.16)), (0.65, (0.78, 0.66, 0.46)), (0.85, (0.85, 0.75, 0.55))])
    if ink:
        # contour-like inked coastlines (an invented map, no real places)
        c = k.noise(obj, 0.35, 3, 0.5).outputs["Fac"]
        f = k.math("FRACT", k.math("MULTIPLY", c, 7.0))
        line = k.math("LESS_THAN", k.math("ABSOLUTE", k.math("SUBTRACT", f, 0.5)), 0.035)
        ink_m = k.math("MULTIPLY", line, 0.3)
        col = k.mix(ink_m, col, (0.08, 0.05, 0.03, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.85, Subsurface_Weight=0.1,
                     Normal=k.bump(k.noise(obj, 3.0, 6).outputs["Fac"], 0.15, 0.05)))
    return m


def velvet(name="Velvet", color=(0.01, 0.015, 0.06), stars=True):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    sh = k.bsdf(Base_Color=(*color, 1), Roughness=0.9, Sheen_Weight=1.0, Sheen_Tint=(0.4, 0.5, 1.0, 1))
    if stars:
        v = k.voronoi(obj, 0.35)
        st = k.math("LESS_THAN", v.outputs["Distance"], 0.07)
        gold = k.bsdf(Base_Color=(0.9, 0.65, 0.25, 1), Metallic=1.0, Roughness=0.35)
        sh = k.mix_shader(st, sh, gold)
    k.surface(sh)
    return m


def wax():
    m, k = E.material("Candle wax")
    k.surface(k.bsdf(Base_Color=(0.9, 0.84, 0.7, 1), Roughness=0.45, Subsurface_Weight=1.0,
                     Subsurface_Radius=(1.2, 0.7, 0.3), Subsurface_Scale=0.6))
    return m


def flame_mat(strength=60.0, color=(1.0, 0.62, 0.22)):
    m, k = E.material("Candle flame")
    lw = k.node("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    fac = k.math("SUBTRACT", 1.0, lw.outputs["Facing"])
    col = k.ramp(fac, [(0.0, (1.0, 0.25, 0.03)), (0.6, color), (1.0, (1.0, 0.95, 0.8))])
    em = k.emission(col, strength)
    tr = k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(k.math("POWER", fac, 0.6), tr, em))
    return m


def glass(name="Glass", color=(0.95, 0.97, 1.0), rough=0.02, ior=1.45):
    m, k = E.material(name)
    k.surface(k.bsdf(Base_Color=(*color, 1), Transmission_Weight=1.0, Roughness=rough, IOR=ior))
    return m


# --------------------------------------------------------------------------
# Props
# --------------------------------------------------------------------------

_MATS = {}


def _m(key, fn):
    if key not in _MATS or _MATS[key].name not in bpy.data.materials:
        _MATS[key] = fn()
    return _MATS[key]


def candle(scene, x, y, z=0.0, h=12.0, r=1.6, holder=True, light=True, seed=0, energy=40.0):
    rng = random.Random(seed)
    wm = _m("wax", wax)
    base_z = z
    if holder:
        bm = _m("brass", brass)
        E.cylinder("candle_dish", r * 2.0, 0.5, (x, y, z + 0.25), bm, r2=r * 2.2, bevel=0.15)
        E.cylinder("candle_cup", r * 1.1, 1.4, (x, y, z + 1.2), bm, r2=r * 1.25)
        base_z = z + 1.9
    E.cylinder("candle", r, h, (x, y, base_z + h / 2), wm, segs=32, bevel=0.25)
    for i in range(rng.randint(2, 4)):
        a = rng.uniform(0, 6.28)
        dl = rng.uniform(1.5, h * 0.45)
        E.sphere("drip", 0.32, (x + math.cos(a) * r * 0.96, y + math.sin(a) * r * 0.96, base_z + h - dl / 2),
                 wm, subdiv=2, scale=(1, 1, dl / 0.64))
    wick = E.cylinder("wick", 0.07, 0.6, (x, y, base_z + h + 0.3), E.simple("Wick", (0.02, 0.02, 0.02), 0.9),
                      segs=6)
    fl = E.sphere("flame", 0.5, (x, y, base_z + h + 1.3), _m("flame", flame_mat), subdiv=3,
                  scale=(0.55, 0.55, 1.7))
    fl.visible_shadow = False
    if light:
        E.light(scene, "POINT", "candle_light", (x, y, base_z + h + 1.4), energy, color=(1.0, 0.6, 0.28),
                size=0.4)
    return base_z + h


def book(x, y, z, w, d, t, rot=0.0, color=(0.08, 0.02, 0.02), name="book"):
    leather, k = E.material(f"{name} leather")
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 1.5, 8, 0.6).outputs["Fac"]
    col = k.mix(k.math("MULTIPLY", n, 0.5), (*color, 1), (0.01, 0.008, 0.006, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.6, Normal=k.bump(n, 0.3, 0.1)))
    cover = E.cube(name, (w, d, t), (x, y, z + t / 2), leather, bevel=0.25)
    cover.rotation_euler = (0, 0, rot)
    pages, k = E.material(f"{name} pages")
    obj = k.coords().outputs["Object"]
    wv = k.node("ShaderNodeTexWave", bands_direction="Z")
    k.link(obj, wv.inputs["Vector"])
    k.set(wv, Scale=40.0, Distortion=1.0)
    k.surface(k.bsdf(Base_Color=k.ramp(wv.outputs["Fac"], [(0.2, (0.55, 0.45, 0.3)), (0.8, (0.8, 0.7, 0.52))]),
                     Roughness=0.9))
    pg = E.cube(f"{name}_pages", (w - 0.5, d - 0.6, t - 0.6), (0.3, 0, 0), pages)
    pg.parent = cover
    gold = _m("brass", brass)
    for yy in (-d * 0.3, -d * 0.22, d * 0.22, d * 0.3):
        b = E.cube(f"{name}_band", (0.7, 0.35, t * 1.04), (-w / 2 + 0.2, yy, 0), gold)
        b.parent = cover
    return z + t


def book_stack(x, y, z, n, seed=0, w=(10, 13), d=(14, 18), t=(1.8, 3.0), palette=None):
    rng = random.Random(seed)
    palette = palette or [(0.07, 0.015, 0.012), (0.02, 0.03, 0.07), (0.03, 0.05, 0.025), (0.06, 0.04, 0.02)]
    top = z
    for i in range(n):
        top = book(x + rng.uniform(-0.8, 0.8), y + rng.uniform(-0.8, 0.8), top, rng.uniform(*w), rng.uniform(*d),
                   rng.uniform(*t), rot=rng.uniform(-0.15, 0.15) + math.pi / 2, color=rng.choice(palette),
                   name=f"book{seed}_{i}")
    return top


def coin(x, y, z, r=1.4, tilt=(0, 0), name="coin"):
    c = E.cylinder(name, r, 0.22, (x, y, z + 0.11), _m("coin", lambda: brass("Coin brass", worn=0.7)), segs=40,
                   bevel=0.05)
    c.rotation_euler = (tilt[0], tilt[1], 0)
    return c


def bowl(x, y, z, r, mat, depth=None):
    depth = depth or r * 0.55
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=r)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 0.001], context="VERTS")
    bmesh.ops.scale(bm, vec=(1, 1, depth / r), verts=bm.verts)
    ob = E.mesh_object("bowl", bm, mat, smooth=True)
    ob.location = (x, y, z + depth)
    s = ob.modifiers.new("solid", "SOLIDIFY")
    s.thickness = 0.35
    return ob


def runestones(x, y, z, n, glow=(0.2, 0.55, 1.0), seed=5, spread=3.0):
    m, k = E.material("Runestone")
    obj = k.coords().outputs["Object"]
    v = k.voronoi(obj, 1.8, feature="DISTANCE_TO_EDGE")
    line = k.math("LESS_THAN", v.outputs["Distance"], 0.05)
    stone = k.bsdf(Base_Color=(0.55, 0.65, 0.8, 1), Transmission_Weight=0.8, Roughness=0.25, IOR=1.5)
    k.surface(k.add_shader(stone, k.emission((*glow, 1), k.math("MULTIPLY", line, 12.0))))
    rng = random.Random(seed)
    for i in range(n):
        a, rr = rng.uniform(0, 6.28), spread * math.sqrt(rng.random())
        E.rock(f"runestone{i}", rng.uniform(0.9, 1.3), (x + math.cos(a) * rr, y + math.sin(a) * rr,
                                                       z + rng.uniform(0.3, 1.2)), m, seed=seed * 10 + i,
               squash=(1.0, 0.8, 0.45), strength=0.15, subdiv=3)


def paper(x, y, z, w, d, rot=0.0, mat=None, curl=0.6, seed=0):
    ob = E.plane("paper", w, d, (x, y, z + 0.05), mat or _m("parchment", parchment), subdiv=24)
    ob.rotation_euler = (0, 0, rot)
    tex = bpy.data.textures.new(f"curl{seed}", "CLOUDS")
    tex.noise_scale = 6.0
    dm = ob.modifiers.new("curl", "DISPLACE")
    dm.texture = tex
    dm.strength = curl
    dm.texture_coords = "GLOBAL"
    sol = ob.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.05
    return ob


def torus(name, R, r, loc, mat, rot=(0, 0, 0), major_seg=96, minor_seg=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=major_seg,
                                     minor_segments=minor_seg, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def armillary(x, y, z, R=6.0, mat=None):
    mat = mat or _m("brass", brass)
    E.cylinder("arm_base", 3.0, 0.8, (x, y, z + 0.4), mat, r2=2.4, bevel=0.2)
    E.cylinder("arm_post", 0.35, R + 2.0, (x, y, z + (R + 2) / 2 + 0.8), mat, segs=16)
    cz = z + R + 3.0
    torus("arm_meridian", R, 0.22, (x, y, cz), mat, rot=(math.radians(90), 0, 0.3))
    torus("arm_equator", R * 0.98, 0.18, (x, y, cz), mat, rot=(math.radians(23), 0, 0))
    torus("arm_ecliptic", R * 0.9, 0.16, (x, y, cz), mat, rot=(math.radians(-35), math.radians(20), 0))
    torus("arm_colure", R * 0.95, 0.15, (x, y, cz), mat, rot=(math.radians(90), 0, 1.6))
    E.sphere("arm_globe", R * 0.28, (x, y, cz), _m("glass", glass), subdiv=4)


def hourglass(x, y, z, h=10.0, sand=(0.85, 0.7, 0.45), glow=0.0, mat=None):
    mat = mat or _m("brass", brass)
    r = h * 0.26
    for zz in (z + 0.3, z + h - 0.3):
        E.cylinder("hg_plate", r * 1.25, 0.6, (x, y, zz), mat, bevel=0.1)
    for i in range(3):
        a = 2 * math.pi * i / 3
        E.cylinder("hg_post", 0.18, h, (x + math.cos(a) * r * 1.05, y + math.sin(a) * r * 1.05, z + h / 2), mat,
                   segs=10)
    g = _m("glass", glass)
    for s in (1, -1):
        E.sphere("hg_bulb", r * 0.95, (x, y, z + h / 2 + s * h * 0.22), g, subdiv=4, scale=(1, 1, 1.25))
    sm, k = E.material("Sand")
    sh = k.bsdf(Base_Color=(*sand, 1), Roughness=0.9)
    if glow:
        sh = k.add_shader(sh, k.emission((*sand, 1), glow))
    k.surface(sh)
    E.sphere("hg_sand", r * 0.8, (x, y, z + h * 0.2), sm, subdiv=3, scale=(1, 1, 0.55))
    E.cylinder("hg_stream", 0.06, h * 0.35, (x, y, z + h * 0.42), sm, segs=6)


def gear(name, r, teeth, thick, loc, mat, rot=(0, 0, 0), hole=0.3):
    bm = bmesh.new()
    pts = []
    tooth = r * 0.12
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        rr = r + (tooth if (i % 4) in (1, 2) else 0)
        pts.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), 0)))
    f = bm.faces.new(pts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z += thick
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    ob = E.mesh_object(name, bm, mat)
    ob.location = loc
    ob.rotation_euler = rot
    if hole:
        cut = E.cylinder(name + "_hole", r * hole, thick * 4, loc, None, segs=24)
        cut.rotation_euler = rot
        b = ob.modifiers.new("hole", "BOOLEAN")
        b.object = cut
        b.solver = "EXACT"
        cut.hide_render = True
        cut.hide_viewport = True
    bev = ob.modifiers.new("bevel", "BEVEL")
    bev.width = min(0.08, thick * 0.2)
    bev.segments = 2
    return ob


def backdrop_window(x, y, z, w, h, sky_top=(0.02, 0.04, 0.12), sky_bot=(0.1, 0.12, 0.25), moon=True,
                    frame_mat=None):
    """A night window: gradient sky plane + mullions (reads as depth, not detail)."""
    m, k = E.material("Night sky")
    tc = k.coords().outputs["Generated"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(tc, sep.inputs[0])
    col = k.ramp(sep.outputs["Y"], [(0.0, sky_bot), (1.0, sky_top)])
    stars = k.voronoi(tc, 180.0)
    st = k.math("LESS_THAN", stars.outputs["Distance"], 0.05)
    em = k.emission(col, 1.0)
    k.surface(k.add_shader(em, k.emission((1, 1, 1, 1), k.math("MULTIPLY", st, 3.0))))
    sky = E.plane("sky", w, h, (x, y + 30, z), m)
    sky.rotation_euler = (math.radians(90), 0, 0)
    fm = frame_mat or E.simple("Window frame", (0.02, 0.015, 0.012), 0.6)
    for i in range(4):
        E.cube("mullion_v", (1.2, 1.2, h), (x - w / 2 + i * w / 3, y, z), fm)
    for j in range(3):
        E.cube("mullion_h", (w, 1.2, 1.2), (x, y, z - h / 2 + j * h / 2), fm)
    if moon:
        E.sphere("moon", h * 0.07, (x + w * 0.2, y + 28, z + h * 0.25), E.emissive("Moon", (0.8, 0.85, 1.0), 6.0))
