// W3 payload-geometry checks: the VertexPack interleave and the
// manifest encoding native decoders read. `package:dart3d/dart3d.dart`
// is unreachable under `dart test` — the barrel transitively imports
// package:dartnative, which needs DartNative's patched SDK (dart:ui) —
// so this pulls the pure-Dart libraries directly.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:dart3d/src/protocol.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:dart3d/src/vertex_pack.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  // A known 4-vertex face-up quad in unskinned_uv1_tangent.
  final positions = [
    Vector3(-0.5, 0, -0.5),
    Vector3(0.5, 0, -0.5),
    Vector3(0.5, 0, 0.5),
    Vector3(-0.5, 0, 0.5),
  ];
  final uvs = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)];
  final colors = [
    Vector4(1, 0, 0, 1),
    Vector4(0, 1, 0, 1),
    Vector4(0, 0, 1, 1),
    Vector4(1, 1, 0, 1),
  ];
  final tangents = [
    Vector4(1, 0, 0, 1),
    Vector4(1, 0, 0, -1),
    Vector4(0, 0, 1, 1),
    Vector4(-1, 0, 0, 1),
  ];
  final vertices = VertexPack.unskinned(
    positions: positions,
    normals: [for (var i = 0; i < 4; i++) Vector3(0, 1, 0)],
    uvs: uvs,
    colors: colors,
    tangents: tangents,
  );
  // CCW from the +Y front face; uint16 index payload.
  final indices = Uint16List.fromList(const [0, 2, 1, 0, 3, 2]);
  final bounds = BoundsSpec(
    min: Vector3(-0.5, 0, -0.5),
    max: Vector3(0.5, 0, 0.5),
  );

  /// Test-local unpacker: reads one vertex of the 72 B interleave back.
  ({
    Vector3 position,
    Vector3 normal,
    Vector2 uv0,
    Vector2 uv1,
    Vector4 color,
    Vector4 tangent,
  }) unpackVertex(Uint8List bytes, int i) {
    final d = ByteData.sublistView(bytes, i * 72, (i + 1) * 72);
    double f(int n) => d.getFloat32(n * 4, Endian.little);
    return (
      position: Vector3(f(0), f(1), f(2)),
      normal: Vector3(f(3), f(4), f(5)),
      uv0: Vector2(f(6), f(7)),
      uv1: Vector2(f(8), f(9)),
      color: Vector4(f(10), f(11), f(12), f(13)),
      tangent: Vector4(f(14), f(15), f(16), f(17)),
    );
  }

  group('VertexPack.unskinned', () {
    test('vertex count is bytes/72 and fields land in order', () {
      expect(vertices.lengthInBytes % 72, 0);
      expect(vertices.lengthInBytes ~/ 72, positions.length);

      final v = unpackVertex(vertices, 2);
      expect(v.position, positions[2]);
      expect(v.normal, Vector3(0, 1, 0));
      expect(v.uv0, uvs[2]);
      expect(v.uv1, Vector2.zero()); // uv1 is always zero-filled
      expect(v.color, colors[2]);
      expect(v.tangent, tangents[2]); // xyz + handedness w
    });

    test('omitted channels get the upstream neutral fill', () {
      final sparse = VertexPack.unskinned(positions: positions);
      final v = unpackVertex(sparse, 0);
      expect(v.normal, Vector3(0, 0, 1));
      expect(v.uv0, Vector2.zero());
      expect(v.color, Vector4(1, 1, 1, 1));
      expect(v.tangent, Vector4(1, 0, 0, 1));
    });

    test('mismatched channel length is an authoring error', () {
      expect(
        () => VertexPack.unskinned(
          positions: positions,
          normals: [Vector3(0, 1, 0)],
        ),
        throwsArgumentError,
      );
    });

    test('bounds computed from packed positions match the BoundsSpec', () {
      final min = Vector3.all(double.infinity);
      final max = Vector3.all(double.negativeInfinity);
      for (var i = 0; i < vertices.lengthInBytes ~/ 72; i++) {
        final p = unpackVertex(vertices, i).position;
        Vector3.min(min, p, min);
        Vector3.max(max, p, max);
      }
      expect(min, bounds.min);
      expect(max, bounds.max);
    });
  });

  group('manifest encoding', () {
    // A minimal document shaped like feature_scene's payload probes:
    // an upstream-layout geometry with CCW uint16 indices + bounds, a
    // legacyWinding sibling on a CW index payload, and a manifest-only
    // (bytes: null) deferred vertex payload.
    SceneDocument buildDoc() {
      final doc = SceneDocument();
      final verts = doc.addPayload(
        PayloadSpec(
          doc.newId(),
          encoding: PayloadEncoding.vertexBuffer,
          layout: 'unskinned_uv1_tangent',
          length: vertices.lengthInBytes,
          bytes: vertices,
        ),
      );
      final idx = doc.addPayload(
        PayloadSpec(
          doc.newId(),
          encoding: PayloadEncoding.indexBuffer,
          format: 'uint16',
          length: indices.lengthInBytes,
          bytes: indices.buffer.asUint8List(),
        ),
      );
      final idxCw = doc.addPayload(
        PayloadSpec(
          doc.newId(),
          encoding: PayloadEncoding.indexBuffer,
          format: 'uint16',
          length: indices.lengthInBytes,
          bytes: Uint16List.fromList(const [0, 1, 2, 0, 2, 3])
              .buffer
              .asUint8List(),
        ),
      );
      final deferred = doc.addPayload(
        PayloadSpec(
          doc.newId(),
          encoding: PayloadEncoding.vertexBuffer,
          layout: 'unskinned_uv1_tangent',
          length: vertices.lengthInBytes,
        ),
      );
      doc.addResource(
        GeometryResource(
          doc.newId(),
          vertices: verts.id,
          indices: idx.id,
          bounds: bounds,
        ),
      );
      doc.addResource(
        GeometryResource(
          doc.newId(),
          vertices: verts.id,
          indices: idxCw.id,
          bounds: bounds,
          legacyWinding: true,
        ),
      );
      doc.addResource(
        GeometryResource(
          doc.newId(),
          vertices: deferred.id,
          indices: idx.id,
          bounds: bounds,
        ),
      );
      return doc;
    }

    test('payloads carry encoding/layout/format and geometry ref tokens',
        () {
      // Same encoder loadSceneBytes runs on the wire path.
      final json = jsonDecode(
        utf8.decode(D3Protocol.loadSceneBytes(buildDoc())),
      ) as Map<String, dynamic>;

      final payloads = json['payloads'] as Map<String, dynamic>;
      expect(payloads, hasLength(4));
      for (final entry in payloads.entries) {
        // Payload manifest keys are plain-string id tokens.
        expect(entry.key, isA<String>());
        final p = entry.value as Map<String, dynamic>;
        expect(p['encoding'], isA<String>());
        expect(p['length'], isA<int>());
        switch (p['encoding']) {
          case 'vertexBuffer':
            expect(p['layout'], 'unskinned_uv1_tangent');
          case 'indexBuffer':
            expect(p['format'], 'uint16');
        }
      }

      final resources = json['resources'] as Map<String, dynamic>;
      final geometries = [
        for (final r in resources.values)
          (r as Map<String, dynamic>),
      ];
      expect(geometries, hasLength(3));
      for (final geo in geometries) {
        expect(geo['kind'], 'geometry');
        expect(geo['vertices'], isA<String>());
        expect(geo['indices'], isA<String>());
        expect(geo['bounds'], {
          'min': [-0.5, 0.0, -0.5],
          'max': [0.5, 0.0, 0.5],
        });
      }
      final legacy = geometries.where((g) => g['legacyWinding'] == true);
      expect(legacy, hasLength(1));
      // The deferred payload is in the manifest too — its token
      // resolves like any other; only the chunk bytes arrive later.
      final unresolved = geometries.where(
        (g) => !payloads.keys.contains(g['vertices'] ?? ''),
      );
      expect(unresolved, hasLength(0));
    });

    test('index payload element count is bytes/format-width', () {
      expect(indices.lengthInBytes ~/ 2, 6);
      expect(
        Uint16List.view(indices.buffer).toList(),
        [0, 2, 1, 0, 3, 2],
      );
    });

    test('payloadBytes frames id + chunk; byte-less payloads refuse', () {
      final doc = buildDoc();
      final payload = doc.payloads.values.firstWhere(
        (p) => p.encoding == PayloadEncoding.vertexBuffer,
      );
      final framed = D3Protocol.payloadBytes(payload);
      expect(framed.lengthInBytes, 8 + payload.bytes!.lengthInBytes);
      // First 8 bytes are the LocalId (session u32, index u32 LE).
      final head = ByteData.sublistView(framed);
      expect(head.getUint32(0, Endian.little), payload.id.session);
      expect(head.getUint32(4, Endian.little), payload.id.index);
      expect(
        Uint8List.sublistView(framed, 8),
        payload.bytes,
      );

      final deferred = doc.payloads.values.firstWhere(
        (p) => p.bytes == null,
      );
      expect(() => D3Protocol.payloadBytes(deferred), throwsArgumentError);
    });
  });
}
