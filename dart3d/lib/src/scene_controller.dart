import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartnative/dartnative.dart' show dnLog;
import 'package:vector_math/vector_math.dart';

import 'scene_model.dart';

import 'animation.dart';
import 'components.dart';
import 'diff_apply.dart';
import 'dispatch.dart';
import 'doc_layer.dart' as doc_layer;
import 'glb_import.dart';
import 'physics.dart';
import 'protocol.dart';
import 'scene_view.dart';
import 'subtree_stream.dart';

/// One node's transform write in a [SceneController.setNodeTransforms]
/// batch. `null` fields keep their previous values.
final class NodeTransform {
  /// Creates a transform update for [node].
  const NodeTransform(this.node, {this.translation, this.rotation, this.scale});

  /// The node to update.
  final LocalId node;

  /// New translation, or null to keep the current value.
  final Vector3? translation;

  /// New rotation, or null to keep the current value.
  final Quaternion? rotation;

  /// New scale, or null to keep the current value.
  final Vector3? scale;
}

/// Owns the scene shown by a [SceneView].
///
/// Create the controller, pass it to the widget, then drive it:
///
/// ```dart
/// final controller = SceneController();
/// // …
/// controller.loadDocument(document);          // full replace
/// controller.setNodeTransforms([…]);          // per-frame writes
/// ```
///
/// Calls made before the native view exists are queued and flushed on
/// attach, so `loadDocument` may be issued before the widget mounts.
/// Structural edits go through [applyCommands]; per-frame transform writes
/// go through [setNodeTransforms] — callers should batch to one call per
/// frame (the mutation crosses to native on the platform thread).
final class SceneController {
  SceneViewElement? _element;
  SceneDocument? _document;
  final List<({int tag, Uint8List data})> _pending = [];
  // W15: instance node id → the stream record unloadSubtree reverses.
  // Entries live only while a subtree is streamed; loadDocument clears
  // them with the rest of the scene.
  final Map<LocalId, StreamedSubtree> _streamed = {};
  final StreamController<ScenePhysicsEvent> _physicsEvents =
      StreamController<ScenePhysicsEvent>.broadcast();
  final StreamController<SceneCollisionEvent> _contactEvents =
      StreamController<SceneCollisionEvent>.broadcast();
  final StreamController<SceneJointBroke> _jointEvents =
      StreamController<SceneJointBroke>.broadcast();
  int _jointSeq = 0;
  int _querySeq = 0;
  final Map<int, Completer<Map<String, Object?>>> _pendingQueries = {};

  /// The document most recently sent to the view, or null.
  SceneDocument? get document => _document;

  /// Whether a native view is currently attached.
  bool get isAttached => _element != null;

  /// Physics events fired from the native simulation: `SceneAwakeEvent`
  /// when bodies start moving, `SceneSettledEvent` (with final poses)
  /// when every dynamic body has come to rest.
  Stream<ScenePhysicsEvent> get physicsEvents => _physicsEvents.stream;

  /// Collider-pair lifecycle events from the native simulation:
  /// `SceneCollisionBegan`/`SceneCollisionEnded` for solid pairs,
  /// `SceneTriggerEntered`/`SceneTriggerExited` when either collider is
  /// a sensor. One event per pair per transition; began events carry
  /// the contact manifold.
  Stream<SceneCollisionEvent> get contactEvents => _contactEvents.stream;

  /// Joint lifecycle events — today only [SceneJointBroke], fired when a
  /// joint created with `breakDistance` exceeds that world-space anchor
  /// separation; the native side has already removed the constraint when
  /// the event lands (a dart3d extension — upstream has no joint events).
  Stream<SceneJointBroke> get jointEvents => _jointEvents.stream;

  /// Replaces the whole scene with [doc]'s contents.
  ///
  /// Sends the canonical `.fscene` manifest, then one `payload` mutation
  /// per payload chunk the document carries.
  ///
  /// Feature negotiation runs before anything sends: unrealized
  /// `featuresRequired`/`featuresUsed` names always log, and with
  /// [strictFeatures] a document requiring an unrealized feature is
  /// refused with [FsceneUnsupportedFeatureException] — upstream's
  /// required-means-refuse rule applied to the engine's realized set
  /// (W29). The default is warn-only (W12).
  void loadDocument(SceneDocument doc, {bool strictFeatures = false}) {
    if (strictFeatures) {
      final missing = missingRequiredFeatures(doc);
      if (missing.isNotEmpty) {
        throw FsceneUnsupportedFeatureException(missing.first);
      }
    }
    _document = doc;
    _streamed.clear();
    _warnUnrealizedFeatures(doc);
    _sendOrQueue(D3Protocol.loadScene, D3Protocol.loadSceneBytes(doc));
    for (final payload in doc.payloads.values) {
      if (payload.bytes == null) continue;
      _sendOrQueue(D3Protocol.payload, D3Protocol.payloadBytes(payload));
    }
  }

  /// Expands [doc]'s prefab instances via upstream `composeSceneAsync`
  /// (W15) — every eager `instance` is resolved through [loadPrefab]
  /// and inlined — then sends the result through [loadDocument]. Lazy
  /// instances pass through untouched and arrive as tagged placeholder
  /// nodes, resolvable later via [loadSubtree].
  ///
  /// Host asset resolution stays with the caller: [loadPrefab] maps
  /// each `instance.source` AssetRef to its decoded (uncomposed)
  /// document, exactly as `composeSceneAsync`'s `load` contract
  /// specifies.
  Future<void> loadDocumentComposed(
    SceneDocument doc, {
    required AsyncPrefabLoader loadPrefab,
  }) async {
    loadDocument(await composeSceneAsync(doc, load: loadPrefab));
  }

  /// Parses a `.fscene` JSON/JSONC [source] and loads it — upstream's
  /// `readFscene`, which runs the `migrateFscene` chain so older schema
  /// versions upgrade on load (W29). An upgrade logs a one-line
  /// `migrated fscene vN→vM` so lane runs can see it. [strictFeatures]
  /// follows [loadDocument].
  void loadFscene(String source, {bool strictFeatures = false}) => loadDocument(
    doc_layer.readFsceneLogged(source, log: dnLog),
    strictFeatures: strictFeatures,
  );

  /// Imports a single-file `.glb` in memory and loads it — the
  /// `Node.fromGlbBytes` equivalent (W29). [onWarning] receives
  /// non-fatal import issues; [strictFeatures] follows [loadDocument].
  void loadGlb(
    Uint8List glbBytes, {
    GltfWarningCallback? onWarning,
    bool strictFeatures = false,
  }) => loadDocument(
    importGlbToSceneDocument(glbBytes, onWarning: onWarning),
    strictFeatures: strictFeatures,
  );

  /// Imports a multi-file `.gltf` (JSON plus external resources fetched
  /// through [resolveUri]) and loads it. [strictFeatures] follows
  /// [loadDocument].
  void loadGltf(
    Uint8List gltfBytes, {
    required GltfUriResolver resolveUri,
    GltfWarningCallback? onWarning,
    bool strictFeatures = false,
  }) => loadDocument(
    importGltfToSceneDocument(
      gltfBytes,
      resolveUri: resolveUri,
      onWarning: onWarning,
    ),
    strictFeatures: strictFeatures,
  );

  /// The live scene back as a standalone [SceneDocument] — upstream's
  /// `serializeScene(Node root)` for dart3d's document-shaped graph
  /// (W29). Everything sent since the last load is folded in:
  /// [applyCommands] structural ops, [setNodeTransforms] writes, and
  /// [sendPayload] deliveries, so a scene built or edited at runtime
  /// serializes truthfully. Serialize the result with `writeFscene`;
  /// reload it with [loadDocument] or [loadFscene].
  ///
  /// Returns null until the first document or structural op lands.
  /// Runtime state the format doesn't model — animation playheads,
  /// physics poses, joint constraints, morph weights — is not captured,
  /// same as upstream.
  SceneDocument? serializeScene() {
    final doc = _document;
    return doc == null ? null : doc_layer.serializeScene(doc);
  }

  /// Sends one payload chunk to the native side — for payloads the
  /// document declared with `bytes: null` (loadDocument skips those;
  /// the manifest entry already went out, so the geometry that
  /// references it re-realizes when the chunk lands). Throws
  /// [ArgumentError] if [payload] still has no bytes.
  ///
  /// A payload sent before any [loadDocument] still lands natively,
  /// so it mints a fresh document to fold into — same as
  /// [applyCommands] — rather than going missing from
  /// [serializeScene].
  void sendPayload(PayloadSpec payload) {
    doc_layer.foldPayloadIntoDocument(_document ??= SceneDocument(), payload);
    _sendOrQueue(D3Protocol.payload, D3Protocol.payloadBytes(payload));
  }

  /// Applies structural ops (utf8 JSON commands) to the live scene without
  /// replacing it. Supported ops: `addNode`, `removeNode`, `updateNode`,
  /// `upsertResource`, `upsertPayload`, `updateStage`, `upsertSkin`,
  /// `upsertAnimation`, `removeSkin`, `removeAnimation`, `anim`,
  /// `setMorphWeights`, `updateViews`, `render`, `loadSubtree`,
  /// `unloadSubtree`, the physics/joint ops, and `query`.
  ///
  /// Ops that carry document state (`commandAffectsDocument`'s set)
  /// fold into the tracked [document] as they go out — that fold is
  /// what [serializeScene] reads back. A scene built entirely from ops
  /// gets a fresh document to fold into; a fold that can't decode an
  /// op logs and drops just that mirror update, never the send.
  void applyCommands(List<Map<String, Object?>> ops) {
    if (ops.isEmpty) return;
    for (final op in ops) {
      if (doc_layer.commandAffectsDocument(op)) {
        try {
          doc_layer.foldCommandIntoDocument(_document ??= SceneDocument(), op);
        } catch (e) {
          dnLog('dart3d: document mirror dropped op ${op['op']} ($e)');
        }
      }
      _sendOrQueue(D3Protocol.command, D3Protocol.commandBytes(op));
    }
  }

  /// Applies [diff] — the `diffScene` result from the controller's
  /// [document] to [newDoc] — to the live scene as one ordered command
  /// batch, and returns the emitted ops.
  ///
  /// The batch order is canonical: `removeSkin`/`removeAnimation`,
  /// `removeNode`, `upsertPayload`, `upsertResource`, `addNode`,
  /// `updateNode`, `upsertSkin`, `upsertAnimation`, `updateStage` —
  /// detaches precede re-adds and chunks land before the resources,
  /// skins, and nodes that consume them (see
  /// docs/structural-commands-spec.md and
  /// docs/animation-skins-morphs-spec.md). [newDoc] becomes the
  /// tracked [document], so chain the next diff against it.
  List<Map<String, Object?>> applyDiff(SceneDiff diff, SceneDocument newDoc) {
    final ops = diffCommands(diff, _document, newDoc);
    // A streamed instance that is itself removed drops its stream
    // record — the removeNode took the whole subtree with it.
    for (final id in diff.removed) {
      _streamed.remove(id);
    }
    _document = newDoc;
    _warnUnrealizedFeatures(newDoc);
    // No document fold — newDoc is already the post-op state.
    for (final op in ops) {
      _sendOrQueue(D3Protocol.command, D3Protocol.commandBytes(op));
    }
    return ops;
  }

  /// Writes transforms for [updates] in one batched mutation.
  ///
  /// This is the hot path — physics write-back and programmatic animation
  /// both funnel here. Fields left null on a [NodeTransform] keep the
  /// node's previous value on the native side.
  void setNodeTransforms(List<NodeTransform> updates) {
    if (updates.isEmpty) return;
    final doc = _document;
    if (doc != null) {
      for (final u in updates) {
        doc_layer.foldTransformIntoDocument(
          doc,
          u.node,
          translation: u.translation,
          rotation: u.rotation,
          scale: u.scale,
        );
      }
    }
    _sendOrQueue(
      D3Protocol.setTransforms,
      D3Protocol.transformsBytes([
        for (final u in updates)
          (
            node: u.node,
            t: u.translation == null
                ? null
                : [u.translation!.x, u.translation!.y, u.translation!.z],
            r: u.rotation == null
                ? null
                : [u.rotation!.x, u.rotation!.y, u.rotation!.z, u.rotation!.w],
            s: u.scale == null ? null : [u.scale!.x, u.scale!.y, u.scale!.z],
          ),
      ]),
    );
  }

  /// Sends a view configuration mutation immediately (used by the element
  /// to push widget props; apps normally just set them on [SceneView]).
  void sendViewConfig(Map<String, Object?> config) {
    _sendOrQueue(D3Protocol.viewConfig, D3Protocol.viewConfigBytes(config));
  }

  /// Removes [id] and its subtree from the live scene.
  void removeNode(LocalId id) {
    _streamed.remove(id);
    applyCommands([
      {'op': 'removeNode', 'node': id.toToken()},
    ]);
  }

  // MARK: - Prefab subtree streaming (W15)

  /// The node [id] as the live scene knows it — the tracked
  /// document's spec, or a nested placeholder recorded by the stream
  /// that delivered it. Streamed members never join [_document], so a
  /// lazy instance inside a streamed subtree resolves through the
  /// parent stream's [StreamedSubtree.placeholders].
  NodeSpec? _liveNode(LocalId id) {
    final tracked = _document?.nodes[id];
    if (tracked != null) return tracked;
    for (final s in _streamed.values) {
      final p = s.placeholders[id];
      if (p != null) return p;
    }
    return null;
  }

  /// Realizes the lazy prefab instance at [id] — expands the subtree
  /// the placeholder tags and sends it as one `loadSubtree` command.
  ///
  /// [resolve] maps the instance's `source` AssetRef to the prefab's
  /// decoded (uncomposed) document — host asset resolution stays on
  /// the host layer, the same contract `composeScene` gives its
  /// `resolve`. The returned ops are upstream composition translated
  /// into the standard structural batch: the placeholder's own
  /// `updateNode` re-specs it without `instance` (clearing the native
  /// placeholder tag), payloads and resources upsert first, member
  /// `addNode`s follow parent-before-child, and `Attachment` grafts
  /// ride `updateNode` reparents.
  ///
  /// Calling this on an already-streamed instance re-composes and
  /// re-sends; roots the previous stream created that the new compose
  /// no longer produces are removed first, so a re-load replaces
  /// rather than piles up. Throws [ArgumentError] when [id] is not a
  /// tracked node or streamed member, or carries no `instance`.
  void loadSubtree(LocalId id, {required PrefabResolver resolve}) {
    final doc = _document;
    final node = _liveNode(id);
    if (node == null) {
      throw ArgumentError('loadSubtree: no node ${id.toToken()}');
    }
    final result = encodeSubtreeLoad(
      node,
      resolve: resolve,
      hostDoc: doc,
      priorRoots: _streamed[id]?.roots ?? const [],
    );
    applyCommands([
      {'op': 'loadSubtree', 'node': id.toToken(), 'ops': result.ops},
    ]);
    _streamed[id] = result.streamed;
  }

  /// [loadSubtree] on upstream `composeSceneAsync` — [loadPrefab]
  /// resolves each `source` AssetRef to its decoded document
  /// transitively (eager prefabs inside the streamed prefab
  /// included), for callers whose asset layer is async.
  Future<void> loadSubtreeAsync(
    LocalId id, {
    required AsyncPrefabLoader loadPrefab,
  }) async {
    final doc = _document;
    final node = _liveNode(id);
    if (node == null) {
      throw ArgumentError('loadSubtreeAsync: no node ${id.toToken()}');
    }
    final result = await encodeSubtreeLoadAsync(
      node,
      loadPrefab: loadPrefab,
      hostDoc: doc,
      priorRoots: _streamed[id]?.roots ?? const [],
    );
    applyCommands([
      {'op': 'loadSubtree', 'node': id.toToken(), 'ops': result.ops},
    ]);
    _streamed[id] = result.streamed;
  }

  /// Reverses [loadSubtree] at [id]: attachment targets reparent to
  /// their authored homes, streamed roots drop, and the placeholder
  /// spec restores — the `instance` member rides the wire again, so
  /// the node re-tags as a loadable placeholder. No-ops when [id] has
  /// no live stream.
  void unloadSubtree(LocalId id) {
    final streamed = _streamed.remove(id);
    if (streamed == null) return;
    final doc = _document;
    final node = _liveNode(id);
    // A live stream implies a document — but [_liveNode] now resolves
    // through stream records too, so guard rather than force.
    if (doc == null || node == null) return;
    final parents = <LocalId, LocalId?>{
      for (final n in doc.nodes.keys) n: null,
    };
    for (final n in doc.nodes.values) {
      for (final c in n.children) {
        parents[c] = n.id;
      }
    }
    applyCommands([
      {
        'op': 'unloadSubtree',
        'node': id.toToken(),
        'ops': encodeSubtreeUnload(
          node,
          streamed: streamed,
          attachmentHomes: {
            for (final t in streamed.attachments) t: parents[t],
          },
          hostDoc: doc,
        ),
      },
    ]);
  }

  // MARK: - Physics

  /// Applies an instantaneous world-space [impulse] to [node]'s rigid
  /// body, optionally at world-space [at] (defaults to the body's center
  /// of mass — an off-center impulse also induces spin). No-op if the
  /// node has no rigid body.
  void applyImpulse(LocalId node, Vector3 impulse, {Vector3? at}) {
    applyCommands([
      {
        'op': 'applyImpulse',
        'node': node.toToken(),
        'impulse': [impulse.x, impulse.y, impulse.z],
        if (at != null) 'position': [at.x, at.y, at.z],
      },
    ]);
  }

  /// Applies an instantaneous angular impulse: [axis] (world space) with
  /// [magnitude] in newton-meter-seconds.
  void applyTorqueImpulse(LocalId node, Vector3 axis, double magnitude) {
    applyCommands([
      {
        'op': 'applyTorque',
        'node': node.toToken(),
        'torque': [axis.x, axis.y, axis.z, magnitude],
      },
    ]);
  }

  /// Sets a rigid body's velocities directly. [linear] is world-space
  /// m/s; [angularAxis]+[angularRate] is the axis-and-rate form SceneKit
  /// uses (radians/second).
  void setBodyVelocity(
    LocalId node, {
    Vector3? linear,
    Vector3? angularAxis,
    double? angularRate,
  }) {
    applyCommands([
      {
        'op': 'setVelocity',
        'node': node.toToken(),
        if (linear != null) 'velocity': [linear.x, linear.y, linear.z],
        if (angularAxis != null)
          'angularVelocity': [
            angularAxis.x,
            angularAxis.y,
            angularAxis.z,
            angularRate ?? 0,
          ],
      },
    ]);
  }

  /// Clears all forces and impulses accumulated on [node]'s rigid body.
  void clearForces(LocalId node) {
    applyCommands([
      {'op': 'clearForces', 'node': node.toToken()},
    ]);
  }

  // MARK: - Joints

  /// Adds a joint between two rigid-body nodes and returns its handle —
  /// a caller-side u32 minted from a per-controller sequence (upstream's
  /// `createJoint` returns the handle synchronously; the native apply is
  /// async by construction). Ids may be reused after [removeJoint].
  ///
  /// Anchors and axes on [joint] are body-local; if either body isn't a
  /// live rigid-body node yet the op defers natively like a payload
  /// claim.
  int addJoint(SceneJoint joint) {
    final id = _jointSeq;
    _jointSeq = d3NextJointSeq(_jointSeq);
    applyCommands([
      {'op': 'addJoint', 'id': id, ...joint.toWire()},
    ]);
    return id;
  }

  /// Reconfigures joint [id] — same field set as [addJoint]. Backends
  /// without in-place update recreate the native constraint (upstream's
  /// own `updateJoint` contract).
  void updateJoint(int id, SceneJoint joint) {
    applyCommands([
      {'op': 'updateJoint', 'id': id, ...joint.toWire()},
    ]);
  }

  /// Removes joint [id]; the handle becomes reusable.
  void removeJoint(int id) {
    applyCommands([
      {'op': 'removeJoint', 'id': id},
    ]);
  }

  // MARK: - Skins and animation

  /// The tracked [document]'s animation pool as read-only
  /// [SceneAnimation] handles — descriptors of the animations the
  /// `anim` op addresses. Rebuilt from the document on each read;
  /// empty until a document carrying `animations` loads.
  Map<LocalId, SceneAnimation> get animations {
    final doc = _document;
    if (doc == null || doc.animations.isEmpty) return const {};
    return Map.unmodifiable({
      for (final entry in doc.animations.entries)
        entry.key: SceneAnimation.fromSpec(entry.value, doc),
    });
  }

  /// Starts (or resumes) animation [id] — upstream `AnimationClip`'s
  /// `play`/`gotoAndPlay` depending on whether [time] is given.
  /// [loop] wraps the clip at its end instead of pausing, [weight] is
  /// the blend weight (clamped to `[0, 1]` natively), [timeScale]
  /// scales the advance rate, and [time] seeks before playing.
  /// Absent knobs keep the clip's current values.
  void playAnimation(
    LocalId id, {
    bool? loop,
    double? weight,
    double? timeScale,
    double? time,
  }) {
    applyCommands([
      encodeAnimCommand(
        id,
        play: true,
        time: time,
        timeScale: timeScale,
        weight: weight,
        loop: loop,
      ),
    ]);
  }

  /// Pauses animation [id] at its current playback time.
  void pauseAnimation(LocalId id) {
    applyCommands([encodeAnimCommand(id, pause: true)]);
  }

  /// Pauses animation [id] and seeks it back to the beginning.
  void stopAnimation(LocalId id) {
    applyCommands([encodeAnimCommand(id, stop: true)]);
  }

  /// Seeks animation [id] to [time] (clamped to `[0, endTime]`
  /// natively) without changing its playing state.
  void seekAnimation(LocalId id, double time) {
    applyCommands([encodeAnimCommand(id, time: time)]);
  }

  /// Writes [node]'s morph target weights directly — one weight per
  /// target, replacing whatever the mesh currently blends (including
  /// a weights channel a playing animation drives).
  void setMorphWeights(LocalId node, List<double> weights) {
    applyCommands([encodeMorphWeightsCommand(node, weights)]);
  }

  // MARK: - Material variants

  /// Selects variant [name] on the `materialsVariants` component
  /// mounted on [node] — upstream `MaterialsVariantsComponent.select`.
  /// Each resolved binding's primitive swaps to the variant's mapped
  /// material, or back to its recorded default when the variant has
  /// no mapping. A null or unknown [name] re-applies the defaults.
  void selectMaterialVariant(LocalId node, String? name) {
    applyCommands([encodeSelectVariantCommand(node, name)]);
  }

  // MARK: - Render textures and views

  /// Triggers one render pass for the `RenderTextureResource` [id] —
  /// the `render` op (W14). Required to refresh a `manual` target; on
  /// an `interval` target it forces an early refresh.
  void renderTexture(LocalId id) {
    applyCommands([encodeRenderCommand(id)]);
  }

  /// Replaces the live view list wholesale with [views] — the
  /// `updateViews` op (W14). Entries encode in the manifest `_encodeView`
  /// shape with the tracked [document]'s id keys (`n:`/`rt:`/…
  /// prefixes); before any document loads, bare id tokens go out —
  /// the native decoders strip prefixes either way. To ship the dart3d
  /// `viewport` extension or reference ids outside the document, send
  /// pre-encoded entries through [applyCommands] directly.
  void updateViews(List<RenderViewSpec> views) {
    final doc = _document;
    applyCommands([
      {
        'op': 'updateViews',
        'views': [
          for (final v in views)
            encodeViewSpec(
              v,
              doc == null ? (LocalId id) => id.toToken() : manifestIdKey(doc),
            ),
        ],
      },
    ]);
  }

  // MARK: - Physics queries

  /// Reads [node]'s current world pose, or null when the node isn't in
  /// the reply (no body, not realized). Completes with an error if the
  /// view detaches or the controller is disposed before the reply.
  Future<ScenePose?> poseOf(LocalId node) async {
    final reply = await _query({
      'type': 'pose',
      'nodes': [node.toToken()],
    });
    for (final pose in decodePoseReply(reply)) {
      if (pose.node == node) return pose;
    }
    return null;
  }

  /// Reads the current world pose of every rigid-body node.
  Future<List<ScenePose>> poses() async {
    final reply = await _query({
      'type': 'pose',
      'nodes': ['all'],
    });
    return decodePoseReply(reply);
  }

  /// Casts a ray from [origin] along [direction] (world space,
  /// `.fscene` coordinates) up to [maxDistance]. Returns the closest
  /// hit, or every hit nearest-first when [all] is set; `[]` on a miss.
  Future<List<SceneRaycastHit>> raycast({
    required Vector3 origin,
    required Vector3 direction,
    double maxDistance = 100.0,
    bool all = false,
  }) async {
    final reply = await _query({
      'type': 'raycast',
      'origin': [origin.x, origin.y, origin.z],
      'direction': [direction.x, direction.y, direction.z],
      'maxDistance': maxDistance,
      'all': all,
    });
    return decodeRaycastReply(reply);
  }

  /// Returns every collider intersecting a sphere of [radius] at
  /// world-space [center].
  Future<List<SceneOverlapHit>> overlapSphere(Vector3 center, double radius) =>
      _overlap({'type': 'sphere', 'radius': radius}, center, null);

  /// Returns every collider intersecting a box of full [extents] at
  /// world-space [center], optionally [rotation]-posed.
  Future<List<SceneOverlapHit>> overlapBox(
    Vector3 center,
    Vector3 extents, {
    Quaternion? rotation,
  }) => _overlap(
    {
      'type': 'box',
      'extents': [extents.x, extents.y, extents.z],
    },
    center,
    rotation,
  );

  /// Sweeps a sphere of [radius] from [from] to [to] (world space) and
  /// returns the hits nearest-first; `[]` on a miss. Sphere shapes only,
  /// matching upstream's bound.
  Future<List<SceneRaycastHit>> shapeCastSphere({
    required double radius,
    required Vector3 from,
    required Vector3 to,
  }) async {
    final reply = await _query({
      'type': 'shapecast',
      'shape': {'type': 'sphere', 'radius': radius},
      'from': [from.x, from.y, from.z],
      'to': [to.x, to.y, to.z],
    });
    return decodeRaycastReply(reply);
  }

  Future<List<SceneOverlapHit>> _overlap(
    Map<String, Object?> shape,
    Vector3 position,
    Quaternion? rotation,
  ) async {
    final reply = await _query({
      'type': 'overlap',
      'shape': shape,
      'position': [position.x, position.y, position.z],
      if (rotation != null)
        'rotation': [rotation.x, rotation.y, rotation.z, rotation.w],
    });
    return decodeOverlapReply(reply);
  }

  // Sends one `query` command op and returns the future its matching
  // `queryReply` event completes — `q` is the u32 correlation id. The
  // op queues like any other mutation when no view is attached.
  Future<Map<String, Object?>> _query(Map<String, Object?> request) {
    final q = _querySeq;
    _querySeq = (_querySeq + 1) & 0xFFFFFFFF;
    final completer = Completer<Map<String, Object?>>();
    _pendingQueries[q] = completer;
    applyCommands([
      {'op': 'query', 'q': q, ...request},
    ]);
    return completer.future;
  }

  /// Drops queued mutations and closes the event stream. The native
  /// view keeps running; its events stop reaching Dart.
  void dispose() {
    final element = _element;
    if (element != null) {
      final id = element.viewId;
      if (id != null) d3UnregisterViewHandler(id);
      _element = null;
    }
    _pending.clear();
    d3FailPendingQueries(
      _pendingQueries,
      StateError('dart3d: SceneController disposed'),
    );
    _physicsEvents.close();
    _contactEvents.close();
    _jointEvents.close();
  }

  // MARK: - Native events

  // Handles one event frame from the dispatcher (token = the attached
  // view's id). Payload is JSON; see D3Event in dispatch.dart.
  void _onNativeEvent(int type, String payload) {
    if (_physicsEvents.isClosed) return;
    final Object? json = jsonDecode(payload);
    if (json is! Map<String, Object?>) return;
    switch (type) {
      case D3Event.awake:
        final n = (json['awake'] as num?)?.toInt() ?? 0;
        _physicsEvents.add(SceneAwakeEvent(n));
      case D3Event.settled:
        final nodes = json['nodes'];
        if (nodes is! List) return;
        _physicsEvents.add(
          SceneSettledEvent([
            for (final entry in nodes)
              if (entry case {'s': num s, 'i': num i, 'p': List p, 'r': List r})
                ScenePose(
                  LocalId(s.toInt(), i.toInt()),
                  Vector3(p[0].toDouble(), p[1].toDouble(), p[2].toDouble()),
                  Quaternion(
                    r[0].toDouble(),
                    r[1].toDouble(),
                    r[2].toDouble(),
                    r[3].toDouble(),
                  ),
                ),
          ]),
        );
      case D3Event.contact:
        final event = decodeContactEvent(json);
        if (event != null) _contactEvents.add(event);
      case D3Event.queryReply:
        if (!d3SettleQueryReply(json, _pendingQueries)) {
          dnLog('dart3d: queryReply with no pending query: $payload');
        }
      case D3Event.joint:
        final event = decodeJointEvent(json);
        if (event != null) _jointEvents.add(event);
      default:
        dnLog('dart3d: unknown native event type=$type payload=$payload');
    }
  }

  /// The `featuresRequired`/`featuresUsed` capability pass (W12) —
  /// the pure-Dart check lives in components.dart so `dart test` can
  /// reach it; here each line just goes to the log.
  void _warnUnrealizedFeatures(SceneDocument doc) {
    for (final line in unrealizedFeatureWarnings(doc)) {
      dnLog('dart3d: $line');
    }
  }

  void _sendOrQueue(int tag, Uint8List data) {
    final element = _element;
    if (element == null) {
      _pending.add((tag: tag, data: data));
    } else {
      element.sendMutation(tag, data);
    }
  }

  // Called by SceneViewElement on mount/unmount. Not public API.
  void attachElement(SceneViewElement element) {
    assert(_element == null || identical(_element, element));
    _element = element;
    final id = element.viewId;
    if (id != null) d3RegisterViewHandler(id, _onNativeEvent);
    final pendingReload = _pending.any((p) => p.tag == D3Protocol.loadScene);
    for (final p in _pending) {
      element.sendMutation(p.tag, p.data);
    }
    _pending.clear();
    // A re-attach means the previous native view is gone — its scene
    // went with it. Re-send the live document so the fresh view isn't
    // left empty. A loadScene already in the flush covers this.
    if (!pendingReload && _document != null) {
      loadDocument(_document!);
    }
  }

  /// Called by SceneViewElement on unmount. Not public API.
  void detachElement(SceneViewElement element) {
    if (identical(_element, element)) {
      final id = element.viewId;
      if (id != null) d3UnregisterViewHandler(id);
      _element = null;
      d3FailPendingQueries(
        _pendingQueries,
        StateError('dart3d: scene view detached'),
      );
    }
  }
}
