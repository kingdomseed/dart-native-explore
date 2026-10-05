package com.jasonholtdigital.dart3d

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class BodyCarryTest {
    private fun motion(
        kind: BodyMotion.Kind = BodyMotion.Kind.DYNAMIC,
        awake: Boolean = true,
        linear: FloatArray = floatArrayOf(0f, 0f, 0f),
        angular: FloatArray = floatArrayOf(0f, 0f, 0f),
    ) = BodyMotion(
        kind,
        position = doubleArrayOf(1.0, 2.0, 3.0),
        rotation = floatArrayOf(0f, 0f, 0f, 1f),
        linearVelocity = linear,
        angularVelocity = angular,
        awake = awake,
    )

    private val die = 1L
    private val ball = 2L
    private val lift = 3L
    private val floor = 4L

    @Test
    fun aRollingDieKeepsItsPoseVelocitiesAndWakefulness() {
        val carry = BodyCarry()
        val rolling = motion(
            linear = floatArrayOf(3f, -4f, 0f),
            angular = floatArrayOf(0f, 9f, 0f))
        carry.capture(die, rolling)
        val applied = HashMap<Long, BodyMotion>()
        val restored = carry.restore({ BodyMotion.Kind.DYNAMIC }) { key, m ->
            applied[key] = m
        }
        assertSame(rolling, applied[die])
        assertEquals(1, restored.bodies)
        assertEquals(1, restored.awake)
        assertEquals(5f, restored.fastest, 1e-6f)
    }

    @Test
    fun theWholePoseCarriesWhateverSetTransformsWrote() {
        // `_pullInside` writes a die's translation only. The written-
        // transform restore then puts back that one field; the die's
        // rotation has to come from here.
        val tumbled = BodyMotion(
            BodyMotion.Kind.DYNAMIC,
            position = doubleArrayOf(4.0, 0.5, -2.0),
            rotation = floatArrayOf(0.5f, 0.5f, 0.5f, 0.5f),
            linearVelocity = floatArrayOf(0f, 0f, 0f),
            angularVelocity = floatArrayOf(0f, 0f, 0f),
            awake = false,
        )
        val carry = BodyCarry()
        carry.capture(die, tumbled)
        var applied: BodyMotion? = null
        carry.restore({ BodyMotion.Kind.DYNAMIC }) { _, m -> applied = m }
        assertEquals(listOf(4.0, 0.5, -2.0), applied!!.position.toList())
        assertEquals(listOf(0.5f, 0.5f, 0.5f, 0.5f), applied!!.rotation.toList())
    }

    @Test
    fun aSleepingBodyComesBackAsleep() {
        val carry = BodyCarry()
        carry.capture(die, motion(awake = false))
        carry.capture(ball, motion(awake = true))
        val awake = HashMap<Long, Boolean>()
        val restored = carry.restore({ BodyMotion.Kind.DYNAMIC }) { key, m ->
            awake[key] = m.awake
        }
        assertEquals(mapOf(die to false, ball to true), awake)
        assertEquals(2, restored.bodies)
        assertEquals(1, restored.awake)
    }

    @Test
    fun fixedBodiesAreNotCarried() {
        val carry = BodyCarry()
        carry.capture(floor, null)
        carry.capture(die, motion())
        assertEquals(1, carry.size)
    }

    @Test
    fun aBodyThatDidNotComeBackIsSkipped() {
        val carry = BodyCarry()
        carry.capture(die, motion())
        carry.capture(ball, motion())
        val applied = ArrayList<Long>()
        val restored = carry.restore(
            rebuiltKind = { if (it == die) BodyMotion.Kind.DYNAMIC else null },
        ) { key, _ -> applied.add(key) }
        assertEquals(listOf(die), applied)
        assertEquals(1, restored.bodies)
    }

    @Test
    fun aBodyRebuiltAsAnotherKindKeepsItsRebuiltState() {
        val carry = BodyCarry()
        carry.capture(lift, motion(kind = BodyMotion.Kind.KINEMATIC))
        carry.capture(die, motion(kind = BodyMotion.Kind.DYNAMIC))
        val applied = ArrayList<Long>()
        carry.restore(
            rebuiltKind = {
                // An op replaced the lift's rigidBody since the capture.
                BodyMotion.Kind.DYNAMIC
            },
        ) { key, _ -> applied.add(key) }
        assertEquals(listOf(die), applied)
    }

    @Test
    fun kinematicBodiesCarryToo() {
        val carry = BodyCarry()
        val moving = motion(
            kind = BodyMotion.Kind.KINEMATIC,
            linear = floatArrayOf(0f, 0.5f, 0f))
        carry.capture(lift, moving)
        var applied: BodyMotion? = null
        carry.restore({ BodyMotion.Kind.KINEMATIC }) { _, m -> applied = m }
        assertSame(moving, applied)
    }

    @Test
    fun restoresInCaptureOrderSoParentsLandBeforeChildren() {
        val carry = BodyCarry()
        for (key in listOf(7L, 3L, 9L)) carry.capture(key, motion())
        val order = ArrayList<Long>()
        carry.restore({ BodyMotion.Kind.DYNAMIC }) { key, _ -> order.add(key) }
        assertEquals(listOf(7L, 3L, 9L), order)
    }

    @Test
    fun nothingCapturedRestoresNothing() {
        val restored = BodyCarry().restore({ BodyMotion.Kind.DYNAMIC }) { _, _ ->
            throw AssertionError("nothing to apply")
        }
        assertEquals(0, restored.bodies)
        assertTrue(restored.fastest == 0f)
    }
}
