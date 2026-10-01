"""Rounded wet laminate counter with chrome bullnose, paneled apron and kick plate."""
import bpy
import math
import random
import env_common as E
from . import geometry as G, materials as M


def build(name="Diner counter", loc=(0, 0, 0), rot_z=0, width=140, depth=60, height=76,
          tone=(0.013, 0.016, 0.021), wood_tone=(0.025, 0.009, 0.009), wear=0.45, seed=1,
          quiet=(0, 0), droplets=170, footrail=True, back_wings=0, back_wing_inset=24,
          puddles=9, streaks=0, drop_radius=(0.055, 0.19)) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    top = M.wet_surface(f"{name} polished laminate", tone, wear, seed, quiet)
    chrome = M.polished_metal(f"{name} edge chrome", wear=wear, seed=seed)
    panel = M.oak(f"{name} dark walnut", wood_tone, wear, seed, axis="Z")
    black = E.simple(f"{name} reveals", (0.005, 0.006, 0.009), 0.7)
    if back_wings:
        outline = [(-width / 2, -depth / 2), (width / 2, -depth / 2),
                   (width / 2, depth / 2 + back_wings), (back_wing_inset, depth / 2 + back_wings),
                   (back_wing_inset, depth / 2), (-back_wing_inset, depth / 2), (-back_wing_inset, depth / 2 + back_wings),
                   (-width / 2, depth / 2 + back_wings)]
        pts = []
        for i, corner in enumerate(outline):
            prev, nex = outline[i - 1], outline[(i + 1) % len(outline)]
            left = math.dist(prev, corner)
            right = math.dist(nex, corner)
            start = tuple(c + (p - c) * 1.6 / left for c, p in zip(corner, prev))
            end = tuple(c + (n - c) * 1.6 / right for c, n in zip(corner, nex))
            for j in range(7):
                t = j / 6
                pts.append(tuple((1 - t) ** 2 * u + 2 * (1 - t) * t * c + t * t * v for u, c, v in zip(start, corner, end)))
        count = len(pts)
        verts = [(x, y, z) for z in (height - 3.6, height) for x, y in pts]
        faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
        faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
        a.mesh("Continuous shaped countertop", verts, faces, top, bevel=0.35)
        wing_w = width / 2 - back_wing_inset - 4
        for side in (-1, 1):
            a.block("Wing cabinet", (wing_w, back_wings, height - 5),
                    (side * (back_wing_inset + 2 + wing_w / 2), depth / 2 - 4 + back_wings / 2, (height - 5) / 2), panel, 0.8)
    else:
        a.block("Countertop", (width, depth, 3.6), (0, 0, height - 1.8), top, 1.25)
        pts = E.rounded_rect(width, depth, 2, seg=10)
    for z, r in ((height - 1.3, 0.55), (height - 2.6, 0.26)):
        a.tube("Continuous chrome bullnose", [(p[0], p[1], z) for p in pts], r, chrome, cyclic=True)
    a.block("Counter base", (width - 8, depth - 8, height - 5), (0, 0, (height - 5) / 2), black, 0.8)
    count = max(2, int(width / 24))
    for side in (-1, 1):
        for i in range(count):
            x = -width / 2 + 5 + (i + 0.5) * (width - 10) / count
            a.block("Recessed walnut panel", ((width - 10) / count - 1.4, 0.8, height - 23),
                    (x, side * (depth / 2 - 3.6), height * 0.51), panel, 0.35)
        a.block("Chrome kick plate", (width - 8, 0.7, 12), (0, side * (depth / 2 - 3.2), 8), chrome, 0.4)
        if footrail:
            a.tube("Foot rail", [(-width / 2 + 7, side * (depth / 2 + 8), 17), (width / 2 - 7, side * (depth / 2 + 8), 17)], 1.1, chrome)
            for x in (-width / 2 + 11, width / 2 - 11):
                a.beam("Rail bracket", (x, side * (depth / 2 - 2), 9), (x, side * (depth / 2 + 8), 17), 1.4, 1.4, chrome, 0.4)
    water = M.clear_glass(f"{name} water beads", 0.035, 1.333)
    rng = random.Random(seed)
    for i in range(droplets):
        x, y = rng.uniform(-width / 2 + 2, width / 2 - 2), rng.uniform(-depth / 2 + 2, depth / 2 + back_wings - 2)
        if back_wings and abs(x) < back_wing_inset + 1 and y > depth / 2 - 1: continue
        if abs(x) < quiet[0] and abs(y) < quiet[1]: continue
        r = rng.uniform(*drop_radius)
        a.sphere("Counter water bead", r, (x, y, height + r * 0.2), water, scale=(1.25, 1, 0.4), subdiv=2)
    for i in range(puddles + streaks):
        rx, ry = rng.uniform(1.2, 3.5), rng.uniform(0.7, 1.9)
        if i >= puddles:
            rx, ry = rng.uniform(0.12, 0.3), rng.uniform(1.1, 2.8)
        for attempt in range(40):
            x, y = rng.uniform(-width / 2 + rx + 2, width / 2 - rx - 2), rng.uniform(-depth / 2 + ry + 2, depth / 2 - ry - 2)
            if abs(x) > quiet[0] + rx * 1.12 or abs(y) > quiet[1] + ry:
                break
        else:
            continue
        verts = [(x, y, height + 0.025)]
        verts += [(x + rx * math.cos(t) * (1 + 0.12 * math.sin(t * 5)), y + ry * math.sin(t), height + 0.02)
                  for t in [i * math.tau / 40 for i in range(40)]]
        a.mesh("Small spilled puddle", verts, [(0, i + 1, (i + 1) % 40 + 1) for i in range(40)], water, smooth=True)
    return a.root
