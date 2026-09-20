// dart3d's reference particle simulation (W18) — a line-for-line port
// of flutter_scene's CPU particle stack (`particle_system.dart`,
// `particle_storage.dart`, `spawner.dart`, `emitter_shape.dart`,
// `distribution.dart`, `vec3_distribution.dart`, `particle_module.dart`,
// `curl.dart` + the OpenSimplex2 single-octave slice of
// `fast_noise_lite.dart`), plus a port of
// `particle_emitter_codec.dart`'s `particleSystemFromProperties` so a
// spec decodes straight from the tagged `Map<String, PropertyValue>`
// map a `.fscene` document carries.
//
// Why a port instead of a package import: flutter_scene's particle
// sources transitively import `package:scene/scene.dart`, which fails
// DartNative's kernel build (see scene_model.dart's library doc), and
// pull in `package:flutter` for debugPrint. The port keeps the wire
// vocabulary and the stepping semantics byte-identical so the Android
// runtime (ParticleRuntime.kt, its Kotlin mirror) and these tests can
// pin one behavior contract.
//
// Pure-Dart (vector_math + dart:math + dart:typed_data only) so it is
// reachable under `dart test`.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import 'scene_model.dart';

// ---------------------------------------------------------------------------
// Storage — the structure-of-arrays live set with swap-with-last kill.
// ---------------------------------------------------------------------------

/// dart3d's port of upstream `ParticleStorage`: one tightly packed
/// [Float32List] column per particle property; live particles occupy
/// the dense prefix `[0, aliveCount)`; [kill] compacts by moving the
/// last live particle into the freed slot.
class ParticleStorage {
  ParticleStorage(this.capacity)
    : posX = Float32List(capacity),
      posY = Float32List(capacity),
      posZ = Float32List(capacity),
      velX = Float32List(capacity),
      velY = Float32List(capacity),
      velZ = Float32List(capacity),
      age = Float32List(capacity),
      lifetime = Float32List(capacity),
      rotation = Float32List(capacity),
      angularVelocity = Float32List(capacity),
      size = Float32List(capacity),
      baseSize = Float32List(capacity),
      colorR = Float32List(capacity),
      colorG = Float32List(capacity),
      colorB = Float32List(capacity),
      colorA = Float32List(capacity),
      frame = Float32List(capacity),
      axisX = Float32List(capacity),
      axisY = Float32List(capacity),
      axisZ = Float32List(capacity),
      random01 = Float32List(capacity);

  final int capacity;
  final Float32List posX, posY, posZ;
  final Float32List velX, velY, velZ;
  final Float32List age;
  final Float32List lifetime;
  final Float32List rotation, angularVelocity;
  final Float32List size, baseSize;
  final Float32List colorR, colorG, colorB, colorA;
  final Float32List frame;
  final Float32List axisX, axisY, axisZ;
  final Float32List random01;

  int _aliveCount = 0;
  int get aliveCount => _aliveCount;
  bool get isFull => _aliveCount >= capacity;

  int spawn() {
    if (_aliveCount >= capacity) return -1;
    return _aliveCount++;
  }

  void kill(int index) {
    final last = _aliveCount - 1;
    if (index != last) _copy(last, index);
    _aliveCount--;
  }

  void clear() => _aliveCount = 0;

  /// Upstream's `randomFor` — derives an independent `[0,1)` random for
  /// particle [index] from its stored [random01] and [salt], pure
  /// double arithmetic so it is identical on every backend (and in the
  /// Kotlin port).
  double randomFor(int index, int salt) {
    final x = math.sin(random01[index] * 127.1 + salt * 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }

  void _copy(int from, int to) {
    posX[to] = posX[from];
    posY[to] = posY[from];
    posZ[to] = posZ[from];
    velX[to] = velX[from];
    velY[to] = velY[from];
    velZ[to] = velZ[from];
    age[to] = age[from];
    lifetime[to] = lifetime[from];
    rotation[to] = rotation[from];
    angularVelocity[to] = angularVelocity[from];
    size[to] = size[from];
    baseSize[to] = baseSize[from];
    colorR[to] = colorR[from];
    colorG[to] = colorG[from];
    colorB[to] = colorB[from];
    colorA[to] = colorA[from];
    frame[to] = frame[from];
    axisX[to] = axisX[from];
    axisY[to] = axisY[from];
    axisZ[to] = axisZ[from];
    random01[to] = random01[from];
  }
}

// ---------------------------------------------------------------------------
// Curves / gradients — baked LUTs over normalized time.
// ---------------------------------------------------------------------------

/// Upstream `ParticleKeyframe`: (t, value) over `[0,1]`.
class ParticleKeyframe {
  const ParticleKeyframe(this.t, this.value);
  final double t;
  final double value;
}

/// Upstream `ParticleCurve`: piecewise-linear keys baked into a
/// [resolution]-entry LUT; clamped at the ends.
class ParticleCurve {
  ParticleCurve(List<ParticleKeyframe> keyframes, {this.resolution = 64})
    : keyframes = List.unmodifiable(
        [...keyframes]..sort((a, b) => a.t.compareTo(b.t)),
      ),
      _lut = Float32List(resolution) {
    _bake(this.keyframes);
  }

  ParticleCurve.constant(double value)
    : this([ParticleKeyframe(0, value)], resolution: 2);

  final int resolution;
  final List<ParticleKeyframe> keyframes;
  final Float32List _lut;

  void _bake(List<ParticleKeyframe> sorted) {
    for (var i = 0; i < resolution; i++) {
      final t = i / (resolution - 1);
      _lut[i] = sorted.isEmpty ? 0.0 : _evaluate(sorted, t);
    }
  }

  static double _evaluate(List<ParticleKeyframe> sorted, double t) {
    if (t <= sorted.first.t) return sorted.first.value;
    if (t >= sorted.last.t) return sorted.last.value;
    for (var i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (t >= a.t && t <= b.t) {
        final span = b.t - a.t;
        if (span <= 0) return b.value;
        return a.value + (b.value - a.value) * ((t - a.t) / span);
      }
    }
    return sorted.last.value;
  }

  double sample(double t) {
    final clamped = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
    final x = clamped * (resolution - 1);
    final i = x.floor();
    if (i >= resolution - 1) return _lut[resolution - 1];
    final f = x - i;
    return _lut[i] + (_lut[i + 1] - _lut[i]) * f;
  }
}

/// Upstream `ColorStop`: linear RGBA at normalized [t].
class ColorStop {
  const ColorStop(this.t, this.color);
  final double t;
  final Vector4 color;
}

/// Upstream `ColorGradient`: color stops baked into a
/// `[resolution × 4]` float LUT.
class ColorGradient {
  ColorGradient(List<ColorStop> stops, {this.resolution = 64})
    : stops = List.unmodifiable([...stops]..sort((a, b) => a.t.compareTo(b.t))),
      _lut = Float32List(resolution * 4) {
    _bake(this.stops);
  }

  ColorGradient.constant(Vector4 color)
    : this([ColorStop(0, color)], resolution: 2);

  final int resolution;
  final List<ColorStop> stops;
  final Float32List _lut;

  void _bake(List<ColorStop> sorted) {
    for (var i = 0; i < resolution; i++) {
      final c = _evaluate(sorted, i / (resolution - 1));
      final o = i * 4;
      _lut[o] = c.x;
      _lut[o + 1] = c.y;
      _lut[o + 2] = c.z;
      _lut[o + 3] = c.w;
    }
  }

  static Vector4 _evaluate(List<ColorStop> sorted, double t) {
    if (sorted.isEmpty) return Vector4(1, 1, 1, 1);
    if (t <= sorted.first.t) return sorted.first.color.clone();
    if (t >= sorted.last.t) return sorted.last.color.clone();
    for (var i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (t >= a.t && t <= b.t) {
        final span = b.t - a.t;
        if (span <= 0) return b.color.clone();
        return a.color + (b.color - a.color) * ((t - a.t) / span);
      }
    }
    return sorted.last.color.clone();
  }

  Vector4 sample(double t, [Vector4? out]) {
    final result = out ?? Vector4.zero();
    final clamped = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
    final x = clamped * (resolution - 1);
    final i = x.floor();
    if (i >= resolution - 1) {
      final o = (resolution - 1) * 4;
      result.setValues(_lut[o], _lut[o + 1], _lut[o + 2], _lut[o + 3]);
      return result;
    }
    final f = x - i;
    final o = i * 4;
    final n = o + 4;
    result.setValues(
      _lut[o] + (_lut[n] - _lut[o]) * f,
      _lut[o + 1] + (_lut[n + 1] - _lut[o + 1]) * f,
      _lut[o + 2] + (_lut[n + 2] - _lut[o + 2]) * f,
      _lut[o + 3] + (_lut[n + 3] - _lut[o + 3]) * f,
    );
    return result;
  }
}

// ---------------------------------------------------------------------------
// Distributions
// ---------------------------------------------------------------------------

/// Upstream `FloatDistribution` — `sample(normalizedAge, random01)`.
sealed class FloatDistribution {
  const FloatDistribution();
  double sample(double normalizedAge, double random01);
}

class ConstantFloat extends FloatDistribution {
  const ConstantFloat(this.value);
  final double value;
  @override
  double sample(double normalizedAge, double random01) => value;
}

class UniformFloat extends FloatDistribution {
  const UniformFloat(this.min, this.max);
  final double min, max;
  @override
  double sample(double normalizedAge, double random01) =>
      min + (max - min) * random01;
}

class CurveFloat extends FloatDistribution {
  const CurveFloat(this.curve, {this.scale = 1.0});
  final ParticleCurve curve;
  final double scale;
  @override
  double sample(double normalizedAge, double random01) =>
      curve.sample(normalizedAge) * scale;
}

class UniformCurveFloat extends FloatDistribution {
  const UniformCurveFloat(this.min, this.max);
  final ParticleCurve min, max;
  @override
  double sample(double normalizedAge, double random01) {
    final lo = min.sample(normalizedAge);
    final hi = max.sample(normalizedAge);
    return lo + (hi - lo) * random01;
  }
}

/// Upstream `ColorDistribution` — `sample(nAge, random01, out)`.
sealed class ColorDistribution {
  const ColorDistribution();
  Vector4 sample(double normalizedAge, double random01, [Vector4? out]);
}

class ConstantColor extends ColorDistribution {
  const ConstantColor(this.color);
  final Vector4 color;
  @override
  Vector4 sample(double normalizedAge, double random01, [Vector4? out]) {
    final result = out ?? Vector4.zero();
    return result..setFrom(color);
  }
}

class GradientColor extends ColorDistribution {
  const GradientColor(this.gradient);
  final ColorGradient gradient;
  @override
  Vector4 sample(double normalizedAge, double random01, [Vector4? out]) =>
      gradient.sample(normalizedAge, out);
}

class UniformColor extends ColorDistribution {
  const UniformColor(this.a, this.b);
  final Vector4 a, b;
  @override
  Vector4 sample(double normalizedAge, double random01, [Vector4? out]) {
    final result = out ?? Vector4.zero();
    return result
      ..setFrom(a)
      ..add((b - a)..scale(random01));
  }
}

/// Upstream `UniformBoxVec3` — the only vec3 distribution the emitter
/// shapes use (box positions). Samples three salted randoms.
class UniformBoxVec3 {
  const UniformBoxVec3(this.min, this.max);
  final Vector3 min, max;

  Vector3 sample(
    ParticleStorage storage,
    int index,
    int saltBase, [
    Vector3? out,
  ]) {
    final result = out ?? Vector3.zero();
    final rx = storage.randomFor(index, saltBase);
    final ry = storage.randomFor(index, saltBase + 1);
    final rz = storage.randomFor(index, saltBase + 2);
    result.setValues(
      min.x + (max.x - min.x) * rx,
      min.y + (max.y - min.y) * ry,
      min.z + (max.z - min.z) * rz,
    );
    return result;
  }
}

// ---------------------------------------------------------------------------
// Emitter shapes — spawn position + unit direction into storage.
// ---------------------------------------------------------------------------

sealed class EmitterShape {
  const EmitterShape();
  void sample(ParticleStorage storage, int index);
}

const int _saltA = 20;
const int _saltB = 21;
const int _saltC = 22;
const int _saltD = 23;

class PointEmitterShape extends EmitterShape {
  PointEmitterShape({Vector3? direction})
    : direction = (direction?.clone() ?? Vector3(0, 1, 0))..normalize();
  final Vector3 direction;
  @override
  void sample(ParticleStorage s, int index) {
    s.posX[index] = 0.0;
    s.posY[index] = 0.0;
    s.posZ[index] = 0.0;
    s.velX[index] = direction.x;
    s.velY[index] = direction.y;
    s.velZ[index] = direction.z;
  }
}

class SphereEmitterShape extends EmitterShape {
  const SphereEmitterShape({
    this.radius = 1.0,
    this.surfaceOnly = false,
    this.hemisphere = false,
  });
  final double radius;
  final bool surfaceOnly;
  final bool hemisphere;
  @override
  void sample(ParticleStorage s, int index) {
    final u = s.randomFor(index, _saltA);
    final v = s.randomFor(index, _saltB);
    final y = hemisphere ? u : (2.0 * u - 1.0);
    final ring = math.sqrt(math.max(0.0, 1.0 - y * y));
    final phi = 2.0 * math.pi * v;
    final dx = ring * math.cos(phi);
    final dy = y;
    final dz = ring * math.sin(phi);
    var magnitude = radius;
    if (!surfaceOnly && radius > 0.0) {
      final w = s.randomFor(index, _saltC);
      magnitude = radius * math.pow(w, 1.0 / 3.0).toDouble();
    }
    s.posX[index] = dx * magnitude;
    s.posY[index] = dy * magnitude;
    s.posZ[index] = dz * magnitude;
    s.velX[index] = dx;
    s.velY[index] = dy;
    s.velZ[index] = dz;
  }
}

class ConeEmitterShape extends EmitterShape {
  const ConeEmitterShape({this.angle = 0.5, this.radius = 0.0});
  final double angle;
  final double radius;
  @override
  void sample(ParticleStorage s, int index) {
    final rr = radius * math.sqrt(s.randomFor(index, _saltA));
    final theta = 2.0 * math.pi * s.randomFor(index, _saltB);
    s.posX[index] = rr * math.cos(theta);
    s.posY[index] = 0.0;
    s.posZ[index] = rr * math.sin(theta);
    final cosT = 1.0 - s.randomFor(index, _saltC) * (1.0 - math.cos(angle));
    final sinT = math.sqrt(math.max(0.0, 1.0 - cosT * cosT));
    final phi = 2.0 * math.pi * s.randomFor(index, _saltD);
    s.velX[index] = sinT * math.cos(phi);
    s.velY[index] = cosT;
    s.velZ[index] = sinT * math.sin(phi);
  }
}

class BoxEmitterShape extends EmitterShape {
  BoxEmitterShape({Vector3? halfExtents, Vector3? direction})
    : halfExtents = halfExtents?.clone() ?? Vector3.all(0.5),
      direction = (direction?.clone() ?? Vector3(0, 1, 0))..normalize(),
      _box = UniformBoxVec3(
        (halfExtents?.clone() ?? Vector3.all(0.5))..scale(-1.0),
        halfExtents?.clone() ?? Vector3.all(0.5),
      );
  final Vector3 halfExtents;
  final Vector3 direction;
  final UniformBoxVec3 _box;
  final Vector3 _tmp = Vector3.zero();
  @override
  void sample(ParticleStorage s, int index) {
    _box.sample(s, index, _saltA, _tmp);
    s.posX[index] = _tmp.x;
    s.posY[index] = _tmp.y;
    s.posZ[index] = _tmp.z;
    s.velX[index] = direction.x;
    s.velY[index] = direction.y;
    s.velZ[index] = direction.z;
  }
}

// ---------------------------------------------------------------------------
// Spawner
// ---------------------------------------------------------------------------

/// Upstream `ParticleBurst` — a scheduled emission window.
class ParticleBurst {
  const ParticleBurst({
    required this.time,
    required this.count,
    this.interval = 0.0,
    this.cycles,
  });
  final double time;
  final int count;
  final double interval;
  final int? cycles;
}

/// Upstream `Spawner` — fractional rate accumulation + half-open
/// burst windows.
class Spawner {
  Spawner({this.rate = 0.0, List<ParticleBurst> bursts = const []})
    : bursts = List.unmodifiable(bursts);

  double rate;
  final List<ParticleBurst> bursts;
  double _accumulator = 0.0;

  int emit(double dt, double time) {
    var count = 0;
    if (rate > 0.0) {
      _accumulator += rate * dt;
      final whole = _accumulator.floor();
      _accumulator -= whole;
      count += whole;
    }
    if (bursts.isNotEmpty) {
      final end = time + dt;
      for (final burst in bursts) {
        if (burst.interval > 0.0) {
          final inverse = 1.0 / burst.interval;
          var first = ((time - burst.time) * inverse).ceil();
          if (first < 0) first = 0;
          var last = ((end - burst.time) * inverse).ceil() - 1;
          final cycles = burst.cycles;
          if (cycles != null && last > cycles - 1) last = cycles - 1;
          if (last >= first) count += (last - first + 1) * burst.count;
        } else if (burst.time >= time && burst.time < end) {
          count += burst.count;
        }
      }
    }
    return count;
  }

  void reset() => _accumulator = 0.0;
}

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

/// Upstream `ParticleModule` — spawn-phase + update-phase hooks.
abstract class ParticleModule {
  const ParticleModule();
  void spawn(ParticleStorage storage, int index) {}
  void update(ParticleStorage storage, double dt) {}
}

class AccelerationModule extends ParticleModule {
  AccelerationModule(Vector3 acceleration)
    : acceleration = acceleration.clone();
  final Vector3 acceleration;
  @override
  void update(ParticleStorage s, double dt) {
    final ax = acceleration.x * dt;
    final ay = acceleration.y * dt;
    final az = acceleration.z * dt;
    final n = s.aliveCount;
    for (var i = 0; i < n; i++) {
      s.velX[i] += ax;
      s.velY[i] += ay;
      s.velZ[i] += az;
    }
  }
}

class LinearDragModule extends ParticleModule {
  LinearDragModule(this.coefficient);
  double coefficient;
  @override
  void update(ParticleStorage s, double dt) {
    var factor = 1.0 - coefficient * dt;
    if (factor < 0.0) factor = 0.0;
    final n = s.aliveCount;
    for (var i = 0; i < n; i++) {
      s.velX[i] *= factor;
      s.velY[i] *= factor;
      s.velZ[i] *= factor;
    }
  }
}

class SizeOverLifeModule extends ParticleModule {
  const SizeOverLifeModule(this.scale);
  final FloatDistribution scale;
  @override
  void update(ParticleStorage s, double dt) {
    final n = s.aliveCount;
    for (var i = 0; i < n; i++) {
      final life = s.lifetime[i];
      final nAge = life > 0.0 ? s.age[i] / life : 0.0;
      s.size[i] = s.baseSize[i] * scale.sample(nAge, s.random01[i]);
    }
  }
}

class ColorOverLifeModule extends ParticleModule {
  ColorOverLifeModule(this.color);
  final ColorDistribution color;
  final Vector4 _tmp = Vector4.zero();
  @override
  void update(ParticleStorage s, double dt) {
    final n = s.aliveCount;
    for (var i = 0; i < n; i++) {
      final life = s.lifetime[i];
      final nAge = life > 0.0 ? s.age[i] / life : 0.0;
      color.sample(nAge, s.random01[i], _tmp);
      s.colorR[i] = _tmp.x;
      s.colorG[i] = _tmp.y;
      s.colorB[i] = _tmp.z;
      s.colorA[i] = _tmp.w;
    }
  }
}

const int _saltFlipbookStart = 10;

class FlipbookModule extends ParticleModule {
  const FlipbookModule({
    required this.frameCount,
    this.framesPerSecond,
    this.randomStartFrame = false,
  });
  final int frameCount;
  final double? framesPerSecond;
  final bool randomStartFrame;
  @override
  void update(ParticleStorage s, double dt) {
    final count = frameCount.toDouble();
    final fps = framesPerSecond;
    final n = s.aliveCount;
    for (var i = 0; i < n; i++) {
      var frame = 0.0;
      if (fps == null) {
        final life = s.lifetime[i];
        final nAge = life > 0.0 ? s.age[i] / life : 0.0;
        frame = nAge * count;
        if (frame > count - 1.0) frame = count - 1.0;
      } else {
        frame = s.age[i] * fps;
      }
      if (randomStartFrame) {
        frame += s.randomFor(i, _saltFlipbookStart) * count;
      }
      s.frame[i] = frame % count;
    }
  }
}

/// Upstream `TurbulenceModule` — curl-noise advection against a
/// drifting field (the OpenSimplex2 slice below is its substrate).
class TurbulenceModule extends ParticleModule {
  TurbulenceModule({
    this.strength = 1.0,
    this.frequency = 1.0,
    Vector3? scroll,
    this.seed = 1337,
  }) : scroll = scroll?.clone() ?? Vector3.zero();
  double strength;
  double frequency;
  final Vector3 scroll;
  final int seed;
  double _time = 0.0;
  @override
  void update(ParticleStorage s, double dt) {
    _time += dt;
    final ox = scroll.x * _time * frequency;
    final oy = scroll.y * _time * frequency;
    final oz = scroll.z * _time * frequency;
    final n = s.aliveCount;
    for (var i = 0; i < n; i++) {
      final curl = noiseCurl3(
        s.posX[i] * frequency - ox,
        s.posY[i] * frequency - oy,
        s.posZ[i] * frequency - oz,
        seed: seed,
      );
      s.velX[i] += curl.x * strength * dt;
      s.velY[i] += curl.y * strength * dt;
      s.velZ[i] += curl.z * strength * dt;
    }
  }
}

class RotationModule extends ParticleModule {
  const RotationModule();
  @override
  void update(ParticleStorage s, double dt) {
    final n = s.aliveCount;
    for (var i = 0; i < n; i++) {
      s.rotation[i] += s.angularVelocity[i] * dt;
    }
  }
}

// ---------------------------------------------------------------------------
// Curl noise — upstream curl.dart on the OpenSimplex2-3D single octave
// of fast_noise_lite.dart (the only path it exercises: frequency 1.0,
// fractalType none). The gradient table is transcribed verbatim.
// ---------------------------------------------------------------------------

({double x, double y, double z}) noiseCurl3(
  double x,
  double y,
  double z, {
  int seed = 1337,
  double epsilon = 0.25,
}) {
  final inv = 1.0 / (2.0 * epsilon);
  final p0y1 = _potential(seed, x, y + epsilon, z);
  final p0y0 = _potential(seed, x, y - epsilon, z);
  final p0z1 = _potential(seed, x, y, z + epsilon);
  final p0z0 = _potential(seed, x, y, z - epsilon);
  final p1x1 = _potential(seed + 1, x + epsilon, y, z);
  final p1x0 = _potential(seed + 1, x - epsilon, y, z);
  final p1z1 = _potential(seed + 1, x, y, z + epsilon);
  final p1z0 = _potential(seed + 1, x, y, z - epsilon);
  final p2x1 = _potential(seed + 2, x + epsilon, y, z);
  final p2x0 = _potential(seed + 2, x - epsilon, y, z);
  final p2y1 = _potential(seed + 2, x, y + epsilon, z);
  final p2y0 = _potential(seed + 2, x, y - epsilon, z);
  return (
    x: ((p2y1 - p2y0) - (p1z1 - p1z0)) * inv,
    y: ((p0z1 - p0z0) - (p2x1 - p2x0)) * inv,
    z: ((p1x1 - p1x0) - (p0y1 - p0y0)) * inv,
  );
}

double _potential(int seed, double x, double y, double z) {
  // getNoise3's OpenSimplex2 pre-rotation (r3 = 2/3) then the single
  // octave — frequency is 1.0 at the call site.
  const r3 = 2.0 / 3.0;
  final r = (x + y + z) * r3;
  return _singleOpenSimplex2_3(seed, r - x, r - y, r - z);
}

const int _primeX = 501125321;
const int _primeY = 1136930381;
const int _primeZ = 1720413743;

int _i32(int v) => v.toSigned(32);

int _fastRound(double f) => f >= 0 ? (f + 0.5).toInt() : (f - 0.5).toInt();

int _hash3(int seed, int xPrimed, int yPrimed, int zPrimed) {
  var hash = _i32(seed ^ xPrimed ^ yPrimed ^ zPrimed);
  hash = _i32(hash * 0x27d4eb2d);
  return hash;
}

double _gradCoord3(
  int seed,
  int xPrimed,
  int yPrimed,
  int zPrimed,
  double xd,
  double yd,
  double zd,
) {
  var hash = _hash3(seed, xPrimed, yPrimed, zPrimed);
  hash ^= hash >> 15;
  hash &= 63 << 2;
  final xg = _gradients3D[hash];
  final yg = _gradients3D[hash | 1];
  final zg = _gradients3D[hash | 2];
  return xd * xg + yd * yg + zd * zg;
}

double _singleOpenSimplex2_3(int seed, double x, double y, double z) {
  var i = _fastRound(x);
  var j = _fastRound(y);
  var k = _fastRound(z);
  var x0 = x - i;
  var y0 = y - j;
  var z0 = z - k;

  var xNSign = (-1.0 - x0).toInt() | 1;
  var yNSign = (-1.0 - y0).toInt() | 1;
  var zNSign = (-1.0 - z0).toInt() | 1;

  var ax0 = xNSign * -x0;
  var ay0 = yNSign * -y0;
  var az0 = zNSign * -z0;

  i = _i32(i * _primeX);
  j = _i32(j * _primeY);
  k = _i32(k * _primeZ);

  var value = 0.0;
  var a = (0.6 - x0 * x0) - (y0 * y0 + z0 * z0);

  for (var l = 0; ; l++) {
    if (a > 0) {
      value += (a * a) * (a * a) * _gradCoord3(seed, i, j, k, x0, y0, z0);
    }

    if (ax0 >= ay0 && ax0 >= az0) {
      var b = a + ax0 + ax0;
      if (b > 1) {
        b -= 1;
        value +=
            (b * b) *
            (b * b) *
            _gradCoord3(
              seed,
              _i32(i - xNSign * _primeX),
              j,
              k,
              x0 + xNSign,
              y0,
              z0,
            );
      }
    } else if (ay0 > ax0 && ay0 >= az0) {
      var b = a + ay0 + ay0;
      if (b > 1) {
        b -= 1;
        value +=
            (b * b) *
            (b * b) *
            _gradCoord3(
              seed,
              i,
              _i32(j - yNSign * _primeY),
              k,
              x0,
              y0 + yNSign,
              z0,
            );
      }
    } else {
      var b = a + az0 + az0;
      if (b > 1) {
        b -= 1;
        value +=
            (b * b) *
            (b * b) *
            _gradCoord3(
              seed,
              i,
              j,
              _i32(k - zNSign * _primeZ),
              x0,
              y0,
              z0 + zNSign,
            );
      }
    }

    if (l == 1) break;

    ax0 = 0.5 - ax0;
    ay0 = 0.5 - ay0;
    az0 = 0.5 - az0;

    x0 = xNSign * ax0;
    y0 = yNSign * ay0;
    z0 = zNSign * az0;

    a += (0.75 - ax0) - (ay0 + az0);

    i = _i32(i + ((xNSign >> 1) & _primeX));
    j = _i32(j + ((yNSign >> 1) & _primeY));
    k = _i32(k + ((zNSign >> 1) & _primeZ));

    xNSign = -xNSign;
    yNSign = -yNSign;
    zNSign = -zNSign;

    seed = ~seed;
  }

  return value * 32.69428253173828125;
}

// 64 gradient vectors, stride 4 (w padded 0) — transcribed verbatim
// from upstream fast_noise_lite.dart's `_gradients3D`.
final Float64List _gradients3D = Float64List.fromList(<double>[
  0.0,
  1.0,
  1.0,
  0.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  0.0,
  1.0,
  -1.0,
  0.0,
  0.0,
  -1.0,
  -1.0,
  0.0,
  1.0,
  0.0,
  1.0,
  0.0,
  -1.0,
  0.0,
  1.0,
  0.0,
  1.0,
  0.0,
  -1.0,
  0.0,
  -1.0,
  0.0,
  -1.0,
  0.0,
  1.0,
  1.0,
  0.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  0.0,
  1.0,
  -1.0,
  0.0,
  0.0,
  -1.0,
  -1.0,
  0.0,
  0.0,
  0.0,
  1.0,
  1.0,
  0.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  0.0,
  1.0,
  -1.0,
  0.0,
  0.0,
  -1.0,
  -1.0,
  0.0,
  1.0,
  0.0,
  1.0,
  0.0,
  -1.0,
  0.0,
  1.0,
  0.0,
  1.0,
  0.0,
  -1.0,
  0.0,
  -1.0,
  0.0,
  -1.0,
  0.0,
  1.0,
  1.0,
  0.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  0.0,
  1.0,
  -1.0,
  0.0,
  0.0,
  -1.0,
  -1.0,
  0.0,
  0.0,
  0.0,
  1.0,
  1.0,
  0.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  0.0,
  1.0,
  -1.0,
  0.0,
  0.0,
  -1.0,
  -1.0,
  0.0,
  1.0,
  0.0,
  1.0,
  0.0,
  -1.0,
  0.0,
  1.0,
  0.0,
  1.0,
  0.0,
  -1.0,
  0.0,
  -1.0,
  0.0,
  -1.0,
  0.0,
  1.0,
  1.0,
  0.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  0.0,
  1.0,
  -1.0,
  0.0,
  0.0,
  -1.0,
  -1.0,
  0.0,
  0.0,
  0.0,
  1.0,
  1.0,
  0.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  0.0,
  1.0,
  -1.0,
  0.0,
  0.0,
  -1.0,
  -1.0,
  0.0,
  1.0,
  0.0,
  1.0,
  0.0,
  -1.0,
  0.0,
  1.0,
  0.0,
  1.0,
  0.0,
  -1.0,
  0.0,
  -1.0,
  0.0,
  -1.0,
  0.0,
  1.0,
  1.0,
  0.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  0.0,
  1.0,
  -1.0,
  0.0,
  0.0,
  -1.0,
  -1.0,
  0.0,
  0.0,
  0.0,
  1.0,
  1.0,
  0.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  0.0,
  1.0,
  -1.0,
  0.0,
  0.0,
  -1.0,
  -1.0,
  0.0,
  1.0,
  0.0,
  1.0,
  0.0,
  -1.0,
  0.0,
  1.0,
  0.0,
  1.0,
  0.0,
  -1.0,
  0.0,
  -1.0,
  0.0,
  -1.0,
  0.0,
  1.0,
  1.0,
  0.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  0.0,
  1.0,
  -1.0,
  0.0,
  0.0,
  -1.0,
  -1.0,
  0.0,
  0.0,
  1.0,
  1.0,
  0.0,
  0.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  -1.0,
  1.0,
  0.0,
  0.0,
  0.0,
  -1.0,
  -1.0,
  0.0,
]);

// ---------------------------------------------------------------------------
// The system — upstream ParticleSystem verbatim modulo naming.
// ---------------------------------------------------------------------------

const int _saltLifetime = 1;
const int _saltSpeed = 2;
const int _saltSize = 3;
const int _saltRotation = 4;
const int _saltAngularVelocity = 5;
const int _saltColor = 6;
const int _saltAxisTheta = 7;
const int _saltAxisZ = 8;

const double _minLifetime = 1e-4;

/// dart3d's port of upstream `ParticleSystem`: fixed-timestep
/// accumulation, spawn→modules→integrate→reap per step, all spawn
/// randomness drawn from [seed] (a Dart `math.Random` — the Kotlin
/// twin uses java.util.Random; streams differ across engines but each
/// is self-consistent, which is the determinism contract
/// fixedStep/maxFrameTime/seed sell).
class ParticleSystem {
  ParticleSystem({
    int maxParticles = 1024,
    required this.shape,
    required this.spawner,
    List<ParticleModule> modules = const [],
    this.lifetime = const ConstantFloat(1.0),
    this.startSpeed = const ConstantFloat(0.0),
    this.startSize = const ConstantFloat(1.0),
    this.startRotation = const ConstantFloat(0.0),
    this.startAngularVelocity = const ConstantFloat(0.0),
    ColorDistribution? startColor,
    Vector3? gravity,
    this.looping = true,
    this.duration = 5.0,
    this.fixedStep = 1.0 / 60.0,
    this.maxFrameTime = 0.25,
    this.seed = 0,
    this.prewarm = 0.0,
  }) : storage = ParticleStorage(maxParticles),
       modules = List.unmodifiable(modules),
       startColor = startColor ?? ConstantColor(Vector4(1, 1, 1, 1)),
       gravity = gravity?.clone() ?? Vector3.zero(),
       _random = math.Random(seed) {
    if (prewarm > 0.0) {
      final steps = (prewarm / fixedStep).floor();
      for (var i = 0; i < steps; i++) {
        _stepFixed(fixedStep);
      }
    }
  }

  final ParticleStorage storage;
  final double prewarm;
  EmitterShape shape;
  final Spawner spawner;
  final List<ParticleModule> modules;
  FloatDistribution lifetime,
      startSpeed,
      startSize,
      startRotation,
      startAngularVelocity;
  ColorDistribution startColor;
  final Vector3 gravity;
  bool looping;
  double duration;
  final double fixedStep;
  final double maxFrameTime;
  final int seed;

  math.Random _random;
  double _accumulator = 0.0;
  double _systemTime = 0.0;
  final Vector4 _tmpColor = Vector4.zero();

  double get time => _systemTime;

  void step(double dt) {
    var frame = dt;
    if (frame < 0.0) frame = 0.0;
    if (frame > maxFrameTime) frame = maxFrameTime;
    _accumulator += frame;
    while (_accumulator >= fixedStep) {
      _stepFixed(fixedStep);
      _accumulator -= fixedStep;
    }
  }

  void reset() {
    storage.clear();
    spawner.reset();
    _random = math.Random(seed);
    _accumulator = 0.0;
    _systemTime = 0.0;
  }

  void _stepFixed(double dt) {
    if (looping || _systemTime < duration) {
      final toSpawn = spawner.emit(dt, _systemTime);
      for (var i = 0; i < toSpawn; i++) {
        final index = storage.spawn();
        if (index < 0) break;
        _initParticle(index);
      }
    }
    for (final module in modules) {
      module.update(storage, dt);
    }
    final gx = gravity.x * dt, gy = gravity.y * dt, gz = gravity.z * dt;
    final n = storage.aliveCount;
    for (var i = 0; i < n; i++) {
      storage.velX[i] += gx;
      storage.velY[i] += gy;
      storage.velZ[i] += gz;
      storage.posX[i] += storage.velX[i] * dt;
      storage.posY[i] += storage.velY[i] * dt;
      storage.posZ[i] += storage.velZ[i] * dt;
    }
    for (var i = storage.aliveCount - 1; i >= 0; i--) {
      storage.age[i] += dt;
      if (storage.age[i] >= storage.lifetime[i]) {
        storage.kill(i);
      }
    }
    _systemTime += dt;
  }

  void _initParticle(int index) {
    final s = storage;
    s.random01[index] = _random.nextDouble();
    s.age[index] = 0.0;

    shape.sample(s, index);

    var life = lifetime.sample(0.0, s.randomFor(index, _saltLifetime));
    if (life < _minLifetime) life = _minLifetime;
    s.lifetime[index] = life;

    final speed = startSpeed.sample(0.0, s.randomFor(index, _saltSpeed));
    s.velX[index] *= speed;
    s.velY[index] *= speed;
    s.velZ[index] *= speed;

    final size = startSize.sample(0.0, s.randomFor(index, _saltSize));
    s.size[index] = size;
    s.baseSize[index] = size;

    s.rotation[index] = startRotation.sample(
      0.0,
      s.randomFor(index, _saltRotation),
    );
    s.angularVelocity[index] = startAngularVelocity.sample(
      0.0,
      s.randomFor(index, _saltAngularVelocity),
    );

    final c = startColor.sample(0.0, s.randomFor(index, _saltColor), _tmpColor);
    s.colorR[index] = c.x;
    s.colorG[index] = c.y;
    s.colorB[index] = c.z;
    s.colorA[index] = c.w;

    s.frame[index] = 0.0;

    final az = s.randomFor(index, _saltAxisZ) * 2.0 - 1.0;
    final at = s.randomFor(index, _saltAxisTheta) * 2.0 * math.pi;
    final ar = math.sqrt(math.max(0.0, 1.0 - az * az));
    s.axisX[index] = ar * math.cos(at);
    s.axisY[index] = ar * math.sin(at);
    s.axisZ[index] = az;

    for (final module in modules) {
      module.spawn(s, index);
    }
  }
}

/// The per-frame tick contract both natives implement — a port of
/// upstream `Component.update`'s gating: [enabled] (the universal
/// component flag, W18's first consumer) suppresses the whole tick,
/// simulation *and* repack; [paused] suppresses only the step, so a
/// held system keeps drawing its last repacked state. The natives
/// implement this contract: iOS drives `SCNParticleSystem`, Android the
/// CPU sim in ParticleRuntime.kt.
class ParticleEmitterRuntime {
  ParticleEmitterRuntime({
    required this.system,
    this.enabled = true,
    this.paused = false,
  });

  final ParticleSystem system;
  bool enabled;
  bool paused;

  /// Steps the system by [dt] under the enabled/paused gates, then
  /// repacks. [repack] runs whenever the gate allows a tick — even when
  /// paused — mirroring upstream's `update()` (a paused emitter still
  /// refreshes its buffers, e.g. after a property edit).
  void tick(double dt, void Function(ParticleStorage storage) repack) {
    if (!enabled) return;
    if (!paused) system.step(dt);
    repack(system.storage);
  }
}

// ---------------------------------------------------------------------------
// Spec decode — port of particle_emitter_codec.dart's readers. The
// input is the component's `properties` map, exactly what the wire
// carries (MapValue/ListValue/tagged scalars).
// ---------------------------------------------------------------------------

const int _kMaxParticles = 512;
const double _kEmitRate = 32.0;
const double _kLifetime = 1.5;
const double _kStartSpeed = 1.5;
const double _kStartSize = 0.3;
const double _kDefaultShapeRadius = 0.25;
const double _kDefaultShapeAngle = 0.3;
const double _kDuration = 5.0;
const double _kFixedStep = 1.0 / 60.0;
const double _kMaxFrameTime = 0.25;

EmitterShape _defaultShape() => const ConeEmitterShape(
  angle: _kDefaultShapeAngle,
  radius: _kDefaultShapeRadius,
);

Vector4 _opaqueWhite() => Vector4(1, 1, 1, 1);

/// Decodes an `EmitterShape` from a tagged map; unrecognized or absent
/// input yields the default cone (upstream `decodeEmitterShape`).
EmitterShape decodeEmitterShape(PropertyValue? value) {
  if (value is! MapValue) return _defaultShape();
  final m = value.values;
  return switch (_str(m, 'kind', 'cone')) {
    'point' => PointEmitterShape(
      direction: _vec3(m, 'direction', Vector3(0, 1, 0)),
    ),
    'sphere' => SphereEmitterShape(
      radius: _nonNegative(_num(m, 'radius', 1.0)),
      surfaceOnly: _bool(m, 'surfaceOnly', false),
      hemisphere: _bool(m, 'hemisphere', false),
    ),
    'box' => BoxEmitterShape(
      halfExtents: _vec3(m, 'halfExtents', Vector3.all(0.5)),
      direction: _vec3(m, 'direction', Vector3(0, 1, 0)),
    ),
    _ => ConeEmitterShape(
      radius: _nonNegative(_num(m, 'radius', 0.0)),
      angle: _nonNegative(_num(m, 'angle', 0.5)),
    ),
  };
}

/// Decodes one module tagged map; null on unknown/malformed kinds.
ParticleModule? decodeParticleModule(PropertyValue? value) {
  if (value is! MapValue) return null;
  final m = value.values;
  return switch (_str(m, 'kind', '')) {
    'acceleration' => AccelerationModule(
      _vec3(m, 'acceleration', Vector3.zero()),
    ),
    'linearDrag' => LinearDragModule(_nonNegative(_num(m, 'coefficient', 0.0))),
    'sizeOverLife' => SizeOverLifeModule(
      decodeFloatDistribution(m['scale'], fallback: 1.0),
    ),
    'colorOverLife' => ColorOverLifeModule(decodeColorDistribution(m['color'])),
    'flipbook' => _decodeFlipbook(m),
    'turbulence' => TurbulenceModule(
      strength: _num(m, 'strength', 1.0),
      frequency: _num(m, 'frequency', 1.0),
      scroll: _vec3(m, 'scroll', Vector3.zero()),
      seed: _int(m, 'seed', 1337),
    ),
    'rotation' => const RotationModule(),
    _ => null,
  };
}

FlipbookModule _decodeFlipbook(Map<String, PropertyValue> m) {
  final frameCount = _int(m, 'frameCount', 1);
  final fps = _num(m, 'framesPerSecond', 0.0);
  return FlipbookModule(
    frameCount: frameCount < 1 ? 1 : frameCount,
    framesPerSecond: fps > 0 ? fps : null,
    randomStartFrame: _bool(m, 'randomStartFrame', false),
  );
}

/// Decodes `{time, count, interval?, cycles?}`; null when malformed.
ParticleBurst? decodeParticleBurst(PropertyValue? value) {
  if (value is! MapValue) return null;
  final m = value.values;
  final cycles = m['cycles'];
  return ParticleBurst(
    time: _nonNegative(_num(m, 'time', 0.0)),
    count: _int(m, 'count', 0) < 0 ? 0 : _int(m, 'count', 0),
    interval: _num(m, 'interval', 0.0),
    cycles: cycles is IntValue ? (cycles.value < 1 ? 1 : cycles.value) : null,
  );
}

/// Port of upstream `particleSystemFromProperties` — builds the sim
/// from a component's property map with the format's authoring
/// defaults; accepts the legacy flat keys (`shapeType`/`shapeRadius`/
/// `shapeAngle`, `drag`/`sizeOverLife`/`colorOverLife`) when the union
/// members are absent.
ParticleSystem particleSystemFromProperties(
  Map<String, PropertyValue> properties,
) {
  final fixedStep = switch (_num(properties, 'fixedStep', _kFixedStep)) {
    final step when step > 0 => step,
    _ => _kFixedStep,
  };
  var maxFrameTime = _num(properties, 'maxFrameTime', _kMaxFrameTime);
  if (maxFrameTime < fixedStep) maxFrameTime = fixedStep;
  final duration = _num(properties, 'duration', _kDuration);
  final maxParticles = _int(properties, 'maxParticles', _kMaxParticles);
  return ParticleSystem(
    maxParticles: maxParticles < 1 ? 1 : maxParticles,
    shape: _shapeFromProperties(properties),
    spawner: Spawner(
      rate: _nonNegative(_num(properties, 'emitRate', _kEmitRate)),
      bursts: _burstsFromProperties(properties),
    ),
    modules: _modulesFromProperties(properties),
    lifetime: _dist(properties, 'lifetime', _kLifetime),
    startSpeed: _dist(properties, 'startSpeed', _kStartSpeed),
    startSize: _dist(properties, 'startSize', _kStartSize),
    startRotation: _dist(properties, 'startRotation', 0),
    startAngularVelocity: _dist(properties, 'startAngularVelocity', 0),
    startColor: decodeColorDistribution(properties['startColor']),
    gravity: _vec3(properties, 'gravity', Vector3.zero()),
    looping: _bool(properties, 'looping', true),
    duration: duration > 0 ? duration : _kDuration,
    fixedStep: fixedStep,
    maxFrameTime: maxFrameTime,
    seed: _int(properties, 'seed', 0),
    prewarm: _nonNegative(_num(properties, 'prewarm', 0)),
  );
}

/// The render-side half of a `particleEmitter` spec — the billboard
/// knobs that don't feed the sim.
class SpriteEmitterSpec {
  const SpriteEmitterSpec({
    this.blendMode = 'alpha',
    this.facing = 'spherical',
    this.velocityStretch = 0.0,
    this.paused = false,
    this.flipbookColumns = 1,
    this.flipbookRows = 1,
    this.flipbookBlend = false,
    this.randomFlipX = false,
    this.aspectRatio = 1.0,
    this.texture,
    this.enabled = true,
  });
  final String blendMode;
  final String facing;
  final double velocityStretch;
  final bool paused;
  final int flipbookColumns;
  final int flipbookRows;
  final bool flipbookBlend;
  final bool randomFlipX;
  final double aspectRatio;
  final LocalId? texture;

  /// The universal `enabled` component gate — W18 is its first
  /// consumer: false freezes the emitter outright (no simulation
  /// step, no repack).
  final bool enabled;
}

/// Decodes the sprite-side fields of a `particleEmitter` spec.
SpriteEmitterSpec spriteEmitterSpecFromProperties(
  Map<String, PropertyValue> properties,
) => SpriteEmitterSpec(
  blendMode: _str(properties, 'blendMode', 'alpha'),
  facing: _str(properties, 'facing', 'spherical'),
  velocityStretch: _nonNegative(_num(properties, 'velocityStretch', 0)),
  paused: _bool(properties, 'paused', false),
  flipbookColumns: _int(properties, 'flipbookColumns', 1) < 1
      ? 1
      : _int(properties, 'flipbookColumns', 1),
  flipbookRows: _int(properties, 'flipbookRows', 1) < 1
      ? 1
      : _int(properties, 'flipbookRows', 1),
  flipbookBlend: _bool(properties, 'flipbookBlend', false),
  randomFlipX: _bool(properties, 'randomFlipX', false),
  aspectRatio: _nonNegative(_num(properties, 'aspectRatio', 1.0)),
  texture: properties['texture'] is ResourceRefValue
      ? (properties['texture']! as ResourceRefValue).id
      : null,
  enabled: _bool(properties, 'enabled', true),
);

/// The render-side half of a `meshParticleEmitter` spec.
class MeshEmitterSpec {
  const MeshEmitterSpec({
    required this.geometries,
    this.material,
    this.facing = 'tumble',
    this.paused = false,
    this.enabled = true,
  });
  final List<LocalId> geometries;
  final LocalId? material;
  final String facing;
  final bool paused;
  final bool enabled;
}

/// Decodes the mesh-side fields of a `meshParticleEmitter` spec —
/// upstream's `_geometryIds`/`material`/`facing`/`paused` readers.
MeshEmitterSpec meshEmitterSpecFromProperties(
  Map<String, PropertyValue> properties,
) {
  final geometries = properties['geometries'];
  return MeshEmitterSpec(
    geometries: [
      if (geometries is ListValue)
        for (final entry in geometries.values)
          if (entry is ResourceRefValue) entry.id,
    ],
    material: properties['material'] is ResourceRefValue
        ? (properties['material']! as ResourceRefValue).id
        : null,
    facing: _str(properties, 'facing', 'tumble'),
    paused: _bool(properties, 'paused', false),
    enabled: _bool(properties, 'enabled', true),
  );
}

EmitterShape _shapeFromProperties(Map<String, PropertyValue> p) {
  final shape = p['shape'];
  if (shape is MapValue) return decodeEmitterShape(shape);
  final radius = _nonNegative(_num(p, 'shapeRadius', _kDefaultShapeRadius));
  final angle = _nonNegative(_num(p, 'shapeAngle', _kDefaultShapeAngle));
  return switch (_str(p, 'shapeType', 'cone')) {
    'point' => PointEmitterShape(),
    'sphere' => SphereEmitterShape(radius: radius),
    'box' => BoxEmitterShape(halfExtents: Vector3.all(radius)),
    _ => ConeEmitterShape(angle: angle, radius: radius),
  };
}

List<ParticleModule> _modulesFromProperties(Map<String, PropertyValue> p) {
  final modules = p['modules'];
  if (modules is ListValue) {
    return [
      for (final entry in modules.values)
        if (decodeParticleModule(entry) case final module?) module,
    ];
  }
  // Legacy fixed stack — an absent curve/gradient means "no shaping",
  // not the decoders' empty-input fallbacks.
  final drag = _num(p, 'drag', 0);
  final sizeOverLife = p['sizeOverLife'];
  final colorOverLife = p['colorOverLife'];
  return [
    if (drag > 0) LinearDragModule(drag),
    SizeOverLifeModule(
      CurveFloat(
        sizeOverLife != null
            ? decodeParticleCurve(sizeOverLife)
            : ParticleCurve.constant(1.0),
      ),
    ),
    ColorOverLifeModule(
      GradientColor(
        colorOverLife != null
            ? decodeColorGradient(colorOverLife)
            : ColorGradient.constant(_opaqueWhite()),
      ),
    ),
    const RotationModule(),
  ];
}

List<ParticleBurst> _burstsFromProperties(Map<String, PropertyValue> p) {
  final bursts = p['bursts'];
  if (bursts is! ListValue) return const [];
  return [
    for (final entry in bursts.values)
      if (decodeParticleBurst(entry) case final burst?) burst,
  ];
}

// ---------------------------------------------------------------------------
// Tagged-value readers — the PropertyValue twins of the codec's
// `_num`/`_int`/`_bool`/`_str`/`_vec3`/`_dist` helpers.
// ---------------------------------------------------------------------------

double _nonNegative(double value) => value < 0 ? 0 : value;

double _num(Map<String, PropertyValue> p, String key, double fallback) {
  final v = p[key];
  return v is DoubleValue
      ? v.value
      : v is IntValue
      ? v.value.toDouble()
      : fallback;
}

int _int(Map<String, PropertyValue> p, String key, int fallback) {
  final v = p[key];
  return v is IntValue
      ? v.value
      : v is DoubleValue
      ? v.value.round()
      : fallback;
}

bool _bool(Map<String, PropertyValue> p, String key, bool fallback) {
  final v = p[key];
  return v is BoolValue ? v.value : fallback;
}

String _str(Map<String, PropertyValue> p, String key, String fallback) {
  final v = p[key];
  return v is StringValue ? v.value : fallback;
}

Vector3 _vec3(Map<String, PropertyValue> p, String key, Vector3 fallback) {
  final v = p[key];
  return v is Vec3Value ? v.value.clone() : fallback;
}

FloatDistribution _dist(
  Map<String, PropertyValue> p,
  String key,
  double fallback,
) => decodeFloatDistribution(p[key], fallback: fallback);

// --- particle_property_values.dart ports ---

/// `{keys: [{t, v}, …]}` → [ParticleCurve]; empty/absent → constant 0.
ParticleCurve decodeParticleCurve(PropertyValue? value) {
  final keys = <ParticleKeyframe>[];
  if (value is MapValue && value.values['keys'] is ListValue) {
    for (final entry in (value.values['keys']! as ListValue).values) {
      if (entry is MapValue) {
        keys.add(
          ParticleKeyframe(
            _num(entry.values, 't', 0),
            _num(entry.values, 'v', 0),
          ),
        );
      }
    }
  }
  return ParticleCurve(keys);
}

/// `{stops: [{t, color}, …]}` → [ColorGradient]; empty/absent →
/// opaque white.
ColorGradient decodeColorGradient(PropertyValue? value) {
  final stops = <ColorStop>[];
  if (value is MapValue && value.values['stops'] is ListValue) {
    for (final entry in (value.values['stops']! as ListValue).values) {
      if (entry is MapValue) {
        final c = entry.values['color'];
        final color = c is ColorValue
            ? Vector4(c.r, c.g, c.b, c.a)
            : Vector4(1, 1, 1, 1);
        stops.add(ColorStop(_num(entry.values, 't', 0), color));
      }
    }
  }
  return ColorGradient(stops);
}

/// `{kind: constant|uniform|curve|uniformCurve, …}` →
/// [FloatDistribution]; unrecognized/absent → `ConstantFloat(fallback)`.
FloatDistribution decodeFloatDistribution(
  PropertyValue? value, {
  double fallback = 0.0,
}) {
  if (value is! MapValue) return ConstantFloat(fallback);
  final m = value.values;
  final kind = _str(m, 'kind', 'constant');
  return switch (kind) {
    'uniform' => UniformFloat(
      _num(m, 'min', fallback),
      _num(m, 'max', fallback),
    ),
    'curve' => CurveFloat(
      decodeParticleCurve(m['curve']),
      scale: _num(m, 'scale', 1.0),
    ),
    'uniformCurve' => UniformCurveFloat(
      decodeParticleCurve(m['min']),
      decodeParticleCurve(m['max']),
    ),
    _ => ConstantFloat(_num(m, 'value', fallback)),
  };
}

/// `{kind: constant|gradient|uniform, …}` → [ColorDistribution];
/// unrecognized/absent → opaque white (or [fallback]).
ColorDistribution decodeColorDistribution(
  PropertyValue? value, {
  Vector4? fallback,
}) {
  final fallbackColor = fallback ?? Vector4(1, 1, 1, 1);
  if (value is! MapValue) return ConstantColor(fallbackColor);
  final m = value.values;
  final kind = _str(m, 'kind', 'constant');
  return switch (kind) {
    'gradient' => GradientColor(decodeColorGradient(m['gradient'])),
    'uniform' => UniformColor(
      _colorValue(m['a'], fallbackColor),
      _colorValue(m['b'], fallbackColor),
    ),
    _ => ConstantColor(_colorValue(m['color'], fallbackColor)),
  };
}

Vector4 _colorValue(PropertyValue? v, Vector4 fallback) =>
    v is ColorValue ? Vector4(v.r, v.g, v.b, v.a) : fallback.clone();
