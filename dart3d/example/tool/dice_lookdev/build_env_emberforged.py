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
    """A seated broadside view, with the working bay behind the player table."""
    from assets import (anvil, barrel, book, candles, ember_bowl, forge, fur_throw,
                        geometry as G, lantern, leaded_window, leather_mat, loose_hardware,
                        masonry, materials as M, oak_table, pouch, shelf, shield,
                        stone_steps, strongbox, tool_rack, vessel)
    import bpy

    before = set(bpy.data.objects)
    floor_z, bay_z = RC.FLOOR_Z, RC.FLOOR_Z - 40
    wood = (0.095, 0.038, 0.013)
    oak_table.build("Player work table", loc=(0, -14, floor_z), width=136, depth=56,
                    height=74.8, thickness=7, wood_tone=wood, seed=2)
    vessel.build("Foreground chased goblet", loc=(-35, 5, -1.2), height=18, radius=5.1, seed=8)
    book.build(loc=(-40, -6, -0.83), rot_z=-0.12, width=17, depth=24, thickness=5, seed=9)
    pouch.build(loc=(35, 6, -1.2), radius=6, height=11, seed=4)
    ember_bowl.build(loc=(36.5, 4, -1.2), radius=8.5, height=4.5, energy=70, seed=5)
    leather_mat.build(loc=(-43, -6, -1.17), rot_z=0.1, width=24, depth=31, seed=4)
    loose_hardware.build(loc=(43, 3, -1.2), rot_z=-0.3, length=14, seed=9)
    lantern.build("Above-table lantern", loc=(31, 10, 25), height=32, radius=7, chain_length=36, energy=900)
    foreground = set(bpy.data.objects) - before

    masonry.build("Smithy back wall", loc=(0, 218, bay_z), width=350, height=255,
                  openings=((-48.5, 50, 44, 60), (77, 10.5, 84, 74)), tone=(0.15, 0.135, 0.105))
    masonry.build("Left return", loc=(-175, 50, bay_z), rot_z=math.pi / 2,
                  width=335, height=255, tone=(0.12, 0.105, 0.083), seed=21)
    floor = M.stone("Worn flagstones", (0.064, 0.056, 0.043), wear=0.6, seed=18)
    E.cube("Room flagstone floor", (350, 500, 5), (0, 70, bay_z - 2.5), floor, bevel=0.3)
    platform = G.Asset("Player floor platform")
    platform.block("Raised stone floor", (350, 290, 54), (0, -45, floor_z - 27), floor, 0.3)
    stone_steps.build("Work bay steps", loc=(110, 100, bay_z - 14), width=60, tread=15, rise=9, count=6)
    forge.build(loc=(-44, 204, bay_z), rot_z=0.18, width=70, depth=50, height=215,
                energy=75000, stone_tone=(0.048, 0.045, 0.04), seed=12,
                hearth_height=50, mouth_spring=22)
    anvil.build(loc=(29, 187, bay_z), rot_z=math.pi + 0.08, length=55, stump_height=49, seed=8)
    barrel.build("Quench tub", loc=(-89, 156, bay_z), radius=19, height=48,
                 open_top=True, water=True, seed=9)
    barrel.build("Left cask", loc=(-121, 187, bay_z), radius=23, height=80, seed=6)
    barrel.build("Right cask", loc=(150, 154, bay_z), radius=23, height=80, seed=14)
    tool_rack.build(loc=(0, 215, -94), width=70, height=52, metal_finish="steel", seed=7)
    shield.build(loc=(-91, 215, -38), radius=19, seed=5)
    shelf.build("High smithy shelf", loc=(-5, 217, -33), width=59, levels=1, spacing=30, count=4, seed=4)
    shelf.build("Right shelves", loc=(147, 217, -67), width=40, levels=2, spacing=28, seed=21)
    leaded_window.build(loc=(77, 218, -105), width=60, height=65, reveal=14, energy=42000,
                         seed=9, moon_height=0.8, moon_offset=0.6, exterior_slope=0.47)
    oak_table.build("Back workbench", loc=(80, 174, bay_z), width=86, depth=57, height=56,
                    thickness=6, wood_tone=(0.1, 0.04, 0.016), seed=8)
    fur_throw.build(loc=(96, 158.5, -59.9), width=38, length=62, drop=30,
                    tone=(0.115, 0.078, 0.043), seed=12)
    strongbox.build(loc=(108, 191, -60), width=26, depth=21, height=22, seed=3)
    candles.build(loc=(69, 164, -60), height=10, radius=1.5, energy=1400, seed=5)
    lantern.build("Bench lantern", loc=(44, 180, -60), height=26, radius=6.5, chain_length=0, energy=13000)
    lantern.build("Forge-side hanging lantern", loc=(-87, 198, -56), height=28, radius=7,
                  chain_length=134, energy=18000)
    lantern.build("Tools hanging lantern", loc=(26, 206, -55), height=25, radius=6.5,
                  chain_length=136, energy=18000)
    lantern.build("Window-side hanging lantern", loc=(99, 206, -65), height=30, radius=7,
                  chain_length=141, energy=18000)
    dressing = G.Asset("Smithy fixtures")
    im = M.metal("Smithy chains", wear=0.7)
    beam_wood = M.oak("Roof timber", (0.07, 0.028, 0.012), axis="Z", seed=4)
    for x in (-155, -92, 29, 124):
        dressing.block("Roof post", (11, 10, 255), (x, 222, bay_z + 127.5), beam_wood, 0.65)
    dressing.block("Wall head beam", (348, 14, 16), (0, 216, 121), beam_wood, 0.8)
    for x in (-87, 26, 31, 99):
        dressing.block("Lantern supporting joist", (12, 280, 18), (x, 115, 121), beam_wood, 0.7)
    for x, z, length in ((-108, -10, 73), (-95, -4, 62), (28, -35, 42), (131, -12, 62)):
        G.chain(dressing, "Hanging smithy chain", (x, 210, z), length, im, radius=1.25)

    def area(name, loc, target, energy, color, size, specular=True):
        ob = dressing.light(name, loc, energy, color, size, target=target, kind="AREA")
        ob.visible_glossy = specular
        ob.data.specular_factor = 1 if specular else 0
        return ob

    area("Forge light on wall and tools", (-58, 112, -26), (-12, 215, -65),
         165000, (1, 0.62, 0.35), 65)
    area("Warm smithy bounce", (10, 85, 2), (18, 210, -55),
         105000, (1, 0.76, 0.51), 120)
    soot_rake = area("Warm grazing light on soot", (-96, 100, 7), (-44, 146, -21),
                     150000, (1, 0.66, 0.4), 55)
    area("Anvil reflected forge light", (-12, 132, -14), (16, 180, -38),
         28000, (1, 0.73, 0.46), 38)
    area("Bench lantern reflected warmth", (49, 142, -21), (81, 180, -48),
         24000, (1, 0.72, 0.43), 45)
    area("Window moonlit edge", (80, 213, -46), (26, 144, -43),
         50000, (0.32, 0.53, 1), 48)
    table_bounce = area("Lantern table bounce", (-20, 4, 38), (0, 12, -1.2),
                        6500, (1, 0.69, 0.4), 38)
    for ob in set(bpy.data.objects) - before:
        if ob.parent is None and ob not in foreground and ob.name not in {"Player floor platform", "Work bay steps"}:
            ob.location.y += 30
            ob.location.z -= 14
    table_bounce.location.y -= 30
    table_bounce.location.z += 14
    table_receivers = bpy.data.collections.new("Player table light receivers")
    room_receivers = bpy.data.collections.new("Smithy light receivers")
    hearth_receivers = bpy.data.collections.new("Hearth stone receivers")
    furnishings = bpy.data.collections.new("Room illumination without washing soot")
    hearth_objects = set(bpy.data.objects["Stone forge"].children_recursive)
    for ob in set(bpy.data.objects) - before:
        if ob.type in {"MESH", "CURVE"}:
            table_receivers.objects.link(ob)
            if ob not in foreground:
                room_receivers.objects.link(ob)
            if ob in hearth_objects:
                hearth_receivers.objects.link(ob)
            elif ob not in foreground:
                furnishings.objects.link(ob)
    table_receivers.objects.link(bpy.data.objects["forge_slab"])
    group = G.Asset("Emberforged room frame", rot_z=-math.pi / 2)
    for ob in set(bpy.data.objects) - before:
        if ob.type == "LIGHT":
            restrained = ob == table_bounce or ob in foreground or ob.name in {
                "Window moonlit edge", "Bench lantern reflected warmth", "Moon through window"}
            ob.data.energy *= 7 if restrained else 13
            ob.light_linking.receiver_collection = (table_receivers if ob == table_bounce or ob in foreground else
                                                   hearth_receivers if ob == soot_rake else room_receivers if ob in hearth_objects else furnishings)
        if ob != group.root and ob.parent is None:
            group.add(ob)
    return dict(loc=(-61, 0, 39), target=(0, 0, 10.55), lens=50,
                fstop=8 * scene.unit_settings.scale_length, focus=(8, 0, 1.4))
