import 'dart:math' as math;

import 'package:dart3d/dart3d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('W19 characterController codec & moveCharacter reply', () {
    test('characterControllerComponent encodes upstream KinematicCharacterControllerCodec fields', () {
      final comp = characterControllerComponent(
        up: Vector3(0, 2, 0),
        offset: 0.02,
        slide: true,
        maxSlopeClimbAngle: math.pi / 3,
        minSlopeSlideAngle: math.pi / 4,
        snapToGround: 0.15,
        autostep: true,
        autostepMaxHeight: 0.35,
        autostepMinWidth: 0.12,
        autostepIncludeDynamicBodies: false,
        mass: 15.0,
      );

      expect(comp.type, 'characterController');
      expect((comp.properties['up'] as Vec3Value).value, Vector3(0, 1, 0));
      expect((comp.properties['offset'] as DoubleValue).value, closeTo(0.02, 1e-6));
      expect((comp.properties['slide'] as BoolValue).value, isTrue);
      expect(
        (comp.properties['maxSlopeClimbAngle'] as DoubleValue).value,
        closeTo(math.pi / 3, 1e-6),
      );
      expect(
        (comp.properties['minSlopeSlideAngle'] as DoubleValue).value,
        closeTo(math.pi / 4, 1e-6),
      );
      expect(
        (comp.properties['snapToGround'] as DoubleValue).value,
        closeTo(0.15, 1e-6),
      );
      expect((comp.properties['autostep'] as BoolValue).value, isTrue);
      expect(
        (comp.properties['autostepMaxHeight'] as DoubleValue).value,
        closeTo(0.35, 1e-6),
      );
      expect(
        (comp.properties['autostepMinWidth'] as DoubleValue).value,
        closeTo(0.12, 1e-6),
      );
      expect(
        (comp.properties['autostepIncludeDynamicBodies'] as BoolValue).value,
        isFalse,
      );
      expect((comp.properties['mass'] as DoubleValue).value, closeTo(15.0, 1e-6));

      final noSnap = characterControllerComponent(snapToGround: null);
      expect(noSnap.properties.containsKey('snapToGround'), isFalse);
    });

    test('decodeCharacterMovementReply parses translation, grounded, and slidingDownSlope', () {
      final movement = decodeCharacterMovementReply({
        'q': 1,
        'type': 'moveCharacter',
        'translation': [0.25, 0.12, -0.05],
        'p': [1.25, 0.84, -0.05],
        'grounded': true,
        'slidingDownSlope': false,
      });
      expect(movement.translation.x, closeTo(0.25, 1e-6));
      expect(movement.translation.y, closeTo(0.12, 1e-6));
      expect(movement.translation.z, closeTo(-0.05, 1e-6));
      expect(movement.grounded, isTrue);
      expect(movement.slidingDownSlope, isFalse);

      final slideMove = decodeCharacterMovementReply({
        'q': 2,
        'type': 'moveCharacter',
        'translation': [0.10, -0.18, 0.0],
        'grounded': false,
        'slidingDownSlope': true,
      });
      expect(slideMove.grounded, isFalse);
      expect(slideMove.slidingDownSlope, isTrue);
    });

    test('kRealizedFeatures includes characterController', () {
      expect(kRealizedFeatures.contains('characterController'), isTrue);
    });
  });
}
