"""Fate Engine environment: the machine *is* the environment.

A riveted, domed brass dice engine feeds a sloped output mouth behind
the tray. Meshing involute gears, copper unions, pressure instruments and
a glass induction column sit among drafting tools and warm work lamps. The rolling area is its output
tray: a dark steel plate engraved with a gear-and-orbit pattern whose
grooves carry a faint teal charge, walled by a riveted brass rail.
"""
from __future__ import annotations

import math
import bpy

import env_common as E
import env_props as P
from build_dice import _circle

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.2, 3.0
TEAL = (0.1, 1.0, 0.85)


def plate_strokes(w=0.004):
    s = []
    for r in (0.47, 0.44, 0.3, 0.12):
        s.append(([P.ring(r)], w, True))
    teeth = 36
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        r = 0.41 if (i % 4) in (1, 2) else 0.385
        pts.append((0.5 + r * math.cos(a), 0.5 + r * math.sin(a)))
    s.append(([pts], w * 1.2, True))
    for i in range(6):
        a = 2 * math.pi * i / 6
        s.append(([[(0.5 + 0.12 * math.cos(a), 0.5 + 0.12 * math.sin(a)),
                    (0.5 + 0.3 * math.cos(a), 0.5 + 0.3 * math.sin(a))]], w * 1.5, False))
    for i in range(3):  # orbits with 'planets'
        a = 0.6 + i * 2.1
        r = 0.2 + i * 0.03
        s.append(([_circle(0.5 + r * math.cos(a), 0.5 + r * math.sin(a), 0.018, 16)], w, True))
    for i in range(72):
        a = 2 * math.pi * i / 72
        s.append(([[(0.5 + 0.44 * math.cos(a), 0.5 + 0.44 * math.sin(a)),
                    (0.5 + 0.47 * math.cos(a), 0.5 + 0.47 * math.sin(a))]], w * 0.7, False))
    # long channels running to the machine
    for x in (0.3, 0.7):
        s.append(([[(x, 0.9), (x, 1.02)]], w * 1.6, False))
    return s


def steel_plate(mask, size):
    m, k = E.material("Engine plate")
    obj = k.coords().outputs["Object"]
    brush = k.node("ShaderNodeMapping")
    brush.inputs["Scale"].default_value = (1.0, 25.0, 1.0)
    k.link(obj, brush.inputs["Vector"])
    streak = k.noise(brush.outputs[0], 3.0, 3).outputs["Fac"]
    grime = k.noise(obj, 0.3, 8, 0.6).outputs["Fac"]
    sm = k.node("ShaderNodeMapping")
    sm.inputs["Scale"].default_value = (1 / size, 1 / size, 1)
    sm.inputs["Location"].default_value = (0.5, 0.5, 0)
    k.link(obj, sm.inputs["Vector"])
    tex = k.node("ShaderNodeTexImage", image=mask, extension="CLIP", interpolation="Cubic")
    k.link(sm.outputs[0], tex.inputs["Vector"])
    g = tex.outputs["Color"]
    nrm = k.bump(streak, 0.08, 0.02)
    nrm = k.bump(g, 0.8, 0.12, normal=nrm, invert=True)
    # Round 2: bright brushed steel with the pattern inlaid in brass (round
    # 1's dark plate + teal grooves read green and swallowed the dice); the
    # grooves keep only a whisper of charge.
    col = k.ramp(grime, [(0.3, (0.4, 0.38, 0.35)), (0.7, (0.6, 0.57, 0.52))])
    steel = k.bsdf(Base_Color=col, Metallic=0.65, Roughness=k.math("ADD", k.math("MULTIPLY", streak, 0.15), 0.42),
                   Normal=nrm)
    inlay = k.bsdf(Base_Color=(0.9, 0.64, 0.28, 1), Metallic=1.0, Roughness=0.3, Normal=nrm,
                   Emission_Color=(*TEAL, 1), Emission_Strength=0.12)
    k.surface(k.mix_shader(g, steel, inlay))
    return m


def build(scene):
    E.world(scene, color=(0.004, 0.006, 0.008), strength=1.0)
    mask = P.mask_texture("engine_plate", plate_strokes(), E.TMP, res=4096)
    brass = P.brass("Engine brass", worn=0.55)
    dark_brass = P.brass("Engine dark brass", worn=0.9, color=(0.55, 0.38, 0.18))
    E.plane("plate", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.31), steel_plate(mask, W * 0.98))
    E.cube("plate_base", (W + 2 * RIM_T + 1.4, D + 2 * RIM_T + 1.4, 0.6), (0, 0, 0.0), dark_brass, bevel=0.2)
    E.rim("rail", W + RIM_T, D + RIM_T, 3.5, RIM_H, RIM_T, brass, z0=0.3)
    rv = P.brass("Rivet", worn=0.8)
    for i, (x, y) in enumerate(E.rounded_rect(W + RIM_T, D + RIM_T, 3.5, seg=2)):
        E.sphere(f"rivet{i}", 0.3, (x, y, RIM_H + 0.3), rv, subdiv=2, scale=(1, 1, 0.6))
    for t in range(-4, 5):
        for sx in (-1, 1):
            E.sphere("rail_rivet", 0.22, (sx * (W / 2 + RIM_T + 0.1), t * D / 9.5, RIM_H * 0.55), rv, subdiv=2)

    top = D / 2 + RIM_T

    # Light: warm workshop key, teal machine glow, cool rim.
    # side key: its mirror image in the steel plate lands off the tray
    E.light(scene, "AREA", "key", (-48, -18, 40), 26000, color=(1.0, 0.72, 0.46), size=25, target=(0, 0, 0))
    E.overhead(scene, 9000, color=(1.0, 0.82, 0.6), size=90, height=110)
    E.light(scene, "AREA", "rim", (20, 70, 40), 3000, color=(0.5, 0.7, 1.0), size=30, target=(0, 0, 5))
    E.light(scene, "AREA", "tray_teal", (0, top - 4, 12), 10, color=TEAL, size=12, target=(0, 0, 0))
    rc = room(scene)
    return dict(
        samples=128, exposure=0.1, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=28, az=-6, lens=65, fstop=2.8),
        hero_layout={
            "d20": ((-1.8, -1.0), 20, 0), "d12": ((2.6, 10.0), 12, 12),
            "d10u": ((3.2, -11.5), 0, -15), "d10t": ((3.0, 4.0), 0, 20),
            "d8": ((-1.7, -9.5), 8, -10), "d6": ((3.2, -3.0), 6, 18),
            "d4": ((-0.4, 6.0), 4, 58),
        },
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene):
    """Broadside output bench, riveted machine, warm work lamps and a cool city window.

    Local X runs across the composition, local Y recedes into the workshop.
    Lighting for the room has separate receivers from the original tray rig.
    """
    from assets import (geometry as G, materials as M, oak_table, masonry, shelf,
                        gothic_window, armillary, astronomer_tools, writing_set,
                        clockwork_gear, pipework, tesla_column, dice_machine,
                        engineering_sheet, precision_tools, industrial_lamp, lantern,
                        stone_steps, vessel)
    before=set(bpy.data.objects)
    fixture=G.Asset("Workshop architecture")
    top=-.3
    oak=M.oak("Workshop floorboards",(.065,.029,.011),.65,12)
    iron=M.machined_metal("Workshop structural iron","iron",.7,13)
    brass=M.machined_metal("Workshop furniture brass","brass",.6,15)
    oak_table.build("Inventor output bench",loc=(0,2,-76),width=116,depth=62,height=75.7,
                    thickness=4.8,wood_tone=(.09,.038,.014),wear=.6,scorch=.35,seed=7,rear_recess=(40,24))
    # The casting stands on a lower working deck; its chute arrives just above the desk.
    oak_table.build("Engine mounting bench",loc=(27,71,-144),width=86,depth=57,height=72,
                    thickness=6,wood_tone=(.065,.025,.008),wear=.6,seed=8)
    dice_machine.build("Riveted brass dice engine",loc=(23,69,-72),rot_z=-.48,width=40,depth=36,height=83,
                       output_height=60,wear=.72,seed=4)
    tesla_column.build("Teal induction column",loc=(53,73,-72),radius=7,height=80,turns=6,
                       strength=9,energy=2400,wear=.65,seed=7)
    pipework.build("Engine coil feed",points=((40,72,-60),(53,72,-60),(53,73,-60)),radius=1.4,seed=9)
    pipework.build("Coil overhead return",points=((53,73,8),(53,80,15),(16,80,15),(16,80,9)),radius=1.3,seed=4)
    # Quiet desk centre with drafting work framing its outer corners.
    engineering_sheet.build("Gear study parchment",loc=(-42.5,13,top+.15),rot_z=.10,width=24,depth=34,seed=7)
    precision_tools.build("Desk caliper",loc=(-33,8,top+.2),rot_z=-.7,length=18,seed=11)
    precision_tools.build("Desk dividers",loc=(-46,8,top+.08),rot_z=.6,kind="dividers",length=16,opening=7,seed=4)
    astronomer_tools.build("Drafting magnifier",loc=(-33,11,top+.35),rot_z=-.7,kind="magnifier",radius=3.4,seed=9)
    writing_set.build("Rolled workshop drawing",loc=(-44,34,top+.05),rot_z=-.1,kind="scroll",width=25,seed=4)
    precision_tools.build("Bench screwdriver",loc=(32,19,top+.03),rot_z=-.5,kind="screwdriver",length=18,seed=3)
    precision_tools.build("Spare steel divider",loc=(42,22,top-.03),rot_z=.6,kind="dividers",length=17,opening=5,seed=13)
    for i,(x,y,r,n) in enumerate(((-30,27,3.2,24),(-30,19,2.0,16),(32,25,2.5,20),(42,-1,2.0,16))):
        clockwork_gear.build(f"Loose machined gear {i}",loc=(x,y,top+.665),radius=r,teeth=n,
                             thickness=.7,axis="Z",bore=.35,wear=.7,seed=20+i)
    vessel.build("Tool cup",loc=(39,28,top),kind="tankard",height=11,radius=3.8,metal_finish="brass",wear=.7,seed=4)
    for i in range(3):
        tool=precision_tools.build(f"Standing spare screwdriver {i}",loc=(38+i*.7,29,11),kind="screwdriver",length=16,seed=20+i)
        tool.rotation_euler.x=-math.pi/2-.1+i*.1
    for x,y in ((-26,28),(-48,25),(34,22),(39,20)):
        fixture.cylinder("Loose hexagonal nut",.45,.4,(x,y,top+.2),brass,segments=6,bevel=.05)
    # Lower bays keep real-scale tools and furniture legible above the close tray.
    fixture.block("Player workshop floor",(360,100,7),(0,-19,-79.5),oak,.4)
    fixture.block("Machine bay floor",(380,103,7),(0,82,-147.5),oak,.4)
    fixture.block("Back workshop floor",(430,200,7),(0,233,-163.5),oak,.4)
    stone_steps.build("Workshop steps",loc=(-100,48,-144),width=55,tread=10,rise=11.333333,count=6,tone=(.09,.07,.045))
    stone_steps.build("Instrument bay steps",loc=(-120,141,-160),width=55,tread=10,rise=4,count=4,tone=(.09,.07,.045))
    oak_table.build("Instrument workbench",loc=(-38,130,-160),width=98,depth=46,height=93,
                    wood_tone=(.065,.027,.009),wear=.55,seed=12)
    armillary.build("Brass gyroscopic model",loc=(-34,126,-67),radius=15,pedestal=12,seed=7)
    pipework.build("Bench pressure dial",loc=(-59,134,-54),kind="gauge",gauge_radius=6,seed=15)
    pipework.build("Instrument bench pipe",points=((-59,138,-67),(-59,138,-32),(-47,138,-32)),radius=1.2,seed=13)
    tesla_column.build("Small bench experiment",loc=(-71,121,-67),radius=4,height=24,turns=3,
                       strength=2,energy=100,tone=(1,.53,.18),seed=9)
    engineering_sheet.build("Instrument bench schematic",loc=(-39,119,-66.8),width=22,depth=26,seed=16)
    writing_set.build("Stored paper rolls",loc=(-64,121,-66.8),kind="scroll",width=22,seed=12)
    # Brick courses and pipes retain depth under warm grazing light.
    masonry.build("Workshop brick back",loc=(0,280,-160),width=450,height=220,thickness=15,
                   tone=(.14,.060,.026),wear=.24,seed=12,openings=((-35,0,110,181),),
                   block_width=(18,24),course_height=(7,9),arris=(.15,.4),relief=.4)
    masonry.build("Workshop left brick",loc=(-167,180,-160),rot_z=math.pi/2,width=200,height=220,
                   tone=(.14,.06,.026),wear=.24,seed=18,block_width=(18,24),course_height=(7,9),arris=(.15,.4),relief=.4)
    gothic_window.build("Moonlit inventor window",loc=(-35,274,-155),width=95,height=168,reveal=16,
                         stone_tone=(.11,.085,.05),sky_strength=2.5,moon_strength=3.3,exterior_slope=.46,
                         moon_offset=.35,energy=55000,seed=9)
    shelf.build("Workshop bottle shelves",loc=(-108,271,-89),width=95,levels=2,spacing=39,seed=11)
    for i,(x,z,r,t) in enumerate(((-102,20,25,50),(-67,-7,18,36),(111,-18,23,46))):
        clockwork_gear.build(f"Wall transmission wheel {i}",loc=(x,267,z),radius=r,teeth=t,
                             thickness=2.5,spokes=6,bore=2,wear=.8,seed=19+i)
        fixture.beam("Wall gear axle",(x,265,z),(x,283,z),2.8,2.8,iron,.4)
    for i,(x,z) in enumerate(((-146,35),(-129,60),(96,51),(122,82))):
        pipework.build(f"Wall copper circuit {i}",points=((x,268,-157),(x,268,z),(x+20,268,z),(x+20,268,100)),radius=2+i*.25,seed=30+i)
        pipework.build(f"Wall stop valve {i}",loc=(x,268,-34+i*12),kind="valve",radius=2+i*.25,wheel_radius=6,seed=30+i)
    for i,(x,z,w,d) in enumerate(((-65,-39,42,51),(-126,-10,35,44),(100,-89,40,52))):
        sheet=engineering_sheet.build(f"Pinned blueprint {i}",loc=(x,277.5,z),width=w,depth=d,blueprint=True,pinned=True,curl=.18,ink_width=.09,seed=5+i)
        sheet.rotation_euler.x=math.pi/2
        fixture.block("Blueprint pinning board",(w+4,3,d+4),(x,279,z),oak,.35)
    drawing=engineering_sheet.build("Left wall mechanism drawing",loc=(-164,143,-35),width=58,depth=68,
                                      blueprint=False,pinned=True,curl=.15,ink_width=.12,seed=20)
    drawing.rotation_euler=(math.pi/2,0,math.pi/2)
    fixture.block("Left drafting pin board",(3.5,62,72),(-165.8,143,-35),oak,.35)
    pipework.build("Left return copper circuit",loc=(-158,90,-130),rot_z=math.pi/2,
                    points=((0,0,0),(0,0,133),(74,0,133),(74,0,20)),radius=2,seed=44)
    clockwork_gear.build("Left return transmission",loc=(-158,210,-25),rot_z=math.pi/2,
                        radius=20,teeth=40,thickness=2.5,bore=2,wear=.75,seed=40)
    industrial_lamp.build("Left hanging work lamp",loc=(-55,102,-12),radius=12,height=10,drop=87,energy=22000,wear=.65,seed=8)
    industrial_lamp.build("Receding work lamp",loc=(-69,198,-8),radius=11,height=10,drop=117,energy=20000,wear=.65,seed=9)
    lantern.build("Back caged inspection lamp",loc=(-13,244,-86),height=27,radius=6,metal_finish="brass",energy=16000,seed=9)
    def area(name,loc,target,energy,color,size,gloss=True):
        ob=fixture.light(name,loc,energy,color,size,target=target,kind="AREA")
        ob.visible_glossy=gloss;ob.data.specular_factor=1 if gloss else .1
        return ob
    area("Work lamp pool on drafts",(-45,45,36),(-32,8,0),24000,(1,.70,.38),21)
    area("Brass crown warm strip",(-8,23,28),(21,60,2),65000,(1,.76,.45),25)
    area("Teal coil cast light",(49,73,3),(26,65,-9),1800,(.055,1,.77),15)
    area("Window cool brass edge",(9,255,-15),(20,75,-10),90000,(.40,.62,1),46)
    area("Lamp pool on brick and piping",(-92,211,-20),(-84,278,-35),120000,(1,.64,.29),28)
    area("Warm instrument bench pool",(-53,114,-12),(-45,129,-63),45000,(1,.72,.40),24)
    area("Right return from coil",(70,159,-15),(97,270,-30),60000,(.12,.63,.65),40,False)
    area("Gear bearing warm edge",(67,34,20),(44,56,-7),23000,(1,.72,.40),23)
    area("Left wall work-lamp return",(-98,111,-4),(-158,145,-25),65000,(1,.69,.34),36)
    receivers=bpy.data.collections.new("Fateengine room light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    frame=G.Asset("Fateengine room frame",rot_z=-math.pi/2+.10)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT":ob.light_linking.receiver_collection=receivers
        if ob!=frame.root and ob.parent is None:frame.add(ob)
    field=bpy.data.collections.new("Engine field warm work-lamp return")
    for ob in bpy.data.objects:
        if ob.name in {"plate","rail"} or ob.name.startswith(("rail_rivet","rivet")):
            field.objects.link(ob)
    bounce=E.light(scene,"AREA","Warm lamp reflection on output tray",(9,-18,30),9500,
                   color=(1,.82,.57),size=36,target=(0,0,0))
    bounce.light_linking.receiver_collection=field
    return dict(loc=(-18,-5,22),target=(0,0,9),lens=17.7,
                fstop=8*scene.unit_settings.scale_length,focus=(4,0,1.4))
