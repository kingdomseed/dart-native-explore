"""Arcane Study environment: "The Night Study".

The rolling surface is the hero: a dark oak board inlaid with an engraved
brass sigil circle, framed by a low brass-capped rim. Around it: candles,
stacked leather tomes, a brass armillary, a bowl of glowing blue
runestones, star-stitched velvet, coins, maps and an hourglass, with a
moonlit window behind. Warm candlelight vs. a cool magical blue.
"""
from __future__ import annotations

import math

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
    wood = k.ramp(grain, [(0.05, (0.018, 0.009, 0.005)), (0.5, (0.07, 0.035, 0.016))])
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
    k.surface(k.mix_shader(inlay, wood_s, brass))
    return m


def build(scene):
    E.world(scene, color=(0.004, 0.005, 0.012), strength=1.0)
    sigil = P.mask_texture("arcane_sigil", P.sigil_strokes(seed=7, points=7, runes=30), E.TMP, res=4096)
    table = P.dark_wood("Study table", c1=(0.02, 0.01, 0.006), c2=(0.06, 0.03, 0.015))
    E.cube("table", (220, 160, 6), (0, 20, -3.0), table, bevel=0.5)
    E.plane("board", W + 2 * RIM_T, D + 2 * RIM_T, (0, 0, 0.3), board(sigil, W * 0.96))
    E.cube("board_base", (W + 2 * RIM_T + 1, D + 2 * RIM_T + 1, 0.6), (0, 0, 0.0),
           P.dark_wood("Board edge", c1=(0.02, 0.01, 0.006), c2=(0.05, 0.025, 0.012)), bevel=0.2)
    rim_wood = P.dark_wood("Rim wood", c1=(0.025, 0.012, 0.007), c2=(0.07, 0.035, 0.016), varnish=0.6)
    E.rim("rim", W + RIM_T, D + RIM_T, 2.0, RIM_H, RIM_T, rim_wood, z0=0.3)
    E.rim("rim_cap", W + RIM_T, D + RIM_T, 2.0, 0.5, 0.7, P.brass("Rim brass", worn=0.35), z0=RIM_H + 0.1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            E.sphere("rim_boss", 0.8, (sx * (W / 2 + RIM_T / 2), sy * (D / 2 + RIM_T / 2), RIM_H + 0.7),
                     P.brass(), subdiv=3, scale=(1, 1, 0.6))

    # Back edge: candles, tomes, armillary, window.
    top = D / 2 + RIM_T
    P.candle(scene, -9.0, top + 7.0, 0.0, h=13, r=1.7, seed=1, energy=55)
    P.candle(scene, 11.0, top + 5.5, 0.0, h=9, r=1.5, seed=2, energy=45)
    P.candle(scene, 3.5, top + 16.0, 0.0, h=16, r=1.9, seed=3, energy=60)
    P.book_stack(-26.0, top + 8.0, 0.0, 5, seed=1)
    P.book_stack(28.0, top + 4.0, 0.0, 4, seed=2)
    P.armillary(18.0, top + 20.0, 0.0, R=6.5)
    P.backdrop_window(0, top + 80, 45, 70, 80)
    # Sides/front: runestones, velvet, coins, maps, hourglass, inkwell + quill.
    P.bowl(W / 2 + 12, -8.0, 0.0, 6.0, P.brass("Bowl brass", worn=0.6))
    P.runestones(W / 2 + 12, -8.0, 0.8, 7, spread=3.5)
    E.light(scene, "POINT", "rune_glow", (W / 2 + 12, -8, 5), 250, color=(0.25, 0.5, 1.0), size=3)
    cloth = P.paper(W / 2 + 18, 14, 0.0, 30, 40, rot=0.2, mat=P.velvet("Star velvet"), curl=1.2, seed=3)
    P.paper(-W / 2 - 16, -6, 0.0, 22, 30, rot=-0.25, curl=0.8, seed=4)
    P.paper(-W / 2 - 10, -D / 2 - 6, 0.0, 26, 18, rot=0.35, curl=0.6, seed=5)
    for i, (x, y) in enumerate(((-W / 2 - 7, -D / 2 + 4), (-W / 2 - 4.5, -D / 2 + 1), (-W / 2 - 9.5, -D / 2),
                                (-W / 2 - 5, -D / 2 - 3))):
        P.coin(x, y, 0.1 + 0.25 * (i == 3), r=1.5, tilt=(0.05 * i, -0.04 * i))
    P.hourglass(W / 2 + 9, D / 2 - 4, 0.0, h=11)
    ink = E.cube("inkwell", (4, 4, 3.6), (-W / 2 - 8, 12, 1.8), P.glass("Ink glass", color=(0.05, 0.08, 0.2)),
                 bevel=0.4)
    E.cylinder("inkwell_cap", 1.2, 0.8, (-W / 2 - 8, 12, 4.0), P.brass())
    quill = E.sphere("quill", 1.0, (-W / 2 - 11, 16, 5), E.simple("Quill", (0.02, 0.02, 0.03), 0.4,
                                                                Sheen_Weight=1.0), subdiv=3,
                     scale=(0.9, 9.0, 0.08))
    quill.rotation_euler = (math.radians(-35), math.radians(10), math.radians(25))

    # Lights: moon from the window (cool key on the board), warm candle fill.
    E.light(scene, "AREA", "moon", (8, top + 70, 60), 16000, color=(0.55, 0.65, 1.0), size=40, target=(0, 0, 0),
            shadow=False)
    E.light(scene, "AREA", "warm_fill", (-30, -30, 30), 1200, color=(1.0, 0.7, 0.45), size=25, target=(0, 0, 0))
    E.light(scene, "AREA", "board_spot", (0, -10, 55), 4500, color=(1.0, 0.85, 0.7), size=15, target=(0, 0, 0))
    # Dust motes in the candlelight + faint haze.
    E.scatter("motes", 160, ((-35, -25, 3), (35, 50, 35)), 0.05, E.emissive("Mote", (1.0, 0.85, 0.6), 4.0),
              seed=12, scale_range=(0.3, 1.0))
    E.haze_box("haze", (160, 180, 70), (0, 20, 34), 0.004, color=(0.9, 0.85, 1.0), noise_scale=0.03)
    return dict(
        samples=128, exposure=0.9, hero=dict(dist=32, elev=30, az=6, lens=65, fstop=2.8),
        d20=dict(dist=11, elev=50, az=-10, lens=100, fstop=4.0),
        env=dict(target=(0, 12, 3), dist=95, elev=34, az=16, lens=35, fstop=8.0, focus=(0, 0, 2)),
        roll=dict(
            settled={"d12": ((-4.5, -7.0), 12, 20), "d6": ((5.5, -3.0), 6, -10), "d10t": ((-2.0, 4.0), 0, 30),
                     "d4": ((6.0, 9.0), 4, 0)},
            airborne={"d20": ((0.5, -2.5, 3.0), (1.2, 2.5, 0.2)), "d8": ((-5.5, 7.0, 5.0), (2.0, -1.0, -0.5)),
                      "d10u": ((4.0, 14.0, 2.2), (-1.5, -2.0, 0.3))}),
    )
