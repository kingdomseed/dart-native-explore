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
        hero_layout={"d20":((-5.2,-13),18,8),"d12":((-4.6,0),11,-14),
                     "d10u":((2.5,4),9,12),"d10t":((2,-3),40,-6),
                     "d8":((2,-22),5,16),"d6":((1,-14),3,-9),
                     "d4":((-4,-23),3,22)},
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
                        lantern, amethyst_cluster, firewood)
    before=set(bpy.data.objects)
    a=G.Asset("Reading nook architecture")
    oak=M.oak("Nook oiled oak",(.095,.039,.014),.55,12,axis="Z")
    dark=M.oak("Nook recessed oak",(.044,.017,.007),.6,14,axis="Z")
    plaster=M.stone("Soft warm lime plaster",(.16,.115,.077),.25,3)
    brass=M.metal("Nook antique brass","brass",.65,4)
    oak_table.build("Small reading table",loc=(0,0,-76),width=126,depth=84,height=76,
                    thickness=4,wood_tone=(.075,.026,.009),wear=.45,scorch=0,seed=9,grain_scale=2.8,
                    leg_width=6,leg_inset=(13,11))
    a.block("Reading platform",(350,180,8),(0,15,-80),dark,.5)
    a.block("Sitting bay oak floor",(420,230,8),(0,285,-189),dark,.5)
    for x,w in ((-81,279),(238,105)):
        a.block("Warm nook wall",(w,9,280),(x,383,-30),plaster,.5)
        for j in range(int(w/28)):
            xx=x-w/2+14+j*28
            a.block("Recessed oak wainscot",(24,2,70),(xx,376,-110),dark,.4)
            a.block("Panel stile",(2,3,75),(xx-13,374,-110),oak,.3)
    a.block("Wall beneath rain window",(125,10,35),(122,383,-280),plaster,.5)
    a.block("Wall above rain window",(125,10,90),(122,383,-44),plaster,.5)
    hearth_fireplace.build("Reading nook fieldstone hearth",loc=(-93,280,-185),width=142,
                           depth=55,height=218,hearth_height=32,energy=320000,seed=6)
    wing_armchair.build("Leather wing chair and wine throw",loc=(54,285,-185),rot_z=-.12,
                         width=85,depth=90,height=105,tone=(.115,.029,.014),seed=4)
    cottage_window.build("Rainy blue casement",loc=(122,375,-260),width=125,height=172,
                          density=.032,drop_radius=.21,seed=7)
    bookcase.build("Books beside the hearth",loc=(2,352,-185),width=66,height=228,depth=27,rows=7,seed=8)
    bookcase.build("Left returning bookcase",loc=(-181,308,-185),rot_z=.28,width=72,height=235,depth=26,rows=7,seed=12)
    bookcase.build("Window-side books",loc=(235,352,-185),width=72,height=235,depth=25,rows=7,seed=17)
    # The compact side table supports the jug beside the chair.
    oak_table.build("Chair side table",loc=(113,285,-185),width=45,depth=41,height=67,
                    thickness=3,wood_tone=(.065,.023,.007),seed=15,scorch=0,leg_width=4,leg_inset=(7,7))
    lavender.build("Lavender beside the chair",loc=(114,287,-106),height=39,radius=6.2,seed=9)
    for i in range(3):
        book.build(f"Chair-side book {i}",loc=(113,285,-118+i*4),width=17,depth=23,thickness=4,seed=20+i)
    # Corner dressing: no object occupies the ten-centimetre clear band.
    for i in range(2):
        book.build(f"Left reading volume {i}",loc=(-43,20,4.2*i),rot_z=.05+i*.05,
                   width=17,depth=24,thickness=4.2,tone=(.10,.029,.011),seed=30+i,gilt_spine=True)
    candlestick.build("Foreground reading candle",loc=(-38.4,24,8.4),height=2.5,radius=3,
                       candle_height=5,candle_radius=1.8,energy=900,seed=7)
    pouch.build("Wine velvet dice pouch",loc=(-26,34,0),radius=6.3,height=12.5,
                tone=(.095,.006,.019),fabric="velvet",seed=6)
    for i in range(2):
        book.build(f"Right reading volume {i}",loc=(53,15,4.3*i),rot_z=-.06+i*.12,
                   width=17,depth=23,thickness=4.3,tone=(.035,.017,.008),seed=40+i,gilt_spine=True)
    coaster=M.bark("Cork mug coaster",(.10,.060,.025),.7,4)
    a.cylinder("Cork coaster",6.7,.8,(35.5,23,.4),coaster,bevel=.25,segments=64)
    coffee_mug.build("Fireside stoneware coffee",loc=(35.5,23,.8),rot_z=.18,height=10.2,radius=4.5,
                     tone=(.25,.18,.095),glaze_style="stoneware",steam_height=11,steam_width=1.6,
                     steam_strength=2.4,steam_opacity=.24,steam_drift=1.6,seed=13)
    lavender.build("Table lavender bundle",loc=(-43,38,9.1),rot_z=.3,kind="bundle",height=25,radius=4,stems=13,seed=18)
    amethyst_cluster.build("Foreground amethyst dish",loc=(-47,14,8.4),radius=4.5,height=5.5,count=9,energy=45,seed=9)
    a.beam("Lantern ceiling joist",(-210,252,5),(260,252,5),10,12,oak,.5)
    lantern.build("Brass reading lantern",loc=(-150,252,-90),height=30,radius=7,metal_finish="brass",chain_length=60,
                  energy=1000,seed=6,glass_tone=(.26,.06,.43),glow_color=(.55,.08,1),light_color=(.52,.18,1))
    candlestick.build("Mantel candle",loc=(-126,263,-52),height=4,radius=4,candle_height=16,candle_radius=2.2,energy=5000,seed=5)
    for i in range(4):
        book.build(f"Mantel volume {i}",loc=(-74,276,-52+i*4),width=22,depth=25,thickness=4,seed=60+i,gilt_spine=True)
    candlestick.build("Window candle",loc=(72,358,-151),height=3,radius=3.5,candle_height=12,energy=4200,seed=11)
    a.block("Window candle bracket",(15,21,3),(72,365,-152.5),oak,.7)
    a.beam("Window bracket scroll",(72,373,-167),(72,357,-153),3,3,oak,.6)
    for i in range(4):
        firewood.build(f"Hearth spare log {i}",loc=(-137,250+i%2*8,-185+i//2*7.4),length=24,radius=3.7,rot_z=.18*i,seed=30+i)
    def area(name,loc,target,energy,color,size,gloss=True):
        light=a.light(name,loc,energy,color,size,target=target,kind="AREA")
        light.visible_glossy=gloss;light.data.specular_factor=1 if gloss else .1
        return light
    area("Firelight caught on leather",(-67,239,-96),(47,278,-106),290000,(1,.49,.18),42)
    area("Warm light on hearth arch",(-95,215,-104),(-93,282,-104),55000,(1,.47,.15),45)
    area("Firelight on middle books",(-68,283,-77),(0,348,-68),170000,(1,.59,.28),38)
    area("Firelight on left shelves",(-104,232,-68),(-181,308,-65),210000,(1,.62,.32),48)
    area("Rain light on chair",(122,362,-94),(58,279,-92),230000,(.35,.48,1),60)
    area("Window edge on jug",(136,348,-86),(114,280,-102),95000,(.42,.57,1),42)
    area("Candle pool on desk",(-41,24,25),(-20,13,0),15000,(1,.65,.30),20)
    area("Lantern across oak",(-46,44,20),(7,23,0),23000,(1,.70,.38),26)
    area("Blue glass reflected on cup",(49,69,23),(34,26,6),7000,(.48,.63,1),25,False)
    area("Candle highlight on mug",(18,26,20),(36,26,6),8000,(1,.72,.39),17)
    area("Soft purple crystal return",(-43,42,19),(-37,15,0),1000,(.51,.17,1),9,False)
    area("Window candle on panelling",(72,352,-129),(86,375,-143),22000,(1,.62,.26),22)
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
    return dict(loc=(-34,-7,38),target=(0,0,12),lens=27.7,
                fstop=8*scene.unit_settings.scale_length,focus=(3,0,4.3))
