import 'dart:ffi';
import 'dart:io' show Platform;

import 'dispatch.dart';
import 'scene_view.dart';

/// Loads dart3d's native symbols and registers its element factories.
///
/// Called once per app by `DartNativePluginRegistrant.registerAll()`
/// (generated from the `dartnative.registrant` block in dart3d's
/// pubspec). Apps never call this directly.
final class Dart3dFFIBindings {
  Dart3dFFIBindings._();

  static bool _loaded = false;

  /// Registers element factories and, on iOS, registers the native
  /// view provider (`@_cdecl("DNDart3dRegisterProvider")` in the pod).
  /// On Android the provider self-registers from
  /// `FlutterPlugin.onAttachedToEngine`.
  static void loadSymbols() {
    if (_loaded) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;
    _loaded = true;

    initializeDart3d();

    if (Platform.isIOS) {
      final lib = DynamicLibrary.process();
      lib.lookupFunction<Void Function(), void Function()>(
        'DNDart3dRegisterProvider',
      )();
      lib.lookupFunction<Void Function(Int64), void Function(int)>(
        'Dart3dSetDispatcher',
      )(d3DispatcherPointer.address);
    } else if (Platform.isAndroid) {
      // The JNI shim ships inside the dart3d AAR; dlopen resolves it
      // from the app's library namespace whether or not Kotlin already
      // loaded it (System.loadLibrary refcounts the same soname).
      final lib = DynamicLibrary.open('libdart3d_jni.so');
      lib.lookupFunction<Void Function(Int64), void Function(int)>(
        'Dart3dSetDispatcher',
      )(d3DispatcherPointer.address);
    }
  }
}
