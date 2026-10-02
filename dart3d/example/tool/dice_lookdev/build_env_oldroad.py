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
        hero_layout={"d20":((-4.4,-3),18,8),"d12":((-3.6,4.6),11,-14),
                     "d10u":((2.6,8),9,12),"d10t":((2.2,-1),40,-6),
                     "d8":((2.2,-10.5),5,16),"d6":((1,-6.5),3,-9),"d4":((-3.6,10.8),3,22)},
        play_view=True,tray_half=(W/2+RIM_T,D/2+RIM_T),room_cam=room(scene))


def room(scene):
    """A broadside lantern table above a shallow stepped inn sitting bay."""
    from assets import (geometry as G,materials as M,oak_table,timber_wall,cottage_window,
        hearth_fireplace,tavern_chair,travel_pack,walking_staff,hurricane_lantern,
        clay_pipe,bread_board,vessel,velvet_drape,fur_throw,barrel,shelf,candlestick,table_wear)
    before=set(bpy.data.objects)
    a=G.Asset("Wayfarer inn architecture")
    timber=M.oak("Inn dark oak floor",(.085,.038,.014),.8,13,grain_scale=1.5)
    table=oak_table.build("Wayfarer tavern table",loc=(0,-15,-76.35),width=110,depth=92,height=76.69,
        thickness=5,wood_tone=(.025,.010,.0035),wear=.92,scorch=.17,grain_scale=1.15,finish="weathered",
        leg_width=6,leg_inset=(12,12),seed=11)
    for ob in table.children:
        if ob.name.startswith(("Shallow work scar","Old heat stain")):ob.hide_render=True
    table_wear.build("Tavern knife marks and cup rings",loc=(0,0,.34),width=110,depth=38,quiet=(31,23),wear=.95,seed=41)
    a.block("Raised table floor",(330,120,8),(0,-30,-80.35),timber,.5)
    a.block("Inn sitting bay floor",(440,500,8),(0,180,-139),timber,.5)
    for i in range(5):
        top=-76-i*11.8
        a.block("Oak descending step",(75,18,11.8),(-145,39+i*18,top-5.9),timber,.7)
    timber_wall.build("Rear half-timber wall",loc=(0,277,-178),width=420,height=270,bays=6,
        openings=((-80,85,96,105),),tone=(.21,.15,.09),wood_tone=(.035,.014,.005),seed=5)
    timber_wall.build("Inn left return",loc=(-208,161,-178),rot_z=math.pi/2,width=230,height=270,bays=3,seed=8)
    timber_wall.build("Inn right return",loc=(208,161,-178),rot_z=math.pi/2,width=230,height=270,bays=3,wood_tone=(.035,.014,.005),tone=(.21,.15,.09),seed=11)
    window=cottage_window.build("Blue-hour village window",loc=(-80,269,-93),width=96,height=105,panes=3,rows=3,
        density=0,drop_radius=.1,sky_colors=((.26,.12,.065),(.11,.105,.16),(.018,.044,.10)),sky_strength=1.45,
        exterior_slope=.7,town_altitude=136,sky_horizon=.65,seed=7)
    dusk_roofs=E.simple("Village roofs in dusk air",(.055,.062,.09),.9,
        Emission_Color=(.046,.059,.095,1),Emission_Strength=.55)
    dusk_windows=E.simple("Small village lamplight",(.5,.20,.055),.7,
        Emission_Color=(1,.42,.12,1),Emission_Strength=.8)
    for ob in window.children_recursive:
        if ob.name.startswith(("Distant cottage","Slate pitched roof")):
            ob.data.materials.clear();ob.data.materials.append(dusk_roofs)
        elif ob.name.startswith("Tiny warm window"):
            ob.data.materials.clear();ob.data.materials.append(dusk_windows)
    hearth_fireplace.build("Right-hand inn hearth",loc=(104,210,-108.8),width=132,depth=60,height=176,
        hearth_height=40,stone_tone=(.032,.023,.015),energy=125000,rugged=True,flame_height=1.35,seed=12)
    a.block("Stone hearth foundation",(142,75,25),(104,210,-122.5),M.stone("Hearth foundation",(.035,.027,.017),.8,14),1)
    tavern_chair.build("Chair for the travel pack",loc=(7,71,-85),width=52,depth=49,seat_height=45,height=94,seed=7)
    travel_pack.build("Canvas pack and rolled blanket",loc=(7,69,-40.975),rot_z=-.20,width=42,depth=26,height=42,buckle_height=.75,cup_height=.95,
        leather_tone=(.055,.018,.006),roll_tone=(.025,.038,.017),seed=4)
    staff=walking_staff.build("Staff resting on chair",loc=(49,103,-84.75),height=154,seed=4)
    staff.rotation_euler.x=.03;staff.rotation_euler.y=-.08
    tavern_chair.build("Hearth low stool",loc=(110,130,-67),width=43,depth=35,seat_height=43,back=False,seed=13)
    a.block("Raised hearth seat landing",(64,61,68),(110,130,-101),timber,.7)
    fur_throw.build("Worn sheepskin on stool",loc=(110,130,-24),width=47,length=53,drop=19,strands=3500,
        tone=(.16,.12,.075),seed=7)
    a.block("Chair and stool landing",(88,96,50),(7,92,-110),timber,.7)
    barrel.build("Inn coopered barrel",loc=(-158,234,-135),radius=24,height=80,seed=5)
    shelf.build("Inn crockery shelf",loc=(-181,267,-62),width=72,depth=20,levels=2,spacing=37,seed=15)
    oak_table.build("Hearth candle table",loc=(42,224,-75),width=46,depth=39,height=65,thickness=3,
        leg_width=4,leg_inset=(7,7),scorch=0,seed=17)
    a.block("Side table landing",(58,53,60),(42,224,-105),timber,.6)
    candlestick.build("Candle beside hearth",loc=(42,221,-10),height=4,radius=3,candle_height=10,candle_radius=1.8,
        energy=4500,metal_finish="pewter",seed=13)
    vessel.build("Inn side table jug",loc=(54,231,-10),kind="jug",height=18,radius=5.3,tone=(.13,.078,.035),seed=8)
    hurricane_lantern.build("Tin lantern on the table",loc=(-29.5,25,.55),height=22,radius=5.6,
        metal_finish="iron",energy=7200,flame_strength=100,flame_width=1.5,seed=7)
    vessel.build("Coopered travelling tankard",loc=(-47,23,.55),rot_z=math.pi,kind="wooden_tankard",height=14,radius=4.6,
        tone=(.10,.047,.017),metal_finish="iron",seed=9)
    vessel.build("Right pewter tankard",loc=(30,222,-10),rot_z=.5,kind="tankard",height=10,radius=3.6,
        metal_finish="pewter",seed=5)
    bread_board.build("Country bread and trencher",loc=(37,10.5,.34),rot_z=math.pi/2,width=18,depth=12,loaf_height=5.4,seed=9)
    velvet_drape.build("Fringed travel plaid",loc=(-39,8,.34),width=24,length=44,drop=0,heap=3.8,sweep=5,
        tone=(.18,.037,.023),stars=0,fabric="wool",weave=True,edge_fraction=.20,rest_patches=((9.5,17,9),(-8,15,7),(8,8,5),(0,8,8),(-7,8,8)),seed=3)
    clay_pipe.build("Resting briar pipe",loc=(-31,16,.60),rot_z=math.pi,length=16,bowl_height=4.5,radius=2.15,finish="briar",tone=(.11,.028,.008),seed=6)
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get();verts=[];faces=[]
    cloth=bpy.data.objects["Fringed travel plaid"]
    for ob in cloth.children_recursive:
        if ob.type not in {"MESH","CURVE"}:continue
        ev=ob.evaluated_get(deps);mesh=ev.to_mesh();mesh.calc_loop_triangles();offset=len(verts)
        verts.extend(ob.matrix_world@v.co for v in mesh.vertices)
        faces.extend(tuple(offset+i for i in t.vertices) for t in mesh.loop_triangles)
        ev.to_mesh_clear()
    support=BVHTree.FromPolygons(verts,faces,all_triangles=True)
    for name in ("Tin lantern on the table","Coopered travelling tankard"):
        root=bpy.data.objects[name];points=[]
        for ob in root.children_recursive:
            if ob.type not in {"MESH","CURVE"}:continue
            ev=ob.evaluated_get(deps);mesh=ev.to_mesh()
            points.extend(ob.matrix_world@v.co for v in mesh.vertices);ev.to_mesh_clear()
        low=min(p.z for p in points);offsets=[]
        for p in points:
            if p.z>low+.8:continue
            hit,_,_,_=support.ray_cast(p+Vector((0,0,10)),Vector((0,0,-1)),20)
            if hit is not None:offsets.append(hit.z-p.z)
        if offsets:root.location.z+=max(offsets)+.095
    def area(name,loc,target,energy,color,size):
        light=a.light(name,loc,energy,color,size,target=target,kind="AREA")
        light.visible_glossy=True;light.data.specular_factor=1
        return light
    area("Lantern pool on oak",(-29.5,24,13),(-24,0,.34),11500,(1,.56,.23),12)
    area("Lantern on travel gear",(-34,38,4),(7,69,-22),58000,(1,.62,.30),30)
    area("Dusk through window",(-76,256,-64),(7,69,-22),65000,(.42,.56,1),65)
    area("Fire on pack leather",(80,175,-40),(7,69,-22),70000,(1,.46,.16),42)
    area("Fire on bound staff",(82,120,30),(40,100,25),14000,(1,.50,.17),18)
    area("Fire pool on plaster",(77,174,-41),(103,275,-35),90000,(1,.52,.22),48)
    area("Blue edge on table",(-60,128,19),(17,18,0),4500,(.43,.59,1),35)
    receivers=bpy.data.collections.new("Oldroad environment light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    group=G.Asset("Oldroad broadside room",rot_z=-math.pi/2+.14)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT" and ob.light_linking.receiver_collection is None:ob.light_linking.receiver_collection=receivers
        if ob!=group.root and ob.parent is None:group.add(ob)
    bpy.context.view_layer.update()
    for ob in table.children:
        if ob.type=="MESH" and ob.name.startswith(("Oak plank","Dark recessed plank joints")):
            cut=ob.modifiers.new("Concealed map board bedding","BOOLEAN")
            cut.operation="DIFFERENCE";cut.object=bpy.data.objects["map_board"]
    excluded=bpy.data.collections.new("Hearth gold-return exclusions")
    for ob in bpy.data.objects:
        if ob.type in {"MESH","CURVE"}:excluded.objects.link(ob)
    for entry in excluded.collection_objects:entry.light_linking.link_state="EXCLUDE"
    reflection=E.light(scene,"AREA","Hearth reflected on polished gold",(45,6,35),2000,
                       color=(1,.86,.66),size=24,target=(0,0,1))
    reflection.light_linking.receiver_collection=excluded
    return dict(loc=(-17,-4,14),target=(2,0,4.5),lens=19.5,
        fstop=6.3*scene.unit_settings.scale_length,focus=(-3,0,1.4))
