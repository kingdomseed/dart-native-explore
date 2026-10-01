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
    """A seated view across the astronomer's table into an open night loggia."""
    from assets import (geometry as G, materials as M, marble_loggia, marble_table, telescope,
                        armillary, amethyst_cluster, velvet_drape, astronomer_tools,
                        night_vista, lantern, book, stone_steps)
    before=set(bpy.data.objects)
    top=-.3
    marble_table.build(loc=(0,-10,-76),width=110,depth=62,height=75.7,quiet=(28,30),back_wings=0,seed=8)
    velvet_drape.build(loc=(-47,4,top+.2),rot_z=-math.pi/2,width=26,length=32,drop=18,seed=5)
    astronomer_tools.build("Foreground astrolabe",loc=(-35.5,14,top+.8),rot_z=-.3,radius=7,seed=4)
    lantern.build("Table brass lantern",loc=(-67,154,-74.5),height=30,radius=6.5,
                  metal_finish="brass",chain_length=0,energy=1700,seed=9)
    for i in range(3):
        book.build(f"Gilt observatory folio {i}",loc=(-68,180,-74.5+i*4),rot_z=-.09+i*.10,
                   width=22,depth=28,thickness=4,tone=(.027,.011,.04),seed=10+i)
    amethyst_cluster.build("Right amethyst bowl",loc=(100,210,-100),radius=7.4,height=10.5,seed=8,energy=280)
    amethyst_cluster.build("Left amethyst bowl",loc=(-48,165,-75),radius=7,height=9,seed=5,energy=110)
    astronomer_tools.build("Parchment star chart",loc=(37,13,top),rot_z=0,kind="chart",width=17,depth=23,seed=6)
    astronomer_tools.build("Brass magnifier",loc=(35,16,top+.65),rot_z=-.25,kind="magnifier",radius=3.6)
    astronomer_tools.build("Incense burner",loc=(44,14,top),kind="incense",radius=3.2,seed=3)
    armillary.build("Table celestial globe",loc=(51,150,-75),kind="globe",radius=10,pedestal=10,seed=7)
    fixtures=G.Asset("Observatory fixtures")
    marble=M.fine_marble("Loggia floor marble",(.27,.26,.25),.6,seed=11)
    fixtures.block("Player loggia floor",(290,150,8),(0,-10,-80),marble,.7)
    fixtures.block("Astronomy terrace",(350,180,8),(0,154,-197),marble,.7)
    fixtures.block("Lower loggia terrace",(510,150,8),(0,300,-294),marble,.7)
    fixtures.block("Outer balcony pavement",(510,75,8),(0,412,-329),marble,.7)
    stone_steps.build("Terrace stair",loc=(110,65,-193),width=70,tread=11,rise=13,count=9,tone=(.20,.20,.23))
    stone_steps.build("Arcade stair",loc=(140,244,-290),width=80,tread=10,rise=12.125,count=8,tone=(.20,.20,.23))
    stone_steps.build("Balcony edge steps",loc=(0,375,-325),width=500,tread=7,rise=7,count=5,tone=(.20,.20,.23))
    marble_loggia.build(loc=(0,330,-290),bays=3,span=135,height=125,radius=10,balustrade_height=95,rail_offset=70,rail_base=-35,seed=6)
    marble_table.build("Instrument console",loc=(-68,170,-147),width=32,depth=50,height=72,quiet=(0,0),seed=9)
    armillary.build("Great brass armillary",loc=(-51,211,-125),radius=20,pedestal=18,seed=12)
    telescope.build(loc=(-13,210,-193),rot_z=.08,length=91,radius=4.8,stand_height=91,elevation=-12,seed=6)
    velvet_drape.build("Console velvet",loc=(-68,170,-74.5),width=30,length=46,drop=20,seed=13)
    lantern.build("Distant brass lantern",loc=(134,274,-134),height=33,radius=8,metal_finish="brass",chain_length=0,energy=24000,seed=18)
    fixtures.lathe("Lantern marble pedestal",[(0,0),(18,0),(18,6),(12,12),(9,20),(9,135),(14,143),(18,147),(18,156),(0,156)],
                   marble,(134,274,-290),segments=48)
    fixtures.lathe("Armillary marble plinth",[(0,0),(22,0),(22,4),(17,9),(14,16),(14,58),(20,66),(22,68),(0,68)],
                   marble,(-51,211,-193),segments=48)
    marble_table.build("Globe side console",loc=(51,150,-147),width=30,depth=30,height=72,quiet=(0,0),seed=19)
    night_vista.build(seed=15,slope=.60,sky_strength=2.3,moon_strength=2.4)
    def area(name,loc,target,energy,color,size):
        ob=fixtures.light(name,loc,energy,color,size,target=target,kind="AREA")
        ob.visible_glossy=True;ob.data.specular_factor=1
        return ob
    area("Lantern reflected table warmth",(-62,139,-47),(-50,172,-75),36000,(1,.65,.32),20)
    area("Moonlit table edge",(23,60,38),(19,9,0),25000,(.47,.62,1),35)
    area("Amethyst bowl reflected accent",(39,32,20),(20,14,0),3000,(.60,.35,1),15)
    area("Lantern on brass instruments",(-61,162,-68),(-35,208,-97),65000,(1,.67,.35),55)
    area("Moonlit arcade stone",(20,410,80),(0,320,-100),900000,(.40,.56,1),180)
    area("Warm loggia return",(-150,220,-25),(-40,320,-120),140000,(1,.68,.38),85)
    area("Right lantern stone pool",(127,251,-105),(147,330,-125),180000,(1,.64,.30),45)
    area("Instrument moon edge",(38,195,42),(-10,180,-30),170000,(.52,.65,1),55)
    fixtures.block("Left console landing",(34,52,46),(-68,170,-170),marble,.5)
    fixtures.block("Right console landing",(32,32,46),(51,150,-170),marble,.5)
    for x,y,r,h in ((-48,165,8,118),(100,210,9,93)):
        fixtures.lathe("Crystal display pedestal",[(0,0),(r*1.2,0),(r*1.2,5),(r*.7,12),
            (r*.6,h-13),(r,h-5),(r*1.15,h-3),(r*1.15,h),(0,h)],marble,(x,y,-193),segments=48)
    receivers=bpy.data.collections.new("Celestial room light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    group=G.Asset("Celestial room frame",rot_z=-math.pi/2)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT":
            ob.light_linking.receiver_collection=receivers
            ob.data.energy *= 1.7
        if ob!=group.root and ob.parent is None:group.add(ob)
    return dict(loc=(-50,0,41),target=(0,0,7.5),lens=46.3,
                fstop=8*scene.unit_settings.scale_length,focus=(5,0,1.4))
