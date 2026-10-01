"""Voltline environment: "Rain Counter".

A late-night diner counter by a rain-streaked window. The tray is a holo
tray: smoked black glass with a faint hex grid of light, its rim a neon
tube in cyan with a magenta inner line. Wet black counter top with
puddles reflects the neon; abstract signage (shapes, no words) glows
outside; chrome tableware and a ceramic coffee mug frame the tray.
"""
from __future__ import annotations

import math
import random

import bpy

import env_common as E
import room_common as RC

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 1.6, 1.8
CYAN, MAGENTA = (0.05, 0.85, 1.0), (1.0, 0.08, 0.6)


def holo_floor():
    m, k = E.material("Holo floor")
    obj = k.coords().outputs["Object"]
    # hex grid from voronoi on a regular lattice is costly; a triangle-ish grid of 3 line families reads close
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    lines = None
    for ang in (0, 60, 120):
        a = math.radians(ang)
        proj = k.math("ADD", k.math("MULTIPLY", sep.outputs["X"], math.cos(a)),
                      k.math("MULTIPLY", sep.outputs["Y"], math.sin(a)))
        f = k.math("ABSOLUTE", k.math("SUBTRACT", k.math("FRACT", k.math("DIVIDE", proj, 2.0)), 0.5))
        l = k.math("GREATER_THAN", f, 0.48)
        lines = l if lines is None else k.math("MAXIMUM", lines, l)
    pulse = k.noise(obj, 0.08, 2).outputs["Fac"]
    s = k.bsdf(Base_Color=(0.005, 0.006, 0.01, 1), Roughness=0.08, Coat_Weight=1.0, Coat_Roughness=0.02,
               Emission_Color=(*CYAN, 1), Emission_Strength=k.math("MULTIPLY", lines, k.math("MULTIPLY", pulse, 1.2)))
    # Round 2: the tray is a lightbox under smoked glass: a soft indigo glow
    # everywhere, so the black-chrome dice read as crisp silhouettes.
    field = k.emission((0.14, 0.1, 0.42, 1), k.math("ADD", 0.62, k.math("MULTIPLY", pulse, 0.3)))
    k.surface(k.add_shader(s, field))
    return m


def build(scene):
    E.world(scene, color=(0.004, 0.004, 0.008), strength=1.0)
    E.plane("holo_floor", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.26), holo_floor())
    E.cube("holo_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.5), (0, 0, 0),
           E.simple("Anodized black", (0.01, 0.01, 0.012), 0.3, 1.0), bevel=0.2)
    E.rim("rim_body", W + RIM_T, D + RIM_T, 2.5, RIM_H, RIM_T,
          E.simple("Rim black chrome", (0.03, 0.03, 0.035), 0.12, 1.0), z0=0.25)
    E.rim("rim_neon", W + RIM_T, D + RIM_T, 2.5, 0.35, 0.35, E.emissive("Rim cyan", CYAN, 25.0), z0=RIM_H + 0.25)
    E.rim("rim_inner", W + 0.2, D + 0.2, 1.6, 0.2, 0.2, E.emissive("Rim magenta", MAGENTA, 15.0), z0=0.3)
    top = D / 2 + RIM_T
    E.light(scene, "AREA", "neon_m", (-22, top + 60, 50), 12000, color=MAGENTA, size=30, target=(0, 0, 0))
    E.light(scene, "AREA", "neon_c", (22, top + 60, 50), 12000, color=CYAN, size=30, target=(0, 0, 0))
    E.light(scene, "AREA", "key", (0, -40, 50), 1800, color=(0.8, 0.85, 1.0), size=25, target=(0, 0, 0))
    rc = room(scene, top, None)
    return dict(
        samples=128, exposure=0.2, topdown=dict(width=W + 2 * RIM_T + 1.0),
        hero=dict(dist=32, elev=28, az=6, lens=65, fstop=2.8),
        hero_layout={
            "d20": ((-1.8, -1.0), 20, 0), "d12": ((2.6, 10.0), 12, 12),
            "d10u": ((3.2, -11.5), 0, -15), "d10t": ((3.0, 4.0), 0, 20),
            "d8": ((-1.7, -9.5), 8, -10), "d6": ((3.2, -3.0), 6, 18),
            "d4": ((-0.4, 6.0), 4, 58),
        },
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene, top, chrome):
    """A raised window counter looking broadside into the lower diner and wet street."""
    from assets import (geometry as G, materials as M, diner_counter, bar_stool, dome_pendant,
                        rain_window, neon_street, neon_sign, napkin_dispenser, salt_shaker,
                        coffee_mug, leather_menu, espresso_machine, pie_stand, vessel, stone_steps)
    before = set(bpy.data.objects)
    diner_counter.build("Window counter", loc=(0, 0, -76), width=80, depth=64, height=75.75,
                        quiet=(28, 22), droplets=600, footrail=False, seed=11)
    napkin_dispenser.build(loc=(-28, 22, -0.25), rot_z=-0.1, width=8, depth=7, height=12, seed=3)
    salt_shaker.build(loc=(-24, 29.5, -0.25), seed=4)
    coffee_mug.build(loc=(27, 25, -0.25), rot_z=0.12, height=9.5, radius=4.2, steam_height=8.5, seed=7)
    leather_menu.build(loc=(33.5, 7, -0.25), rot_z=-0.06, width=10, depth=18, seed=9)
    foreground = set(bpy.data.objects) - before
    fixtures = G.Asset("Diner architecture")
    chrome = M.polished_metal("Diner architectural chrome", wear=0.4, seed=6)
    wood = M.oak("Diner wall walnut", (0.032, 0.01, 0.008), wear=0.5, seed=2, axis="Z")
    black = E.simple("Diner black frames", (0.008, 0.01, 0.018), 0.35, 0.65)
    floor = RC.tiles("Diner checker floor", (0.32, 0.29, 0.24), (0.012, 0.014, 0.019), scale=0.00045, rough=0.24)
    fixtures.block("Checker floor", (245, 300, 4), (-151.5, 135, -142), floor, 0.2)
    fixtures.block("Player counter platform", (240, 90, 64), (0, -10, -108), wood, 0.6)
    stone_steps.build("Diner side steps", loc=(-126, 24, -140), width=60, tread=18, rise=10.6, count=6,
                      tone=(0.042, 0.032, 0.027), seed=4)
    for i in range(9):
        y = 20 + i * 31
        fixtures.block("Walnut wall panel", (4, 29.7, 165), (-166, y, -58), wood, 0.4)
        fixtures.block("Wall chrome upright", (0.8, 1.2, 165), (-163.8, y - 15, -58), chrome, 0.2)
    mirror = E.simple("Smoked bar mirror", (0.38, 0.42, 0.46), 0.065, 1)
    for y in (88, 178, 243):
        fixtures.block("Backbar mirror", (0.7, 83, 112), (-162, y, -29), mirror, 0.3)
        for zz in (-85, 27): fixtures.block("Mirror frame", (2, 87, 2), (-161, y, zz), chrome, 0.4)
    diner_counter.build("Long service bar", loc=(-105, 160, -140), rot_z=math.pi / 2,
                        width=250, depth=54, height=88, quiet=(0, 0), droplets=65, seed=22)
    for i, y in enumerate((65, 110, 155, 200, 245)):
        bar_stool.build(f"Red stool {i}", loc=(-58, y, -140), radius=16, height=65, seed=20 + i)
    for i, (x, y, z) in enumerate(((-98, 70, -1), (-87, 105, -17), (-76, 135, -23))):
        dome_pendant.build(f"Warm pendant {i}", loc=(x, y, z), radius=13 - i, height=17,
                           drop=47 - z, energy=60000, seed=i)
    espresso_machine.build(loc=(-105, 118, -52), rot_z=0.3, width=46, depth=31, height=34, seed=4)
    pie_stand.build(loc=(-99, 183, -52), radius=13, height=13, seed=3)
    pie_stand.build("Second pie stand", loc=(-106, 264, -52), radius=12, height=16, seed=7)
    rng = random.Random(16)
    for level, z in enumerate((-41, 1)):
        fixtures.block("Backbar shelf", (22, 220, 3), (-148, 165, z), chrome, 0.6)
        for i in range(11):
            y = 74 + i * 18
            tone = rng.choice(((0.025, 0.09, 0.042), (0.16, 0.055, 0.013), (0.07, 0.035, 0.095)))
            vessel.build(f"Backbar bottle {level}-{i}", loc=(-149 + rng.uniform(-3, 3), y, z + 1.5),
                         kind="bottle", height=rng.uniform(17, 26), radius=rng.uniform(3, 4.2), tone=tone, seed=100 + i)
    fixtures.block("End bar mirror", (56, 1.2, 44), (-105, 159, -29), mirror, 0.4)
    fixtures.block("Display chrome foot", (56, 5, 1.2), (-105, 157, -51.4), chrome, 0.4)
    for i, h in enumerate((18, 21, 24, 17, 20)):
        vessel.build(f"Counter display bottle {i}", loc=(-125 + i * 10, 155, -50.8), kind="bottle",
                     height=h, radius=3.1, tone=((0.025, 0.11, 0.035), (0.15, 0.05, 0.012))[i % 2], seed=200 + i)
    bar_objects = set(bpy.data.objects) - before - foreground
    for ob in bar_objects:
        if ob.parent is None:
            ob.location.x += 54
    rain_window.build(loc=(150, 310, -150), rot_z=0.4, width=310, height=300,
                      panes=3, density=0.01, drop_radius=0.22, seed=41)
    near_window = rain_window.build("Near rain window", loc=(40, 151.8, -90), rot_z=math.pi / 2,
                                    width=223.6, height=220, panes=1, density=0.014, drop_radius=0.2, seed=44)
    rain_window.build("Rear rain window", loc=(-46, 292, -115), width=144, height=230, panes=2,
                      density=0.012, drop_radius=0.22, seed=43)
    neon_street.build(loc=(70, 480, -220), depth=1900, exterior_slope=0.4, seed=30)
    # Nearby window neon gives a clear motif; the remaining signs are across the road.
    neon_sign.build("Window orbital neon", loc=(74, 277.9, -85), rot_z=0.4, width=36, height=34,
                    design="planet", strength=4.5, backing=False, seed=17)
    neon_m = E.emissive("Ceiling magenta", (1, 0.009, 0.25), 12)
    neon_c = E.emissive("Ceiling cyan", (0.008, 0.6, 1), 12)
    fixtures.tube("Magenta ceiling rail", [(-162, 20, 35), (-162, 367, 35)], 0.8, neon_m)
    fixtures.tube("Cyan ceiling rail", [(-156, 360, 29), (30, 360, 29)], 0.8, neon_c)
    fixtures.tube("Counter canopy magenta", [(-80, 112, 40), (12, 112, 40)], 0.5, neon_m)
    fixtures.tube("Counter canopy cyan", [(-79, 129, 45), (15, 129, 45)], 0.45, neon_c)
    fixtures.tube("Window cyan return", [(-14, 40, -10), (-14, 40, 42)], 0.22, neon_c)
    fixtures.block("Ceiling soffit", (335, 460, 7), (-2, 225, 72), black, 0.6)
    for y in range(35, 451, 60): fixtures.beam("Ceiling ribs", (-162, y, 64), (157, y, 64), 2, 4, chrome, 0.5)
    fixtures.light("Warm bar reflected light", (-138, 137, -16), 170000, (1, 0.49, 0.18), 65,
                   target=(-81, 180, -65), kind="AREA")
    fixtures.light("Backbar shelf warmth", (-125, 210, 8), 130000, (1, 0.56, 0.26), 80,
                   target=(-163, 197, -25), kind="AREA")
    fixtures.light("Cyan through rain", (89, 178, 1), 150000, (0.025, 0.6, 1), 75,
                   target=(17, 12, -2), kind="AREA")
    fixtures.light("Magenta window reflection", (-50, 92, 28), 12000, (1, 0.014, 0.28), 60,
                   target=(-45, 24, -1), kind="AREA")
    fixtures.light("Warm counter pendant pool", (-85, 3, 47), 18000, (1, 0.57, 0.27), 24,
                   target=(-89, 18, 0), kind="AREA")
    fixtures.light("Coffee pendant bounce", (-24, 5, 30), 2500, (1, 0.69, 0.4), 16,
                   target=(-27, 25, 5), kind="AREA")
    fixtures.light("Cyan edge on service bar", (-30, 215, -12), 85000, (0.04, 0.56, 1), 45,
                   target=(-75, 165, -55), kind="AREA")
    fixtures.light("Rain window raking neon", (-38, 80, 22), 5000, (0.08, 0.5, 1), 70,
                   target=(-14, 150, -40), kind="AREA")
    rain_receivers = bpy.data.collections.new("Voltline rain glint receivers")
    for ob in near_window.children_recursive:
        if ob.type in {"MESH", "CURVE"}:
            rain_receivers.objects.link(ob)
    receivers = bpy.data.collections.new("Voltline room light receivers")
    for ob in set(bpy.data.objects) - before:
        if ob.type in {"MESH", "CURVE"}: receivers.objects.link(ob)
    group = G.Asset("Voltline room frame", rot_z=-math.pi / 2)
    for ob in set(bpy.data.objects) - before:
        if ob.type == "LIGHT":
            ob.light_linking.receiver_collection = receivers
            if ob.name == "Rain window raking neon":
                ob.light_linking.receiver_collection = rain_receivers
                ob.visible_glossy = True
                ob.data.specular_factor = 1
                ob.data.shape = "RECTANGLE"
                ob.data.size_y = 0.8
            if ob.name.startswith("Pendant pool"):
                ob.visible_glossy = True
                ob.data.specular_factor = 1
            if ob.name.startswith(("Neon spill on street", "Streetlamp road pool")):
                ob.visible_glossy = True
                ob.data.specular_factor = 1
            if ob.name in {"Warm counter pendant pool", "Cyan through rain"}:
                ob.visible_glossy = True
                ob.data.specular_factor = 1
                ob.data.shape = "RECTANGLE"
                ob.data.size_y = 4
        if ob != group.root and ob.parent is None: group.add(ob)
    return dict(loc=(-60, 0, 38.5), target=(0, -1.5, 11), lens=54,
                fstop=8 * scene.unit_settings.scale_length, focus=(8, 0, 1.4))
