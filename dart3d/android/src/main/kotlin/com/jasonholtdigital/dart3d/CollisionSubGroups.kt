package com.jasonholtdigital.dart3d

/**
 * Hands out the sub-group ids of a world's shared collision-group
 * table, one per body, and takes them back when the body goes.
 *
 * A pair of sub-groups collides unless the upstream interaction rule
 * excludes it: `(a.layer & b.mask) != 0 && (b.layer & a.mask) != 0`.
 * An id that is handed out again has its row rewritten against every
 * live id, so nothing a previous holder disabled carries over. Rows
 * against free ids are left stale; they are rewritten when that id is
 * next handed out.
 */
internal class CollisionSubGroups(private val capacity: Int) {
    private val layerMask = ArrayList<Long>()
    private val live = java.util.BitSet()

    val liveCount: Int get() = live.cardinality()

    /**
     * An id for a body with collider [layer]/[mask], or -1 when all
     * [capacity] ids are held. [setPair] is called once per live id
     * with whether the new pair collides.
     */
    fun acquire(
        layer: Int, mask: Int,
        setPair: (id: Int, other: Int, collides: Boolean) -> Unit,
    ): Int {
        val id = live.nextClearBit(0)
        if (id >= capacity) return -1
        val packed = (layer.toLong() shl 32) or (mask.toLong() and 0xFFFFFFFFL)
        if (id == layerMask.size) layerMask.add(packed) else layerMask[id] = packed
        var other = live.nextSetBit(0)
        while (other >= 0) {
            setPair(id, other, !excludes(id, other))
            other = live.nextSetBit(other + 1)
        }
        live.set(id)
        return id
    }

    fun release(id: Int) {
        if (id >= 0) live.clear(id)
    }

    /** True when the layer/mask rule keeps [a] and [b] from colliding. */
    fun excludes(a: Int, b: Int): Boolean {
        val pa = layerMask[a]
        val pb = layerMask[b]
        return ((pa ushr 32).toInt() and pb.toInt()) == 0 ||
            ((pb ushr 32).toInt() and pa.toInt()) == 0
    }
}
