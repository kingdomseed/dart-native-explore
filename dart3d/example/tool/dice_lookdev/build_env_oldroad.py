"""Old Road: a lantern-lit wayfarer's table in a timber inn at blue hour.

The original leather-framed map and its lighting recipe are preserved.
Gold faces need a light, open ceiling; the room dressing sits outside a
10 cm quiet band and is illuminated through separate receiver collections.
"""
from __future__ import annotations
import math
import bpy
import env_common as E
import env_props as P
W,D=E.TRAY_W,E.TRAY_D
RIM_T,RIM_H=2.4,2.6


def leather(name="Saddle leather", color=(0.2, 0.08, 0.03)):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 2.0, 8, 0.6).outputs["Fac"]
    pores = k.voronoi(obj, 12.0).outputs["Distance"]
    col = k.mix(k.math("MULTIPLY", n, 0.6), (*color, 1), (0.05, 0.02, 0.01, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=k.math("ADD", k.math("MULTIPLY", n, 0.3), 0.4),
                     Normal=k.bump(pores, 0.15, 0.05), Coat_Weight=0.2, Coat_Roughness=0.3))
    return m


def build(scene):
    scene.cycles.filter_width=.5
    scene.view_settings.gamma=.8
    E.world(scene,color=(.1,.075,.05),strength=1.0)
    E.plane("map", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.36), P.parchment("Travel map", tone=((0.05, 0.034, 0.018), (0.075, 0.05, 0.027), (0.09, 0.062, 0.034)),
                                                             ink_color=(0.3, 0.22, 0.12), ink_amount=0.18, grain=0.5), subdiv=1)
    E.cube("map_board", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.7), (0, 0, 0), leather("Board leather",
                                                                                    (0.1, 0.04, 0.02)), bevel=0.3)
    E.rim("rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, leather(), z0=0.35)
    top = D / 2 + RIM_T
    E.light(scene, "AREA", "blue_hour", (0, top + 70, 50), 9000, color=(0.5, 0.6, 1.0), size=50, target=(0, 0, 0))
    # side key (its reflection in the gold lands off the tray) + a soft warm
    # overhead: worn gold seen straight down mirrors whatever is above it
    E.light(scene, "AREA", "warm_key", (-44, -16, 38), 12000, color=(1.0, 0.75, 0.5), size=20, target=(0, 0, 0))
    E.overhead(scene, 20000, color=(1.0, 0.85, 0.65), size=90, height=110)
    return dict(samples=128,exposure=1.5,topdown=dict(width=W+2*RIM_T+1),
        hero=dict(dist=32,elev=30,az=-6,lens=65,fstop=2.8),
        hero_layout={"d20":((-4.8,-5),18,8),"d12":((-3.6,4.6),11,-14),
                     "d10u":((2.6,8),9,12),"d10t":((2.2,-1),40,-6),
                     "d8":((2.2,-10.5),5,16),"d6":((1,-6.5),3,-9),"d4":((-3.6,10.8),3,22)},
        play_view=True,tray_half=(W/2+RIM_T,D/2+RIM_T),room_cam=room(scene))


def room(scene):
    """A broadside lantern table above a shallow stepped inn sitting bay."""
    from assets import (geometry as G,materials as M,oak_table,timber_wall,cottage_window,
        hearth_fireplace,tavern_chair,travel_pack,walking_staff,hurricane_lantern,
        clay_pipe,bread_board,vessel,velvet_drape,fur_throw,barrel,shelf,candlestick)
    before=set(bpy.data.objects)
    a=G.Asset("Wayfarer inn architecture")
    timber=M.oak("Inn dark oak floor",(.085,.038,.014),.8,13,grain_scale=1.5)
    oak_table.build("Wayfarer tavern table",loc=(0,0,-76.35),width=110,depth=82,height=76,
        thickness=5,wood_tone=(.055,.024,.008),wear=.75,scorch=.07,grain_scale=2.2,
        leg_width=6,leg_inset=(12,12),rear_recess=(29,30),seed=11)
    a.block("Raised table floor",(330,140,8),(0,-10,-80.35),timber,.5)
    a.block("Inn sitting bay floor",(440,300,8),(0,300,-139),timber,.5)
    for i in range(5):
        top=-76-i*11.8
        a.block("Oak descending step",(330,18,11.8),(0,69+i*18,top-5.9),timber,.7)
    timber_wall.build("Rear half-timber wall",loc=(0,313,-190),width=420,height=270,bays=6,
        openings=((-80,85,96,105),),tone=(.32,.24,.15),seed=5)
    timber_wall.build("Inn left return",loc=(-208,197,-190),rot_z=math.pi/2,width=230,height=270,bays=3,seed=8)
    cottage_window.build("Blue-hour village window",loc=(-80,305,-105),width=96,height=105,panes=3,rows=3,
        density=0,drop_radius=.1,sky_colors=((.40,.16,.08),(.22,.11,.18),(.025,.055,.15)),sky_strength=1.8,
        exterior_slope=.7,town_altitude=76,sky_horizon=.65,seed=7)
    hearth_fireplace.build("Right-hand inn hearth",loc=(118,257,-135),width=110,depth=48,height=162,
        hearth_height=40,stone_tone=(.040,.026,.014),energy=250000,seed=12)
    tavern_chair.build("Chair for the travel pack",loc=(12,174,-135),width=52,depth=49,seat_height=45,height=94,seed=7)
    travel_pack.build("Canvas pack and rolled blanket",loc=(12,172,-91.005),rot_z=-.30,width=42,depth=26,height=56,buckle_height=.62,cup_height=.48,seed=4)
    staff=walking_staff.build("Staff resting on chair",loc=(47,201,-134.75),height=160,seed=4)
    staff.rotation_euler.x=.03;staff.rotation_euler.y=-.14
    tavern_chair.build("Hearth low stool",loc=(106,207,-135),width=43,depth=35,seat_height=43,back=False,seed=13)
    fur_throw.build("Worn sheepskin on stool",loc=(106,207,-92),width=47,length=53,drop=19,strands=3500,
        tone=(.16,.12,.075),seed=7)
    barrel.build("Inn coopered barrel",loc=(-158,270,-135),radius=24,height=80,seed=5)
    shelf.build("Inn crockery shelf",loc=(-181,303,-62),width=72,depth=20,levels=2,spacing=37,seed=15)
    oak_table.build("Hearth candle table",loc=(57,285,-135),width=46,depth=39,height=65,thickness=3,
        leg_width=4,leg_inset=(7,7),scorch=0,seed=17)
    candlestick.build("Candle beside hearth",loc=(57,282,-70),height=4,radius=3,candle_height=10,candle_radius=1.8,
        energy=4500,metal_finish="pewter",seed=13)
    vessel.build("Inn side table jug",loc=(69,292,-70),kind="jug",height=18,radius=5.3,tone=(.13,.078,.035),seed=8)
    hurricane_lantern.build("Tin lantern on the table",loc=(-25.5,27,-.35),height=22,radius=5.3,
        metal_finish="pewter",energy=3500,seed=7)
    vessel.build("Coopered travelling tankard",loc=(-41,26,-.20),rot_z=math.pi,kind="wooden_tankard",height=14,radius=4.6,
        tone=(.10,.047,.017),metal_finish="iron",seed=9)
    vessel.build("Right pewter tankard",loc=(34,31,-.35),rot_z=.5,kind="tankard",height=12,radius=4.2,
        metal_finish="pewter",seed=5)
    bread_board.build("Country bread and trencher",loc=(38,18,-.35),rot_z=math.pi/2,width=25,depth=16,loaf_height=7.5,seed=9)
    velvet_drape.build("Fringed travel plaid",loc=(-41.5,-14,-.35),width=22,length=90,drop=20,heap=2.7,
        tone=(.18,.037,.023),stars=0,fabric="wool",rest_patches=((8.5,31,7),(.5,40,7),(-4,20,5)),seed=3)
    clay_pipe.build("Resting clay pipe",loc=(-33,17,-.20),rot_z=1.65,length=12,bowl_height=5.2,radius=2.4,seed=6)
    def area(name,loc,target,energy,color,size):
        light=a.light(name,loc,energy,color,size,target=target,kind="AREA")
        light.visible_glossy=True;light.data.specular_factor=1
        return light
    area("Lantern pool on oak",(-24,25,18),(-13,4,-.35),21000,(1,.65,.30),22)
    area("Lantern on travel gear",(-47,100,-13),(12,172,-55),155000,(1,.67,.34),42)
    area("Dusk through window",(-76,292,-76),(10,172,-51),115000,(.42,.56,1),65)
    area("Fire on pack leather",(94,226,-83),(12,172,-49),150000,(1,.46,.16),42)
    area("Fire pool on plaster",(89,226,-73),(108,309,-40),130000,(1,.52,.22),48)
    area("Blue edge on table",(-60,128,19),(17,18,0),7500,(.43,.59,1),35)
    area("Warm reflected brass accent",(38,64,27),(30,10,0),11500,(1,.72,.38),29)
    area("Window return on left timber",(-74,264,-83),(-174,300,-47),115000,(.61,.68,1),55)
    receivers=bpy.data.collections.new("Oldroad environment light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    group=G.Asset("Oldroad broadside room",rot_z=-math.pi/2+.14)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT" and ob.light_linking.receiver_collection is None:ob.light_linking.receiver_collection=receivers
        if ob!=group.root and ob.parent is None:group.add(ob)
    excluded=bpy.data.collections.new("Hearth gold-return exclusions")
    for ob in bpy.data.objects:
        if ob.type in {"MESH","CURVE"}:excluded.objects.link(ob)
    for entry in excluded.collection_objects:entry.light_linking.link_state="EXCLUDE"
    reflection=E.light(scene,"AREA","Hearth reflected on polished gold",(45,6,35),2000,
                       color=(1,.86,.66),size=24,target=(0,0,1))
    reflection.light_linking.receiver_collection=excluded
    return dict(loc=(-32,-6,24),target=(0,0,6.5),lens=26.4,
        fstop=8*scene.unit_settings.scale_length,focus=(2,0,2))
