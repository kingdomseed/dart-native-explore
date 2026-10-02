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
 * - [exportDir], set only while baking, receives every compiled package
 *   raw, with an `index.txt` line naming its key.
 */
internal class MaterialStore(
    private val shipped: (fileName: String) -> ByteArray?,
    private val cacheDir: File?,
    private val exportDir: File? = null,
    private val maxCached: Int = 48,
) {
    fun find(fingerprint: String): ByteArray? =
        shipped(fileName(fingerprint)) ?: readCache(fingerprint)

    fun save(fingerprint: String, key: String, bytes: ByteArray) {
        cacheDir?.let { dir ->
            val crc = ByteBuffer.allocate(4).putInt(crcOf(bytes)).array()
            writeAtomically(File(dir, fileName(fingerprint)), bytes, crc)
            trim(dir)
        }
        exportDir?.let { dir ->
            if (writeAtomically(File(dir, fileName(fingerprint)), bytes)) {
                File(dir, INDEX_NAME).appendText(indexLine(fingerprint, key))
            }
        }
    }

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
        val files = dir.listFiles { f -> f.name.endsWith(SUFFIX) } ?: return
        files.sortedByDescending { it.lastModified() }
            .drop(maxCached)
            .forEach { it.delete() }
    }

    private fun writeAtomically(
        target: File, vararg parts: ByteArray,
    ): Boolean = try {
        target.parentFile?.mkdirs()
        val tmp = File(target.path + ".tmp")
        tmp.outputStream().use { out ->
            for (p in parts) out.write(p)
            out.fd.sync()
        }
        tmp.renameTo(target) || run { tmp.delete(); false }
    } catch (e: Exception) {
        false
    }

    companion object {
        /** Asset directory of shipped packages, in the plugin and the app. */
        const val ASSET_DIR = "dart3d/materials"
        const val INDEX_NAME = "index.txt"

        private const val SUFFIX = ".filamat"

        fun fileName(fingerprint: String) = fingerprint + SUFFIX

        fun indexLine(fingerprint: String, key: String) = "$fingerprint $key\n"

        /** `index.txt` → fingerprint to key; the last line for a fingerprint wins. */
        fun parseIndex(text: String): Map<String, String> {
            val out = LinkedHashMap<String, String>()
            for (line in text.lineSequence()) {
                val cut = line.indexOf(' ')
                if (cut <= 0) continue
                out[line.substring(0, cut)] = line.substring(cut + 1).trim()
            }
            return out
        }

        private fun crcOf(bytes: ByteArray): Int =
            CRC32().apply { update(bytes) }.value.toInt()
    }
}
