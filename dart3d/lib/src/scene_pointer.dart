/// Stateful pointer raycaster and picking helper for `.fscene` scenes
/// (U1 / E2 / D8).
///
/// Mirrors upstream `flutter_scene` `ScenePointer`: tracks hover, press,
/// release, cancel, and scroll across renderable nodes in a [SceneDocument]
/// (or live [SceneController]).
///
/// Pure Dart (no `dartnative` import) so it runs under `dn test`.
library;

import 'package:vector_math/vector_math.dart';

import 'camera.dart';
import 'physics.dart' show SceneRaycastHit;
import 'raycast.dart';
import 'scene_controller.dart';
import 'scene_model.dart';

/// Callback fired when a pointer event occurs on a picked node.
typedef ScenePointerNodeCallback =
    void Function(LocalId node, SceneRaycastHit hit);

/// Callback fired when a pointer scroll event occurs on a picked node.
typedef ScenePointerScrollCallback =
    void Function(
      LocalId node,
      SceneRaycastHit hit,
      double scrollDx,
      double scrollDy,
    );

/// Stateful pointer raycaster and interaction dispatcher for a `.fscene`
/// scene.
///
/// Mirrors upstream `flutter_scene` `ScenePointer`:
/// - [pointAt] unprojects a 2D viewport position through [camera] (or
///   [sceneController]'s active camera) and raycasts the scene's renderable
///   meshes.
/// - [pointAlong] raycasts along an explicit world-space [Ray].
/// - [press], [release], [cancel], and [scroll] update pressed/hovered state
///   and invoke optional per-event callbacks ([onHoverEnter], [onHoverExit],
///   [onPress], [onRelease], [onTap], [onScroll]).
class ScenePointer {
  /// Creates a [ScenePointer] bound to [sceneController] or [document].
  ScenePointer({
    this.sceneController,
    this.document,
    this.camera,
    this.cameraNode,
    this.maxDistance = double.infinity,
    this.layerMask = -1,
    this.where,
    this.onHoverEnter,
    this.onHoverExit,
    this.onPress,
    this.onRelease,
    this.onTap,
    this.onScroll,
  });

  /// Optional controller whose live `document` is raycast.
  SceneController? sceneController;

  /// Optional standalone document when [sceneController] is not supplied.
  SceneDocument? document;

  /// Optional explicit [SceneCamera]. When null, resolved from the document
  /// via [SceneCamera.fromDocument] using [cameraNode].
  SceneCamera? camera;

  /// Optional camera node id when resolving the camera from the document.
  LocalId? cameraNode;

  /// Maximum raycast distance in world units.
  double maxDistance;

  /// Bitmask matched against `node.layers`.
  int layerMask;

  /// Optional node filter predicate.
  SceneNodePredicate? where;

  /// Fired when hover enters a node (or a different instance of an instanced
  /// node).
  ScenePointerNodeCallback? onHoverEnter;

  /// Fired when hover leaves the previously hovered node.
   void Function(LocalId node)? onHoverExit;

  /// Fired when [press] lands on a hit node.
  ScenePointerNodeCallback? onPress;

  /// Fired when [release] occurs while a node was pressed.
  void Function(LocalId pressedNode, SceneRaycastHit? releaseHit)? onRelease;

  /// Fired when [release] lands on the same node (and instance, if instanced)
  /// that was originally pressed.
  ScenePointerNodeCallback? onTap;

  /// Fired when [scroll] occurs over a hit node.
  ScenePointerScrollCallback? onScroll;

  SceneRaycastHit? _hit;
  LocalId? _hoveredNode;
  int? _hoveredInstance;
  LocalId? _pressedNode;
  int? _pressedInstance;
  bool _hoverChanged = false;

  /// The most recent raycast hit, or `null` if the pointer is over empty space.
  SceneRaycastHit? get hit => _hit;

  /// The currently hovered node id, or `null`.
  LocalId? get hoveredNode => _hoveredNode;

  /// The currently hovered instance index (for `d3:instances` nodes), or `null`.
  int? get hoveredInstance => _hoveredInstance;

  /// The node id where the current press began, or `null` when not pressed.
  LocalId? get pressedNode => _pressedNode;

  /// Whether the last [pointAt] / [pointAlong] call changed the hovered node
  /// (or hovered instance).
  bool get hoverChanged => _hoverChanged;

  SceneDocument? get _resolvedDoc => sceneController?.document ?? document;

  SceneCamera? _resolveCamera() {
    if (camera != null) return camera;
    final doc = _resolvedDoc;
    if (doc == null) return null;
    return SceneCamera.fromDocument(doc, cameraNode: cameraNode);
  }

  /// Unprojects `(screenX, screenY)` in a viewport of `(viewWidth, viewHeight)`
  /// and raycasts the scene, updating [hit], [hoveredNode], and [hoverChanged].
  SceneRaycastHit? pointAt(
    double screenX,
    double screenY,
    double viewWidth,
    double viewHeight, {
    SceneCamera? overrideCamera,
  }) {
    final cam = overrideCamera ?? _resolveCamera();
    if (cam == null) {
      _updateHover(null);
      return null;
    }
    final ray = cam.screenPointToRay(screenX, screenY, viewWidth, viewHeight);
    return _pointAlong(ray, cam);
  }

  /// Raycasts along world-space [ray], updating [hit], [hoveredNode], and
  /// [hoverChanged].
  SceneRaycastHit? pointAlong(Ray ray) {
    return _pointAlong(ray, _resolveCamera());
  }

  SceneRaycastHit? _pointAlong(Ray ray, SceneCamera? cam) {
    final doc = _resolvedDoc;
    if (doc == null) {
      _updateHover(null);
      return null;
    }
    final nextHit = raycastDocument(
      doc,
      ray,
      camera: cam,
      maxDistance: maxDistance,
      layerMask: layerMask,
      where: where,
    );
    _updateHover(nextHit);
    return nextHit;
  }

  /// Begins a pointer press at the current [hit] (or after calling [pointAt]
  /// if viewport coordinates are provided).
  SceneRaycastHit? press({
    double? screenX,
    double? screenY,
    double? viewWidth,
    double? viewHeight,
    SceneCamera? overrideCamera,
  }) {
    if (screenX != null &&
        screenY != null &&
        viewWidth != null &&
        viewHeight != null) {
      pointAt(
        screenX,
        screenY,
        viewWidth,
        viewHeight,
        overrideCamera: overrideCamera,
      );
    }
    final currentHit = _hit;
    _pressedNode = currentHit?.node;
    _pressedInstance = currentHit?.instanceIndex;
    if (currentHit != null) {
      onPress?.call(currentHit.node, currentHit);
    }
    return currentHit;
  }

  /// Ends a pointer press at the current [hit] (or after calling [pointAt] if
  /// viewport coordinates are provided).
  ///
  /// Fires [onRelease] if a node was pressed, and [onTap] if the release hit
  /// lands on the same node (and instance) where the press started.
  SceneRaycastHit? release({
    double? screenX,
    double? screenY,
    double? viewWidth,
    double? viewHeight,
    SceneCamera? overrideCamera,
  }) {
    if (screenX != null &&
        screenY != null &&
        viewWidth != null &&
        viewHeight != null) {
      pointAt(
        screenX,
        screenY,
        viewWidth,
        viewHeight,
        overrideCamera: overrideCamera,
      );
    }
    final currentHit = _hit;
    final wasPressed = _pressedNode;
    final wasInstance = _pressedInstance;
    _pressedNode = null;
    _pressedInstance = null;
    if (wasPressed != null) {
      onRelease?.call(wasPressed, currentHit);
      if (currentHit != null &&
          currentHit.node == wasPressed &&
          currentHit.instanceIndex == wasInstance) {
        onTap?.call(currentHit.node, currentHit);
      }
    }
    return currentHit;
  }

  /// Cancels any active press and clears hover state.
  void cancel() {
    _pressedNode = null;
    _pressedInstance = null;
    _updateHover(null);
  }

  /// Dispatches a scroll delta `(scrollDx, scrollDy)` at the current [hit].
  void scroll(double scrollDx, double scrollDy) {
    final currentHit = _hit;
    if (currentHit != null) {
      onScroll?.call(currentHit.node, currentHit, scrollDx, scrollDy);
    }
  }

  void _updateHover(SceneRaycastHit? nextHit) {
    final nextNode = nextHit?.node;
    final nextInst = nextHit?.instanceIndex;
    final prevNode = _hoveredNode;
    final prevInst = _hoveredInstance;

    _hit = nextHit;
    _hoverChanged = (nextNode != prevNode) || (nextInst != prevInst);
    if (!_hoverChanged) return;

    if (prevNode != null) {
      onHoverExit?.call(prevNode);
    }
    _hoveredNode = nextNode;
    _hoveredInstance = nextInst;
    if (nextHit != null && nextNode != null) {
      onHoverEnter?.call(nextNode, nextHit);
    }
  }
}
