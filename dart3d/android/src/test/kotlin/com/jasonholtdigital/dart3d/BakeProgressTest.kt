package com.jasonholtdigital.dart3d

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BakeProgressTest {
    @Test
    fun aCompleteFixedSetReportsExported() {
        val line = BakeProgress.fixedSetLine(40, emptyList())
        assertEquals("bake: fixed set exported (40 packages)", line)
    }

    @Test
    fun aRejectedRecipeNeverReportsExported() {
        val line = BakeProgress.fixedSetLine(40, listOf("catcher|vk"))
        assertFalse(line.contains(BakeProgress.EXPORTED))
        assertTrue(line.startsWith(BakeProgress.INCOMPLETE))
        assertTrue(line.contains("39 of 40"))
        assertTrue(line.contains("catcher|vk"))
    }

    @Test
    fun theLaneIsIdleOnlyWhenEveryStartedCompileHasFinished() {
        val lines = ArrayList<String>()
        val progress = BakeProgress(lines::add)
        progress.started()
        progress.started()
        progress.finished()
        assertEquals(listOf(
            "bake: variants compiling (1 in flight)",
            "bake: variants compiling (2 in flight)"), lines)
        progress.finished()
        assertEquals(BakeProgress.IDLE_LINE, lines.last())
        progress.started()
        assertEquals("bake: variants compiling (1 in flight)", lines.last())
    }

    @Test
    fun theLastLineIsNeverIdleWhileACompileIsInFlight() {
        // Many threads start and finish compiles; after every line the
        // log must agree with the count that produced it.
        val lines = java.util.Collections.synchronizedList(ArrayList<String>())
        val progress = BakeProgress(lines::add)
        val pool = java.util.concurrent.Executors.newFixedThreadPool(8)
        progress.started()   // one compile stays in flight throughout
        repeat(400) {
            pool.execute {
                progress.started()
                progress.finished()
            }
        }
        pool.shutdown()
        assertTrue(pool.awaitTermination(20, java.util.concurrent.TimeUnit.SECONDS))
        assertFalse("idle was logged with a compile still in flight",
            lines.contains(BakeProgress.IDLE_LINE))
        progress.finished()
        assertEquals(BakeProgress.IDLE_LINE, lines.last())
    }

    @Test
    fun theScriptsSentinelsDoNotContainEachOther() {
        // bake_materials.sh greps for these; a busy line must not read
        // as idle, nor an incomplete set as exported.
        assertFalse(BakeProgress.busyLine(3).contains(BakeProgress.IDLE_LINE))
        assertFalse(BakeProgress.INCOMPLETE.contains(BakeProgress.EXPORTED))
    }
}
