// W8 contact-event + physics-query checks: the D3Event.contact payload
// decode into the SceneCollisionEvent hierarchy, the queryReply decoders
// behind SceneController's query APIs, and the pending-query routing
// (error frames, stray ids, detach/dispose) — pinned by
// docs/physics-events-queries-spec.md. Same constraint as the W3–W7
// tests: package:dart3d/dart3d.dart is unreachable under `dart test`
// (the barrel transitively imports package:dartnative, which needs
// DartNative's patched SDK), so this pulls the pure-Dart libraries
// directly. `SceneController` itself is unreachable for the same
// reason — its _onNativeEvent cases are thin wrappers over
// decodeContactEvent / the reply decoders / d3SettleQueryReply, which
// are what these assertions exercise.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';

import 'package:dart3d/src/dispatch.dart';
import 'package:dart3d/src/physics.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  const dieId = LocalId(1, 2);
  const slabId = LocalId(1, 7);

  // vector_math stores components as f32 — compare with a tolerance.
  Matcher vec3(double x, double y, double z) => predicate<Vector3>(
    (v) =>
        (v.x - x).abs() < 1e-6 &&
        (v.y - y).abs() < 1e-6 &&
        (v.z - z).abs() < 1e-6,
    'Vector3($x, $y, $z)',
  );

  Map<String, Object?> frame(String json) =>
      jsonDecode(json) as Map<String, Object?>;

  group('contact event decode', () {
    test('began decodes the pair, collider indices, and contact points', () {
      final event = decodeContactEvent(
        frame(
          '{"kind":"began","a":{"s":1,"i":2},"ca":0,'
          '"b":{"s":1,"i":7},"cb":1,'
          '"points":[{"p":[0.0,-0.5,1.2],"n":[0.0,1.0,0.0],'
          '"imp":12.3,"sep":-0.01}]}',
        ),
      );
      final began = event as SceneCollisionBegan;
      expect(began.nodeA, dieId);
      expect(began.nodeB, slabId);
      expect(began.colliderIndexA, 0);
      expect(began.colliderIndexB, 1);
      final pt = began.contacts.single;
      expect(pt.worldPosition, vec3(0, -0.5, 1.2));
      expect(pt.worldNormal, vec3(0, 1, 0));
      expect(pt.impulse, 12.3);
      expect(pt.separation, -0.01);
    });

    test('began tolerates an empty or absent points list', () {
      for (final points in ['"points":[],', '']) {
        final event = decodeContactEvent(
          frame(
            '{"kind":"began","a":{"s":1,"i":2},"ca":2,'
            '$points"b":{"s":1,"i":7},"cb":0}',
          ),
        ) as SceneCollisionBegan;
        expect(event.contacts, isEmpty);
        expect(event.colliderIndexA, 2);
      }
    });

    test('ended / triggerEntered / triggerExited map to their kinds', () {
      const pair = '"a":{"s":1,"i":2},"ca":0,"b":{"s":1,"i":7},"cb":0';
      expect(
        decodeContactEvent(frame('{"kind":"ended",$pair}')),
        isA<SceneCollisionEnded>(),
      );
      expect(
        decodeContactEvent(frame('{"kind":"triggerEntered",$pair}')),
        isA<SceneTriggerEntered>(),
      );
      final exited =
          decodeContactEvent(frame('{"kind":"triggerExited",$pair}'))
              as SceneTriggerExited;
      expect(exited.nodeA, dieId);
      expect(exited.nodeB, slabId);
    });

    test('malformed frames and unknown kinds decode to null', () {
      expect(
        decodeContactEvent(frame('{"kind":"began","a":{"s":1,"i":2}}')),
        isNull,
      );
      expect(
        decodeContactEvent(
          frame(
            '{"kind":"paused","a":{"s":1,"i":2},"b":{"s":1,"i":7}}',
          ),
        ),
        isNull,
      );
      expect(decodeContactEvent(frame('{}')), isNull);
    });
  });

  group('query reply decode', () {
    test('pose replies decode nodes, positions, and rotations', () {
      final poses = decodePoseReply(
        frame(
          '{"q":17,"type":"pose","poses":['
          '{"node":{"s":1,"i":2},"p":[0.1,-0.25,0.8],"r":[0.0,0.0,0.0,1.0]},'
          '{"node":{"s":1,"i":7},"p":[0.0,-0.75,1.5],'
          '"r":[0.0,0.707,0.0,0.707]}'
          ']}',
        ),
      );
      expect(poses, hasLength(2));
      expect(poses[0].node, dieId);
      expect(poses[0].position, vec3(0.1, -0.25, 0.8));
      expect(poses[0].rotation.w, 1.0);
      expect(poses[1].node, slabId);
      expect(poses[1].rotation.y, closeTo(0.707, 1e-6));
    });

    test('a pose reply with no poses decodes empty', () {
      expect(decodePoseReply(frame('{"q":1,"type":"pose","poses":[]}')), isEmpty);
      expect(decodePoseReply(frame('{"q":1,"type":"pose"}')), isEmpty);
    });

    test('raycast hits decode with optional normals; miss is []', () {
      final hits = decodeRaycastReply(
        frame(
          '{"q":18,"type":"raycast","hits":['
          '{"node":{"s":1,"i":2},"collider":1,"p":[0.0,0.5,0.0],'
          '"n":[0.0,1.0,0.0],"d":1.23},'
          '{"node":{"s":1,"i":7},"collider":0,"p":[0.0,-0.5,1.5],"d":2.4}'
          ']}',
        ),
      );
      expect(hits, hasLength(2));
      expect(hits[0].node, dieId);
      expect(hits[0].colliderIndex, 1);
      expect(hits[0].worldPoint, vec3(0, 0.5, 0));
      expect(hits[0].worldNormal, vec3(0, 1, 0));
      expect(hits[0].distance, 1.23);
      // Jolt's raycast reports no normal — `n` absent → null.
      expect(hits[1].node, slabId);
      expect(hits[1].worldNormal, isNull);
      expect(hits[1].distance, 2.4);

      expect(
        decodeRaycastReply(frame('{"q":21,"type":"raycast","hits":[]}')),
        isEmpty,
      );
    });

    test('shapecast replies share the raycast hit shape', () {
      final hits = decodeRaycastReply(
        frame(
          '{"q":20,"type":"shapecast","hits":['
          '{"node":{"s":1,"i":7},"collider":0,"p":[0.0,-0.2,1.5],'
          '"n":[0.0,1.0,0.0],"d":0.8}]}',
        ),
      );
      expect(hits.single.node, slabId);
      expect(hits.single.distance, 0.8);
    });

    test('overlap hits decode node plus collider index', () {
      final hits = decodeOverlapReply(
        frame(
          '{"q":19,"type":"overlap","hits":['
          '{"node":{"s":1,"i":7},"collider":0},'
          '{"node":{"s":1,"i":2},"collider":2}]}',
        ),
      );
      expect(hits, hasLength(2));
      expect(hits[0].node, slabId);
      expect(hits[0].colliderIndex, 0);
      expect(hits[1].node, dieId);
      expect(hits[1].colliderIndex, 2);
    });

    test('malformed hit entries are skipped, not fatal', () {
      final hits = decodeRaycastReply(
        frame(
          '{"q":18,"type":"raycast","hits":['
          '{"node":{"s":1,"i":2}},'
          '{"p":[0.0,0.5,0.0]},'
          '{"node":{"s":1,"i":7},"p":[0.0,-0.5,1.5],"d":2.4}]}',
        ),
      );
      expect(hits, hasLength(1));
      expect(hits.single.node, slabId);
    });
  });

  group('pending-query routing', () {
    test('a reply completes its pending completer with the map', () async {
      final pending = <int, Completer<Map<String, Object?>>>{
        5: Completer(),
      };
      unawaited(
        expectLater(pending[5]!.future, completion(isA<Map>())),
      );
      expect(
        d3SettleQueryReply(
          frame('{"q":5,"type":"raycast","hits":[]}'),
          pending,
        ),
        isTrue,
      );
      expect(pending, isEmpty);
    });

    test('an error reply completes the completer with an error', () async {
      final pending = <int, Completer<Map<String, Object?>>>{
        22: Completer(),
      };
      unawaited(
        expectLater(
          pending[22]!.future,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains("unknown query type 'foo'"),
            ),
          ),
        ),
      );
      expect(
        d3SettleQueryReply(
          frame('{"q":22,"error":"unknown query type \'foo\'"}'),
          pending,
        ),
        isTrue,
      );
      expect(pending, isEmpty);
    });

    test('a stray or q-less reply is dropped, not routed', () {
      final pending = <int, Completer<Map<String, Object?>>>{};
      expect(
        d3SettleQueryReply(frame('{"q":9,"type":"pose","poses":[]}'), pending),
        isFalse,
      );
      expect(
        d3SettleQueryReply(frame('{"type":"pose","poses":[]}'), pending),
        isFalse,
      );
    });

    test('d3FailPendingQueries errors every pending query and clears', () async {
      final pending = <int, Completer<Map<String, Object?>>>{
        0: Completer(),
        1: Completer(),
      };
      unawaited(
        expectLater(pending[0]!.future, throwsA(isA<StateError>())),
      );
      unawaited(
        expectLater(pending[1]!.future, throwsA(isA<StateError>())),
      );
      d3FailPendingQueries(
        pending,
        StateError('dart3d: scene view detached'),
      );
      expect(pending, isEmpty);
    });
  });
}
