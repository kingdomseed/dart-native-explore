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
export 'src/bvh.dart';
export 'src/camera.dart';
export 'src/camera_controllers.dart';
export 'src/camera_controls.dart';
export 'src/components.dart';
export 'src/compose_extensions.dart';
export 'src/diff_apply.dart';
export 'src/doc_layer.dart';
export 'src/fsceneb_reader.dart';
export 'src/geometry/instances.dart';
export 'src/geometry/mesh_data.dart';
export 'src/geometry/paths.dart';
export 'src/geometry/proc.dart';
export 'src/glb_import.dart';
export 'src/lut_assets.dart';
export 'src/particle_sim.dart';
export 'src/particles.dart';
export 'src/raycast.dart';
export 'src/scene_model.dart';
export 'src/scene_controller.dart'
    show NodeTransform, SceneController, SceneTickListener;
export 'src/scene_pointer.dart';
export 'src/sky_generator.dart';
export 'src/scene_view.dart'
    show SceneDebugChannel, SceneDebugView, SceneQuality, SceneView;
export 'src/subtree_stream.dart';
export 'src/ffi_bindings.dart' show Dart3dFFIBindings;
export 'src/physics.dart';
export 'src/texture_atlas.dart';
export 'src/sprite_material.dart';
export 'src/trail_lod.dart';
export 'src/vertex_pack.dart' show VertexPack;
export 'src/world_bounds.dart'
    show
        computeWorldTransforms,
        documentContentBounds,
        documentWorldBounds,
        meshNodeWorldBounds;
