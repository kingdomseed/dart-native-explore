# Procedural room assets

Every asset exposes `build(name, loc, rot_z, **params) -> bpy.types.Object`.
The result is an empty transform root; geometry, nested assets, and lights are
parented beneath it. Dimensions are centimetres and `rot_z` is in radians.
Furniture origins are on the floor, small-prop origins on their supporting
surface, and the fur origin on the bench top. Wall pieces face local -Y.

All modeled assets accept `wear` and `seed`. Wood assets expose `wood_tone`;
metal assets expose `metal_finish` (`iron`, `steel`, `brass`, `copper`, `pewter`).
Other surface colors use `tone` or `stone_tone`. No downloaded geometry,
textures, text, or external assets are required.

| Module | Geometry and main variation controls |
| --- | --- |
| `forge` | Masonry firebox, wedge arch, tapered hood, coke and flame tongues; width, depth, height, hearth_height, mouth_spring, stone_tone, energy |
| `anvil` | London profile, drawn horn, cutting step, pierced heel, feet and banded stump; length, stump_height, wood_tone, metal_finish |
| `oak_table` | Separate planks, breadboard ends, pegs, aprons, chamfered legs, through stretcher; width, depth, height, thickness, wood_tone, scorch |
| `tool_rack` | Pivoted tongs, two peen types, chisels, punches, horseshoes and suspension loops; width, height, wood_tone, metal_finish |
| `lantern` | Hexagonal glazed cage, diamond bars, peaked cap, candle, chain and hook; height, radius, chain_length, metal_finish, energy |
| `leaded_window` | Stone reveal, diamond cames, glazing, moon and town backdrop; width, height, reveal, moon_height, moon_offset, sky_strength, moon_strength, exterior_slope, energy |
| `barrel` | Curved individual staves, riveted hoops and inset head or open tub; radius, height, open_top, water, wood_tone |
| `fur_throw` | Draped hide, short undercoat and clumped guard hairs with lighter tips; width, length, drop, tone, strands |
| `strongbox` | Oak coffer, curved plank lid, iron straps, hasp, handles; width, depth, height, wood_tone, metal_finish |
| `shelf` | Bracketed shelves populated with vessels; width, depth, levels, spacing, count, wood_tone |
| `vessel` | Lathed and decorated goblet, tankard, jar or bottle; kind, height, radius, metal_finish, tone |
| `book` | Leather covers, raised binding cords, parchment, clasps and corner mounts; width, depth, thickness, tone, metal_finish |
| `pouch` | Gathered leather, eyelets, drawstring and knots; radius, height, tone, metal_finish |
| `ember_bowl` | Hammered copper bowl and refractive crystals with separate glowing cores; radius, height, metal_finish, energy |
| `candles` | Beeswax, drips, wick, small flames and drip pan; height, radius, count, tone, energy |
| `shield` | Dished iron plate, boss, rolled rim and riveted ribs; radius, metal_finish |
| `table_tools` | Resting full-size tongs or peen hammers; kind, length, metal_finish, wood_tone |
| `stone_steps` | Dressed tread slabs and recessed mortar risers; width, tread, rise, count, tone |
| `forge_plate` | Thin hammered support plate; width, depth, thickness, metal_finish |
| `leather_mat` | Curled hide, blind-tooled rings and lozenges, sewn border; width, depth, roll, tone |
| `loose_hardware` | Resting interlocked chain and blank iron counters; length, coins, metal_finish |
| `masonry` | Varied hewn ashlar with real rectangular openings; width, height, thickness, openings, tone |

`geometry.py` supplies construction helpers. `materials.py` supplies procedural
PBR surfaces. `preview_asset.py` renders one asset in a neutral studio with an
unlettered 10 cm scale bar. Run it through Blender with arguments after `--`,
for example `--asset anvil --out <dice_lookdev>/out/r2/assets`.

The studio accepts `--params` as a JSON object and `--elevation` for its viewing
angle. All previews and temporary files must stay below `dice_lookdev/out`.

Emberforged rotates the room root -90 degrees and keeps the tray at z=0.
The table top is z=-1.2, flush with the bottom of the 1.2 cm forged plate.
The room camera is 35.2 cm above the tabletop, at f/4 with the aperture converted
for the centimetre scene. Its hero layout spreads the seven dice along the tray.
The top-down layout remains unchanged. The player floor stays at z=-76;
four 10 cm steps descend to a working bay at z=-116. The bay sits 70 cm
farther behind the table, preserving the furniture dimensions while allowing
the forge arch, anvil stump and window to appear together in the seated view.
Full-size tongs rest beyond the 10 cm exclusion zone at the far table edge.

Exposure is -1.15 EV. Room lights use a receiver collection containing room
surfaces and the plate, so the room can be lit without changing the tray lights.
The tray geometry and materials, dice code, and `key`, `cold_rim`, and `fill`
lights remain unchanged.

`leaded_window.exterior_slope` offsets the distant backdrop with depth to match
the viewing elevation through the reveal (rise/run; default 0 for a level view).
