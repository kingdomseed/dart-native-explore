import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart3d/src/animation.dart';
import 'package:dart3d/src/compose_extensions.dart';
import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/doc_layer.dart';
import 'package:dart3d/src/fsceneb_reader.dart';
import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';

const clip = LocalId(1, 5),
    mat = LocalId(1, 2),
    light = LocalId(1, 3),
    camera = LocalId(1, 4);
const times = LocalId(1, 6),
    colors = LocalId(1, 7),
    powers = LocalId(1, 8),
    fovs = LocalId(1, 9);
Uint8List f32(List<double> values) {
  final data = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    data.setFloat32(i * 4, values[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

SceneDocument fixture() {
  final doc = SceneDocument();
  doc.resources[mat] = MaterialResource(mat, type: 'unlit');
  doc.nodes[light] = NodeSpec(id: light);
  doc.nodes[camera] = NodeSpec(id: camera);
  for (final entry in {
    times: [0.0, 2.0],
    colors: [1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0],
    powers: [2.0, 6.0],
    fovs: [0.7853981634, 1.5707963268],
  }.entries) {
    doc.payloads[entry.key] = PayloadSpec(
      entry.key,
      encoding: PayloadEncoding.floats,
      bytes: f32(entry.value),
    );
  }
  doc.animations[clip] = Dart3dAnimationSpec(
    clip,
    name: 'Reveal',
    propertyChannels: [
      D3MaterialBaseColorChannel(
        material: mat,
        timeline: times,
        keyframes: colors,
      ),
      D3LightIntensityChannel(node: light, timeline: times, keyframes: powers),
      D3CameraFovChannel(node: camera, timeline: times, keyframes: fovs),
    ],
  );
  return doc;
}

const literal = <String, Object?>{
  'name': 'Reveal',
  'channels': <Object?>[],
  'd3:properties': [
    {
      'kind': 'materialBaseColor',
      'material': 'mat:0000008000004',
      'timeline': 'chunk:000000800000C',
      'keyframes': 'chunk:000000800000E',
    },
    {
      'kind': 'lightIntensity',
      'node': 'n:0000008000006',
      'timeline': 'chunk:000000800000C',
      'keyframes': 'chunk:000000800000G',
    },
    {
      'kind': 'cameraFovRadiansY',
      'node': 'n:0000008000008',
      'timeline': 'chunk:000000800000C',
      'keyframes': 'chunk:000000800000J',
    },
  ],
};
Map<String, dynamic> manifest(SceneDocument doc) =>
    jsonDecode(writeFsceneWithExtensions(doc)) as Map<String, dynamic>;
String rawWith(Object? entry) {
  final m = jsonDecode(writeFscene(SceneDocument())) as Map<String, dynamic>;
  m['animations'] = {'anim:000000800000A': entry};
  return jsonEncode(m);
}

void main() {
  test(
    'literal wire and paired reader preserve all property kinds without mutating feature sets',
    () {
      final doc = fixture();
      final m = jsonDecode(utf8.decode(D3Protocol.loadSceneBytes(doc))) as Map;
      expect((m['animations'] as Map)['anim:000000800000A'], literal);
      expect(m['featuresRequired'], contains('d3:propertyAnimation'));
      expect(doc.featuresRequired, isEmpty);
      final back = readFsceneWithExtensions(rawWith(literal));
      final a = back.animations[clip] as Dart3dAnimationSpec;
      expect(a.channels, isEmpty);
      expect(a.propertyChannels.map((c) => c.runtimeType), [
        D3MaterialBaseColorChannel,
        D3LightIntensityChannel,
        D3CameraFovChannel,
      ]);
      expect(encodeAnimationSpec(a, fixture()), literal);
    },
  );
  test(
    'mixed ordinary four kinds retain literal properties and payload IDs',
    () {
      final doc = fixture();
      final old = doc.animations[clip] as Dart3dAnimationSpec;
      doc.animations[clip] = Dart3dAnimationSpec(
        clip,
        channels: [
          for (final p in AnimationProperty.values)
            AnimationChannelSpec(
              target: light,
              property: p,
              timeline: times,
              keyframes: powers,
            ),
        ],
        propertyChannels: old.propertyChannels,
      );
      final back = readFsceneWithExtensions(writeFsceneWithExtensions(doc));
      expect(back.animations[clip]!.channels.map((c) => c.property.name), [
        'translation',
        'rotation',
        'scale',
        'weights',
      ]);
      expect(
        (back.animations[clip] as Dart3dAnimationSpec).propertyChannels,
        hasLength(3),
      );
    },
  );
  test(
    'lists and serialized payload bytes detach; descriptor includes pending values timeline',
    () {
      final doc = fixture();
      final list = <D3PropertyChannelSpec>[
        D3LightIntensityChannel(
          node: light,
          timeline: times,
          keyframes: powers,
        ),
      ];
      final ordinary = <AnimationChannelSpec>[];
      final spec = Dart3dAnimationSpec(
        clip,
        channels: ordinary,
        propertyChannels: list,
      );
      list.clear();
      ordinary.add(
        AnimationChannelSpec(
          target: light,
          property: AnimationProperty.scale,
          timeline: times,
          keyframes: powers,
        ),
      );
      expect(spec.propertyChannels, hasLength(1));
      expect(spec.channels, isEmpty);
      expect(() => spec.propertyChannels.clear(), throwsUnsupportedError);
      expect(() => spec.channels.clear(), throwsUnsupportedError);
      doc.payloads[powers]!.bytes = null;
      expect(
        SceneAnimation.fromSpec(doc.animations[clip]!, doc).channelCount,
        3,
      );
      expect(SceneAnimation.fromSpec(doc.animations[clip]!, doc).duration, 2);
      final copy = serializeScene(doc);
      copy.payloads[times]!.bytes![0] = 17;
      expect(doc.payloads[times]!.bytes![0], 0);
      expect(
        (copy.animations[clip] as Dart3dAnimationSpec).propertyChannels,
        hasLength(3),
      );
    },
  );
  test(
    'property-only changes and reference-ID changes emit upsert with absent or equal bytes',
    () {
      for (final ready in [false, true]) {
        final a = fixture(), b = serializeScene(a);
        const other = LocalId(1, 20);
        if (!ready) {
          a.payloads[powers]!.bytes = null;
          b.payloads[powers]!.bytes = null;
        }
        b.payloads[other] = PayloadSpec(
          other,
          encoding: PayloadEncoding.floats,
          bytes: b.payloads[powers]!.bytes,
        );
        b.animations[clip] = Dart3dAnimationSpec(
          clip,
          name: 'Reveal',
          propertyChannels: [
            D3LightIntensityChannel(
              node: light,
              timeline: times,
              keyframes: other,
            ),
          ],
        );
        final ops = diffCommands(diffScene(a, b), a, b);
        expect(ops.where((o) => o['op'] == 'upsertAnimation'), hasLength(1));
        final c = serializeScene(a);
        c.animations[clip] = AnimationSpec(clip, name: 'Reveal');
        expect(
          diffCommands(
            diffScene(a, c),
            a,
            c,
          ).where((o) => o['op'] == 'upsertAnimation'),
          hasLength(1),
        );
      }
    },
  );
  test(
    'mirror same-ID replacement, clear and removal use paired entry codec',
    () {
      final doc = fixture();
      foldCommandIntoDocument(doc, {
        'op': 'upsertAnimation',
        'id': 'anim:000000800000A',
        'animation': literal,
      });
      expect(doc.animations[clip], isA<Dart3dAnimationSpec>());
      foldCommandIntoDocument(doc, {
        'op': 'upsertAnimation',
        'id': 'anim:000000800000A',
        'animation': {'channels': []},
      });
      expect(doc.animations[clip]!.channels, isEmpty);
      expect(
        manifest(doc)['animations'].toString(),
        isNot(contains('d3:properties')),
      );
      foldCommandIntoDocument(doc, {
        'op': 'removeAnimation',
        'id': 'anim:000000800000A',
      });
      expect(doc.animations, isEmpty);
    },
  );
  test('raw structural errors and unknown ordinary property are rejected', () {
    final base = Map<String, Object?>.from(literal);
    for (final value in <Object?>[
      {},
      'bad',
      [
        {'kind': 'future'},
      ],
      [
        {
          'kind': 'lightIntensity',
          'node': 'invalid',
          'timeline': 'chunk:000000800000C',
          'keyframes': 'chunk:000000800000G',
        },
      ],
      [
        ...(literal['d3:properties'] as List),
        (literal['d3:properties'] as List).first,
      ],
    ]) {
      expect(
        () => readFsceneWithExtensions(
          rawWith({...base, 'd3:properties': value}),
        ),
        throwsA(anything),
        reason: '$value',
      );
    }
    expect(
      () => readFsceneWithExtensions(
        rawWith({
          'channels': [
            {
              'target': 'n:0000008000006',
              'property': 'future',
              'timeline': 'chunk:000000800000C',
              'keyframes': 'chunk:000000800000G',
            },
          ],
        }),
      ),
      throwsA(anything),
    );
  });
  test(
    'available f32 curves reject domain, shape, encoding and timeline errors',
    () {
      for (final entry in <LocalId, List<double>>{
        times: [0, 0],
        colors: [1, 0, 0, 2, 0, 0, 1, 1],
        powers: [-1, 2],
        fovs: [0, 1],
      }.entries) {
        final doc = fixture();
        doc.payloads[entry.key]!.bytes = f32(entry.value);
        expect(
          () => D3Protocol.loadSceneBytes(doc),
          throwsA(anything),
          reason: '${entry.key}',
        );
      }
      final short = fixture();
      short.payloads[powers]!.bytes = f32([2]);
      expect(() => D3Protocol.loadSceneBytes(short), throwsA(anything));
      final bad = fixture();
      bad.payloads[powers] = PayloadSpec(
        powers,
        encoding: PayloadEncoding.bytes,
        bytes: f32([2, 6]),
      );
      expect(() => D3Protocol.loadSceneBytes(bad), throwsA(anything));
    },
  );
  for (final compressed in [false, true]) {
    test(
      'binary JSON plus ${compressed ? 'GZBL' : 'BLOB'} attaches bytes to typed clip',
      () {
        final doc = fixture();
        final bytes = container(doc, compressed);
        final back = readFsceneb(bytes);
        expect(back.animations[clip], isA<Dart3dAnimationSpec>());
        expect(back.payloads[colors]!.bytes, doc.payloads[colors]!.bytes);
        expect(
          SceneAnimation.fromSpec(back.animations[clip]!, back).duration,
          2,
        );
      },
    );
  }
  test(
    'host property clips survive sync and async eager composition; prefab properties reject',
    () async {
      final host = fixture();
      const instance = LocalId(2, 1);
      host.addNode(
        NodeSpec(
          id: instance,
          instance: PrefabInstanceSpec(source: const AssetRef('ordinary')),
        ),
        root: true,
      );
      final prefab = SceneDocument()
        ..addNode(NodeSpec(id: const LocalId(3, 1)), root: true);
      prefab.animations[const LocalId(3, 2)] = AnimationSpec(
        const LocalId(3, 2),
        channels: [
          AnimationChannelSpec(
            target: const LocalId(3, 1),
            property: AnimationProperty.translation,
            timeline: const LocalId(3, 3),
            keyframes: const LocalId(3, 4),
          ),
        ],
      );
      final before = writeFsceneWithExtensions(host);
      final prefabBefore = writeFsceneWithExtensions(prefab);
      final sync = composeSceneWithExtensions(host, resolve: (_) => prefab);
      final async = await composeSceneAsyncWithExtensions(
        host,
        load: (_) async => prefab,
      );
      for (final result in [sync, async]) {
        expect(encodeAnimationSpec(result.animations[clip]!, result), literal);
        expect(result.nodes[instance]!.instance, isNull);
        expect(result.animations, hasLength(2));
        expect(
          result.animations.values
              .singleWhere((a) => a.id != clip)
              .channels
              .single
              .property,
          AnimationProperty.translation,
        );
      }
      expect(writeFsceneWithExtensions(host), before);
      expect(writeFsceneWithExtensions(prefab), prefabBefore);
      expect(
        () => composeSceneWithExtensions(host, resolve: (_) => fixture()),
        throwsUnsupportedError,
      );
      await expectLater(
        composeSceneAsyncWithExtensions(host, load: (_) async => fixture()),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'pending curves preserve late arrival and replacement bytes for native validation',
    () {
      final doc = SceneDocument();
      doc.animations[clip] = Dart3dAnimationSpec(
        clip,
        propertyChannels: [
          D3LightIntensityChannel(
            node: light,
            timeline: times,
            keyframes: powers,
          ),
        ],
      );
      final copy = readFsceneWithExtensions(writeFsceneWithExtensions(doc));
      expect(copy.animations[clip], isA<Dart3dAnimationSpec>());
      foldPayloadIntoDocument(
        doc,
        PayloadSpec(
          times,
          encoding: PayloadEncoding.floats,
          bytes: f32([0, 2]),
        ),
      );
      foldPayloadIntoDocument(
        doc,
        PayloadSpec(
          powers,
          encoding: PayloadEncoding.floats,
          bytes: f32([2, 6]),
        ),
      );
      foldPayloadIntoDocument(
        doc,
        PayloadSpec(
          powers,
          encoding: PayloadEncoding.floats,
          bytes: f32([-1, 6]),
        ),
      );
      expect(doc.payloads[powers]!.bytes, f32([-1, 6]));
      expect(() => D3Protocol.loadSceneBytes(doc), throwsFormatException);
      foldCommandIntoDocument(doc, {
        'op': 'upsertPayload',
        'id': 'chunk:000000800000G',
        'bytes': base64Encode(f32([4, 8])),
      });
      expect(doc.payloads[powers]!.bytes, f32([4, 8]));
      expect(SceneAnimation.fromSpec(doc.animations[clip]!, doc).duration, 2);
    },
  );
  test(
    'property reference ID alone changes upsert with equal and missing bytes',
    () {
      for (final ready in [false, true]) {
        final old = fixture();
        final next = serializeScene(old);
        const other = LocalId(1, 20);
        if (!ready) {
          old.payloads[powers]!.bytes = null;
          next.payloads[powers]!.bytes = null;
        }
        next.payloads[other] = PayloadSpec(
          other,
          encoding: PayloadEncoding.floats,
          bytes: next.payloads[powers]!.bytes,
        );
        final original = old.animations[clip] as Dart3dAnimationSpec;
        next.animations[clip] = Dart3dAnimationSpec(
          clip,
          name: original.name,
          propertyChannels: [
            original.propertyChannels[0],
            D3LightIntensityChannel(
              node: light,
              timeline: times,
              keyframes: other,
            ),
            original.propertyChannels[2],
          ],
        );
        expect(diffScene(old, next).animationsChanged, isFalse);
        final upserts = diffCommands(
          diffScene(old, next),
          old,
          next,
        ).where((op) => op['op'] == 'upsertAnimation');
        expect(upserts, hasLength(1));
        expect(
          ((upserts.single['animation'] as Map)['d3:properties']
              as List)[1]['keyframes'],
          'chunk:0000008000018',
        );
      }
    },
  );
  test(
    'property bytes alone change upsert; ordinary reference IDs remain significant',
    () {
      final old = fixture(), next = serializeScene(fixture());
      next.payloads[powers]!.bytes = f32([3, 7]);
      expect(
        diffCommands(
          diffScene(old, next),
          old,
          next,
        ).where((o) => o['op'] == 'upsertAnimation'),
        hasLength(1),
      );
      const alternate = LocalId(1, 20);
      final a = SceneDocument(), b = SceneDocument();
      a.animations[clip] = AnimationSpec(
        clip,
        channels: [
          AnimationChannelSpec(
            target: light,
            property: AnimationProperty.translation,
            timeline: times,
            keyframes: powers,
          ),
        ],
      );
      b.animations[clip] = AnimationSpec(
        clip,
        channels: [
          AnimationChannelSpec(
            target: light,
            property: AnimationProperty.translation,
            timeline: alternate,
            keyframes: powers,
          ),
        ],
      );
      expect(
        diffCommands(
          diffScene(a, b),
          a,
          b,
        ).where((o) => o['op'] == 'upsertAnimation'),
        hasLength(1),
      );
    },
  );
  test(
    'nested property prefab rejects when loaded without modifying any input',
    () async {
      final host = fixture();
      host.addNode(
        NodeSpec(
          id: const LocalId(2, 1),
          instance: PrefabInstanceSpec(source: const AssetRef('outer')),
        ),
        root: true,
      );
      final outer = SceneDocument()
        ..addNode(
          NodeSpec(
            id: const LocalId(3, 1),
            instance: PrefabInstanceSpec(source: const AssetRef('inner')),
          ),
          root: true,
        );
      final inner = fixture();
      final inputs = [host, outer, inner];
      final before = inputs.map(writeFsceneWithExtensions).toList();
      SceneDocument resolve(AssetRef ref) => ref.key == 'outer' ? outer : inner;
      expect(
        () => composeSceneWithExtensions(host, resolve: resolve),
        throwsUnsupportedError,
      );
      await expectLater(
        composeSceneAsyncWithExtensions(
          host,
          load: (ref) async => resolve(ref),
        ),
        throwsUnsupportedError,
      );
      expect(inputs.map(writeFsceneWithExtensions), before);
    },
  );
  test(
    'metadata rejects unexpected fields and duplicate endpoints while distinct node categories coexist',
    () {
      final property = (literal['d3:properties'] as List)[1] as Map;
      for (final bad in [
        {
          'kind': 'lightIntensity',
          'node': 'n:0000008000006',
          'timeline': 'chunk:000000800000C',
        },
        {...property, 'interpolation': 'linear'},
        {...property, 'material': 'mat:0000008000004'},
      ]) {
        expect(
          () => readFsceneWithExtensions(
            rawWith({
              'channels': [],
              'd3:properties': [bad],
            }),
          ),
          throwsA(anything),
        );
      }
      final c = D3LightIntensityChannel(
        node: light,
        timeline: times,
        keyframes: powers,
      );
      expect(
        () => Dart3dAnimationSpec(clip, propertyChannels: [c, c]),
        throwsArgumentError,
      );
      expect(
        Dart3dAnimationSpec(
          clip,
          propertyChannels: [
            c,
            D3CameraFovChannel(node: light, timeline: times, keyframes: fovs),
          ],
        ).propertyChannels,
        hasLength(2),
      );
    },
  );
  test(
    'all available f32 timeline and value constraints run through the wire ingress',
    () {
      final cases = <LocalId, List<List<double>>>{
        times: [
          [],
          [-1, 2],
          [2, 1],
          [0, double.nan],
          [0, double.infinity],
        ],
        colors: [
          [1, 0, 0, 1, -1, 0, 1, 1],
          [1, 0, 0, 1, 0, 0, 1, double.nan],
        ],
        powers: [
          [2, double.infinity],
          [],
        ],
        fovs: [
          [1, 3.2],
          [1, double.nan],
        ],
      };
      for (final entry in cases.entries) {
        for (final values in entry.value) {
          final doc = fixture();
          doc.payloads[entry.key]!.bytes = f32(values);
          expect(
            () => D3Protocol.loadSceneBytes(doc),
            throwsFormatException,
            reason: '${entry.key}: $values',
          );
        }
      }
      final unaligned = fixture();
      unaligned.payloads[powers]!.bytes = Uint8List(7);
      expect(() => D3Protocol.loadSceneBytes(unaligned), throwsFormatException);
      final badMetadata = fixture();
      badMetadata.payloads[powers] = PayloadSpec(
        powers,
        encoding: PayloadEncoding.floats,
        length: 7,
      );
      expect(
        () => D3Protocol.loadSceneBytes(badMetadata),
        throwsFormatException,
      );
      final hdr = fixture();
      hdr.payloads[colors]!.bytes = f32([10, 0, 0, 1, 0, 4, 1, 0]);
      expect(() => writeFsceneWithExtensions(hdr), returnsNormally);
    },
  );
  test(
    'binary deferred payload remains pending and validates when its bytes arrive',
    () {
      final doc = fixture();
      doc.payloads[powers]!.bytes = null;
      final back = readFsceneb(container(doc, true));
      expect(back.animations[clip], isA<Dart3dAnimationSpec>());
      expect(back.payloads[powers]!.bytes, isNull);
      foldPayloadIntoDocument(
        back,
        PayloadSpec(
          powers,
          encoding: PayloadEncoding.floats,
          bytes: f32([2, 6]),
        ),
      );
      expect(back.payloads[powers]!.bytes, f32([2, 6]));
      expect(SceneAnimation.fromSpec(back.animations[clip]!, back).duration, 2);
    },
  );
  test(
    'property timeline ID alone changes upsert even with equal or absent bytes',
    () {
      for (final ready in [true, false]) {
        final old = fixture(), next = serializeScene(fixture());
        const other = LocalId(1, 20);
        if (!ready) {
          old.payloads[times]!.bytes = null;
          next.payloads[times]!.bytes = null;
        }
        next.payloads[other] = PayloadSpec(
          other,
          encoding: PayloadEncoding.floats,
          bytes: next.payloads[times]!.bytes,
        );
        final spec = next.animations[clip] as Dart3dAnimationSpec;
        next.animations[clip] = Dart3dAnimationSpec(
          clip,
          name: spec.name,
          propertyChannels: [
            spec.propertyChannels[0],
            D3LightIntensityChannel(
              node: light,
              timeline: other,
              keyframes: powers,
            ),
            spec.propertyChannels[2],
          ],
        );
        expect(diffScene(old, next).animationsChanged, isFalse);
        final ops = diffCommands(
          diffScene(old, next),
          old,
          next,
        ).where((o) => o['op'] == 'upsertAnimation').toList();
        expect(ops, hasLength(1));
        expect(
          ((ops.single['animation'] as Map)['d3:properties']
              as List)[1]['timeline'],
          'chunk:0000008000018',
        );
      }
    },
  );
  test(
    'available color groups reject malformed arity even while timeline bytes are pending',
    () {
      final doc = fixture();
      doc.payloads[times]!.bytes = null;
      doc.payloads[colors]!.bytes = f32([1, 0, 0]);
      expect(() => D3Protocol.loadSceneBytes(doc), throwsFormatException);
    },
  );
  test(
    'binary attachment validates delivered BLOB and GZBL curves before returning document',
    () {
      for (final compressed in [false, true]) {
        final bytes = container(
          fixture(),
          compressed,
          blobs: {
            powers: f32([-1, 6]),
          },
        );
        expect(() => readFsceneb(bytes), throwsFormatException);
      }
    },
  );
}

Uint8List container(
  SceneDocument doc,
  bool compressed, {
  Map<LocalId, Uint8List> blobs = const {},
}) {
  final chunks = <int>[];
  void chunk(String type, List<int> bytes) {
    final header = ByteData(8)..setUint32(0, bytes.length, Endian.little);
    chunks.addAll(header.buffer.asUint8List().take(4));
    chunks.addAll(ascii.encode(type));
    chunks.addAll(bytes);
    chunks.addAll(List.filled((-bytes.length) & 7, 0));
  }

  chunk('JSON', utf8.encode(writeFsceneWithExtensions(doc)));
  for (final p in doc.payloads.values) {
    if (p.bytes == null) continue;
    final token = ascii.encode(p.id.toToken());
    final n = ByteData(4)..setUint32(0, token.length, Endian.little);
    final blob = [
      ...n.buffer.asUint8List(),
      ...token,
      ...(blobs[p.id] ?? p.bytes!),
    ];
    chunk(compressed ? 'GZBL' : 'BLOB', compressed ? gzip.encode(blob) : blob);
  }
  final header = ByteData(16)
    ..setUint32(4, 2, Endian.little)
    ..setUint32(8, 16 + chunks.length, Endian.little);
  final out = Uint8List.fromList([...header.buffer.asUint8List(), ...chunks]);
  out.setRange(0, 4, ascii.encode('FSCB'));
  return out;
}
