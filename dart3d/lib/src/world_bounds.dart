/// World-space bounds over a document's mesh content.
///
/// `GeometryResource.bounds` are local-space — a node that scales or
/// repositions its mesh moves the rendered result without touching the
/// resource. Camera framing and tap-sizing code that unions the raw
/// resource bounds frames the wrong volume for any document whose
/// nodes carry real transforms (imported glTF hierarchies do).
/// [documentWorldBounds] composes each mesh-bearing node's world
/// transform down the `children` hierarchy and unions the transformed
/// bounds corners — the same volume the renderer draws.
library;

import 'dart:math';

import 'package:vector_math/vector_math.dart';

import 'scene_model.dart';

/// The union of every mesh component's geometry bounds in world space,
/// or null when the document has no bounded mesh content.
///
/// Each node's world transform is its ancestors' composed down from
/// the roots (nodes unreachable from `roots` treat their own transform
/// as world). Bounds corners are transformed individually, so rotation
/// and non-uniform scale still produce a tight union. Invisible
/// subtrees are skipped — they don't draw.
(Vector3 min, Vector3 max)? documentWorldBounds(SceneDocument doc) {
  final perNode = meshNodeWorldBounds(doc);
  final bmin = Vector3.all(double.infinity);
  final bmax = Vector3.all(-double.infinity);
  for (final bounds in perNode.values) {
    Vector3.min(bmin, bounds.$1, bmin);
    Vector3.max(bmax, bounds.$2, bmax);
  }
  return bmin.x.isFinite ? (bmin, bmax) : null;
}

/// The world-space bounds of every mesh-bearing node, keyed by node id.
///
/// Same traversal as [documentWorldBounds] but returns per-node AABBs
/// so callers can reason about which nodes dominate the union.
Map<LocalId, (Vector3 min, Vector3 max)> meshNodeWorldBounds(
  SceneDocument doc,
) {
  final world = _worldTransforms(doc);
  final perNode = <LocalId, (Vector3, Vector3)>{};
  final corner = Vector3.zero();
  for (final node in doc.nodes.values) {
    if (!node.visible) continue;
    final w = world[node.id];
    if (w == null) continue;
    Vector3? nmin, nmax;
    for (final comp in node.components) {
      if (comp.type != 'mesh') continue;
      for (final geoId in _meshGeometryIds(comp)) {
        final resource = doc.resources[geoId];
        if (resource is! GeometryResource) continue;
        // Authored bounds win; procedural primitives derive theirs
        // from the spec — `.fscene` JSON rarely declares `bounds`.
        final b = resource.bounds ?? _proceduralBounds(resource.procedural);
        if (b == null) continue;
        nmin ??= Vector3.all(double.infinity);
        nmax ??= Vector3.all(-double.infinity);
        for (var i = 0; i < 8; i++) {
          corner.setValues(
            i & 1 == 0 ? b.min.x : b.max.x,
            i & 2 == 0 ? b.min.y : b.max.y,
            i & 4 == 0 ? b.min.z : b.max.z,
          );
          w.transform3(corner);
          Vector3.min(nmin, corner, nmin);
          Vector3.max(nmax, corner, nmax);
        }
      }
    }
    if (nmin != null) perNode[node.id] = (nmin, nmax!);
  }
  return perNode;
}

/// Bounds for camera framing — [documentWorldBounds] minus floor-like
/// slabs that would otherwise set the frame. A node counts as a floor
/// slab when its world AABB is wide and flat (vertical size under 25%
/// of its horizontal span) and that span is more than 2.5× the largest
/// non-flat node's — the authored ground plane in a scene document
/// dwarfs the content it carries. When everything is flat (the scene
/// *is* a floor) nothing is excluded.
(Vector3 min, Vector3 max)? documentContentBounds(SceneDocument doc) {
  final perNode = meshNodeWorldBounds(doc);
  if (perNode.isEmpty) return null;

  bool isFlat(Vector3 size) {
    final horizontal = max(size.x, size.z);
    return horizontal > 0 && size.y < horizontal * 0.25;
  }

  var maxNonFlatSpan = 0.0;
  for (final bounds in perNode.values) {
    final size = bounds.$2 - bounds.$1;
    if (!isFlat(size)) {
      maxNonFlatSpan = max(maxNonFlatSpan, max(size.x, size.z));
    }
  }
  if (maxNonFlatSpan == 0) return documentWorldBounds(doc);

  final bmin = Vector3.all(double.infinity);
  final bmax = Vector3.all(-double.infinity);
  for (final bounds in perNode.values) {
    final size = bounds.$2 - bounds.$1;
    if (isFlat(size) &&
        max(size.x, size.z) > maxNonFlatSpan * 2.5) {
      continue; // a floor slab — it draws, but doesn't frame
    }
    Vector3.min(bmin, bounds.$1, bmin);
    Vector3.max(bmax, bounds.$2, bmax);
  }
  return bmin.x.isFinite ? (bmin, bmax) : null;
}

/// Each node's world transform — ancestors composed down from the
/// roots; orphans (no parent reference anywhere) render at the scene
/// root, so they map from identity. A node whose parent is invisible
/// keeps its subtree hidden, matching the realizers.
Map<LocalId, Matrix4> _worldTransforms(SceneDocument doc) {
  final world = <LocalId, Matrix4>{};

  void walk(NodeSpec node, Matrix4 parent) {
    if (world.containsKey(node.id)) return; // a cycle or shared child
    final w = parent * node.transform.toMatrix4();
    world[node.id] = w;
    if (!node.visible) return;
    for (final childId in node.children) {
      final child = doc.nodes[childId];
      if (child != null) walk(child, w);
    }
  }

  for (final root in doc.rootNodes) {
    walk(root, Matrix4.identity());
  }
  final hasParent = <LocalId>{
    for (final node in doc.nodes.values) ...node.children,
  };
  for (final node in doc.nodes.values) {
    if (!hasParent.contains(node.id)) walk(node, Matrix4.identity());
  }
  return world;
}

/// Local-space bounds derived from a procedural descriptor — cuboids
/// span ±extents/2, spheres ±radius, and so on. Null for payloads and
/// unknown shapes.
BoundsSpec? _proceduralBounds(ProceduralGeometry? spec) {
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

/// The geometry refs a mesh component draws — `geometry` for the
/// single-primitive form, `primitives[].geometry` for the multi one.
Iterable<LocalId> _meshGeometryIds(ComponentSpec comp) sync* {
  final single = comp.properties['geometry'];
  if (single is ResourceRefValue) yield single.id;
  final prims = comp.properties['primitives'];
  if (prims is! ListValue) return;
  for (final entry in prims.values) {
    if (entry is! MapValue) continue;
    final ref = entry.values['geometry'];
    if (ref is ResourceRefValue) yield ref.id;
  }
}
