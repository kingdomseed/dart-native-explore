package com.jasonholtdigital.dart3d

/**
 * Owns native-backed wrappers for one unit of work and closes them in
 * reverse creation order when the work ends, whether it returned or
 * threw.
 *
 * jolt-jni frees a wrapper's native memory in `close()`. Its automatic
 * cleanup needs `java.lang.ref.Cleaner` (API 33), so below that an
 * unclosed owner is leaked for the life of the process, and above it
 * the release waits on a GC that the native heap never triggers. Every
 * owning jolt-jni object the plugin creates is therefore handed to a
 * scope on the line that creates it, or held in a field that the
 * owner's own `close()` closes.
 */
internal class NativeScope : AutoCloseable {
    private val owned = ArrayList<AutoCloseable>()

    fun <T : AutoCloseable> own(obj: T): T {
        owned.add(obj)
        return obj
    }

    /** [obj] when it is closeable, registered; anything else untouched. */
    fun <T> ownIfCloseable(obj: T): T {
        if (obj is AutoCloseable) owned.add(obj)
        return obj
    }

    override fun close() {
        var failure: Throwable? = null
        for (i in owned.indices.reversed()) {
            try {
                owned[i].close()
            } catch (t: Throwable) {
                if (failure == null) failure = t
            }
        }
        owned.clear()
        failure?.let { throw it }
    }
}

internal inline fun <R> nativeScope(block: NativeScope.() -> R): R {
    val scope = NativeScope()
    try {
        return scope.block()
    } finally {
        scope.close()
    }
}
