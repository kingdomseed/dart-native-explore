/// The `d3:instances` component — one node, one instanced draw, N
/// copies of a mesh with per-instance transforms and attributes (W26).
///
/// The spec carries the repeated geometry (an upstream geometry
/// resource ref or an inline `d3:procMesh`-style `shape` + params), a
/// material ref, the per-instance transform list (inline or a
/// `matrices` payload chunk), and named per-instance attribute vectors
/// (inline lists or `floats`/`bytes` payload chunks). Both platforms
/// bake the instances into a single mesh — one node, one renderable,
/// one draw — with per-instance transforms applied to the vertex
/// copies and the `color` attribute stamped into the COLOR stream
/// (SceneKit has no instanced draw on `SCNGeometry`; Filament 1.71.6's
/// Java binding exposes `Builder.instances(int)` but not the
/// `InstanceBuffer` overload that carries per-instance data, so the
/// baked path is the portable contract). `billboard: true` swaps the
/// instanced mesh for camera-facing quads re-faced per frame.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import '../scene_model.dart';
import 'mesh_data.dart';
import 'proc.dart';

/// Per-instance attribute data: an inline vector list or a payload
/// chunk (`floats`/`bytes` encoding — four floats per instance).
final class D3InstanceAttribute {
  /// Creates an attribute from inline values.
  const D3InstanceAttribute.inline(List<Vector4> this.values) : payload = null;

  /// Creates an attribute referencing [payload] — a `floats` or
  /// `bytes` chunk with `count * 4` floats (or bytes normalized by the
  /// native decoder for `bytes`).
  const D3InstanceAttribute.payload(LocalId this.payload) : values = null;

  /// Inline `vec4` values, one per instance.
  final List<Vector4>? values;

  /// The payload id holding packed per-instance values.
  final LocalId? payload;

  /// The wire encoding.
  PropertyValue toPropertyValue() {
    final p = payload;
    if (p != null) return ResourceRefValue(p);
    return ListValue([for (final v in values!) Vec4Value(v)]);
  }
}

/// Per-instance transform data: inline `Matrix4` list or a `matrices`
/// payload chunk.
final class D3InstanceTransforms {
  /// Creates transforms from inline matrices (column-major storage
  /// order on the wire).
  const D3InstanceTransforms.inline(List<Matrix4> this.matrices)
    : payload = null;

  /// Creates transforms referencing a `matrices` payload chunk —
  /// `count` packed column-major 4x4 float32 matrices.
  const D3InstanceTransforms.payload(LocalId this.payload) : matrices = null;

  /// Inline instance local transforms (doc space; natives mirror).
  final List<Matrix4>? matrices;

  /// The `matrices` payload id.
  final LocalId? payload;

  /// The wire encoding.
  PropertyValue toPropertyValue() {
    final p = payload;
    if (p != null) return ResourceRefValue(p);
    return ListValue([for (final m in matrices!) Matrix4Value(m)]);
  }
}

/// The `d3:instances` component value.
///
/// Exactly one of [geometry]/[proc] supplies the repeated mesh: a
/// geometry resource ref (payload-backed or upstream procedural) or an
/// inline [D3Proc]. [transforms] is required. [attributes] maps a
/// name — `color`, `attr1`, `attr2`, `attr3` — to per-instance vec4
/// data; `color` is the one with a defined renderer contract today
/// (it stamps the COLOR stream, multiplying the material's base color
/// on both platforms); `attr1`–`attr3` are carried on the wire for
/// future material hooks but natives currently read only `color`.
/// [billboard] realizes each instance as a camera-facing quad sized
/// [size] (the transform's translation is the quad center).
final class D3InstancesSpec {
  /// Creates an instancing spec.
  const D3InstancesSpec({
    required this.transforms,
    this.geometry,
    this.proc,
    this.material,
    this.attributes = const {},
    this.billboard = false,
    this.size,
    this.rotation = 0.0,
    this.doubleSided = false,
  });

  /// The instanced geometry resource, or null when [proc] is inline.
  final LocalId? geometry;

  /// The inline procedural spec, or null when [geometry] is a ref.
  final D3Proc? proc;

  /// The material resource ref (null → the platform default material).
  final LocalId? material;

  /// Per-instance local transforms.
  final D3InstanceTransforms transforms;

  /// Named per-instance vec4 attributes — `color` is applied today;
  /// `attr1`…`attr3` are wire-carried but unread by the natives.
  final Map<String, D3InstanceAttribute> attributes;

  /// Whether instances realize as camera-facing quads.
  final bool billboard;

  /// Billboard quad size (world units) — billboard mode only.
  final Vector2? size;

  /// In-plane billboard rotation (radians).
  final double rotation;

  /// Whether the instanced draw renders both faces.
  final bool doubleSided;

  /// The number of instances.
  int get count {
    final m = transforms.matrices;
    if (m != null) return m.length;
    return -1; // payload-driven — the native decoder reads the chunk
  }

  /// The component spec.
  ComponentSpec toComponent() {
    assert(
      (geometry == null) != (proc == null),
      'd3:instances needs exactly one of geometry/proc',
    );
    return ComponentSpec(
      kD3InstancesType,
      properties: {
        if (geometry != null) 'geometry': ResourceRefValue(geometry!),
        if (proc != null) 'shape': StringValue(proc!.shape),
        if (proc != null) ...proc!.props,
        if (material != null) 'material': ResourceRefValue(material!),
        'transforms': transforms.toPropertyValue(),
        if (attributes.isNotEmpty)
          'attributes': MapValue({
            for (final e in attributes.entries)
              e.key: e.value.toPropertyValue(),
          }),
        if (billboard) 'billboard': const BoolValue(true),
        if (billboard && size != null) 'size': Vec2Value(size!),
        if (rotation != 0) 'rotation': DoubleValue(rotation),
        if (doubleSided) 'doubleSided': const BoolValue(true),
      },
    );
  }

  /// The component's local-space bounds: the geometry bounds unioned
  /// over the instance transforms — inline, or decoded from
  /// [transformsPayload] when the transforms are a payload ref (pass
  /// the document's `PayloadSpec`; without bytes the untransformed
  /// geometry bounds come back). Only the first [kD3MaxBakedInstances]
  /// count, as the natives truncate the tail. Billboard mode ignores
  /// the geometry (natives draw quads only) and pads each instance
  /// center by the quad's half-diagonal.
  BoundsSpec? bounds(
    GeometryResource? geometryResource, {
    PayloadSpec? transformsPayload,
  }) {
    final geomBounds = billboard
        ? null
        : proc?.bounds ??
              geometryResource?.bounds ??
              _resourceProceduralBounds(geometryResource?.procedural);
    final pad = billboard
        ? d3BillboardRadius(size?.x ?? 1.0, size?.y ?? 1.0)
        : 0.0;
    final local = geomBounds;
    if (local == null && pad == 0) return null;
    final min = Vector3.all(double.infinity);
    final max = Vector3.all(-double.infinity);
    var mats = transforms.matrices;
    final payloadBytes = transformsPayload?.bytes;
    if (mats == null && payloadBytes != null) {
      mats = d3DecodeMatrices(payloadBytes);
    }
    if (mats == null || mats.isEmpty) {
      return local ??
          (pad > 0
              ? BoundsSpec(min: Vector3.all(-pad), max: Vector3.all(pad))
              : null);
    }
    if (mats.length > kD3MaxBakedInstances) {
      mats = mats.sublist(0, kD3MaxBakedInstances);
    }
    final corner = Vector3.zero();
    for (final m in mats) {
      if (local != null) {
        for (var i = 0; i < 8; i++) {
          corner.setValues(
            i & 1 == 0 ? local.min.x : local.max.x,
            i & 2 == 0 ? local.min.y : local.max.y,
            i & 4 == 0 ? local.min.z : local.max.z,
          );
          m.transform3(corner);
          if (corner.x < min.x) min.x = corner.x;
          if (corner.y < min.y) min.y = corner.y;
          if (corner.z < min.z) min.z = corner.z;
          if (corner.x > max.x) max.x = corner.x;
          if (corner.y > max.y) max.y = corner.y;
          if (corner.z > max.z) max.z = corner.z;
        }
      }
      if (pad > 0) {
        final c = m.getTranslation();
        if (c.x - pad < min.x) min.x = c.x - pad;
        if (c.y - pad < min.y) min.y = c.y - pad;
        if (c.z - pad < min.z) min.z = c.z - pad;
        if (c.x + pad > max.x) max.x = c.x + pad;
        if (c.y + pad > max.y) max.y = c.y + pad;
        if (c.z + pad > max.z) max.z = c.z + pad;
      }
    }
    if (!min.x.isFinite) return local;
    return BoundsSpec(min: min, max: max);
  }
}

/// Packs matrices as a `matrices` payload — column-major float32, the
/// encoding the native `matrices` decoders read.
PayloadSpec d3MatricesPayload(LocalId id, List<Matrix4> matrices) {
  final data = Float32List(matrices.length * 16);
  for (var i = 0; i < matrices.length; i++) {
    data.setRange(i * 16, i * 16 + 16, matrices[i].storage);
  }
  return PayloadSpec(
    id,
    encoding: PayloadEncoding.matrices,
    length: data.lengthInBytes,
    bytes: data.buffer.asUint8List(),
  );
}

/// Decodes a `matrices` payload chunk — packed column-major float32
/// 4×4s, little-endian — into matrices. A trailing partial matrix is
/// ignored (the natives drop it too). At most [maxCount] matrices are
/// decoded (default [kD3MaxBakedInstances], the count the natives
/// draw), so an oversized or hostile payload costs no more than the
/// cap — the tail is never allocated.
List<Matrix4> d3DecodeMatrices(
  Uint8List bytes, {
  int maxCount = kD3MaxBakedInstances,
}) {
  final data = ByteData.sublistView(bytes);
  final count = math.min(bytes.lengthInBytes ~/ 64, math.max(0, maxCount));
  return [
    for (var i = 0; i < count; i++)
      Matrix4.fromList([
        for (var k = 0; k < 16; k++)
          data.getFloat32(i * 64 + k * 4, Endian.little),
      ]),
  ];
}

/// The CPU reference for the native `d3:instances` bake: [base] copied
/// once per transform into one mesh, with [colors] (one rgba per
/// instance, multiplied into any base color) stamped on each copy.
///
/// The instance count is capped by [d3BakedInstanceCount]
/// ([kD3MaxBakedInstances] and the [kD3MaxBakedVertices] budget) and
/// the tail is truncated. Normals use each matrix's normal matrix
/// (inverse transpose — translation never touches them), and a
/// reflecting transform (negative determinant) reverses its copy's
/// triangles so mirrored instances keep outward winding. The natives
/// mirror this contract (see `docs/triage/dart.md`).
D3MeshData d3BakeInstances(
  D3MeshData base,
  List<Matrix4> transforms, {
  List<Vector4>? colors,
}) {
  final count = d3BakedInstanceCount(transforms.length, base.vertexCount);
  final out = D3MeshBuilder();
  final hasBaseColor = base.colors.length == base.vertexCount * 4;
  for (var k = 0; k < count; k++) {
    final copy = D3MeshBuilder();
    final tint = colors != null && k < colors.length ? colors[k] : null;
    for (var i = 0; i < base.vertexCount; i++) {
      List<double>? color;
      if (tint != null || hasBaseColor) {
        final c = hasBaseColor
            ? [for (var j = 0; j < 4; j++) base.colors[i * 4 + j]]
            : [1.0, 1.0, 1.0, 1.0];
        color = tint == null
            ? c
            : [c[0] * tint.x, c[1] * tint.y, c[2] * tint.z, c[3] * tint.w];
      }
      copy.emit(
        Vector3(
          base.positions[i * 3],
          base.positions[i * 3 + 1],
          base.positions[i * 3 + 2],
        ),
        n: Vector3(
          base.normals[i * 3],
          base.normals[i * 3 + 1],
          base.normals[i * 3 + 2],
        ),
        uv: Vector2(base.uvs[i * 2], base.uvs[i * 2 + 1]),
        color: color,
      );
    }
    for (var t = 0; t + 2 < base.indices.length; t += 3) {
      copy.tri(base.indices[t], base.indices[t + 1], base.indices[t + 2]);
    }
    copy.transform(transforms[k]);
    out.addMesh(copy.build());
  }
  return out.build();
}

/// Packs vec4 lists as a `floats` payload — four float32 per entry.
PayloadSpec d3FloatsPayload(LocalId id, List<Vector4> vectors) {
  final data = Float32List(vectors.length * 4);
  for (var i = 0; i < vectors.length; i++) {
    data[i * 4] = vectors[i].x;
    data[i * 4 + 1] = vectors[i].y;
    data[i * 4 + 2] = vectors[i].z;
    data[i * 4 + 3] = vectors[i].w;
  }
  return PayloadSpec(
    id,
    encoding: PayloadEncoding.floats,
    length: data.lengthInBytes,
    bytes: data.buffer.asUint8List(),
  );
}

// Mirrors world_bounds' upstream-procedural bounds — kept private so
// the instances component resolves `geometry` refs without a circular
// import.
BoundsSpec? _resourceProceduralBounds(ProceduralGeometry? spec) {
  return switch (spec) {
    CuboidGeometrySpec(:final extents) => BoundsSpec(
      min: -extents / 2,
      max: extents / 2,
    ),
    PlaneGeometrySpec(:final width, :final depth) => BoundsSpec(
      min: Vector3(-width / 2, 0, -depth / 2),
      max: Vector3(width / 2, 0, depth / 2),
    ),
    SphereGeometrySpec(:final radius) => _cubeBounds(radius),
    IcosphereGeometrySpec(:final radius) => _cubeBounds(radius),
    TorusGeometrySpec(:final radius, :final tubeRadius) => BoundsSpec(
      min: Vector3(-(radius + tubeRadius), -tubeRadius, -(radius + tubeRadius)),
      max: Vector3(radius + tubeRadius, tubeRadius, radius + tubeRadius),
    ),
    _ => null,
  };
}

BoundsSpec _cubeBounds(double r) =>
    BoundsSpec(min: Vector3.all(-r), max: Vector3.all(r));
