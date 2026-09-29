# Dice look-dev: themed sets and their rolling environments (plan P3)

Status: look-dev **round 2** for operator review, 2026-09-29. Nothing here
is app code. Source of truth for the renders:
`dart3d/example/tool/dice_lookdev/` (Blender 5.2.2, Cycles). Renders:
`docs/design/dice-lookdev/`. Context: `docs/design/demo-program.md` §3
(upstream's roller) and §5 (our Dice Roller plan).

Eleven themes. Each is a **dice set plus the environment it is rolled in**:
an engraved rolling surface as a hero object, framing props, a lighting
mood and atmosphere. The two signature sets are Emberforged (fire) and
Frostbound (ice).

**Judge from `all-sets-topdown.jpg` first.** The app's camera looks
straight down, so every set now has a top-down in-app view as its primary
render, and every set has to pass a measured readability gate on that view
(§0.2).

| # | Set | Environment | Top-down (primary) | Hero | d4 close-up |
|---|---|---|---|---|---|
| 1 | **Emberforged** | The Forge Hearth | [topdown](dice-lookdev/emberforged-topdown.jpg) | [hero](dice-lookdev/emberforged-hero.jpg) | [d4](dice-lookdev/emberforged-d4.jpg) |
| 2 | **Frostbound** | The Frozen Altar | [topdown](dice-lookdev/frostbound-topdown.jpg) | [hero](dice-lookdev/frostbound-hero.jpg) | [d4](dice-lookdev/frostbound-d4.jpg) |
| 3 | **Arcane Study** | The Night Study | [topdown](dice-lookdev/arcane-topdown.jpg) | [hero](dice-lookdev/arcane-hero.jpg) | [d4](dice-lookdev/arcane-d4.jpg) |
| 4 | **Fate Engine** | The Fate Engine | [topdown](dice-lookdev/fateengine-topdown.jpg) | [hero](dice-lookdev/fateengine-hero.jpg) | [d4](dice-lookdev/fateengine-d4.jpg) |
| 5 | Celestial Observatory | The Star Balcony | [topdown](dice-lookdev/celestial-topdown.jpg) | [hero](dice-lookdev/celestial-hero.jpg) | [d4](dice-lookdev/celestial-d4.jpg) |
| 6 | Hearthside Tome | Fireside Reading | [topdown](dice-lookdev/hearthside-topdown.jpg) | [hero](dice-lookdev/hearthside-hero.jpg) | [d4](dice-lookdev/hearthside-d4.jpg) |
| 7 | Old Road | The Wayfarer's Table | [topdown](dice-lookdev/oldroad-topdown.jpg) | [hero](dice-lookdev/oldroad-hero.jpg) | [d4](dice-lookdev/oldroad-d4.jpg) |
| 8 | Northfield Relay | Kitchen Table, 1986 | [topdown](dice-lookdev/northfield-topdown.jpg) | [hero](dice-lookdev/northfield-hero.jpg) | [d4](dice-lookdev/northfield-d4.jpg) |
| 9 | Voltline | Rain Counter | [topdown](dice-lookdev/voltline-topdown.jpg) | [hero](dice-lookdev/voltline-hero.jpg) | [d4](dice-lookdev/voltline-d4.jpg) |
| 10 | Vermilion Court | Lantern Pavilion | [topdown](dice-lookdev/vermilion-topdown.jpg) | [hero](dice-lookdev/vermilion-hero.jpg) | [d4](dice-lookdev/vermilion-d4.jpg) |
| 11 | Gemcutter | The Jeweler's Bench | [topdown](dice-lookdev/gemcutter-topdown.jpg) | [hero](dice-lookdev/gemcutter-hero.jpg) | [d4](dice-lookdev/gemcutter-d4.jpg) |

Sheets: `all-sets-topdown.jpg` (every set as the phone shows it),
`all-sets-hero.jpg` (heroes), `readability-crops.jpg` (the seven dice of
every set at phone pixels, 1:1). Per set: `<theme>-topdown.jpg`
(1179×2556, iPhone portrait, straight down with the app's fov),
`<theme>-hero.jpg` (1600×900, 3/4 view) and `<theme>-d4.jpg` (1000×625).
All renders are full-colour JPEG q90 (round 1's 128-colour palette PNGs
are gone). `readability.json` holds every measurement.

**IP guardrail.** Every name, symbol and pattern here is original. The
TTRPG lines and the operator's AI mood boards were inspiration only: no
game titles, logos, trademarked symbols or fonts, no copied slogans (props
carry no text at all; the engine's nameplate is blank, the newspaper and
notebook are abstract strokes). Runes and sigils are generated from
strokes by our own code (`_rune`, `sigil_strokes`) and are not a real
script. Fonts: Inter (OFL, bundled with Blender), DejaVu Sans Mono
(Bitstream Vera licence, bundled with Blender) and EB Garamond (OFL,
vendored in `tool/dice_lookdev/fonts/` with its licence).

---

## 0. Round 2

### 0.1 What changed (operator feedback → change)

| Feedback | Change |
|---|---|
| "Dice numbers must be super readable no matter what." | A readability system (§0.2) with a measured gate on the top-down view; every set passes. Numerals are 20–40% bigger relative to their face (and the dice 1.3× bigger), and every set has a chosen numeral treatment. |
| Vermilion Court too dark to read | Brighter vermilion lacquer; gold-leaf numerals (part diffuse) in a black-lacquer keyline; side key placed so its mirror image misses the tray; a soft overhead for the gold; matte-ish tray lacquer (round 1 mirrored the lanterns as white discs). A z-fight between the tray floor and its base (half the floor went black) is fixed, in every environment that had it. |
| "You can't see the arcane ones" | The tray bed is now a brushed-brass field with the sigil engraved dark; oak shows as a border. A warm candle key pools on the tray from the candle cluster; the gilt numerals glow softly. Far-side numerals no longer show through the body (transmission 0.25 → 0.04). |
| "Camera is still face down" | The primary render is the app's camera: straight down, fov 0.95 rad (`dice_table_scene.dart`), 1179×2556, rims at the screen edges, every die settled with a result up. Dice are 1.3× larger (in-app size: `dice_table_scene` uses ~23–33 mm dice in a 132 mm tray). |
| No tetrahedron d4 | The d4 is a long crystal **shard** that rests on a long face; the result is the big numeral on the top face (§0.3). Face map updated. |
| "Kitchen table doesn't look like a kitchen table" | Northfield is now a 1980s kitchen table seen from above: wood-grain laminate, a stoneware mug on a cork coaster, a plate with a toast crust and crumbs, the morning paper, a spiral notebook with a pencil, a pocket radio and salt shaker, plus the CRT keyboard, field instrument and coiled cable; the calibration mat is dark green. |
| Dice clipping into the tray (coordinator) | Every die is dropped onto whatever is under it (ray-cast per low vertex) and a contact report checks gap and interpenetration per die per shot (§0.4). |
| Fate Engine too green | Bright brushed-steel plate with a brass-inlaid gear pattern, sigils on the dice in brass, teal only in the numerals and the machine's core/tubes (dimmed). |
| Emberforged molten channel pale | A deep-orange melt with dark crust rafts whose edges burn yellow. |
| Celestial dice grey-violet | Saturated indigo → violet → magenta nebula with cyan wisps and more glow. |
| Gemcutter banding | Domain-warped noise swirl (deep emerald, jade ribbons, thin pearl wisps) replaces the regular wave bands. |
| Posterized renders | Full-colour JPEG q90, pixel-for-pixel the measured render (only JPEG compression in between); ~10 MB for everything. |

Every set and every tray from round 1 is kept. Low props were added to the
strips above and below each tray so the environment reads at top-down (tall
props leave the frame under perspective, so the strips carry coins,
papers, a fan, loose gears, a phone, a compass...).

### 0.2 The readability system

**Rules (every set):**

1. **Numeral contrast** on the top face, as rendered (display sRGB after
   tone mapping, not albedo): WCAG relative luminance, numeral vs the face
   immediately around it, **≥ 4.5 : 1** on every die.
2. **Numeral size**: the top-face numeral's height is **≥ 40% of the
   face's inscribed width** (worst face of each die, measured from the
   atlas). All dice are also 1.3× the round-1 size, so a d20 numeral is
   ~26 px tall on a 1179 px wide phone render and the d6's ~56 px.
3. **A numeral treatment chosen per theme** (table below): glowing
   (emissive numerals, usually inside a dark keyline), inked/filled, bright
   metal or enamel with a dark keyline. The keyline is a second texture in
   the atlas layout (`<theme>_halo.png`: R = numeral dilated by ~0.2 face
   inradius, G = soft glow), so it is exact per glyph.
4. **Die vs tray**: the die's silhouette must separate from the tray around
   it by **≥ 2 : 1**, taking the best of three readings: the die's median
   body tone, its mean (which counts glowing numerals and metal edges),
   and its outline (the die's outer 2 px, for rim-lit or neon-edged dice;
   only Voltline needs it). This drove a lighter or darker field under
   most sets (Arcane brass field, Frostbound slate, Gemcutter light grey
   velvet, Fate Engine bright steel, Voltline lightbox, Hearthside
   tea-stained vellum, Old Road dark map, Northfield dark-green mat).
5. **Top-down lighting rules** (the round-1 failures were mostly these):
   - Never put a small, bright light near the camera axis: its reflection
     lands on the top faces as a hotspot over the numeral.
   - Place side keys so their mirror image in a glossy floor lands
     *off* the tray (for a camera at height h and a light at (x, z), the
     reflection sits at x·h/(z+h)).
   - Straight down, a metal numeral or frame mirrors the ceiling. Every
     metal-numeral set gets a big, soft overhead source (`E.overhead`);
     in real time that is the zenith of the IBL.
   - Glass dice print their numerals on the outside only (back-facing
     glyphs are masked), or the far face reads mirrored through the body.

**The check** (`tool/dice_lookdev/readability_check.py`) runs on every
top-down render (`render_set.py --check`, always on in `render.sh`):

- The beauty frame is kept as a lossless PNG. A second, exact **mask
  pass** re-renders the same camera with each die's material swapped for
  an emission-only mask (R = numeral from the atlas, G = "top face": true
  normal within 14° of up, B = die id), everything else hidden, 1 sample,
  no pixel filter, EXR.
- Per die: numeral luminance = median over the numeral (eroded 1 px);
  surround = median over the top face in a ring 1…1+r px around the
  numeral (r = 8% of the numeral's pixel height). Also a "plain body"
  ratio over the rest of the face (where the keyline doesn't reach) for
  reference, and die vs a 3–12 px ring of tray (other dice excluded,
  contact shadow included).
- Results merge into `readability.json`; `readability_check.py --table`
  prints the table below. `readability-crops.jpg` shows exactly the
  pixels that were measured.

Quick loop while iterating a set (≈1 min):

```
Blender --background --python dart3d/example/tool/dice_lookdev/readability_check.py -- \
    --theme arcane --samples 16 --pct 50 --out /tmp/rd
```

**Results** (full renders, 96 samples, 1179×2556):

| Set | Numeral treatment | Numeral contrast, worst die (gate 4.5) | vs plain body | Die vs tray, worst (gate 2.0) | Top numeral height | Numeral / face width (gate 0.40) | Result |
|---|---|---|---|---|---|---|---|
| Emberforged | glowing: white-hot emissive numerals in a soot keyline | 15.8:1 (d4) | 3.7:1 | 2.7:1 | 26 px | 0.41 | PASS |
| Frostbound | glowing: emissive rime numerals on a deep-blue keyline | 14.6:1 (d8) | 3.1:1 | 2.4:1 | 25 px | 0.41 | PASS |
| Arcane Study | glowing: warm spell-lit gilt numerals, midnight keyline | 9.2:1 (d4) | 6.0:1 | 2.1:1 | 26 px | 0.42 | PASS |
| Fate Engine | glowing: aqua-charged numerals in a dark keyline | 16.6:1 (d8) | 14.2:1 | 2.2:1 | 26 px | 0.42 | PASS |
| Celestial Observatory | glowing: starlight-silver numerals in an indigo keyline | 18.7:1 (d10u) | 9.8:1 | 2.7:1 | 26 px | 0.41 | PASS |
| Hearthside Tome | inked: engraved, filled with sepia-black ink | 5.1:1 (d10t) | 5.4:1 | 2.1:1 | 23 px | 0.43 | PASS |
| Old Road | enamel fill: black niello in bright worn gold | 6.2:1 (d10t) | 5.9:1 | 2.1:1 | 28 px | 0.46 | PASS |
| Northfield Relay | inked: near-black instrument print on warm-white ABS | 8.1:1 (d4) | 7.9:1 | 4.6:1 | 22 px | 0.41 | PASS |
| Voltline | glowing: magenta neon numerals in a black keyline | 14.3:1 (d4) | 14.3:1 | 4.6:1 | 29 px | 0.41 | PASS |
| Vermilion Court | bright metal + keyline: gold leaf in a black-lacquer keyline | 5.4:1 (d10u) | 2.0:1 | 2.1:1 | 27 px | 0.44 | PASS |
| Gemcutter | bright enamel + keyline: warm-gold enamel in a deep-green keyline | 8.2:1 (d4) | 3.8:1 | 2.1:1 | 24 px | 0.41 | PASS |

"vs plain body" is the numeral against the face beyond the keyline; it
shows which sets lean on the keyline (Vermilion, Frostbound, Celestial) and
which read on the body alone.

### 0.3 The d4 shard

- A square prism along the die's long axis with pyramid caps: section
  1.3 cm, 3.2 cm tip to tip (`SHARD_HALF`, `SHARD_CAP` in `build_dice.py`),
  316 triangles. It rests on one of its four long faces, so the result is
  the face pointing up, read like every other die.
- Numbering: opposite long faces sum to 5 (4 up ↔ 1 down, 2 ↔ 3), asserted
  at build time. One numeral per long face, reading along the crystal,
  ~0.5 of the face width tall (the biggest numeral in the set). The eight
  cap facets are blank (their own atlas cells; 78 of 81 cells used).
- **Face map** (`dice_faces.lookdev.json`): the d4 lists only its four long
  faces with `"shape": "shard"` and no `readout` override: the existing
  "most aligned with up" readout works. The shard cannot come to rest on a
  cap facet: the centre of mass projects outside every cap triangle (a cap
  plane sits 0.78 × section from the centre, a long face 0.5), so it
  topples onto a long face and ignoring the caps is safe.
- Physics: use the convex hull (10 points) as the collider. It rolls along
  its long axis much more readily than end over end, so a throw needs a
  little extra spin about the long axis to look lively (DR2 tuning).

### 0.4 Placement and contacts

`env_common.place_layout()` orients each die (value up, numeral facing the
viewer) and `settle()` drops it straight down: for every vertex in the
die's lower third it ray-casts the surface below and lifts the die until
none is below it, plus a 0.004 cm gap. This handles bowed pages, rim lips
and trays at any height. `contact_report()` then records, per die and per
shot, the gap at the contact point and any interpenetration (BVH overlap)
with other dice or with environment meshes near the die; render_set prints
`CONTACT PROBLEMS` if any die has a gap outside 0…0.01 cm or overlaps
anything. The final renders have none (all gaps 0.004 cm, no overlaps).
There are no mid-roll shots in round 2.

---

## 1. How it is built

```
dart3d/example/tool/dice_lookdev/
  build_dice.py        geometry, numbering, glyph atlas, all dice materials, face map, glb export
  env_common.py        scene/render helpers, tray + rim builder, scatter, camera, settle + contact
                       report, overhead light, JPEG writer
  env_props.py         procedural props (candles, tomes, armillary, hourglass, gears, ...) + mask renderer
  build_env_<theme>.py one environment per theme (11)
  render_set.py        builds dice + environment, renders topdown / hero / d4 (+ --check)
  readability_check.py the readability gate (mask pass + measurements, --table)
  contact_sheet.py     all-sets-topdown.jpg, all-sets-hero.jpg, readability-crops.jpg
  render.sh            everything (./render.sh [themes...]; PCT/SAMPLES/SHOTS env for previews)
  fonts/               EB Garamond + OFL
  dice_faces.lookdev.json  face map for this geometry
```

Everything is procedural (no downloaded assets), so a render is a pure
function of the scripts and Blender 5.2.

Render settings: Cycles on Metal, 96 samples (`SAMPLES=96`; each
environment's default is 128–160) with OpenImageDenoise, **Khronos PBR
Neutral** view transform. AgX bleached the fire to white; PBR Neutral keeps
emissive hues and is also a tone mapper the real-time path can match.
Output: full-colour JPEG q90 (`env_common.save_jpeg`); the lossless PNG is
kept only in the temp dir for the readability check. About 1.5 h for all
eleven sets on an M4. Do not run two renders at once: Cycles runs out of
GPU memory.

Scale: 1 Blender unit = 1 cm. Dice are a standard set × `SIZE_SCALE` 1.3
(d20 ≈ 2.9 cm across), the in-app size; the tray's play area stays
15 × 31 cm.

### 1.1 Dice geometry and numbering (shared by every set)

| Die | Shape | Size | Bevel | Tris | Numbering (asserted at build time) |
|---|---|---|---|---|---|
| d4 | **shard**: square prism + pyramid caps, rests on a long face, read from the top face (§0.3) | 1.3 cm section, 3.2 cm long | 0.09, 3 segs | 316 | 1–4, opposite long faces sum to 5 |
| d6 | cube | 2.1 cm | 0.17, 4 segs | 300 | opposite faces sum to 7; 1-2-3 counter-clockwise |
| d8 | octahedron | 2.7 cm tip-to-tip | 0.09, 3 segs | 188 | sum 9 |
| d10 units | pentagonal trapezohedron (planar kites, exact) | 2.9 cm tall | 0.08, 3 segs | 316 | 0–9, sum 9, odd numbers around one pole |
| d10 tens (d%) | same | same | same | 316 | 00–90, sum 90 |
| d12 | dodecahedron | 2.9 cm | 0.09, 3 segs | 476 | sum 13 |
| d20 | icosahedron | 2.9 cm | 0.07, 3 segs | 476 | sum 21 |

- 6 and 9 carry a dot ("6." / "9.") on the d10, d12 and d20.
- All dice are modelled resting on a face (face up = +Z), so they sit flat
  in the tray.
- Every die is **< 500 triangles**, well under the 2–4k budget. That leaves
  room for more bevel segments on a "high" quality tier. The inner "core"
  hulls of the two glowing sets are 4–36 triangles.
- **Face map.** `dice_faces.lookdev.json` has the same schema as
  `assets/dice/dice_faces.json`: glTF Y-up normals, `"resultSide": "up"`.
  The d4 lists its four long faces (`"shape": "shard"`), like the existing
  Retro Classic and overlay crystal d4s; the "most aligned with up"
  readout works unchanged for every die.

### 1.2 One RGBA atlas per set

Every face is planar-projected into one cell of a 9×9 atlas (78 of 81 cells
used), so **all seven dice of a set share one texture**. The bevel strips
project into a band just inside each face outline. The atlas is rendered
with Workbench from real text and stroke curves:

| Channel | Content | Real-time use |
|---|---|---|
| R | numerals | numeral colour / emissive mask |
| G | theme decor (runes, frost dendrites, circuit pads, calibration ticks, stars, sigil rings, lacquer borders) | decor colour / emissive mask |
| B | engrave height (R∪G, blurred) | bake into a tangent-space **normal map** |
| A | **metal-edge frame**: bevel strip + a lip onto the face | metallic/roughness mask for the gold/brass/silver-framed sets |
| halo R | **keyline**: the numeral dilated by ~0.2 face inradius (round 2) | bake into baseColor (dark ring) and zero the emissive there |
| halo G | soft outer glow (numeral blurred) | optional emissive halo; unused in the stills (it lowers contrast) |

Look-dev renders use 4096²; 2048² is enough in real time. glTF wants
separate slots, so the shipping form per set is **baseColor(+alpha) +
metallicRoughness + normal + emissive**, all 2048² in the same UV layout.
Numeral placement is per die type and the font changes only per theme, so
sets that share a font can also share the normal map. Compress as KTX2:
UASTC for the normal map, ETC1S for colour (dart3d already loads KTX2).

Export: `build_dice.py --theme X --export-glb dir` writes one .glb per die
(geometry, UVs, and a placeholder material that embeds the 4096² look-dev
atlas, ~7 MB each; for production, share one 2048² KTX2 set across the
seven dice). The .fsceneb conversion follows the `dn_logo/build.sh`
recipe.

---

## 2. What makes upstream's roller feel premium, and how we beat it

From demo-program §3. Upstream's "Dice Shadows" feels expensive because of:

1. **Physics tuned for drama**: gravity −30 (3 g) with lively restitution
   (0.35/0.45), spin tied to the throw direction, and dice that fly in
   along *your* aim arrow.
2. **Every event fires on several channels at once**: outline, particles,
   light flash, camera shake, sound. Impacts are classified
   (clack/wall/surface) with a log volume curve and pitch scaled by force
   and material.
3. **Suspense on a clock**: accelerating count-up ticks
   (`0.26·0.92ⁱ`), a held multiplier reveal, a wind-up slam into the
   TOTAL sticker, and 0.18× slow-mo while a match is forming.
4. **Escalation**: bigger outcomes pay out bigger (fireworks, golden hour,
   hop, shattering cards).
5. **A physical world**: dice shadows on the UI, cards that press and
   crack, skid marks, trails only while flying.
6. **Material variety**: ten finishes (glass, opal, neon, steel, ...)
   over one lighting preset (sun el 46.8°, bloom, tilt-shift DOF).

What it lacks, and where these sets go further:

- **Only d6s on a flat UI.** We have a full polyhedral set (d4–d20 + d%)
  with engraved, readable numerals, in **eleven designed places** rather
  than one screen. Each place has an engraved hero surface, props that frame
  the phone's edges, and a light mood.
- **Finishes are surface-only.** Ours have **interiors**: a live coal
  inside smoked amber, fractured glacial ice with a cold heart, star glitter
  under gold frames, nebula resin. That depth is the "wow" in a close-up.
- **The surface reacts.** The engraved rolling surfaces (forge sigil, ward
  circle, brass sigil, engine plate, astrolabe) are emissive masks, so the
  scene can answer a result: the sigil ring under the landing die lights
  up, the molten channel surges, the engine's tubes flare.
- **Themed juice** on top of upstream's channel stack (flash + shake +
  particles + sound):
  - Emberforged: impact flares and an **ember burst on land**; sparks
    shed while tumbling; a nat 20 makes the molten channel surge round
    the tray.
  - Frostbound: a **frost puff** (a cold-mist ring plus ice glitter) on
    land; rime creeps across the altar ward on a crit.
  - Arcane Study: sigil runes ignite along the ring toward the result;
    the runestones in the bowl pulse.
  - Fate Engine: the charge tubes surge and the core flashes; the gears
    turn as the dice count up.
  - The others follow the same pattern: star streaks, falling petals,
    neon flicker, candle gutter, lamp flicker.
- **Escalation keyed to TTRPG moments**: nat 20 / nat 1 / doubles and
  d% "00" instead of upstream's match multiplier (demo-program §5.5 DR4).

---

## 3. The sets

Real-time notes use the capability table in demo-program §3.5. In short:

- **Now on both platforms**: base PBR, emissive + bloom, clearcoat
  (iOS OK), normal maps, material upserts (animate at ≤ 10 Hz), W18
  particles (iOS ignores bursts and turbulence), trails, one shadowed
  directional light with cascades on Android, extra unshadowed point
  lights, DOF.
- **Transmission/refraction**: Android approximated; iOS is alpha-blend
  (IOR, volume and dispersion dropped).
- **Waiting on units**: animated noise/flow shaders, true refraction,
  view-dependent glitter and parallax interiors wait for **E6** (shader
  contract). Instanced props and particles wait for **E1**. Sky/IBL
  generation waits for **E3**. Sprites and flipbooks wait for **E5b**.
  Animating material properties without an upsert per frame waits for
  **E5c**. Spot shadows wait for **E5**.

**Environment budget (all sets, mobile):**

- The tray is one mesh, ≤ 2k tris: floor plus rim. The engraved floor is
  one 2048² set (normal, roughness and emissive mask); the Workbench masks
  in the scripts are exactly those maps.
- Props are merged into **one baked prop mesh per environment**: ≤ 25k
  tris, one 2048² atlas with baked lighting/AO, and emissive where glowing.
- Hero props sit near the wall and stay real geometry, so they cast real
  shadows onto the tray: candles, a brazier, crystal clusters, the engine
  front.
- Far props become **baked low-poly silhouettes or cards**: walls,
  windows, the balustrade, the cave ice, the sky.
- Lights: one shadowed key plus ≤ 3 unshadowed point lights (candles,
  brazier, tubes). Everything else is baked.
- Atmosphere is particles and cards. Volumetric haze is not available in
  real time (and was too slow even for these stills), so fake it with
  camera-facing gradient cards and fog, if dart3d exposes fog (verify).

**Readability (all sets):** see §0.2. The play area is lower in detail
than the dice and separated from them in luminance (lighter *or* darker,
per set). The **long walls sit on the screen edges** in the top-down view
(frame width = tray + rims + ~1 cm), so a d20 is ~14% of the screen width.
Low props frame the top and bottom edges.

### 3.1 Emberforged: "a banked fire you can hold"

![top-down, in-app](dice-lookdev/emberforged-topdown.jpg)

![hero](dice-lookdev/emberforged-hero.jpg)

**Round 2.** Treatment: *glowing* — white-hot numerals (emissive 9, pale
gold) inside a soot keyline, so the fire behind the glass never touches
the digit. Less smoke in the glass (absorption 1.6 → 1.1) and a slightly
bigger core, so the dice glow amber rather than smoulder. The molten
channel is a deep-orange melt with dark crust rafts whose edges burn
yellow (round 1 read pale salmon). The forge floor stays dark: the dice's
own glow separates them.

**Dice**:

- The shell is smoked amber glass: transmission 1, IOR 1.52, roughness
  0.02–0.14 from grime noise, a thin coat, and volume absorption with
  dark smoky amber at density 1.6.
- Inside is a smaller **core hull** (66% scale) with an emission-only
  volume. The flame comes from 4D noise over a domain-warped position,
  raised to the power 3 and faded radially: black → deep red → orange →
  pale gold.
- Sparse voronoi **ember flecks** burn at ~90.
- Numerals are engraved (height bump) and glow hot orange (emission 3.5).

**Environment: The Forge Hearth.**

- A cast-iron tray on a basalt forge slab. The floor is hammered, forged
  iron with an engraved five-point forge sigil whose grooves hold a faint,
  flickering ember glow.
- A **molten channel** rings the play area just inside the wall. It is
  crusted, with glowing cracks.
- The hammered iron rim has rivets.
- Two coal braziers with flames and rising sparks stand behind the wall,
  with a brick forge wall behind them. An anvil, ingots and tongs sit
  beside the tray, and embers drift in the air.
- Lighting: warm key, a cold blue rim for separation, the brazier point
  lights.

**Real time:**

- Shell: Android uses Filament transmission (solid refraction mode, thick
  absorption tint). iOS is alpha-blended smoky tint plus a fresnel-ish
  rim from clearcoat.
- Core: an inner mesh with an emissive flame texture, visible through the
  shell. Bloom does the rest.
- **Now:** "breathing" fire via emissive intensity and colour upserts at
  ≤ 10 Hz (a slow 0.6 Hz pulse plus a flicker). Numerals are an emissive
  mask.
- **Needs E6:** flowing noise inside the core (time-animated 3D noise) and
  refraction of the core that moves with the view.
- **Interim for E6:** two core shells (inner hot, outer cooler) with
  counter-rotating emissive textures, spun by the scene on a transform
  (cheap), which reads as moving fire.
- Environment: the molten channel and the sigil are emissive masks with
  an upserted intensity (surge on nat 20). Sparks and embers are W18
  particles (Android CPU sim; iOS one-shot emitters). Brazier flames are
  flipbook cards (E5b) or crossed emissive cards with an upsert flicker.
  The brazier is one real point light, unshadowed. Coals are baked
  emissive.
- **Juice**: impact flare (short point-light pop plus a spark burst at the
  contact), **ember burst on land**, sparks shed while tumbling (trail +
  particles), channel surge on crit.

### 3.2 Frostbound: "glacial ice with a cold heart"

![top-down, in-app](dice-lookdev/frostbound-topdown.jpg)

![hero](dice-lookdev/frostbound-hero.jpg)

**Round 2.** Treatment: *glowing* — rime numerals with a cold emissive
(5) on a deep-blue keyline, like ink frozen under the frost. The altar's
play field is now blue-black slate (round 1's pale frosted granite was the
same luminance as the ice). No snow falls between the camera and the tray;
low ice shards sit in the strips.

**Dice**:

- The shell is clear ice: transmission, IOR 1.31, roughness 0.015–0.46
  varied by frost-patch noise, micro-bump, and faint blue absorption.
- The core hull is a Principled volume with **fracture sheets**: thin
  voronoi distance-to-edge planes at two scales, plus cloudy inclusions,
  with a cold blue emission that is strongest at the heart.
- Numerals are **rime-frosted**: rough white with subsurface and a faint
  blue glow.
- G-channel frost dendrites creep in from each corner. Voronoi glints give
  a subtle sparkle.

**Environment: The Frozen Altar.**

- A frost-rimed granite altar with snow-capped walls (the snow is a
  material on up-facing normals).
- The floor has an engraved six-point ward circle whose grooves hold faint
  cold light.
- Hexagonal ice-crystal clusters stand on the altar ledge at the corners.
  Snow-capped boulders sit around it, and a glowing ice-cave wall stands
  far behind.
- Falling snow and cold ground mist around the altar base.
- Lighting: cool moon key, a blue cave glow, and a whisper of warm bounce
  so it isn't monochrome.

**Real time:**

- Shell: Android transmission; iOS alpha-blend with high clearcoat.
- **Fractures now**: the core mesh gets a few **internal crossed quads**
  with an alpha/emissive crack texture (baked from the voronoi sheets).
  It reads as internal fractures from every angle and costs about 20 tris.
- The cold heart is an emissive core with a slow upserted pulse.
- Sparkle: an emissive speckle mask plus W18 glitter particles on land.
- **Needs E6**: view-dependent glints and parallax depth in the ice.
- Environment:
  - Crystals are real geometry near the walls (few tris, transmission or
    alpha), with an unshadowed blue point light.
  - Boulders and the cave wall are baked.
  - Snow is W18 particles (low rate, large and soft near the camera).
  - Mist is 2–3 alpha gradient cards at the altar base (no volumes).
- **Juice**: **frost puff** on land (mist-card ring plus ice glitter),
  rime creeping across the ward circle on a crit (emissive mask upsert),
  a crystal chime.

### 3.3 Arcane Study: "gold-framed midnight"

![top-down, in-app](dice-lookdev/arcane-topdown.jpg)

![hero](dice-lookdev/arcane-hero.jpg)

**Round 2.** Treatment: *glowing* — gilt numerals with a soft warm
emissive (spell-lit), a midnight keyline, gold frames. The dice body is a
little lighter blue and no longer shows its far-side numerals through the
body. The tray bed is a brushed-brass field with the sigil engraved dark
(the operator's "lighter brass circle field"), bordered by oak; a warm
candle key pools on it from the candle cluster; a big soft overhead gives
the gilt something to mirror. Strips: a map, coins, a sealed letter, a
quill, velvet, a bowl of glowing runestones.

**Dice**:

- The body is deep midnight blue with a swirl, clearcoat and a little
  transmission.
- **Star-glitter inlay**: voronoi flakes with a random tint, metallic,
  with a per-flake bump so they wink.
- Raised **gold frames** come from the atlas alpha (bevel + lip). The
  numerals are gold, and so are small four-point star marks at the
  corners.
- The body is closest to operator reference 1.

**Environment: The Night Study.**

- A dark oak board **inlaid with an engraved brass sigil circle**. The
  circle is seven-pointed, with a rune band, 120 ticks and a compass rose;
  it is the hero object. A brass-capped oak rim with corner bosses frames
  the board.
- Around it:
  - three candles on brass dishes, with drips
  - stacked leather tomes with gilt bands (no titles)
  - a brass armillary
  - a bowl of glowing blue runestones
  - star-stitched velvet, coins, inked maps, an inkwell and quill, and
    an hourglass
- A moonlit window behind; dust motes in the air.
- Warm candlelight versus a cool magical blue.

**Real time:**

- Everything on the dice is standard PBR from the atlas: gold frame via
  metal mask, glitter via a high-frequency normal map plus a
  metal/roughness speckle map, clearcoat.
- **Now:** moving lights and the tumble make the flakes wink.
- **Needs E6:** true view-dependent glitter.
- Environment:
  - The board is one mesh: the brass inlay is a metallic mask plus a
    normal map from the sigil mask, plus a faint emissive mask for
    "ignite" effects.
  - Candles: wax meshes baked into the prop atlas, flames as small
    flipbook sprites (E5b) or emissive teardrop cards with flicker
    upserts, and one or two unshadowed warm point lights.
  - Tomes, armillary, coins and maps are baked low-poly.
  - Runestones are emissive, and dust motes are W18 particles.
- **Juice**: the rune band ignites around the ring toward the landing
  die; the runestones pulse with the total.

### 3.4 Fate Engine: "the machine is the environment"

![top-down, in-app](dice-lookdev/fateengine-topdown.jpg)

![hero](dice-lookdev/fateengine-hero.jpg)

**Round 2.** Treatment: *glowing* — aqua-charged numerals in a dark
keyline; everything else on the dice is gunmetal and brass (the sigil
marks are brass now). The output plate is bright brushed steel with the
gear-and-orbit pattern inlaid in brass; the teal survives only as a
whisper in the grooves, the machine's core and tubes (all dimmed), so the
set reads brass-first. Strips: loose gears, screws and a schematic.

**Dice**:

- Machined gunmetal: brushed anisotropic streaks via bump; iOS drops
  anisotropy.
- Brass frames come from the atlas alpha.
- Numerals and **sigil marks** (inset ring, corner pads) are emissive
  teal.

**Environment: The Fate Engine.**

- A brass dice engine stands at the head of the tray:
  - a plinth, deck and crown
  - twin **glass charge tubes** filled with teal light
  - a gyroscopic cradle around a glowing core
  - gear trains, a pull lever and a blank nameplate
- The rolling area is its output tray: a dark steel plate engraved with a
  **gear-and-orbit pattern** whose grooves carry a faint teal charge,
  walled by a riveted brass rail.
- Workshop props: a teal-sand hourglass, tomes, a candle, calipers, maps
  and an armillary.

**Real time:**

- Dice and plate: emissive masks plus bloom.
- The engine is a baked prop mesh except for the tubes, which are
  emissive cylinders with **scrolling UVs**. The scroll needs E5c/E6;
  interim is an emissive intensity pulse via upsert, plus W18 bubbles.
- Gears rotate with plain node transforms: cheap, and they look alive.
- The core is an emissive sphere with an unshadowed teal point light.
- **Juice**:
  - Pulling the lever (or the throw gesture) drives the whole machine:
    gears spin up, the tubes surge, and the core flashes on a crit.
  - The dice drop from the chute, so the throw origin is fixed and
    diegetic.

### 3.5 Celestial Observatory: "a night sky caught in resin"

![top-down, in-app](dice-lookdev/celestial-topdown.jpg)

![hero](dice-lookdev/celestial-hero.jpg)

**Round 2.** Treatment: *glowing* — starlight-silver numerals in an
indigo keyline. The nebula is saturated indigo → violet → magenta with
cyan wisps and stronger glow (round 1 read grey-violet). Strips: a star
chart, a silver compass, loose amethyst.

**Dice**:

- Violet nebula resin: domain-warped noise with a violet ramp, faint
  emission in the brightest wisps, and pin-point star flakes.
- Silver edges come from the atlas alpha. Star marks are in G.

**Environment: The Star Balcony.**

- A veined marble table on a night balcony.
- The rolling field is dark lapis with gold flecks, inlaid with a silver
  **astrolabe**: an eight-phase moon ring, a 180-tick scale, an invented
  star chart and a rete ring.
- Amethyst clusters, a silver armillary, a star globe and a brass lantern
  sit around it.
- A marble balustrade stands in front of a violet star-dusted sky.

**Real time:**

- Bake the nebula into the dice atlas (baseColor + emissive): the 3D
  noise is baked per face cell.
- The star speckle is an emissive map.
- The sky is a low-res equirect or a sky card (E3 for a generated one).
- **Juice**: star streaks (trails) while dice fly; the astrolabe rete
  rotates to point at the result.

### 3.6 Hearthside Tome: "old bone, firelit"

![top-down, in-app](dice-lookdev/hearthside-topdown.jpg)

![hero](dice-lookdev/hearthside-hero.jpg)

**Round 2.** Treatment: *inked* — engraved and filled with sepia-black
ink. The pages are tea-stained vellum a few steps darker than the bone,
and a side reading key (plus +0.7 exposure) keeps the bone bright, so the
dice separate. The top-down layout keeps dice off the gutter's slope
(the physics floor will be flat). The mug and the velvet pouch sit at the
top corners of the phone frame, wax seals at the bottom.

**Dice**:

- Bone and ivory: a grain along one axis, AO-darkened wear in the
  crevices, subsurface, a light coat.
- Sepia-inked engraved numerals.

**Environment: Fireside Reading.**

- The rolling surface is a **huge open tome**, spine across the screen
  (portrait-friendly). Its pages are bowed to the gutter, with ruled text
  blocks (abstract dashes, no words), an ink-wash plate and a ribbon
  marker.
- A hearth glows behind.
- Around the tome: a stoneware mug, a velvet dice pouch, wax seals,
  dried lavender and a candle.

**Real time:**

- The pages are one curved mesh with a single 2048² page texture.
- The tome's gutter dip must be reflected in the physics floor. Either
  use a flat collider (dice never reach the gutter), or accept a small
  lip.
- Fire glow is an emissive card plus a flickering warm light upsert.
- **Juice**: pages flutter (vertex animation or a card) on a crit.

### 3.7 Old Road: "wayfarer's gold"

![top-down, in-app](dice-lookdev/oldroad-topdown.jpg)

![hero](dice-lookdev/oldroad-hero.jpg)

**Round 2.** Treatment: *enamel fill* — numerals cut deep and filled
with black niello in bright worn gold. The gold needed a strong soft
overhead to read straight down (a top-down metal face mirrors the ceiling)
and a side key, and a warm dim room instead of black (most faces of a die
seen straight down mirror the room, not the ceiling); the map is now dark
tobacco vellum so the gold dice stand out. Strips: the clay pipe, coins and a sheathed knife.

**Dice**:

- Worn gold with AO-darkened recesses, noise wear and stretched-noise
  scratches.
- Numerals (EB Garamond) and flowing original **runes** are cut and
  filled with black niello.

**Environment: The Wayfarer's Table.**

- A weathered inn table.
- The rolling surface is a hand-inked **map of an invented land**,
  stretched inside a stitched-leather rim.
- A tin lantern, a clay pipe, a satchel and strap with a buckle, coins,
  bread and a wooden mug.
- A blue-hour window versus warm lantern light.

**Real time:**

- Standard PBR. The niello fill is the baseColor from the atlas.
- The lantern is an emissive glass plus one warm point light.
- **Juice**: the lantern flame gutters on a hard landing; dust puffs off
  the map.

### 3.8 Northfield Relay: "1986 lab hardware" (loop-era, original)

![top-down, in-app](dice-lookdev/northfield-topdown.jpg)

![hero](dice-lookdev/northfield-hero.jpg)

**Round 2.** Treatment: *inked* — near-black instrument print on the
warm-white ABS (round 1's orange print was 1.9 : 1); orange survives in
the calibration ticks. The environment is an actual 1986 kitchen table
seen from above: wood-grain laminate with an aluminium edge band, the CRT
terminal's keyboard at the head of the table, a stoneware mug of coffee on
a cork coaster, a plate with a toast crust and crumbs, the morning paper
(abstract columns and a photo block), a spiral notebook with pencilled
tallies and a yellow pencil, a pocket radio and a salt shaker, the teal
field instrument and a coiled cable. The pendant lamp now hangs behind the
top-down camera (round 1's shade blocked the view). The calibration mat is
dark green, so the white dice separate.

**Dice**:

- Warm-white ABS with slight subsurface and a fine texture.
- Numerals are orange instrument print (DejaVu Sans Mono), with teal
  calibration ticks and an index notch.

**Environment: Kitchen Table, 1986.**

- A 1980s farmhouse kitchen table: wood-grain laminate with an aluminium
  edge band, under a warm pendant lamp (round 2; see the note above).
- The tray is a beige instrument case lined with a dark-green rubber mat
  printed with a 1 cm / 5 cm calibration grid.
- A chunky CRT terminal glows green (scanlines, blocky text) at the head of
  the table, its keyboard in front; an odd teal field instrument with
  dials, toggles and LEDs.
- Breakfast things and paperwork: mug, plate and crumbs, newspaper,
  notebook and pencil, pocket radio, salt shaker; a coiled cable; a
  grey-blue dusk window.

**Real time:**

- All standard. The CRT screen is an emissive texture with a scanline
  scroll: interim is an upsert, with E6 or E10 (external texture) for live
  "terminal text" showing the roll log.
- **Juice**: the CRT prints the roll result; the instrument needle swings
  with the total.

### 3.9 Voltline: "black mirror chrome, neon-lit"

![top-down, in-app](dice-lookdev/voltline-topdown.jpg)

![hero](dice-lookdev/voltline-hero.jpg)

**Round 2.** Treatment: *glowing* — magenta neon numerals in a black
keyline, and a thin cyan neon line along every edge (the atlas's bevel
mask), so each black die keeps a lit outline. The holo tray is a lightbox
under smoked glass (a soft indigo glow everywhere); the chrome is darker
with less clearcoat so the slanted faces don't mirror the glow back.
Strips: a phone with a lit screen, a receipt, a straw.

**Dice**:

- Black chrome with a heavy clearcoat.
- Magenta emissive numerals and cyan **circuit-trace rims** (bevel border
  plus corner traces and pads in G).

**Environment: Rain Counter.**

- A late-night diner counter, wet with puddles (a roughness mask plus a
  clearcoat mask).
- The rolling area is a **holo tray**: smoked black glass with a faint
  pulsing triangular grid of light, a cyan neon rim tube and a magenta
  inner line.
- Rain-streaked window glass, with abstract neon signage outside (shapes,
  no words) and rain particles.
- A chrome napkin box, a paper cup and a phone.

**Real time:**

- Emissive plus bloom is the whole look, and it is fully supported.
- Wet reflections: on Android, screen-space reflections if Filament's are
  exposed; otherwise a planar-reflection fake. On iOS, `SCNFloor`
  reflectivity (E8 note) or rely on the clearcoat plus IBL of the neon.
- **Juice**: grid ripples from the landing point (emissive mask upsert,
  or E6 for a real ripple); neon flicker on a crit.

### 3.10 Vermilion Court: "urushi and gold"

![top-down, in-app](dice-lookdev/vermilion-topdown.jpg)

![hero](dice-lookdev/vermilion-hero.jpg)

**Round 2.** Treatment: *bright metal + keyline* — gold-leaf numerals
(part diffuse, so they read straight down) inside a black-lacquer keyline;
the red alone was ~2.5 : 1 against gold. The lacquer is a brighter
vermilion. The tray's black lacquer is satin rather than mirror (round 1
mirrored the lanterns as white discs), the moon no longer shadows half the
tray through the folding screen, the key comes from the side so its mirror
image misses the tray, and a paper-ceiling overhead lights the gold.
Strips: a folding fan, a celadon cup on a saucer, fallen petals.

**Dice**:

- Deep urushi-red lacquer with depth variation, a glassy coat (IOR 1.55)
  and sparse gold flakes.
- Gold-leaf numerals (EB Garamond) and double gold inlay borders with
  corner dots.

**Environment: Lantern Pavilion.**

- A black-lacquer shrine tray with a gold-dust wave pattern and a gilt
  rim, set on tatami.
- Paper lanterns at the corners and a folding screen with gold-leaf
  panels and painted waves.
- A celadon tea cup, and drifting petals.
- Ties to the M18 diorama palette.

**Real time:**

- Standard PBR plus clearcoat.
- Lanterns are emissive paper plus unshadowed warm point lights.
- Petals are W18 particles; flat sprites are fine.
- **Juice**: a petal burst on land; a lantern sway on a hard hit.

### 3.11 Gemcutter: "classic swirled gems"

![top-down, in-app](dice-lookdev/gemcutter-topdown.jpg)

![hero](dice-lookdev/gemcutter-hero.jpg)

**Round 2.** Treatment: *bright enamel + keyline* — warm-gold enamel
numerals in a deep-green keyline. The swirl is a domain-warped noise
(deep emerald, jade ribbons, thin pearl wisps) instead of regular bands.
The tray velvet is a light jeweler's grey (round 1's teal matched the
emerald; at top-down under the daylight lamp it reads almost white, which
the operator may want a step darker — the gate allows down to ~0.3 grey). Strips: gem paper with loose stones, tweezers, the loupe.

**Dice**:

- Emerald-and-pearl swirl: distorted band noise, partial transmission,
  coat and subsurface.
- Gold-painted numerals.
- This is the classic polyhedral "gemstone" look, and the easiest to
  vary: swap the ramp for sapphire, ruby, amethyst or opal.

**Environment: The Jeweler's Bench.**

- A deep-teal velvet tray with a padded rim on a walnut bench, lit by a
  cool daylight bench lamp.
- A brass loupe, tweezers, glass-lidded gem cases with loose cut stones
  (an original brilliant-ish cut), gem papers and a brass balance.

**Real time:**

- Bake the swirl into baseColor. Android uses partial transmission; iOS
  uses alpha.
- Loose gems are low-poly glass with a high-contrast IBL.
- **Juice**: a loupe zoom on the result (camera dolly to the d20).

---

## 4. dart3d features to verify (before building these for real)

1. **Emissive intensity > 1 + bloom threshold** on both platforms, and
   emissive *texture* support. Check that SceneKit `emission` takes a
   texture and an intensity.
2. **Material upsert rate**: 10 Hz emissive and colour animation on 7
   dice plus the environment without hitches on the A142 (W22 lane).
3. **Transmission on Android** (Filament refraction mode and thickness)
   and the **iOS alpha fallback**. Check the look of a dark shell over an
   emissive core on iOS.
4. **Nested meshes per die** (shell + core, parented) under one rigid
   body. Check that the physics collider is only the outer hull.
5. **Internal alpha cards** (the frost fractures): sorting inside a
   transmissive shell on both backends.
6. **Clearcoat** (both) and anisotropy (Android only). Check that
   iOS's loss of anisotropy is acceptable for Fate Engine and steel.
7. **KTX2 UASTC normal maps** on both, and a 4-texture material per die
   set.
8. **Unshadowed point lights**: per-light shadow toggle and the light
   count budget (3–4 small lights plus one shadowed key).
9. **Fog** or an equivalent for the "mist cards" fallback.
10. **Particles**: W18 one-shot bursts on iOS (bursts are ignored today,
    per §3.5). Ember burst, frost puff and petals need either a burst
    workaround (a short high-rate emitter) or an iOS fix.
11. **Flipbook sprites** (E5b) for candle and brazier flames. Interim:
    crossed emissive cards.
12. **Node transform animation** (gears, rete, lantern sway) at 60 Hz
    from Dart without per-frame payload churn.
13. **Transparent SceneView (X1)** is *not* needed. Every environment
    here is in-scene, which sidesteps X1 and D6.

---

## 5. Readability in real time: remaining risks

The gate is measured on offline renders. What can break it in the app:

1. **Glowing numerals = emissive mask + bloom.** The numeral colour and
   the emissive map come from atlas R (per-set colour, strength 3–9 in the
   stills). Bloom spreads that light *into the keyline*, which is exactly
   the ring the gate measures, so the contrast drops as bloom rises. Keep
   the bloom threshold above the dice's emissive level (bloom the
   environment, not the numerals), or cap bloom radius below ~0.1 face
   inradius at phone scale; re-measure on device screenshots (below).
2. **Keyline via texture.** Bake halo R into baseColor (dark ring) and
   zero the emissive there. At 2048² the keyline is ~12 texels wide on a d20
   face; ETC1S can smear it into the numeral. Use UASTC for the colour map
   of keyline sets, or keep the keyline in its own channel (e.g. roughness
   texture alpha) and darken in the shader once E6 lands.
3. **Top-down metal needs something to mirror.** Old Road, Vermilion,
   Gemcutter, Arcane and Celestial rely on a soft overhead source. In real
   time that is the zenith of the environment map (E3) or a large
   unshadowed directional fill; with a dark IBL the gold goes dark again.
   Part-diffuse numerals (Vermilion, Gemcutter) are the fallback that does
   not depend on it.
4. **Specular hotspots.** A key light near the camera axis puts its
   highlight on the top faces. The in-app sun preset (el 46.8°) is fine;
   a "lamp mode" light dragged over the tray (E5/V3) is not. Clamp the
   lamp's elevation or lower clearcoat on keyline sets.
5. **Glass dice (Emberforged, Frostbound).** The stills mask back-facing
   glyphs. In real time back faces are culled (fine), but Filament's
   refraction samples the scene behind the die, and the iOS alpha fallback
   blends it: a bright floor under clear ice lowers contrast again. The
   keylines carry the gate there (the plain-body ratio for Frostbound is
   the honest worst case).
6. **Tone mapper parity.** The numbers are for Khronos PBR Neutral. If
   dart3d ships ACES or plain clamp, emissive numerals and pale gold clip
   differently; pick PBR Neutral for the dice scenes or re-tune.
7. **Screen size.** Measured on a 1179 px wide frame: the smallest numeral
   is ~22–27 px (the d20's two-digit numbers, ~1.4 mm on a 460 ppi
   phone). A smaller phone or a zoomed-out camera goes below that; don't
   let the camera fit show more than tray + ~1 cm.
8. **Verify on device.** The check reads any PNG plus the mask pass. The
   next step is to run the same measurement on simulator/device
   screenshots of the real app (the mask pass can come from a debug
   material override), so the gate covers the real renderer too.


---

## 6. Open points for the operator

- **Pick** which environments go to production first. Suggested:
  Emberforged → Frostbound → Arcane Study → Fate Engine, matching the
  batches.
- **Keyline weight**: the keylines are generous (~0.2 face inradius) so
  the gate holds with margin. On Vermilion and Gemcutter they read as a
  bold outline in close-ups; a thinner keyline still passes on most sets
  if the operator prefers a finer look (it's one number,
  `build_atlas` → halo).
- **Die size vs screen**: dice are 1.3× the round-1 size (in-app size).
  A tablet shows more of the environment around the walls (the props are
  modelled for that).
- The *final* dice for the app come from this script (`--export-glb`),
  then the fsceneb conversion. Baking of procedural textures (nebula,
  swirl, fire) into the atlas is the next tool step (a `--bake` mode), not
  done in this pass.
