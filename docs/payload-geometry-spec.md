# Payload geometry — wire spec (W3)

Pins the upstream `package:scene` vocabulary for payload-backed geometry so
dart3d documents interchange with `flutter_scene` producers. All field names,
layout strings, and defaults below are taken from `scene-0.3.0`
(`lib/src/specs.dart`, `lib/src/json/fscene_json.dart`) and the reference
decoder `flutter_scene-0.23.0`
(`lib/src/fscene/realize/resource_realizer.dart`,
`lib/src/geometry/interleaved_layout.dart`).

## geometry resource

| Field | Type | Default | Notes |
|---|---|---|---|
| `vertices` | payload id | — | The `vertexBuffer` chunk holding vertex data. Exactly one of `vertices`/`procedural` is set. |
| `indices` | payload id | absent | The `indexBuffer` chunk, or absent for non-indexed geometry. |
| `procedural` | map | absent | Runtime primitive — already implemented. |
| `bounds` | `{min: v3, max: v3}` | absent | Local-space AABB, min/max corners. Present → skip the position scan; feeds renderable bounds and `boundingBox` colliders. |
| `topology` | string | `'triangle'` | `triangle`, `triangleStrip`, `line`, `lineStrip`, `point`. |
| `legacyWinding` | bool | `false` | Pre-format-v5 documents stored indices clockwise. |
| `morphTargets` | map | absent | Delta payloads + weights. **Deferred** — no skinning/morph pipeline exists yet; log once and realize the base mesh. |

## payload manifest entries

| Field | Type | Notes |
|---|---|---|
| `encoding` | string | `vertexBuffer`, `indexBuffer`, `image`, `matrices`, `floats`, `bytes`. W3 uses the first two; `image` lands in W4. |
| `layout` | string | Vertex layout name, on `vertexBuffer` payloads only (table below). |
| `format` | string | On `indexBuffer`: `uint16` or `uint32` (absent ⇒ `uint16`). On `image`: pixel format. |
| `length` | int | Byte length. |
| `bytes` | chunk | Attached when the payload arrives; absent in a manifest-only pass. |

## vertex layouts

Upstream layout names and byte layouts (`f32` little-endian throughout):

| `layout` | Form | Bytes/vtx | Contents |
|---|---|---|---|
| `unskinned_uv1_tangent` | interleaved | 72 | `pos3 | normal3 | uv0-2 | uv1-2 | color4 | tangent4` (18 floats) |
| `unskinned_soa_uv1_tangent` | structure-of-arrays | 72 | six concatenated streams in order: positions (n×12B), normals (n×12), uv0 (n×8), uv1 (n×8), color (n×16), tangent (n×16) |
| `skinned_uv1_tangent` | interleaved | 104 | unskinned 18 floats, then `joints4`, `weights4` (26 floats) |
| `unskinned` or absent | legacy interleaved | 48 | `pos3 | normal3 | uv-2 | color4` (12 floats); decoder upgrades: uv1 = (0,0), tangent = neutral |
| `unskinned_soa` | legacy SoA | 48 | four streams: pos, normal, uv, color; same upgrade |
| `skinned` | legacy interleaved | 80 | 20 floats; upgrade inserts uv1 (0,0) and neutral tangent between color and joints/weights |
| `p3t4` (dart3d extension) | interleaved | 28 | `pos3 | tangentFrameQuat4`. Tangent frame packed as a quaternion — what MeshFactory produces internally. Upstream never emits it; dart3d decoders keep it for lean native-authored docs. **Native-space verbatim: no mirror, no winding swap, `legacyWinding` does not apply.** |

`tangent4` on the wire is a tangent vector xyz plus `w` = bitangent
handedness (±1) — not the `p3t4` quaternion. Skinned layouts decode the
unskinned 18 floats now; `joints`/`weights` are consumed-but-ignored until
the skinning wave, and realizing one logs once.

Legacy-upgrade neutral values (upstream `packUnskinned` defaults): normal
`(0,0,1)`, uv `(0,0)`, color opaque white `(1,1,1,1)`, tangent
`(1,0,0,1)`.

## winding and the z-mirror

Format v5+ stores model-space front faces counter-clockwise; `legacyWinding`
(or manifest `fscene < 5`) marks clockwise index buffers.

dart3d lands doc-space vertex data under the same z-mirror as node
transforms: `p' = (x, y, -z)`, `n' = (nx, ny, -nz)`. Mirroring is
orientation-reversing, so it flips every triangle's winding once. The net
rule for `triangle` topology on both platforms:

- `legacyWinding` absent/false (v5+ CCW source): mirror makes it CW →
  **swap `i+1` ↔ `i+2` in each triple** to restore front-facing.
- `legacyWinding` true (CW source): mirror already produced CCW →
  **no swap**.

Same rule for `uint16` and `uint32`. `triangleStrip` and non-indexed
geometry are not migrated (upstream marks both TODO) — log once and use
the data as-is.

Tangents transform as basis vectors: `t' = (tx, ty, -tz)` and the
handedness flips, `w' = -w` (a reflection conjugates `b = w·(n×t)` into
`b' = -w·(n'×t')`). UVs and colors pass through untouched.

`p3t4` payloads skip all of this — native-space verbatim, indices used
as authored.

## coordinate convention

Positions land through the same LH→RH z-mirror as node transforms
(`(x, y, -z)`); normals and tangent vectors flip z likewise and the
tangent handedness `w` negates. UVs and colors pass through untouched.

## deferred payloads

The manifest pass arrives before payload bytes — `bytes:` on a
`PayloadSpec` always travels as a separate `payload` mutation, never
inline. A geometry whose `vertices` payload is absent logs
`geometry <id>: awaiting payload` and realizes on the payload-arrival
re-realize — the path W1 already proves for textures.
`boundingBox`/`convexHull`/`triMesh` colliders on payload-mesh nodes read
the realized geometry, so they resolve correctly once the mesh lands.

A collider that resolves to no shape must not kill the body — but the
two engines differ. SceneKit attaches a body with `shape: nil` and
auto-derives from `node.geometry` at attach time (`physicsShape` keeps
reporting nil — a reporting artifact; the auto-derived shape is
SceneKit's documented behaviour for a shapeless body). Jolt
dereferences `BodyCreationSettings.shape` unconditionally, so Android
skips `addBody` and logs `node <id>: collider has no shape yet; body
deferred`. Both converge on the payload-arrival re-realize, where the
real shape is built.

## malformed payloads

Decode failures are data errors, not crashes: a vertex payload not
divisible by its layout's stride, an unknown layout name, or a missing
payload chunk each produce one `d3Log`/`Log.w` line and the geometry
resolves to null (node stays renderless). Never throw across the bridge.

# d3 extension components — wire spec (W26)

Upstream `ProceduralGeometry` is a sealed five-type hierarchy, so the
expanded dart3d vocabulary rides generic `ComponentSpec` extension
components — `d3:procMesh` and `d3:instances` — which upstream's
component codec passes through manifests, diffs, prefab
`addedComponents`/`memberComponents`, and subtree streams untouched.
Property values use upstream's tagged form (`property_json.dart`):
`b`/`i`/`d`/`s` scalars, `v2`/`v3`/`v4`/`q`/`m4`/`c` vectors, `rref`
resource refs, `list`/`map` containers.

## d3:procMesh

One runtime-built mesh on the node. `shape` selects the generator; the
rest of the property bag is that shape's parameter set.

| Field | Tag | Default | Notes |
|---|---|---|---|
| `shape` | `s` | — | Required. One of the 14 names below. |
| `material` | `rref` | absent | Material resource; absent → platform default. |

### shape vocabulary

The five upstream shapes appear by name so `d3:instances` can reference
the whole vocabulary uniformly. `d3:procMesh` also accepts them —
`procedural` on a geometry resource remains the upstream-canonical form
for those five.

| `shape` | Parameters (tag → default) |
|---|---|
| `cuboid` | `extents` v3 → required; `debugColors` b → false |
| `plane` | `width` d → 1, `depth` d → 1, `segmentsX` i → 1, `segmentsZ` i → 1. XZ plane centered at y=0, +Y facing — `width` spans X, `depth` spans Z. |
| `sphere` | `radius` d → .5, `segments` i → 32, `rings` i → 16 |
| `torus` | `radius` d → .5, `tubeRadius` d → .15, `radialSegments` i → 32, `tubularSegments` i → 16 |
| `icosphere` | `radius` d → .5, `subdivisions` i → 2 |
| `cylinder` | `bottomRadius` d → .5, `topRadius` d → .5, `height` d → 1, `radialSegments` i → 32, `heightSegments` i → 1, `bottomCap` b → true, `topCap` b → true |
| `cone` | `radius` d → .5, `height` d → 1, `radialSegments` i → 32, `heightSegments` i → 1, `bottomCap` b → true |
| `capsule` | `radius` d → .5, `height` d → 1, `radialSegments` i → 32, `capRings` i → 8. Total height = `height + 2·radius`. |
| `disc` | `radius` d → .5, `segments` i → 32. XZ plane, +Y facing. |
| `tube` | `points` list(v3) → required, `radius` d → .5, `radialSegments` i → 12, `stations` i → 64, `caps` b → true, `closed` b → false. Catmull-Rom sweep, rotation-minimizing frames. |
| `ribbon` | `points` list(v3) → required, `width` d → 1, `stations` i → 64, `up` v3 → (0,1,0), `closed` b → false. Flat strip swept along a Catmull-Rom path. |
| `polyline` | `points` list(v3) → required, `width` d → 1, `widthInPixels` b → false, `colors` list(c) → absent, `widths` list(d) → absent, `dashes` v2 → absent (on,off arc lengths), `closed` b → false, `caps` s → 'round' optional |
| `lineSegments` | `points` list(v3) → required, even count; `width` d → 1, `widthInPixels` b → false, `colors` list(c) → absent |
| `billboard` | `size` v2 → (1,1), `facing` s → 'spherical' (`axisY`, `screen`), `rotation` d → 0, `color` c → white |

`icosphere` is a real subdivided icosahedron on both platforms — 12
vertices / 20 faces, midpoint edge cache, four-way subdivision per
iteration, vertices projected to `radius`. It replaces the earlier
UV-sphere approximation; the wire name is unchanged.

### orientation, winding, and tangent frames

`plane` and `disc` are XZ sheets facing +Y — never SceneKit's XY/+Z
`SCNPlane` orientation, which the pre-W26 iOS port emitted edge-on.
Every generator (proc.dart, GeometryFactory.swift, MeshFactory.kt)
produces the same vertex order, UVs, and outward winding: the
geometric normal agrees with the attribute normal on every
non-degenerate triangle. Segment counts clamp at the native
dispatchers — ≥1 for grid/radial/ring counts, ≥2 for `stations`,
≥0 for `subdivisions` — so a degenerate wire value can't NaN a
division.

Tangent frames are UV-aligned where the surface has a natural
parameterization (plane, sphere, torus — tangent = the uv.x gradient)
and synthesized perpendicular elsewhere; both natives encode the
bitangent handedness — `w<0` marks the reflected frame (the XZ
plane's +Z v-gradient bitangent is the contract case). On iOS the
tangent4 and uv1 streams survive extraction and instance baking —
the second `.texcoord` source is uv1, emitted after uv0 and before
any bone streams; Android's shared 15-float record carries the same
channels end to end.

### camera-facing shapes

Filament line primitives rasterize one pixel wide, so `polyline`,
`lineSegments`, and `billboard` are emitted as quads the natives re-face
toward the active camera each frame. The phase slot is fixed per
platform — iOS re-expands in `renderer(_:willRenderScene:)`
(post-update, pre-render); Android rewrites the vertex buffer at the
top of `render()` before `beginFrame` — so a camera move can never
draw a frame against a stale expansion. The Dart-side `build*`
generators emit a default +Y-facing ribbon for bounds/tests; natives
own the live orientation.

`facing` selects the billboard basis: `spherical` aims the quad
normal at the node-local camera position (the Dart default), `axisY`
rotates about node-local +Y only (cylindrical), `screen` keeps the
camera plane. Unknown values warn once and read as `spherical`.
Lines always aim at the camera — the mode applies to `billboard`
quads and `d3:instances` billboards only.

Carried-but-unrealized fields warn once per node rather than dropping
silently: `widthInPixels` (widths are world units — pixel sizing needs
a viewport scale the wire doesn't carry), polyline `caps` (line ends
are butt), an odd `lineSegments` tail (the trailing point drops), and
an unknown `facing`. A camera-facing shape used as a `procedural`
geometry resource or a non-billboard `d3:instances` base can't reface
— it bakes once toward +Z with the same warn-once note.

## d3:instances

N copies of one mesh under one node — one SceneKit geometry / one
Filament renderable, one draw.

| Field | Tag | Default | Notes |
|---|---|---|---|
| `geometry` | `rref` | absent | Geometry resource (payload-backed or upstream `procedural`). Exactly one of `geometry`/`shape` is set. |
| `shape` | `s` + params | absent | Inline `d3:procMesh`-style spec — `shape` plus that shape's parameter bag, same names as above. |
| `material` | `rref` | absent | Material resource; absent → platform default. |
| `transforms` | `list(m4)` or `rref` | — | Required. Inline column-major matrices, or a `matrices` payload ref (`count` × 64-byte f32 column-major). |
| `attributes` | `map` | absent | name → per-instance vec4: `list(v4)` inline or `rref` to a `floats`/`bytes` payload (`count` × 4 values). `color` stamps the COLOR stream and multiplies the material base color; `attr1`–`attr3` are carried for future hooks but unread today. |
| `billboard` | `b` | false | Realize each instance as a camera-facing quad instead of the mesh. |
| `size` | `v2` | (1,1) | Billboard quad size, world units. |
| `rotation` | `d` | 0 | In-plane billboard rotation, radians. |
| `facing` | `s` | 'spherical' | Billboard facing mode — `spherical`/`axisY`/`screen`, same semantics as `d3:procMesh`; billboard mode only. |
| `doubleSided` | `b` | false | Render both faces — binds a per-component material copy (see below). |

### baked instancing

Both platforms expand instances into a single vertex/index stream:
positions transform by the instance matrix; **normals transform by the
exact inverse-transpose of its upper 3×3** (computed in cofactor form
— exact under non-uniform scale, mirror, and shear, where a
normalize-the-columns approximation drifts; a non-invertible or
non-finite transform carries the source frame through unchanged);
tangents transform by the matrix itself, re-orthogonalized against the
new normal, with bitangent handedness flipping on a negative
determinant. `color` stamps the COLOR stream, and one renderable draws
the result. SceneKit has no instanced draw on `SCNGeometry`; Filament
1.71.6's Java binding exposes `Builder.instances(int)` but not the
`InstanceBuffer` overload carrying per-instance data, so the baked
path is the portable contract. The 1000-instance field in the example
is one node and one draw.

Precedence is explicit, each case logging once per node:
`billboard: true` overrides `shape`/`geometry` entirely; when both
mesh fields are present `shape` wins. `attr1`–`attr3` log once as
carried-but-unread (`color` is the only realized attribute). A skinned
base geometry bakes unskinned — the joint/weight streams drop with a
warn-once on both platforms; a morphed base likewise bakes unmorphed
with a warn-once. Baked instance counts cap at 16384 — over it, the
tail truncates with a warn-once (upstream's GPU instancing has no
equivalent limit).

`billboard: true` instances re-expand per frame toward the camera
(transform translation = quad center, `size` = extent, `facing` =
basis mode). `doubleSided` can't ride the shared material instance —
the node binds a per-component copy (SceneKit `copy()`, Filament
`MaterialInstance.duplicate`). The copy is a snapshot: surgical
updates to the source material resource after the bind don't
propagate to it.

## Catmull-Rom paths (Dart only)

`CatmullRomPath`/`PolylinePath` (`src/geometry/paths.dart`) provide
`sample`, `length`, arc-length `evenlySpacedFrames`, and
rotation-minimizing frames. They feed `tube`/`ribbon` generation and
the navigation-route use case; nothing path-typed travels the wire —
paths flatten to `points` lists before encode.
