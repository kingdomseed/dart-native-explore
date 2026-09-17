import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

/// Authors upstream-`package:scene`-layout vertex buffers in Dart.
///
/// The wire shapes are pinned by `docs/payload-geometry-spec.md`: the
/// `unskinned_uv1_tangent` interleave packs
/// `pos3 | normal3 | uv0-2 | uv1-2 | color4 | tangent4` (18 f32, 72 B
/// per vertex, little-endian). Channels left null get upstream's
/// neutral fill — normal (0,0,1), uv (0,0), color (1,1,1,1), tangent
/// (1,0,0,1) — and uv1 is always zero-filled. `skinned_uv1_tangent`
/// appends `joints4 | weights4` (26 f32, 104 B).
abstract final class VertexPack {
  /// Bytes per vertex in the `unskinned_uv1_tangent` interleave.
  static const int unskinnedUv1TangentStride = 72;

  /// Bytes per vertex in the `skinned_uv1_tangent` interleave.
  static const int skinnedUv1TangentStride = 104;

  /// Packs vertex channels into the `unskinned_uv1_tangent` interleave.
  ///
  /// [positions] fixes the vertex count; every non-null channel must
  /// have the same length. [tangents] is a vec4 per vertex — xyz
  /// tangent plus `w` bitangent handedness (±1), not the `p3t4`
  /// quaternion.
  static Uint8List unskinned({
    required List<Vector3> positions,
    List<Vector3>? normals,
    List<Vector2>? uvs,
    List<Vector4>? colors,
    List<Vector4>? tangents,
  }) {
    final n = positions.length;
    void check(String name, List<Object>? channel) {
      if (channel != null && channel.length != n) {
        throw ArgumentError.value(
          channel.length,
          name,
          'channel length must match positions ($n)',
        );
      }
    }

    check('normals', normals);
    check('uvs', uvs);
    check('colors', colors);
    check('tangents', tangents);

    final out = ByteData(n * unskinnedUv1TangentStride);
    var off = 0;
    for (var i = 0; i < n; i++) {
      final p = positions[i];
      final nrm = normals?[i];
      final uv = uvs?[i];
      final c = colors?[i];
      final t = tangents?[i];
      for (final v in <double>[
        p.x, p.y, p.z, // pos3
        nrm?.x ?? 0.0, nrm?.y ?? 0.0, nrm?.z ?? 1.0, // normal3
        uv?.x ?? 0.0, uv?.y ?? 0.0, // uv0-2
        0.0, 0.0, // uv1-2 — zero-filled
        c?.x ?? 1.0, c?.y ?? 1.0, c?.z ?? 1.0, c?.w ?? 1.0, // color4
        t?.x ?? 1.0, t?.y ?? 0.0, t?.z ?? 0.0, t?.w ?? 1.0, // tangent4
      ]) {
        out.setFloat32(off, v, Endian.little);
        off += 4;
      }
    }
    return out.buffer.asUint8List();
  }

  /// Packs vertex channels into the `skinned_uv1_tangent` interleave —
  /// the unskinned 18 floats, then `joints4` and `weights4` (26 f32,
  /// 104 B per vertex).
  ///
  /// [positions] fixes the vertex count; every other channel must have
  /// the same length. [joints] carries the skin's joint indices
  /// float-encoded one per component (the wire format is all-f32 —
  /// natives decode to int); [weights] carries the blend weights.
  /// Remaining channels fall back to [unskinned]'s neutral fill.
  static Uint8List skinned({
    required List<Vector3> positions,
    required List<Vector4> joints,
    required List<Vector4> weights,
    List<Vector3>? normals,
    List<Vector2>? uvs,
    List<Vector4>? colors,
    List<Vector4>? tangents,
  }) {
    final n = positions.length;
    void check(String name, List<Object>? channel) {
      if (channel != null && channel.length != n) {
        throw ArgumentError.value(
          channel.length,
          name,
          'channel length must match positions ($n)',
        );
      }
    }

    check('normals', normals);
    check('uvs', uvs);
    check('colors', colors);
    check('tangents', tangents);
    check('joints', joints);
    check('weights', weights);

    final out = ByteData(n * skinnedUv1TangentStride);
    var off = 0;
    for (var i = 0; i < n; i++) {
      final p = positions[i];
      final nrm = normals?[i];
      final uv = uvs?[i];
      final c = colors?[i];
      final t = tangents?[i];
      final j = joints[i];
      final w = weights[i];
      for (final v in <double>[
        p.x, p.y, p.z, // pos3
        nrm?.x ?? 0.0, nrm?.y ?? 0.0, nrm?.z ?? 1.0, // normal3
        uv?.x ?? 0.0, uv?.y ?? 0.0, // uv0-2
        0.0, 0.0, // uv1-2 — zero-filled
        c?.x ?? 1.0, c?.y ?? 1.0, c?.z ?? 1.0, c?.w ?? 1.0, // color4
        t?.x ?? 1.0, t?.y ?? 0.0, t?.z ?? 0.0, t?.w ?? 1.0, // tangent4
        j.x, j.y, j.z, j.w, // joints4
        w.x, w.y, w.z, w.w, // weights4
      ]) {
        out.setFloat32(off, v, Endian.little);
        off += 4;
      }
    }
    return out.buffer.asUint8List();
  }
}
