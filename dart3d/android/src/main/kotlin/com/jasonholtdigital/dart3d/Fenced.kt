package com.jasonholtdigital.dart3d

import android.os.Build

/**
 * Runs [block] on the receiver and keeps the receiver reachable until
 * it has returned.
 *
 * Filament's Java builders (and filamat's MaterialBuilder) free their
 * native builder in a finalizer. `build()` reads the native handle out
 * of the Java object and then spends its time in native code; once the
 * handle is read the Java object has no further use, so ART may treat
 * it as garbage while the native call is still running, and a GC in
 * that window lets the finalizer free the builder under it. That is
 * the crash in `ColorGrading::Builder::build` recorded in
 * docs/triage/integration.md. Every such `build` goes through here.
 */
internal inline fun <B : Any, R> B.fenced(block: B.() -> R): R =
    try {
        block()
    } finally {
        Reachability.fence(this)
    }

internal object Reachability {
    @Volatile
    private var held: Any? = null

    fun fence(obj: Any?) {
        if (Build.VERSION.SDK_INT >= 28) {
            java.lang.ref.Reference.reachabilityFence(obj)
        } else {
            // API 26 and 27 have no reachabilityFence. A volatile store
            // cannot be dropped, and reading the field back keeps R8
            // from deleting it as write-only.
            held = obj
            if (held != null) held = null
        }
    }
}
