# Hero scene brief — dart3d launch screen (P4)

Status: design brief, research only, no code. Written 2026-09-29.
Scope: the new launch "hero" for `dart3d/example`. It shows a 3D DartNative
logo on a dark stage, with a slow camera drift and a subtle glow pulse.
Over it sit a headline, three value props, and a way into the existing
**Dice / Showcase / Harness** screens. Context: `docs/program-v2.md`
Track P, P4. P4 depends on E2 (orbit controller). §3.4 gives an interim
path that doesn't need E2.

Sources checked 2026-09-29:

- dartnative.com home (live CSS read in the browser): <https://dartnative.com/>
- License / continuity page: <https://dartnative.com/license>
- Changelog: <https://dartnative.com/changelog/>
- dartpub.dev home: <https://dartpub.dev/>
- GitHub README and LICENSE: <https://github.com/DartNative/dartnative>
  (local clone `dartnative/README.md`, `dartnative/LICENSE`)
- Playground palette: `dartnative/playground/lib/screens/home/demo_ui.dart`
- Logo: `dartnative/playground/assets/dn-logo.svg`, plus the site's
  `https://dartnative.com/media/img/dn-logo.svg` and `dn-logo-transparent.svg`.
  The first gradient's stops are the same in all three.
- Widget support: `dartnative/docs/widgets.md`, `dartnative/skills/dart-native/SKILL.md`
- dart3d realization: `dart3d/README.md`, `docs/texture-material-spec.md`,
  `docs/environment-ibl-spec.md`, `docs/extended-surface-program.md`
  (W13/W25 effects matrix), `docs/verification-matrix.md` (W7, W13),
  `docs/program-audit-2026-09-28.md`

---

## 1. Visual language (what DartNative looks like)

### 1.1 Palette: site (dark-only)

The site's CSS defines these tokens in `oklch`. I converted them to sRGB
hex in the browser. The site has no light theme and no theme toggle.

| token | oklch | hex | use |
|---|---|---|---|
| `--bg` | .16 .012 250 | `#090E12` | page background (blue-black) |
| `--bg-2` | .185 .013 250 | `#0E1318` | panels, hero card, CTA band |
| `--surface` | .21 .014 250 | `#13191F` | cards, secondary button fill |
| `--surface-2` | .245 .015 250 | `#1B2127` | raised surface |
| `--border` | .30 .014 250 | `#292E35` | hairlines, secondary button border |
| `--border-strong` | .38 .016 250 | `#3C434B` | emphasized borders |
| `--text` | .96 .005 250 | `#EFF2F5` | primary text |
| `--text-2` | .78 .012 250 | `#B2B8BF` | lead paragraphs |
| `--muted` | .58 .012 250 | `#757B81` | captions, inline code |
| `--muted-2` | .45 .012 250 | `#50565C` | tertiary |
| `--accent` | .86 .19 132 | `#A1EA5A` | **lime green**: primary CTA fill, eyebrow text, glows |
| `--accent-ink` | .22 .05 132 | `#121F05` | text on the accent button |
| `--accent-soft` | .32 .05 132 | `#29381D` | tinted accent background |
| `--link` | .78 .10 240 | `#79C0F1` | links; also the second, cool glow |
| `--warn` / `--danger` | — | `#FCB442` / `#FF6F69` | status |

Every neutral uses hue 250, a slightly blue grey. Nothing on the site is
pure black or pure grey.

**Brand gradient** (`--brand-grad`). It fills the hero headline's
"mobile apps." span through `background-clip: text`:

```
linear-gradient(96deg, #FA60A6 0%, #EF388B 26%, #E99173 48%, #D7BA52 72%, #B5C75E 100%)
```

That is pink → magenta → coral → gold → olive-lime. The site also has a
second, brighter gradient (`.grad-text` / `.grad-bar`, a 999px pill bar):

```
linear-gradient(92deg, oklch(.78 .22 5)=#FF6DA4, oklch(.86 .18 85)=#FFC500, #7CE782, #12CBF5)
```

That one runs pink → amber → mint → cyan.

**Background glows.** Sections are never flat. Each gets one or two large,
soft radial gradients in the accent at 6–14% alpha:

- Hero wrap: lime at 10% from the top-right (`1100×520 at 80% −10%`),
  plus blue `#79C0F1` at 10% from the left (`900×520 at −5% 10%`).
- CTA band: lime at 14% centred above the top edge.
- "Deep" chapters: a plum wash, `oklch(.25 .05 320)` = `#2C1930` at 35%,
  over `rgb(5,8,12)`.
- The phone mockup has a lime halo behind it: `radial-gradient(closest-side, lime/22%, transparent 72%)`.

### 1.2 Palette: the logo

`dn-logo.svg` is one path, a flowing lowercase "n", drawn with four
stacked fills (viewBox 56×56, gradients running left to right from
x 6.14 to 49.86):

1. Base: `#FA60A6 0 → #EF388B .32 → #E99173 .50 → #D7BA52 .77 → #B5C75E 1`.
   These are the same stops as `--brand-grad`, spaced a little differently.
2. and 3. Soft yellow sheen (`#F9D126`…`#E2CE39`, opacity 0 → 1 → 0),
   peaking around 52–63% across. This reads as a specular band over
   the middle stroke.
4. A diagonal overlay (8,20 → 47,37) that goes yellow → `#BBCA5B` →
   **`#17C4E0` / `#03C3F0` cyan**. This makes the right-hand tail turn cyan.

In 3D terms: warm pink on the left stroke, gold highlight across the
middle, cyan on the tail. **Bake all four layers into one texture.**
Don't try to rebuild them from materials.

### 1.3 Palette: playground app (the in-app look)

`demo_ui.dart` borrows Apple's system palette for both platforms. It is
not the website palette.

- Dark: bg `#000000`, bar `#1C1C1E` (glass `#1C1C1E` at 85%), row `#1C1C1E`,
  tile `#2C2C2E`, chip `#3A3A3C`, text `#FFFFFF` / `#8E8E93` / `#636366`.
- Light: bg `#FFFFFF`, rows `#F2F2F7`, text `#111111` / `#6B6B70`.
- Accents: `#0A84FF` blue, `#30D158` green, `#FF9F0A`, `#FF453A`,
  `#BF5AF2`, `#64D2FF`, `#FFD60A`, `#FF375F`, `#5E5CE6`.

What this tells us: in apps, DartNative's style is to **look like the
platform**. Branding stays on the website. The hero can borrow the site's
dark, glowing look for the 3D stage. The controls should stay native.

### 1.4 Typography

- Family: **Geist** for everything, and **Geist Mono** for eyebrows and code
  (fallback stack `ui-sans-serif, system-ui, sans-serif`).
- h1: 700 weight, ~76px at 1280px wide (96px at the widest), letter-spacing
  −2.1px (≈ **−0.028em**), line-height ≈ 0.98.
- h2: 700, ~55px, letter-spacing −1.77px (≈ **−0.032em**), line-height ≈ 1.03.
- h3: 700, ~35px, letter-spacing ≈ **−0.025em**, line-height 1.1.
- Lead paragraph: 600 weight, ~19.5px, line-height 1.55, colour `--text-2`.
  The key phrases are set bold in `--text`.
- **Eyebrow**: Geist Mono 500, 12px, UPPERCASE, letter-spacing 1.44px
  (**0.12em**), lime `--accent`. Examples: "IF YOU KNOW FLUTTER",
  "THE KEYBOARD TEST".
- Buttons: 600, 15px.

### 1.5 Shape, depth, effects

- Radii: buttons 7px (`.btn`); the hero CTAs and nav primary are **pills
  (999px)**; cards 10px; plugin cards 13px; plan/tutorial cards 16px;
  hero/code cards 14px; big media and CTA band 22px; the phone clip 44px.
- Glass: only the sticky nav. It uses `backdrop-filter: saturate(1.4) blur(14px)`
  over `rgba(9,14,18,.72)`. The sound chip uses `blur(8px)`.
- Shadows: deep and soft for media, e.g. `0 30px 60px rgba(0,0,0,.45)`.
  Inputs get a 3px lime focus ring at 12%. The status dot glows
  `0 0 6px var(--accent)`.
- Icons: small rounded tiles (8–9px radius) with the icon in a tinted
  accent, e.g. `#79C0F1` on `rgba(121,192,241,.12)`.
- Spacing: firecrawl's brand extraction reports a 12px base unit and
  10px as the default radius. Sections are generous and centred, with
  lots of air.

### 1.6 Motion on the site

The site's motion is small in amount and in distance. Everything is a
single ease-out, and nothing loops except the product videos.

- Hero entrance (`hero-rise`): each line of the pitch fades in from
  `translateY(26px)` over **0.85s** with **`cubic-bezier(0.16, 1, 0.3, 1)`**
  (expo-out). Stagger delays: 60ms, 180ms, 300ms, 400ms.
- Device mockup (`hero-bloom`): opacity 0 → 1, scale **0.965 → 1**, 1.0s,
  same curve, 260ms delay.
- Scroll reveals: `translateY(24–26px)`, 0.7–0.75s, same curve. Children
  stagger at 110ms steps.
- Hover: 0.12–0.16s on colour, border, and a small transform.
- **`prefers-reduced-motion: reduce` turns all of it off.** Content just
  appears, with no transition.
- No ambient animation: no pulsing, no parallax, no spinning logo. The
  hero's only "life" is the looping product video in the phone frame.

---

## 2. Messaging (how DartNative explains itself)

Short quotes, attributed. Everything else is paraphrased.

- Tagline: "The best way to build mobile apps." (dartnative.com h1,
  footer, and `<title>`)
- Sub-tagline: "Real native apps, written in Dart." (dartnative.com hero;
  the README banner alt text is close to this)
- Its sharpest line is a negation: "No Impeller. No Skia. No bridge. No
  alien feeling." (dartnative.com hero)
- Flutter on-ramp: "The only change is the import." (dartnative.com,
  "You already know DartNative")
- dartpub.dev's hero: "Ship more. Maintain less." (dartpub.dev)

Core claims, paraphrased:

1. **The platform's own views, not a canvas.** Your widgets become real
   UIKit and Android views: text, lists, inputs, keyboard, Liquid Glass,
   Material 3. There is no rendering engine in between. The README says
   Dart drives the native UI directly through synchronous FFI on the main
   thread.
2. **Flutter-compatible.** Same widgets, layout, hot reload, and Dart.
3. **Performance as a consequence of the design.** Their examples: the
   keyboard animation runs in the same compositor transaction as the
   system's, 120fps native scrolling, AOT cold start with no engine to
   warm up, and a smaller binary because no rasterizer ships (README:
   4.4 MB vs 5.7 MB compressed).
4. **Stats row:** "0 abstraction layers · 120fps native scrolling · 34
   first-party plugins · 1 language".
5. **An ecosystem run like a product.** First-party plugins are free and
   native-backed. Community plugins are open source and archived on
   dartpub.dev. Authors of popular plugins pay less.
6. **Trust and commercial terms.** "You're the customer." A sunset clause
   open-sources the framework if it is ever discontinued. Shipped apps
   keep working if a subscription lapses. CodePush is included in every
   plan.
7. **Skia only where it's needed.** GPU canvas "islands" (Skia Graphite on
   Metal/Vulkan) for shaders and dense graphics, never as the app's
   renderer. This is the positioning closest to dart3d: a native GPU
   surface placed inside a native view tree.

Words they use again and again: *native, real, the platform's own,
the system's own, both platforms, first-party, zero (stutter/lag/per-frame
CPU), fidelity, honest, maintained like a product*. The changelog is
titled "Always shipping" and lists concrete widgets and fixes, with no
hype.

What dart3d can honestly borrow: **"real native renderers."** dart3d
drives SceneKit on iOS and Filament on Android, with no Flutter renderer
(the README calls it the renderer Zero deleted). That parallels
DartNative's "the platform's own views" story, one level down.

---

## 3. Hero scene recommendations

Principle: **match their restraint, not their layout.** Use a dark
blue-black stage, one hero object lit in the brand gradient, one soft
glow, native controls, expo-out entrances, and very little ambient motion.

### 3.1 Backdrop and environment

| layer | recommendation | realized? |
|---|---|---|
| Clear colour | `SceneView(backgroundColor: 0xFF090E12)` (site `--bg`) | wire field exists (`lib/src/scene_view.dart:52`) |
| ~~Soft glow behind the logo~~ | **Discarded (operator, §3.4/§3.5): no separate glow card, quad or halo — the logo's own gradient emission + bloom is the glow.** Original recipe (unlit radial-gradient quad) kept only as history. |
| IBL | `environment: {type: studio}` for reflections and specular on the logo. **No skybox**, so the clear colour shows. | studio IBL verified both (W7 matrix rows 159–163) |
| Env intensity | Tune per platform. The W-HDR lane needed `1.0` on iOS but `0.08` on Android (`verification-matrix.md:447`). Expect the same kind of split here. | known quirk |
| Option: gradient sky | `skybox.source.type: gradient` (zenith `#0E1318`, horizon `#13191F`, ground `#090E12`, no sun). It's in code on both platforms (`FsceneRealizer.swift:~6394`, `EnvironmentFactory.kt:~143`), but I found **no verification row** for it. | code only. **If chosen, it needs a T3 live check on the A142 (Vulkan + GL) and the iOS sim before merge — a T1 run can't show it renders.** |
| Floor or shadows | **None, as an aesthetic choice** — the logo floats. (Android directional shadows work since #16; a soft floor shadow remains an option if it looks better.) |

### 3.2 Lighting

- **Key**: one directional light, warm white (`#FFF4E8`), from
  upper-left-front (elevation ~40°, azimuth ~−35° from the camera's
  axis). Set it strong enough that the gold sheen band reads as a real
  specular highlight as the camera moves.
- **Rim lights**: two spot or point lights behind the logo, placed so the
  extruded edges pick up the brand's two ends. Pink `#FA60A6` behind-left
  and cyan `#03C3F0` behind-right (the logo tail's own colour), each at
  about 0.6× the key. They catch the bevels and define the silhouette
  against the near-black stage.
- No fill light. The studio IBL provides fill.
- Exposure: leave the defaults and adjust `exposure` only if the gradient
  clips. iOS keeps SceneKit's filmic tonemapper (recorded approximation,
  W7 row 166). Android can use `pbrNeutral`. **Compare the two side by
  side for gradient saturation.** Filmic tends to desaturate the pinks.
  If needed, `colorGrading.saturation` ~1.05–1.1 on iOS only.

### 3.3 Logo model and material (Blender)

> **Superseded by the landed asset (#26).** The logo is built by
> `dart3d/example/tool/dn_logo/build_dn_logo.py`: variable-radius
> elliptical **rounded tubes** swept along the stroke (`DEPTH_RATIO = 0.85`),
> one glossy clear-coated material, the gradient baked into a 1024²
> texture reused as the emissive map. That rounded form is what makes the
> full-orbit decision work. The flat-extrusion recipe below is kept as
> history only — do not rebuild the logo from it.


- Geometry: trace the SVG path, extrude to ~12% of glyph width, and add a
  small rounded bevel (2–3 segments). Export `.glb`, then convert to
  `.fsceneb` with the upstream importer, as the other showcase assets were.
  Put it in a **separate primitive (material) for the face and for the
  side walls/bevel** (multi-primitive is supported on both platforms).
- **Face material** ("lacquered gradient"):
  - `baseColorTexture`: the four SVG layers flattened to a 1024×1024
    sRGB texture, UV-mapped planar across the glyph's x extent.
  - `metallic 0.0`, `roughness 0.28`.
  - `clearcoat 1.0`, `clearcoatRoughness 0.08`. KHR clearcoat is
    realized on both platforms: SceneKit `clearCoat` and Filament
    `clearCoat` (`texture-material-spec.md:211-216`). The device lane
    (`full-engine-program.md:160`, `w22-clearcoat.png`) is still
    unchecked. It arrives through the glTF extension path, so confirm
    that the `.glb → .fsceneb` conversion (or runtime `loadGlb`) keeps
    it. If it's dropped, raise the roughness contrast instead.
  - `emissive = #FFFFFF`, `emissiveTexture` = the same gradient,
    `emissiveStrength` base **0.35**. The logo then glows faintly in its
    own colours rather than white, and bloom takes its hue from it.
    (Emissive-texture semantics were fixed on Android in W4: `w=0`, not
    attenuated.)
- **Side/bevel material**: the gradient multiplied by ~0.45 (a dark,
  saturated version), `metallic 0.6`, `roughness 0.35`. The rim lights
  do the work here. This keeps the 3D form readable and stops the logo
  looking like a flat sticker.

### 3.4 Camera

**Operator decision (2026-09-29): full, slow 360° orbit** — option (a). The
original recommendation (a ±24° arc, kept below for reference) was declined:
the logo is a rounded tube, so the edge-on and mirrored views are part of
the 3D appeal. Use a constant-speed yaw orbit of **~30 s per revolution**
(12°/s), with the pitch bob below; make sure the rim lights read well from
every angle.

| parameter | value |
|---|---|
| FOV (vertical) | 30–35° (long lens, flat perspective, "product shot") |
| Target | logo centroid, raised +0.05 × glyph height |
| Radius | framing-driven: logo width ≈ **62% of the view width** in portrait. With a 2.0-unit-wide logo at 32° FOV on a ~9:19.5 screen, that is r = 2 / (0.62 · 2 · tan(FOV/2) · aspect) ≈ **11–13 units** (aspect 9/19.5, FOV 30–35°). Derive it from the bounds (`world_bounds.dart`) rather than hard-coding. |
| Yaw | **full 360° orbit, ~30 s per revolution, constant speed** (operator decision). *Superseded suggestion: sine pendulum ±24°, period 18 s.* |
| Pitch | base elevation **+8°**, sine **±3°**, **period 13s** (not a multiple of 18s, so the path doesn't visibly repeat) |
| Roll | 0 |
| User input | one-finger drag takes over and scrubs yaw/pitch (yaw unclamped, pitch −5…+25°). On release, ease back into the drift over **1.2s** (expo-out). Pinch is off on the hero. |

Implementation. Until E2 lands, the camera can use the showcase screen's
boom: `showcase_scene.dart` recomputes position plus look-at and writes
it with `setNodeTransforms`, driven by a `Ticker`. Measure the cost of
one `setNodeTransforms` per frame on the Nothing A142 and on the iPhone
simulator before committing to 60 Hz. Once E2 ships its orbit
controller, replace this with the controller's drift/auto-rotate mode.
Alternatively, rotate the **logo node** instead of the camera (same
look, one transform). The rim lights then move with the logo, which
removes the light sweep. Keep them fixed in world space.

> **Operator direction (2026-09-29): the glow comes from the model itself.**
> The logo emits its own gradient colours — `emissiveTexture` = the baked
> gradient, so each part glows its own colour (pink glows pink, cyan tail
> glows cyan) — and bloom bleeds that colour into the dark stage. **No
> separate glow card or single-colour halo**; any "glow card" references
> below are superseded. The pulse is the emissive strength of that
> gradient emission, over a still-lit glossy PBR surface (not a flat neon
> sign).

### 3.5 Pulse and glow

Their site never pulses, so keep ours to **one slow "breath"**, almost
subliminal.

| channel | spec | notes |
|---|---|---|
| **Primary: emissive breath** | `emissiveStrength` 0.35 → **0.65** → 0.35, raised-cosine (`0.5 − 0.5·cos`), **period 4.8s** | Needs a material update at runtime: `upsertResource` on the face material. **Unmeasured cost.** Rate-limit to ≤ 20 Hz. The change is smooth enough that 20 Hz isn't visible. If `upsertResource` re-realizes the material, use the fallback. |
| ~~Fallback / companion: halo breath~~ | **Discarded** with the glow card (operator, §3.5). If the emissive breath hitches, fall back to a **static glow** (bloom must not be animated: every bloom change rebuilds the environment, ~10–70 ms). | — |
| Bloom (static) | `effects.bloom`: enabled, threshold ~**0.85**, intensity ~**0.3**, scatter/blur ~**0.6** | iOS: applied (threshold/intensity/blurRadius). Android: approximate (`strength/highlight/levels ← scatter`). **Tune separately per platform.** **Never animate bloom**: effects live on the environment resource, and any change there re-runs the env build, which is fingerprint-gated and costs ~10–70ms (`environment-ibl-spec.md`). |
| Vignette (static) | subtle, ~0.25 | iOS applied, Android approximate |
| Don't use | lens flare (iOS approximate; on Android flare is ignored when bloom is on, per the audit), chromatic aberration (Android platform limit), god rays (limit on both), DoF (unnecessary with a single subject) |

### 3.6 Entrance and motion spec (matches their curve)

Easing for every UI entrance: **`Cubic(0.16, 1, 0.3, 1)`** (their
expo-out). `CurvedAnimation` with a custom `Cubic` is supported
(`widgets.md`, Animation table).

| t (ms) | what |
|---|---|
| 0 | Stage visible (clear colour). The logo is already in the scene at emissive 0. |
| 0–1000 | Logo "bloom-in": uniform scale 0.965 → 1.0 and emissive 0 → 0.35. This echoes their `hero-bloom` (scale 0.965, 1.0s). Scale via `setNodeTransforms`. The emissive ramp uses the pulse channel. |
| 260 | Camera drift starts from yaw 0 with its sine phase at 0, so there's no jump. |
| 400 / 520 / 640 / 740 | Eyebrow, headline, value props, and CTA rows each rise 26px and fade in over 850ms (their `hero-rise` stagger, shifted by +340ms to follow the logo). Use `SlideTransition` + `FadeTransition`. |
| 1800+ | Ambient only: drift and breath. |

Reduced motion. Check the platform setting. `MediaQuery.disableAnimations`
support in DartNative is **unverified**; look for it in `widgets.md`
before use, or add a small plugin/`dartnative_system` probe. If reduced
motion is on: no rise-ins, logo at rest scale, **camera parked at yaw
−12° / pitch +8°**, no breath (static emissive 0.45). Also pause all
ambient motion when the hero isn't the visible screen.

### 3.7 Overlay UI (DartNative widgets)

Available in DartNative core (`widgets.md`): `Stack`/`Positioned`/`SafeArea`,
`Text`/`RichText` (per-span weight and colour), `LinearGradient`/`RadialGradient`
in `BoxDecoration`, `StadiumBorder`, `Button` / `FilledButton` /
`OutlinedButton` / `TextButton`, the animation widgets, and
`GlassEffectContainer` (iOS 26 only; a no-op elsewhere). `BackdropFilter`
maps to native blur, but **blurring a live SCNView/Filament surface
behind it is untested**.

**Not available:** `ShaderMask`, so no gradient-clipped text like the
site's "mobile apps." Get the gradient from the **3D logo itself** and
from a thin gradient hairline (a `Container` with the brand
`LinearGradient`, `StadiumBorder`, 3px tall, 40px wide) above the
headline. This also keeps us from copying their signature headline
treatment.

Typography on device:

- **Default: the system font** (SF Pro / Roboto). This fits DartNative's
  own "real text / CoreText / platform text" message. Headline 34pt,
  `FontWeight.w700`, `letterSpacing: -0.8` (≈ −0.024em, their tight
  headline tracking scaled down). Value props 15pt w500 in `#B2B8BF`,
  with the leading keyword in w600 `#EFF2F5`.
- Eyebrow: 12pt, w500, UPPERCASE, `letterSpacing: 1.4`, lime `#A1EA5A`,
  in a monospace face. `fontFamily: 'Menlo'` on iOS and `'monospace'` on
  Android (the playground uses `'monospace'` and `'Courier'`). Test both.
- Optional: bundle **Geist / Geist Mono**. Vercel publishes them under
  the SIL OFL 1.1; verify the licence file before bundling. Declare them
  in pubspec `fonts:` and call `DartNativeFontRegistrant.registerAll()`
  at boot (iOS; see `skills/dart-native/SKILL.md`). This matches their
  typography more closely but pulls our look nearer to theirs, so treat
  it as a guardrail decision (§4).
- Font size units: pt on iOS, **sp on Android** (sp scales with the
  accessibility setting). Leave room for 1.3× text.

Portrait phone layout sketch (iPhone 17 Pro, 402×874pt):

```
┌──────────────────────────────────────┐
│ ░ status bar ░                       │
│  dart3d                    [ ⓘ ]     │ ← 17pt w600 wordmark (ours), info → About
│                                      │
│            ·  ·  (glow) ·  ·         │
│         ╭───────────────────╮        │
│         │                   │        │
│         │   3D DN logo      │        │  ← logo ≈ 62% width, centred ~38% from top
│         │  (drifting arc,   │        │    (no glow quad — the logo glows its own colours)
│         │   breathing glow) │        │
│         ╰───────────────────╯        │
│                                      │
│  ▬▬▬  (3px brand-gradient pill)      │
│  COMMUNITY 3D PLUGIN · DARTNATIVE    │  ← eyebrow, mono 12pt, lime, +0.12em
│  Real 3D, on the                     │
│  platform's own GPU.                 │  ← headline 34pt w700, −0.8 tracking, 2 lines
│                                      │
│  SceneKit on iOS. Filament on        │
│  Android. One Dart scene graph.      │  ← value prop 1
│  flutter_scene documents, physics,   │
│  PBR and particles — rendered        │  ← value prop 2
│  natively.                           │
│                                      │
│  ╭──────────────────────────────╮    │
│  │         Roll the dice         │    │  ← primary pill, lime #A1EA5A / ink #121F05
│  ╰──────────────────────────────╯    │
│     Showcase      ·      Harness     │  ← TextButtons, #B2B8BF
│                                      │
│  Community plugin · not affiliated   │
│  with Presence Network               │  ← 11pt #757B81 (see §4)
└──────────────────────────────────────┘
```

- The text block is bottom-anchored inside `SafeArea`, with 24pt side
  margins and 12pt rhythm (their base unit): 12 between eyebrow and
  headline, 16 between headline and props, 24 above the CTA, 12 between
  CTA and links.
- A scrim behind the text: a `Container` with a vertical
  `LinearGradient` from `#00090E12` at 45% height to `#F2090E12` at the
  bottom. This keeps the glow from lowering text contrast. Check AA
  contrast for `#B2B8BF` on the scrim (≈ 9:1 on `#090E12`).
- Primary CTA: `FilledButton`/`Button(variant: filled)` with a pill
  (`StadiumBorder`), fill `#A1EA5A`, label `#121F05` 17pt w600, height 52.
  On iOS 26 a `prominentGlass` tinted lime is an alternative. Keep it
  opaque for contrast.
- Navigation: "Roll the dice" → Dice (index 0); "Showcase" → 1;
  "Harness" → 2. The hero becomes a new first screen, and the existing
  `SegmentedControl` shell is unchanged behind it. Add a small "Home"
  way back, e.g. a leading item on the shell's nav row.
- The Harness link can sit lower, or only in debug builds. It's a test
  surface, and P4 asks for a curated showcase, "not test lanes".

**Headline copy options** (ours; informed by their positioning, not
reusing their sentences):

1. "Real 3D, on the platform's own GPU." *(recommended: echoes "the
   platform's own", which is their key phrase, applied to rendering)*
2. "Native renderers. Dart scene graph."
3. "SceneKit and Filament, driven from Dart."

Avoid: "The best way to …", "No Impeller. No Skia …", "You already know
…", "Zero …" triplets, and "Real native apps, written in Dart". Those
are their taglines.

**Value props** (pick 2–3):

- "SceneKit on iOS. Filament on Android. One Dart scene graph."
- "flutter_scene documents, rendered natively." (factual compatibility
  claim; keep "flutter_scene" as the package name in code style, not as
  a brand)
- "PBR, physics, particles — no Flutter renderer required."

---

## 4. Guardrails (brand and attribution)

What I found about brand usage:

- **No public brand or logo guidelines** on dartnative.com, the license
  page, the changelog, dartpub.dev, or the GitHub README. None of them
  mention trademarks or logos.
- The **framework LICENSE** (`dartnative/LICENSE`) is "All rights
  reserved", © Presence Network Inc. §4.2 explicitly leaves *Licensor's
  trademarks* out of the sunset open-sourcing. §7.4 says DartNative is
  an independent product of Presence Network Inc. Read this as: the
  name and logo are their marks, and no licence to use them is granted.
- **Their own disclaimer pattern** (site footer): DartNative is a product
  of Presence Network Inc. and is not affiliated with or endorsed by
  Google LLC. Ours should follow the same pattern.
- dartpub.dev community plugins mostly use `*_kit` / `native_*` names,
  never `dartnative_*`. That prefix appears to be reserved in practice
  for first-party plugins. Keep `dart3d` as-is and don't rename to
  `dartnative_3d`.

Rules for the hero:

1. **Our identity leads.** The top-left wordmark and the eyebrow say
   *dart3d*. DartNative appears only as "for DartNative" / "built for
   DartNative". No "DartNative 3D", no "Official", no lime-pill "Get
   started" copy.
2. **Disclaimer on the hero**, small but present: *"dart3d is a community
   plugin, not affiliated with or endorsed by Presence Network Inc.
   DartNative and its logo are trademarks of Presence Network Inc."*
   ("trademarks" is our assumption; the LICENSE only reserves them.)
   Repeat it in the About sheet and in `example/README.md`.
3. **Logo use is nominative.** The 3D mark says "this runs on
   DartNative". It's an homage centrepiece in a non-commercial demo. It
   must not be modified into our own logo, combined with our wordmark as
   a lockup, or used as the app icon or splash. Keep its proportions and
   gradient faithful: no recolouring beyond lighting.
4. **Attribution gap to fix.** `dart3d/example/assets/showcase/ATTRIBUTION.md`
   only mentions `assets/dn-logo.png` in passing (the `cube.glb` row).
   It has **no ownership or usage line for the DartNative logo**, and the
   source SVG comes from an "All rights reserved" repo. Before P4 ships,
   add a row for the logo (`dn-logo.png`, the new `.blend`/`.glb`/`.fsceneb`)
   saying it was derived from `DartNative/dartnative`
   `playground/assets/dn-logo.svg`, © Presence Network Inc., used to
   identify the platform, all rights reserved by the owner, not covered
   by this repo's licence. Consider asking hello@dartnative.com for
   permission. Their contributor program suggests they'd welcome it,
   but that is an inference.
5. **Don't clone the site.** Borrow tokens (colours, tracking, easing),
   not composition. No left-headline/right-phone split, no stats row
   ("0 / 120fps / 34 / 1"), no comparison table, no gradient-clipped
   headline word, no Geist-everything unless decided on purpose.
   Native system controls keep it reading as an app built on DartNative,
   not a port of their marketing page.
6. **No third-party screenshots in git** (per the task). Browser
   screenshots taken for this brief were kept out of the repo.
7. **No claims we can't back.** Don't use "120fps", "zero lag", or size
   figures for dart3d unless we measure them. Prefer factual renderer
   and feature claims that the verification matrix supports.

---

## 5. Open questions and checks before implementation

- T3 (live, both platforms): does the `gradient` skybox render on both platforms? (Only if we
  use the optional sky.)
- Measure: cost of `upsertResource` on a material at 20 Hz (emissive
  breath). Is it a property write or a re-realize? Is per-frame
  `setNodeTransforms` sustainable at 60 Hz on the A142?
- Does clearcoat survive the importer path, and does it show on device
  (W22 lane 4 still unchecked)? Tune the Android bloom look separately
  from iOS.
- `BackdropFilter` over a live 3D surface: if the scrim ever needs blur,
  test on both platforms first. The default plan uses a gradient scrim,
  with no blur.
- How to detect reduced motion in DartNative (`MediaQuery.disableAnimations`
  or equivalent).
- Decide Geist vs system font (guardrail 5).
- Permission or attribution for the logo (guardrail 4).
