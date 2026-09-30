"""Centimetre-scale PBR surfaces; each builder owns its material variants."""
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
