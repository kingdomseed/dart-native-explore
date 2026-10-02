"""Vermilion Court: a lantern-lit pavilion opening onto mountains at dusk.

The preserved black lacquer tray sits on a low table. Gold-leaf pine screens,
washi lanterns, tatami and a cherry-framed veranda surround a clean play area.
"""
from __future__ import annotations
import math
import bpy
import env_common as E
import env_props as P

W,D=E.TRAY_W,E.TRAY_D
RIM_T,RIM_H=2.2,2.4


def lacquer_floor():
    m, k = E.material("Black lacquer + gold dust")
    obj = k.coords().outputs["Object"]
    wave = k.node("ShaderNodeTexWave", wave_type="RINGS", rings_direction="SPHERICAL")
    k.link(obj, wave.inputs["Vector"])
    k.set(wave, Scale=0.12, Distortion=1.5, Detail=2.0)
    band = k.math("LESS_THAN", k.math("ABSOLUTE", k.math("SUBTRACT", wave.outputs["Fac"], 0.5)), 0.03)
    dust = k.math("LESS_THAN", k.voronoi(obj, 6.0).outputs["Distance"], 0.05)
    gold_amt = k.math("MAXIMUM", k.math("MULTIPLY", band, 0.8), k.math("MULTIPLY", dust, 0.5))
    # coat a little softer than round 1 so the lanterns don't mirror as big
    # white discs in the play area at top-down
    lac = k.bsdf(Base_Color=(0.006, 0.004, 0.004, 1), Roughness=0.5, Coat_Weight=0.5, Coat_Roughness=0.35)
    gold = k.bsdf(Base_Color=(1.0, 0.75, 0.32, 1), Metallic=1.0, Roughness=0.3)
    k.surface(k.mix_shader(gold_amt, lac, gold))
    return m



def build(scene):
    E.world(scene, color=(0.006, 0.004, 0.006), strength=1.0)
    E.plane("tray_floor", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 1.21), lacquer_floor())
    lac = E.simple("Tray lacquer", (0.008, 0.005, 0.005), 0.2, Coat_Weight=1.0, Coat_Roughness=0.01)
    E.cube("tray_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 1.2), (0, 0, 0.6), lac, bevel=0.3)
    E.rim("rim", W + RIM_T, D + RIM_T, 1.5, RIM_H, RIM_T, lac, z0=1.2)
    E.rim("rim_gilt", W + RIM_T, D + RIM_T, 1.5, 0.3, 0.5, P.brass("Gilt", worn=0.1, color=(1.0, 0.78, 0.35)),
          z0=RIM_H + 1.25)
    # moon: unshadowed (round 1: the folding screen shadowed half the tray)
    E.light(scene, "AREA", "moon", (40, 60, 80), 2500, color=(0.55, 0.6, 1.0), size=40, target=(0, 0, 0),
            shadow=False)
    # key from the side: its mirror image in the lacquer lands off the tray
    E.light(scene, "AREA", "key", (-46, -12, 36), 9600, color=(1.0, 0.75, 0.55), size=25, target=(0, 0, 0))
    # Round 2: soft warm overhead (a paper ceiling lamp) for the gold leaf,
    # which mirrors the ceiling when seen straight down.
    E.overhead(scene, 1500, color=(1.0, 0.82, 0.62), size=90, height=110)
    return dict(samples=128,exposure=1.3,topdown=dict(width=W+2*RIM_T+1),surface_z=1.2,centre=(0,2,2.2),
        hero=dict(dist=32,elev=30,az=8,lens=65,fstop=2.8),
        hero_layout={"d20":((-1.8,-2),20,0),"d12":((-1.3,9),12,12),
            "d10u":((4,-11),0,-15),"d10t":((4,7),0,20),
            "d8":((-1,-9),8,-10),"d6":((4,-2.5),6,18),"d4":((4,1.5),4,58)},
        play_view=True,tray_half=(W/2+RIM_T,D/2+RIM_T),room_cam=room(scene))


def room(scene):
    """Low lacquer tea platform, warm paper pools and a dusk veranda."""
    from assets import (geometry as G, materials as M, pavilion_lantern, tatami_mat,
        shoji_screen, byobu_screen, lacquer_table, zabuton, tea_service,
        cherry_branch, pavilion_vista, stone_lantern, maki_e)
    before=set(bpy.data.objects)
    a=G.Asset("Pavilion joinery")
    wood=M.oak("Smoked cedar posts",(.040,.015,.006),.4,3,axis="Z")
    red=M.urushi("Vermilion veranda lacquer",(.25,.018,.009),.45,6)
    gold=M.metal("Pavilion bronze caps","brass",.4,4)
    lacquer_table.build("Player low table",loc=(0,0,-32),width=112,depth=47,
        height=33.12,polish=.7,wear=.23,seed=4)
    table_top=bpy.data.objects["Rounded solid lacquer top"]
    bed=table_top.modifiers.new("Close fitted tray bedding","BOOLEAN")
    bed.operation="DIFFERENCE";bed.object=bpy.data.objects["tray_base"]
    tea_service.build("Left maki-e tea bowl",loc=(-29.5,19.3,1.12),radius=3.8,height=6.5,blossoms=True,seed=7)
    tea_service.build("Tea caddy",loc=(29.5,19.3,1.12),kind="caddy",radius=3.8,height=7,blossoms=True,seed=8)
    tea_service.build("Right tea bowl",loc=(34.5,-1,1.12),radius=5.3,height=5.5,blossoms=True,seed=10)
    tea_service.build("Pleated vermilion fan",loc=(-45,-4,1.02),rot_z=-.45,kind="fan",radius=13,seed=6)
    cherry_branch.build("Left table petals",loc=(-35,14,1.12),kind="petals",width=4,height=14,count=11,seed=3)
    cherry_branch.build("Right table petals",loc=(33,13,1.12),kind="petals",width=4,height=20,count=9,seed=4)
    fallen=E.simple("Pale fallen blossom petals",(.72,.32,.37),.56,Subsurface_Weight=.18)
    cherry_branch.blossom_mesh(a,[((x,22.1+.35*math.sin(x),1.123),.50+.12*math.cos(x))
        for x in (-9,-7,-2,1,5,9,12,16,20,23)],fallen,seed=29,petals=1,normal=(0,0,1))
    # Each landing supports its lanterns and screens; the tea table has a straight far edge.
    a.block("Tea platform foundation",(420,145,12),(0,-7.5,-42.5),wood,.7)
    for ix in range(5):
        tatami_mat.build("Tea platform tatami",loc=(-180+90*ix,-7.5,-36.5),width=89.6,depth=144.6,seed=ix*3)
    for y,z in ((72,-45),(85,-58)):
        a.block("Tea landing step",(430,13,13),(0,y,z-6.5),wood,.4)
    a.block("Lantern landing foundation",(430,34,8),(0,108.5,-66.5),wood,.5)
    for ix in range(5):
        tatami_mat.build("Lantern landing tatami",loc=(-180+90*ix,108.5,-62.5),width=89.6,depth=33.6,seed=ix*5)
    for y,z in ((131,-80.5),(143,-103)):
        a.block("Screen landing step",(430,12,22.5),(0,y,z-11.25),wood,.4)
    a.block("Screen platform foundation",(430,62,8),(0,180,-111.5),wood,.5)
    for ix in range(5):
        tatami_mat.build("Screen landing tatami",loc=(-180+90*ix,180,-107.5),width=89.6,depth=61.6,seed=ix*5+1)
    a.block("Veranda threshold step",(430,14,5),(0,218,-105.5),wood,.4)
    a.block("Raised tatami seating dais",(430,40,8),(0,80,-28.5),wood,.5)
    for i in range(5):
        tatami_mat.build("Raised seating tatami",loc=(-172+86*i,80,-24.5),width=39.6,depth=85.6,rot_z=math.pi/2,seed=9+i,tone=(.34,.26,.12))
    for y,z in ((49,-28),(56,-24)):
        a.block("Seat dais step",(430,7,4),(0,y,z-2),wood,.4)
    zabuton.build("Left silk seat",loc=(-41,80,-20),width=38,depth=35,height=7,rot_z=.15,seed=8)
    zabuton.build("Right silk seat",loc=(89,17,-32),width=48,depth=47,height=7,rot_z=-.18,seed=4,tone=(.11,.013,.009))
    lacquer_table.build("Low tea service stand",loc=(13,85,-20),width=20,depth=22,height=12,gilt=True,seed=8)
    byobu_screen.build("Gold-leaf blossom folding screen",loc=(-91,166,-103),panels=4,panel_width=37,height=97,fold=.25,blossoms=True,seed=3)
    pavilion_lantern.build("Left andon floor lantern",loc=(-63,113,-58),height=60,radius=12.5,energy=16000,glow=.55,seed=6)
    pavilion_lantern.build("Red hanging chochin",loc=(100,155,-48),kind="chochin",height=47,radius=16,tone=(.62,.022,.008),glow=.95,energy=14000,drop=140,seed=2)
    pavilion_lantern.build("Ceiling paper reflection lantern",loc=(-4,87,19),kind="chochin",height=30,radius=7,
        tone=(.9,.52,.16),glow=.45,energy=1600,drop=65,seed=14)
    pavilion_lantern.build("Veranda small andon",loc=(9,186,-103),height=30,radius=6,energy=2000,glow=.7,seed=5)
    shoji_screen.build("Left sliding shoji",loc=(-185,174,-103),width=72,height=172,seed=7)
    shoji_screen.build("Partly opened shoji",loc=(-31,205,-103),width=61,height=177,seed=4)
    shoji_screen.build("Right sliding shoji",loc=(186,205,-103),width=66,height=177,seed=5)
    for x in (-225,-34,38,158,221):
        a.block("Chamfered cedar pillar",(9,9,224),(x,211,9),wood,.75)
        a.block("Pillar foot shoe",(11,11,5),(x,211,-100.5),gold,.45)
    for z in (-101,78):a.block("Grooved shoji track",(490,12,5),(14,205,z),wood,.4)
    a.block("Lintel under ceiling",(490,17,17),(14,205,102),wood,.7)
    for x in range(-225,260,45):a.block("Overhead cedar rafter",(6,410,10),(x,92,114),wood,.4)
    a.beam("Ceiling lantern hanger",(-4,87,114),(0,87,114),.35,.35,gold,.08)
    plaster=M.limewash("Warm pavilion plaster",(.21,.17,.105),.3,4)
    a.block("Left plaster return",(5,320,220),(-230,85,20),plaster,.5)
    for i in range(18):a.block("Veranda cedar plank",(26.6,100,3),(-218+i*27,275,-109.5),wood,.2)
    for x in (-27,45,117,189,261):
        a.block("Vermilion railing post",(6,6,56),(x,303,-80),red,.4)
        a.lathe("Bronze railing finial",[(0,0),(4,0),(4.6,1.1),(3.2,2),(2.8,5),(0,9)],gold,loc=(x,303,-52))
    for z in (-87,-61):a.block("Rounded veranda rail",(300,4.5,4.5),(117,303,z),red,.8)
    stone_lantern.build("Garden stone lantern",loc=(66,271,-108),height=61,radius=14,energy=1900,seed=3)
    cherry_branch.build("Cherry over the veranda",loc=(41,324,-110),width=210,height=116,count=1080,seed=10)
    cherry_branch.build("Right garden cherry",loc=(235,366,-116),width=170,height=150,count=780,seed=4)
    vista=pavilion_vista.build("Dusk mountain pagoda",loc=(0,309,-133),pagoda_x=360,pagoda_depth=780,
        pagoda_width=175,pagoda_height=235,slope=.35,seed=5)
    for ob in vista.children_recursive:
        if ob.name.startswith("Dusk cloud sky"):
            ob.data.materials.clear();ob.data.materials.append(M.atelier_sky("Vermilion dusk clouds",strength=.7,seed=5))
    petal=E.simple("Drifting cherry petals",(.69,.25,.31),.6,Subsurface_Weight=.15)
    for i,(x,y,z) in enumerate(((-32,49,8),(35,57,9),(48,83,7),(50,134,-10),(-11,141,-5),(70,185,-18))):
        cherry_branch.blossom_mesh(a,[((x,y,z),.65+i*.06)],petal,seed=12+i,petals=1)
    def area(name,loc,target,energy,color,size):
        light=a.light(name,loc,energy,color,size,target,"AREA")
        light.visible_glossy=True;light.data.specular_factor=1
        return light
    area("Andon falloff on tatami",(-80,99,-15),(-35,80,-20),18000,(1,.55,.20),27)
    area("Andon gilt screen pool",(-76,110,-1),(-91,168,-29),42000,(1,.66,.30),39)
    area("Lantern on table lacquer",(-32,37,21),(-26,3,1),3500,(1,.65,.26),14)
    cool=area("Cool dusk through veranda",(99,252,69),(5,100,-30),74000,(.37,.48,.78),98)
    cool.visible_glossy=False;cool.data.specular_factor=0
    area("Red paper reflected accent",(94,142,-8),(28,22,1),11000,(1,.14,.045),24)
    area("Garden dusk on blossoms",(126,276,100),(80,342,4),110000,(.56,.63,.88),160)
    area("Lantern blush on cherry blossoms",(55,290,21),(90,328,-25),55000,(1,.61,.58),50)
    area("Andon on woven seat",(-48,59,10),(-35,85,-20),10000,(1,.64,.28),35)
    receivers=bpy.data.collections.new("Vermilion environment receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    gilt_receivers=bpy.data.collections.new("Lantern rim reflection receivers")
    gilt_receivers.objects.link(bpy.data.objects["rim_gilt"])
    gilt_receivers.objects.link(table_top)
    light=area("Andon strip reflected in gilt",(-19,22,17),(0,0,3.7),2300,(1,.62,.24),18)
    light.data.shape="RECTANGLE";light.data.size_y=3
    light.light_linking.receiver_collection=gilt_receivers
    group=G.Asset("Vermilion broadside room",rot_z=-math.pi/2+.10)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT" and ob.light_linking.receiver_collection is None:ob.light_linking.receiver_collection=receivers
        if ob!=group.root and ob.parent is None:group.add(ob)
    # The removable floral applique follows the unchanged near wall's rounded section.
    ornament=G.Asset("Tray exterior blossom applique")
    leaf=M.metal("Exterior maki-e leaf","brass",.15,12)
    def outer_wall(u,v,d):
        z=1.65+v
        outward=math.sqrt(max(0,1.1**2-max(0,abs(z-2.4)-.1)**2))
        return (-8.6-outward-d,u,z)
    maki_e.sprig(ornament,outer_wall,27,1.30,leaf,seed=7,flowers=17,relief=.012)
    receivers.objects.link(next(ob for ob in ornament.root.children if ob.name.startswith("Five lobed")))
    dice_receivers=bpy.data.collections.new("Lantern paper bounce exclusions")
    for ob in tuple(bpy.data.objects):
        if ob.type in {"MESH","CURVE"}:dice_receivers.objects.link(ob)
    for entry in dice_receivers.collection_objects:entry.light_linking.link_state="EXCLUDE"
    bounce=E.light(scene,"AREA","Pavilion paper ceiling return",(3,-3,42),7200,color=(1,.9,.72),size=26,target=(0,0,2))
    bounce.light_linking.receiver_collection=dice_receivers
    bounce.data.specular_factor=0;bounce.visible_glossy=False
    edge=E.light(scene,"AREA","Dusk edge across the dice",(20,12,16),1980,color=(.62,.72,1),size=16,target=(0,0,2))
    edge.light_linking.receiver_collection=dice_receivers
    edge.data.specular_factor=0;edge.visible_glossy=False
    warm_edge=E.light(scene,"AREA","Andon edge across dice",(-8,28,12),2200,color=(1,.78,.48),size=18,target=(0,0,2))
    warm_edge.light_linking.receiver_collection=dice_receivers
    warm_edge.data.specular_factor=0;warm_edge.visible_glossy=False
    return dict(loc=(-18.5,-2.6,21),target=(2,0,7.8),lens=26,fstop=8*scene.unit_settings.scale_length,focus=(0,0,3))
