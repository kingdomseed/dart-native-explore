/// Interactive [CameraControls] wrapper around a [SceneView] or other child.
/// Routes mobile tap, pan, and pinch input to a [CameraController] and optional
/// [ScenePointer]. A Dart frame ticker advances the controller and forwards
/// frame callbacks to [SceneController] tick listeners.
///
/// It does not implement upstream keyboard, wheel, or hover input, or V6f's
/// native fixed-step loop.
library;

import 'package:dartnative/dartnative.dart';

import 'camera_controllers.dart';
import 'physics.dart' show SceneRaycastHit;
import 'scene_controller.dart';
import 'scene_pointer.dart';

/// Wraps a [SceneView] (or other widget) with gesture handlers and a frame
/// ticker that drive [controller] (and optional [pointer]).
///
/// Mirrors upstream `flutter_scene` `CameraControls`.
class CameraControls extends StatefulWidget {
  /// Creates a [CameraControls] wrapper.
  const CameraControls({
    super.key,
    required this.controller,
    required this.child,
    this.sceneController,
    this.pointer,
    this.enabled = true,
    this.onTapPick,
  });

  /// The camera controller driven by gestures and frame ticks.
  final CameraController controller;

  /// Optional [SceneController] whose camera node receives per-frame pose
  /// updates and whose tick listeners are notified each frame.
  final SceneController? sceneController;

  /// Optional [ScenePointer] updated on tap / drag gestures.
  final ScenePointer? pointer;

  /// Optional callback invoked when a tap picks (or misses) a scene node.
  final void Function(SceneRaycastHit? hit, Offset localPosition)? onTapPick;

  /// Whether gesture routing is enabled.
  final bool enabled;

  /// The child widget (typically a [SceneView]).
  final Widget child;

  @override
  State<CameraControls> createState() => _CameraControlsState();
}

class _CameraControlsState extends State<CameraControls>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastElapsed = Duration.zero;

  // One-finger vs two-finger gesture arbitration (DartNative iOS scale
  // recognizer claims one-finger drags too, so we arbitrate between pan and
  // scale streams like ShowcaseScreen / HeroScreen).
  _GestureOwner? _dragOwner;
  Offset? _lastFocal;
  int _scalePointers = 0;
  bool _tapPending = false;

  @override
  void initState() {
    super.initState();
    _syncSceneInitial();
    _ticker.start();
  }

  @override
  void didUpdateWidget(CameraControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller) ||
        !identical(widget.sceneController, oldWidget.sceneController)) {
      _syncSceneInitial();
    }
  }

  void _syncSceneInitial() {
    final sc = widget.sceneController;
    if (sc != null) {
      widget.controller.applyToScene(sc);
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastElapsed == Duration.zero
        ? 0.0
        : (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    final clampedDt = dt.clamp(0.0, 0.1);

    final sc = widget.sceneController;
    sc?.notifyTick(clampedDt);

    if (clampedDt > 0) {
      widget.controller.update(clampedDt);
      if (sc != null) {
        widget.controller.applyToScene(sc);
      }
    }
  }

  void _applyPrimaryDrag(_GestureOwner source, Offset delta) {
    if (!widget.enabled) return;
    _dragOwner ??= source;
    if (_dragOwner != source) return;
    _cancelTap();
    widget.controller.onPrimaryDrag(delta.dx, delta.dy);
    final sc = widget.sceneController;
    if (sc != null) {
      widget.controller.applyToScene(sc);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!widget.enabled) return;
    if (d.pointerCount == 1) {
      _applyPrimaryDrag(_GestureOwner.pan, d.delta);
    } else if (d.pointerCount >= 2) {
      _cancelTap();
    }
  }

  void _startTap(Offset position, Size viewSize) {
    if (!widget.enabled || _tapPending) return;
    _tapPending = true;
    widget.pointer?.press(
      screenX: position.dx,
      screenY: position.dy,
      viewWidth: viewSize.width,
      viewHeight: viewSize.height,
      overrideCamera: widget.controller.camera,
    );
  }

  void _cancelTap() {
    if (!_tapPending) return;
    _tapPending = false;
    widget.pointer?.cancel();
  }

  void _finishTap(Offset position, Size viewSize) {
    if (!_tapPending) return;
    if (!widget.enabled) {
      _cancelTap();
      return;
    }
    _tapPending = false;
    final ptr = widget.pointer;
    final hit = ptr != null
        ? ptr.release(
            screenX: position.dx,
            screenY: position.dy,
            viewWidth: viewSize.width,
            viewHeight: viewSize.height,
            overrideCamera: widget.controller.camera,
          )
        : widget.onTapPick != null && widget.sceneController != null
        ? widget.sceneController!.pick(
            position.dx,
            position.dy,
            viewSize.width,
            viewSize.height,
            camera: widget.controller.camera,
          )
        : null;
    widget.onTapPick?.call(hit, position);
  }

  void _onScaleStart(ScaleStartDetails d, Size viewSize) {
    if (!widget.enabled) return;
    _lastFocal = d.focalPoint;
    _scalePointers = d.pointerCount;
    if (d.pointerCount >= 2) {
      _cancelTap();
    } else {
      _startTap(d.focalPoint, viewSize);
    }
    widget.controller.onScaleStart();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!widget.enabled) return;
    final last = _lastFocal;
    final prevPointers = _scalePointers;
    _lastFocal = d.focalPoint;
    _scalePointers = d.pointerCount;

    if (d.pointerCount >= 2) _cancelTap();
    if (d.pointerCount == 1) {
      if (prevPointers == 1 && last != null) {
        _applyPrimaryDrag(_GestureOwner.scale, d.focalPoint - last);
      }
      return;
    }

    if (prevPointers < 2) {
      widget.controller.onScaleStart();
    }
    final focalDelta = (prevPointers >= 2 && last != null)
        ? (d.focalPoint - last)
        : Offset.zero;
    widget.controller.onScaleUpdate(
      d.scale,
      panDx: focalDelta.dx,
      panDy: focalDelta.dy,
    );
    final sc = widget.sceneController;
    if (sc != null) {
      widget.controller.applyToScene(sc);
    }
  }

  void _endGesture() {
    _dragOwner = null;
    _lastFocal = null;
    _scalePointers = 0;
  }

  void _onScaleEnd(Size viewSize) {
    final last = _lastFocal;
    if (last != null) _finishTap(last, viewSize);
    _endGesture();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mqSize = MediaQuery.of(context).size;
        final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : mqSize.width;
        final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : mqSize.height;
        final viewSize = Size(w, h);
        return GestureDetector(
          onTapDown: (d) => _startTap(d.localPosition, viewSize),
          onTapUp: (d) => _finishTap(d.localPosition, viewSize),
          onTapCancel: _cancelTap,
          onPanStart: (_) {
            _dragOwner = null;
            _cancelTap();
          },
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => _endGesture(),
          onScaleStart: (d) => _onScaleStart(d, viewSize),
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: (_) => _onScaleEnd(viewSize),
          child: widget.child,
        );
      },
    );
  }
}

enum _GestureOwner { pan, scale }
