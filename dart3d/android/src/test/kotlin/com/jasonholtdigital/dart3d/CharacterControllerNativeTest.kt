package com.jasonholtdigital.dart3d

import com.github.stephengold.joltjni.Body
import com.github.stephengold.joltjni.BodyCreationSettings
import com.github.stephengold.joltjni.BoxShape
import com.github.stephengold.joltjni.Quat
import com.github.stephengold.joltjni.RVec3
import com.github.stephengold.joltjni.Vec3
import com.github.stephengold.joltjni.enumerate.EMotionType
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test

/** Requires the matching host Jolt JNI library on java.library.path. */
class CharacterControllerNativeTest {
    private lateinit var world: JoltWorld
    private val rotation = floatArrayOf(0f, 0f, 0f, 1f)

    @Before
    fun createWorld() {
        assumeTrue(java.lang.Boolean.getBoolean("dart3d.nativeTests"))
        world = JoltWorld()
        world.setGravity(0f, 0f, 0f)
    }

    @After
    fun closeWorld() {
        if (::world.isInitialized) world.close()
    }

    private fun spec(mask: Int = -1, slide: Boolean = true, autostep: Boolean = false,
        mass: Float = 0f, minimumWidth: Float = 0.1f) =
        CharacterSpec(
            up = floatArrayOf(0f, 1f, 0f), offset = 0.02f, slide = slide,
            maxSlopeClimbAngle = 0.7f, minSlopeSlideAngle = 0.9f,
            snapToGround = null, autostep = autostep,
            autostepMaxHeight = 0.3f, autostepMinWidth = minimumWidth,
            autostepIncludeDynamicBodies = false, mass = mass,
            layer = 1, mask = mask)

    private fun character(key: Long, x: Float, spec: CharacterSpec, zHalf: Float = 0.25f) {
        BoxShape(Vec3(0.25f, 0.5f, zHalf)).use {
            world.addCharacter(key, it, floatArrayOf(x, 0.5f, 0f), rotation, spec)
        }
    }

    private fun platform(key: Long, x: Double, y: Double, halfX: Float, halfY: Float,
        motion: EMotionType = EMotionType.Static): Body =
        BoxShape(Vec3(halfX, halfY, 5f)).use { shape ->
            BodyCreationSettings(shape, RVec3(x, y, 0.0), Quat.sIdentity(), motion,
                if (motion == EMotionType.Static) JoltWorld.OBJ_NON_MOVING
                else JoltWorld.OBJ_MOVING).use { settings ->
                world.addBody(settings, motion != EMotionType.Static, key, 1, -1)
            }
        }

    private fun settle(): FloatArray = world.moveCharacter(1, floatArrayOf(0f, 0.5f, 0f),
        rotation, floatArrayOf(0f, -0.05f, 0f), 1f / 60f)!!.position

    @Test
    fun stairCorrectionUsesOnlyRemainingRequestedDistance() {
        platform(2, 0.0, -0.5, 5f, 0.5f)
        platform(3, 1.165, 0.1, 0.835f, 0.1f)
        character(1, 0f, spec(autostep = true))
        val start = settle()
        val result = world.moveCharacter(1, start, rotation,
            floatArrayOf(0.1f, -0.01f, 0f), 1f / 60f)!!
        assertTrue("fixture did not climb the curb ${result.position.toList()}", result.position[1] > 0.65f)
        assertTrue("stair correction exceeded the request ${result.translation.toList()}", result.translation[0] <= 0.1001f)
    }

    @Test
    fun dynamicSupportingFloorDoesNotDisableStaticCurbStep() {
        platform(2, 0.0, -0.5, 5f, 0.5f, EMotionType.Dynamic)
        platform(3, 1.165, 0.1, 0.835f, 0.1f)
        character(1, 0f, spec(autostep = true))
        val start = settle()
        val result = world.moveCharacter(1, start, rotation,
            floatArrayOf(0.1f, -0.01f, 0f), 1f / 60f)!!
        assertTrue("supporting floor suppressed static-curb step ${result.position.toList()}", result.position[1] > 0.65f)
    }

    @Test
    fun flatStairLandingRequiresMinimumForwardClearance() {
        platform(2, 0.0, -0.5, 5f, 0.5f)
        platform(3, 1.165, 0.1, 0.835f, 0.1f)
        platform(4, 0.67, 1.0, 0.25f, 1f)
        character(1, 0f, spec(autostep = true))
        val start = settle()
        val result = world.moveCharacter(1, start, rotation,
            floatArrayOf(0.1f, -0.01f, 0f), 1f / 60f)!!
        assertTrue("climbed with less than 0.1m of clearance ${result.position.toList()}", result.position[1] < 0.6f)
    }

    @Test
    fun sameLandingAcceptsSmallerMinimumWidth() {
        platform(2, 0.0, -0.5, 5f, 0.5f)
        platform(3, 1.165, 0.1, 0.835f, 0.1f)
        platform(4, 0.67, 1.0, 0.25f, 1f)
        character(1, 0f, spec(autostep = true, minimumWidth = 0.02f))
        val start = settle()
        val result = world.moveCharacter(1, start, rotation,
            floatArrayOf(0.1f, -0.01f, 0f), 1f / 60f)!!
        assertTrue("smaller width rejected a usable landing ${result.position.toList()}", result.position[1] > 0.65f)
        assertTrue("clearance probe moved the character ${result.translation.toList()}", result.translation[0] <= 0.1001f)
    }

    @Test
    fun clippedStepUpStillAcceptsWideLanding() {
        platform(2, 0.0, -0.5, 5f, 0.5f)
        platform(3, 1.165, 0.1, 0.835f, 0.1f)
        platform(4, 0.0, 1.35, 5f, 0.1f)
        character(1, 0f, spec(autostep = true))
        val start = settle()
        val result = world.moveCharacter(1, start, rotation,
            floatArrayOf(0.1f, -0.01f, 0f), 1f / 60f)!!
        assertTrue("clipped upward sweep rejected a wide landing ${result.position.toList()}", result.position[1] > 0.65f)
        assertTrue("clearance probe moved the character ${result.translation.toList()}", result.translation[0] <= 0.1001f)
    }

    @Test
    fun clippedStepUpStillRejectsNarrowLanding() {
        platform(2, 0.0, -0.5, 5f, 0.5f)
        platform(3, 1.165, 0.1, 0.835f, 0.1f)
        platform(4, 0.0, 1.35, 5f, 0.1f)
        platform(5, 0.67, 1.0, 0.25f, 1f)
        character(1, 0f, spec(autostep = true))
        val start = settle()
        val result = world.moveCharacter(1, start, rotation,
            floatArrayOf(0.1f, -0.01f, 0f), 1f / 60f)!!
        assertTrue("climbed a narrow landing below a ceiling ${result.position.toList()}", result.position[1] < 0.6f)
    }

    @Test
    fun rejectedWidthPreservesOrdinaryMovementAndGroundImpulse() {
        fun move(autostep: Boolean): Pair<FloatArray, Float> {
            world.close()
            world = JoltWorld()
            val floor = platform(2, 0.0, -0.5, 5f, 0.5f, EMotionType.Dynamic)
            platform(3, 1.165, 0.1, 0.835f, 0.1f)
            platform(4, 0.67, 1.0, 0.25f, 1f)
            character(1, 0f, spec(autostep = autostep, mass = 80f))
            val start = settle()
            val result = world.moveCharacter(1, start, rotation,
                floatArrayOf(0.1f, -0.01f, 0f), 1f / 60f)!!
            return result.position to world.bodyInterface.getLinearVelocity(floor.id).y
        }
        val withoutStairs = move(false)
        val withRejectedStair = move(true)
        assertTrue("fixture made no ordinary progress", withoutStairs.first[0] > 0.04f)
        for (axis in 0..2) {
            assertEquals(withoutStairs.first[axis], withRejectedStair.first[axis], 1e-5f)
        }
        assertTrue("fixture applied no ground weight", withoutStairs.second < 0f)
        assertEquals(withoutStairs.second, withRejectedStair.second, 1e-7f)
    }

    @Test
    fun matchingCharacterMasksStillBlockMovement() {
        character(1, 0f, spec())
        character(2, 1f, spec())
        val result = world.moveCharacter(1, floatArrayOf(0f, 0.5f, 0f), rotation,
            floatArrayOf(2f, 0f, 0f), 1f / 60f)!!
        assertTrue("matching masks failed to block ${result.position.toList()}", result.position[0] < 0.6f)
    }

    @Test
    fun actualDynamicBlockerStillDisablesAutostep() {
        platform(2, 0.0, -0.5, 5f, 0.5f)
        platform(3, 1.165, 0.1, 0.835f, 0.1f, EMotionType.Dynamic)
        character(1, 0f, spec(autostep = true))
        val start = settle()
        val result = world.moveCharacter(1, start, rotation,
            floatArrayOf(0.1f, -0.01f, 0f), 1f / 60f)!!
        assertTrue("stepped onto excluded dynamic body ${result.position.toList()}", result.position[1] < 0.6f)
    }

    @Test
    fun stairAttemptDoesNotRepeatTheGroundWeightImpulse() {
        fun floorVelocity(autostep: Boolean): Float {
            world.close()
            world = JoltWorld()
            val floor = platform(2, 0.0, -0.5, 5f, 0.5f, EMotionType.Dynamic)
            platform(3, 1.165, 0.1, 0.835f, 0.1f)
            character(1, 0f, spec(autostep = autostep, mass = 80f))
            val start = settle()
            world.moveCharacter(1, start, rotation,
                floatArrayOf(0.1f, -0.01f, 0f), 1f / 60f)
            return world.bodyInterface.getLinearVelocity(floor.id).y
        }
        val withoutStairs = floorVelocity(false)
        val withStairs = floorVelocity(true)
        assertTrue("fixture applied no ground weight", withoutStairs < 0f)
        assertEquals(withoutStairs, withStairs, 1e-7f)
    }

    @Test
    fun characterMasksApplyInBothDirections() {
        character(1, 0f, spec(mask = 0))
        character(2, 1f, spec())
        val first = world.moveCharacter(1, floatArrayOf(0f, 0.5f, 0f), rotation,
            floatArrayOf(2f, 0f, 0f), 1f / 60f)!!
        assertTrue("zero-mask mover was blocked at ${first.position.toList()}", first.position[0] > 1.9f)
        val second = world.moveCharacter(2, floatArrayOf(1f, 0.5f, 0f), rotation,
            floatArrayOf(2f, 0f, 0f), 1f / 60f)!!
        assertTrue("zero-mask target blocked mover at ${second.position.toList()}", second.position[0] > 2.9f)
    }

    @Test
    fun characterContactHonorsSlideFalse() {
        character(1, 0f, spec(slide = false))
        character(2, 1f, spec(), zHalf = 5f)
        val result = world.moveCharacter(1, floatArrayOf(0f, 0.5f, 0f), rotation,
            floatArrayOf(2f, 0f, 1f), 1f / 60f)!!
        assertTrue("character slid along another character ${result.position.toList()}", result.position[2] < 0.6f)
    }

    @Test
    fun zeroMaskInnerBodyDoesNotBlockDynamicBodies() {
        character(1, 0f, spec(mask = 0))
        BoxShape(Vec3(0.1f, 0.1f, 0.1f)).use { shape ->
            BodyCreationSettings(shape, RVec3(-2.0, 0.5, 0.0), Quat.sIdentity(),
                EMotionType.Dynamic, JoltWorld.OBJ_MOVING).use { settings ->
                settings.setLinearVelocity(4f, 0f, 0f)
                settings.setLinearDamping(0f)
                val body = world.addBody(settings, true, 2, 1, -1)
                repeat(60) { assertTrue(world.update(1f / 60f, 1)) }
                val x = world.bodyInterface.getPosition(body.id).xx()
                assertTrue("dynamic body hit the zero-mask inner body at $x", x > 1.9)
            }
        }
    }

    @Test
    fun syncingColliderOnlyPoseMovesItsQueryableInnerBody() {
        character(1, 0f, spec(), zHalf = 0.1f)
        val halfSqrt = kotlin.math.sqrt(0.5f)
        world.syncCharacterTransform(1, floatArrayOf(3f, 0.5f, 0f),
            floatArrayOf(0f, halfSqrt, 0f, halfSqrt))
        assertFalse(world.overlapBox(RVec3(0.0, 0.5, 0.0), Quat.sIdentity(),
            Vec3(0.1f, 0.1f, 0.1f)).contains(1L))
        assertTrue(world.overlapBox(RVec3(3.0, 0.5, 0.0), Quat.sIdentity(),
            Vec3(0.1f, 0.1f, 0.1f)).contains(1L))
        assertTrue(world.overlapBox(RVec3(3.0, 0.5, 0.22), Quat.sIdentity(),
            Vec3(0.02f, 0.02f, 0.02f)).contains(1L))
        assertFalse(world.overlapBox(RVec3(3.22, 0.5, 0.0), Quat.sIdentity(),
            Vec3(0.02f, 0.02f, 0.02f)).contains(1L))
    }

    @Test
    fun clearingCharactersReleasesNativeBodiesWhileSystemIsLive() {
        val bodyCount = world.physicsSystem.numBodies
        character(1, 0f, spec())
        character(2, 1f, spec())
        val result = world.moveCharacter(1, floatArrayOf(0f, 0.5f, 0f), rotation,
            floatArrayOf(2f, 0f, 0f), 1f / 60f)!!
        assertTrue("characters did not collide ${result.position.toList()}", result.position[0] < 0.6f)
        assertEquals(bodyCount + 2, world.physicsSystem.numBodies)

        world.clearCharacters()

        assertEquals("character bodies outlived clearCharacters",
            bodyCount, world.physicsSystem.numBodies)
        assertTrue("physics system stopped after character cleanup",
            world.update(1f / 60f, 1))
    }
}
