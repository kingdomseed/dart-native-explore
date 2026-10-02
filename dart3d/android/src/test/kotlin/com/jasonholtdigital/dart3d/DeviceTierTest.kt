package com.jasonholtdigital.dart3d

import org.junit.Assert.assertEquals
import org.junit.Test

/** [DeviceTier.classify] — which devices take the low profile. */
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
