# iOS U4 sprite snapshots and late texture binding

The bounded sprite snapshot and late texture unit passed independent Codex review with no scoped reachable P1/P2. The reviewer verified exact source replay and independently recomputed all 11 assigned states, 20 screenshots and clean-video decoding; see `review-r1.md`. Builds, tests and native execution remain parent-produced evidence. This does not complete U4 or Track E.

The two cards show current material A on the left and an instance snapshot on the right. One existing red-to-blue clip runs through public U4 controls. Both image payloads are declared without bytes at load. Texture buttons use explicit `applyCommands(upsertPayload)`; Sprite refresh uses an explicit same-ID material upsert, including identical repeated definitions. No timer, native production change, new protocol or new clock was added.

## Native observations

`observed-states.log` records 11 states read from the actual assigned `node.geometry.firstMaterial` slots after the existing sampler. Each row includes player time/weight, material identity, ordinary/sprite kind, effective factor and diffuse texture identity/type. `observed-proof.json` checks every state against literal expected factors and identities; maximum factor error is `5.000000002919336e-8` at tolerance `1e-6`. The run observes seven distinct material objects and three texture/fallback objects. Those counts describe this run, not a general allocation rule.

1. Ordinary white A creates a double-sided instance clone with captured white factor. Registered time0/weight1 samples the current A as red; the clone remains white.
2. Weight .25 / Seek1 samples current `[.875,.75,.875,1]`; the clone remains `[1,1,1,1]`.
3. Texture 1 changes only the current material's diffuse contents from a white UIColor fallback to `MTLSimTexture`. Both factors, assigned material objects, time and weight stay unchanged. The clone retains its captured fallback.
4. Sprite refresh replaces A with sprite authored rest `[.2,.4,.6,1]`, referencing still-pending T2. At retained time1/weight.25 both the new source and refreshed clone have `[.275,.3,.575,1]` at the first observed post-command sample. Source review traces retained sampling before snapshot copying in the same structural mutation. This is pre-render assigned-state evidence, not a GPU first-frame readback or latency measurement.
5. Seek2 changes current to `[.15,.3,.7,1]`; the clone stays frozen at `[.275,.3,.575,1]`.
6. Texture 2 binds a new `MTLSimTexture` to the current sprite without changing factors, objects or clock. The clone retains its captured white fallback and factor.
7. An identical explicit Sprite refresh creates new source/clone material objects. Both use the ready T2 texture and current `[.15,.3,.7,1]` factor.
8. Seek1 changes only current to `[.275,.3,.575,1]`; the clone retains `[.15,.3,.7,1]`. Other assigns green B to the right slot; Default restores the exact refreshed clone and its T2 texture.

Snapshot clones are not registered texture consumers. This lane proves preservation of each recipient's captured/effective factor, and subsequent structural capture of a ready texture. It does not promise automatic late-image propagation to frozen clones.

The observer is read-only apart from changed-state log deduplication. Its exact source and `observation-only.patch` remain in the private pickup. It was removed before the clean build. Final `SceneViewHost.swift` SHA256 is restored to `8887e13b946bb3ba8d4073992fef2e2d432fbbf91bc7ef001c71c404e191da73`; `FsceneRealizer.swift` remains `08b1f5011e2dd13848dcad3833fba486e593f2f46711ba8632f3b4be1527ab22`.

## Images and video

Files `00-` through `09-` show the observed sequence. `clean-00-` through `clean-09-` show the rebuilt app without the observer. `image-proof.json` reports zero changed pixels for every matched card crop `[100,275,210,95]` at402x874. It also checks:

- Both late texture arrivals change the current card while leaving the snapshot crop identical.
- The ready-texture refresh changes the snapshot while leaving current output identical.
- Seek1 changes current output while the snapshot remains identical.
- The variant round trip restores the whole two-card crop exactly.

The scripts decode PNGs into sRGB. They do not calibrate linear color, alpha coverage or raw shadow visibility. The parent inspected the phone layout and the image pairs; cards and all controls fit clear of each other.

Full videos are private, with hashes in `video-receipt.txt`: container durations observed51.5s, clean30.0s. The clean clip supplies motion proof and decodes sequentially through FFmpeg with no error output (`clean-video-decode.log`). Both decode-output attempts for the observed clip exit0 but report non-monotonic DTS warnings (`observed-video-decode.log`, `observed-video-raw-decode.log`). That clip is retained as auxiliary evidence, not a clean decode or timing receipt. No timing or frame-latency conclusion uses either clip. Parent inspected the observed contact sheet and the sequentially decoded clean FFmpeg sheet.

The initial clean `record contact-sheet` output (`snapshot-sequence-clean-contact.png`, 18 cells) contains incomplete card/control regions. It is excluded from motion proof and retained to document the discrepancy. Sequential FFmpeg extraction at0.638 and13.410 seconds shows complete frames at those points; `snapshot-sequence-clean-ffmpeg-contact.png` samples the same video sequentially at one frame per second in row order,30 cells. It shows intact cards/controls throughout the sampled sequence. The underlying reason for the extraction difference is not established. No app/renderer change was made for it. `video-analysis-commands.txt` records the independent decoder commands. Neither sheet proves latency or absence of an unsampled transient.

## Verification and source provenance

Approved iPhone17 Pro simulator `C24F3C6D-A3A9-4FB7-978E-36E67EF55354`, debug build, high quality. Both run logs contain native build completion and normal `Application finished.` after quitting. Controls were driven from fresh agent-device accessibility snapshots. The simulator is shut down; parent-owned runs, recording and filtered logger are stopped. No A142 input occurred.

- Parent focused tests:23 passed (`parent-focused-tests.log`).
- Final full example tests:291 passed (`example-tests.log`).
- Final full package tests:380 passed (`package-tests.log`).
- Both analyses clean (`example-analyze.log`, `package-analyze.log`).
- `git diff --check` passed.
- Baseline47 source archive SHA256: `acf142a8efb87a6425fea8ee529497e31197b714cc4bd813dd1950e351c1a82f` (`../ios-owners/source.tgz` in the private pickup).
- Final49 source archive SHA256: `525d0bd3412b607de0090948252e949cb42add20ca25494154c992da5c73574d`.
- Four-file correction SHA256: `3d3016c10aefb798328f7b4f60efa6d89ae78078e0bc9811be48f0f6c024da9a`.
- `replay-proof.log`, `final-source-check.log` and `final-lock-check.log`: all49 sources match, all45 unowned baseline sources and five tracked locks unchanged. Replay scratch removed.

Worker patch integration differs only by the accepted private helper rename and two narrative-comment deletions. See `fixture-source-review.md`.

Durable small evidence is under writer `docs/artifacts/e5c-u4-property-animation/ios-snapshots/`. Complete source archive, clean patch, temporary observer source/patch, full videos and scripts remain at `/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-snapshots/`. Ignored build and Dart-resolution outputs remain in the writer checkout. No commits, pushes, PR edits or external mutations occurred.

The existing `d3:propertyAnimation` capability warning remains because the public native feature bit is deliberately not advertised. Capability acceptance, Android execution, other remaining light/camera/payload/owner cases, T2/T4 and whole-U4 readiness stay open. This is parent-produced native/test evidence awaiting independent review.
