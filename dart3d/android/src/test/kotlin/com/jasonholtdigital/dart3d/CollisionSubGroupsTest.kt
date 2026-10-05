package com.jasonholtdigital.dart3d

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CollisionSubGroupsTest {
    /** Stands in for Jolt's GroupFilterTable: collide unless disabled. */
    private class Table {
        private val disabled = HashSet<Pair<Int, Int>>()
        val set: (Int, Int, Boolean) -> Unit = { a, b, collides ->
            val pair = minOf(a, b) to maxOf(a, b)
            if (collides) disabled.remove(pair) else disabled.add(pair)
        }
        fun collides(a: Int, b: Int) = (minOf(a, b) to maxOf(a, b)) !in disabled
    }

    private val all = -1

    @Test
    fun appliesTheLayerMaskRuleBothWays() {
        val table = Table()
        val groups = CollisionSubGroups(8)
        val dice = groups.acquire(layer = 0b01, mask = 0b11, table.set)
        val wall = groups.acquire(layer = 0b10, mask = 0b01, table.set)
        val ghost = groups.acquire(layer = 0b100, mask = 0b01, table.set)
        assertTrue(table.collides(dice, wall))
        assertFalse("dice's mask has no ghost layer", table.collides(dice, ghost))
        assertFalse("neither mask names the other", table.collides(wall, ghost))
        assertTrue(groups.excludes(dice, ghost))
        assertFalse(groups.excludes(dice, wall))
    }

    @Test
    fun aReleasedIdIsHandedOutAgain() {
        val table = Table()
        val groups = CollisionSubGroups(4)
        val a = groups.acquire(all, all, table.set)
        val b = groups.acquire(all, all, table.set)
        groups.release(a)
        assertEquals(1, groups.liveCount)
        assertEquals(a, groups.acquire(all, all, table.set))
        assertEquals(2, groups.liveCount)
        assertTrue(table.collides(a, b))
    }

    @Test
    fun aReusedIdDoesNotInheritItsPreviousRow() {
        val table = Table()
        val groups = CollisionSubGroups(4)
        val floor = groups.acquire(layer = 0b01, mask = 0b01, table.set)
        val ghost = groups.acquire(layer = 0b10, mask = 0b10, table.set)
        assertFalse(table.collides(floor, ghost))
        groups.release(ghost)
        val die = groups.acquire(layer = 0b01, mask = 0b01, table.set)
        assertEquals(ghost, die)
        assertTrue("the ghost's disabled pair must not stick to the die",
            table.collides(floor, die))
    }

    @Test
    fun aRowAgainstAFreeIdIsRewrittenWhenThatIdReturns() {
        val table = Table()
        val groups = CollisionSubGroups(4)
        val a = groups.acquire(layer = 0b01, mask = 0b01, table.set)
        val b = groups.acquire(layer = 0b10, mask = 0b10, table.set)
        assertFalse(table.collides(a, b))
        groups.release(a)
        groups.release(b)
        val a2 = groups.acquire(all, all, table.set)
        val b2 = groups.acquire(all, all, table.set)
        assertEquals(listOf(a, b), listOf(a2, b2))
        assertTrue(table.collides(a2, b2))
    }

    @Test
    fun rebuildingEveryBodyManyTimesNeverRunsOut() {
        val table = Table()
        val groups = CollisionSubGroups(32)
        var live = List(13) { groups.acquire(all, all, table.set) }
        // A re-realize creates the new bodies before the old ones go.
        repeat(500) {
            val next = List(13) { groups.acquire(all, all, table.set) }
            assertTrue(next.all { it >= 0 })
            live.forEach(groups::release)
            live = next
        }
        assertEquals(13, groups.liveCount)
    }

    @Test
    fun reportsFullInsteadOfOverrunningTheTable() {
        val table = Table()
        val groups = CollisionSubGroups(2)
        assertEquals(0, groups.acquire(all, all, table.set))
        assertEquals(1, groups.acquire(all, all, table.set))
        assertEquals(-1, groups.acquire(all, all, table.set))
        groups.release(-1)
        assertEquals(2, groups.liveCount)
    }
}
