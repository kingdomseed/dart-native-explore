package com.jasonholtdigital.dart3d

import java.io.File
import java.nio.ByteBuffer
import java.util.zip.CRC32

/**
 * Where compiled material packages are kept between processes, looked
 * up by [MaterialRecipe.fingerprint].
 *
 * - [shipped] reads a package built ahead of time and packaged with the
 *   app: the plugin's own fixed set, plus whatever the app baked for
 *   its documents (`assets/dart3d/materials/<fingerprint>.filamat`).
 * - [cacheDir] holds what this install compiled itself, so a package is
 *   compiled at most once per install. Each file carries a CRC-32
 *   trailer; a file that fails it is deleted and reads as a miss. The
 *   directory keeps the [maxCached] most recently used packages.
 * - A package the engine refused to load is marked with [reject]: its
 *   shipped copy is skipped from then on and the cache holds the
 *   recompiled one. That happens when the app's build resolves another
 *   Filament than the one the shipped packages were built for.
 * - [exportDir], set only while baking, receives every compiled package
 *   raw, with an `index.txt` line naming its key.
 */
internal class MaterialStore(
    private val shipped: (fileName: String) -> ByteArray?,
    private val cacheDir: File?,
    private val exportDir: File? = null,
    private val maxCached: Int = 48,
) {
    fun find(fingerprint: String): ByteArray? {
        if (!isRejected(fingerprint)) {
            shipped(fileName(fingerprint))?.let { return it }
        }
        return readCache(fingerprint)
    }

    /**
     * Drops [fingerprint]'s cached file and stops serving its shipped
     * copy, for as long as the cache directory lives.
     */
    fun reject(fingerprint: String) {
        rejectedNow.add(fingerprint)
        val dir = cacheDir ?: return
        try {
            File(dir, fileName(fingerprint)).delete()
            dir.mkdirs()
            File(dir, fingerprint + REJECTED_SUFFIX).createNewFile()
        } catch (e: Exception) {
            // Without the marker the next process retries the shipped
            // copy and lands here again.
        }
    }

    private val rejectedNow =
        java.util.concurrent.ConcurrentHashMap.newKeySet<String>()

    private fun isRejected(fingerprint: String): Boolean =
        fingerprint in rejectedNow ||
            cacheDir?.let { File(it, fingerprint + REJECTED_SUFFIX).exists() }
                ?: false

    fun save(fingerprint: String, key: String, bytes: ByteArray) {
        cacheDir?.let { dir ->
            val crc = ByteBuffer.allocate(4).putInt(crcOf(bytes)).array()
            writeAtomically(File(dir, fileName(fingerprint)), bytes, crc)
            trim(dir)
        }
        exportDir?.let { dir ->
            val target = File(dir, fileName(fingerprint))
            if (!target.exists() && writeAtomically(target, bytes)) {
                File(dir, INDEX_NAME).appendText(indexLine(fingerprint, key))
            }
        }
    }

    /** True when a bake run has this package's file in [exportDir]. */
    fun isExported(fingerprint: String): Boolean =
        exportDir?.let { File(it, fileName(fingerprint)).isFile } ?: false

    private fun readCache(fingerprint: String): ByteArray? {
        val file = File(cacheDir ?: return null, fileName(fingerprint))
        val framed = try {
            if (!file.isFile) return null
            file.readBytes()
        } catch (e: Exception) {
            return null
        }
        if (framed.size > 4) {
            val bytes = framed.copyOf(framed.size - 4)
            val stored = ByteBuffer.wrap(framed, framed.size - 4, 4).int
            if (stored == crcOf(bytes)) {
                file.setLastModified(System.currentTimeMillis())
                return bytes
            }
        }
        file.delete()
        return null
    }

    private fun trim(dir: File) {
        val all = dir.listFiles() ?: return
        all.filter { it.name.endsWith(SUFFIX) }
            .sortedByDescending { it.lastModified() }
            .drop(maxCached)
            .forEach { it.delete() }
        val stale = System.currentTimeMillis() - TMP_MAX_AGE_MS
        all.filter { it.name.endsWith(TMP_SUFFIX) && it.lastModified() < stale }
            .forEach { it.delete() }
    }

    private fun writeAtomically(
        target: File, vararg parts: ByteArray,
    ): Boolean {
        val tmp = File(target.path + TMP_SUFFIX)
        val written = try {
            target.parentFile?.mkdirs()
            tmp.outputStream().use { out ->
                for (p in parts) out.write(p)
                out.fd.sync()
            }
            tmp.renameTo(target)
        } catch (e: Exception) {
            false
        }
        if (!written) tmp.delete()
        return written
    }

    companion object {
        /** Asset directory of shipped packages, in the plugin and the app. */
        const val ASSET_DIR = "dart3d/materials"
        const val INDEX_NAME = "index.txt"

        private const val SUFFIX = ".filamat"
        private const val TMP_SUFFIX = ".tmp"
        private const val REJECTED_SUFFIX = ".rejected"

        /** A temp file older than this was orphaned by a killed write. */
        private const val TMP_MAX_AGE_MS = 60_000L

        fun fileName(fingerprint: String) = fingerprint + SUFFIX

        fun indexLine(fingerprint: String, key: String) = "$fingerprint $key\n"

        /**
         * `index.txt` → fingerprint to key; the last line for a
         * fingerprint wins. `#` lines are comments.
         */
        fun parseIndex(text: String): Map<String, String> {
            val out = LinkedHashMap<String, String>()
            for (line in text.lineSequence()) {
                val cut = line.indexOf(' ')
                if (cut <= 0 || line.startsWith("#")) continue
                out[line.substring(0, cut)] = line.substring(cut + 1).trim()
            }
            return out
        }

        private fun crcOf(bytes: ByteArray): Int =
            CRC32().apply { update(bytes) }.value.toInt()
    }
}
