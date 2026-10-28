# Throwaway authored-text host reload probe

Implemented only the five new owned paths. Mac host integration and a generic arm64 iOS simulator build pass. Native iOS connectivity/rendering/reload and Android remain NOT_RUN. No device, simulator, emulator or adb action or query occurred. A142 remains reserved. No child agents, commits, pushes, external mutations or writes in the parent checkout occurred.

## Baseline and scope

HEAD verified as `2f38e4e33f0b1cb678bc408a42d069c796cefc12`. Imported only accepted production52 from `/private/tmp/dart3d-e5b-outline-state-current-20261027/r1/parent-source.tgz`. Its SHA256 matched `646f5d269a78020fb588ea420fb2783ea9d5a998e6b8019fd8885ad365726f2d`. All 52 manifest paths matched immediately after import and after implementation/build/test. The failed showcase probe was never imported. `lib/w34_reload_probe.dart` was absent before adding it. No applicable CONTEXT.md was found.

Read the supplied AGENTS, package/example READMEs, local DartNative guide and widget documentation, Poteto native Codex instructions, current program E9/T1-T4 gates, historical W34 scope, source-grounded recommendation, and prior runtime failure/log. The local widget documentation is in the main repository's `dartnative/docs/widgets.md`; this checkout has no `dartnative/` directory. Used installed SDK WebSocket, HttpServer, Directory.watch, State and widget signatures. The prior runtime receipt is stale evidence of the failed app-side watcher, not a result of this implementation. No PR/issue work was performed.

The five-file patch is relative to production52. All accepted normal entrypoint/showcase/U3/U4/native source remains byte-identical. `unowned-preservation.log` verifies 1,928 baseline files; `all52-preservation.log` verifies the accepted manifest; `locks-preservation.log` verifies six recorded locks/registrant. `status-delta.txt` is exactly the five owned additions. No pubspec, pin or dependency changes. The package resolution commands only generated ignored local outputs.

## Files and ownership

- `tool/w34_reload_host.dart` binds only IPv4 loopback on the caller's explicit port. It subscribes to a nonrecursive parent watcher before its first read. Events for the source, move destinations and coalesced parent events reread only the explicit source. Text is opaque. One active consumer receives full WebSocket text messages. The last sent string suppresses duplicate text. No scene model, parsing, diff, ID allocation, sibling scanning, polling, debounce, reconnect or transport envelope exists on the host.
- `tool/fixtures/w34_reload.fscene` is byte-identical to the supplied initial authored scene. It has the same IDs, red PBR cube, directional light, fixed camera, and linear environment exposure 1. The target reserves a separate footer below the scene viewport.
- `lib/w34_reload_probe.dart` owns one connection attempt. It decodes each received text once through `readFsceneLogged`, then loads the first valid document or applies the existing diff against `controller.document`. It catches actual format/version/unsupported-feature exceptions, malformed property casts and argument/range failures only around decoding. Controller operations remain outside the catch boundary. No fallback scene or duplicate document exists. A lifetime flag stops callbacks synchronously before controller disposal; the owned HTTP client aborts pending startup, and the real socket is closed.
- `lib/w34_reload_main.dart` registers plugins as the normal main does and requires `DART3D_RELOAD_URL`. It retains one controller/SceneView and shows brief diagnostic status. It uses typed `SceneQuality.high`. The ordinary app starts no network or watcher. There is no debug-build gate, lifecycle hot-reload override, VM extension or Android backend/native wiring.
- `test/w34_reload_transport_test.dart` uses actual temporary files, host watcher, loopback sockets, receiver and SceneController with the existing recording SceneViewElement pattern. No mock transport or test-only production seam.

Model the Domain kept the accepted SceneDocument solely on SceneController. Boundary Discipline confined authored-data catches to decoding. Laziness Protocol kept the transport to existing WebSocket framing with one socket. The explicit no-children grant superseded skill delegation guidance.

## Verification

- `focused-tests.log`: 13 passing integration tests. Initial scene loads once. Red-to-blue sends `upsertResource` and consumer `updateNode`; exposure 1-to-0.2 sends environment `upsertResource` and `updateStage`; restoration preserves the fixed camera. Malformed JSON, wrong property type, short color vector and invalid document root produce no mutation and retain the prior document. A later valid save recovers. Actual rename saves work; an unrelated sibling save emits no mutation. A missing source during rename reports an error and recovers on a later real event.
- The same tests cover stop-before-dispose with a later file save, peer/server disconnect, port release, occupied-port and missing-source startup failures, second-consumer rejection, refused connection, cancellation during a real pending handshake, binary-message rejection and later valid text, and CLI SIGTERM exit/port reuse. Tests close their sockets, servers, subscriptions and temporary directories. No host process remains after the run.
- `example-regressions.log`: 60 passing tests across the probe and seven affected U3/U4 example test files. This combined run predates only the final host terminal-error message clarification; all 13 focused tests and analysis were rerun on the final host source.
- `package-regressions.log`: 61 passing affected U3/U4 package tests.
- `analysis.log` and `package-analysis.log`: clean `dn analyze`.
- `ios-build.log`: `** BUILD SUCCEEDED **` using `generic/platform=iOS Simulator`, `ARCHS=arm64`, no boot/run. `build-config-verification.log` confirms the new target and explicit URL. Build defines containing the configured license were redacted from the exported build log; the generated configuration and credential were left intact.
- `replay-verification.log`: forward apply/check against an isolated production52 extraction, exact five-file hashes, all52 unchanged, reverse apply/check, all52 restored and all five additions absent. Task-owned replay scratch removed.
- `diff-check.log`: successful `git diff --check`.

Early failures are retained separately. The first test compile used the wrong protocol class name, corrected to installed `D3Protocol`. One package command named a nonexistent test file; the actual six U3/U4 files were then run successfully. The CLI test first launched `Platform.resolvedExecutable`, which under `dn test` is `flutter_tester`, not host Dart. The failed log showed a VM banner and timeout; the final test derives and launches the actual sibling SDK Dart. Direct host-Dart usage returns the documented usage/exit64. These were test-runner corrections, not runtime capability failures. All failed-process instances exited and no daemon was retained.

No full T1 suite or native T2/T3/T4 gate is claimed. Host timestamps and receiver request timestamps diagnose delivery and submitted operation only. They prove neither a first frame nor latency/performance.

## Parent commands and save order

Apply `five-file.patch` in the parent only after verifying its production52 baseline. The archive `owned-source.tgz` contains all five complete new source files. Hashes are in `owned-source-sha256.txt` and `artifact-sha256.txt`.

From the parent checkout's `dart3d/example`, start the host with this explicit source and chosen port:

```sh
/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart run tool/w34_reload_host.dart "$PWD/tool/fixtures/w34_reload.fscene" 49334
```

It logs its actual URL as `ws://127.0.0.1:49334`. This is a one-consumer experiment. A dead socket or watcher ends it; restart explicitly rather than reconnecting. Ctrl-C or SIGTERM closes the watcher, upgraded socket, server and signal subscriptions. A missing file during a rename is logged and may recover on a later actual event.

Only the parent may select/use an approved iOS simulator. The separate launch command is:

```sh
/Users/jasonholt/zero/bin/dn run -d <parent-approved-ios-simulator-id> --target lib/w34_reload_main.dart --dart-define=DART3D_RELOAD_URL=ws://127.0.0.1:49334
```

First prove one iOS connection and the visible initial red cube at exposure 1. Stop at the capability boundary if connection or initial rendering fails. Do not save any edits before that proof.

Then keep the same view/controller/camera/IDs mounted and save the same explicit source in this order:

1. Change only `resources.mat:01VK6D0000000.properties.baseColor.c` from `[0.7, 0.08, 0.03, 1.0]` to `[0.03, 0.08, 0.7, 1.0]`. Capture the blue result and diff diagnostics.
2. Keep blue and change only `resources.env:01VK6D000000A.exposure` from `1.0` to `0.2`. Capture the result and resource/stage diagnostics.
3. Save malformed JSON, such as a single `{`. Capture the decode error and verify the prior valid scene stays visible with no mutation. A separate wrong-property save may change `roughness.d` to `"wrong"`.
4. Restore the exact initial source from the delivered archive. This command is for the parent after the invalid-save proof:

```sh
tar xOf /private/tmp/dart3d-e9-host-reload-probe-20261027/r1/owned-source.tgz dart3d/example/tool/fixtures/w34_reload.fscene > tool/fixtures/w34_reload.fscene
```

Capture recovery to red/exposure1. Matched screenshots/video and actual native logs are the parent's responsibility. Preserve the fixed camera and viewport throughout.

## Reproduction commands already run

From `dart3d/example`:

```sh
/Users/jasonholt/zero/bin/dn pub get
/Users/jasonholt/zero/bin/dn test test/w34_reload_transport_test.dart
/Users/jasonholt/zero/bin/dn test test/w34_reload_transport_test.dart test/u3_atlas_probe_test.dart test/u3_sprite_showcase_test.dart test/u3_tone_showcase_test.dart test/u4_material_showcase_test.dart test/u4_owner_showcase_test.dart test/u4_showcase_test.dart test/u4_snapshot_showcase_test.dart
/Users/jasonholt/zero/bin/dn analyze
/Users/jasonholt/zero/bin/dn build ios --simulator --debug --config-only --target lib/w34_reload_main.dart --dart-define=DART3D_RELOAD_URL=ws://127.0.0.1:49334
```

From `dart3d`:

```sh
/Users/jasonholt/zero/bin/dn pub get
/Users/jasonholt/zero/bin/dn test test/u3_node_highlights_test.dart test/u3_sprite_material_test.dart test/u3_texture_atlas_test.dart test/u4_controller_test.dart test/u4_payload_arrival_test.dart test/u4_property_animation_test.dart
/Users/jasonholt/zero/bin/dn analyze
```

From `dart3d/example/ios`:

```sh
FLUTTER_ROOT=/Users/jasonholt/zero xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator -derivedDataPath /private/tmp/dart3d-e9-host-reload-probe-20261027/r1/DerivedData ARCHS=arm64 IPHONEOS_DEPLOYMENT_TARGET=15.0 CODE_SIGNING_ALLOWED=NO build
```

From the worktree root, `package_delivery.dart` rebuilds the patch/archive/hash manifests and verifies replay/preservation. `verify_build_config.dart` checks target/URL without disclosing other defines. Both scripts are retained in the evidence directory.

## Retained outputs and open gates

Retained ignored checkout outputs are enumerated by path in `generated-outputs.txt`. They include package/example `.dart_tool`, package/example `build`, generated iOS `DartNative` configuration, `Pods`, `.symlinks` and workspace support produced by package resolution/configuration/tests. The generic simulator build's `DerivedData/` is retained beside this handoff as build output. Evidence logs, manifests, archives and the two evidence scripts are retained. Replay scratch was deleted. No task-owned server/watcher/socket or temporary test directory remains.

Native iOS socket/connectivity/rendering/watch behavior, visible authored reload, Android connectivity/backend/native behavior, external asset/payload-byte refresh, debug channels/wireframe, device teardown, first-frame evidence and latency are NOT_RUN. Android is not claimed ready. No Android reverse mapping or permission/native change was attempted. The parent owns all native use, evidence capture and removal of throwaway diagnostics. Shader reload remains E6. This probe does not close whole E9 or Track E.
