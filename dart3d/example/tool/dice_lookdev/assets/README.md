# Procedural room assets

Every asset exposes `build(name, loc, rot_z, **params) -> bpy.types.Object`.
The result is an empty transform root; geometry, nested assets, and lights are
parented beneath it. Dimensions are centimetres and `rot_z` is in radians.
Furniture origins are on the floor, small-prop origins on their supporting
surface, and the fur origin on the bench top. Wall pieces face local -Y.

All modeled assets accept `wear` and `seed`. Wood assets expose `wood_tone`;
forged metal assets expose `metal_finish` (`iron`, `steel`, `brass`, `copper`, `pewter`).
Polished diner metals use `metal_tone` or `tone`, with finish breakup controlled by `wear`.
Other surface colors use `tone` or `stone_tone`. No downloaded geometry,
textures, text, or external assets are required.

| Module | Geometry and main variation controls |
| --- | --- |
| `forge` | Masonry firebox, wedge arch, tapered hood, coke and flame tongues; width, depth, height, hearth_height, mouth_spring, stone_tone, energy |
| `anvil` | London profile, drawn horn, cutting step, pierced heel, feet and bark-covered log with sawn end grain and radial splits; length, stump_height, wood_tone, metal_finish |
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
| `diner_counter` | Rounded laminate top, continuous chrome bullnose, walnut panels, kick plate, foot rail, individual water beads and small puddles; width, depth, height, tone, wood_tone, quiet, droplets, puddles, streaks, drop_radius, back_wings, back_wing_inset |
| `bar_stool` | Spun pedestal and foot ring, upholstered red vinyl cushion with button dimples and piping; height, radius, tone, metal_tone |
| `dome_pendant` | Spun chrome dome, enamel lining, socket, bulb and suspension cord; radius, height, drop, tone, color, energy |
| `espresso_machine` | Shaped boiler cover, gauges, group heads, portafilters, steam wands, drip grille and warming cups; width, depth, height, tone |
| `pie_stand` | Raised pie plate, crimped crust, lattice filling and glass cloche; radius, height |
| `napkin_dispenser` | Pressed curved shell, paper opening, folded tissues, cover rivets and rubber feet; width, depth, height, metal_tone |
| `salt_shaker` | Fluted glass, salt fill, domed chrome cap and perforations; height, radius |
| `coffee_mug` | Thick porcelain, rolled lip, swept ear handle, coffee meniscus and curling steam sheets; height, radius, tone, steam_height, steam_strength, steam_width, steam_drift |
| `leather_menu` | Folded leather, inset cover, rolled binding and saddle stitches; width, depth, thickness, tone |
| `rain_window` | Clear panes, chrome and black frames, separate refracting droplets, runoff trails and slight low condensation; width, height, panes, density, drop_radius, large_drop_fraction, bottom_density, fog |
| `neon_sign` | Supported original tubes shaped as a planet, rings, bars or chevrons; width, height, design, color, strength, backing |
| `street_car` | Parked saloon silhouette with a shaped body, curved roof, glazing, wheels, brightwork and lamps; length, width, height, tone, tail_lights |
| `neon_street` | Wet road and puddles, kerbs, articulated facades at multiple depths, mostly dark window grids, mounted neon signs, street lamps, curbside cars and falling rain; width, depth, cars, exterior_slope, falling_rain, lead_in |

`geometry.py` supplies construction helpers. `materials.py` supplies procedural
PBR surfaces, including dull fissured bark and sawn end grain for log sections. `preview_asset.py` renders one asset in a neutral studio with an
unlettered 10 cm scale bar. Run it through Blender with arguments after `--`,
for example `--asset anvil --out <dice_lookdev>/out/r2/assets`.

The studio accepts `--params` as a JSON object and `--elevation` for its viewing
angle. All previews and temporary files must stay below `dice_lookdev/out`.
Use `--direction`, `--target` and `--extent` to frame larger assemblies.
`--studio-strength` can be reduced to inspect a street or illuminated sign under
its own lights. Pendant origins are at the shade lip; window origins are at the
bottom rail; street origins are at road level.

Voltline uses a continuous 80 × 64 cm counter with its top at z=-0.25,
flush with the preserved holo base. The broadside room and furniture rotate
as one root while the tray stays in its original orientation. Foreground
props are at least 10 cm from the tray and sit directly on the counter.
The camera is 38.75 cm above the top, looks down 24.6 degrees through a
54 mm lens. The second pass stops down to f/32 converted for centimetre
scene units and focuses 25 cm behind the tray centre to keep the street legible; the visible neon rim spans 77% of the frame.
`diner_counter.quiet` sets the half-widths of a rectangle without water beads
or puddles. Voltline uses a 28 × 20 cm half-extent, preserving at least
10 cm of quiet surface beyond the rim, with a gradual material transition to the wet surface outside.
Rain is separate geometry on clear panes; the glass has no large-scale bump
or distortion. City windows, signs, cars and their reflections are actual
geometry behind the glazing. All signage is abstract and unlettered.
`neon_street.exterior_slope` grades the road with depth, places the buildings
on that grade, and pitches the cars to keep their tires on the road. The
window counter can therefore overlook a descending street without flattening
the exterior into a backdrop. `lead_in` extends the wet approach toward the
camera without moving the facades. Voltline uses a 0.22 grade; the camera
stays above the road plane so its reflections remain visible. The planet sign
mounts to the near building end wall. The 17–15.4 cm pendant shades recede
roughly 2.3–5.1 m from the camera over descending bar terraces. Rain glint
lights affect only drops and trails and remain visible to transmission rays,
so individual water lenses catch light without washing out the pane.

Voltline adds procedural polished metal, porcelain, vinyl, wet laminate,
clear glass, steam, pastry, clear rain glazing and wet asphalt helpers to
`materials.py`. The existing Emberforged material functions are unchanged.
Room lights are linked to environment receivers, preserving the holo tray's
three original lights and its top-down readability.

Emberforged rotates the room root -90 degrees and keeps the tray at z=0.
The table top is z=-1.2, flush with the bottom of the 1.2 cm forged plate.
The seated camera is 40.2 cm above the tabletop, looks down 25 degrees, and
uses a 50 mm lens at f/8 with the aperture converted for centimetre scene units.
Focus is slightly behind the middle dice to retain background definition.
The hero layout spreads the seven dice along the tray; the top-down layout
remains unchanged. The shallower player table clears the view of the hearth
and anvil base, and the tabletop tongs have been removed.
The player floor stays at z=-76; six 9 cm steps descend to the working bay at
z=-130. Fixtures sit roughly 1.9-2.5 m behind the tray, with the forge to the
left, tools and anvil in the middle, and the moonlit window to the right.
The forge uses a separate grazing light so room fill does not wash out soot.

Exposure is -1.15 EV. Room lights use a receiver collection containing room
surfaces and the plate, so the room can be lit without changing the tray lights.
The tray geometry and materials, dice code, and `key`, `cold_rim`, and `fill`
lights remain unchanged.

`leaded_window.exterior_slope` offsets the distant backdrop with depth to match
the viewing elevation through the reveal (rise/run; default 0 for a level view).
