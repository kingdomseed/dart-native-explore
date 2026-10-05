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
}
