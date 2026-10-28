Host checks passed on the four-file control over actual runtime70. Runtime was not run. Commands below used this worktree; SDK/destination selection is compile-only, with no simulator boot, device discovery, install or launch.

From `dart3d/`:

```sh
/Users/jasonholt/zero/bin/dn pub get
/Users/jasonholt/zero/bin/dn test test/u3_node_highlights_test.dart
```

`pub-get-package-correct-cwd.log` exit0; `tests-highlights.log` exit0, 13 tests.

From `dart3d/example/`:

```sh
/Users/jasonholt/zero/bin/dn pub get
/Users/jasonholt/zero/bin/dn analyze
/Users/jasonholt/zero/bin/dn test test/u3_outline_views_test.dart test/w34_debug_scene_test.dart
/Users/jasonholt/zero/bin/dn build ios --simulator --debug --config-only --no-codesign --target lib/u3_outline_views_main.dart --dart-define=DART3D_U3_OUTLINE_MODE=off --dart-define=DART3D_U3_OUTLINE_PUBLISH_IN_UPDATE=true
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build/u3-outline-publication-derived ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO FLUTTER_ROOT=/Users/jasonholt/zero FLUTTER_APPLICATION_PATH=/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-b38c6b48/dart3d/example FLUTTER_TARGET=lib/u3_outline_views_main.dart FLUTTER_BUILD_DIR=build build
/Users/jasonholt/zero/bin/dn build ios --simulator --debug --config-only --no-codesign --target lib/main.dart
```

`pub-get-example.log`, `analyze-example.log`, `tests-example-final.log`, `configure-control.log`, `generic-arm64-control-build.log`, `restore-normal-main.log`: exit0. Analysis has no issues; tests pass23 (9 outline fixture tests, 14 W34 tests). The two added selector cases use real controller load/transform/highlight/render mutations, verify all non-selector loaded scene fields unchanged after normalizing independently generated document identity, preserve selector through every mode, and observe no implicit render mutation. The existing seven outline tests retain the target/camera/layer/geometry/public-path checks. These are wire/controller tests, not SceneKit runtime tests.

The generic app build reports BUILD SUCCEEDED and includes the probe Swift file. Existing warnings include the shipped engine's simulator minimum version versus project deployment target, missing Metal-toolchain Swift library search path, and skipped AppIntents metadata without that dependency. No SDK/pin change was made. Embedded Metal strings were not runtime compiled or executed. Configuration restoration is recorded without secret values in normal-main-receipt.json.

From worktree root:

```sh
xcrun --sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios15.0-simulator -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk dart3d/ios/Classes/*.swift
/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart format dart3d/example/lib/u3_outline_views_main.dart dart3d/example/lib/u3_outline_views_scene.dart dart3d/example/test/u3_outline_views_test.dart
git diff --check
```

Full-plugin14-source typecheck exit0, empty swift-typecheck-final.log. Formatting completed and diff check exit0. Formatting uses dn's sibling SDK Dart; all DartNative analysis/test/build commands use dn. Tests required pub-get initialization because neither package had .dart_tool; every six-lock hash remained unchanged. Own generated outputs were removed after verification, retaining only normalized ignored Generated.xcconfig and dn_export_environment.sh.

Offline evidence and patch replay:

```sh
uv run --no-project python /private/tmp/dart3d-u3-outline-publication-diagnosis-20261028/r1/worker/recompute.py
uv run --no-project python /private/tmp/dart3d-u3-outline-publication-diagnosis-20261028/r1/worker/replay.py
```

Both exit0. The replay uses a plain temporary archive tree, no git checkout, no children and no parent writes. It verifies all70 before/forward/reverse entries and the final70-control archive. Removed scratch is recorded in replay-receipt.json and removed-own-generated-files.json.

Corrected local checking failures are retained accurately:

- Initial `dn pub get` from repo root reported `Expected to find project root in current working directory.` Rerunning the underlying dn command directly from dart3d succeeded. An auxiliary source search also used a package-relative cwd with a root-relative path and was repeated from root.
- The first independent console-byte reconstruction encountered a non-ASCII ellipsis in a truncated mask log row. Complete mask files are available and hash-verified; recomputation now records that limitation rather than manufacturing bytes. All23 complete four-byte textures reconstruct exactly from the native log; all six half-float mask rows are checked from the hashed raw files.
- The first added comparison tests failed on randomly generated `documentId` values from two separately built documents. The serialized scene codec was inspected; the test normalizes that independent identity and the intentional marker transform before comparing the complete wire scene. Both selector cases and all23 final tests pass. No production code changed for this test correction.
- Apple's linked Markdown endpoint returned web-tool `Unsupported content-type: text/markdown`; the relevant callback text was retrieved through Apple's indexed documentation, and the same contract is explicit in the installed SCNSceneRenderer.h. This did not block source grounding.

Logs retain command diagnostics, with build-define environment lines/any literal license removed only from our log copies. log-sanitization.json records counts. No supplied or generated config secret was deleted, rotated or changed.

NOT_RUN: controlled runtime, GPU, runtime Metal compilation/execution, current-selection correction, devices/discovery, Android/A142, production, performance, whole U3, T2/T4, moving alignment, MSAA runtime, W34 coexistence, reduced scale and retirement. Parent owns runtime and final independent review.
