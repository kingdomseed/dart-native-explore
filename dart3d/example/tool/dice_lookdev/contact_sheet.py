"""Contact sheets from the per-theme renders: all-sets-topdown.jpg (primary), all-sets-hero.jpg,
readability-crops.jpg (from the per-set crop strips readability_check leaves in out/crops/).

Blender --background --python contact_sheet.py -- --dir docs/design/dice-lookdev --themes a,b,c
Labels are rendered with Workbench (Inter) and composited with numpy.
"""
from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import build_dice  # noqa: E402
import env_common as E  # noqa: E402

COLS, CW, CH, LAB = 3, 533, 300, 34


def load(path):
    img = bpy.data.images.load(str(path))
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]
    bpy.data.images.remove(img)
    return a


def resize(a, w, h):
    H, W = a.shape[:2]
    # box-filter by averaging the source rows/cols that land in each target pixel
    ys = (np.arange(h + 1) * H / h).astype(int)
    xs = (np.arange(w + 1) * W / w).astype(int)
    c = np.cumsum(np.cumsum(np.pad(a, ((1, 0), (1, 0), (0, 0))), 0), 1)
    tot = c[ys[1:]][:, xs[1:]] - c[ys[:-1]][:, xs[1:]] - c[ys[1:]][:, xs[:-1]] + c[ys[:-1]][:, xs[:-1]]
    area = np.outer(ys[1:] - ys[:-1], xs[1:] - xs[:-1])[:, :, None]
    return tot / area


def labels(texts, sheet_w, sheet_h, positions):
    sc = bpy.data.scenes.new("labels")
    font = bpy.data.fonts.load(str(build_dice.FONTS["sans"]), check_existing=True)
    for (t, sub), (x, y) in zip(texts, positions):
        for body, size, dy in ((t, 17, 0), (sub, 11.5, -1)):
            cu = bpy.data.curves.new("lab", "FONT")
            cu.body = body
            cu.font = font
            cu.size = size
            ob = bpy.data.objects.new("lab", cu)
            ob.location = (x, sheet_h - y - (LAB * 0.62 if dy == 0 else LAB * 0.62), 0)
            if dy:
                ob.location.x += len(t) * 10.5 + 14
            sc.collection.objects.link(ob)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = sheet_w
    cam.location = (sheet_w / 2, sheet_h / 2, 10)
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "SINGLE"
    sc.display.shading.single_color = (1, 1, 1)
    sc.display.render_aa = "16"
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0, 0, 0)
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = sheet_w, sheet_h
    sc.render.image_settings.file_format = "PNG"
    tmp = Path(tempfile.mkdtemp()) / "labels.png"
    sc.render.filepath = str(tmp)
    bpy.ops.render.render(write_still=True, scene=sc.name)
    return load(tmp)[:, :, 0]


def save_jpeg(sheet, path):
    H, W = sheet.shape[:2]
    tmp = Path(tempfile.mkdtemp()) / "sheet.png"
    img = bpy.data.images.new("sheet", W, H, alpha=False)
    px = np.ones((H, W, 4), dtype=np.float32)
    px[:, :, :3] = np.clip(sheet[::-1], 0, 1)
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = str(tmp)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return E.save_jpeg(tmp, path)


def grid(d, themes, suffix, cw, ch, cols, out_name, src=None):
    rows = (len(themes) + cols - 1) // cols
    W, H = cols * cw + 1, rows * (ch + LAB)
    sheet = np.full((H, W, 3), 0.035, dtype=np.float32)
    pos, texts = [], []
    for i, t in enumerate(themes):
        r, c = divmod(i, cols)
        x, y = c * cw, r * (ch + LAB)
        sheet[y:y + ch, x:x + cw - 1] = resize(load((src or d) / f"{t}-{suffix}"), cw - 1, ch)
        pos.append((x + 10, y + ch))
        th = build_dice.THEMES[t]
        texts.append((th["title"], "" if cw < 450 else th.get("env", "")))
    lab = labels(texts, W, H, pos)
    sheet = sheet * (1 - lab[:, :, None]) + lab[:, :, None] * np.array([0.95, 0.9, 0.8])
    size = save_jpeg(sheet, d / out_name)
    print(f"dice_lookdev: {out_name} {size // 1024} KB ({len(themes)} themes)")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--themes", required=True)
    ap.add_argument("--crops", default=str(HERE / "out" / "crops"), help="readability_check crop strips")
    a = ap.parse_args(argv)
    d = Path(a.dir)
    themes = [t for t in a.themes.split(",") if (d / f"{t}-topdown.jpg").exists()]
    # The primary sheet: every set as the phone shows it (straight down).
    grid(d, themes, "topdown.jpg", 360, 780, 6, "all-sets-topdown.jpg")
    heroes = [t for t in themes if (d / f"{t}-hero.jpg").exists()]
    if heroes:
        grid(d, heroes, "hero.jpg", 533, 300, 3, "all-sets-hero.jpg")
    cd = Path(a.crops)
    crops = [t for t in themes if (cd / f"{t}-crops.png").exists()]
    if crops:
        # the seven dice of every set at phone pixels (1:1), one row per set
        grid(d, crops, "crops.png", 1260, 180, 1, "readability-crops.jpg", src=cd)


main()
