/// Bounding Volume Hierarchy (BVH) for render-geometry raycasting and
/// instance / scene spatial acceleration (U1 / E2 / D8).
///
/// Pure Dart (no `dartnative` import) so it runs under `dn test`.
///
/// Mirrors upstream `flutter_scene` `Bvh` + `MeshBvh`:
/// - [Bvh] builds a top-down midpoint-split binary AABB tree over arbitrary
///   bounded items (nodes or instances) and supports in-place [updateBounds]
///   when bounds move dynamically.
/// - [TriangleMeshBvh] builds a flat-array binary BVH over a triangle mesh's
///   positions and indices and performs Möller-Trumbore ray-triangle tests
///   returning barycentrics, interpolated normal/UV, and hit distance.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

/// Axis-aligned bounding box slab intersection test against [ray] on `[0, maxDistance]`.
///
/// Returns the entry parameter `tNear >= 0` on a hit, or `null` on a miss.
double? intersectRayAabb(
  Ray ray,
  Vector3 bmin,
  Vector3 bmax, {
  double maxDistance = double.infinity,
}) {
  const eps = 1e-6;
  final ox = ray.origin.x, oy = ray.origin.y, oz = ray.origin.z;
  final dx = ray.direction.x, dy = ray.direction.y, dz = ray.direction.z;

  var tMin = 0.0;
  var tMax = maxDistance;

  // X slab
  if (dx.abs() < 1e-12) {
    if (ox < bmin.x - eps || ox > bmax.x + eps) return null;
  } else {
    final invD = 1.0 / dx;
    var t0 = (bmin.x - eps - ox) * invD;
    var t1 = (bmax.x + eps - ox) * invD;
    if (t0 > t1) {
      final tmp = t0;
      t0 = t1;
      t1 = tmp;
    }
    if (t0 > tMin) tMin = t0;
    if (t1 < tMax) tMax = t1;
    if (tMin > tMax) return null;
  }

  // Y slab
  if (dy.abs() < 1e-12) {
    if (oy < bmin.y - eps || oy > bmax.y + eps) return null;
  } else {
    final invD = 1.0 / dy;
    var t0 = (bmin.y - eps - oy) * invD;
    var t1 = (bmax.y + eps - oy) * invD;
    if (t0 > t1) {
      final tmp = t0;
      t0 = t1;
      t1 = tmp;
    }
    if (t0 > tMin) tMin = t0;
    if (t1 < tMax) tMax = t1;
    if (tMin > tMax) return null;
  }

  // Z slab
  if (dz.abs() < 1e-12) {
    if (oz < bmin.z - eps || oz > bmax.z + eps) return null;
  } else {
    final invD = 1.0 / dz;
    var t0 = (bmin.z - eps - oz) * invD;
    var t1 = (bmax.z + eps - oz) * invD;
    if (t0 > t1) {
      final tmp = t0;
      t0 = t1;
      t1 = tmp;
    }
    if (t0 > tMin) tMin = t0;
    if (t1 < tMax) tMax = t1;
    if (tMin > tMax) return null;
  }

  return tMin;
}

/// Generic Bounding Volume Hierarchy over items of type [T] with world/local
/// AABBs `(min, max)`.
///
/// Mirrors upstream `flutter_scene` `Bvh`: builds a binary tree by splitting
/// along the longest centroid axis and supports in-place [updateBounds] when
/// items move without changing topology.
final class Bvh<T> {
  Bvh._(this._nodes, this._leafMap);

  /// Builds a BVH over [entries].
  factory Bvh.build(
    List<({T item, Vector3 min, Vector3 max})> entries, {
    int maxLeafSize = 4,
  }) {
    if (entries.isEmpty) {
      return Bvh._(const [], const {});
    }
    final nodes = <_BvhNode<T>>[];
    final leafMap = <T, int>{};
    final indices = List<int>.generate(entries.length, (i) => i);

    int buildRange(int start, int end) {
      final nodeIndex = nodes.length;
      final bmin = Vector3.all(double.infinity);
      final bmax = Vector3.all(-double.infinity);
      final cmin = Vector3.all(double.infinity);
      final cmax = Vector3.all(-double.infinity);

      for (var i = start; i < end; i++) {
        final e = entries[indices[i]];
        Vector3.min(bmin, e.min, bmin);
        Vector3.max(bmax, e.max, bmax);
        final cx = (e.min.x + e.max.x) * 0.5;
        final cy = (e.min.y + e.max.y) * 0.5;
        final cz = (e.min.z + e.max.z) * 0.5;
        if (cx < cmin.x) cmin.x = cx;
        if (cy < cmin.y) cmin.y = cy;
        if (cz < cmin.z) cmin.z = cz;
        if (cx > cmax.x) cmax.x = cx;
        if (cy > cmax.y) cmax.y = cy;
        if (cz > cmax.z) cmax.z = cz;
      }

      final count = end - start;
      final node = _BvhNode<T>(min: bmin, max: bmax);
      nodes.add(node);

      if (count <= maxLeafSize) {
        node.items = [for (var i = start; i < end; i++) entries[indices[i]].item];
        node.itemMins = [
          for (var i = start; i < end; i++) entries[indices[i]].min.clone(),
        ];
        node.itemMaxs = [
          for (var i = start; i < end; i++) entries[indices[i]].max.clone(),
        ];
        for (final item in node.items!) {
          leafMap[item] = nodeIndex;
        }
        return nodeIndex;
      }

      final spanX = cmax.x - cmin.x;
      final spanY = cmax.y - cmin.y;
      final spanZ = cmax.z - cmin.z;
      final axis = (spanX >= spanY && spanX >= spanZ)
          ? 0
          : (spanY >= spanZ ? 1 : 2);
      final splitPos = (cmin.storage[axis] + cmax.storage[axis]) * 0.5;

      var mid = start;
      if ((cmax.storage[axis] - cmin.storage[axis]) > 1e-7) {
        var i = start;
        var j = end - 1;
        while (i <= j) {
          final e = entries[indices[i]];
          final c = (e.min.storage[axis] + e.max.storage[axis]) * 0.5;
          if (c < splitPos) {
            i++;
          } else {
            final tmp = indices[i];
            indices[i] = indices[j];
            indices[j] = tmp;
            j--;
          }
        }
        mid = i;
      }
      if (mid <= start || mid >= end) {
        mid = (start + end) >> 1;
      }

      final left = buildRange(start, mid);
      final right = buildRange(mid, end);
      node.left = left;
      node.right = right;
      nodes[left].parent = nodeIndex;
      nodes[right].parent = nodeIndex;
      return nodeIndex;
    }

    buildRange(0, entries.length);
    return Bvh._(nodes, leafMap);
  }

  final List<_BvhNode<T>> _nodes;
  final Map<T, int> _leafMap;

  /// Whether the hierarchy has no nodes.
  bool get isEmpty => _nodes.isEmpty;

  /// Root AABB `(min, max)`, or `null` when empty.
  (Vector3 min, Vector3 max)? get rootBounds =>
      _nodes.isEmpty ? null : (_nodes.first.min.clone(), _nodes.first.max.clone());

  /// Updates [item]'s AABB in place and refits ancestor bounding boxes up to
  /// the root. Returns `true` if [item] was found.
  bool updateBounds(T item, Vector3 newMin, Vector3 newMax) {
    final leafIdx = _leafMap[item];
    if (leafIdx == null) return false;
    final leaf = _nodes[leafIdx];
    final items = leaf.items;
    if (items == null) return false;
    final idx = items.indexOf(item);
    if (idx < 0) return false;
    leaf.itemMins![idx].setFrom(newMin);
    leaf.itemMaxs![idx].setFrom(newMax);

    var curr = leafIdx;
    while (curr >= 0) {
      final node = _nodes[curr];
      node.min.setValues(double.infinity, double.infinity, double.infinity);
      node.max.setValues(-double.infinity, -double.infinity, -double.infinity);
      if (node.items != null) {
        for (var i = 0; i < node.items!.length; i++) {
          Vector3.min(node.min, node.itemMins![i], node.min);
          Vector3.max(node.max, node.itemMaxs![i], node.max);
        }
      } else {
        final l = _nodes[node.left];
        final r = _nodes[node.right];
        Vector3.min(node.min, l.min, node.min);
        Vector3.min(node.min, r.min, node.min);
        Vector3.max(node.max, l.max, node.max);
        Vector3.max(node.max, r.max, node.max);
      }
      curr = node.parent;
    }
    return true;
  }

  /// Traverses the BVH front-to-back along [ray] up to [maxDistance], invoking
  /// [visitItem] for each candidate leaf item whose AABB intersects [ray].
  ///
  /// [visitItem] may return a tightened `maxDistance` (e.g. when finding the
  /// closest hit) to prune farther subtrees.
  void queryRay(
    Ray ray, {
    double maxDistance = double.infinity,
    required double Function(T item, double currentMaxDistance) visitItem,
  }) {
    if (_nodes.isEmpty) return;
    var limit = maxDistance;
    final rootT = intersectRayAabb(
      ray,
      _nodes[0].min,
      _nodes[0].max,
      maxDistance: limit,
    );
    if (rootT == null) return;

    final stack = <int>[0];
    while (stack.isNotEmpty) {
      final nodeIdx = stack.removeLast();
      final node = _nodes[nodeIdx];
      final tNode = intersectRayAabb(
        ray,
        node.min,
        node.max,
        maxDistance: limit,
      );
      if (tNode == null || tNode > limit) continue;

      final items = node.items;
      if (items != null) {
        final mins = node.itemMins!;
        final maxs = node.itemMaxs!;
        for (var i = 0; i < items.length; i++) {
          final tItem = intersectRayAabb(
            ray,
            mins[i],
            maxs[i],
            maxDistance: limit,
          );
          if (tItem != null && tItem <= limit) {
            final newLimit = visitItem(items[i], limit);
            if (newLimit < limit) limit = newLimit;
          }
        }
        continue;
      }

      final leftIdx = node.left;
      final rightIdx = node.right;
      final leftNode = _nodes[leftIdx];
      final rightNode = _nodes[rightIdx];
      final tLeft = intersectRayAabb(
        ray,
        leftNode.min,
        leftNode.max,
        maxDistance: limit,
      );
      final tRight = intersectRayAabb(
        ray,
        rightNode.min,
        rightNode.max,
        maxDistance: limit,
      );

      if (tLeft != null && tRight != null) {
        // Push farther child first so nearer child is popped first.
        if (tLeft <= tRight) {
          stack.add(rightIdx);
          stack.add(leftIdx);
        } else {
          stack.add(leftIdx);
          stack.add(rightIdx);
        }
      } else if (tLeft != null) {
        stack.add(leftIdx);
      } else if (tRight != null) {
        stack.add(rightIdx);
      }
    }
  }
}

final class _BvhNode<T> {
  _BvhNode({required this.min, required this.max});

  final Vector3 min;
  final Vector3 max;
  int parent = -1;
  int left = -1;
  int right = -1;
  List<T>? items;
  List<Vector3>? itemMins;
  List<Vector3>? itemMaxs;
}

/// Result of a local-space ray-triangle intersection in [TriangleMeshBvh].
final class LocalMeshHit {
  /// Creates a local-space mesh hit.
  const LocalMeshHit({
    required this.t,
    required this.localPoint,
    required this.localNormal,
    required this.uv,
    required this.barycentrics,
    required this.triangleIndex,
  });

  /// Parameter `t` along the local ray (`localOrigin + localDirection * t`).
  final double t;

  /// Intersection point in mesh-local space.
  final Vector3 localPoint;

  /// Interpolated vertex normal (or geometric face normal) in mesh-local space.
  final Vector3 localNormal;

  /// Interpolated primary texture coordinate `(u, v)`.
  final Vector2 uv;

  /// Barycentric weights `(w0, w1, w2)` where `w0 = 1 - u - v`, `w1 = u`, `w2 = v`.
  final Vector3 barycentrics;

  /// Index of the hit triangle (`0 .. triangleCount - 1`).
  final int triangleIndex;
}

/// Flat-array binary BVH over a triangle mesh's positions, normals, UVs, and
/// triangle indices.
///
/// Mirrors upstream `flutter_scene` `MeshBvh`.
final class TriangleMeshBvh {
  TriangleMeshBvh._({
    required this.positions,
    required this.normals,
    required this.uvs,
    required this.indices,
    required Float32List nodeBounds,
    required Int32List nodeLeftOrStart,
    required Int32List nodeRight,
    required Int32List nodeTriCount,
    required Uint32List triOrder,
  }) : _nodeBounds = nodeBounds,
       _nodeLeftOrStart = nodeLeftOrStart,
       _nodeRight = nodeRight,
       _nodeTriCount = nodeTriCount,
       _triOrder = triOrder;

  /// Builds a triangle BVH from flat `positions` (`3 * V` floats), optional
  /// `normals` (`3 * V` floats), optional `uvs` (`2 * V` floats), and triangle
  /// `indices` (`3 * T` ints; if empty, sequential `0 .. V-1` is used).
  factory TriangleMeshBvh.build({
    required Float32List positions,
    Float32List? normals,
    Float32List? uvs,
    Uint32List? indices,
    int maxLeafTriangles = 8,
  }) {
    final vCount = positions.length ~/ 3;
    final triIndices = (indices != null && indices.isNotEmpty)
        ? indices
        : Uint32List.fromList(List<int>.generate(vCount, (i) => i));
    final triCount = triIndices.length ~/ 3;
    if (triCount == 0 || vCount == 0) {
      return TriangleMeshBvh._(
        positions: positions,
        normals: normals,
        uvs: uvs,
        indices: triIndices,
        nodeBounds: Float32List(0),
        nodeLeftOrStart: Int32List(0),
        nodeRight: Int32List(0),
        nodeTriCount: Int32List(0),
        triOrder: Uint32List(0),
      );
    }

    final triOrder = Uint32List(triCount);
    final triBounds = Float32List(triCount * 6);
    final triCentroids = Float32List(triCount * 3);

    for (var t = 0; t < triCount; t++) {
      triOrder[t] = t;
      final i0 = triIndices[t * 3] * 3;
      final i1 = triIndices[t * 3 + 1] * 3;
      final i2 = triIndices[t * 3 + 2] * 3;
      if (i0 + 2 >= positions.length ||
          i1 + 2 >= positions.length ||
          i2 + 2 >= positions.length) {
        continue;
      }
      final x0 = positions[i0], y0 = positions[i0 + 1], z0 = positions[i0 + 2];
      final x1 = positions[i1], y1 = positions[i1 + 1], z1 = positions[i1 + 2];
      final x2 = positions[i2], y2 = positions[i2 + 1], z2 = positions[i2 + 2];

      final minX = math.min(x0, math.min(x1, x2));
      final minY = math.min(y0, math.min(y1, y2));
      final minZ = math.min(z0, math.min(z1, z2));
      final maxX = math.max(x0, math.max(x1, x2));
      final maxY = math.max(y0, math.max(y1, y2));
      final maxZ = math.max(z0, math.max(z1, z2));

      final bOff = t * 6;
      triBounds[bOff] = minX;
      triBounds[bOff + 1] = minY;
      triBounds[bOff + 2] = minZ;
      triBounds[bOff + 3] = maxX;
      triBounds[bOff + 4] = maxY;
      triBounds[bOff + 5] = maxZ;

      final cOff = t * 3;
      triCentroids[cOff] = (minX + maxX) * 0.5;
      triCentroids[cOff + 1] = (minY + maxY) * 0.5;
      triCentroids[cOff + 2] = (minZ + maxZ) * 0.5;
    }

    final maxNodes = math.max(1, triCount * 2);
    final nodeBounds = Float32List(maxNodes * 6);
    final nodeLeftOrStart = Int32List(maxNodes);
    final nodeRight = Int32List(maxNodes);
    final nodeTriCount = Int32List(maxNodes);
    var nodeCount = 0;

    int buildNode(int start, int end) {
      final nodeIdx = nodeCount++;
      var minX = double.infinity,
          minY = double.infinity,
          minZ = double.infinity;
      var maxX = -double.infinity,
          maxY = -double.infinity,
          maxZ = -double.infinity;
      var cMinX = double.infinity,
          cMinY = double.infinity,
          cMinZ = double.infinity;
      var cMaxX = -double.infinity,
          cMaxY = -double.infinity,
          cMaxZ = -double.infinity;

      for (var i = start; i < end; i++) {
        final t = triOrder[i];
        final bOff = t * 6;
        final cOff = t * 3;
        final tMinX = triBounds[bOff],
            tMinY = triBounds[bOff + 1],
            tMinZ = triBounds[bOff + 2];
        final tMaxX = triBounds[bOff + 3],
            tMaxY = triBounds[bOff + 4],
            tMaxZ = triBounds[bOff + 5];
        if (tMinX < minX) minX = tMinX;
        if (tMinY < minY) minY = tMinY;
        if (tMinZ < minZ) minZ = tMinZ;
        if (tMaxX > maxX) maxX = tMaxX;
        if (tMaxY > maxY) maxY = tMaxY;
        if (tMaxZ > maxZ) maxZ = tMaxZ;

        final cx = triCentroids[cOff],
            cy = triCentroids[cOff + 1],
            cz = triCentroids[cOff + 2];
        if (cx < cMinX) cMinX = cx;
        if (cy < cMinY) cMinY = cy;
        if (cz < cMinZ) cMinZ = cz;
        if (cx > cMaxX) cMaxX = cx;
        if (cy > cMaxY) cMaxY = cy;
        if (cz > cMaxZ) cMaxZ = cz;
      }

      final nbOff = nodeIdx * 6;
      nodeBounds[nbOff] = minX;
      nodeBounds[nbOff + 1] = minY;
      nodeBounds[nbOff + 2] = minZ;
      nodeBounds[nbOff + 3] = maxX;
      nodeBounds[nbOff + 4] = maxY;
      nodeBounds[nbOff + 5] = maxZ;

      final count = end - start;
      if (count <= maxLeafTriangles) {
        nodeLeftOrStart[nodeIdx] = start;
        nodeRight[nodeIdx] = -1;
        nodeTriCount[nodeIdx] = count;
        return nodeIdx;
      }

      final spanX = cMaxX - cMinX;
      final spanY = cMaxY - cMinY;
      final spanZ = cMaxZ - cMinZ;
      final axis = (spanX >= spanY && spanX >= spanZ)
          ? 0
          : (spanY >= spanZ ? 1 : 2);
      final cMin = axis == 0 ? cMinX : (axis == 1 ? cMinY : cMinZ);
      final cMax = axis == 0 ? cMaxX : (axis == 1 ? cMaxY : cMaxZ);
      final split = (cMin + cMax) * 0.5;

      var mid = start;
      if (cMax - cMin > 1e-7) {
        var i = start;
        var j = end - 1;
        while (i <= j) {
          final t = triOrder[i];
          final c = triCentroids[t * 3 + axis];
          if (c < split) {
            i++;
          } else {
            final tmp = triOrder[i];
            triOrder[i] = triOrder[j];
            triOrder[j] = tmp;
            j--;
          }
        }
        mid = i;
      }
      if (mid <= start || mid >= end) {
        mid = (start + end) >> 1;
      }

      final leftChild = buildNode(start, mid);
      final rightChild = buildNode(mid, end);
      nodeLeftOrStart[nodeIdx] = leftChild;
      nodeRight[nodeIdx] = rightChild;
      nodeTriCount[nodeIdx] = 0;
      return nodeIdx;
    }

    buildNode(0, triCount);

    return TriangleMeshBvh._(
      positions: positions,
      normals: normals,
      uvs: uvs,
      indices: triIndices,
      nodeBounds: Float32List.sublistView(nodeBounds, 0, nodeCount * 6),
      nodeLeftOrStart: Int32List.sublistView(nodeLeftOrStart, 0, nodeCount),
      nodeRight: Int32List.sublistView(nodeRight, 0, nodeCount),
      nodeTriCount: Int32List.sublistView(nodeTriCount, 0, nodeCount),
      triOrder: triOrder,
    );
  }

  /// Flat `x, y, z` vertex positions.
  final Float32List positions;

  /// Optional flat `nx, ny, nz` vertex normals.
  final Float32List? normals;

  /// Optional flat `u, v` vertex texture coordinates.
  final Float32List? uvs;

  /// Triangle vertex indices (`3 * triangleCount`).
  final Uint32List indices;

  final Float32List _nodeBounds;
  final Int32List _nodeLeftOrStart;
  final Int32List _nodeRight;
  final Int32List _nodeTriCount;
  final Uint32List _triOrder;

  /// Total number of triangles in this mesh.
  int get triangleCount => indices.length ~/ 3;

  /// Local-space AABB `(min, max)` of the mesh, or `(zero, zero)` when empty.
  (Vector3 min, Vector3 max) get bounds {
    if (_nodeBounds.isEmpty) {
      return (Vector3.zero(), Vector3.zero());
    }
    return (
      Vector3(_nodeBounds[0], _nodeBounds[1], _nodeBounds[2]),
      Vector3(_nodeBounds[3], _nodeBounds[4], _nodeBounds[5]),
    );
  }

  double? _intersectNodeAabb(int nodeIdx, Ray ray, double maxT) {
    const eps = 1e-6;
    final off = nodeIdx * 6;
    final bminX = _nodeBounds[off] - eps,
        bminY = _nodeBounds[off + 1] - eps,
        bminZ = _nodeBounds[off + 2] - eps;
    final bmaxX = _nodeBounds[off + 3] + eps,
        bmaxY = _nodeBounds[off + 4] + eps,
        bmaxZ = _nodeBounds[off + 5] + eps;

    final ox = ray.origin.x, oy = ray.origin.y, oz = ray.origin.z;
    final dx = ray.direction.x, dy = ray.direction.y, dz = ray.direction.z;

    var tMin = 0.0;
    var tMax = maxT;

    if (dx.abs() < 1e-12) {
      if (ox < bminX || ox > bmaxX) return null;
    } else {
      final inv = 1.0 / dx;
      var t0 = (bminX - ox) * inv;
      var t1 = (bmaxX - ox) * inv;
      if (t0 > t1) {
        final tmp = t0;
        t0 = t1;
        t1 = tmp;
      }
      if (t0 > tMin) tMin = t0;
      if (t1 < tMax) tMax = t1;
      if (tMin > tMax) return null;
    }

    if (dy.abs() < 1e-12) {
      if (oy < bminY || oy > bmaxY) return null;
    } else {
      final inv = 1.0 / dy;
      var t0 = (bminY - oy) * inv;
      var t1 = (bmaxY - oy) * inv;
      if (t0 > t1) {
        final tmp = t0;
        t0 = t1;
        t1 = tmp;
      }
      if (t0 > tMin) tMin = t0;
      if (t1 < tMax) tMax = t1;
      if (tMin > tMax) return null;
    }

    if (dz.abs() < 1e-12) {
      if (oz < bminZ || oz > bmaxZ) return null;
    } else {
      final inv = 1.0 / dz;
      var t0 = (bminZ - oz) * inv;
      var t1 = (bmaxZ - oz) * inv;
      if (t0 > t1) {
        final tmp = t0;
        t0 = t1;
        t1 = tmp;
      }
      if (t0 > tMin) tMin = t0;
      if (t1 < tMax) tMax = t1;
      if (tMin > tMax) return null;
    }

    return tMin;
  }

  /// Finds the closest triangle hit along [localRay] on `(0, maxT]`, or `null`
  /// on a miss.
  LocalMeshHit? raycastClosest(
    Ray localRay, {
    double maxT = double.infinity,
  }) {
    if (_nodeTriCount.isEmpty) return null;
    if (_intersectNodeAabb(0, localRay, maxT) == null) return null;

    var closestT = maxT;
    LocalMeshHit? best;

    final stack = <int>[0];
    while (stack.isNotEmpty) {
      final nodeIdx = stack.removeLast();
      final tBox = _intersectNodeAabb(nodeIdx, localRay, closestT);
      if (tBox == null || tBox > closestT) continue;

      final count = _nodeTriCount[nodeIdx];
      if (count > 0) {
        final start = _nodeLeftOrStart[nodeIdx];
        for (var i = 0; i < count; i++) {
          final triIdx = _triOrder[start + i];
          final hit = _intersectTriangle(localRay, triIdx, closestT);
          if (hit != null && (best == null || hit.t < closestT)) {
            closestT = hit.t;
            best = hit;
          }
        }
        continue;
      }

      final left = _nodeLeftOrStart[nodeIdx];
      final right = _nodeRight[nodeIdx];
      final tLeft = _intersectNodeAabb(left, localRay, closestT);
      final tRight = _intersectNodeAabb(right, localRay, closestT);

      if (tLeft != null && tRight != null) {
        if (tLeft <= tRight) {
          stack.add(right);
          stack.add(left);
        } else {
          stack.add(left);
          stack.add(right);
        }
      } else if (tLeft != null) {
        stack.add(left);
      } else if (tRight != null) {
        stack.add(right);
      }
    }
    return best;
  }

  /// Collects all triangle hits along [localRay] on `(0, maxT]`.
  List<LocalMeshHit> raycastAll(
    Ray localRay, {
    double maxT = double.infinity,
  }) {
    if (_nodeTriCount.isEmpty) return const [];
    if (_intersectNodeAabb(0, localRay, maxT) == null) return const [];

    final hits = <LocalMeshHit>[];
    final stack = <int>[0];
    while (stack.isNotEmpty) {
      final nodeIdx = stack.removeLast();
      final tBox = _intersectNodeAabb(nodeIdx, localRay, maxT);
      if (tBox == null || tBox > maxT) continue;

      final count = _nodeTriCount[nodeIdx];
      if (count > 0) {
        final start = _nodeLeftOrStart[nodeIdx];
        for (var i = 0; i < count; i++) {
          final triIdx = _triOrder[start + i];
          final hit = _intersectTriangle(localRay, triIdx, maxT);
          if (hit != null) {
            hits.add(hit);
          }
        }
        continue;
      }

      stack.add(_nodeRight[nodeIdx]);
      stack.add(_nodeLeftOrStart[nodeIdx]);
    }
    return hits;
  }

  LocalMeshHit? _intersectTriangle(Ray ray, int triIdx, double maxT) {
    final i0 = indices[triIdx * 3];
    final i1 = indices[triIdx * 3 + 1];
    final i2 = indices[triIdx * 3 + 2];
    final p0Off = i0 * 3;
    final p1Off = i1 * 3;
    final p2Off = i2 * 3;
    if (p0Off + 2 >= positions.length ||
        p1Off + 2 >= positions.length ||
        p2Off + 2 >= positions.length) {
      return null;
    }

    final p0x = positions[p0Off],
        p0y = positions[p0Off + 1],
        p0z = positions[p0Off + 2];
    final p1x = positions[p1Off],
        p1y = positions[p1Off + 1],
        p1z = positions[p1Off + 2];
    final p2x = positions[p2Off],
        p2y = positions[p2Off + 1],
        p2z = positions[p2Off + 2];

    final e1x = p1x - p0x, e1y = p1y - p0y, e1z = p1z - p0z;
    final e2x = p2x - p0x, e2y = p2y - p0y, e2z = p2z - p0z;

    final dx = ray.direction.x, dy = ray.direction.y, dz = ray.direction.z;
    // h = dir x e2
    final hx = dy * e2z - dz * e2y;
    final hy = dz * e2x - dx * e2z;
    final hz = dx * e2y - dy * e2x;

    final a = e1x * hx + e1y * hy + e1z * hz;
    if (a > -1e-9 && a < 1e-9) return null;
    final f = 1.0 / a;

    final sx = ray.origin.x - p0x;
    final sy = ray.origin.y - p0y;
    final sz = ray.origin.z - p0z;

    final u = f * (sx * hx + sy * hy + sz * hz);
    if (u < -1e-6 || u > 1.0 + 1e-6) return null;

    // q = s x e1
    final qx = sy * e1z - sz * e1y;
    final qy = sz * e1x - sx * e1z;
    final qz = sx * e1y - sy * e1x;

    final v = f * (dx * qx + dy * qy + dz * qz);
    if (v < -1e-6 || u + v > 1.0 + 1e-6) return null;

    final t = f * (e2x * qx + e2y * qy + e2z * qz);
    if (t <= 1e-6 || t > maxT) return null;

    final w0 = 1.0 - u - v;
    final w1 = u;
    final w2 = v;

    final localPoint = Vector3(
      ray.origin.x + dx * t,
      ray.origin.y + dy * t,
      ray.origin.z + dz * t,
    );

    Vector3 normal;
    final nrms = normals;
    if (nrms != null &&
        p0Off + 2 < nrms.length &&
        p1Off + 2 < nrms.length &&
        p2Off + 2 < nrms.length) {
      normal = Vector3(
        nrms[p0Off] * w0 + nrms[p1Off] * w1 + nrms[p2Off] * w2,
        nrms[p0Off + 1] * w0 + nrms[p1Off + 1] * w1 + nrms[p2Off + 1] * w2,
        nrms[p0Off + 2] * w0 + nrms[p1Off + 2] * w1 + nrms[p2Off + 2] * w2,
      );
      if (normal.length2 > 1e-12) {
        normal.normalize();
      } else {
        normal = Vector3(
          e1y * e2z - e1z * e2y,
          e1z * e2x - e1x * e2z,
          e1x * e2y - e1y * e2x,
        )..normalize();
      }
    } else {
      normal = Vector3(
        e1y * e2z - e1z * e2y,
        e1z * e2x - e1x * e2z,
        e1x * e2y - e1y * e2x,
      );
      if (normal.length2 > 1e-12) normal.normalize();
    }

    Vector2 uvCoord = Vector2.zero();
    final uvList = uvs;
    final uv0Off = i0 * 2, uv1Off = i1 * 2, uv2Off = i2 * 2;
    if (uvList != null &&
        uv0Off + 1 < uvList.length &&
        uv1Off + 1 < uvList.length &&
        uv2Off + 1 < uvList.length) {
      uvCoord = Vector2(
        uvList[uv0Off] * w0 + uvList[uv1Off] * w1 + uvList[uv2Off] * w2,
        uvList[uv0Off + 1] * w0 +
            uvList[uv1Off + 1] * w1 +
            uvList[uv2Off + 1] * w2,
      );
    }

    return LocalMeshHit(
      t: t,
      localPoint: localPoint,
      localNormal: normal,
      uv: uvCoord,
      barycentrics: Vector3(w0, w1, w2),
      triangleIndex: triIdx,
    );
  }
}
