import 'dart:typed_data';

import 'package:dartnative/dartnative.dart';
import 'package:dartnative/plugin.dart';

import 'protocol.dart';
import 'scene_controller.dart';

/// The `ViewType.claim` key for the dart3d scene view. The native
/// providers claim the same key and receive the same index.
const String kSceneViewTypeKey = 'com.jasonholtdigital.dart3d/sceneView';

/// Whole-pipeline quality presets for [SceneView].
///
/// - `low`: no shadow maps, AA off.
/// - `medium`: shadow maps on (1024), MSAA×2 + FXAA.
/// - `high`: shadow maps on (2048), MSAA×4 + FXAA — the default when
///   [quality] is unset.
///
/// Setting [quality] takes the whole pipeline — [antialiasingMode] is
/// ignored while a tier is active. Leave `quality` null to drive AA
/// (and per-light `castsShadow`) directly.
enum SceneQuality { low, medium, high }

/// A 3D scene rendered by the platform's native 3D stack.
///
/// The widget owns no scene content — a [SceneController] does. Place the
/// view in the tree, then load `.fscene` documents and stream updates
/// through the controller:
///
/// ```dart
/// SceneView(
///   controller: controller,
///   allowsCameraControl: true,
/// )
/// ```
///
/// The view expands to fill its slot (Yoga `grow: 1`); give it a definite
/// size with a `SizedBox`/`Expanded` parent or a `Stack` +
/// `Positioned.fill`.
class SceneView extends StatefulWidget {
  /// The controller that drives this view's scene.
  final SceneController controller;

  /// Enables the platform's built-in camera gestures (orbit/zoom on iOS
  /// SceneKit). Off by default; app-owned cameras should keep it off.
  final bool allowsCameraControl;

  /// Shows the renderer's debug statistics overlay (draw calls, fps).
  final bool showsStatistics;

  /// Opaque ARGB color behind the scene, or null for the platform
  /// default (black). Encoded `0xAARRGGBB`.
  final int? backgroundColor;

  /// Multisample level: 0 = off, 2 or 4 = MSAA×N where the platform
  /// supports it. Ignored while [quality] is set.
  final int antialiasingMode;

  /// Whole-pipeline quality preset — see [SceneQuality] for the tier
  /// contents. Null (default) leaves AA to [antialiasingMode] and
  /// shadows to per-light `castsShadow`.
  final SceneQuality? quality;

  /// Creates a scene view.
  const SceneView({
    super.key,
    required this.controller,
    this.allowsCameraControl = false,
    this.showsStatistics = false,
    this.backgroundColor,
    this.antialiasingMode = 4,
    this.quality,
  });

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> {
  @override
  Widget build(BuildContext context) => SceneViewLeaf(
    controller: widget.controller,
    allowsCameraControl: widget.allowsCameraControl,
    showsStatistics: widget.showsStatistics,
    backgroundColor: widget.backgroundColor,
    antialiasingMode: widget.antialiasingMode,
    quality: widget.quality,
  );
}

/// The leaf widget behind [SceneView]; carries the same props so the
/// element can diff them. Apps use [SceneView].
class SceneViewLeaf extends Widget {
  /// See [SceneView.controller].
  final SceneController controller;

  /// See [SceneView.allowsCameraControl].
  final bool allowsCameraControl;

  /// See [SceneView.showsStatistics].
  final bool showsStatistics;

  /// See [SceneView.backgroundColor].
  final int? backgroundColor;

  /// See [SceneView.antialiasingMode].
  final int antialiasingMode;

  /// See [SceneView.quality].
  final SceneQuality? quality;

  /// Creates the leaf widget.
  const SceneViewLeaf({
    super.key,
    required this.controller,
    this.allowsCameraControl = false,
    this.showsStatistics = false,
    this.backgroundColor,
    this.antialiasingMode = 4,
    this.quality,
  });
}

/// Rendering-pipeline element behind [SceneViewLeaf].
class SceneViewElement extends NativeElement {
  /// Creates the element for [widget].
  SceneViewElement(super.widget);

  static final int _viewType = ViewType.claim(kSceneViewTypeKey);

  SceneViewLeaf get _leaf => widget as SceneViewLeaf;

  /// The reconciler that owns this element — kept so mutations emitted
  /// outside a build pass (ticker callbacks, controller calls) can
  /// schedule their own batch flush. The framework flushes queued
  /// mutations at pass boundaries; per-frame transform writes can't wait
  /// for the next rebuild.
  UIKitReconciler? _reconciler;

  @override
  int get viewType => _viewType;

  /// The scene view has no intrinsic size; it fills whatever slot layout
  /// gives it.
  @override
  ViewProps buildProps() => const FlexProps(direction: 0, grow: 1);

  /// As a `Stack` flow child the view stretches to the stack's cross-axis
  /// size rather than collapsing.
  @override
  bool get stretchAsStackFlowChild => true;

  @override
  void mount(Element? parent, UIKitReconciler reconciler) {
    super.mount(parent, reconciler);
    _reconciler = reconciler;
    sendMutation(D3Protocol.hello, D3Protocol.helloBytes());
    sendMutation(
      D3Protocol.viewConfig,
      D3Protocol.viewConfigBytes(_config()),
    );
    _leaf.controller.attachElement(this);
  }

  @override
  void update(Widget newWidget) {
    final old = _leaf;
    super.update(newWidget);
    if (_leaf.allowsCameraControl != old.allowsCameraControl ||
        _leaf.showsStatistics != old.showsStatistics ||
        _leaf.backgroundColor != old.backgroundColor ||
        _leaf.antialiasingMode != old.antialiasingMode ||
        _leaf.quality != old.quality) {
      sendMutation(
        D3Protocol.viewConfig,
        D3Protocol.viewConfigBytes(_config()),
      );
    }
    if (!identical(_leaf.controller, old.controller)) {
      old.controller.detachElement(this);
      _leaf.controller.attachElement(this);
    }
  }

  @override
  void unmount() {
    _leaf.controller.detachElement(this);
    _reconciler = null;
    super.unmount();
  }

  /// Emits one plugin mutation for this view. Called by the controller;
  /// not public API.
  void sendMutation(int tag, Uint8List data) {
    final id = viewId;
    if (id == null) return;
    emitMutation(PluginMutation(id, tag, data));
    _reconciler?.scheduleMutationFlush();
  }

  Map<String, Object?> _config() => {
    'allowsCameraControl': _leaf.allowsCameraControl,
    'showsStatistics': _leaf.showsStatistics,
    'antialiasingMode': _leaf.antialiasingMode,
    // Always sent — 'default' clears a previously-set tier (org.json
    // drops null values, so absence can't carry "unset").
    'quality': _leaf.quality?.name ?? 'default',
    if (_leaf.backgroundColor != null)
      'backgroundColor': _leaf.backgroundColor,
  };
}

/// Registers the scene-view element factory with the reconciler. Called
/// by [Dart3dFFIBindings.loadSymbols]; apps don't call this.
void initializeDart3d() {
  DartNativeReconciler.registerElementFactory<SceneViewLeaf>(
    (w) => SceneViewElement(w),
  );
}
