// W9 joint checks: the SceneJoint → wire encode per type (fields,
// defaults, the generic axes order), the joint-id sequence behind
// SceneController.addJoint, and the D3Event.joint "broke" decode —
// pinned by docs/joints-spec.md. W23 adds the semantics tripwires:
// signed limits/motors pass through verbatim (each native owns its
// handedness conversion — the wire never mirrors), and `collide`
// defaults false on every type (the pairwise-exclusion path). Same
// constraint as the W3–W8 tests:
// package:dart3d/dart3d.dart is unreachable under `dart test` (the
// barrel transitively imports package:dartnative, which needs
// DartNative's patched SDK), so this pulls the pure-Dart libraries
// directly. `SceneController` itself is unreachable for the same
// reason — addJoint/updateJoint/removeJoint are thin wrappers over
// SceneJoint.toWire + d3NextJointSeq, and the joint-event case over
// decodeJointEvent; those are what these assertions exercise.
// ignore_for_file: implementation_imports

import 'dart:convert';

import 'package:dart3d/src/dispatch.dart';
import 'package:dart3d/src/physics.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  const anchorId = LocalId(1, 2);
  const bodyId = LocalId(1, 7);

  Map<String, Object?> frame(String json) =>
      jsonDecode(json) as Map<String, Object?>;

  // The controller's op envelope: `{"op":…,"id":…}` merged over the
  // joint's wire fields — kept identical to addJoint/updateJoint.
  Map<String, Object?> op(String name, int id, SceneJoint joint) => {
    'op': name,
    'id': id,
    ...joint.toWire(),
  };

  // vector_math stores components as f32 — expected lists are built
  // from the same Vector3s so the doubles match exactly.
  List<double> xyz(Vector3 v) => [v.x, v.y, v.z];
  List<double> xyzw(Quaternion q) => [q.x, q.y, q.z, q.w];

  group('SceneJoint → wire', () {
    test('fixed carries the pair, defaults, and both anchors', () {
      final anchorA = Vector3(0, 0.2, 0);
      final wire = SceneJoint.fixed(
        bodyA: anchorId,
        bodyB: bodyId,
        localAnchorA: anchorA,
      ).toWire();
      expect(wire, {
        'type': 'fixed',
        'a': anchorId.toToken(),
        'b': bodyId.toToken(),
        'ca': 0,
        'cb': 0,
        'collide': false,
        'anchorA': xyz(anchorA),
        'anchorB': [0.0, 0.0, 0.0],
      });
    });

    test('spherical has the same shape; optional fields stay absent', () {
      final anchorA = Vector3(0, -0.2, 0);
      final anchorB = Vector3(0, 0.2, 0);
      final wire = SceneJoint.spherical(
        bodyA: anchorId,
        bodyB: bodyId,
        colliderIndexA: 1,
        colliderIndexB: 2,
        collisionsEnabled: true,
        localAnchorA: anchorA,
        localAnchorB: anchorB,
        breakDistance: 0.35,
      ).toWire();
      expect(wire['type'], 'spherical');
      expect(wire['ca'], 1);
      expect(wire['cb'], 2);
      expect(wire['collide'], isTrue);
      expect(wire['anchorA'], xyz(anchorA));
      expect(wire['anchorB'], xyz(anchorB));
      expect(wire['breakDistance'], 0.35);
      // Axis/limit/motor/basis fields belong to other types.
      for (final key in [
        'axisA',
        'axisB',
        'lower',
        'upper',
        'motorVelocity',
        'motorMaxForce',
        'basisA',
        'basisB',
        'axes',
      ]) {
        expect(wire.containsKey(key), isFalse, reason: key);
      }
    });

    test('revolute emits axes plus optional limits and motor', () {
      final axis = Vector3(0, 1, 0);
      final wire = SceneJoint.revolute(
        bodyA: anchorId,
        bodyB: bodyId,
        localAxisA: axis,
        localAxisB: axis,
        lowerLimit: -1.745,
        upperLimit: 1.745,
        motorTargetVelocity: 2.0,
        motorMaxForce: 50.0,
      ).toWire();
      expect(wire['type'], 'revolute');
      expect(wire['axisA'], xyz(axis));
      expect(wire['axisB'], xyz(axis));
      expect(wire['lower'], -1.745);
      expect(wire['upper'], 1.745);
      expect(wire['motorVelocity'], 2.0);
      expect(wire['motorMaxForce'], 50.0);
      expect(wire.containsKey('axes'), isFalse);
      expect(wire.containsKey('basisA'), isFalse);
    });

    test('revolute omits unset limits and motor fields', () {
      final wire = SceneJoint.revolute(
        bodyA: anchorId,
        bodyB: bodyId,
        localAxisA: Vector3(0, 0, 1),
        localAxisB: Vector3(0, 0, 1),
      ).toWire();
      expect(wire['axisA'], [0.0, 0.0, 1.0]);
      for (final key in ['lower', 'upper', 'motorVelocity', 'motorMaxForce']) {
        expect(wire.containsKey(key), isFalse, reason: key);
      }
    });

    test('prismatic shares the revolute field set', () {
      final wire = SceneJoint.prismatic(
        bodyA: anchorId,
        bodyB: bodyId,
        localAxisA: Vector3(0, 1, 0),
        localAxisB: Vector3(0, 1, 0),
        localAnchorB: Vector3(0, 0.5, 0),
        lowerLimit: -0.3,
        upperLimit: 0.6,
        motorTargetVelocity: 0.5,
        motorMaxForce: 60,
      ).toWire();
      expect(wire['type'], 'prismatic');
      expect(wire['lower'], -0.3);
      expect(wire['upper'], 0.6);
      expect(wire['motorVelocity'], 0.5);
      expect(wire['motorMaxForce'], 60);
      expect(wire['anchorB'], [0.0, 0.5, 0.0]);
    });

    test('generic defaults to identity bases and six free axes', () {
      final wire = SceneJoint.generic(bodyA: anchorId, bodyB: bodyId).toWire();
      expect(wire['type'], 'generic');
      expect(wire['basisA'], [0.0, 0.0, 0.0, 1.0]);
      expect(wire['basisB'], [0.0, 0.0, 0.0, 1.0]);
      expect(
        wire['axes'],
        List.filled(6, {'motion': 'free'}),
        reason: 'one config per SceneJointAxis, all free by default',
      );
    });

    test('generic axes encode in JointAxis order with per-motion fields', () {
      final basisA = Quaternion.axisAngle(Vector3(0, 1, 0), 0.5);
      const motor = SceneJointMotor(
        targetVelocity: 1.5,
        maxForce: 40,
        model: SceneJointMotorModel.force,
      );
      final wire = SceneJoint.generic(
        bodyA: anchorId,
        bodyB: bodyId,
        localBasisA: basisA,
        axes: const [
          SceneJointAxisConfig.locked(),
          SceneJointAxisConfig.free(motor: motor),
          SceneJointAxisConfig.limited(-0.3, 0.6),
          SceneJointAxisConfig.locked(),
          SceneJointAxisConfig.limited(-0.9, 0.9),
          SceneJointAxisConfig.free(),
        ],
      ).toWire();
      expect(wire['basisA'], xyzw(basisA));
      expect(wire['basisB'], [0.0, 0.0, 0.0, 1.0]);
      expect(wire['axes'], [
        {'motion': 'locked'},
        {
          'motion': 'free',
          'motor': {
            'targetPosition': 0.0,
            'targetVelocity': 1.5,
            'stiffness': 0.0,
            'damping': 0.0,
            'maxForce': 40.0,
            'model': 'force',
          },
        },
        {'motion': 'limited', 'lower': -0.3, 'upper': 0.6},
        {'motion': 'locked'},
        {'motion': 'limited', 'lower': -0.9, 'upper': 0.9},
        {'motion': 'free'},
      ]);
    });

    // W23: signed values go over the wire verbatim — mirroring is a
    // native concern (SceneKit folds it into the axis direction; Jolt
    // into its constraint-space scalars), so a Dart-side normalize or
    // sign fix would double up. Asymmetric magnitudes are what make a
    // regression visible.
    test('revolute signed limits and motor pass through verbatim', () {
      final wire = SceneJoint.revolute(
        bodyA: anchorId,
        bodyB: bodyId,
        localAxisA: Vector3(0, 1, 0),
        localAxisB: Vector3(0, 1, 0),
        lowerLimit: -0.35,
        upperLimit: 1.745,
        motorTargetVelocity: -2.0,
        motorMaxForce: 40,
      ).toWire();
      expect(wire['lower'], -0.35);
      expect(wire['upper'], 1.745);
      expect(wire['motorVelocity'], -2.0);
      expect(wire['motorMaxForce'], 40);
    });

    test('generic angular axes keep signed limits and motor verbatim', () {
      // Axes 3/4/5 are angular (twist X, swing Y, swing Z) — the same
      // signed-value rule as revolute applies per axis.
      final wire = SceneJoint.generic(
        bodyA: anchorId,
        bodyB: bodyId,
        axes: const [
          SceneJointAxisConfig.locked(),
          SceneJointAxisConfig.locked(),
          SceneJointAxisConfig.locked(),
          SceneJointAxisConfig.limited(-0.1, 1.2),
          SceneJointAxisConfig.free(
            motor: SceneJointMotor(targetVelocity: -3.0, maxForce: 25),
          ),
          SceneJointAxisConfig.limited(-1.4, 0.2),
        ],
      ).toWire();
      expect(wire['axes'], [
        {'motion': 'locked'},
        {'motion': 'locked'},
        {'motion': 'locked'},
        {'motion': 'limited', 'lower': -0.1, 'upper': 1.2},
        {
          'motion': 'free',
          'motor': {
            'targetPosition': 0.0,
            'targetVelocity': -3.0,
            'stiffness': 0.0,
            'damping': 0.0,
            'maxForce': 25.0,
            'model': 'acceleration',
          },
        },
        {'motion': 'limited', 'lower': -1.4, 'upper': 0.2},
      ]);
    });

    test('collide defaults false on every type (the exclusion path)', () {
      // `collisionsEnabled` defaults false upstream; the wire's
      // `collide:false` is what drives iOS's category-bit carve and
      // Jolt's constraint collide-bodies flag.
      for (final joint in [
        SceneJoint.fixed(bodyA: anchorId, bodyB: bodyId),
        SceneJoint.spherical(bodyA: anchorId, bodyB: bodyId),
        SceneJoint.revolute(
          bodyA: anchorId,
          bodyB: bodyId,
          localAxisA: Vector3(0, 1, 0),
          localAxisB: Vector3(0, 1, 0),
        ),
        SceneJoint.prismatic(
          bodyA: anchorId,
          bodyB: bodyId,
          localAxisA: Vector3(0, 1, 0),
          localAxisB: Vector3(0, 1, 0),
        ),
        SceneJoint.generic(bodyA: anchorId, bodyB: bodyId),
      ]) {
        expect(joint.toWire()['collide'], isFalse);
      }
      // The opt-in still ships — exclusion only applies to false.
      expect(
        SceneJoint.fixed(
          bodyA: anchorId,
          bodyB: bodyId,
          collisionsEnabled: true,
        ).toWire()['collide'],
        isTrue,
      );
    });

    test('a motor with no force cap omits maxForce (JSON has no inf)', () {
      const motor = SceneJointMotor(targetVelocity: 2);
      expect(motor.toWire(), {
        'targetPosition': 0.0,
        'targetVelocity': 2.0,
        'stiffness': 0.0,
        'damping': 0.0,
        'model': 'acceleration',
      });
    });

    test('non-finite force caps and break distances are omitted', () {
      final wire = SceneJoint.prismatic(
        bodyA: anchorId,
        bodyB: bodyId,
        localAxisA: Vector3(0, 1, 0),
        localAxisB: Vector3(0, 1, 0),
        motorTargetVelocity: 1.0,
        motorMaxForce: double.infinity,
        breakDistance: double.infinity,
      ).toWire();
      expect(wire['motorVelocity'], 1.0);
      expect(wire.containsKey('motorMaxForce'), isFalse);
      expect(wire.containsKey('breakDistance'), isFalse);
      expect(jsonEncode(wire), isA<String>());
    });

    test('the full addJoint op matches the spec envelope', () {
      final joint = SceneJoint.revolute(
        bodyA: anchorId,
        bodyB: bodyId,
        localAxisA: Vector3(0, 1, 0),
        localAxisB: Vector3(0, 1, 0),
        lowerLimit: -1.57,
        upperLimit: 1.57,
        motorTargetVelocity: 2.0,
        motorMaxForce: 50.0,
        breakDistance: 0.5,
      );
      // Round-trip through commandBytes' JSON encode — what the
      // natives actually parse.
      final decoded = jsonDecode(
        jsonEncode({'op': 'addJoint', 'id': 7, ...joint.toWire()}),
      ) as Map<String, Object?>;
      expect(decoded, {
        'op': 'addJoint',
        'id': 7,
        'type': 'revolute',
        'a': anchorId.toToken(),
        'b': bodyId.toToken(),
        'ca': 0,
        'cb': 0,
        'collide': false,
        'anchorA': [0.0, 0.0, 0.0],
        'anchorB': [0.0, 0.0, 0.0],
        'axisA': [0.0, 1.0, 0.0],
        'axisB': [0.0, 1.0, 0.0],
        'lower': -1.57,
        'upper': 1.57,
        'motorVelocity': 2.0,
        'motorMaxForce': 50.0,
        'breakDistance': 0.5,
      });
      // updateJoint differs only in the op name; removeJoint carries
      // just the handle.
      expect(op('updateJoint', 7, joint)['op'], 'updateJoint');
    });

    test('every wire map survives the JSON round-trip', () {
      for (final joint in [
        SceneJoint.fixed(bodyA: anchorId, bodyB: bodyId),
        SceneJoint.spherical(bodyA: anchorId, bodyB: bodyId),
        SceneJoint.revolute(
          bodyA: anchorId,
          bodyB: bodyId,
          localAxisA: Vector3(1, 0, 0),
          localAxisB: Vector3(1, 0, 0),
        ),
        SceneJoint.prismatic(
          bodyA: anchorId,
          bodyB: bodyId,
          localAxisA: Vector3(0, 1, 0),
          localAxisB: Vector3(0, 1, 0),
          motorMaxForce: double.infinity,
        ),
        SceneJoint.generic(bodyA: anchorId, bodyB: bodyId),
      ]) {
        final decoded = jsonDecode(jsonEncode(joint.toWire()));
        expect(decoded, isA<Map<String, Object?>>());
      }
    });
  });

  group('joint id allocation', () {
    test('the sequence is monotonic and wraps at u32', () {
      // addJoint returns the counter value, then advances it via
      // d3NextJointSeq — same pattern as _querySeq.
      var seq = 0;
      final first = seq;
      seq = d3NextJointSeq(seq);
      expect(first, 0);
      expect(seq, 1);
      expect(d3NextJointSeq(41), 42);
      expect(d3NextJointSeq(0xFFFFFFFE), 0xFFFFFFFF);
      expect(d3NextJointSeq(0xFFFFFFFF), 0);
    });
  });

  group('joint event decode', () {
    test('broke decodes the id and both body nodes', () {
      final event = decodeJointEvent(
        frame(
          '{"kind":"broke","id":7,'
          '"a":{"s":1,"i":2},"b":{"s":1,"i":7}}',
        ),
      );
      expect(event, isA<SceneJointBroke>());
      expect(event!.id, 7);
      expect(event.nodeA, anchorId);
      expect(event.nodeB, bodyId);
    });

    test('unknown kinds and malformed frames decode to null', () {
      expect(
        decodeJointEvent(
          frame('{"kind":"added","id":3,"a":{"s":1,"i":2},"b":{"s":1,"i":7}}'),
        ),
        isNull,
      );
      // Missing id / missing `a` are malformed, not events.
      expect(
        decodeJointEvent(
          frame('{"kind":"broke","a":{"s":1,"i":2},"b":{"s":1,"i":7}}'),
        ),
        isNull,
      );
      expect(
        decodeJointEvent(frame('{"kind":"broke","id":3,"b":{"s":1,"i":7}}')),
        isNull,
      );
      expect(decodeJointEvent(frame('{}')), isNull);
    });

    test('broke with null/absent b decodes world-anchored (W12)', () {
      // A document-declared joint component with no `otherNode` anchors
      // to the world — natives emit `"b":null` on break (iOS and
      // Android share the contract).
      for (final frame_ in [
        '{"kind":"broke","id":9,"a":{"s":1,"i":2},"b":null}',
        '{"kind":"broke","id":9,"a":{"s":1,"i":2}}',
      ]) {
        final event = decodeJointEvent(frame(frame_));
        expect(event, isA<SceneJointBroke>());
        expect(event!.id, 9);
        expect(event.nodeA, anchorId);
        expect(event.nodeB, isNull);
      }
    });
  });
}
