/// Camera math, projection, and ray helpers in `.fscene` coordinates (U1 / E2).
///
/// `.fscene` uses a left-handed coordinate system (`+X` right, `+Y` up,
/// `+Z` forward). A camera node looks along its local `+Z` axis (which the
/// native realizers z-mirror to `(0, 0, -1)` in SceneKit and Filament).
///
/// Pure Dart (no `dartnative` import) so it runs under `dn test`.
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'scene_model.dart';
import 'world_bounds.dart' show computeWorldTransforms;

/// Computes the right-handed/det-+1 rotation quaternion that aims a node's
/// local `+Z` axis from [eye] toward [target] with reference [up] (default
/// `+Y`), matching upstream `Node._lookAtMatrix` in `.fscene` space. The
/// quaternion uses the local-to-world convention of [Matrix4.compose].
Quaternion lookAtRotation(Vector3 eye, Vector3 target, {Vector3? up}) {
  final refUp = up ?? Vector3(0, 1, 0);
  var forward = target - eye;
  final fLen = forward.length;
  if (fLen <= 1e-8) {
    forward = Vector3(0, 0, 1);
  } else {
    forward /= fLen;
  }
  var right = refUp.cross(forward);
  var rLen = right.length;
  if (rLen <= 1e-6) {
    // Forward is collinear with refUp; pick an orthogonal fallback axis.
    final fallback = forward.x.abs() < 0.9
        ? Vector3(1, 0, 0)
        : Vector3(0, 0, 1);
    right = fallback.cross(forward);
    rLen = right.length;
  }
  right /= rLen;
  final trueUp = forward.cross(right)..normalize();
  // Keep this in Matrix4.compose's local-to-world convention. Quaternion's
  // rotated() method applies the inverse convention.
  return (Quaternion.fromRotation(Matrix3.columns(right, trueUp, forward)))
    ..normalize();
}

/// Computes a [TrsTransform] placed at [eye] and rotated via [lookAtRotation]
/// so its local `+Z` points at [target].
TrsTransform lookAtTransform(
  Vector3 eye,
  Vector3 target, {
  Vector3? up,
  Vector3? scale,
}) => TrsTransform(
  translation: eye.clone(),
  rotation: lookAtRotation(eye, target, up: up),
  scale: (scale ?? Vector3.all(1)).clone(),
);

/// Camera projection and pose in `.fscene` world space, with upstream-parity
/// [screenPointToRay] and [worldToScreen] helpers.
///
/// Mirrors upstream `flutter_scene` `Camera` (`PerspectiveCamera` /
/// `OrthographicCamera`) for dart3d's `.fscene` document model.
final class SceneCamera {
  /// Creates a perspective camera.
  SceneCamera.perspective({
    Vector3? position,
    Vector3? target,
    Vector3? up,
    this.fovRadiansY = 60.0 * degrees2Radians,
    this.near = 0.1,
    this.far = 1000.0,
    this.nodeId,
  }) : isOrthographic = false,
       orthoScale = 1.0,
       position = (position ?? Vector3(0, 0, -5)).clone(),
       target = (target ?? Vector3.zero()).clone(),
       up = (up ?? Vector3(0, 1, 0)).clone();

  /// Creates an orthographic camera where [orthoScale] is half the visible
  /// world height (`top = +orthoScale`, `bottom = -orthoScale`).
  SceneCamera.orthographic({
    Vector3? position,
    Vector3? target,
    Vector3? up,
    this.orthoScale = 1.0,
    this.near = 0.1,
    this.far = 1000.0,
    this.nodeId,
  }) : isOrthographic = true,
       fovRadiansY = 60.0 * degrees2Radians,
       position = (position ?? Vector3(0, 0, -5)).clone(),
       target = (target ?? Vector3.zero()).clone(),
       up = (up ?? Vector3(0, 1, 0)).clone();

  /// Optional node id in the [SceneDocument] this camera represents.
  final LocalId? nodeId;

  /// World-space camera position (`eye`).
  Vector3 position;

  /// World-space target point the camera looks at.
  Vector3 target;

  /// World-space reference up vector.
  Vector3 up;

  /// Vertical field of view in radians (perspective mode).
  double fovRadiansY;

  /// Half the visible world height (orthographic mode).
  double orthoScale;

  /// Whether this camera uses orthographic projection.
  bool isOrthographic;

  /// Near clip plane distance.
  double near;

  /// Far clip plane distance.
  double far;

  /// Extracts a [SceneCamera] from [doc].
  ///
  /// When [cameraNode] is null, searches:
  /// 1. the primary view (`doc.views.firstWhere((v) => v.target == null)`)
  ///    camera node,
  /// 2. any node carrying a `'camera'` component with `primary != false`,
  /// 3. any node carrying a `'camera'` component.
  ///
  /// Returns null when [doc] has no matching camera node.
  static SceneCamera? fromDocument(SceneDocument doc, {LocalId? cameraNode}) {
    LocalId? id = cameraNode;
    if (id == null) {
      for (final view in doc.views) {
        if (view.target == null && doc.nodes.containsKey(view.cameraNode)) {
          id = view.cameraNode;
          break;
        }
      }
    }
    if (id == null) {
      LocalId? fallback;
      for (final node in doc.nodes.values) {
        for (final comp in node.components) {
          if (comp.type != 'camera') continue;
          fallback ??= node.id;
          final primary = comp.properties['primary'];
          if (primary is! BoolValue || primary.value) {
            id = node.id;
            break;
          }
        }
        if (id != null) break;
      }
      id ??= fallback;
    }
    if (id == null) return null;
    final node = doc.nodes[id];
    if (node == null) return null;

    final worlds = computeWorldTransforms(doc, includeHidden: true);
    final world = worlds[id] ?? node.transform.toMatrix4();
    final eye = world.getTranslation();
    // Column 2 of the world matrix is the node's local +Z (forward) axis,
    // and column 1 is local +Y (up).
    var forward = Vector3(
      world.entry(0, 2),
      world.entry(1, 2),
      world.entry(2, 2),
    );
    if (forward.length2 <= 1e-12) {
      forward = Vector3(0, 0, 1);
    } else {
      forward.normalize();
    }
    var worldUp = Vector3(
      world.entry(0, 1),
      world.entry(1, 1),
      world.entry(2, 1),
    );
    if (worldUp.length2 <= 1e-12) {
      worldUp = Vector3(0, 1, 0);
    } else {
      worldUp.normalize();
    }

    var isOrtho = false;
    var fovY = 60.0 * degrees2Radians;
    var orthoHalfH = 1.0;
    var zNear = 0.1;
    var zFar = 1000.0;

    for (final comp in node.components) {
      if (comp.type != 'camera') continue;
      final props = comp.properties;
      if (props['projection'] case StringValue(:final value)) {
        isOrtho = value == 'orthographic';
      }
      final fovProp = props['fovRadiansY'];
      if (fovProp case DoubleValue(:final value)) {
        fovY = value;
      } else if (fovProp case IntValue(:final value)) {
        fovY = value.toDouble();
      }
      final orthoProp = props['orthoScale'] ?? props['orthographicScale'];
      if (orthoProp case DoubleValue(:final value)) {
        orthoHalfH = value;
      } else if (orthoProp case IntValue(:final value)) {
        orthoHalfH = value.toDouble();
      }
      if (props['near'] case DoubleValue(:final value)) {
        zNear = value;
      } else if (props['near'] case IntValue(:final value)) {
        zNear = value.toDouble();
      }
      if (props['far'] case DoubleValue(:final value)) {
        zFar = value;
      } else if (props['far'] case IntValue(:final value)) {
        zFar = value.toDouble();
      }
      break;
    }

    if (isOrtho) {
      return SceneCamera.orthographic(
        nodeId: id,
        position: eye,
        target: eye + forward,
        up: worldUp,
        orthoScale: orthoHalfH,
        near: zNear,
        far: zFar,
      );
    }
    return SceneCamera.perspective(
      nodeId: id,
      position: eye,
      target: eye + forward,
      up: worldUp,
      fovRadiansY: fovY,
      near: zNear,
      far: zFar,
    );
  }

  /// Orthonormal camera basis `(right, trueUp, forward)` in `.fscene` world
  /// space (`+X` right, `+Y` up, `+Z` forward).
  (Vector3 right, Vector3 trueUp, Vector3 forward) get basis {
    var forward = target - position;
    final fLen = forward.length;
    if (fLen <= 1e-8) {
      forward = Vector3(0, 0, 1);
    } else {
      forward /= fLen;
    }
    var right = up.cross(forward);
    var rLen = right.length;
    if (rLen <= 1e-6) {
      final fallback = forward.x.abs() < 0.9
          ? Vector3(1, 0, 0)
          : Vector3(0, 0, 1);
      right = fallback.cross(forward);
      rLen = right.length;
    }
    right /= rLen;
    final trueUp = forward.cross(right)..normalize();
    return (right, trueUp, forward);
  }

  /// Unprojects a 2D viewport position (`dx`, `dy` in logical pixels, top-left
  /// origin) within a viewport of `(viewWidth, viewHeight)` into a world-space
  /// [Ray].
  ///
  /// Matches upstream `Camera.screenPointToRay`. Returns a forward ray from
  /// [position] if the viewport dimensions are non-positive.
  Ray screenPointToRay(
    double screenX,
    double screenY,
    double viewWidth,
    double viewHeight,
  ) {
    final (right, trueUp, forward) = basis;
    if (viewWidth <= 0 || viewHeight <= 0) {
      return Ray.originDirection(position, forward);
    }
    final ndcX = (screenX / viewWidth) * 2.0 - 1.0;
    final ndcY = 1.0 - (screenY / viewHeight) * 2.0;
    final aspect = viewWidth / viewHeight;

    if (isOrthographic) {
      final halfW = orthoScale * aspect;
      final origin =
          position + right * (ndcX * halfW) + trueUp * (ndcY * orthoScale);
      return Ray.originDirection(origin, forward);
    }

    final tanHalfFovY = math.tan(fovRadiansY * 0.5);
    final tanHalfFovX = tanHalfFovY * aspect;
    final dir =
        (right * (ndcX * tanHalfFovX) + trueUp * (ndcY * tanHalfFovY) + forward)
            .normalized();
    return Ray.originDirection(position, dir);
  }

  /// Projects [worldPoint] to 2D viewport coordinates `(x, y)` (top-left
  /// origin) within `(viewWidth, viewHeight)`.
  ///
  /// Returns `null` if [worldPoint] is behind the camera (`zCam <= 0` for
  /// perspective) or if the viewport dimensions are non-positive.
  /// Matches upstream `Camera.worldToScreen`.
  (double x, double y)? worldToScreen(
    Vector3 worldPoint,
    double viewWidth,
    double viewHeight,
  ) {
    if (viewWidth <= 0 || viewHeight <= 0) return null;
    final (right, trueUp, forward) = basis;
    final rel = worldPoint - position;
    final zCam = forward.dot(rel);
    final aspect = viewWidth / viewHeight;

    double ndcX;
    double ndcY;
    if (isOrthographic) {
      if (orthoScale <= 0) return null;
      final halfW = orthoScale * aspect;
      ndcX = right.dot(rel) / halfW;
      ndcY = trueUp.dot(rel) / orthoScale;
    } else {
      if (zCam <= 1e-6) return null;
      final tanHalfFovY = math.tan(fovRadiansY * 0.5);
      final tanHalfFovX = tanHalfFovY * aspect;
      if (tanHalfFovX <= 0 || tanHalfFovY <= 0) return null;
      ndcX = right.dot(rel) / (zCam * tanHalfFovX);
      ndcY = trueUp.dot(rel) / (zCam * tanHalfFovY);
    }

    final sx = (ndcX + 1.0) * 0.5 * viewWidth;
    final sy = (1.0 - ndcY) * 0.5 * viewHeight;
    if (!sx.isFinite || !sy.isFinite) return null;
    return (sx, sy);
  }
}
