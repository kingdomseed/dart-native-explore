/// Render-geometry raycasting over `.fscene` [SceneDocument]s (U1 / E2 / D8).
///
/// Mirrors upstream `flutter_scene` `raycast` / `raycastAll` over dart3d's
/// document-shaped scene graph, using per-mesh [TriangleMeshBvh] and an
/// instance-level [Bvh] for `d3:instances` draws.
///
/// Supported renderables:
/// - Standard `mesh` components (both single-primitive `geometry` and
///   multi-primitive `primitives[]`), backed by either `procedural`
///   ([ProceduralGeometry]), W26 `d3ExtensionResources` procedural shapes, or
///   payload chunks (`vertices` / `indices` across all 7 vertex layouts in
///   `docs/payload-geometry-spec.md`).
/// - Skinned meshes (`node.skin != null` with `skinned_uv1_tangent` or
///   `skinned` layouts): evaluates linear blend skinning (LBS) against the
///   joint nodes' current world transforms in the document when joint weights
///   and inverse-bind matrices are present, falling back to bind-pose vertices.
/// - `d3:procMesh` components across all 14 procedural shapes in `proc.dart`.
/// - `d3:instances` components (both inline `transforms` and `matrices`
///   payload chunks, with `geometry` resource ref, inline `shape`, or
///   `billboard`), reporting the hit instance's index on
///   [SceneRaycastHit.instanceIndex].
///
/// Pure Dart (no `dartnative` import) so it runs under `dn test`.
library;

import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import 'bvh.dart';
import 'camera.dart';
import 'diff_apply.dart' show d3ExtensionResources;
import 'geometry/instances.dart';
import 'geometry/mesh_data.dart';
import 'geometry/paths.dart';
import 'geometry/proc.dart';
import 'physics.dart' show SceneRaycastHit;
import 'scene_model.dart';
import 'world_bounds.dart' show computeWorldTransforms;

/// Predicate that filters candidate nodes during a render-geometry raycast.
typedef SceneNodePredicate = bool Function(NodeSpec node);

/// Casts [ray] (in `.fscene` world space) against the renderable geometry of
/// [doc] and returns the closest [SceneRaycastHit] within [maxDistance], or
/// `null` on a miss.
///
/// Nodes hidden via `visible: false` (or inside a hidden ancestor subtree) are
/// skipped. Only nodes whose `layers & layerMask != 0` and for which [where]
/// returns `true` (when supplied) are tested.
/// [camera] overrides the document camera for billboards; when omitted, the
/// document camera is used when present.
SceneRaycastHit? raycastDocument(
  SceneDocument doc,
  Ray ray, {
  SceneCamera? camera,
  double maxDistance = double.infinity,
  int layerMask = -1,
  SceneNodePredicate? where,
}) {
  final hits = _raycastDocImpl(
    doc,
    ray,
    camera: camera,
    maxDistance: maxDistance,
    layerMask: layerMask,
    where: where,
    closestOnly: true,
  );
  return hits.isEmpty ? null : hits.first;
}

/// Casts [ray] (in `.fscene` world space) against the renderable geometry of
/// [doc] and returns all [SceneRaycastHit]s within [maxDistance], sorted
/// nearest-first. [camera] overrides the document camera for billboards; when
/// omitted, the document camera is used when present.
List<SceneRaycastHit> raycastDocumentAll(
  SceneDocument doc,
  Ray ray, {
  SceneCamera? camera,
  double maxDistance = double.infinity,
  int layerMask = -1,
  SceneNodePredicate? where,
}) {
  return _raycastDocImpl(
    doc,
    ray,
    camera: camera,
    maxDistance: maxDistance,
    layerMask: layerMask,
    where: where,
    closestOnly: false,
  );
}

// Cache of built TriangleMeshBvhs keyed by D3MeshData / PayloadSpec identity
// so repeated raycasts (e.g. pointer hover at 60-90 Hz) do not rebuild static
// triangle BVHs every frame.
final Expando<TriangleMeshBvh> _procMeshBvhCache =
    Expando<TriangleMeshBvh>('d3ProcMeshBvh');
final Expando<Map<_PayloadBvhCacheKey, _CachedPayloadBvh>> _payloadBvhCache =
    Expando<Map<_PayloadBvhCacheKey, _CachedPayloadBvh>>('d3PayloadBvh');

final class _PayloadBvhCacheKey {
  const _PayloadBvhCacheKey({
    required this.layout,
    required this.indexPayload,
    required this.indexFormat,
    required this.topology,
  });

  final String layout;
  final PayloadSpec? indexPayload;
  final String? indexFormat;
  final String topology;

  @override
  bool operator ==(Object other) =>
      other is _PayloadBvhCacheKey &&
      layout == other.layout &&
      identical(indexPayload, other.indexPayload) &&
      indexFormat == other.indexFormat &&
      topology == other.topology;

  @override
  int get hashCode => Object.hash(
    layout,
    identityHashCode(indexPayload),
    indexFormat,
    topology,
  );
}

final class _CachedPayloadBvh {
  const _CachedPayloadBvh({
    required this.bvh,
    required this.vertexBytes,
    required this.indexBytes,
  });

  final TriangleMeshBvh bvh;
  final Uint8List vertexBytes;
  final Uint8List? indexBytes;
}

bool _samePayloadBytes(Uint8List? a, Uint8List? b) {
  if (a == null || b == null) return a == b;
  if (a.lengthInBytes != b.lengthInBytes) return false;
  for (var i = 0; i < a.lengthInBytes; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<SceneRaycastHit> _raycastDocImpl(
  SceneDocument doc,
  Ray worldRay, {
  required SceneCamera? camera,
  required double maxDistance,
  required int layerMask,
  required SceneNodePredicate? where,
  required bool closestOnly,
}) {
  if (maxDistance <= 0) return const [];
  final rayDirLen = worldRay.direction.length;
  if (rayDirLen <= 1e-12) return const [];
  final unitRay = (rayDirLen - 1.0).abs() < 1e-6
      ? worldRay
      : Ray.originDirection(worldRay.origin, worldRay.direction / rayDirLen);
  final queryCamera = camera ?? SceneCamera.fromDocument(doc);

  // Visible world transforms (hidden subtrees are excluded).
  final visibleWorlds = computeWorldTransforms(doc, includeHidden: false);
  // All world transforms (including non-mesh joint hierarchies) for skinning.
  Map<LocalId, Matrix4>? allWorlds;

  final results = <SceneRaycastHit>[];
  var currentMaxDist = maxDistance;

  for (final node in doc.nodes.values) {
    if (!node.visible) continue;
    final nodeWorld = visibleWorlds[node.id];
    if (nodeWorld == null) continue;
    if ((node.layers & layerMask) == 0) continue;
    if (where != null && !where(node)) continue;

    for (final comp in node.components) {
      switch (comp.type) {
        case 'mesh':
          final primRefs = _meshPrimitiveGeometryIds(comp);
          for (var primIdx = 0; primIdx < primRefs.length; primIdx++) {
            final geoId = primRefs[primIdx];
            final res = doc.resources[geoId];
            TriangleMeshBvh? bvh;
            if (res is GeometryResource) {
              bvh = _resolveGeometryBvh(
                doc,
                res,
                node: node,
                nodeWorld: nodeWorld,
                allWorlds: () => allWorlds ??= computeWorldTransforms(
                  doc,
                  includeHidden: true,
                ),
              );
            } else {
              final extEntry = d3ExtensionResources(doc)[geoId];
              if (extEntry != null) {
                bvh = _resolveExtensionResourceBvh(extEntry);
              }
            }
            if (bvh == null) continue;
            _testBvhWithTransform(
              bvh: bvh,
              worldTransform: nodeWorld,
              unitWorldRay: unitRay,
              nodeId: node.id,
              primitiveIndex: primIdx,
              instanceIndex: null,
              currentMaxDist: currentMaxDist,
              closestOnly: closestOnly,
              outHits: results,
              onTightenMaxDist: (d) => currentMaxDist = d,
            );
          }

        case kD3ProcMeshType:
          final bvh = _resolveD3ProcComponentBvh(comp.properties);
          if (bvh == null) continue;
          final shape = comp.properties['shape'];
          final isBillboard =
              shape is StringValue && shape.value == 'billboard';
          final worldTransform = isBillboard && queryCamera != null
              ? _queryBillboardWorldTransform(
                  nodeWorld: nodeWorld,
                  camera: queryCamera,
                  facing: _billboardFacing(comp.properties),
                  center: Vector3.zero(),
                )
              : nodeWorld;
          if (worldTransform == null) continue;
          _testBvhWithTransform(
            bvh: bvh,
            worldTransform: worldTransform,
            unitWorldRay: unitRay,
            nodeId: node.id,
            primitiveIndex: 0,
            instanceIndex: null,
            currentMaxDist: currentMaxDist,
            closestOnly: closestOnly,
            outHits: results,
            onTightenMaxDist: (d) => currentMaxDist = d,
          );

        case kD3InstancesType:
          _testD3InstancesComponent(
            doc: doc,
            node: node,
            comp: comp,
            nodeWorld: nodeWorld,
            camera: queryCamera,
            unitWorldRay: unitRay,
            currentMaxDist: currentMaxDist,
            closestOnly: closestOnly,
            outHits: results,
            onTightenMaxDist: (d) => currentMaxDist = d,
          );
      }
    }
  }

  if (results.length > 1) {
    results.sort((a, b) => a.distance.compareTo(b.distance));
  }
  if (closestOnly && results.length > 1) {
    return [results.first];
  }
  return results;
}

void _testBvhWithTransform({
  required TriangleMeshBvh bvh,
  required Matrix4 worldTransform,
  required Ray unitWorldRay,
  required LocalId nodeId,
  required int primitiveIndex,
  required int? instanceIndex,
  required double currentMaxDist,
  required bool closestOnly,
  required List<SceneRaycastHit> outHits,
  required void Function(double) onTightenMaxDist,
}) {
  if (bvh.triangleCount == 0) return;

  final invWorld = Matrix4.copy(worldTransform);
  if (invWorld.invert() == 0.0) return;

  final localOrigin = invWorld.transformed3(unitWorldRay.origin.clone());
  final localDir = invWorld.rotated3(unitWorldRay.direction.clone());
  final localDirLen = localDir.length;
  if (localDirLen <= 1e-12) return;
  final localUnitDir = localDir / localDirLen;
  final localRay = Ray.originDirection(localOrigin, localUnitDir);
  // A distance `d` in world space corresponds to `d * localDirLen` along
  // `localUnitDir` because `worldPoint - worldOrigin = W * (localUnitDir * tLocal)`
  // has length `tLocal / localDirLen` (plus a tiny epsilon for float rounding).
  final maxLocalT = (currentMaxDist * localDirLen) * (1.0 + 1e-5) + 1e-6;

  // Normal matrix = transpose of upper-left 3x3 of invWorld.
  final normalMatrix = invWorld.getRotation()..transpose();

  SceneRaycastHit toWorldHit(LocalMeshHit h) {
    final wp = worldTransform.transformed3(h.localPoint.clone());
    final wn = normalMatrix.transformed(h.localNormal.clone());
    if (wn.length2 > 1e-12) wn.normalize();
    final dist = wp.distanceTo(unitWorldRay.origin);
    return SceneRaycastHit(
      node: nodeId,
      colliderIndex: 0,
      worldPoint: wp,
      worldNormal: wn,
      distance: dist,
      uv: h.uv,
      barycentrics: h.barycentrics,
      triangleIndex: h.triangleIndex,
      primitiveIndex: primitiveIndex,
      instanceIndex: instanceIndex,
    );
  }

  if (closestOnly) {
    final hit = bvh.raycastClosest(localRay, maxT: maxLocalT);
    if (hit != null) {
      final worldHit = toWorldHit(hit);
      if (worldHit.distance <= currentMaxDist + 1e-6) {
        outHits
          ..clear()
          ..add(worldHit);
        onTightenMaxDist(worldHit.distance);
      }
    }
  } else {
    final hits = bvh.raycastAll(localRay, maxT: maxLocalT);
    for (final h in hits) {
      final worldHit = toWorldHit(h);
      if (worldHit.distance <= currentMaxDist + 1e-6) {
        outHits.add(worldHit);
      }
    }
  }
}

void _testD3InstancesComponent({
  required SceneDocument doc,
  required NodeSpec node,
  required ComponentSpec comp,
  required Matrix4 nodeWorld,
  required SceneCamera? camera,
  required Ray unitWorldRay,
  required double currentMaxDist,
  required bool closestOnly,
  required List<SceneRaycastHit> outHits,
  required void Function(double) onTightenMaxDist,
}) {
  final props = comp.properties;
  final billboard = switch (props['billboard']) {
    BoolValue(:final value) => value,
    _ => false,
  };

  TriangleMeshBvh? meshBvh;
  if (billboard) {
    final size = switch (props['size']) {
      Vec2Value(:final value) => value,
      _ => Vector2(1.0, 1.0),
    };
    final rot = switch (props['rotation']) {
      DoubleValue(:final value) => value,
      IntValue(:final value) => value.toDouble(),
      _ => 0.0,
    };
    final mesh = buildBillboard(
      size: size,
      rotation: rot,
      color: const [1.0, 1.0, 1.0, 1.0],
    );
    meshBvh = _bvhFromMeshData(mesh);
  } else if (props['shape'] case StringValue(:final value)) {
    meshBvh = _resolveD3ProcShapeBvh(value, props);
  } else if (props['geometry'] case ResourceRefValue(:final id)) {
    final res = doc.resources[id];
    if (res is GeometryResource) {
      meshBvh = _resolveGeometryBvh(
        doc,
        res,
        node: node,
        nodeWorld: nodeWorld,
        allWorlds: () => computeWorldTransforms(doc, includeHidden: true),
      );
    } else {
      final extEntry = d3ExtensionResources(doc)[id];
      if (extEntry != null) {
        meshBvh = _resolveExtensionResourceBvh(extEntry);
      }
    }
  }
  if (meshBvh == null || meshBvh.triangleCount == 0) return;

  final transformsProp = props['transforms'];
  var mats = switch (transformsProp) {
    ListValue(:final values) => <Matrix4>[
      for (final v in values)
        if (v is Matrix4Value) v.value,
    ],
    ResourceRefValue(:final id) => switch (doc.payloads[id]?.bytes) {
      final bytes? => d3DecodeMatrices(bytes),
      null => const <Matrix4>[],
    },
    _ => const <Matrix4>[],
  };
  if (mats.isEmpty) return;
  if (mats.length > kD3MaxBakedInstances) {
    mats = mats.sublist(0, kD3MaxBakedInstances);
  }

  late final Vector3 cameraPosition;
  late final Vector3 cameraRight;
  late final Vector3 cameraUp;
  if (billboard && camera != null) {
    final inverseNodeWorld = Matrix4.copy(nodeWorld);
    if (inverseNodeWorld.invert() == 0.0) return;
    cameraPosition = inverseNodeWorld.transformed3(camera.position.clone());
    final (worldRight, worldUp, _) = camera.basis;
    cameraRight = inverseNodeWorld.rotated3(worldRight.clone());
    cameraUp = inverseNodeWorld.rotated3(worldUp.clone());
  }

  Matrix4 worldForInstance(Matrix4 authoredTransform) {
    if (!billboard) return nodeWorld * authoredTransform;
    final center = authoredTransform.getTranslation();
    final localTransform = camera == null
        ? Matrix4.translationValues(center.x, center.y, center.z)
        : _billboardLocalTransform(
            facing: _billboardFacing(props),
            center: center,
            cameraPosition: cameraPosition,
            cameraRight: cameraRight,
            cameraUp: cameraUp,
          );
    return nodeWorld * localTransform;
  }

  final (localMin, localMax) = meshBvh.bounds;
  final corner = Vector3.zero();

  // Build an instance-level AABB BVH when there are multiple instances so
  // large instance clouds (e.g. 1,000 instances) prune in O(log N) before
  // testing triangle BVHs.
  if (mats.length > 8) {
    final entries = <({int index, Vector3 min, Vector3 max})>[];
    final instanceWorlds = List<Matrix4>.filled(
      mats.length,
      Matrix4.identity(),
    );
    for (var idx = 0; idx < mats.length; idx++) {
      final w = worldForInstance(mats[idx]);
      instanceWorlds[idx] = w;
      final bmin = Vector3.all(double.infinity);
      final bmax = Vector3.all(-double.infinity);
      for (var c = 0; c < 8; c++) {
        corner.setValues(
          (c & 1) == 0 ? localMin.x : localMax.x,
          (c & 2) == 0 ? localMin.y : localMax.y,
          (c & 4) == 0 ? localMin.z : localMax.z,
        );
        w.transform3(corner);
        Vector3.min(bmin, corner, bmin);
        Vector3.max(bmax, corner, bmax);
      }
      entries.add((index: idx, min: bmin, max: bmax));
    }

    var limit = currentMaxDist;
    final instanceBvh = Bvh<int>.build([
      for (final e in entries) (item: e.index, min: e.min, max: e.max),
    ]);
    instanceBvh.queryRay(
      unitWorldRay,
      maxDistance: limit,
      visitItem: (instIdx, maxDist) {
        _testBvhWithTransform(
          bvh: meshBvh!,
          worldTransform: instanceWorlds[instIdx],
          unitWorldRay: unitWorldRay,
          nodeId: node.id,
          primitiveIndex: 0,
          instanceIndex: instIdx,
          currentMaxDist: limit,
          closestOnly: closestOnly,
          outHits: outHits,
          onTightenMaxDist: (d) {
            limit = d;
            onTightenMaxDist(d);
          },
        );
        return closestOnly ? limit : maxDist;
      },
    );
  } else {
    var limit = currentMaxDist;
    for (var instIdx = 0; instIdx < mats.length; instIdx++) {
      final instWorld = worldForInstance(mats[instIdx]);
      _testBvhWithTransform(
        bvh: meshBvh,
        worldTransform: instWorld,
        unitWorldRay: unitWorldRay,
        nodeId: node.id,
        primitiveIndex: 0,
        instanceIndex: instIdx,
        currentMaxDist: limit,
        closestOnly: closestOnly,
        outHits: outHits,
        onTightenMaxDist: (d) {
          limit = d;
          onTightenMaxDist(d);
        },
      );
    }
  }
}

String _billboardFacing(Map<String, PropertyValue> props) {
  final facing = switch (props['facing']) {
    StringValue(:final value) => value,
    _ => 'spherical',
  };
  return switch (facing) {
    'axisY' || 'screen' => facing,
    _ => 'spherical',
  };
}

Matrix4? _queryBillboardWorldTransform({
  required Matrix4 nodeWorld,
  required SceneCamera camera,
  required String facing,
  required Vector3 center,
}) {
  final inverseNodeWorld = Matrix4.copy(nodeWorld);
  if (inverseNodeWorld.invert() == 0.0) return null;
  final cameraPosition = inverseNodeWorld.transformed3(camera.position.clone());
  final (worldRight, worldUp, _) = camera.basis;
  final cameraRight = inverseNodeWorld.rotated3(worldRight.clone());
  final cameraUp = inverseNodeWorld.rotated3(worldUp.clone());
  return nodeWorld *
      _billboardLocalTransform(
        facing: facing,
        center: center,
        cameraPosition: cameraPosition,
        cameraRight: cameraRight,
        cameraUp: cameraUp,
      );
}

Matrix4 _billboardLocalTransform({
  required String facing,
  required Vector3 center,
  required Vector3 cameraPosition,
  required Vector3 cameraRight,
  required Vector3 cameraUp,
}) {
  var right = cameraRight.clone();
  var up = cameraUp.clone();

  if (facing == 'spherical') {
    final toCamera = cameraPosition - center;
    if (toCamera.length2 > 1e-12) {
      toCamera.normalize();
      final facingRight = toCamera.cross(cameraUp);
      if (facingRight.length2 > 1e-12) {
        right = facingRight..normalize();
        up = -(toCamera.cross(right));
      }
    }
  } else if (facing == 'axisY') {
    final toCamera = cameraPosition - center;
    toCamera.y = 0;
    if (toCamera.length2 > 1e-12) {
      toCamera.normalize();
      right = toCamera.cross(Vector3(0, 1, 0))..normalize();
      up = Vector3(0, 1, 0);
    }
  }

  // Native renderers reflect document Z. Negating right × up preserves the
  // canonical billboard mesh's +Z normal toward the camera in document space.
  final normal = -right.cross(up)
    ..normalize();
  return Matrix4.identity()
    ..setColumn(0, Vector4(right.x, right.y, right.z, 0))
    ..setColumn(1, Vector4(up.x, up.y, up.z, 0))
    ..setColumn(2, Vector4(normal.x, normal.y, normal.z, 0))
    ..setTranslation(center);
}

List<LocalId> _meshPrimitiveGeometryIds(ComponentSpec comp) {
  final single = comp.properties['geometry'];
  if (single is ResourceRefValue) return [single.id];
  final prims = comp.properties['primitives'];
  if (prims is! ListValue) return const [];
  return [
    for (final entry in prims.values)
      if (entry is MapValue)
        if (entry.values['geometry'] case ResourceRefValue(:final id)) id,
  ];
}

TriangleMeshBvh? _resolveGeometryBvh(
  SceneDocument doc,
  GeometryResource res, {
  required NodeSpec node,
  required Matrix4 nodeWorld,
  required Map<LocalId, Matrix4> Function() allWorlds,
}) {
  final proc = res.procedural;
  if (proc != null) {
    final mesh = _buildUpstreamProceduralMesh(proc);
    if (mesh == null) return null;
    return _bvhFromMeshData(mesh);
  }

  final vtxId = res.vertices;
  if (vtxId == null) return null;
  final vtxPayload = doc.payloads[vtxId];
  final vtxBytes = vtxPayload?.bytes;
  if (vtxPayload == null || vtxBytes == null || vtxBytes.isEmpty) return null;

  final idxId = res.indices;
  final idxPayload = idxId != null ? doc.payloads[idxId] : null;
  final idxBytes = idxPayload?.bytes;

  // If the node has a skin and the vertex layout is skinned, deform vertices
  // into mesh-local space using the skin's joints and inverseBindMatrices.
  final skinId = node.skin;
  final layout = vtxPayload.layout ?? 'unskinned';
  final isSkinnedLayout =
      layout == 'skinned_uv1_tangent' || layout == 'skinned';
  if (skinId != null && isSkinnedLayout && doc.skins.containsKey(skinId)) {
    return _decodeAndDeformSkinnedGeometry(
      doc: doc,
      skin: doc.skins[skinId]!,
      nodeWorld: nodeWorld,
      allWorlds: allWorlds(),
      vtxBytes: vtxBytes,
      layout: layout,
      idxBytes: idxBytes,
      idxFormat: idxPayload?.format,
      topology: res.topology,
    );
  }

  final cacheMap = _payloadBvhCache[vtxPayload] ??=
      <_PayloadBvhCacheKey, _CachedPayloadBvh>{};
  final cacheKey = _PayloadBvhCacheKey(
    layout: layout,
    indexPayload: idxPayload,
    indexFormat: idxPayload?.format,
    topology: res.topology,
  );
  final cached = cacheMap[cacheKey];
  if (cached != null &&
      _samePayloadBytes(cached.vertexBytes, vtxBytes) &&
      _samePayloadBytes(cached.indexBytes, idxBytes)) {
    return cached.bvh;
  }

  final decoded = _decodePayloadGeometry(
    vtxBytes: vtxBytes,
    layout: layout,
    idxBytes: idxBytes,
    idxFormat: idxPayload?.format,
    topology: res.topology,
  );
  if (decoded == null) return null;
  cacheMap[cacheKey] = _CachedPayloadBvh(
    bvh: decoded,
    vertexBytes: Uint8List.fromList(vtxBytes),
    indexBytes: idxBytes == null ? null : Uint8List.fromList(idxBytes),
  );
  return decoded;
}

TriangleMeshBvh? _resolveExtensionResourceBvh(Map<String, Object?> extEntry) {
  final proc = extEntry['procedural'];
  if (proc is! Map) return null;
  final shape = proc['shape'];
  if (shape is! String) return null;
  final props = <String, PropertyValue>{};
  for (final e in proc.entries) {
    final k = e.key;
    final v = e.value;
    if (k is! String) continue;
    if (v is bool) {
      props[k] = BoolValue(v);
    } else if (v is int) {
      props[k] = IntValue(v);
    } else if (v is double) {
      props[k] = DoubleValue(v);
    } else if (v is String) {
      props[k] = StringValue(v);
    } else if (v is List && v.length == 3 && v.every((x) => x is num)) {
      props[k] = Vec3Value(
        Vector3(
          (v[0] as num).toDouble(),
          (v[1] as num).toDouble(),
          (v[2] as num).toDouble(),
        ),
      );
    } else if (v is List && v.length == 2 && v.every((x) => x is num)) {
      props[k] = Vec2Value(
        Vector2((v[0] as num).toDouble(), (v[1] as num).toDouble()),
      );
    }
  }
  return _resolveD3ProcShapeBvh(shape, props);
}

Matrix3 _inverseTransposeLinear(Matrix4 transform) {
  final upper = transform.getRotation();
  final determinant = upper.determinant();
  final c0 = upper.getColumn(0);
  final c1 = upper.getColumn(1);
  final c2 = upper.getColumn(2);
  final normalMatrix = Matrix3.columns(
    c1.cross(c2),
    c2.cross(c0),
    c0.cross(c1),
  );
  if (determinant != 0.0) normalMatrix.scale(1.0 / determinant);
  return normalMatrix;
}

D3MeshData? _buildUpstreamProceduralMesh(ProceduralGeometry proc) {
  return switch (proc) {
    CuboidGeometrySpec(:final extents, :final debugColors) => buildCuboid(
      extents,
      debugColors: debugColors,
    ),
    PlaneGeometrySpec(
      :final width,
      :final depth,
      :final segmentsX,
      :final segmentsZ,
    ) =>
      buildPlane(
        width: width,
        depth: depth,
        segmentsX: segmentsX,
        segmentsZ: segmentsZ,
      ),
    SphereGeometrySpec(:final radius, :final segments, :final rings) =>
      buildSphere(radius: radius, segments: segments, rings: rings),
    TorusGeometrySpec(
      :final radius,
      :final tubeRadius,
      :final radialSegments,
      :final tubularSegments,
    ) =>
      buildTorus(
        radius: radius,
        tubeRadius: tubeRadius,
        radialSegments: radialSegments,
        tubularSegments: tubularSegments,
      ),
    IcosphereGeometrySpec(:final radius, :final subdivisions) => buildIcosphere(
      radius: radius,
      subdivisions: subdivisions,
    ),
  };
}

TriangleMeshBvh? _resolveD3ProcComponentBvh(Map<String, PropertyValue> props) {
  final shape = props['shape'];
  if (shape is! StringValue) return null;
  return _resolveD3ProcShapeBvh(shape.value, props);
}

TriangleMeshBvh? _resolveD3ProcShapeBvh(
  String shape,
  Map<String, PropertyValue> props,
) {
  double d(String k, double def) => switch (props[k]) {
    DoubleValue(:final value) => value,
    IntValue(:final value) => value.toDouble(),
    _ => def,
  };
  int i(String k, int def) => switch (props[k]) {
    IntValue(:final value) => value,
    DoubleValue(:final value) => value.toInt(),
    _ => def,
  };
  bool b(String k, bool def) => switch (props[k]) {
    BoolValue(:final value) => value,
    _ => def,
  };
  List<Vector3> pts() => switch (props['points']) {
    ListValue(:final values) => [
      for (final v in values)
        if (v is Vec3Value) v.value,
    ],
    _ => const <Vector3>[],
  };

  D3MeshData? mesh;
  switch (shape) {
    case 'cuboid':
      final ext = switch (props['extents']) {
        Vec3Value(:final value) => value,
        _ => Vector3.all(1.0),
      };
      mesh = buildCuboid(ext, debugColors: b('debugColors', false));
    case 'plane':
      mesh = buildPlane(
        width: d('width', 1.0),
        depth: d('depth', 1.0),
        segmentsX: i('segmentsX', 1),
        segmentsZ: i('segmentsZ', 1),
      );
    case 'sphere':
      mesh = buildSphere(
        radius: d('radius', 0.5),
        segments: i('segments', 32),
        rings: i('rings', 16),
      );
    case 'torus':
      mesh = buildTorus(
        radius: d('radius', 0.5),
        tubeRadius: d('tubeRadius', 0.15),
        radialSegments: i('radialSegments', 32),
        tubularSegments: i('tubularSegments', 16),
      );
    case 'icosphere':
      mesh = buildIcosphere(
        radius: d('radius', 0.5),
        subdivisions: i('subdivisions', 2),
      );
    case 'cylinder':
      mesh = buildCylinder(
        bottomRadius: d('bottomRadius', 0.5),
        topRadius: d('topRadius', 0.5),
        height: d('height', 1.0),
        radialSegments: i('radialSegments', 32),
        heightSegments: i('heightSegments', 1),
        bottomCap: b('bottomCap', true),
        topCap: b('topCap', true),
      );
    case 'cone':
      mesh = buildCylinder(
        bottomRadius: d('radius', 0.5),
        topRadius: 0.0,
        height: d('height', 1.0),
        radialSegments: i('radialSegments', 32),
        heightSegments: i('heightSegments', 1),
        bottomCap: b('bottomCap', true),
        topCap: false,
      );
    case 'capsule':
      mesh = buildCapsule(
        radius: d('radius', 0.5),
        height: d('height', 1.0),
        radialSegments: i('radialSegments', 32),
        capRings: i('capRings', 8),
      );
    case 'disc':
      mesh = buildDisc(
        radius: d('radius', 0.5),
        segments: i('segments', 32),
      );
    case 'tube':
      final p = pts();
      if (p.length >= 2) {
        final closed = b('closed', false);
        final pathPts = closed ? <Vector3>[...p, p.first] : p;
        mesh = buildTube(
          CatmullRomPath(pathPts),
          radius: d('radius', 0.5),
          radialSegments: i('radialSegments', 12),
          stations: i('stations', 64),
          caps: b('caps', true) && !closed,
        );
      }
    case 'ribbon':
      final p = pts();
      if (p.length >= 2) {
        final closed = b('closed', false);
        final pathPts = closed ? <Vector3>[...p, p.first] : p;
        final up = switch (props['up']) {
          Vec3Value(:final value) => value,
          _ => Vector3(0, 1, 0),
        };
        mesh = buildRibbon(
          CatmullRomPath(pathPts),
          width: d('width', 1.0),
          stations: i('stations', 64),
          up: up,
        );
      }
    case 'polyline':
      final p = pts();
      if (p.length >= 2) {
        mesh = buildPolyline(
          p,
          width: d('width', 1.0),
          closed: b('closed', false),
        );
      }
    case 'lineSegments':
      final p = pts();
      if (p.length >= 2 && p.length.isEven) {
        mesh = buildLineSegments(p, width: d('width', 1.0));
      }
    case 'billboard':
      final size = switch (props['size']) {
        Vec2Value(:final value) => value,
        _ => Vector2(1.0, 1.0),
      };
      mesh = buildBillboard(
        size: size,
        rotation: d('rotation', 0.0),
        color: const [1.0, 1.0, 1.0, 1.0],
      );
  }
  if (mesh == null) return null;
  return _bvhFromMeshData(mesh);
}

TriangleMeshBvh _bvhFromMeshData(D3MeshData mesh) {
  final cached = _procMeshBvhCache[mesh];
  if (cached != null) return cached;
  final bvh = TriangleMeshBvh.build(
    positions: mesh.positions,
    normals: mesh.normals,
    uvs: mesh.uvs,
    indices: mesh.indices,
  );
  _procMeshBvhCache[mesh] = bvh;
  return bvh;
}

TriangleMeshBvh? _decodePayloadGeometry({
  required Uint8List vtxBytes,
  required String layout,
  required Uint8List? idxBytes,
  required String? idxFormat,
  required String topology,
}) {
  if (topology == 'line' || topology == 'lineStrip' || topology == 'point') {
    return null;
  }

  final decoded = _unpackVertexStreams(vtxBytes, layout);
  if (decoded == null) return null;

  final triIndices = _unpackTriangleIndices(
    vertexCount: decoded.vertexCount,
    idxBytes: idxBytes,
    idxFormat: idxFormat,
    topology: topology,
  );
  if (triIndices == null || triIndices.isEmpty) return null;

  return TriangleMeshBvh.build(
    positions: decoded.positions,
    normals: decoded.normals,
    uvs: decoded.uvs,
    indices: triIndices,
  );
}

TriangleMeshBvh? _decodeAndDeformSkinnedGeometry({
  required SceneDocument doc,
  required SkinSpec skin,
  required Matrix4 nodeWorld,
  required Map<LocalId, Matrix4> allWorlds,
  required Uint8List vtxBytes,
  required String layout,
  required Uint8List? idxBytes,
  required String? idxFormat,
  required String topology,
}) {
  final decoded = _unpackVertexStreams(vtxBytes, layout, readSkinning: true);
  if (decoded == null) return null;
  final jointsStream = decoded.joints;
  final weightsStream = decoded.weights;
  if (jointsStream == null || weightsStream == null || skin.joints.isEmpty) {
    return _decodePayloadGeometry(
      vtxBytes: vtxBytes,
      layout: layout,
      idxBytes: idxBytes,
      idxFormat: idxFormat,
      topology: topology,
    );
  }

  final triIndices = _unpackTriangleIndices(
    vertexCount: decoded.vertexCount,
    idxBytes: idxBytes,
    idxFormat: idxFormat,
    topology: topology,
  );
  if (triIndices == null || triIndices.isEmpty) return null;

  // Compute joint palettes in mesh-local space:
  // M_j = inv(nodeWorld) * jointWorld[j] * ibm[j]
  final invNodeWorld = Matrix4.copy(nodeWorld);
  if (invNodeWorld.invert() == 0.0) {
    invNodeWorld.setIdentity();
  }

  List<Matrix4>? ibms;
  final ibmBytes = doc.payloads[skin.inverseBindMatrices]?.bytes;
  if (ibmBytes != null && ibmBytes.lengthInBytes >= 64) {
    ibms = d3DecodeMatrices(ibmBytes);
  }

  final jointCount = skin.joints.length;
  final jointMatrices = List<Matrix4>.generate(jointCount, (j) {
    final jointNodeId = skin.joints[j];
    final jWorld = allWorlds[jointNodeId] ?? Matrix4.identity();
    final ibm = (ibms != null && j < ibms.length) ? ibms[j] : Matrix4.identity();
    return invNodeWorld * jWorld * ibm;
  });
  final jointNormalMatrices = [
    for (final matrix in jointMatrices) _inverseTransposeLinear(matrix),
  ];

  final vCount = decoded.vertexCount;
  final outPos = Float32List(vCount * 3);
  final outNrm = Float32List(vCount * 3);
  final srcPos = decoded.positions;
  final srcNrm = decoded.normals;
  final tmpP = Vector3.zero();
  final tmpN = Vector3.zero();

  for (var v = 0; v < vCount; v++) {
    final pOff = v * 3;
    final jOff = v * 4;
    final px = srcPos[pOff], py = srcPos[pOff + 1], pz = srcPos[pOff + 2];
    final nx = srcNrm[pOff], ny = srcNrm[pOff + 1], nz = srcNrm[pOff + 2];

    final w0 = weightsStream[jOff],
        w1 = weightsStream[jOff + 1],
        w2 = weightsStream[jOff + 2],
        w3 = weightsStream[jOff + 3];
    final wSum = w0 + w1 + w2 + w3;
    if (wSum <= 1e-6) {
      outPos[pOff] = px;
      outPos[pOff + 1] = py;
      outPos[pOff + 2] = pz;
      outNrm[pOff] = nx;
      outNrm[pOff + 1] = ny;
      outNrm[pOff + 2] = nz;
      continue;
    }

    var sx = 0.0, sy = 0.0, sz = 0.0;
    var snx = 0.0, sny = 0.0, snz = 0.0;

    for (var k = 0; k < 4; k++) {
      final w = weightsStream[jOff + k];
      final jointIndex = jointsStream[jOff + k];
      if (!jointIndex.isFinite) return null;
      if (w <= 1e-6) continue;
      final jIdx = jointIndex.round().clamp(0, jointCount - 1);
      final m = jointMatrices[jIdx];
      tmpP.setValues(px, py, pz);
      m.transform3(tmpP);
      sx += tmpP.x * w;
      sy += tmpP.y * w;
      sz += tmpP.z * w;

      tmpN.setValues(nx, ny, nz);
      jointNormalMatrices[jIdx].transform(tmpN);
      snx += tmpN.x * w;
      sny += tmpN.y * w;
      snz += tmpN.z * w;
    }

    outPos[pOff] = sx;
    outPos[pOff + 1] = sy;
    outPos[pOff + 2] = sz;
    outNrm[pOff] = snx;
    outNrm[pOff + 1] = sny;
    outNrm[pOff + 2] = snz;
  }

  return TriangleMeshBvh.build(
    positions: outPos,
    normals: outNrm,
    uvs: decoded.uvs,
    indices: triIndices,
  );
}

final class _UnpackedStreams {
  const _UnpackedStreams({
    required this.vertexCount,
    required this.positions,
    required this.normals,
    required this.uvs,
    this.joints,
    this.weights,
  });

  final int vertexCount;
  final Float32List positions;
  final Float32List normals;
  final Float32List uvs;
  final Float32List? joints;
  final Float32List? weights;
}

_UnpackedStreams? _unpackVertexStreams(
  Uint8List bytes,
  String layout, {
  bool readSkinning = false,
}) {
  final byteLen = bytes.lengthInBytes;
  final bd = ByteData.sublistView(bytes);

  switch (layout) {
    case 'unskinned_uv1_tangent':
    case 'skinned_uv1_tangent':
    case 'unskinned':
    case '':
    case 'skinned':
      final stride = switch (layout) {
        'unskinned_uv1_tangent' => 72,
        'skinned_uv1_tangent' => 104,
        'skinned' => 80,
        _ => 48,
      };
      if (byteLen < stride || byteLen % stride != 0) return null;
      final vCount = byteLen ~/ stride;
      final positions = Float32List(vCount * 3);
      final normals = Float32List(vCount * 3);
      final uvs = Float32List(vCount * 2);
      Float32List? joints;
      Float32List? weights;
      final jointsByteOffset = layout == 'skinned_uv1_tangent'
          ? 72
          : (layout == 'skinned' ? 48 : -1);
      if (readSkinning && jointsByteOffset >= 0) {
        joints = Float32List(vCount * 4);
        weights = Float32List(vCount * 4);
      }

      for (var v = 0; v < vCount; v++) {
        final base = v * stride;
        final pOff = v * 3;
        final uvOff = v * 2;
        positions[pOff] = bd.getFloat32(base, Endian.little);
        positions[pOff + 1] = bd.getFloat32(base + 4, Endian.little);
        positions[pOff + 2] = bd.getFloat32(base + 8, Endian.little);
        normals[pOff] = bd.getFloat32(base + 12, Endian.little);
        normals[pOff + 1] = bd.getFloat32(base + 16, Endian.little);
        normals[pOff + 2] = bd.getFloat32(base + 20, Endian.little);
        uvs[uvOff] = bd.getFloat32(base + 24, Endian.little);
        uvs[uvOff + 1] = bd.getFloat32(base + 28, Endian.little);

        if (joints != null && weights != null) {
          final jBase = base + jointsByteOffset;
          final jOff = v * 4;
          joints[jOff] = bd.getFloat32(jBase, Endian.little);
          joints[jOff + 1] = bd.getFloat32(jBase + 4, Endian.little);
          joints[jOff + 2] = bd.getFloat32(jBase + 8, Endian.little);
          joints[jOff + 3] = bd.getFloat32(jBase + 12, Endian.little);
          weights[jOff] = bd.getFloat32(jBase + 16, Endian.little);
          weights[jOff + 1] = bd.getFloat32(jBase + 20, Endian.little);
          weights[jOff + 2] = bd.getFloat32(jBase + 24, Endian.little);
          weights[jOff + 3] = bd.getFloat32(jBase + 28, Endian.little);
        }
      }
      return _UnpackedStreams(
        vertexCount: vCount,
        positions: positions,
        normals: normals,
        uvs: uvs,
        joints: joints,
        weights: weights,
      );

    case 'unskinned_soa_uv1_tangent':
    case 'unskinned_soa':
      final stride = layout == 'unskinned_soa_uv1_tangent' ? 72 : 48;
      if (byteLen < stride || byteLen % stride != 0) return null;
      final vCount = byteLen ~/ stride;
      final positions = Float32List(vCount * 3);
      final normals = Float32List(vCount * 3);
      final uvs = Float32List(vCount * 2);
      final posBase = 0;
      final nrmBase = vCount * 12;
      final uv0Base = vCount * 24;
      for (var i = 0; i < vCount * 3; i++) {
        positions[i] = bd.getFloat32(posBase + i * 4, Endian.little);
        normals[i] = bd.getFloat32(nrmBase + i * 4, Endian.little);
      }
      for (var i = 0; i < vCount * 2; i++) {
        uvs[i] = bd.getFloat32(uv0Base + i * 4, Endian.little);
      }
      return _UnpackedStreams(
        vertexCount: vCount,
        positions: positions,
        normals: normals,
        uvs: uvs,
      );

    case 'p3t4':
      const stride = 28;
      if (byteLen < stride || byteLen % stride != 0) return null;
      final vCount = byteLen ~/ stride;
      final positions = Float32List(vCount * 3);
      final normals = Float32List(vCount * 3);
      final uvs = Float32List(vCount * 2);
      for (var v = 0; v < vCount; v++) {
        final base = v * stride;
        final pOff = v * 3;
        positions[pOff] = bd.getFloat32(base, Endian.little);
        positions[pOff + 1] = bd.getFloat32(base + 4, Endian.little);
        positions[pOff + 2] = -bd.getFloat32(base + 8, Endian.little);
        final frame = Quaternion(
          bd.getFloat32(base + 12, Endian.little),
          bd.getFloat32(base + 16, Endian.little),
          bd.getFloat32(base + 20, Endian.little),
          bd.getFloat32(base + 24, Endian.little),
        );
        final normal = frame.length2 == 0.0
            ? Vector3(0, 0, 1)
            : frame.asRotationMatrix().transform(Vector3(0, 0, 1));
        normals[pOff] = normal.x;
        normals[pOff + 1] = normal.y;
        normals[pOff + 2] = -normal.z;
      }
      return _UnpackedStreams(
        vertexCount: vCount,
        positions: positions,
        normals: normals,
        uvs: uvs,
      );

    default:
      return null;
  }
}

Uint32List? _unpackTriangleIndices({
  required int vertexCount,
  required Uint8List? idxBytes,
  required String? idxFormat,
  required String topology,
}) {
  Uint32List raw;
  if (idxBytes == null || idxBytes.isEmpty) {
    raw = Uint32List.fromList(List<int>.generate(vertexCount, (i) => i));
  } else {
    final bd = ByteData.sublistView(idxBytes);
    final isU32 = idxFormat == 'uint32';
    final elemSize = isU32 ? 4 : 2;
    if (idxBytes.lengthInBytes < elemSize ||
        idxBytes.lengthInBytes % elemSize != 0) {
      return null;
    }
    final count = idxBytes.lengthInBytes ~/ elemSize;
    raw = Uint32List(count);
    if (isU32) {
      for (var i = 0; i < count; i++) {
        raw[i] = bd.getUint32(i * 4, Endian.little);
      }
    } else {
      for (var i = 0; i < count; i++) {
        raw[i] = bd.getUint16(i * 2, Endian.little);
      }
    }
  }

  if (topology == 'triangle' || topology.isEmpty) {
    final triCount = raw.length ~/ 3;
    if (triCount == 0) return null;
    return Uint32List.sublistView(raw, 0, triCount * 3);
  }
  if (topology == 'triangleStrip') {
    if (raw.length < 3) return null;
    final triCount = raw.length - 2;
    final tris = Uint32List(triCount * 3);
    for (var t = 0; t < triCount; t++) {
      if (t.isEven) {
        tris[t * 3] = raw[t];
        tris[t * 3 + 1] = raw[t + 1];
        tris[t * 3 + 2] = raw[t + 2];
      } else {
        tris[t * 3] = raw[t + 1];
        tris[t * 3 + 1] = raw[t];
        tris[t * 3 + 2] = raw[t + 2];
      }
    }
    return tris;
  }
  return null;
}
