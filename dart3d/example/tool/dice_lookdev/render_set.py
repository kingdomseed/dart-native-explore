"""Render one themed dice set in its environment (Cycles).

Blender --background --python render_set.py -- --theme emberforged \
    [--shots topdown,hero,d4] [--samples 256] [--pct 100] [--check] \
    [--out docs/design/dice-lookdev] [--tmp /tmp/x] [--save-blend f.blend]

Shots (every die is settled on the surface; see env_common.settle)
  topdown - PRIMARY. The in-app view: portrait 1179 x 2556 (iPhone), camera
            straight down with the app's vertical fov (0.95 rad,
            dice_table_scene.dart), tray walls at the screen edges, all seven
            dice showing a result. Judge everything from this first.
  hero    - the full set in the tray, 3/4 view, shallow depth of field
  d4      - close-up of the d4 shard with its result on the top face

--check runs readability_check.measure() on the top-down render (numeral vs
face contrast, numeral size, die vs tray contrast, contacts) and merges the
result into <out>/readability.json.
"""
from __future__ import annotations

import argparse
import importlib
import json
import math
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import build_dice  # noqa: E402
import env_common as E  # noqa: E402

REPO = HERE.parents[3]
PHONE = (1179, 2556)  # iPhone 15/16 Pro portrait, px
APP_FOV_Y = 0.95  # rad, dice_table_scene.dart cameraFovY


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--theme", required=True, choices=sorted(build_dice.THEMES))
    ap.add_argument("--shots", default="topdown,hero,d4")
    ap.add_argument("--samples", type=int, default=0, help="0 = environment default")
    ap.add_argument("--pct", type=int, default=100, help="resolution percentage (previews)")
    ap.add_argument("--check", action="store_true", help="measure readability on the top-down shot")
    ap.add_argument("--out", default=str(REPO / "docs" / "design" / "dice-lookdev"))
    ap.add_argument("--tmp", default=tempfile.mkdtemp(prefix="dice_lookdev_"))
    ap.add_argument("--save-blend")
    return ap.parse_args(argv)


def topdown_camera(scene, info, z):
    """Straight-down perspective camera framing the tray like the app."""
    td = info.get("topdown", {})
    width = td.get("width", E.TRAY_W + 5.0)  # visible table width at the surface, cm
    height = width * PHONE[1] / PHONE[0]
    dist = height / 2 / math.tan(APP_FOV_Y / 2)
    tgt = Vector((0, td.get("shift", 0.0), z))
    cam = E.camera(scene, "topdown", tgt + Vector((0, 0, dist)), tgt, lens=50)
    cam.data.sensor_fit = "VERTICAL"
    cam.data.sensor_height = 2 * 50 * math.tan(APP_FOV_Y / 2)
    return cam


def run(a):
    out, tmp = Path(a.out), Path(a.tmp)
    out.mkdir(parents=True, exist_ok=True)
    tmp.mkdir(parents=True, exist_ok=True)
    scene = E.reset()
    E.TMP = str(tmp)
    env = importlib.import_module(f"build_env_{a.theme}")
    info = env.build(scene)
    E.setup_cycles(scene, samples=a.samples or info.get("samples", 256), look=info.get("look"),
                   exposure=info.get("exposure", 0.0), view=info.get("view", "Khronos PBR Neutral"))
    scene.render.resolution_percentage = a.pct
    objs, specs, stats, atlas = build_dice.make_set(a.theme, tmp / "atlas")
    print("dice_lookdev: triangles", json.dumps(stats))
    z = info.get("surface_z", 0.0)
    shots = a.shots.split(",")
    sizes = {}
    report = {}

    def shot(name, cam, res):
        scene.render.resolution_x, scene.render.resolution_y = res
        scene.render.use_motion_blur = False
        sizes[name] = E.render_to(scene, cam, tmp / f"{a.theme}_{name}.png", out / f"{a.theme}-{name}.jpg")
        return tmp / f"{a.theme}_{name}.png"

    if "topdown" in shots:
        E.place_layout(objs, specs, info.get("topdown_layout", E.TOPDOWN_LAYOUT))
        report["contacts_topdown"] = E.contact_report(objs)
        cam = topdown_camera(scene, info, z)
        png = shot("topdown", cam, PHONE)
        if a.check:
            import readability_check as R
            res = R.measure(scene, cam, objs, specs, png, a.theme, tmp, crops_dir=HERE / "out" / "crops")
            res["contacts"] = report["contacts_topdown"]
            res["numeral_ratio_min"] = stats["numeral_ratio_min"]
            R.merge(out / "readability.json", a.theme, res)
            R.print_row(a.theme, res)
    centre = Vector(info.get("centre", (0.0, 2.0, z + 1.0)))
    if "hero" in shots or "d4" in shots:
        h = info.get("hero", {})
        loc = E.orbit(centre, h.get("dist", 34) * 1.12, h.get("elev", 27), h.get("az", 0))
        E.place_layout(objs, specs, info.get("hero_layout", E.HERO_LAYOUT), centre=centre.to_2d(), facing_from=loc)
        report["contacts_hero"] = E.contact_report(objs)
        if "hero" in shots:
            cam = E.camera(scene, "hero", loc, centre, lens=h.get("lens", 70), fstop_real=h.get("fstop", 2.8),
                           focus=centre + Vector((0, -1.0, 0)))
            shot("hero", cam, (1600, 900))
        if "d4" in shots:
            t = objs["d4"].location.copy()
            az = h.get("az", 0) - 18
            cam_loc = E.orbit(t, 13, 48, az)
            cam = E.camera(scene, "d4", cam_loc, t, lens=100, fstop_real=5.6)
            shot("d4", cam, (1000, 625))
    print("dice_lookdev: contacts", json.dumps(report))
    bad = [(s, k, v) for s, r in report.items() for k, v in r.items()
           if v["overlaps"] or not (0 <= v["gap_cm"] < 0.01)]
    if bad:
        print("dice_lookdev: CONTACT PROBLEMS", bad)
    if a.save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=a.save_blend)
    print("dice_lookdev: sizes", json.dumps(sizes))


if __name__ == "__main__":
    run(args())
