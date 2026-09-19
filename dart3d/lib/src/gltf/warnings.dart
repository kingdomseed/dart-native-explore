// Ported from flutter_scene 0.23.0 `lib/src/importer/src/gltf/warnings.dart`
// (MIT, copyright Brandon DeRosier). Verbatim.

/// A non-fatal issue noticed while importing a glTF/GLB asset, for example an
/// unrecognized `extensionsUsed` entry or an image that failed to resolve.
/// Delivered to a caller-supplied [GltfWarningCallback] when one is given to
/// the importer, or printed otherwise.
class GltfImportWarning {
  const GltfImportWarning(this.message);

  /// Human-readable description of the issue.
  final String message;

  @override
  String toString() => message;
}

/// Receives non-fatal issues noticed during a glTF/GLB import.
typedef GltfWarningCallback = void Function(GltfImportWarning warning);
