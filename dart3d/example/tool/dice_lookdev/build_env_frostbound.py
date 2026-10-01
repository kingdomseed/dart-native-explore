"""Frostbound environment: "The Frozen Altar".

A frost-rimed granite altar tray in an ice cave: a carved ward-circle in
the floor with faint cold light in its grooves, snow-capped walls, ice
crystal clusters and rime-covered boulders framing the edges, falling snow,
low cold mist and a blue glow through the cave ice behind.
"""
from __future__ import annotations

import math
import random

import bpy
from mathutils import Euler, Matrix, Vector

import env_common as E
import env_props as P
import room_common as RC

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.6, 3.2


def granite(name, snow=0.0, frost_lines=None, size=None, dark=False):
    m, k = E.material(name)
    tc = k.coords()
    obj = tc.outputs["Object"]
    n = k.noise(obj, 0.8, 10, 0.62).outputs["Fac"]
    speck = k.voronoi(obj, 9.0).outputs["Distance"]
    # dark=True: the altar's play field is blue-black slate (round 2), so
    # the clear-ice dice and their glowing numerals separate at top-down
    col = k.ramp(n, [(0.2, (0.02, 0.028, 0.045)), (0.8, (0.06, 0.075, 0.1))] if dark else
                 [(0.2, (0.2, 0.24, 0.3)), (0.8, (0.38, 0.42, 0.5))])
    col = k.mix(k.math("LESS_THAN", speck, 0.08), col, (0.25, 0.28, 0.33, 1))
    nrm = k.bump(n, 0.5, 0.3)
    rough = 0.7
    frost = k.ramp(k.noise(obj, 2.5, 6, 0.6).outputs["Fac"], [(0.5, (0, 0, 0)), (0.72, (1, 1, 1))])
    col = k.mix(k.math("MULTIPLY", frost, 0.1 if dark else 0.35), col, (0.6, 0.7, 0.8, 1))
    emis = (0, 0, 0, 1)
    estr = 0.0
    if frost_lines is not None:
        mp = k.node("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1 / size, 1 / size, 1)
        mp.inputs["Location"].default_value = (0.5, 0.5, 0)
        k.link(obj, mp.inputs["Vector"])
        tex = k.node("ShaderNodeTexImage", image=frost_lines, extension="CLIP")
        k.link(mp.outputs[0], tex.inputs["Vector"])
        groove = tex.outputs["Color"]
        nrm = k.bump(groove, 0.9, 0.25, normal=nrm, invert=True)
        col = k.mix(groove, col, (0.55, 0.75, 0.95, 1))
        emis = (0.25, 0.6, 1.0, 1)
        estr = k.math("MULTIPLY", groove, 1.6)
    s = k.bsdf(Base_Color=col, Roughness=rough, Normal=nrm, Emission_Color=emis, Emission_Strength=estr)
    if snow:
        geo = k.node("ShaderNodeNewGeometry")
        sep = k.node("ShaderNodeSeparateXYZ")
        k.link(geo.outputs["Normal"], sep.inputs[0])
        cap = k.math("MULTIPLY", k.math("SUBTRACT", sep.outputs["Z"], 0.55), 4.0, clamp=True)
        patch = k.math("MULTIPLY", k.math("SUBTRACT", k.noise(obj, 0.6, 4).outputs["Fac"], 1.0 - snow), 6.0,
                       clamp=True)
        cap = k.math("MULTIPLY", cap, patch)
        snow_s = k.bsdf(Base_Color=(0.9, 0.94, 1.0, 1), Roughness=0.6, Subsurface_Weight=0.6,
                        Subsurface_Radius=(0.6, 0.8, 1.2), Normal=k.bump(k.noise(obj, 4.0, 4).outputs["Fac"], 0.3, 0.2))
        s = k.mix_shader(cap, s, snow_s)
    k.surface(s)
    return m


def ice(name="Cave ice", glow=0.0):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.5, 6).outputs["Fac"]
    s = k.bsdf(Base_Color=(0.6, 0.85, 1.0, 1), Transmission_Weight=1.0, IOR=1.31,
               Roughness=k.math("ADD", k.math("MULTIPLY", n, 0.2), 0.03),
               Normal=k.bump(k.noise(obj, 2.0, 5).outputs["Fac"], 0.25, 0.3))
    if glow:
        s = k.add_shader(s, k.emission((0.2, 0.6, 1.0, 1), k.math("MULTIPLY", k.math("POWER", n, 3.0), glow)))
    k.surface(s)
    vol = k.node("ShaderNodeVolumeAbsorption")
    k.set(vol, Color=(0.55, 0.85, 1.0, 1), Density=0.05)
    k.volume(vol.outputs[0])
    return m


def crystal_cluster(x, y, z, n, seed, mat, scale=1.0):
    rng = random.Random(seed)
    for i in range(n):
        h = rng.uniform(4, 13) * scale
        r = h * rng.uniform(0.1, 0.16)
        body = E.cylinder("crystal", r, h, (0, 0, h / 2), mat, segs=6, cap=True)
        tip = E.cylinder("crystal_tip", r, r * 2.2, (0, 0, h + r * 1.1), mat, segs=6, r2=0.0)
        tilt = (rng.uniform(-0.55, 0.55), rng.uniform(-0.55, 0.55), rng.uniform(0, 6.28))
        base = Vector((x + rng.uniform(-1.5, 1.5) * scale, y + rng.uniform(-1.5, 1.5) * scale, z - 0.5))
        R = Euler(tilt).to_matrix().to_4x4()
        for ob in (body, tip):
            ob.data.set_sharp_from_angle(angle=math.radians(20))
            ob.matrix_world = Matrix.Translation(base) @ R @ Matrix.Translation(ob.location)


def build(scene):
    E.world(scene, color=(0.004, 0.008, 0.018), strength=1.0)
    size = W + 2 * RIM_T
    circle = P.mask_texture("frost_circle", P.sigil_strokes(seed=21, points=6, runes=24,
                                                            rings=(0.47, 0.455, 0.37, 0.18), w=0.0035),
                            E.TMP)
    E.plane("altar_floor", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.01),
            granite("Altar granite", frost_lines=circle, size=W * 0.95, dark=True))
    prof = E.profile_curve("altar_rim_profile", [(-1.3, -1.6), (1.3, -1.6), (1.3, 0.9), (0.8, 1.6),
                                                 (-0.8, 1.6), (-1.3, 0.9)])
    E.rim("altar_rim", W + RIM_T, D + RIM_T, 2.5, RIM_H, RIM_T, granite("Rim granite", snow=0.8), profile=prof)
    E.light(scene, "AREA", "cave_glow", (0, 260, 40), 90000, color=(0.25, 0.55, 1.0), size=120,
            target=(0, 100, 10), shadow=False)
    # crystals glow
    for x, y in ((-W / 2 - 8, D / 2 + 6), (W / 2 + 8, D / 2 + 7)):
        E.light(scene, "POINT", "crystal_light", (x, y, 8), 1800, color=(0.3, 0.65, 1.0), size=3)
    # moon key + soft cold fill; a very faint warm bounce keeps it from going monochrome
    E.light(scene, "AREA", "moon_key", (-20, -18, 60), 9000, color=(0.75, 0.85, 1.0), size=25, target=(0, 0, 0))
    E.light(scene, "AREA", "fill", (25, -45, 15), 700, color=(0.55, 0.65, 1.0), size=30, target=(0, 0, 2))
    E.light(scene, "AREA", "warm_bounce", (0, -60, 5), 150, color=(1.0, 0.75, 0.55), size=40, target=(0, 0, 0))
    rc = room(scene)
    return dict(
        samples=160, exposure=-.9, topdown=dict(width=W + 2 * RIM_T + 1.0),
        hero=dict(dist=32, elev=26, az=10, lens=70, fstop=2.8),
        hero_layout={
            "d20": ((-1.8,-1.0),20,0), "d12": ((2.6,10.0),12,12),
            "d10u": ((3.2,-11.5),0,-15), "d10t": ((3.0,4.0),0,20),
            "d8": ((-1.7,-9.5),8,-10), "d6": ((3.2,-3.0),6,18),
            "d4": ((-.4,6.0),4,58),
        },
        play_view=True, tray_half=(W/2+RIM_T,D/2+RIM_T), room_cam=rc,
    )


def room(scene):
    """A broadside altar between warm bronze braziers and a luminous glacier arch."""
    from assets import (geometry as G, materials as M, stone_altar, frost_pillar, frozen_arch,
                        fire_bowl, ice_formation, winter_banner, glacier_vista, cold_mist,
                        amethyst_cluster, vessel, candles, armillary, stone_steps, snow_cover)
    before=set(bpy.data.objects)
    fixtures=G.Asset("Frozen sanctuary fixtures")
    stone=M.frozen_stone("Chamber foundation granite",(.11,.15,.20),.65,.7,9)
    snow=M.snow("Sanctuary settled snow",seed=8)
    fixtures.block("Player chamber pavement",(270,110,8),(0,0,-80),stone,.8)
    fixtures.block("Lower frozen hall",(430,170,9),(0,140,-139.5),stone,.8)
    fixtures.block("Sanctuary apse floor",(520,70,9),(0,260,-204.5),stone,.8)
    fixtures.block("Deep arch landing",(450,100,8),(0,352,-244),stone,.8)
    stone_steps.build("Glacier threshold descent",loc=(10,295,-240),width=160,tread=7,rise=10,count=4,tone=(.13,.17,.22))
    ice_formation.build("Near snow drift",loc=(0,0,-75.8),kind="drift",width=270,depth=110,height=3,seed=3)
    ice_formation.build("Hall snow drift",loc=(0,140,-134.8),kind="drift",width=430,depth=170,height=5,seed=7)
    ice_formation.build("Apse snow drift",loc=(0,260,-199.8),kind="drift",width=520,depth=70,height=5,seed=9)
    stone_steps.build("Hall descent",loc=(130,55,-135),width=85,tread=12,rise=9.83,count=6,tone=(.13,.17,.22))
    stone_steps.build("Apse descent",loc=(165,225,-200),width=90,tread=10,rise=10.83,count=6,tone=(.13,.17,.22))
    stone_altar.build(loc=(0,-7,-76),width=106,depth=40,height=76,tone=(.035,.055,.085),frost=.18,seed=4,
                      carving=True,accumulation=.65,quiet=(28.3,20.3),quiet_center=(0,7))
    stone_altar.build("Left altar return",loc=(-39,30,-76),width=28,depth=34,height=76,
                      tone=(.045,.065,.10),frost=.7,seed=5,carving=True,accumulation=.9,
                      quiet=(28.3,20.3),quiet_center=(39,-30))
    vessel.build("Bronze votive cup",loc=(-29,24,.1),rot_z=math.pi,kind="tankard",height=10,radius=3.2,metal_finish="brass",seed=8)
    candles.build("Small altar candles",loc=(-28,37,.1),height=8,radius=.8,count=3,energy=45,seed=9)
    amethyst_cluster.build("Near clear ice shards",loc=(-31,42,.1),radius=5,height=9,count=8,bowl=False,
                           mineral="ice",tone=(.61,.83,.94),glow=2.5,energy=30,seed=10)
    amethyst_cluster.build("Luminous right glacial formation",loc=(68,108,-135),radius=20,height=138,count=9,
                           bowl=False,mineral="ice",tone=(.42,.76,.91),glow=7,fractures=3,edge_glow=.8,
                           energy=2400,seed=17)
    ice_formation.build("Snow at glacier foot",loc=(68,108,-134.8),kind="drift",width=54,depth=40,height=9,seed=13)
    frost_pillar.build("Near brazier pedestal",loc=(-35,135,-135),height=91,radius=10,tone=(.065,.085,.12),seed=11,accumulation=1.1,cap_hole=8)
    fire_bowl.build("Near warm bronze brazier",loc=(-35,135,-44),radius=12,height=12,flame_height=23,energy=15500,seed=4)
    for x,y,z,h,r,energy,seed in ((-25,205,-135,63,10,18500,7),(47,230,-200,117,10,22000,9),
                                  (103,337,-240,120,8,15500,14)):
        frost_pillar.build("Carved brazier plinth",loc=(x,y,z),height=h,radius=r*.80,tone=(.065,.085,.12),seed=seed,accumulation=1.1,cap_hole=r*.67)
        fire_bowl.build("Receding bronze brazier",loc=(x,y,z+h),radius=r,height=r,
                        flame_height=r*2.1,energy=energy,seed=seed)
    frost_pillar.build("Instrument pedestal",loc=(41,75,-135),height=104,radius=9,tone=(.055,.08,.12),seed=8,accumulation=1,cap_hole=5.5)
    armillary.build("Bronze winter armillary",loc=(41,75,-31),radius=8,pedestal=8,
                    metal_tone=(.43,.26,.085),seed=8)
    for x,y,z,h,r in ((-26,245,-200,170,12),(104,265,-200,150,12),(-145,280,-200,228,14)):
        frost_pillar.build("Hall frost pillar",loc=(x,y,z),height=h,radius=r,tone=(.07,.09,.13),frost=.9,seed=int(y),accumulation=1.5)
    frozen_arch.build(loc=(10,330,-240),width=155,shoulder=136,radius=12,depth=29,seed=12)
    winter_banner.build("Left snow-star banner",loc=(-61,260,-34),width=31,height=72,seed=3,metal_tone=(.68,.43,.12),stitch_width=.25)
    winter_banner.build("Right snow-star banner",loc=(85,280,-48),width=35,height=72,seed=6,metal_tone=(.68,.43,.12),stitch_width=.25)
    bronze=M.polished_metal("Banner support bronze",(.40,.25,.08),.5,8,.34)
    fixtures.beam("Left banner bracket",(-26,245,-33),(-43,260,-32),1.3,1.3,bronze,.2)
    fixtures.beam("Right banner bracket",(104,265,-51),(106,280,-46),1.3,1.3,bronze,.2)
    for x,y,z,w,h,d,rz,seed in ((-165,169,-135,92,183,35,.16,1),(190,191,-135,94,210,32,-.25,2),
                              (-122,310,-240,98,265,37,.08,4),(133,335,-240,103,270,34,-.12,5)):
        ice_formation.build("Deep cave ice wall",loc=(x,y,z),rot_z=rz,width=w,height=h,depth=d,
                            count=20,tone=(.23,.54,.76),glow=.23,seed=seed)
    for name,loc,w,h,d,seed in (("Left glacial ceiling vault",(-98,220,23),145,180,28,20),
                               ("Right glacial ceiling vault",(92,220,23),160,180,28,22),
                               ("Near cave ceiling",(0,130,47),330,110,20,23)):
        roof=ice_formation.build(name,loc=loc,width=w,height=h,depth=d,count=14,seed=seed)
        roof.rotation_euler.x=-math.pi/2
    for x,y,z,w,h,seed in ((-89,243,9,27,88,3),(170,290,9,42,95,4),(-127,174,39,77,61,8),(123,202,44,82,72,9)):
        ice_formation.build("Hanging cave icicles",loc=(x,y,z),kind="icicles",width=w,depth=17,height=h,count=15,seed=seed)
    for x,y,z,r,h,seed in ((-97,141,-135,22,58,4),(110,166,-135,24,80,5),(-78,266,-200,18,106,7),(140,305,-240,17,107,9)):
        amethyst_cluster.build("Ice footwall cluster",loc=(x,y,z),radius=r,height=h,count=11,bowl=False,
                               mineral="ice",tone=(.58,.82,.94),glow=6,fractures=5,edge_glow=.5,energy=300,seed=seed)
    cold_mist.build("Low hall cold mist",loc=(0,117,-133),width=155,depth=145,height=60,
                    layers=3,opacity=.70,tone=(.58,.78,.96),flakes=12,flake_height=170,seed=14)
    cold_mist.build("Mist through glacier arch",loc=(10,285,-187),width=175,depth=85,height=75,
                    layers=4,opacity=1.2,tone=(.80,.90,1),flakes=8,flake_height=140,seed=18)
    cold_mist.build("Ceiling crack snowfall",loc=(-5,205,-110),width=24,depth=40,height=0,layers=0,
                    flakes=14,flake_height=130,seed=22,flake_radius=(.08,.20),flake_glow=3)
    cold_mist.build("Thin mist beyond altar",loc=(0,45,-3),width=86,depth=20,height=7,
                    layers=2,opacity=.50,tone=(.44,.67,.87),seed=31)
    glacier_vista.build(slope=.48,sky_strength=4.4,seed=11)
    def area(name,loc,target,energy,color,size):
        ob=fixtures.light(name,loc,energy,color,size,target=target,kind="AREA")
        ob.visible_glossy="ice" not in name.lower();ob.data.specular_factor=1
        return ob
    area("Near brazier golden spill",(-35,130,-28),(-25,110,-70),16500,(1,.53,.22),20)
    area("Warm altar stone return",(-42,18,20),(-25,3,0),9500,(1,.65,.34),23)
    area("Brazier light on left capital",(-48,215,-57),(-26,245,-48),26000,(1,.47,.17),25)
    area("Right fire on carved stone",(72,230,-67),(104,265,-72),35000,(1,.51,.21),25)
    area("Glacier opening cold fill",(14,334,30),(0,180,-90),90000,(.51,.74,1),95)
    area("Left ice blue caustic pool",(-95,155,-15),(-66,175,-75),45000,(.13,.56,1),40)
    area("Right ice blue rim",(130,179,3),(35,110,-20),75000,(.19,.63,1),45)
    area("Glacial crystal edge light",(85,235,-40),(65,273,-90),50000,(.15,.55,1),30)
    area("Gold light on left banner",(-40,180,-15),(-61,260,-70),28000,(1,.68,.33),24)
    area("Gold light on right banner",(105,205,-17),(85,280,-82),44000,(1,.72,.4),26)
    area("Inner light in right glacier",(73,112,-42),(68,108,-10),18000,(.12,.70,1),14)
    area("Light through left ice",(-57,160,-60),(-89,195,-60),65000,(.15,.63,1),28)
    area("Light through right ice",(68,143,-50),(85,195,-65),85000,(.15,.70,1),28)
    area("Blue rim across altar edge",(45,60,33),(18,12,0),10000,(.36,.70,1),25)
    receivers=bpy.data.collections.new("Frostbound room light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    group=G.Asset("Frostbound room frame",rot_z=-math.pi/2)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT":
            ob.data.energy*=3.2 if ob.name.startswith("Moon on snowy peaks") else 2
            if ob.light_linking.receiver_collection is None:
                ob.light_linking.receiver_collection=receivers
        if ob!=group.root and ob.parent is None:group.add(ob)
    bounce=E.light(scene,"AREA","Glacier bounce across altar",(24,4,9),12000,color=(.38,.72,1),size=10,target=(0,0,1))
    # Dice are created after the environment; exclude existing surfaces from the added ice highlights.
    bounce_receivers=bpy.data.collections.new("Glacier bounce exclusions")
    for ob in tuple(bpy.data.objects):
        if ob.type in {"MESH","CURVE"}:bounce_receivers.objects.link(ob)
    for entry in bounce_receivers.collection_objects:
        entry.light_linking.link_state="EXCLUDE"
    bounce.light_linking.receiver_collection=bounce_receivers
    skylight=E.light(scene,"AREA","Cold skylight reflected in ice",(4,-10,26),1900,color=(.63,.84,1),size=14,target=(0,0,1))
    skylight.data.shape="RECTANGLE";skylight.data.size_y=5
    skylight.light_linking.receiver_collection=bounce_receivers
    return dict(loc=(-46,8,33),target=(2,0,8),lens=39.5,
                fstop=8*scene.unit_settings.scale_length,focus=(10,0,1.4))
