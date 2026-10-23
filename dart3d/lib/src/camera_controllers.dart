/// Upstream-parity camera controllers (`CameraController`,
/// `OrbitCameraController`, `FlyCameraController`, `FollowCameraController`)
/// for `.fscene` scenes (U1 / E2 / V6f).
///
/// Pure Dart (no `dartnative` import) so all controllers are directly
/// testable under `dn test`. See `camera_controls.dart` for the
/// [CameraControls] widget that routes touch/mouse gestures and frame ticks
/// to a [CameraController].
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'camera.dart';
import 'scene_controller.dart';
import 'scene_model.dart';
import 'world_bounds.dart' show computeWorldTransforms;

/// Logical key identifiers for [FlyCameraController.onKeyEvent].
///
/// Matches the WASD / arrow / space / shift controls in upstream
/// `FlyCameraController`.
enum CameraKey {
  keyW,
  keyA,
  keyS,
  keyD,
  keyE,
  keyQ,
  arrowUp,
  arrowDown,
  arrowLeft,
  arrowRight,
  space,
  shiftLeft,
  shiftRight,
  controlLeft,
  controlRight,
}

/// Abstract base class for interactive camera controllers.
///
/// Mirrors upstream `flutter_scene` `CameraController`. A controller updates
/// a [SceneCamera] each frame (`update(dt)`) and can synchronize that pose
/// into a [SceneController]'s camera node via [applyToScene] (or
/// automatically when wrapped in `CameraControls`).
abstract class CameraController {
  /// Creates a camera controller driving [camera] (or a default perspective
  /// camera) and optionally targeting [cameraNode] in a [SceneDocument].
  CameraController({
    SceneCamera? camera,
    this.cameraNode,
    double? fovRadiansY,
    double? near,
    double? far,
  }) : camera =
           camera ??
           SceneCamera.perspective(
             fovRadiansY: fovRadiansY ?? (60.0 * degrees2Radians),
             near: near ?? 0.1,
             far: far ?? 1000.0,
           ) {
    if (fovRadiansY != null) this.camera.fovRadiansY = fovRadiansY;
    if (near != null) this.camera.near = near;
    if (far != null) this.camera.far = far;
  }

  /// Returns a [NodeTransform] setting [nodeId] to [camera]'s current
  /// world-space position and look-at rotation.
  NodeTransform toNodeTransform(LocalId nodeId) => NodeTransform(
    nodeId,
    translation: camera.position.clone(),
    rotation: lookAtRotation(camera.position, camera.target, up: camera.up),
  );

  /// The camera state updated by this controller.
  final SceneCamera camera;

  /// Optional camera node id in the [SceneDocument] to update when
  /// [applyToScene] runs. When null, [applyToScene] resolves the primary
  /// camera node from `controller.document`.
  LocalId? cameraNode;

  /// Advances the controller by [dt] seconds and updates [camera].
  void update(double dt);

  /// Updates [dt] and writes the resulting camera pose to [controller].
  ///
  /// Returns `true` if a camera node was resolved and updated.
  bool stepAndApply(SceneController controller, double dt) {
    update(dt);
    return applyToScene(controller);
  }

  /// Writes [camera]'s current `position` and `lookAtRotation(position, target, up: up)`
  /// to [controller]'s camera node via [SceneController.setNodeTransforms].
  ///
  /// When the camera node has a parent in `controller.document`, converts the
  /// world-space camera pose into the parent node's local TRS. Returns false
  /// without writing when the parent is singular or the local pose requires
  /// shear, which [NodeTransform] cannot represent.
  bool applyToScene(SceneController controller) {
    final doc = controller.document;
    var nodeId = cameraNode ?? camera.nodeId;
    if (nodeId == null && doc != null) {
      nodeId = SceneCamera.fromDocument(doc)?.nodeId;
    }
    if (nodeId == null) return false;

    var translation = camera.position.clone();
    var rotation = lookAtRotation(
      camera.position,
      camera.target,
      up: camera.up,
    );
    Vector3? scale;

    if (doc != null) {
      final parentId = _findParentId(doc, nodeId);
      if (parentId != null) {
        final worlds = computeWorldTransforms(doc, includeHidden: true);
        final parentWorld = worlds[parentId];
        if (parentWorld == null) return false;
        final invParent = Matrix4.copy(parentWorld);
        if (invParent.invert() == 0.0) return false;

        final worldMat = Matrix4.compose(
          translation,
          rotation,
          Vector3.all(1.0),
        );
        final localMat = invParent * worldMat;
        final localTranslation = Vector3.zero();
        final localRotation = Quaternion.identity();
        final localScale = Vector3.zero();
        localMat.decompose(localTranslation, localRotation, localScale);
        final recomposed = Matrix4.compose(
          localTranslation,
          localRotation,
          localScale,
        );
        for (var i = 0; i < 16; i++) {
          final expected = localMat.storage[i];
          final actual = recomposed.storage[i];
          final tolerance =
              1e-5 * math.max(1.0, math.max(expected.abs(), actual.abs()));
          if ((actual - expected).abs() > tolerance) return false;
        }
        translation = localTranslation;
        rotation = localRotation;
        scale = localScale;
      }
    }

    controller.setNodeTransforms([
      NodeTransform(
        nodeId,
        translation: translation,
        rotation: rotation,
        scale: scale,
      ),
    ]);
    return true;
  }

  /// Called when a primary pointer drag (orbit / look) updates by
  /// `(dx, dy)` logical pixels.
  void onPrimaryDrag(double dx, double dy) {}

  /// Called when a secondary/two-finger pan updates by `(dx, dy)` logical
  /// pixels.
  void onSecondaryDrag(double dx, double dy) {}

  /// Called when a pinch-scale gesture starts.
  void onScaleStart() {}

  /// Called when a pinch-scale gesture updates with multiplicative [scale]
  /// (`1.0` at gesture start) and optional focal pan `(panDx, panDy)`.
  void onScaleUpdate(double scale, {double panDx = 0.0, double panDy = 0.0}) {}

  /// Called when a mouse wheel / trackpad scroll event occurs.
  void onScroll(double scrollDeltaY) {}

  /// Called when a keyboard key state changes.
  void onKeyEvent(CameraKey key, {required bool isDown}) {}
}

LocalId? _findParentId(SceneDocument doc, LocalId target) {
  for (final node in doc.nodes.values) {
    if (node.children.contains(target)) return node.id;
  }
  return null;
}

/// Spherical orbit camera controller around a [target] point, with optional
/// exponential damping, two-finger pan, and pinch/wheel zoom.
///
/// Mirrors upstream `flutter_scene` `OrbitCameraController`.
class OrbitCameraController extends CameraController {
  /// Creates an orbit camera controller.
  OrbitCameraController({
    super.camera,
    super.cameraNode,
    super.fovRadiansY,
    super.near,
    super.far,
    Vector3? target,
    double distance = 5.0,
    this.azimuth = 0.0,
    this.elevation = 0.3,
    this.minDistance = 0.1,
    this.maxDistance = 1000.0,
    double? minElevation,
    double? maxElevation,
    this.rotateSensitivity = 0.005,
    this.panSensitivity = 1.0,
    this.zoomSensitivity = 0.001,
    this.damping = 0.0,
    this.enableRotate = true,
    this.enablePan = true,
    this.enableZoom = true,
  }) : minElevation = minElevation ?? (-math.pi / 2 + 0.01),
       maxElevation = maxElevation ?? (math.pi / 2 - 0.01),
       _target = (target ?? Vector3.zero()).clone() {
    _distance = distance.clamp(minDistance, maxDistance);
    elevation = elevation.clamp(this.minElevation, this.maxElevation);
    _desiredTarget = _target.clone();
    _desiredDistance = _distance;
    _desiredAzimuth = azimuth;
    _desiredElevation = elevation;
    _syncCamera();
  }

  /// Creates an [OrbitCameraController] initialized from the current camera
  /// pose in [doc] (and optional [target]).
  factory OrbitCameraController.fromDocument(
    SceneDocument doc, {
    LocalId? cameraNode,
    Vector3? target,
    double minDistance = 0.1,
    double maxDistance = 1000.0,
    double damping = 0.0,
  }) {
    final cam =
        SceneCamera.fromDocument(doc, cameraNode: cameraNode) ??
        SceneCamera.perspective();
    final tgt = (target ?? cam.target).clone();
    final offset = cam.position - tgt;
    final dist = math.max(offset.length, minDistance);
    final az = dist > 1e-6 ? math.atan2(offset.x, -offset.z) : 0.0;
    final el = dist > 1e-6
        ? math.asin((offset.y / dist).clamp(-1.0, 1.0))
        : 0.3;
    return OrbitCameraController(
      camera: cam,
      cameraNode: cam.nodeId ?? cameraNode,
      target: tgt,
      distance: dist,
      azimuth: az,
      elevation: el,
      minDistance: minDistance,
      maxDistance: maxDistance,
      damping: damping,
    );
  }

  Vector3 _target;
  late Vector3 _desiredTarget;

  /// Current orbit distance from [target].
  double _distance = 5.0;
  late double _desiredDistance;
  double get distance => _distance;
  set distance(double value) {
    _distance = value.clamp(minDistance, maxDistance);
    _desiredDistance = _distance;
    _syncCamera();
  }

  /// Current horizontal orbit angle in radians (`0` places camera at `-Z`
  /// looking toward `+Z`).
  double azimuth;
  late double _desiredAzimuth;

  /// Current vertical elevation angle in radians (`0` level, `+pi/2` straight
  /// down from `+Y`).
  double elevation;
  late double _desiredElevation;

  /// Minimum allowed orbit distance.
  double minDistance;

  /// Maximum allowed orbit distance.
  double maxDistance;

  /// Minimum allowed elevation angle in radians.
  double minElevation;

  /// Maximum allowed elevation angle in radians.
  double maxElevation;

  /// Radians per logical pixel for primary orbit drag.
  double rotateSensitivity;

  /// Multiplier on screen-space pan delta.
  double panSensitivity;

  /// Multiplier on scroll wheel delta.
  double zoomSensitivity;

  /// Exponential damping factor in `[0, 1)`. `0` disables damping (instant).
  double damping;

  /// Whether primary drag orbits the camera.
  bool enableRotate;

  /// Whether secondary / two-finger drag pans [target].
  bool enablePan;

  /// Whether pinch / scroll zooms [distance].
  bool enableZoom;

  double _scaleStartDistance = 5.0;

  /// The world-space target point the camera orbits around.
  Vector3 get target => _target;
  set target(Vector3 value) {
    _target = value.clone();
    _desiredTarget = value.clone();
    _syncCamera();
  }

  /// Orbits by `(deltaAzimuth, deltaElevation)` in radians.
  void orbitBy(double deltaAzimuth, double deltaElevation) {
    _desiredAzimuth += deltaAzimuth;
    _desiredElevation = (_desiredElevation + deltaElevation).clamp(
      minElevation,
      maxElevation,
    );
    if (damping <= 0.0) {
      azimuth = _desiredAzimuth;
      elevation = _desiredElevation;
      _syncCamera();
    }
  }

  /// Pans [target] in the camera's local right/up plane by world-space
  /// `(deltaRight, deltaUp)`.
  void panBy(double deltaRight, double deltaUp) {
    final (right, trueUp, _) = camera.basis;
    final offset = right * deltaRight + trueUp * deltaUp;
    _desiredTarget.add(offset);
    if (damping <= 0.0) {
      _target.setFrom(_desiredTarget);
      _syncCamera();
    }
  }

  /// Scales the desired orbit distance by [factor] (clamped to
  /// `[minDistance, maxDistance]`).
  void zoomByFactor(double factor) {
    if (factor <= 0 || !factor.isFinite) return;
    _desiredDistance = (_desiredDistance * factor).clamp(
      minDistance,
      maxDistance,
    );
    if (damping <= 0.0) {
      _distance = _desiredDistance;
      _syncCamera();
    }
  }

  @override
  void onPrimaryDrag(double dx, double dy) {
    if (!enableRotate) return;
    orbitBy(-dx * rotateSensitivity, dy * rotateSensitivity);
  }

  @override
  void onSecondaryDrag(double dx, double dy) {
    if (!enablePan) return;
    // Scale pan speed with distance so panning feels 1:1 at the target depth.
    final scale = distance * 0.002 * panSensitivity;
    panBy(-dx * scale, dy * scale);
  }

  @override
  void onScaleStart() {
    _scaleStartDistance = _desiredDistance;
  }

  @override
  void onScaleUpdate(double scale, {double panDx = 0.0, double panDy = 0.0}) {
    if (enableZoom && scale > 0.0 && scale.isFinite) {
      _desiredDistance = (_scaleStartDistance / scale).clamp(
        minDistance,
        maxDistance,
      );
      if (damping <= 0.0) {
        _distance = _desiredDistance;
      }
    }
    if (enablePan && (panDx != 0.0 || panDy != 0.0)) {
      final panScale = distance * 0.002 * panSensitivity;
      final (right, trueUp, _) = camera.basis;
      _desiredTarget.add(
        right * (-panDx * panScale) + trueUp * (panDy * panScale),
      );
      if (damping <= 0.0) {
        _target.setFrom(_desiredTarget);
      }
    }
    if (damping <= 0.0) {
      _syncCamera();
    }
  }

  @override
  void onScroll(double scrollDeltaY) {
    if (!enableZoom) return;
    final factor = math.exp(scrollDeltaY * zoomSensitivity);
    zoomByFactor(factor);
  }

  @override
  void update(double dt) {
    if (dt <= 0) {
      _syncCamera();
      return;
    }
    if (damping <= 0.0) {
      azimuth = _desiredAzimuth;
      elevation = _desiredElevation;
      _distance = _desiredDistance;
      _target.setFrom(_desiredTarget);
      _syncCamera();
      return;
    }

    // Frame-rate independent exponential smoothing matching upstream.
    final clampedDamping = damping.clamp(0.0, 0.999);
    final alpha = 1.0 - math.pow(clampedDamping, dt * 60.0).toDouble();
    azimuth += (_desiredAzimuth - azimuth) * alpha;
    elevation += (_desiredElevation - elevation) * alpha;
    _distance += (_desiredDistance - _distance) * alpha;
    Vector3.mix(_target, _desiredTarget, alpha, _target);
    _syncCamera();
  }

  void _syncCamera() {
    final cosEl = math.cos(elevation);
    final sinEl = math.sin(elevation);
    final sinAz = math.sin(azimuth);
    final cosAz = math.cos(azimuth);
    // At azimuth = 0, elevation = 0: offset is (0, 0, -distance), so camera
    // sits at -Z looking toward target at +Z.
    final offset = Vector3(
      distance * cosEl * sinAz,
      distance * sinEl,
      -distance * cosEl * cosAz,
    );
    camera.position = _target + offset;
    camera.target = _target.clone();
  }
}

/// First-person free-fly camera controller with yaw/pitch look, keyboard
/// WASD/EQ movement, and programmatic/virtual-stick [setMoveInput] (`V6f`).
///
/// Mirrors upstream `flutter_scene` 0.24 `FlyCameraController`.
class FlyCameraController extends CameraController {
  /// Creates a free-fly camera controller.
  FlyCameraController({
    super.camera,
    super.cameraNode,
    super.fovRadiansY,
    super.near,
    super.far,
    Vector3? position,
    this.yaw = 0.0,
    this.pitch = 0.0,
    double? maxPitch,
    this.moveSpeed = 5.0,
    this.boostMultiplier = 3.0,
    this.lookSensitivity = 0.003,
  }) : maxPitch = maxPitch ?? (math.pi / 2 - 0.01) {
    if (position != null) {
      camera.position = position.clone();
    }
    pitch = pitch.clamp(-this.maxPitch, this.maxPitch);
    _syncCameraTarget();
  }

  /// Creates a [FlyCameraController] initialized from [doc]'s camera pose.
  factory FlyCameraController.fromDocument(
    SceneDocument doc, {
    LocalId? cameraNode,
    double moveSpeed = 5.0,
    double boostMultiplier = 3.0,
    double lookSensitivity = 0.003,
  }) {
    final cam =
        SceneCamera.fromDocument(doc, cameraNode: cameraNode) ??
        SceneCamera.perspective();
    final dir = (cam.target - cam.position);
    if (dir.length2 > 1e-12) {
      dir.normalize();
    } else {
      dir.setValues(0, 0, 1);
    }
    final yaw = math.atan2(dir.x, dir.z);
    final pitch = math.asin(dir.y.clamp(-1.0, 1.0));
    return FlyCameraController(
      camera: cam,
      cameraNode: cam.nodeId ?? cameraNode,
      position: cam.position,
      yaw: yaw,
      pitch: pitch,
      moveSpeed: moveSpeed,
      boostMultiplier: boostMultiplier,
      lookSensitivity: lookSensitivity,
    );
  }

  /// Horizontal look angle in radians (`0` looks along `+Z`, `+pi/2` along `+X`).
  double yaw;

  /// Vertical look angle in radians (`0` level, `+` looks up toward `+Y`).
  double pitch;

  /// Maximum absolute pitch angle in radians.
  double maxPitch;

  /// Base movement speed in world units per second.
  double moveSpeed;

  /// Speed multiplier when boost (Shift) is active.
  double boostMultiplier;

  /// Radians per logical pixel for primary look drag.
  double lookSensitivity;

  final Set<CameraKey> _pressedKeys = <CameraKey>{};

  // Programmatic / virtual-joystick input (upstream 0.24 V6f).
  final Vector2 _externalMove = Vector2.zero();
  double _externalElevate = 0.0;
  bool _externalBoost = false;

  /// Sets programmatic movement input for virtual joysticks or automated
  /// camera paths (`V6f` — upstream `flutter_scene` 0.24 parity).
  ///
  /// - `move.x`: strafe right (`+1`) / left (`-1`)
  /// - `move.y`: move forward (`+1`) / backward (`-1`)
  /// - `elevate`: move up (`+1`) / down (`-1`) along world `+Y`
  /// - `boost`: multiplies speed by [boostMultiplier]
  void setMoveInput(Vector2 move, {double elevate = 0.0, bool boost = false}) {
    _externalMove.setFrom(move);
    _externalElevate = elevate;
    _externalBoost = boost;
  }

  /// Rotates look angles by `(deltaYaw, deltaPitch)` in radians.
  void lookBy(double deltaYaw, double deltaPitch) {
    yaw += deltaYaw;
    pitch = (pitch + deltaPitch).clamp(-maxPitch, maxPitch);
    _syncCameraTarget();
  }

  /// Forward unit vector in `.fscene` world space (`+Z` at `yaw=0, pitch=0`).
  Vector3 get forwardDirection => Vector3(
    math.cos(pitch) * math.sin(yaw),
    math.sin(pitch),
    math.cos(pitch) * math.cos(yaw),
  )..normalize();

  @override
  void onPrimaryDrag(double dx, double dy) {
    // Dragging right turns camera right (+yaw); dragging down looks down (-pitch).
    lookBy(dx * lookSensitivity, -dy * lookSensitivity);
  }

  @override
  void onScroll(double scrollDeltaY) {
    // Scroll adjusts base moveSpeed, matching upstream FlyCameraController.
    final factor = math.exp(-scrollDeltaY * 0.001);
    moveSpeed = (moveSpeed * factor).clamp(0.1, 500.0);
  }

  @override
  void onKeyEvent(CameraKey key, {required bool isDown}) {
    if (isDown) {
      _pressedKeys.add(key);
    } else {
      _pressedKeys.remove(key);
    }
  }

  @override
  void update(double dt) {
    if (dt <= 0) {
      _syncCameraTarget();
      return;
    }

    var forwardInput = _externalMove.y;
    var rightInput = _externalMove.x;
    var upInput = _externalElevate;

    if (_pressedKeys.contains(CameraKey.keyW) ||
        _pressedKeys.contains(CameraKey.arrowUp)) {
      forwardInput += 1.0;
    }
    if (_pressedKeys.contains(CameraKey.keyS) ||
        _pressedKeys.contains(CameraKey.arrowDown)) {
      forwardInput -= 1.0;
    }
    if (_pressedKeys.contains(CameraKey.keyD) ||
        _pressedKeys.contains(CameraKey.arrowRight)) {
      rightInput += 1.0;
    }
    if (_pressedKeys.contains(CameraKey.keyA) ||
        _pressedKeys.contains(CameraKey.arrowLeft)) {
      rightInput -= 1.0;
    }
    if (_pressedKeys.contains(CameraKey.keyE) ||
        _pressedKeys.contains(CameraKey.space)) {
      upInput += 1.0;
    }
    if (_pressedKeys.contains(CameraKey.keyQ) ||
        _pressedKeys.contains(CameraKey.controlLeft) ||
        _pressedKeys.contains(CameraKey.controlRight)) {
      upInput -= 1.0;
    }

    final boosted =
        _externalBoost ||
        _pressedKeys.contains(CameraKey.shiftLeft) ||
        _pressedKeys.contains(CameraKey.shiftRight);
    final speed = moveSpeed * (boosted ? boostMultiplier : 1.0);

    final (right, _, forward) = camera.basis;
    final worldUp = camera.up.normalized();

    final moveVec =
        forward * forwardInput + right * rightInput + worldUp * upInput;
    if (moveVec.length2 > 1e-12) {
      if (moveVec.length2 > 1.0) {
        moveVec.normalize();
      }
      camera.position = camera.position + moveVec * (speed * dt);
    }
    _syncCameraTarget();
  }

  void _syncCameraTarget() {
    camera.target = camera.position + forwardDirection;
  }
}

/// Third-person follow camera controller that tracks a target node (or
/// world-space target callback) with configurable local/world offset,
/// look-at offset, and exponential smoothing.
///
/// Mirrors upstream `flutter_scene` `FollowCameraController`.
class FollowCameraController extends CameraController {
  /// Creates a follow camera controller.
  ///
  /// Supply either [targetNode] + [sceneController] (or [document]) to read
  /// the followed node's world transform automatically, or [targetPose] to
  /// supply `(position, rotation)` directly.
  FollowCameraController({
    super.camera,
    super.cameraNode,
    super.fovRadiansY,
    super.near,
    super.far,
    this.targetNode,
    this.sceneController,
    this.document,
    this.targetPose,
    Vector3? offset,
    Vector3? lookAtOffset,
    this.rotateOffsetWithTarget = true,
    this.positionSmoothing = 0.85,
    this.targetSmoothing = 0.85,
  }) : offset = (offset ?? Vector3(0, 2, -5)).clone(),
       lookAtOffset = (lookAtOffset ?? Vector3(0, 0.5, 0)).clone() {
    snapToTarget();
  }

  /// Target node id in [sceneController]'s (or [document]'s) scene graph.
  LocalId? targetNode;

  /// Optional controller whose live `document` supplies [targetNode]'s pose.
  SceneController? sceneController;

  /// Optional standalone document supplying [targetNode]'s pose when
  /// [sceneController] is not provided.
  SceneDocument? document;

  /// Optional callback returning `(worldPosition, worldRotation)` of the
  /// followed subject. [worldRotation] uses [Matrix4.compose]'s local-to-world
  /// convention. Takes precedence over [targetNode] when non-null.
  (Vector3 position, Quaternion rotation)? Function()? targetPose;

  /// Camera offset from the target's position (in target-local space when
  /// [rotateOffsetWithTarget] is true, or world space when false).
  Vector3 offset;

  /// Offset added to the target's position for the camera's look-at point.
  Vector3 lookAtOffset;

  /// Whether [offset] and [lookAtOffset] rotate with the target's heading/pose.
  bool rotateOffsetWithTarget;

  /// Exponential smoothing factor in `[0, 1)` for camera position (`0` = instant).
  double positionSmoothing;

  /// Exponential smoothing factor in `[0, 1)` for look-at target (`0` = instant).
  double targetSmoothing;

  bool _initialized = false;

  (Vector3 position, Quaternion rotation)? _resolveTargetPose() {
    if (targetPose != null) return targetPose!();
    final id = targetNode;
    final doc = sceneController?.document ?? document;
    if (id == null || doc == null) return null;
    final worlds = computeWorldTransforms(doc, includeHidden: true);
    final world = worlds[id];
    if (world == null) return null;
    final pos = world.getTranslation();
    final rotMat = world.getRotation();
    final c0 = rotMat.getColumn(0);
    final c1 = rotMat.getColumn(1);
    final c2 = rotMat.getColumn(2);
    if (c0.length2 > 1e-12) c0.normalize();
    if (c1.length2 > 1e-12) c1.normalize();
    if (c2.length2 > 1e-12) c2.normalize();
    if (rotMat.determinant() < 0) c0.negate();
    final rot = Quaternion.fromRotation(Matrix3.columns(c0, c1, c2))
      ..normalize();
    return (pos, rot);
  }

  (Vector3 desiredPos, Vector3 desiredLookAt)? _computeDesired() {
    final pose = _resolveTargetPose();
    if (pose == null) return null;
    final (targetPos, targetRot) = pose;
    final targetRotation = targetRot.asRotationMatrix();
    final worldOffset = rotateOffsetWithTarget
        ? targetRotation.transform(offset.clone())
        : offset;
    final worldLookOffset = rotateOffsetWithTarget
        ? targetRotation.transform(lookAtOffset.clone())
        : lookAtOffset;
    return (targetPos + worldOffset, targetPos + worldLookOffset);
  }

  /// Orbits [offset] around the target by `(deltaAzimuth, deltaElevation)` in
  /// radians.
  void orbitBy(double deltaAzimuth, double deltaElevation) {
    final len = offset.length;
    if (len <= 1e-6) return;
    final az = math.atan2(offset.x, -offset.z) + deltaAzimuth;
    final el = (math.asin((offset.y / len).clamp(-1.0, 1.0)) + deltaElevation)
        .clamp(-math.pi / 2 + 0.05, math.pi / 2 - 0.05);
    final cosEl = math.cos(el);
    offset = Vector3(
      len * cosEl * math.sin(az),
      len * math.sin(el),
      -len * cosEl * math.cos(az),
    );
  }

  @override
  void onPrimaryDrag(double dx, double dy) {
    orbitBy(-dx * 0.005, dy * 0.005);
  }

  /// Immediately snaps [camera] to the desired follow pose without smoothing.
  void snapToTarget() {
    final desired = _computeDesired();
    if (desired == null) return;
    camera.position = desired.$1;
    camera.target = desired.$2;
    _initialized = true;
  }

  @override
  void update(double dt) {
    final desired = _computeDesired();
    if (desired == null) return;
    final (desiredPos, desiredLookAt) = desired;

    if (!_initialized || dt <= 0) {
      camera.position = desiredPos;
      camera.target = desiredLookAt;
      _initialized = true;
      return;
    }

    if (positionSmoothing <= 0.0) {
      camera.position = desiredPos;
    } else {
      final pClamp = positionSmoothing.clamp(0.0, 0.999);
      final pAlpha = 1.0 - math.pow(pClamp, dt * 60.0).toDouble();
      Vector3.mix(camera.position, desiredPos, pAlpha, camera.position);
    }

    if (targetSmoothing <= 0.0) {
      camera.target = desiredLookAt;
    } else {
      final tClamp = targetSmoothing.clamp(0.0, 0.999);
      final tAlpha = 1.0 - math.pow(tClamp, dt * 60.0).toDouble();
      Vector3.mix(camera.target, desiredLookAt, tAlpha, camera.target);
    }
  }
}
