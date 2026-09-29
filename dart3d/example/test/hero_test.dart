// The launch hero's pure-Dart halves: the orbit / breath / framing math
// (`hero_motion.dart`) and the pivot-rig document (`hero_scene.dart`)
// against the real bundled logo asset.
// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d_example/dn_logo_stage.dart';
import 'package:dart3d_example/hero_motion.dart';
import 'package:dart3d_example/hero_scene.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

Uint8List? bytesFromDisk(String key) {
  final file = File(key);
  return file.existsSync() ? file.readAsBytesSync() : null;
}

const _deg = pi / 180;

void main() {
  group('heroEase', () {
    test('pins the ends and is monotonic expo-out', () {
      expect(heroEase(0), 0);
      expect(heroEase(1), 1);
      var last = 0.0;
      for (var i = 1; i <= 100; i++) {
        final v = heroEase(i / 100);
        expect(v, greaterThanOrEqualTo(last));
        last = v;
      }
      // Expo-out: most of the travel happens early.
      expect(heroEase(0.25), greaterThan(0.7));
    });
  });

  group('heroBreath', () {
    test('raised cosine low → high → low over the period', () {
      expect(heroBreath(0), closeTo(0.35, 1e-9));
      expect(heroBreath(2.4), closeTo(0.65, 1e-9));
      expect(heroBreath(4.8), closeTo(0.35, 1e-9));
      expect(heroBreath(1.2), closeTo(0.5, 1e-9));
      for (var t = 0.0; t < 10; t += 0.1) {
        expect(heroBreath(t), inInclusiveRange(0.35, 0.65));
      }
    });
  });

  group('HeroOrbit', () {
    test('drifts one full turn per revolution at constant speed', () {
      final orbit = HeroOrbit();
      for (var i = 0; i < 30 * 60; i++) {
        orbit.tick(1 / 60);
      }
      expect(orbit.yaw, closeTo(2 * pi, 1e-6));
      final before = orbit.yaw;
      orbit.tick(1);
      expect(orbit.yaw - before, closeTo(12 * _deg, 1e-9));
    });

    test('pitch bobs ±3° around +8° with a 13 s period', () {
      final orbit = HeroOrbit();
      expect(orbit.pitch, closeTo(8 * _deg, 1e-9));
      orbit.tick(13 / 4);
      expect(orbit.pitch, closeTo(11 * _deg, 1e-9));
      orbit.tick(13 / 2);
      expect(orbit.pitch, closeTo(5 * _deg, 1e-9));
    });

    test('a drag holds the drift, yaw unclamped, pitch clamped', () {
      final orbit = HeroOrbit();
      orbit.tick(1);
      final yaw = orbit.yaw;
      orbit.drag(-1000, 0);
      expect(orbit.dragging, isTrue);
      expect(orbit.yaw, closeTo(yaw + 8, 1e-9)); // 1000 px × 0.008
      orbit.tick(2);
      expect(orbit.yaw, closeTo(yaw + 8, 1e-9));
      orbit.drag(0, 10000);
      expect(orbit.pitch, closeTo(25 * _deg, 1e-9));
      orbit.drag(0, -10000);
      expect(orbit.pitch, closeTo(-5 * _deg, 1e-9));
    });

    test('release eases speed and pitch back into the drift', () {
      final orbit = HeroOrbit();
      orbit.drag(0, 10000); // pitch pinned at +25°
      orbit.release();
      expect(orbit.easing, isTrue);
      expect(orbit.pitch, closeTo(25 * _deg, 1e-9));
      // The first frame after release moves slower than the drift.
      final y0 = orbit.yaw;
      orbit.tick(1 / 60);
      expect(orbit.yaw - y0, lessThan(orbit.yawSpeed / 60));
      expect(orbit.yaw - y0, greaterThan(0));
      // Pitch glides from the drag's +25° toward the bob.
      for (var i = 0; i < 30; i++) {
        orbit.tick(1 / 60);
      }
      expect(orbit.pitch, lessThan(25 * _deg));
      expect(orbit.pitch, greaterThan(orbit.bobPitch(31 / 60)));
      for (var i = 0; i < 30; i++) {
        orbit.tick(1 / 60);
      }
      // After the 1.2 s ease it is back on the drift exactly.
      for (var i = 0; i < 20; i++) {
        orbit.tick(1 / 60);
      }
      expect(orbit.easing, isFalse);
      final y1 = orbit.yaw;
      orbit.tick(0.5);
      expect(orbit.yaw - y1, closeTo(orbit.yawSpeed * 0.5, 1e-9));
    });
  });

  group('framing', () {
    test('boom fits the bounding sphere to the width fraction', () {
      const fov = 32 * _deg;
      final aspect = 402 / 874;
      final d = heroBoomDistance(
        frameRadius: 1,
        fovY: fov,
        aspect: aspect,
        widthFraction: 0.5,
        heightFraction: 0.34,
      );
      // Sphere's projected half-width over the view's half-width.
      final frac = 1 / (d * tan(fov / 2) * aspect);
      expect(frac, closeTo(0.5, 1e-9));
      // A wide view is limited by height instead.
      final wide = heroBoomDistance(
        frameRadius: 1,
        fovY: fov,
        aspect: 2,
        widthFraction: 0.5,
        heightFraction: 0.34,
      );
      expect(1 / (wide * tan(fov / 2)), closeTo(0.34, 1e-9));
    });

    test('aim drop lifts the target by the screen fraction', () {
      const fov = 32 * _deg;
      final a = heroAimDrop(fovY: fov, screenLift: 0.3);
      expect(tan(a) / tan(fov / 2), closeTo(0.3, 1e-9));
    });
  });

  group('entrance + glow', () {
    test('entrance scale blooms 0.965 → 1.0 over 1 s', () {
      expect(heroEntranceScale(0), closeTo(0.965, 1e-12));
      expect(heroEntranceScale(1), closeTo(1.0, 1e-12));
      expect(heroEntranceScale(5), closeTo(1.0, 1e-12));
      expect(heroEntranceScale(0.3), inExclusiveRange(0.965, 1.0));
    });

    test('glow ramps in, then breathes', () {
      expect(heroGlowAt(0, low: 0.35), 0);
      expect(heroGlowAt(1.0, low: 0.35), closeTo(0.35, 1e-9));
      expect(heroGlowAt(1.0 + 2.4, low: 0.35), closeTo(0.65, 1e-9));
    });

    test('pulse off holds the static stage glow (not zero)', () {
      expect(heroGlowAt(0.5, low: 0.35, breathing: false), greaterThan(0));
      for (final t in [1.0, 3.4, 10.0]) {
        expect(heroGlowAt(t, low: 0.35, breathing: false), 0.35);
      }
    });

    test('a pinned glow wins over the breath', () {
      for (final t in [1.0, 3.4, 10.0]) {
        expect(heroGlowAt(t, low: 0.35, pinned: 0.65), 0.65);
      }
    });
  });

  group('HeroFraming', () {
    const fov = 32 * _deg;

    test('portrait: centred horizontally, lifted above centre', () {
      final f = HeroFraming.forView(
        frameRadius: 1,
        fovY: fov,
        aspect: 402 / 874,
      );
      expect(f.aimYaw, 0);
      expect(tan(f.aimDrop) / tan(fov / 2), closeTo(0.44, 1e-9));
    });

    test('landscape: target a quarter in from the left, sphere in the '
        'left half', () {
      const aspect = 874 / 402;
      final f = HeroFraming.forView(frameRadius: 1, fovY: fov, aspect: aspect);
      expect(f.aimDrop, 0);
      final tanX = tan(fov / 2) * aspect;
      expect(tan(f.aimYaw) / tanX, closeTo(0.5, 1e-9));
      // Sphere half-width ≤ a quarter of the view width.
      expect(1 / (f.distance * tanX), lessThanOrEqualTo(0.25 + 1e-9));
    });

    test('a portrait → landscape change reframes (distance differs)', () {
      final p = HeroFraming.forView(frameRadius: 1, fovY: fov, aspect: 0.46);
      final l = HeroFraming.forView(frameRadius: 1, fovY: fov, aspect: 2.17);
      expect(p.distance, isNot(closeTo(l.distance, 1e-3)));
    });
  });

  group('HeroFocalTracker', () {
    test('one finger yields deltas', () {
      final f = HeroFocalTracker()..start(10, 10, 1);
      expect(f.update(15, 12, 1), (5.0, 2.0));
    });

    test('2 → 1 finger rebases instead of snapping', () {
      final f = HeroFocalTracker()..start(100, 100, 2);
      expect(f.update(120, 100, 2), isNull);
      // A finger lifts: the focal point jumps from the centroid to the
      // remaining finger — no delta for that step.
      expect(f.update(300, 400, 1), isNull);
      expect(f.update(305, 400, 1), (5.0, 0.0));
    });
  });

  group('buildHeroScene', () {
    final hero = buildHeroScene(
      bytesFor: bytesFromDisk,
      stage: DnLogoStage.heroAndroid,
      aspect: 402 / 874,
    )!;
    final doc = hero.document;

    test('camera and the whole rig hang off one pivot at the centre', () {
      final pivot = doc.nodes[hero.pivot]!;
      expect(doc.roots, contains(hero.pivot));
      final names = {for (final id in pivot.children) doc.nodes[id]!.name};
      expect(names, heroRigNodeNames);
      for (final id in pivot.children) {
        expect(doc.roots, isNot(contains(id)));
      }
      final t = pivot.transform as TrsTransform;
      expect(t.translation, hero.center);
      // No slab on the hero; the logo floats.
      expect(doc.nodes.values.where((n) => n.name == 'showcase.slab'), isEmpty);
    });

    test('camera sits on the pivot −Z at the framed distance, hero lens', () {
      final pivot = doc.nodes[hero.pivot]!;
      final cam = pivot.children
          .map((id) => doc.nodes[id]!)
          .firstWhere((n) => n.name == 'showcase.camera');
      final t = cam.transform as TrsTransform;
      expect(t.translation.x, 0);
      expect(t.translation.y, 0);
      expect(t.translation.z, closeTo(-hero.distance, 1e-4));
      final comp = cam.components.firstWhere((c) => c.type == 'camera');
      expect((comp.properties['fovRadiansY']! as DoubleValue).value, heroFovY);
      // Zoomed out: the boom is well past the showcase's 2.8 × radius.
      expect(hero.distance, greaterThan(hero.frameRadius * 5));
    });

    test('pivot rotation orbits the camera around the centre', () {
      for (final yaw in [0.0, 2.1, 4.2]) {
        final p = heroCameraPosition(
          center: hero.center,
          distance: hero.distance,
          yaw: yaw,
          pitch: 8 * _deg,
        );
        expect((p - hero.center).length, closeTo(hero.distance, 1e-4));
        // +pitch puts the camera above the target.
        expect(p.y, greaterThan(hero.center.y));
      }
      final front = heroCameraPosition(
        center: Vector3.zero(),
        distance: 10,
        yaw: 0,
        pitch: 0,
      );
      final back = heroCameraPosition(
        center: Vector3.zero(),
        distance: 10,
        yaw: pi,
        pitch: 0,
      );
      expect(front.z, closeTo(-10, 1e-5));
      expect(back.z, closeTo(10, 1e-5));
    });

    test('glow ops re-send the textured material with a new factor', () {
      expect(hero.glowMaterials, isNotEmpty);
      final ops = heroGlowOps(doc, hero.glowMaterials, 0.5);
      expect(ops, hasLength(hero.glowMaterials.length));
      final op = ops.single;
      expect(op['op'], 'upsertResource');
      expect(op['id'], startsWith('mat:'));
      final res = op['resource']! as Map<String, Object?>;
      expect(res['kind'], 'material');
      final m = doc.resources[hero.glowMaterials.single]! as MaterialResource;
      expect(m.properties['emissive'], isA<ColorValue>());
      expect((m.properties['emissive']! as ColorValue).r, 0.5);
      expect(m.properties['emissiveTexture'], m.properties['baseColorTexture']);
    });

    test('per-platform stages: flat backdrop, grading only on iOS', () {
      final env =
          doc.resources[doc.stage.environmentRef]! as EnvironmentResource;
      expect(env.exposure, DnLogoStage.heroAndroid.exposure);
      expect(env.effects.colorGradingEnabled, isFalse);
      final ios = buildHeroScene(
        bytesFor: bytesFromDisk,
        stage: DnLogoStage.heroIos,
        aspect: 402 / 874,
      )!;
      final iosEnv =
          ios.document.resources[ios.document.stage.environmentRef]!
              as EnvironmentResource;
      expect(iosEnv.effects.colorGradingEnabled, isTrue);
      expect(iosEnv.effects.saturation, DnLogoStage.heroIos.saturation);
      final sky = iosEnv.skybox!.source as GradientSkySpec;
      expect(sky.zenithColor, sky.groundColor);
    });
  });
}
