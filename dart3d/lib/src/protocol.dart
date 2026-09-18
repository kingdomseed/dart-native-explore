import 'dart:convert';
import 'dart:typed_data';

import 'scene_model.dart';

/// The dart3d ↔ native wire protocol, version 1.
///
/// Every message is one [PluginMutation]: the `eventTag` is the message
/// kind and the `Uint8List` is the kind-specific payload below. All
/// multi-byte binary fields are little-endian. Ids on the wire are the
/// 8 raw bytes of a `LocalId` (`session` u32 then `index` u32); inside
/// `.fscene` JSON they remain the canonical base32 tokens.
///
/// | tag | kind            | payload                                             |
/// |-----|-----------------|-----------------------------------------------------|
/// |  1  | `hello`         | `[u8 major][u8 minor]` — sent once at mount         |
/// |  2  | `loadScene`     | utf8 canonical `.fscene` JSON — full replace        |
/// |  3  | `payload`       | `[8B payloadId][raw bytes]` — binary chunk          |
/// |  4  | `setTransforms` | `[u32 count]` × `[8B nodeId][u8 mask][t][r][s]` —
/// |     |                 | mask bits: 1=t f32×3, 2=r f32×4, 4=s f32×3;    |
/// |     |                 | absent fields keep the node's previous values  |
/// |  5  | `command`       | utf8 JSON op (see below)                            |
/// |  6  | `viewConfig`    | utf8 JSON `{allowsCameraControl, showsStatistics,   |
/// |     |                 |  backgroundColor, antialiasingMode}`                |
///
/// `command` ops come in two groups. Structural edits between snapshots —
/// `addNode`, `removeNode`, `updateNode`, `upsertResource`,
/// `upsertPayload` — are derived Dart-side from `diffScene` output
/// (`NodeChange` carries flags, not values, so ops carry the new
/// content; `spec` is always the manifest `nodes` entry shape and
/// `resource` the manifest `resources` entry shape):
///
/// - `{"op":"removeNode","node":"<id>"}` — detach the node + subtree.
/// - `{"op":"addNode","node":"<id>","parent":"<id>"|null,"spec":{…}}` —
///    create + attach under `parent` (absent/null → scene root).
///    `spec.children` is inert — each child attaches itself via its own
///    op's `parent`, so adds are order-independent within a batch.
/// - `{"op":"updateNode","node":"<id>","flags":[…],"spec":{…},
///    "parent":"<id>"?}` — apply only flagged spec fields; `flags` are
///    upstream `NodeChange` names (`transform`, `name`, `layers`,
///    `visible`, `reparented`, `components`, `skin`). `reparented` reads
///    `parent` (null → root); `components` clears realized component
///    state (geometry, material refs, light, physics body) then
///    re-decodes the array; `skin` re-decodes the spec's `skin`
///    member (bind or unbind — see below).
/// - `{"op":"upsertResource","id":"<kind>:<id>","resource":{…}}` —
///    re-decode one manifest resource (`texture`, `material`,
///    `geometry`, `environment`, `renderTexture`) and rebind every
///    consuming node/slot.
/// - `{"op":"upsertPayload","id":"chunk:<id>","bytes":<base64|[ints]>,
///    "encoding":"<enc>","layout":<s>?,"format":<s>?,"width":<i>?,
///    "height":<i>?,"length":<i>?}` — store a chunk, then re-decode
///    and rebind the resources it backs (image payloads → textures,
///    vertex/index → geometries). The spec fields let a runtime-minted
///    chunk register in the native spec table — the manifest's
///    `payloads` block only covers install-time chunks.
/// - `{"op":"updateStage","stage":{…}}` — re-decode the manifest
///    `stage` block on the live context (environment/IBL, exposure,
///    tone mapping, AA/render-scale defaults). Sent last in a diff
///    batch so any environment resource it names has already landed.
///
/// A diff batch goes out in that order — skin/animation removes,
/// node removes, payloads, resources, adds, updates, skin/animation
/// upserts, then the stage — so detaches precede re-adds, chunks
/// precede the resources decoding them, resources precede
/// referencing nodes, and skins/animations rebind against the
/// post-batch graph.
/// Batches may be re-sent: `addNode` on a live id applies as a full
/// `updateNode`; `updateNode`/`removeNode`/physics ops on a missing id
/// warn and no-op; unknown resource kinds and unconsumed payloads log
/// once.
///
/// Skin/animation ops (W11) extend the diff batch — `removeSkin` and
/// `removeAnimation` lead it (dependents detach before the nodes they
/// reference) and `upsertSkin`/`upsertAnimation` land after the node
/// ops (joints and channel targets bind against the post-batch graph):
///
/// - `{"op":"upsertSkin","id":"skin:<id>","skin":{"joints":
///    ["n:<id>",…],"inverseBindMatrices":"chunk:<id>",
///    "skeleton":"n:<id>"?}}` — re-decode one manifest `skins` entry;
///    `inverseBindMatrices` is a `matrices` chunk (16×f32 per joint,
///    column-major). The upsert attaches to every node whose `skin`
///    member names the id (the rebind-consumers contract, same as
///    `upsertResource`).
/// - `{"op":"upsertAnimation","id":"anim:<id>","animation":
///    {"name":…?,"channels":[{"target":"n:<id>","targetName":…?,
///    "property":"translation"|"rotation"|"scale"|"weights",
///    "timeline":"chunk:<id>","keyframes":"chunk:<id>"}]}}` —
///    re-decode one manifest `animations` entry. `timeline` is a
///    `floats` chunk of keyframe seconds; `keyframes` carries vec3 /
///    quat / flattened weights values (`times × targetCount` floats —
///    trailing floats past a whole keyframe are dropped). Channels
///    bind `target` id first, `targetName` as fallback. Animations do
///    not autoplay — a realized clip starts paused.
/// - `{"op":"removeSkin","id":"skin:<id>"}` /
///    `{"op":"removeAnimation","id":"anim:<id>"}` — drop the entity
///    and detach it from any bound node.
///
/// The node `skin` member travels inside `spec` as
/// `"skin":"skin:<id>"` — decoded on `loadScene`, `addNode`, and
/// `updateNode` (`flags` gains a `skin` entry that re-decodes the
/// member: bind a changed skin, or unbind when the member went null).
///
/// `anim` is the runtime clip control — upstream's `AnimationClip`
/// knobs; `setMorphWeights` writes a node's morph weights directly:
///
/// - `{"op":"anim","anim":"<id>","play":true|"pause":true|
///    "stop":true,"time":<s>?,"timeScale":<f>?,"weight":<f>?,
///    "loop":<bool>?}` — `play` starts/resumes (with `time` it is
///    `gotoAndPlay`), `pause` holds the playhead, `stop` pauses and
///    rewinds. With no verb the op is a pure knob write: `time` seeks
///    (clamped to `[0, endTime]`), `timeScale` scales the advance,
///    `weight` is the clip's blend weight (clamped `[0, 1]`), `loop`
///    toggles wrap-at-end.
/// - `{"op":"setMorphWeights","node":"<id>","weights":[f,…]}` —
///    replace the node's morph target weights (one per target),
///    independent of any playing weights channel.
/// - `{"op":"selectVariant","node":"<id>","selected":<str|null>}` —
///    W12 `materialsVariants` selection: each of the component's
///    bindings resolves the named variant's material for its
///    (node, primitive) slot; null or unknown names restore the
///    recorded default (upstream `KHR_materials_variants` semantics —
///    a foreign slot write rebases the default).
///
/// W12 also realizes the document-declared joint COMPONENTS
/// (`fixedJoint`/`sphericalJoint`/`revoluteJoint`/`prismaticJoint`/
/// `genericJoint`, upstream `physics_codecs.dart` names). Natives
/// translate them onto this same constraint machinery — an absent
/// `otherNode` anchors to the world (upstream `_resolveOtherNode`),
/// encoded internally as a null `b` endpoint; component joints get
/// handles from a reserved range so they never collide with
/// caller-chosen command ids.
///
/// W14 realizes the manifest `views` list and `renderTexture`
/// resources at runtime. Upstream `diffScene`/`composeScene` treat
/// views as install-only, so `diffCommands` diffs the encoded list
/// itself and emits `updateViews` last in the batch (after
/// `updateStage`) — a view may reference a camera node or render
/// target the same batch ships:
///
/// - `{"op":"updateViews","views":[{…},…]}` — wholesale-replaces the
///    document's `views` list. Each entry is the manifest view shape
///    (upstream `_encodeView`): `"camera":"n:<id>"` always, then only
///    the non-default members — `"target":"rt:<id>"` (absent → the
///    screen), `"layerMask":<int>` (absent → all layers),
///    `"order":<int>` (absent → 0, compositing order among views
///    sharing a target), and the quality knobs that inherit the
///    stage's when absent: `"antiAliasing":"none"|"msaa"|"fxaa"|
///    "auto"`, `"renderScale":<num>`, `"filterQuality":"none"|"low"|
///    "medium"|"high"`. dart3d extension: an entry may also carry
///    `"viewport":[l,b,w,h]` — doubles in target-pixel units, a
///    split-screen rect inside the target (absent = full target).
/// - `{"op":"render","target":"rt:<id>"}` — triggers one render pass
///    for a `RenderTextureResource` whose `update` is `'manual'`
///    (also valid for `interval` — forces an early refresh).
///
/// W15 streams lazy prefab subtrees. A node whose spec carries an
/// `instance` member (manifest `nodes` entry, `addNode`, or
/// `updateNode` — the member always travels with the full spec) is a
/// placeholder: the native records the tag but realizes no content
/// for it until the subtree lands. `SceneController.loadSubtree`
/// composes the instance's prefab upstream and ships the result as
/// the standard structural batch nested under an envelope op;
/// `unloadSubtree` ships the reverse batch:
///
/// - `{"op":"loadSubtree","node":"<id>","ops":[<op>,…]}` — requires
///    `node` to exist (it is the placeholder; a node without the
///    `instance` tag warns and still applies — the batch is
///    self-describing). `ops` are applied in order through the same
///    dispatch as top-level commands: the first `updateNode` re-specs
///    the instance without the `instance` member, which clears the
///    placeholder tag; payload/resource upserts land before the
///    member `addNode`s (parents precede children); `Attachment`
///    grafts arrive as reparent-only `updateNode`s.
/// - `{"op":"unloadSubtree","node":"<id>","ops":[<op>,…]}` — same
///    envelope around the reverse batch: attachment targets reparent
///    to their authored parents first (so grafted host nodes leave
///    the doomed subtree), `removeNode` drops each streamed root,
///    and a final `updateNode` restores the placeholder spec — the
///    `instance` member rides the wire again and the node re-tags.
///
/// The envelope keeps one subtree mutation atomic inside the mutation
/// queue's drain — no partial subtree is observable between commands.
/// Repeating either op is safe by the same idempotency rules as the
/// ops it carries.
///
/// Physics ops act on nodes' rigid bodies and carry `.fscene`-space
/// vectors (the native side applies the same LH→RH z-mirror as for
/// transforms; torque/angular axes are pseudovectors and mirror like
/// quaternion axes):
///
/// - `{"op":"applyImpulse","node":"<id>","impulse":[x,y,z],
///    "position":[x,y,z]?}` — world-space impulse; optional world point.
/// - `{"op":"applyTorque","node":"<id>","torque":[x,y,z,w]}` — world axis
///    + magnitude impulse.
/// - `{"op":"setVelocity","node":"<id>","velocity":[x,y,z]?,
///    "angularVelocity":[x,y,z,w]?}` — linear m/s and/or axis+rate rad/s.
/// - `{"op":"clearForces","node":"<id>"}` — drop accumulated forces.
///
/// Joint ops create and steer constraints between two bodies — the
/// runtime-only half of upstream's physics surface (`createJoint`/
/// `updateJoint`/`destroyJoint`; no `.fscene` component encodes them).
/// `id` is a caller-chosen u32 handle — upstream's `createJoint` return
/// value, minted Dart-side because the native apply is async; one id
/// space per view, reusable after `removeJoint`. `a`/`b` are the joined
/// bodies' node tokens, `ca`/`cb` collider indices within each node
/// (`0` is the norm — a node's colliders compose one body today), and
/// `collide` keeps the joined pair colliding (default `false`).
/// Anchors and axes are BODY-LOCAL on the wire; natives convert to
/// their engine's frame at creation. If `a`/`b` isn't a live rigid-body
/// node yet the op defers like a payload claim.
///
/// - `{"op":"addJoint","id":7,"type":…,"a":"<id>","b":"<id>","ca":0,
///    "cb":0,"collide":false,"anchorA":[x,y,z],"anchorB":[x,y,z],
///    "breakDistance":<d>?}`
/// - `{"op":"updateJoint","id":7,…same fields as addJoint…}` —
///    backends without in-place update recreate the constraint.
/// - `{"op":"removeJoint","id":7}`.
///
/// Per `type`: `fixed` and `spherical` carry anchors only; `revolute`
/// and `prismatic` add `"axisA":[x,y,z],"axisB":[x,y,z]` plus optional
/// `"lower"`,`"upper"` (radians / meters) and `"motorVelocity"`,
/// `"motorMaxForce"`; `generic` adds `"basisA"/"basisB":[x,y,z,w]`
/// constraint-frame quats and `"axes"` — six entries in `JointAxis`
/// order (linearX…angularZ), each `{"motion":"locked|free|limited",
/// "lower":f,"upper":f,"motor":{…}?}` with `lower`/`upper` present only
/// on `limited` and `motor` as `{"targetPosition":f,"targetVelocity":f,
/// "stiffness":f,"damping":f,"maxForce":f?,"model":"acceleration"|
/// "force"}` (`maxForce` absent when unbounded). `breakDistance` is a
/// dart3d extension on any type: the native side polls the anchors'
/// world-space separation each step, removes the constraint past the
/// threshold, and fires the `joint` event below.
///
/// Physics queries ride the same `command` tag as
/// `{"op":"query","q":<u32>,"type":…,…}`; `q` is a per-controller
/// correlation id that the matching `D3Event.queryReply` frame echoes:
///
/// - `{"op":"query","q":…,"type":"pose","nodes":["<id>"…]}` — world
///    poses of the named rigid-body nodes; `"nodes":["all"]` (or
///    `nodes` omitted) returns every body.
/// - `{"op":"query","q":…,"type":"raycast","origin":[x,y,z],
///    "direction":[x,y,z],"maxDistance":<d>,"all":<bool>}` — closest
///    hit, or every hit when `all`.
/// - `{"op":"query","q":…,"type":"overlap","shape":{…},
///    "position":[x,y,z],"rotation":[x,y,z,w]?}` — colliders
///    intersecting `{"type":"sphere","radius":r}` or
///    `{"type":"box","extents":[x,y,z]}` (full extents) at the pose;
///    `rotation` defaults to identity.
/// - `{"op":"query","q":…,"type":"shapecast","shape":{…},"from":[x,y,z],
///    "to":[x,y,z]}` — sweep hits along the segment (sphere shapes
///    only, matching upstream).
///
/// Native→Dart traffic (physics events, query replies) does not use
/// the mutation channel at all: it rides the plugin dispatcher slot
/// (`Dart3dSetDispatcher`, see dispatch.dart) as
/// `(token=viewId, type, json)` frames:
///
/// - `D3Event.contact` (type 3): one collider-pair lifecycle
///    transition —
///    `{"kind":"began"|"ended"|"triggerEntered"|"triggerExited",
///    "a":{"s":,"i":},"ca":<collider index>,"b":{…},"cb":<…>,
///    "points":[{"p":[x,y,z],"n":[x,y,z],"imp":<double>,
///    "sep":<double>}]}` — `points` on `began` only; the trigger kinds
///    replace began/ended when either collider is a sensor.
/// - `D3Event.queryReply` (type 4): the answer to a `query` op —
///    `{"q":<id>,"type":"pose","poses":[{"node":{"s":,"i":},"p":[x,y,z],
///    "r":[x,y,z,w]}]}` or `{"q":<id>,"type":"raycast"|"overlap"|
///    "shapecast","hits":[{"node":{…},"collider":<i>,"p":[…],"n":[…]?,
///    "d":<dist>}]}` (overlap hits carry just `node`+`collider`; `[]`
///    on a miss) — or `{"q":<id>,"error":<message>}` for a malformed
///    or unknown query.
/// - `D3Event.joint` (type 5): a joint lifecycle event —
///    `{"kind":"broke","id":<joint id>,"a":{"s":,"i":},"b":{…}|null}` —
///    fired when a `breakDistance` joint's anchors separate past the
///    threshold; the constraint is already removed when the frame
///    lands. `b` is null for a world-anchored joint component (W12 —
///    absent `otherNode`). A dart3d extension (upstream has no joint
///    events); `kind` leaves the frame open to further kinds.
///
/// The native side must treat unknown tags as no-ops (log only) and must
/// validate `hello` before applying anything else.
abstract final class D3Protocol {
  /// Protocol version sent in the `hello` mutation.
  static const int major = 1;
  static const int minor = 0;

  static const int hello = 1;
  static const int loadScene = 2;
  static const int payload = 3;
  static const int setTransforms = 4;
  static const int command = 5;
  static const int viewConfig = 6;

  /// `[u8 major][u8 minor]`.
  static Uint8List helloBytes() => Uint8List.fromList([major, minor]);

  /// Canonical `.fscene` JSON for [doc], utf8-encoded.
  static Uint8List loadSceneBytes(SceneDocument doc) =>
      Uint8List.fromList(utf8.encode(writeFscene(doc)));

  /// `[8B payloadId][raw bytes]` for one [PayloadSpec].
  static Uint8List payloadBytes(PayloadSpec payload) {
    final bytes = payload.bytes;
    if (bytes == null) {
      throw ArgumentError('payload ${payload.id} has no bytes to send');
    }
    final out = ByteData(8 + bytes.lengthInBytes);
    writeLocalId(out, 0, payload.id);
    final list = out.buffer.asUint8List();
    list.setRange(
      8,
      list.length,
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    return list;
  }

  /// `[u32 count]` then per entry `[8B nodeId][u8 mask]` followed by the
  /// masked fields: bit 0 = translation f32×3, bit 1 = rotation f32×4,
  /// bit 2 = scale f32×3. Absent fields keep the node's previous values.
  static Uint8List transformsBytes(
    List<({LocalId node, List<double>? t, List<double>? r, List<double>? s})>
    updates,
  ) {
    var size = 4;
    for (final u in updates) {
      size +=
          9 +
          (u.t != null ? 12 : 0) +
          (u.r != null ? 16 : 0) +
          (u.s != null ? 12 : 0);
    }
    final out = ByteData(size);
    out.setUint32(0, updates.length, Endian.little);
    var off = 4;
    for (final u in updates) {
      writeLocalId(out, off, u.node);
      off += 8;
      out.setUint8(
        off,
        (u.t != null ? 1 : 0) | (u.r != null ? 2 : 0) | (u.s != null ? 4 : 0),
      );
      off += 1;
      if (u.t != null) {
        for (var i = 0; i < 3; i++) {
          out.setFloat32(off, u.t![i], Endian.little);
          off += 4;
        }
      }
      if (u.r != null) {
        for (var i = 0; i < 4; i++) {
          out.setFloat32(off, u.r![i], Endian.little);
          off += 4;
        }
      }
      if (u.s != null) {
        for (var i = 0; i < 3; i++) {
          out.setFloat32(off, u.s![i], Endian.little);
          off += 4;
        }
      }
    }
    return out.buffer.asUint8List();
  }

  /// A structural op as utf8 JSON, for example
  /// `{"op":"removeNode","node":"<id token>"}`.
  static Uint8List commandBytes(Map<String, Object?> op) =>
      Uint8List.fromList(utf8.encode(jsonEncode(op)));

  /// View configuration as utf8 JSON.
  static Uint8List viewConfigBytes(Map<String, Object?> config) =>
      Uint8List.fromList(utf8.encode(jsonEncode(config)));

  /// Writes a [LocalId] as `session` u32 then `index` u32, little-endian.
  static void writeLocalId(ByteData out, int offset, LocalId id) {
    out.setUint32(offset, id.session, Endian.little);
    out.setUint32(offset + 4, id.index, Endian.little);
  }
}
