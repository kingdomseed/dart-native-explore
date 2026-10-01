"""Gemcutter: an intimate walnut atelier, cool task lamp and warm sunset.

Original velvet, walnut tray, padded rim and four tray lights are preserved.
The room is composed broadside; its added lamps light environment receivers.
"""
from __future__ import annotations
import math
import bpy
import env_common as E
import env_props as P
import room_common as RC
W,D=E.TRAY_W,E.TRAY_D
RIM_T,RIM_H=2.8,2.6


def _room_sampling(scene, depsgraph=None):
    if scene.camera and scene.camera.name == "room" and "Gemcutter broadside room" in scene.objects:
        scene.cycles.filter_width=1.5


def build(scene):
    scene.cycles.filter_width=.3
    scene.view_settings.gamma=.75
    if _room_sampling not in bpy.app.handlers.render_pre:
        bpy.app.handlers.render_pre.append(_room_sampling)
    E.world(scene, color=(0.02, 0.022, 0.025), strength=1.0)
    # Round 2: jeweler's dove-grey velvet (round 1's deep teal matched the
    # emerald dice at top-down)
    vel = P.velvet("Grey velvet", color=(0.42, 0.43, 0.43), stars=False)
    E.plane("velvet", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.41), vel)
    E.cube("tray_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.8), (0, 0, 0),
           P.dark_wood("Tray walnut", varnish=0.9), bevel=0.3)
    E.rim("rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, vel, z0=0.4)
    top = D / 2 + RIM_T
    E.light(scene, "AREA", "bench_lamp", (12, top + 14, 36), 20000, color=(0.95, 0.97, 1.0), size=10,
            target=(0, 0, 0))
    E.light(scene, "AREA", "fill", (-35, -45, 35), 10000, color=(1.0, 0.85, 0.7), size=40, target=(0, 0, 0))
    E.overhead(scene, 9000, color=(0.95, 0.97, 1.0), size=90, height=110)  # gold enamel reads top-down
    E.light(scene, "AREA", "rim", (30, 60, 20), 2000, color=(0.7, 0.9, 1.0), size=30, target=(0, 0, 2))
    return dict(samples=128,exposure=.85,topdown=dict(width=W+2*RIM_T+1),
        hero=dict(dist=32,elev=30,az=-8,lens=65,fstop=2.8),play_view=True,
        hero_layout={"d20":((-4.8,0),18,8),"d12":((-2.8,9.5),11,-14),
                     "d10u":((3.5,-9.5),9,12),"d10t":((-2,-9.5),40,-6),
                     "d8":((3.7,10.8),5,16),"d6":((2,-2),3,-9),"d4":((4.1,4.9),3,22)},
        tray_half=(W/2+RIM_T,D/2+RIM_T),room_cam=room(scene))


def room(scene):
    from assets import (geometry as G,materials as M,jeweler_bench,bench_lamp,balance_scale,
        gem_case,cut_gem,jeweler_tools,drawer_chest,atelier_window,lantern,
        book,shelf,candles,potted_plant)
    before=set(bpy.data.objects)
    a=G.Asset("Atelier architecture")
    floor=-130
    wood=M.oak("Atelier panelling",(.08,.028,.014),.65,4,axis="Z")
    plaster=M.limewash("Warm atelier plaster",(.24,.17,.12),.55,3)
    a.block("Oak atelier floor",(420,410,5),(0,100,floor-2.5),RC.planks("Atelier boards"),.3)
    a.block("Player floor landing",(300,100,54.6),(0,-20,-102.7),wood,.4)
    a.block("Balance bay landing",(116,64,24.6),(-25,75,-117.7),wood,.4)
    a.block("Chest bay landing",(78,69,11.6),(49,101,-124.2),wood,.4)
    for i in range(4):a.block("Workshop level step",(38,14,13.65),(-100,37+i*14,-82.225-i*13.65),wood,.4)
    wall=RC.wall_plane("Panelled atelier back wall",400,260,((42,83,150,142),),plaster,thickness=7)
    a.add(wall);wall.location=(0,190,floor)
    a.block("Atelier side wall",(6,400,260),(-198,0,0),plaster,.3)
    for x in range(-186,197,38):
        a.block("Walnut wall pilaster",(4,3,234),(x,185,-9),wood,.5)
        if x< -48 or x>132:
            a.block("Recessed oak wall panel",(31,1,64),(x+19,186,-52),wood,.4)
    a.block("Panelled dado rail",(400,4,6),(0,184,-13),wood,.8)
    jeweler_bench.build("Hero walnut workbench",loc=(0,-2,-75.4),width=124,depth=76,height=75,bench_pin=False,rear_recess=(28,25),seed=4)
    jeweler_bench.build("Balance workbench",loc=(-25,75,-105.4),width=106,depth=62,height=75,seed=7)
    jeweler_bench.build("Chest workbench",loc=(49,101,-118.4),width=72,depth=67,height=75,seed=9)
    bench_lamp.build("Adjustable daylight bench lamp",loc=(-55,75,-30.4),reach=12,height=25,radius=8.7,rot_z=.35,head_tilt=-.65,energy=7500,seed=8)
    balance_scale.build("Brass assay balance",loc=(-15,68,-30.4),height=30,width=29,pan_radius=4.8,rot_z=.05,seed=6)
    gem_case.build("Left open specimen case",loc=(-40,28,-.4),width=18,depth=14,lid_angle=68,seed=3)
    gem_case.build("Right open specimen case",loc=(48,27,-.4),width=18,depth=16,lid_angle=175,seed=7)
    gem_case.build("Work in progress specimen case",loc=(-55,55,-30.4),width=24,depth=17,lid_angle=112,seed=2)
    jeweler_tools.build("Foreground optical loupe",loc=(-32,5,-.4),radius=2.5,seed=4)
    jeweler_tools.build("Foreground steel tweezers",loc=(-34,3,-.42),kind="tweezers",rot_z=-.72,length=15,seed=4)
    jeweler_tools.build("Right spring tweezers",loc=(33,13,-.42),kind="tweezers",rot_z=.4,length=12,seed=8)
    # Pale folded gem papers sit outside the ten-centimetre play margin.
    paper=M.parchment("Folded white gem paper",(.66,.63,.55),3)
    for x,y,angle in ((-40,15,.3),(39,9,-.15)):
        ob=a.block("Folded gem packet",(8,7,.08),(x,y,-.34),paper,.04);ob.rotation_euler.z=angle
        a.add(cut_gem.build("Loose specimen on paper",loc=(x,y,-.29),radius=1.3,tone=(.05,.48,.25),cut="emerald",rot_z=angle,seed=7))
    drawer_chest.build("Many-drawered gem chest",loc=(49,101,-43.4),width=42,depth=26,height=39,columns=3,rows=5,rot_z=-.13,seed=4)
    for i in range(9):
        jeweler_tools.build("Upright precision graver",loc=(32+i*4,101,-4.4),kind="graver",length=14+i%3*3,seed=i)
    a.block("Graver holder base",(38,8,3),(48,101,-2.9),wood,.6)
    lantern.build("Emerald assay lantern",loc=(34,25,-.4),height=18,radius=3.5,chain_length=0,
        metal_finish="brass",glass_tone=(.03,.48,.22),glow_color=(.015,.38,.11),light_color=(.10,1,.38),energy=1100,seed=6)
    atelier_window.build("Sunset city casement",loc=(42,183,-119),width=142,height=136,exterior_slope=.36,energy=150000,seed=11)
    potted_plant.build("Window vine",loc=(-24,168,-131),height=62,radius=8,seed=4)
    shelf.build("Jewel bottles on left shelves",loc=(-126,178,-91),width=90,levels=3,spacing=35,count=5,seed=9)
    for x in (-5,101):candles.build("Sill candle",loc=(x,170,-131),height=11,radius=1.7,energy=950,seed=3)
    for x,y,z in ((-65,89,-30.4),):
        book.build("Unlettered ledger",loc=(x,y,z),width=18,depth=24,thickness=3.4,tone=(.05,.022,.012),seed=4)
    def area(name,loc,target,energy,color,size):
        light=a.light(name,loc,energy,color,size,target,"AREA")
        light.visible_glossy=True;light.data.specular_factor=1
    area("Daylight task pool",(-27,13,40),(-4,5,0),11000,(.82,.91,1),18)
    area("Amber glint on left walnut",(-46,15,28),(-29,8,0),9500,(1,.54,.24),24)
    area("Sunset on workbench",(63,99,38),(-20,15,0),48000,(1,.56,.28),52)
    area("Warm drawer-front return",(47,49,16),(49,94,-23),21000,(1,.66,.37),32)
    area("Sunset on drawers",(32,155,-11),(67,94,-30),70000,(1,.61,.33),58)
    area("Warm wall lamp pool",(-112,127,0),(-89,159,-47),60000,(1,.64,.36),43)
    area("Cool open-window return",(5,134,10),(-16,70,-30),35000,(.48,.65,1),60)
    area("Emerald edge reflection",(48,27,12),(33,-3,0),2200,(.09,1,.36),14)
    receivers=bpy.data.collections.new("Gemcutter environment light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    group=G.Asset("Gemcutter broadside room",rot_z=-math.pi/2+.10)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT" and ob.light_linking.receiver_collection is None:ob.light_linking.receiver_collection=receivers
        if ob!=group.root and ob.parent is None:group.add(ob)
    return dict(loc=(-28,-5,27),target=(0,0,6.2),lens=25,
        fstop=8*scene.unit_settings.scale_length,focus=(0,0,2))
