# Host checks and corrected failures

All commands ran in this worktree. No simulator/device command was run; `iphonesimulator` below selects a compile SDK or generic build destination only.

## Passing checks

From `dart3d/`:

```sh
/Users/jasonholt/zero/bin/dn pub get
/Users/jasonholt/zero/bin/dn analyze
/Users/jasonholt/zero/bin/dn test test/u3_node_highlights_test.dart
```

Analysis: no issues. Highlights: 13 tests. Locks unchanged.

From `dart3d/example/`:

```sh
/Users/jasonholt/zero/bin/dn pub get
/Users/jasonholt/zero/bin/dn analyze
/Users/jasonholt/zero/bin/dn test test/u3_outline_views_test.dart test/w34_debug_scene_test.dart
/Users/jasonholt/zero/bin/dn build ios --simulator --debug --config-only --no-codesign \
  --target lib/u3_outline_views_main.dart --dart-define=DART3D_U3_OUTLINE_MODE=off
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/u3-outline-views-derived ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO FLUTTER_ROOT=/Users/jasonholt/zero \
  FLUTTER_APPLICATION_PATH=/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-886b3c86/dart3d/example \
  FLUTTER_TARGET=lib/u3_outline_views_main.dart FLUTTER_BUILD_DIR=build build
/Users/jasonholt/zero/bin/dn build ios --simulator --debug --config-only --no-codesign --target lib/main.dart
```

Analysis: no issues. Example tests: 21 (7 new fixture tests +14 existing W34). Generic simulator build: BUILD SUCCEEDED, arm64 Debug, no signing, no launch. The built Info.plist identifies `com.jasonholtdigital.dart3dExample`. Normal-main restoration: `DN_TARGET=lib/main.dart`, no outline defines, SDK license retained. Both pub-get calls were necessary because neither package had `.dart_tool`; no dependency upgrade was requested/performed and all six lock/generated-source hashes stayed unchanged.

From worktree root, all 14 plugin Swift sources:

```sh
xcrun --sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios15.0-simulator \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk \
  dart3d/ios/Classes/*.swift
```

Final typecheck: exit0, empty diagnostics. Installed build SDK was iPhoneSimulator27.1. `git diff --check` also passed. Compiler validation does not execute the runtime Metal source strings or establish any GPU/view behavior.

Build warnings retained: linker search path for installed Metal-toolchain Swift libraries absent; shipped Flutter engine built for newer iOS18.5 while project links for simulator16.0; no AppIntents dependency, so metadata extraction skipped. These warnings did not fail the generic build. No SDK/pin/project change was made for them.

## Corrected failures and exact receipts

- Initial shell reads used package-relative source paths from the example cwd and failed with `No such file or directory`. The underlying reads were repeated from the worktree root. This was a caller cwd error, not missing imported source.
- `analyze-fixture-1.log`: analyzer invoked from the root with example-relative arguments: `You provided the path .../lib/u3_outline_views_main.dart, however it does not exist on disk`. Reran the actual dn command from the example directory.
- `analyze-fixture-2.log`: `The getter 'local' isn't defined for the type 'LocalId'` and `The named parameter 'antiAliasing' isn't defined`. Checked installed API and corrected to `LocalId.index` and `antiAliasingMode`. Full final analysis passes.
- `tests-example-1.log`: first test invocation from the root failed because no pubspec was found. Reran the underlying `dn test` directly in the example directory.
- `tests-example-2.log`: `Member not found: 'unskinnedStride'`. Corrected to the installed `unskinnedUv1TangentStride` constant; no production seam was added.
- `tests-example-3.log`: public Vector4 transport correctly serialized float32 decimals, e.g. `0.20000000298023224` instead of a test's literal `0.2`. Switched the fixture colors and expected wire values to exactly representable `.25/.0625/.5`, retaining orange/blue and alpha0/.5 coverage cases. The animation assertion also incorrectly expected `id`; the real public wire field is `anim`. Corrected that expectation. `tests-example-final.log` passes all 21 tests.
- `generic-simulator-build-1.log`: existing Runner scheme has a legacy Flutter pre-action and a DartNative pre-action. The legacy action failed: `/bin/sh: /packages/flutter_tools/bin/xcode_backend.sh: No such file or directory`. Reran that exact underlying shell command directly; exit127 with the same line. Supplied the installed Zero SDK through command-line `FLUTTER_ROOT`, application path, target and build-dir settings for that action; build2 and final build succeed. No SDK or scheme source edit was made. This is not a claim that a third-party tool is broken.
- An intermediate local edit script stopped with `ValueError: substring not found`; the subsequent patch attempt reported `Failed to find expected lines`. Both concerned inserting the Rebind button and left that file unchanged. The insertion was then applied against the actual button block, formatted, analyzed and tested.
- Initial archive replay used git apply inside a nested directory. Git returned0 but silently skipped repository-relative paths. The full forward-file comparison failed with `AssertionError: forward`; no pass was recorded. Repeated plain archive replay with `GIT_CEILING_DIRECTORIES` preventing ancestor repository discovery. Forward70/reverse66 hashes now all match. The replay tree was removed.

The initial and final Swift typechecks were clean. Earlier successful host checks were repeated only after source changes warranted them. The final native screen-observation addition was typechecked and included in the final generic app build; Dart sources were unchanged after their final tests/analysis.

Xcode environment exports are omitted from delivered build logs to keep them readable; commands and diagnostics remain exact. SDK license defines are redacted from our logs only. `log-sanitization.json` records omissions. No supplied/generated secret was deleted, rotated or edited in configuration.

NOT_RUN: device discovery/boot/install/run, Metal runtime shader compilation/execution, GPU/readback outcomes, per-view correctness, screen ordering, moving alignment, W34 runtime coexistence, retirement safety, Android, performance, production integration and whole U3.
