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
    E.light(scene, "AREA", "key", (-46, -12, 36), 16000, color=(1.0, 0.75, 0.55), size=25, target=(0, 0, 0))
    # Round 2: soft warm overhead (a paper ceiling lamp) for the gold leaf,
    # which mirrors the ceiling when seen straight down.
    E.overhead(scene, 1500, color=(1.0, 0.82, 0.62), size=90, height=110)
    return dict(samples=128,exposure=1.3,topdown=dict(width=W+2*RIM_T+1),surface_z=1.2,centre=(0,2,2.2),
        hero=dict(dist=32,elev=30,az=8,lens=65,fstop=2.8),
        hero_layout={"d20":((-4.5,-2),20,0),"d12":((-2.5,9),12,12),
            "d10u":((3,-11),0,-15),"d10t":((3,7),0,20),
            "d8":((-2,-9),8,-10),"d6":((3,-2.5),6,18),"d4":((3,1.5),4,58)},
        play_view=True,tray_half=(W/2+RIM_T,D/2+RIM_T),room_cam=room(scene))


def room(scene):
    """Room coordinates are lateral X and depth Y, rotated around the tray."""
    from assets import (geometry as G,materials as M,pavilion_lantern,tatami_mat,
        shoji_screen,byobu_screen,lacquer_table,zabuton,tea_service,cherry_branch,pavilion_vista)
    before=set(bpy.data.objects)
    a=G.Asset("Pavilion joinery")
    wood=M.oak("Smoked cedar posts",(.040,.015,.006),.4,3,axis="Z")
    red=M.urushi("Vermilion veranda lacquer",(.25,.018,.009),.45,6)
    gold=M.metal("Pavilion bronze caps","brass",.4,4)
    lacquer_table.build("Player low table",loc=(0,0,-32),width=124,depth=47,height=32,seed=4)
    tea_service.build("Left maki-e tea bowl",loc=(-33,10,0),radius=5.1,height=7.5,seed=7)
    tea_service.build("Tea caddy",loc=(31.5,18,0),kind="caddy",radius=4.8,height=8,seed=8)
    tea_service.build("Right tea bowl",loc=(34.5,1,0),radius=5.3,height=5.5,seed=10)
    tea_service.build("Pleated vermilion fan",loc=(-46,-4,-.1),rot_z=-.45,kind="fan",radius=13,seed=6)
    cherry_branch.build("Left table petals",loc=(-39,10,.15),kind="petals",width=13,height=18,count=7,seed=3)
    cherry_branch.build("Right table petals",loc=(36,-5,.15),kind="petals",width=12,height=10,count=5,seed=4)
    # Shallow landings let the seated viewpoint look out over the veranda.
    a.block("Tea platform foundation",(420,118,12),(0,-15,-42.5),wood,.7)
    for ix in range(4):
        tatami_mat.build("Foreground bound tatami",loc=(-135+90*ix,-15,-36.5),width=89.6,depth=117.6,seed=ix*3)
    for i in range(5):
        a.block("Cedar platform step",(72,11,16.5),(0,49.5+i*11,-40.25-i*16.5),wood,.5)
    for ix in range(5):
        tatami_mat.build("Lantern landing tatami",loc=(-180+90*ix,115,-119),width=89.6,depth=35.6,seed=ix*5)
        tatami_mat.build("Screen landing tatami",loc=(-180+90*ix,193,-154.5),width=89.6,depth=83.6,seed=ix*5+1)
    for y,z in ((140,-132),(151,-150)):
        a.block("Screen landing step",(430,11,18),(0,y,z-9),wood,.4)
    for y,z in ((240,-162.5),(251,-175)):
        a.block("Veranda threshold step",(430,11,12.5),(0,y,z-6.25),wood,.4)
    a.block("Left seating platform",(75,62,17),(-77,75,-45),wood,.7)
    tatami_mat.build("Seat platform tatami",loc=(-77,75,-36.5),width=74.5,depth=61.5,seed=6)
    zabuton.build("Left silk seat",loc=(-65,70,-32),width=49,depth=45,height=8,rot_z=.15,seed=8)
    zabuton.build("Right silk seat",loc=(89,17,-32),width=48,depth=47,height=7,rot_z=-.18,seed=4,tone=(.11,.013,.009))
    byobu_screen.build("Gold-leaf pine folding screen",loc=(-112,171,-150),panels=4,panel_width=42,height=148,fold=.22,seed=3)
    pavilion_lantern.build("Left andon floor lantern",loc=(-74,115,-70),height=77,radius=12.5,energy=9500,seed=6)
    # A low dais supports the principal lantern at the edge of the platform.
    lacquer_table.build("Andon low stand",loc=(-74,115,-114.5),width=35,depth=33,height=44.5,gilt=False,seed=8)
    pavilion_lantern.build("Red hanging chochin",loc=(111,152,-66),kind="chochin",height=49,radius=17,tone=(.85,.085,.025),glow=1.3,energy=14000,drop=140,seed=2)
    pavilion_lantern.build("Veranda small andon",loc=(12,185,-150),height=39,radius=7,energy=2200,glow=.85,seed=5)
    shoji_screen.build("Left sliding shoji",loc=(-186,174,-150),width=72,height=207,seed=7)
    shoji_screen.build("Partly opened shoji",loc=(-32,206,-150),width=67,height=207,seed=4)
    shoji_screen.build("Right sliding shoji",loc=(216,206,-150),width=77,height=207,seed=5)
    for x in (-225,-34,43,180,255):
        a.block("Chamfered cedar pillar",(10,10,224),(x,211,-38),wood,.75)
        a.block("Pillar foot shoe",(12,12,5),(x,211,-147.5),gold,.45)
    for z in (-148,61):a.block("Grooved shoji track",(490,12,5),(14,205,z),wood,.4)
    a.block("Lintel under ceiling",(490,17,17),(14,205,71),wood,.7)
    for x in range(-225,260,45):a.block("Overhead cedar rafter",(6,410,10),(x,92,81),wood,.4)
    plaster=M.limewash("Warm pavilion plaster",(.21,.17,.105),.3,4)
    a.block("Left plaster return",(5,320,220),(-230,85,-40),plaster,.5)
    # Veranda boards, two rails and shaped finials.
    for i in range(18):a.block("Veranda cedar plank",(26.6,104,3),(-218+i*27,288,-176.5),wood,.2)
    for x in (-27,45,117,189,261):
        a.block("Vermilion railing post",(6,6,62),(x,315,-144),red,.4)
        a.lathe("Bronze railing finial",[(0,0),(4,0),(4.6,1.1),(3.2,2),(2.8,5),(0,9)],gold,loc=(x,315,-112))
    for z in (-150,-121):a.block("Rounded veranda rail",(300,4.5,4.5),(117,315,z),red,.8)
    cherry_branch.build("Cherry over the veranda",loc=(42,324,-147),width=210,height=100,count=680,seed=10)
    cherry_branch.build("Right garden cherry",loc=(262,366,-175),width=165,height=139,count=360,seed=4)
    pavilion_vista.build("Dusk mountain pagoda",loc=(0,309,-154),pagoda_x=440,pagoda_depth=780,pagoda_width=195,pagoda_height=235,slope=.40,seed=5)
    # Only a handful of curved petals hang in the air, well beyond the play margin.
    petal=E.simple("Drifting cherry petals",(.69,.25,.31),.6,Subsurface_Weight=.15)
    for i,(x,y,z) in enumerate(((-34,55,10),(43,79,5),(73,131,-9),(53,195,-24),(-11,141,-5))):
        cherry_branch.blossom_mesh(a,[((x,y,z),.8+i*.08)],petal,seed=12+i,petals=1)
    def area(name,loc,target,energy,color,size):
        light=a.light(name,loc,energy,color,size,target,"AREA")
        light.visible_glossy=True;light.data.specular_factor=1
    area("Andon reflected warm pool",(-62,90,-4),(-69,141,-39),25000,(1,.60,.25),42)
    area("Screen gilt warm bounce",(-42,83,28),(-90,170,-20),55000,(1,.72,.36),75)
    area("Lantern on table lacquer",(-45,34,26),(-28,2,0),3000,(1,.68,.33),25)
    area("Cool dusk through veranda",(115,252,58),(5,60,-25),105000,(.41,.54,.84),125)
    area("Red paper reflected accent",(93,127,-2),(30,22,0),14000,(1,.20,.08),30)
    area("Open pavilion soft return",(8,-30,70),(0,132,-42),8500,(.72,.73,.77),110)
    area("Garden dusk on blossoms",(126,276,100),(80,342,-10),140000,(.56,.63,.88),180)
    area("Lantern blush on cherry blossoms",(55,290,-15),(90,328,-90),70000,(1,.61,.58),60)
    receivers=bpy.data.collections.new("Vermilion environment receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    group=G.Asset("Vermilion broadside room",rot_z=-math.pi/2+.10)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT" and ob.light_linking.receiver_collection is None:ob.light_linking.receiver_collection=receivers
        if ob!=group.root and ob.parent is None:group.add(ob)
    dice_receivers=bpy.data.collections.new("Lantern paper bounce exclusions")
    for ob in tuple(bpy.data.objects):
        if ob.type in {"MESH","CURVE"}:dice_receivers.objects.link(ob)
    for entry in dice_receivers.collection_objects:entry.light_linking.link_state="EXCLUDE"
    bounce=E.light(scene,"AREA","Pavilion paper ceiling return",(3,-3,42),12000,color=(1,.9,.72),size=26,target=(0,0,2))
    bounce.light_linking.receiver_collection=dice_receivers
    bounce.data.specular_factor=0;bounce.visible_glossy=False
    edge=E.light(scene,"AREA","Dusk edge across the dice",(20,12,16),3300,color=(.62,.72,1),size=16,target=(0,0,2))
    edge.light_linking.receiver_collection=dice_receivers
    edge.data.specular_factor=0;edge.visible_glossy=False
    return dict(loc=(-23,-4,22),target=(0,0,7.8),lens=18.4,fstop=8*scene.unit_settings.scale_length,focus=(0,0,3))
