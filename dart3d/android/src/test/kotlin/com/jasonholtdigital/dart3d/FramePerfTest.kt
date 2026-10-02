package com.jasonholtdigital.dart3d

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** [FramePerf] — the `dart3d.perf` frame-time window. Pure JVM. */
class FramePerfTest {

    private val ms = 1_000_000L

    @Test
    fun `nearest-rank percentiles`() {
        val v = floatArrayOf(5f, 1f, 4f, 2f, 3f, 99f)
        assertEquals(3f, FramePerf.percentile(v, 5, 0.50), 0f)
        assertEquals(5f, FramePerf.percentile(v, 5, 0.95), 0f)
        assertEquals(5f, FramePerf.percentile(v, 5, 1.0), 0f)
        assertEquals(0f, FramePerf.percentile(v, 0, 0.5), 0f)
    }

    @Test
    fun `a window reports once it has run its length`() {
        val p = FramePerf(windowNanos = 100 * ms)
        var t = 1_000 * ms
        var line: String? = null
        var frames = 0
        while (line == null) {
            line = p.frame(t, 1f, 0.5f, 2f, didRender = true, steps = 2)
            t += 20 * ms
            frames++
        }
        assertEquals(6, frames)
        assertTrue(line, line!!.startsWith("perf n=5 fps=50.0 frame p50=20.0"))
        assertTrue(line, line.contains("sim p50=1.0 p95=1.0 (physics p50=0.5"))
        assertTrue(line, line.contains("submit p50=2.0"))
        assertTrue(line, line.contains("skipped=0/6"))
        assertNull(p.frame(t, 1f, 0.5f, 2f, didRender = true, steps = 0))
    }

    @Test
    fun `skipped callbacks lengthen the interval and are counted`() {
        val p = FramePerf(windowNanos = 100 * ms)
        var t = 1_000 * ms
        var line: String? = null
        var i = 0
        while (line == null) {
            line = p.frame(t, 0f, 0f, 0f, didRender = i % 2 == 0, steps = 0)
            t += 10 * ms
            i++
        }
        assertTrue(line, line!!.contains("frame p50=20.0"))
        assertTrue(line, line.contains("skipped=5/11"))
    }

    @Test
    fun `gpu times count once each and wait for a pending frame`() {
        val p = FramePerf(windowNanos = 100 * ms)
        fun rec(vararg r: Long) = r
        // Newest first: frame 3 timed, 2 still pending, 1 timed.
        p.timings(rec(3, 9 * ms, 1 * ms, 0, 2, -2, 1 * ms, 0,
            1, 4 * ms, 1 * ms, 0), 3)
        // Frame 2 lands; 1 must not count twice, 3 counts now.
        p.timings(rec(3, 9 * ms, 1 * ms, 0, 2, 6 * ms, 1 * ms, 0,
            1, 4 * ms, 1 * ms, 0), 3)
        var t = 1_000 * ms
        var line: String? = null
        while (line == null) {
            line = p.frame(t, 0f, 0f, 0f, didRender = true, steps = 0)
            t += 20 * ms
        }
        assertTrue(line, line.contains("gpu p50=6.0 p95=9.0"))
        assertTrue(line, line.contains("backend p50=1.0"))
    }

    @Test
    fun `a window with nothing drawn says so`() {
        val p = FramePerf(windowNanos = 10 * ms)
        p.frame(1_000 * ms, 0f, 0f, 0f, didRender = false, steps = 0)
        assertEquals("perf n=0 skipped=2/2",
            p.frame(1_020 * ms, 0f, 0f, 0f, didRender = false, steps = 0))
    }
}
