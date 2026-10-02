package com.jasonholtdigital.dart3d

import com.jasonholtdigital.dart3d.DeviceProfile.ScaleRange
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** [DeviceTier.classify] — which devices are low-end. */
class DeviceTierTest {

    @Test
    fun `the Fire tablet's 2_9 GB is low`() {
        assertEquals(DeviceTier.LOW,
            DeviceTier.classify(2_871_216L * 1024, lowRamDevice = false))
    }

    @Test
    fun `a 4 GB device and up is standard`() {
        assertEquals(DeviceTier.STANDARD,
            DeviceTier.classify(3_700_000_000L, lowRamDevice = false))
        assertEquals(DeviceTier.STANDARD,
            DeviceTier.classify(11_600_000_000L, lowRamDevice = false))
    }

    @Test
    fun `the boundary itself is standard, one byte under is low`() {
        assertEquals(3_200_000_000L, DeviceTier.LOW_MEMORY_BYTES)
        assertEquals(DeviceTier.STANDARD,
            DeviceTier.classify(3_200_000_000L, lowRamDevice = false))
        assertEquals(DeviceTier.LOW,
            DeviceTier.classify(3_199_999_999L, lowRamDevice = false))
    }

    @Test
    fun `the system's low-RAM flag wins`() {
        assertEquals(DeviceTier.LOW,
            DeviceTier.classify(8_000_000_000L, lowRamDevice = true))
    }

    @Test
    fun `an unreadable memory size doesn't demote the device`() {
        assertEquals(DeviceTier.STANDARD,
            DeviceTier.classify(0L, lowRamDevice = false))
    }
}

/** [DeviceProfile] — what a low-end device changes, and when. */
class DeviceProfileTest {

    private val dynamic = ScaleRange(0.5f, 1f)

    @Test
    fun `the profile is on only for a low device with no quality tier`() {
        assertTrue(DeviceProfile.isLow(DeviceTier.LOW, null))
        assertFalse(DeviceProfile.isLow(DeviceTier.STANDARD, null))
        for (q in listOf("low", "medium", "high")) {
            assertFalse(q, DeviceProfile.isLow(DeviceTier.LOW, q))
        }
    }

    @Test
    fun `nothing authored - dynamic on the low profile, off otherwise`() {
        assertEquals(dynamic, DeviceProfile.renderScale(null, null, low = true))
        assertNull(DeviceProfile.renderScale(null, null, low = false))
    }

    @Test
    fun `an authored 1_0 stays fixed at full resolution`() {
        assertNull(DeviceProfile.renderScale(1.0, null, low = true))
        assertNull(DeviceProfile.renderScale(null, 1.0, low = true))
        assertNull(DeviceProfile.renderScale(1.0, 0.5, low = true))
    }

    @Test
    fun `an authored scale is fixed on either tier, the entry's first`() {
        val fixed = ScaleRange(0.75f, 0.75f)
        assertEquals(fixed, DeviceProfile.renderScale(0.75, null, low = true))
        assertEquals(fixed, DeviceProfile.renderScale(0.75, null, low = false))
        assertEquals(fixed, DeviceProfile.renderScale(null, 0.75, low = true))
        assertEquals(fixed, DeviceProfile.renderScale(0.75, 0.5, low = false))
    }

    @Test
    fun `an invalid authored scale means full resolution, not dynamic`() {
        assertNull(DeviceProfile.renderScale(0.0, null, low = true))
        assertNull(DeviceProfile.renderScale(null, -1.0, low = true))
    }

    @Test
    fun `the low profile turns requested MSAA into FXAA alone`() {
        assertNull(DeviceProfile.aaSource(null, 4, low = true))
        assertNull(DeviceProfile.aaSource(null, 2, low = true))
    }

    @Test
    fun `the low profile keeps an explicit no-AA and an unsent mode`() {
        assertEquals(0, DeviceProfile.aaSource(null, 0, low = true))
        assertNull(DeviceProfile.aaSource(null, null, low = true))
    }

    @Test
    fun `off the low profile the widget's mode passes through`() {
        assertEquals(4, DeviceProfile.aaSource(null, 4, low = false))
        assertEquals(0, DeviceProfile.aaSource(null, 0, low = false))
        assertNull(DeviceProfile.aaSource(null, null, low = false))
    }

    @Test
    fun `a quality tier owns AA whatever the widget asked for`() {
        assertEquals(0, DeviceProfile.aaSource("low", 4, low = false))
        assertEquals(1, DeviceProfile.aaSource("medium", 0, low = false))
        assertEquals(4, DeviceProfile.aaSource("high", null, low = false))
    }
}
