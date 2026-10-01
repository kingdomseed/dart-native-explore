"""Unlettered folded leather menu or wallet with edge binding and saddle stitches."""
import bpy
from . import geometry as G, materials as M
import env_common as E


def build(name="Leather menu", loc=(0, 0, 0), rot_z=0, width=14, depth=21, thickness=0.9,
          tone=(0.029, 0.008, 0.011), wear=0.6, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    leather = M.leather(f"{name} worn hide", tone, wear, seed)
    edge = M.leather(f"{name} binding", tuple(c * 0.5 for c in tone), wear, seed)
    a.block("Folded leather", (width, depth, thickness), (0, 0, thickness / 2), leather, min(0.3, thickness * 0.3))
    a.block("Inset padded cover", (width - 0.8, depth - 0.8, 0.14), (0, 0, thickness), leather, 0.2)
    thread = E.simple(f"{name} thread", (0.23, 0.12, 0.065), 0.9)
    pts = E.rounded_rect(width - 0.9, depth - 0.9, 0.6, seg=6)
    a.tube("Rolled binding", [(p[0], p[1], thickness * 0.65) for p in pts], 0.065, edge, cyclic=True)
    for side in (-1, 1):
        for i in range(int(depth / 0.55) - 2):
            y = -depth / 2 + 0.65 + i * 0.55
            a.tube("Saddle stitch", [(side * (width / 2 - 0.55), y, thickness + 0.09),
                                     (side * (width / 2 - 0.55), y + 0.27, thickness + 0.09)], 0.022, thread, resolution=0)
    return a.root
