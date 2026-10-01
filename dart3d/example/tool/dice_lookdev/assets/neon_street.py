"""Layered street geometry: illuminated façades, abstract signs, parked cars and wet asphalt."""
import bpy
import math
import random
from mathutils import Quaternion, Vector
import env_common as E
from . import geometry as G, materials as M
from . import neon_sign, street_car


def build(name="Night street", loc=(0, 0, 0), rot_z=0, width=1300, depth=1100,
          wear=0.6, seed=1, cars=True, exterior_slope=0) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    asphalt = M.wet_asphalt(f"{name} wet road", seed=seed)
    a.block("Wet roadway", (width, depth, 5), (0, depth / 2, -2.5), asphalt, 0.4)
    stone = M.stone(f"{name} curb stone", (0.047, 0.052, 0.063), wear, seed)
    brick = M.stone(f"{name} dark concrete", (0.033, 0.039, 0.052), wear, seed)
    trim = M.stone(f"{name} facade trim", (0.061, 0.07, 0.085), wear, seed)
    steel = M.polished_metal(f"{name} steel", (0.033, 0.04, 0.052), wear, seed, roughness=0.32)
    frame = E.simple(f"{name} window frames", (0.008, 0.012, 0.02), 0.42, 0.7)
    panes = [E.emissive(f"{name} lit window {i}", col, power) for i, (col, power) in enumerate(
        (((0.38, 0.67, 1), 1.6), ((1, 0.63, 0.29), 1.6), ((0.05, 0.17, 0.27), 0.5), ((0.008, 0.015, 0.022), 0.2)))]
    curb_y = depth * 470 / 1100
    front_y = depth * 570 / 1100
    a.block("Far sidewalk", (width, front_y - curb_y + 5, 15), (0, (curb_y + front_y) / 2, 7.5), stone, 1)
    for x in range(-int(width / 2), int(width / 2), 55):
        a.block("Curb block", (54, 14, 18), (x + 27, curb_y, 9), stone, 0.8)
    for layer, y in enumerate((front_y, depth * 830 / 1100)):
        for i in range(5):
            w = rng.uniform(195, 255)
            x = (i - 2) * 260 + (layer * 77)
            h = rng.uniform(620, 920) + layer * 140
            a.block("City building", (w, 170, h), (x, y + 85, h / 2 + 15), brick, 2)
            for side in (-1, 1):
                a.block("Facade corner pier", (8, 12, h), (x + side * (w / 2 - 7), y - 4, h / 2 + 15), trim, 0.8)
            for z in range(190, int(h), 105):
                a.block("Stone floor cornice", (w + 8, 8, 6), (x, y - 2, z), stone, 0.5)
                for col in range(4):
                    xx = x + (col - 1.5) * w * 0.22
                    a.block("Window recess", (w * 0.17 + 4, 3, 70), (xx, y - 5, z + 43), frame, 0.4)
                    a.block("Lit city window", (w * 0.17, 0.5, 65), (xx, y - 7, z + 43), rng.choices(panes, weights=(2, 2, 2, 6), k=1)[0], 0.1)
                    a.block("City window mullion", (1.7, 1, 65), (xx, y - 8, z + 43), frame, 0.1)
            a.block("Storefront surround", (w - 20, 8, 150), (x, y - 2, 91), steel, 1)
            for col in range(12):
                for row in range(8):
                    xx, zz = x + (col - 5.5) * w * 0.074, 23 + row * 17
                    a.block("Storefront window grid", (w * 0.065, 1, 13.5), (xx, y - 7, zz),
                            rng.choices(panes, weights=(1, 1, 2, 6), k=1)[0], 0)
            a.tube("Downpipe", [(x + w * 0.45, y - 9, 18), (x + w * 0.45, y - 9, h - 6)], 2.4, steel)
    specs = [(-370, front_y - 12, 105, 80, 220, "bars", (0.01, 0.64, 1)),
             (-120, front_y - 23, 80, 65, 210, "chevrons", (1, 0.008, 0.27)),
             (175, front_y - 30, 125, 75, 210, "rings", (0.005, 0.6, 1)),
             (430, front_y - 12, 70, 70, 190, "bars", (1, 0.045, 0.32))]
    for i, (x, y, z, w, h, design, color) in enumerate(specs):
        a.add(neon_sign.build(f"{name} sign {i}", loc=(x, y, z), width=w, height=h, design=design, color=color,
                             strength=5, seed=seed + i, backing=design != "planet"))
        for side in (-1, 1):
            for level in (0.2, 0.8):
                a.beam("Sign wall bracket", (x + side * w * 0.35, y + 4, z + h * level),
                       (x + side * w * 0.35, front_y + 1, z + h * level), 2.5, 2.5, steel, 0.3)
        a.light("Neon spill on street", (x, y - 35, z + h * 0.35), 420000, color, 75,
                target=(x, y - 150, 0), kind="AREA")
        a.light("Sign reflected on masonry", (x, y - 60, z + h * 0.5), 120000, color, 55,
                target=(x, front_y, z + h * 0.3), kind="AREA")
    lamp = E.emissive(f"{name} street lamps", (1, 0.63, 0.25), 7)
    for x in (-460, -185, 240, 520):
        y = curb_y - 25
        a.lathe("Streetlamp foot", [(0, 0), (10, 0), (11, 6), (7, 14), (4, 20)], steel, loc=(x, y, 0))
        a.tube("Streetlight bent pole", [(x, y, 20), (x, y, 220), (x, y - 12, 237), (x, y - 43, 240)], 3.2, steel)
        a.sphere("Street lamp shade", 17, (x, y - 44, 236), steel, scale=(1, 1.5, 0.3))
        a.sphere("Street lamp diffuser", 12, (x, y - 46, 231), lamp, scale=(1, 1.4, 0.2))
        a.light("Streetlamp road pool", (x, y - 45, 226), 360000, (1, 0.6, 0.25), 16,
                target=(x, y - 80, 0), kind="AREA")
    if cars:
        a.add(street_car.build(f"{name} burgundy car", loc=(-135, depth * 0.245, 0), rot_z=-1.4, length=370, width=160, height=110,
                              tone=(0.055, 0.008, 0.018), seed=seed))
        a.add(street_car.build(f"{name} blue car", loc=(135, depth * 0.245, 0), rot_z=1.4, length=350, width=158, height=110,
                              tone=(0.025, 0.065, 0.12), seed=seed + 1))
    paint = E.simple(f"{name} road marks", (0.27, 0.24, 0.16), 0.33, Coat_Weight=0.7)
    for x in range(-550, 551, 160):
        a.block("Wet road dash", (80, 4, 0.03), (x, depth * 160 / 1100, 0.03), paint, 0.1)
    a.light("Blue city ambience", (0, front_y - 30, 580), 900000, (0.12, 0.27, 0.55), 500,
            target=(0, curb_y - 130, 0), kind="AREA")
    if exterior_slope:
        for ob in a.root.children:
            if ob.type == "EMPTY" and ob.name.endswith(" car"):
                rotation = ob.rotation_euler.to_quaternion()
                ob.rotation_mode = "QUATERNION"
                ob.rotation_quaternion = Quaternion(Vector((1, 0, 0)), -math.atan(exterior_slope)) @ rotation
            if ob.type == "CURVE":
                for spline in ob.data.splines:
                    for p in spline.points:
                        p.co.z -= exterior_slope * p.co.y
            elif ob.type == "MESH" and ob.name.startswith(("Wet roadway", "Far sidewalk", "Curb block", "Wet road dash")):
                for v in ob.data.vertices:
                    v.co.z -= exterior_slope * v.co.y
            ob.location.z -= exterior_slope * ob.location.y
    return a.root
