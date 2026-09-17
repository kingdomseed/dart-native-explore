import 'dart:typed_data';

import 'scene_model.dart';

/// Read-only descriptor of one animation in the tracked
/// [SceneDocument] — the Dart-side info handle behind
/// `SceneController.animations`.
///
/// Playback itself lives on the native side (driven by the `anim`
/// command op through `SceneController.playAnimation` et al.); this
/// handle only reports what the document authored.
final class SceneAnimation {
  const SceneAnimation._({
    required this.id,
    required this.name,
    required this.channelCount,
    required this.duration,
  });

  /// Builds the handle for [spec] against [doc]: [duration] is the
  /// latest channel end — each channel's timeline payload's last
  /// keyframe time (upstream's `Animation.endTime` rule). Channels
  /// whose timeline chunk is absent or empty contribute 0.
  factory SceneAnimation.fromSpec(AnimationSpec spec, SceneDocument doc) {
    var duration = 0.0;
    for (final channel in spec.channels) {
      final times = _floats(doc.payload(channel.timeline));
      if (times.isNotEmpty && times.last > duration) {
        duration = times.last;
      }
    }
    return SceneAnimation._(
      id: spec.id,
      name: spec.name,
      channelCount: spec.channels.length,
      duration: duration,
    );
  }

  /// The animation's stable document id — the id the `anim` op
  /// addresses.
  final LocalId id;

  /// The animation's authored name (`''` when unnamed).
  final String name;

  /// How many channels the animation drives.
  final int channelCount;

  /// The clip length in seconds — the maximum channel end time.
  final double duration;
}

/// The morph-target count a `weights` channel's keyframes payload
/// encodes: `values ~/ times`.
///
/// Weights channels carry the flattened glTF shape — one weight per
/// target per keyframe, so `times × targetCount` floats are consumed
/// and trailing floats past a whole keyframe are dropped rather than
/// trusted (upstream `skin_animation.dart` applies the same rule at
/// decode). [times] and [values] are the element counts of the decoded
/// f32 timeline/keyframes payloads. Returns 0 for an empty timeline.
int weightsChannelTargetCount({required int times, required int values}) =>
    times == 0 ? 0 : values ~/ times;

/// `{"op":"anim",…}` — the runtime clip control, upstream's
/// `AnimationClip` knobs over one op.
///
/// At most one of [play]/[pause]/[stop] sets the verb; with none set
/// the op is a pure knob write — [time] seeks (clamped to
/// `[0, endTime]` natively), [timeScale] scales the advance rate,
/// [weight] is the blend weight (clamped to `[0, 1]` natively), and
/// [loop] toggles wrap-at-end — all leaving the clip's playing state
/// untouched.
Map<String, Object?> encodeAnimCommand(
  LocalId id, {
  bool play = false,
  bool pause = false,
  bool stop = false,
  double? time,
  double? timeScale,
  double? weight,
  bool? loop,
}) => {
  'op': 'anim',
  'anim': id.toToken(),
  if (play) 'play': true,
  if (pause) 'pause': true,
  if (stop) 'stop': true,
  if (time != null) 'time': time,
  if (timeScale != null) 'timeScale': timeScale,
  if (weight != null) 'weight': weight,
  if (loop != null) 'loop': loop,
};

/// `{"op":"setMorphWeights",…}` — a direct write of a node's morph
/// target weights (upstream's `SCNMorpher.weights` /
/// `RenderableManager.setMorphWeights` path), independent of any
/// weights channel a playing animation drives.
Map<String, Object?> encodeMorphWeightsCommand(
  LocalId node,
  List<double> weights,
) => {'op': 'setMorphWeights', 'node': node.toToken(), 'weights': weights};

/// A payload chunk's bytes read as f32 — the same view the
/// `matrices`/`floats` decoders take (native-endian, matching the
/// little-endian wire on every supported platform). Absent bytes read
/// as empty.
Float32List _floats(PayloadSpec? payload) {
  final bytes = payload?.bytes;
  if (bytes == null) return Float32List(0);
  if (bytes.offsetInBytes % 4 == 0) {
    return bytes.buffer.asFloat32List(
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 4,
    );
  }
  final aligned = Uint8List.fromList(bytes);
  return aligned.buffer.asFloat32List(0, aligned.lengthInBytes ~/ 4);
}
