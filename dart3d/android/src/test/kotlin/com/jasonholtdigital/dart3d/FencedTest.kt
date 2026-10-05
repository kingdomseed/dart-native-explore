package com.jasonholtdigital.dart3d

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.fail
import org.junit.Test

class FencedTest {
    private class Builder {
        var built = 0
        fun build(extra: Int): Int {
            built++
            return 40 + extra
        }
        fun fail(): Nothing = throw IllegalStateException("Couldn't create Texture")
    }

    @Test
    fun runsTheBlockOnTheReceiverAndReturnsItsResult() {
        val builder = Builder()
        assertEquals(42, builder.fenced { build(2) })
        assertEquals(1, builder.built)
        assertSame(builder, builder.fenced { this })
    }

    @Test
    fun aFailingBuildStillPropagates() {
        try {
            Builder().fenced { fail() }
            fail("build's exception should propagate")
        } catch (e: IllegalStateException) {
            assertEquals("Couldn't create Texture", e.message)
        }
    }
}
