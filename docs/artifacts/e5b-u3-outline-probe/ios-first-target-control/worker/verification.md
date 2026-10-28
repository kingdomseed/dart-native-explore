All commands ran in the disposable worker checkout. No simulator or device operation was used. SDK and generic destination flags below are compile-only.

From dart3d/:

```sh
/Users/jasonholt/zero/bin/dn pub get
/Users/jasonholt/zero/bin/dn test test/u3_node_highlights_test.dart
```

Both exit zero. tests-highlights.log records 13 passing tests.

From dart3d/example/:

```sh
/Users/jasonholt/zero/bin/dn pub get
/Users/jasonholt/zero/bin/dn analyze
/Users/jasonholt/zero/bin/dn test test/u3_outline_views_test.dart test/w34_debug_scene_test.dart
/Users/jasonholt/zero/bin/dn build ios --simulator --debug --config-only --no-codesign --target lib/u3_outline_views_main.dart --dart-define=DART3D_U3_OUTLINE_MODE=off --dart-define=DART3D_U3_OUTLINE_PUBLISH_IN_UPDATE=true --dart-define=DART3D_U3_OUTLINE_BIND_BEFORE_INSTALL=true
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/u3-outline-first-target-derived ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO FLUTTER_ROOT=/Users/jasonholt/zero FLUTTER_APPLICATION_PATH=/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-f04b045f/dart3d/example FLUTTER_TARGET=lib/u3_outline_views_main.dart FLUTTER_BUILD_DIR=build build
/Users/jasonholt/zero/bin/dn build ios --simulator --debug --config-only --no-codesign --target lib/main.dart
```

Every command exits zero. Logs are pub-get-example.log, analyze-example.log, tests-example.log, configure-control.log, generic-arm64-control-build.log and restore-normal-main.log. Analysis has no issues and all 25 fixture/W34 tests pass. The generic app build includes the probe Swift source. Config-only setup runs the existing pod install with unchanged Podfile.lock. The build warnings are summarized in report.md.

From the checkout root:

```sh
xcrun --sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios15.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk dart3d/ios/Classes/*.swift
/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart format dart3d/example/lib/u3_outline_views_main.dart dart3d/example/lib/u3_outline_views_scene.dart dart3d/example/test/u3_outline_views_test.dart
git diff --check
```

All exit zero. swift-typecheck.log is empty. Formatter reports three files and zero changes. The full 14-source plugin is typechecked; embedded runtime Metal strings are not executed.

Offline checks:

```sh
uv run --no-project python /private/tmp/dart3d-u3-outline-first-target-diagnosis-20261028/r1/worker/recompute.py
uv run --no-project python /private/tmp/dart3d-u3-outline-first-target-diagnosis-20261028/r1/worker/package.py
uv run --no-project python /private/tmp/dart3d-u3-outline-first-target-diagnosis-20261028/r1/worker/cleanup.py
```

All exit zero. Recompute uses Python standard libraries and the already installed ffmpeg for screen decoding. No new dependency was installed. Video commands and exits are retained in independent-video-receipts.json. Full original videos are only read; no frame timings are treated as latency or performance.

Source and compilation PASS. Supplied prior runtime evidence independently recomputed. New control native/GPU/runtime/performance NOT_RUN. Parent owns those lanes.
