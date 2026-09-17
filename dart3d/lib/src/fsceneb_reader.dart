/// Reads `.fsceneb` containers without `package:archive`.
///
/// Upstream's reader (`package:scene/src/binary/fsceneb.dart`) is unreachable
/// in DartNative-compiled code: the patched SDK bakes a pre-4.x `archive`
/// into `platform.dill`, and platform libraries shadow pub resolution — see
/// `scene_model.dart`. The container itself needs nothing from `archive`
/// except gzip inflation, which `dart:io`'s [gzip] codec provides.
///
/// The format (little-endian, chunks 8-byte aligned):
///
/// ```text
/// Header (16 bytes): "FSCB" | u32 version | u32 totalByteLength | u32 zero
/// Chunks: u32 dataByteLength | 4-byte type | data | zero padding
///   "JSON" — the canonical .fscene manifest (fed to readFscene)
///   "BLOB" — [u32 idByteLength][id token][payload bytes]
///   "GZBL" — same payload framing, gzip-compressed
/// ```
///
/// Semantics match upstream's reader: version newer than
/// [kFscenebReaderVersion] is rejected, unrecognized chunk types are skipped,
/// and embedded bytes land on each payload's [PayloadSpec.bytes].
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:scene/src/id.dart';
import 'package:scene/src/json/fscene_json.dart';
import 'package:scene/src/scene_document.dart';

/// The newest `.fsceneb` container version this reader accepts.
const int kFscenebReaderVersion = 2;

const List<int> _kMagic = [0x46, 0x53, 0x43, 0x42]; // "FSCB"
const int _kHeaderBytes = 16;
const int _kAlignment = 8;

/// Thrown when a `.fsceneb` container is malformed.
class FscenebFormatException implements Exception {
  /// Creates a container-format exception with the given [message].
  const FscenebFormatException(this.message);

  /// What is wrong with the container.
  final String message;

  @override
  String toString() => 'FscenebFormatException: $message';
}

/// Parses a `.fsceneb` container from [bytes] into a [SceneDocument] with each
/// embedded payload's `bytes` attached.
///
/// Equivalent to upstream's `readFsceneb`; kept dependency-free so it compiles
/// under DartNative's patched SDK.
SceneDocument readFsceneb(Uint8List bytes) {
  if (bytes.length < _kHeaderBytes) {
    throw const FscenebFormatException('Truncated container (no header)');
  }
  for (var i = 0; i < 4; i++) {
    if (bytes[i] != _kMagic[i]) {
      throw const FscenebFormatException(
        'Not a .fsceneb container (bad magic)',
      );
    }
  }
  final view = ByteData.sublistView(bytes);
  final version = view.getUint32(4, Endian.little);
  if (version > kFscenebReaderVersion) {
    throw FscenebFormatException(
      'Container version $version is newer than supported '
      '$kFscenebReaderVersion',
    );
  }
  final total = view.getUint32(8, Endian.little);
  if (total > bytes.length) {
    throw const FscenebFormatException('Container length exceeds the data');
  }

  String? manifest;
  final blobs = <LocalId, Uint8List>{};
  var offset = _kHeaderBytes;
  while (offset + 8 <= total) {
    final dataLength = view.getUint32(offset, Endian.little);
    final type = ascii.decode(
      Uint8List.sublistView(bytes, offset + 4, offset + 8),
    );
    final dataStart = offset + 8;
    final dataEnd = dataStart + dataLength;
    if (dataEnd > total) {
      throw const FscenebFormatException('Chunk extends past the container');
    }
    final data = Uint8List.sublistView(bytes, dataStart, dataEnd);
    switch (type) {
      case 'JSON':
        manifest = utf8.decode(data);
      case 'BLOB':
        final (id, payload) = _decodeBlob(data);
        blobs[id] = payload;
      case 'GZBL':
        try {
          final decompressed = Uint8List.fromList(gzip.decode(data));
          final (id, payload) = _decodeBlob(decompressed);
          blobs[id] = payload;
        } catch (error) {
          throw FscenebFormatException('Invalid gzip payload chunk ($error)');
        }
      default:
        break; // Skip unrecognized chunk types.
    }
    final padded = dataLength + ((-dataLength) & (_kAlignment - 1));
    offset = dataStart + padded;
  }

  if (manifest == null) {
    throw const FscenebFormatException('Container has no JSON manifest chunk');
  }
  final document = readFscene(manifest);
  blobs.forEach((id, payload) {
    document.payload(id)?.bytes = payload;
  });
  return document;
}

(LocalId, Uint8List) _decodeBlob(Uint8List data) {
  if (data.length < 4) {
    throw const FscenebFormatException('Truncated payload chunk');
  }
  final idLength = ByteData.sublistView(data).getUint32(0, Endian.little);
  final tokenEnd = 4 + idLength;
  if (tokenEnd > data.length) {
    throw const FscenebFormatException('Payload chunk id runs past its data');
  }
  final token = ascii.decode(Uint8List.sublistView(data, 4, tokenEnd));
  // Copy so the payload does not retain a view onto the whole container buffer.
  final payload = Uint8List.fromList(Uint8List.sublistView(data, tokenEnd));
  return (LocalId.parse(token), payload);
}
