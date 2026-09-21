package com.jasonholtdigital.dart3d

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * W25 fix-2 regression coverage for
 * [FsceneRealizer.Context.InstalledResources.pendingClaims] — the gate
 * `applyPayload` consults before arming the manifest re-realize.
 * Arming on a chunk no pending texture/geometry awaits is what let a
 * never-landing sibling ref revert the live stage's LUT ~50 ms after
 * `sendPayload` delivered it (A142 lane 1b). Pure JVM — no Filament.
 */
class PendingClaimsTest {

    @Test
    fun `a chunk awaited by a deferred texture arms the re-realize`() {
        val res = FsceneRealizer.Context.InstalledResources()
        res.texturePayloadIds[7] = 42          // texture 7 awaits chunk 42
        assertTrue(res.pendingClaims(42, setOf(7)))
    }

    @Test
    fun `a chunk awaited by a deferred geometry arms the re-realize`() {
        val res = FsceneRealizer.Context.InstalledResources()
        res.geometryPayloadIds[9] = mutableSetOf(42, 43)
        assertTrue(res.pendingClaims(43, setOf(9)))
        assertTrue(res.pendingClaims(42, setOf(9)))
    }

    @Test
    fun `an env or LUT claim served surgically never arms`() {
        // Regression shape: envKey stays pending (e.g. its equirect
        // still waits) while the LUT chunk lands — the surgical
        // decodeStage consumed the chunk; the gate must not re-arm.
        val res = FsceneRealizer.Context.InstalledResources()
        res.environmentPayloadIds[5] = 40      // env 5 awaits equirect 40
        res.lutPayloadIds[5] = 41              // env 5 awaits LUT 41
        assertFalse(res.pendingClaims(41, setOf(5)))
        assertFalse(res.pendingClaims(40, setOf(5)))
    }

    @Test
    fun `a chunk claimed by a non-pending ref does not arm`() {
        val res = FsceneRealizer.Context.InstalledResources()
        res.texturePayloadIds[7] = 42
        // Texture 7 already resolved — only unrelated refs defer.
        assertFalse(res.pendingClaims(42, setOf(8)))
    }

    @Test
    fun `an unclaimed chunk never arms regardless of the pending set`() {
        val res = FsceneRealizer.Context.InstalledResources()
        res.texturePayloadIds[7] = 42
        res.geometryPayloadIds[9] = mutableSetOf(43)
        assertFalse(res.pendingClaims(99, setOf(7, 9)))
    }

    @Test
    fun `skin and animation claims never arm`() {
        // Those payloads re-decode surgically in applyPayload; their
        // chunks must not re-realize even while refs stay pending.
        val res = FsceneRealizer.Context.InstalledResources()
        res.skinPayloadIds[3] = 60
        res.animPayloadIds[4] = mutableSetOf(61, 62)
        assertFalse(res.pendingClaims(60, setOf(3)))
        assertFalse(res.pendingClaims(61, setOf(4)))
    }
}
