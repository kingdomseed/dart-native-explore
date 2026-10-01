"""Twin-group chrome espresso machine with boiler crown, gauges, portafilters and drip grille."""
import bpy
import math
import env_common as E
from . import geometry as G, materials as M
from . import coffee_mug


def build(name="Espresso machine", loc=(0, 0, 0), rot_z=0, width=65, depth=40, height=46,
          tone=(0.035, 0.012, 0.016), wear=0.35, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    chrome = M.polished_metal(f"{name} steel", wear=wear, seed=seed)
    paint = M.ceramic(f"{name} enamel", tone, wear, seed)
    black = E.simple(f"{name} bakelite", (0.008, 0.009, 0.011), 0.3)
    outline = [(-width / 2, 8), (width / 2, 8), (width / 2, height - 10)]
    outline += [(width / 2 * math.cos(t), height - 10 + 10 * math.sin(t)) for t in [math.pi * i / 32 for i in range(1, 33)]]
    a.extrude("Rounded boiler housing", outline, depth * 0.66, paint, y=depth * 0.17, bevel=1.3)
    a.block("Drip tray pan", (width + 2, depth, 3), (0, 0, 5), chrome, 1)
    a.block("Drip tray well", (width - 4, depth * 0.47, 0.5), (0, -depth * 0.22, 6.6), black, 0.4)
    for i in range(28):
        x = -width * 0.45 + i * width * 0.9 / 27
        a.beam("Drain grille", (x, -depth * 0.44, 7), (x, -depth * 0.02, 7), 0.6, 0.5, chrome, 0.15)
    a.block("Control fascia", (width - 3, 1, height * 0.25), (0, -depth * 0.17, height * 0.69), chrome, 0.5)
    for x in (-width * 0.22, width * 0.22):
        a.lathe("Group head", [(0, 0), (5, 0), (5.6, 2), (4.6, 4), (4.2, 8)], chrome, loc=(x, -depth * 0.19, height * 0.38))
        a.tube("Portafilter handle", [(x, -depth * 0.19, height * 0.4), (x, -depth * 0.58, height * 0.38)], 1.2, black)
        a.tube("Twin coffee spout", [(x - 2, -depth * 0.2, height * 0.38), (x - 2, -depth * 0.2, height * 0.32),
                                     (x + 2, -depth * 0.2, height * 0.32), (x + 2, -depth * 0.2, height * 0.38)], 0.4, chrome)
        for i in range(3): a.sphere("Control pushbutton", 0.9, (x + (i - 1) * 3, -depth * 0.195, height * 0.71), black, scale=(1, 0.35, 1))
    gauge = E.simple(f"{name} ivory gauge", (0.62, 0.57, 0.45), 0.6)
    a.ring("Pressure gauge bezel", 3.5, 0.45, (0, -depth * 0.2, height * 0.72), chrome, plane="XZ")
    ob = a.cylinder("Gauge face", 3.3, 0.3, (0, -depth * 0.2, height * 0.72), gauge)
    ob.rotation_euler.x = math.pi / 2
    a.tube("Gauge pointer", [(0, -depth * 0.208, height * 0.72), (1.5, -depth * 0.208, height * 0.76)], 0.1, black)
    for side in (-1, 1):
        a.tube("Steam wand", [(side * width * 0.43, -depth * 0.18, height * 0.68),
                              (side * width * 0.53, -depth * 0.34, height * 0.6),
                              (side * width * 0.52, -depth * 0.42, height * 0.24)], 0.5, chrome)
        a.sphere("Steam valve", 2.2, (side * width * 0.43, -depth * 0.23, height * 0.75), black)
    for x in (-width * 0.39, width * 0.39):
        for y in (-depth * 0.33, depth * 0.33): a.cylinder("Machine foot", 2.3, 4, (x, y, 2), black)
    for x in (-12, 1, 14):
        cup = coffee_mug.build(f"{name} warming cup", loc=(x, 7, height - 10 + 10 * math.sqrt(1 - (x / (width / 2)) ** 2) + 0.01), height=5.5, radius=2.6, steam_height=0, seed=seed)
        a.add(cup)
    for x in (-width * 0.4, width * 0.4):
        crown = height - 10 + 10 * math.sqrt(1 - (x / (width / 2)) ** 2)
        for y in (0, depth * 0.4):
            a.cylinder("Cup rail standoff", 0.55, height + 1 - crown, (x, y, (height + 1 + crown) / 2), chrome)
    a.tube("Cup rail", [(-width * 0.4, 0, height + 1), (-width * 0.4, depth * 0.4, height + 1),
                        (width * 0.4, depth * 0.4, height + 1), (width * 0.4, 0, height + 1)], 0.45, chrome)
    return a.root
