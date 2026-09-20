// W18 checks: the `particleEmitter`/`meshParticleEmitter` component
// wire shape (upstream-compatible tagged property maps), the
// property-map → ParticleSystem decode, the fixed-step simulation
// semantics (fractional emission, bursts, reaping), determinism under
// a fixed seed, and the enabled/paused tick gates — pinned by
// docs/particles-spec.md. Same constraint as the W3–W15 tests:
// package:dart3d/dart3d.dart is unreachable under `dart test` (the
// barrel transitively imports package:dartnative, which needs
// DartNative's patched SDK), so this pulls the pure-Dart libraries
// directly.
// ignore_for_file: implementation_imports

import 'package:dart3d/src/particle_sim.dart';
import 'package:dart3d/src/particles.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// A small emitter: 60 particles/s, 0.5 s lifetime, empty module
/// stack — deterministic counts with no over-life shaping.
ParticleSystem quietSystem({int seed = 0}) => particleSystemFromProperties({
  'emitRate': DoubleValue(60),
  'seed': IntValue(seed),
  'modules': ListValue(const []),
  'lifetime': constantFloat(0.5),
});

void main() {
  group('component factories', () {
    test('particleEmitter carries the upstream property vocabulary', () {
      final spec = particleEmitterComponent(
        emitRate: 40,
        seed: 7,
        gravity: Vector3(0, -2, 0),
        blendMode: 'additive',
        facing: 'axisLocked',
      );
      expect(spec.type, kParticleEmitterType);
      expect(spec.type, 'particleEmitter');
      final p = spec.properties;
      expect((p['emitRate']! as DoubleValue).value, 40);
      expect((p['seed']! as IntValue).value, 7);
      expect((p['maxParticles']! as IntValue).value, kParticleMaxParticles);
      expect((p['fixedStep']! as DoubleValue).value, kParticleFixedStep);
      expect((p['maxFrameTime']! as DoubleValue).value, kParticleMaxFrameTime);
      expect((p['blendMode']! as StringValue).value, 'additive');
      expect((p['facing']! as StringValue).value, 'axisLocked');
      // Tagged union shapes/distributions ride as MapValue.
      expect(p['shape'], isA<MapValue>());
      expect(p['lifetime'], isA<MapValue>());
      expect(p['modules'], isA<ListValue>());
      // `enabled` is omitted unless explicitly set — absent means the
      // natives' default (true) applies, matching every other component.
      expect(p.containsKey('enabled'), isFalse);
    });

    test('enabled:false and paused ride the property map', () {
      final spec = particleEmitterComponent(enabled: false, paused: true);
      expect((spec.properties['enabled']! as BoolValue).value, isFalse);
      expect((spec.properties['paused']! as BoolValue).value, isTrue);
    });

    test('meshParticleEmitter carries geometry refs + material ref', () {
      const g0 = LocalId(3, 1);
      const g1 = LocalId(3, 2);
      const mat = LocalId(4, 9);
      final spec = meshParticleEmitterComponent(
        geometries: const [g0, g1],
        material: mat,
        facing: 'velocityAligned',
      );
      expect(spec.type, 'meshParticleEmitter');
      final geoms = (spec.properties['geometries']! as ListValue).values
          .cast<ResourceRefValue>();
      expect(geoms.map((r) => r.id), [g0, g1]);
      expect((spec.properties['material']! as ResourceRefValue).id, mat);
      expect(
        (spec.properties['facing']! as StringValue).value,
        'velocityAligned',
      );
    });
  });

  group('decode', () {
    test('absent properties decode to the format defaults', () {
      final system = particleSystemFromProperties(const {});
      expect(system.storage.capacity, kParticleMaxParticles);
      expect(system.spawner.rate, kParticleEmitRate);
      expect(system.fixedStep, kParticleFixedStep);
      expect(system.maxFrameTime, kParticleMaxFrameTime);
      expect(system.duration, kParticleDuration);
      expect(system.looping, isTrue);
      expect(system.gravity.x, 0);
      expect(system.shape, isA<ConeEmitterShape>());
      // Legacy stack default: sizeOverLife + colorOverLife + rotation.
      expect(system.modules, hasLength(3));
    });

    test('explicit modules list decodes tagged unions in order', () {
      final system = particleSystemFromProperties({
        'modules': ListValue([
          linearDragModule(0.5),
          turbulenceModule(strength: 2.0, frequency: 0.5, seed: 9),
          rotationModule(),
        ]),
      });
      expect(system.modules, hasLength(3));
      expect(system.modules[0], isA<LinearDragModule>());
      expect(system.modules[1], isA<TurbulenceModule>());
      expect((system.modules[1] as TurbulenceModule).seed, 9);
      expect(system.modules[2], isA<RotationModule>());
    });

    test('shape union decodes per kind', () {
      final sphere = particleSystemFromProperties({
        'shape': sphereEmitterShape(radius: 2, surfaceOnly: true),
      });
      expect(sphere.shape, isA<SphereEmitterShape>());
      expect((sphere.shape as SphereEmitterShape).radius, 2);
      expect((sphere.shape as SphereEmitterShape).surfaceOnly, isTrue);
      final point = particleSystemFromProperties({
        'shape': pointEmitterShape(direction: Vector3(0, 0, 1)),
      });
      expect(point.shape, isA<PointEmitterShape>());
    });

    test('legacy flat shape keys still decode', () {
      final system = particleSystemFromProperties({
        'shapeType': const StringValue('box'),
        'shapeRadius': DoubleValue(3.0),
      });
      expect(system.shape, isA<BoxEmitterShape>());
      expect(
        (system.shape as BoxEmitterShape).halfExtents.x,
        closeTo(3.0, 1e-9),
      );
    });

    test('sprite + mesh render-side specs decode', () {
      const tex = LocalId(9, 1);
      const g = LocalId(9, 2);
      const mat = LocalId(9, 3);
      final sprite = spriteEmitterSpecFromProperties({
        'blendMode': const StringValue('additive'),
        'facing': const StringValue('velocityStretched'),
        'velocityStretch': DoubleValue(0.5),
        'paused': const BoolValue(true),
        'flipbookColumns': IntValue(4),
        'flipbookRows': IntValue(2),
        'texture': const ResourceRefValue(tex),
        'enabled': const BoolValue(false),
      });
      expect(sprite.blendMode, 'additive');
      expect(sprite.facing, 'velocityStretched');
      expect(sprite.flipbookColumns, 4);
      expect(sprite.flipbookRows, 2);
      expect(sprite.texture, tex);
      expect(sprite.paused, isTrue);
      expect(sprite.enabled, isFalse);

      final mesh = meshEmitterSpecFromProperties({
        'geometries': ListValue(const [ResourceRefValue(g)]),
        'material': const ResourceRefValue(mat),
        'facing': const StringValue('velocityAligned'),
      });
      expect(mesh.geometries, [g]);
      expect(mesh.material, mat);
      expect(mesh.facing, 'velocityAligned');
      expect(mesh.enabled, isTrue);
    });

    test('maxFrameTime never falls below fixedStep', () {
      final system = particleSystemFromProperties({
        'fixedStep': DoubleValue(0.1),
        'maxFrameTime': DoubleValue(0.01),
      });
      expect(system.maxFrameTime, system.fixedStep);
    });
  });

  group('simulation', () {
    test('fixed-step accumulation emits at the authored rate', () {
      final system = quietSystem();
      // 60/s at 60Hz fixed step → exactly one particle per step.
      for (var i = 0; i < 10; i++) {
        system.step(kParticleFixedStep);
      }
      expect(system.storage.aliveCount, 10);
    });

    test('fractional rates accumulate rather than truncate', () {
      final system = particleSystemFromProperties({
        'emitRate': DoubleValue(20), // 1/3 particle per 60Hz step
        'modules': ListValue(const []),
      });
      for (var i = 0; i < 30; i++) {
        system.step(kParticleFixedStep);
      }
      expect(system.storage.aliveCount, 10);
    });

    test('a frame smaller than fixedStep carries over', () {
      final system = quietSystem();
      system.step(kParticleFixedStep * 0.4);
      expect(system.storage.aliveCount, 0);
      expect(system.time, 0);
      system.step(kParticleFixedStep * 0.7);
      expect(system.time, closeTo(kParticleFixedStep, 1e-12));
      expect(system.storage.aliveCount, 1);
    });

    test('maxFrameTime clamps a hitching frame', () {
      final system = quietSystem();
      system.step(10.0); // clamps to 0.25 → 15 steps at 60Hz
      expect(system.time, closeTo(0.25, 1e-9));
    });

    test('bursts fire once inside their step window', () {
      final system = particleSystemFromProperties({
        'emitRate': DoubleValue(0),
        'bursts': ListValue([particleBurst(time: 0.05, count: 8)]),
        'modules': ListValue(const []),
      });
      for (var i = 0; i < 12; i++) {
        system.step(kParticleFixedStep);
      }
      expect(system.storage.aliveCount, 8);
    });

    test('particles die at their lifetime and compact the pool', () {
      final system = quietSystem();
      // lifetime 0.5 s → after 0.55 s of stepping only the last
      // ~0.5 s of the 60/s stream remains alive.
      for (var i = 0; i < 60; i++) {
        system.step(kParticleFixedStep);
      }
      expect(system.storage.aliveCount, lessThanOrEqualTo(31));
      expect(system.storage.aliveCount, greaterThan(0));
    });

    test('gravity integrates into velocity then position', () {
      final system = particleSystemFromProperties({
        'emitRate': DoubleValue(60), // one particle per 60Hz step
        'gravity': Vec3Value(Vector3(0, -10, 0)),
        'shape': pointEmitterShape(direction: Vector3(0, 1, 0)),
        'startSpeed': constantFloat(0),
        'lifetime': constantFloat(10),
        'modules': ListValue(const []),
      });
      // Slot 0 spawns in the first step and then accrues gravity for
      // the full 60 steps: v = −10·1 s, position negative.
      for (var i = 0; i < 60; i++) {
        system.step(kParticleFixedStep);
      }
      expect(system.storage.aliveCount, 60);
      expect(system.storage.velY[0], closeTo(-10.0, 0.2));
      expect(system.storage.posY[0], lessThan(0));
    });
  });

  group('determinism', () {
    List<double> snapshot(ParticleSystem s) => [
      for (var i = 0; i < s.storage.aliveCount; i++) ...[
        s.storage.posX[i],
        s.storage.posY[i],
        s.storage.posZ[i],
        s.storage.size[i],
        s.storage.colorR[i],
      ],
    ];

    test('same seed replays identically', () {
      final a = quietSystem(seed: 42);
      final b = quietSystem(seed: 42);
      for (var i = 0; i < 30; i++) {
        a.step(kParticleFixedStep);
        b.step(kParticleFixedStep);
      }
      expect(snapshot(a), snapshot(b));
    });

    test('different seeds diverge', () {
      final a = quietSystem(seed: 1);
      final b = quietSystem(seed: 2);
      for (var i = 0; i < 30; i++) {
        a.step(kParticleFixedStep);
        b.step(kParticleFixedStep);
      }
      expect(snapshot(a), isNot(snapshot(b)));
    });

    test('reset replays the seed stream', () {
      final a = quietSystem(seed: 5);
      for (var i = 0; i < 20; i++) {
        a.step(kParticleFixedStep);
      }
      final first = snapshot(a);
      a.reset();
      for (var i = 0; i < 20; i++) {
        a.step(kParticleFixedStep);
      }
      expect(snapshot(a), first);
    });

    test('prewarm advances the system before first render', () {
      final warm = particleSystemFromProperties({
        'emitRate': DoubleValue(60),
        'prewarm': DoubleValue(0.5),
        'modules': ListValue(const []),
        'lifetime': constantFloat(10),
      });
      expect(warm.time, closeTo(0.5, 1e-6));
      expect(warm.storage.aliveCount, greaterThan(0));
    });
  });

  group('tick gates (enabled/paused)', () {
    test('enabled:false suppresses step AND repack', () {
      final system = quietSystem();
      var repacks = 0;
      final runtime = ParticleEmitterRuntime(system: system, enabled: false);
      for (var i = 0; i < 10; i++) {
        runtime.tick(kParticleFixedStep, (_) => repacks++);
      }
      expect(system.time, 0);
      expect(system.storage.aliveCount, 0);
      expect(repacks, 0);
    });

    test('paused:true holds the sim but still repacks', () {
      final system = quietSystem();
      var repacks = 0;
      final runtime = ParticleEmitterRuntime(system: system);
      runtime.tick(kParticleFixedStep, (_) => repacks++);
      runtime.paused = true;
      final aliveAtPause = system.storage.aliveCount;
      for (var i = 0; i < 10; i++) {
        runtime.tick(kParticleFixedStep, (_) => repacks++);
      }
      expect(system.storage.aliveCount, aliveAtPause);
      expect(repacks, 11);
    });

    test('spec decode feeds the gates', () {
      final spec = spriteEmitterSpecFromProperties({
        'enabled': const BoolValue(false),
        'paused': const BoolValue(true),
      });
      final runtime = ParticleEmitterRuntime(
        system: particleSystemFromProperties(const {}),
        enabled: spec.enabled,
        paused: spec.paused,
      );
      var repacks = 0;
      runtime.tick(kParticleFixedStep, (_) => repacks++);
      expect(repacks, 0);
    });
  });

  group('noise', () {
    test('noiseCurl3 is deterministic and finite', () {
      final a = noiseCurl3(1.5, -2.25, 0.75, seed: 1337);
      final b = noiseCurl3(1.5, -2.25, 0.75, seed: 1337);
      expect(a.x, b.x);
      expect(a.y, b.y);
      expect(a.z, b.z);
      expect(a.x.isFinite && a.y.isFinite && a.z.isFinite, isTrue);
      final c = noiseCurl3(1.5, -2.25, 0.75, seed: 42);
      expect(
        a.x != c.x || a.y != c.y || a.z != c.z,
        isTrue,
        reason: 'different seeds should give different curl fields',
      );
    });
  });
}
