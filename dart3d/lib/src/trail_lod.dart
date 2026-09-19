// W16 — `trail` and `lod` component vocabulary plus the pure-Dart
// reference math the natives port: the trail point-buffer policy, the
// camera-facing ribbon expansion, and the LOD screen-size selection.
//
// Pure Dart (no dartnative import) so `dart test` reaches it — the same
// constraint as components.dart / physics.dart. Names mirror upstream
// `TrailComponent`/`LodComponent`/`LodSelection` (flutter_scene); the
// fields serialize inside ordinary `{type, properties}` component bags
// matching upstream's `TrailCodec`/`LodCodec` wire shapes.

import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'scene_model.dart';

/// One keyframe of a `widthOverTrail` curve — sampled piecewise-
/// linearly at the head-to-tail fraction `t` (0 = head, 1 = tail). An
/// absent curve falls back to upstream's default taper `1 − t`.
/// Serializes inside upstream's curve shape `{keys: [{t, v}, …]}`.
class TrailStop {
  const TrailStop(this.t, this.value);

  final double t;
  final double value;
}

/// One stop of a `colorOverTrail` gradient — same `t` convention. An
/// absent gradient falls back to upstream's default: white fading
/// alpha `1 − t` toward the tail. Serializes inside upstream's
/// gradient shape `{stops: [{t, color}, …]}`.
class TrailColorStop {
  const TrailColorStop(this.t, this.color);

  final double t;
  final ColorValue color;
}

/// The `trail` component — upstream `TrailComponent`. Each frame the
/// node records its world position; the head follows continuously, a
/// new anchor drops once the node has moved [minVertexDistance] from
/// the previous anchor, and points older than [lifetime] expire
/// ([maxPoints] bounds the buffer, oldest first). The path renders as
/// a camera-facing ribbon in world space — the trail hangs where the
/// node has been.
///
/// [widthOverTrail] multiplies [width] over the head-to-tail fraction;
/// [colorOverTrail] tints it (rgba). [emitting] false pauses recording
/// while the existing ribbon ages out — upstream's
/// `TrailComponent.emitting`. Upstream does not serialize a trail
/// material (the default is translucent vertex-color unlit, drawn
/// without culling), so dart3d's natives draw the same default and the
/// wire carries no material field.
ComponentSpec trailComponent({
  double width = 0.25,
  double lifetime = 0.6,
  double minVertexDistance = 0.05,
  int maxPoints = 48,
  bool emitting = true,
  List<TrailStop>? widthOverTrail,
  List<TrailColorStop>? colorOverTrail,
}) {
  return ComponentSpec(
    'trail',
    properties: {
      'width': DoubleValue(width),
      'lifetime': DoubleValue(lifetime),
      'minVertexDistance': DoubleValue(minVertexDistance),
      'maxPoints': IntValue(maxPoints),
      'emitting': BoolValue(emitting),
      if (widthOverTrail != null)
        'widthOverTrail': MapValue({
          'keys': ListValue([
            for (final s in widthOverTrail)
              MapValue({'t': DoubleValue(s.t), 'v': DoubleValue(s.value)}),
          ]),
        }),
      if (colorOverTrail != null)
        'colorOverTrail': MapValue({
          'stops': ListValue([
            for (final s in colorOverTrail)
              MapValue({'t': DoubleValue(s.t), 'color': s.color}),
          ]),
        }),
    },
  );
}

/// One drawable variant of an `lod` component — upstream `LodLevel`:
/// [geometry] drawn while the node's projected on-screen size is at
/// least [screenSize], a fraction of the viewport height. Both
/// [geometry] and [material] are required — upstream skips level
/// entries missing either resource ref.
class LodLevel {
  const LodLevel({
    required this.geometry,
    required this.material,
    required this.screenSize,
  });

  final LocalId geometry;
  final LocalId material;
  final double screenSize;
}

/// The `lod` component — upstream `LodComponent`. [levels] are highest
/// detail first with strictly descending `screenSize` thresholds; the
/// natives draw the first level whose threshold the projected size
/// meets, and nothing once the size drops below the smallest threshold
/// (the cull floor — a last threshold of `0` never culls). [lodBias]
/// multiplies the projected size before selection. A non-perspective
/// camera disables the metric — the natives draw the highest-detail
/// level (upstream's orthographic rule).
///
/// [hysteresis] and [blendRange] decode for wire parity but are
/// documented no-ops: dart3d hard-switches levels (the upstream
/// dead-band and cross-fade are future work).
ComponentSpec lodComponent({
  required List<LodLevel> levels,
  double lodBias = 1.0,
  double? hysteresis,
  double? blendRange,
}) {
  return ComponentSpec(
    'lod',
    properties: {
      'levels': ListValue([
        for (final l in levels)
          MapValue({
            'geometry': ResourceRefValue(l.geometry),
            'material': ResourceRefValue(l.material),
            'screenSize': DoubleValue(l.screenSize),
          }),
      ]),
      'lodBias': DoubleValue(lodBias),
      if (hysteresis != null) 'hysteresis': DoubleValue(hysteresis),
      if (blendRange != null) 'blendRange': DoubleValue(blendRange),
    },
  );
}

/// The trail's recorded path — the upstream `TrailComponent.update`
/// policy ported verbatim. [points] are world-space, head-first: the
/// head tracks the node every frame, a new anchor is inserted once the
/// node travels [minVertexDistance] from the previous anchor, and the
/// tail expires by age ([lifetime]) and capacity ([maxPoints]).
class TrailPointBuffer {
  TrailPointBuffer({
    this.lifetime = 0.6,
    this.minVertexDistance = 0.05,
    this.maxPoints = 48,
    this.emitting = true,
  });

  double lifetime;
  double minVertexDistance;
  int maxPoints;

  /// While false no new points record; the existing path ages out.
  bool emitting;

  /// Head-first world positions — [points][0] is the following head.
  final List<Vector3> points = [];

  /// Parallel birth clock of [points] (seconds of accumulated time).
  final List<double> bornTimes = [];

  double _time = 0.0;

  /// Current playback clock — bornTimes are measured against it.
  double get time => _time;

  int get length => points.length;

  /// Forgets the path — the ribbon disappears immediately.
  void clear() {
    points.clear();
    bornTimes.clear();
  }

  /// The head-to-tail fraction of point [i] (`0` head, `1` tail) — the
  /// `t` the width/color ramps sample at.
  double fractionAt(int i) => points.length > 1 ? i / (points.length - 1) : 0.0;

  /// Records the node's [worldPosition] at `now + deltaSeconds`.
  /// Mirrors upstream: the head follows continuously, anchors drop by
  /// distance, expiry trims the tail.
  void update(double deltaSeconds, Vector3 worldPosition) {
    _time += deltaSeconds;
    if (emitting) {
      if (points.isEmpty) {
        points.insert(0, worldPosition.clone());
        bornTimes.insert(0, _time);
      } else {
        // The head follows the node continuously; a new anchor is
        // dropped once it has traveled far enough from the previous
        // one.
        points.first.setFrom(worldPosition);
        bornTimes[0] = _time;
        final anchored = points.length > 1 ? points[1] : points.first;
        if (points.length == 1 ||
            anchored.distanceTo(worldPosition) >= minVertexDistance) {
          points.insert(0, worldPosition.clone());
          bornTimes.insert(0, _time);
        }
      }
    }
    // Expire by age and by capacity (head stays, tail goes).
    while (points.length > maxPoints ||
        (bornTimes.isNotEmpty && _time - bornTimes.last > lifetime)) {
      points.removeLast();
      bornTimes.removeLast();
      if (points.isEmpty) break;
    }
  }
}

/// Samples a `widthOverTrail` keyframe list at the head-to-tail
/// fraction [t] — piecewise-linear between keyframes, clamped to the
/// ends (upstream bakes the same curve into a lookup table). [stops]
/// must be sorted by `t`. Callers supply the absent-ramp fallback
/// `1 − t` themselves via the empty list.
double sampleTrailStops(List<TrailStop> stops, double t) {
  if (stops.isEmpty) return 1.0 - t;
  if (t <= stops.first.t) return stops.first.value;
  if (t >= stops.last.t) return stops.last.value;
  for (var i = 1; i < stops.length; i++) {
    if (t <= stops[i].t) {
      final a = stops[i - 1];
      final b = stops[i];
      final f = (t - a.t) / (b.t - a.t);
      return a.value + (b.value - a.value) * f;
    }
  }
  return stops.last.value;
}

/// Samples a `colorOverTrail` stop list at the head-to-tail fraction
/// [t] — piecewise-linear rgba, clamped to the ends. [stops] must be
/// sorted by `t`. The absent-gradient fallback is upstream's white
/// fading alpha `1 − t` (the empty list returns it).
ColorValue sampleTrailColorStops(List<TrailColorStop> stops, double t) {
  if (stops.isEmpty) return ColorValue(1, 1, 1, 1.0 - t);
  if (t <= stops.first.t) return stops.first.color;
  if (t >= stops.last.t) return stops.last.color;
  for (var i = 1; i < stops.length; i++) {
    if (t <= stops[i].t) {
      final a = stops[i - 1].color;
      final b = stops[i].color;
      final f = (t - stops[i - 1].t) / (stops[i].t - stops[i - 1].t);
      return ColorValue(
        a.r + (b.r - a.r) * f,
        a.g + (b.g - a.g) * f,
        a.b + (b.b - a.b) * f,
        a.a + (b.a - a.a) * f,
      );
    }
  }
  return stops.last.color;
}

/// Expands the recorded path into ribbon vertices — two per anchor,
/// offset `±width·side/2` where `side = normalize(tangent ×
/// toCamera)`. [points] are head-first positions, [widths] the
/// per-point widths (ramp already sampled), all in the same space —
/// the natives pass node-local points and a node-local camera so the
/// ribbon renders under the emitting node's transform (upstream's
/// rebase). Returns `2·n` vertices interleaved left/right per anchor —
/// the natives' per-frame ribbon fill. Degenerate tangents (duplicate
/// points) reuse the last good side; a camera on the point falls back
/// to any perpendicular.
List<Vector3> expandTrailRibbon(
  List<Vector3> points,
  List<double> widths,
  Vector3 cameraPosition,
) {
  final out = List<Vector3>.filled(points.length * 2, Vector3.zero());
  final up = Vector3(0, 1, 0);
  Vector3? lastSide;
  for (var i = 0; i < points.length; i++) {
    final n = points.length;
    final prev = points[i == 0 ? 0 : i - 1];
    final next = points[i == n - 1 ? n - 1 : i + 1];
    var tangent = prev - next;
    if (tangent.length2 < 1e-12 && n > 1) {
      // Duplicate point — fall back to the one-sided difference.
      tangent = (i == 0 ? points[0] - points[1] : points[i - 1] - points[i]);
    }
    var side = lastSide ?? Vector3(1, 0, 0);
    if (tangent.length2 >= 1e-12) {
      final view = cameraPosition - points[i];
      final c = tangent.cross(view);
      if (c.length2 >= 1e-12) {
        side = c.normalized();
      } else {
        final f = tangent.cross(up);
        side = f.length2 >= 1e-12
            ? f.normalized()
            : tangent.cross(Vector3(1, 0, 0)).normalized();
      }
    }
    lastSide = side;
    final half = widths[i] * 0.5;
    out[i * 2] = points[i] + side * half;
    out[i * 2 + 1] = points[i] - side * half;
  }
  return out;
}

/// The projected on-screen size of a world-space bounding sphere as a
/// fraction of the viewport height — upstream `lodScreenSize`. `1.0`
/// means the sphere's diameter spans the viewport. A camera inside the
/// sphere yields [double.infinity] (highest detail).
double lodScreenSize({
  required Vector3 center,
  required double radius,
  required Vector3 cameraPosition,
  required double fovRadiansY,
}) {
  final distance = center.distanceTo(cameraPosition);
  if (distance <= radius) return double.infinity;
  // The viewport spans 2·distance·tan(fovY/2) world units at the
  // sphere's depth, so the diameter covers radius/(distance·tan) of
  // the height.
  return radius / (distance * math.tan(fovRadiansY / 2));
}

/// Picks the LOD index for a projected [screenSize] against descending
/// [thresholds] — the first level whose threshold the size meets, or
/// `-1` to cull below the smallest threshold (a last threshold of `0`
/// never culls). [lodBias] multiplies the size first, matching
/// upstream's `LodSelection.resolve`; upstream's `hysteresis`
/// dead-band and `blendRange` cross-fade are documented no-ops in
/// dart3d (hard switch).
int selectLodLevel(
  double screenSize,
  List<double> thresholds, {
  double lodBias = 1.0,
}) {
  final size = screenSize * lodBias;
  for (var i = 0; i < thresholds.length; i++) {
    if (size >= thresholds[i]) return i;
  }
  return -1;
}
