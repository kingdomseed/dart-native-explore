package com.jasonholtdigital.dart3d

import java.util.concurrent.atomic.AtomicInteger

/**
 * What a bake run tells `tool/bake_materials.sh` through the log: that
 * the fixed set is complete, and when the variant lane has nothing in
 * flight. The script pulls the exported packages, so a line that says
 * "done" early or wrongly ships an app without them.
 */
internal class BakeProgress {
    private val inFlight = AtomicInteger()

    /** A variant compile was queued. Returns how many are in flight. */
    fun started(): Int = inFlight.incrementAndGet()

    /** A variant compile ended. True when the lane is idle again. */
    fun finished(): Boolean = inFlight.decrementAndGet() == 0

    companion object {
        const val EXPORTED = "bake: fixed set exported"
        const val INCOMPLETE = "bake: fixed set INCOMPLETE"
        const val BUSY = "bake: variants compiling"
        const val IDLE_LINE = "bake: variants idle"

        /**
         * The fixed set's closing line. [EXPORTED] only when filamat
         * accepted every one of the [expected] recipes; otherwise
         * [INCOMPLETE] with the keys in [rejected].
         */
        fun fixedSetLine(expected: Int, rejected: List<String>): String =
            if (rejected.isEmpty()) "$EXPORTED ($expected packages)"
            else "$INCOMPLETE (${expected - rejected.size} of $expected" +
                " packages; filamat rejected: ${rejected.joinToString()})"

        fun busyLine(inFlight: Int): String = "$BUSY ($inFlight in flight)"
    }
}
