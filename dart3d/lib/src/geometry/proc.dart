/// The expanded dart3d procedural-shape vocabulary (W26).
///
/// Upstream `ProceduralGeometry` (scene-0.3.0) is a sealed five-type
/// hierarchy — cuboid/plane/sphere/torus/icosphere — so dart3d-specific
/// geometry can't subclass it. Instead the new shapes ride the wire as
/// a `d3:procMesh` component whose `properties` bag carries the shape
/// name and parameters; upstream's generic component codec passes it
/// through the manifest, diffs, and subtree streams untouched. The
/// spec types below are the typed Dart face of that bag: each knows
/// its wire `shape` name, its parameter map, its local-space bounds,
/// and a CPU-side mesh generator mirroring the native decoders.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

import '../scene_model.dart';
import 'limits.dart';
import 'mesh_data.dart';
import 'paths.dart';

export 'limits.dart';

/// The `d3:procMesh` component type tag.
const kD3ProcMeshType = 'd3:procMesh';

/// The `d3:instances` component type tag.
const kD3InstancesType = 'd3:instances';

/// One entry in the dart3d shape vocabulary — a compact, typed value
/// describing a runtime-built mesh.
///
/// `shape` is the wire name the native decoders switch on; `props` is
/// the parameter map merged into the component's `properties`;
/// [bounds] is the local-space AABB (used for world-bounds and the
/// culling box); [build] produces the CPU mesh for tests and tools.
abstract class D3Proc {
  /// The wire shape name.
  String get shape;

  /// Wire parameters (merged into the `d3:procMesh` property bag).
  Map<String, PropertyValue> get props;

  /// Local-space bounds of the generated mesh.
  BoundsSpec get bounds;

  /// Generates the mesh in doc space (z unmirrored — the natives
  /// mirror at decode like every other vertex source).
  D3MeshData build();
}

/// Builds the `d3:procMesh` component spec for [proc], optionally
/// bound to material resource [material].
ComponentSpec d3ProcMeshComponent(D3Proc proc, {LocalId? material}) =>
    ComponentSpec(
      kD3ProcMeshType,
      properties: {
        'shape': StringValue(proc.shape),
        if (material != null) 'material': ResourceRefValue(material),
        ...proc.props,
      },
    );

/// The dart3d primitive vocabulary: every value a `d3:procMesh`
/// `shape` or `d3:instances` `shape` may take, including the five
/// upstream shapes so instancing can reference them by name.
const kD3ProcShapes = {
  'cuboid',
  'plane',
  'sphere',
  'torus',
  'icosphere',
  'cylinder',
  'cone',
  'capsule',
  'disc',
  'tube',
  'ribbon',
  'polyline',
  'lineSegments',
  'billboard',
};

// ---------------------------------------------------------------------------
// Primitives — five upstream shapes plus the W26 additions.
// ---------------------------------------------------------------------------

/// A box of the given [extents] — the upstream cuboid, rideable on
/// `d3:procMesh`/`d3:instances` for vocabulary symmetry.
final class D3CuboidProc extends D3Proc {
  /// Creates a cuboid spec.
  D3CuboidProc({required this.extents, this.debugColors = false});

  /// The box dimensions.
  final Vector3 extents;

  /// Whether each corner carries a distinct debug color.
  final bool debugColors;

  @override
  String get shape => 'cuboid';

  @override
  Map<String, PropertyValue> get props => {
    'extents': Vec3Value(extents),
    if (debugColors) 'debugColors': const BoolValue(true),
  };

  @override
  BoundsSpec get bounds => BoundsSpec(min: -extents / 2, max: extents / 2);

  @override
  D3MeshData build() => buildCuboid(extents, debugColors: debugColors);
}

/// A flat plane in the XZ plane.
final class D3PlaneProc extends D3Proc {
  /// Creates a plane spec.
  D3PlaneProc({
    this.width = 1.0,
    this.depth = 1.0,
    this.segmentsX = 1,
    this.segmentsZ = 1,
  });

  /// Size along X.
  final double width;

  /// Size along Z.
  final double depth;

  /// Grid subdivisions along X.
  final int segmentsX;

  /// Grid subdivisions along Z.
  final int segmentsZ;

  @override
  String get shape => 'plane';

  @override
  Map<String, PropertyValue> get props => {
    'width': DoubleValue(width),
    'depth': DoubleValue(depth),
    'segmentsX': IntValue(segmentsX),
    'segmentsZ': IntValue(segmentsZ),
  };

  @override
  BoundsSpec get bounds => BoundsSpec(
    min: Vector3(-width / 2, 0, -depth / 2),
    max: Vector3(width / 2, 0, depth / 2),
  );

  @override
  D3MeshData build() => buildPlane(
    width: width,
    depth: depth,
    segmentsX: segmentsX,
    segmentsZ: segmentsZ,
  );
}

/// A UV sphere.
final class D3SphereProc extends D3Proc {
  /// Creates a sphere spec.
  D3SphereProc({this.radius = 0.5, this.segments = 32, this.rings = 16});

  /// The sphere radius.
  final double radius;

  /// Divisions around the equator.
  final int segments;

  /// Divisions from pole to pole.
  final int rings;

  @override
  String get shape => 'sphere';

  @override
  Map<String, PropertyValue> get props => {
    'radius': DoubleValue(radius),
    'segments': IntValue(segments),
    'rings': IntValue(rings),
  };

  @override
  BoundsSpec get bounds => _cubeBounds(radius);

  @override
  D3MeshData build() =>
      buildSphere(radius: radius, segments: segments, rings: rings);
}

/// A torus centered on the origin around the Y axis.
final class D3TorusProc extends D3Proc {
  /// Creates a torus spec.
  D3TorusProc({
    this.radius = 0.5,
    this.tubeRadius = 0.15,
    this.radialSegments = 32,
    this.tubularSegments = 16,
  });

  /// Distance from the origin to the tube center.
  final double radius;

  /// Tube radius.
  final double tubeRadius;

  /// Divisions around the main ring.
  final int radialSegments;

  /// Divisions around the tube.
  final int tubularSegments;

  @override
  String get shape => 'torus';

  @override
  Map<String, PropertyValue> get props => {
    'radius': DoubleValue(radius),
    'tubeRadius': DoubleValue(tubeRadius),
    'radialSegments': IntValue(radialSegments),
    'tubularSegments': IntValue(tubularSegments),
  };

  @override
  BoundsSpec get bounds => BoundsSpec(
    min: Vector3(-(radius + tubeRadius), -tubeRadius, -(radius + tubeRadius)),
    max: Vector3(radius + tubeRadius, tubeRadius, radius + tubeRadius),
  );

  @override
  D3MeshData build() => buildTorus(
    radius: radius,
    tubeRadius: tubeRadius,
    radialSegments: radialSegments,
    tubularSegments: tubularSegments,
  );
}

/// A geodesic sphere made by subdividing an icosahedron — the real
/// thing, replacing the UV-sphere stand-in the natives previously
/// realized for `icosphere`.
final class D3IcosphereProc extends D3Proc {
  /// Creates an icosphere spec.
  D3IcosphereProc({this.radius = 0.5, this.subdivisions = 2});

  /// Sphere radius.
  final double radius;

  /// Recursive triangle subdivision count.
  final int subdivisions;

  @override
  String get shape => 'icosphere';

  @override
  Map<String, PropertyValue> get props => {
    'radius': DoubleValue(radius),
    'subdivisions': IntValue(subdivisions),
  };

  @override
  BoundsSpec get bounds => _cubeBounds(radius);

  @override
  D3MeshData build() =>
      buildIcosphere(radius: radius, subdivisions: subdivisions);
}

/// A cylinder along the Y axis with independent end radii — with
/// [topRadius] `0` it generates the cone's sloped side correctly.
final class D3CylinderProc extends D3Proc {
  /// Creates a cylinder spec.
  D3CylinderProc({
    this.bottomRadius = 0.5,
    this.topRadius = 0.5,
    this.height = 1.0,
    this.radialSegments = 32,
    this.heightSegments = 1,
    this.bottomCap = true,
    this.topCap = true,
  });

  /// Radius at `y = -height/2`.
  final double bottomRadius;

  /// Radius at `y = +height/2`.
  final double topRadius;

  /// Height along Y.
  final double height;

  /// Divisions around the circumference.
  final int radialSegments;

  /// Divisions along the side.
  final int heightSegments;

  /// Whether the bottom disc is closed.
  final bool bottomCap;

  /// Whether the top disc is closed.
  final bool topCap;

  @override
  String get shape => 'cylinder';

  @override
  Map<String, PropertyValue> get props => {
    'bottomRadius': DoubleValue(bottomRadius),
    'topRadius': DoubleValue(topRadius),
    'height': DoubleValue(height),
    'radialSegments': IntValue(radialSegments),
    'heightSegments': IntValue(heightSegments),
    if (!bottomCap) 'bottomCap': const BoolValue(false),
    if (!topCap) 'topCap': const BoolValue(false),
  };

  @override
  BoundsSpec get bounds => BoundsSpec(
    min: Vector3(
      -math.max(bottomRadius, topRadius),
      -height / 2,
      -math.max(bottomRadius, topRadius),
    ),
    max: Vector3(
      math.max(bottomRadius, topRadius),
      height / 2,
      math.max(bottomRadius, topRadius),
    ),
  );

  @override
  D3MeshData build() => buildCylinder(
    bottomRadius: bottomRadius,
    topRadius: topRadius,
    height: height,
    radialSegments: radialSegments,
    heightSegments: heightSegments,
    bottomCap: bottomCap,
    topCap: topCap,
  );
}

/// A cone along the Y axis — a cylinder whose top radius is zero,
/// exposed under its own wire name.
final class D3ConeProc extends D3Proc {
  /// Creates a cone spec.
  D3ConeProc({
    this.radius = 0.5,
    this.height = 1.0,
    this.radialSegments = 32,
    this.heightSegments = 1,
    this.bottomCap = true,
  });

  /// Base radius at `y = -height/2`.
  final double radius;

  /// Height along Y.
  final double height;

  /// Divisions around the circumference.
  final int radialSegments;

  /// Divisions along the side.
  final int heightSegments;

  /// Whether the base disc is closed.
  final bool bottomCap;

  @override
  String get shape => 'cone';

  @override
  Map<String, PropertyValue> get props => {
    'radius': DoubleValue(radius),
    'height': DoubleValue(height),
    'radialSegments': IntValue(radialSegments),
    'heightSegments': IntValue(heightSegments),
    if (!bottomCap) 'bottomCap': const BoolValue(false),
  };

  @override
  BoundsSpec get bounds => BoundsSpec(
    min: Vector3(-radius, -height / 2, -radius),
    max: Vector3(radius, height / 2, radius),
  );

  @override
  D3MeshData build() => buildCylinder(
    bottomRadius: radius,
    topRadius: 0.0,
    height: height,
    radialSegments: radialSegments,
    heightSegments: heightSegments,
    bottomCap: bottomCap,
    topCap: false,
  );
}

/// A capsule along the Y axis: a cylinder of mid-section length
/// [height] closed by hemispherical caps of [radius]. Total height is
/// `height + 2 * radius`.
final class D3CapsuleProc extends D3Proc {
  /// Creates a capsule spec.
  D3CapsuleProc({
    this.radius = 0.5,
    this.height = 1.0,
    this.radialSegments = 32,
    this.capRings = 8,
  });

  /// Cap and mid-section radius.
  final double radius;

  /// Cylindrical mid-section length.
  final double height;

  /// Divisions around the circumference.
  final int radialSegments;

  /// Rings per hemisphere cap.
  final int capRings;

  @override
  String get shape => 'capsule';

  @override
  Map<String, PropertyValue> get props => {
    'radius': DoubleValue(radius),
    'height': DoubleValue(height),
    'radialSegments': IntValue(radialSegments),
    'capRings': IntValue(capRings),
  };

  @override
  BoundsSpec get bounds => BoundsSpec(
    min: Vector3(-radius, -(height / 2 + radius), -radius),
    max: Vector3(radius, height / 2 + radius, radius),
  );

  @override
  D3MeshData build() => buildCapsule(
    radius: radius,
    height: height,
    radialSegments: radialSegments,
    capRings: capRings,
  );
}

/// A filled disc in the XZ plane facing +Y.
final class D3DiscProc extends D3Proc {
  /// Creates a disc spec.
  D3DiscProc({this.radius = 0.5, this.segments = 32});

  /// Disc radius.
  final double radius;

  /// Rim divisions.
  final int segments;

  @override
  String get shape => 'disc';

  @override
  Map<String, PropertyValue> get props => {
    'radius': DoubleValue(radius),
    'segments': IntValue(segments),
  };

  @override
  BoundsSpec get bounds => BoundsSpec(
    min: Vector3(-radius, 0, -radius),
    max: Vector3(radius, 0, radius),
  );

  @override
  D3MeshData build() => buildDisc(radius: radius, segments: segments);
}

/// A round cross-section swept along a Catmull-Rom path through
/// [points]. [closed] repeats the endpoint control points so the tube
/// loops.
final class D3TubeProc extends D3Proc {
  /// Creates a tube spec.
  D3TubeProc({
    required List<Vector3> points,
    this.radius = 0.5,
    this.radialSegments = 12,
    this.stations = 64,
    this.caps = true,
    this.closed = false,
  }) : points = <Vector3>[for (final p in points) p.clone()] {
    if (this.points.length < 2) {
      throw ArgumentError('A tube needs at least two points');
    }
  }

  /// Path control points (copied).
  final List<Vector3> points;

  /// Tube radius.
  final double radius;

  /// Faces around the circumference.
  final int radialSegments;

  /// Cross-sections sampled along the path.
  final int stations;

  /// Whether the two ends close with discs. Ignored when [closed] — a
  /// loop has no ends, and caps at the seam would intersect the tube.
  final bool caps;

  /// Whether the path closes into a loop.
  final bool closed;

  /// The path the sweep follows — closed wraps the point list.
  ScenePath get path {
    final pts = closed ? <Vector3>[...points, points.first] : points;
    return CatmullRomPath(pts);
  }

  @override
  String get shape => 'tube';

  @override
  Map<String, PropertyValue> get props => {
    'points': ListValue([for (final p in points) Vec3Value(p)]),
    'radius': DoubleValue(radius),
    'radialSegments': IntValue(radialSegments),
    'stations': IntValue(stations),
    if (!caps) 'caps': const BoolValue(false),
    if (closed) 'closed': const BoolValue(true),
  };

  @override
  BoundsSpec get bounds => _padded(d3CatmullRomBounds(points, closed), radius);

  @override
  D3MeshData build() => buildTube(
    path,
    radius: radius,
    radialSegments: radialSegments,
    stations: stations,
    caps: caps && !closed,
  );
}

/// A flat strip of constant [width] swept along a Catmull-Rom path —
/// the route-ribbon primitive.
final class D3RibbonProc extends D3Proc {
  /// Creates a ribbon spec.
  D3RibbonProc({
    required List<Vector3> points,
    this.width = 1.0,
    this.stations = 64,
    this.up,
    this.closed = false,
  }) : points = <Vector3>[for (final p in points) p.clone()] {
    if (this.points.length < 2) {
      throw ArgumentError('A ribbon needs at least two points');
    }
  }

  /// Path control points (copied).
  final List<Vector3> points;

  /// Strip width.
  final double width;

  /// Cross-sections sampled along the path.
  final int stations;

  /// Reference up direction (default +Y): the strip stays
  /// perpendicular to the path as seen from above.
  final Vector3? up;

  /// Whether the path closes into a loop.
  final bool closed;

  /// The path the sweep follows.
  ScenePath get path =>
      CatmullRomPath(closed ? <Vector3>[...points, points.first] : points);

  @override
  String get shape => 'ribbon';

  @override
  Map<String, PropertyValue> get props => {
    'points': ListValue([for (final p in points) Vec3Value(p)]),
    'width': DoubleValue(width),
    'stations': IntValue(stations),
    if (up != null) 'up': Vec3Value(up!),
    if (closed) 'closed': const BoolValue(true),
  };

  @override
  BoundsSpec get bounds =>
      _padded(d3CatmullRomBounds(points, closed), width / 2);

  @override
  D3MeshData build() => buildRibbon(
    path,
    width: width,
    stations: stations,
    up: up ?? Vector3(0.0, 1.0, 0.0),
  );
}

/// A camera-facing polyline of constant screen or world [width].
///
/// Solid by default; [dashPattern] `(on, off)` arc lengths split it
/// into dashes. [colors] and [widths] may carry per-point values.
/// Natives expand the ribbon toward the active camera each frame.
final class D3PolylineProc extends D3Proc {
  /// Creates a polyline spec.
  D3PolylineProc({
    required List<Vector3> points,
    this.width = 1.0,
    this.widthInPixels = false,
    this.colors,
    this.widths,
    this.dashPattern,
    this.closed = false,
    this.roundCaps = false,
  }) : points = <Vector3>[for (final p in points) p.clone()] {
    if (this.points.length < 2) {
      throw ArgumentError('A polyline needs at least two points');
    }
  }

  /// Line points in order (copied).
  final List<Vector3> points;

  /// Line width — world units, or pixels when [widthInPixels].
  final double width;

  /// Whether [width] is in screen pixels.
  final bool widthInPixels;

  /// Optional per-point rgba colors (same length as [points]).
  final List<List<double>>? colors;

  /// Optional per-point widths (same length as [points]).
  final List<double>? widths;

  /// `(on, off)` dash arc lengths — null for a solid line.
  final (double, double)? dashPattern;

  /// Whether the path closes into a loop.
  final bool closed;

  /// Whether end caps round rather than butt.
  final bool roundCaps;

  /// The points as a straight-segment path.
  ScenePath get path =>
      PolylinePath(closed ? <Vector3>[...points, points.first] : points);

  @override
  String get shape => 'polyline';

  @override
  Map<String, PropertyValue> get props => {
    'points': ListValue([for (final p in points) Vec3Value(p)]),
    'width': DoubleValue(width),
    if (widthInPixels) 'widthInPixels': const BoolValue(true),
    if (colors != null)
      'colors': ListValue([
        for (final c in colors!)
          ColorValue(c[0], c[1], c[2], c.length > 3 ? c[3] : 1.0),
      ]),
    if (widths != null)
      'widths': ListValue([for (final w in widths!) DoubleValue(w)]),
    if (dashPattern != null)
      'dashes': Vec2Value(Vector2(dashPattern!.$1, dashPattern!.$2)),
    if (closed) 'closed': const BoolValue(true),
    if (roundCaps) 'caps': const StringValue('round'),
  };

  @override
  BoundsSpec get bounds {
    var maxW = width;
    if (widths != null) {
      for (final w in widths!) {
        if (w > maxW) maxW = w;
      }
    }
    final b = computeD3Bounds(
      Float32List.fromList([
        for (final p in points) ...[p.x, p.y, p.z],
      ]),
    );
    final half = maxW / 2;
    return BoundsSpec(
      min: b.min - Vector3.all(half),
      max: b.max + Vector3.all(half),
    );
  }

  @override
  D3MeshData build() => buildPolyline(
    points,
    width: width,
    colors: colors,
    widths: widths,
    dashPattern: dashPattern,
    closed: closed,
  );
}

/// Independent camera-facing quads, one per point pair — thick line
/// segments without join stitching.
final class D3LineSegmentsProc extends D3Proc {
  /// Creates a line-segments spec. [points] must have even length —
  /// each pair is one segment.
  D3LineSegmentsProc({
    required List<Vector3> points,
    this.width = 1.0,
    this.widthInPixels = false,
    this.colors,
  }) : points = <Vector3>[for (final p in points) p.clone()] {
    if (this.points.length < 2 || this.points.length % 2 != 0) {
      throw ArgumentError(
        'Line segments need an even number of points, at least two',
      );
    }
  }

  /// Segment endpoints, two per segment (copied).
  final List<Vector3> points;

  /// Quad width — world units, or pixels when [widthInPixels].
  final double width;

  /// Whether [width] is in screen pixels.
  final bool widthInPixels;

  /// Optional per-segment rgba colors — one per point *pair*, applied
  /// to both endpoints of that segment. rgb entries get alpha 1.
  final List<List<double>>? colors;

  @override
  String get shape => 'lineSegments';

  @override
  Map<String, PropertyValue> get props => {
    'points': ListValue([for (final p in points) Vec3Value(p)]),
    'width': DoubleValue(width),
    if (widthInPixels) 'widthInPixels': const BoolValue(true),
    if (colors != null)
      'colors': ListValue([
        for (final c in colors!)
          ColorValue(c[0], c[1], c[2], c.length > 3 ? c[3] : 1.0),
      ]),
  };

  @override
  BoundsSpec get bounds {
    final b = computeD3Bounds(
      Float32List.fromList([
        for (final p in points) ...[p.x, p.y, p.z],
      ]),
    );
    final half = width / 2;
    return BoundsSpec(
      min: b.min - Vector3.all(half),
      max: b.max + Vector3.all(half),
    );
  }

  @override
  D3MeshData build() => buildLineSegments(points, width: width, colors: colors);
}

/// A camera-facing quad centered on the node's position — the sprite
/// primitive. [size] is the world-space extent, [facing] selects the
/// orientation mode.
final class D3BillboardProc extends D3Proc {
  /// Creates a billboard spec.
  D3BillboardProc({
    Vector2? size,
    this.facing = 'spherical',
    this.rotation = 0.0,
    this.color = const [1.0, 1.0, 1.0, 1.0],
  }) : size = size ?? Vector2(1.0, 1.0);

  /// Quad size (width, height) in world units.
  final Vector2 size;

  /// Facing mode: `spherical` (face the camera fully), `axisY`
  /// (rotate about Y only), `screen` (camera plane).
  final String facing;

  /// In-plane rotation in radians.
  final double rotation;

  /// Quad color multiplied into the material.
  final List<double> color;

  @override
  String get shape => 'billboard';

  @override
  Map<String, PropertyValue> get props => {
    'size': Vec2Value(size),
    'facing': StringValue(facing),
    if (rotation != 0) 'rotation': DoubleValue(rotation),
    'color': ColorValue(color[0], color[1], color[2], color[3]),
  };

  @override
  BoundsSpec get bounds {
    // The quad faces the camera and spins by [rotation], so any corner
    // can point along any axis: the half-diagonal is the conservative
    // orientation-independent radius.
    final half = d3BillboardRadius(size.x, size.y);
    return BoundsSpec(min: Vector3.all(-half), max: Vector3.all(half));
  }

  @override
  D3MeshData build() =>
      buildBillboard(size: size, rotation: rotation, color: color);
}

// ---------------------------------------------------------------------------
// Component → spec decode (world bounds + tests).
// ---------------------------------------------------------------------------

/// The local-space bounds a `d3:procMesh` component realizes, or null
/// for an unrecognized shape.
BoundsSpec? d3ProcComponentBounds(ComponentSpec comp) {
  final shape = comp.properties['shape'];
  if (shape is! StringValue) return null;
  return d3ProcShapeBounds(shape.value, comp.properties);
}

/// Bounds for a shape name + raw property map — the decoder-side
/// bounds table, shared by `d3:procMesh` and `d3:instances` (whose
/// inline `shape` uses the same parameter names).
BoundsSpec? d3ProcShapeBounds(String shape, Map<String, PropertyValue> props) {
  double d(String k, double def) => switch (props[k]) {
    DoubleValue(:final value) => value,
    IntValue(:final value) => value.toDouble(),
    _ => def,
  };
  List<Vector3> points() => switch (props['points']) {
    ListValue(:final values) => [
      for (final v in values)
        if (v is Vec3Value) v.value else Vector3.zero(),
    ],
    _ => const <Vector3>[],
  };
  double width() {
    var w = d('width', 1.0);
    final widths = props['widths'];
    if (widths is ListValue) {
      for (final v in widths.values) {
        if (v is DoubleValue && v.value > w) w = v.value;
      }
    }
    return w;
  }

  bool flag(String k) => switch (props[k]) {
    BoolValue(:final value) => value,
    _ => false,
  };

  BoundsSpec curveBounds(double pad) =>
      _padded(d3CatmullRomBounds(points(), flag('closed')), pad);

  BoundsSpec pointBounds(double pad) {
    final pts = points();
    if (pts.isEmpty)
      return BoundsSpec(min: Vector3.zero(), max: Vector3.zero());
    final b = computeD3Bounds(
      Float32List.fromList([
        for (final p in pts) ...[p.x, p.y, p.z],
      ]),
    );
    return BoundsSpec(
      min: b.min - Vector3.all(pad),
      max: b.max + Vector3.all(pad),
    );
  }

  return switch (shape) {
    'cuboid' => switch (props['extents']) {
      Vec3Value(:final value) => BoundsSpec(min: -value / 2, max: value / 2),
      _ => _cubeBounds(0.5),
    },
    'plane' => BoundsSpec(
      min: Vector3(-d('width', 1) / 2, 0, -d('depth', 1) / 2),
      max: Vector3(d('width', 1) / 2, 0, d('depth', 1) / 2),
    ),
    'sphere' || 'icosphere' => _cubeBounds(d('radius', 0.5)),
    'torus' => () {
      final r = d('radius', 0.5) + d('tubeRadius', 0.15);
      return BoundsSpec(
        min: Vector3(-r, -d('tubeRadius', 0.15), -r),
        max: Vector3(r, d('tubeRadius', 0.15), r),
      );
    }(),
    'cylinder' => () {
      final r = math.max(d('bottomRadius', 0.5), d('topRadius', 0.5));
      final h = d('height', 1.0) / 2;
      return BoundsSpec(min: Vector3(-r, -h, -r), max: Vector3(r, h, r));
    }(),
    'cone' => () {
      final r = d('radius', 0.5);
      final h = d('height', 1.0) / 2;
      return BoundsSpec(min: Vector3(-r, -h, -r), max: Vector3(r, h, r));
    }(),
    'capsule' => () {
      final r = d('radius', 0.5);
      final h = d('height', 1.0) / 2 + r;
      return BoundsSpec(min: Vector3(-r, -h, -r), max: Vector3(r, h, r));
    }(),
    'disc' => () {
      final r = d('radius', 0.5);
      return BoundsSpec(min: Vector3(-r, 0, -r), max: Vector3(r, 0, r));
    }(),
    'tube' => curveBounds(d('radius', 0.5)),
    'ribbon' => curveBounds(d('width', 1.0) / 2),
    'polyline' => pointBounds(width() / 2),
    'lineSegments' => pointBounds(d('width', 1.0) / 2),
    'billboard' => () {
      final size = props['size'];
      final half = size is Vec2Value
          ? d3BillboardRadius(size.value.x, size.value.y)
          : d3BillboardRadius(1, 1);
      return BoundsSpec(min: Vector3.all(-half), max: Vector3.all(half));
    }(),
    _ => null,
  };
}

BoundsSpec _cubeBounds(double r) =>
    BoundsSpec(min: Vector3.all(-r), max: Vector3.all(r));

BoundsSpec _padded(BoundsSpec b, double pad) =>
    BoundsSpec(min: b.min - Vector3.all(pad), max: b.max + Vector3.all(pad));

/// The conservative radius of a camera-facing `w × h` quad centered on
/// its anchor: half its diagonal, which covers every facing and
/// in-plane rotation.
double d3BillboardRadius(double w, double h) => math.sqrt(w * w + h * h) / 2;

/// A conservative AABB for the uniform Catmull-Rom curve through
/// [points] (closed appends the first point, matching the sweep
/// paths). Each segment `p1→p2` is exactly the cubic Bézier with
/// controls `p1`, `p1 + (p2 − p0)/6`, `p2 − (p3 − p1)/6`, `p2`, which
/// lies inside those controls' convex hull — so their box bounds the
/// curve's overshoot (a control-point-only box does not: `0,1,1,0`
/// peaks at 1.125). Endpoint controls repeat like `CatmullRomPath`.
BoundsSpec d3CatmullRomBounds(List<Vector3> points, bool closed) {
  final pts = closed && points.isNotEmpty
      ? <Vector3>[...points, points.first]
      : points;
  if (pts.isEmpty) return BoundsSpec(min: Vector3.zero(), max: Vector3.zero());
  final last = pts.length - 1;
  Vector3 at(int i) => pts[i < 0 ? 0 : (i > last ? last : i)];
  final hull = <double>[];
  void add(Vector3 v) => hull.addAll([v.x, v.y, v.z]);
  add(pts.first);
  for (var s = 0; s < last; s++) {
    final p0 = at(s - 1), p1 = at(s), p2 = at(s + 1), p3 = at(s + 2);
    add(p1 + (p2 - p0) / 6.0);
    add(p2 - (p3 - p1) / 6.0);
    add(p2);
  }
  return computeD3Bounds(Float32List.fromList(hull));
}

// ---------------------------------------------------------------------------
// Generators — CPU mirrors of the native decoders.
// ---------------------------------------------------------------------------

/// A box — 24 vertices (four per face so normals stay axis-aligned).
/// [debugColors] keys each vertex color to its corner: the position's
/// sign bits map to rgb (a centered box gives the eight corners
/// black/red/green/yellow/blue/magenta/cyan/white).
D3MeshData buildCuboid(Vector3 extents, {bool debugColors = false}) {
  final b = D3MeshBuilder();
  final hx = extents.x / 2;
  final hy = extents.y / 2;
  final hz = extents.z / 2;
  List<double>? cornerColor(Vector3 v) => debugColors
      ? [v.x >= 0 ? 1.0 : 0.0, v.y >= 0 ? 1.0 : 0.0, v.z >= 0 ? 1.0 : 0.0, 1.0]
      : null;
  void face(Vector3 n, Vector3 v0, Vector3 v1, Vector3 v2, Vector3 v3) {
    final base = b.vertexCount;
    b.emit(v0, n: n, uv: Vector2(0, 1), color: cornerColor(v0));
    b.emit(v1, n: n, uv: Vector2(1, 1), color: cornerColor(v1));
    b.emit(v2, n: n, uv: Vector2(0, 0), color: cornerColor(v2));
    b.emit(v3, n: n, uv: Vector2(1, 0), color: cornerColor(v3));
    b.quad(base, base + 1, base + 2, base + 3);
  }

  face(
    Vector3(0, 0, 1),
    Vector3(-hx, -hy, hz),
    Vector3(hx, -hy, hz),
    Vector3(-hx, hy, hz),
    Vector3(hx, hy, hz),
  );
  face(
    Vector3(0, 0, -1),
    Vector3(hx, -hy, -hz),
    Vector3(-hx, -hy, -hz),
    Vector3(hx, hy, -hz),
    Vector3(-hx, hy, -hz),
  );
  face(
    Vector3(1, 0, 0),
    Vector3(hx, -hy, hz),
    Vector3(hx, -hy, -hz),
    Vector3(hx, hy, hz),
    Vector3(hx, hy, -hz),
  );
  face(
    Vector3(-1, 0, 0),
    Vector3(-hx, -hy, -hz),
    Vector3(-hx, -hy, hz),
    Vector3(-hx, hy, -hz),
    Vector3(-hx, hy, hz),
  );
  face(
    Vector3(0, 1, 0),
    Vector3(-hx, hy, hz),
    Vector3(hx, hy, hz),
    Vector3(-hx, hy, -hz),
    Vector3(hx, hy, -hz),
  );
  face(
    Vector3(0, -1, 0),
    Vector3(-hx, -hy, -hz),
    Vector3(hx, -hy, -hz),
    Vector3(-hx, -hy, hz),
    Vector3(hx, -hy, hz),
  );
  return b.build();
}

/// An XZ grid plane, front face toward +Y (the winding runs the z row
/// ahead of the x column so the geometric normal agrees with the
/// `n: (0,1,0)` attribute — same outward-CCW doc convention the other
/// generators use).
D3MeshData buildPlane({
  required double width,
  required double depth,
  required int segmentsX,
  required int segmentsZ,
}) {
  // Clamped like the native `seg()` decode (min 1) plus the shared cap
  // — zero used to divide by zero into NaN positions.
  segmentsX = d3ClampSegments(segmentsX, 1);
  segmentsZ = d3ClampSegments(segmentsZ, 1);
  final b = D3MeshBuilder();
  for (var z = 0; z <= segmentsZ; z++) {
    for (var x = 0; x <= segmentsX; x++) {
      b.emit(
        Vector3(
          (x / segmentsX - 0.5) * width,
          0,
          (z / segmentsZ - 0.5) * depth,
        ),
        n: Vector3(0, 1, 0),
        uv: Vector2(x / segmentsX, z / segmentsZ),
      );
    }
  }
  final cols = segmentsX + 1;
  for (var z = 0; z < segmentsZ; z++) {
    for (var x = 0; x < segmentsX; x++) {
      final a = z * cols + x;
      b.quad(a, a + cols, a + 1, a + cols + 1);
    }
  }
  return b.build();
}

/// A UV sphere — rows run pole to pole, outward-wound.
D3MeshData buildSphere({
  required double radius,
  required int segments,
  required int rings,
}) {
  segments = d3ClampSegments(segments, 1);
  rings = d3ClampSegments(rings, 1);
  final b = D3MeshBuilder();
  final cols = segments + 1;
  for (var r = 0; r <= rings; r++) {
    final lat = math.pi * r / rings;
    final sinLat = math.sin(lat);
    final cosLat = math.cos(lat);
    for (var s = 0; s <= segments; s++) {
      final lon = 2 * math.pi * s / segments;
      final n = Vector3(sinLat * math.cos(lon), cosLat, sinLat * math.sin(lon));
      b.emit(n * radius, n: n, uv: Vector2(s / segments, r / rings));
    }
  }
  for (var r = 0; r < rings; r++) {
    for (var s = 0; s < segments; s++) {
      final a = r * cols + s;
      b.quad(a, a + 1, a + cols, a + cols + 1);
    }
  }
  return b.build();
}

/// A torus around Y.
D3MeshData buildTorus({
  required double radius,
  required double tubeRadius,
  required int radialSegments,
  required int tubularSegments,
}) {
  radialSegments = d3ClampSegments(radialSegments, 1);
  tubularSegments = d3ClampSegments(tubularSegments, 1);
  final b = D3MeshBuilder();
  final cols = tubularSegments + 1;
  for (var i = 0; i <= radialSegments; i++) {
    final u = 2 * math.pi * i / radialSegments;
    final cosU = math.cos(u);
    final sinU = math.sin(u);
    for (var j = 0; j <= tubularSegments; j++) {
      final v = 2 * math.pi * j / tubularSegments;
      final cosV = math.cos(v);
      final sinV = math.sin(v);
      final ringRadius = radius + tubeRadius * cosV;
      b.emit(
        Vector3(ringRadius * cosU, tubeRadius * sinV, ringRadius * sinU),
        n: Vector3(cosV * cosU, sinV, cosV * sinU),
        uv: Vector2(j / tubularSegments, i / radialSegments),
      );
    }
  }
  for (var i = 0; i < radialSegments; i++) {
    for (var j = 0; j < tubularSegments; j++) {
      final a = i * cols + j;
      b.quad(a, a + 1, a + cols, a + cols + 1);
    }
  }
  return b.build();
}

/// A cylinder/cone along Y with optional end caps — ported from
/// upstream `buildCylinderArrays` (sloped side normals, apex-fan
/// handling for collapsed rows, flip-wound bottom cap).
D3MeshData buildCylinder({
  required double bottomRadius,
  required double topRadius,
  required double height,
  required int radialSegments,
  required int heightSegments,
  required bool bottomCap,
  required bool topCap,
}) {
  if (radialSegments < 3) {
    throw ArgumentError('A cylinder needs at least three radial segments');
  }
  if (heightSegments < 1) {
    throw ArgumentError('A cylinder needs at least one height segment');
  }
  if (bottomRadius < 0 || topRadius < 0) {
    throw ArgumentError('Cylinder radii cannot be negative');
  }
  if (bottomRadius == 0 && topRadius == 0) {
    throw ArgumentError(
      'A cylinder needs a nonzero radius on at least one end',
    );
  }
  radialSegments = d3ClampSegments(radialSegments, 3);
  heightSegments = d3ClampSegments(heightSegments, 1);

  final b = D3MeshBuilder();
  final slopeY = bottomRadius - topRadius;
  final columns = radialSegments + 1;
  for (var r = 0; r <= heightSegments; r++) {
    final t = r / heightSegments;
    final y = height / 2 - height * t;
    final radius = topRadius + (bottomRadius - topRadius) * t;
    for (var s = 0; s <= radialSegments; s++) {
      final theta = 2 * math.pi * s / radialSegments;
      final cos = math.cos(theta);
      final sin = math.sin(theta);
      final normal = Vector3(height * cos, slopeY, height * sin).normalized();
      b.emit(
        Vector3(radius * cos, y, radius * sin),
        n: normal,
        uv: Vector2(s / radialSegments, t),
      );
    }
  }
  for (var r = 0; r < heightSegments; r++) {
    final topApex = r == 0 && topRadius == 0;
    final bottomApex = r + 1 == heightSegments && bottomRadius == 0;
    for (var s = 0; s < radialSegments; s++) {
      final a = r * columns + s;
      final bv = a + 1;
      final c = a + columns;
      final d = c + 1;
      if (!topApex) b.tri(a, bv, c);
      if (!bottomApex) b.tri(bv, d, c);
    }
  }

  void addCap(double y, double radius, double ny, {required bool flip}) {
    if (radius <= 0) return;
    final center = b.emit(
      Vector3(0, y, 0),
      n: Vector3(0, ny, 0),
      uv: Vector2(0.5, 0.5),
    );
    final rimBase = b.vertexCount;
    for (var s = 0; s <= radialSegments; s++) {
      final theta = 2 * math.pi * s / radialSegments;
      final cos = math.cos(theta);
      final sin = math.sin(theta);
      b.emit(
        Vector3(radius * cos, y, radius * sin),
        n: Vector3(0, ny, 0),
        uv: Vector2(0.5 + 0.5 * cos, 0.5 + 0.5 * sin),
      );
    }
    for (var s = 0; s < radialSegments; s++) {
      final r0 = rimBase + s;
      final r1 = rimBase + s + 1;
      if (flip) {
        b.tri(center, r0, r1);
      } else {
        b.tri(center, r1, r0);
      }
    }
  }

  if (bottomCap) addCap(-height / 2, bottomRadius, -1, flip: true);
  if (topCap) addCap(height / 2, topRadius, 1, flip: false);
  return b.build();
}

/// A capsule along Y — hemisphere rings sharing the mid-section
/// equators, ported from upstream `buildCapsuleArrays`.
D3MeshData buildCapsule({
  required double radius,
  required double height,
  required int radialSegments,
  required int capRings,
}) {
  if (radialSegments < 3) {
    throw ArgumentError('A capsule needs at least three radial segments');
  }
  if (capRings < 1) {
    throw ArgumentError('A capsule needs at least one cap ring');
  }
  if (radius <= 0) {
    throw ArgumentError('A capsule needs a positive radius');
  }
  radialSegments = d3ClampSegments(radialSegments, 3);
  capRings = d3ClampSegments(capRings, 1);

  final halfH = height / 2;
  final rings = <({double posY, double posR, double normY, double normR})>[];
  for (var r = 0; r <= capRings; r++) {
    final phi = (math.pi / 2) * (r / capRings);
    rings.add((
      posY: halfH + radius * math.cos(phi),
      posR: radius * math.sin(phi),
      normY: math.cos(phi),
      normR: math.sin(phi),
    ));
  }
  for (var r = 0; r <= capRings; r++) {
    final phi = (math.pi / 2) + (math.pi / 2) * (r / capRings);
    rings.add((
      posY: -halfH + radius * math.cos(phi),
      posR: radius * math.sin(phi),
      normY: math.cos(phi),
      normR: math.sin(phi),
    ));
  }

  final b = D3MeshBuilder();
  final columns = radialSegments + 1;
  final rowCount = rings.length;
  for (var r = 0; r < rowCount; r++) {
    final ring = rings[r];
    for (var s = 0; s <= radialSegments; s++) {
      final theta = 2 * math.pi * s / radialSegments;
      final cos = math.cos(theta);
      final sin = math.sin(theta);
      b.emit(
        Vector3(ring.posR * cos, ring.posY, ring.posR * sin),
        n: Vector3(ring.normR * cos, ring.normY, ring.normR * sin),
        uv: Vector2(s / radialSegments, r / (rowCount - 1)),
      );
    }
  }
  for (var r = 0; r < rowCount - 1; r++) {
    for (var s = 0; s < radialSegments; s++) {
      final a = r * columns + s;
      b.quad(a, a + 1, a + columns, a + columns + 1);
    }
  }
  return b.build();
}

/// A filled disc in the XZ plane facing +Y.
D3MeshData buildDisc({required double radius, required int segments}) {
  if (segments < 3) {
    throw ArgumentError('A disc needs at least three segments');
  }
  if (radius <= 0) {
    throw ArgumentError('A disc needs a positive radius');
  }
  segments = d3ClampSegments(segments, 3);
  final b = D3MeshBuilder();
  final center = b.emit(
    Vector3.zero(),
    n: Vector3(0, 1, 0),
    uv: Vector2(0.5, 0.5),
  );
  final rimBase = b.vertexCount;
  for (var s = 0; s <= segments; s++) {
    final theta = 2 * math.pi * s / segments;
    final cos = math.cos(theta);
    final sin = math.sin(theta);
    b.emit(
      Vector3(radius * cos, 0, radius * sin),
      n: Vector3(0, 1, 0),
      uv: Vector2(0.5 + 0.5 * cos, 0.5 + 0.5 * sin),
    );
  }
  for (var s = 0; s < segments; s++) {
    b.tri(center, rimBase + s + 1, rimBase + s);
  }
  return b.build();
}

/// A real subdivided icosahedron projected to [radius] — the W26
/// icosphere, ported from upstream `buildIcosphereArrays` (midpoint
/// edge cache, spherical UVs, outward winding).
///
/// [subdivisions] above [kD3MaxIcosphereSubdivisions] clamp to it (the
/// triangle count is `20·4ⁿ`). Triangles straddling the `atan2` seam
/// get duplicated vertices with `u + 1` so the texture doesn't smear
/// back across the whole atlas, and pole vertices (where longitude is
/// undefined) are split per triangle at the neighbours' mean `u`.
D3MeshData buildIcosphere({required double radius, required int subdivisions}) {
  if (subdivisions < 0) {
    throw ArgumentError('Icosphere subdivisions cannot be negative');
  }
  if (radius <= 0) {
    throw ArgumentError('An icosphere needs a positive radius');
  }
  subdivisions = d3ClampSubdivisions(subdivisions);

  final t = (1 + math.sqrt(5)) / 2;
  final verts = <Vector3>[
    Vector3(-1, t, 0),
    Vector3(1, t, 0),
    Vector3(-1, -t, 0),
    Vector3(1, -t, 0),
    Vector3(0, -1, t),
    Vector3(0, 1, t),
    Vector3(0, -1, -t),
    Vector3(0, 1, -t),
    Vector3(t, 0, -1),
    Vector3(t, 0, 1),
    Vector3(-t, 0, -1),
    Vector3(-t, 0, 1),
  ];
  var faces = <List<int>>[
    [0, 11, 5],
    [0, 5, 1],
    [0, 1, 7],
    [0, 7, 10],
    [0, 10, 11],
    [1, 5, 9],
    [5, 11, 4],
    [11, 10, 2],
    [10, 7, 6],
    [7, 1, 8],
    [3, 9, 4],
    [3, 4, 2],
    [3, 2, 6],
    [3, 6, 8],
    [3, 8, 9],
    [4, 9, 5],
    [2, 4, 11],
    [6, 2, 10],
    [8, 6, 7],
    [9, 8, 1],
  ];

  // 32 bits per index: collision-free for any vertex count the
  // subdivision cap allows (a 16-bit shift aliased past 65535).
  final midpointCache = <int, int>{};
  int midpoint(int a, int b) {
    final key = a < b ? (a << 32) | b : (b << 32) | a;
    final cached = midpointCache[key];
    if (cached != null) return cached;
    final index = verts.length;
    verts.add((verts[a] + verts[b]) * 0.5);
    midpointCache[key] = index;
    return index;
  }

  for (var i = 0; i < subdivisions; i++) {
    final next = <List<int>>[];
    for (final f in faces) {
      final a = f[0];
      final bv = f[1];
      final c = f[2];
      final ab = midpoint(a, bv);
      final bc = midpoint(bv, c);
      final ca = midpoint(c, a);
      next
        ..add([a, ab, ca])
        ..add([bv, bc, ab])
        ..add([c, ca, bc])
        ..add([ab, bc, ca]);
    }
    faces = next;
  }

  final normals = [for (final v in verts) v.normalized()];
  final us = [
    for (final n in normals) 0.5 + math.atan2(n.z, n.x) / (2 * math.pi),
  ];
  final vs = [
    for (final n in normals) 0.5 - math.asin(n.y.clamp(-1.0, 1.0)) / math.pi,
  ];
  bool isPole(int i) => normals[i].y.abs() > 1 - 1e-9;

  final b = D3MeshBuilder();
  final shared = <int, int>{}; // source vertex → builder index
  final wrapped = <int, int>{}; // source vertex → its u+1 seam copy
  int vertex(int i, double u, {bool wrap = false, bool fresh = false}) {
    int make() =>
        b.emit(normals[i] * radius, n: normals[i], uv: Vector2(u, vs[i]));
    if (fresh) return make();
    return (wrap ? wrapped : shared).putIfAbsent(i, make);
  }

  for (final f in faces) {
    final nonPole = [
      for (final i in f)
        if (!isPole(i)) us[i],
    ];
    final seam =
        nonPole.isNotEmpty &&
        nonPole.reduce(math.max) - nonPole.reduce(math.min) > 0.5;
    double adjusted(int i) => seam && us[i] < 0.5 ? us[i] + 1.0 : us[i];
    final poleU = nonPole.isEmpty
        ? 0.5
        : [
                for (final i in f)
                  if (!isPole(i)) adjusted(i),
              ].reduce((a, c) => a + c) /
              nonPole.length;
    final out = [
      for (final i in f)
        if (isPole(i))
          vertex(i, poleU, fresh: true)
        else if (seam && us[i] < 0.5)
          vertex(i, us[i] + 1.0, wrap: true)
        else
          vertex(i, us[i]),
    ];
    b.tri(out[0], out[1], out[2]);
  }
  return b.build();
}

/// A round cross-section swept along [path] — upstream
/// `buildTubeArrays` (rotation-minimizing frames, ring stitching, fan
/// caps).
D3MeshData buildTube(
  ScenePath path, {
  required double radius,
  required int radialSegments,
  required int stations,
  required bool caps,
}) {
  if (stations < 2) {
    throw ArgumentError.value(stations, 'stations', 'must be at least two');
  }
  if (radialSegments < 3) {
    throw ArgumentError.value(
      radialSegments,
      'radialSegments',
      'must be at least three',
    );
  }
  stations = d3ClampSegments(stations, 2);
  radialSegments = d3ClampSegments(radialSegments, 3);
  final frames = path.evenlySpacedFrames(stations);
  final length = path.length;
  final b = D3MeshBuilder();
  final ringBases = <int>[];

  for (var i = 0; i < stations; i++) {
    final frame = frames[i];
    final v = length * i / (stations - 1);
    ringBases.add(b.vertexCount);
    for (var k = 0; k <= radialSegments; k++) {
      final theta = 2 * math.pi * k / radialSegments;
      final radial =
          frame.normal * math.cos(theta) + frame.binormal * math.sin(theta);
      b.emit(
        frame.position + radial * radius,
        n: radial,
        uv: Vector2(k / radialSegments, v),
      );
    }
  }

  _stitchRings(b, ringBases, radialSegments + 1);

  if (caps) {
    _tubeCap(b, frames.first, radius, radialSegments, atEnd: false);
    _tubeCap(b, frames.last, radius, radialSegments, atEnd: true);
  }
  return b.build();
}

/// A flat strip swept along [path] — upstream `buildRibbonArrays`
/// with the `ground` alignment (width perpendicular to the path from
/// above).
D3MeshData buildRibbon(
  ScenePath path, {
  required double width,
  required int stations,
  required Vector3 up,
}) {
  if (stations < 2) {
    throw ArgumentError.value(stations, 'stations', 'must be at least two');
  }
  stations = d3ClampSegments(stations, 2);
  final frames = path.evenlySpacedFrames(stations);
  final length = path.length;
  final half = width / 2.0;
  final b = D3MeshBuilder();
  final ringBases = <int>[];

  for (var i = 0; i < stations; i++) {
    final frame = frames[i];
    var sideways = frame.tangent.cross(up);
    if (sideways.length2 < 1e-12) sideways = frame.binormal;
    final across = sideways.normalized();
    // The surface normal is perpendicular to both the path tangent and
    // the strip's across axis — `up` with its tangent component
    // projected out, not raw `up` (which tilts off the surface on any
    // climbing segment).
    var normal = across.cross(frame.tangent);
    if (normal.length2 < 1e-12) normal = up.clone();
    normal.normalize();
    final v = stations == 1 ? 0.0 : length * i / (stations - 1);
    ringBases.add(b.vertexCount);
    b.emit(frame.position - across * half, n: normal, uv: Vector2(0, v));
    b.emit(frame.position + across * half, n: normal, uv: Vector2(1, v));
  }

  _stitchRings(b, ringBases, 2);
  return b.build();
}

void _stitchRings(D3MeshBuilder b, List<int> ringBases, int ringSize) {
  for (var s = 0; s < ringBases.length - 1; s++) {
    final base = ringBases[s];
    final nextBase = ringBases[s + 1];
    for (var j = 0; j < ringSize - 1; j++) {
      b.quad(base + j, base + j + 1, nextBase + j, nextBase + j + 1);
    }
  }
}

void _tubeCap(
  D3MeshBuilder b,
  ScenePathFrame frame,
  double radius,
  int radialSegments, {
  required bool atEnd,
}) {
  final ringPositions = <Vector3>[];
  final ringTexCoords = <Vector2>[];
  for (var k = 0; k < radialSegments; k++) {
    final theta = 2 * math.pi * k / radialSegments;
    final radial =
        frame.normal * math.cos(theta) + frame.binormal * math.sin(theta);
    ringPositions.add(frame.position + radial * radius);
    ringTexCoords.add(
      Vector2(0.5 + 0.5 * math.cos(theta), 0.5 + 0.5 * math.sin(theta)),
    );
  }
  final normal = atEnd ? frame.tangent : -frame.tangent;
  final center = b.emit(frame.position, n: normal, uv: Vector2(0.5, 0.5));
  final ringIndices = <int>[
    for (var k = 0; k < radialSegments; k++)
      b.emit(ringPositions[k], n: normal, uv: ringTexCoords[k]),
  ];
  for (var k = 0; k < radialSegments; k++) {
    final next = (k + 1) % radialSegments;
    if (atEnd) {
      b.tri(center, ringIndices[k], ringIndices[next]);
    } else {
      b.tri(center, ringIndices[next], ringIndices[k]);
    }
  }
}

/// A camera-facing ribbon along the point list — the CPU-side version
/// expands along a fixed perpendicular when [right] isn't supplied
/// (natives re-expand toward the live camera each frame).
///
/// [dashPattern] splits the polyline at `(on, off)` arc-length
/// boundaries. Per-point [colors]/[widths] map to the matching point;
/// a closed loop's seam segment wraps back to point zero's attributes.
/// Missing entries (a short list) fall back to [width]/white like the
/// natives. rgb colors get alpha 1.
///
/// A dash pattern that cannot advance (`on <= 0`, a negative or
/// non-finite length — see [d3DashPatternValid]) or that would emit
/// more than [kD3MaxDashSpans] dashes renders solid.
D3MeshData buildPolyline(
  List<Vector3> points, {
  required double width,
  List<List<double>>? colors,
  List<double>? widths,
  (double, double)? dashPattern,
  bool closed = false,
  Vector3? right,
}) {
  final pts = closed ? <Vector3>[...points, points.first] : points;
  final ptColors = colors == null
      ? null
      : [
          for (var i = 0; i < pts.length; i++)
            _rgba(_at(colors, closed ? i % points.length : i)),
        ];
  final ptWidths = widths == null
      ? null
      : [
          for (var i = 0; i < pts.length; i++)
            _at(widths, closed ? i % points.length : i) ?? width,
        ];
  final segments = <(int, int)>[
    for (var i = 0; i < pts.length - 1; i++) (i, i + 1),
  ];
  final side = right ?? Vector3(0, 0, 1);
  if (dashPattern != null &&
      d3DashPatternValid(dashPattern.$1, dashPattern.$2) &&
      _dashSpans(pts, dashPattern.$1, dashPattern.$2) <= kD3MaxDashSpans) {
    return _expandDashed(
      pts,
      segments,
      dashPattern.$1,
      dashPattern.$2,
      width: width,
      colors: ptColors,
      widths: ptWidths,
      sideHint: side,
    );
  }
  return _expandSegments(
    pts,
    segments,
    width: width,
    colors: ptColors,
    widths: ptWidths,
    sideHint: side,
  );
}

T? _at<T>(List<T> list, int i) => i < list.length ? list[i] : null;

/// [c] as four components: rgb gets alpha 1, extras drop, null stays
/// null (white downstream).
List<double>? _rgba(List<double>? c) => switch (c) {
  null => null,
  [final r, final g, final b] => [r, g, b, 1.0],
  [final r, final g, final b, final a, ...] => [r, g, b, a],
  _ => null,
};

/// An upper bound on the dash spans `(on, off)` produces over [pts].
double _dashSpans(List<Vector3> pts, double on, double off) {
  var length = 0.0;
  for (var i = 0; i + 1 < pts.length; i++) {
    length += (pts[i + 1] - pts[i]).length;
  }
  return length / (on + off) + 1;
}

/// Independent camera-facing quads per point pair.
D3MeshData buildLineSegments(
  List<Vector3> points, {
  required double width,
  List<List<double>>? colors,
  Vector3? right,
}) {
  final side = right ?? Vector3(0, 0, 1);
  // `colors` is one entry per segment (point pair): expand each onto
  // both endpoints so a segment is flat-colored, never a gradient
  // between neighbouring segments' colors.
  final ptColors = colors == null
      ? null
      : [for (var i = 0; i < points.length; i++) _rgba(_at(colors, i ~/ 2))];
  return _expandSegments(
    points,
    [for (var i = 0; i + 1 < points.length; i += 2) (i, i + 1)],
    width: width,
    colors: ptColors,
    widths: null,
    sideHint: side,
  );
}

/// A camera-facing quad at the origin — the CPU-side fallback builds
/// it in the XY plane; natives re-face the live camera.
D3MeshData buildBillboard({
  required Vector2 size,
  required double rotation,
  required List<double> color,
  Vector3? right,
  Vector3? up,
}) {
  final r = right ?? Vector3(1, 0, 0);
  final u = up ?? Vector3(0, 1, 0);
  final cos = math.cos(rotation);
  final sin = math.sin(rotation);
  final b = D3MeshBuilder();
  final n = r.cross(u).normalized();
  for (final (dx, dy) in [(-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5)]) {
    // Size first, then rotate: rotating the unit square and scaling
    // afterwards shears a non-square quad instead of turning it.
    final sx = dx * size.x;
    final sy = dy * size.y;
    final rx = sx * cos - sy * sin;
    final ry = sx * sin + sy * cos;
    b.emit(
      r * rx + u * ry,
      n: n,
      uv: Vector2(dx + 0.5, dy + 0.5),
      color: color,
    );
  }
  b.quad(0, 1, 2, 3);
  return b.build();
}

/// Emits one camera-facing quad for the span `pts[ia]→pts[ib]`.
///
/// [wa]/[wb] are the half-width multipliers at each end; [ca]/[cb] the
/// vertex colors. The quad expands perpendicular to the segment
/// direction and [sideHint] (the camera's right vector on device, a
/// fixed axis in tests).
void _emitQuad(
  D3MeshBuilder b,
  List<Vector3> pts,
  int ia,
  int ib,
  double wa,
  double wb,
  Vector3 sideHint,
  List<double>? ca,
  List<double>? cb,
) {
  final a = pts[ia];
  final c = pts[ib];
  var d = c - a;
  if (d.length2 < 1e-20) return;
  d = d.normalized();
  var side = d.cross(sideHint);
  if (side.length2 < 1e-12) {
    side = d.cross(Vector3(0, 1, 0));
  }
  if (side.length2 < 1e-12) side = Vector3(1, 0, 0);
  side.normalize();
  final sa = side * (wa / 2);
  final sb = side * (wb / 2);
  final v0 = b.emit(a - sa, uv: Vector2(0, 0), color: ca);
  b.emit(c - sb, uv: Vector2(1, 0), color: cb);
  b.emit(a + sa, uv: Vector2(0, 1), color: ca);
  b.emit(c + sb, uv: Vector2(1, 1), color: cb);
  b.quad(v0, v0 + 1, v0 + 2, v0 + 3);
}

/// Dashed-polyline expansion: walks each segment's arc length with a
/// global `(on, off)` cursor, emitting one quad per kept span. Colors
/// and widths interpolate across cut points via the segment's
/// endpoints. Callers validate the pattern first ([d3DashPatternValid]
/// and the [kD3MaxDashSpans] budget) — `on == 0` would never advance.
D3MeshData _expandDashed(
  List<Vector3> pts,
  List<(int, int)> segments,
  double onLen,
  double offLen, {
  required double width,
  List<List<double>?>? colors,
  List<double>? widths,
  required Vector3 sideHint,
}) {
  final b = D3MeshBuilder();
  final dense = <Vector3>[];
  var distance = 0.0;
  var on = true;
  var nextBoundary = onLen;
  List<double>? lerpColor(List<double>? ca, List<double>? cb, double t) {
    if (ca == null && cb == null) return null;
    ca ??= const [1.0, 1.0, 1.0, 1.0];
    cb ??= const [1.0, 1.0, 1.0, 1.0];
    return [for (var i = 0; i < 4; i++) ca[i] + (cb[i] - ca[i]) * t];
  }

  for (final (ia, ib) in segments) {
    final a = pts[ia];
    final c = pts[ib];
    final dir = c - a;
    final segLen = dir.length;
    if (segLen < 1e-12) continue;
    var t0 = 0.0;
    while (t0 < 1.0 - 1e-9) {
      final remain = distance + segLen - nextBoundary;
      final t1 = remain > 0 ? (nextBoundary - distance) / segLen : 1.0;
      if (on) {
        final i0 = dense.length;
        dense.add(a + dir * t0);
        dense.add(a + dir * t1);
        final w0 = widths?[ia] ?? width;
        final w1 = widths?[ib] ?? width;
        final wa = w0 + (w1 - w0) * t0;
        final wb = w0 + (w1 - w0) * t1;
        _emitQuad(
          b,
          dense,
          i0,
          i0 + 1,
          wa,
          wb,
          sideHint,
          lerpColor(colors?[ia], colors?[ib], t0),
          lerpColor(colors?[ia], colors?[ib], t1),
        );
      }
      t0 = t1;
      if (distance + t0 * segLen >= nextBoundary - 1e-9) {
        on = !on;
        nextBoundary += on ? onLen : offLen;
      }
    }
    distance += segLen;
  }
  b.computeFlatNormals();
  return b.build();
}

/// Shared solid segment expansion — one quad per segment pair.
D3MeshData _expandSegments(
  List<Vector3> pts,
  List<(int, int)> segments, {
  required double width,
  List<List<double>?>? colors,
  List<double>? widths,
  required Vector3 sideHint,
}) {
  final b = D3MeshBuilder();
  for (final (ia, ib) in segments) {
    _emitQuad(
      b,
      pts,
      ia,
      ib,
      widths?[ia] ?? width,
      widths?[ib] ?? width,
      sideHint,
      colors?[ia],
      colors?[ib],
    );
  }
  b.computeFlatNormals();
  return b.build();
}
