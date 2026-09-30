# Integration triage — `stabilize/integration` (2026-09-28)

Owner: integration pass. Branch: `stabilize/integration` from `origin/main`.
Devices: Nothing A142 (`00064149A002033`, Mali-G610, Vulkan + GL, release)
and iPhone 17 Pro simulator (`9151BBE4-…`, debug via `dn run`).

## Verified heads

T2 was run on integration head **`ab62511`**, which contains:

| Branch | PR | SHA verified |
|---|---|---|
| `stabilize/dart` | #14 | `c0a4a43` |
| `stabilize/ios` | #15 | `93cbb7a` |
| `stabilize/android` | #16 | `ff3d591` |
| `origin/main` | — | `9835ee0` (docs replan #17) |

## Merges and conflicts

Merged `--no-ff` in the order dart → ios → android three times as the
branches moved: first `50ef732` / `8132821` / `b6fa42b`, then
`abd9d33` / `93cbb7a` / `ff3d591`, then dart `c0a4a43`. `origin/main`
`9835ee0` (docs only) was merged in as well.

**No conflicts at any step.** The Android branch's
`dice_table_scene.dart` `aimLight` edit merged cleanly. That helper was
later moved into the shared `lib/light_aim.dart` (see fix 1).
`dn analyze` is clean and `dn test` is green in `dart3d/` (273 tests) and
`dart3d/example/` (126 tests) at the head.

## Fixes on the integration branch

| # | Commit(s) | Area | What |
|---|---|---|---|
| 1 | `51ec9d3`, `a6b8c1a` | example | **Light aims.** New `lib/light_aim.dart` `aimAlong(dir)`, which points node-local +Z along the travel direction (upstream 0.23 `worldDirection`). The cube, imported and feature `key` lights and `showcase.key` now use it. `dice_table_scene`'s local `aimLight` is gone. The first cut (`51ec9d3`) preserved the old −Z travel, which pointed **at** the cameras, because cameras also look along +Z from −Z. The iOS harness showed black camera-facing slabs (`ios-harness-backlit-first-aim.png`). `a6b8c1a` makes the keys travel down and away from the camera. Tests: `test/light_aim_test.dart` covers matrix semantics, downward travel, and travel·camera-forward > 0.3. **Gotcha:** vector_math `Quaternion.rotated` applies the *inverse* rotation, so check aims through `asRotationMatrix()`. No other directional or spot rotations exist in the example; `rectAreaLight` (W12) was left alone. |
| 2 | `3673e02`, `c115d3e` | example | **iOS over-exposure (stopgap).** `keyLightIntensity()` scales the example's directional keys and the showcase fill by `kIosDirectionalScale` = 1000·10·2.604e-5 ≈ 0.26 on iOS only. The native unit fix is a follow-up (below). |
| 3 | `8aa13fa` | **android native** | **Materials lane black on A142 Vulkan: a regression.** The catcher and particle packages are no longer prewarmed. See §Materials lane. |
| 4 | `e0c5b41`, `ab62511` | **android native** | **New crash found by T2:** SIGBUS/SIGSEGV in `ColorGrading::Builder::build` / `::customLut` at the harness W25 LUT lanes. Fixed with a reachability fence. See §W25 crash. |

The native changes were unavoidable: fixes 3 and 4 are Android runtime
bugs that no example change can avoid.

## Light units (task 2): analysis and follow-up

- **iOS:** the wire `intensity` goes straight into `SCNLight.intensity`
  (SceneKit PBR: 1000 ≈ unit radiance). The camera uses `wantsHDR` with
  `exposureOffset = log2(exposure)`. `toneMapping` is **ignored**:
  "iOS keeps SceneKit's".
- **Android:** directional lights use `DIRECTIONAL_LUX_PER_UNIT = 10`
  lx (`FsceneRealizer.kt:68`). Filament's default camera exposure is
  f/16, 1/125 s, ISO 100, so EV100 ≈ 14.97 and exposure ≈ 2.604e-5.
  The same wire value is therefore **≈0.26× as bright** as on iOS.
  - Point lights use candela = lm/4π. At the showcase fill's distance
    that is ~10⁻⁴ of the iOS value, because SceneKit's range attenuation
    keeps most of the light.
  - Environment: 30 000 lx × 2.6e-5 ≈ 0.78 vs iOS 1.0, roughly equal.
  - Android applies `pbrNeutral` tone mapping; iOS applies none.
- **Why it only showed now:** the example keys (1300–2400) were tuned on
  Android. Until the +Z axis fix, every iOS key shone upward, so iOS
  never saw them.
- **Result:** the dice tables are now comparable. iOS is a lighter tan
  than Android's darker walnut (`ios-dice-calibrated.png` vs
  `a142-vk-dice-roll.png`). Before the scale, iOS was near-white
  (`ios-dice-overexposed-before.png`). Showcase fcar is comparable.
  - **Remaining difference (not intensity):** iOS dash and glb are
    paler and less saturated than Android (`ios-dash.png` vs
    `a142-vk-dash.png`). This looks like a colour-pipeline difference
    (sRGB/texture decode or the missing tone mapper on iOS).
- **Follow-up (native, both):** pick one wire unit contract and implement
  it on both sides, then delete `kIosDirectionalScale`. Two options:
  - Make the iOS directional/point mapping reproduce Android's
    photometric pipeline.
  - Raise Android to SceneKit parity (≈38.4 lx/unit) and re-tune every
    authored key down by 0.26.

  Either way, also decide the iOS tone mapper (`pbrNeutral` has no
  SceneKit path today) and the point-light falloff model.
  `docs/android-parity-spec.md` §Light units needs the same update.

## Materials lane (task 3)

- **origin/main (`8089c11`) renders** on A142 Vulkan
  (`materials-vk-origin-main.png`). This was run from a separate
  worktree, `../dn-main-check`.
- **Integration: fully black** on Vulkan (`materials-vk-before-fix.png`).
  GL renders (`materials-gl-before-fix.png`), so it is a regression.
- **Symptom:** kernel `CS_FATAL … CS_BUS_FAULT`, a Mali `Unhandled Page
  fault in AS1`, and the app log `[mali]CET: cpu queue set unrecoverable
  error`, about 2 s after the first realize. The device is lost and the
  view goes black. There is no Java or native crash. The earlier
  "no errors" report missed these because they are kernel/driver lines.
- **Bisect** (main Dart + `stabilize/android` native at each step):
  - bad: `ff3d591`, `6b4dcca`
  - good: `8572f74`, `ae1c966`, `9482304`
  - **Culprit: `6b4dcca`** "never compile materials on main at view
    creation".
- **Trigger:** the fault landed about 0.45 s after the background
  prewarm finished compiling the **catcher and particle** packages
  (added to the prewarm by `6b4dcca`). That happened while the first
  realized frames were rendering.
  - Removing the STE `variantFilter` did not help.
  - Removing catcher + particle from the prewarm renders with 0 faults
    (2/2 runs, `materials-vk-after-fix.png`).
- **Mechanism: not proven.** Hypothesis: the same class of bug as
  §W25 crash. filamat's allocations on the prewarm thread trigger a GC,
  which finalizes a Java-owned buffer or object that a pending Vulkan
  upload still references. The GPU then reads freed memory. GL does not
  page-fault on this. Follow-up below.

## W25 crash found by T2

- **First run** (Vulkan, head before the fix): the app died at
  `w25 LUT blend 0.35`. The crash was `SIGBUS pc=0x12` in
  `libfilament-jni` `ColorGrading::Builder::build`, on the main thread.
- **After `e0c5b41`** (holding the ToneMapper): the crash moved to
  `SIGSEGV SEGV_ACCERR` in `ColorGrading::Builder::customLut` ←
  `nBuilderCustomLut`. That means the Java `Builder` itself was being
  finalized.
- **Cause:** Filament's Java Builder, `ToneMapper` and the LUT
  `ByteBuffer` free native memory in finalizers. The Builder holds raw
  native pointers only. In the R8-minified release build, ART may
  consider an object dead once its `long` handle is loaded. The
  multi-MiB LUT resolve between `toneMapper()`/`customLut()` and
  `build()` triggers GCs.
- **Fix (`ab62511`):** all three objects are written to a volatile field
  after `build()`. The field is read on release, so R8 keeps it.
- **Pre-existing?** The code is the same on main (W13/W25). A main
  Vulkan harness passed the same lane once, so this is a latent GC race
  that the new harness timing exposes. It was never caught because T2
  had never been run through W25 on Vulkan.

## T2 — device smoke on `ab62511`

| Surface | Result | Evidence (`docs/artifacts/integration/`) |
|---|---|---|
| A142 **Vulkan** | **PASS** | See Vulkan notes below. |
| A142 **GL** | **PASS** | See GL notes below. |
| iPhone 17 Pro **sim** | **PASS, with caveats** | See iOS notes below. |

**A142 Vulkan:**
- The harness ran to `w18 lane complete` with **0**
  FATAL/`Fatal signal`/`CS_FATAL`/AndroidRuntime lines.
- Dice rolled and settled.
- dash, fcar and glb render; warm relaunch had no crash.
- Evidence: `a142-vk-harness-end.png`, `a142-vk-dice-roll.png`,
  `a142-vk-dash.png`, `a142-vk-fcar.png`, `a142-vk-glb.png`,
  `a142-vk-warm-relaunch.png`, `a142-vk-harness-w18.png`,
  `a142-vk-w26.png` (W26 lane shot from the pre-fence head `c115d3e`),
  `logs.md`.

**A142 GL:**
- The harness ran to completion with 0 fatal lines.
- A mid-harness tab-switch storm during W14 (Dice → Showcase → Harness
  → Dice → Harness) did not crash, and the harness restarted and
  completed.
- Dice rolled and settled; dash, fcar and glb render; warm relaunch had
  no crash.
- Evidence: `a142-gl-*.png`, `logs.md`.

**iPhone 17 Pro sim:**
- The harness ran to `w18 lane complete` twice. There were no "Lost
  connection" lines and no Runner crash reports.
- The harness die rolls and settles (wLoose rolls 1–3 via
  pose-quiescence). The dice table settles at boot.
- dash, fcar and glb render.
- **Not done: tab switching and the ROLL button.** The user declined
  simulator input access for this session, so neither was exercised.
- Evidence: `ios-harness-w14.png`, `ios-harness-w18.png`,
  `ios-dice-settled.png`, `ios-dash.png`, `ios-fcar.png`,
  `ios-glb.png`, `logs.md`.

The iOS runs were on `a6b8c1a`. `ab62511` changes only Android Kotlin,
so that iOS evidence carries over.

### Coordinator-requested checks

| Check | Result |
|---|---|
| AutoRerollGate: no 3 s auto-reroll after wLoose (+78 s) | **PASS (A142 Vk, logs).** Die (node 82) contacts appear in the first 20 s and during the wLoose rolls. After that, only the single W25 close-out roll appears: nothing between +100 s and +160 s, and nothing after +180 s. **Caveat:** settle events are *absent* after wLoose (`wloose settled event path: absent`, on main too), so the loop could not re-arm anyway. |
| A reload re-enables auto-reroll | **PASS (A142 Vk).** After Dice → Harness the harness restarts and the die's contact cadence resumes. |
| (a) billboard `d3:instances` rebuild | **PASS (smoke).** The `w26` showcase lane renders the billboard grid with no crash or garbage (`a142-vk-w26.png`). The only log is `transforms unresolved` before the payload lands. An *empty* rebake was not specifically exercised. |
| (b) doubleSided instances + KHR variant pick-up | **Partial.** The log shows `material variant d3_lit_e20/opaque compiling in background; base material meanwhile`. That the variant swapped in on a doubleSided instance was not visually confirmed. |
| (c) W18 alpha particle ordering | **Not judgeable** from the harness screenshots (`final` W18 shots show particles, but ordering can't be read at this density). No crash. |
| (d) warm relaunch: no physics/trail jump | **PASS (no crash, first frame correct)** on the Showcase w26 lane and after harness runs. A physics or trail jump was not measured: nothing was moving at relaunch. |
| (e) no "init failed" overlay | **PASS.** There are 0 `init failed` / `cannot render` / `base material compile FAILED` lines across all runs. |
| iOS W18 flipbook/burst particles | **PASS (no crash)** in 2 harness runs. |

### Harness findings (not fixed, for owners)

- **W25 dice-regression close-out FAILs on every surface.** The log reads
  `rolled but no settle event within 10 s`.
  - Settle events are never delivered after wLoose, because some body
    never sleeps. This is identical on origin/main
    (`wloose settled event path: absent`).
  - The lane added in #14 therefore cannot pass as designed. Dart owner:
    wait on pose-quiescence like wLoose does, or find the body that
    never sleeps.
- **Android A142 d12 rests on an edge at spawn:** q≈identity, and the
  best face dot is 0.851. iOS tips it over.

## Dice readout mismatch (task 5): root cause confirmed

- **Diagnostic:** I temporarily logged the settle quaternion and a
  matrix-based read (not committed), then compared the readout with the
  visible top faces:
  - iOS: 6 dice. A142 Vulkan: 5 dice.
  - Evidence: `readout-diag-ios.png`, `readout-diag-a142-vk.png`.
- **What fits:** only one hypothesis matches **11/11** dice on both
  platforms, every one with dot = 1.000:
  ```dart
  (q.asRotationMatrix() * Vector3(n.x, n.y, -n.z)).y   // max over faces
  ```
- **Two compounding bugs:**
  1. `DieFaceMap.read` (`dice_table_scene.dart:40`) uses vector_math
     `Quaternion.rotated`, which computes `conj(q)·v·q`. That is the
     **inverse** rotation.
  2. The `dice_faces.json` normals are in the opposite Z handedness from
     the posed mesh frame. They look like right-handed source-asset
     normals.
- The current code matched 3/6 (iOS) and 1/5 (Android). The earlier
  "d6, d8 and d10u match" was partly luck.
- **Fix (Dart owner):** use the expression above in `read`, or mirror z
  in the JSON and keep matrix semantics.

## Follow-ups

1. **Light-unit contract (native, both):** see §Light units. Delete
   `kIosDirectionalScale` afterwards.
2. **iOS colour saturation** vs Android (dash, glb): check sRGB/texture
   decode and the tone mapper.
3. **Mechanism of the materials-lane GPU page fault**: see §Materials
   lane. Then restore the catcher/particle prewarm if it's safe.
4. **Audit all Filament Java Builders and buffer descriptors for GC
   reachability.** There are 23 `.Builder()` sites plus
   `setImage`/`setBufferAt` direct buffers. Two crashes and possibly the
   page fault come from this class of bug.
5. **W25 close-out lane:** settle-event absence (Dart).
6. ~~**Dice readout:** the fix above (Dart).~~ — done in P3 DR1 (matrix read, z mirrored once on load; per-face unit tests; A142 10-roll check in `docs/artifacts/p3-dr1/`). iOS device check pending.
7. ~~iOS T2 tab-switch soak and ROLL-button roll~~ — done on main `4e12ef3` (§iOS T2 close-out).
8. **Showcase shows a black view with no loading indicator** while a large
   asset (Dash, ~9 MB) loads — about 3 s on the iOS sim. Add a loading state (example UX).
9. ~~**Dice can come to rest under the tab bar**~~ — fixed in P3 DR1 (walls fitted to the screen minus the chrome insets). Original note:: on iOS a die settled against the
   top wall beneath the segmented control (`ios-main/ios-harness-run-roll.png`) —
   the tray doesn't account for the overlay insets (part of the P3 "table follows
   screen aspect" item).

## Final T2 — merged heads (2026-09-28)

**Merged-head equivalence (T2 reuse justification).** main after #16 is
`e19e031`. `git diff c67ffac e19e031` is empty, so the Android runs at
`c67ffac` are on the merged tree byte-for-byte. The iOS run at `7c6dbcb`
differs from `e19e031` only under `dart3d/android/` and `docs/`
(`git diff 7c6dbcb e19e031 -- dart3d/ios dart3d/lib dart3d/example` is
empty), none of which an iOS build compiles, so the iOS evidence applies
to `e19e031` for the checks it covered.

Evidence: `docs/artifacts/integration/final/` (per-run counts in each `logs.md`).

| Head | Surface | Result |
|---|---|---|
| main 1c3f961 + ios ae4d876 + android c3635e1 (`7c6dbcb`) | iOS sim | **PARTIAL** (T2 not closed) — harness complete, 0 crash lines; W15 reload/remove cycles; W18 sub-frame bursts; dice settle; dash/fcar/glb/materials. Not exercised: tab switching and the ROLL-button roll + settle (no simulator input access) — iOS T2 stays open until those run. → merged as #15 |
| android c679636 | A142 Vulkan / GL | Vulkan PASS except warm relaunch; GL PASS incl. 5/5 warm relaunches (`android-c679636/`) |
| android **c67ffac** (merged as #16) | A142 Vulkan | **PASS** — harness complete; 0 native fatal, 0 Java exceptions, 0 `E dart3d`; replay 55 ops; dice settle; dash; materials not black (`android-c67ffac/`) |
| android **c67ffac** | A142 GL | **PASS** — same counts (`android-c67ffac/`) |

**Correction:** the Vulkan warm-relaunch PASS reported above for `ab62511`
and `7c6dbcb` only grepped native `Fatal signal` lines and missed a Java
`RuntimeException`; treat it as unverified. Vulkan warm relaunch crashes on
every head including `main` before this work — tracked in #18.

**Incident (7c6dbcb GL run):** another app (Chrome) took the A142 foreground
mid-run and blind `adb input` taps landed in it; reported to the operator,
who cleared the device. All later runs gate every input on the foreground
package being `com.jasonholtdigital.dart3d_example`.

### iOS T2 close-out — main `4e12ef3` (2026-09-29)

One continuous session on the rewritten main `4e12ef3` (iPhone 17 Pro sim,
debug, driven through the simulator input tool), so no evidence is reused
from pre-rewrite heads:

1. `dn run -d 9151BBE4-… --dart-define=DART3D_SCENE=harness` → harness ran to
   `w18 lane complete`.
2. Dice tab → **ROLL button** → rolled and settled (`rolled … total 51`;
   `ios-main/ios-harness-run-roll.png`).
3. Showcase → Dash renders (`ios-main/ios-harness-run-after-tabs.png`).
   (A Harness tap in this session did not register — no log evidence — so
   the tab storm was re-run separately, below.)

**Error scan over the complete capture** (`ios-main/ios-harness-roll-tabs-full.log`, 672 lines, launch → end):
`grep -ciE 'fatal|crash|exception|error|sigabrt|sigsegv|lost connection'` → **0**.
Crash reports: `find ~/Library/Logs/DiagnosticReports -newermt @<run start> -iname '*Runner*'` → **0**.

**Tab storm, separate session** on main `4e12ef3` (default mode;
`ios-main/ios-tab-storm-full.log`, 490 lines). Each switch is confirmed by a
log line and/or screenshot: Dice (line 15) → **Harness**
(`storm-1-harness.png`, 60 fps, rolling) → **Showcase** (line 328,
`storm-2-showcase.png`) → **Harness revisit** (`storm-3-harness-revisit.png`,
settled) → **Dice** (line 487). Scan
`grep -ciE 'fatal|crash|exception|error|sigabrt|sigsegv|lost connection'` → 2
hits, both explained: line 192 `Errored: 0` (a harness counter) and line 490
`Lost connection to device.` — the simulator log shows `installcoordinationd`
terminating the app at 08:35:30 for a reinstall by another agent's `dn run`
on the same simulator (runningboardd "termination request from
installcoordinationd", then `InstallsStarted`), after the storm had
completed (excerpt committed: `ios-main/simulator-termination-0835.log` — line 96 `Received termination request from [osservice<com.apple.installcoordinationd>]`, line 109 `terminate_with_reason` for pid 33097, lines 179/194 `InstallsStarted`). No crash report was written (`DiagnosticReports`, no `Runner*`).
Lesson recorded: one agent per simulator at a time.

An earlier short run on the same tree (`ios-roll-button-settled.png`,
`ios-after-tab-storm-dash.png`) showed the same behaviour.

**iOS T2: PASS** on main `4e12ef3`. Known items seen: d20 readout mismatch (S0g),
Dash paler than Android (S0g), follow-ups 8–9 above.
