"""Wet avenue with articulated facades, curbside cars and lights at several depths."""
import math
import random

import bpy
from mathutils import Quaternion, Vector
import env_common as E
from . import geometry as G, materials as M, neon_sign, street_car


def _building(name, loc, rotation, width, depth, height, seed, style):
    a = G.Asset(name, loc, rotation)
    rng = random.Random(seed)
    tones = ((0.055, 0.045, 0.042), (0.038, 0.05, 0.06), (0.07, 0.065, 0.053))
    wall = M.stone(name + " masonry", tones[style % 3], 0.45, seed)
    trim = M.stone(name + " coping", (0.085, 0.08, 0.068), 0.35, seed)
    iron = M.polished_metal(name + " frames", (0.035, 0.043, 0.05), 0.5, seed, roughness=0.32)
    dark = E.simple(name + " unlit glazing", (0.006, 0.009, 0.014), 0.19, metal=0.12, Coat_Weight=0.8)
    warm = E.emissive(name + " occupied warm rooms", (1, 0.56, 0.23), 1.35)
    cool = E.emissive(name + " occupied cool rooms", (0.26, 0.56, 0.8), 0.85)
    a.block("Building mass", (width, depth, height), (0, depth / 2, height / 2), wall, 2)
    a.block("Roof coping", (width + 8, depth + 6, 10), (0, depth / 2, height), trim, 0.8)
    for x in (-width / 2 + 7, width / 2 - 7):
        a.block("Masonry pier", (12, 12, height), (x, -3, height / 2), trim, 0.6)
    columns = 3 + style % 3
    spacing = (width - 38) / columns
    window_w = spacing * (0.60 if style % 2 else 0.72)
    floor_h = 112 + style % 3 * 14
    for row, z in enumerate(range(190, int(height) - 60, floor_h)):
        a.block("Projecting floor cornice", (width + 5, 15, 5), (0, -3, z - 16), trim, 0.4)
        lit_floor = rng.random() < 0.62
        for col in range(columns):
            x = (col - (columns - 1) / 2) * spacing
            lit = lit_floor and rng.random() < 0.29
            pane = rng.choice((warm, warm, cool)) if lit else dark
            window_h = 68 + (style % 2) * 16
            a.block("Recessed window surround", (window_w + 6, 4, window_h + 6), (x, -5, z + 35), iron, 0.25)
            a.block("Window pane", (window_w, 0.35, window_h), (x, -7.2, z + 35), pane, 0)
            a.block("Window sill", (window_w + 10, 11, 4), (x, -7, z + 33 - window_h / 2), trim, 0.3)
            if style % 2:
                a.block("Window transom", (window_w, 1, 1.8), (x, -8, z + 46), iron, 0.1)
            if lit:
                a.block("Curtain edge", (window_w * 0.16, 0.5, window_h), (x - window_w * 0.38, -7.8, z + 35), dark, 0)
    for x in (-width * 0.29, width * 0.03, width * 0.33):
        w = width * 0.26
        a.block("Storefront framing", (w + 5, 5, 146), (x, -4, 77), iron, 0.4)
        a.block("Shopfront glazing", (w, 0.5, 132), (x, -7, 78), dark, 0)
        a.block("Shopfront transom", (w, 1, 3), (x, -8, 112), iron, 0.2)
    a.beam("Door pull", (width * 0.12, -10, 61), (width * 0.12, -10, 85), 1.2, 1.2, iron, 0.3)
    a.block("Shop canopy", (width - 12, 36, 7), (0, -17, 155), iron, 1.2)
    a.tube("Drain pipe", [(width * 0.43, -10, 0), (width * 0.43, -10, height - 10)], 2, iron)
    return a.root


def build(name="Night street", loc=(0, 0, 0), rot_z=0, width=1400, depth=1700,
          wear=0.6, seed=1, cars=True, exterior_slope=0, falling_rain=90, lead_in=0) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    road_w = width * 0.44
    asphalt = M.wet_asphalt(name + " wet asphalt", seed)
    stone = M.stone(name + " curb", (0.062, 0.065, 0.071), wear, seed)
    iron = M.polished_metal(name + " fixtures", (0.06, 0.067, 0.073), wear, seed, roughness=0.25)
    a.block("Wet roadway", (road_w, depth + lead_in, 5), (0, (depth - lead_in) / 2, -2.5), asphalt, 0.2)
    for side in (-1, 1):
        a.block("Sidewalk", (104, depth + lead_in, 15), (side * (road_w / 2 + 52), (depth - lead_in) / 2, 7.5), stone, 0.4)
        for y in range(int(26 - lead_in), int(depth), 52):
            a.block("Rounded kerb stone", (13, 51, 19), (side * (road_w / 2 + 3), y, 9.5), stone, 0.7)
    near_end = None
    for side in (-1, 1):
        for i, fraction in enumerate((0.28, 0.55, 0.82)):
            y = depth * fraction
            front_x = side * (road_w / 2 + 104)
            building_width = 320 + rng.uniform(-35, 45)
            a.add(_building(f"{name} side building {side}-{i}", (front_x, y, 15), -side * math.pi / 2,
                            building_width, 230, rng.uniform(650, 980), seed + i + (side + 1) * 5, i + side + 1))
            if side == 1 and i == 0:
                near_end = y - building_width / 2
    for i, x in enumerate((-420, 0, 420)):
        a.add(_building(f"{name} far building {i}", (x, depth + 80, 15), 0,
                        380, 260, 900 + i * 130, seed + 30 + i, i + 1))
    a.add(neon_sign.build(name + " corner planet", loc=(road_w/2+215, near_end-3, 25),
                          width=180, height=160, design="planet", strength=6, backing=False, seed=seed+60))
    signs = [(-road_w / 2 - 82, depth * 0.28, 210, math.pi / 2, "chevrons", (1, 0.012, 0.26)),
             (road_w / 2 + 82, depth * 0.4, 215, -math.pi / 2, "bars", (0.015, 0.62, 1)),
             (road_w / 2 + 82, depth * 0.71, 190, -math.pi / 2, "rings", (1, 0.025, 0.35)),
             (70, depth + 65, 170, 0, "bars", (0.015, 0.6, 1))]
    for i, (x, y, z, angle, design, color) in enumerate(signs):
        sign = neon_sign.build(f"{name} facade neon {i}", loc=(x, y, z), rot_z=angle,
                               width=70, height=180, design=design, color=color, strength=7, seed=seed + i)
        a.add(sign)
        sign_axis = Vector((-math.sin(angle), math.cos(angle), 0))
        for xx in (-24, 24):
            for zz in (25, 150):
                start = Vector((x, y, z + zz)) + Vector((math.cos(angle), math.sin(angle), 0)) * xx + sign_axis * 4
                a.beam("Neon wall bracket", start, start + sign_axis * 25, 3, 3, iron, 0.4)
        lamp = a.light("Neon spill on street", (x * 0.84, y - 35, z + 80), 360000, color, 75,
                       target=(x * 0.4, y - 150, 0), kind="AREA")
        lamp.visible_glossy = True
        lamp.data.specular_factor = 1
        lamp.data.shape = "RECTANGLE"
        lamp.data.size_y = 18
    glow = E.emissive(name + " sodium lamps", (1, 0.66, 0.3), 12)
    lamp_positions = []
    for i, (side, f) in enumerate(((-1, 0.22), (1, 0.36), (-1, 0.63), (1, 0.81))):
        x, y = side * (road_w / 2 - 8), depth * f
        h = 230 + i * 10
        lamp_positions.append((x, y, h))
        a.lathe("Streetlamp foot", [(0, 0), (9, 0), (10, 5), (6, 12), (3, 22)], iron, loc=(x, y, 0), segments=24)
        a.tube("Street lamp post", [(x, y, 20), (x, y, h - 15), (x - side * 8, y, h), (x - side * 35, y, h)], 2.7, iron)
        a.sphere("Street lamp reflector", 12, (x - side * 35, y, h), iron, scale=(1.3, 1, 0.28))
        a.sphere("Street lamp glowing lens", 9, (x - side * 35, y, h - 3), glow, scale=(1.2, 1, 0.18))
        light = a.light("Streetlamp road pool", (x - side * 35, y, h - 5), 250000, (1, 0.62, 0.28), 16,
                        target=(x - side * 80, y - 35, 0), kind="AREA")
        light.visible_glossy = True
        light.data.specular_factor = 1
    if cars:
        a.add(street_car.build(name + " blue car", loc=(road_w/2-100, 390, 0), rot_z=math.pi/2, length=350, width=158, height=110,
                              tone=(0.025, 0.065, 0.12), seed=seed))
        a.add(street_car.build(name + " burgundy car", loc=(-road_w/2+100, 840, 0), rot_z=-math.pi/2, length=370, width=160, height=120,
                              tone=(0.065, 0.014, 0.02), seed=seed + 1))
    water = M.clear_glass(name + " road puddles", 0.025, 1.333)
    for i in range(24):
        x, y = rng.uniform(-road_w / 2 + 35, road_w / 2 - 35), rng.uniform(30 - lead_in, depth - 30)
        rx, ry = rng.uniform(12, 44), rng.uniform(25, 90)
        vertices = [(x, y, 0.08)]
        for j in range(48):
            t = j * math.tau / 48
            wobble = 1 + 0.08 * math.sin(t * 5 + i)
            vertices.append((x + math.cos(t) * rx * wobble, y + math.sin(t) * ry * wobble, 0.07))
        a.mesh("Road puddle", vertices, [(0, j + 1, (j + 1) % 48 + 1) for j in range(48)], water)
    paint = E.simple(name + " road paint", (0.28, 0.26, 0.19), 0.25, Coat_Weight=0.8)
    for y in range(int(100-lead_in), int(depth), 190):
        a.block("Wet lane dash", (5, 65, 0.02), (0, y, 0.03), paint, 0)
    rain = M.rain_streak(name + " falling rain", 4)
    for i in range(falling_rain):
        lx, ly, h = rng.choice(lamp_positions)
        x, y, z = lx + rng.uniform(-70, 70), ly + rng.uniform(-90, 90), rng.uniform(20, h - 10)
        length, radius = rng.uniform(12, 35), rng.uniform(0.4, 0.9)
        ob = a.mesh("Backlit falling streak", [(x-radius, y, z), (x+radius, y, z),
                                              (x+radius+0.7, y, z+length), (x-radius+0.7, y, z+length)], [(0, 1, 2, 3)], rain)
        uv = ob.data.uv_layers.new()
        for loop, co in zip(uv.data, ((0, 0), (1, 0), (1, 1), (0, 1))): loop.uv = co
        ob.visible_shadow = False
    a.light("Blue city ambience", (0, depth * 0.6, 650), 1400000, (0.16, 0.29, 0.5), 550,
            target=(0, depth * 0.4, 0), kind="AREA")
    if exterior_slope:
        for ob in a.root.children:
            if ob.type == "EMPTY" and ob.name.endswith(" car"):
                rotation = ob.rotation_euler.to_quaternion()
                ob.rotation_mode = "QUATERNION"
                ob.rotation_quaternion = Quaternion(Vector((1, 0, 0)), -math.atan(exterior_slope)) @ rotation
            if ob.type == "CURVE":
                for spline in ob.data.splines:
                    for p in spline.points: p.co.z -= exterior_slope * p.co.y
            elif ob.type == "MESH" and ob.name.startswith(("Wet roadway", "Sidewalk", "Rounded kerb", "Wet lane", "Road puddle", "Backlit falling")):
                for v in ob.data.vertices: v.co.z -= exterior_slope * v.co.y
            ob.location.z -= exterior_slope * ob.location.y
    return a.root
