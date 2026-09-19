/// dart3d's scene-model surface, imported from `package:scene`'s component
/// libraries rather than its `package:scene/scene.dart` barrel.
///
/// Why: DartNative's `flutter_patched_sdk` `platform.dill` bakes in the
/// Dart SDK's vendored `pkg/archive` (a pre-4.x API), and platform
/// libraries shadow `package:` resolution at kernel-compile time — so
/// `package:archive` always resolves to the baked copy regardless of the
/// version `pubspec.lock` selects. `scene.dart` exports
/// `src/binary/fsceneb.dart`, which invokes `const GZipEncoder()`; the
/// baked archive's `GZipEncoder` has no const constructor, so importing
/// `package:scene/scene.dart` fails the DartNative kernel build no matter
/// what `archive` version is resolved. The component libraries below are
/// the same public types with the same identities, and none of them reach
/// `fsceneb.dart` (the only `package:archive` consumer in `scene`).
///
/// Keep all `package:scene` imports routed through this file. Do not add
/// `package:scene/scene.dart` imports anywhere in dart3d or its consumers
/// until the DartNative SDK stops shadowing `package:archive`.
library;

export 'package:scene/src/compose/compose.dart';
export 'package:scene/src/diff.dart';
export 'package:scene/src/id.dart';
export 'package:scene/src/json/canonical.dart';
export 'package:scene/src/json/fscene_json.dart';
export 'package:scene/src/json/jsonc.dart';
export 'package:scene/src/json/property_json.dart';
export 'package:scene/src/property_value.dart';
export 'package:scene/src/scene_document.dart';
export 'package:scene/src/specs.dart';
