# E4 landing-width blocker

No bounded correct implementation found within the plain-Kotlin/Jolt-JNI 6 scope. No production change exported. The failing width assertion remains enabled and unchanged.

## Reproduced result

Imported tracked.patch, untracked.tgz, compile-only.patch, android-six-fix.patch in the requested order at 6366c07. Removed the Ignore import and annotation, then saved both owned files in astra-baseline/.

Both astra-before.xml and astra-after.xml report 10 tests, 1 failure, 0 errors, 0 skipped. Nine tests pass, including the wide-landing distance test and the five inherited fixes' regressions. The width failure remains `climbed with less than 0.1m of clearance [0.099999905, 0.6694428, -9.9341E-8]`. After means restored baseline, not a successful fix.

Ran from this isolated checkout's dart3d/example/android with FLUTTER_STORAGE_BASE_URL=https://cdn.dartnative.com and the cached Gradle 9.3.1 executable, --init-script /private/tmp/dart3d-e4-resume-20261025/sol-native.init.gradle :dart3d:testReleaseUnitTest --tests '*CharacterControllerNativeTest'. Native library was the supplied MacARM library. Logs are astra-before.log and astra-after.log.

## API and source evidence

astra-javap.txt records the installed 6.0.0 jar's CharacterVirtual, CharacterBase, CharacterContact, NarrowPhaseQuery, CustomCharacterContactListener, ExtendedUpdateSettings and ShapeCastSettings APIs. No Update, WalkStairs or StickToFloor entry points, stair-candidate result, or stair-acceptance callback are exposed.

Authoritative source is https://raw.githubusercontent.com/stephengold/JoltPhysics/sg260728/Jolt/Physics/Character/CharacterVirtual.cpp, saved as astra-CharacterVirtual-sg260728.cpp. File line numbers below refer to that saved file.

- Lines 1710-1753 run the forward support test only when the first landing is too steep. Flat landings bypass it.
- Lines 1617-1653 clamp upward motion against overhead geometry and solve horizontal movement through MoveShape. A cast from requested endpoint plus maximum step height is not the computed landing.
- Lines 1691-1697 calculate the final landing from the actual horizontal result and downward contact fraction.
- Lines 216-238 construct CharacterContact with the point on the obstacle. It is not the character's candidate transform. The validation callback lacks the cast origin and displacement.
- Lines 1512-1519 set the character position before ContactAdded. ContactAdded may also be suppressed for a body/subshape already notified during this update.
- Lines 1812-1829 perform ordinary Update before reading stair enablement. That explains why the existing early dynamic-blocker cancellation works.

## Callback experiment

Temporarily logged onContactValidate/onContactAdded and set walkStairsStepUp to zero on upward-facing fractional sweep contacts. The two stair tests still produced one pass and the original width failure. At the downward landing validation, both fixtures reported the character at x=0.0600000061, y=0.4999999702, while the final result was x=0.099999905, y=0.6694428. The contact point was x=0.3466666341, y=0.1872677803, z=0.1999998093, fraction=0.43519068. These are different quantities. Changing extended settings at this stage does not cancel WalkStairs, whose arguments and local up vector are already captured.

The experiment patch, log, and XML are astra-callback-probe.patch, astra-callback-probe.log, and astra-callback-probe.xml. The patch is diagnostic evidence only and must not be integrated. It has been removed from the checkout.

## Missing capability and rejected approximation

The minimal missing capability is a stair-specific acceptance decision with the actual candidate character pose and travel direction available before MoveToContact, allowing rejection of that stair attempt while retaining ordinary movement. Existing contact validation can reject collision contacts, but cannot identify a completed stair candidate or veto the stair as an operation. Exposing WalkStairs alone would still commit before a Kotlin post-check.

NarrowPhaseQuery can check clearance at a supplied pose without movement impulses. It does not supply the missing pose. Predicting it independently requires reproducing Jolt's upward clipping, MoveShape sliding/contact solution, downward sweep, padding, and character collision behavior. A maximum-height or requested-endpoint guard would be an approximation, particularly under low overhead and oblique contacts. I did not implement that workaround, clone/replay a controller, or clip the final position.

This is a bounded engineering blocker, not a proof that no more elaborate Kotlin algorithm could exist. Low-overhead runtime controls and device/public-path verification are NOT_RUN. No shipping dependency or native binding changes were made.

## Handoff

Both owned files are byte-identical to astra-baseline/. width-astra-only.patch is intentionally zero bytes. No parent checkout writes, commits, pushes, PRs, subdelegation or device actions occurred. The temporary SDK local.properties was removed. No Gradle launcher was created. dn pub get generated dn_plugins.lock, retained under the generated-file preservation instruction and excluded from the owned-file export. Imported Gradle configuration and all other inherited changes remain intact. Ignored dependency/build outputs remain for reproducibility. Evidence files in this directory and baseline copies are retained deliberately.

The Fix Root Causes principle ruled out a clearance guard whose origin is not the actual landing. The source and runtime evidence do not support declaring this item resolved.
