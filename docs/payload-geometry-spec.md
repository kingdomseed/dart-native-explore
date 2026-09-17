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
