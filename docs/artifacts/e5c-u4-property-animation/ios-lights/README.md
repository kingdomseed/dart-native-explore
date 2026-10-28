# iOS U4 light conversions and owner replacement

The bounded point, spot and area light lane passed independent Codex review with no scoped reachable P1/P2. The reviewer verified exact49-source replay, recomputed all30 assigned states, decoded/inspected36 screenshots and confirmed the clean video decode; see `review-r1.md`. Native execution, builds and tests remain parent-produced evidence. This does not complete U4 or Track E.

The existing `u4` fixture selects a light using `DART3D_U4_LIGHT=point|spot|area`. The original clip still animates shared material color and light intensity. Replace, Remove and Re-add use public components-only `updateNode` commands on the existing light node. No production native change, new endpoint, clock or protocol operation was added.

## Actual native states

`native-observed.log` and its exact extraction `observed-states.log` contain ten states per process,30 total. A temporary observer reads the assigned `node.light`, the registered intensity owner's `light`, authored rest/effective values, native intensity, declaration count, area extents and actual player controls after the existing sampler. It does not supply samples or alter those objects. `check-observed.dart` checks every row against literal expected values; `observed-proof.json` reports maximum numeric error0 at tolerance1e-6.

| Paused state | Point / spot native intensity | Area native intensity |
|---|---:|---:|
| Rest1, weight1, time0 | 2 | 2000 |
| Time1 / time2, weight1 | 4 / 6 | 4000 / 6000 |
| Rest1, weight.25, time1 | 1.75 | 1750 |
| Replace with rest3, same time/weight | 3.25 | 3250 |
| Rest3, time2, weight.25 | 3.75 | 3750 |
| Remove components | No light or owner | No light or owner |
| Re-add rest1, retained time2/weight.25 | 2.25 | 2250 |
| Seek1 after re-add | 1.75 | 1750 |

Every live state's assigned light is identical to the owner's light; declaration count is1. Removal has nil light/owner and count0. One registered clip, its paused state, time and weight survive all structural actions. Identities stay stable within each live interval. The spot re-add uses a previously seen SCNLight address after the nil interval; the proof does not treat historical addresses as unique lifetime IDs. Authored rest and the new registered owner are checked directly.

Area extents are `(2,1,0)` initially, `(3,2,0)` after replacement and `(2,1,0)` after re-add. Sampling leaves them unchanged. Native intensity uses the existing effective-value×1000 conversion, without multiplying by area dimensions. Point and spot write the effective value directly. These are native field observations, not calibrated photometry.

## Screenshots and clean replay

`point-00` through `point-08`, `spot-00` through `spot-08`, and `area-00` through `area-08` capture the three observed sequences. `all-lanes-contact.png` assembles all27 screenshots. The parent inspected that sheet and full-size phone captures. Controls and cards fit; the neutral receiver goes black on removal and lights again on re-add, while the shared color pair stays unchanged at the retained time/weight. `image-proof.json` retains the sRGB center samples and checks those observations.

The observer was removed, restoring `SceneViewHost.swift` SHA256 `8887e13b946bb3ba8d4073992fef2e2d432fbbf91bc7ef001c71c404e191da73`. `FsceneRealizer.swift` remains `08b1f5011e2dd13848dcad3833fba486e593f2f46711ba8632f3b4be1527ab22`. The area lane was rebuilt and replayed without the observer. All nine `area-clean-*` card crops `[95,300,215,85]` at402x874 exactly match their observed counterparts. Point and spot were not separately rebuilt without the observer; their evidence is the read-only assigned-state observer plus screenshots. The source probe changes only reads/log deduplication.

The clean area interaction video is retained privately as `area-clean-controls.mp4`, with SHA256 in `video-receipt.txt`. It is21.923333 container seconds, fully decodes through FFmpeg with empty error output, and has a sequential1fps sheet `area-clean-ffmpeg-contact.png`. The grid has24 slots,22 sampled frames and two empty padding cells. Parent inspected the sheet. The clip covers the paused seek/weight/component controls, not a new real-time playback or performance test. Prior accepted basic iOS evidence covers continuous playback.

`analyze-images.swift` converts decoded PNGs to sRGB for comparisons. Its samples illustrate visible output; actual native field logs establish conversions. No calibrated linear-color, physical brightness, frame latency or monotonic brightness-vs-area claim is made.

## Source and verification

All four runs use the approved iPhone17Pro simulator `C24F3C6D-A3A9-4FB7-978E-36E67EF55354`, debug build, high quality. Exact flags are in the worker observation guide and the run filenames identify each selector. Run logs contain native build completion and normal `Application finished.` after quitting. The filtered native log is not a global crash audit. The simulator, all parent-owned runs, logger and recording are stopped; a fresh booted-device listing is empty. No physical device input occurred in this lane.

- Parent focused suite:30 passed; final full example suite:298 passed; package suite:380 passed. Both analyses and `git diff --check` pass.
- Worker default normal/camera exports and payload receipts match before/after. Export temporarily fixed only the fresh DocumentId; that code was removed. Copies of the four `.fscene` and four payload receipts plus `default-preservation.log` are retained here. Default and camera behavior were not changed to create these light lanes.
- Baseline49 archive: `../ios-snapshots/source.tgz` in the private pickup, SHA256 `525d0bd3412b607de0090948252e949cb42add20ca25494154c992da5c73574d`.
- Final49 archive: `source.tgz`, SHA256 `587e6d1a99b8a563b453d9fb0cb81dfd091ef847dafbdb29db758a6dbced0495`.
- Four-file correction: SHA256 `ac0e909692456700ce355c1496cd8fb563c37f8515b401c8279133166d1025e7`.
- Replay/source/lock receipts verify all49 paths,45 unchanged baseline paths and five unchanged tracked locks. The existing `light_aim.dart` dependency is unchanged from HEAD; `dependency-sha256.txt` freezes it separately. Temporary replay scratch was removed.

Fixture source/comment review is recorded in `fixture-source-review.md`. Exact observer source/patch, full source archive, clean correction, analysis scripts, native logs and full video remain under `/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-lights/`. Small evidence is copied to writer `docs/artifacts/e5c-u4-property-animation/ios-lights/`. Ignored build/resolution outputs remain in the writer; no commit, push, PR edit or external mutation occurred.

The required-feature warning remains because property animation is deliberately not advertised yet. Android runtime, camera proxy/render-target runtime repeats, capability advertisement, remaining program gates, final T2/T4 and whole-U4 acceptance remain open. This lane does not add an eligibility harness or repeat unchanged renderer features.
