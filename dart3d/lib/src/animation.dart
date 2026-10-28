import 'dart:math' as math;
import 'dart:typed_data';

import 'scene_model.dart';

/// An authored clip with ordinary channels and dart3d property curves.
/// Persist with the paired dart3d codecs. Native property playback requires
/// a renderer implementing `d3:propertyAnimation`.
final class Dart3dAnimationSpec extends AnimationSpec {
  Dart3dAnimationSpec(
    super.id, {
    super.name = '',
    List<AnimationChannelSpec>? channels,
    List<D3PropertyChannelSpec>? propertyChannels,
  }) : propertyChannels = List.unmodifiable(propertyChannels ?? const []),
       super(channels: List.unmodifiable(channels ?? const [])) {
    final endpoints = <(Type, LocalId)>{};
    for (final channel in this.propertyChannels) {
      final target = switch (channel) {
        D3MaterialBaseColorChannel(:final material) => material,
        D3LightIntensityChannel(:final node) => node,
        D3CameraFovChannel(:final node) => node,
      };
      if (!endpoints.add((channel.runtimeType, target))) {
        throw ArgumentError(
          'animation $id has duplicate property endpoint $target',
        );
      }
    }
  }

  final List<D3PropertyChannelSpec> propertyChannels;
}

/// A closed property endpoint using the existing f32 curve payloads.
sealed class D3PropertyChannelSpec {
  const D3PropertyChannelSpec({
    required this.timeline,
    required this.keyframes,
  });
  final LocalId timeline;
  final LocalId keyframes;
}

/// Straight linear RGBA. RGB is nonnegative and alpha is in [0, 1].
final class D3MaterialBaseColorChannel extends D3PropertyChannelSpec {
  const D3MaterialBaseColorChannel({
    required this.material,
    required super.timeline,
    required super.keyframes,
  });
  final LocalId material;
}

/// Nonnegative intensity in the light component's authored units.
final class D3LightIntensityChannel extends D3PropertyChannelSpec {
  const D3LightIntensityChannel({
    required this.node,
    required super.timeline,
    required super.keyframes,
  });
  final LocalId node;
}

/// Perspective vertical FOV, strictly between zero and pi radians.
final class D3CameraFovChannel extends D3PropertyChannelSpec {
  const D3CameraFovChannel({
    required this.node,
    required super.timeline,
    required super.keyframes,
  });
  final LocalId node;
}

/// Validates available authored property curves at a document/curve ingress.
/// Missing payload specs or bytes remain pending; target eligibility belongs
/// to the native resource/component owner.
void validatePropertyAnimation(
  AnimationSpec spec,
  PayloadSpec? Function(LocalId) payload,
) {
  if (spec is! Dart3dAnimationSpec) return;
  for (var index = 0; index < spec.propertyChannels.length; index++) {
    final channel = spec.propertyChannels[index];
    Never invalid(String message) =>
        throw FormatException('animation ${spec.id} property $index: $message');
    List<double>? read(LocalId id) {
      final p = payload(id);
      if (p == null) return null;
      if (p.encoding != PayloadEncoding.floats)
        invalid('payload $id must use floats');
      if (p.length != null && (p.length! < 0 || p.length! % 4 != 0))
        invalid('payload $id length must align to f32');
      final bytes = p.bytes;
      if (bytes == null) return null;
      if (bytes.lengthInBytes % 4 != 0)
        invalid('payload $id bytes must align to f32');
      final data = ByteData.sublistView(bytes);
      return [
        for (var i = 0; i < bytes.lengthInBytes; i += 4)
          data.getFloat32(i, Endian.little),
      ];
    }

    final times = read(channel.timeline);
    final values = read(channel.keyframes);
    if (times != null) {
      if (times.isEmpty) invalid('timeline must be nonempty');
      for (var i = 0; i < times.length; i++) {
        if (!times[i].isFinite ||
            times[i] < 0 ||
            (i > 0 && times[i] <= times[i - 1]))
          invalid(
            'timeline must be finite, nonnegative and strictly increasing',
          );
      }
    }
    if (values == null) continue;
    final arity = channel is D3MaterialBaseColorChannel ? 4 : 1;
    if (values.isEmpty || values.length % arity != 0) {
      invalid('keyframes must contain nonempty groups of $arity');
    }
    if (times != null && values.length != times.length * arity)
      invalid('keyframe count must equal timeline count times $arity');
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (!v.isFinite) invalid('keyframes must be finite');
      switch (channel) {
        case D3MaterialBaseColorChannel():
          if (v < 0 || (i % 4 == 3 && v > 1)) invalid('invalid linear RGBA');
        case D3LightIntensityChannel():
          if (v < 0) invalid('intensity must be nonnegative');
        case D3CameraFovChannel():
          if (v <= 0 || v >= math.pi)
            invalid('FOV must be strictly between zero and pi');
      }
    }
  }
}

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
    final timelines = [
      for (final channel in spec.channels) channel.timeline,
      if (spec is Dart3dAnimationSpec)
        for (final channel in spec.propertyChannels) channel.timeline,
    ];
    for (final timeline in timelines) {
      final times = _floats(doc.payload(timeline));
      if (times.isNotEmpty && times.last > duration) {
        duration = times.last;
      }
    }
    return SceneAnimation._(
      id: spec.id,
      name: spec.name,
      channelCount: timelines.length,
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

/// The command batch that hands playback from [from] to [to] —
/// upstream's clip-switch idiom, where only weight decides what a clip
/// contributes.
///
/// A stopped clip still blends its t=0 pose at its weight (upstream
/// `AnimationClip.stop` is pause + rewind), so a switcher that only
/// stops the outgoing clip leaves every clip it ever played in the
/// blend, and the playing clip's share shrinks to 1/N (#33). This
/// batch zeroes and stops [from], then plays [to] from the start at
/// weight 1: [to] is the only contributing clip, and every channel
/// [from] drove that [to] doesn't returns to its bind pose.
///
/// Emit it as one `applyCommands` batch so both ops land in the same
/// native drain — no frame shows the bind pose between clips. [from]
/// may be null (nothing playing yet) or equal to [to] (a restart).
List<Map<String, Object?>> encodeSwitchAnimCommands({
  LocalId? from,
  required LocalId to,
  bool loop = false,
}) => [
  if (from != null && from != to)
    encodeAnimCommand(from, stop: true, weight: 0),
  encodeAnimCommand(to, play: true, time: 0, weight: 1, loop: loop),
];

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
