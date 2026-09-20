// Particle emitter component vocabulary (W18) — the `.fscene`
// `particleEmitter`/`meshParticleEmitter` component types, encoded as
// the same tagged `MapValue` property shapes upstream's
// `particle_emitter_codec.dart` writes, so documents built here are
// interchangeable with the wider flutter_scene ecosystem.
//
// Pure-Dart (no dartnative import) so the shapes are reachable under
// `dart test`. The decode/simulation twin lives in
// `particle_sim.dart`; the native twins are
// `FsceneRealizer.swift` (SCNParticleSystem mapping) and
// `ParticleRuntime.kt` (the Filament CPU sim + billboard batch).

import 'package:vector_math/vector_math.dart';

import 'scene_model.dart';

// Wire defaults shared with upstream's particle_emitter_codec.dart —
// the format's authoring defaults (NOT the ParticleSystem constructor
// defaults; existing documents rely on these).
const int kParticleMaxParticles = 512;
const double kParticleEmitRate = 32.0;
const double kParticleLifetime = 1.5;
const double kParticleStartSpeed = 1.5;
const double kParticleStartSize = 0.3;
const double kParticleShapeRadius = 0.25;
const double kParticleShapeAngle = 0.3;
const double kParticleDuration = 5.0;
const double kParticleFixedStep = 1.0 / 60.0;
const double kParticleMaxFrameTime = 0.25;

/// `particleEmitter` — the sprite/billboard emitter component type.
const String kParticleEmitterType = 'particleEmitter';

/// `meshParticleEmitter` — the instanced-mesh emitter component type.
const String kMeshParticleEmitterType = 'meshParticleEmitter';

// ---------------------------------------------------------------------------
// Curves and gradients — `{keys:[{t,v},…]}` / `{stops:[{t,color},…]}`.
// ---------------------------------------------------------------------------

/// A `ParticleCurve` value: piecewise-linear keys over normalized time
/// `[0,1]` (`{keys: [{t, v}, …]}`), the `curve`/`scale` carrier inside
/// `curve`-kind float distributions and `sizeOverLife` modules.
MapValue particleCurve(List<(double t, double v)> keys) => MapValue({
  'keys': ListValue([
    for (final k in keys)
      MapValue({'t': DoubleValue(k.$1), 'v': DoubleValue(k.$2)}),
  ]),
});

/// A `ColorGradient` value: linear-RGBA stops over normalized time
/// (`{stops: [{t, color: {r,g,b,a}}, …]}`), the `gradient` carrier
/// inside `gradient`-kind color distributions and `colorOverLife`
/// modules.
MapValue colorGradient(List<(double t, Vector4 color)> stops) => MapValue({
  'stops': ListValue([
    for (final s in stops)
      MapValue({
        't': DoubleValue(s.$1),
        'color': ColorValue(s.$2.x, s.$2.y, s.$2.z, s.$2.w),
      }),
  ]),
});

// ---------------------------------------------------------------------------
// Distributions — `{kind: …}` tagged maps (upstream
// particle_property_values.dart shapes).
// ---------------------------------------------------------------------------

/// `FloatDistribution` constant: `{kind:'constant', value}`.
MapValue constantFloat(double value) => MapValue({
  'kind': const StringValue('constant'),
  'value': DoubleValue(value),
});

/// `FloatDistribution` uniform range: `{kind:'uniform', min, max}` —
/// each particle keeps the drawn value for its whole life.
MapValue uniformFloat(double min, double max) => MapValue({
  'kind': const StringValue('uniform'),
  'min': DoubleValue(min),
  'max': DoubleValue(max),
});

/// `FloatDistribution` curve-over-life:
/// `{kind:'curve', curve, scale}`.
MapValue curveFloat(MapValue curve, {double scale = 1.0}) => MapValue({
  'kind': const StringValue('curve'),
  'curve': curve,
  'scale': DoubleValue(scale),
});

/// `FloatDistribution` per-particle blend between two curves:
/// `{kind:'uniformCurve', min, max}`.
MapValue uniformCurveFloat(MapValue min, MapValue max) => MapValue({
  'kind': const StringValue('uniformCurve'),
  'min': min,
  'max': max,
});

/// `ColorDistribution` constant: `{kind:'constant', color}` (linear
/// RGBA — the wire `{'c':[r,g,b,a]}` shape).
MapValue constantColor(Vector4 color) => MapValue({
  'kind': const StringValue('constant'),
  'color': ColorValue(color.x, color.y, color.z, color.w),
});

/// `ColorDistribution` gradient-over-life: `{kind:'gradient',
/// gradient}`.
MapValue gradientColor(MapValue gradient) => MapValue({
  'kind': const StringValue('gradient'),
  'gradient': gradient,
});

/// `ColorDistribution` per-particle blend between two colors:
/// `{kind:'uniform', a, b}`.
MapValue uniformColor(Vector4 a, Vector4 b) => MapValue({
  'kind': const StringValue('uniform'),
  'a': ColorValue(a.x, a.y, a.z, a.w),
  'b': ColorValue(b.x, b.y, b.z, b.w),
});

// ---------------------------------------------------------------------------
// Emitter shapes — `{kind: …}` tagged maps.
// ---------------------------------------------------------------------------

/// Point emitter: every particle spawns at the local origin heading
/// along [direction] (default +Y).
MapValue pointEmitterShape({Vector3? direction}) => MapValue({
  'kind': const StringValue('point'),
  'direction': Vec3Value(direction?.clone() ?? Vector3(0, 1, 0)),
});

/// Sphere emitter: positions fill the volume (or the shell when
/// [surfaceOnly]), directions radially outward; [hemisphere] restricts
/// to the +Y half.
MapValue sphereEmitterShape({
  double radius = 1.0,
  bool surfaceOnly = false,
  bool hemisphere = false,
}) => MapValue({
  'kind': const StringValue('sphere'),
  'radius': DoubleValue(radius),
  'surfaceOnly': BoolValue(surfaceOnly),
  'hemisphere': BoolValue(hemisphere),
});

/// Box emitter: positions uniform inside `±halfExtents`, every
/// particle heading along [direction] (default +Y).
MapValue boxEmitterShape({Vector3? halfExtents, Vector3? direction}) =>
    MapValue({
      'kind': const StringValue('box'),
      'halfExtents': Vec3Value(
        halfExtents?.clone() ?? Vector3.all(0.5),
      ),
      'direction': Vec3Value(direction?.clone() ?? Vector3(0, 1, 0)),
    });

/// Cone emitter (the upstream default): a `radius` disc in the XZ
/// plane, directions uniform over the solid angle of a cone of
/// half-[angle] about +Y.
MapValue coneEmitterShape({double radius = 0.0, double angle = 0.5}) =>
    MapValue({
      'kind': const StringValue('cone'),
      'radius': DoubleValue(radius),
      'angle': DoubleValue(angle),
    });

// ---------------------------------------------------------------------------
// Modules — `{kind: …}` tagged maps, applied in list order.
// ---------------------------------------------------------------------------

/// Constant acceleration (world units/s²) added to every live
/// particle's velocity each step.
MapValue accelerationModule(Vector3 acceleration) => MapValue({
  'kind': const StringValue('acceleration'),
  'acceleration': Vec3Value(acceleration.clone()),
});

/// Linear drag: velocity scales by `max(0, 1 − coefficient·dt)` per
/// step.
MapValue linearDragModule(double coefficient) => MapValue({
  'kind': const StringValue('linearDrag'),
  'coefficient': DoubleValue(coefficient),
});

/// Size over life: `size = baseSize · scale(age/lifetime)`; [scale] is
/// a float distribution (see [curveFloat]).
MapValue sizeOverLifeModule(MapValue scale) => MapValue({
  'kind': const StringValue('sizeOverLife'),
  'scale': scale,
});

/// Color over life: writes the color columns from [color] sampled at
/// normalized age (see [gradientColor]).
MapValue colorOverLifeModule(MapValue color) => MapValue({
  'kind': const StringValue('colorOverLife'),
  'color': color,
});

/// Flipbook animation through a [frameCount]-cell atlas. With
/// [framesPerSecond] unset the sequence plays once over each particle's
/// life; with it set frames advance at that rate and wrap.
/// [randomStartFrame] offsets each particle by a stable random frame.
MapValue flipbookModule({
  required int frameCount,
  double? framesPerSecond,
  bool randomStartFrame = false,
}) => MapValue({
  'kind': const StringValue('flipbook'),
  'frameCount': IntValue(frameCount),
  if (framesPerSecond != null)
    'framesPerSecond': DoubleValue(framesPerSecond),
  'randomStartFrame': BoolValue(randomStartFrame),
});

/// Curl-noise turbulence: advects velocities by `curl·strength·dt`
/// sampled at `pos·frequency` against a field drifting by [scroll] per
/// second.
MapValue turbulenceModule({
  double strength = 1.0,
  double frequency = 1.0,
  Vector3? scroll,
  int seed = 1337,
}) => MapValue({
  'kind': const StringValue('turbulence'),
  'strength': DoubleValue(strength),
  'frequency': DoubleValue(frequency),
  'scroll': Vec3Value(scroll?.clone() ?? Vector3.zero()),
  'seed': IntValue(seed),
});

/// Integrates `rotation += angularVelocity·dt` — included in the
/// default module stack; add explicitly when authoring a custom
/// `modules` list that still wants spin.
MapValue rotationModule() =>
    MapValue({'kind': const StringValue('rotation')});

/// The module stack an emitter gets when `modules` is omitted —
/// upstream's `_defaultModules()`: size×1, opaque white, rotation.
ListValue defaultParticleModules() => ListValue([
  sizeOverLifeModule(
    curveFloat(particleCurve(const [(0.0, 1.0)])),
  ),
  colorOverLifeModule(
    gradientColor(colorGradient([(0.0, Vector4(1, 1, 1, 1))])),
  ),
  rotationModule(),
]);

// ---------------------------------------------------------------------------
// Bursts — `{time, count, interval?, cycles?}`.
// ---------------------------------------------------------------------------

/// A scheduled burst: [count] particles at system-time [time],
/// repeating every [interval] seconds for [cycles] occurrences
/// (null = forever). A non-positive interval is a single shot (the
/// encoder omits `interval`/`cycles` accordingly).
MapValue particleBurst({
  required double time,
  required int count,
  double interval = 0.0,
  int? cycles,
}) => MapValue({
  'time': DoubleValue(time),
  'count': IntValue(count),
  if (interval > 0) 'interval': DoubleValue(interval),
  if (cycles != null) 'cycles': IntValue(cycles),
});

// ---------------------------------------------------------------------------
// Components
// ---------------------------------------------------------------------------

/// The shared `ParticleSystem` configuration properties — identical on
/// `particleEmitter` and `meshParticleEmitter`.
Map<String, PropertyValue> _systemProperties({
  int maxParticles = kParticleMaxParticles,
  double emitRate = kParticleEmitRate,
  List<MapValue> bursts = const [],
  MapValue? shape,
  ListValue? modules,
  MapValue? lifetime,
  MapValue? startSpeed,
  MapValue? startSize,
  MapValue? startRotation,
  MapValue? startAngularVelocity,
  MapValue? startColor,
  Vector3? gravity,
  bool looping = true,
  double duration = kParticleDuration,
  double fixedStep = kParticleFixedStep,
  double maxFrameTime = kParticleMaxFrameTime,
  int seed = 0,
  double prewarm = 0.0,
}) => {
  'maxParticles': IntValue(maxParticles),
  'emitRate': DoubleValue(emitRate),
  if (bursts.isNotEmpty) 'bursts': ListValue(bursts),
  'shape': shape ?? coneEmitterShape(
    radius: kParticleShapeRadius,
    angle: kParticleShapeAngle,
  ),
  'modules': modules ?? defaultParticleModules(),
  'lifetime': lifetime ?? constantFloat(kParticleLifetime),
  'startSpeed': startSpeed ?? constantFloat(kParticleStartSpeed),
  'startSize': startSize ?? constantFloat(kParticleStartSize),
  'startRotation': startRotation ?? constantFloat(0),
  'startAngularVelocity': startAngularVelocity ?? constantFloat(0),
  'startColor': startColor ?? constantColor(Vector4(1, 1, 1, 1)),
  'gravity': Vec3Value(gravity?.clone() ?? Vector3.zero()),
  'looping': BoolValue(looping),
  'duration': DoubleValue(duration),
  'fixedStep': DoubleValue(fixedStep),
  'maxFrameTime': DoubleValue(maxFrameTime),
  'seed': IntValue(seed),
  'prewarm': DoubleValue(prewarm),
};

/// A `particleEmitter` component: the upstream sprite emitter — a CPU
/// particle system rendered as one batch of camera-facing billboards.
///
/// The scalar knobs are upstream's format defaults. [shape] takes a
/// `pointEmitterShape`/`sphereEmitterShape`/`boxEmitterShape`/
/// `coneEmitterShape` value; [modules] a `ListValue` of
/// `*Module` values; [lifetime]/[startSpeed]/[startSize]/
/// [startRotation]/[startAngularVelocity] float distributions
/// ([constantFloat]/[uniformFloat]/[curveFloat]/[uniformCurveFloat]);
/// [startColor] a color distribution.
///
/// [facing] is `spherical` (quad normal at the eye — the default),
/// `axisLocked` (upright, yaws to the camera), or `velocityStretched`
/// (up axis follows velocity; [velocityStretch] adds world units of
/// length per unit speed). [blendMode] is `alpha` or `additive`.
/// [flipbookColumns]×[flipbookRows] index the [texture] atlas cells a
/// `flipbookModule` animates; [flipbookBlend] crossfades adjacent
/// cells; [randomFlipX] mirrors half the particles; [aspectRatio] is
/// width as a multiple of particle size.
///
/// [paused] holds the simulation while current particles keep
/// rendering. [enabled] is the universal component gate — W18 is its
/// first consumer: `enabled:false` freezes the emitter outright (no
/// simulation, no repack) instead of merely being recorded.
///
/// [texture] is the sprite atlas resource id; absent → untextured
/// (flat color). [fixedStep]/[maxFrameTime] are the determinism knobs:
/// the sim advances in `fixedStep` quanta and clamps a frame delta at
/// `maxFrameTime`.
ComponentSpec particleEmitterComponent({
  int maxParticles = kParticleMaxParticles,
  double emitRate = kParticleEmitRate,
  List<MapValue> bursts = const [],
  MapValue? shape,
  ListValue? modules,
  MapValue? lifetime,
  MapValue? startSpeed,
  MapValue? startSize,
  MapValue? startRotation,
  MapValue? startAngularVelocity,
  MapValue? startColor,
  Vector3? gravity,
  bool looping = true,
  double duration = kParticleDuration,
  double fixedStep = kParticleFixedStep,
  double maxFrameTime = kParticleMaxFrameTime,
  int seed = 0,
  double prewarm = 0.0,
  String blendMode = 'alpha',
  String facing = 'spherical',
  double velocityStretch = 0.0,
  bool paused = false,
  int flipbookColumns = 1,
  int flipbookRows = 1,
  bool flipbookBlend = false,
  bool randomFlipX = false,
  double aspectRatio = 1.0,
  LocalId? texture,
  bool? enabled,
}) => ComponentSpec(
  kParticleEmitterType,
  properties: {
    ..._systemProperties(
      maxParticles: maxParticles,
      emitRate: emitRate,
      bursts: bursts,
      shape: shape,
      modules: modules,
      lifetime: lifetime,
      startSpeed: startSpeed,
      startSize: startSize,
      startRotation: startRotation,
      startAngularVelocity: startAngularVelocity,
      startColor: startColor,
      gravity: gravity,
      looping: looping,
      duration: duration,
      fixedStep: fixedStep,
      maxFrameTime: maxFrameTime,
      seed: seed,
      prewarm: prewarm,
    ),
    'blendMode': StringValue(blendMode),
    'facing': StringValue(facing),
    'velocityStretch': DoubleValue(velocityStretch),
    'paused': BoolValue(paused),
    'flipbookColumns': IntValue(flipbookColumns),
    'flipbookRows': IntValue(flipbookRows),
    'flipbookBlend': BoolValue(flipbookBlend),
    'randomFlipX': BoolValue(randomFlipX),
    'aspectRatio': DoubleValue(aspectRatio),
    if (texture != null) 'texture': ResourceRefValue(texture),
    if (enabled != null) 'enabled': BoolValue(enabled),
  },
);

/// A `meshParticleEmitter` component: the upstream instanced-mesh
/// emitter — each live particle draws as an instance of one of
/// [geometries] (chosen per particle by its stable random), all
/// sharing [material].
///
/// [facing] is `tumble` (spin around the particle's random unit axis —
/// the default) or `velocityAligned` (mesh +Y tracks velocity, then
/// spins around it by `rotation`). Per-particle color is not applied
/// to mesh instances — a `colorOverLife` module is inert there
/// (upstream parity).
///
/// On Filament this realizes as baked per-particle renderables (one
/// entity per live slot): the Java binding exposes
/// `RenderableManager.Builder.instances` but no `InstanceBuffer`, so
/// true instancing is unreachable — see docs/particles-spec.md. On
/// iOS `SCNParticleSystem` is sprite-only, so the component degrades
/// to an untextured sprite pass tinted by the material's baseColor.
///
/// Missing [geometries]/[material] skip the component entirely —
/// upstream's `realize()` contract.
ComponentSpec meshParticleEmitterComponent({
  required List<LocalId> geometries,
  required LocalId material,
  String facing = 'tumble',
  bool paused = false,
  int maxParticles = kParticleMaxParticles,
  double emitRate = kParticleEmitRate,
  List<MapValue> bursts = const [],
  MapValue? shape,
  ListValue? modules,
  MapValue? lifetime,
  MapValue? startSpeed,
  MapValue? startSize,
  MapValue? startRotation,
  MapValue? startAngularVelocity,
  MapValue? startColor,
  Vector3? gravity,
  bool looping = true,
  double duration = kParticleDuration,
  double fixedStep = kParticleFixedStep,
  double maxFrameTime = kParticleMaxFrameTime,
  int seed = 0,
  double prewarm = 0.0,
  bool? enabled,
}) => ComponentSpec(
  kMeshParticleEmitterType,
  properties: {
    'geometries': ListValue([
      for (final id in geometries) ResourceRefValue(id),
    ]),
    'material': ResourceRefValue(material),
    'facing': StringValue(facing),
    'paused': BoolValue(paused),
    ..._systemProperties(
      maxParticles: maxParticles,
      emitRate: emitRate,
      bursts: bursts,
      shape: shape,
      modules: modules,
      lifetime: lifetime,
      startSpeed: startSpeed,
      startSize: startSize,
      startRotation: startRotation,
      startAngularVelocity: startAngularVelocity,
      startColor: startColor,
      gravity: gravity,
      looping: looping,
      duration: duration,
      fixedStep: fixedStep,
      maxFrameTime: maxFrameTime,
      seed: seed,
      prewarm: prewarm,
    ),
    if (enabled != null) 'enabled': BoolValue(enabled),
  },
);
