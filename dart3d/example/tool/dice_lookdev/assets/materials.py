"""Centimetre-scale PBR surfaces; each builder owns its material variants."""
import math
import env_common as E


def mapped(k, scale, seed=0):
    mapping = k.node("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = scale
    mapping.inputs["Location"].default_value = (seed * 7.31, seed * 2.47, seed * 11.17)
    k.link(k.coords().outputs["Object"], mapping.inputs["Vector"])
    return mapping.outputs[0]


def oak(name="Oiled oak", tone=(0.12, 0.047, 0.016), wear=0.4, seed=0, axis="X"):
    m, k = E.material(name)
    vec = mapped(k, {"X": (0.018, 0.32, 0.32), "Y": (0.32, 0.018, 0.32), "Z": (0.32, 0.32, 0.018)}[axis], seed)
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
