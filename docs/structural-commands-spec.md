# W5 — structural commands

Live scene mutation without `loadScene`. The wire commands are the
transport for upstream's `diffScene`/`reloadScene` semantics
(`scene-0.3.0/lib/src/diff.dart`,
`flutter_scene-0.23.0/lib/src/fscene/reload/reload.dart`): a
document-level diff keyed by stable node id, applied in a fixed order,
patching the live graph in place. Nodes whose id is unchanged keep
identity — physics bodies, animation state and app-held references
survive a diff that doesn't touch them.

Already landed in W4 and reused here: `removeNode` (both platforms),
`upsertResource` for `texture`/`material` kinds (surgical rebind),
`upsertPayload` for image payloads.

## Command shapes

All ops are `{"op": …}` utf8-JSON `command` mutations (tag 5). Node
`spec` payloads are exactly the manifest `nodes` entry shape
(upstream `_encodeNode`): `name`, `transform` (`{trs:{t,r,s}}` or
`{matrix}`), `children` (token list), `components` (`{type,
properties}`), `layers`, `visible:false`.

- `addNode` — `{"op":"addNode","node":"<token>",
  "parent":"<token>"|null,"spec":{…}}`. Native creates the node,
  applies every spec field, and attaches under `parent` (absent/null
  → scene root; a parent token that doesn't resolve yet warns and
  roots — see ordering below). Children are NOT wired from
  `spec.children` — each child attaches itself via its own
  `addNode`'s `parent` field. `spec.components` decodes the same way
  as a manifest node (mesh/light/camera/rigidBody).
- `updateNode` — `{"op":"updateNode","node":"<token>",
  "flags":[…],"spec":{…},"parent":"<token>"?}`. `flags` are
  upstream `NodeChange` field names: `transform`, `name`, `layers`,
  `visible`, `reparented`, `components`. Native applies only flagged
  fields from `spec`; `reparented` reads `parent` (null → root);
  `components` clears the node's realized component state (geometry,
  material refs, light, physics body) then re-decodes the components
  array — a rebuilt rigid body is a replace, matching upstream's
  component re-realize.
- `removeNode` — `{"op":"removeNode","node":"<token>"}` (landed).
- `upsertResource` — `{"op":"upsertResource","id":"<kind>:<token>",
  "resource":{…}}`. W4 landed `texture`/`material`; W5 adds
  `geometry`: re-decode the geometry resource and rebind every node
  whose mesh referenced it (new `geometryConsumers` map: geometry id
  → consuming nodes, populated at `decodeMesh` and maintained by
  `removeNode`/component re-decode). Other kinds log once.
- `upsertPayload` — `{"op":"upsertPayload","id":"chunk:<token>",
  "bytes":<base64|[ints]>}`. W4 landed image payloads; W5 adds
  vertex/index payloads backing `geometry` resources: store the
  chunk, re-decode each geometry that references it
  (`geometryPayloadKeys`: geometry id → Set of claimed payload ids —
  a geometry references both `vertices` and `indices` — mirroring
  `texturePayloadKeys` in direction), and rebind consumers. iOS
  rebuilds the `SCNGeometry` and swaps it onto consuming nodes'
  `.geometry`; Android rebuilds the `GpuMesh` buffers and rebinds
  renderables.

## Ordering and idempotency

Dart emits one diff batch in this canonical order — documented in
`protocol.dart` next to the op table:

1. `removeNode` — detach first so re-added or reparented subtrees
   don't collide with their previous instances.
2. `upsertPayload` — chunks land before resources that decode them.
3. `upsertResource` — resources before nodes that reference them.
4. `addNode` — in topological order: parents before their added
   children (a child's `parent` must already exist when its op lands;
   natives warn + root on an unresolvable parent rather than defer).
5. `updateNode` — surviving-node patches last.

Per-op idempotency (a command batch may be re-sent):

- `addNode` on a live id → warn `addNode on live id; treating as
  update` and apply the spec as a full `updateNode` (all flags).
- `updateNode`/`removeNode`/physics ops on a missing id → warn, no-op
  (lane 10 requires the process survives).
- `upsertResource` unknown kind → `logOnce`.
- `upsertPayload` with no consumers → store bytes, `logOnce`.

`animationsChanged` and `stageChanged` exist in `SceneDiff` but are
out of W5 scope: skins/animations aren't on the wire (W10 scope) and
stage/env lands in W7. The bridge logs `not implemented` for either
flag set — the diff still applies its node/resource ops.

## Dart bridge

`SceneController.applyDiff(SceneDiff diff, SceneDocument newDoc)`
returns the ordered command list and sends it via `applyCommands`.
Building it:

- `diffScene` is already re-exported through `lib/src/scene_model.dart`.
- Node specs: dart3d writes a small `encodeNodeCommandSpec(NodeSpec)`
  in the bridge — upstream `_encodeNode` is private. It emits the
  identical shape; component properties encode through
  `encodePropertyValue` (add
  `export 'package:scene/src/json/property_json.dart'` to
  `scene_model.dart` — same routing rule as the rest).
- Resource changes: `SceneDiff` does not expose which resources
  changed (upstream folds them into `NodeChange.components`), so the
  bridge re-diffs `oldDoc.resources` vs `newDoc.resources` itself —
  canonical-JSON compare via the exported `encodeResource`. Each
  changed resource emits `upsertResource`. This is a superset of
  upstream's transitive-reference detection and equally correct:
  natives rebind consumers surgically regardless.
- Payload changes: payloads in `newDoc` whose `bytes` differ from the
  old doc's (or arrive where old was null) emit `upsertPayload`.
- Parent map: computed from `newDoc` (`children` lists inverted;
  absent → root).

## Harness probes

`feature_scene.dart` keeps the loaded doc and, on a timer, builds a
mutated second doc (`FeatureScene.build(ortho, phase2: true)` or a
doc-copy path), diffs, and sends `applyDiff` output — the lanes
exercise the real diff path, not hand-written ops:

- `addNode`: a new lit quad appears (≥+8 s, after W4's +6 s swap).
- `updateNode`: a probe's material color / transform changes.
- `removeNode`: a probe subtree disappears.
- `upsertResource` geometry: a quad's mesh swaps to a different
  shape.
- `upsertPayload`: a vertex-chunk payload re-uploads with morphed
  positions — the live mesh visibly deforms.
- Burst: ~50 mixed ops in one batch for lanes 8/9.
- Stale: one op addressed to an already-removed node (lane 10).

## Deferred

- Skins/animations wiring (`skin` flag on `addNode`/`updateNode`)
  — no skin decode on the wire yet (W10).
- `stageChanged` re-application — env/IBL lands in W7.

## The `instance` placeholder tag (W15)

A node spec's `instance` member marks a lazy prefab placeholder.
Natives record the member raw (`instanceSpecs` /
`NodeRec.instanceSpec`) without realizing content;
`SceneController.loadSubtree`/`unloadSubtree` stream the expansion
in and out through `loadSubtree`/`unloadSubtree` envelope ops whose
nested batch is the op vocabulary above.

`updateNode` tag semantics, both platforms: an `instance` dict sets
the tag (the unload's restore update), explicit `null` clears it
(the load's instance update), and an absent key preserves it — a
reparent-only update (`spec: {}`, as the graft/ungraft ops send)
must not strip the tag.

Nested lazy instances inside a streamed subtree keep the member on
their `addNode` spec (prefab-local id space, upstream's unremapped
rule) and resolve through the public `loadSubtree` — each stream
record carries `placeholders` (composed id → spec) because streamed
members never join the tracked document.

`unloadSubtree` emits `removeSkin`/`removeAnimation` for the pools
the load upserted. Upserted payloads and resources persist by
design: their ids derive from the prefab's document identity, so
the host document and sibling instances may legitimately consume
them — and the vocabulary has no `removePayload`/`removeResource`
to retract them anyway.
