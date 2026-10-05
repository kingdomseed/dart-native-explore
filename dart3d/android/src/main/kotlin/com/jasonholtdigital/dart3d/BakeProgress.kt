package com.jasonholtdigital.dart3d

/**
 * What a bake run tells `tool/bake_materials.sh` through the log: that
 * the fixed set is complete, and when the variant lane has nothing in
 * flight. The script pulls the exported packages, so a line that says
 * "done" early or wrongly ships an app without them.
 */
internal class BakeProgress(private val log: (String) -> Unit) {
    private var inFlight = 0

    // The count changes and its line is written under one lock. The
    // script trusts the last busy-or-idle line, so an "idle" must never
    // be written after the "compiling" of a compile that is still
    // running.

    /** A variant compile was queued. */
    @Synchronized
    fun started() {
        inFlight++
        log(busyLine(inFlight))
    }

    /** A variant compile ended. */
    @Synchronized
    fun finished() {
        inFlight--
        if (inFlight == 0) log(IDLE_LINE)
    }

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
