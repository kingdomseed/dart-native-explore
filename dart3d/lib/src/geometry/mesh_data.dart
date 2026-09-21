/// CPU-side mesh containers for the dart3d geometry generators (W26).
///
/// Upstream `ProceduralGeometry` is a sealed five-type hierarchy, so the
/// expanded dart3d shape vocabulary carries its own spec types
/// (`proc.dart`). Their generators emit [D3MeshData] — plain attribute
/// arrays plus a precomputed bounds — which tests inspect directly and
/// which mirrors what the native decoders build on both platforms.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import '../scene_model.dart';

/// Vertex attribute arrays plus bounds for one drawable mesh.
///
/// Attributes are flat (non-interleaved) float arrays: `positions`,
/// `normals`, and `uvs` (two components), `colors` (four). `indices`
/// may be empty for non-indexed geometry. `lineTopology` marks a
/// polyline source so tests can assert topology expectations.
final class D3MeshData {
  /// Creates a mesh record; [bounds] is computed from [positions] when
  /// not supplied.
  D3MeshData({
    required this.positions,
    required this.normals,
    required this.uvs,
    required this.colors,
    required this.indices,
    BoundsSpec? bounds,
    this.lineTopology = false,
  }) : bounds = bounds ?? computeD3Bounds(positions);

  /// xyz positions, three floats per vertex.
  final Float32List positions;

  /// xyz normals, three floats per vertex.
  final Float32List normals;

  /// uv texture coordinates, two floats per vertex.
  final Float32List uvs;

  /// rgba vertex colors, four floats per vertex.
  final Float32List colors;

  /// Triangle indices (empty when non-indexed).
  final Uint32List indices;

  /// Local-space axis-aligned bounds.
  final BoundsSpec bounds;

  /// Whether the indices describe `line` primitives rather than
  /// triangles (native lineSegments without width).
  final bool lineTopology;

  /// Vertex count (positions.length ~/ 3).
  int get vertexCount => positions.length ~/ 3;

  /// Triangle count for indexed triangle topology.
  int get triangleCount => indices.length ~/ 3;
}

/// Growable builder for [D3MeshData] — the shared accumulate/finish
/// shape the generators use.
final class D3MeshBuilder {
  final List<double> _positions = [];
  final List<double> _normals = [];
  final List<double> _uvs = [];
  final List<double> _colors = [];
  final List<int> _indices = [];
  var _hasColor = false;

  /// Vertices added so far.
  int get vertexCount => _positions.length ~/ 3;

  /// Appends a vertex. [uv] defaults to `(0, 0)`; a non-null [color]
  /// fills the color stream (missing colors emit opaque white).
  int emit(Vector3 p, {Vector3? n, Vector2? uv, List<double>? color}) {
    final index = vertexCount;
    _positions.addAll([p.x, p.y, p.z]);
    if (n == null) {
      _normals.addAll([0.0, 0.0, 1.0]);
    } else {
      _normals.addAll([n.x, n.y, n.z]);
    }
    final t = uv ?? Vector2.zero();
    _uvs.addAll([t.x, t.y]);
    if (color != null) {
      _hasColor = true;
      _colors.addAll(color);
    } else {
      _colors.addAll(const [1.0, 1.0, 1.0, 1.0]);
    }
    return index;
  }

  /// Appends a triangle.
  void tri(int a, int b, int c) => _indices.addAll([a, b, c]);

  /// Appends a quad as two triangles, `(a,b,c)` and `(b,d,c)`.
  void quad(int a, int b, int c, int d) {
    tri(a, b, c);
    tri(b, d, c);
  }

  /// Recomputes flat normals from the triangle winding — for the
  /// expansion generators whose vertex normals don't exist
  /// meaningfully (lines face the camera instead).
  void computeFlatNormals() {
    _normals
      ..clear()
      ..addAll(List<double>.filled(_positions.length, 0.0));
    final a = Vector3.zero();
    final b = Vector3.zero();
    final c = Vector3.zero();
    final e1 = Vector3.zero();
    final e2 = Vector3.zero();
    for (var t = 0; t < _indices.length; t += 3) {
      final i0 = _indices[t];
      final i1 = _indices[t + 1];
      final i2 = _indices[t + 2];
      a.setValues(
        _positions[i0 * 3],
        _positions[i0 * 3 + 1],
        _positions[i0 * 3 + 2],
      );
      b.setValues(
        _positions[i1 * 3],
        _positions[i1 * 3 + 1],
        _positions[i1 * 3 + 2],
      );
      c.setValues(
        _positions[i2 * 3],
        _positions[i2 * 3 + 1],
        _positions[i2 * 3 + 2],
      );
      e1
        ..setFrom(b)
        ..sub(a);
      e2
        ..setFrom(c)
        ..sub(a);
      final n = e1.cross(e2);
      if (n.length2 < 1e-20) continue;
      n.normalize();
      for (final i in [i0, i1, i2]) {
        _normals[i * 3] += n.x;
        _normals[i * 3 + 1] += n.y;
        _normals[i * 3 + 2] += n.z;
      }
    }
    for (var i = 0; i < _normals.length; i += 3) {
      final l = math.sqrt(
        _normals[i] * _normals[i] +
            _normals[i + 1] * _normals[i + 1] +
            _normals[i + 2] * _normals[i + 2],
      );
      if (l > 1e-12) {
        _normals[i] /= l;
        _normals[i + 1] /= l;
        _normals[i + 2] /= l;
      } else {
        _normals[i + 2] = 1.0;
      }
    }
  }

  /// Applies [m] to positions and its upper-3x3 to normals (rebuilt
  /// orthonormal basis assumed — callers pass rigid or uniform
  /// transforms).
  void transform(Matrix4 m) {
    final v = Vector3.zero();
    final n = Vector3.zero();
    for (var i = 0; i < _positions.length; i += 3) {
      v.setValues(_positions[i], _positions[i + 1], _positions[i + 2]);
      m.transform3(v);
      _positions[i] = v.x;
      _positions[i + 1] = v.y;
      _positions[i + 2] = v.z;
      n.setValues(_normals[i], _normals[i + 1], _normals[i + 2]);
      m.transform3(n);
      if (n.length2 > 1e-20) n.normalize();
      _normals[i] = n.x;
      _normals[i + 1] = n.y;
      _normals[i + 2] = n.z;
    }
  }

  /// Merges [other] (already translated into place by the caller) into
  /// this builder.
  void addMesh(D3MeshData other) {
    final base = vertexCount;
    _positions.addAll(other.positions);
    _normals.addAll(other.normals);
    _uvs.addAll(other.uvs);
    _colors.addAll(other.colors);
    _hasColor = _hasColor || other.colors.isNotEmpty;
    _indices.addAll(other.indices.map((i) => i + base));
  }

  /// Builds the mesh. [lineTopology] marks the indices as line pairs.
  D3MeshData build({bool lineTopology = false}) => D3MeshData(
    positions: Float32List.fromList(_positions),
    normals: Float32List.fromList(_normals),
    uvs: Float32List.fromList(_uvs),
    colors: _hasColor ? Float32List.fromList(_colors) : Float32List(0),
    indices: Uint32List.fromList(_indices),
    lineTopology: lineTopology,
  );
}

/// Min/max corners over a flat xyz position array.
BoundsSpec computeD3Bounds(Float32List positions) {
  final min = Vector3.all(double.infinity);
  final max = Vector3.all(-double.infinity);
  for (var i = 0; i + 2 < positions.length; i += 3) {
    if (positions[i] < min.x) min.x = positions[i];
    if (positions[i] > max.x) max.x = positions[i];
    if (positions[i + 1] < min.y) min.y = positions[i + 1];
    if (positions[i + 1] > max.y) max.y = positions[i + 1];
    if (positions[i + 2] < min.z) min.z = positions[i + 2];
    if (positions[i + 2] > max.z) max.z = positions[i + 2];
  }
  if (!min.x.isFinite) {
    min.setZero();
    max.setZero();
  }
  return BoundsSpec(min: min, max: max);
}

/// Packs the tangent frame (tangent `t`, normal `n`, handedness `w`)
/// into the Filament/SceneKit quaternion encoding — the same math
/// `MeshFactory.kt` uses for its `TANGENTS` attribute.
Quaternion d3TangentQuat(Vector3 n, Vector3 t, double w) {
  final bitangent = n.cross(t)..scale(w);
  final m = Matrix3.columns(t, bitangent, n);
  final q = Quaternion.fromRotation(m);
  if (q.w < 0) q.scale(-1);
  return q.normalized();
}
