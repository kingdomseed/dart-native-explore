# Reload an authored scene and its payload sidecar

Use the explicit development target to reload an external `.fscene` and its
`payloadSource` sidecar in one mounted `SceneView`. Normal `main.dart` and
ordinary library imports open no reload connection. Activation requires a URL,
including in release builds.

## Prepare the external fixture

Run these commands from `dart3d/example`. Keep logs and captures outside the
fixture directory because the host watches that directory recursively.

```sh
DART=/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart
FIXTURE=$(mktemp -d /private/tmp/dart3d-w34-assets.XXXXXX)
"$DART" tool/w34_asset_fixture.dart "$FIXTURE" init
shasum -a 256 "$FIXTURE/quad.fscene" "$FIXTURE/pixels.fsceneb"
"$DART" ../tool/reload_host.dart "$FIXTURE/quad.fscene" 49334
```

The host prints `listening ws://127.0.0.1:49334/scene`. Leave this process running
while using the development target. It binds IPv4 loopback only. A peer close,
terminal watcher or socket error, SIGINT, or SIGTERM shuts it down. Restart the
host and target explicitly after a terminal error.

## Launch the development target

Use the parent-approved iOS simulator ID in a second terminal, from
`dart3d/example`.

```sh
/Users/jasonholt/zero/bin/dn run -d "$SIMULATOR_ID" \
  -t lib/dev_reload_main.dart \
  --dart-define=DART3D_RELOAD_URL=ws://127.0.0.1:49334/scene
```

The target registers the real plugin, owns one controller and view, and displays
reload status in a 100-point footer. The fixed fixture has a white unlit material
on a quad and an opaque 2×2 RGBA8 texture. Its image ID is
`LocalId(0x7734, 0)`, with null layout, format `rgba8`, width and height 2, and
length 16. Pattern A alternates red and green pixels. Pattern B alternates blue
and yellow pixels. The generator fixes document and local IDs and emits FSCB v2
JSON and BLOB chunks deterministically.

In a third terminal, set `FIXTURE` to the directory printed by the first command.
Change only the sidecar, reject malformed content, and restore A.

```sh
DART=/Users/jasonholt/zero/bin/cache/dart-sdk/bin/dart
"$DART" tool/w34_asset_fixture.dart "$FIXTURE" b
"$DART" tool/w34_asset_fixture.dart "$FIXTURE" malformed
"$DART" tool/w34_asset_fixture.dart "$FIXTURE" a
shasum -a 256 "$FIXTURE/quad.fscene" "$FIXTURE/pixels.fsceneb"
```

The authored file stays byte-identical. A valid changed image uses the existing
same-ID descriptor-bearing payload upsert before resources and consumers.
An unchanged reread sends no redundant native mutation. Invalid text, malformed
containers, missing bytes, descriptor mismatch, and invalid RGBA8 dimensions or
length retain the accepted document. A later actual save retries preparation.
Each file is read independently; saves across files are not a transaction.

Capture baseline A, changed B, retained B after malformed input, and recovered A
in the same mounted view. Save native logs, screenshots and a continuous video
outside the watched root. Controller command tests do not establish native pixels.

## Own a reload session

Import the opt-in library directly. The controller remains the sole accepted
scene owner.

```dart
import 'package:dart3d/dev_reload.dart';

final reload = DevSceneReload(
  controller: controller,
  endpoint: Uri.parse('ws://127.0.0.1:49334/scene'),
  onStatus: reportStatus,
);
await reload.start();
await reload.stop();
controller.dispose();
```

Construction starts no I/O. `start()` connects once and reports setup, not a
render acknowledgement. Repeated starts throw. `stop()` revokes callbacks and
application immediately, force-closes its client, then joins connection,
reception, socket and active preparation cleanup. Repeated stops return the same
future. A widget status callback must check `mounted`; widget disposal starts
stop synchronously and disposes the controller after that future completes.
Unexpected controller application errors propagate to the caller's async zone.

The host sends complete authored text on initial connect and every recursive
parent-directory event, even if text is identical. The app reparses a detached
candidate and fetches `payloadSource` through same-origin
`/payload?path=<encoded relative path>`. Redirects are disabled. The host decodes
the query once and accepts only relative `.fsceneb` files under the canonical
authored parent, including resolved symlink containment. Missing files return
404. The byte route remains available while the single WebSocket is claimed.
The app matches required payload IDs and all six descriptor fields, checks
actual declared lengths, and validates raw RGBA8 dimensions and byte count.
Surplus sidecar payloads and its graph are ignored.

## Run the host and controller checks

From `dart3d/example`.

```sh
/Users/jasonholt/zero/bin/dn test --no-pub test/dev_reload_test.dart
/Users/jasonholt/zero/bin/dn analyze --no-pub
```

The tests use real temporary files, recursive watches, loopback HTTP and
WebSockets, the public session, actual host class and CLI, and a recording
controller transport. Each test closes its resources. CLI subprocesses use the
host Dart SDK because `dn test` runs under `flutter_tester`.

Native iOS HTTP delivery, rendered asset replacement, native cancellation,
Android transport, broader assets, debug channels, wireframe, latency, T2 and T4
remain separate verification work. General encoded-image, mesh and LUT semantic
validation is outside this boundary. This feature does not complete E9/W34.
