package com.jasonholtdigital.dart3d

import android.content.Context

/**
 * W25 fix-2: one resolver for every wire asset `ref`. DartNative —
 * like Flutter — nests the pubspec `assets/` tree under
 * `assets/flutter_assets/` inside the APK, so a verbatim
 * `context.assets.open(ref)` misses packaged assets. Try the nested
 * path first, then the bare ref (non-Flutter-packaged asset trees
 * still resolve); a ref already carrying the prefix skips the
 * double-prefix.
 */
object FlutterAssets {
    fun readBytes(context: Context, ref: String): ByteArray? {
        if (ref.isEmpty()) return null
        val paths = if (ref.startsWith("flutter_assets/")) {
            arrayOf(ref)
        } else {
            arrayOf("flutter_assets/$ref", ref)
        }
        for (path in paths) {
            try {
                return context.assets.open(path).use { it.readBytes() }
            } catch (e: Exception) {
                // Miss — try the next shape.
            }
        }
        return null
    }
}
