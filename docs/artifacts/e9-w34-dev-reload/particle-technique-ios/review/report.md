# Independent review: native iOS particle scene-pass experiment

**PASS for the bounded negative conclusion.** I found no material reachable in-scope P1/P2 defect or evidence overclaim. In the retained r2 presentation, the tested renderer-local `SCNTechnique` `DRAW_SCENE` constant Metal override makes both ordinary mesh controls magenta while the frozen original native particles remain green. This validates rejection of that tested visible-output override premise. It accepts neither a public debug feature nor complete W34 behavior.

Confidence is high for the visible result in this fixed fixture on the recorded iOS simulator, and high for source/patch identity and offline measurements. The native runs belong to the parent. My independent runtime, builds, tests, simulator/device execution or queries, GPU/material compilation, baking, and performance measurements are **NOT_RUN**. There were no children or external writes.

## Inputs, identity, and replay

I read the complete frozen `README.md`, then `frame.md`, `parent-preparation.md`, and `worker/HANDOFF.md`. I also read the current cross-judgment, the four scoped files, their native/public call paths, relevant repo guides, and installed SceneKit headers. The cross-judgment still rejects complete architecture bases; its ranking of B does not establish an implementation or override this experiment's narrower question.

The prepared review checkout began clean at `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. I imported only the expressly requested coherent **r2 source61** into `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-70a094be`. It remains there unchanged after review. No shell worktree was created.

| Input | Independently verified SHA-256 |
| --- | --- |
| Accepted58 archive | `6a313b9effba2725aedaf14ebc5be082848b248cdd0b70ea4af04269e323c706` |
| r1 source61 archive | `560cbe5d93d83b8bd96c659002e6d71d98ab1a304468dd0f7b5a811c79af9294` |
| r1 four-file patch | `4b67a86525f3bcb961bb9307d51f541e4b9e6b72b54653776fe996d35ce22620` |
| r2 source61 archive | `ad36f3cb97f394bc56324e9bd0f211d3ea6e7225132c594436f54049764d6ecb` |
| r2 four-file patch | `2709b22236ef3f9867e554105b81deb78c147ffe0f088e84269dae58564e1d46` |

All archives contain the expected unique relative regular-file entries: 58, 61, and 61 respectively. Every entry matches its adjacent source manifest. Each experiment differs from accepted58 on exactly the four scoped paths; all 57 other accepted sources match. The r1→r2 comparison changes only `ParticleDebugProbe.swift`: `enableRead: true` becomes `false`, and actual pass `depthStates` logging is added. The embedded vertex and fragment source is byte-identical. See [r1-to-r2.diff](r1-to-r2.diff).

For **each** parent patch I exported base HEAD to disposable scratch, overlaid exact accepted58, ran forward `git apply --check` and apply, compared the resulting entire regular-file tree against the expected archive overlay, then ran reverse check and reverse apply. All commands exited 0. Both forward trees exactly reproduce their source61 snapshots; all 1,933 unowned baseline paths survive unchanged; both reversals exactly restore all 1,934 baseline regular-file paths. The replay scratch was removed. This is offline replay verification, not a build or test run.

I verified all **118** entries in private `packet-sha256.txt`, and all **52** entries in the durable `evidence-sha256.txt`. Every durable entry is byte-identical to its corresponding private-packet entry. Both movies independently match root `video-sha256.txt`. The manifest hashes are:

- Private packet manifest: `fc0223859236a74f8d01823b5843ba717c7ec5180d67ef2d9d626e0240ea58b5`.
- Durable evidence manifest: `d918655badc7d391d486917ed7c9ca8ebcc791dd153acfae9a92bc655a145629`.

Receipts: [verification script](verify-source.py), [source/replay receipt](source-replay-receipt.json), [before import inventory](preimport-source-sha256.json), [after import inventory](postimport-source-sha256.json). The import preserved every pre-existing unowned path and all six locks/registrants, including `dn_plugins.lock`; the complete six-file check is in [final-evidence-receipt.json](final-evidence-receipt.json).

## Reachable path and ownership

The actual fixture calls `SceneController.loadDocument(buildW34ParticleProbe())` once (`w34_particle_probe_main.dart:28`). Existing `SceneController.loadDocument` serializes the document and its payloads (`scene_controller.dart:268–289`). The emitter is the existing public `particleEmitterComponent` (`w34_particle_probe_scene.dart:136–154`), not custom geometry. Existing `FsceneRealizer.decodeParticleEmitter` creates the `SCNParticleSystem`, assigns its image/color/simulation, and attaches it with `node.addParticleSystem(sys)` (`FsceneRealizer.swift:6097–6375`). SceneKit retains simulation and particle presentation ownership.

The new host hook only accepts the exact private fixture tag through existing `viewConfig` (`SceneViewHost.swift:1314–1327`). One optional probe belongs to that host. It binds the named final emitter with exactly one attached system and the named quad, then applies requests after the existing mutation/payload drain (`SceneViewHost.swift:5366–5369`; `ParticleDebugProbe.swift:41–95`). Startup's existing deferred payload realization is not evidence of control-time particle replacement: the observation interval starts after the probe binds the realized fixture.

The probe reads and retains that actual system; it creates no particle system, second scene, copied simulation, material `SCNProgram`, callbacks, reconstructed geometry, or replacement particle renderer. Freeze saves its speed/birth values and sets them to zero; resume restores those values on that object. Off restores the captured ordinary technique. Removal restores those values and the original wire bit while preserving other current debug-option bits (`ParticleDebugProbe.swift:86–117`). Scene load and host destruction invoke removal. The fixed scene has no stage changes during the comparison; broader current-stage restoration and teardown timing are not accepted promises.

The only custom pass assigns the named vertex and constant-magenta fragment to the original host technique (`ParticleDebugProbe.swift:119–164,194–217`). Its vertex uses position attribute 0 and `scn_node.modelViewProjectionTransform`; its fragment does not depend on particle texture, tint, normal, or depth bindings. A missing sampled texture pattern therefore does not invalidate the narrower visible constant-override question.

There is no new public API, schema, opcode, or selection architecture in the four-file delta. Host-local diagnostic state owns the temporary override; the existing realizer and SceneKit continue to own authored particles. **No finding requires a production/public-path fix.** The negative capability result is the intended answer to this experiment, not a feature regression.

## Installed public API check

I independently read and hashed installed iPhoneOS27.1 `SCNTechnique.h`, `SCNParticleSystem.h`, `SCNSceneRenderer.h`, and `scn_metal`; [installed-api-excerpts.txt](installed-api-excerpts.txt) retains line-numbered excerpts and their hashes.

- `SCNTechnique.h:26–47,98–128,198–207,296–326` documents the sequence/pass dictionary, `DRAW_SCENE`, Metal function names, COLOR/DEPTH outputs, depth read/write state, named node semantics, library selection, and technique support. This is a source-supported public experiment, not an invented private shader hook.
- `scn_metal:8–23,59–71` places position first in the vertex semantic enum and describes automatic node fields named in a struct argument `scn_node`, including the model-view-projection transform. The working r2 mesh supplies the visible binding witness; header compatibility alone would not.
- `SCNParticleSystem.h:190–203,215–225,289–295,310–377,406–423` declares an animatable native particle system, image/color/rendering configuration, simulation speed, reset, and property callbacks. It does not make the particle system `SCNShadable` or establish that this technique replaces particle fragments. Those interface facts also do not prove every public SceneKit route impossible.
- `SCNSceneRenderer.h:314–320` documents reverse Z and its default. Reading `usesReverseZ` and selecting a comparison does not establish the actual cause of r1's missing meshes or a valid production depth policy.

I read the repo-local DartNative guide for the fixture/transport conventions. Its referenced vendored `dartnative/docs/plugin_development.md` is absent in this prepared checkout; I used the actual adapter and installed headers. The current [Apple SCNTechnique](https://developer.apple.com/documentation/scenekit/scntechnique) and [SCNParticleSystem](https://developer.apple.com/documentation/scenekit/scnparticlesystem) pages returned JavaScript shells; their linked Markdown fetches were unsupported by the web tool. No semantic claim above relies on those incomplete fetches.

## Independent screenshots and pixel computation

I visually inspected all five r2 screenshots and its parent contact sheet, plus all eight r1 screenshots: live, both frozen baselines, Constant, returned Off, wire, restored frozen, and resumed. I wrote and ran an independent standard-library PNG decoder with CRC checks, zlib decompression, and PNG row unfiltering. It reads the screenshot RGB bytes directly; it does not invoke/import the parent's analyzer. I inspected the parent's analyzer afterward to resolve the exact magenta threshold. See [verify-pixels.py](verify-pixels.py) and [pixel-receipt.json](pixel-receipt.json).

All screenshots are 402×874. Crop `[0,100,402,620]` excludes device chrome/footer. Independent r2 results:

| Measurement | Result |
| --- | --- |
| Frozen Off → returned Off changed scene pixels | **0 / 249,240** |
| Mesh sample `(80,360)`, Off → Constant → returned Off | **[71,57,39] → [255,0,255] → [71,57,39]** |
| Bar sample `(300,360)`, same sequence | **[83,121,137] → [255,0,255] → [83,121,137]** |
| Constant magenta scene pixels, R>220 / G<50 / B>220 | **21,320** |
| Stricter R>240 / G<20 / B>240 threshold | 21,318; two boundary pixels differ in classification |
| Baseline green 3×3-uniform interior pixels in region `[220,180,160,380]` | **10,361** |
| Those same pixels still green under Constant | **10,361** |
| Those same pixels magenta under Constant | **0** |
| Maximum absolute RGB channel change on those interiors | **1** |
| Live / resumed scene changes versus frozen | 12,340 / 13,630; mesh ROI unchanged in both |

The interior mask is selected solely from the frozen baseline: G>R+25, G>B+15 and all nine RGB pixels in its 3×3 neighborhood equal the center. It independently selects the same 10,361 pixels. These are screenshot samples, not a particle count or native position measurement. A broader selection includes antialiased edges affected by the changed background; the uniform-interior boundary is deliberate.

**Off and Constant do not have identical scene bytes.** All 249,240 crop pixels differ, including the gray background and the one-channel green shift. The exact identity claim applies only to frozen Off versus returned Off. This is neither raw color calibration nor sampled texture/tint parity. The original display shows green rectangles; the authored asymmetric L/amber/blue image is not visibly established. Logs saying `MTLSimTexture` was bound cannot establish its sampled appearance or diagnose that absence.

For r1 I independently obtain zero magenta scene pixels under Constant; the mesh sample becomes background `[33,33,33]`, and the bar disappears. Its frozen, steady, returned Off and restored-frozen crop bytes match exactly. The ordinary wire image visibly contains the mesh's indexed diagonal. It does not establish native particle edges. Thus **r1 remains INCONCLUSIVE for interception**, despite native library/technique object creation.

## Native records and movie

The parent's r2 log names PID61329 and the same original system `ObjectIdentifier(0x0000000108d9bc00)` throughout the recorded control interval. Its actual applied state—not just request labels—records:

- 21:50:24: Off, `d3_resolve`, attached=true, speedFactor=0, birthRate=0, saved values 1/8.
- 21:50:30: Constant, `w34_particle_scene`, named functions, actual `enableRead=false`, `enableWrite=true`, `clear=true`, `greaterEqual`; the same attached system remains at 0/0.
- 21:51:37: Off restores `d3_resolve`, same attached frozen system.
- 21:51:45: Resume restores speedFactor=1 and birthRate=8 on that same attached system.

The source contains no control-time reset/removal/recreation or callback measurements. These parent records plus the frozen image restoration support preservation of the original visible population; they do not measure population/positions or reveal the particle's private GPU program. The logs explicitly retain `population=unavailable`, `positions=unavailable`, `pipeline=unobserved`. Library/function creation and technique assignment establish objects and selected state; the magenta meshes establish custom visible output. Neither proves the private program used for particle output. Relevant native records are retained in [r2 probe lines](parent-runtime-r2-probe-lines.txt) and [r1 probe lines](parent-runtime-probe-lines.txt).

I independently hashed both movies. R2 SHA-256 is `f9248cd5996c0ab9133f0a2ee8e5548e206cb999157fcee53b2cbdeb7006dca5`. `ffprobe` reports HEVC/yuv420p, 1206×2622, 89.848333 seconds, 5,476 frames. Independent full FFmpeg 9.0.2 decode to null exited **0** and reached **5,476 frames**, `progress=end`; the [complete stderr](video-decode-stderr.txt) and [progress](video-decode-progress.txt) are retained. There are 77 explicit nonmonotonic-DTS warning lines and 11 repeat-summary lines, accounting for the parent's **88** retained warning lines. This is complete decoding evidence with timestamp warnings, not clean timing, latency, frame-rate, or performance proof.

I independently extracted and inspected frames at **0,5,12,30,60,75,82,88 seconds**. In that order they show live ordinary output; frozen ordinary output; four sustained samples with magenta meshes and green frozen particles; ordinary frozen restoration; then resumed particles. Frame 0 is live before Freeze, consistent with the first recorded gesture at 2.828 seconds and Constant at 10.211 seconds. The recording therefore includes the pre-control state. The extracted [frames](video-frames/) and [contact sheet](independent-video-contact-sheet.png) correspond to the retained movie, not a new runtime execution. Details: [video-ffprobe.json](video-ffprobe.json), [video-receipt.json](video-receipt.json), [verify-video.py](verify-video.py). R1's movie hash matches its manifest; no independent full-decode claim is made for that earlier inconclusive movie.

## Proof boundaries and cleanup

R2's depth-read change is a **synthetic control** that yields the required mesh witness. It is not a production depth/occlusion correction. The precise r1 reverse-Z/clear/comparison interaction remains uninvestigated. Color inputs, sampled alpha, depth, actual particle triangle edges, occlusion behavior, target/sibling isolation and production parity remain unproved. The experiment supplies no reason to build a public implementation on its failed premise; other public SceneKit routes remain untested. B's design ranking and whole W34/Track E acceptance remain unchanged and open.

Worker analysis/typecheck/adapter compilation and parent analysis/typecheck are preparation receipts. The parent's documented native app runs report Xcode builds of **27.7s** (r1) and **8.7s** (r2), both ending `Application finished.` Those are native run/build receipts, not my executions or comparative performance measurements. Archive hashes, post-run source61 checks and logs support the supplied source/evidence correspondence; I did not independently extract or attest the installed binary.

I read parent `source61-after.txt` for each run, `restored58.txt`, both restored-lock receipts, `cleanup-check.txt`, target/Pods restore logs, record-stop receipts and `device-after.json`. They record recorder/app/logger shutdown, normal `DN_TARGET=lib/main.dart`, regenerated Pods, simulator shutdown/no open device and no targeted A142 action. Those operational statements remain **parent-produced evidence**, not independently queried current process/device state. Pod regeneration retains its custom-configuration warning. No last-installed-binary replacement is claimed.

Separately, a read-only filesystem hash check confirms the parent's current 58 accepted source files match accepted58 and all three probe additions are absent. I made no parent writes. My review checkout still exactly matches the imported r2 source61 and its post-import inventory; all six locks/registrants and every unowned path remain intact. [final-evidence-receipt.json](final-evidence-receipt.json) and [final-git-status.txt](final-git-status.txt) retain those checks.

Retained: this report; three independent verification scripts plus the final evidence script; source/replay/import inventories and diff; installed API excerpts/hashes; filtered parent probe records; independent pixel/video receipts and decoder logs; eight representative movie frames and their contact sheet; final status and artifact hashes. The imported r2 snapshot remains in the prepared review checkout. The original private/durable packets, raw videos and parent sources are untouched. Only my disposable replay scratch was removed; no replay scratch or running review process remains. I did not repeat the comment audit or run builds, tests, device queries, material baking, commits, pushes, PR actions, or external writes.
