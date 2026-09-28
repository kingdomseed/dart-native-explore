/// Resource caps for the W26 procedural geometry and instancing paths.
///
/// Every value below is part of the wire contract: the Dart CPU
/// generators apply them, and the iOS/Android decoders mirror them so a
/// hostile or careless document can't hang a decoder or exhaust memory
/// (see `docs/triage/dart.md` for the native-mirror checklist). Counts
/// that arrive over the wire are *clamped*, never rejected, so a
/// document degrades to the capped mesh on every platform identically.
library;

import 'dart:math' as math;

/// Upper bound for every per-axis tessellation count: `segments`,
/// `rings`, `radialSegments`, `tubularSegments`, `heightSegments`,
/// `capRings`, `segmentsX`/`segmentsZ`, and sweep `stations`.
///
/// A capped UV sphere is `513 × 513 ≈ 263k` vertices — past the 16-bit
/// index range, so natives must pick 32-bit indices by vertex count
/// (see [kD3MaxUint16Vertices]), but bounded to ~12 MB of attributes.
const kD3MaxProcSegments = 512;

/// Upper bound for icosphere `subdivisions`. Level 6 is
/// `10·4⁶ + 2 = 40 962` shared vertices and `20·4⁶ = 81 920` triangles;
/// level 7 would quadruple both. The Dart generator's seam/pole UV
/// copies keep level 6 under [kD3MaxUint16Vertices] (pinned by
/// `w26_geometry_fixes_test`), but natives should still pick the index
/// width from the vertex count rather than assume it.
const kD3MaxIcosphereSubdivisions = 6;

/// The largest vertex count a 16-bit index buffer can address. Any mesh
/// with more vertices must use 32-bit indices (natives: `UINT32` /
/// `SCNGeometryElement` `bytesPerIndex: 4`). The Dart generators always
/// emit 32-bit indices.
const kD3MaxUint16Vertices = 65536;

/// Upper bound on instances baked into one `d3:instances` mesh (the
/// pre-existing native `MAX_BAKED_INSTANCES`). Excess instances are
/// truncated from the tail.
const kD3MaxBakedInstances = 16384;

/// Upper bound on total vertices in one baked `d3:instances` mesh —
/// `instances × base-mesh vertices`. With position/normal/uv/color that
/// is ~48 MB of float attributes at the cap. The instance count is
/// truncated to fit ([d3BakedInstanceCount]).
const kD3MaxBakedVertices = 1 << 20;

/// Upper bound on dash spans (on-segments) one dashed polyline may
/// emit. A pattern that would exceed it — e.g. a microscopic
/// `(on, off)` against a long line — renders solid instead.
const kD3MaxDashSpans = 16384;

/// Clamps a wire/typed tessellation count to `[min, kD3MaxProcSegments]`.
int d3ClampSegments(int value, int min) => value < min
    ? min
    : (value > kD3MaxProcSegments ? kD3MaxProcSegments : value);

/// Clamps icosphere subdivisions to `[0, kD3MaxIcosphereSubdivisions]`.
int d3ClampSubdivisions(int value) => value < 0
    ? 0
    : (value > kD3MaxIcosphereSubdivisions
          ? kD3MaxIcosphereSubdivisions
          : value);

/// How many of [requested] instances a bake of a [baseVertexCount]-vertex
/// mesh keeps: capped by [kD3MaxBakedInstances] and by the
/// [kD3MaxBakedVertices] budget. A base mesh larger than the whole
/// budget keeps a single instance (the mesh itself is already bounded
/// by the per-shape caps).
int d3BakedInstanceCount(int requested, int baseVertexCount) {
  if (requested <= 0) return 0;
  var n = math.min(requested, kD3MaxBakedInstances);
  if (baseVertexCount > 0) {
    n = math.min(n, math.max(1, kD3MaxBakedVertices ~/ baseVertexCount));
  }
  return n;
}

/// Whether an `(on, off)` dash pattern can advance: both lengths finite
/// and non-negative, `on` positive. A pattern that fails renders solid
/// (`(0, x)` would emit nothing; `(x, 0)` is solid already, and
/// `(0, 0)` used to loop forever).
bool d3DashPatternValid(double on, double off) =>
    on.isFinite && off.isFinite && on > 0 && off >= 0;
