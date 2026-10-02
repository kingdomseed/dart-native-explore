"""Save the procedural look-dev scenes as .blend files for a Blender artist.

Blender --background --python export_blend.py -- --room <theme> --out <dir>
    <dir>/rooms/<theme>.blend: the room exactly as render_set.py assembles it
    (tray, room, dice, lights, world, render settings) with the room, hero and
    top-down cameras, sorted into collections, generated images packed.
Blender --background --python export_blend.py -- --library --out <dir>
    <dir>/library/dice-room-assets.blend: every assets/*.py module built once
    at the origin with its defaults, one asset-marked collection per module.
Blender --background --python export_blend.py -- --dice --out <dir>
    <dir>/library/dice-sets.blend: the seven dice of every set, asset-marked
    per die and per set.
Blender --background --python export_blend.py -- --verify <file.blend> [--thumb out.jpg]
    Reopen a saved file, print what is in it, optionally render a thumbnail.

--library and --dice also write <dir>/library/blender_assets.cats.txt.
export_blend.sh runs all of it, one Blender at a time. Nothing here changes
how a scene looks: objects are only moved between collections after the build.
"""
from __future__ import annotations

import argparse
import ast
import importlib
import json
import pkgutil
import sys
import tempfile
import time
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import build_dice  # noqa: E402
import env_common as E  # noqa: E402
import render_set  # noqa: E402

ROOM_RES = (1600, 900)
NOT_ASSETS = {"geometry", "materials", "preview_asset"}
CATALOG_NS = uuid.UUID("6f1d3c0a-5b7e-4f0e-9c56-d1ce00b1e7d0")


def log(*parts):
    print("export_blend:", *parts, flush=True)


def asset_modules():
    import assets
    names = sorted(m.name for m in pkgutil.iter_modules(assets.__path__) if m.name not in NOT_ASSETS)
    mods = {}
    for name in names:
        mod = importlib.import_module(f"assets.{name}")
        if hasattr(mod, "build"):
            mods[name] = mod
    return mods


def themes():
    return sorted(build_dice.THEMES)


# --------------------------------------------------------------------------
# Collections, packing, saving
# --------------------------------------------------------------------------

def child_collection(parent, name):
    coll = bpy.data.collections.new(name)
    parent.children.link(coll)
    return coll


def move_to(ob, coll, scene_tree):
    """Put `ob` in `coll`, leaving memberships outside the scene's own tree
    (light-linking receiver collections) untouched."""
    for c in list(ob.users_collection):
        if c in scene_tree:
            c.objects.unlink(ob)
    if ob.name not in coll.objects:
        coll.objects.link(ob)


def pack_images():
    try:
        bpy.ops.file.pack_all()
    except RuntimeError as err:  # one unreadable file must not stop the rest
        log("pack_all:", str(err).strip())
    unpacked = []
    for img in bpy.data.images:
        if img.type != "IMAGE" or img.source not in ("FILE", "GENERATED"):
            continue
        if img.packed_file is None:
            try:
                img.pack()
            except RuntimeError:
                pass
        if img.packed_file is None:
            unpacked.append(img.name)
        elif img.filepath and not img.filepath.startswith("//textures/"):
            img.filepath = "//textures/" + Path(img.filepath).name  # where File > External Data > Unpack puts it
    return unpacked


def save(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
    log("saved", str(path), f"{path.stat().st_size / 1e6:.1f} MB")


def add_text(name, body):
    bpy.data.texts.new(name).write(body)


# --------------------------------------------------------------------------
# Rooms
# --------------------------------------------------------------------------

class BuildTracker:
    """Remembers which objects the tray stage made and which asset module
    built each prop, without touching what the builders do."""

    def __init__(self, env):
        self.tray_names = None
        self.props = []  # (module name, root object) for top-level asset builds
        self._depth = 0
        for name, mod in asset_modules().items():
            mod.build = self._wrap_asset(name, mod.build)
        if hasattr(env, "room"):
            env.room = self._wrap_room(env.room)

    def _wrap_room(self, fn):
        def room(*a, **kw):
            self.tray_names = {o.name for o in bpy.data.objects}
            return fn(*a, **kw)
        return room

    def _wrap_asset(self, name, fn):
        def build(*a, **kw):
            self._depth += 1
            try:
                root = fn(*a, **kw)
            finally:
                self._depth -= 1
            if self._depth == 0 and isinstance(root, bpy.types.Object):
                self.props.append((name, root))
            return root
        return build


def shot_settings(scene, res):
    return dict(resolution_x=res[0], resolution_y=res[1], filter_width=round(scene.cycles.filter_width, 4),
                gamma=round(scene.view_settings.gamma, 4), exposure=round(scene.view_settings.exposure, 4))


def pose(objs, logos):
    bpy.context.view_layer.update()
    return {ob.name: (ob.location.copy(), ob.rotation_quaternion.copy())
            for ob in list(objs.values()) + list(logos.values())}


APPLY_SHOT = '''"""Switch this scene to one of the look-dev shots.

Each shot has its own camera, dice layout (keyed on frames 1..N, one frame
per shot) and a few render settings. Set SHOT below and press Run Script.
The same values are stored as custom properties on each camera.
"""
import bpy

SHOT = "{primary}"
SHOTS = {shots}

s = SHOTS[SHOT]
scene = bpy.context.scene
scene.frame_set(s["frame"])
scene.camera = scene.objects[SHOT]
scene.render.resolution_x, scene.render.resolution_y = s["resolution_x"], s["resolution_y"]
scene.cycles.filter_width = s["filter_width"]
scene.view_settings.gamma = s["gamma"]
scene.view_settings.exposure = s["exposure"]
'''

ROOM_NOTES = """{theme}: dice look-dev room, saved from dart3d/example/tool/dice_lookdev
(build_env_{theme}.py + build_dice.py, assembled like render_set.py).

Units: 1 Blender unit = 1 cm (Unit Scale 0.01, Length = Centimeters).
Light power and depth-of-field f-stops are authored for that scale.
Materials are procedural node materials; the few generated images (dice
numeral atlas, inlay masks) are packed in this file.

Shots: {shot_list}. Frame N of the timeline holds shot N's dice layout and a
marker binds its camera. Run the text "apply_shot.py" to also switch the
resolution and the per-shot filter width / gamma / exposure.
The top-down shot is the in-app view; look-dev renders of it darken and
desaturate everything outside the tray in a 2D pass after rendering
(env_common.play_view_grade), which is not part of this scene.

Collections: Tray, Room, Props/<asset>, Dice, Lights/Tray lights,
Lights/Room lights, Cameras. Each Props collection has an "asset_module"
custom property naming the assets/*.py module that built it. Room lights
use light linking: the "... light receivers" collections are not in the
scene tree on purpose.
"""


def export_room(theme, out, tmp):
    t0 = time.time()
    scene = E.reset()
    scene.name = theme
    E.TMP = str(tmp)
    env = importlib.import_module(f"build_env_{theme}")
    tracker = BuildTracker(env)
    info = env.build(scene)
    E.setup_cycles(scene, samples=info.get("samples", 256), look=info.get("look"),
                   exposure=info.get("exposure", 0.0), view=info.get("view", "Khronos PBR Neutral"))
    scene.render.use_motion_blur = False
    objs, specs, _stats, _atlas = build_dice.make_set(theme, tmp / "atlas")
    logos = {k: bpy.data.objects[ob["logo"]] for k, ob in objs.items() if "logo" in ob}
    z = info.get("surface_z", 0.0)
    shots = {}  # name -> (camera, pose, settings); same order and calls as render_set.run

    def aim_logos(cam):
        if logos:
            bpy.context.view_layer.update()
            build_dice.align_logos(objs, logos, cam.matrix_world.translation.copy())

    E.place_layout(objs, specs, info.get("topdown_layout", E.TOPDOWN_LAYOUT))
    cam = render_set.topdown_camera(scene, info, z)
    aim_logos(cam)
    shots["topdown"] = (cam, pose(objs, logos), shot_settings(scene, render_set.PHONE))

    centre = Vector(info.get("centre", (0.0, 2.0, z + 1.0)))
    h = info.get("hero", {})
    loc = E.orbit(centre, h.get("dist", 34) * 1.12, h.get("elev", 27), h.get("az", 0))
    E.place_layout(objs, specs, info.get("hero_layout", E.HERO_LAYOUT), centre=centre.to_2d(), facing_from=loc)
    cam = E.camera(scene, "hero", loc, centre, lens=h.get("lens", 70), fstop_real=h.get("fstop", 2.8),
                   focus=centre + Vector((0, -1.0, 0)))
    aim_logos(cam)
    shots["hero"] = (cam, pose(objs, logos), shot_settings(scene, ROOM_RES))

    rc = info.get("room_cam")
    if rc:
        E.place_layout(objs, specs, info.get("hero_layout", E.HERO_LAYOUT), centre=centre.to_2d(),
                       facing_from=rc["loc"])
        cam = E.camera(scene, "room", rc["loc"], rc["target"], lens=rc.get("lens", 24),
                       fstop_real=rc.get("fstop", 5.6), focus=rc.get("focus", centre))
        aim_logos(cam)
        scene.camera = cam
        # some rooms change the pixel filter / grade for the room shot in a
        # render_pre handler; handlers are not saved, so bake the result
        if hasattr(env, "_room_sampling"):
            env._room_sampling(scene)
        shots["room"] = (cam, pose(objs, logos), shot_settings(scene, ROOM_RES))
    contacts = E.contact_report(objs)
    bad = {k: v for k, v in contacts.items() if v["overlaps"] or not (0 <= v["gap_cm"] < 0.01)}
    if bad:
        log("CONTACT PROBLEMS", json.dumps(bad))

    # one frame per shot, the establishing shot first; constant keys
    order = [n for n in ("room", "hero", "topdown") if n in shots]
    primary = order[0]
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "CONSTANT"
    table = {}
    for frame, name in enumerate(order, start=1):
        cam, poses, settings = shots[name]
        for ob_name, (loc_, quat) in poses.items():
            ob = bpy.data.objects[ob_name]
            ob.location, ob.rotation_quaternion = loc_, quat
            ob.keyframe_insert("location", frame=frame)
            ob.keyframe_insert("rotation_quaternion", frame=frame)
        scene.timeline_markers.new(name, frame=frame).camera = cam
        table[name] = dict(frame=frame, **settings)
        for key, val in table[name].items():
            cam[key] = val
    scene.frame_start, scene.frame_end = 1, len(order)
    scene.frame_set(1)
    cam, poses, settings = shots[primary]
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = settings["resolution_x"], settings["resolution_y"]
    scene.render.resolution_percentage = 100
    scene.render.filepath = f"//{theme}-"
    bpy.context.view_layer.update()
    drift = max((bpy.data.objects[n].matrix_world.translation - p[0]).length for n, p in poses.items())
    assert drift < 1e-5, f"keyed dice moved by {drift}"

    counts = organise_room(scene, tracker, objs, logos)
    add_text("README", ROOM_NOTES.format(theme=theme, shot_list=", ".join(
        f"{i}: {n}" for i, n in enumerate(order, start=1))))
    add_text("apply_shot.py", APPLY_SHOT.format(primary=primary, shots=json.dumps(table, indent=4)))
    unpacked = pack_images()
    save(out / "rooms" / f"{theme}.blend")
    log("room", theme, json.dumps(dict(objects=len(scene.objects), collections=counts, shots=table,
                                       images=len(bpy.data.images), unpacked=unpacked,
                                       seconds=round(time.time() - t0))))


def organise_room(scene, tracker, objs, logos):
    tree = {scene.collection, *scene.collection.children_recursive}
    dice = set(objs.values()) | set(logos.values())
    for ob in objs.values():
        dice.update(ob.children_recursive)
    prop_of = {}
    for module, root in tracker.props:
        for ob in (root, *root.children_recursive):
            prop_of.setdefault(ob, root)
    module_of = {root: module for module, root in tracker.props}
    tray_names = tracker.tray_names  # None: this set has no room stage
    made = {}

    def coll(path):
        if path not in made:
            parent = coll(path[:-1]) if len(path) > 1 else scene.collection
            made[path] = child_collection(parent, path[-1])
        return made[path]

    for ob in list(scene.objects):
        in_tray = tray_names is None or ob.name in tray_names
        if ob in dice:
            path = ("Dice",)
        elif ob.type == "CAMERA":
            path = ("Cameras",)
        elif ob in prop_of:
            root = prop_of[ob]
            path = ("Props", root.name)
            coll(path)["asset_module"] = module_of[root]
        elif ob.type == "LIGHT":
            path = ("Lights", "Tray lights" if in_tray else "Room lights")
        else:
            path = ("Tray",) if in_tray else ("Room",)
        move_to(ob, coll(path), tree)
    counts = {}
    for path, c in made.items():
        top = path[0]
        counts[top] = counts.get(top, 0) + len(c.objects)
    counts["Props collections"] = sum(1 for p in made if len(p) == 2 and p[0] == "Props")
    return counts


# --------------------------------------------------------------------------
# Asset libraries
# --------------------------------------------------------------------------

def asset_themes():
    """{asset module: [themes whose build_env imports it]}"""
    used = {}
    for theme in themes():
        tree = ast.parse((HERE / f"build_env_{theme}.py").read_text())
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom) and node.module == "assets":
                for alias in node.names:
                    used.setdefault(alias.name, []).append(theme)
            elif isinstance(node, ast.ImportFrom) and (node.module or "").startswith("assets."):
                used.setdefault(node.module.split(".")[1], []).append(theme)
    return {k: sorted(set(v)) for k, v in used.items()}


def catalog_id(path):
    return str(uuid.uuid5(CATALOG_NS, path))


def catalog_paths():
    paths = ["Dice", "Room props", "Room props/Shared", "Room props/Components"]
    for theme in themes():
        paths += [f"Dice/{theme.capitalize()}", f"Room props/{theme.capitalize()}"]
    return sorted(paths)


def write_catalogs(lib_dir):
    lines = ["# This is an Asset Catalog Definition file for Blender.",
             "#",
             "# Written by dart3d/example/tool/dice_lookdev/export_blend.py.",
             "", "VERSION 1", ""]
    for path in catalog_paths():
        lines.append(f"{catalog_id(path)}:{path}:{path.replace('/', '-')}")
    lib_dir.mkdir(parents=True, exist_ok=True)
    (lib_dir / "blender_assets.cats.txt").write_text("\n".join(lines) + "\n")


def mark(coll, catalog, description, tags):
    coll.asset_mark()
    coll.asset_data.catalog_id = catalog_id(catalog)
    coll.asset_data.description = description
    coll.asset_data.author = "dart3d dice look-dev (procedural, export_blend.py)"
    for tag in tags:
        coll.asset_data.tags.new(tag, skip_if_exists=True)


def generate_previews(colls, timeout=900):
    """Ask Blender for collection previews and wait for its preview jobs."""
    t0 = time.time()
    for coll in colls:
        try:
            coll.asset_generate_preview()
        except Exception as err:  # noqa: BLE001 - previews are optional
            log("preview failed", coll.name, err)
    while bpy.app.is_job_running("RENDER_PREVIEW") and time.time() - t0 < timeout:
        time.sleep(0.5)
    have = [c.name for c in colls if c.preview and c.preview.image_size[0] and any(c.preview.image_pixels_float)]
    log(f"previews: {len(have)}/{len(colls)} in {time.time() - t0:.0f}s")
    return have


def hide_all(scene, colls):
    """Everything sits at the origin; start with the collections hidden."""
    names = {c.name for c in colls}

    def walk(lc):
        for child in lc.children:
            if child.collection.name in names:
                child.hide_viewport = True
            walk(child)
    walk(bpy.context.view_layer.layer_collection)


LIBRARY_NOTES = """Dice-room asset library, built by dart3d/example/tool/dice_lookdev/export_blend.py.

Every collection is one assets/<name>.py module built at the origin with its
default parameters, and is marked as an asset. Units: 1 Blender unit = 1 cm
(Unit Scale 0.01). All collections start hidden (eye icon) because they
overlap at the origin. Materials are procedural node materials.
"""


def export_library(out, only=None, previews=True):
    t0 = time.time()
    scene = E.reset()
    scene.name = "Dice room assets"
    used = asset_themes()
    tree = {scene.collection}
    done, failed, stats = [], {}, {}
    for name, mod in asset_modules().items():
        if only and name not in only:
            continue
        before = set(bpy.data.objects)
        t1 = time.time()
        try:
            root = mod.build()
            new = [o for o in bpy.data.objects if o not in before]
            if not isinstance(root, bpy.types.Object) or not new:
                raise RuntimeError("build() returned no root object")
        except Exception as err:  # noqa: BLE001 - report and carry on with the other modules
            failed[name] = f"{type(err).__name__}: {err}"
            log("FAILED", name, failed[name])
            for ob in [o for o in bpy.data.objects if o not in before]:
                bpy.data.objects.remove(ob)
            continue
        coll = child_collection(scene.collection, name)
        coll["asset_module"] = name
        for ob in new:
            if ob.users_collection:  # helper curves that were never linked stay unlinked
                move_to(ob, coll, tree)
        where = used.get(name, [])
        catalog = ("Room props/Components" if not where else
                   f"Room props/{where[0].capitalize()}" if len(where) == 1 else "Room props/Shared")
        doc = (mod.__doc__ or "").strip().splitlines()
        mark(coll, catalog, doc[0] if doc else f"assets/{name}.py with default parameters", where)
        stats[name] = dict(objects=len(coll.objects), catalog=catalog, seconds=round(time.time() - t1, 1))
        done.append(coll)
        log("asset", name, json.dumps(stats[name]))
    have = generate_previews(done) if previews else []
    hide_all(scene, done)
    add_text("README", LIBRARY_NOTES)
    unpacked = pack_images()
    lib = out / "library"
    write_catalogs(lib)
    save(lib / "dice-room-assets.blend")
    log("library", json.dumps(dict(assets=len(done), failed=failed, previews=len(have), unpacked=unpacked,
                                   objects=len(scene.objects), seconds=round(time.time() - t0))))


DICE_NOTES = """Dice sets, built by dart3d/example/tool/dice_lookdev/export_blend.py from build_dice.py.

One asset-marked collection per set ("<set> dice", seven dice in a row centred
on the origin, resting on z = 0) and one per die ("<set> <kind>"). A die's
collection has its Instance Offset on the die, so dropping it from the Asset
Browser as a collection instance puts the die where you drop it. Units:
1 Blender unit = 1 cm (Unit Scale 0.01). The numeral atlases are packed.
Sets with a core (emberforged, frostbound) parent it to the die; the
DartNative logo is a separate object that the look-dev re-aims at the camera
for every shot (build_dice.align_logos).
"""


def export_dice(out, tmp, only=None, previews=True):
    t0 = time.time()
    scene = E.reset()
    scene.name = "Dice sets"
    specs = build_dice.all_specs()
    done = []
    for theme in themes():
        if only and theme not in only:
            continue
        set_coll = child_collection(scene.collection, f"{theme} dice")
        objs, _specs, _stats, _atlas = build_dice.make_set(theme, tmp / "atlas", collection=set_coll, specs=specs)
        logos = {k: bpy.data.objects[ob["logo"]] for k, ob in objs.items() if "logo" in ob}
        kinds = list(objs)
        for i, kind in enumerate(kinds):
            ob = objs[kind]
            value = E.HERO_LAYOUT[kind][1]
            ob.rotation_quaternion = build_dice.face_quaternion(specs[kind], value)
            x = (i - (len(kinds) - 1) / 2) * 4.5
            ob.location = (x, 0, 0)
            bpy.context.view_layer.update()
            ob.location.z = -min((ob.matrix_world @ v.co).z for v in ob.data.vertices)
        if logos:
            bpy.context.view_layer.update()
            build_dice.align_logos(objs, logos, Vector((0, -60, 45)), yaw=0)
        mark(set_coll, f"Dice/{theme.capitalize()}", f"The seven {theme} dice (d4, d6, d8, d10, d10 tens, d12, d20)",
             [theme, "dice"])
        done.append(set_coll)
        for kind in kinds:
            ob = objs[kind]
            die_coll = child_collection(set_coll, f"{theme} {kind}")
            for member in (ob, *ob.children_recursive, *([logos[kind]] if kind in logos else [])):
                set_coll.objects.unlink(member)
                die_coll.objects.link(member)
            die_coll.instance_offset = (ob.location.x, ob.location.y, 0)
            mark(die_coll, f"Dice/{theme.capitalize()}", f"{theme} {kind}", [theme, "dice", kind])
            done.append(die_coll)
        log("dice", theme, len(set_coll.all_objects), "objects")
    have = generate_previews(done) if previews else []
    hide_all(scene, [c for c in done if c.name.endswith(" dice")])
    add_text("README", DICE_NOTES)
    unpacked = pack_images()
    lib = out / "library"
    write_catalogs(lib)
    save(lib / "dice-sets.blend")
    log("dice library", json.dumps(dict(assets=len(done), previews=len(have), unpacked=unpacked,
                                        objects=len(scene.objects), seconds=round(time.time() - t0))))


# --------------------------------------------------------------------------
# Verify
# --------------------------------------------------------------------------

def verify(path, thumb=None, samples=16, pct=25):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    by_type = {}
    for ob in scene.objects:
        by_type[ob.type] = by_type.get(ob.type, 0) + 1
    top = {c.name: len(c.all_objects) for c in scene.collection.children}
    assets_ = [c for c in bpy.data.collections if c.asset_data]
    images = [i for i in bpy.data.images if i.type == "IMAGE" and i.source in ("FILE", "GENERATED")]
    report = dict(
        file=str(path), size_mb=round(Path(path).stat().st_size / 1e6, 1), blender=bpy.app.version_string,
        scene=scene.name, objects=len(scene.objects), by_type=by_type,
        collections=len(scene.collection.children_recursive),
        top_collections=top if len(top) <= 12 else f"{len(top)} top-level collections",
        asset_collections=len(assets_),
        assets_with_catalog=sum(1 for c in assets_ if c.asset_data.catalog_id != "00000000-0000-0000-0000-000000000000"),
        assets_with_preview=sum(1 for c in assets_ if c.preview and c.preview.image_size[0] > 0),
        materials=len(bpy.data.materials),
        images=len(images), images_packed=sum(1 for i in images if i.packed_file),
        cameras=[o.name for o in scene.objects if o.type == "CAMERA"],
        active_camera=scene.camera.name if scene.camera else None,
        markers={m.name: m.frame for m in scene.timeline_markers},
        unit_scale=round(scene.unit_settings.scale_length, 6), unit_system=scene.unit_settings.system,
        length_unit=scene.unit_settings.length_unit,
        engine=scene.render.engine, samples=scene.cycles.samples,
        resolution=[scene.render.resolution_x, scene.render.resolution_y],
        view=scene.view_settings.view_transform, exposure=round(scene.view_settings.exposure, 3),
        gamma=round(scene.view_settings.gamma, 3), filter_width=round(scene.cycles.filter_width, 3),
        world=scene.world.name if scene.world else None,
    )
    log("verify", json.dumps(report))
    if thumb:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        try:
            prefs.compute_device_type = "METAL"
            prefs.get_devices()
            for d in prefs.devices:
                d.use = True
        except Exception:  # noqa: BLE001 - CPU fallback
            scene.cycles.device = "CPU"
        scene.cycles.samples = samples
        scene.render.resolution_percentage = pct
        scene.render.image_settings.file_format = "JPEG"
        scene.render.image_settings.quality = 90
        scene.render.filepath = str(thumb)
        t0 = time.time()
        bpy.ops.render.render(write_still=True)
        log("thumbnail", str(thumb), f"{samples} samples at {pct}%, {time.time() - t0:.0f}s")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--room", choices=themes())
    ap.add_argument("--library", action="store_true")
    ap.add_argument("--dice", action="store_true")
    ap.add_argument("--verify")
    ap.add_argument("--thumb")
    ap.add_argument("--samples", type=int, default=16)
    ap.add_argument("--pct", type=int, default=25)
    ap.add_argument("--only", default="", help="comma-separated asset modules / themes (testing)")
    ap.add_argument("--no-previews", action="store_true")
    ap.add_argument("--out", default=str(Path.home() / "repos" / "dart-native-explore-media" / "blend"))
    ap.add_argument("--tmp", default="")
    a = ap.parse_args(argv)
    out = Path(a.out)
    tmp = Path(a.tmp or tempfile.mkdtemp(prefix="export_blend_"))
    tmp.mkdir(parents=True, exist_ok=True)
    only = set(filter(None, a.only.split(",")))
    if a.room:
        export_room(a.room, out, tmp)
    elif a.library:
        export_library(out, only, not a.no_previews)
    elif a.dice:
        export_dice(out, tmp, only, not a.no_previews)
    elif a.verify:
        verify(Path(a.verify), a.thumb, a.samples, a.pct)
    else:
        ap.error("one of --room, --library, --dice, --verify")


if __name__ == "__main__":
    main()
