package com.jasonholtdigital.dart3d

import android.os.Handler
import android.os.Looper

/**
 * Kotlin face of the dart3d_jni shim (cpp/dart3d_jni.cpp): the stored
 * Dart dispatcher pointer plus the `fireToDart` wrapper every native
 * event funnels through. Mirrors `d3FireToDart` in Dart3dPlugin.swift —
 * events carry the view's viewId token; a token of 0 means the view was
 * never stamped (no mutation seen yet) and the event drops.
 */
object Dart3dJni {
    init {
        System.loadLibrary("dart3d_jni")
    }

    private val main = Handler(Looper.getMainLooper())

    @JvmStatic
    private external fun nativeFireToDart(token: Long, type: Int, payload: String)

    /**
     * Filament backend pref written by `Dart3dSetBackend` from the Dart
     * side at boot (0 = auto, 1 = force OpenGL, 2 = force Vulkan).
     * Read once per Dart3dView engine construction. Stays public:
     * `internal` would mangle the JNI symbol name.
     */
    @JvmStatic
    external fun nativeBackendPref(): Int

    /**
     * Fires one event frame through the plugin slot. The dispatcher
     * (a Dart NativeCallable) tolerates any calling thread, but the
     * physics loop already runs on the main Choreographer — hop to main
     * anyway so event order stays tied to the frame stream.
     */
    fun fireToDart(token: Long, type: Int, payload: String) {
        if (token == 0L) return
        if (Looper.myLooper() == Looper.getMainLooper()) {
            nativeFireToDart(token, type, payload)
        } else {
            main.post { nativeFireToDart(token, type, payload) }
        }
    }
}
