# E2 camera and picking evidence

Video captures (`.mp4`) are published on GitHub release [`media-e2-cameras-picking`](https://github.com/kingdomseed/dart-native-explore/releases/tag/media-e2-cameras-picking) per `S0f` (`docs/artifacts/README.md`); PNG screenshots and text logs are committed in this directory.

## Native iOS

The iPhone 17 Pro simulator `C24F3C6D-A3A9-4FB7-978E-36E67EF55354`
ran the example through `dn run --dart-define=DART3D_MODEL=u1`.
These are simulator results, not physical-device results.

| Evidence | Observation |
| --- | --- |
| `ios-before-camera-fix.png`, `ios-before-camera-fix.mp4` | The scene was empty despite passing startup raycast self-checks. |
| `ios-after-orbit1.png` | Corrected camera orientation frames all five targets. |
| `ios-after-picking.mp4`, `ios-tap-before.log` | Intermediate failure after camera correction. Real taps produced a one-pointer scale-start event and no tap-pick. The video filename predates that diagnosis. |
| `ios-touch-fixed.mp4`, `ios-tap-after.log` | Five actual taps select procedural, payload, d3 procedural, skinned, and instanced targets. The stack selects instance 2. Drag and pinch produce no pick; a subsequent tap selects the capsule. |
| `ios-five-targets-picked.png` | The final target label and marker show the instanced selection. |
| `ios-camera-gestures.mp4` | Three one-finger drags in each of orbit, fly, and follow modes. Mode changes use the existing camera selector. |
| `ios-{orbit,fly,follow}-gesture-{1,2,3}.png` | Nine poses captured after those drags. The labels retain the preset name used to enter each mode. |
| `ios-touch-callback-order.log` | Temporary instrumentation shows that normal taps end through scale-end, then emit tap-cancel. Drags emit tap-cancel before scale-end. The instrumentation was removed after capture. |
| `ios-cancel-forward.mp4`, `ios-cancel-forward.log` | After explicit tap-cancel forwarding, all five real target taps and a recovery tap pass. Drag and pinch emit no picks. |
| `ios-final-journey.mp4`, `ios-final-journey.log` | After the billboard and reflected-target corrections, five real target taps, drag/pinch rejection, recovery, and three gestures per camera mode pass again. |
| `ios-final-{orbit,fly,follow}-gesture-{1,2,3}.png` | Nine poses from that final rerun. |

These native checks exercise the showcase's direct gesture path. The reusable
`CameraControls` widget has no current example consumer, so its native callback
delivery remains NOT_RUN. Its correction receives source review and analysis.

## A142 Android

Jason connected and granted the Nothing A142 `00064149A002033` for this run.
Both release builds used `dn run`, `DART3D_MODEL=u1`, and an explicit backend.
Native logs confirm `VULKAN (pref=2, tier=STANDARD)` and
`OPENGL (pref=1, tier=STANDARD)`. No backend fallback was observed.
Android CLI screenshots use the tool's default status-bar stabilization,
which shows a normalized clock. Use native log timestamps for chronology.

| Backend | Feature result | Evidence |
| --- | --- | --- |
| Vulkan | Five actual target taps, including the skinned mesh and instance 2; drag/pinch rejection and recovery; three gesture poses per camera mode. | `android-vulkan-journey.mp4`, `android-vulkan-run-transcript.log`, `android-vulkan-native.log`, `android-vulkan-{orbit,fly,follow}-gesture-{1,2,3}.png` |
| OpenGL | The same five taps, rejection/recovery sequence, and nine gesture poses pass. | `android-opengl-journey.mp4`, `android-opengl-journey.log`, `android-opengl-run.log`, `android-opengl-native.log`, `android-opengl-{orbit,fly,follow}-gesture-{1,2,3}.png` |

The first Vulkan logcat filter omitted the lowercase `dartnative` tag.
`android-vulkan-run-transcript.log` is the complete recorded `dn run` output
retrieved from parent-thread item `turn-item:provider:codex:native-item:exec-08a55336-a783-4490-9fee-c48c97225e69`
at position 1895. Its line endings were normalized to LF. It includes all five
tap results and recovery. The native log independently confirms the backend;
the recording and screenshots show the interactions. The late logcat extract
contains only the final follow preset and is not the pick evidence.

OpenGL app navigation and a dice roll/settle also pass, with the real settled
readout in `android-opengl-smoke.log`, `android-opengl-dice-settled.png`, and
`android-opengl-smoke.mp4`. The OpenGL harness reaches `w18 lane complete`,
including the W25 dice-regression PASS, with no captured failure or crash.
See `android-opengl-harness-summary.log`, `android-opengl-harness-native.log`,
`android-opengl-harness-run.log`, `android-opengl-harness-crash-buffer.log`,
and `android-opengl-harness.png`. The Vulkan harness also reaches
`w18 lane complete` with W25 PASS and no captured failure or crash. Its
matching evidence uses the `android-vulkan-harness-` prefix and
`android-vulkan-harness.png`. Vulkan app navigation and dice roll/settle also
pass, with readout 94 in `android-vulkan-smoke.log`,
`android-vulkan-dice-settled.png`, and `android-vulkan-smoke.mp4`.
The logs record three automatic cocked-die nudges before settling.
Both A142 T2 smoke runs are complete. No failure, exception, or crash marker
was found in the captured native logs or process-specific crash buffers.
This does not claim full multi-device T2 completion.

Luna independently reviewed both U1/T3 videos, every gesture screenshot,
backend logs, and the transcript recovery. It found no material evidence gap
within that scope. The harness and dice smoke results above were subsequently
completed and checked by the parent; they are separate from that review verdict.

## Regression evidence

The retained before/after logs cover the undefined `filter` callback parameter,
camera matrix orientation and state synchronization, the closest-hit maximum
distance endpoint, and packed-normal Z reflection. `dart-targeted.log` records
the parent's 30-test combined camera, BVH, and raycast check before the billboard
correction.

The current tree passes 319 package tests and 225 example tests in
`package-tests.log` and `example-tests.log`. Both package analyses are clean in
`package-analyze.log` and `example-analyze.log`. These runs include the reflected
follow-target correction. `follow-reflection-parent-before.log` records the
parent's two new tests failing before the one-line correction. They pass in the
full package run. The worker's earlier full camera run used an old `camera.dart`
and failed three unrelated tests; that file was not imported into the parent.

The billboard worker's red/green evidence is retained in
`billboard-before-test.log` and `billboard-final-tests.log`.
Its cases cover all three facing modes, parent rotation, explicit camera
overrides, translation-only instance centers, and broad-phase instance bounds.
Billboard native picking is NOT_RUN.

## Open gates

- A142 Vulkan/OpenGL U1 feature checks and T2 app/dice/harness smoke pass. Fire, Wacom, and iOS T2 app/dice/harness smoke have not been rerun in this correction pass. The iOS U1 feature checks above are complete.
- Camera writes support parent-relative matrices representable as translation, rotation, and scale. Singular parents and required local shear return false without mutation. Arbitrary shear remains unsupported by the existing cross-platform mutation contract.
- Picking uses authored document transforms and rest-pose skinning. It does not promise native evaluated animation or morph poses.
- V6f remains incomplete. The current frame notification does not implement upstream's callback before every fixed physics step. The current SceneKit path has no supported per-step callback.
- The installed DartNative SDK exposes no keyboard-event, pointer-wheel, or hover API for this widget. Those input paths remain unsupported.
- Explicit `onTapCancel` clears pending presses. Cancellation completeness remains open because `onScaleEnd` also represents cancellation and its details contain no cancellation flag. The native sequence proves ordinary taps, drag/pinch rejection, and recovery only.
- Billboard picks now use camera context and oriented hit transforms. Luna's source review found no material issue in that delta and no actionable new comment issue. Native rotated non-square footprints differ between [iOS](../../../dart3d/ios/Classes/GeometryFactory.swift#L1051) and [Android](../../../dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/MeshFactory.kt#L1576). Their scaled-parent camera bases also differ. [iOS normalizes each inverse-transformed axis](../../../dart3d/ios/Classes/SceneViewHost.swift#L5085); [Android passes those axes without normalization](../../../dart3d/android/src/main/kotlin/com/jasonholtdigital/dart3d/Dart3dView.kt#L5030). This correction does not change those native renderers.
- Reflected follow targets use canonical signed-X rotation extraction. The correction passes its direct-target and reflected-parent regressions. Luna's second source review found no new actionable issue in that delta. It does not promise to recover the authored quaternion for reflections on other axes.

No commit, push, merge, or external tracker update was made.
The owned app, log session, and simulator were stopped after verification;
`simulator-shutdown.log` shows no booted simulator. The integration worktree,
worker worktrees, snapshot archive, patches, and before/after evidence remain
available because the work has not landed.
The A142 verification app and log sessions were also stopped. The phone
remains powered on at its launcher with the verification build installed.

## Decision trail

`.audit/e2-resume-decisions.tsv` is append-only. Its `ts` column records when
each row was logged. The first ten decisions were recorded together after
their actions, so their shared timestamp is not their decision time.
The audit's citation and wording corrections are appended as new rows.
In particular, “gesture cancellation” in the early row means the observed
drag/pinch rejection and tap recovery. Full cancellation semantics remain open.

Luna reviewed the trail against artifacts and the parent thread. The test,
review-verdict, packed-normal, pose-manifest, and native-source pointers were
supplemented after that review. Earlier parent reruns of 13 and 22 tests are
recorded at positions 1352 and 1390 of [the parent thread](t3-thread://v1/c28a3742-2f96-4105-850a-f3cbfd0e3441).
The final suite logs above establish the current integrated result.
