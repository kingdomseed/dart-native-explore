"""Centimetre-scale PBR surfaces; each builder owns its material variants."""
import math
import env_common as E


def bench_walnut(name="Rubbed walnut",tone=(.11,.046,.018),wear=.6,seed=1):
    m,k=E.material(name)
    v=mapped(k,(.045,1.6,.8),seed)
    grain=k.noise(v,2,4,.68,dist=.35).outputs["Fac"]
    pores=k.noise(mapped(k,(.12,11,2),seed),2,2).outputs["Fac"]
    col=k.ramp(grain,[(.25,tuple(c*.22 for c in tone)),(.43,tuple(c*.65 for c in tone)),(.65,tone),(.8,tuple(c*1.4 for c in tone))])
    rough=k.math("ADD",.24,k.math("MULTIPLY",grain,.2*wear))
    k.surface(k.bsdf(Base_Color=col,Roughness=rough,Metallic=0,
        Coat_Weight=.28,Coat_Roughness=.24,Normal=k.bump(pores,.22,.012)))
    return m


def atelier_sky(name="Clouded sunset",strength=1.3,seed=1):
    m,k=E.material(name)
    coord=k.coords().outputs["Generated"]
    sep=k.node("ShaderNodeSeparateXYZ");k.link(coord,sep.inputs[0])
    col=k.ramp(sep.outputs["Z"],[(0,(.11,.12,.19)),(.43,(.42,.20,.16)),(.51,(.88,.46,.20)),(.59,(.25,.19,.31)),(.8,(.055,.105,.23)),(1,(.015,.035,.09))])
    mapping=k.node("ShaderNodeMapping");k.link(coord,mapping.inputs["Vector"])
    mapping.inputs["Scale"].default_value=(2,2,14)
    n=k.noise(mapping.outputs[0],3,4,.7,dist=.5).outputs["Fac"]
    mask=k.ramp(n,[(.4,(0,0,0)),(.58,(.55,.55,.55)),(.78,(.9,.9,.9))])
    col=k.mix(mask,col,(.06,.08,.145,1))
    k.surface(k.emission(col,strength))
    return m


def cut_stone(name="Faceted coloured crystal", tone=(.025,.46,.19), wear=.1, seed=1, ior=1.78):
    m,k=E.material(name)
    n=k.noise(mapped(k,(.6,.6,.6),seed),2,2).outputs["Fac"]
    col=k.mix(k.math("MULTIPLY",n,.14),(*tone,1),tuple(min(1,c*1.4+.04) for c in tone)+(1,))
    k.surface(k.bsdf(Base_Color=col,Metallic=0,Roughness=k.math("ADD",.025,k.math("MULTIPLY",n,wear*.08)),
                     Transmission_Weight=.93,IOR=ior,Coat_Weight=.25,Coat_Roughness=.035))
    return m


def urushi(name="Hand-polished lacquer", tone=(.016,.005,.004), wear=.35, seed=1):
    m,k=E.material(name)
    vec=mapped(k,(1,1,1),seed)
    n=k.noise(vec,.75,3).outputs["Fac"]
    slow=k.noise(vec,.06,2).outputs["Fac"]
    col=k.mix(slow,tuple(c*.65 for c in tone)+(1,),tuple(c*1.4 for c in tone)+(1,))
    geo=k.node("ShaderNodeNewGeometry")
    edge=k.math("MINIMUM",k.math("MULTIPLY",k.math("MAXIMUM",k.math("SUBTRACT",geo.outputs["Pointiness"],.49),0),wear*12),.18)
    col=k.mix(edge,col,(.11,.025,.009,1))
    k.surface(k.bsdf(Base_Color=col,Roughness=k.math("ADD",.2,k.math("MULTIPLY",n,.13*wear)),
        Coat_Weight=.7,Coat_Roughness=.13,Normal=k.bump(n,.12,.012*wear)))
    return m


def washi(name="Mulberry paper", tone=(.75,.56,.32), glow=.5, seed=1):
    m,k=E.material(name)
    vec=mapped(k,(1.1,1.1,.16),seed)
    fibers=k.noise(vec,4,3).outputs["Fac"]
    cloud=k.noise(vec,.13,3).outputs["Fac"]
    col=k.mix(k.math("MULTIPLY",cloud,.35),(*tone,1),(.92,.83,.61,1))
    sep=k.node("ShaderNodeSeparateXYZ");k.link(k.coords().outputs["Generated"],sep.inputs[0])
    core=k.math("MAXIMUM",k.math("SUBTRACT",1,k.math("MULTIPLY",k.math("ABSOLUTE",k.math("SUBTRACT",sep.outputs["Z"],.48)),1.8)),0)
    strength=k.math("MULTIPLY",glow,k.math("ADD",.3,k.math("MULTIPLY",core,1.4)))
    diffuse=k.bsdf(Base_Color=col,Roughness=.85,Normal=k.bump(fibers,.16,.017),
        Emission_Color=(*tone,1),Emission_Strength=strength)
    trans=k.node("ShaderNodeBsdfTranslucent");k.link(col,trans.inputs["Color"])
    k.surface(k.mix_shader(.32,diffuse,trans.outputs[0]))
    return m


def rush_weave(name="Woven igusa", tone=(.28,.25,.11), seed=1):
    m,k=E.material(name);v=mapped(k,(1,1,1),seed)
    reed=k.node("ShaderNodeTexWave",bands_direction="Y");k.link(v,reed.inputs["Vector"])
    k.set(reed,Scale=.75,Distortion=.08,Detail=2)
    cross=k.node("ShaderNodeTexWave",bands_direction="X");k.link(v,cross.inputs["Vector"])
    k.set(cross,Scale=.075,Distortion=.2,Detail=2)
    n=k.noise(v,.2,3).outputs["Fac"]
    col=k.mix(n,tuple(c*.7 for c in tone)+(1,),tuple(c*1.28 for c in tone)+(1,))
    weave=k.math("MULTIPLY",reed.outputs["Fac"],k.math("ADD",.7,k.math("MULTIPLY",cross.outputs["Fac"],.3)))
    k.surface(k.bsdf(Base_Color=k.mix(k.math("MULTIPLY",weave,.5),col,(.15,.13,.055,1)),
        Roughness=.73,Normal=k.bump(weave,.28,.045)))
    return m


def woven_silk(name="Figured silk", tone=(.012,.025,.035), seed=1):
    m,k=E.material(name);vec=mapped(k,(1,1,1),seed)
    n=k.noise(vec,12,2).outputs["Fac"]
    sep=k.node("ShaderNodeSeparateXYZ");k.link(vec,sep.inputs[0])
    wave=k.math("MULTIPLY",k.math("SINE",k.math("MULTIPLY",sep.outputs["X"],1.7)),k.math("SINE",k.math("MULTIPLY",sep.outputs["Y"],1.7)))
    pattern=k.math("GREATER_THAN",wave,.82)
    col=k.mix(pattern,(*tone,1),(.19,.115,.033,1))
    k.surface(k.bsdf(Base_Color=col,Roughness=.7,Sheen_Weight=.3,Sheen_Roughness=.5,Sheen_Tint=tuple(min(1,c*3) for c in tone)+(1,),Normal=k.bump(n,.2,.013)))
    return m


def gold_leaf(name="Laid gold leaf", wear=.3, seed=1):
    m,k=E.material(name);vec=mapped(k,(1,1,1),seed)
    patches=k.noise(vec,.045,3).outputs["Fac"]
    creases=k.noise(vec,2,2).outputs["Fac"]
    cells=k.voronoi(vec,.09).outputs["Color"]
    col=k.mix(k.math("MULTIPLY",patches,.35),(.63,.34,.075,1),(.86,.61,.24,1))
    col=k.mix(.035,col,cells)
    k.surface(k.bsdf(Base_Color=col,Metallic=1,Roughness=k.math("ADD",.33,k.math("MULTIPLY",patches,.15)),Normal=k.bump(creases,.16,.012*wear)))
    return m


def aged_plastic(name="Warm ABS", tone=(.52,.47,.34), wear=.4, seed=1):
    m,k=E.material(name)
    vec=mapped(k,(1,1,1),seed)
    n=k.noise(vec,.13,3).outputs["Fac"]
    micro=k.noise(vec,5,2).outputs["Fac"]
    col=k.mix(k.math("MULTIPLY",n,wear*.32),(*tone,1),tuple(c*.55 for c in tone)+(1,))
    k.surface(k.bsdf(Base_Color=col,Roughness=k.math("ADD",.31,k.math("MULTIPLY",n,.16)),
                     Normal=k.bump(micro,.11,.006)))
    return m


def toast_crumb(name="Toasted bread crumb", seed=1):
    m,k=E.material(name)
    vec=mapped(k,(1,1,1),seed)
    n=k.noise(vec,.7,4).outputs["Fac"]
    pores=k.voronoi(vec,5).outputs["Distance"]
    pits=k.ramp(pores,[(.04,(0,0,0)),(.14,(.25,.25,.25)),(.23,(1,1,1))])
    col=k.ramp(n,[(.20,(.07,.018,.003)),(.45,(.32,.13,.032)),(.68,(.66,.41,.15)),(.86,(.78,.57,.27))])
    col=k.mix(.48,col,k.mix(pits,(.05,.018,.005,1),col))
    k.surface(k.bsdf(Base_Color=col,Roughness=.76,Normal=k.bump(pores,.7,.12)))
    return m


def foliage(name="Waxy foliage", tone=(.09,.17,.025), seed=1):
    m,k=E.material(name)
    n=k.noise(mapped(k,(1,1,1),seed),2,3).outputs["Fac"]
    col=k.mix(n,tuple(c*.5 for c in tone)+(1,),(*tone,1))
    k.surface(k.bsdf(Base_Color=col,Roughness=.48,Subsurface_Weight=.06,
                     Normal=k.bump(n,.08,.018)))
    return m


def wood_laminate(name="Walnut print laminate", tone=(.24,.105,.032), wear=.4, seed=1):
    m,k=E.material(name)
    vec=mapped(k,(.035,.72,.72),seed)
    grain=k.noise(vec,1.5,4,.65,dist=.45).outputs["Fac"]
    wave=k.node("ShaderNodeTexWave",wave_type="BANDS",bands_direction="Y")
    k.link(vec,wave.inputs["Vector"])
    k.set(wave,Scale=.7,Distortion=8,Detail=4,Detail_Scale=.5)
    col=k.ramp(grain,[(.22,tuple(c*.19 for c in tone)),(.49,tone),(.78,tuple(c*1.8 for c in tone))])
    col=k.mix(.21,col,k.mix(wave.outputs["Fac"],tuple(c*.3 for c in tone)+(1,),col))
    rough=k.math("ADD",.22,k.math("MULTIPLY",grain,.15*wear))
    k.surface(k.bsdf(Base_Color=col,Roughness=rough,Coat_Weight=.45,Coat_Roughness=.18,
                     Normal=k.bump(wave.outputs["Fac"],.04,.008)))
    return m


def figured_laminate(name="Figured walnut laminate", tone=(.14,.065,.023), wear=.5, seed=1):
    m,k=E.material(name)
    vec=mapped(k,(.055,.32,.32),seed)
    broad=k.noise(vec,1.4,3,.65,dist=.8).outputs["Fac"]
    wave=k.node("ShaderNodeTexWave",wave_type="BANDS",bands_direction="Y")
    k.link(vec,wave.inputs["Vector"])
    k.set(wave,Scale=2.2,Distortion=12,Detail=4,Detail_Scale=.65)
    grain=k.noise(mapped(k,(.08,2.4,1),seed),1,3).outputs["Fac"]
    col=k.ramp(broad,[(.2,tuple(c*.30 for c in tone)),(.46,tone),(.74,tuple(c*1.75 for c in tone))])
    line=k.ramp(wave.outputs["Fac"],[(.18,(.12,.12,.12)),(.42,(.65,.65,.65)),(.72,(1,1,1))])
    col=k.mix(.32,col,k.mix(line,tuple(c*.28 for c in tone)+(1,),col))
    col=k.mix(.12,col,k.mix(grain,tuple(c*.38 for c in tone)+(1,),col))
    scuff=k.noise(mapped(k,(.12,.13,.1),seed+3),1,3).outputs["Fac"]
    rough=k.math("ADD",.19,k.math("MULTIPLY",scuff,wear*.36))
    k.surface(k.bsdf(Base_Color=col,Roughness=rough,Coat_Weight=.3,Coat_Roughness=.22,
                     Normal=k.bump(grain,.10,.012)))
    return m


def retro_flower(name="1970s floral print", tone=(.58,.49,.31), ink=(.22,.25,.055), scale=.15,
                 axes=("X","Z"), ceramic=False, seed=1):
    m,k=E.material(name)
    sep=k.node("ShaderNodeSeparateXYZ"); k.link(k.coords().outputs["Object"],sep.inputs[0])
    x=k.math("SUBTRACT",k.math("FRACT",k.math("MULTIPLY",sep.outputs[axes[0]],scale)),.5)
    y=k.math("SUBTRACT",k.math("FRACT",k.math("MULTIPLY",sep.outputs[axes[1]],scale)),.5)
    r=k.math("SQRT",k.math("ADD",k.math("MULTIPLY",x,x),k.math("MULTIPLY",y,y)))
    angle=k.math("ARCTAN2",y,x)
    petal=k.math("ADD",.24,k.math("MULTIPLY",k.math("COSINE",k.math("MULTIPLY",angle,6)),.11))
    flower=k.math("MULTIPLY",k.math("LESS_THAN",r,petal),k.math("GREATER_THAN",r,.065))
    dot=k.math("LESS_THAN",r,.039)
    mask=k.math("MAXIMUM",flower,dot)
    n=k.noise(mapped(k,(1,1,1),seed),3,2).outputs["Fac"]
    col=k.mix(mask,(*tone,1),(*ink,1))
    k.surface(k.bsdf(Base_Color=col,Roughness=.25 if ceramic else .78,Coat_Weight=.4 if ceramic else 0,
                     Normal=k.bump(n,.12,.008 if ceramic else .025)))
    return m


def mapped(k, scale, seed=0):
    mapping = k.node("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = scale
    mapping.inputs["Location"].default_value = (seed * 7.31, seed * 2.47, seed * 11.17)
    k.link(k.coords().outputs["Object"], mapping.inputs["Vector"])
    return mapping.outputs[0]


def oak(name="Oiled oak", tone=(0.12, 0.047, 0.016), wear=0.4, seed=0, axis="X", grain_scale=1.0):
    m, k = E.material(name)
    scale = {"X": (0.018, 0.32, 0.32), "Y": (0.32, 0.018, 0.32), "Z": (0.32, 0.32, 0.018)}[axis]
    vec = mapped(k, tuple(v * grain_scale for v in scale), seed)
    grain = k.noise(vec, 1, 4, 0.7, dist=0.45).outputs["Fac"]
    wave = k.node("ShaderNodeTexWave")
    wave.bands_direction = "Y" if axis == "X" else "X"
    k.link(vec, wave.inputs["Vector"])
    k.set(wave, Scale=0.55, Distortion=7.5, Detail=3, Detail_Scale=0.6, Detail_Roughness=0.7)
    rings = wave.outputs["Color"]
    pores = k.ramp(rings, [(0.25, (0.08, 0.08, 0.08)), (0.42, (0.4, 0.4, 0.4)), (0.6, (1, 1, 1))])
    col = k.ramp(grain, [(0.24, tuple(c * 0.19 for c in tone)), (0.48, tuple(c * 0.65 for c in tone)),
                         (0.62, tone), (0.8, tuple(c * 1.8 for c in tone))])
    col = k.mix(0.48, col, k.mix(pores, tuple(c * 0.12 for c in tone) + (1,), col))
    geo = k.node("ShaderNodeNewGeometry")
    edge = k.math("MULTIPLY", k.math("MAXIMUM", k.math("SUBTRACT", geo.outputs["Pointiness"], 0.49), 0), wear * 15)
    edge = k.math("MINIMUM", edge, 0.16)
    col = k.mix(edge, col, tuple(c * 2.1 for c in tone) + (1,))
    rough = k.math("ADD", 0.3, k.math("MULTIPLY", grain, 0.34))
    k.surface(k.bsdf(Base_Color=col, Metallic=0, Roughness=rough,
                     Normal=k.bump(rings, 0.2, 0.045), Coat_Weight=0.18, Coat_Roughness=0.32))
    return m


def weathered_oak(name="Weathered tavern oak", tone=(.035,.015,.005), wear=.8, seed=0, axis="X", grain_scale=1):
    m,k=E.material(name)
    scale=(.055,1.1,.8) if axis=="X" else (1.1,.055,.8)
    vec=mapped(k,tuple(v*grain_scale for v in scale),seed)
    grain=k.noise(vec,1,5,.72,dist=.35).outputs["Fac"]
    pores=k.voronoi(vec,3,feature="DISTANCE_TO_EDGE").outputs["Distance"]
    channels=k.ramp(pores,[(0,(0,0,0)),(.027,(.18,.18,.18)),(.085,(1,1,1))])
    color=k.ramp(grain,[(.2,tuple(c*.12 for c in tone)),(.45,tuple(c*.55 for c in tone)),(.62,tone),(.82,tuple(c*2.4 for c in tone))])
    color=k.mix(k.math("MULTIPLY",k.math("SUBTRACT",1,channels),wear*.7),color,tuple(c*.12 for c in tone)+(1,))
    patches=k.noise(mapped(k,(.09,.09,.09),seed),1,3,.7).outputs["Fac"]
    rough=k.ramp(patches,[(.2,(.25,.25,.25)),(.5,(.43,.43,.43)),(.8,(.67,.67,.67))])
    k.surface(k.bsdf(Base_Color=color,Roughness=rough,Coat_Weight=.14,Coat_Roughness=.25,
                     Normal=k.bump(channels,.36,.065,normal=k.bump(grain,.3,.11))))
    return m


def metal(name="Forged iron", finish="iron", wear=0.4, seed=0):
    m, k = E.material(name)
    vec = mapped(k, (1, 1, 1), seed)
    n = k.noise(vec, 0.5, 3, 0.7).outputs["Fac"]
    patches = k.noise(vec, 0.09, 3).outputs["Fac"]
    tones = {"iron": (0.055, 0.051, 0.047), "steel": (0.42, 0.44, 0.46),
             "brass": (0.48, 0.28, 0.075), "copper": (0.5, 0.18, 0.075), "pewter": (0.39, 0.41, 0.42)}
    tone = tones[finish]
    col = k.ramp(patches, [(0.24, tuple(c * 0.12 for c in tone)), (0.52, tuple(c * 0.65 for c in tone)), (0.8, tone)])
    geo = k.node("ShaderNodeNewGeometry")
    edge = k.math("MULTIPLY", k.math("MAXIMUM", k.math("SUBTRACT", geo.outputs["Pointiness"], 0.49), 0), wear * 16)
    edge = k.math("MINIMUM", edge, 0.3)
    col = k.mix(edge, col, tuple(min(0.7, c * 1.8) for c in tone) + (1,))
    rough = k.ramp(n, [(0.2, (0.2, 0.2, 0.2)), (0.52, (0.4, 0.4, 0.4)), (0.8, (0.68, 0.68, 0.68))])
    if finish == "iron":
        rough = k.math("MAXIMUM", rough, 0.48)
    dents = k.node("ShaderNodeTexVoronoi")
    k.link(vec, dents.inputs["Vector"])
    dents.inputs["Scale"].default_value = 1.8 if finish == "copper" else 3
    normal = k.bump(dents.outputs["Distance"], 0.28, 0.07 if finish == "copper" else 0.025)
    normal = k.bump(n, 0.25, 0.04, normal=normal)
    k.surface(k.bsdf(Base_Color=col, Metallic=1, Roughness=rough, Normal=normal))
    return m


def stone(name="Hewn stone", tone=(0.105, 0.10, 0.085), wear=0.5, seed=0, soot=0):
    m, k = E.material(name)
    vec = mapped(k, (1, 1, 1), seed)
    n = k.noise(vec, 0.24, 4, 0.75).outputs["Fac"]
    small = k.noise(vec, 1.1, 3, 0.7).outputs["Fac"]
    col = k.ramp(n, [(0.2, tuple(c * 0.2 for c in tone)), (0.49, tuple(c * 0.7 for c in tone)),
                     (0.8, tuple(c * 1.3 for c in tone))])
    if soot:
        patch = k.math("MULTIPLY", k.math("ADD", 0.58, k.math("MULTIPLY", n, 0.7)), soot, clamp=True)
        col = k.mix(patch, col, (0.004, 0.003, 0.0025, 1))
    bump = k.bump(n, 0.65, 0.85 * wear)
    bump = k.bump(small, 0.3, 0.12, normal=bump)
    k.surface(k.bsdf(Base_Color=col, Metallic=0, Roughness=k.math("ADD", 0.7, k.math("MULTIPLY", n, 0.25)), Normal=bump))
    return m


def leather(name="Leather", tone=(0.065, 0.019, 0.008), wear=0.5, seed=0, tooling_rings=()):
    m, k = E.material(name)
    vec = mapped(k, (1, 1, 1), seed)
    n = k.noise(vec, 0.5, 3).outputs["Fac"]
    pore = k.noise(vec, 9, 2).outputs["Fac"]
    col = k.ramp(n, [(0.2, tuple(c * 0.35 for c in tone)), (0.8, tone)])
    normal = k.bump(pore, 0.16, 0.022)
    if tooling_rings:
        sep = k.node("ShaderNodeSeparateXYZ")
        k.link(k.coords().outputs["Object"], sep.inputs[0])
        x, y = sep.outputs["X"], k.math("ADD", sep.outputs["Y"], 2)
        radius = k.math("SQRT", k.math("ADD", k.math("MULTIPLY", x, x), k.math("MULTIPLY", y, y)))
        groove = 0
        for r in tooling_rings:
            line = k.math("LESS_THAN", k.math("ABSOLUTE", k.math("SUBTRACT", radius, r)), 0.045)
            groove = k.math("MAXIMUM", groove, line)
        theta = k.math("ARCTAN2", y, x)
        phase = k.math("FRACT", k.math("MULTIPLY", theta, 12 / 6.2831853))
        angular = k.math("MULTIPLY", k.math("ABSOLUTE", k.math("SUBTRACT", phase, 0.5)), 2)
        radial = k.math("ABSOLUTE", k.math("DIVIDE", k.math("SUBTRACT", radius, 7.1), 1.1))
        diamond = k.math("LESS_THAN", k.math("ABSOLUTE", k.math("SUBTRACT", k.math("ADD", angular, radial), 1)), 0.055)
        groove = k.math("MAXIMUM", groove, diamond)
        col = k.mix(groove, col, tuple(c * 0.18 for c in tone) + (1,))
        normal = k.bump(groove, 0.7, 0.06, normal=normal, invert=True)
    k.surface(k.bsdf(Base_Color=col, Roughness=k.math("ADD", 0.48, k.math("MULTIPLY", n, wear * 0.35)),
                     Normal=normal, Sheen_Weight=0.15))
    return m


def flame(name="Flame", strength=3):
    m, k = E.material(name)
    vec = k.coords().outputs["Generated"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(vec, sep.inputs[0])
    col = k.ramp(sep.outputs["Z"], [(0, (1, 0.62, 0.16)), (0.35, (1, 0.24, 0.018)),
                                   (0.85, (0.7, 0.045, 0.002)), (1, (0.22, 0.006, 0.001))])
    n = k.noise(vec, 5, 3, 0.65, dist=0.7).outputs["Fac"]
    layer = k.node("ShaderNodeLayerWeight")
    density = k.math("MULTIPLY", k.math("POWER", n, 1.6),
                     k.math("SUBTRACT", 1, layer.outputs["Fresnel"]))
    opacity = k.math("MULTIPLY", density, 2.3, clamp=True)
    emission = k.emission(col, k.math("MULTIPLY", strength, k.math("ADD", 0.4, density)))
    transparent = k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(opacity, transparent, emission))
    return m



def forge_flame(name="Forge flame", strength=28):
    m, k = E.material(name)
    uv = k.coords().outputs["UV"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(uv, sep.inputs[0])
    height = sep.outputs["Y"]
    col = k.ramp(height, [(0, (1, 0.92, 0.48)), (0.14, (1, 0.65, 0.08)),
                          (0.42, (1, 0.19, 0.007)), (0.76, (0.75, 0.028, 0.001)),
                          (1, (0.35, 0.003, 0.0003))])
    edge = k.math("POWER", k.math("MAXIMUM", 0, k.math("SINE", k.math("MULTIPLY", sep.outputs["X"], 3.141593))), 0.7)
    fade = k.ramp(height, [(0, (0, 0, 0)), (0.055, (0.78, 0.78, 0.78)), (0.25, (0.86, 0.86, 0.86)),
                           (0.65, (0.38, 0.38, 0.38)), (0.98, (0, 0, 0))])
    mapping = k.node("ShaderNodeVectorMath")
    mapping.operation = "MULTIPLY"
    k.link(uv, mapping.inputs[0])
    mapping.inputs[1].default_value = (3, 7, 1)
    n = k.noise(mapping.outputs[0], 1.6, 2, 0.6, dist=0.4).outputs["Fac"]
    wisps = k.ramp(n, [(0.22, (0.06, 0.06, 0.06)), (0.48, (0.7, 0.7, 0.7)), (0.74, (1, 1, 1))])
    opacity = k.math("MULTIPLY", k.math("MULTIPLY", edge, fade), wisps)
    transparent = k.node("ShaderNodeBsdfTransparent").outputs[0]
    heat = k.ramp(height, [(0, (1, 1, 1)), (0.22, (0.6, 0.6, 0.6)),
                           (0.55, (0.15, 0.15, 0.15)), (1, (0.035, 0.035, 0.035))])
    k.surface(k.mix_shader(opacity, transparent, k.emission(col, k.math("MULTIPLY", strength, heat))))
    return m


def coal(name="Cracked coke", heat=1):
    m, k = E.material(name)
    vec = k.coords().outputs["Generated"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(vec, sep.inputs[0])
    n = k.noise(vec, 5, 3).outputs["Fac"]
    cracks = k.voronoi(vec, 2.4, feature="DISTANCE_TO_EDGE").outputs["Distance"]
    cracks = k.ramp(cracks, [(0, (1, 1, 1)), (0.018, (0.65, 0.65, 0.65)), (0.038, (0, 0, 0))])
    crust = k.ramp(sep.outputs["Z"], [(0, (1, 1, 1)), (0.36, (0.8, 0.8, 0.8)),
                                     (0.66, (0.13, 0.13, 0.13)), (0.85, (0.08, 0.08, 0.08))])
    glow = k.math("MULTIPLY", k.math("MULTIPLY", cracks, crust), 15 * heat)
    col = k.ramp(n, [(0.2, (0.0008, 0.0006, 0.0005)), (0.65, (0.003, 0.0024, 0.002)),
                     (0.85, (0.008, 0.006, 0.004))])
    k.surface(k.bsdf(Base_Color=col, Roughness=0.98, Specular_IOR_Level=0.08,
                     Normal=k.bump(n, 0.6, 0.16),
                     Emission_Color=(1, 0.055 + heat * 0.29, 0.003 + heat * 0.018, 1),
                     Emission_Strength=glow))
    return m

def glass(name="Lantern glass", tone=(0.8, 0.56, 0.3), reflection=0.16):
    m, k = E.material(name)
    pane = k.bsdf(Base_Color=(*tone, 1), Roughness=0.13, Transmission_Weight=1, IOR=1.46)
    tr = k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(reflection, tr, pane))
    return m


def bark(name="Rough oak bark", tone=(0.10, 0.042, 0.016), wear=0.8, seed=0):
    m, k = E.material(name)
    vec = mapped(k, (0.48, 0.48, 0.026), seed)
    ridges = k.voronoi(vec, 2.4, feature="DISTANCE_TO_EDGE").outputs["Distance"]
    n = k.noise(vec, 2, 3, 0.7).outputs["Fac"]
    col = k.ramp(n, [(0.2, tuple(c * 0.15 for c in tone)),
                     (0.5, tuple(c * 0.7 for c in tone)),
                     (0.8, tuple(c * 1.3 + 0.018 for c in tone))])
    split = k.math("LESS_THAN", ridges, 0.045)
    col = k.mix(split, col, (0.009, 0.006, 0.003, 1))
    normal = k.bump(ridges, 0.75, 0.42 * wear)
    normal = k.bump(n, 0.4, 0.18, normal=normal)
    k.surface(k.bsdf(Base_Color=col, Metallic=0, Roughness=0.92, Normal=normal))
    return m


def end_grain(name="Sawn oak end grain", tone=(0.16, 0.085, 0.038), wear=0.8, seed=0):
    m, k = E.material(name)
    vec = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(vec, sep.inputs[0])
    x = k.math("ADD", sep.outputs["X"], 3.2)
    y = k.math("SUBTRACT", sep.outputs["Y"], 1.4)
    radius = k.math("SQRT", k.math("ADD", k.math("MULTIPLY", x, x),
                                    k.math("MULTIPLY", k.math("MULTIPLY", y, y), 1.13)))
    n = k.noise(vec, 0.16, 3, 0.7).outputs["Fac"]
    radius = k.math("ADD", radius, k.math("MULTIPLY", n, 2.5))
    ring = k.math("SINE", k.math("MULTIPLY", radius, 5.2))
    latewood = k.math("GREATER_THAN", ring, 0.65)
    col = k.ramp(n, [(0.2, tuple(c * 0.48 for c in tone)), (0.8, tone)])
    col = k.mix(k.math("MULTIPLY", latewood, 0.55), col, tuple(c * 0.2 for c in tone) + (1,))
    normal = k.bump(ring, 0.25, 0.035 * wear)
    saw = k.noise(mapped(k, (0.025, 1.5, 0.04), seed), 2, 2).outputs["Fac"]
    k.surface(k.bsdf(Base_Color=col, Metallic=0, Roughness=0.86,
                     Normal=k.bump(saw, 0.25, 0.045, normal=normal)))
    return m


def polished_metal(name="Worn chrome", tone=(0.65, 0.68, 0.72), wear=0.35, seed=0, roughness=0.13):
    m, k = E.material(name)
    n = k.noise(mapped(k, (0.7, 0.7, 0.7), seed), 0.3, 2).outputs["Fac"]
    scratches = k.noise(mapped(k, (0.025, 5, 1), seed), 2, 2).outputs["Fac"]
    col = k.mix(k.math("MULTIPLY", n, wear * 0.35), (*tone, 1), tuple(c * 0.55 for c in tone) + (1,))
    rough = k.math("ADD", roughness, k.math("MULTIPLY", n, wear * 0.18))
    k.surface(k.bsdf(Base_Color=col, Metallic=1, Roughness=rough,
                     Normal=k.bump(scratches, 0.12 * wear, 0.006)))
    return m


def machined_metal(name="Aged machine brass", finish="brass", wear=.55, seed=0):
    m,k=E.material(name)
    tones={"brass":(.56,.34,.105),"copper":(.54,.205,.095),"steel":(.39,.43,.46),"iron":(.065,.072,.076)}
    tone=tones[finish]
    vec=mapped(k,(1,1,1),seed)
    stain=k.noise(vec,.19,3,.65).outputs["Fac"]
    tarnish=k.ramp(stain,[(.22,(.06,.06,.06)),(.48,(.7,.7,.7)),(.76,(1,1,1))])
    col=k.mix(wear,(*tone,1),k.mix(tarnish,tuple(c*.2 for c in tone)+(1,),(*tone,1)))
    geo=k.node("ShaderNodeNewGeometry")
    edge=k.math("MULTIPLY",k.math("MAXIMUM",0,k.math("SUBTRACT",geo.outputs["Pointiness"],.495)),wear*22,clamp=True)
    col=k.mix(edge,col,tuple(min(.8,c*1.35) for c in tone)+(1,))
    tool=k.noise(mapped(k,(.035,4,.6),seed),2.5,2).outputs["Fac"]
    pits=k.noise(vec,2.2,2).outputs["Fac"]
    oxidation=k.ramp(pits,[(.40,(0,0,0)),(.55,(0,0,0)),(.67,(1,1,1))])
    oxidation=k.math("MULTIPLY",oxidation,wear*.6)
    col=k.mix(oxidation,col,tuple(c*.10 for c in tone)+(1,))
    rough=k.math("ADD",k.math("ADD",.16,k.math("MULTIPLY",stain,.29*wear)),k.math("MULTIPLY",oxidation,.3))
    normal=k.bump(tool,.15*wear,.012,normal=k.bump(pits,.25*wear,.065))
    k.surface(k.bsdf(Base_Color=col,Metallic=1,Roughness=rough,Normal=normal))
    return m


def ceramic(name="Glazed porcelain", tone=(0.67, 0.62, 0.48), wear=0.25, seed=0):
    m, k = E.material(name)
    n = k.noise(mapped(k, (1, 1, 1), seed), 2, 2).outputs["Fac"]
    col = k.mix(k.math("MULTIPLY", n, wear * 0.16), (*tone, 1), tuple(c * 0.62 for c in tone) + (1,))
    k.surface(k.bsdf(Base_Color=col, Roughness=k.math("ADD", 0.18, k.math("MULTIPLY", n, 0.1)),
                     Coat_Weight=0.4, Coat_Roughness=0.12, Normal=k.bump(n, 0.15, 0.008)))
    return m


def vinyl(name="Diner vinyl", tone=(0.24, 0.014, 0.024), wear=0.45, seed=0):
    m, k = E.material(name)
    n = k.noise(mapped(k, (1, 1, 1), seed), 3, 2).outputs["Fac"]
    col = k.ramp(n, [(0.2, tuple(c * 0.65 for c in tone)), (0.8, tone)])
    k.surface(k.bsdf(Base_Color=col, Roughness=0.32 + wear * 0.12, Coat_Weight=0.35,
                     Coat_Roughness=0.24, Normal=k.bump(n, 0.22, 0.012), Sheen_Weight=0.14))
    return m


def wet_surface(name="Wet dark laminate", tone=(0.013, 0.016, 0.021), wear=0.35, seed=0, quiet=(0, 0)):
    m, k = E.material(name)
    vec = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(vec, sep.inputs[0])
    outside = k.math("MAXIMUM", k.math("MULTIPLY", k.math("SUBTRACT", k.math("ABSOLUTE", sep.outputs["X"]), quiet[0]), 0.5, clamp=True),
                     k.math("MULTIPLY", k.math("SUBTRACT", k.math("ABSOLUTE", sep.outputs["Y"]), quiet[1]), 0.5, clamp=True))
    n = k.noise(vec, 1.4, 2).outputs["Fac"]
    col = k.ramp(n, [(0.25, tuple(c * 0.55 for c in tone)), (0.8, tone)])
    damp = k.noise(vec, 0.08, 2).outputs["Fac"]
    rough = k.mix(outside, (0.32, 0.32, 0.32, 1), k.ramp(damp, [(0.2, (0.045, 0.045, 0.045)), (0.8, (0.095, 0.095, 0.095))]))
    k.surface(k.bsdf(Base_Color=col, Roughness=rough, Coat_Weight=outside,
                     Coat_Roughness=0.035, Normal=k.bump(n, 0.1 * wear, 0.009)))
    return m


def clear_glass(name="Clear glass", roughness=0.035, ior=1.46):
    m, k = E.material(name)
    k.surface(k.bsdf(Base_Color=(0.96, 0.98, 1, 1), Roughness=roughness,
                     Transmission_Weight=1, IOR=ior))
    return m


def steam(name="Coffee steam", strength=1.2, opacity=0.12):
    m, k = E.material(name)
    uv = k.coords().outputs["UV"]
    sep = k.node("ShaderNodeSeparateXYZ"); k.link(uv, sep.inputs[0])
    edge = k.math("POWER", k.math("MAXIMUM", 0, k.math("SINE", k.math("MULTIPLY", sep.outputs["X"], 3.14159))), 2)
    fade = k.math("MULTIPLY", k.math("POWER", k.math("SUBTRACT", 1, sep.outputs["Y"]), 2),
                  k.math("MINIMUM", 1, k.math("MULTIPLY", sep.outputs["Y"], 8)))
    n = k.noise(uv, 2.5, 2, dist=0.3).outputs["Fac"]
    alpha = k.math("MULTIPLY", k.math("MULTIPLY", edge, fade), k.math("MULTIPLY", n, opacity))
    tr = k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(alpha, tr, k.emission((0.45, 0.55, 0.65, 1), strength)))
    return m


def pastry(name="Baked pastry", seed=0):
    m, k = E.material(name)
    n = k.noise(mapped(k, (1, 1, 1), seed), 0.6, 3).outputs["Fac"]
    col = k.ramp(n, [(0.18, (0.09, 0.024, 0.006)), (0.52, (0.36, 0.15, 0.035)), (0.8, (0.55, 0.32, 0.1))])
    k.surface(k.bsdf(Base_Color=col, Roughness=0.6, Normal=k.bump(n, 0.35, 0.05)))
    return m


def rain_pane(name="Rain pane", fog=0.25):
    m, k = E.material(name)
    vec = k.coords().outputs["Generated"]
    sep = k.node("ShaderNodeSeparateXYZ"); k.link(vec, sep.inputs[0])
    low = k.math("MULTIPLY", k.math("MAXIMUM", 0, k.math("SUBTRACT", 0.25, sep.outputs["Z"])), fog)
    pane = k.bsdf(Base_Color=(0.88, 0.93, 1, 1), Roughness=k.math("ADD", 0.035, low), Transmission_Weight=1, IOR=1.46)
    tr = k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(k.math("ADD", 0.055, low), tr, pane))
    return m


def wet_asphalt(name="Wet asphalt", seed=0):
    m, k = E.material(name)
    vec = mapped(k, (1, 1, 1), seed)
    n = k.noise(vec, 1.7, 2).outputs["Fac"]
    ripple = k.noise(mapped(k, (0.025, 0.6, 1), seed), 1.2, 2).outputs["Fac"]
    col = k.ramp(n, [(0.2, (0.008, 0.011, 0.017)), (0.8, (0.019, 0.025, 0.033))])
    k.surface(k.bsdf(Base_Color=col, Roughness=k.math("ADD", 0.055, k.math("MULTIPLY", ripple, 0.07)),
                     Coat_Weight=1, Coat_Roughness=0.035,
                     Normal=k.bump(ripple, 0.5, 0.22)))
    return m


def rain_streak(name="Backlit falling rain", strength=1):
    m, k = E.material(name)
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(k.coords().outputs["UV"], sep.inputs[0])
    x = k.math("POWER", k.math("SINE", k.math("MULTIPLY", sep.outputs["X"], math.pi)), 2)
    y = k.math("SINE", k.math("MULTIPLY", sep.outputs["Y"], math.pi))
    alpha = k.math("MULTIPLY", k.math("MULTIPLY", x, y), 0.28)
    transparent = k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(alpha, transparent, k.emission((0.48, 0.64, 0.8, 1), strength)))
    return m


def fine_marble(name="Warm statuary marble", tone=(0.46, 0.43, 0.37), wear=0.35, seed=0, quiet=(0, 0), polish=0):
    m, k = E.material(name)
    vec = mapped(k, (0.045, 0.045, 0.065), seed)
    n = k.noise(vec, 1, 4, 0.62, dist=0.35).outputs["Fac"]
    vein = k.ramp(n, [(0.455, (0,0,0)), (0.474, (0.48,0.48,0.48)),
                      (0.481, (0.75,0.75,0.75)), (0.493, (0,0,0))])
    if quiet != (0, 0):
        sep = k.node("ShaderNodeSeparateXYZ")
        k.link(k.coords().outputs["Object"], sep.inputs[0])
        outside = k.math("MAXIMUM", k.math("SUBTRACT", k.math("ABSOLUTE", sep.outputs["X"]), quiet[0]),
                         k.math("SUBTRACT", k.math("ABSOLUTE", sep.outputs["Y"]), quiet[1]))
        vein = k.math("MULTIPLY", vein, k.math("MAXIMUM", 0.14, k.math("MULTIPLY", k.math("MAXIMUM", 0, outside), 0.2, clamp=True)))
    col = k.mix(vein, (*tone,1), tuple(c*0.42 for c in tone)+(1,))
    n2 = k.noise(vec, 8, 2).outputs["Fac"]
    k.surface(k.bsdf(Base_Color=col, Roughness=k.math("ADD", 0.19-0.10*polish, k.math("MULTIPLY", n2, wear*0.27)),
                     Coat_Weight=0.28+0.3*polish, Coat_Roughness=0.16-0.11*polish, Subsurface_Weight=0.04,
                     Normal=k.bump(n2, 0.12, 0.009)))
    return m


def velvet(name="Violet silk velvet", tone=(0.045,0.008,0.075), wear=0.35, seed=0, sheen_tone=(.16,.025,.26)):
    m, k = E.material(name)
    vec = mapped(k, (0.12,0.12,0.12), seed)
    n = k.noise(vec, 1, 2).outputs["Fac"]
    col = k.mix(n, tuple(c*0.4 for c in tone)+(1,), (*tone,1))
    k.surface(k.bsdf(Base_Color=col, Roughness=0.92, Sheen_Weight=0.55, Sheen_Roughness=0.65, Sheen_Tint=(*sheen_tone,1),
                     Normal=k.bump(k.noise(vec, 80, 2).outputs["Fac"], 0.15, 0.009)))
    return m


def amethyst(name="Amethyst quartz", tone=(0.21,0.055,0.38), seed=0):
    m, k = E.material(name)
    sep=k.node("ShaderNodeSeparateXYZ"); k.link(k.coords().outputs["Generated"],sep.inputs[0])
    col=k.ramp(sep.outputs["Z"],[(0,tuple(c*0.42 for c in tone)),(0.65,tone),(1,(0.65,0.42,0.78))])
    k.surface(k.bsdf(Base_Color=col, Metallic=0, Roughness=0.075, Transmission_Weight=0.82,
                     IOR=1.55, Coat_Weight=0.4, Coat_Roughness=0.055))
    return m


def night_sky(name="Indigo galaxy", strength=1, seed=0):
    m,k=E.material(name)
    uv=k.coords().outputs["Generated"]
    sep=k.node("ShaderNodeSeparateXYZ"); k.link(uv,sep.inputs[0])
    n=k.noise(uv,7,5,0.7,dist=0.3).outputs["Fac"]
    axis=k.math("ABSOLUTE",k.math("SUBTRACT",sep.outputs["Z"],k.math("ADD",0.32,k.math("MULTIPLY",sep.outputs["X"],0.65))))
    band=k.ramp(axis,[(0,(1,1,1)),(0.025,(0.8,0.8,0.8)),(0.095,(0.22,0.22,0.22)),(0.19,(0,0,0))])
    dust=k.ramp(n,[(0.28,(0.02,0.02,0.02)),(0.48,(0.18,0.18,0.18)),(0.66,(0.8,0.8,0.8)),(0.8,(1,1,1))])
    base=k.ramp(sep.outputs["Z"],[(0,(0.04,0.064,0.13)),(0.45,(0.009,0.022,0.055)),(1,(0.0015,0.003,0.012))])
    col=k.mix(k.math("MULTIPLY",band,dust),base,(0.26,0.21,0.37,1))
    star_uv=k.node("ShaderNodeCombineXYZ")
    k.link(k.math("MULTIPLY",sep.outputs["X"],1.875),star_uv.inputs["X"])
    k.link(sep.outputs["Z"],star_uv.inputs["Y"])
    star=0
    for scale,size,power in ((170,.08,4.0),(70,.068,6.0),(24,.046,10.0)):
        v=k.voronoi(star_uv.outputs[0],scale)
        v.voronoi_dimensions="2D"
        mask=k.math("SUBTRACT",1,k.math("DIVIDE",v.outputs["Distance"],size),clamp=True)
        selected=k.math("GREATER_THAN",v.outputs["Color"],.60)
        star=k.math("ADD",star,k.math("MULTIPLY",k.math("MULTIPLY",mask,selected),power))
    k.surface(k.add_shader(k.emission(col,strength),k.emission((0.64,0.77,1,1),star)))
    return m


def moon_surface(name="Moon maria", strength=1.4, seed=0):
    m,k=E.material(name)
    uv=k.coords().outputs["Generated"]
    n=k.noise(uv,5.5,5,0.67,dist=0.28).outputs["Fac"]
    maria=k.ramp(n,[(0.25,(0.15,0.19,0.27)),(0.43,(0.23,0.28,0.37)),
                    (0.55,(0.46,0.52,0.63)),(0.74,(0.63,0.69,0.79))])
    v=k.voronoi(uv,28).outputs["Distance"]
    crater=k.ramp(v,[(0.12,(0.55,0.55,0.55)),(0.20,(0.6,0.6,0.6)),(0.24,(0.95,0.95,0.95)),(0.29,(0.8,0.8,0.8))])
    col=k.mix(0.22,maria,k.mix(crater,(0.10,0.14,0.2,1),maria))
    geo=k.node("ShaderNodeNewGeometry")
    dot=k.node("ShaderNodeVectorMath",operation="DOT_PRODUCT"); k.link(geo.outputs["Normal"],dot.inputs[0]); dot.inputs[1].default_value=(-0.65,-0.65,0.4)
    light=k.ramp(dot.outputs["Value"],[(0,(0.015,0.015,0.015)),(0.18,(0.2,0.2,0.2)),(0.6,(0.9,0.9,0.9)),(1,(1,1,1))])
    k.surface(k.emission(col,k.math("MULTIPLY",light,strength)))
    return m


def cloud_bank(name="Moonlit cloud bank", tone=(0.17,0.2,0.30), seed=0):
    m,k=E.material(name)
    uv=k.coords().outputs["UV"]
    sep=k.node("ShaderNodeSeparateXYZ"); k.link(uv,sep.inputs[0])
    v=k.node("ShaderNodeVectorMath",operation="MULTIPLY"); k.link(uv,v.inputs[0]); v.inputs[1].default_value=(5,1.5,1)
    n=k.noise(v.outputs[0],3,4,0.65,dist=0.35).outputs["Fac"]
    x=k.math("POWER",k.math("SINE",k.math("MULTIPLY",sep.outputs["X"],math.pi)),0.65)
    y=k.math("SINE",k.math("MULTIPLY",sep.outputs["Y"],math.pi))
    shape=k.math("MULTIPLY",x,y)
    alpha=k.ramp(k.math("MULTIPLY",shape,n),[(0.08,(0,0,0)),(0.22,(0.15,0.15,0.15)),(0.34,(0.88,0.88,0.88)),(0.47,(1,1,1))])
    color=k.ramp(n,[(0.2,tuple(c*0.25 for c in tone)),(0.5,tone),(0.78,tuple(c*2 for c in tone))])
    tr=k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(alpha,tr,k.emission(color,1)))
    return m


def frozen_stone(name="Frost-rimed granite", tone=(.14,.18,.23), frost=.7, wear=.6, seed=0, rime_start=.35):
    m,k=E.material(name)
    vec=mapped(k,(1,1,1),seed)
    grain=k.noise(vec,.7,4,.65).outputs["Fac"]
    weather=k.noise(vec,.075,3).outputs["Fac"]
    col=k.ramp(grain,[(.2,tuple(c*.38 for c in tone)),(.55,tone),(.8,tuple(c*1.45 for c in tone))])
    normal=k.bump(grain,.3,.10*wear)
    normal=k.bump(weather,.28,.30*wear,normal=normal)
    stone=k.bsdf(Base_Color=col,Roughness=.66,Normal=normal)
    geo=k.node("ShaderNodeNewGeometry")
    sep=k.node("ShaderNodeSeparateXYZ");k.link(geo.outputs["Normal"],sep.inputs[0])
    ledges=k.math("MULTIPLY",k.math("MAXIMUM",0,k.math("SUBTRACT",sep.outputs["Z"],rime_start)),1.6,clamp=True)
    mask=k.math("MULTIPLY",ledges,k.ramp(weather,[(.25,(.05,.05,.05)),(.6,(frost,frost,frost))]))
    snow=k.bsdf(Base_Color=(.65,.76,.84,1),Roughness=.78,Subsurface_Weight=.12,
                Normal=k.bump(k.noise(vec,2.5,2).outputs["Fac"],.22,.045))
    k.surface(k.mix_shader(mask,stone,snow))
    return m


def snow(name="Settled snow", tone=(.66,.78,.87), seed=0, sparkle=0, mask_attribute=None):
    m,k=E.material(name)
    vec=mapped(k,(1,1,1),seed)
    n=k.noise(vec,.5,3).outputs["Fac"]
    grain=k.voronoi(vec,5).outputs["Distance"]
    glints=k.math("MULTIPLY",k.math("LESS_THAN",grain,.075),sparkle)
    shader=k.bsdf(Base_Color=(*tone,1),Roughness=k.math("SUBTRACT",.76,glints),Coat_Weight=glints,Subsurface_Weight=.18,
                  Subsurface_Radius=(.25,.4,.6),Normal=k.bump(n,.18,.10))
    if mask_attribute:
        attr=k.node("ShaderNodeAttribute");attr.attribute_name=mask_attribute
        shader=k.mix_shader(attr.outputs["Fac"],k.node("ShaderNodeBsdfTransparent").outputs[0],shader)
    k.surface(shader)
    return m


def frozen_ice(name="Glacial blue ice", tone=(.30,.64,.82), glow=.12, wear=.3, seed=0, edge_glow=0):
    m,k=E.material(name)
    vec=mapped(k,(.12,.12,.24),seed)
    n=k.noise(vec,1,3).outputs["Fac"]
    pale=k.ramp(n,[(.22,tuple(c*.60 for c in tone)),(.78,tuple(min(.95,c*1.3) for c in tone))])
    fresnel=k.node("ShaderNodeFresnel");fresnel.inputs["IOR"].default_value=1.31
    emission=k.math("ADD",k.math("MULTIPLY",n,glow*.04),k.math("MULTIPLY",fresnel.outputs[0],edge_glow))
    k.surface(k.bsdf(Base_Color=pale,Transmission_Weight=.88,IOR=1.31,
                     Roughness=k.math("ADD",.045,k.math("MULTIPLY",n,wear*.15)),
                     Coat_Weight=.25,Coat_Roughness=.065,
                     Normal=k.bump(n,.12,.035),Emission_Color=(.08,.39,.66,1),
                     Emission_Strength=emission))
    return m


def cold_mist(name="Cold ground mist", tone=(.30,.43,.55), opacity=.25, seed=0):
    m,k=E.material(name)
    uv=k.coords().outputs["UV"]
    sep=k.node("ShaderNodeSeparateXYZ");k.link(uv,sep.inputs[0])
    v=k.node("ShaderNodeVectorMath",operation="MULTIPLY");k.link(uv,v.inputs[0]);v.inputs[1].default_value=(2,1.5,1)
    offset=k.node("ShaderNodeVectorMath",operation="ADD");k.link(v.outputs[0],offset.inputs[0]);offset.inputs[1].default_value=(seed*.63,seed*.31,0)
    n=k.noise(offset.outputs[0],3,4,.65,dist=.4).outputs["Fac"]
    x=k.math("SINE",k.math("MULTIPLY",sep.outputs["X"],math.pi))
    y=k.math("POWER",k.math("SINE",k.math("MULTIPLY",sep.outputs["Y"],math.pi)),1.4)
    wisps=k.ramp(n,[(.28,(0,0,0)),(.47,(.17,.17,.17)),(.70,(1,1,1))])
    density=k.math("MULTIPLY",k.math("MULTIPLY",x,y),k.math("MULTIPLY",wisps,opacity))
    tr=k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(density,tr,k.emission((*tone,1),1)))
    return m


def parchment(name="Scholar parchment", tone=(.55,.38,.19), seed=0):
    m,k=E.material(name)
    n=k.noise(mapped(k,(1,1,1),seed),.42,3).outputs["Fac"]
    fibre=k.noise(mapped(k,(.9,4,1),seed),5,2).outputs["Fac"]
    k.surface(k.bsdf(Base_Color=k.ramp(n,[(.2,tuple(c*.52 for c in tone)),(.8,tone)]),
                     Roughness=.83,Normal=k.bump(fibre,.16,.012)))
    return m


def feather(name="Raven quill", tone=(.009,.022,.045), seed=0):
    m,k=E.material(name)
    n=k.noise(mapped(k,(1,12,.5),seed),2,2).outputs["Fac"]
    k.surface(k.bsdf(Base_Color=k.ramp(n,[(.25,tuple(c*.25 for c in tone)),(.8,tone)]),
                     Roughness=.34,Sheen_Weight=.55,Coat_Weight=.25,
                     Normal=k.bump(n,.25,.014)))
    return m


def rune_stone(name="Blue runestone", tone=(.009,.035,.17), seed=0):
    m,k=E.material(name)
    n=k.noise(mapped(k,(1,1,1),seed),2.7,3).outputs["Fac"]
    col=k.ramp(n,[(.25,tuple(c*.14 for c in tone)),(.60,tone),(.8,tuple(c*1.6 for c in tone))])
    fleck=k.math("GREATER_THAN",k.noise(mapped(k,(1,1,1),seed),12,2).outputs["Fac"],.79)
    k.surface(k.bsdf(Base_Color=col,Roughness=.19,Coat_Weight=.6,Coat_Roughness=.12,
                     Metallic=0,Transmission_Weight=.12,IOR=1.53,
                     Emission_Color=(.015,.12,1,1),Emission_Strength=k.math("MULTIPLY",fleck,.7),
                     Normal=k.bump(n,.12,.017)))
    return m


def upholstery(name="Rubbed upholstery leather", tone=(.13,.035,.019), wear=.6, seed=0):
    m,k=E.material(name)
    vec=mapped(k,(1,1,1),seed)
    n=k.noise(vec,.17,3,.65).outputs["Fac"]
    pores=k.voronoi(vec,8,feature="DISTANCE_TO_EDGE").outputs["Distance"]
    folds=k.noise(mapped(k,(.08,1.7,.22),seed),1.4,3,.7).outputs["Fac"]
    col=k.ramp(n,[(.2,tuple(c*.32 for c in tone)),(.55,tone),(.8,tuple(c*1.6 for c in tone))])
    geo=k.node("ShaderNodeNewGeometry")
    edge=k.math("MULTIPLY",k.math("MAXIMUM",0,k.math("SUBTRACT",geo.outputs["Pointiness"],.49)),wear*9,clamp=True)
    col=k.mix(edge,col,tuple(c*1.9 for c in tone)+(1,))
    normal=k.bump(pores,.25,.025,normal=k.bump(folds,.24,.045*wear))
    k.surface(k.bsdf(Base_Color=col,Roughness=k.math("ADD",.27,k.math("MULTIPLY",n,.24)),
                     Normal=normal,Coat_Weight=.16,Coat_Roughness=.3,Sheen_Weight=.12))
    return m


def wool(name="Wool yarn", tone=(.11,.012,.029), seed=0, plaid=False, plaid_axes=("X","Z"), weave=False):
    m,k=E.material(name)
    vec=mapped(k,(1,1,1),seed)
    n=k.noise(vec,3.5,2).outputs["Fac"]
    col=k.ramp(n,[(.2,tuple(c*.45 for c in tone)),(.8,tone)])
    if plaid:
        sep=k.node("ShaderNodeSeparateXYZ");k.link(k.coords().outputs["Object"],sep.inputs[0])
        for axis in plaid_axes:
            stripe=k.math("PINGPONG",sep.outputs[axis],7)
            wide=k.math("LESS_THAN",stripe,2.2)
            fine=k.math("LESS_THAN",k.math("ABSOLUTE",k.math("SUBTRACT",stripe,3.7)),.18)
            col=k.mix(k.math("MULTIPLY",wide,.75),col,(.025,.045,.065,1))
            col=k.mix(fine,col,(.32,.18,.055,1))
    normal=k.bump(n,.28,.027)
    if weave:
        threads=[]
        for axis in plaid_axes:
            wave=k.node("ShaderNodeTexWave");wave.bands_direction=axis
            k.link(k.coords().outputs["Object"],wave.inputs["Vector"])
            k.set(wave,Scale=12,Distortion=.9,Detail=2,Detail_Scale=1)
            threads.append(wave.outputs["Fac"])
        thread=k.math("MULTIPLY",threads[0],threads[1])
        normal=k.bump(thread,.38,.018,normal=normal)
        col=k.mix(k.math("MULTIPLY",thread,.22),col,tuple(c*1.5 for c in tone)+(1,))
    k.surface(k.bsdf(Base_Color=col,Roughness=.86,Sheen_Weight=.35,Sheen_Roughness=.65,Sheen_Tint=tuple(c*2 for c in tone)+(1,),
                     Normal=normal))
    return m


def stoneware(name="Iron-speckled salt glaze", tone=(.30,.22,.12), wear=.4, seed=0):
    m,k=E.material(name)
    vec=mapped(k,(1,1,1),seed)
    n=k.noise(vec,1.5,3,.7).outputs["Fac"]
    speck=k.ramp(n,[(.28,(1,1,1)),(.40,(.75,.75,.75)),(.44,(0,0,0)),(.67,(0,0,0)),(.75,(1,1,1))])
    col=k.mix(speck,(*tone,1),(.025,.015,.008,1))
    wheel=k.noise(mapped(k,(.05,.05,4),seed),1,2).outputs["Fac"]
    k.surface(k.bsdf(Base_Color=col,Roughness=k.math("ADD",.16,k.math("MULTIPLY",n,.17)),
                     Normal=k.bump(n,.32,.035,normal=k.bump(wheel,.24,.024)),
                     Coat_Weight=.6,Coat_Roughness=.17))
    return m


def charred_wood(name="Burning oak", heat=.7, seed=0):
    m,k=E.material(name)
    vec=mapped(k,(.8,.8,.55),seed)
    distortion=k.noise(vec,1.8,3,.7).outputs["Color"]
    offset=k.node("ShaderNodeVectorMath",operation="SCALE")
    k.link(distortion,offset.inputs[0]);offset.inputs[3].default_value=.7
    warped=k.node("ShaderNodeVectorMath",operation="ADD")
    k.link(vec,warped.inputs[0]);k.link(offset.outputs[0],warped.inputs[1])
    fissure=k.voronoi(warped.outputs[0],1.2,feature="DISTANCE_TO_EDGE").outputs["Distance"]
    n=k.noise(vec,1.7,4,.7).outputs["Fac"]
    crack=k.ramp(fissure,[(0,(1,1,1)),(.006,(.6,.6,.6)),(.022,(0,0,0))])
    pockets=k.ramp(k.noise(vec,.45,3).outputs["Fac"],[(.38,(0,0,0)),(.58,(.3,.3,.3)),(.8,(1,1,1))])
    geo=k.node("ShaderNodeNewGeometry");sep=k.node("ShaderNodeSeparateXYZ")
    k.link(geo.outputs["Normal"],sep.inputs[0])
    crust=k.math("SUBTRACT",1,k.math("MULTIPLY",k.math("MAXIMUM",0,sep.outputs["Z"]),.92))
    glow=k.math("MULTIPLY",k.math("MULTIPLY",crack,pockets),k.math("MULTIPLY",crust,heat*10))
    col=k.ramp(n,[(.2,(.0015,.001,.0007)),(.8,(.027,.022,.018))])
    normal=k.bump(n,.6,.15,normal=k.bump(fissure,.7,.19))
    k.surface(k.bsdf(Base_Color=col,Roughness=.93,Normal=normal,
                     Emission_Color=(1,.095,.003,1),Emission_Strength=glow))
    return m


def canvas(name="Weathered canvas", tone=(.15,.12,.07), wear=.6, seed=1):
    m,k=E.material(name)
    vec=mapped(k,(1,1,1),seed)
    broad=k.noise(vec,.21,4,.7).outputs["Fac"]
    col=k.ramp(broad,[(.2,tuple(c*.35 for c in tone)),(.55,tone),(.8,tuple(c*1.5 for c in tone))])
    weave=[]
    for direction in ("X","Z"):
        wave=k.node("ShaderNodeTexWave");wave.bands_direction=direction
        k.link(vec,wave.inputs["Vector"]);k.set(wave,Scale=8,Distortion=1.5,Detail=2)
        weave.append(wave.outputs["Color"])
    yarn=k.math("MULTIPLY",weave[0],weave[1])
    normal=k.bump(yarn,.24,.022,normal=k.bump(broad,.3,.11*wear))
    k.surface(k.bsdf(Base_Color=col,Roughness=.87,Sheen_Weight=.28,Normal=normal))
    return m


def limewash(name="Aged lime plaster",tone=(.43,.34,.23),wear=.6,seed=1):
    m,k=E.material(name);vec=mapped(k,(1,1,1),seed)
    n=k.noise(vec,.07,5,.65).outputs["Fac"]
    col=k.ramp(n,[(.18,tuple(c*.4 for c in tone)),(.52,tone),(.85,tuple(c*1.2 for c in tone))])
    pores=k.noise(vec,1.8,3).outputs["Fac"]
    k.surface(k.bsdf(Base_Color=col,Roughness=.88,Normal=k.bump(pores,.22,.07,normal=k.bump(n,.55,.6*wear))))
    return m


def bread_crust(name="Scored bread crust", seed=1):
    m,k=E.material(name)
    vec=mapped(k,(1,1,1),seed)
    n=k.noise(vec,.55,3).outputs["Fac"]
    pore=k.noise(vec,7,2).outputs["Fac"]
    crust=k.ramp(n,[(.20,(.10,.031,.006)),(.52,(.34,.13,.027)),(.80,(.50,.28,.09))])
    attr=k.node("ShaderNodeAttribute");attr.attribute_name="Bread scoring"
    cut=k.math("MULTIPLY",attr.outputs["Fac"],.9)
    color=k.mix(cut,crust,(.47,.31,.14,1))
    k.surface(k.bsdf(Base_Color=color,Roughness=.73,Normal=k.bump(pore,.25,.032),Subsurface_Weight=.025))
    return m


def workbench_stain(name="Lapidary oil stain",tone=(.035,.018,.007),seed=1):
    m,k=E.material(name)
    uv=k.coords().outputs["Generated"]
    sep=k.node("ShaderNodeSeparateXYZ");k.link(uv,sep.inputs[0])
    x=k.math("MULTIPLY",k.math("SUBTRACT",sep.outputs["X"],.5),2)
    y=k.math("MULTIPLY",k.math("SUBTRACT",sep.outputs["Y"],.5),2)
    r=k.math("ADD",k.math("MULTIPLY",x,x),k.math("MULTIPLY",y,y))
    edge=k.math("MAXIMUM",k.math("SUBTRACT",1,r),0)
    n=k.noise(mapped(k,(1,1,1),seed),1.6,3).outputs["Fac"]
    opacity=k.math("MULTIPLY",edge,k.math("MULTIPLY",n,.78))
    transparent=k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(opacity,transparent,k.bsdf(Base_Color=(*tone,1),Roughness=.72)))
    return m


def rough_mineral(name="Fractured beryl",tone=(.025,.3,.13),wear=.5,seed=1):
    m,k=E.material(name)
    vec=mapped(k,(1,1,1),seed)
    n=k.noise(vec,3.5,3,.7).outputs["Fac"]
    v=k.voronoi(vec,2.8,feature="DISTANCE_TO_EDGE").outputs["Distance"]
    fracture=k.math("MULTIPLY",k.math("LESS_THAN",v,.028),k.math("GREATER_THAN",n,.48))
    col=k.mix(k.math("MULTIPLY",fracture,.28),(*tone,1),(.55,.79,.64,1))
    k.surface(k.bsdf(Base_Color=col,Transmission_Weight=.78,IOR=1.59,
        Roughness=k.math("ADD",.11,k.math("MULTIPLY",n,.18*wear)),
        Normal=k.bump(k.math("ADD",n,k.math("MULTIPLY",fracture,.15)),.24,.03)))
    return m
