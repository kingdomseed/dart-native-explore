package com.jasonholtdigital.dart3d

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [TransformWrites] — what a payload-arrival re-realize carries across
 * its manifest rebuild. The dice tray's screen fit (camera, walls, rim)
 * is a `setTransforms` sent right behind `loadScene`; it drains ahead of
 * the document's last payload chunk, so the rebuild used to put every
 * node back at its build-time pose (Fire tablet, landscape: a portrait
 * rim on a landscape screen). Pure JVM — no Filament.
 */
class TransformWritesTest {

    private val t = TransformWrites.TRANSLATION
    private val r = TransformWrites.ROTATION
    private val s = TransformWrites.SCALE

    private fun live(vararg nodes: Pair<Long, Array<FloatArray>>) =
        mapOf(*nodes).let { m -> { id: Long -> m[id] } }

    private fun trs(x: Float) = arrayOf(
        floatArrayOf(x, 0f, 0f), floatArrayOf(0f, 0f, 0f, 1f),
        floatArrayOf(x, 1f, 1f))

    @Test
    fun `written fields accumulate per node`() {
        val w = TransformWrites()
        w.record(1, t)
        w.record(1, s)
        w.record(2, t or r)
        val got = w.capture(current = live(1L to trs(5f), 2L to trs(6f)))
        assertEquals(listOf(1L, 2L), got.map { it.id })
        assertEquals(listOf(t or s, t or r), got.map { it.mask })
    }

    @Test
    fun `capture reads the node's current pose, not the written one`() {
        val w = TransformWrites()
        w.record(1, t or s)
        val pose = w.capture(current = live(1L to trs(9f))).single()
        assertArrayEquals(floatArrayOf(9f, 0f, 0f), pose.pos, 0f)
        assertArrayEquals(floatArrayOf(9f, 1f, 1f), pose.scale, 0f)
    }

    @Test
    fun `capture copies, so the rebuild can't alias the old node`() {
        val w = TransformWrites()
        w.record(1, t)
        val node = trs(3f)
        val pose = w.capture(current = live(1L to node)).single()
        node[0][0] = 99f
        assertEquals(3f, pose.pos[0], 0f)
    }

    @Test
    fun `an untouched node is not carried`() {
        val w = TransformWrites()
        w.record(1, t)
        val got = w.capture(current = live(1L to trs(1f), 2L to trs(2f)))
        assertEquals(listOf(1L), got.map { it.id })
    }

    @Test
    fun `a clip-driven node is left to the manifest pose`() {
        val w = TransformWrites()
        w.record(1, t)
        w.record(2, t)
        val got = w.capture(
            clipDriven = { it == 1L },
            current = live(1L to trs(1f), 2L to trs(2f)))
        assertEquals(listOf(2L), got.map { it.id })
    }

    @Test
    fun `a removed subtree drops every doomed node's writes`() {
        val w = TransformWrites()
        w.record(1, t)
        w.record(2, s)
        w.record(3, r)
        w.supersedeAll(setOf(1L, 2L))
        val got = w.capture(
            current = live(1L to trs(1f), 2L to trs(2f), 3L to trs(3f)))
        assertEquals(listOf(3L), got.map { it.id })
    }

    @Test
    fun `a removed node is skipped`() {
        val w = TransformWrites()
        w.record(1, t)
        assertTrue(w.capture(current = live()).isEmpty())
    }

    @Test
    fun `a structural rewrite supersedes earlier writes`() {
        val w = TransformWrites()
        w.record(1, t or r or s)
        w.supersede(1)
        assertTrue(w.capture(current = live(1L to trs(1f))).isEmpty())
        w.record(1, s)
        assertEquals(s, w.capture(current = live(1L to trs(1f))).single().mask)
    }

    @Test
    fun `an empty mask records nothing and clear forgets everything`() {
        val w = TransformWrites()
        w.record(1, 0)
        assertTrue(w.isEmpty)
        w.record(1, t)
        w.clear()
        assertTrue(w.isEmpty)
    }
}
