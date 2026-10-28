# Throwaway E9/W34 authored-file reload prototype

Prepared in `/Users/jasonholt/.t3/worktrees/dart-native-explore/t3-da4b87a5` at HEAD `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. No commits, pushes, external changes, devices, simulator boots, launches, or child agents.

Imported production52 from `/private/tmp/dart3d-e5b-outline-state-current-20261027/r1/parent-source.tgz`. SHA256 `646f5d269a78020fb588ea420fb2783ea9d5a998e6b8019fd8885ad365726f2d`. All 52 manifest paths verified before editing. No native U3 evidence probe appears in this archive or this checkout's iOS source paths. Accepted U3/U4 sources are preserved.

`probe.patch` is relative to that imported baseline, not HEAD. `owned-source.tgz` contains exactly the five owned Dart files. Verify using `artifact-sha256.txt` and `owned-source-sha256.txt`. Apply only after the same production52 import. The patch includes no renderer, shader, protocol, package, lock, or registrant edits.

The probe is added to the roster only when compiled with `DART3D_MODEL=w34-reload-probe`. It requires a nonempty absolute `.fscene` caller path. It watches that file's parent directory with `dart:io`, filters events to the caller file or move destination, and synchronously reads that file on actual events. There is no debounce, retry, transport, fallback directory, registry, or custom diff. Directory watching is intended to retain observation through rename saves; actual simulator save behavior is NOT_RUN. Read/watch errors are logged in full. The existing two-line showcase footer displays current-file status or the error.

The first successfully parsed file calls `SceneController.loadDocument`. Subsequent valid files call `diffScene` and `SceneController.applyDiff`. A parse/read error does not mutate the controller or replace the last valid document. A later actual event can recover. The watch is canceled on showcase item change and screen disposal.

The fixture builder lives in the host tool so standalone Dart imports only the existing pure model, serializer, and parser, with no DartNative widget import. The native probe and host tool use the same existing parser. IDs are deterministic. The fixture has a fixed camera at `(0,0,-7)`, a rotated lit cuboid, one material, and an existing `EnvironmentResource` with linear tone mapping and exposure 1. The authored saves never edit the camera or node IDs.

The installed SDK's `lib/io/file_system_entity.dart:430-469` documents platform-dependent event ordering/coalescing and subscription timing. Event counts are not assumed. Native iOS `FsceneRealizer.swift:6916` reads environment exposure; `SceneViewHost.swift:366` applies it to the camera. This is source evidence that exposure is supported, not proof that this fixture renders or changes visibly.

## Parent run and save commands

Run in the parent checkout after importing the five source files, from its `dart3d/example` directory. Existing `.dart_tool/package_config.json` resolution is required. If it is missing, use `/Users/jasonholt/zero/bin/dn pub get`. No dependencies or pins were added.

```sh
/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart --packages=.dart_tool/package_config.json tool/w34_reload_source.dart initial /private/tmp/dart3d-e9-reload-probe-20261027/r1/authored.fscene
```

The following command is parent-owned and was NOT_RUN. Replace the device placeholder with the parent's currently approved iPhone17Pro simulator UUID.

```sh
/Users/jasonholt/zero/bin/dn run --debug -d <parent-confirmed-iPhone17Pro-UUID> --dart-define=DART3D_MODEL=w34-reload-probe --dart-define=DART3D_RELOAD_SOURCE=/private/tmp/dart3d-e9-reload-probe-20261027/r1/authored.fscene
```

Capture the initial visible state and logs before each next save. Run each save separately after observing the previous result.

```sh
/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart --packages=.dart_tool/package_config.json tool/w34_reload_source.dart material /private/tmp/dart3d-e9-reload-probe-20261027/r1/authored.fscene
/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart --packages=.dart_tool/package_config.json tool/w34_reload_source.dart environment /private/tmp/dart3d-e9-reload-probe-20261027/r1/authored.fscene
/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart --packages=.dart_tool/package_config.json tool/w34_reload_source.dart baseline /private/tmp/dart3d-e9-reload-probe-20261027/r1/authored.fscene
```

The host tool validates the caller path to a direct `.fscene` child of this task's `/private/tmp/dart3d-e9-reload-probe-20261027/r1/` pickup. It writes in place with `writeAsStringSync(..., flush: true)`. It does not create directories. The host sequence was executed successfully in this checkout. `authored.fscene` is left at baseline.

## Literal expected controller behavior

These operation sequences were observed and asserted through the actual controller and a recording SceneViewElement in host tests. They are requests to native code, not render acknowledgments.

- Initial parsed baseline emits `loadScene`. This fixture has no payload chunks.
- Material save changes only `w34.color.baseColor` from RGBA `[0.7,0.08,0.03,1]` to `[0.03,0.15,0.7,1]`. The public diff emits `[upsertResource, updateNode]`. The existing diff includes the mesh consumer update for its changed material.
- Environment save retains blue and changes only the existing `w34.environment.exposure` from `1` to `0.2`. The diff emits `[upsertResource, updateStage]`.
- Baseline save restores red and exposure 1. The diff emits `[upsertResource, upsertResource, updateNode, updateStage]`.
- Duplicate/coalesced file events may read the same file again and log `ops=[]`. They must not cause a second `loadScene`.
- Malformed/incomplete input logs the actual parse error, emits no controller mutations, and leaves the last valid scene visible. A valid later event resumes the diff path.

Expected visible sequence for parent proof is red cuboid, blue cuboid, darker blue cuboid, red cuboid. Appearance is NOT_RUN. If file access or watch support fails, capture the actual error and stop that experiment. No transport workaround is included or authorized here. A missing event is evidence about the tested save strategy, not a reason to add a timer.

Each successful application logs `w34 applied-request time=... source=... ops=[...]`. This is the request time after controller dispatch. It proves neither first rendered frame nor latency. There is no unconditional PASS log.

## Verification

- `focused-tests.log` records 2 real-file/controller tests. The tests exercise actual file events, native-bound command bytes through a recording element, incremental material/environment saves, malformed-input retention, valid recovery, unchanged camera, cancellation, and explicit path errors.
- `regressions.log` records 49 passing tests across the new probe and all seven supplied U3/U4 showcase test files.
- `analysis.log` records clean `dn analyze` for the example, including the imported library source.
- `ios-build.log` records `** BUILD SUCCEEDED **` for the generic arm64 simulator build with the two probe defines configured. License text/encoded license define in this log is redacted. The generated configuration and existing configured credential were left unchanged.
- `import-check.log` records all 52 source checksums before editing.
- `replay-verification.log` records forward apply/check, exact five-file hashes, reverse apply/check, restoration of all 52 imported paths, and removal of all three new probe files in disposable replay scratch.
- `unowned-preservation.log` records 1,926 unchanged unowned baseline file hashes. Final git status adds exactly the three owned additions to the imported status. The two edited showcase files were already modified by production52.
- `diff-check.log` is empty after successful `git diff --check`.

Commands used from `dart3d/example`:

```sh
/Users/jasonholt/zero/bin/dn analyze
/Users/jasonholt/zero/bin/dn test test/w34_reload_probe_test.dart
/Users/jasonholt/zero/bin/dn test test/w34_reload_probe_test.dart test/u3_atlas_probe_test.dart test/u3_sprite_showcase_test.dart test/u3_tone_showcase_test.dart test/u4_material_showcase_test.dart test/u4_owner_showcase_test.dart test/u4_showcase_test.dart test/u4_snapshot_showcase_test.dart
/Users/jasonholt/zero/bin/dn build ios --simulator --debug --config-only --dart-define=DART3D_MODEL=w34-reload-probe --dart-define=DART3D_RELOAD_SOURCE=/private/tmp/dart3d-e9-reload-probe-20261027/r1/authored.fscene
```

From `dart3d/example/ios`, without booting or running:

```sh
FLUTTER_ROOT=/Users/jasonholt/zero xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator -derivedDataPath /private/tmp/dart3d-e9-reload-probe-20261027/r1/DerivedData ARCHS=arm64 IPHONEOS_DEPLOYMENT_TARGET=15.0 CODE_SIGNING_ALLOWED=NO build
```

Retained generated outputs are listed in `generated-outputs.txt`. No tracked lock or registrant changed. No project pins changed. Replay scratch and superseded editing scripts were removed. `package.dart` and `sanitize-build-log.dart` are retained as evidence reproduction tools.

Simulator host-file access, simulator watch behavior, actual scene appearance, runtime reload, T2/T3/T4, render latency, Android transport, and performance are NOT_RUN. This is not E9 completion. The current v2 gate supersedes the old W34 ten-lane execution text. Debug views are not implemented here. Scene.debug/split/per-node/collider work stays V6e, and shader hot reload stays E6. The parent must remove this throwaway probe after runtime proof before designing production E9 or Android transport.

Model the Domain guided the use of the existing SceneDocument and controller diff rather than a second change model. No architecture or review children were started, as explicitly instructed.
