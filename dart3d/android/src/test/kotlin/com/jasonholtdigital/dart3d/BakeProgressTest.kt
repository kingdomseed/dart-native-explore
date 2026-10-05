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
        val progress = BakeProgress()
        assertEquals(1, progress.started())
        assertEquals(2, progress.started())
        assertFalse(progress.finished())
        assertTrue(progress.finished())
        assertEquals(1, progress.started())
        assertTrue(progress.finished())
    }

    @Test
    fun theScriptsSentinelsDoNotContainEachOther() {
        // bake_materials.sh greps for these; a busy line must not read
        // as idle, nor an incomplete set as exported.
        assertFalse(BakeProgress.busyLine(3).contains(BakeProgress.IDLE_LINE))
        assertFalse(BakeProgress.INCOMPLETE.contains(BakeProgress.EXPORTED))
    }
}
