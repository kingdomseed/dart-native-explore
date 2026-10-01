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
        scene.view_settings.gamma=.95
        scene.view_settings.exposure=.25


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
        hero_layout={"d20":((-2.5,0),18,8),"d12":((-2.8,9.5),11,-14),
                     "d10u":((3.5,-9.5),9,12),"d10t":((-2,-9.5),40,-6),
                     "d8":((3.7,10.8),5,16),"d6":((2,-2),3,-9),"d4":((4.1,4.9),3,22)},
        tray_half=(W/2+RIM_T,D/2+RIM_T),room_cam=room(scene))


def room(scene):
    from assets import (geometry as G,materials as M,jeweler_bench,bench_lamp,balance_scale,
        gem_case,cut_gem,jeweler_tools,drawer_chest,atelier_window,lantern,book,shelf,candles,
        potted_plant,gem_scatter,loupe_stand,mineral_display,jeweler_tool_rack,bench_patina)
    before=set(bpy.data.objects)
    a=G.Asset("Atelier architecture")
    floor=-130
    wood=M.oak("Atelier panelling",(.065,.022,.009),.75,4,axis="Z")
    plaster=M.limewash("Warm atelier plaster",(.18,.115,.069),.6,3)
    a.block("Oak atelier floor",(420,410,5),(0,100,floor-2.5),RC.planks("Atelier boards"),.3)
    a.block("Player floor landing",(300,100,54.6),(0,-20,-102.7),wood,.4)
    a.block("Balance bay landing",(116,64,24.6),(0,65,-117.7),wood,.4)
    a.block("Chest bay landing",(78,69,11.6),(44,96,-124.2),wood,.4)
    for i in range(4):a.block("Workshop level step",(38,14,13.65),(-100,37+i*14,-82.225-i*13.65),wood,.4)
    wall=RC.wall_plane("Panelled atelier back wall",400,260,((16,140,180,180),),plaster,thickness=7)
    a.add(wall);wall.location=(0,172,floor)
    a.block("Atelier side wall",(6,400,260),(-198,0,0),plaster,.3)
    for x in range(-186,197,38):
        a.block("Walnut wall pilaster",(4,3,234),(x,167,-9),wood,.5)
        if x< -84 or x>114:a.block("Recessed oak wall panel",(31,1,64),(x+19,168,-52),wood,.4)
    a.block("Panelled dado rail",(400,4,6),(0,166,-13),wood,.8)
    top=.402
    desk=jeweler_bench.build("Hero walnut workbench",loc=(0,-2,-75.4),width=112,depth=82,height=75.802,
        wood_tone=(.073,.027,.010),wear=.9,bench_pin=False,seed=4)
    for ob in desk.children_recursive:
        if ob.name.startswith(("Old heat stain","Shallow work scar")):
            ob.hide_render=True
        if ob.name.startswith("Oak plank"):
            for mat in ob.data.materials:
                for node in mat.node_tree.nodes:
                    if node.type=="BSDF_PRINCIPLED":node.inputs["Coat Weight"].default_value=.1
    bench_patina.build(loc=(0,-2,top),width=102,depth=78,quiet=(29,25),seed=7)
    jeweler_bench.build("Balance workbench",loc=(0,74,-105.4),width=96,depth=66,height=99.802,seed=7)
    jeweler_bench.build("Chest workbench",loc=(43,77,-118.4),width=66,depth=60,height=103.4,seed=9)
    bench_lamp.build("Adjustable daylight bench lamp",loc=(-35,52,-5.598),reach=11,height=28,radius=11.5,
        rot_z=.6,head_tilt=-.45,energy=9000,color=(.94,.96,1),seed=8)
    balance_scale.build("Brass assay balance",loc=(0,85,-5.598),height=22,width=26,pan_radius=5.3,rot_z=.04,seed=6)
    gem_case.build("Left open specimen case",loc=(-19,34,top),rot_z=0,width=17,depth=13,height=3,lid_angle=158,columns=4,rows=3,seed=3)
    gem_case.build("Right open specimen case",loc=(22,30,top),rot_z=0,width=18,depth=13,height=3,lid_angle=150,columns=4,rows=3,seed=7)
    jeweler_tools.build("Foreground optical loupe",loc=(-23,24,top),radius=2.6,seed=4)
    jeweler_tools.build("Foreground steel tweezers",loc=(-33,27,top-.015),kind="tweezers",rot_z=math.pi/2,length=12,seed=4)
    for i in range(2):
        tool=jeweler_tools.build("Resting pear-handled graver",loc=(-40,20+i*3.5,top+1.55),kind="graver",length=9+i,seed=13+i)
        tool.rotation_euler=(math.pi/2,0,math.pi/2)
    loupe_stand.build("Mounted inspection loupe",loc=(-5,33,top),height=13,radius=2.1,rot_z=-.2,seed=5)
    mineral_display.build("Rough emerald on velvet",loc=(-33,33,top),radius=4.4,height=7.8,seed=6)
    occupied=[(-19,34,9,7),(22,30,10,7),(-23,24,3.3,3.3),(-36,23,6,5),(-33,27,6.5,1.2),(-33,33,4.8,4.8),(-5,33,4.2,4.2),(36,34,4,4)]
    gem_scatter.build("Left sorting spill",loc=(-29,26,top+.025),width=19,depth=6,count=35,radius=(.4,1.15),quiet=(29,22),occupied=occupied,seed=19)
    gem_scatter.build("Right sorting spill",loc=(30,25,top+.025),width=17,depth=8,count=32,radius=(.4,1.25),quiet=(29,22),occupied=occupied,seed=26)
    gem_scatter.build("Rear diamond sorting",loc=(0,27,top+.025),width=42,depth=9,count=26,radius=(.4,1.0),quiet=(29,22),occupied=occupied,seed=9)
    paper=M.parchment("Folded white gem paper",(.43,.39,.31),3)
    for x,y,angle in ((-38,5,.3),(39,5,-.15)):
        ob=a.block("Folded gem packet",(7,6,.06),(x,y,top+.03),paper,.04);ob.rotation_euler.z=angle
        a.add(cut_gem.build("Loose specimen on paper",loc=(x,y,top+.07),radius=1.1,tone=(.02,.36,.16),cut="emerald",ior=1.59,glints=2,rot_z=angle,seed=7))
    drawer_chest.build("Many-drawered gem chest",loc=(43,70,-15),width=34,depth=25,height=25,columns=3,rows=5,rot_z=-.12,seed=4)
    jeweler_tool_rack.build("Precision graver and plier rack",loc=(42,70,10),width=25,height=10,rot_z=-.12,seed=8)
    lantern.build("Emerald assay lantern",loc=(36,34,top),height=15,radius=3.3,chain_length=0,
        metal_finish="brass",glass_tone=(.03,.48,.22),glow_color=(.015,.38,.11),light_color=(.10,1,.38),energy=800,seed=6)
    atelier_window.build("Sunset city casement",loc=(16,165,-75),width=170,height=170,exterior_slope=.44,
        energy=60000,sky_strength=1.5,city_style="spires",town_altitude=60,sky_altitude=170,seed=11)
    for x,h in ((-58,65),(84,58)):
        potted_plant.build("Sill climbing green",loc=(x,155,-84.5),height=h,radius=6,seed=4+int(h))
    shelf.build("Jewel bottles on left shelves",loc=(-115,159,-91),width=82,levels=3,spacing=32,count=5,seed=9)
    for i,x in enumerate((-28,37,53)):
        candles.build("Sunset sill candle",loc=(x,156,-84.5),height=12+i*3,radius=1.6,energy=900,seed=3+i)
    book.build("Unlettered ledger",loc=(-32,82,-5.598),width=18,depth=24,thickness=3.4,tone=(.05,.022,.012),seed=4)
    def area(name,loc,target,energy,color,size):
        light=a.light(name,loc,energy,color,size,target,"AREA")
        light.visible_glossy=True;light.data.specular_factor=1
        return light
    area("Daylight task pool",(-27,22,29),(-24,15,0),11000,(.90,.95,1),10)
    area("Amber sunset pool on walnut",(44,72,17),(-25,18,0),24000,(1,.49,.20),23)
    area("Warm drawer-front return",(30,39,4),(43,79,-23),6500,(1,.58,.26),14)
    area("Wall candle reflected warmth",(-92,125,-13),(-99,155,-43),32000,(1,.54,.25),28)
    area("Small gem inspection glint",(-17,35,20),(-29,19,0),2800,(.84,.94,1),2)
    area("Emerald edge reflection",(38,26,10),(30,3,0),1600,(.09,1,.36),8)
    receivers=bpy.data.collections.new("Gemcutter environment light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    group=G.Asset("Gemcutter broadside room",rot_z=-math.pi/2+.10)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT" and ob.light_linking.receiver_collection is None:ob.light_linking.receiver_collection=receivers
        if ob!=group.root and ob.parent is None:group.add(ob)
    velvet_receivers=bpy.data.collections.new("Gemcutter velvet grazing receivers")
    for ob in tuple(bpy.data.objects):
        if ob.name in {"velvet","rim"} and ob.type=="MESH":velvet_receivers.objects.link(ob)
    grazing=E.light(scene,"AREA","Low task reflection on velvet",(13,16,5),3500,color=(1,.72,.44),size=7,target=(0,0,1))
    grazing.light_linking.receiver_collection=velvet_receivers
    return dict(loc=(-18,-2,16),target=(3,0,7),lens=21.5,
        fstop=8*scene.unit_settings.scale_length,focus=(-3,0,1.6))
