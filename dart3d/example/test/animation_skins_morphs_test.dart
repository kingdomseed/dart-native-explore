// W11 skins/animation/morph-target checks: the diff_apply.dart op
// emission (upsertSkin/upsertAnimation/removeSkin/removeAnimation,
// the updateNode `skin` flag), the animation.dart command encoders
// (`anim`, `setMorphWeights`) and `weightsChannelTargetCount`, the
// `skinned_uv1_tangent` vertex packer, and the SceneAnimation
// handle's duration rule — all pinned by
// docs/animation-skins-morphs-spec.md. Same constraint as the other
// suites: package:dart3d/dart3d.dart is unreachable under `dart test`
// (the barrel transitively imports package:dartnative, which needs
// DartNative's patched SDK), so this pulls the pure-Dart libraries
// directly.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/src/animation.dart';
import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/vertex_pack.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // Deterministic ids — explicit (session, index) pairs so tokens are
  // stable across the two documents.
  const j0Id = LocalId(1, 40);
  const j1Id = LocalId(1, 41);
  const flagId = LocalId(1, 42);
  const blobId = LocalId(1, 43);
  const skinId = LocalId(1, 50);
  const waveId = LocalId(1, 60);
  const pulseId = LocalId(1, 61);
  const ibmId = LocalId(1, 70);
  const tlId = LocalId(1, 71);
  const kfId = LocalId(1, 72);
  const wtlId = LocalId(1, 73);
  const wkfId = LocalId(1, 74);

  Uint8List f32(List<double> values) {
    final out = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      out.setFloat32(i * 4, values[i], Endian.little);
    }
    return out.buffer.asUint8List();
  }

  PayloadSpec floats(LocalId id, List<double> values) {
    final bytes = f32(values);
    return PayloadSpec(
      id,
      encoding: PayloadEncoding.floats,
      length: bytes.lengthInBytes,
      bytes: bytes,
    );
  }

  /// The shared W11 fixture: a two-joint chain (j0 root, j1 child), a
  /// skinned `flag` node bound to `skin`, a `blob` morph node, the
  /// skin, and two animations — `wave` driving j0/j1 rotations and
  /// `pulse` driving blob weights.
  SceneDocument skinnedDoc({
    String j0Name = 'j0',
    Vector3? j0T,
    LocalId? flagSkin = skinId,
    bool dropSkin = false,
    bool dropWave = false,
    bool dropPulse = false,
    Uint8List? ibmBytes,
    List<double>? waveTimes,
    List<double>? waveKeys,
    String waveName = 'wave',
  }) {
    final doc = SceneDocument();
    doc.addPayload(
      PayloadSpec(
        ibmId,
        encoding: PayloadEncoding.matrices,
        length: (ibmBytes ?? f32(List.filled(32, 0))).lengthInBytes,
        bytes: ibmBytes ?? f32(List.filled(32, 0)),
      ),
    );
    doc.addPayload(floats(tlId, waveTimes ?? const [0, 0.5, 1.0]));
    doc.addPayload(floats(kfId, waveKeys ?? List.filled(12, 0)));
    doc.addPayload(floats(wtlId, const [0, 1]));
    doc.addPayload(floats(wkfId, const [0, 0, 1, 0]));
    final j0 = doc.addNode(
      NodeSpec(
        id: j0Id,
        name: j0Name,
        transform: TrsTransform(translation: j0T ?? Vector3.zero()),
        children: [j1Id],
      ),
      root: true,
    );
    doc.addNode(
      NodeSpec(id: j1Id, name: 'j1', transform: TrsTransform()),
    );
    final flag = doc.addNode(
      NodeSpec(id: flagId, name: 'flag', transform: TrsTransform()),
      root: true,
    );
    flag.skin = flagSkin;
    doc.addNode(
      NodeSpec(id: blobId, name: 'blob', transform: TrsTransform()),
      root: true,
    );
    if (!dropSkin) {
      doc.addSkin(
        SkinSpec(
          skinId,
          joints: [j0Id, j1Id],
          inverseBindMatrices: ibmId,
          skeleton: j0Id,
        ),
      );
    }
    if (!dropWave) {
      doc.addAnimation(
        AnimationSpec(
          waveId,
          name: waveName,
          channels: [
            AnimationChannelSpec(
              target: j0Id,
              targetName: j0.name,
              property: AnimationProperty.rotation,
              timeline: tlId,
              keyframes: kfId,
            ),
            AnimationChannelSpec(
              target: j1Id,
              targetName: 'j1',
              property: AnimationProperty.rotation,
              timeline: tlId,
              keyframes: kfId,
            ),
          ],
        ),
      );
    }
    if (!dropPulse) {
      doc.addAnimation(
        AnimationSpec(
          pulseId,
          name: 'pulse',
          channels: [
            AnimationChannelSpec(
              target: blobId,
              targetName: 'blob',
              property: AnimationProperty.weights,
              timeline: wtlId,
              keyframes: wkfId,
            ),
          ],
        ),
      );
    }
    return doc;
  }

  List<Map<String, Object?>> opsFor(SceneDocument a, SceneDocument b) =>
      diffCommands(diffScene(a, b), a, b);

  group('spec encoders', () {
    test('encodeSkinSpec emits the manifest skins entry shape', () {
      final doc = skinnedDoc();
      expect(encodeSkinSpec(doc.skins[skinId]!, doc), {
        'joints': ['n:${j0Id.toToken()}', 'n:${j1Id.toToken()}'],
        'inverseBindMatrices': 'chunk:${ibmId.toToken()}',
        'skeleton': 'n:${j0Id.toToken()}',
      });
      // `skeleton` is optional — absent from the encode when null.
      doc.skins[skinId] = SkinSpec(
        skinId,
        joints: [j0Id],
        inverseBindMatrices: ibmId,
      );
      expect(
        encodeSkinSpec(doc.skins[skinId]!, doc).containsKey('skeleton'),
        isFalse,
      );
    });

    test('encodeAnimationSpec emits the manifest animations entry', () {
      final doc = skinnedDoc();
      final spec = encodeAnimationSpec(doc.animations[waveId]!, doc);
      expect(spec['name'], 'wave');
      final channels = spec['channels'] as List;
      expect(channels, hasLength(2));
      expect(channels[0], {
        'target': 'n:${j0Id.toToken()}',
        'targetName': 'j0',
        'property': 'rotation',
        'timeline': 'chunk:${tlId.toToken()}',
        'keyframes': 'chunk:${kfId.toToken()}',
      });
      // `targetName`/`name` are optional on the wire.
      final bare = encodeAnimationSpec(
        AnimationSpec(
          pulseId,
          channels: [
            AnimationChannelSpec(
              target: blobId,
              property: AnimationProperty.weights,
              timeline: wtlId,
              keyframes: wkfId,
            ),
          ],
        ),
        doc,
      );
      expect(bare.containsKey('name'), isFalse);
      expect((bare['channels'] as List).single, isNot(contains('targetName')));
    });

    test('encodeNodeCommandSpec carries the skin member', () {
      final doc = skinnedDoc();
      final spec = encodeNodeCommandSpec(doc.nodes[flagId]!, doc);
      expect(spec['skin'], 'skin:${skinId.toToken()}');
      // …and it round-trips through the manifest exactly like upstream.
      final manifest =
          jsonDecode(writeFscene(doc)) as Map<String, dynamic>;
      final entry =
          (manifest['nodes'] as Map)['n:${flagId.toToken()}'] as Map;
      expect(spec, entry);
      // A node with no skin omits the member.
      expect(
        encodeNodeCommandSpec(
          doc.nodes[blobId]!,
          doc,
        ).containsKey('skin'),
        isFalse,
      );
    });
  });

  group('diff emission', () {
    test('new skin + animations emit upserts after the node ops', () {
      final ops = opsFor(SceneDocument(), skinnedDoc());
      final order = [for (final o in ops) o['op'] as String];
      final skinAt = order.indexOf('upsertSkin');
      final animAt = order.indexOf('upsertAnimation');
      expect(skinAt, greaterThan(-1));
      expect(animAt, greaterThan(skinAt));
      // Nodes land before the skin/animations that bind them; chunks
      // land before both.
      expect(order.lastIndexOf('addNode'), lessThan(skinAt));
      expect(order.lastIndexOf('upsertPayload'), lessThan(skinAt));
      expect(order.where((o) => o == 'upsertAnimation'), hasLength(2));

      final skin = ops[skinAt];
      expect(skin['id'], 'skin:${skinId.toToken()}');
      expect(skin['skin'], {
        'joints': ['n:${j0Id.toToken()}', 'n:${j1Id.toToken()}'],
        'inverseBindMatrices': 'chunk:${ibmId.toToken()}',
        'skeleton': 'n:${j0Id.toToken()}',
      });
      final wave = ops.firstWhere(
        (o) => o['id'] == 'anim:${waveId.toToken()}',
      );
      expect(wave['op'], 'upsertAnimation');
      expect((wave['animation'] as Map)['name'], 'wave');
    });

    test('dropped skin/animations emit removes ahead of node ops', () {
      final ops = opsFor(
        skinnedDoc(),
        skinnedDoc(dropSkin: true, dropWave: true, dropPulse: true),
      );
      final order = [for (final o in ops) o['op'] as String];
      expect(order[0], 'removeSkin');
      expect(order[1], 'removeAnimation');
      expect(order[2], 'removeAnimation');
      final removes = {
        for (final o in ops.take(3)) o['id'],
      };
      expect(removes, {
        'skin:${skinId.toToken()}',
        'anim:${waveId.toToken()}',
        'anim:${pulseId.toToken()}',
      });
      // And the flag's unbound skin member rides an updateNode flag.
      final flag = ops.firstWhere(
        (o) => o['op'] == 'updateNode' && o['node'] == flagId.toToken(),
      );
      expect(flag['flags'], contains('skin'));
    });

    test('unchanged skin/animations emit nothing', () {
      final ops = opsFor(skinnedDoc(), skinnedDoc());
      expect(ops, isEmpty);
    });

    test('an IBM byte change re-emits the skin upsert', () {
      final ops = opsFor(
        skinnedDoc(),
        skinnedDoc(ibmBytes: f32(List.filled(32, 1))),
      );
      final skin = [
        for (final o in ops) if (o['op'] == 'upsertSkin') o,
      ];
      expect(skin, hasLength(1));
      // …and every node bound to it gets the skin-flag update.
      final flag = ops.firstWhere(
        (o) => o['op'] == 'updateNode' && o['node'] == flagId.toToken(),
      );
      expect(flag['flags'], contains('skin'));
    });

    test('a node skin-member change emits only the updateNode flag', () {
      final ops = opsFor(
        skinnedDoc(),
        skinnedDoc(flagSkin: null),
      );
      final skinOps = [
        for (final o in ops)
          if (o['op'] == 'upsertSkin' || o['op'] == 'removeSkin') o,
      ];
      expect(skinOps, isEmpty);
      final flag = ops.firstWhere(
        (o) => o['op'] == 'updateNode' && o['node'] == flagId.toToken(),
      );
      expect(flag['flags'], contains('skin'));
    });

    test('a keyframe byte change re-emits only that animation', () {
      final ops = opsFor(
        skinnedDoc(),
        skinnedDoc(waveKeys: List.filled(12, 9)),
      );
      final anims = [
        for (final o in ops)
          if (o['op'] == 'upsertAnimation') o['id'],
      ];
      expect(anims, ['anim:${waveId.toToken()}']);
    });

    test('a target rename re-emits its animation (retarget rule)', () {
      final ops = opsFor(
        skinnedDoc(),
        skinnedDoc(j0Name: 'j0renamed'),
      );
      final anims = [
        for (final o in ops)
          if (o['op'] == 'upsertAnimation') o['id'],
      ];
      // wave targets j0 → re-emits; pulse targets blob → stays.
      expect(anims, ['anim:${waveId.toToken()}']);
    });

    test('a target rest-transform change re-emits its animation', () {
      final ops = opsFor(
        skinnedDoc(),
        skinnedDoc(j0T: Vector3(1, 0, 0)),
      );
      final anims = [
        for (final o in ops)
          if (o['op'] == 'upsertAnimation') o['id'],
      ];
      expect(anims, ['anim:${waveId.toToken()}']);
    });

    test('every op survives the commandBytes JSON round-trip', () {
      final ops = opsFor(SceneDocument(), skinnedDoc())
        ..addAll(opsFor(skinnedDoc(), SceneDocument()));
      for (final op in ops) {
        final decoded =
            jsonDecode(utf8.decode(D3Protocol.commandBytes(op)))
                as Map<String, dynamic>;
        expect(decoded['op'], isA<String>());
      }
      // The skin id parses back through the last-colon strip.
      final skinOp = ops.firstWhere((o) => o['op'] == 'upsertSkin');
      expect(
        LocalId.parse((skinOp['id'] as String).split(':').last),
        skinId,
      );
    });
  });

  group('anim command encoding', () {
    test('play / pause / stop verbs', () {
      expect(encodeAnimCommand(waveId, play: true), {
        'op': 'anim',
        'anim': waveId.toToken(),
        'play': true,
      });
      expect(encodeAnimCommand(waveId, pause: true), {
        'op': 'anim',
        'anim': waveId.toToken(),
        'pause': true,
      });
      expect(encodeAnimCommand(waveId, stop: true), {
        'op': 'anim',
        'anim': waveId.toToken(),
        'stop': true,
      });
    });

    test('knobs: time seek, timeScale, weight, loop', () {
      expect(
        encodeAnimCommand(
          waveId,
          play: true,
          time: 0.75,
          timeScale: 2.0,
          weight: 0.5,
          loop: true,
        ),
        {
          'op': 'anim',
          'anim': waveId.toToken(),
          'play': true,
          'time': 0.75,
          'timeScale': 2.0,
          'weight': 0.5,
          'loop': true,
        },
      );
      // A pure seek carries no verb.
      final seek = encodeAnimCommand(waveId, time: 1.5);
      expect(seek, {
        'op': 'anim',
        'anim': waveId.toToken(),
        'time': 1.5,
      });
      // …and absent knobs stay absent (natives keep current values).
      expect(seek.containsKey('loop'), isFalse);
      expect(seek.containsKey('weight'), isFalse);
    });

    test('setMorphWeights carries node + weight list', () {
      expect(encodeMorphWeightsCommand(blobId, const [0.6, 0.4]), {
        'op': 'setMorphWeights',
        'node': blobId.toToken(),
        'weights': [0.6, 0.4],
      });
    });
  });

  group('weights channel decode', () {
    test('targetCount is values ~/ times; trailing floats drop', () {
      // 3 keys × 2 targets consumes exactly 6.
      expect(weightsChannelTargetCount(times: 3, values: 6), 2);
      // 7 floats over 3 keys → still 2 targets, the 7th drops.
      expect(weightsChannelTargetCount(times: 3, values: 7), 2);
      expect(weightsChannelTargetCount(times: 3, values: 5), 1);
      expect(weightsChannelTargetCount(times: 0, values: 4), 0);
    });
  });

  group('SceneAnimation handle', () {
    test('duration is the maximum channel end time', () {
      final doc = skinnedDoc();
      final wave = SceneAnimation.fromSpec(doc.animations[waveId]!, doc);
      expect(wave.id, waveId);
      expect(wave.name, 'wave');
      expect(wave.channelCount, 2);
      expect(wave.duration, 1.0);
      final pulse = SceneAnimation.fromSpec(
        doc.animations[pulseId]!,
        doc,
      );
      expect(pulse.duration, 1.0);
      // A channel whose timeline chunk is absent contributes 0.
      final bare = SceneAnimation.fromSpec(
        AnimationSpec(
          LocalId(9, 9),
          channels: [
            AnimationChannelSpec(
              target: blobId,
              property: AnimationProperty.weights,
              timeline: LocalId(9, 10),
              keyframes: LocalId(9, 11),
            ),
          ],
        ),
        doc,
      );
      expect(bare.duration, 0.0);
    });
  });

  group('skinned vertex packer', () {
    test('writes 26 f32 per vertex in the upstream order', () {
      final bytes = VertexPack.skinned(
        positions: [Vector3(1, 2, 3), Vector3(4, 5, 6)],
        joints: [Vector4(0, 1, 0, 0), Vector4(1, 0, 0, 0)],
        weights: [Vector4(0.25, 0.75, 0, 0), Vector4(0, 1, 0, 0)],
        normals: [Vector3(0, 1, 0), Vector3(0, 0, -1)],
        uvs: [Vector2(0.5, 0.5), Vector2(1, 0)],
      );
      expect(bytes.lengthInBytes, 2 * VertexPack.skinnedUv1TangentStride);
      final view = ByteData.view(bytes.buffer);
      double v(int vertex, int field) =>
          view.getFloat32((vertex * 26 + field) * 4, Endian.little);
      // pos3 | normal3 | uv0-2 | uv1-2 | color4 | tangent4 | j4 | w4
      expect([v(0, 0), v(0, 1), v(0, 2)], [1.0, 2.0, 3.0]);
      expect([v(0, 3), v(0, 4), v(0, 5)], [0.0, 1.0, 0.0]);
      expect([v(0, 6), v(0, 7)], [0.5, 0.5]);
      expect([v(0, 8), v(0, 9)], [0.0, 0.0]); // uv1 zero-filled
      expect([v(0, 10), v(0, 11), v(0, 12), v(0, 13)],
          [1.0, 1.0, 1.0, 1.0]); // neutral color
      expect([v(0, 14), v(0, 15), v(0, 16), v(0, 17)],
          [1.0, 0.0, 0.0, 1.0]); // neutral tangent
      expect([v(0, 18), v(0, 19), v(0, 20), v(0, 21)],
          [0.0, 1.0, 0.0, 0.0]); // joints4
      expect([v(0, 22), v(0, 23), v(0, 24), v(0, 25)],
          [0.25, 0.75, 0.0, 0.0]); // weights4
      expect([v(1, 18), v(1, 19)], [1.0, 0.0]);
    });

    test('a mismatched channel length throws', () {
      expect(
        () => VertexPack.skinned(
          positions: [Vector3.zero()],
          joints: [Vector4.zero()],
          weights: [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0)],
        ),
        throwsArgumentError,
      );
    });
  });
}
