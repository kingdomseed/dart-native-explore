"""Forged smithing tools with working jaws, peens, pivots and curved shoes."""

import bpy
import math
import random

from . import geometry as G, materials as M


def tongs(a, x, z, length, iron, steel):
    pivot = z - length * 0.26
    for side in (-1, 1):
        a.tube("Tong rein and jaw", [(x + side * 3.3, -5, z - length),
                                    (x + side * 2.9, -5, pivot - length * 0.43),
                                    (x + side * 1.6, -5, pivot - 6), (x, -5 + side * 0.5, pivot),
                                    (x - side * 3, -5, pivot + 5), (x - side * 3, -5, pivot + 10),
                                    (x - side * 1.2, -5, pivot + 12)], 0.65, iron)
        a.block("Tong gripping jaw", (1.8, 2.6, 4.2), (x - side * 1.4, -5, pivot + 10.5), steel, 0.3)
    rivet = a.cylinder("Tong pivot rivet", 1.3, 2.7, (x, -5, pivot), steel, segments=16)
    rivet.rotation_euler.x = math.pi / 2


def hammer(a, x, z, length, wood, iron, steel, ball=False):
    handle = [(1.25, 0), (1.6, 1), (1.35, length * 0.2), (1, length * 0.75), (1.2, length), (0, length)]
    a.lathe("Shaped hickory handle", handle, wood, (x, -6, z - length), segments=16)
    a.block("Forged hammer eye", (7, 4.5, 5), (x, -6, z - 2), iron, 0.7)
    face = a.cylinder("Hammer striking face", 2.55, 2, (x - 4.4, -6, z - 2), steel, bevel=0.25)
    face.rotation_euler.y = math.pi / 2
    if ball:
        a.sphere("Ball peen", 2.25, (x + 4.8, -6, z - 2), steel)
    else:
        a.extrude("Cross peen", [(x + 3, z - 4.3), (x + 7, z - 2.6),
                                (x + 7, z - 1.5), (x + 3, z + 0.3)], 4.4, steel, y=-6, bevel=0.25)


def shoe(a, x, z, size, iron, steel):
    n = 26
    verts = []
    for j in range(n):
        t = math.radians(-35 + j * 250 / (n - 1))
        for r, y in ((size, -3.4), (size - 2, -3.4), (size - 2, -4.3), (size, -4.3)):
            verts.append((x + r * math.cos(t), y, z - r * math.sin(t)))
    faces = [(j * 4 + k, j * 4 + (k + 1) % 4, (j + 1) * 4 + (k + 1) % 4, (j + 1) * 4 + k)
             for j in range(n - 1) for k in range(4)]
    faces += [(0, 3, 2, 1), tuple(range((n - 1) * 4, n * 4))]
    a.mesh("Forged horseshoe", verts, faces, iron, bevel=0.18)
    for t in (0, 30, 60, 120, 150, 180):
        angle = math.radians(t)
        nail = a.block("Recessed shoe nail", (0.75, 0.06, 1),
                       (x + (size - 1) * math.cos(angle), -4.34, z - (size - 1) * math.sin(angle)), steel, 0.1)
        nail.rotation_euler.y = -angle


def build(name="Tool wall", loc=(0, 0, 0), rot_z=0, width=100, height=68,
          wood_tone=(0.1, 0.045, 0.018), metal_finish="iron", wear=0.7, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    rng = random.Random(seed)
    iron = M.metal(f"{name} iron", metal_finish, wear, seed)
    steel = M.metal(f"{name} edges", "steel", wear, seed)
    wood = M.oak(f"{name} oak rail", wood_tone, wear, seed)
    handles = M.oak(f"{name} hickory", (0.25, 0.14, 0.055), wear, seed, axis="Z")
    for z in (height, height - 32):
        a.block("Tool rack timber", (width, 4, 7), (0, 0, z), wood, 0.5)
        for x in (-width * 0.42, width * 0.42):
            a.sphere("Rail fixing", 0.9, (x, -2.2, z), iron, scale=(1, 0.4, 1))
    for i in range(8):
        x = -width * 0.42 + i * width * 0.12
        z = height + rng.uniform(-2, 2)
        a.tube("Tool peg", [(x, -2, height + 1), (x, -8, height + 1), (x, -8.5, height + 3)], 0.55, iron)
        a.ring("Tool suspension loop", 2.7, 0.3, (x, -6, z - 0.5), iron, plane="XZ", ellipse=1.5, segments=20)
        if i in (0, 1, 5):
            tongs(a, x, z, rng.uniform(46, 59), iron, steel)
        elif i in (2, 4):
            hammer(a, x, z, 36 if i == 2 else 32, handles, iron, steel, ball=i == 4)
        else:
            a.lathe("Punch" if i == 7 else "Chisel", [(0.3, 0), (1.1, 5), (1.1, 26),
                                                     (1.35, 27), (0, 27)], iron, (x, -5, z - 27), segments=8)
    for x, z in ((-width * 0.33, 9), (width * 0.24, 7)):
        shoe(a, x, z, 8, iron, steel)
        a.tube("Horseshoe wall peg", [(x, 5, z - 6.3), (x, -5, z - 6.3)], 0.45, iron)
    return a.root
