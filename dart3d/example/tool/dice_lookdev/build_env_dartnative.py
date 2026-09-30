"""DartNative environments for the frosted-glass logo dice (the example app's set).

Calm and premium: the dice are the hero. Three options (render_set
--env-option a|b|c), all on a #090E12 base, the brand gradient
(#FA60A6 -> #EF388B -> #E99173 -> #D7BA52 -> #B5C75E) and cyan #03C3F0 used
as *light*, lime #A1EA5A once:

  a  "Obsidian"  - a glossy obsidian tray, a thin brand-gradient light line
                   along the rim, one lime "ready" light.
  b  "Lightbox"  - a frosted-glass tray floor lit softly from below by the
                   brand gradient (pink at one end, gold-green at the other).
  c  "Stage"     - a minimal dark matte stage, a low dark rim, and soft pools
                   of gradient light (pink key, gold fill, cyan rim) from
                   three sides.
"""
from __future__ import annotations

import env_common as E

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 1.8, 2.2
OPTION = "a"


def srgb(hexcode):
    """'#RRGGBB' -> linear RGB tuple."""
    h = hexcode.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


BODY = srgb("#090E12")
GRADIENT = [srgb(c) for c in ("#FA60A6", "#EF388B", "#E99173", "#D7BA52", "#B5C75E")]
CYAN = srgb("#03C3F0")
LIME = srgb("#A1EA5A")


def gradient_ramp(k, fac, wrap=True):
    stops = [(i / (len(GRADIENT) - (0 if wrap else 1)), c) for i, c in enumerate(GRADIENT)]
    if wrap:
        stops.append((1.0, GRADIENT[0]))
    return k.ramp(fac, stops)


def around(k):
    """0..1 angle around the tray centre (object space), for rim gradients."""
    obj = k.coords().outputs["Object"]
    g = k.node("ShaderNodeTexGradient", gradient_type="RADIAL")
    k.link(obj, g.inputs["Vector"])
    return g.outputs["Fac"]


def rim_glow(strength=3.0):
    m, k = E.material("DN rim glow")
    k.surface(k.emission(gradient_ramp(k, around(k)), strength))
    return m


def studio_overhead(scene, energy):
    """A big soft overhead that lights the frost milky-white. It is kept out
    of reflections (visible_glossy off): in the engine a light never shows
    in a glossy floor either, only the IBL does."""
    ob = E.overhead(scene, energy, color=(0.92, 0.95, 1.0), size=90, height=110)
    ob.visible_glossy = False
    return ob


def table():
    E.cube("table", (160, 120, 4), (0, 10, -2.0), E.simple("Table", srgb("#070A0D"), 0.6), bevel=0.3)


def ready_light():
    """The one lime accent: a small 'ready' light set into the rim."""
    E.sphere("ready_light", 0.28, (W / 2 - 2.0, -D / 2 - RIM_T / 2, RIM_H + 0.28),
             E.emissive("Ready lime", LIME, 8.0), subdiv=2, scale=(1.6, 1, 0.5))


def option_a(scene):
    """Obsidian tray + gradient rim line."""
    m, k = E.material("Obsidian")
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 0.6, 6, 0.6).outputs["Fac"]
    col = k.ramp(n, [(0.3, srgb("#0B1116")), (0.7, srgb("#141C23"))])
    k.surface(k.bsdf(Base_Color=col, Roughness=0.22, Coat_Weight=1.0, Coat_Roughness=0.12))
    E.plane("tray_floor", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.31), m)
    anod = E.simple("Anodized rim", srgb("#1A2229"), 0.32, 0.9)
    E.cube("tray_base", (W + 2 * RIM_T + 0.6, D + 2 * RIM_T + 0.6, 0.6), (0, 0, 0.0), anod, bevel=0.2)
    E.rim("rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, anod, z0=0.3)
    E.rim("rim_glow", W + RIM_T, D + RIM_T, 3.0, 0.22, 0.22, rim_glow(), z0=RIM_H + 0.32)
    ready_light()
    studio_overhead(scene, 16000)
    E.light(scene, "AREA", "key", (-46, -14, 38), 9000, color=(1.0, 0.96, 0.92), size=24, target=(0, 0, 0))
    E.light(scene, "AREA", "fill", (40, 30, 30), 1500, color=(0.7, 0.85, 1.0), size=30, target=(0, 0, 0))


def option_b(scene):
    """A frosted-glass lightbox floor: the brand gradient glows softly up
    through it (pink at the far end, gold-green near), dimmer at the edges."""
    m, k = E.material("Lightbox floor")
    obj = k.coords().outputs["Object"]
    sep = k.node("ShaderNodeSeparateXYZ")
    k.link(obj, sep.inputs[0])
    t = k.math("ADD", k.math("DIVIDE", sep.outputs["Y"], -(D + 2 * RIM_T)), 0.5, clamp=True)
    # soft falloff toward the walls (a diffuser lit from a smaller panel)
    ax = k.math("ABSOLUTE", k.math("DIVIDE", sep.outputs["X"], W / 2 + RIM_T))
    ay = k.math("ABSOLUTE", k.math("DIVIDE", sep.outputs["Y"], D / 2 + RIM_T))
    fall = k.math("SUBTRACT", 1.0, k.math("POWER", k.math("MAXIMUM", ax, ay), 3.0), clamp=True)
    glow = k.emission(gradient_ramp(k, t, wrap=False), k.math("MULTIPLY", fall, 0.15))
    frost = k.bsdf(Base_Color=(0.05, 0.055, 0.06, 1), Roughness=0.55, Coat_Weight=0.4, Coat_Roughness=0.3,
                   Normal=k.bump(k.noise(obj, 30.0, 3).outputs["Fac"], 0.05, 0.01))
    k.surface(k.add_shader(frost, glow))
    E.plane("tray_floor", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.31), m)
    anod = E.simple("Anodized rim", srgb("#11181E"), 0.3, 0.9)
    E.cube("tray_base", (W + 2 * RIM_T + 0.6, D + 2 * RIM_T + 0.6, 0.6), (0, 0, 0.0), anod, bevel=0.2)
    E.rim("rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, anod, z0=0.3)
    ready_light()
    studio_overhead(scene, 12000)
    E.light(scene, "AREA", "key", (-46, -14, 38), 7000, color=(1.0, 0.96, 0.92), size=24, target=(0, 0, 0))


def option_c(scene):
    """Minimal dark stage with soft pools of gradient light."""
    stage = E.simple("Stage", srgb("#10161B"), 0.62)
    E.plane("tray_floor", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.31), stage)
    E.cube("tray_base", (W + 2 * RIM_T + 0.6, D + 2 * RIM_T + 0.6, 0.6), (0, 0, 0.0),
           E.simple("Stage edge", srgb("#0C1115"), 0.5), bevel=0.2)
    E.rim("rim", W + RIM_T, D + RIM_T, 3.0, 1.0, RIM_T, E.simple("Low rim", srgb("#151D24"), 0.4, 0.6), z0=0.3)
    ready_light()
    pink, gold = GRADIENT[0], GRADIENT[3]
    # soft coloured pools from three sides; the dice's frost catches all three
    E.light(scene, "SPOT", "pink_key", (-30, -34, 42), 200000, color=pink, size=12, target=(0, -6, 0),
            spot_deg=34, blend=1.0)
    E.light(scene, "SPOT", "gold_fill", (32, 30, 40), 140000, color=gold, size=12, target=(0, 7, 0),
            spot_deg=34, blend=1.0)
    E.light(scene, "AREA", "cyan_rim", (40, -20, 14), 2500, color=CYAN, size=20, target=(0, 0, 1))
    studio_overhead(scene, 10000)


def build(scene):
    E.world(scene, color=(0.002, 0.003, 0.004), strength=1.0)
    table()
    {"a": option_a, "b": option_b, "c": option_c}[OPTION](scene)
    return dict(
        samples=96, exposure=0.4, topdown=dict(width=W + 2 * RIM_T + 1.0),
        hero=dict(dist=32, elev=30, az=-8, lens=65, fstop=2.8),
    )
