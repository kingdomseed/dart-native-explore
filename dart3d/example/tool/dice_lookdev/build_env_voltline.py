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
    """A window table above the receding diner bar and a rain-wet avenue."""
    from assets import (geometry as G, materials as M, diner_counter, bar_stool, dome_pendant,
                        rain_window, neon_street, napkin_dispenser, salt_shaker,
                        coffee_mug, leather_menu, espresso_machine, pie_stand, vessel, stone_steps)
    before = set(bpy.data.objects)
    diner_counter.build("Window counter", loc=(0, 0, -76), width=80, depth=64, height=75.75,
                        quiet=(28, 20), droplets=1400, puddles=18, streaks=28,
                        drop_radius=(0.075, 0.24), footrail=False, seed=11)
    napkin_dispenser.build(loc=(-28, 22, -0.25), rot_z=-0.1, width=8, depth=7, height=12, seed=3)
    salt_shaker.build(loc=(-24, 29.5, -0.25), seed=4)
    coffee_mug.build(loc=(27, 25, -0.25), rot_z=0.12, height=9.5, radius=4.2,
                     steam_height=7.5, steam_strength=3, steam_width=1.3, steam_drift=-1.5, seed=7)
    leather_menu.build(loc=(33.5, 7, -0.25), rot_z=-0.06, width=10, depth=18, seed=9)
    fixtures = G.Asset("Diner architecture")
    chrome = M.polished_metal("Diner architectural chrome", wear=0.4, seed=6)
    wood = M.oak("Diner wall walnut", (0.032, 0.01, 0.008), wear=0.5, seed=2, axis="Z")
    black = E.simple("Diner black frames", (0.008, 0.01, 0.018), 0.35, 0.65)
    floor = RC.tiles("Diner checker floor", (0.32, 0.29, 0.24), (0.012, 0.014, 0.019), scale=0.00045, rough=0.24)
    mirror = E.simple("Smoked bar mirror", (0.38, 0.42, 0.46), 0.065, 1)
    fixtures.block("Player counter platform", (155, 92, 64), (-17, -10, -108), wood, 0.6)
    rng = random.Random(16)
    for level, (y, top_z) in enumerate(((165, -90), (285, -150), (405, -210))):
        floor_z = top_z - 88
        fixtures.block("Checker floor terrace", (210, 120, 5), (-75, y, floor_z - 2.5), floor, 0.2)
        diner_counter.build(f"Service bar {level}", loc=(-58, y, floor_z), rot_z=math.pi / 2,
                            width=118, depth=54, height=88, quiet=(0, 0), droplets=60, seed=22+level)
        for j, yy in enumerate((y-25, y+29)):
            bar_stool.build(f"Red stool {level}-{j}", loc=(-9, yy, floor_z), radius=15, height=65, seed=20+level*2+j)
        dome_pendant.build(f"Warm pendant {level}", loc=(-58, y, top_z+50), radius=8.5-level*0.4,
                           height=13, drop=60-top_z-50, energy=52000, seed=level)
        for j in range(4):
            yy = y-45+j*30
            fixtures.block("Walnut wall panel", (4, 29, 240), (-122, yy, top_z+5), wood, 0.4)
            fixtures.block("Wall chrome upright", (0.8, 1, 235), (-119.8, yy-15, top_z+5), chrome, 0.2)
        fixtures.block("Backbar mirror", (0.7, 110, 125), (-118, y, top_z+24), mirror, 0.3)
        for zz in (top_z-38, top_z+87):
            fixtures.block("Mirror frame", (2, 114, 2), (-117, y, zz), chrome, 0.4)
        for shelf, zz in enumerate((top_z+7, top_z+43)):
            fixtures.block("Backbar shelf", (20, 110, 3), (-107, y, zz), chrome, 0.6)
            for j in range(6):
                tone = rng.choice(((0.025,0.09,0.042),(0.16,0.055,0.013),(0.07,0.035,0.095)))
                vessel.build(f"Backbar bottle {level}-{shelf}-{j}", loc=(-109+rng.uniform(-2,2),y-45+j*18,zz+1.5),
                             kind="bottle", height=rng.uniform(17,26), radius=rng.uniform(3,4.2), tone=tone, seed=100+j)
        fixtures.light(f"Backbar shelf warmth {level}", (-95,y,top_z+60), 125000, (1,0.52,0.22), 60,
                       target=(-115,y,top_z+10), kind="AREA")
        fixtures.light(f"Bar cyan edge {level}", (10,y+40,top_z+50), 65000, (0.03,0.46,1), 40,
                       target=(-58,y,top_z), kind="AREA")
        if level:
            stone_steps.build(f"Diner aisle steps {level}", loc=(-163,y-61,floor_z), width=42,
                              tread=26, rise=15, count=4, tone=(0.035,0.03,0.025), seed=level)
    espresso_machine.build(loc=(-58,140,-90), rot_z=0.3, width=46, depth=31, height=34, seed=4)
    pie_stand.build(loc=(-57,270,-150), radius=13, height=13, seed=3)
    pie_stand.build("Second pie stand", loc=(-58,406,-210), radius=12, height=16, seed=7)
    near_window = rain_window.build("Rain window", loc=(47,60,-65), rot_z=0.18, width=110, height=110,
                                    panes=2, density=0.30, drop_radius=0.20, bottom_density=0.2, fog=0.9, seed=44)
    neon_street.build(loc=(80,1900,-650), depth=2400, exterior_slope=0.22, lead_in=900, seed=30)
    neon_m = E.emissive("Ceiling magenta", (1,0.009,0.25), 12)
    neon_c = E.emissive("Ceiling cyan", (0.008,0.6,1), 12)
    fixtures.tube("Magenta window header neon", [(-27,96,30),(17,96,30)], 0.25, neon_m)
    fixtures.tube("Cyan window header neon", [(11,88,28),(41,88,28)], 0.25, neon_c)
    fixtures.tube("Magenta ceiling rail", [(-118,90,60),(-118,465,60)], 0.8, neon_m)
    fixtures.tube("Cyan ceiling rail", [(-118,465,52),(15,465,52)], 0.8, neon_c)
    fixtures.block("Ceiling soffit", (155,400,7), (-62,265,72), black, 0.6)
    for y in range(90,466,60):
        fixtures.beam("Ceiling ribs", (-138,y,64),(15,y,64),2,4,chrome,0.5)
    fixtures.light("Warm bar chrome strip", (-20,75,-15), 180000, (1,0.6,0.28), 60,
                   target=(-70,240,-100), kind="AREA")
    fixtures.light("Cyan through rain", (110,105,10), 115000, (0.025,0.6,1), 60,
                   target=(30,24,-1), kind="AREA")
    fixtures.light("Magenta window reflection", (-5,96,30), 4500, (1,0.014,0.28), 45,
                   target=(0,27,-1), kind="AREA")
    fixtures.light("Cyan counter reflection", (26,88,28), 3500, (0.025,0.6,1), 30,
                   target=(15,27,-1), kind="AREA")
    fixtures.light("Warm counter pendant pool", (-31,3,47), 18000, (1,0.57,0.27),24,
                   target=(-35,18,0), kind="AREA")
    fixtures.light("Coffee pendant bounce", (30,5,30),2500,(1,0.69,0.4),16,
                   target=(27,25,5), kind="AREA")
    fixtures.light("Rain window raking neon", (15,85,30),80000,(0.35,0.72,1),20,
                   target=(25,55,-10),kind="AREA")
    fixtures.light("Rain window warm glint", (30,95,-5),18000,(1,0.7,0.4),18,
                   target=(20,55,-10),kind="AREA")
    rain_receivers = bpy.data.collections.new("Voltline rain glint receivers")
    for ob in near_window.children_recursive:
        if ob.name.startswith(("Rain bead", "Large running drop", "Running rain trail")):
            rain_receivers.objects.link(ob)
    receivers = bpy.data.collections.new("Voltline room light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}: receivers.objects.link(ob)
    group = G.Asset("Voltline room frame", rot_z=-math.pi/2)
    for ob in set(bpy.data.objects)-before:
        if ob.type == "LIGHT":
            ob.light_linking.receiver_collection = receivers
            if ob.name.startswith("Rain window "):
                ob.light_linking.receiver_collection = rain_receivers
                ob.data.shape = "RECTANGLE"
                ob.data.size_y = 10
                ob.visible_glossy = True
                ob.data.specular_factor = 1
                ob.visible_transmission = True
            if ob.name.startswith(("Pendant pool","Neon spill on street","Streetlamp road pool")) or ob.name in {
                    "Warm bar chrome strip","Rain window raking neon","Warm counter pendant pool","Cyan through rain"}:
                ob.visible_glossy = True
                ob.data.specular_factor = 1
            if ob.name in {"Warm counter pendant pool","Cyan through rain"}:
                ob.data.shape = "RECTANGLE"
                ob.data.size_y = 0.6 if ob.name in {"Magenta window reflection", "Cyan counter reflection"} else 4
        if ob != group.root and ob.parent is None: group.add(ob)
    return dict(loc=(-60,0,38.5), target=(0,-1.5,11), lens=54,
                fstop=32*scene.unit_settings.scale_length, focus=(25,0,1.4))
