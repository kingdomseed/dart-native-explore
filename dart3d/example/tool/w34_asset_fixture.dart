import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart3d/src/diff_apply.dart';
import 'package:dart3d/src/scene_model.dart';
import 'package:vector_math/vector_math.dart';

const w34ImageId = LocalId(0x7734, 0);

Uint8List w34Pixels({bool alternate = false}) => Uint8List.fromList(
  alternate
      ? [
          20,
          80,
          255,
          255,
          255,
          220,
          20,
          255,
          255,
          220,
          20,
          255,
          20,
          80,
          255,
          255,
        ]
      : [
          255,
          30,
          20,
          255,
          20,
          240,
          70,
          255,
          20,
          240,
          70,
          255,
          255,
          30,
          20,
          255,
        ],
);

SceneDocument buildW34AssetDocument() {
  final doc = SceneDocument(
    documentId: DocumentId.parse('48HJ89964WM2JAHB5GPJWBSG64'),
    allocator: IdAllocator(session: 0x7734),
  )..payloadSource = 'pixels.fsceneb';
  final image = doc.addPayload(
    PayloadSpec(
      doc.newId(),
      encoding: PayloadEncoding.image,
      format: 'rgba8',
      width: 2,
      height: 2,
      length: 16,
    ),
  );
  final texture = doc.addResource(
    TextureResource(doc.newId(), payload: image.id),
  );
  final material = doc.addResource(
    MaterialResource(
      doc.newId(),
      type: 'unlit',
      properties: {
        'baseColor': const ColorValue(1, 1, 1, 1),
        'baseColorTexture': ResourceRefValue(texture.id),
        'doubleSided': const BoolValue(true),
      },
    ),
  );
  final geometry = doc.addResource(
    GeometryResource(
      doc.newId(),
      procedural: PlaneGeometrySpec(width: 3, depth: 3),
    ),
  );
  doc.createNode(
    name: 'w34.quad',
    root: true,
    transform: TrsTransform(
      rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -math.pi / 2),
    ),
    components: [
      ComponentSpec(
        'mesh',
        properties: {
          'geometry': ResourceRefValue(geometry.id),
          'material': ResourceRefValue(material.id),
        },
      ),
    ],
  );
  doc.createNode(
    name: 'w34.camera',
    root: true,
    transform: TrsTransform(translation: Vector3(0, 0, -6)),
    components: [
      ComponentSpec(
        'camera',
        properties: {
          'projection': const StringValue('perspective'),
          'fovRadiansY': const DoubleValue(0.8),
          'near': const DoubleValue(0.1),
          'far': const DoubleValue(30),
        },
      ),
    ],
  );
  doc.stage.environmentRef = doc
      .addResource(
        EnvironmentResource(
          doc.newId(),
          environment: const EmptyEnvironment(),
          environmentIntensity: 0,
          exposure: 1,
          toneMapping: 'linear',
          effects: EnvironmentEffectsSpec(),
        ),
      )
      .id;
  return doc;
}

/// Fixture-only FSCB encoder. The production reader remains the format owner.
Uint8List emitW34Container(
  SceneDocument doc, {
  Map<LocalId, Uint8List> blobs = const {},
}) {
  final body = BytesBuilder();
  void chunk(String type, Uint8List bytes) {
    final header = Uint8List(8)..setRange(4, 8, ascii.encode(type));
    ByteData.sublistView(header).setUint32(0, bytes.length, Endian.little);
    body
      ..add(header)
      ..add(bytes)
      ..add(Uint8List((-bytes.length) & 7));
  }

  chunk('JSON', utf8.encode(writeFsceneWithExtensions(doc)));
  for (final entry in blobs.entries) {
    final token = ascii.encode(entry.key.toToken());
    final blob = Uint8List(4 + token.length + entry.value.length)
      ..setRange(4, 4 + token.length, token)
      ..setRange(
        4 + token.length,
        4 + token.length + entry.value.length,
        entry.value,
      );
    ByteData.sublistView(blob).setUint32(0, token.length, Endian.little);
    chunk('BLOB', blob);
  }
  final bytes = body.takeBytes();
  final result = Uint8List(16 + bytes.length)
    ..setRange(0, 4, ascii.encode('FSCB'))
    ..setRange(16, 16 + bytes.length, bytes);
  ByteData.sublistView(result)
    ..setUint32(4, 2, Endian.little)
    ..setUint32(8, result.length, Endian.little);
  return result;
}

void writeW34Pattern(Directory directory, {bool alternate = false}) {
  File('${directory.path}/pixels.fsceneb').writeAsBytesSync(
    emitW34Container(
      buildW34AssetDocument(),
      blobs: {w34ImageId: w34Pixels(alternate: alternate)},
    ),
    flush: true,
  );
}

void main(List<String> args) {
  if (args.length != 2 || !['init', 'a', 'b', 'malformed'].contains(args[1])) {
    stderr.writeln(
      'Usage: dart tool/w34_asset_fixture.dart DIRECTORY init|a|b|malformed',
    );
    exitCode = 64;
    return;
  }
  final directory = Directory(args[0]);
  if (args[1] == 'init') {
    directory.createSync(recursive: true);
    File('${directory.path}/quad.fscene').writeAsStringSync(
      writeFsceneWithExtensions(buildW34AssetDocument()),
      flush: true,
    );
  }
  if (args[1] == 'malformed') {
    File(
      '${directory.path}/pixels.fsceneb',
    ).writeAsBytesSync([0, 1, 2], flush: true);
  } else {
    writeW34Pattern(directory, alternate: args[1] == 'b');
  }
  stdout.writeln('fixture ${args[1]} ${directory.absolute.path}');
}
