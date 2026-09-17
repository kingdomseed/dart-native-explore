package com.jasonholtdigital.dart3d

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The upstream `mesh` component's primitive-list shape — single-prim
 * meshes emit direct `geometry`/`material` refs while multi-prim
 * meshes emit `primitives` as a tagged list of `{"map":{...}}`
 * PropertyValues. [meshPrimitiveKeys] must resolve both to ordered
 * (geometry, material) ref pairs; the map-unwrap is what the dice
 * `.fsceneb` corpus exercises. Pure JVM; no Filament needed.
 */
class MeshPrimitivesTest {

    /** A Crockford token that round-trips through localIdKey. */
    private fun token(session: Long, index: Long): String =
        "r:" + D3Wire.localIdToken(D3Wire.idKey(session, index))

    @Test
    fun `single-primitive mesh reads direct geometry and material refs`() {
        val geo = token(1, 10)
        val mat = token(1, 11)
        val p = JSONObject(
            """{"geometry":{"rref":"$geo"},
               "material":{"rref":"$mat"}}""")
        val (geos, mats) = meshPrimitiveKeys(p)
        assertEquals(listOf(D3Wire.localIdKey(geo)), geos)
        assertEquals(listOf(D3Wire.localIdKey(mat)), mats)
    }

    @Test
    fun `multi-primitive mesh unwraps tagged map entries`() {
        // The shape upstream's codec writes — every list entry is a
        // MapValue, so the refs live under {"map":{...}}, not at the
        // entry's top level.
        val g0 = token(2, 20)
        val m0 = token(2, 21)
        val g1 = token(2, 22)
        val m1 = token(2, 23)
        val p = JSONObject(
            """{"primitives":{"list":[
                 {"map":{"geometry":{"rref":"$g0"},
                         "material":{"rref":"$m0"}}},
                 {"map":{"geometry":{"rref":"$g1"},
                         "material":{"rref":"$m1"}}}
               ]}}""")
        val (geos, mats) = meshPrimitiveKeys(p)
        assertEquals(
            listOf(D3Wire.localIdKey(g0), D3Wire.localIdKey(g1)), geos)
        assertEquals(
            listOf(D3Wire.localIdKey(m0), D3Wire.localIdKey(m1)), mats)
    }

    @Test
    fun `primitive entry missing geometry is skipped`() {
        val m0 = token(3, 30)
        val g1 = token(3, 31)
        val p = JSONObject(
            """{"primitives":{"list":[
                 {"map":{"material":{"rref":"$m0"}}},
                 {"map":{"geometry":{"rref":"$g1"}}}
               ]}}""")
        val (geos, mats) = meshPrimitiveKeys(p)
        assertEquals(listOf(D3Wire.localIdKey(g1)), geos)
        assertEquals(listOf(null), mats)
    }

    @Test
    fun `mesh with neither form resolves empty`() {
        val (geos, mats) = meshPrimitiveKeys(JSONObject("{}"))
        assertTrue(geos.isEmpty())
        assertTrue(mats.isEmpty())
    }

    @Test
    fun `material-less primitive keeps a null slot`() {
        val g0 = token(4, 40)
        val p = JSONObject(
            """{"primitives":{"list":[
                 {"map":{"geometry":{"rref":"$g0"}}}
               ]}}""")
        val (geos, mats) = meshPrimitiveKeys(p)
        assertEquals(listOf(D3Wire.localIdKey(g0)), geos)
        assertEquals(1, mats.size)
        assertNull(mats[0])
    }
}
