package com.jasonholtdigital.dart3d

/**
 * What a moving body is doing, read off the simulation: world pose,
 * velocities, and whether it is awake. `rotation` is (x, y, z, w).
 */
internal class BodyMotion(
    val kind: Kind,
    val position: DoubleArray,
    val rotation: FloatArray,
    val linearVelocity: FloatArray,
    val angularVelocity: FloatArray,
    val awake: Boolean,
) {
    enum class Kind { KINEMATIC, DYNAMIC }

    val speed: Float
        get() = kotlin.math.sqrt(
            linearVelocity[0] * linearVelocity[0] +
                linearVelocity[1] * linearVelocity[1] +
                linearVelocity[2] * linearVelocity[2])
}

/**
 * Carries the simulation state of every moving body across a
 * payload-arrival re-realize. The rebuild creates each body again from
 * its manifest pose, at rest and awake; the simulation has moved on
 * since the manifest was written, so what a body was doing is live
 * state the manifest never saw. The view captures it before the
 * rebuild and puts it on the rebuilt bodies afterwards.
 *
 * Fixed bodies are not carried: they have no motion, and their pose is
 * the node's, which the manifest and the written-transform restore
 * already settle. A body whose node came back as another kind (or not
 * at all) is left as the rebuild made it.
 */
internal class BodyCarry {
    private val motions = LinkedHashMap<Long, BodyMotion>()

    val size: Int get() = motions.size

    /** [motion] is null for a fixed body. */
    fun capture(nodeKey: Long, motion: BodyMotion?) {
        if (motion != null) motions[nodeKey] = motion
    }

    /**
     * Calls [apply] for each carried body whose node has a body of the
     * same kind again ([rebuiltKind]; null for none or fixed). Returns
     * what was restored.
     */
    fun restore(
        rebuiltKind: (Long) -> BodyMotion.Kind?,
        apply: (Long, BodyMotion) -> Unit,
    ): Restored {
        val keys = ArrayList<Long>()
        var awake = 0
        var fastest = 0f
        for ((key, motion) in motions) {
            if (rebuiltKind(key) != motion.kind) continue
            apply(key, motion)
            keys.add(key)
            if (motion.awake) awake++
            fastest = maxOf(fastest, motion.speed)
        }
        return Restored(keys, awake, fastest)
    }

    class Restored(val keys: List<Long>, val awake: Int, val fastest: Float) {
        val bodies: Int get() = keys.size
    }

    companion object {
        /**
         * [keys] ordered so that every node comes after its ancestors
         * ([parentOf]; null at a root). A node's local transform is
         * derived from its parent's world transform, so a parent has to
         * be in place before its child is synced, and the bodies come
         * out of a hash map in no such order.
         */
        fun parentsFirst(
            keys: Collection<Long>, parentOf: (Long) -> Long?,
        ): List<Long> {
            fun depth(key: Long): Int {
                var d = 0
                var p = parentOf(key)
                // The bound only guards against a malformed parent loop.
                while (p != null && d < MAX_DEPTH) {
                    d++
                    p = parentOf(p)
                }
                return d
            }
            return keys.sortedBy(::depth)
        }

        private const val MAX_DEPTH = 4096
    }
}
