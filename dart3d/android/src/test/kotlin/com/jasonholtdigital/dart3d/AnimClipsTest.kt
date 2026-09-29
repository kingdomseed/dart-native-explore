package com.jasonholtdigital.dart3d

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * #33 regression coverage for the clip verb rules and the blend
 * weights `Dart3dView.sampleAnimations` samples with. A stopped clip
 * must leave the blend so the channels it drove return to rest —
 * before the fix it kept blending its t=0 pose at full weight, and a
 * clip cycler (stop old, play next) left every visited clip in the
 * blend: Dash's eyes stayed half-closed from Jump's t=0 squash.
 * Pure JVM — no Filament.
 */
class AnimClipsTest {

    private fun clip(block: AnimClipState.() -> Unit = {}) =
        AnimClipState().apply(block)

    @Test
    fun `stop takes the clip out of the blend`() {
        val a = clip { applyOp(endTime = 1.0, play = true) }
        assertEquals(mapOf(1L to 1f), blendWeights(mapOf(1L to a)))

        a.applyOp(endTime = 1.0, stop = true)
        assertFalse(a.playing)
        assertEquals(0.0, a.time, 0.0)
        // No active clip → nothing blends; the sampler's write-back
        // then holds every recorded node at its bind pose.
        assertTrue(blendWeights(mapOf(1L to a)).isEmpty())
    }

    @Test
    fun `switching clips leaves only the next clip at full weight`() {
        val clips = HashMap<Long, AnimClipState>()
        // Cycle 9 clips 3× the way the showcase chip does.
        var current = 0L
        clips.getOrPut(current) { AnimClipState() }
            .applyOp(endTime = 1.0, play = true, loop = true)
        repeat(27) {
            clips.getValue(current).applyOp(endTime = 1.0, stop = true)
            current = (current + 1) % 9
            clips.getOrPut(current) { AnimClipState() }
                .applyOp(endTime = 1.0, play = true, loop = true)
            assertEquals(mapOf(current to 1f), blendWeights(clips))
        }
        assertEquals(9, clips.size)
    }

    @Test
    fun `paused clips keep blending and normalize with the rest`() {
        val a = clip { applyOp(endTime = 1.0, play = true, time = 0.4) }
        val b = clip { applyOp(endTime = 1.0, play = true) }
        a.applyOp(endTime = 1.0, pause = true)
        assertEquals(mapOf(1L to 0.5f, 2L to 0.5f),
            blendWeights(mapOf(1L to a, 2L to b)))
    }

    @Test
    fun `play or seek brings a stopped clip back`() {
        val a = clip { applyOp(endTime = 2.0, play = true) }
        a.applyOp(endTime = 2.0, stop = true)
        a.applyOp(endTime = 2.0, time = 5.0)
        assertTrue(a.active)
        assertEquals(2.0, a.time, 0.0)   // seek clamps to endTime
        assertFalse(a.playing)

        a.applyOp(endTime = 2.0, stop = true)
        a.applyOp(endTime = 2.0, play = true)
        assertTrue(a.active && a.playing)
    }

    @Test
    fun `stop then play in one op restarts from zero`() {
        val a = clip { applyOp(endTime = 1.0, play = true, time = 0.7) }
        a.applyOp(endTime = 1.0, stop = true, play = true)
        assertTrue(a.active && a.playing)
        assertEquals(0.0, a.time, 0.0)
    }
}
