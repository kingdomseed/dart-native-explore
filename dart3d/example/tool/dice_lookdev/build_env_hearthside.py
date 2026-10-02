"""Hearthside Tome environment: "Fireside Reading".

The rolling surface is a huge open illustrated tome lying spine-across
(portrait friendly): sepia-inked plates and ruled text blocks, pages
bowed toward the gutter, a ribbon marker. A low hearth glows behind;
a stoneware mug, velvet dice pouch, wax seals and dried lavender sit
around the book on a worn oak table.
"""
from __future__ import annotations

import math

import bmesh
import bpy

import env_common as E

W, D = E.TRAY_W, E.TRAY_D


def page_mat():
    m, k = E.material("Tome page")
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.3, 8, 0.6).outputs["Fac"]
    # Round 2: tea-stained vellum, a few steps darker than the bone dice so
    # they separate at top-down (round 1's cream pages matched the dice).
    col = k.ramp(n, [(0.3, (0.33, 0.24, 0.13)), (0.7, (0.5, 0.39, 0.24))])
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    # ruled text blocks: rows of short dashes, leaving an illustration window
    rows = k.math("LESS_THAN", k.math("FRACT", k.math("DIVIDE", sep.outputs["Y"], 0.42)), 0.22)
    wm = k.node("ShaderNodeMapping")
    wm.inputs["Scale"].default_value = (1.0, 6.0, 1.0)
    k.link(obj, wm.inputs["Vector"])
    words = k.math("GREATER_THAN", k.noise(wm.outputs[0], 2.2, 1).outputs["Fac"], 0.42)
    ax, ay = k.math("ABSOLUTE", sep.outputs["X"]), k.math("ABSOLUTE", sep.outputs["Y"])
    margin = k.math("MULTIPLY", k.math("LESS_THAN", ax, W / 2 + 1.5), k.math("LESS_THAN", ay, D / 2 + 1.0))
    margin = k.math("MULTIPLY", margin, k.math("GREATER_THAN", ay, 1.8))
    illus_c = k.math("LESS_THAN", k.math("ABSOLUTE", sep.outputs["X"]), W / 2 - 1.0)
    illus = k.math("MULTIPLY", illus_c, k.math("LESS_THAN", k.math("ABSOLUTE", k.math("SUBTRACT", ay, D / 4 + 2.0)),
                                               D / 8))
    text = k.math("MULTIPLY", k.math("MULTIPLY", rows, words), margin)
    text = k.math("MULTIPLY", text, k.math("SUBTRACT", 1.0, illus))
    # the 'plate': an ink-wash landscape made of layered noise contours
    c = k.noise(obj, 0.25, 5, 0.6).outputs["Fac"]
    hatch = k.math("LESS_THAN", k.math("FRACT", k.math("MULTIPLY", c, 14.0)), 0.25)
    plate = k.math("MULTIPLY", illus, k.math("MAXIMUM", hatch, k.math("MULTIPLY", c, 0.4)))
    ink = k.math("MAXIMUM", k.math("MULTIPLY", text, 0.8), k.math("MULTIPLY", plate, 0.7))
    col = k.mix(ink, col, (0.18, 0.1, 0.05, 1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.8, Subsurface_Weight=0.15))
    return m


def open_book(scene):
    cover_m = E.simple("Tome cover", (0.12, 0.035, 0.02), 0.55, Coat_Weight=0.2)
    E.cube("tome_cover", (W + 8, D + 12, 0.8), (0, 0, 0.4), cover_m, bevel=0.3)
    pm = page_mat()
    for s in (1, -1):  # two page blocks; spine runs along x at y=0
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=40, y_segments=40, size=0.5)
        for v in bm.verts:
            x, y = v.co.x * (W + 6), (v.co.y + 0.5) * (D / 2 + 4)
            t = y / (D / 2 + 4)
            z = 3.0 + 0.4 * math.sin(math.pi * t) - 1.2 * math.exp(-t * 14)
            v.co = (x, s * y, z)
        ob = E.mesh_object(f"pages{s}", bm, pm, smooth=True)
        sol = ob.modifiers.new("block", "SOLIDIFY")
        sol.thickness = 1.6
    rib = E.cube("ribbon", (1.2, 20, 0.05), (6, -D / 2 - 2, 0.9), E.simple("Ribbon", (0.35, 0.02, 0.03), 0.5,
                                                                           Sheen_Weight=1.0))
    rib.rotation_euler = (0, 0, 0.15)


def build(scene):
    # Preserve the fine ink strokes when the phone preview is rendered at half size.
    scene.cycles.filter_width = 0.5
    scene.view_settings.gamma = 0.8
    E.world(scene, color=(0.012, 0.006, 0.003), strength=1.0)
    open_book(scene)
    top = D / 2 + 6
    # the hearth's glow on the tray (the fireplace itself is in room())
    E.light(scene, "AREA", "fire", (0, top + 45, 12), 16000, color=(1.0, 0.5, 0.2), size=35, target=(0, 0, 0))
    E.light(scene, "AREA", "cool_fill", (-50, -40, 40), 1200, color=(0.55, 0.65, 1.0), size=40, target=(0, 0, 0))
    # reading key from the side (its hotspot misses the top faces), strong
    # enough that the bone reads bright against the tea-stained vellum
    E.light(scene, "AREA", "reading_key", (40, -20, 40), 11000, color=(1.0, 0.9, 0.8), size=20, target=(0, 0, 0))
    return dict(
        samples=128, exposure=1.15, surface_z=3.3, centre=(0, 9.0, 4.3),
        topdown=dict(width=W + 9.0),
        # keep the dice off the gutter's slope (the physics floor is flat)
        topdown_layout={"d20": ((0.4, -4.2), 18, 8), "d12": ((-3.9, 4.6), 11, -14), "d10u": ((3.7, 4.2), 9, 12),
                        "d10t": ((-0.3, 9.0), 40, -6), "d8": ((-3.8, -8.6), 5, 16), "d6": ((3.8, -8.4), 3, -9),
                        "d4": ((0.4, 13.0), 3, 22)},
        hero_layout={"d20":((-7,-12),18,8),"d12":((-4,-1),11,-14),
                     "d10u":((3,-17),9,12),"d10t":((-3,-19),40,-6),
                     "d8":((3.5,-1),5,16),"d6":((2.5,-14),3,-9),
                     "d4":((4,4),3,22)},
        hero=dict(dist=32, elev=30, az=-8, lens=65, fstop=2.8),
        play_view=True, tray_half=(W / 2 + 4, D / 2 + 6), room_cam=room(scene),
    )


def room(scene):
    """A compact broadside reading table before a lower, firelit sitting bay.

    The room frame uses lateral X and depth Y around the untouched tome.
    Environmental lamps exclude the play surface to preserve its gate recipe.
    """
    from assets import (geometry as G, materials as M, oak_table, bookcase,
                        hearth_fireplace, wing_armchair, cottage_window,
                        lavender, coffee_mug, pouch, book, candlestick,
                        lantern, amethyst_cluster, firewood, table_wear)
    before=set(bpy.data.objects)
    a=G.Asset("Reading nook architecture")
    oak=M.oak("Nook oiled oak",(.095,.039,.014),.55,12,axis="Z")
    dark=M.oak("Nook recessed oak",(.044,.017,.007),.6,14,axis="Z")
    plaster=M.stone("Soft warm lime plaster",(.16,.115,.077),.25,3)
    brass=M.metal("Nook antique brass","brass",.65,4)
    oak_table.build("Small reading table",loc=(0,3,-76),width=116,depth=110,height=76,
                    thickness=4,wood_tone=(.045,.015,.005),wear=.88,scorch=.14,seed=9,grain_scale=1.15,
                    leg_width=6,leg_inset=(13,11))
    table_wear.build("Firelit aged table marks",width=116,depth=80,quiet=(33,25),wear=.8,seed=19)
    a.block("Reading platform",(350,180,8),(0,10,-80),dark,.5)
    a.block("Sitting bay oak floor",(420,230,8),(0,195,-100),dark,.5)
    for x,w in ((-70,300),(244,68)):
        a.block("Warm nook wall",(w,9,280),(x,253,30),plaster,.5)
        for j in range(int(w/28)):
            xx=x-w/2+14+j*28
            a.block("Recessed oak wainscot",(24,2,70),(xx,246,-60),dark,.4)
            a.block("Panel stile",(2,3,75),(xx-13,244,-60),oak,.3)
    a.block("Wall beneath rain window",(126,10,30),(142,253,-94),plaster,.5)
    a.block("Wall above rain window",(126,10,90),(142,253,155),plaster,.5)
    hearthstone=M.stone("Hearth raised foundation",(.04,.028,.018),.65,6)
    a.hewn_block("Raised fireplace foundation",(160,85,74),(-73,140,-59),hearthstone,2,.5,6)
    hearth_fireplace.build("Reading nook fieldstone hearth",loc=(-73,144,-22),width=144,
                           depth=64,height=185,hearth_height=28,stone_tone=(.055,.034,.021),
                           rugged=True,flame_height=1.25,energy=85000,seed=6)
    a.block("Raised chair bay",(146,116,65),(64,145,-63.5),dark,.7)
    wing_armchair.build("Leather wing chair and wine throw",loc=(42,142,-31),rot_z=-.12,
                         width=85,depth=90,height=112,tone=(.085,.019,.009),seed=4,
                         tufted=True,throw_tone=(.16,.006,.018),throw_width=36,throw_fold=2.2,throw_pitch=3.0)
    cottage_window.build("Rainy blue casement",loc=(142,245,-79),width=126,height=186,
                          density=.055,drop_radius=.28,seed=7,town_altitude=140,
                          sky_colors=((.03,.044,.08),(.105,.15,.27),(.022,.044,.10)),
                          sky_strength=1.3,exterior_slope=.15)
    bookcase.build("Books beside the hearth",loc=(6,230,-96),width=61,height=228,depth=27,rows=7,seed=8)
    bookcase.build("Left returning bookcase",loc=(-183,198,-96),rot_z=.28,width=72,height=235,depth=26,rows=7,seed=12)
    bookcase.build("Window-side books",loc=(249,230,-96),width=72,height=235,depth=25,rows=7,seed=17)
    oak_table.build("Chair side table",loc=(105,153,-31),width=45,depth=41,height=67,
                    thickness=3,wood_tone=(.045,.016,.005),seed=15,scorch=0,leg_width=4,leg_inset=(7,7))
    lavender.build("Lavender beside the chair",loc=(105,153,48),height=39,radius=6.2,seed=9)
    for i in range(3):
        book.build(f"Chair-side book {i}",loc=(105,153,36+i*4),width=17,depth=23,thickness=4,seed=20+i)
    for i in range(2):
        book.build(f"Left reading volume {i}",loc=(-40,25,4.65*i),rot_z=.05+i*.05,
                   width=17,depth=24,thickness=4.2,tone=(.10,.029,.011),seed=30+i,gilt_spine=True)
    candlestick.build("Foreground reading candle",loc=(-30,43,0),height=5,radius=3,
                       candle_height=12,candle_radius=2.4,drip_pan_radius=4.1,drips=22,energy=1900,seed=7)
    lantern.build("Violet glass table lantern",loc=(-39,50,0),height=27,radius=6,metal_finish="brass",chain_length=0,
                  energy=800,seed=6,glass_tone=(.26,.035,.48),glow_color=(.46,.018,1),light_color=(.44,.09,1))
    pouch.build("Wine velvet dice pouch",loc=(-14,39,0),radius=6.3,height=12.5,
                tone=(.095,.006,.019),fabric="velvet",seed=6)
    for i in range(3):
        book.build(f"Right reading volume {i}",loc=(49,46,4.75*i),rot_z=-.06+i*.08,
                   width=17,depth=23,thickness=4.3,tone=(.035,.017,.008),seed=40+i,gilt_spine=True)
    coaster=M.bark("Cork mug coaster",(.10,.060,.025),.7,4)
    a.cylinder("Cork coaster",6.7,.8,(38.5,21,.4),coaster,bevel=.25,segments=64)
    coffee_mug.build("Fireside stoneware coffee",loc=(38.5,21,.8),rot_z=.18,height=10.2,radius=4.5,
                     tone=(.25,.18,.095),glaze_style="stoneware",steam_height=11,steam_width=1.6,
                     steam_strength=1.6,steam_opacity=.14,steam_drift=1.6,seed=13)
    lavender.build("Table lavender bundle",loc=(-51,30,9.65),rot_z=.785,kind="bundle",height=25,radius=4,stems=23,seed=18)
    lavender.build("Loose table lavender sprigs",loc=(-29,29.2,1),rot_z=math.pi/2,kind="bundle",height=12,
                   radius=3,stems=19,tone=(.25,.075,.35),seed=22)
    velvet=M.velvet("Crystal bowl resting pad",(.055,.009,.031),seed=8)
    a.cylinder("Crystal bowl velvet rest",3.2,.5,(-33.5,27,9.1),velvet,bevel=.15,segments=48)
    amethyst_cluster.build("Foreground amethyst dish",loc=(-33.5,27,9.3),radius=5.6,height=6.5,count=11,energy=60,seed=9)
    candlestick.build("Mantel candle",loc=(-122,127,106.5),height=4,radius=4,candle_height=16,candle_radius=2.2,energy=1700,seed=5)
    for i in range(4):
        book.build(f"Mantel volume {i}",loc=(-44,140,106.5+i*4),width=22,depth=25,thickness=4,seed=60+i,gilt_spine=True)
    candlestick.build("Window candle",loc=(70,232,-106),height=3,radius=3.5,candle_height=12,energy=2600,seed=11)
    a.block("Window candle bracket",(15,21,3),(70,238,-107.5),oak,.7)
    a.beam("Window bracket scroll",(70,247,-122),(70,232,-108),3,3,oak,.6)
    for i in range(4):
        firewood.build(f"Hearth spare log {i}",loc=(-142,110+i%2*8,-96+i//2*7.4),length=24,radius=3.7,rot_z=.18*i,seed=30+i)
    import random
    rng=random.Random(41)
    petal=M.wool("Fallen lavender calyx",(.16,.04,.23),7)
    crumb=M.stone("Small dry biscuit crumbs",(.22,.095,.028),.4,5)
    for i in range(30):
        x=rng.uniform(33,47);y=rng.uniform(5,10)
        ob=a.add(E.rock("Lavender petal" if i%3 else "Biscuit crumb",rng.uniform(.08,.20),(x,y,.14),petal if i%3 else crumb,seed=i,subdiv=1))
        ob.scale=(1.6,.6,.35)
    def area(name,loc,target,energy,color,size,gloss=True):
        light=a.light(name,loc,energy,color,size,target=target,kind="AREA")
        light.visible_glossy=gloss;light.data.specular_factor=1 if gloss else .1
        return light
    area("Rain light on chair",(142,232,12),(46,142,25),110000,(.32,.46,1),48)
    area("Window edge on jug",(163,227,30),(105,153,40),35000,(.36,.50,1),30)
    area("Candle pool on desk",(-33,32,21),(-24,30,0),7400,(1,.57,.22),12)
    area("Hearth grazing old oak",(-46,70,24),(0,21,0),12500,(1,.48,.18),20)
    area("Blue glass reflected on cup",(48,54,21),(38.5,21,6),2600,(.36,.52,1),20,False)
    area("Candle highlight on mug",(20,26,23),(38.5,21,6),2600,(1,.65,.29),12)
    area("Soft purple crystal return",(-38,27,20),(-39,24,0),700,(.51,.17,1),7,False)
    area("Window candle on panelling",(70,228,-88),(83,245,-90),8500,(1,.54,.19),15)
    # Seat the irregular bouquet and spun bowl on the modeled book cover.
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    bpy.context.view_layer.update()
    graph=bpy.context.evaluated_depsgraph_get()
    support=bpy.data.objects["Left reading volume 1"]
    verts=[];faces=[]
    for ob in support.children_recursive:
        if ob.type not in {"MESH","CURVE"}:continue
        ev=ob.evaluated_get(graph);mesh=ev.to_mesh();mesh.calc_loop_triangles();offset=len(verts)
        verts.extend(ob.matrix_world@v.co for v in mesh.vertices)
        faces.extend(tuple(offset+i for i in t.vertices) for t in mesh.loop_triangles)
        ev.to_mesh_clear()
    surface=BVHTree.FromPolygons(verts,faces,all_triangles=True)
    for label in ("Table lavender bundle","Foreground amethyst dish"):
        root=bpy.data.objects[label];offsets=[]
        for ob in root.children_recursive:
            if ob.type not in {"MESH","CURVE"}:continue
            ev=ob.evaluated_get(graph);mesh=ev.to_mesh()
            for vertex in mesh.vertices:
                point=ob.matrix_world@vertex.co
                hit,_,_,_=surface.ray_cast(point+Vector((0,0,3)),Vector((0,0,-1)),8)
                if hit is not None:offsets.append(hit.z-point.z)
            ev.to_mesh_clear()
        if offsets:root.location.z+=max(offsets)+.035
        bpy.context.view_layer.update()
    bpy.data.objects["Foreground amethyst dish"].location.z=9.385
    root=bpy.data.objects["Loose table lavender sprigs"]
    lowest=min((ob.matrix_world@v.co).z for ob in root.children_recursive if ob.type=="MESH" for v in ob.data.vertices)
    root.location.z+=.025-lowest
    for ob in set(bpy.data.objects)-before:
        if (ob.parent is None or ob.parent==a.root) and ob.location.y>90:
            ob.location.y+=95
            ob.location.z-=55
    area("Hearth return to leather",(-10,178,-5),(42,235,-38),90000,(1,.48,.19),24)
    area("Fire over the arch",(-75,191,2),(-73,224,10),22000,(1,.44,.14),25)
    area("Fire across book spines",(-10,227,-3),(6,319,15),80000,(1,.51,.23),26)
    area("Fire on returning shelves",(-114,185,0),(-183,293,-20),65000,(1,.49,.20),30)
    receivers=bpy.data.collections.new("Hearthside environment light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    group=G.Asset("Hearthside room frame",rot_z=-math.pi/2+.16)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT" and ob.light_linking.receiver_collection is None:
            ob.light_linking.receiver_collection=receivers
        if ob!=group.root and ob.parent is None:group.add(ob)
    excluded=bpy.data.collections.new("Reading candle bounce exclusions")
    for ob in bpy.data.objects:
        if ob.type in {"MESH","CURVE"}:excluded.objects.link(ob)
    for entry in excluded.collection_objects:entry.light_linking.link_state="EXCLUDE"
    bounce=E.light(scene,"AREA","Candle return on ivory",(-25,-20,45),10000,
                   color=(1,.83,.61),size=25,target=(0,0,3.3))
    bounce.light_linking.receiver_collection=excluded
    bounce.visible_glossy=False
    bounce.visible_transmission=False
    bounce.data.specular_factor=0
    pages=bpy.data.collections.new("Warm vellum light receivers")
    for label in ("pages1","pages-1"):pages.objects.link(bpy.data.objects[label])
    page_light=E.light(scene,"AREA","Candle return on vellum",(-15,24,30),2500,
                       color=(1,.75,.43),size=30,target=(0,0,3))
    page_light.light_linking.receiver_collection=pages
    return dict(loc=(-20,-2,13),target=(2,0,5),lens=20,
                fstop=8*scene.unit_settings.scale_length,focus=(-5.5,-1,4.3))
