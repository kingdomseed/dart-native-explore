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

import 'scene_model.dart';

/// The newest `.fsceneb` container version this reader accepts.
const int kFscenebReaderVersion = 2;

/// glTF photometric intensity → dart3d's SceneKit-scale `intensity`
/// multiplier (W21 light-units contract).
///
/// dart3d's wire `intensity` is SceneKit-scale: `SCNLight.intensity`
/// is unitless with a platform default of 1000, and the authored
/// scenes run directional keys at 1300–2400 (`showcase_loader.dart`,
/// `imported_scene.dart`, `dice_table_scene.dart`). glTF's
/// `KHR_lights_punctual` directional intensity is lux, and shipped
/// assets commonly use ~1–3. `1000` anchors a unit glTF directional to
/// SceneKit's own default intensity and lands the common 1–3 lux band
/// at 1000–3000 — inside the authored range and the plausible
/// 500–1400 mapping window.
///
/// Point and spot lights recover candela through the same constant —
/// upstream's `n` normalization is type-agnostic, so the scale is too.
/// The derivation lives in `docs/android-parity-spec.md` §Light units.
const double kGltfToSceneKitLightScale = 1000.0;

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
  normalizeLightIntensity(document);
  return document;
}

/// The punctual-light component types upstream's glTF importer emits —
/// `KHR_lights_punctual` has no area-light kind, so `rectAreaLight` is
/// deliberately absent: an `n` on it wouldn't carry the photometric
/// convention this translation inverts.
const Set<String> _kPunctualLightTypes = {
  'directionalLight',
  'pointLight',
  'spotLight',
};

/// Translates upstream's normalized light field `n` into dart3d's
/// `intensity` convention, in place (W21).
///
/// Upstream's importer (`fscene_emitter.dart` / `gltf_light_units.dart`)
/// bakes glTF photometric intensity down to a radiometric multiplier:
/// `n = photometric / (683 · luminance(color))`, where 683 lm/W is the
/// peak photopic luminous efficacy and the luminance division keeps
/// `color · n` at the authored luminance. dart3d's wire `intensity` is
/// SceneKit-scale instead, so decode recovers the photometric value and
/// rescales:
///
/// ```text
/// intensity = n · 683 · luminance(color) · kGltfToSceneKitLightScale
/// ```
///
/// Rules: only punctual light components translate; an authored
/// `intensity` always wins over `n` (both present → `n` is left
/// unread); `color` may be a `Vec3Value` (upstream's emit) or a
/// `ColorValue` (dart3d-authored) and defaults to white (luminance 1);
/// `n` may be `DoubleValue` or `IntValue`. The `n` property is left in
/// place — re-encoding keeps it, and a second decode is a no-op since
/// `intensity` then exists (idempotent).
///
/// This is dart3d's decode boundary for the light-units contract — the
/// natives read only `intensity`. Called by [readFsceneb]; the
/// `.fscene` text path applies it at its own decode site
/// (`showcase_loader.dart`).
void normalizeLightIntensity(SceneDocument document) {
  for (final node in document.nodes.values) {
    for (var i = 0; i < node.components.length; i++) {
      final component = node.components[i];
      if (!_kPunctualLightTypes.contains(component.type)) continue;
      final props = component.properties;
      if (props.containsKey('intensity')) continue;
      final n = switch (props['n']) {
        DoubleValue(:final value) => value,
        IntValue(:final value) => value.toDouble(),
        _ => null,
      };
      if (n == null) continue;
      final luminance = _lightColorLuminance(props['color']);
      // Rebuild rather than mutate — a caller-authored properties map
      // may be unmodifiable.
      node.components[i] = ComponentSpec(
        component.type,
        properties: {
          ...props,
          'intensity': DoubleValue(
            n * 683.0 * luminance * kGltfToSceneKitLightScale,
          ),
        },
      );
    }
  }
}

/// Rec. 709 luma of a light's `color` property — the same weights
/// upstream's `gltfLightIntensity` divides by. Absent color reads as
/// white (luminance 1); a non-positive luminance clamps to 0 rather
/// than recovering a meaningless negative photometric value.
double _lightColorLuminance(PropertyValue? color) {
  final (r, g, b) = switch (color) {
    Vec3Value(:final value) => (value.x, value.y, value.z),
    ColorValue(:final r, :final g, :final b) => (r, g, b),
    _ => (1.0, 1.0, 1.0),
  };
  final luminance = r * 0.2126 + g * 0.7152 + b * 0.0722;
  return luminance < 0.0 ? 0.0 : luminance;
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
