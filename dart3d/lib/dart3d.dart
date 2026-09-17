/// dart3d — a general-purpose 3D scene plugin for DartNative.
///
/// Apps describe scenes as `.fscene` documents ([SceneDocument] from
/// `package:scene`), hand them to a [SceneController], and place a
/// [SceneView] in the widget tree. Documents and updates travel to the
/// native renderer as `PluginMutation` bytes; iOS renders with SceneKit
/// and Android with Filament + Jolt.
///
/// ```dart
/// final controller = SceneController();
/// SceneView(controller: controller)
/// controller.loadDocument(myDocument);
/// ```
library;

export 'src/animation.dart';
export 'src/diff_apply.dart';
export 'src/fsceneb_reader.dart';
export 'src/scene_model.dart';
export 'src/scene_controller.dart' show NodeTransform, SceneController;
export 'src/scene_view.dart' show SceneQuality, SceneView;
export 'src/ffi_bindings.dart' show Dart3dFFIBindings;
export 'src/physics.dart';
export 'src/vertex_pack.dart' show VertexPack;
export 'src/world_bounds.dart'
    show documentContentBounds, documentWorldBounds, meshNodeWorldBounds;
