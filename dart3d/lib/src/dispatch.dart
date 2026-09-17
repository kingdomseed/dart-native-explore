import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// dart3d's native→Dart event channel, following the dispatcher-slot
/// pattern in docs/plugin_async_callbacks.md: ONE C callback pointer for
/// the whole plugin, registered with native once; every event carries a
/// token (the view's viewId) so one pointer serves every scene view.
///
/// Native re-reads its slot before every call; the framework zeroes the
/// slot on hot restart before the old pointer dies, so a stale event can
/// never reach a dead callback. A token with no registered handler (view
/// already unmounted, or a leftover from before a restart) is dropped.
typedef _D3DispatchC = Void Function(Int64, Int32, Pointer<Utf8>);

final Map<int, void Function(int type, String payload)> _d3Handlers = {};

void _d3Dispatch(int token, int type, Pointer<Utf8> payload) {
  _d3Handlers[token]?.call(type, payload.toDartString());
}

/// The one dispatcher pointer handed to native via `Dart3dSetDispatcher`.
final Pointer<NativeFunction<_D3DispatchC>> d3DispatcherPointer =
    Pointer.fromFunction<_D3DispatchC>(_d3Dispatch);

/// Registers [handler] for events carrying [token] (a viewId). Called by
/// `SceneController` when its element attaches; not public API.
void d3RegisterViewHandler(int token, void Function(int, String) handler) {
  _d3Handlers[token] = handler;
}

/// Drops the handler for [token]. Called on detach; not public API.
void d3UnregisterViewHandler(int token) {
  _d3Handlers.remove(token);
}

/// Routes one decoded `queryReply` frame to the completer registered
/// under its `q` correlation id: a frame carrying `error` completes it
/// with [StateError]; any other frame completes with the decoded map
/// itself. Returns false when nothing is pending for the id — a stray
/// reply is dropped, not an error. Kept pure so the query channel's
/// semantics are exercisable under `dart test` (the controller's view
/// imports need the patched SDK).
bool d3SettleQueryReply(
  Map<String, Object?> reply,
  Map<int, Completer<Map<String, Object?>>> pending,
) {
  final q = (reply['q'] as num?)?.toInt();
  final completer = q == null ? null : pending.remove(q);
  if (completer == null) return false;
  final error = reply['error'];
  if (error != null) {
    completer.completeError(StateError('dart3d: query $q failed: $error'));
  } else {
    completer.complete(reply);
  }
  return true;
}

/// Fails every completer in [pending] with [error] and clears the map —
/// the detach/dispose path, after which no reply can arrive anyway.
void d3FailPendingQueries(
  Map<int, Completer<Map<String, Object?>>> pending,
  Object error,
) {
  for (final completer in pending.values) {
    completer.completeError(error);
  }
  pending.clear();
}

/// Advances a per-view u32 joint-handle sequence — the counter behind
/// `SceneController.addJoint`'s return value (upstream's
/// `createJoint→int`, minted client-side because the native apply is
/// async). Wraps at 2³²; reuse after `removeJoint` is legal. Kept pure
/// so the allocation rule is exercisable under `dart test` (the
/// controller's view imports need the patched SDK).
int d3NextJointSeq(int seq) => (seq + 1) & 0xFFFFFFFF;

/// Event type tags fired by `d3FireToDart` in Dart3dPlugin.swift. Native
/// and Dart must agree on these constants.
abstract final class D3Event {
  /// At least one dynamic body woke up: `{"awake": <count>}`.
  static const int awake = 1;

  /// All dynamic bodies came to rest:
  /// `{"nodes":[{"s":session,"i":index,"p":[x,y,z],"r":[x,y,z,w]}]}`.
  static const int settled = 2;

  /// A collider-pair lifecycle transition:
  /// `{"kind":"began"|"ended"|"triggerEntered"|"triggerExited",
  ///  "a":{"s":session,"i":index},"ca":<collider index>,
  ///  "b":{…},"cb":<…>,
  ///  "points":[{"p":[x,y,z],"n":[x,y,z],"imp":<double>,"sep":<double>}]}`
  /// — `points` on `began` only, and the trigger kinds whenever either
  /// collider is a sensor.
  static const int contact = 3;

  /// The reply to a `{"op":"query","q":<id>,…}` command:
  /// `{"q":<id>,"type":<query type>,"poses":[…]|"hits":[…]}` — `[]` on a
  /// miss — or `{"q":<id>,"error":<message>}` for a malformed or unknown
  /// query.
  static const int queryReply = 4;

  /// A joint lifecycle event — a dart3d extension (upstream has no joint
  /// events), fired when a `breakDistance` joint's world-space anchor
  /// separation exceeds the threshold and the constraint is removed:
  /// `{"kind":"broke","id":<joint id>,"a":{"s":session,"i":index},
  ///  "b":{…}}`. `kind` leaves the frame open to further kinds.
  static const int joint = 5;
}
