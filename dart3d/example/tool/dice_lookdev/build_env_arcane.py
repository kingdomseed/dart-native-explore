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
import room_common as RC

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
    table = P.dark_wood("Study table", c1=(0.02, 0.01, 0.006), c2=(0.06, 0.03, 0.015))
    E.cube("table", (220, 160, 6), (0, 20, -3.0), table, bevel=0.5)
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

    # Top-down framing: low props peeking into the strips above and below
    # the tray (tall ones leave the frame under perspective).
    top_in, bot_in = D / 2 + RIM_T, -D / 2 - RIM_T
    P.paper(-4.0, top_in + 4.2, 0.0, 16, 7, rot=0.06, curl=0.25, seed=21)  # a map sheet
    for i, (x, y) in enumerate(((5.5, top_in + 2.6), (7.6, top_in + 3.5), (6.3, top_in + 5.0))):
        P.coin(x, y, 0.05 + 0.23 * i, r=1.3, tilt=(0.04 * i, -0.03 * i))
    letter = P.paper(2.5, bot_in - 3.6, 0.0, 14, 8, rot=-0.08, curl=0.2, seed=22)
    E.cylinder("wax_seal", 1.25, 0.35, (6.5, bot_in - 3.2, 0.3), E.simple("Seal wax", (0.35, 0.02, 0.02), 0.35,
                                                                        Coat_Weight=0.5), segs=32, bevel=0.1)
    q = E.sphere("quill_low", 1.0, (-5.0, bot_in - 2.6, 0.4), E.simple("Quill low", (0.85, 0.82, 0.75), 0.6,
                                                                     Sheen_Weight=1.0), subdiv=3,
                 scale=(0.7, 7.5, 0.08))
    q.rotation_euler = (0, 0, math.radians(72))
    E.cube("velvet_corner", (12, 10, 0.5), (-W / 2 - 3.0, bot_in - 4.0, 0.25), P.velvet("Bag velvet"), bevel=0.2)
    P.bowl(W / 2 + 2.2, bot_in - 4.0, 0.0, 4.5, P.brass("Low bowl brass", worn=0.6), depth=1.8)
    P.runestones(W / 2 + 2.2, bot_in - 4.0, 0.4, 5, spread=2.4, seed=8)

    # Lights. Round 2: a warm candle key pooled on the tray from the candle
    # cluster (angled, so no hotspot in the dice's top faces), a big soft
    # overhead for the gilt, and a weaker moon than round 1.
    E.light(scene, "AREA", "moon", (8, top + 70, 60), 6000, color=(0.55, 0.65, 1.0), size=40, target=(0, 0, 0),
            shadow=False)
    E.light(scene, "AREA", "candle_key", (-8, top + 2, 34), 13000, color=(1.0, 0.74, 0.48), size=14,
            target=(0, -5, 0))
    E.light(scene, "AREA", "warm_fill", (-30, -30, 30), 900, color=(1.0, 0.7, 0.45), size=25, target=(0, 0, 0))
    E.overhead(scene, 3500, color=(1.0, 0.85, 0.65), size=90, height=110)
    # Dust motes in the candlelight (kept off the tray so they don't read as
    # specks on the dice at top-down).
    E.scatter("motes", 160, ((-35, -25, 3), (35, 50, 35)), 0.05, E.emissive("Mote", (1.0, 0.85, 0.6), 4.0),
              seed=12, scale_range=(0.3, 1.0), avoid=lambda p: abs(p.x) < W / 2 + 6 and abs(p.y) < D / 2 + 10)
    E.haze_box("haze", (160, 180, 70), (0, 20, 34), 0.004, color=(0.9, 0.85, 1.0), noise_scale=0.03)
    rc = room(scene, table, top)
    return dict(
        samples=128, exposure=0.6, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=30, az=6, lens=65, fstop=2.8),
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T), room_cam=rc,
    )


def room(scene, table, top):
    """The night study (concept: room-concepts/arcane-room).

    The desk stands against the window wall: a tall leaded window with a
    moonlit skyline of spires behind the tray, floor-to-ceiling bookcases
    either side of it and along the left wall, a fireplace on the right
    wall, candle sconces, a rug. Lights from four sides: moonlight through
    the window (cool, back), the fireplace (warm, right), sconces and the
    desk candles (warm, back-left and back-right), the tray's candle key.
    """
    wy = top + 80  # the window plane (P.backdrop_window's mullions)
    wall = RC.plaster("Study plaster", (0.12, 0.1, 0.09))
    panel = P.dark_wood("Study panelling", c1=(0.025, 0.012, 0.007), c2=(0.07, 0.035, 0.016))
    RC.shell(half_w=190, back=wy, front=-200, height=280, wall=wall, floor=RC.planks(),
             openings={"back": [(0, 45, 70, 80)]}, side_mats={"left": panel})
    spires = RC.sky("Study night", (0.015, 0.02, 0.06), (0.07, 0.09, 0.2), stars=2.0, strength=0.7,
                    skyline=((0.01, 0.012, 0.025), 0.3))
    RC.window("back", 0, 45, 70, 80, spires, panel, mullions=(1, 1), sill=False,
              glow=(25000, (0.55, 0.65, 1.0)))
    RC.work_table(220, 160, top_z=0.0, thick=6.0, mat=table, leg_r=6, y=20, top=False)
    oak = P.dark_wood("Study oak", c1=(0.03, 0.015, 0.008), c2=(0.09, 0.045, 0.02))
    for u, seed in ((-120, 1), (120, 2)):
        RC.bookshelf("back", u, w=110, h=250, depth=32, rows=8, seed=seed, mat=oak)
    for u, seed in ((-60, 3), (-170, 4)):
        RC.bookshelf("left", u, w=110, h=250, depth=32, rows=8, seed=seed, mat=oak)
    RC.fireplace(scene, "right", -60, w=130, h=115, depth=40, energy=160000, seed=5,
                 mat=RC.stone("Study hearth", (0.1, 0.09, 0.08), (0.22, 0.2, 0.17), scale=0.03))
    for u in (-58, 58):
        RC.sconce(scene, "back", u, 80, energy=6000)
    RC.rug(0, -60, 260, 200, (0.12, 0.02, 0.03), (0.03, 0.02, 0.08), name="Study rug")
    RC.chair(-20, -95, rot=math.radians(180 - 10), mat=oak)
    # a tall brass candelabrum on the floor by the left bookcase (warm, left)
    brass = P.brass("Candelabrum brass", worn=0.4)
    E.cylinder("candelabrum", 1.5, 150, (-150, 60, RC.FLOOR_Z + 75), brass, segs=16)
    E.cylinder("candelabrum_foot", 16, 4, (-150, 60, RC.FLOOR_Z + 2), brass, segs=32, r2=6)
    for dx in (-12, 0, 12):
        P.candle(scene, -150 + dx, 60, RC.FLOOR_Z + 150, h=14, r=1.6, seed=int(dx) + 30, energy=0, light=False)
    E.light(scene, "POINT", "candelabrum_light", (-150, 60, RC.FLOOR_Z + 170), 20000, color=(1.0, 0.65, 0.35),
            size=8)
    return dict(loc=(14, -58, 36), target=(-2, 90, 12), lens=20, fstop=4.0, focus=(0, 0, 2))
