// `readFsceneb` conformance: dart3d's archive-free container reader
// (lib/src/fsceneb_reader.dart) against hand-built containers and the
// real upstream-importer artifacts in assets/dice/ (the tome_keeper
// dice set converted from .glb by `dart run flutter_scene:import`).
// Same constraint as the codec fixture: tests pull the pure-Dart
// libraries directly — the dart3d barrel needs DartNative's patched
// SDK.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart3d/src/fsceneb_reader.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

/// Emits a `.fsceneb` container byte-for-byte per upstream's format
/// (lib/src/binary/fsceneb.dart): 16-byte header, one JSON chunk, then
/// one BLOB/GZBL chunk per payload — GZBL when gzip actually shrinks.
Uint8List emitFsceneb(
  SceneDocument doc, {
  Map<LocalId, Uint8List> blobBytes = const {},
  Set<LocalId> forceGzip = const {},
}) {
  final body = BytesBuilder();
  void addChunk(String type, Uint8List data) {
    final preamble = Uint8List(8)
      ..setRange(4, 8, ascii.encode(type));
    ByteData.sublistView(preamble)
        .setUint32(0, data.length, Endian.little);
    body.add(preamble);
    body.add(data);
    final remainder = data.length % 8;
    if (remainder != 0) body.add(Uint8List(8 - remainder));
  }

  addChunk('JSON', utf8.encode(writeFscene(doc)));
  for (final entry in doc.payloads.entries) {
    final bytes = blobBytes[entry.key];
    if (bytes == null) continue;
    final token = ascii.encode(entry.key.toToken());
    final blob = Uint8List(4 + token.length + bytes.length)
      ..setRange(4, 4 + token.length, token)
      ..setRange(4 + token.length, 4 + token.length + bytes.length, bytes);
    ByteData.sublistView(blob).setUint32(0, token.length, Endian.little);
    final compressed = Uint8List.fromList(gzip.encode(blob));
    if (compressed.length < blob.length || forceGzip.contains(entry.key)) {
      addChunk('GZBL', compressed);
    } else {
      addChunk('BLOB', blob);
    }
  }
  final bodyBytes = body.toBytes();
  final out = Uint8List(16 + bodyBytes.length)
    ..setRange(0, 4, const [0x46, 0x53, 0x43, 0x42])
    ..setRange(16, 16 + bodyBytes.length, bodyBytes);
  ByteData.sublistView(out)
    ..setUint32(4, 2, Endian.little)
    ..setUint32(8, out.length, Endian.little);
  return out;
}

SceneDocument oneMeshDoc() {
  final doc = SceneDocument();
  const vertsId = LocalId(9, 0);
  const geoId = LocalId(9, 1);
  const matId = LocalId(9, 2);
  const nodeId = LocalId(9, 3);
  doc.addPayload(PayloadSpec(vertsId,
      encoding: PayloadEncoding.vertexBuffer,
      layout: 'unskinned_soa_uv1_tangent'));
  doc.addResource(GeometryResource(geoId, vertices: vertsId));
  doc.addResource(MaterialResource(matId, type: 'physicallyBased'));
  doc.addNode(
    NodeSpec(id: nodeId, name: 'die', components: [
      ComponentSpec('mesh', properties: {}),
    ]),
    root: true,
  );
  return doc;
}

void main() {
  test('round-trip: manifest + BLOB + GZBL payloads land on the doc', () {
    final doc = oneMeshDoc();
    final blobBytes = {
      const LocalId(9, 0): Uint8List.fromList(
          List.generate(144, (i) => i & 0xff)), // compressible → GZBL
    };
    final container = emitFsceneb(doc, blobBytes: blobBytes);

    final read = readFsceneb(container);
    expect(read.nodes.length, 1);
    expect(read.nodes.values.single.name, 'die');
    expect(read.resources.length, 2);
    final payload = read.payload(const LocalId(9, 0));
    expect(payload, isNotNull);
    expect(payload!.layout, 'unskinned_soa_uv1_tangent');
    expect(payload.bytes, blobBytes[const LocalId(9, 0)]);
  });

  test('BLOB chunk lands uncompressed bytes', () {
    final doc = oneMeshDoc();
    // Incompressible bytes → stays a BLOB chunk.
    final raw = Uint8List.fromList(
        List.generate(64, (i) => (i * 2654435761) & 0xff));
    final container = emitFsceneb(doc,
        blobBytes: {const LocalId(9, 0): raw});
    final read = readFsceneb(container);
    expect(read.payload(const LocalId(9, 0))!.bytes, raw);
  });

  test('unknown chunk types are skipped', () {
    final doc = oneMeshDoc();
    final body = BytesBuilder();
    void addChunk(String type, List<int> data) {
      final preamble = Uint8List(8)
        ..setRange(4, 8, ascii.encode(type));
      ByteData.sublistView(preamble)
          .setUint32(0, data.length, Endian.little);
      body.add(preamble);
      body.add(data);
      final r = data.length % 8;
      if (r != 0) body.add(Uint8List(8 - r));
    }

    addChunk('JSON', utf8.encode(writeFscene(doc)));
    addChunk('NOPE', Uint8List(24));
    final bodyBytes = body.toBytes();
    final out = Uint8List(16 + bodyBytes.length)
      ..setRange(0, 4, const [0x46, 0x53, 0x43, 0x42])
      ..setRange(16, 16 + bodyBytes.length, bodyBytes);
    ByteData.sublistView(out)
      ..setUint32(4, 2, Endian.little)
      ..setUint32(8, out.length, Endian.little);
    expect(readFsceneb(out).nodes.length, 1);
  });

  test('rejects bad magic, truncation, and newer versions', () {
    final good = emitFsceneb(oneMeshDoc());
    final badMagic = Uint8List.fromList(good)..[0] = 0x58;
    expect(() => readFsceneb(badMagic),
        throwsA(isA<FscenebFormatException>()));
    expect(() => readFsceneb(Uint8List(8)),
        throwsA(isA<FscenebFormatException>()));
    final newer = Uint8List.fromList(good);
    ByteData.sublistView(newer).setUint32(4, 99, Endian.little);
    expect(() => readFsceneb(newer),
        throwsA(isA<FscenebFormatException>()));
  });

  test('real importer artifact: d4 .fsceneb decodes with payloads', () {
    final file = File('assets/dice/scene.d4.dbe53cde.fsceneb');
    final doc = readFsceneb(file.readAsBytesSync());
    expect(doc.nodes.length, 1);
    expect(doc.resources.values.whereType<GeometryResource>().length, 2);
    expect(doc.resources.values.whereType<MaterialResource>().length, 2);
    expect(doc.payloads.length, 4);
    for (final p in doc.payloads.values) {
      expect(p.bytes, isNotNull,
          reason: 'payload ${p.id} bytes should attach');
      expect(p.bytes!.length, greaterThan(0));
    }
    // The importer emits unskinned_soa_uv1_tangent vertex buffers +
    // uint16 index buffers for this corpus.
    final encodings = doc.payloads.values.map((p) => p.encoding).toSet();
    expect(encodings, {
      PayloadEncoding.vertexBuffer,
      PayloadEncoding.indexBuffer,
    });
  });

  test('real importer artifact: full dice set decodes', () {
    final dir = Directory('assets/dice');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.fsceneb'));
    expect(files.length, 7);
    for (final f in files) {
      final doc = readFsceneb(f.readAsBytesSync());
      expect(doc.nodes, isNotEmpty, reason: f.path);
      for (final p in doc.payloads.values) {
        expect(p.bytes, isNotNull, reason: '${f.path} ${p.id}');
      }
    }
  });

  // W21 light-units contract: upstream's importer bakes glTF
  // photometric intensity to `n = photometric / (683 · luminance)`;
  // the reader translates it back to SceneKit-scale `intensity`
  // (n · 683 · luminance · kGltfToSceneKitLightScale).
  group('light field n → intensity (W21)', () {
    SceneDocument lightDoc(
      Map<String, PropertyValue> props, {
      String type = 'directionalLight',
    }) {
      final doc = SceneDocument();
      doc.addNode(
        NodeSpec(
          id: const LocalId(9, 0),
          name: 'light',
          components: [ComponentSpec(type, properties: props)],
        ),
        root: true,
      );
      return doc;
    }

    Map<String, PropertyValue> lightProps(SceneDocument doc) =>
        doc.nodes.values.single.components.single.properties;

    double? intensityOf(SceneDocument doc) =>
        switch (lightProps(doc)['intensity']) {
          DoubleValue(:final value) => value,
          _ => null,
        };

    test('n-only light converts to SceneKit-scale intensity', () {
      // A white 2.0-lux glTF directional ships n = 2/683.
      final doc = lightDoc({
        'n': DoubleValue(2.0 / 683.0),
        'color': Vec3Value(Vector3(1, 1, 1)),
      });
      final read = readFsceneb(emitFsceneb(doc));
      expect(
        intensityOf(read),
        closeTo(2.0 * kGltfToSceneKitLightScale, 1e-2),
      );
      // `n` is preserved — a re-encode keeps the upstream field.
      expect(lightProps(read)['n'], isA<DoubleValue>());
    });

    test('absent color reads as white (luminance 1)', () {
      final doc = lightDoc({'n': DoubleValue(1.5 / 683.0)});
      final read = readFsceneb(emitFsceneb(doc));
      expect(
        intensityOf(read),
        closeTo(1.5 * kGltfToSceneKitLightScale, 1e-2),
      );
    });

    test('color luminance scales the recovered intensity', () {
      // Same n, saturated red (luma 0.2126): upstream divided the
      // photometric value by that luma, so decode multiplies it back.
      final red = lightDoc({
        'n': DoubleValue(2.0 / (683.0 * 0.2126)),
        'color': Vec3Value(Vector3(1, 0, 0)),
      });
      final white = lightDoc({'n': DoubleValue(2.0 / 683.0)});
      expect(
        intensityOf(readFsceneb(emitFsceneb(red))),
        closeTo(2.0 * kGltfToSceneKitLightScale, 1e-2),
      );
      // And a bare n with a non-unit luminance does scale by it.
      expect(
        intensityOf(
          readFsceneb(
            emitFsceneb(
              lightDoc({
                'n': DoubleValue(0.01),
                'color': Vec3Value(Vector3(1, 0, 0)),
              }),
            ),
          ),
        ),
        closeTo(0.01 * 683.0 * 0.2126 * kGltfToSceneKitLightScale, 1e-3),
      );
      expect(intensityOf(readFsceneb(emitFsceneb(white))), isNotNull);
    });

    test('ColorValue colors read the same luminance', () {
      final doc = lightDoc({
        'n': DoubleValue(2.0 / (683.0 * 0.2126)),
        'color': const ColorValue(1, 0, 0, 1),
      });
      expect(
        intensityOf(readFsceneb(emitFsceneb(doc))),
        closeTo(2.0 * kGltfToSceneKitLightScale, 1e-2),
      );
    });

    test('intensity-only light is untouched', () {
      final doc = lightDoc({'intensity': DoubleValue(1400)});
      final read = readFsceneb(emitFsceneb(doc));
      expect(intensityOf(read), 1400);
      expect(lightProps(read).containsKey('n'), isFalse);
    });

    test('both fields present: authored intensity wins', () {
      final doc = lightDoc({
        'n': DoubleValue(0.01),
        'intensity': DoubleValue(1400),
      });
      final read = readFsceneb(emitFsceneb(doc));
      expect(intensityOf(read), 1400);
    });

    test('neither field: no intensity synthesized', () {
      final doc = lightDoc({'castsShadow': BoolValue(true)});
      final read = readFsceneb(emitFsceneb(doc));
      expect(lightProps(read).containsKey('intensity'), isFalse);
    });

    test('point and spot lights translate; non-light n does not', () {
      for (final type in ['pointLight', 'spotLight']) {
        final doc = lightDoc(
          {'n': DoubleValue(1.0 / 683.0)},
          type: type,
        );
        expect(
          intensityOf(readFsceneb(emitFsceneb(doc))),
          closeTo(kGltfToSceneKitLightScale, 1),
          reason: type,
        );
      }
      // `n` on a non-light component is not the light field — left alone.
      final mesh = lightDoc(
        {'n': DoubleValue(0.5)},
        type: 'mesh',
      );
      final read = readFsceneb(emitFsceneb(mesh));
      expect(lightProps(read).containsKey('intensity'), isFalse);
      expect(lightProps(read)['n'], isA<DoubleValue>());
    });

    test('n as IntValue translates', () {
      final doc = lightDoc({'n': const IntValue(1)});
      final read = readFsceneb(emitFsceneb(doc));
      expect(
        intensityOf(read),
        closeTo(683.0 * kGltfToSceneKitLightScale, 1),
      );
    });

    test('normalizeLightIntensity is idempotent', () {
      final doc = lightDoc({'n': DoubleValue(2.0 / 683.0)});
      final read = readFsceneb(emitFsceneb(doc));
      final once = intensityOf(read);
      normalizeLightIntensity(read);
      expect(intensityOf(read), once);
    });
  });
}
