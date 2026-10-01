"""Arcane Study environment: "The Night Study".

The rolling surface is the hero: a dark oak board inlaid with an engraved
brass sigil circle, framed by a low brass-capped rim. Around it: candles,
stacked leather tomes, a brass armillary, a bowl of glowing blue
runestones, star-stitched velvet, coins, maps and an hourglass, with a
moonlit window behind. Warm candlelight vs. a cool magical blue.
"""
from __future__ import annotations

import math

import bpy

import env_common as E
import env_props as P

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.2, 2.6


def board(sigil, size):
    m, k = E.material("Sigil board")
    obj = k.coords().outputs["Object"]
    wood_n = k.noise(obj, 0.6, 8, 0.6).outputs["Fac"]
    mp = k.node("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0, 0.1, 1.0)
    k.link(obj, mp.inputs["Vector"])
    wave = k.node("ShaderNodeTexWave", wave_type="BANDS", bands_direction="X")
    k.link(mp.outputs[0], wave.inputs["Vector"])
    k.set(wave, Scale=0.5, Distortion=7.0, Detail=6.0)
    grain = k.math("MULTIPLY", wave.outputs["Fac"], wood_n)
    # Round 2: honey-toned oak (round 1's near-black board swallowed the
    # midnight dice at top-down).
    wood = k.ramp(grain, [(0.05, (0.09, 0.05, 0.022)), (0.5, (0.22, 0.12, 0.05))])
    sm = k.node("ShaderNodeMapping")
    sm.inputs["Scale"].default_value = (1 / size, 1 / size, 1)
    sm.inputs["Location"].default_value = (0.5, 0.5, 0)
    k.link(obj, sm.inputs["Vector"])
    tex = k.node("ShaderNodeTexImage", image=sigil, extension="CLIP", interpolation="Cubic")
    k.link(sm.outputs[0], tex.inputs["Vector"])
    inlay = tex.outputs["Color"]
    nrm = k.bump(grain, 0.2, 0.1)
    nrm = k.bump(inlay, 0.5, 0.08, normal=nrm)
    wood_s = k.bsdf(Base_Color=wood, Roughness=k.math("ADD", k.math("MULTIPLY", wood_n, 0.3), 0.35), Normal=nrm,
                    Coat_Weight=0.4, Coat_Roughness=0.3)
    brass = k.bsdf(Base_Color=(0.95, 0.66, 0.3, 1), Metallic=1.0, Roughness=0.28, Normal=nrm,
                   Emission_Color=(0.4, 0.6, 1.0, 1), Emission_Strength=0.08)
    # Round 2: the tray bed is a satin-brass field (a light ground for the
    # dark dice) with the sigil engraved dark; the oak shows as a border.
    # The field is a rounded rectangle 1 cm inside the rim (rounded-box SDF).
    xy = k.node("ShaderNodeMapping")
    xy.inputs["Scale"].default_value = (1.0, 1.0, 0.0)
    k.link(obj, xy.inputs["Vector"])
    ab = k.node("ShaderNodeVectorMath", operation="ABSOLUTE")
    k.link(xy.outputs[0], ab.inputs[0])
    r = 2.0
    sub = k.node("ShaderNodeVectorMath", operation="SUBTRACT")
    k.link(ab.outputs[0], sub.inputs[0])
    sub.inputs[1].default_value = (W / 2 - 1.0 - r, D / 2 - 1.0 - r, 0)
    mx = k.node("ShaderNodeVectorMath", operation="MAXIMUM")
    k.link(sub.outputs[0], mx.inputs[0])
    mx.inputs[1].default_value = (0, 0, 0)
    ln = k.node("ShaderNodeVectorMath", operation="LENGTH")
    k.link(mx.outputs[0], ln.inputs[0])
    disc = k.math("LESS_THAN", ln.outputs["Value"], r)
    field_n = k.noise(obj, 1.5, 6, 0.6).outputs["Fac"]
    # brushed brass: fine circular brushing around the circle's centre
    ang = k.node("ShaderNodeTexGradient", gradient_type="RADIAL")
    k.link(obj, ang.inputs["Vector"])
    rn = k.node("ShaderNodeVectorMath", operation="LENGTH")
    k.link(xy.outputs[0], rn.inputs[0])
    ring_n = k.noise(None, 1.0, 2)
    cmb = k.node("ShaderNodeCombineXYZ")
    k.link(k.math("MULTIPLY", rn.outputs["Value"], 40.0), cmb.inputs[0])
    k.link(k.math("MULTIPLY", ang.outputs["Fac"], 3.0), cmb.inputs[1])
    k.link(cmb.outputs[0], ring_n.inputs["Vector"])
    field_nrm = k.bump(ring_n.outputs["Fac"], 0.08, 0.02, normal=k.bump(inlay, 0.5, 0.08))
    field = k.bsdf(Base_Color=k.ramp(field_n, [(0.3, (0.55, 0.42, 0.22)), (0.7, (0.7, 0.56, 0.32))]),
                   Metallic=0.75, Roughness=k.math("ADD", k.math("MULTIPLY", field_n, 0.12), 0.34),
                   Normal=field_nrm)
    etched = k.bsdf(Base_Color=(0.05, 0.03, 0.015, 1), Roughness=0.6, Normal=field_nrm,
                    Emission_Color=(0.4, 0.6, 1.0, 1), Emission_Strength=0.05)
    inner = k.mix_shader(inlay, field, etched)
    k.surface(k.mix_shader(disc, k.mix_shader(inlay, wood_s, brass), inner))
    return m


def build(scene):
    E.world(scene, color=(0.004, 0.005, 0.012), strength=1.0)
    sigil = P.mask_texture("arcane_sigil", P.sigil_strokes(seed=7, points=7, runes=30), E.TMP, res=4096)
    E.plane("board", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.31), board(sigil, W * 0.96))
    E.cube("board_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.6), (0, 0, 0.0),
           P.dark_wood("Board edge", c1=(0.02, 0.01, 0.006), c2=(0.05, 0.025, 0.012)), bevel=0.2)
    rim_wood = P.dark_wood("Rim wood", c1=(0.025, 0.012, 0.007), c2=(0.07, 0.035, 0.016), varnish=0.6)
    E.rim("rim", W + RIM_T, D + RIM_T, 2.0, RIM_H, RIM_T, rim_wood, z0=0.3)
    E.rim("rim_cap", W + RIM_T, D + RIM_T, 2.0, 0.5, 0.7, P.brass("Rim brass", worn=0.35), z0=RIM_H + 0.1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            E.sphere("rim_boss", 0.8, (sx * (W / 2 + RIM_T / 2), sy * (D / 2 + RIM_T / 2), RIM_H + 0.7),
                     P.brass(), subdiv=3, scale=(1, 1, 0.6))

    top = D / 2 + RIM_T
    E.light(scene, "POINT", "rune_glow", (W / 2 + 12, -8, 5), 250, color=(0.25, 0.5, 1.0), size=3)

    # Lights. Round 2: a warm candle key pooled on the tray from the candle
    # cluster (angled, so no hotspot in the dice's top faces), a big soft
    # overhead for the gilt, and a weaker moon than round 1.
    E.light(scene, "AREA", "moon", (8, top + 70, 60), 6000, color=(0.55, 0.65, 1.0), size=40, target=(0, 0, 0),
            shadow=False)
    E.light(scene, "AREA", "candle_key", (-8, top + 2, 34), 13000, color=(1.0, 0.74, 0.48), size=14,
            target=(0, -5, 0))
    E.light(scene, "AREA", "warm_fill", (-30, -30, 30), 900, color=(1.0, 0.7, 0.45), size=25, target=(0, 0, 0))
    E.overhead(scene, 3500, color=(1.0, 0.85, 0.65), size=90, height=110)
    rc = room(scene)
    return dict(
        samples=128, exposure=-.15, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=30, az=6, lens=65, fstop=2.8),
        hero_layout={
            "d20": ((-1.8, -1.0), 20, 0), "d12": ((2.6, 10.0), 12, 12),
            "d10u": ((3.2, -11.5), 0, -15), "d10t": ((3.0, 4.0), 0, 20),
            "d8": ((-1.7, -9.5), 8, -10), "d6": ((3.2, -3.0), 6, 18),
            "d4": ((-0.4, 6.0), 4, 58),
        },
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene):
    """Layered candlelit library, broadside desk and a moonlit pointed window.

    Room coordinates are lateral X, depth Y; the parent rotates the study
    around the untouched tray. Room lights only illuminate room receivers.
    """
    from assets import (geometry as G, materials as M, oak_table, bookcase,
                        gothic_window, writing_set, runestone_bowl, candlestick,
                        book, armillary, velvet_drape, astronomer_tools, stone_steps)
    before=set(bpy.data.objects)
    top=-.3
    fixtures=G.Asset("Study architecture")
    oak=M.oak("Study wall oak",(.075,.027,.009),.45,7,axis="Z")
    dark=M.oak("Study recessed panels",(.038,.016,.009),.4,8,axis="Z")
    stone=M.stone("Warm study plaster",(.085,.068,.048),.25,7)
    oak_table.build("Scholar desk",loc=(0,5,-76),width=118,depth=72,height=75.7,
                    thickness=3.8,wood_tone=(.07,.026,.008),wear=.25,scorch=0,seed=11,rear_recess=(16,30))
    velvet_drape.build("Star embroidered desk velvet",loc=(-43,-2,top),width=44,
                       length=72,drop=18,tone=(.008,.020,.06),stars=18,seed=8,
                       sheen_tone=(.08,.13,.32),stitch_width=.05,heap=5.5,
                       sweep=11,sweep_peak=.53,edge_fraction=.10,star_scale=2.7,star_spacing=5.5,star_band=(.35,.90,.22,.9),rest_patches=((7,15,3.6),(1,3,3.2),(11.5,18,4),(20,31,4.5)))
    writing_set.build("Quill and inkwell",loc=(-31.5,16,top+.17),width=5.6,height=5.8,quill_length=21,seed=4)
    runestone_bowl.build("Luminous blue basin",loc=(-23,29,top+.17),radius=6.5,height=4.8,energy=170,seed=7)
    astronomer_tools.build("Study parchment chart",loc=(42,17,top+.05),rot_z=-.18,
                           kind="chart",width=17,depth=24,seed=8)
    writing_set.build("Rolled scholar scroll",loc=(42,29,top+.1),rot_z=-.18,kind="scroll",width=17,seed=12)
    astronomer_tools.build("Desk magnifier",loc=(38,16,top+.65),rot_z=-.5,kind="magnifier",radius=3.2,seed=8)
    astronomer_tools.build("Pierced brass censer",loc=(29,16,top),kind="incense",radius=3.5,seed=15)
    fixtures.block("Player oak floor",(360,104,8),(0,-7,-80),dark,.5)
    fixtures.block("Library lower floor",(430,80,8),(0,90,-149),dark,.5)
    fixtures.block("Back library floor",(480,190,8),(0,225,-174),dark,.5)
    stone_steps.build("Library shallow stair",loc=(135,130,-170),width=60,tread=9,rise=5,count=5,tone=(.10,.063,.032))
    stone_steps.build("Study stair",loc=(125,52,-145),width=70,tread=11.5,rise=11.5,count=6,tone=(.10,.063,.032))
    candlestick.build("Tall left candle",loc=(-37,34,top),height=7,radius=4.2,candle_height=12,
                       candle_radius=1.8,energy=1800,seed=3)
    candlestick.build("Short left candle",loc=(-36,13,top+.17),height=4,radius=3.4,candle_height=9,
                       energy=1100,seed=9)
    candlestick.build("Foreground left taper",loc=(-42,1,top+.17),height=3,radius=3.0,candle_height=8,
                       energy=650,seed=12)
    for i in range(3):
        book.build(f"Left stacked grimoire {i}",loc=(-54,29,top+i*4.4),rot_z=math.pi/2-.12+i*.06,
                   width=22,depth=25,thickness=4.4,tone=(.018,.023,.039),seed=4+i,gilt_spine=True)
    oak_table.build("Instrument reading table",loc=(-3,64,-145),width=44,depth=35,height=118,
                    wood_tone=(.07,.026,.008),scorch=0,seed=14)
    armillary.build("Brass scholar armillary",loc=(-3,64,-27),radius=12,pedestal=10,seed=8)
    for i in range(4):
        book.build(f"Right stacked codex {i}",loc=(34,36,top+i*4.3),rot_z=.9+.12-i*.047,
                   width=17,depth=22,thickness=4.3,tone=(.028,.012,.009),seed=30+i,gilt_spine=True)
    candlestick.build("Right desktop candle",loc=(13,66,-27),height=10,radius=3.2,
                       candle_height=10,energy=1800,seed=5)
    for label,x,y in (("Basin candle",-18,38),("Codex candle",17.5,33)):
        candlestick.build(label,loc=(x,y,top),height=2,radius=1.7,candle_height=5,
                           candle_radius=.9,energy=950,seed=18 if x<0 else 23)
    backdrop_before=set(bpy.data.objects)
    # The surrounding wall is real panel construction with a clear window aperture.
    for x,w in ((-99,268),(226,110)):
        fixtures.block("Study back plaster",(w,8,260),(x,292,-20),stone,.2)
        for j in range(max(1,int(w/25))):
            xx=x-w/2+13+j*25
            fixtures.block("Recessed oak wall panel",(22,2,72),(xx,286,-122),dark,.35)
            fixtures.block("Wall panel stile",(2.2,3,76),(xx-12,284,-122),oak,.25)
    fixtures.block("Window wall below sill",(130,9,75),(99,292,-204),stone,.3)
    fixtures.block("Window wall above arch",(130,9,120),(99,292,64),stone,.3)
    gothic_window.build("Moonlit Gothic window",loc=(99,285,-166),width=110,height=170,
                         reveal=17,stone_tone=(.095,.075,.055),sky_strength=2.6,
                         moon_strength=3.7,moon_offset=.67,energy=70000,exterior_slope=.46,seed=12)
    bookcase.build("Left tall library",loc=(-39,232,-170),width=145,height=236,depth=31,rows=7,seed=3)
    bookcase.build("Left returning library",loc=(-127,193,-170),rot_z=math.pi/2,
                    width=120,height=236,depth=29,rows=7,seed=9)
    bookcase.build("Right tall library",loc=(206,264,-170),width=100,height=236,depth=31,rows=7,seed=16)
    for x,z in ((33,-67),(166,-65)):
        fixtures.block("Window candle bracket",(13,17,3),(x,267,z-1.5),oak,.4)
        fixtures.beam("Window bracket scroll support",(x,275,z-18),(x,261,z-3),3,3,oak,.5)
        candlestick.build("Window sill taper",loc=(x,267,z),height=12,radius=3.2,
                           candle_height=11,energy=4000,seed=int(x+60))
    for ob in set(bpy.data.objects)-backdrop_before:
        if ob.parent is None:
            ob.location.z-=8
            ob.location.x-=30
        elif ob.parent==fixtures.root:
            ob.location.z-=8
            ob.location.x-=30
    def area(name,loc,target,energy,color,size,gloss=True):
        ob=fixtures.light(name,loc,energy,color,size,target=target,kind="AREA")
        ob.visible_glossy=gloss;ob.data.specular_factor=1 if gloss else .12
        return ob
    area("Candle pool on desk",(-33,28,20),(-20,15,0),19000,(1,.70,.36),17,False)
    area("Candle catches quill and embroidery",(-34,25,24),(-36,8,2),20000,(1,.76,.48),17)
    area("Moon caught in velvet pile",(-35,7,25),(-29,12,0),2800,(.35,.50,1),22,False)
    area("Blue basin reflected accent",(-23,32,8),(-26,23,2),600,(.035,.19,1),10,False)
    area("Window cool desk edge",(31,104,38),(6,22,0),10000,(.42,.57,1),30,False)
    area("Left candle brass highlights",(-31,47,12),(-3,70,-19),18000,(1,.69,.35),18)
    area("Warm library candle pool",(-74,169,-38),(-69,231,-58),160000,(1,.64,.31),36)
    area("Left return candle pool",(-107,149,-28),(-157,193,-58),100000,(1,.64,.31),32)
    area("Right candle book pool",(23,33,24),(38,28,8),17000,(1,.71,.40),18)
    area("Right shelf candle glow",(137,224,-43),(175,264,-58),90000,(1,.61,.27),35)
    area("Moon on tracery and brass",(50,274,-20),(-15,155,-50),105000,(.38,.54,1),55)
    area("Window sill warm left",(3,261,-42),(3,285,-74),18000,(1,.58,.23),16)
    area("Window sill warm right",(135,261,-40),(135,285,-72),18000,(1,.58,.23),16)
    receivers=bpy.data.collections.new("Arcane environment light receivers")
    for ob in set(bpy.data.objects)-before:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    group=G.Asset("Arcane room frame",rot_z=-math.pi/2+.36)
    for ob in set(bpy.data.objects)-before:
        if ob.type=="LIGHT":
            ob.light_linking.receiver_collection=receivers
            ob.data.energy *= 2.1
        if ob!=group.root and ob.parent is None:group.add(ob)
    floor_receivers=bpy.data.collections.new("Arcane brass field candle return")
    floor_receivers.objects.link(bpy.data.objects["board"])
    for ob in bpy.data.objects:
        if ob.name == "rim_cap" or ob.name.startswith("rim_boss"):
            floor_receivers.objects.link(ob)
    bounce=E.light(scene,"AREA","Candle return on brass field",(5,-24,34),9000,
                    color=(1,.79,.49),size=25,target=(0,-6,0))
    bounce.light_linking.receiver_collection=floor_receivers
    reflection=E.light(scene,"AREA","Candle reflected in brass ground",(20,10,29),14500,
                        color=(1,.89,.70),size=40,target=(0,0,0))
    reflection.light_linking.receiver_collection=floor_receivers
    return dict(loc=(-18,-9,21.2),target=(0,0,7),lens=20.4,
                fstop=8*scene.unit_settings.scale_length,focus=(1,0,1.4))
