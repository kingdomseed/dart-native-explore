# E4 character-controller evidence

E4 is in progress. The inherited implementation is based on E3 merge `6366c07`.
The current SDK is DartNative 1.4.0, framework `75bc07e9b49`.

## Native compilation

`android-compile-before.log` reproduces four unresolved `Body.cInvalidBodyId` references.
The installed jolt-jni 6.0.0 API declares the constant on `Jolt`.
After changing those four references, the parent checkout's
`:dart3d:testReleaseUnitTest` succeeds in `android-parent-compile-after.log`.
This proves compilation and the existing native unit suite, not character movement correctness.

## Inherited movement

`ios-inherited-run.log` records an iPhone 17 Pro simulator run before the movement corrections.
The walking capsule reaches X=-1.45, climbs to Y=0.91, pushes the crate to X=1.21,
reports slope sliding, and finishes the jump grounded.
`ios-inherited-final.png` shows the final scene.
The corresponding recording remains at `/private/tmp/dart3d-e4-resume-20261025/ios-before.mp4`.

`android-inherited-vulkan-run.log` and `android-inherited-vulkan-native.log`
record the same initial journey on A142 after the compile correction.
The native log confirms Vulkan. The capsule climbs the step, pushes the crate,
reports slope sliding, and finishes grounded.
The recording remains at `/private/tmp/dart3d-e4-resume-20261025/android-inherited-vulkan.mp4`.
Android recorded 66.7 seconds of the 104.7-second window because screenrecord
encodes frames only when the screen changes.

The recorded inherited stage messages print PASS unconditionally.
Their numeric values and recordings are observations; their status words are not an acceptance result.
Five Android corrections pass the native regression suite. The approved native
extension also passes the previously failing minimum-width regression.
Stage checks now compare the returned poses, grounded state, crate movement,
slope flag, and jump peak with the fixture's expected outcomes.
They also verify a public transform write through overlap queries and ten seconds of grounding.

## iOS curb correction

`ios-conditional-run.log` records the capsule stopping at X=-1.52 and leaving the crate at X=0.45.
`ios-curb-probe-native.log` shows the character's own body hiding external landing contacts.
`ios-curb-self-mask-native.log` shows the next issue after excluding that body from queries.
The min-width lookahead finds walkable support, but the curved curb-edge contact fails the old landing-normal threshold.

The correction excludes the querying body until the synchronous pre-step query returns,
then restores its authored category. A bounded stair can use its validated walkable support for grounding.
The maximum climb height, minimum-width lookahead, dynamic-body exclusion, and requested travel bound remain in the code.

`ios-curb-fixed-run.log` records two complete passing journeys, one cold launch and one hot restart.
Each passes walking, stepping, pushing, slope sliding, jumping and landing,
the public transform-overlap check, and ten seconds of stable grounding.
`ios-curb-fixed-final.png` shows the final scene after the transform check.
`ios-curb-fixed-source.sha256` identifies the Swift source that ran.
The recording is `/private/tmp/dart3d-e4-resume-20261025/ios-curb-fixed.mp4`.
Temporary diagnostic logging was removed before these runs.
`ios-curb-before.png` is the frame at 3.2 seconds of `ios-conditional-replay.mp4`.
`ios-curb-after.png` is the frame at 28.5 seconds of `ios-curb-fixed.mp4`.
The green capsule is blocked beside the step in the first frame and stands on it in the second.

Both current Dart analyses are clean. `package-tests.log` records 328 passing tests,
and `example-tests.log` records 228 passing tests.

## iOS regression checks

`ios-harness-run.log` reaches `w18 lane complete` and the W25 dice regression PASS.
`ios-harness.png` shows the final fixture.
`ios-smoke-run.log` records a real roll from the hero screen to the dice table,
with settled readout 55. `ios-hero.png` and `ios-dice-settled.png` show those screens.
These checks use the inherited iOS native implementation; the remaining reviewed
engine corrections affect Android.

The current-source rerun in `ios-harness-final-run.log` also reaches W25 PASS
and `w18 lane complete`; `ios-harness-final.png` shows its final fixture.
`ios-smoke-final-run.log` records hero navigation, a real roll, and settled
readout 48. A later watchdog timeout reports the same readout 48.
`ios-hero-final.png` and `ios-dice-final.png` show those screens.
The owned simulator run was stopped and the simulator shut down afterward.

## Android landing width and teardown

The parent imported the native extension and verified all 18 manifest checksums.
`android-native-width-parent.log` and `android-native-width-parent-xml/` record
150 passing tests across 18 suites, with no failures, errors, or skips.
The narrow-landing baseline failures remain in `native-width-expanded-before.xml`.
Independent Codex source reviews found no material findings in the extension
or the current Dart/iOS controller paths. Neither review substitutes for device checks.

`android-vulkan-final-run.log` records a passing A142 Vulkan character journey
with the packaged extension. `android-vulkan-final.png` shows its final scene.
Navigation back to the hero then crashed. The native stack in
`android-vulkan-navigation-crash.log` shows a delayed character destructor
calling `BodyInterface::RemoveBody` after its mutex was destroyed.

The correction closes both owning character aliases before the physics system.
The pinned API JAR closes the collision collector's removed reference, and the
contact-validation callback closes its temporary `characterB` wrapper.
`character-teardown-before.log` and `character-teardown-after-simple.log` show
that fixing only the collector still leaves the contact alias alive.
`android-teardown-parent-tests.log` and `android-teardown-parent-xml/` record
151 passing native tests with no skips, plus a passing duplicate-class check.
The native libraries remain unchanged. `android-teardown-fixed-source.sha256`
identifies the Kotlin source and API JAR used by the repaired device build.
Independent Codex review found no material issue in this lifecycle delta.

The repaired character journeys pass on A142 Vulkan, A142 OpenGL, and Fire.
Each includes walking, stepping, pushing, slope sliding, jumping and landing,
the public transform-overlap check, and ten seconds of stable grounding.
Each then returns to the hero and completes a real dice roll and settle.

| Device | Run log | Hero and settled dice | Readout |
|---|---|---|---|
| A142 Vulkan | `android-vulkan-teardown-fixed-run.log` | `android-vulkan-hero-fixed.png`, `android-vulkan-dice-fixed.png` | 119 |
| A142 OpenGL | `android-opengl-final-run.log` | `android-opengl-hero.png`, `android-opengl-dice.png` | 41 |
| Fire OpenGL | `fire-character-final-run.log` | `fire-hero-final.png`, `fire-dice-final.png` | 39 |
| Wacom OpenGL | `wacom-character-run.log` | `wacom-hero.png`, `wacom-dice.png` | 103 |

The corresponding process-scoped native logs confirm the requested backends and
contain no fatal crash markers. The Fire log includes a deferred licence-server
lookup failure; the app remains running and completes the checks.
Vulkan and Fire recordings remain in `/private/tmp/dart3d-e4-resume-20261025/`
as `android-vulkan-teardown-fixed.mp4` and `fire-character-final.mp4`.

[The published A142 review clip](https://github.com/kingdomseed/dart-native-explore/releases/download/media-e4-character-controller/e4-character-review.mp4)
covers source seconds 22–82, from character movement through navigation and
dice settling. Only recorder letterboxing is cropped; timing is unchanged.
`review-video.json` records the source and output hashes and the crop.

## Device matrix

- A142 Vulkan and OpenGL, Fire, and current-source iOS harnesses reach W25 PASS and W18 completion in their `*-harness-final-run.log` files, with matching screenshots.
- The repeated Vulkan run also reaches both completion markers in `android-vulkan-harness-live-run.log`; its live native capture retains `VULKAN (pref=2)` selection and has no fatal markers.
- Wacom completes W25 PASS and W18 in `wacom-harness-run.log`. Its live native log confirms `OPENGL (pref=1, tier=LOW)` and contains no fatal markers. `wacom-harness.png` shows the final fixture.

The Wacom reports Android 16 / API 36. Before app launch, its rotation values
were `accelerometer_rotation=1` and `user_rotation=0`, differing from the older
device guide. Matching before/after files confirm those values were preserved.
The optional Wacom recording did not export. After the failed stop/close
attempts, a close retry succeeded. The recording resource and both owned
native paths were verified absent. `wacom-recording-export.txt` records that
limit; its screenshots and complete run logs remain the tablet evidence.

## Remaining gates

- `ci-implementation-head.json` records passing Dart, Android unit, and security checks at implementation commit `6a63b24`. Current-head checks are shown on the PR.
- Operator review of the screenshots remains pending.

[PR #64](https://github.com/kingdomseed/dart-native-explore/pull/64) is draft.
E4 has not merged.
