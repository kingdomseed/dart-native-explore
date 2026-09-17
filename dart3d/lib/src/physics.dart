import 'package:vector_math/vector_math.dart';

import 'scene_model.dart';

/// dart3d's physics component vocabulary and the native→Dart event types.
///
/// The components are `.fscene` `ComponentSpec`s — open `{type, properties}`
/// bags — so they travel inside ordinary scene documents and stay
/// interchangeable with the wider flutter_scene ecosystem. Names mirror the
/// upstream vocabulary: `rigidBody`, `collider`, `physicsWorld`.
///
/// Semantics are engine-agnostic; each native backend maps them to its own
/// API (iOS: `SCNPhysicsBody`/`SCNPhysicsShape`/`SCNPhysicsWorld`). Physical
/// material lives on the collider (Jolt/PhysX convention); SceneKit folds it
/// onto the body — the document doesn't care which.

/// A rigid body on a node: simulation mode and motion tuning.
///
/// [type] is `dynamic` (simulated), `kinematic` (moved by transform writes,
/// pushes dynamics) or `fixed` (immovable). Dynamic bodies take ownership
/// of the node's transform — per-frame `setNodeTransforms` writes to them
/// fight the simulation; use them for kinematic/fixed nodes only.
///
/// [ccdEnabled] turns on continuous collision detection — fast bodies can
/// tunnel through thin walls without it. [linearAxisLocks] and
/// [angularAxisLocks] are per-axis motion factors, 1 free and 0 locked.
/// Surface material and collision filtering live on the collider, not the
/// body.
///
/// [velocity] and [angularVelocityAxis]/[angularVelocityRate] are dart3d
/// extension properties — upstream deliberately does not persist live
/// velocities, but dart3d keeps them so a document can launch a body
/// without a follow-up `setBodyVelocity`. Upstream decoders ignore them.
ComponentSpec rigidBodyComponent({
  String type = 'dynamic',
  double? mass,
  double? linearDamping,
  double? angularDamping,
  bool? useGravity,
  bool? ccdEnabled,
  Vector3? linearAxisLocks,
  Vector3? angularAxisLocks,
  Vector3? velocity,
  Vector3? angularVelocityAxis,
  double? angularVelocityRate,
}) {
  return ComponentSpec(
    'rigidBody',
    properties: {
      'type': StringValue(type),
      if (mass != null) 'mass': DoubleValue(mass),
      if (linearDamping != null) 'linearDamping': DoubleValue(linearDamping),
      if (angularDamping != null)
        'angularDamping': DoubleValue(angularDamping),
      if (useGravity != null) 'useGravity': BoolValue(useGravity),
      if (ccdEnabled != null) 'ccdEnabled': BoolValue(ccdEnabled),
      if (linearAxisLocks != null)
        'linearAxisLocks': Vec3Value(linearAxisLocks),
      if (angularAxisLocks != null)
        'angularAxisLocks': Vec3Value(angularAxisLocks),
      if (velocity != null) 'velocity': Vec3Value(velocity),
      if (angularVelocityAxis != null)
        'angularVelocity': Vec4Value(Vector4(
          angularVelocityAxis.x,
          angularVelocityAxis.y,
          angularVelocityAxis.z,
          angularVelocityRate ?? 0,
        )),
    },
  );
}

/// A collision shape on a node, plus its surface material.
///
/// [shape] names the shape-union kind: `box` (use [extents]), `sphere`
/// ([radius]), `capsule` or `cylinder` ([radius]+[height]),
/// `convexHull`/`triMesh` (derived from the node's own mesh geometry in
/// W2 — payload-backed forms land later), `heightField`, `compound`,
/// plus the dart3d extensions `boundingBox` (the mesh's box, the
/// historical default) and `concaveMesh` (a `triMesh` built from node
/// geometry — only valid on static bodies). The emitter writes the
/// upstream tagged-union map (`{kind: …, halfExtents: …}`), so callers
/// never build it by hand.
///
/// [extents] is a box's FULL size and [height] a capsule or cylinder's
/// full cylindrical length — the emitted `halfExtents`/`halfHeight` are
/// halved, so callers keep thinking in whole sizes. [center] offsets
/// the shape in node space: it becomes the translation of the emitted
/// `localPose` matrix. [localPose] carries a full pose when a
/// translation isn't enough; combined with [center], it supplies the
/// rotation and [center] the offset.
///
/// [friction], [restitution], [density] and the combine rules
/// (`average`, `minimum`, `maximum`, `multiply`) are the surface
/// material, emitted as a nested `material` map — upstream keeps
/// material on the collider only. [collisionLayer]/[collisionMask] are
/// the layer bitmasks; [isTrigger] asks for trigger events instead of
/// contact response.
ComponentSpec colliderComponent({
  String shape = 'boundingBox',
  Vector3? extents,
  double? radius,
  double? height,
  Vector3? center,
  double? friction,
  double? restitution,
  double? density,
  String? frictionCombine,
  String? restitutionCombine,
  int? collisionLayer,
  int? collisionMask,
  bool? isTrigger,
  Matrix4? localPose,
}) {
  // [center] alone is a translation-only pose; with [localPose] also
  // set it replaces the pose's translation and keeps the rotation.
  Matrix4? pose = localPose;
  if (center != null) {
    pose = (pose?.clone() ?? Matrix4.identity())..setTranslation(center);
  }
  return ComponentSpec(
    'collider',
    properties: {
      'shape': MapValue({
        'kind': StringValue(shape),
        if (extents != null) 'halfExtents': Vec3Value(extents * 0.5),
        if (radius != null) 'radius': DoubleValue(radius),
        if (height != null) 'halfHeight': DoubleValue(height * 0.5),
      }),
      if (friction != null ||
          restitution != null ||
          density != null ||
          frictionCombine != null ||
          restitutionCombine != null)
        'material': MapValue({
          if (friction != null) 'friction': DoubleValue(friction),
          if (restitution != null)
            'restitution': DoubleValue(restitution),
          if (density != null) 'density': DoubleValue(density),
          if (frictionCombine != null)
            'frictionCombine': StringValue(frictionCombine),
          if (restitutionCombine != null)
            'restitutionCombine': StringValue(restitutionCombine),
        }),
      if (collisionLayer != null)
        'collisionLayer': IntValue(collisionLayer),
      if (collisionMask != null) 'collisionMask': IntValue(collisionMask),
      if (isTrigger != null) 'isTrigger': BoolValue(isTrigger),
      if (pose != null) 'localPose': Matrix4Value(pose),
    },
  );
}

/// Scene-wide physics settings. Conventionally placed on a root node; it
/// configures the simulation world itself, not the node carrying it.
///
/// [backend] names a registered simulation backend — dart3d has exactly
/// one per platform, so the value rides along for document interchange
/// and is ignored (a name the platform doesn't have logs once rather
/// than silently running the wrong sim). [fixedTimestep] is the fixed
/// step in seconds and [maxSubsteps] the cap on steps per frame; both
/// are advisory on iOS, where SceneKit runs its own internal stepping.
ComponentSpec physicsWorldComponent({
  String? backend,
  Vector3? gravity,
  double? fixedTimestep,
  int? maxSubsteps,
}) {
  return ComponentSpec(
    'physicsWorld',
    properties: {
      if (backend != null) 'backend': StringValue(backend),
      if (gravity != null) 'gravity': Vec3Value(gravity),
      if (fixedTimestep != null)
        'fixedTimestep': DoubleValue(fixedTimestep),
      if (maxSubsteps != null) 'maxSubsteps': IntValue(maxSubsteps),
    },
  );
}

/// A node's world-space pose read back from native, delivered in
/// `.fscene` coordinates (left-handed, +Y up, +Z forward) — the inverse
/// conversion is applied on the native side.
final class ScenePose {
  /// Creates a pose for [node].
  const ScenePose(this.node, this.position, this.rotation);

  /// The node the pose belongs to.
  final LocalId node;

  /// World-space position.
  final Vector3 position;

  /// World-space orientation.
  final Quaternion rotation;
}

/// Base type for events fired from the native simulation back to Dart.
sealed class ScenePhysicsEvent {
  const ScenePhysicsEvent();
}

/// One or more dynamic bodies woke up (an impulse was applied, a body was
/// disturbed). Fired on the transition, not per-body.
final class SceneAwakeEvent extends ScenePhysicsEvent {
  /// Creates the event with [awakeCount] bodies currently awake.
  const SceneAwakeEvent(this.awakeCount);

  /// How many dynamic bodies are currently awake.
  final int awakeCount;
}

/// Every dynamic body in the scene has come to rest — the dice have
/// settled. [poses] carries each dynamic body's final world pose so the
/// app can do its own readout (face-up math lives app-side by design).
final class SceneSettledEvent extends ScenePhysicsEvent {
  /// Creates the event with the settled [poses].
  const SceneSettledEvent(this.poses);

  /// Final world poses of all dynamic bodies, in `.fscene` coordinates.
  final List<ScenePose> poses;
}

/// One contact within a collision manifold, delivered in `.fscene`
/// world coordinates: the contact's [worldPosition], the [worldNormal]
/// pointing out of the touched surface, the applied [impulse], and the
/// signed [separation] (negative while penetrating).
final class SceneContactPoint {
  /// Creates a contact point.
  const SceneContactPoint({
    required this.worldPosition,
    required this.worldNormal,
    required this.impulse,
    required this.separation,
  });

  /// Contact position in world space.
  final Vector3 worldPosition;

  /// Contact normal in world space.
  final Vector3 worldNormal;

  /// The impulse applied at the contact, in newton-seconds (`0` when the
  /// backend doesn't expose per-point impulse).
  final double impulse;

  /// Signed separation at the contact — negative while penetrating.
  final double separation;
}

/// Base type for collider-pair lifecycle events (`D3Event.contact`).
///
/// [nodeA]/[nodeB] are the pair's nodes; [colliderIndexA]/
/// [colliderIndexB] are each collider's index within its node's
/// `components` array — `0` when the backend can't disambiguate a
/// compound. The trigger subclasses replace began/ended whenever either
/// collider is a sensor (`isTrigger`).
sealed class SceneCollisionEvent {
  /// Creates the event for one collider pair.
  const SceneCollisionEvent({
    required this.nodeA,
    required this.nodeB,
    required this.colliderIndexA,
    required this.colliderIndexB,
  });

  /// The pair's first node.
  final LocalId nodeA;

  /// The pair's second node.
  final LocalId nodeB;

  /// [nodeA]'s collider index within its `components` array.
  final int colliderIndexA;

  /// [nodeB]'s collider index within its `components` array.
  final int colliderIndexB;
}

/// Two solid colliders began touching. [contacts] is the manifold at
/// the moment contact began — empty when the backend reports no
/// per-point contact details.
final class SceneCollisionBegan extends SceneCollisionEvent {
  /// Creates the event with the contact [contacts].
  const SceneCollisionBegan({
    required super.nodeA,
    required super.nodeB,
    required super.colliderIndexA,
    required super.colliderIndexB,
    this.contacts = const [],
  });

  /// The contact manifold at the moment contact began.
  final List<SceneContactPoint> contacts;
}

/// Two solid colliders stopped touching.
final class SceneCollisionEnded extends SceneCollisionEvent {
  /// Creates the event for the pair.
  const SceneCollisionEnded({
    required super.nodeA,
    required super.nodeB,
    required super.colliderIndexA,
    required super.colliderIndexB,
  });
}

/// A collider entered a trigger volume — the pair touched and at least
/// one collider is a sensor.
final class SceneTriggerEntered extends SceneCollisionEvent {
  /// Creates the event for the pair.
  const SceneTriggerEntered({
    required super.nodeA,
    required super.nodeB,
    required super.colliderIndexA,
    required super.colliderIndexB,
  });
}

/// A collider left a trigger volume.
final class SceneTriggerExited extends SceneCollisionEvent {
  /// Creates the event for the pair.
  const SceneTriggerExited({
    required super.nodeA,
    required super.nodeB,
    required super.colliderIndexA,
    required super.colliderIndexB,
  });
}

/// One collider hit by a `raycast` or `shapecast` query. [worldPoint]
/// is the hit position and [distance] its distance along the ray or
/// cast; [worldNormal] is the surface normal where the backend reports
/// one — Jolt raycasts don't, so it stays null there.
final class SceneRaycastHit {
  /// Creates a hit.
  const SceneRaycastHit({
    required this.node,
    required this.colliderIndex,
    required this.worldPoint,
    this.worldNormal,
    required this.distance,
  });

  /// The node whose collider was hit.
  final LocalId node;

  /// The hit collider's index within the node's `components` array.
  final int colliderIndex;

  /// Hit position in world space.
  final Vector3 worldPoint;

  /// Surface normal at the hit, or null when the backend doesn't
  /// report one.
  final Vector3? worldNormal;

  /// Distance from the ray origin / cast start to [worldPoint].
  final double distance;
}

/// One collider returned by an `overlap` query — the node plus the
/// collider's index within the node's `components` array.
final class SceneOverlapHit {
  /// Creates a hit.
  const SceneOverlapHit({required this.node, required this.colliderIndex});

  /// The overlapped node.
  final LocalId node;

  /// The overlapped collider's index within the node's `components`
  /// array.
  final int colliderIndex;
}

/// Decodes one `D3Event.contact` payload into its [SceneCollisionEvent]
/// subclass — `began` (carrying `points`), `ended`, `triggerEntered`,
/// `triggerExited`. Returns null on a malformed frame or unknown `kind`.
SceneCollisionEvent? decodeContactEvent(Map<String, Object?> json) {
  final a = _wireLocalId(json['a']);
  final b = _wireLocalId(json['b']);
  if (a == null || b == null) return null;
  final ca = (json['ca'] as num?)?.toInt() ?? 0;
  final cb = (json['cb'] as num?)?.toInt() ?? 0;
  return switch (json['kind']) {
    'began' => SceneCollisionBegan(
      nodeA: a,
      nodeB: b,
      colliderIndexA: ca,
      colliderIndexB: cb,
      contacts: _contactPoints(json['points']),
    ),
    'ended' => SceneCollisionEnded(
      nodeA: a,
      nodeB: b,
      colliderIndexA: ca,
      colliderIndexB: cb,
    ),
    'triggerEntered' => SceneTriggerEntered(
      nodeA: a,
      nodeB: b,
      colliderIndexA: ca,
      colliderIndexB: cb,
    ),
    'triggerExited' => SceneTriggerExited(
      nodeA: a,
      nodeB: b,
      colliderIndexA: ca,
      colliderIndexB: cb,
    ),
    _ => null,
  };
}

/// Decodes the `poses` array of a `pose` `queryReply` — one [ScenePose]
/// per `{"node":{"s","i"},"p":[x,y,z],"r":[x,y,z,w]}` entry; malformed
/// entries are skipped.
List<ScenePose> decodePoseReply(Map<String, Object?> reply) => [
  if (reply['poses'] case List poses)
    for (final e in poses)
      if (e case {
        'node': {'s': num s, 'i': num i},
        'p': [num x, num y, num z],
        'r': [num qx, num qy, num qz, num qw],
      })
        ScenePose(
          LocalId(s.toInt(), i.toInt()),
          Vector3(x.toDouble(), y.toDouble(), z.toDouble()),
          Quaternion(
            qx.toDouble(),
            qy.toDouble(),
            qz.toDouble(),
            qw.toDouble(),
          ),
        ),
];

/// Decodes the `hits` array of a `raycast` or `shapecast` `queryReply`
/// — nearest-first where the backend sorts; a miss decodes to `[]`.
/// `n` may be absent → [SceneRaycastHit.worldNormal] stays null.
List<SceneRaycastHit> decodeRaycastReply(Map<String, Object?> reply) => [
  if (reply['hits'] case List hits)
    for (final h in hits)
      if (h case {
        'node': {'s': num s, 'i': num i},
        'p': [num x, num y, num z],
      })
        SceneRaycastHit(
          node: LocalId(s.toInt(), i.toInt()),
          colliderIndex: (h['collider'] as num?)?.toInt() ?? 0,
          worldPoint: Vector3(x.toDouble(), y.toDouble(), z.toDouble()),
          worldNormal: _wireVec3(h['n']),
          distance: (h['d'] as num?)?.toDouble() ?? 0,
        ),
];

/// Decodes the `hits` array of an `overlap` `queryReply` — node plus
/// collider index per entry; malformed entries are skipped.
List<SceneOverlapHit> decodeOverlapReply(Map<String, Object?> reply) => [
  if (reply['hits'] case List hits)
    for (final h in hits)
      if (h case {'node': {'s': num s, 'i': num i}})
        SceneOverlapHit(
          node: LocalId(s.toInt(), i.toInt()),
          colliderIndex: (h['collider'] as num?)?.toInt() ?? 0,
        ),
];

LocalId? _wireLocalId(Object? json) => switch (json) {
  {'s': num s, 'i': num i} => LocalId(s.toInt(), i.toInt()),
  _ => null,
};

Vector3? _wireVec3(Object? json) => switch (json) {
  [num x, num y, num z] => Vector3(x.toDouble(), y.toDouble(), z.toDouble()),
  _ => null,
};

List<SceneContactPoint> _contactPoints(Object? json) => [
  if (json is List)
    for (final pt in json)
      if (pt case {
        'p': [num x, num y, num z],
        'n': [num nx, num ny, num nz],
      })
        SceneContactPoint(
          worldPosition: Vector3(x.toDouble(), y.toDouble(), z.toDouble()),
          worldNormal: Vector3(nx.toDouble(), ny.toDouble(), nz.toDouble()),
          impulse: (pt['imp'] as num?)?.toDouble() ?? 0,
          separation: (pt['sep'] as num?)?.toDouble() ?? 0,
        ),
];

// MARK: - Joints (W9)

/// The joint kinds a [SceneJoint] describes — one per upstream
/// `JointDesc` subclass. Upstream joints are runtime-only objects
/// (`PhysicsSimulation.createJoint`/`updateJoint`/`destroyJoint`); no
/// `.fscene` component encodes them, so dart3d carries the same
/// descriptions as `addJoint`/`updateJoint`/`removeJoint` command ops.
enum SceneJointType { fixed, spherical, revolute, prismatic, generic }

/// One of the six relative degrees of freedom a [SceneJointType.generic]
/// joint constrains. `axes` lists on the wire are indexed in this order
/// (`linearX`…`angularZ`), matching upstream `JointAxis`.
enum SceneJointAxis { linearX, linearY, linearZ, angularX, angularY, angularZ }

/// How a joint motor's strength is interpreted (upstream
/// `JointMotorModel`).
enum SceneJointMotorModel { acceleration, force }

/// Drives a joint axis toward a target position and/or velocity —
/// upstream `JointMotor` field for field. [maxForce] defaults to
/// unbounded; the wire omits it then (JSON can't express infinity).
final class SceneJointMotor {
  /// Creates a motor config.
  const SceneJointMotor({
    this.targetPosition = 0,
    this.targetVelocity = 0,
    this.stiffness = 0,
    this.damping = 0,
    this.maxForce = double.infinity,
    this.model = SceneJointMotorModel.acceleration,
  });

  /// See upstream `JointMotor.targetPosition`.
  final double targetPosition;

  /// See upstream `JointMotor.targetVelocity`.
  final double targetVelocity;

  /// See upstream `JointMotor.stiffness` — Jolt maps this and [damping]
  /// to `SpringSettings`; iOS hinge/slider motors ignore it.
  final double stiffness;

  /// See upstream `JointMotor.damping`.
  final double damping;

  /// Force/torque cap. Emitted only when finite — natives read an
  /// absent `maxForce` as no cap.
  final double maxForce;

  /// Whether [maxForce] is interpreted as acceleration or force.
  final SceneJointMotorModel model;

  /// The wire form: `{"targetPosition":f,"targetVelocity":f,
  /// "stiffness":f,"damping":f,"maxForce":f?,"model":"acceleration"|
  /// "force"}`.
  Map<String, Object?> toWire() => {
    'targetPosition': targetPosition,
    'targetVelocity': targetVelocity,
    'stiffness': stiffness,
    'damping': damping,
    if (maxForce.isFinite) 'maxForce': maxForce,
    'model': model.name,
  };
}

/// How a single axis of a [SceneJointType.generic] joint is constrained
/// (upstream `JointAxisMotion`).
enum SceneJointAxisMotion { locked, free, limited }

/// Motion allowance for one axis of a generic joint — upstream
/// `JointAxisConfig` field for field. `lowerLimit`/`upperLimit` are
/// emitted only when [motion] is [SceneJointAxisMotion.limited].
final class SceneJointAxisConfig {
  /// The axis cannot move.
  const SceneJointAxisConfig.locked()
    : this._(SceneJointAxisMotion.locked, 0, 0, null);

  /// The axis moves freely, optionally motor-driven.
  const SceneJointAxisConfig.free({SceneJointMotor? motor})
    : this._(SceneJointAxisMotion.free, 0, 0, motor);

  /// The axis moves within `[lowerLimit, upperLimit]`, optionally
  /// motor-driven.
  const SceneJointAxisConfig.limited(
    double lowerLimit,
    double upperLimit, {
    SceneJointMotor? motor,
  }) : this._(SceneJointAxisMotion.limited, lowerLimit, upperLimit, motor);

  const SceneJointAxisConfig._(
    this.motion,
    this.lowerLimit,
    this.upperLimit,
    this.motor,
  );

  /// The constraint applied to the axis.
  final SceneJointAxisMotion motion;

  /// Range lower bound; meaningful only when [motion] is `limited`.
  final double lowerLimit;

  /// Range upper bound; meaningful only when [motion] is `limited`.
  final double upperLimit;

  /// Optional motor driving the axis.
  final SceneJointMotor? motor;

  /// The wire form: `{"motion":"locked|free|limited","lower":f?,
  /// "upper":f?,"motor":{…}?}`.
  Map<String, Object?> toWire() => {
    'motion': motion.name,
    if (motion == SceneJointAxisMotion.limited) ...{
      'lower': lowerLimit,
      'upper': upperLimit,
    },
    if (motor != null) 'motor': motor!.toWire(),
  };
}

/// A joint between two rigid-body nodes — the Dart-side mirror of
/// upstream's `JointDesc` subclasses, folded into one value type with a
/// factory per [SceneJointType] (the wire is the same flat field set, so
/// a sealed hierarchy would only shuffle the same fields around).
///
/// [bodyA]/[bodyB] are the joined bodies' node ids; [colliderIndexA]/
/// [colliderIndexB] select a collider within each node (`0` is the norm
/// — a node's colliders compose one body today). [collisionsEnabled]
/// keeps the joined pair colliding (upstream default `false`).
/// [localAnchorA]/[localAnchorB] and [localAxisA]/[localAxisB] are
/// BODY-LOCAL, matching upstream's `localAnchor*`/`localAxis*`
/// semantics; natives convert to whatever frame their engine wants at
/// creation.
///
/// [breakDistance] is a dart3d extension: when the world-space
/// separation of the two anchors exceeds it, the native side removes
/// the constraint and fires a `D3Event.joint` `broke` frame. Geometric,
/// not force-based — the only semantic expressible on both engines.
final class SceneJoint {
  const SceneJoint._({
    required this.type,
    required this.bodyA,
    required this.bodyB,
    required this.colliderIndexA,
    required this.colliderIndexB,
    required this.collisionsEnabled,
    required this.localAnchorA,
    required this.localAnchorB,
    this.localAxisA,
    this.localAxisB,
    this.lowerLimit,
    this.upperLimit,
    this.motorTargetVelocity,
    this.motorMaxForce,
    this.localBasisA,
    this.localBasisB,
    this.axes,
    this.breakDistance,
  });

  /// Welds the two bodies at their current relative pose (upstream
  /// `FixedJointDesc`).
  factory SceneJoint.fixed({
    required LocalId bodyA,
    required LocalId bodyB,
    int colliderIndexA = 0,
    int colliderIndexB = 0,
    bool collisionsEnabled = false,
    Vector3? localAnchorA,
    Vector3? localAnchorB,
    double? breakDistance,
  }) => SceneJoint._(
    type: SceneJointType.fixed,
    bodyA: bodyA,
    bodyB: bodyB,
    colliderIndexA: colliderIndexA,
    colliderIndexB: colliderIndexB,
    collisionsEnabled: collisionsEnabled,
    localAnchorA: localAnchorA ?? Vector3.zero(),
    localAnchorB: localAnchorB ?? Vector3.zero(),
    breakDistance: breakDistance,
  );

  /// A ball-and-socket constraint at the local anchors (upstream
  /// `SphericalJointDesc`).
  factory SceneJoint.spherical({
    required LocalId bodyA,
    required LocalId bodyB,
    int colliderIndexA = 0,
    int colliderIndexB = 0,
    bool collisionsEnabled = false,
    Vector3? localAnchorA,
    Vector3? localAnchorB,
    double? breakDistance,
  }) => SceneJoint._(
    type: SceneJointType.spherical,
    bodyA: bodyA,
    bodyB: bodyB,
    colliderIndexA: colliderIndexA,
    colliderIndexB: colliderIndexB,
    collisionsEnabled: collisionsEnabled,
    localAnchorA: localAnchorA ?? Vector3.zero(),
    localAnchorB: localAnchorB ?? Vector3.zero(),
    breakDistance: breakDistance,
  );

  /// A hinge about [localAxisA]/[localAxisB], optionally limited and
  /// motorized (upstream `RevoluteJointDesc`).
  factory SceneJoint.revolute({
    required LocalId bodyA,
    required LocalId bodyB,
    required Vector3 localAxisA,
    required Vector3 localAxisB,
    int colliderIndexA = 0,
    int colliderIndexB = 0,
    bool collisionsEnabled = false,
    Vector3? localAnchorA,
    Vector3? localAnchorB,
    double? lowerLimit,
    double? upperLimit,
    double? motorTargetVelocity,
    double? motorMaxForce,
    double? breakDistance,
  }) => SceneJoint._(
    type: SceneJointType.revolute,
    bodyA: bodyA,
    bodyB: bodyB,
    colliderIndexA: colliderIndexA,
    colliderIndexB: colliderIndexB,
    collisionsEnabled: collisionsEnabled,
    localAnchorA: localAnchorA ?? Vector3.zero(),
    localAnchorB: localAnchorB ?? Vector3.zero(),
    localAxisA: localAxisA,
    localAxisB: localAxisB,
    lowerLimit: lowerLimit,
    upperLimit: upperLimit,
    motorTargetVelocity: motorTargetVelocity,
    motorMaxForce: motorMaxForce,
    breakDistance: breakDistance,
  );

  /// A slider along [localAxisA]/[localAxisB], optionally limited and
  /// motorized (upstream `PrismaticJointDesc`).
  factory SceneJoint.prismatic({
    required LocalId bodyA,
    required LocalId bodyB,
    required Vector3 localAxisA,
    required Vector3 localAxisB,
    int colliderIndexA = 0,
    int colliderIndexB = 0,
    bool collisionsEnabled = false,
    Vector3? localAnchorA,
    Vector3? localAnchorB,
    double? lowerLimit,
    double? upperLimit,
    double? motorTargetVelocity,
    double? motorMaxForce,
    double? breakDistance,
  }) => SceneJoint._(
    type: SceneJointType.prismatic,
    bodyA: bodyA,
    bodyB: bodyB,
    colliderIndexA: colliderIndexA,
    colliderIndexB: colliderIndexB,
    collisionsEnabled: collisionsEnabled,
    localAnchorA: localAnchorA ?? Vector3.zero(),
    localAnchorB: localAnchorB ?? Vector3.zero(),
    localAxisA: localAxisA,
    localAxisB: localAxisB,
    lowerLimit: lowerLimit,
    upperLimit: upperLimit,
    motorTargetVelocity: motorTargetVelocity,
    motorMaxForce: motorMaxForce,
    breakDistance: breakDistance,
  );

  /// A six-degree-of-freedom constraint with per-axis motion configs
  /// (upstream `GenericJointDesc`). [axes] takes one
  /// [SceneJointAxisConfig] per [SceneJointAxis], indexed by
  /// `SceneJointAxis.index`; the default is all-free. [localBasisA]/
  /// [localBasisB] orient the constraint frames and default to
  /// identity.
  factory SceneJoint.generic({
    required LocalId bodyA,
    required LocalId bodyB,
    int colliderIndexA = 0,
    int colliderIndexB = 0,
    bool collisionsEnabled = false,
    Vector3? localAnchorA,
    Vector3? localAnchorB,
    Quaternion? localBasisA,
    Quaternion? localBasisB,
    List<SceneJointAxisConfig>? axes,
    double? breakDistance,
  }) {
    final resolved =
        axes ??
        List.filled(
          SceneJointAxis.values.length,
          const SceneJointAxisConfig.free(),
        );
    assert(
      resolved.length == SceneJointAxis.values.length,
      'generic joints take one config per SceneJointAxis',
    );
    return SceneJoint._(
      type: SceneJointType.generic,
      bodyA: bodyA,
      bodyB: bodyB,
      colliderIndexA: colliderIndexA,
      colliderIndexB: colliderIndexB,
      collisionsEnabled: collisionsEnabled,
      localAnchorA: localAnchorA ?? Vector3.zero(),
      localAnchorB: localAnchorB ?? Vector3.zero(),
      localBasisA: localBasisA ?? Quaternion.identity(),
      localBasisB: localBasisB ?? Quaternion.identity(),
      axes: resolved,
      breakDistance: breakDistance,
    );
  }

  /// The joint kind — which `type` string [toWire] emits.
  final SceneJointType type;

  /// The joined bodies' node ids (`a`/`b` tokens on the wire).
  final LocalId bodyA;
  final LocalId bodyB;

  /// The collider index within each node's `components` array (`ca`/
  /// `cb` on the wire).
  final int colliderIndexA;
  final int colliderIndexB;

  /// Whether the joined bodies still collide with each other
  /// (`collide` on the wire).
  final bool collisionsEnabled;

  /// The joint anchor in each body's local frame (`anchorA`/`anchorB`).
  final Vector3 localAnchorA;
  final Vector3 localAnchorB;

  /// The hinge/slider axis in each body's local frame (`axisA`/`axisB`)
  /// — revolute and prismatic only.
  final Vector3? localAxisA;
  final Vector3? localAxisB;

  /// Range limits — revolute (radians) and prismatic (meters) only;
  /// `lower`/`upper` on the wire, omitted when null.
  final double? lowerLimit;
  final double? upperLimit;

  /// Velocity motor targets — `motorVelocity`/`motorMaxForce` on the
  /// wire, omitted when null.
  final double? motorTargetVelocity;
  final double? motorMaxForce;

  /// Constraint-frame orientations for generic joints (`basisA`/
  /// `basisB` quats on the wire).
  final Quaternion? localBasisA;
  final Quaternion? localBasisB;

  /// Per-axis configs for generic joints (`axes` on the wire), in
  /// [SceneJointAxis] order.
  final List<SceneJointAxisConfig>? axes;

  /// World-space anchor separation at which the native side removes
  /// the constraint and fires `broke` (dart3d extension; absent → the
  /// joint never breaks).
  final double? breakDistance;

  /// The op's field set — everything after `{"op":…,"id":…}` on the
  /// wire. `addJoint`/`updateJoint` share it; the controller merges in
  /// the op name and id.
  Map<String, Object?> toWire() => {
    'type': type.name,
    'a': bodyA.toToken(),
    'b': bodyB.toToken(),
    'ca': colliderIndexA,
    'cb': colliderIndexB,
    'collide': collisionsEnabled,
    'anchorA': [localAnchorA.x, localAnchorA.y, localAnchorA.z],
    'anchorB': [localAnchorB.x, localAnchorB.y, localAnchorB.z],
    if (localAxisA != null)
      'axisA': [localAxisA!.x, localAxisA!.y, localAxisA!.z],
    if (localAxisB != null)
      'axisB': [localAxisB!.x, localAxisB!.y, localAxisB!.z],
    if (lowerLimit != null) 'lower': lowerLimit,
    if (upperLimit != null) 'upper': upperLimit,
    if (motorTargetVelocity != null) 'motorVelocity': motorTargetVelocity,
    // Non-finite caps/thresholds are "no cap"/"never break" — the wire
    // omits them (JSON can't express infinity).
    if (motorMaxForce != null && motorMaxForce!.isFinite)
      'motorMaxForce': motorMaxForce,
    if (localBasisA != null)
      'basisA': [
        localBasisA!.x,
        localBasisA!.y,
        localBasisA!.z,
        localBasisA!.w,
      ],
    if (localBasisB != null)
      'basisB': [
        localBasisB!.x,
        localBasisB!.y,
        localBasisB!.z,
        localBasisB!.w,
      ],
    if (axes != null) 'axes': [for (final axis in axes!) axis.toWire()],
    if (breakDistance != null && breakDistance!.isFinite)
      'breakDistance': breakDistance,
  };
}

/// A `breakDistance` joint exceeded its anchor separation and was
/// removed natively — `{"kind":"broke","id":…,"a":{s,i},"b":{s,i}}`.
/// A dart3d extension; upstream has no joint events.
final class SceneJointBroke {
  /// Creates the event for joint [id]'s former body pair.
  const SceneJointBroke({
    required this.id,
    required this.nodeA,
    this.nodeB,
  });

  /// The joint id as minted by `SceneController.addJoint`, or a
  /// reserved-range handle for a document-declared joint component.
  final int id;

  /// The joint's first body node.
  final LocalId nodeA;

  /// The joint's second body node — null when the joint anchored to
  /// the world (a joint component with an absent `otherNode`; the
  /// wire emits `"b":null`).
  final LocalId? nodeB;
}

/// Decodes one `D3Event.joint` payload — `broke` only today (`kind`
/// leaves the frame open). Returns null on a malformed frame or an
/// unknown `kind`.
SceneJointBroke? decodeJointEvent(Map<String, Object?> json) {
  if (json['kind'] != 'broke') return null;
  final id = (json['id'] as num?)?.toInt();
  final a = _wireLocalId(json['a']);
  if (id == null || a == null) return null;
  // `b` decodes to null both when absent (world-anchored) and when
  // malformed — either way the event still names the joint and node A.
  return SceneJointBroke(id: id, nodeA: a, nodeB: _wireLocalId(json['b']));
}
