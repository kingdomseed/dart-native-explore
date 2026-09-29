"""Render one themed dice set in its environment (Cycles).

Blender --background --python render_set.py -- --theme emberforged \
    [--shots hero,d20,env,phone] [--samples 256] [--pct 100] \
    [--out docs/design/dice-lookdev] [--tmp /tmp/x] [--save-blend f.blend]

Shots
  hero  - the full set settled in the tray, 3/4 view, shallow depth of field
  d20   - d20 close-up
  env   - establishing shot of the environment, dice mid-roll (motion blur)
  phone - top-down portrait framing as the app would see it (walls = screen edges)
"""
from __future__ import annotations

import argparse
import math
import importlib
import json
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


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--theme", required=True, choices=sorted(build_dice.THEMES))
    ap.add_argument("--shots", default="hero,d20,env")
    ap.add_argument("--samples", type=int, default=0, help="0 = environment default")
    ap.add_argument("--pct", type=int, default=100, help="resolution percentage (previews)")
    ap.add_argument("--out", default=str(REPO / "docs" / "design" / "dice-lookdev"))
    ap.add_argument("--tmp", default=tempfile.mkdtemp(prefix="dice_lookdev_"))
    ap.add_argument("--save-blend")
    return ap.parse_args(argv)


def main():
    a = args()
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

    def shot(name, cam, res=(1600, 900), motion=False):
        scene.render.resolution_x, scene.render.resolution_y = res
        scene.render.use_motion_blur = motion
        scene.render.motion_blur_shutter = 0.3
        sizes[name] = E.render_to(scene, cam, tmp / f"{a.theme}_{name}.png", out / f"{a.theme}-{name}.png",
                                  colors=info.get("colors", 128))

    centre = Vector(info.get("centre", (0.0, 2.0, z + 1.0)))
    if "hero" in shots or "d20" in shots:
        h = info.get("hero", {})
        loc = E.orbit(centre, h.get("dist", 34), h.get("elev", 27), h.get("az", 0))
        E.place_hero(objs, specs, loc, centre=centre.to_2d(), surface_z=z)
        if "hero" in shots:
            cam = E.camera(scene, "hero", loc, centre, lens=h.get("lens", 70), fstop_real=h.get("fstop", 2.8),
                           focus=centre + Vector((0, -1.0, 0)))
            shot("hero", cam)
        if "d20" in shots:
            d = info.get("d20", {})
            t = objs["d20"].location.copy() + Vector((0, 0, 0.3))
            loc = E.orbit(t, d.get("dist", 12), d.get("elev", 34), d.get("az", -12))
            cam = E.camera(scene, "d20", loc, t, lens=d.get("lens", 100), fstop_real=d.get("fstop", 4.0))
            shot("d20", cam, res=(1200, 675))
    def scaled_roll():
        # roll layouts are authored for a 24 x 44 cm area; fit them to the tray
        r = info["roll"]
        sx, sy = E.TRAY_W / 24.0, E.TRAY_D / 44.0
        settled = {k: ((x * sx, y * sy), v, yaw) for k, ((x, y), v, yaw) in r["settled"].items()}
        air = {k: ((x * sx, y * sy, z), vel) for k, ((x, y, z), vel) in r["airborne"].items()}
        return settled, air

    if "env" in shots:
        e = info.get("env", {})
        E.place_roll(objs, specs, *scaled_roll(), surface_z=z)
        t = Vector(e.get("target", (0, 4, 0)))
        loc = E.orbit(t, e.get("dist", 95), e.get("elev", 32), e.get("az", 18))
        cam = E.camera(scene, "env", loc, t, lens=e.get("lens", 35), fstop_real=e.get("fstop", 8.0),
                       focus=e.get("focus", (0, 0, z)))
        shot("env", cam, res=(1200, 675), motion=True)
    if "phone" in shots:
        E.place_roll(objs, specs, *scaled_roll(), surface_z=z)
        # Portrait 9:19.5, looking down with a slight tilt from the player's side.
        # Long walls sit on the screen edges; props peek in above/below the tray.
        ph = info.get("phone", {})
        frame_h = E.TRAY_D + ph.get("margin", 13.0)
        tilt = math.radians(ph.get("tilt", 14.0))
        dist = 95.0
        tgt = Vector((0, ph.get("shift", 2.0), z))
        loc = tgt + Vector((0, -math.sin(tilt) * dist, math.cos(tilt) * dist))
        cam = E.camera(scene, "phone", loc, tgt, lens=50, fstop_real=ph.get("fstop", 11.0), focus=tgt)
        cam.data.sensor_fit = "VERTICAL"
        cam.data.sensor_height = 50.0 * frame_h / dist
        shot("phone", cam, res=(554, 1200), motion=True)
    if a.save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=a.save_blend)
    print("dice_lookdev: sizes", json.dumps(sizes))


main()
