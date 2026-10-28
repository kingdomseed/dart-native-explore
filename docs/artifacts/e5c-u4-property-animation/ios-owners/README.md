# iOS U4 ordinary material ownership

The bounded ownership sequence passed independent Codex review (no scoped reachable P1/P2). The reviewer verified the source/replay and independently recomputed all 16 raw native states and all 11 matched screenshot crops, inspected the images/contact sheets, and decoded both videos. See `review-r1.md`; native execution and tests remain parent-produced evidence. This does not complete U4 or Track E.

The fixture adds three ordinary unlit cards, left to right: current material, variant default, and explicit rebind. It uses one existing animation clock. Public variant selection, same-ID material upsert, and component update commands exercise the existing owners; production native source is unchanged by this unit.

## Observed behavior

- At time 1 and weight .25, all cards share the same material object and factor `[.875,.75,.875,1]`.
- Selecting Other assigns green B to the last two cards while current A continues sampling. Default restores the actual current A object.
- Replacing A while Other is selected gives the current card a new material object. Its new authored rest `[.2,.4,.6,1]` produces `[.275,.3,.575,1]` at time 1 and weight .25.
- At time 2, Default restores the retained old A object to the last two cards, frozen at `[.875,.75,.875,1]`. The current replacement A samples `[.15,.3,.7,1]`.
- Rebind F assigns only the last card to orange `[1,.5,0,1]`. Weight 1 / Seek1 changes only the current card to `[.5,0,.5,1]`.
- Other followed by Default returns the middle card to retained old A and the right card to F. Neither subscribes to replacement A.

`observed-states.log` contains 16 post-sampler states from the actual assigned `node.geometry.firstMaterial` objects, not a Dart model or only the owner registry. `observed-proof.json` checks every time, weight, material identity and factor against literal expected values. Maximum factor error is `5.000000002919336e-8`, tolerance `1e-6`; four material identities are distinct. This measures effective native shader factors, not calibrated display color.

The temporary observer only reads those slots after the existing sampler and logs changed states. Its exact source and patch remain in the private pickup. It was removed before the clean build/replay. `SceneViewHost.swift` returned to SHA256 `8887e13b946bb3ba8d4073992fef2e2d432fbbf91bc7ef001c71c404e191da73`.

## Screenshots and motion

Files `00-` through `10-` show the observed sequence. The corresponding `clean-00-` through `clean-10-` show the rebuilt app without the observer. `image-proof.json` reports zero changed pixels for all 11 matched card crops `[65,275,270,95]` at 402x874. Retained-default and foreign-card center samples are unchanged across the relevant states. The script decodes PNGs into sRGB; it does not claim raw PNG channel equivalence or linear color calibration.

- `clean-01-shared-quarter-seek1.png`: one current A shared by all three.
- `clean-05-replace-A-while-hidden.png`: replacement current A with green selected variants.
- `clean-06-old-default-restored.png`: replacement current A and retained old defaults.
- `clean-08-current-owner-only.png`: current animation, retained old default, foreign F.
- `clean-09-foreign-overridden.png` / `clean-10-foreign-restored.png`: explicit F survives a variant round trip.

The parent inspected both contact sheets: observed 19 cells / 59.0 seconds; clean 21 cells / 33.4 seconds. They show the state changes and the cards clear of the footer. Full videos are retained privately with hashes in `video-receipt.txt`. They are interaction evidence, not a frame latency or performance measurement.

## Verification and provenance

Approved iPhone 17 Pro simulator `C24F3C6D-A3A9-4FB7-978E-36E67EF55354`, debug build, high quality. Both `dn run` logs show native build completion and normal application exit. Controls were driven through fresh agent-device accessibility snapshots. The simulator is shut down; parent-owned runs, recording, and filtered logger are stopped.

- Parent focused tests: 19 passed (`parent-focused-tests.log`).
- Final full example tests: 287 passed (`example-tests.log`).
- Final full package tests: 380 passed (`package-tests.log`).
- Both analyses: no issues (`example-analyze.log`, `package-analyze.log`).
- `git diff --check` passed.
- Baseline source archive: `ios-sheen/source.tgz`, SHA256 `8d07c601bfb91546c03f5b3bfff38c05e6821384e8e01ecfb3ec6de0b89515e6`.
- Final 47-source archive: SHA256 `acf142a8efb87a6425fea8ee529497e31197b714cc4bd813dd1950e351c1a82f`.
- Four-file correction: SHA256 `5e6040a5dc9598a81e57e2732d9147bcad52231664e7fa31878f384e96dc8415`.
- Replay verifies all 47 sources, 43 unchanged baseline sources, and five unchanged tracked locks (`replay-proof.log`).

The fixture worker's patch was integrated with one additional direct-view routing key and three narrative comment deletions. Read-only source review found no scoped P1/P2; comment audit accepted the existing internal-test import suppression. See `fixture-source-review.md`.

Private complete pickup: `/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-owners/`. It retains the source archive, observation-only source/patch, clean correction, scripts, full videos, and receipts for independent review. No replay scratch remains. Ignored build/Dart resolution outputs remain in the writer checkout.

The runtime still emits the existing required-feature warning because the public native property-animation capability is deliberately not advertised. This lane is not a capability-advertisement pass. Android execution, sprite/catcher structural refresh, late texture binding, remaining native owner/projection/light cases, full T2/T4, and whole-U4 readiness remain open. A142 was not used in this lane.
