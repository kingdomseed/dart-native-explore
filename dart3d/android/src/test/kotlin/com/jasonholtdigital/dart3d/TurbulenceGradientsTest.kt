package com.jasonholtdigital.dart3d

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The OpenSimplex2 gradient table `gradCoord3` indexes as 64 stride-4
 * vectors (`hash & (63 << 2)`). It must match
 * `lib/src/particle_sim.dart`'s `_gradients3D` exactly — a previous
 * transcription carried 322 values that drifted from index 32 on,
 * so most hashes read shifted vectors (audit P1).
 */
class TurbulenceGradientsTest {

    @Test
    fun `table is 64 stride-4 vectors`() {
        assertEquals(256, GRADIENTS_3D.size)
    }

    @Test
    fun `every vector is an edge gradient with a zero pad`() {
        for (v in 0 until 64) {
            val x = GRADIENTS_3D[v * 4]
            val y = GRADIENTS_3D[v * 4 + 1]
            val z = GRADIENTS_3D[v * 4 + 2]
            assertEquals("pad at vector $v", 0.0, GRADIENTS_3D[v * 4 + 3], 0.0)
            val comps = listOf(x, y, z)
            assertEquals("two unit components at vector $v", 2,
                comps.count { it == 1.0 || it == -1.0 })
            assertEquals("one zero component at vector $v", 1,
                comps.count { it == 0.0 })
        }
    }

    @Test
    fun `known entries match the Dart reference`() {
        // Spot values from particle_sim.dart `_gradients3D` — the
        // first 12 edges repeat (upstream's 12-edge set tiled), with
        // the final four vectors the upstream padding set.
        val first12 = doubleArrayOf(
            0.0, 1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0,
            0.0, 1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0,
            1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0,
            1.0, 0.0, -1.0, 0.0, -1.0, 0.0, -1.0, 0.0,
            1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0,
            1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0,
        )
        for (i in first12.indices) {
            assertEquals("entry $i", first12[i], GRADIENTS_3D[i], 0.0)
            // The 12-edge block repeats through vector 59.
            assertEquals("entry ${i + 48}", first12[i],
                GRADIENTS_3D[i + 48], 0.0)
        }
    }
}
