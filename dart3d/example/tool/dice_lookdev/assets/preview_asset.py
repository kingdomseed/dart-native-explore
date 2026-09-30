"""Single-asset studio inspection; run with Blender --background --python this file.

Arguments after --: --asset anvil --out <path under dice_lookdev/out>.
The unlettered scale bar is 10 cm long with 1 cm divisions.
Use --target, --extent and --direction for detail views; --studio-strength
allows inspection of emissive assets under their own light.
"""
import argparse
import importlib
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))

import bpy
from mathutils import Vector
import env_common as E
from assets import geometry as G


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", default="anvil")
    parser.add_argument("--out", default=str(HERE / "out" / "r2" / "assets"))
    parser.add_argument("--params", default="{}")
    parser.add_argument("--elevation", type=float, default=0.83)
    parser.add_argument("--target", type=float, nargs=3)
    parser.add_argument("--direction", type=float, nargs=3)
    parser.add_argument("--exposure", type=float, default=0)
    parser.add_argument("--view", default="AgX")
    parser.add_argument("--extent", type=float)
    parser.add_argument("--studio-strength", type=float, default=1.0)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    out = Path(args.out).resolve()
    if not out.is_relative_to(HERE / "out"):
        raise ValueError("Asset previews must stay in dice_lookdev/out")
    out.mkdir(parents=True, exist_ok=True)
    scene = E.reset()
    module = importlib.import_module("assets." + args.asset)
    params = json.loads(args.params)
    root = module.build(**params)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    points, triangles = [], 0
    for obj in root.children_recursive:
        if obj.type not in ("MESH", "CURVE") or obj.hide_render:
            continue
        evaluated = obj.evaluated_get(deps)
        me = evaluated.to_mesh()
        me.calc_loop_triangles()
        triangles += len(me.loop_triangles)
        exterior = args.asset == "leaded_window" and obj.name.startswith(("Night backdrop", "Moon", "Town gable silhouette", "Distant lit slit"))
        if not exterior:
            points.extend(obj.matrix_world @ Vector(p) for p in obj.bound_box)
        evaluated.to_mesh_clear()
    lower = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    upper = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = (lower + upper) / 2
    extent = max(upper - lower)
    floor = E.simple("Studio warm grey", (0.12, 0.13, 0.14), 0.83)
    E.plane("Studio floor", extent * 8, extent * 8, (0, 0, lower.z - 0.015), floor)
    E.world(scene, (0.11, 0.12, 0.14), 0.6)
    for name, loc, energy, color, size in (
        ("Softbox", (-extent, -extent, extent * 1.8), extent ** 2 * 38, (1, 0.83, 0.65), extent),
        ("Cool strip", (extent, extent * 0.5, extent), extent ** 2 * 24, (0.57, 0.72, 1), extent * 0.65),
        ("Front fill", (0, -extent * 1.5, extent * 0.4), extent ** 2 * 12, (0.8, 0.88, 1), extent)):
        light = E.light(scene, "AREA", name, loc, energy, color=color, size=size, target=center)
        if args.asset == "leaded_window":
            light.visible_glossy = False
            light.visible_transmission = False
    ruler = G.Asset("10 cm scale bar")
    white = E.simple("Scale divisions", (0.6, 0.6, 0.6), 0.8)
    black = E.simple("Scale dark", (0.015, 0.015, 0.015), 0.8)
    for i in range(10):
        ruler.block("Centimetre", (1, 1, 0.25), (lower.x + i, lower.y - 6, lower.z + 0.15), white if i % 2 else black, 0.04)
    if args.asset == "leaded_window":
        import room_common as RC
        w, h = params.get("width", 75), params.get("height", 115)
        surround = RC.wall_plane("Studio window surround", w * 4, h * 3, ((0, h, w + 24, h + 9),), floor, thickness=2)
        surround.parent = root
        surround.location = (0, 1, -h * 0.5)
        direction = Vector((-0.32, -1.7, 0.18))
    else:
        direction = Vector((-0.95, -1.5, args.elevation))
    if args.target is not None:
        center = Vector(args.target)
    if args.extent is not None:
        extent = args.extent
    for name in ("Softbox", "Cool strip", "Front fill"):
        bpy.data.objects[name].data.energy *= args.studio_strength
    scene.world.node_tree.nodes.get("Background").inputs["Strength"].default_value *= args.studio_strength
    if args.direction is not None:
        direction = Vector(args.direction)
    camera_loc = center + direction * extent
    camera = E.camera(scene, "Studio", camera_loc, center, lens=50)
    E.setup_cycles(scene, samples=32, res=(800, 650), view=args.view, exposure=args.exposure)
    E.render_to(scene, camera, out / f"{args.asset}.png", out / f"{args.asset}.jpg")
    print(f"dice_lookdev: asset {args.asset}: {triangles:,} evaluated triangles, bounds {tuple(round(v, 2) for v in upper-lower)} cm")


if __name__ == "__main__":
    run()
