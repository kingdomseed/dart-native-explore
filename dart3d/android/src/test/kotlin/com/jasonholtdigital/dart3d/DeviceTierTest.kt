package com.jasonholtdigital.dart3d

import com.jasonholtdigital.dart3d.DeviceProfile.ScaleRange
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** [DeviceTier.classify] — which devices are low-end. */
class DeviceTierTest {

    private fun tier(memoryKb: Long, gpu: String?, lowRam: Boolean = false) =
        DeviceTier.classify(memoryKb * 1024, lowRam, gpu)

    @Test
    fun `the Fire tablet is low, by memory and by GPU`() {
        assertEquals(DeviceTier.LOW, tier(2_871_216L, "Mali-G52 MC2"))
        assertEquals(DeviceTier.LOW, tier(2_871_216L, null))
        assertEquals(DeviceTier.LOW, tier(8_000_000L, "Mali-G52 MC2"))
    }

    @Test
    fun `the Wacom tablet's 8 GB doesn't hide its Mali-G57`() {
        assertEquals(DeviceTier.LOW, tier(8_070_660L, "Mali-G57 MC2"))
    }

    @Test
    fun `the A142's Mali-G610 is standard`() {
        assertEquals(DeviceTier.STANDARD, tier(7_590_488L, "Mali-G610 MC4"))
    }

    @Test
    fun `a three-digit Mali-G model is not its two-digit prefix`() {
        for (gpu in listOf("Mali-G510 MC4", "Mali-G310")) {
            assertEquals(gpu, DeviceTier.STANDARD, tier(8_000_000L, gpu))
        }
    }

    @Test
    fun `faster neighbours of the listed families are standard`() {
        for (gpu in listOf(
            "Mali-G615 MC6", "Mali-G710 MC10", "Mali-G720 MC8",
            "Adreno (TM) 620", "Adreno (TM) 630", "Adreno (TM) 640",
        )) {
            assertEquals(gpu, DeviceTier.STANDARD, tier(8_000_000L, gpu))
        }
    }

    @Test
    fun `an ANGLE-wrapped renderer string is read by the GPU inside it`() {
        assertEquals(
            DeviceTier.LOW,
            tier(8_000_000L,
                "ANGLE (ARM, Vulkan 1.3.0 (Mali-G57 MC2 (0x90910010)), Mali-G57 MC2)"))
        assertEquals(
            DeviceTier.STANDARD,
            tier(8_000_000L,
                "ANGLE (ARM, Vulkan 1.3.0 (Mali-G610 MC4 (0xA8670000)), Mali-G610 MC4)"))
    }

    @Test
    fun `the listed families are low whatever the memory`() {
        for (gpu in listOf(
            "Mali-G31", "Mali-G51 MP4", "Mali-T860", "Mali-450 MP",
            "Adreno (TM) 308", "Adreno (TM) 506", "Adreno (TM) 512",
            "Adreno (TM) 610", "PowerVR Rogue GE8320",
        )) {
            assertEquals(gpu, DeviceTier.LOW, tier(8_000_000L, gpu))
        }
    }

    @Test
    fun `an unlisted or unknown GPU is decided by memory`() {
        for (gpu in listOf(
            "Mali-G78", "Mali-G715-Immortalis MC11", "Adreno (TM) 540",
            "Adreno (TM) 650", "Adreno (TM) 740", "Samsung Xclipse 920",
            "Android Emulator OpenGL ES Translator (Apple M2)", "", null,
        )) {
            assertEquals(gpu, DeviceTier.STANDARD, tier(8_000_000L, gpu))
            assertEquals(gpu, DeviceTier.LOW, tier(2_871_216L, gpu))
        }
    }

    @Test
    fun `a 4 GB device and up is standard`() {
        assertEquals(DeviceTier.STANDARD,
            DeviceTier.classify(3_700_000_000L, false, null))
        assertEquals(DeviceTier.STANDARD,
            DeviceTier.classify(11_600_000_000L, false, null))
    }

    @Test
    fun `the boundary itself is standard, one byte under is low`() {
        assertEquals(3_200_000_000L, DeviceTier.LOW_MEMORY_BYTES)
        assertEquals(DeviceTier.STANDARD,
            DeviceTier.classify(3_200_000_000L, false, null))
        assertEquals(DeviceTier.LOW,
            DeviceTier.classify(3_199_999_999L, false, null))
    }

    @Test
    fun `the system's low-RAM flag wins`() {
        assertEquals(DeviceTier.LOW,
            tier(8_000_000L, "Mali-G610 MC4", lowRam = true))
    }

    @Test
    fun `an unreadable memory size doesn't demote the device`() {
        assertEquals(DeviceTier.STANDARD,
            DeviceTier.classify(0L, false, "Mali-G610 MC4"))
        assertEquals(DeviceTier.LOW,
            DeviceTier.classify(0L, false, "Mali-G57 MC2"))
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
