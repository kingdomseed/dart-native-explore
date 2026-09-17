package com.jasonholtdigital.dart3d

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Flutter plugin entry point — auto-registered by the generated
 * registrant via pubspec `pluginClass`. Its sole job is to register the
 * dart3d view provider once per engine attach.
 *
 * When the Filament backend lands it will also `System.loadLibrary`
 * the dart3d JNI shim here (the only call site that fires JNI_OnLoad).
 */
class DartNativeDart3dPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Dart3dBridge.register()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // The provider registry lives for the process lifetime; nothing
        // to unwind on detach.
    }
}
