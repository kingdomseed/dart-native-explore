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
| `oak_table` | Separate planks, breadboard ends, pegs, aprons, chamfered legs, through stretcher; width, depth, height, thickness, wood_tone, scorch, leg_inset, leg_width, optional rear_recess |
| `tool_rack` | Pivoted tongs, two peen types, chisels, punches, horseshoes and suspension loops; width, height, wood_tone, metal_finish |
| `lantern` | Hexagonal glazed cage, diamond bars, peaked cap, candle, chain and hook; height, radius, chain_length, metal_finish, energy |
| `leaded_window` | Stone reveal, diamond cames, glazing, moon and town backdrop; width, height, reveal, moon_height, moon_offset, sky_strength, moon_strength, exterior_slope, energy |
| `barrel` | Curved individual staves, riveted hoops and inset head or open tub; radius, height, open_top, water, wood_tone |
| `fur_throw` | Draped hide, short undercoat and clumped guard hairs with lighter tips; width, length, drop, tone, strands |
| `strongbox` | Oak coffer, curved plank lid, iron straps, hasp, handles; width, depth, height, wood_tone, metal_finish |
| `shelf` | Bracketed shelves populated with vessels; width, depth, levels, spacing, count, wood_tone |
| `vessel` | Lathed and decorated goblet, tankard, jar or bottle; kind, height, radius, metal_finish, tone |
| `book` | Leather covers, raised binding cords, parchment, clasps, corner mounts and optional unlettered spine tooling; width, depth, thickness, tone, metal_finish, gilt_spine |
| `pouch` | Gathered leather, eyelets, drawstring and knots; radius, height, tone, metal_finish |
| `ember_bowl` | Hammered copper bowl and refractive crystals with separate glowing cores; radius, height, metal_finish, energy |
| `candles` | Beeswax, drips, wick, small flames and drip pan; height, radius, count, tone, energy |
| `shield` | Dished iron plate, boss, rolled rim and riveted ribs; radius, metal_finish |
| `table_tools` | Resting full-size tongs or peen hammers; kind, length, metal_finish, wood_tone |
| `stone_steps` | Dressed tread slabs and recessed mortar risers; width, tread, rise, count, tone |
| `forge_plate` | Thin hammered support plate; width, depth, thickness, metal_finish |
| `leather_mat` | Curled hide, blind-tooled rings and lozenges, sewn border; width, depth, roll, tone |
| `loose_hardware` | Resting interlocked chain and blank iron counters; length, coins, metal_finish |
| `masonry` | Varied hewn ashlar with real rectangular openings; width, height, thickness, openings, tone; optional block_width, course_height, arris and relief |
| `diner_counter` | Rounded laminate top, continuous chrome bullnose, walnut panels, kick plate, foot rail, individual water beads and small puddles; width, depth, height, tone, wood_tone, quiet, droplets, puddles, streaks, drop_radius, back_wings, back_wing_inset |
| `bar_stool` | Spun pedestal and foot ring, upholstered red vinyl cushion with button dimples and piping; height, radius, tone, metal_tone |
| `dome_pendant` | Spun chrome dome, enamel lining, socket, bulb and suspension cord; radius, height, drop, tone, color, energy |
| `espresso_machine` | Shaped boiler cover, gauges, group heads, portafilters, steam wands, drip grille and warming cups; width, depth, height, tone |
| `pie_stand` | Raised pie plate, crimped crust, lattice filling and glass cloche; radius, height |
| `napkin_dispenser` | Pressed curved shell, paper opening, folded tissues, cover rivets and rubber feet; width, depth, height, metal_tone |
| `salt_shaker` | Fluted glass, salt fill, domed chrome cap and perforations; height, radius |
| `coffee_mug` | Thick porcelain, rolled lip, swept ear handle, coffee meniscus and curling steam sheets; height, radius, tone, steam_height, steam_strength, steam_width, steam_drift, steam_opacity |
| `leather_menu` | Folded leather, inset cover, rolled binding and saddle stitches; width, depth, thickness, tone |
| `rain_window` | Clear panes, chrome and black frames, separate refracting droplets, runoff trails and slight low condensation; width, height, panes, density, drop_radius, large_drop_fraction, bottom_density, fog |
| `neon_sign` | Supported original tubes shaped as a planet, rings, bars or chevrons; width, height, design, color, strength, backing |
| `street_car` | Parked saloon silhouette with a shaped body, curved roof, glazing, wheels, brightwork and lamps; length, width, height, tone, tail_lights, lamp_gain |
| `neon_street` | Wet road and puddles, kerbs, articulated facades at multiple depths, mostly dark window grids, mounted neon signs, street lamps, curbside cars and falling rain; width, depth, cars, exterior_slope, falling_rain, lead_in, emission_gain, light_gain, ambient_gain |
| `marble_loggia` | Entasis shafts, carved capitals, dressed arches, molded archivolts and turned balustrade; bays, span, height, radius, balustrade_height, rail_offset, rail_base, tone |
| `marble_table` | Fine-veined polished top, ogee edge and turned stone trestles; width, depth, height, thickness, tone, quiet, back_wings, polish |
| `telescope` | Sectioned refractor, dew cap, lens, focuser, finder, equatorial bearings and braced tripod; length, radius, stand_height, elevation, wood_tone, metal_tone |
| `armillary` | Graduated nested brass bands and central sphere, or enamel celestial globe with inlaid coordinates; kind, radius, pedestal, metal_tone |
| `amethyst_cluster` | Terminated quartz prisms, pale tips, internal inclusions and spun brass bowl; radius, height, count, bowl, tone, metal_finish, energy, mineral, glow, fractures, edge_glow |
| `velvet_drape` | Folded velvet runner with an edge drop, sewn borders and gold star embroidery; width, length, drop, tone, stars, sheen_tone, stitch_width; optional heap, curved sweep, embroidery spacing/band and weighted rest patches |
| `astronomer_tools` | Rete disk, curled constellation chart, convex magnifier or pierced incense vessel; kind, radius, width, depth, metal_tone |
| `night_vista` | Indigo galaxy, maria and terminator, distant planet, spired floating citadels and layered surface clouds; width, depth, slope, sky_strength, moon_strength, moon_offset, planet_offset, cloud_drop |
| `stone_altar` | Chamfered granite mensa, moulded edge, carved trestles and bronze geometric inlays; width, depth, height, tone, metal_tone, frost, carving, accumulation, quiet, quiet_center |
| `frost_pillar` | Fluted entasis drum shaft, moulded foot, leaf-rib capital and riveted bronze collars; height, radius, tone, frost, metal_tone, accumulation, cap_hole |
| `frozen_arch` | Frosted column pair, separate wedge voussoirs and concentric archivolts; width, shoulder, radius, depth, tone, frost |
| `fire_bowl` | Spun bronze brazier, embossed bands, dark heaped coals, buried embers and curling fire sheets; radius, height, flame_height, metal_tone, flames, energy |
| `ice_formation` | Thick folded glacial wall with internal fractures, tapered curved icicles, or scalloped snow banks; kind, width, depth, height, count, tone, glow |
| `winter_banner` | Draped pointed cloth, gold piping and snowflake embroidery that follows the folds; width, height, tone, metal_tone, stitch_width |
| `cold_mist` | Low soft transparent mist surfaces and sparse falling ice motes; width, depth, height, layers, opacity, tone, flakes, flake_height, flake_radius, flake_glow |
| `glacier_vista` | Layered snow-covered mountain meshes, masonry bridge, frozen cascade and cloud banks; width, depth, slope, sky_strength, tone |
| `snow_cover` | Modeled granular snow with feathered edges, clear footprints and sparse crystal glints; width, depth, thickness, quiet, quiet_center, holes, shape, sparkle |
| `bookcase` | Carved oak pilasters, rosettes, moulded cornice, dentils and varied leather-bound volumes with gilt spine divisions; width, height, depth, rows, fullness, wood_tone |
| `gothic_window` | Moulded pointed reveal, supported lancet and quatrefoil tracery, glazing, shaded moon and layered spired town; width, height, reveal, stone_tone, exterior_slope, moon_offset, sky_strength, energy |
| `writing_set` | Chased botanical inkwell, curved feather with individual barbs, or spirally rolled parchment and leather tie; kind, width, height, quill_length, metal_finish, tone |
| `runestone_bowl` | Repousse basin and faceted blue stones with recessed luminous triangles, diamonds and circles; radius, height, count, tone, metal_finish, energy |
| `candlestick` | Turned pricket foot, knop and fluting around the reused wax candle, drip pan and flame; height, radius, candle_height, candle_radius, metal_finish, energy, flame_strength |

| `clockwork_gear` | Sampled involute spur teeth, open spoke web and bored stepped hub; pitch radius, teeth, thickness, spokes, bore, phase, axis, metal_finish |
| `pipework` | Swept elbows, bolted unions, wheel valves or convex-glass pressure dials with ticks and needle; kind, points, radius, gauge_radius, reading, wheel_radius, metal_finish |
| `tesla_column` | Turned electrode caps, flanges, tie rods, thin glazing, porcelain sheds and continuous emissive helix; radius, height, turns, tone, strength, energy, metal_finish |
| `dice_machine` | Cast frame, riveted barrel crown, sloped discharge plate, rollers, gear train and pressure fittings; width, depth, height, output_height, metal_finish |
| `industrial_lamp` | Reused spun pendant with bowed bulb guard, reinforcing hoops and brass rivets; radius, height, drop, metal_finish, energy, color |
| `engineering_sheet` | Curled technical drawing with gear elevations, section hatching and dimension ticks; width, depth, blueprint, curl, pinned, ink_width |
| `precision_tools` | Graduated sliding caliper, hinged dividers or turned-handle screwdriver; kind, length, opening, wood_tone, metal_finish |

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
54 mm lens at f/8 converted for centimetre scene units, focused on the dice
at the tray centre; the visible neon rim spans 77% of the frame.
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
over descending bar terraces. The bar terraces are lifted 60 cm and shifted
35 cm left from the previous blocking, putting their red seats and chrome
edges above the foreground counter. A lit bottle return sits on the rear
service bar. Street emission, practical-light power and ambient bounce have
independent gain parameters. The steam uses a broad, low-opacity fade instead
of narrow oscillating sheets. Counter beads and short streaks receive linked
magenta, cyan and warm glints; the quiet margin receives only a smooth light wash. Rain glint
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

Celestial keeps the original tray, marble builders, astrolabe inlay and four tray
lights. The room rotates -90 degrees around the tray. Its lower camera sits
29.3 cm above the table, with a 38.5 mm lens and f/8 converted for centimetre
scene units. The rounded rim spans 77.9 percent of the frame. Foreground
instruments and embroidered velvet remain at least 10.3 cm beyond the tray slab.
The table ends just behind the tray, with supported side returns for the cloth,
astrolabe, chart and crystals. Lanterns, armillary, telescope and globe overlap
at distinct depths rather than sharing a single back edge. The refractor points
38 degrees upward and its tripod stands on the lower terrace landing.

The marble table's optional `polish` parameter tightens the coat and base
reflection; zero preserves its previous finish. Warm lantern returns, a cooler
back edge and a violet crystal accent light the room through an environment
receiver collection. Separate linked lights illuminate only the existing tray
chart and thin marble slab. No tray material, geometry or original light is
changed. Exposure remains -0.5 EV for numeral contrast at the required
50 percent preview size.

The night vista uses procedural surfaces and multiple geometry layers, without
volumes, external images or lettering. Its `slope` aligns the vista with the
seated viewing angle. `moon_offset` and `planet_offset` control horizontal
position and height above that slope; `cloud_drop` reveals more of the floating
crags. Two-dimensional, brightness-selected stars avoid the sparse cross-section
of the original three-dimensional noise. The moon retains maria and a soft
terminator with gentler surface contrast. Earlier room material functions remain
unchanged.


Frostbound keeps the original granite floor shader, engraved circle, rim profile,
rim material and all six original lights. Its carved altar top meets the tray at
z=0. The room rotates -90 degrees; a 39.5 mm camera sits 33 cm above the altar at
f/8, converted for centimetre units. The rim spans 79.4 percent of the frame and
its near edge meets the lower frame boundary. The player floor remains at z=-76,
with stepped hall landings at -135, -200 and -240 cm opening toward the bridge
and frozen cascade.

The right return is replaced by internally glowing, fractured ice and an
armillary on a snow-capped carved pedestal. Supported navy and gold banners
frame the bridge behind the warm bronze braziers. Chipped altar edges carry
geometric friezes. Modeled snow accumulates on the altar, capital and base
ledges; `quiet` and `holes` preserve the play-view margin and the feet of objects.
Snow coverage tapers through a mesh attribute to avoid hard grid edges. Small
refractive grains add sparse glints. The clear area around the tray extends
10.2 cm beyond the rim before any bright snow accumulation begins.

Warm fire pools sit against darker granite, with a bright glacier valley and
cyan ice edges. Room lights use environment receivers. Two added cool lights
exclude existing environment surfaces so they illuminate the dice created by
the renderer afterward; the original tray lights and materials stay unchanged.
This avoids washing out the floor while strengthening die separation. Exposure
remains -0.9 EV. Mist uses independently seeded, irregular transparent wisps;
low layers beyond the altar retain the 10 cm clearance. Snowfall is sparse and
there are no room-scale volumes.

The `amethyst_cluster` ice mode shares its original prism construction and
supports optional internal fractures and edge glow. The default amethyst mode
is unchanged. Snow, ice and mist material additions are confined to Frostbound;
Emberforged, Voltline and Celestial retain their material behavior.


Arcane preserves the original board shader, board/base/rim/boss geometry and all
five build-stage lights, including the overhead. Its second-pass camera looks
down 35.2 degrees with a 20.4 mm lens at effective f/8. The camera is 21.5 cm
above the desktop; the close, wider view makes the tray span 84.6 percent of
the frame, with the near rim cropped at the bottom.

The separate box-shaped side returns are replaced by one planked oak desktop
with a continuous straight far edge in front of the armillary reading table. Candles,
inkwell, runestone bowl, gilt tomes, parchment and a pierced brass censer share
the main desktop. Heaped navy velvet has larger sewn stars following its folds
and weighted flat patches beneath the supported objects. The armillary remains
on a lower supported instrument table behind the desk. Carved bookcases and
the moonlit Gothic window frame the upper part of the shot.

Warm candle pools and cool window light are linked to room receivers. Two
additional warm reflections illuminate the existing brass board and rim cap;
exposure remains -0.15 EV. The original tray materials and lights are unchanged.
At 50 percent / 32 samples the top-down gate passes: numeral 5.20, die versus
tray 5.02, stroke 0.124–0.130. Dressing clearance is at least 10.37 cm.

Optional `oak_table.rear_recess` takes the two radii of the curved desk cutout;
it leaves the normal table unchanged when omitted. `velvet_drape.heap`, sweep
controls, rest patches and embroidery controls likewise preserve their previous
defaults. No shared material behavior changes. Emberforged, Voltline, Celestial
and Frostbound are re-rendered serially at 25 percent / 16 samples after these
extensions. There are no room volumes, downloads, lettering or external assets.


Fateengine preserves its brushed-steel floor, inlaid gear chart, riveted brass
rail and all four original tray lights. The broadside 17.7 mm camera at effective
f/8 looks down 34.8 degrees; the tray spans 79.95 percent of the frame. Room
lights have separate receivers. A 9.5 kW warm work-lamp return lights only the
existing tray field and rail. Exposure remains +0.1 EV.

The planked workbench has a rounded rear recess; a lower mounting bench supports
the cast dice engine and its glass induction column. The engine has sampled
involute gears of a common module, phased at the sum of their pitch radii,
shaft bearings, a riveted crown and a sloped mouth. Copper pipes use swept
elbows and bolted unions. The gauges have physical tick marks and needles,
without text. Drafting sheets and precision tools frame the desk; the minimum
measured foreground clearance is 10.37 cm beyond the tray rim.

The new `machined_metal` material adds tarnish, machining scratches, roughness
breakup and rubbed edges without changing existing material functions.
`masonry` gains optional brick-course dimensions, arris radius and face relief;
its original defaults remain unchanged. Emberforged, Voltline, Celestial,
Frostbound and Arcane are re-rendered serially at 25 percent / 16 samples and
visually checked. The engine is about 92k evaluated triangles, the induction
column 15k, and the largest wall 132k. There are no room volumes or external assets.

### Hearthside reading nook assets

- `wing_armchair`: padded leather wings, rolled arms, piped seat, turned feet, brass nailheads and optional tartan cushion/knitted throw; `width`, `depth`, `height`, `tone`, `wood_tone`, `wear`, `seed`, `throw`, `throw_tone`, `pillow`. Floor origin; faces local -Y. Chair plus throw stays below 150k evaluated triangles.
- `knit_throw`: curved support cloth with modeled interlocking wool loops, selvedges and fringe; `width`, Y/Z `path`, stitch `pitch`, `fold`, `tone`, `wear`, `seed`. Paths follow the supported furniture profile; preview contact after changing them.
- `hearth_fireplace`: hewn fieldstone, shallow voussoir arch, oak mantel/corbels, soot-lined hearth, charred logs, andirons and reused layered forge flames; `width`, `depth`, `height`, `hearth_height`, `stone_tone`, `wood_tone`, `wear`, `seed`, `energy`. The interior lamps illuminate masonry separately from the charred logs.
- `firewood`: irregular barked log with sawn ends or glowing char fissures; `length`, `radius`, `tone`, `wear`, `heat`, `seed`. Local X length; floor origin.
- `lavender`: individual branched stalks, narrow leaves and whorled dried buds, in an open handled stoneware jug or a tied flat bundle; `kind`, `height`, `radius`, `stems`, flower `tone`, `jug_tone`, `wear`, `seed`.
- `cottage_window`: deep moulded oak casement, divided lights, brass catches and the existing clear rain bead geometry; `width`, `height`, `panes`, `rows`, `wood_tone`, `wear`, `seed`, `density`, `drop_radius`, optional dusk `view`.

Backward-compatible variants: `coffee_mug(glaze_style="stoneware")`, `pouch(fabric="velvet")`, `vessel(kind="jug")`, and optional `lantern` glass/glow/light colours. `oak_table` and `materials.oak` also accept `grain_scale` (default 1.0) for tighter wood grain on smaller furniture. Their previous defaults are unchanged. New material functions are `upholstery`, `wool` (optional plaid), `stoneware` and `charred_wood`; the existing material recipes remain unchanged.

### Oldroad wayfarer's inn assets

- `hurricane_lantern`: spun tin reservoir, hollow glass chimney, wick/flame, crossed guards, side air pipes and hinged bail; `height`, `radius`, `metal_finish`, `glass_tone`, `wear`, `seed`, `energy`. The compact room version is 22 cm high.
- `travel_pack`: loaded canvas body, sewn bellows pocket, curved leather flap, punched load straps, buckles, shoulder loops, a spiral wool bedroll and suspended pewter cup; `width`, `depth`, `height`, canvas/leather/roll tones, `wear`, `seed`, `bedroll`, `cup`, `buckle_height`, `cup_height`. Faces local -Y; floor origin.
- `walking_staff`: tapered crooked ash, iron shoe, wrapped grip, carved bands and wrist thong; `height`, `radius`, `wood_tone`, `metal_finish`, `wear`, `seed`, `carved_bands`. Origin at the shoe.
- `clay_pipe`: hollow clay bowl, darkened interior, impressed lozenges, curved tapered horn stem and brass ferrule; `length`, `bowl_height`, `radius`, `tone`, `metal_finish`, `wear`, `seed`. The stem runs along local +X.
- `tavern_chair`: scooped seat, turned legs, stretchers, pegged bowed back rails and finials; `width`, `depth`, `seat_height`, `height`, `wood_tone`, `wear`, `seed`, `back`. `back=False` builds a stool.
- `timber_wall`: pegged oak posts, rails and diagonal braces around lime-plaster infill and real window openings; `width`, `height`, `thickness`, `bays`, `openings`, wood/plaster tones, `wear`, `seed`. Openings are `(center_x, bottom_z, width, height)` in local X/Z.
- `bread_board`: scored country loaf on a wooden handled trencher, with crumbs and knife marks; `width`, `depth`, `loaf_height`, `wood_tone`, `wear`, `seed`.

Shared extensions retain their previous defaults: `vessel(kind="wooden_tankard")`
uses the existing coopered `barrel` with adjustable wall/hoop thickness, rivet
radius, stave/hoop counts, bottom thickness and grain scale. `velvet_drape`
accepts `fabric="wool"` for a fringed plaid; weighted rest patches support the
pipe and tankard. `materials.wool` gains `plaid_axes`, defaulting to its original
X/Z axes. New materials are `canvas`, `limewash` and attribute-driven
`bread_crust`.

`cottage_window` gains optional blue-hour `sky_colors`, `sky_strength`,
`sky_horizon`, `exterior_slope` and `town_altitude`. The sky and lower village
silhouettes extend beyond the view for the downward room angle. Omitted
parameters preserve the approved Hearthside window.

Oldroad keeps the original map, leather board/rim and three tray lights. The
84.76-percent broadside composition uses 26.4 mm at effective f/8; the camera
is 24 cm above the table, looking down 28.3 degrees. A lower inn sitting bay
supports the pack chair, staff, fur stool and raised hearth. All foreground
feet contact the table or weighted wool, with at least 10.329 cm clearance
beyond the tray board. The warm lantern and hearth contrast with the dusk
window; no dark ceiling beam crosses the polished dice reflections. The room
uses +1.5 EV, gamma 0.8 and a 0.5-pixel Cycles filter to preserve fine numerals
in the half-size phone check. Environment lamps use separate receivers. A gentle 2 kW hearth reflection
illuminates only the subsequently created dice. The 50% / 32-sample top-down
gate passes: numeral 5.45, die versus tray 3.35, stroke 0.123–0.128.


### Northfield countryside kitchen assets

All dimensions are centimetres. These new assets use a floor or tabletop origin
and face local -Y unless noted. Each accepts `name`, `loc`, `rot_z`, `wear` and
`seed`; existing material recipes and asset defaults remain unchanged.

- `crt_terminal`: deep moulded ABS cabinet, ventilation slots, bowed rectangular CRT, recessed bezel, abstract phosphor marks and blank keyboard caps; `width`, `height`, `depth`, `tone`, `keyboard`, `energy`.
- `portable_radio`: cassette door and reels, woven metal speaker grille, tuning ticks, knurled controls, carry handle and telescopic aerial; `width`, `height`, `depth`, `tone`, `antenna`.
- `kitchen_unit`: fitted cupboard/drawer fronts, pulls and worktop, enamel cooker with hotplates and oven window, or two-door fridge with seals and handles; `kind`, `width`, `height`, `depth`, `tone`, `wood_tone`, `doors`.
- `kettle`: spun enamel body, removable lid, open tapered spout and insulated bail; `radius`, `height`, `tone`.
- `laminate_table`: continuous walnut-print top, rounded perimeter, aluminium edging, aprons and splayed legs; `width`, `depth`, `height`, `thickness`, `wood_tone`, optional `rear_recess` radii.
- `dining_chair`: scooped plywood seat, bowed veneer back, beech stiles, stretchers and legs; `width`, `depth`, `height`, `seat_height`, `wood_tone`.
- `breakfast_plate`: hollow ironstone profile, green rim bands, porous toast, butter and crumbs; `radius`, `tone`, `band_tone`, `butter`.
- `potted_plant`: curved stalks and dished leaves in a glazed pot; `height`, `radius`, `tone`, `pot_tone`, `leaves`.
- `countryside_window`: moulded painted casement, catches, gathered floral curtains and radiator, with layered spruce stands, sloping fields, a red barn and a distant articulated tripod machine; `width`, `height`, `tone`, `curtains`, `radiator`, `view`, `machine_x`, `machine_height`, `exterior_slope`.

Optional shared variants: `coffee_mug(floral=True, print_tone=...)` confines the
flower transfer to the cup's outer wall. `dome_pendant(finish="enamel",
recessed_bulb=True)` makes the orange kitchen shade. The added material recipes
are `aged_plastic`, `wood_laminate`, `retro_flower`, `toast_crumb` and `foliage`.

Northfield preserves the original calibration mat, ABS case, orange case stripe
and all three original light calls. Room lamps use an environment receiver
collection. The broadside 27.7 mm camera looks down 29.8 degrees at effective
f/8, focusing on the dice. The tray spans about 83 percent of the frame; the
closest breakfast dressing clears its board by 11.5 cm. The room uses +0.7 EV,
gamma 0.7 and a 0.2-pixel Cycles phone filter for legible small printed numerals at
half resolution. A room-only render hook uses a 1.5-pixel filter for smooth
grid lines; it does not change the gate mask pass. The required 50-percent /
32-sample gate gives numeral 4.69,
die versus tray 7.10, stroke 0.124–0.132, PASS. No volumes or external assets.


Vermilion adds reusable pavilion assets:

| Module | Geometry and main variation controls |
| --- | --- |
| `pavilion_lantern` | Joinered andon or ribbed chochin with translucent washi, collars and suspension; kind, height, radius, tone, wood_tone, glow, energy, drop |
| `tatami_mat` | Rounded rush-straw core and separate woven edge binding; width, depth, thickness, tone, border_tone |
| `shoji_screen` | Mortised cedar rails, half-lap lattice, paper backing and recessed finger pull; width, height, columns, rows, wood_tone, paper_tone, glow |
| `byobu_screen` | Hinged gold-leaf panels, black frames, original pine brushwork and cloud lines; panels, panel_width, height, fold, wood_tone |
| `lacquer_table` | Rounded solid top, fine gilt mouldings, scalloped aprons and curved legs; width, depth, height, thickness, tone, gilt |
| `zabuton` | Stuffed cushion, pinched corners, sewn welt and central tuft; width, depth, height, tone |
| `tea_service` | Hollow tea bowl, fitted-lid tea caddy or pleated folding fan; kind, radius, height, tone, metal_finish, tea |
| `cherry_branch` | Tapered limbs, blossom-bearing twigs, cupped five-petal flowers or loose resting petals; width, height, count, tone, kind |
| `pavilion_vista` | Atmospheric mountain ridges, procedural dusk sky and a four-storey pagoda with swept roofs, tile seams and bronze finial; width, depth, slope, pagoda_x, pagoda_depth, pagoda_width, pagoda_height, sky_strength |

The low table meets the preserved tray base at z=0; the foreground tatami
is at z=-32. The broadside camera uses an 18.4 mm lens, looks down 31.3 degrees,
and focuses on the dice at effective f/8, converted for centimetre scene units.
The tray spans 83.8 percent of the frame. Stepped landings lower the gold-screen
and veranda areas into the seated view. Tea bowls, the caddy, fan and fallen
petals remain at least 10 cm clear of the tray base in plan. The table props
are supported, and the fan's lowest ribs rest directly on the lacquer.

Warm andon light pools on gold leaf and the table, the red chochin provides
the accent, and blue dusk enters from the veranda. Room lights are linked to
environment receivers. Two additional diffuse-only paper/dusk returns light
the dice, preventing white area-light reflections from obscuring the lacquer
faces. Original key, moon and overhead calls remain unchanged. Exposure is
+1.3 EV; the standard pixel filter and view transform are retained. The room
uses no volumes, downloaded textures or lettering.

New `materials.py` functions are `urushi`, `washi`, `rush_weave`, `woven_silk`
and `gold_leaf`. All pre-existing material functions remain unchanged. The
nine earlier approved rooms are checked at 25 percent / 16 samples after
these additions.


Gemcutter adds reusable atelier assets:

| Module | Geometry and main variation controls |
| --- | --- |
| `jeweler_bench` | Existing pegged table joinery with rubbed walnut boards, apron drawers, drop pulls and a removable V-notched bench pin; width, depth, height, wood_tone, bench_pin, rear_recess |
| `bench_lamp` | Weighted foot, paired adjustable arms, tension springs, locking pivots and a hollow spun reflector; height, reach, radius, head_tilt, metal_finish, energy, color |
| `balance_scale` | Turned base and column, knife-edge beam, pointer, linked suspensions and dished pans; height, width, pan_radius, tilt, metal_finish |
| `cut_gem` | Closed, flat-shaded brilliant or stepped emerald cuts with a crown, girdle and pavilion; radius, cut, tone |
| `gem_case` | Joinered walnut case, velvet compartments, hinged padded lid and brass fittings; width, depth, height, rows, columns, lid_angle, wood_tone, velvet_tone, stones |
| `jeweler_tools` | Hollow knurled optical loupe with convex lens, spring tweezers with tapered jaws, or pear-handled graver; kind, length, radius, wood_tone, metal_finish |
| `drawer_chest` | Framed cabinet, individually recessed drawer fronts, mouldings, turned knobs and bun feet; width, depth, height, rows, columns, wood_tone, metal_finish |
| `atelier_window` | Reused oak casement and catches, procedural sunset clouds, layered gabled streets and pointed towers; width, height, wood_tone, view, exterior_slope, sky_strength, energy |

All eight modules accept `name`, `loc`, `rot_z`, `wear` and `seed`. The three
added material recipes are `bench_walnut`, `cut_stone` and `atelier_sky`;
pre-existing material functions and asset defaults are unchanged.

The original velvet, walnut tray base, padded rim and four light calls remain
unchanged. The broadside 25 mm camera looks down 36.2 degrees at effective
f/8. A curved rear recess exposes the balance; lowered, supported working
bays carry the balance, lamp and drawer chest. The tray spans 77.7 percent
of the image. Foreground loupes and tweezers clear the tray by at least
10.8 cm and rest on the bench. The task lamp remains cool white; sunset
and amber reflections warm the walnut and brass, with emerald at the right.
Room lamps use environment receivers. The global grade is +0.85 EV and
gamma 0.75, with a 0.3-pixel phone filter and the normal 1.5-pixel room
filter. The half-resolution gate passes without altering the tray or dice.


### Round 3 pass 1 small worktop dressing

- `smithy_benchwork`: a rounded oilstone, irregular leather offcut and square-shanked forged nails; `width`, `wood_tone`, `metal_finish`, `wear`, `seed`.
- `diner_place_setting`: dished ceramic saucer, formed metal teaspoon, folded cotton napkin and sealed unprinted sugar packets; `radius`, `napkin`, `packets`, `tone`, `metal_tone`, `wear`, `seed`.

All room calls to `rear_recess` are removed. The optional asset parameter remains available with its default of `None`; tables in the room builders use continuous straight far edges.
