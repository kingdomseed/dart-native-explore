"""Dice readability gate: measure the top-down in-app view of a set.

Runs inside Blender. Two ways in:

  # render the phone view of one set and measure it (merges into readability.json)
  Blender --background --python readability_check.py -- --theme arcane [--samples 64]

  # print the markdown table for every measured set
  Blender --background --python readability_check.py -- --table docs/design/dice-lookdev/readability.json

How it measures (per die, on its TOP face only)
  1. The beauty frame is rendered by render_set.py (topdown shot: 1179 x 2556,
     straight down, the app's fov) and kept as a lossless PNG.
  2. A mask pass re-renders the same camera with every die's material swapped
     for an emission-only mask: R = numeral (atlas R), G = "top face" (true
     normal within ~14 deg of +Z), B = die id. Everything else is hidden, 1
     sample, no pixel filter, written as EXR, so the masks are exact.
  3. From the beauty PNG (display-referred sRGB, what the phone shows), WCAG
     relative luminance: numeral = median over the numeral (eroded 1 px);
     surround = median over the top face in a ring 1..1+r px outside the
     numeral (r = max(2, 8% of the numeral's pixel height)).
     contrast = (Lhi + 0.05) / (Llo + 0.05)  -> gate: >= 4.5 on every die.
     "body" = the rest of the top face (informational: the ring is where a
     keyline or halo lives; the body shows how the plain face reads).
  4. Die vs tray: the die against a 3..12 px ring of tray around it (contact
     shadow included, other dice excluded), taking the best of three readings:
     its median body tone, its mean (which counts glowing numerals and metal
     edges) and its outline (median of the die's outer 2 px band, for
     rim-lit or neon-edged dice)
     -> gate: >= 2.0 (silhouette separation; WCAG's non-text 3:1 is reported).
  5. Numeral size: numeral height / face inscribed width, from the atlas, worst
     face of each die -> gate: >= 0.40. Also the top numeral's height in px.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import build_dice  # noqa: E402

ORDER = ("emberforged", "frostbound", "arcane", "fateengine", "celestial", "hearthside", "oldroad", "northfield",
         "voltline", "vermilion", "gemcutter")
GATE_NUMERAL = 4.5
GATE_SILHOUETTE = 2.0
GATE_SIZE = 0.40
TOP_COS = 0.97  # true normal . +Z


# --------------------------------------------------------------------------
# Image helpers (numpy only)
# --------------------------------------------------------------------------

def load_rgb(path):
    img = bpy.data.images.load(str(path))
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]
    is_float = img.is_float
    bpy.data.images.remove(img)
    return a, is_float


def luminance_srgb(rgb):
    """WCAG relative luminance of display sRGB values in 0..1."""
    c = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def dilate(m, r):
    out = m.copy()
    for _ in range(r):
        o = out.copy()
        o[1:] |= out[:-1]
        o[:-1] |= out[1:]
        o[:, 1:] |= out[:, :-1]
        o[:, :-1] |= out[:, 1:]
        out = o
    return out


def erode(m, r):
    return ~dilate(~m, r)


def ratio(a, b):
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


# --------------------------------------------------------------------------
# Mask pass
# --------------------------------------------------------------------------

def mask_material(atlas_img, die_id):
    m = bpy.data.materials.new(f"readability_mask_{die_id}")
    k = build_dice.NodeKit(m)
    tex = k.node("ShaderNodeTexImage", image=atlas_img, interpolation="Closest")
    sep = k.node("ShaderNodeSeparateColor")
    k.link(tex.outputs["Color"], sep.inputs["Color"])
    geo = k.node("ShaderNodeNewGeometry")
    nz = k.node("ShaderNodeSeparateXYZ")
    k.link(geo.outputs["True Normal"], nz.inputs[0])
    top = k.math("GREATER_THAN", nz.outputs["Z"], TOP_COS)
    num = k.math("MULTIPLY", k.math("GREATER_THAN", sep.outputs["Red"], 0.5), top)
    comb = k.node("ShaderNodeCombineColor")
    k.link(num, comb.inputs[0])
    k.link(top, comb.inputs[1])
    comb.inputs[2].default_value = (die_id + 1) / 10.0
    k.surface(k.emission(comb.outputs[0], 1.0))
    return m


def render_masks(scene, cam, objs, atlas_img, tmp):
    """Exact per-pixel masks (numeral, top face, die id) for the current camera."""
    saved_hide = {ob.name: ob.hide_render for ob in scene.objects}
    saved_mats = {kind: list(ob.data.materials) for kind, ob in objs.items()}
    c, r, v = scene.cycles, scene.render, scene.view_settings
    saved = dict(samples=c.samples, adaptive=c.use_adaptive_sampling, denoise=c.use_denoising,
                 filter=c.filter_width, world=scene.world, fmt=r.image_settings.file_format,
                 depth=r.image_settings.color_depth, view=v.view_transform, look=v.look, exp=v.exposure,
                 dof=cam.data.dof.use_dof, mb=r.use_motion_blur, path=r.filepath)
    dice = set(objs.values())
    for ob in scene.objects:
        if ob not in dice and ob.type != "CAMERA":
            ob.hide_render = True
    for i, (kind, ob) in enumerate(objs.items()):
        ob.data.materials.clear()
        ob.data.materials.append(mask_material(atlas_img, build_dice.KINDS.index(kind)))
    w = bpy.data.worlds.new("mask_world")
    w.color = (0, 0, 0)
    scene.world = w
    c.samples, c.use_adaptive_sampling, c.use_denoising, c.filter_width = 1, False, False, 0.01
    v.view_transform, v.exposure = "Standard", 0.0
    cam.data.dof.use_dof = False
    r.use_motion_blur = False
    r.image_settings.file_format = "OPEN_EXR"
    r.image_settings.color_depth = "32"
    scene.camera = cam
    path = Path(tmp) / "readability_mask.exr"
    r.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    # restore
    for ob in scene.objects:
        if ob.name in saved_hide:
            ob.hide_render = saved_hide[ob.name]
    for kind, ob in objs.items():
        ob.data.materials.clear()
        for m in saved_mats[kind]:
            ob.data.materials.append(m)
    c.samples, c.use_adaptive_sampling = saved["samples"], saved["adaptive"]
    c.use_denoising, c.filter_width = saved["denoise"], saved["filter"]
    scene.world = saved["world"]
    r.image_settings.file_format, r.image_settings.color_depth = saved["fmt"], saved["depth"]
    v.view_transform, v.exposure = saved["view"], saved["exp"]
    if saved["look"]:
        v.look = saved["look"]
    cam.data.dof.use_dof, r.use_motion_blur, r.filepath = saved["dof"], saved["mb"], saved["path"]
    a, _ = load_rgb(path)
    return a


# --------------------------------------------------------------------------
# Measurement
# --------------------------------------------------------------------------

def measure(scene, cam, objs, specs, beauty_png, theme, tmp, crops_dir=None):
    atlas_img = next(im for im in bpy.data.images if im.name.startswith(f"{theme}_atlas"))
    masks = render_masks(scene, cam, objs, atlas_img, tmp)
    beauty, _ = load_rgb(beauty_png)
    if beauty.shape[:2] != masks.shape[:2]:
        raise RuntimeError(f"beauty {beauty.shape} vs mask {masks.shape}: render both at the same size")
    L = luminance_srgb(np.clip(beauty, 0, 1))
    ids = np.round(masks[..., 2] * 10.0).astype(int) - 1  # -1 = background
    any_die = ids >= 0
    dice = {}
    crops = []
    for kind in objs:
        i = build_dice.KINDS.index(kind)
        die = ids == i
        if not die.any():
            dice[kind] = {"visible": False}
            continue
        ys, xs = np.nonzero(die)
        y0, y1 = max(0, ys.min() - 16), min(die.shape[0], ys.max() + 17)
        x0, x1 = max(0, xs.min() - 16), min(die.shape[1], xs.max() + 17)
        sl = (slice(y0, y1), slice(x0, x1))
        d, Lc = die[sl], L[sl]
        top = d & (masks[sl][..., 1] > 0.5)
        num = top & (masks[sl][..., 0] > 0.5)
        res = {"visible": True}
        if num.any():
            nys = np.nonzero(num)[0]
            h_px = int(nys.max() - nys.min() + 1)
            ring_r = max(2, int(round(0.08 * h_px)))
            core = erode(num, 1)
            if core.sum() < 6:
                core = num
            near = dilate(num, 1)
            surround = top & ~near & dilate(num, 1 + ring_r)
            body = top & ~dilate(num, 1 + ring_r)
            ln = float(np.median(Lc[core]))
            ls = float(np.median(Lc[surround])) if surround.any() else float("nan")
            lb = float(np.median(Lc[body])) if body.any() else float("nan")
            res.update(numeral_px=h_px, L_numeral=round(ln, 4), L_surround=round(ls, 4), L_body=round(lb, 4),
                       contrast=round(ratio(ln, ls), 2), contrast_body=round(ratio(ln, lb), 2),
                       numeral_brighter=ln > ls)
        else:
            res.update(numeral_px=0, contrast=0.0, contrast_body=0.0)
        sil = erode(d, 2)
        ring = dilate(d, 12) & ~dilate(d, 3) & ~dilate(any_die[sl], 3)
        if sil.any() and ring.any():
            # Two readings of "the die stands out from the tray": its dominant
            # body tone (median) or its overall brightness (mean, where glowing
            # numerals and metal edges count, as they do for the eye). The gate
            # takes the better of the two; both are recorded.
            med = ratio(float(np.median(Lc[sil])), float(np.median(Lc[ring])))
            mean = ratio(float(Lc[sil].mean()), float(Lc[ring].mean()))
            # A third reading for rim-lit / neon-edged dice: the die's outer
            # band (its first 2 px) against the tray ring, i.e. the outline
            # the eye tracks.
            band = d & ~erode(d, 2)
            outline = ratio(float(np.median(Lc[band])), float(np.median(Lc[ring])))
            res["contrast_silhouette_median"] = round(med, 2)
            res["contrast_silhouette_mean"] = round(mean, 2)
            res["contrast_silhouette_outline"] = round(outline, 2)
            res["contrast_silhouette"] = round(max(med, mean, outline), 2)
            res["L_die_median"] = round(float(np.median(Lc[sil])), 4)
            res["L_tray_median"] = round(float(np.median(Lc[ring])), 4)
        else:
            res["contrast_silhouette"] = float("nan")
        res["pass"] = bool(res["contrast"] >= GATE_NUMERAL and res["contrast_silhouette"] >= GATE_SILHOUETTE
                           and specs[kind]["numeral_ratio_min"] >= GATE_SIZE)
        dice[kind] = res
        crops.append((kind, beauty[sl]))
    out = {"dice": dice,
           "min_contrast": min(v.get("contrast", 0) for v in dice.values()),
           "min_contrast_silhouette": min(v.get("contrast_silhouette", 0) for v in dice.values()),
           "min_numeral_px": min(v.get("numeral_px", 0) for v in dice.values()),
           "min_numeral_ratio": round(min(specs[k]["numeral_ratio_min"] for k in objs), 3)}
    out["pass"] = all(v.get("pass") for v in dice.values())
    if crops_dir:
        Path(crops_dir).mkdir(parents=True, exist_ok=True)
        save_crops(crops, Path(crops_dir) / f"{theme}-crops.png")
    return out


def save_crops(crops, path, cell=180):
    """One strip of the dice as the phone shows them (1:1 px, centred in cells)."""
    strip = np.zeros((cell, cell * len(crops), 3), dtype=np.float32)
    for j, (_k, c) in enumerate(crops):
        h, w = c.shape[:2]
        h2, w2 = min(h, cell), min(w, cell)
        cy, cx = (h - h2) // 2, (w - w2) // 2
        oy, ox = (cell - h2) // 2, j * cell + (cell - w2) // 2
        strip[oy:oy + h2, ox:ox + w2] = c[cy:cy + h2, cx:cx + w2]
    img = bpy.data.images.new("crops", strip.shape[1], cell, alpha=False)
    px = np.ones((cell, strip.shape[1], 4), dtype=np.float32)
    px[..., :3] = strip[::-1]
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def merge(json_path, theme, res):
    p = Path(json_path)
    data = json.loads(p.read_text()) if p.exists() else {}
    data[theme] = res
    p.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n")


def print_row(theme, res):
    worst = min(res["dice"].items(), key=lambda kv: kv[1].get("contrast", 0))
    print(f"dice_lookdev: readability {theme}: numeral min {res['min_contrast']:.2f} ({worst[0]}), "
          f"silhouette min {res['min_contrast_silhouette']:.2f}, numeral >= {res['min_numeral_px']} px, "
          f"size {res['min_numeral_ratio']:.2f} -> {'PASS' if res['pass'] else 'FAIL'}", flush=True)
    for k, v in res["dice"].items():
        print(f"dice_lookdev:   {k:5s} numeral {v.get('contrast', 0):5.2f} (body {v.get('contrast_body', 0):5.2f})"
              f" sil {v.get('contrast_silhouette', 0):5.2f} {v.get('numeral_px', 0):3d}px", flush=True)


def table(json_path, order=None):
    data = json.loads(Path(json_path).read_text())
    order = [t for t in (order or ORDER) if t in data]
    lines = ["| Set | Numeral treatment | Numeral contrast, worst die (gate 4.5) | vs plain body | "
             "Die vs tray, worst (gate 2.0) | Top numeral height | Numeral / face width (gate 0.40) | Result |",
             "|---|---|---|---|---|---|---|---|"]
    for t in order:
        r = data[t]
        worst = min(r["dice"].items(), key=lambda kv: kv[1].get("contrast", 0))
        body = min(v.get("contrast_body", 0) for v in r["dice"].values())
        lines.append(f"| {build_dice.THEMES[t]['title']} | {build_dice.THEMES[t].get('treatment', '')} | "
                     f"{r['min_contrast']:.1f}:1 ({worst[0]}) | {body:.1f}:1 | "
                     f"{r['min_contrast_silhouette']:.1f}:1 | {r['min_numeral_px']} px | "
                     f"{r['min_numeral_ratio']:.2f} | {'PASS' if r['pass'] else 'FAIL'} |")
    return "\n".join(lines)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if argv[:1] == ["--table"]:
        print(table(argv[1]))
        return
    import render_set
    sys.argv = [sys.argv[0], "--"] + argv + ["--shots", "topdown", "--check"]
    render_set.run(render_set.args())


if __name__ == "__main__":
    main()
