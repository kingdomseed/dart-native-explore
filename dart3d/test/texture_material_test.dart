// W4 texture/material checks: the image-payload manifest fields and
// the material texture-slot encodings the native decoders read —
// pinned by docs/texture-material-spec.md. Same constraint as
// payload_geometry_test.dart: package:dart3d/dart3d.dart is
// unreachable under `dart test` — the barrel transitively imports
// package:dartnative, which needs DartNative's patched SDK (dart:ui) —
// so this pulls the pure-Dart libraries directly.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // A document shaped like feature_scene's W4 probes: rgba8 image
  // payloads (one attached, one manifest-only deferred), texture
  // resources pointing at them, and one material carrying every
  // texture slot the spec names plus a KHR_texture_transform map.
  SceneDocument buildDoc() {
    final doc = SceneDocument();
    final pixels = Uint8List(8 * 8 * 4);
    final img = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: 8,
        height: 8,
        length: pixels.lengthInBytes,
        bytes: pixels,
      ),
    );
    final deferredImg = doc.addPayload(
      PayloadSpec(
        doc.newId(),
        encoding: PayloadEncoding.image,
        format: 'rgba8',
        width: 8,
        height: 8,
        length: pixels.lengthInBytes,
      ),
    );
    final tex = doc.addResource(TextureResource(doc.newId(), payload: img.id));
    final normalTex = doc.addResource(
      TextureResource(doc.newId(), payload: img.id, content: 'normal'),
    );
    final deferredTex = doc.addResource(
      TextureResource(doc.newId(), payload: deferredImg.id),
    );
    doc.addResource(
      MaterialResource(
        doc.newId(),
        type: 'physicallyBased',
        properties: {
          'baseColor': ColorValue(0.05, 0.05, 0.08, 1.0),
          'baseColorTexture': ResourceRefValue(tex.id),
          'baseColorTextureTransform': MapValue({
            'offset': Vec2Value(Vector2(0.25, 0.25)),
            'scale': Vec2Value(Vector2(0.5, 0.5)),
            'rotation': DoubleValue(0),
            'texCoord': IntValue(0),
          }),
          'normalTexture': ResourceRefValue(normalTex.id),
          'normalScale': DoubleValue(1.0),
          'metallicRoughnessTexture': ResourceRefValue(normalTex.id),
          'emissive': ColorValue(1, 1, 1, 1),
          'emissiveStrength': DoubleValue(2.0),
          'emissiveTexture': ResourceRefValue(deferredTex.id),
        },
      ),
    );
    return doc;
  }

  Map<String, dynamic> manifest(SceneDocument doc) =>
      jsonDecode(utf8.decode(D3Protocol.loadSceneBytes(doc)))
          as Map<String, dynamic>;

  group('image payload manifest entries', () {
    test('rgba8 payloads carry format/width/height/length', () {
      final payloads = manifest(buildDoc())['payloads'] as Map<String, dynamic>;
      expect(payloads, hasLength(2));
      for (final entry in payloads.entries) {
        expect(entry.key, isA<String>());
        final p = entry.value as Map<String, dynamic>;
        expect(p['encoding'], 'image');
        expect(p['format'], 'rgba8');
        expect(p['width'], 8);
        expect(p['height'], 8);
        // rgba8: length == width*height*4 (spec's required field).
        expect(p['length'], 8 * 8 * 4);
        // Bytes never appear in the manifest — they stream as chunks.
        expect(p.containsKey('bytes'), isFalse);
      }
    });

    test('the byte-less deferred payload is still in the manifest', () {
      final doc = buildDoc();
      final payloads = manifest(doc)['payloads'] as Map<String, dynamic>;
      final deferred = doc.payloads.values.firstWhere((p) => p.bytes == null);
      // Its `chunk:` token resolves in the manifest like any other.
      expect(payloads.keys, contains('chunk:${deferred.id.toToken()}'));
    });

    test('the image payload descriptor round-trips through writeFscene', () {
      final doc = buildDoc();
      final reread = readFscene(writeFscene(doc));
      expect(reread.payloads, hasLength(2));
      for (final p in reread.payloads.values) {
        expect(p.encoding, PayloadEncoding.image);
        expect(p.format, 'rgba8');
        expect(p.width, 8);
        expect(p.height, 8);
        expect(p.length, 8 * 8 * 4);
        // Chunk bytes are out-of-band — the descriptor never holds them.
        expect(p.bytes, isNull);
      }
    });
  });

  group('texture resources', () {
    test('encode kind/payload/content with manifest token forms', () {
      final json = manifest(buildDoc());
      final payloads = json['payloads'] as Map<String, dynamic>;
      final textures = [
        for (final r in (json['resources'] as Map<String, dynamic>).entries)
          if ((r.value as Map<String, dynamic>)['kind'] == 'texture')
            (key: r.key, spec: r.value),
      ];
      expect(textures, hasLength(3));
      for (final t in textures) {
        // Resource keys carry the `tex:` prefix; payload refs `chunk:`.
        expect(t.key, startsWith('tex:'));
        expect(t.spec['payload'], isA<String>());
        expect(payloads.keys, contains(t.spec['payload']));
      }
      // `content` is emitted only when it differs from the default
      // 'color' — exactly one of these declares 'normal'.
      expect(
        textures.where((t) => t.spec['content'] == 'normal'),
        hasLength(1),
      );
      expect(
        textures.where((t) => !t.spec.containsKey('content')),
        hasLength(2),
      );
    });
  });

  group('material texture slots', () {
    test('refs are rref tokens; the transform is a tagged map', () {
      final json = manifest(buildDoc());
      final resources = json['resources'] as Map<String, dynamic>;
      final texKeys = {
        for (final r in resources.entries)
          if ((r.value as Map<String, dynamic>)['kind'] == 'texture') r.key,
      };
      final material = resources.values
          .map((r) => r as Map<String, dynamic>)
          .singleWhere((r) => r['kind'] == 'material');
      expect(material['type'], 'physicallyBased');
      final props = material['properties'] as Map<String, dynamic>;

      // Texture slots encode as {'rref': '<tex:token>'} and the token
      // is the referenced texture's own manifest key.
      for (final slot in [
        'baseColorTexture',
        'normalTexture',
        'metallicRoughnessTexture',
        'emissiveTexture',
      ]) {
        final ref = props[slot] as Map<String, dynamic>;
        expect(texKeys, contains(ref['rref']));
      }
      expect(props['normalScale'], {'d': 1.0});
      expect(props['emissiveStrength'], {'d': 2.0});
      expect(props['emissive'], {
        'c': [1.0, 1.0, 1.0, 1.0],
      });

      // KHR_texture_transform rides as a MapValue — {'map': {…}} with
      // each field tagged (v2 offset/scale, d rotation, i texCoord).
      final transform = props['baseColorTextureTransform'] as Map;
      final map = transform['map'] as Map<String, dynamic>;
      expect(
        map.keys,
        containsAll(['offset', 'scale', 'rotation', 'texCoord']),
      );
      expect(map['offset'], {
        'v2': [0.25, 0.25],
      });
      expect(map['scale'], {
        'v2': [0.5, 0.5],
      });
      expect(map['rotation'], {'d': 0.0});
      expect(map['texCoord'], {'i': 0});
    });
  });

  group('upsertResource command', () {
    test('id tokens parse back to the minted LocalIds', () {
      final doc = buildDoc();
      // Same emission as feature_scene's +6 s lane-10 swap: the
      // texture's `tex:` manifest key and the payload's `chunk:` key.
      final tex = doc.resources.values.whereType<TextureResource>().first;
      final alt = doc.payloads.keys.first;
      final op = {
        'op': 'upsertResource',
        'id': 'tex:${tex.id.toToken()}',
        'resource': {
          'kind': 'texture',
          'payload': 'chunk:${alt.toToken()}',
          'content': 'color',
        },
      };
      final decoded =
          jsonDecode(utf8.decode(D3Protocol.commandBytes(op)))
              as Map<String, dynamic>;
      // LocalId.parse strips the readability prefix exactly like the
      // native D3Wire.localIdKey decoder.
      expect(LocalId.parse(decoded['id'] as String), tex.id);
      final resource = decoded['resource'] as Map<String, dynamic>;
      expect(resource['kind'], 'texture');
      expect(LocalId.parse(resource['payload'] as String), alt);
      expect(resource['content'], 'color');
    });
  });
}
