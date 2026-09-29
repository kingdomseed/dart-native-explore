/// The launch hero's motion and framing math (P4) — pure Dart, no
/// `dartnative` imports, so it runs under `dart test`.
///
/// - [HeroOrbit]: a constant-speed 360° yaw orbit (one turn per
///   [HeroOrbit.revolutionSeconds]) with a slow sine pitch bob. A
///   one-finger drag takes over (yaw unclamped, pitch clamped); on
///   release the orbit eases back in — yaw speed ramps from 0 to the
///   drift speed and the pitch glides back onto the bob — over
///   [HeroOrbit.easeSeconds] with the site's expo-out curve.
/// - [heroBreath]: the emissive "breath", a raised cosine.
/// - [heroBoomDistance] / [heroAimDrop]: framing from the bounds, the
///   lens and the screen aspect.
///
/// See docs/design/hero-scene-brief.md §3.4–3.5 (operator overrides:
/// full orbit, glow from the logo itself, zoomed out).
library;

import 'dart:math';

/// The site's easing, `cubic-bezier(0.16, 1, 0.3, 1)` (expo-out),
/// evaluated at [t] ∈ [0, 1]. Solved for x by bisection — the curve is
/// monotonic in x, so 24 halvings are well under a pixel.
double heroEase(double t) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  const x1 = 0.16, y1 = 1.0, x2 = 0.3, y2 = 1.0;
  double bez(double a, double b, double s) {
    final u = 1 - s;
    return 3 * u * u * s * a + 3 * u * s * s * b + s * s * s;
  }

  var lo = 0.0, hi = 1.0, s = t;
  for (var i = 0; i < 24; i++) {
    s = (lo + hi) / 2;
    if (bez(x1, x2, s) < t) {
      lo = s;
    } else {
      hi = s;
    }
  }
  return bez(y1, y2, s);
}

/// The emissive breath at [seconds]: [low] → [high] → [low] as a
/// raised cosine (`0.5 − 0.5·cos`) over [period] seconds. Starts at
/// [low] so the entrance ramp hands over without a jump.
double heroBreath(
  double seconds, {
  double low = 0.35,
  double high = 0.65,
  double period = 4.8,
}) {
  final phase = (seconds % period) / period;
  return low + (high - low) * (0.5 - 0.5 * cos(2 * pi * phase));
}

/// The camera's orbit state. [tick] advances it; [drag] / [release]
/// hand it to the finger and back. Angles are radians; yaw grows
/// without bound (callers wrap it when writing a rotation).
final class HeroOrbit {
  HeroOrbit({
    this.revolutionSeconds = 30,
    this.basePitch = 8 * pi / 180,
    this.bobAmplitude = 3 * pi / 180,
    this.bobPeriod = 13,
    this.easeSeconds = 1.2,
    this.minPitch = -5 * pi / 180,
    this.maxPitch = 25 * pi / 180,
    this.radiansPerPixel = 0.008,
    double initialYaw = 0,
  }) : _yaw = initialYaw;

  /// Seconds per full revolution of the drift.
  final double revolutionSeconds;

  /// The bob's centre elevation, its ± amplitude, and its period —
  /// 13 s, not a multiple of the orbit, so the path doesn't visibly
  /// repeat.
  final double basePitch;
  final double bobAmplitude;
  final double bobPeriod;

  /// How long the orbit takes to ease back in after a drag.
  final double easeSeconds;

  /// The drag's pitch clamp.
  final double minPitch;
  final double maxPitch;

  /// Drag sensitivity.
  final double radiansPerPixel;

  double _yaw;
  double _clock = 0;
  double? _dragPitch;
  bool _dragging = false;

  /// Seconds since release, or null when no ease-in is running.
  double? _sinceRelease;
  double _releasePitch = 0;

  /// The drift speed, radians per second.
  double get yawSpeed => 2 * pi / revolutionSeconds;

  /// The current yaw (unbounded) and pitch.
  double get yaw => _yaw;
  double get pitch {
    final drag = _dragPitch;
    if (_dragging && drag != null) return drag;
    final since = _sinceRelease;
    if (since == null) return bobPitch(_clock);
    final u = heroEase(since / easeSeconds);
    return _releasePitch + (bobPitch(_clock) - _releasePitch) * u;
  }

  /// Whether a finger owns the orbit.
  bool get dragging => _dragging;

  /// Whether the post-drag ease-in is still running.
  bool get easing => _sinceRelease != null;

  /// The drift's pitch at [seconds] on the orbit clock.
  double bobPitch(double seconds) =>
      basePitch + bobAmplitude * sin(2 * pi * seconds / bobPeriod);

  /// Advances the orbit by [dt] seconds. While dragging the clock
  /// keeps running (so the bob resumes in phase) but yaw holds.
  void tick(double dt) {
    if (dt <= 0) return;
    _clock += dt;
    if (_dragging) return;
    final since = _sinceRelease;
    if (since == null) {
      _yaw += yawSpeed * dt;
      return;
    }
    // Speed ramps 0 → drift along the ease curve; integrate at the
    // midpoint so large frames don't overshoot.
    final mid = heroEase((since + dt / 2) / easeSeconds);
    _yaw += yawSpeed * mid * dt;
    final next = since + dt;
    _sinceRelease = next >= easeSeconds ? null : next;
  }

  /// A one-finger drag of ([dx], [dy]) pixels: right swings the camera
  /// right (yaw unclamped), down lifts it (pitch clamped).
  void drag(double dx, double dy) {
    if (!_dragging) {
      _dragPitch = pitch;
      _dragging = true;
      _sinceRelease = null;
    }
    _yaw -= dx * radiansPerPixel;
    _dragPitch = (_dragPitch! + dy * radiansPerPixel).clamp(
      minPitch,
      maxPitch,
    );
  }

  /// The finger lifted: ease back into the drift from here.
  void release() {
    if (!_dragging) return;
    _releasePitch = _dragPitch ?? pitch;
    _dragging = false;
    _dragPitch = null;
    _sinceRelease = 0;
  }
}

/// Boom length so a subject of bounding radius [frameRadius] fills
/// [widthFraction] of the view's width at vertical FOV [fovY] on a view
/// of [aspect] (width / height) — and never more than
/// [heightFraction] of its height. The bounding sphere covers every
/// orbit angle, so the frame never clips as the logo turns.
double heroBoomDistance({
  required double frameRadius,
  required double fovY,
  required double aspect,
  double widthFraction = 0.62,
  double heightFraction = 0.45,
}) {
  final tanY = tan(fovY / 2);
  final byWidth = frameRadius / (widthFraction * tanY * aspect);
  final byHeight = frameRadius / (heightFraction * tanY);
  return max(byWidth, byHeight);
}

/// The downward aim (radians) that puts the orbit target
/// [screenLift] of the half-height above the screen centre — the logo
/// sits in the upper part of the screen, clear of the text block.
double heroAimDrop({required double fovY, required double screenLift}) =>
    atan(screenLift * tan(fovY / 2));

/// The logo's entrance "bloom" scale at [seconds] after load: 0.965 →
/// 1.0 over [duration] on the site curve (the site's `hero-bloom`).
double heroEntranceScale(double seconds, {double duration = 1.0}) =>
    0.965 + 0.035 * heroEase(seconds / duration);

/// The emissive factor at [seconds] after load: a 1 s ramp from 0 into
/// [low], then — when [breathing] — the [heroBreath] low → high → low;
/// otherwise it holds [pinned] (or [low]) as a static glow.
double heroGlowAt(
  double seconds, {
  required double low,
  double amplitude = 0.3,
  double? pinned,
  bool breathing = true,
}) {
  final target = pinned ?? low;
  if (seconds < 1.0) return target * heroEase(seconds);
  if (!breathing || pinned != null) return target;
  return heroBreath(seconds - 1.0, low: low, high: low + amplitude);
}

/// How the hero frames the logo for a view of a given aspect: the boom
/// [distance] and the camera's aim offsets — [aimYaw] turns the view
/// right (so the target sits left of centre) and [aimDrop] tips it down
/// (so the target sits above centre).
final class HeroFraming {
  const HeroFraming({
    required this.distance,
    required this.aimYaw,
    required this.aimDrop,
  });

  final double distance;
  final double aimYaw;
  final double aimDrop;

  /// Portrait (aspect < 1): the sphere at [portraitWidth] of the width,
  /// lifted [portraitLift] of the half-height above centre, clear of
  /// the bottom-anchored copy. Landscape: the sphere in the left half
  /// (centred a quarter of the width in), the copy on the right.
  factory HeroFraming.forView({
    required double frameRadius,
    required double fovY,
    required double aspect,
    double portraitWidth = 0.5,
    double portraitLift = 0.44,
    double heightFraction = 0.34,
  }) {
    final landscape = aspect >= 1;
    final distance = heroBoomDistance(
      frameRadius: frameRadius,
      fovY: fovY,
      aspect: aspect,
      widthFraction: landscape ? portraitWidth / 2 : portraitWidth,
      heightFraction: heightFraction,
    );
    final tanX = tan(fovY / 2) * aspect;
    return HeroFraming(
      distance: distance,
      // Target at NDC x = −0.5 (a quarter of the width from the left).
      aimYaw: landscape ? atan(0.5 * tanX) : 0,
      aimDrop: landscape
          ? 0
          : heroAimDrop(fovY: fovY, screenLift: portraitLift),
    );
  }
}

/// Focal-point bookkeeping for a one-finger orbit fed by a scale
/// recognizer (mirrors the Showcase handler): a delta is reported only
/// when both this and the previous update were single-pointer, so a
/// finger lifting out of a two-finger contact — whose focal point was
/// the centroid — can't snap the orbit.
final class HeroFocalTracker {
  (double, double)? _last;
  int _pointers = 0;

  void start(double x, double y, int pointers) {
    _last = (x, y);
    _pointers = pointers;
  }

  /// The one-finger delta, or null when the pointer count is or was not
  /// 1 (the focal point is rebased either way).
  (double, double)? update(double x, double y, int pointers) {
    final last = _last;
    final prev = _pointers;
    _last = (x, y);
    _pointers = pointers;
    if (pointers != 1 || prev != 1 || last == null) return null;
    return (x - last.$1, y - last.$2);
  }

  void end() {
    _last = null;
    _pointers = 0;
  }
}
