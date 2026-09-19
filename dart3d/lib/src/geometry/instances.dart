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

import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import '../scene_model.dart';
import 'proc.dart';

/// Per-instance attribute data: an inline vector list or a payload
/// chunk (`floats`/`bytes` encoding — four floats per instance).
final class D3InstanceAttribute {
  /// Creates an attribute from inline values.
  const D3InstanceAttribute.inline(this.values) : payload = null;

  /// Creates an attribute referencing [payload] — a `floats` or
  /// `bytes` chunk with `count * 4` floats (or bytes normalized by the
  /// native decoder for `bytes`).
  const D3InstanceAttribute.payload(this.payload) : values = null;

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
  const D3InstanceTransforms.inline(this.matrices) : payload = null;

  /// Creates transforms referencing a `matrices` payload chunk —
  /// `count` packed column-major 4x4 float32 matrices.
  const D3InstanceTransforms.payload(this.payload) : matrices = null;

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
  /// over every inline instance transform (payload transforms expand
  /// as points — payload matrices aren't readable here). Billboard
  /// mode pads by the quad size.
  BoundsSpec? bounds(GeometryResource? geometryResource) {
    final geomBounds =
        proc?.bounds ??
        geometryResource?.bounds ??
        _resourceProceduralBounds(geometryResource?.procedural);
    final pad = billboard ? (size?.x ?? 1.0) : 0.0;
    final local = geomBounds;
    if (local == null && pad == 0) return null;
    final min = Vector3.all(double.infinity);
    final max = Vector3.all(-double.infinity);
    final mats = transforms.matrices;
    if (mats == null || mats.isEmpty) return local;
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
