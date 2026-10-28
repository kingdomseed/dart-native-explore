package com.jasonholtdigital.dart3d

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder

class U4PropertyAnimationTest {
    private val floats = FsceneRealizer.Context.PayloadMeta("floats", null, null)
    private fun bytes(vararg values: Float): ByteArray = ByteBuffer.allocate(values.size * 4)
        .order(ByteOrder.LITTLE_ENDIAN).also { b -> values.forEach { b.putFloat(it) } }.array()
    private fun definition(kind: String, endpoint: String = "node", prefix: String = "n") =
        AnimationDefinition.parse(JSONObject("""{"d3:properties":[
            {"kind":"$kind","$endpoint":"$prefix:0000000000002",
             "timeline":"chunk:0000000000004","keyframes":"chunk:0000000000006"}]}"""))
    private fun curve(kind: String, vararg values: Float): PropertyCurve {
        val spec = if (kind == "materialBaseColor") definition(kind, "material", "mat")
            else definition(kind)
        return PropertyCurve.decode(spec.properties.single(), bytes(0f, 2f), bytes(*values), floats, floats)!!
    }
    private fun rejects(block: () -> Unit) {
        try { block(); fail("expected invalid input to reject") }
        catch (expected: IllegalArgumentException) { }
    }

    @Test fun `literal wire kinds decode and sample their midpoint`() {
        val color = curve("materialBaseColor", 1f, 0f, 0f, 1f, 0f, 0f, 1f, 1f)
        assertEquals(4, color.spec.kind.arity)
        assertArrayEquals(floatArrayOf(.5f, 0f, .5f, 1f), color.sample(1.0), 0f)
        assertArrayEquals(floatArrayOf(1f, 0f, 0f, 1f), color.sample(-1.0), 0f)
        assertArrayEquals(floatArrayOf(0f, 0f, 1f, 1f), color.sample(3.0), 0f)
        val intensity = curve("lightIntensity", 2f, 6f)
        assertEquals(1, intensity.spec.kind.arity)
        assertEquals(4f, intensity.sample(1.0)[0], 0f)
        val fov = curve("cameraFovRadiansY", (Math.PI / 4).toFloat(), (Math.PI / 2).toFloat())
        assertEquals(1, fov.spec.kind.arity)
        assertEquals((3 * Math.PI / 8).toFloat(), fov.sample(1.0)[0], 1e-6f)
        assertTrue(definition("lightIntensity").ordinary.isEmpty())
    }

    @Test fun `metadata rejects unknown ordinary and property kinds and duplicate endpoints`() {
        rejects { definition("translation") }
        rejects { definition("lightIntensity", "material", "mat") }
        rejects { AnimationDefinition.parse(JSONObject("""{"channels":[{"target":"n:0000000000002",
            "property":"typo","timeline":"chunk:0000000000004","keyframes":"chunk:0000000000006"}]}""")) }
        val json = JSONObject("""{"d3:properties":[{"kind":"lightIntensity","node":"n:0000000000002",
            "timeline":"chunk:0000000000004","keyframes":"chunk:0000000000006"}]}""")
        val extra = JSONObject(json.toString())
        extra.getJSONArray("d3:properties").getJSONObject(0).put("interpolation", "linear")
        rejects { AnimationDefinition.parse(extra) }
        json.getJSONArray("d3:properties").put(json.getJSONArray("d3:properties").get(0))
        rejects { AnimationDefinition.parse(json) }
        rejects { AnimationDefinition.parse(JSONObject("""{"d3:properties":{}}""")) }
    }

    @Test fun `ordinary metadata retains all four kinds retarget name and payload claims`() {
        assertTrue(AnimationDefinition.parse(JSONObject("""{"channels":null}""")).ordinary.isEmpty())
        for (kind in listOf("translation", "rotation", "scale", "weights")) {
            val definition = AnimationDefinition.parse(JSONObject("""{"channels":[
                {"property":"$kind","target":"n:0000000000002","targetName":"retarget",
                 "timeline":"chunk:0000000000004","keyframes":"chunk:0000000000006"}]}"""))
            val channel = definition.ordinary.single()
            assertEquals(kind, channel.kind)
            assertEquals("retarget", channel.targetName)
            assertEquals(setOf(channel.timeline, channel.keyframes), definition.claims)
            assertTrue(definition.properties.isEmpty())
        }
    }

    @Test fun `both claims exist before payloads and corrected peers recover without new IDs`() {
        val def = definition("lightIntensity")
        val spec = def.properties.single()
        assertEquals(setOf(spec.timeline, spec.keyframes), def.claims)
        assertNull(PropertyCurve.decode(spec, bytes(0f, 2f), null, floats, floats))
        assertNull(PropertyCurve.decode(spec, null, bytes(2f, 6f), floats, floats))
        rejects { PropertyCurve.decode(spec, bytes(0f, 1f, 2f), bytes(2f, 6f), floats, floats) }
        val corrected = PropertyCurve.decode(spec, bytes(0f, 1f, 2f), bytes(2f, 4f, 6f), floats, floats)!!
        assertEquals(4f, corrected.sample(1.0)[0], 0f)
        rejects { PropertyCurve.decode(spec, bytes(0f, 2f), bytes(2f, 4f, 6f), floats, floats) }
        assertEquals(4f, PropertyCurve.decode(spec, bytes(0f, 1f, 2f), bytes(2f, 4f, 6f), floats, floats)!!.sample(1.0)[0], 0f)
        val wrongMeta = FsceneRealizer.Context.PayloadMeta("bytes", null, null)
        rejects { PropertyCurve.decode(spec, bytes(0f, 2f), bytes(2f, 6f), floats, wrongMeta) }
        assertEquals(4f, PropertyCurve.decode(spec, bytes(0f, 2f), bytes(2f, 6f), floats, floats)!!.sample(1.0)[0], 0f)
    }

    @Test fun `joined curves reject nonfinite unordered malformed and out of domain values`() {
        rejects { curve("lightIntensity", -1f, 2f) }
        rejects { curve("lightIntensity", 1f, Float.NaN) }
        rejects { curve("lightIntensity", 1f) }
        rejects { curve("cameraFovRadiansY", 0f, 1f) }
        rejects { curve("cameraFovRadiansY", 1f, Math.PI.toFloat()) }
        rejects { curve("materialBaseColor", 1f, 0f, 0f, 2f, 0f, 0f, 1f, 1f) }
        val spec = definition("lightIntensity").properties.single()
        for (times in listOf(bytes(), bytes(0f, 0f), bytes(-1f, 2f), bytes(0f, Float.POSITIVE_INFINITY), byteArrayOf(1))) {
            rejects { PropertyCurve.decode(spec, times, bytes(2f, 6f), floats, floats) }
        }
        rejects { PropertyCurve.decode(spec, bytes(0f, 2f), byteArrayOf(1), floats, floats) }
        val badLength = FsceneRealizer.Context.PayloadMeta("floats", null, null, length = 3)
        rejects { PropertyCurve.decode(spec, bytes(0f, 2f), bytes(2f, 6f), floats, badLength) }
    }

    @Test fun `owner blending uses authored rest global weights zero binding and one restoration`() {
        val owner = AnimatedProperty(floatArrayOf(1f))
        val intensity = curve("lightIntensity", 2f, 6f)
        val clip = AnimClipState().apply { applyOp(2.0, time = 1.0, weight = .25) }
        var acc = owner.rest.copyOf()
        owner.accumulate(acc, intensity, clip.time, blendWeights(mapOf(1L to clip)).getValue(1L))
        var writes = 0
        owner.apply(acc) { writes++; assertEquals(1.75f, it[0], 0f) }
        clip.applyOp(2.0, weight = 1.0, pause = true)
        val unrelatedPending = AnimClipState()
        acc = owner.rest.copyOf()
        owner.accumulate(acc, intensity, clip.time, blendWeights(mapOf(1L to clip, 2L to unrelatedPending)).getValue(1L))
        owner.apply(acc) { assertEquals(2.5f, it[0], 0f) }
        owner.apply(owner.rest.copyOf()) { assertEquals(1f, it[0], 0f) }
        owner.apply(null) { writes++; assertEquals(1f, it[0], 0f) }
        owner.apply(null) { fail("restoration must release driven owner") }
        assertEquals(2, writes)
        val replacement = AnimatedProperty(floatArrayOf(3f))
        acc = replacement.rest.copyOf()
        replacement.accumulate(acc, intensity, 1.0, .25f)
        replacement.apply(acc) { assertEquals(3.25f, it[0], 0f) }
        assertEquals(3f, replacement.rest[0], 0f)
    }

    @Test fun `camera retained projection reads effective vertical field of view`() {
        val camera = RenderTargets.CameraSpec(fovDeg = 45.0)
        val fov = curve("cameraFovRadiansY", (Math.PI / 4).toFloat(), (Math.PI / 2).toFloat())
        val acc = camera.fov.rest.copyOf()
        camera.fov.accumulate(acc, fov, 1.0, 1f)
        camera.fov.apply(acc) { }
        assertEquals(67.5, camera.fovDeg, 1e-5)
        camera.fov.apply(null) { }
        assertEquals(45.0, camera.fovDeg, 1e-5)
    }

    @Test fun `light owner conversion retains actual area dimensions`() {
        val area = FsceneRealizer.LightOwner(listOf(1, 2, 3, 4), false, 2f, 3f, true, 1f)
        assertEquals(4, area.entities.size)
        assertEquals(6f, area.convertedIntensity(4f), 0f)
        assertEquals(4f, FsceneRealizer.LightOwner(listOf(1), false, intensity = 1f).convertedIntensity(4f), 0f)
    }
}
