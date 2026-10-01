package com.jasonholtdigital.dart3d

/**
 * Which TRS fields `setTransforms` has written per node since the last
 * `loadScene`. A payload-arrival re-realize rebuilds every node at its
 * manifest pose; these fields are live state the manifest never saw, so
 * the view captures them before the rebuild and restores them after it.
 *
 * Only written fields carry, and never on a node a clip drives: its
 * current pose is a mid-clip sample, and the sampler re-captures the
 * rebuilt node's pose as the bind pose.
 */
internal class TransformWrites {

    class Pose(
        val id: Long,
        val mask: Int,
        val pos: FloatArray,
        val quat: FloatArray,
        val scale: FloatArray,
    )

    private val masks = LinkedHashMap<Long, Int>()

    val isEmpty: Boolean get() = masks.isEmpty()

    /** [mask]: bit 0 translation, bit 1 rotation, bit 2 scale. */
    fun record(id: Long, mask: Int) {
        val fields = mask and FIELDS
        if (fields == 0) return
        masks[id] = (masks[id] ?: 0) or fields
    }

    /** A structural op rewrote or removed the node: it replays instead. */
    fun supersede(id: Long) {
        masks.remove(id)
    }

    fun supersedeAll(ids: Collection<Long>) {
        masks.keys.removeAll(ids)
    }

    fun clear() = masks.clear()

    /**
     * The written nodes' current local TRS, read through [current]
     * (null for a node that is gone). Current rather than as-written: a
     * dynamic body has moved since its write. Nodes [clipDriven] names
     * are left to the manifest pose.
     */
    fun capture(
        clipDriven: (Long) -> Boolean = { false },
        current: (Long) -> Array<FloatArray>?,
    ): List<Pose> {
        val out = ArrayList<Pose>(masks.size)
        for ((id, mask) in masks) {
            if (clipDriven(id)) continue
            val trs = current(id) ?: continue
            out.add(Pose(id, mask, trs[0].copyOf(), trs[1].copyOf(),
                trs[2].copyOf()))
        }
        return out
    }

    companion object {
        const val TRANSLATION = 1
        const val ROTATION = 2
        const val SCALE = 4
        private const val FIELDS = TRANSLATION or ROTATION or SCALE
    }
}
