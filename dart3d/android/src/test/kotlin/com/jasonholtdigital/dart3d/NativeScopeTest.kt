package com.jasonholtdigital.dart3d

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class NativeScopeTest {
    private class Probe(
        private val name: String,
        private val log: MutableList<String>,
        private val failOnClose: Boolean = false,
    ) : AutoCloseable {
        override fun close() {
            log.add(name)
            if (failOnClose) throw IllegalStateException(name)
        }
    }

    @Test
    fun closesEverythingInReverseOrderOnReturn() {
        val log = ArrayList<String>()
        val result = nativeScope {
            own(Probe("settings", log))
            own(Probe("result", log))
            own(Probe("ref", log))
            42
        }
        assertEquals(42, result)
        assertEquals(listOf("ref", "result", "settings"), log)
    }

    @Test
    fun closesOnThrow() {
        val log = ArrayList<String>()
        try {
            nativeScope {
                own(Probe("a", log))
                own(Probe("b", log))
                throw IllegalArgumentException("decode failed")
            }
        } catch (e: IllegalArgumentException) {
            assertEquals("decode failed", e.message)
        }
        assertEquals(listOf("b", "a"), log)
    }

    @Test
    fun closesOnEarlyReturn() {
        val log = ArrayList<String>()
        fun lookup(): String? = nativeScope {
            own(Probe("shape", log))
            return null
        }
        assertEquals(null, lookup())
        assertEquals(listOf("shape"), log)
    }

    @Test
    fun oneFailingCloseDoesNotSkipTheRest() {
        val log = ArrayList<String>()
        try {
            nativeScope {
                own(Probe("a", log))
                own(Probe("b", log, failOnClose = true))
                own(Probe("c", log))
            }
            fail("the close failure should surface")
        } catch (e: IllegalStateException) {
            assertEquals("b", e.message)
        }
        assertEquals(listOf("c", "b", "a"), log)
    }

    @Test
    fun ownReturnsItsArgumentAndClosesOnlyOnce() {
        val log = ArrayList<String>()
        val scope = NativeScope()
        val probe = Probe("a", log)
        assertSame(probe, scope.own(probe))
        scope.close()
        scope.close()
        assertEquals(listOf("a"), log)
    }

    @Test
    fun ownIfCloseableTakesWrappersAndPassesEverythingElse() {
        val log = ArrayList<String>()
        nativeScope {
            val view: Any = "a view with no native memory of its own"
            assertSame(view, ownIfCloseable(view))
            assertEquals(null, ownIfCloseable<Any?>(null))
            val owner: Any = Probe("leaf", log)
            assertSame(owner, ownIfCloseable(owner))
            assertTrue(log.isEmpty())
        }
        assertEquals(listOf("leaf"), log)
    }
}
