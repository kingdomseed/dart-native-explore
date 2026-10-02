package com.jasonholtdigital.dart3d

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** [MaterialStore] — shipped packages, the disk cache and the bake export. */
class MaterialStoreTest {

    private fun tempDir(): File =
        Files.createTempDirectory("d3-store").toFile().also { it.deleteOnExit() }

    private val pkg = ByteArray(5000) { (it * 31).toByte() }

    @Test
    fun `a saved package is found by a later store on the same directory`() {
        val dir = tempDir()
        MaterialStore({ null }, dir).save("abc", "lit|k", pkg)
        assertArrayEquals(pkg, MaterialStore({ null }, dir).find("abc"))
    }

    @Test
    fun `an unknown fingerprint is a miss`() {
        assertNull(MaterialStore({ null }, tempDir()).find("nope"))
        assertNull(MaterialStore({ null }, null).find("nope"))
    }

    @Test
    fun `the cache directory is created on first save`() {
        val dir = File(tempDir(), "a/b")
        MaterialStore({ null }, dir).save("abc", "k", pkg)
        assertTrue(File(dir, "abc.filamat").isFile)
    }

    @Test
    fun `a damaged cache file reads as a miss and is removed`() {
        val dir = tempDir()
        val store = MaterialStore({ null }, dir)
        store.save("abc", "k", pkg)
        val file = File(dir, "abc.filamat")
        val bytes = file.readBytes()
        bytes[100] = (bytes[100] + 1).toByte()
        file.writeBytes(bytes)
        assertNull(store.find("abc"))
        assertFalse(file.exists())
    }

    @Test
    fun `a truncated cache file reads as a miss`() {
        val dir = tempDir()
        val store = MaterialStore({ null }, dir)
        store.save("abc", "k", pkg)
        val file = File(dir, "abc.filamat")
        file.writeBytes(file.readBytes().copyOf(1200))
        assertNull(store.find("abc"))
        file.writeBytes(ByteArray(3))
        assertNull(store.find("abc"))
    }

    @Test
    fun `a shipped package wins over the cache and is asked for by file name`() {
        val dir = tempDir()
        MaterialStore({ null }, dir).save("abc", "k", pkg)
        val shipped = byteArrayOf(1, 2, 3)
        val asked = ArrayList<String>()
        val store = MaterialStore({ asked += it; shipped }, dir)
        assertArrayEquals(shipped, store.find("abc"))
        assertEquals(listOf("abc.filamat"), asked)
    }

    @Test
    fun `the cache keeps only the most recently used packages`() {
        val dir = tempDir()
        val store = MaterialStore({ null }, dir, maxCached = 2)
        store.save("a", "k", pkg)
        store.save("b", "k", pkg)
        File(dir, "a.filamat").setLastModified(1_000_000)
        File(dir, "b.filamat").setLastModified(2_000_000)
        assertArrayEquals(pkg, store.find("a"))
        store.save("c", "k", pkg)
        assertEquals(setOf("a.filamat", "c.filamat"), dir.list()!!.toSet())
    }

    @Test
    fun `no temp file is left behind`() {
        val dir = tempDir()
        MaterialStore({ null }, dir).save("abc", "k", pkg)
        assertEquals(listOf("abc.filamat"), dir.list()!!.toList())
    }

    @Test
    fun `the export gets the raw package and an index line`() {
        val out = tempDir()
        val store = MaterialStore({ null }, null, out)
        store.save("abc", "lit|false|OPAQUE|e0|s31|VULKAN", pkg)
        store.save("def", "trail|OPENGL", byteArrayOf(9))
        assertArrayEquals(pkg, File(out, "abc.filamat").readBytes())
        assertEquals(
            mapOf("abc" to "lit|false|OPAQUE|e0|s31|VULKAN",
                "def" to "trail|OPENGL"),
            MaterialStore.parseIndex(File(out, "index.txt").readText()))
    }

    @Test
    fun `parseIndex skips blank and malformed lines`() {
        assertEquals(mapOf("a" to "k 1", "b" to "k2"),
            MaterialStore.parseIndex("a k 1\n\nnokey\nb k2\n"))
    }
}
