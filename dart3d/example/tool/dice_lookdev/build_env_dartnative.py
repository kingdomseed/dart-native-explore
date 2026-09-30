"""DartNative environment: "Launch Tray" (the example app's own dice set).

Minimal on purpose: the dice are the hero. A dark, matte tray with a
rounded anodized rim, a thin line of light running the brand gradient
around the rim (like the 3D logo, which glows its own gradient), a
near-black table and nothing else. Soft overhead light plus a side key;
no props, no haze.

Brand colours (sRGB hex -> linear): body #090E12, gradient
#FA60A6 -> #EF388B -> #E99173 -> #D7BA52 -> #B5C75E, cyan #03C3F0,
lime #A1EA5A (sparingly).
"""
from __future__ import annotations

import env_common as E

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 1.8, 2.2


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


def gradient_ramp(k, fac):
    """The brand gradient along fac in 0..1 (wraps back to the start)."""
    stops = [(i / len(GRADIENT), c) for i, c in enumerate(GRADIENT)] + [(1.0, GRADIENT[0])]
    return k.ramp(fac, stops)


def around(k):
    """0..1 angle around the tray centre (object space), for rim gradients."""
    obj = k.coords().outputs["Object"]
    g = k.node("ShaderNodeTexGradient", gradient_type="RADIAL")
    k.link(obj, g.inputs["Vector"])
    return g.outputs["Fac"]


def tray_floor():
    m, k = E.material("Launch tray floor")
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 3.0, 4, 0.5).outputs["Fac"]
    # dark slate, a step lighter than the dice body so they sit on it; a
    # faint micro-texture only
    col = k.ramp(n, [(0.3, srgb("#10171C")), (0.7, srgb("#141C22"))])
    k.surface(k.bsdf(Base_Color=col, Roughness=0.7, Normal=k.bump(k.noise(obj, 40.0, 2).outputs["Fac"], 0.05, 0.01)))
    return m


def rim_glow():
    m, k = E.material("Launch rim glow")
    k.surface(k.emission(gradient_ramp(k, around(k)), 3.0))
    return m


def build(scene):
    E.world(scene, color=(0.002, 0.003, 0.004), strength=1.0)
    E.cube("table", (160, 120, 4), (0, 10, -2.0), E.simple("Table", srgb("#070A0D"), 0.6), bevel=0.3)
    E.plane("tray_floor", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.31), tray_floor())
    anod = E.simple("Anodized rim", srgb("#1A2229"), 0.32, 0.9)
    E.cube("tray_base", (W + 2 * RIM_T + 0.6, D + 2 * RIM_T + 0.6, 0.6), (0, 0, 0.0), anod, bevel=0.2)
    E.rim("rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, anod, z0=0.3)
    # one thin line of gradient light along the top of the rim
    E.rim("rim_glow", W + RIM_T, D + RIM_T, 3.0, 0.22, 0.22, rim_glow(), z0=RIM_H + 0.32)
    # the one lime accent: a small "ready" light set into the rim's bottom edge
    E.sphere("ready_light", 0.28, (W / 2 - 2.0, -D / 2 - RIM_T / 2, RIM_H + 0.28), E.emissive("Ready lime", LIME, 8.0),
             subdiv=2, scale=(1.6, 1, 0.5))
    # Lights: soft overhead (reads the dice's clearcoat without hotspots),
    # a neutral side key whose mirror image lands off the tray, a cool fill.
    E.overhead(scene, 3000, color=(0.92, 0.95, 1.0), size=90, height=110)
    E.light(scene, "AREA", "key", (-46, -14, 38), 9000, color=(1.0, 0.96, 0.92), size=24, target=(0, 0, 0))
    E.light(scene, "AREA", "fill", (40, 30, 30), 1500, color=(0.7, 0.85, 1.0), size=30, target=(0, 0, 0))
    return dict(
        samples=96, exposure=0.4, topdown=dict(width=W + 2 * RIM_T + 1.0),
        hero=dict(dist=32, elev=30, az=-8, lens=65, fstop=2.8),
    )
