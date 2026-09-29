package com.jasonholtdigital.dart3d

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The clip verb rules and blend weights `Dart3dView.sampleAnimations`
 * samples with — upstream `AnimationClip`/`AnimationPlayer` semantics.
 * #33: a stopped clip stays in the blend at its weight (upstream's
 * `stop` is pause + rewind), so a stop-only clip switcher left every
 * visited clip blending its t=0 pose and Dash's eyes half-closed.
 * Switching clips means dropping the outgoing clip's weight to 0 —
 * `SceneController.switchAnimation`. Pure JVM — no Filament.
 */
class AnimClipsTest {

    private fun clip(block: AnimClipState.() -> Unit = {}) =
        AnimClipState().apply(block)

    @Test
    fun `stop pauses and rewinds but keeps blending at its weight`() {
        val a = clip { applyOp(endTime = 1.0, play = true, time = 0.6) }
        val b = clip { applyOp(endTime = 1.0, play = true) }
        a.applyOp(endTime = 1.0, stop = true)
        assertFalse(a.playing)
        assertEquals(0.0, a.time, 0.0)
        // Upstream parity: the stopped clip still takes half the blend.
        assertEquals(mapOf(1L to 0.5f, 2L to 0.5f),
            blendWeights(mapOf(1L to a, 2L to b)))
    }

    @Test
    fun `a weight-0 clip contributes nothing`() {
        val a = clip { applyOp(endTime = 1.0, stop = true, weight = 0.0) }
        val b = clip { applyOp(endTime = 1.0, play = true, weight = 1.0) }
        assertEquals(mapOf(1L to 0f, 2L to 1f),
            blendWeights(mapOf(1L to a, 2L to b)))
        // Only zero-weight clips left → every effective weight is 0, so
        // the sampler writes each bound node back at its bind pose.
        b.applyOp(endTime = 1.0, stop = true, weight = 0.0)
        assertTrue(blendWeights(mapOf(1L to a, 2L to b)).values.all { it == 0f })
    }

    @Test
    fun `a 9-clip switch cycle via weight 0 leaves only the current clip`() {
        val clips = HashMap<Long, AnimClipState>()
        var current = 0L
        clips.getOrPut(current) { AnimClipState() }
            .applyOp(endTime = 1.0, play = true, weight = 1.0, loop = true)
        repeat(27) {
            // switchAnimation's batch: outgoing stop + weight 0, then
            // incoming play at weight 1.
            clips.getValue(current)
                .applyOp(endTime = 1.0, stop = true, weight = 0.0)
            current = (current + 1) % 9
            clips.getOrPut(current) { AnimClipState() }
                .applyOp(endTime = 1.0, play = true, weight = 1.0, loop = true)
            val w = blendWeights(clips)
            assertEquals(1f, w.getValue(current))
            assertTrue(w.filterKeys { it != current }.values.all { it == 0f })
        }
        assertEquals(9, clips.size)
    }

    @Test
    fun `a stop-only cycle dilutes the current clip (the #33 shape)`() {
        val clips = HashMap<Long, AnimClipState>()
        for (k in 0L until 9L) {
            clips.values.forEach { it.applyOp(endTime = 1.0, stop = true) }
            clips.getOrPut(k) { AnimClipState() }
                .applyOp(endTime = 1.0, play = true, loop = true)
        }
        assertEquals(1f / 9f, blendWeights(clips).getValue(8L), 1e-6f)
    }

    @Test
    fun `play trumps stop and seeks clamp to endTime`() {
        val a = clip { applyOp(endTime = 1.0, play = true, time = 0.7) }
        a.applyOp(endTime = 1.0, stop = true, play = true)
        assertTrue(a.playing)
        assertEquals(0.0, a.time, 0.0)
        a.applyOp(endTime = 1.0, time = 5.0, weight = 3.0)
        assertEquals(1.0, a.time, 0.0)
        assertEquals(1.0, a.weight, 0.0)
    }
}
