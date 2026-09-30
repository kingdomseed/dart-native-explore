"""Emberforged: a broadside dice tray on the worktable of a lived-in smithy."""
from __future__ import annotations

import math

import env_common as E
import env_props as P
import room_common as RC

W, D = E.TRAY_W, E.TRAY_D
RIM_T, RIM_H = 2.4, 3.4


def iron(name="Blackened iron", heat=True):
    m, k = E.material(name)
    obj = k.coords().outputs["Object"]
    ham = k.voronoi(obj, 1.6)
    n = k.noise(obj, 3.0, 8, 0.6).outputs["Fac"]
    col = k.ramp(n, [(0.35, (0.02, 0.018, 0.017)), (0.75, (0.09, 0.07, 0.06))])
    bump = k.bump(ham.outputs["Distance"], 0.35, 0.3)
    s = k.bsdf(Base_Color=col, Metallic=0.85, Roughness=k.math("ADD", k.math("MULTIPLY", n, 0.3), 0.32),
               Normal=bump)
    k.surface(s)
    return m


def build(scene):
    E.world(scene, color=(0.004, 0.003, 0.003), strength=1.0)
    from assets import forge_plate
    forge_plate.build(width=W + 4.8, depth=D + 4.8, thickness=1.2)
    # Tray: forged iron plate with an engraved forge sigil, ringed by a molten channel.
    sigil = P.mask_texture("forge_sigil", P.sigil_strokes(seed=5, points=5, runes=20,
                                                          rings=(0.47, 0.455, 0.37, 0.2), w=0.003),
                           E.TMP, res=2048)
    floor_m, k = E.material("Tray forged iron")
    obj = k.coords().outputs["Object"]
    n = k.noise(obj, 1.3, 10, 0.6).outputs["Fac"]
    ham = k.voronoi(obj, 0.9).outputs["Distance"]
    ash = k.ramp(n, [(0.35, (0.03, 0.027, 0.025)), (0.75, (0.075, 0.066, 0.06))])
    sm = k.node("ShaderNodeMapping")
    sm.inputs["Scale"].default_value = (1 / (W * 0.92), 1 / (W * 0.92), 1)
    sm.inputs["Location"].default_value = (0.5, 0.5, 0)
    k.link(obj, sm.inputs["Vector"])
    tex = k.node("ShaderNodeTexImage", image=sigil, extension="CLIP", interpolation="Cubic")
    k.link(sm.outputs[0], tex.inputs["Vector"])
    groove = tex.outputs["Color"]
    bump = k.bump(ham, 0.25, 0.2)
    bump = k.bump(groove, 0.8, 0.15, normal=bump, invert=True)
    flick = k.noise(obj, 0.15, 2).outputs["Fac"]
    k.surface(k.bsdf(Base_Color=ash, Roughness=k.math("ADD", k.math("MULTIPLY", n, 0.25), 0.5), Metallic=0.6,
                     Normal=bump, Emission_Color=(1.0, 0.18, 0.01, 1),
                     Emission_Strength=k.math("MULTIPLY", groove, k.math("MULTIPLY", flick, 0.9))))
    lava, k = E.material("Molten channel")
    obj = k.coords().outputs["Object"]
    # Round 2: real molten metal, not a pale salmon band: a deep-orange melt
    # with small dark crust rafts drifting on it, their edges burning yellow.
    warp = k.noise(obj, 0.35, 3).outputs["Color"]
    wv = k.mix(0.35, obj, warp, "LINEAR_LIGHT")
    cr = k.voronoi(wv, 1.6, feature="DISTANCE_TO_EDGE")
    raft = k.math("GREATER_THAN", cr.outputs["Distance"], 0.12)
    keep = k.math("GREATER_THAN", k.noise(obj, 0.5, 2).outputs["Fac"], 0.55)
    crust = k.math("MULTIPLY", raft, keep)
    heat = k.noise(obj, 0.8, 5, 0.6).outputs["Fac"]
    col = k.ramp(heat, [(0.3, (1.0, 0.13, 0.0)), (0.55, (1.0, 0.26, 0.01)), (0.75, (1.0, 0.42, 0.03))])
    melt = k.math("SUBTRACT", 1.0, crust)
    rim_hot = k.math("MULTIPLY", k.math("LESS_THAN", cr.outputs["Distance"], 0.2), crust)
    strength = k.math("ADD", k.math("MULTIPLY", melt, 1.1), k.math("MULTIPLY", rim_hot, 1.6))
    crust_col = k.ramp(k.noise(obj, 2.0, 4).outputs["Fac"], [(0.4, (0.012, 0.008, 0.006)), (0.7, (0.06, 0.025, 0.012))])
    k.surface(k.bsdf(Base_Color=crust_col, Roughness=0.9, Emission_Color=col, Emission_Strength=strength))
    E.rim("molten_channel", W - 1.6, D - 1.6, 2.2, 0.55, 0.55, lava, z0=-0.35)
    E.plane("tray_floor", W + RIM_T * 2, D + RIM_T * 2, (0, 0, 0.001), floor_m)
    im = iron()
    E.rim("tray_rim", W + RIM_T, D + RIM_T, 3.0, RIM_H, RIM_T, im)
    rv = E.simple("Rivet", (0.12, 0.1, 0.09), 0.35, 1.0)
    for i, (x, y) in enumerate(E.rounded_rect(W + RIM_T, D + RIM_T, 3.0, seg=2)[::1]):
        E.sphere(f"rivet{i}", 0.35, (x, y, RIM_H + 0.05), rv, subdiv=2, scale=(1, 1, 0.6))

    # Lights: warm soft key over the tray, cold rim for separation.
    E.light(scene, "AREA", "key", (-14, -22, 46), 6500, color=(1.0, 0.85, 0.72), size=22, target=(0, 0, 0))
    E.light(scene, "AREA", "cold_rim", (26, 30, 18), 2200, color=(0.35, 0.5, 1.0), size=18, target=(0, 0, 0))
    E.light(scene, "AREA", "fill", (10, -40, 8), 250, color=(0.6, 0.55, 0.9), size=30, target=(0, 0, 2))

    rc = room(scene)
    return dict(
        samples=160, exposure=-1.15, topdown=dict(width=W + 2 * RIM_T + 1.0), hero=dict(dist=32, elev=26, az=-8, lens=70, fstop=2.8),
        hero_layout={
            "d20": ((-1.8, -1.0), 20, 0), "d12": ((2.6, 10.0), 12, 12),
            "d10u": ((3.2, -11.5), 0, -15), "d10t": ((3.0, 4.0), 0, 20),
            "d8": ((-1.7, -9.5), 8, -10), "d6": ((3.2, -3.0), 6, 18),
            "d4": ((-0.4, 6.0), 4, 58),
        },
        play_view=True, tray_half=(W / 2 + RIM_T, D / 2 + RIM_T),
        room_cam=rc,
    )


def room(scene):
    """Full-scale smithy, built facing local -Y and turned broadside to the tray."""
    from assets import (anvil, barrel, book, candles, ember_bowl, forge, fur_throw,
                        geometry as G, lantern, leaded_window, leather_mat, loose_hardware, masonry, materials as M,
                        oak_table, pouch, shelf, shield, stone_steps, strongbox, table_tools, tool_rack, vessel)
    import bpy

    before = set(bpy.data.objects)
    wood = (0.095, 0.038, 0.013)
    floor_z = RC.FLOOR_Z
    oak_table.build("Player work table", loc=(0, -6, floor_z), width=136, depth=72,
                    height=74.8, thickness=7, wood_tone=wood, seed=2)
    masonry.build("Smithy back wall", loc=(0, 160, floor_z), width=470, height=265,
                  openings=((108, 26.5, 104, 119),), tone=(0.105, 0.10, 0.085))
    masonry.build("Left return", loc=(-235, 30, floor_z), rot_z=math.pi / 2,
                  width=270, height=265, tone=(0.09, 0.086, 0.074), seed=21)
    floor = M.stone("Worn flagstones", (0.064, 0.056, 0.043), wear=0.6, seed=18)
    E.cube("Room flagstone floor", (475, 650, 5), (0, 25, floor_z - 2.5), floor, bevel=0.3)
    forge.build(loc=(-98, 123, floor_z), width=120, depth=62, height=235,
                energy=240000, stone_tone=(0.048, 0.045, 0.04), seed=12, hearth_height=30, mouth_spring=32)
    anvil.build(loc=(-32, 83, floor_z), rot_z=-0.12, length=68, stump_height=49, seed=8)
    barrel.build("Quench tub", loc=(-2, 126, floor_z), radius=24, height=48, open_top=True, water=True, seed=9)
    barrel.build("Left cask", loc=(-158, 69, floor_z), radius=24, height=83, seed=6)
    barrel.build("Rear cask", loc=(-178, 118, floor_z), radius=24, height=87, seed=12)
    barrel.build("Right cask", loc=(175, 91, floor_z), radius=25, height=83, seed=14)
    tool_rack.build(loc=(-18, 158, -52), width=70, height=74, seed=7)
    shield.build(loc=(-36, 159, 35), radius=22, seed=5)
    shelf.build("Shelves beside tools", loc=(44, 160, -12), width=44, levels=2, spacing=34, seed=4)
    shelf.build("Right shelves", loc=(190, 160, -12), width=65, levels=3, spacing=32, seed=21)
    leaded_window.build(loc=(108, 160, -45), width=80, height=110, energy=65000, seed=9, moon_height=0.30, exterior_slope=0.35, moon_offset=0.8)
    oak_table.build("Back workbench", loc=(97, 122, floor_z), width=130, depth=76, height=62,
                    thickness=6, wood_tone=(0.1, 0.04, 0.016), seed=8)
    fur_throw.build(loc=(85, 106.5, -13.9), width=52, length=83, drop=38, tone=(0.115, 0.078, 0.043), seed=12)
    strongbox.build(loc=(89, 144, -14), width=30, depth=24, height=25, seed=3)
    candles.build(loc=(45, 112, -14), height=12, radius=1.8, energy=1800, seed=5)
    lantern.build("Bench lantern", loc=(60, 145, -14), height=35, radius=9, chain_length=0, energy=13500)
    lantern.build("Forge-side hanging lantern", loc=(-25, 145, -8), height=32, radius=8, chain_length=137, energy=28000)
    lantern.build("Window-side hanging lantern", loc=(58, 151, -12), height=34, radius=8, chain_length=139, energy=22000)
    lantern.build("Above-table lantern", loc=(31, 10, 65), height=32, radius=7, chain_length=65, energy=900)
    vessel.build("Foreground chased goblet", loc=(-35, 21, -1.2), height=18, radius=5.1, seed=8)
    book.build(loc=(-40, 3, -0.83), rot_z=-0.12, width=17, depth=24, thickness=5, seed=9)
    pouch.build(loc=(35, 24, -1.2), radius=6, height=11, seed=4)
    ember_bowl.build(loc=(36.5, 9.5, -1.2), radius=8.5, height=4.5, energy=70, seed=5)
    leather_mat.build(loc=(-43, 6, -1.17), rot_z=0.1, width=24, depth=31, seed=4)
    loose_hardware.build(loc=(43, 12, -1.2), rot_z=-0.3, length=14, seed=9)
    table_tools.build("Table tongs", loc=(0, 25, -1.2), length=45, seed=6)
    dressing = G.Asset("Smithy fixtures")
    im = M.metal("Smithy chains", wear=0.7)
    beam_wood = M.oak("Roof timber", (0.07, 0.028, 0.012), axis="Z", seed=4)
    for x in (-220, -35, 52, 173):
        dressing.block("Roof post", (13, 12, 260), (x, 163, floor_z + 130), beam_wood, 0.65)
    dressing.block("Wall head beam", (468, 16, 18), (0, 153, 161), beam_wood, 0.8)
    for x in (-20, 31, 61):
        dressing.block("Lantern supporting joist", (14, 280, 18), (x, 80, 161), beam_wood, 0.7)
    for x, z, length in ((-196, 124, 73), (-171, 119, 86), (37, 81, 62), (182, 112, 62)):
        G.chain(dressing, "Hanging smithy chain", (x, 153, z), length, im, radius=1.55)
    dressing.light("Warm room bounce", (-55, 56, 65), 90000, (1, 0.58, 0.31), 100,
                   target=(0, 158, 15), kind="AREA")
    dressing.light("Window bench bounce", (145, 120, 55), 5500, (0.40, 0.52, 1), 65,
                   target=(120, 115, 10), kind="AREA")
    tool_fill = dressing.light("Forge reflection on tools", (-56, 94, 42), 28000, (1, 0.55, 0.25), 45,
                   target=(8, 156, -5), kind="AREA")
    tool_fill.visible_glossy = True
    tool_fill.data.specular_factor = 1
    dressing.light("Bench lantern reflected warmth", (70, 71, 42), 15000, (1, 0.68, 0.4), 45,
                   target=(110, 110, -8), kind="AREA")
    dressing.light("Anvil forge-side sheen", (-72, 48, 39), 15000, (1, 0.56, 0.28), 35,
                   target=(-30, 82, 0), kind="AREA")
    sheen = dressing.light("Forge reflection on anvil", (-53, 126, 37), 35000, (1, 0.71, 0.44), 55,
                           target=(-32, 83, 3), kind="AREA")
    sheen.visible_glossy = True
    sheen.visible_transmission = False
    sheen.data.specular_factor = 1
    soot_rake = dressing.light("Warm grazing light on soot", (-150, 60, 60), 20000, (1, 0.68, 0.42), 55,
                               target=(-98, 108, 5), kind="AREA")
    moon_fill = dressing.light("Moon reflection on work station", (126, 140, 48), 40000, (0.30, 0.46, 1), 60,
                               target=(-12, 110, -8), kind="AREA")
    moon_fill.visible_glossy = True
    moon_fill.visible_transmission = False
    moon_fill.data.specular_factor = 1
    table_bounce = dressing.light("Lantern table bounce", (-20, 4, 38), 6500, (1, 0.69, 0.4), 38,
                                  target=(0, 12, -1.2), kind="AREA")
    table_bounce.visible_glossy = True
    table_bounce.data.specular_factor = 1
    foreground = {"Player work table", "Foreground chased goblet", "Leather book", "Coin pouch",
                  "Ember bowl", "Tooled leather mat", "Loose iron hardware", "Table tongs", "Above-table lantern"}
    for ob in set(bpy.data.objects) - before:
        if ob.parent is None and ob.name not in foreground:
            ob.location.y += 70
            ob.location.z -= 40
    table_bounce.location.y -= 70
    table_bounce.location.z += 40
    bpy.data.objects["Above-table lantern"].location.z -= 40
    platform = G.Asset("Player floor platform")
    platform.block("Raised stone floor", (475, 270, 40), (0, -85, floor_z - 20), floor, 0.3)
    stone_steps.build("Work bay steps", loc=(0, 50, floor_z - 40), width=440, tread=15, rise=10, count=4)
    receivers = bpy.data.collections.new("Table lantern receivers")
    for ob in set(bpy.data.objects) - before:
        if ob.type in {"MESH", "CURVE"}:
            receivers.objects.link(ob)
    receivers.objects.link(bpy.data.objects["forge_slab"])
    table_bounce.light_linking.receiver_collection = receivers
    hearth_objects = set(bpy.data.objects["Stone forge"].children_recursive)
    hearth_receivers = bpy.data.collections.new("Soot surface illumination")
    for ob in hearth_objects:
        if ob.type in {"MESH", "CURVE"}:
            hearth_receivers.objects.link(ob)
    furnishings = bpy.data.collections.new("Room fill without washing the hearth")
    for ob in receivers.objects:
        if ob not in hearth_objects:
            furnishings.objects.link(ob)
    moon_receivers = bpy.data.collections.new("Cool work station reflections")
    for name in ("Anvil", "Quench tub", "Tool wall", "Smithy back wall", "Shelves beside tools"):
        for ob in bpy.data.objects[name].children_recursive:
            if ob.type in {"MESH", "CURVE"}:
                moon_receivers.objects.link(ob)
    group = G.Asset("Emberforged room frame", rot_z=-math.pi / 2)
    for ob in set(bpy.data.objects) - before:
        if ob.type == "LIGHT":
            ob.data.energy *= 7.0
            ob.light_linking.receiver_collection = (moon_receivers if ob == moon_fill else
                                                   hearth_receivers if ob == soot_rake else receivers if ob in hearth_objects else furnishings)
        if ob != group.root and ob.parent is None:
            group.add(ob)
    # Blender's optical calculation uses metres even in a centimetre scene.
    return dict(loc=(-34, 0, 34), target=(65, 0, -33), lens=30,
                fstop=4 * scene.unit_settings.scale_length, focus=(0, 0, 1.4))
