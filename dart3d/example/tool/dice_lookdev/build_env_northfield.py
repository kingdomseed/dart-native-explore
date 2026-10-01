"""Northfield: a green-screen terminal beside breakfast in a 1986 country kitchen.

The original calibration mat, ABS case and tray lights are preserved. New
room lamps have separate receivers; all breakfast dressing clears the tray.
"""
from __future__ import annotations
import math
import bpy
import env_common as E
import room_common as RC
W,D=E.TRAY_W,E.TRAY_D
RIM_T,RIM_H=2.8,3.0
ABS=(0.78,0.74,0.64)

def mat_grid():
    m, k = E.material("Calibration mat")
    obj = k.coords().outputs["Object"]
    g1 = E.grid_lines(k, obj, 1.0, 0.035)
    g5 = E.grid_lines(k, obj, 5.0, 0.1)
    # dark green self-healing mat with pale grid lines
    col = k.mix(k.math("MAXIMUM", k.math("MULTIPLY", g1, 0.35), g5), (0.03, 0.075, 0.05, 1), (0.55, 0.62, 0.5, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.85, Normal=k.bump(k.noise(obj, 20.0, 2).outputs["Fac"], 0.1, 0.02)))
    return m


def _room_sampling(scene, depsgraph=None):
    if scene.camera and scene.camera.name == "room" and "Northfield broadside room" in scene.objects:
        scene.cycles.filter_width=1.5


def build(scene):
    scene.cycles.filter_width=.2
    scene.view_settings.gamma=.7
    if _room_sampling not in bpy.app.handlers.render_pre:
        bpy.app.handlers.render_pre.append(_room_sampling)
    E.world(scene,color=(0.03,0.035,0.045),strength=1.0)
    E.plane("mat", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.36), mat_grid())
    case = E.simple("Case ABS", ABS, 0.45, Coat_Weight=0.15)
    E.cube("case_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.7), (0, 0, 0), case, bevel=0.3)
    E.rim("rim", W + RIM_T, D + RIM_T, 4.0, RIM_H, RIM_T, case, z0=0.35)
    E.cube("rim_stripe", (W + 2 * RIM_T + 1.2, 0.5, 0.5), (0, -D / 2 - RIM_T - 0.3, 1.7),
           E.simple("Stripe orange", (0.85, 0.3, 0.05), 0.5))
    top=D/2+RIM_T
    cx,cy=-3.0,top+22
    E.light(scene, "AREA", "crt_glow", (cx, cy - 10, 12.5), 400, color=(0.3, 1.0, 0.45), size=14,
            target=(cx, 0, 2), shadow=False)
    E.light(scene, "AREA", "lamp", (6, 10, 62), 30000, color=(1.0, 0.8, 0.55), size=24, target=(0, 0, 0))
    E.light(scene, "AREA", "dusk", (0, top + 75, 45), 8000, color=(0.6, 0.7, 1.0), size=60, target=(0, 0, 0))
    return dict(samples=128,exposure=.7,hero=dict(dist=32,elev=30,az=8,lens=65,fstop=2.8),
        topdown=dict(width=W+2*RIM_T+3),play_view=True,
        hero_layout={"d20":((-4.8,-5),18,8),"d12":((-3.6,4.6),11,-14),
                     "d10u":((2.6,8),9,12),"d10t":((2.2,-1),40,-6),
                     "d8":((2.2,-10.5),5,16),"d6":((1,-6.5),3,-9),"d4":((-3.6,10.8),3,22)},
        tray_half=(W/2+RIM_T,D/2+RIM_T),room_cam=room(scene))


def room(scene):
    from assets import (geometry as G,materials as M,laminate_table,crt_terminal,portable_radio,
        kitchen_unit,kettle,countryside_window,potted_plant,dining_chair,coffee_mug,
        breakfast_plate,dome_pendant,velvet_drape,vessel)
    before=set(bpy.data.objects)
    a=G.Asset("Northfield kitchen architecture")
    floor=-146
    laminate_table.build("Breakfast laminate table",loc=(0,0,-75.35),width=113,depth=84,height=75,
        wood_tone=(.14,.057,.014),seed=2)
    laminate_table.build("Terminal side table",loc=(-63,108,-95.35),width=64,depth=86,height=75,
        wood_tone=(.16,.065,.022),seed=7)
    crt_terminal.build("Beige green-screen terminal",loc=(-61,104,-20.35),rot_z=.12,seed=5,energy=1800)
    dining_chair.build("Chair behind breakfast",loc=(8,70,-75.35),rot_z=math.pi,height=79,width=37,seed=5)
    coffee_mug.build("Floral breakfast mug",loc=(-31,28,-.35),rot_z=math.pi,height=10,radius=4.2,
        tone=(.64,.58,.41),floral=True,steam_height=10,steam_opacity=.12,seed=7)
    breakfast_plate.build("Butter toast breakfast",loc=(-39,17,-.35),radius=10.5,rot_z=.28,seed=8)
    velvet_drape.build("Woven kitchen runner",loc=(43,-7,-.35),width=22,length=80,drop=18,
        tone=(.37,.34,.23),stars=0,fabric="wool",heap=.08,seed=2)
    # The background stands on a lower kitchen bay, connected by shallow steps.
    lino=RC.tiles("Faded kitchen linoleum",(.17,.19,.105),(.31,.29,.22),scale=.055)
    a.block("Dining floor",(460,180,5),(0,-14,-77.85),lino,.3)
    a.block("Terminal landing",(460,82,5),(0,117,-97.85),lino,.3)
    a.block("Chair landing extension",(59,23,20),(8,87.5,-85.35),lino,.3)
    a.block("Radio stand dais",(65,42,6),(79,138,-92.35),lino,.3)
    a.block("Kitchen floor",(460,230,5),(0,273,floor-2.5),lino,.3)
    for i in range(2):a.block("Dining landing step",(70,15,10),(-183,83.5+i*15,-80.35-i*10),lino,.3)
    for i in range(5):a.block("Kitchen bay step",(60,13,10.13),(200,164.5+i*13,-100.415-i*10.13),lino,.3)
    wallpaper=M.retro_flower("Ochre daisy wallpaper",(.39,.32,.19),(.21,.105,.025),scale=.042,seed=4)
    wall=RC.wall_plane("Kitchen back wall",480,270,((109,145,128,140),),wallpaper,thickness=6)
    a.add(wall);wall.location=(0,242,floor)
    a.block("Kitchen side wall",(5,360,270),(-237,70,floor+135),wallpaper,.2)
    skirting=M.aged_plastic("Cream skirting",(.48,.43,.30),.45,2)
    a.block("Back skirting",(480,3,12),(0,238,floor+6),skirting,.4)
    for x in (-118,-56,68):kitchen_unit.build("Fitted cream cupboard",loc=(x,209,floor),width=60,seed=int(x)%11)
    kitchen_unit.build("Enamel electric cooker",loc=(6,209,floor),kind="cooker",width=60,seed=7)
    kitchen_unit.build("Two-door refrigerator",loc=(-191,206,floor),kind="fridge",width=66,depth=66,height=171,seed=8)
    for x in (-118,-56):kitchen_unit.build("High wall cupboard",loc=(x,225,floor+145),width=60,depth=30,height=67,seed=12)
    kettle.build("Orange enamel kettle",loc=(-9,198,floor+88.3),radius=8,height=19,rot_z=-.8,seed=9)
    vessel.build("Utensil crock",loc=(-80,207,floor+88.3),kind="jug",height=17,radius=5.2,tone=(.21,.12,.048),seed=4)
    steel=M.polished_metal("Kitchen utensil steel",(.4,.44,.43),.4,3)
    for i in range(5):
        a.tube("Wooden spoon stem",[(-84+i*1.7,208,floor+90),(-86+i*2.2,208,floor+115+i%2*4)],.32,steel)
        a.sphere("Spoon bowl",1.7,(-86+i*2.2,208,floor+115+i%2*4),steel,scale=(.8,.22,1.4))
    # Patterned splashback tiles have real grout channels and a restrained glaze.
    tile=M.retro_flower("Glazed amber flower tile",(.53,.43,.25),(.30,.13,.025),scale=.065,ceramic=True,seed=3)
    for ix in range(13):
        for iz in range(4):a.block("Separate splashback tile",(14.7,.8,14.7),(-143+ix*15,237,floor+96+iz*15),tile,.12)
    countryside_window.build("Kitchen field window",loc=(109,234,-71),width=122,height=134,machine_x=700,machine_height=460,exterior_slope=.2,seed=8)
    potted_plant.build("Sill pilea",loc=(139,220,-80),height=28,radius=6,seed=8)
    potted_plant.build("Terminal plant",loc=(-91,130,-20.35),height=30,radius=6,seed=3)
    laminate_table.build("Radio stand",loc=(79,138,-89.35),width=58,depth=37,height=66,seed=5)
    portable_radio.build("Radio cassette by the window",loc=(78,137,-23.35),rot_z=-.13,width=30,height=18,antenna=24,seed=6)
    dome_pendant.build("Orange enamel pendant",loc=(-4,83,8),radius=22,height=15,drop=100,
        finish="enamel",recessed_bulb=True,tone=(.50,.14,.025),energy=50000,color=(1,.73,.41),seed=3)
    strip=E.emissive("Warm cupboard strip",(1,.67,.26),4)
    a.block("Under-cupboard warm diffuser",(109,3,1),(-87,204,floor+144),strip,.15)
    def area(name,loc,target,energy,color,size):
        light=a.light(name,loc,energy,color,size,target,"AREA")
        light.visible_glossy=True;light.data.specular_factor=1
    area("Pendant glow on breakfast",(-4,34,48),(-12,0,0),6000,(1,.76,.43),32)
    area("Pendant reflection on terminal",(-10,100,41),(-57,78,-17),38000,(1,.77,.48),42)
    area("Window daylight in kitchen",(108,213,24),(-14,150,-44),150000,(.60,.72,1),95)
    area("Window edge on breakfast",(58,100,30),(8,5,0),20000,(.57,.72,1),55)
    area("Warm counter strip",(-86,202,-2),(-64,211,-64),30000,(1,.68,.31),77)
    area("Kitchen ceiling bounce",(-70,162,16),(-75,220,-59),28000,(1,.85,.63),95)
    area("Window on field",(110,246,190),(450,700,-155),1400000,(.65,.76,1),500)
    receivers=bpy.data.collections.new("Northfield environment light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    group=G.Asset("Northfield broadside room",rot_z=-math.pi/2+.12)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT" and ob.light_linking.receiver_collection is None:ob.light_linking.receiver_collection=receivers
        if ob!=group.root and ob.parent is None:group.add(ob)
    return dict(loc=(-34,-6,28),target=(0,0,8.2),lens=27.7,
        fstop=8*scene.unit_settings.scale_length,focus=(0,0,2))
