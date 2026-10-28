# W34 bounded iOS source and native-evidence review

**PASS.** No material reachable in-scope P1/P2 defect or remaining evidence overclaim found in the frozen observed61 source and the corrected parent packet. This verdict covers one opaque PBR quad, sampled view-space normal versus geometric-normal and literal-color controls, filled wireframe off/on/off, and matched image restoration. It does not accept production W34, E9, or Track E.

I performed source review and independent offline artifact verification. **Independent native runtime, devices, simulator queries, builds and tests: NOT_RUN.** The native execution and operational cleanup remain parent-produced evidence. No children, external review provider, PR actions, commits, pushes, external mutations or parent-checkout writes were used.

## Snapshot identity and preservation

The prepared checkout was clean at required HEAD `2f38e4e33f0b1cb678bc408a42d069c796cefc12` before import. I inspected the tar inventory for unique relative regular-file paths, verified all three supplied SHA-256 values, and imported only observed61 into this checkout:

| Input | SHA-256 |
| --- | --- |
| observed61 `parent-r2-source.tgz` | `2c70e6f6dd5c19f42bda18f6fe69a1835ace47a7a7d33807486bf8b175abcfb9` |
| accepted58 `parent-source.tgz` | `6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706` |
| five-file `parent-r2-probe.patch` | `520fe187e53ec2f21059be9e3029860b2f15fa1dccad2d9ff3baef262ed8e3db` |

Both adjacent source-hash manifests match their archive bytes. The observed61 path manifest also matches. Independent forward patch replay on accepted58 in disposable scratch produced exactly observed61; reversing it produced exactly accepted58. The delta is exactly the five authorized files: `DebugChannelProbe.swift`, `FsceneRealizer.swift`, `SceneViewHost.swift`, `w34_debug_probe_scene.dart`, and `w34_debug_probe_main.dart`. All 56 unowned baseline sources are byte-identical. The adjacent preservation receipt's 56 hashes and six lock/registrant OK entries match independently computed values. The six lock/registrant files in my checkout remain unchanged. Scratch was removed.

The r0 versus r2 archive comparison changes only `DebugChannelProbe.swift` logging: one long record becomes render/display/effects records. Shader bodies and selection behavior are unchanged. The retained first-run log has the truncated `<…>` diagnostic. No shader correction or black-frame GPU fix is supported or claimed.

Receipts: [source identity and replay](source-receipt.json), [replay output](patch-replay.txt), [r0/r2 diff](r0-r2.diff), [imported hashes](imported61-sha256.txt), [inventory](archive-inventory.txt), [verification script](verify_sources.py), [final checkout status](final-git-status.txt).

## Actual path and ownership

I read the frame and both platform source maps, then traced the bounded fixture through the imported source. The explicit alternate main registers plugins and loads the fixture. `w34_debug_probe_scene.dart:8–95` supplies four vertices with normals/tangents, indices `[0,2,1,0,3,2]`, an actual 64×64 asymmetric four-region rgba8 texture tagged `normal`, opaque PBR factors, and normal UV offset `(0.1,0.08)`, scale `(0.8,0.84)`, rotation `0.13`, UV set 0. The scene has a fixed rotated quad, directional light, camera, linear tone mode, exposure 1 and empty effects.

The controls call `selectW34DebugProbe` at scene line 156. It modifies only two private fixture properties and sends the full current material through existing `SceneController.applyCommands` (`scene_controller.dart:447–499`), `upsertResource`, and native `applyUpsertResource` (`SceneViewHost.swift:2547`). `redecodeResource` calls `decodeMaterial` at host line 2865 and reattaches the new material to actual consumers. It does not replace geometry or substitute a generic diagnostic material.

`FsceneRealizer.swift:2416` constructs the ordinary SceneKit material. The existing normal slot at line 2933 retains the real texture/mip binding, intensity and slot transform. `applyContentsTransform` at line 3178 applies the authored scale, rotation, translation and mapping channel. Existing surface/factor modifiers and alpha policy are established before the probe append at line 2618. `DebugChannelProbe.swift:12–29` copies the modifier dictionary and appends only a declaration-free fragment body after its existing fragment body. Mapped mode reads normalized `_surface.normal`; geometric control deliberately reads `_surface.geometryNormal`; literal control writes `(0.125,0.5,0.875)`. Only RGB is assigned. The fixture has no sheen, sprite, mask or other material-family composition to prove.

Installed iPhoneOS27.1 SceneKit headers independently support this meaning: `SCNShadable.h:408–454` describes fragment normal, geometryNormal ignoring the map, sampled texture properties and view-space geometric fields; lines 537–560 make those structures readable at the final fragment entry point. `SCNSceneRenderer.h:56–57` distinguishes showWireframe (`1 << 5`, overlay on objects) from renderAsWireframe. Header fingerprints are in `input-sha256.txt`.

After pending mutations drain, `SceneViewHost.swift:5359` updates the probe. The probe owns only the showWireframe bit, retains its prior value, and uses insert/remove without replacing other debug bits (`DebugChannelProbe.swift:32–56`). Scene reset calls release. These are source observations; prior-true bit restoration and scene-reset lifetime behavior were not separately executed. Off selection reconstructs the current authored material through the existing upsert owner and omits the diagnostic fragment. Matched PNG restoration below proves the tested fixed fixture, not restoration across excluded concurrent updates or other material families.

## Independent pixel verification

I inspected all nine saved r2 PNGs and independently decoded their RGB bytes with FFmpeg. The independent script does not run the parent analysis or change its outputs. Its computations reproduce the parent's `analyze.dart`/`pixel-analysis.json` values for crop **[0,100,402,650]** (XYWH).

| Comparison | Changed scene pixels |
| --- | ---: |
| initial mapped → steady mapped | 0 |
| initial mapped → mapped return | 0 |
| initial Off → restored Off | 0 |
| initial Off → wire-off restored | 0 |
| initial Off → wire on | 1,364 |

At `(120,320)`, `(260,330)`, `(140,470)`, `(290,475)`, mapped RGB is respectively `[176,237,237]`, `[113,127,223]`, `[172,187,253]`, `[229,187,245]`. Each surrounding 11×11 interior region is uniform at its own color. Geometry control is `[172,187,253]` throughout all four regions; literal control is `[100,187,237]` throughout. The mapped regions cross triangle interiors and retain the asymmetric transformed texture boundaries visible in ordinary shading. This supports sampled mapped-fragment access rather than a geometric or vertex-normal substitute.

The wire changes occupy bounding box `[91,269,316,504]`. Of these, 359 changed pixels lie well inside the face and within 1.50 pixels of the projected internal triangle diagonal. 50,690 original filled-face pixels remain unchanged. Visual inspection of the PNG and independently extracted video frames confirms the actual internal diagonal and perimeter over filled normal-mapped PBR shading.

Initial and steady mapped PNGs have identical SHA-256 `a24590548f9d79d4489705bea8c142fda1088221629e4b8b3301a9032b6fa7d7`; both decode to the four colored regions and match mapped-return scene bytes. The earlier black-preview interpretation is contradicted by these saved artifacts. It is not an established runtime defect.

Receipts: [independent pixel results](independent-pixels.json), [independent computation](inspect_pixels.py).

## Native transcript, transfer and video

I scanned the complete 1,707-line `native-r2.log` and inspected its selector/display/effects records and other diagnostics. Runner PID is 60742. The sequence is Off → mapped → geometry → transfer → mapped → Off → wire on → wire off; requested and actual wire state agree, with debugOptions 0 → 32 → 0. No matching shader compilation failure appears in the captured log. This is a bounded log observation, not a guarantee about all diagnostics outside its capture/filter.

The log records HDR true, exposureOffset 3, adaptation false, camera whitePoint 128, averageGray about 0.18, SCNTechnique present, packGain 8, resolveWhitePoint 16, stage exposure 1 and linear tone mode. All fourteen logged effect flags are false. Source confirms the camera packing and resolve path remains active. Screenshot RGB is encoded display output through that path; literal RGB is a transfer control, **not raw-normal calibration**.

`run-r2.log` records `Launching lib/w34_debug_probe_main.dart`, `Xcode build done. 8.8s`, and `Application finished.` I did not rerun it. Worker analysis/typecheck/build and parent analyses are supplied historical checks, not independent checks by this reviewer; they are not required to upgrade this review into a new build/test pass.

The raw movie hash independently matches `aa518d452e3572fdefb968b05bd52fb92c78c769ceae18c48e262f332f168380`. FFprobe reports HEVC, 1206×2622, duration 213.713333 seconds and 12,989 frames. My complete independent FFmpeg decode exited **0** and reached **12,989 frames**, retaining **693 duplicate/nonmonotonic DTS warning lines**, matching the parent's warning-line count. This is successful decoding with timestamp warnings, not clean timing or latency proof.

I inspected the parent contact sheet/times and separately extracted and inspected frames at 0, 30, 90, 160, 165, 175, 185, 190, 195, 200, 205 and 211 seconds. They show initial Off; sustained colored mapped mode; geometry; literal RGB; mapped return; ordinary restoration; filled wire including diagonal; final ordinary restoration. The saved recording-start receipt and first Off frame support recording before the first mapped selection. No per-transition latency claim is made.

Receipts: [video metadata](video-metadata.json), [independent decode and frame hashes](video-receipt.json), [decode progress](video-decode-progress.txt), [decode warnings](video-decode-stderr.txt), [independent frame sheet](independent-video-sheet.png), [native selection extract](native-selection-extract.txt).

## Parent cleanup, durable packet and limits

I read the full parent runtime README and saved source61-after-run, restored58, restored-locks, cleanup-check and device-after receipts. Their source/lock path sets exactly match the 61/58/six manifests. The cleanup receipt states normal main, no reload/probe selector, three additions removed and accepted reload library retained. The saved final inventory lists every simulator unbooted and no open thread device. Stopping the recorder/app/logger, actual configuration restoration, shutdown and no targeted A142 action remain **parent-produced operational statements**; I performed no live device queries or operational replay.

The durable parent `docs/artifacts/e9-w34-dev-reload/debug-probe-ios/evidence-sha256.txt` verifies all 26 listed files. Its 25 non-README files match the corresponding private evidence byte-for-byte; the durable README is the deliberately shorter narrative, which I read against the full README. No material overclaim remains in either corrected narrative. [Evidence identity receipt](evidence-receipt.json) records these comparisons.

No finding requires a correction: no reachable in-scope broken contract was established. No production public API is accepted. Shader-family composition, deformation, instances, clones, multiview/capture isolation, Android, other channels, depth, performance, full verification tiers and whole E9/Track E remain open.

Kept: exact observed61 overlay in the prepared checkout; this report; source/input/output hashes; source/replay/pixel/video/evidence receipts; verification scripts; log extracts; independent contact sheet and twelve representative frames under `video-frames/`. The disposable replay directories were removed. Original private evidence and the parent checkout were left untouched. No other checkout writes are present beyond paths in observed61.
