"""Celestial: a marble observatory loggia above moonlit floating citadels."""
from __future__ import annotations

import math
import random

import bpy

import env_common as E
import env_props as P
from build_dice import _circle

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.2, 2.4


def astrolabe_strokes(w=0.0035, seed=3):
    rng = random.Random(seed)
    s = [([P.ring(r)], w * (1.5 if r > 0.46 else 1.0), True) for r in (0.475, 0.46, 0.4, 0.33, 0.15)]
    for i in range(8):  # moon phases in the outer band
        a = 2 * math.pi * i / 8 + math.pi / 2
        cx, cy = 0.5 + 0.43 * math.cos(a), 0.5 + 0.43 * math.sin(a)
        s.append(([_circle(cx, cy, 0.022, 24)], w, True))
        k = math.cos(math.pi * i / 4)
        arc = [(cx + 0.022 * k * math.cos(t), cy + 0.022 * math.sin(t))
               for t in [math.pi / 2 + j * math.pi / 12 for j in range(13)]]
        s.append(([arc], w, False))
    for i in range(180):
        a = 2 * math.pi * i / 180
        r0 = 0.46 - (0.008 if i % 5 else 0.016)
        s.append(([[(0.5 + r0 * math.cos(a), 0.5 + r0 * math.sin(a)),
                    (0.5 + 0.46 * math.cos(a), 0.5 + 0.46 * math.sin(a))]], w * 0.6, False))
    stars = []
    for i in range(40):  # an invented star chart
        r, a = 0.32 * math.sqrt(rng.random()), rng.uniform(0, 6.28)
        p = (0.5 + r * math.cos(a), 0.5 + r * math.sin(a))
        stars.append(p)
        s.append(([_circle(p[0], p[1], rng.uniform(0.002, 0.006), 10)], w * 1.3, True))
    for i in range(0, 30, 3):
        s.append(([[stars[i], stars[i + 1], stars[i + 2]]], w * 0.5, False))
    # the rete: an eccentric ring and pointer
    s.append(([P.ring(0.24, cx=0.5, cy=0.56)], w * 1.2, True))
    s.append(([[(0.5, 0.5), (0.5, 0.86)]], w * 1.5, False))
    return s


def marble(name):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    warp = k.noise(obj, 0.05, 6, 0.6).outputs["Color"]
    vec = k.mix(0.6, obj, warp, "LINEAR_LIGHT")
    wave = k.node("ShaderNodeTexWave", bands_direction="DIAGONAL")
    k.link(vec, wave.inputs["Vector"])
    k.set(wave, Scale=0.06, Distortion=12.0, Detail=8.0)
    vein = k.math("POWER", wave.outputs["Fac"], 6.0)
    col = k.mix(vein, (0.82, 0.8, 0.84, 1), (0.25, 0.2, 0.32, 1))
    s = k.bsdf(Base_Color=col, Roughness=0.12, Subsurface_Weight=0.2, Coat_Weight=0.5, Coat_Roughness=0.05)
    k.surface(s)
    return m


def build(scene):
    E.world(scene, color=(0.01, 0.005, 0.02), strength=1.0)
    inlay = P.mask_texture("astrolabe", astrolabe_strokes(), E.TMP, res=4096)
    lapis, k = E.material("Lapis field")
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.4, 8, 0.6).outputs["Fac"]
    fleck = k.math("LESS_THAN", k.voronoi(obj, 3.0).outputs["Distance"], 0.07)
    base = k.bsdf(Base_Color=k.ramp(n, [(0.3, (0.01, 0.015, 0.07)), (0.7, (0.03, 0.04, 0.16))]), Roughness=0.2,
                  Coat_Weight=0.8, Coat_Roughness=0.03)
    gold = k.bsdf(Base_Color=(1.0, 0.8, 0.4, 1), Metallic=1.0, Roughness=0.3)
    field = k.mix_shader(fleck, base, gold)
    mp = k.node("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / (W * 0.97), 1 / (W * 0.97), 1)
    mp.inputs["Location"].default_value = (0.5, 0.5, 0)
    k.link(obj, mp.inputs["Vector"])
    tex = k.node("ShaderNodeTexImage", image=inlay, extension="CLIP", interpolation="Cubic")
    k.link(mp.outputs[0], tex.inputs["Vector"])
    silver = k.bsdf(Base_Color=(0.85, 0.87, 0.92, 1), Metallic=1.0, Roughness=0.2,
                    Normal=k.bump(tex.outputs["Color"], 0.4, 0.05))
    k.surface(k.mix_shader(tex.outputs["Color"], field, silver))
    E.plane("disc_field", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.31), lapis)
    E.cube("slab", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.6), (0, 0, 0), marble("Slab marble"), bevel=0.2)
    E.rim("rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, marble("Rim marble"), z0=0.3)
    E.rim("rim_cap", W + RIM_T, D + RIM_T, 3.0, 0.4, 0.6, E.simple("Silver", (0.9, 0.9, 0.95), 0.2, 1.0),
          z0=RIM_H + 0.1)
    E.light(scene, "AREA", "moon", (-40, 120, 90), 22000, color=(0.65, 0.7, 1.0), size=40, target=(0, 0, 0))
    E.light(scene, "AREA", "violet_rim", (40, 60, 20), 3500, color=(0.6, 0.35, 1.0), size=30, target=(0, 0, 3))
    E.light(scene, "AREA", "soft_front", (0, -60, 40), 1500, color=(0.85, 0.85, 1.0), size=40, target=(0, 0, 0))
    E.overhead(scene, 2500, color=(0.85, 0.85, 1.0), size=90, height=110)  # silver frames read top-down
    rc = room(scene)
    return dict(
        samples=128, exposure=-0.5, topdown=dict(width=W + 2 * RIM_T + 1.0),
        hero=dict(dist=32, elev=30, az=8, lens=65, fstop=2.8),
        hero_layout={
            "d20": ((-1.8, -1.0), 20, 0), "d12": ((2.6, 10.0), 12, 12),
            "d10u": ((3.2, -11.5), 0, -15), "d10t": ((3.0, 4.0), 0, 20),
            "d8": ((-1.7, -9.5), 8, -10), "d6": ((3.2, -3.0), 6, 18),
            "d4": ((-0.4, 6.0), 4, 58),
        },
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene):
    """Overlapping instruments frame a low, broadside view through the arcade."""
    from assets import (geometry as G, materials as M, marble_loggia, marble_table, telescope,
                        armillary, amethyst_cluster, velvet_drape, astronomer_tools,
                        night_vista, lantern, book, stone_steps)
    before = set(bpy.data.objects)
    top = -.3
    marble_table.build(loc=(0,-7,-76),width=104,depth=40,height=75.7,
                       tone=(.60,.55,.46),wear=.12,quiet=(22,12),polish=.85,seed=8)
    marble_table.build("Left dressing return",loc=(-40.5,32.5,-76),width=27,depth=39,height=75.7,
                       tone=(.60,.55,.46),wear=.12,polish=.85,quiet=(0,0),seed=8)
    velvet_drape.build(loc=(-36,32,top+.5),rot_z=math.pi/2,width=28,length=30,drop=20,
                       tone=(.085,.009,.13),stars=18,seed=5)
    astronomer_tools.build("Foreground astrolabe",loc=(-32,23,top+1),rot_z=-.3,radius=6,seed=4)
    marble_table.build("Right dressing return",loc=(40,26.5,-76),width=26,depth=27,height=75.7,
                       tone=(.60,.55,.46),wear=.12,polish=.85,quiet=(0,0),seed=8)
    astronomer_tools.build("Parchment star chart",loc=(37,13,top+.05),rot_z=0,
                           kind="chart",width=17,depth=23,seed=6)
    astronomer_tools.build("Brass magnifier",loc=(35,14,top+.7),rot_z=-.25,kind="magnifier",radius=3.6)
    astronomer_tools.build("Incense burner",loc=(44,10,top),kind="incense",radius=3.2,seed=3)
    fixtures = G.Asset("Observatory fixtures")
    marble = M.fine_marble("Loggia floor marble",(.36,.33,.28),.4,seed=11)
    fixtures.block("Player loggia floor",(290,110,8),(0,-10,-80),marble,.7)
    fixtures.block("Astronomy terrace",(400,130,8),(0,115,-134),marble,.7)
    fixtures.block("Tripod landing",(100,60,8),(-12,210,-141),marble,.6)
    fixtures.block("Tripod terrace step",(100,8,7),(-12,184,-133.5),marble,.4)
    fixtures.block("Lantern console landing",(36,46,30),(-34,74,-115),marble,.6)
    fixtures.block("Arcade pavement",(520,110,8),(0,270,-191),marble,.7)
    stone_steps.build("Terrace stair",loc=(120,50,-130),width=70,tread=11,rise=9,count=6,tone=(.32,.30,.27))
    stone_steps.build("Arcade stair",loc=(150,230,-187),width=75,tread=9,rise=9.5,count=6,tone=(.32,.30,.27))
    marble_loggia.build(loc=(35,245,-187),bays=3,span=180,height=127,radius=9,
                        balustrade_height=65,rail_offset=38,rail_base=-5,tone=(.57,.52,.44),seed=6)
    marble_table.build("Left lantern console",loc=(-34,74,-100),width=34,depth=44,height=86,
                       tone=(.55,.48,.37),quiet=(0,0),seed=9)
    lantern.build("Table brass lantern",loc=(-33,65,-14),height=30,radius=6.5,
                  metal_finish="brass",chain_length=0,energy=850,seed=9)
    for i in range(3):
        book.build(f"Gilt observatory folio {i}",loc=(-37,86,-14+i*4),rot_z=-.09+i*.10,
                   width=22,depth=25,thickness=4,tone=(.035,.009,.05),seed=10+i)
    amethyst_cluster.build("Left amethyst bowl",loc=(-44,103,-40),radius=7,height=10,seed=5,energy=110)
    marble_table.build("Instrument console",loc=(-27,135,-130),width=46,depth=42,height=77,
                       tone=(.52,.45,.34),quiet=(0,0),seed=12)
    velvet_drape.build("Console velvet",loc=(-27,135,-52.8),width=44,length=42,drop=22,seed=13)
    armillary.build("Great brass armillary",loc=(-27,135,-52),radius=19,pedestal=15,seed=12)
    telescope.build(loc=(-12,210,-137),rot_z=.35,length=64,radius=3.8,
                    stand_height=79,elevation=38,seed=6)
    marble_table.build("Globe side console",loc=(52,130,-130),width=34,depth=40,height=90,
                       tone=(.52,.45,.35),quiet=(0,0),seed=19)
    armillary.build("Table celestial globe",loc=(52,130,-40),kind="globe",radius=10,pedestal=12,seed=7)
    amethyst_cluster.build("Right amethyst bowl",loc=(40,32,top),radius=7.4,height=13,seed=8,energy=110)
    fixtures.lathe("Left crystal pedestal",[(0,0),(10,0),(10,4),(6,9),(4,15),(4,77),(8,84),(10,90),(0,90)],
                   marble,(-44,103,-130),segments=48)
    lantern.build("Distant brass lantern",loc=(121,229,-68),height=30,radius=7,
                  metal_finish="brass",chain_length=0,energy=8000,seed=18)
    fixtures.lathe("Lantern marble pedestal",[(0,0),(14,0),(14,5),(8,12),(7,20),(7,104),(12,112),(14,119),(0,119)],
                   marble,(121,229,-187),segments=48)
    night_vista.build(seed=15,slope=.39,sky_strength=2.8,moon_strength=2.4,
                      moon_offset=(270,200),planet_offset=(420,260),cloud_drop=55)
    def area(name,loc,target,energy,color,size):
        ob=fixtures.light(name,loc,energy,color,size,target=target,kind="AREA")
        ob.visible_glossy=True
        ob.data.specular_factor=1
        if name in {"Lantern golden table pool", "Amethyst bowl reflected accent", "Moonlit table reflection"}:
            ob.visible_glossy=False
            ob.data.specular_factor=.12
        return ob
    area("Lantern golden table pool",(-35,25,25),(-24,0,0),11000,(1,.72,.41),22)
    area("Lantern return on gold embroidery",(-37,12,23),(-34,28,0),2200,(1,.78,.50),13)
    area("Lantern brass highlights",(-43,78,3),(-35,124,-25),28000,(1,.70,.39),26)
    area("Moonlit table reflection",(18,75,48),(12,0,0),5500,(.75,.83,1),34)
    area("Amethyst bowl reflected accent",(40,32,10),(27,12,0),1500,(.61,.36,1),12)
    area("Moonlit arcade stone",(30,320,70),(0,240,-75),250000,(.55,.68,1),100)
    area("Warm loggia return",(-125,185,-20),(-45,245,-90),75000,(1,.71,.42),60)
    area("Right lantern stone pool",(119,224,-52),(120,250,-90),55000,(1,.65,.31),32)
    area("Lantern return on globe and quartz",(60,62,24),(52,130,-15),27000,(1,.79,.49),25)
    area("Instrument moon edge",(40,230,32),(-12,210,-85),65000,(.60,.74,1),35)
    receivers=bpy.data.collections.new("Celestial room light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    group=G.Asset("Celestial room frame",rot_z=-math.pi/2)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT":
            ob.light_linking.receiver_collection=receivers
        if ob!=group.root and ob.parent is None:group.add(ob)
    chart_receivers=bpy.data.collections.new("Celestial silver engraving receivers")
    for name in ("disc_field","slab","rim","rim_cap"):
        chart_receivers.objects.link(bpy.data.objects[name])
    chart=E.light(scene,"AREA","Reflected moon on silver chart",(42,12,48),8500,
                  color=(.78,.85,1),size=27,target=(0,0,0))
    chart.light_linking.receiver_collection=chart_receivers
    slab_receivers=bpy.data.collections.new("Celestial marble base receivers")
    slab_receivers.objects.link(bpy.data.objects["slab"])
    slab_light=E.light(scene,"AREA","Warm return on thin marble base",(-25,25,20),6500,
                       color=(1,.83,.63),size=24,target=(0,0,0))
    slab_light.light_linking.receiver_collection=slab_receivers
    return dict(loc=(-46,8,29),target=(2,0,8),lens=38.5,
                fstop=8*scene.unit_settings.scale_length,focus=(4,0,1.4))
