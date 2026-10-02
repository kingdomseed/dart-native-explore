package com.jasonholtdigital.dart3d

import java.util.Locale

/**
 * Frame-time sampler for the render loop. Per window it reports:
 *
 * - `frame`: the interval between rendered frames, from Choreographer
 *   vsync timestamps (so it quantizes to the display period);
 * - `gpu`: Filament's GPU time per frame (`FrameInfo.gpuFrameDuration`)
 *   — not quantized, and the number to compare settings by. It reads
 *   0.0 where Filament has no timings (Vulkan on the Fire tablet);
 * - `backend`: wall time Filament's driver thread spent on the frame;
 * - `sim`: main-thread mutation drain, animation, physics, sync,
 *   with the physics step broken out;
 * - `submit`: main-thread `beginFrame`…`endFrame`.
 *
 * Off unless the log tag is enabled:
 * `adb shell setprop log.tag.dart3d.perf DEBUG`.
 */
internal class FramePerf(private val windowNanos: Long = 2_000_000_000L) {
    private val interval = Series()
    private val sim = Series()
    private val physics = Series()
    private val submit = Series()
    private val gpu = Series()
    private val backend = Series()
    private var callbacks = 0
    private var skipped = 0
    private var physicsSteps = 0
    private var windowStart = 0L
    private var lastRendered = 0L
    private var lastTimedFrameId = -1L

    fun reset() {
        clearWindow()
        windowStart = 0L
        lastRendered = 0L
        lastTimedFrameId = -1L
    }

    /**
     * Takes Filament frame records (`[frameId, gpuNanos, backendNanos,
     * mainNanos]` × [count], any order). Each frame is counted once,
     * in id order, and only once its GPU time has landed: a pending
     * frame holds back the ones after it until a later call.
     */
    fun timings(records: LongArray, count: Int) {
        val order = (0 until count).sortedBy { records[it * 4] }
        for (i in order) {
            val id = records[i * 4]
            if (id <= lastTimedFrameId) continue
            val gpuNanos = records[i * 4 + 1]
            if (gpuNanos == PENDING) break
            lastTimedFrameId = id
            if (gpuNanos > 0) gpu.add(gpuNanos / 1e6f)
            val backendNanos = records[i * 4 + 2]
            if (backendNanos > 0) backend.add(backendNanos / 1e6f)
        }
    }

    /**
     * Records one Choreographer callback. [didRender] is false when
     * Filament's `beginFrame` asked to skip. Returns the window's
     * summary line when it closes, null otherwise.
     */
    fun frame(
        tNanos: Long, simMs: Float, physicsMs: Float, submitMs: Float,
        didRender: Boolean, steps: Int,
    ): String? {
        if (windowStart == 0L) windowStart = tNanos
        callbacks++
        physicsSteps += steps
        if (didRender) {
            if (lastRendered != 0L) {
                interval.add((tNanos - lastRendered) / 1e6f)
                sim.add(simMs)
                physics.add(physicsMs)
                submit.add(submitMs)
            }
            lastRendered = tNanos
        } else {
            skipped++
        }
        val elapsed = tNanos - windowStart
        if (elapsed < windowNanos) return null
        val line = summary(elapsed)
        clearWindow()
        windowStart = tNanos
        return line
    }

    private fun clearWindow() {
        for (s in arrayOf(interval, sim, physics, submit, gpu, backend)) s.n = 0
        callbacks = 0
        skipped = 0
        physicsSteps = 0
    }

    private fun summary(elapsedNanos: Long): String {
        if (interval.n == 0) {
            return "perf n=0 skipped=$skipped/$callbacks"
        }
        val seconds = elapsedNanos / 1e9
        return String.format(Locale.US,
            "perf n=%d fps=%.1f frame p50=%.1f p95=%.1f max=%.1f ms" +
                " | gpu p50=%.1f p95=%.1f | backend p50=%.1f p95=%.1f" +
                " | sim p50=%.1f p95=%.1f (physics p50=%.1f p95=%.1f)" +
                " | submit p50=%.1f p95=%.1f" +
                " | skipped=%d/%d physics=%.0f/s",
            interval.n, interval.n / seconds,
            interval.at(0.50), interval.at(0.95), interval.at(1.0),
            gpu.at(0.50), gpu.at(0.95),
            backend.at(0.50), backend.at(0.95),
            sim.at(0.50), sim.at(0.95),
            physics.at(0.50), physics.at(0.95),
            submit.at(0.50), submit.at(0.95),
            skipped, callbacks, physicsSteps / seconds)
    }

    private class Series {
        val values = FloatArray(CAPACITY)
        var n = 0
        fun add(v: Float) {
            if (n < CAPACITY) values[n++] = v
        }
        fun at(p: Double) = percentile(values, n, p)
    }

    companion object {
        const val TAG = "dart3d.perf"
        /** Records asked of Filament per frame; a frame's GPU time
         *  lands a few frames after it was submitted. */
        const val HISTORY = 16
        private const val PENDING = -2L
        private const val CAPACITY = 512

        /** Nearest-rank percentile of the first [n] values. */
        fun percentile(values: FloatArray, n: Int, p: Double): Float {
            if (n <= 0) return 0f
            val sorted = values.copyOf(n)
            sorted.sort()
            val rank = Math.ceil(p * n).toInt().coerceIn(1, n)
            return sorted[rank - 1]
        }
    }
}
