# E9/W34 reload implementation handoff

Implemented the selected six-file boundary against source52. The public session,
actual host and CLI pass real file, watch, HTTP, WebSocket and controller-transport
tests. Native execution and independent review belong to the parent.

## Data and API

`dart3d/lib/dev_reload.dart` exposes only `DevSceneReload(controller:, endpoint:,
onStatus:)`, `start()` and `stop()`. Construction starts no I/O. An explicitly
owned HttpClient handles the single handshake and same-origin HTTP reads.
WebSocket asyncMap serializes detached preparation. The session joins its active
preparation explicitly because asyncMap cancellation does not do that itself.
The controller document is read after the last await and remains the only
accepted scene. Application errors propagate outside input catches.

`dart3d/tool/reload_host.dart` exposes the real `SceneReloadHost.start`, `endpoint`,
`done` and `close` used by the CLI and tests. It watches the canonical authored
parent recursively before accepting a connection. Every event rereads the explicit
file, including identical text. `/scene` claims one WebSocket. `/payload` serves
fresh relative FSCB files independently, with decode-once and canonical/symlink
containment checks. Host code imports no scene parser.

The app matches manifest-required IDs, bytes and encoding/layout/format/width/
height/length before attaching to a detached candidate. It validates declared
length and positive RGBA8 dimensions with exact width*height*4 bytes. Surplus
sidecar payloads and graph are ignored. Replacement uses the existing controller
payload upsert route. There is no direct `sendPayload` call in this feature.

The example requires DART3D_RELOAD_URL, registers the real plugin, mounts one view
with SceneQuality.high, stretches the Column and reserves a 100-point footer.
It revokes reload synchronously during disposal, then disposes its controller
after cleanup. Normal main and facade exports are unchanged.

## Owned files

- dart3d/lib/dev_reload.dart.
- dart3d/tool/reload_host.dart.
- dart3d/example/lib/dev_reload_main.dart.
- dart3d/example/tool/w34_asset_fixture.dart.
- dart3d/example/test/dev_reload_test.dart.
- docs/dev-reload.md.

No seventh file was required. All imported unrelated work remains. Accepted52 and
all unowned baseline sources remain byte-identical. All six locks and registrants
match the parent packet. Necessary pub commands generated no tracked changes.

## Verification

- 28 real integration tests pass in focused-final.log.
- 86 package U3/U4/controller/structural-command/codec regressions pass in package-regressions.log.
- 53 example U3/U4/FSCB regressions pass in example-regressions.log.
- Total is 167 passing tests. These are focused suites, not a claim of full T1.
- Package and example `dn analyze --no-pub` pass with no issues.
- `git diff --check` passes. The new-file patch also passes forward/reverse git apply checks.
- Both supplied archives and adjacent manifests/artifact hashes were verified.
- Baseline has 1,928 hashed files, including 52 imported accepted sources. Every hash is unchanged.
- Forward, reverse and forward replay match all six final owned files and preserve every baseline file.

The tests assert one initial load, byte-identical authored text and unchanged
SHA256 after sidecar save, literal RGBA8 values, same-ID descriptor-bearing
upsert before resources/consumer, unchanged reread without mutations, and fixed
camera. They cover malformed text/container, missing payload/chunk, every
descriptor mismatch, declared and raw byte lengths, HTTP 404, actual save and
atomic rename recovery, recursive nested saves, surplus graph/chunks, text-only
color/exposure reload, path/symlink containment and decode-once filename handling,
redirect refusal, binary message rejection, serial preparation, reading current
controller state after I/O, refused connection, actual pending handshake and body
read cancellation against the same disposed controller, async application-error
propagation, host shutdown, and actual CLI signal teardown.

Initial failures are retained in focused-first.log. They were test errors in
record/list equality, incomplete response contentLength, error-zone cleanup and
CLI path. The stalled first process had no output and zero CPU before termination.
Its two owned fixture directories were removed, recorded in temporary-cleanup.json.
The root-directory invocation failure in focused-initial.log happened before
compilation and is not a runtime red baseline. One initial test brace lint was
corrected. application-error-retry.log and focused-second.log retain intermediate
corrected runs. Final logs and verification-results.json carry the final counts.

## Parent reproduction

Apply only correction.patch to the parent's own prepared source52 writer.
Do not import this worktree's whole git diff, which includes inherited source52.

```sh
git apply --check /private/tmp/dart3d-e9-reload-library-implementation-20261027/r1/correction.patch
git apply /private/tmp/dart3d-e9-reload-library-implementation-20261027/r1/correction.patch
cd dart3d/example
/Users/jasonholt/zero/bin/dn test --no-pub test/dev_reload_test.dart --reporter expanded
/Users/jasonholt/zero/bin/dn analyze --no-pub
```

Exact regression commands are recorded in verification-results.json.
From the parent's `dart3d/example`, create an external fixture and start the host.
The following commands are instructions for the parent. They were not used to
launch or query a device in this task.

```sh
DART=/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart
FIXTURE=$(mktemp -d /private/tmp/dart3d-w34-assets.XXXXXX)
"$DART" tool/w34_asset_fixture.dart "$FIXTURE" init
shasum -a 256 "$FIXTURE/quad.fscene" "$FIXTURE/pixels.fsceneb"
"$DART" ../tool/reload_host.dart "$FIXTURE/quad.fscene" 49334
```

In another terminal, use the parent-approved simulator ID. Keep one mounted view.

```sh
/Users/jasonholt/zero/bin/dn run -d "$SIMULATOR_ID" \
  -t lib/dev_reload_main.dart \
  --dart-define=DART3D_RELOAD_URL=ws://127.0.0.1:49334/scene
```

In another terminal, set FIXTURE to the same path and run these actions from
`dart3d/example`. They rewrite only the sidecar. `init` alone writes authored text.

```sh
DART=/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart
"$DART" tool/w34_asset_fixture.dart "$FIXTURE" b
"$DART" tool/w34_asset_fixture.dart "$FIXTURE" malformed
"$DART" tool/w34_asset_fixture.dart "$FIXTURE" a
shasum -a 256 "$FIXTURE/quad.fscene" "$FIXTURE/pixels.fsceneb"
```

The generator fixes document ID 48HJ89964WM2JAHB5GPJWBSG64 and all local IDs.
Image LocalId(0x7734, 0) has image encoding, null layout, rgba8 format, 2x2
size, declared length 16. A is red/green and B blue/yellow, all alpha 255.
It emits deterministic FSCB v2 JSON/BLOB chunks. No prebuilt fixture binary or
bundle/pubspec edit is needed. Capture initial A, changed B, retained B after
malformed input and restored A, plus native logs, continuous video and byte/hash
receipts. Keep every capture and log outside the watched fixture root. Stop the
host with SIGTERM or close the app peer, then remove the external fixture when done.

## Proof boundaries and remaining work

Native build, iOS execution, HTTP on the target, native cancellation, changed
pixels, latency, Android transport, other asset categories, T2 and T4 are NOT_RUN.
Encoded-image/mesh/LUT semantic validation is not promised by this unit. Debug
channels, wireframe, E6 and whole E9/W34 remain open. Source transport tests are
not native rendering proof. No devices, adb/simulator commands, native source or
permission edits, version changes, child agents, commits, pushes or external
writes occurred. Parent checkout and PR65 were not accessed.

## Delivery and retained files

correction.patch SHA256 `31aa933d3962ad2aeaf8f3977a8d4db66b86551473497e9b7513bbe586901058`.
owned-source.tgz SHA256 `a87b30e795cbdbf69604845407b702877fcdf143c9145a04a81c17b1e53155d4`.
owned-source-sha256.txt fingerprints all six files. replay-verification.json
records exact git apply commands and full baseline preservation. No replay
scratch, extracted prototype copies, task-owned server, listener, watcher or CLI
subprocess remains. resource-cleanup.json records the final process check.

The workspace keeps source52, the six new owned files and ignored SDK/test outputs.
Ignored retained outputs have 171 entries, fully listed in
generated-ignored-retained.txt. They include dart3d and example .dart_tool/build,
example .dn-plugins-dependencies, Android local.properties, and generated iOS
DartNative configuration/ephemeral files. These were produced by necessary pub
setup or tests. No tracked lock or registrant was regenerated differently.

kept-files.txt lists every retained evidence file in this directory.
artifact-sha256.txt hashes every evidence file except itself.

## Throughput and principles

Blocking source/schema/cancellation grounding and the parent's selected design
were read before implementation. Independent implementation workstreams were
not applicable because host, preparation, fixture and tests share one coupled
contract. Imported source52 was immutable shared context. One implementation owner
kept transport and cancellation semantics together. Parent owns independent
review, integration and native execution. There are no new design decisions.

Model the Domain kept one session over existing SceneDocument/PayloadSpec types.
Boundary Discipline kept input rejection separate from controller application.
Test Behavior, Not Implementation drove real file/network/controller tests.
Prove It Works required exact hashes and forward/reverse replay.
