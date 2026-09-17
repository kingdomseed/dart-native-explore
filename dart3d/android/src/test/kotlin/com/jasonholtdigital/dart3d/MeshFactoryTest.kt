package com.jasonholtdigital.dart3d

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.sqrt
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Vertex-layout invariants for [MeshFactory] — the shared 13-float
 * `[pos3 | tangent-quat4 | uv2 | color4]` record (52-byte stride) that
 * both the procedural generators and the payload decoders emit, plus
 * the 76-byte skinned repack. Pure JVM; no Filament needed.
 */
class MeshFactoryTest {

    @Test
    fun `stride constants match the 13-float record`() {
        assertEquals(13, MeshFactory.FLOATS_PER_VERTEX)
        assertEquals(13, MeshFactory.PAYLOAD_FLOATS_PER_VERTEX)
        assertEquals(52, MeshFactory.PROCEDURAL_VERTEX_STRIDE_BYTES)
        assertEquals(52, MeshFactory.PAYLOAD_VERTEX_STRIDE_BYTES)
        // Base record + [joints u16x4 | weights f32x4] = 52 + 8 + 16.
        assertEquals(76, MeshFactory.PAYLOAD_SKINNED_VERTEX_STRIDE_BYTES)
    }

    @Test
    fun `procedural generators emit the shared record`() {
        assertProceduralMesh(
            MeshFactory.cuboid(2f, 4f, 6f), 24, 36,
            floatArrayOf(0f, 0f, 0f, 1f, 2f, 3f))
        assertProceduralMesh(
            MeshFactory.sphere(1.5f), 17 * 25, 16 * 24 * 6,
            floatArrayOf(0f, 0f, 0f, 1.5f, 1.5f, 1.5f))
        assertProceduralMesh(
            MeshFactory.plane(2f, 3f), 4, 6,
            floatArrayOf(0f, 0f, 0f, 1f, 1.5f, 0f))
        assertProceduralMesh(
            MeshFactory.torus(1f, 0.25f), 33 * 17, 32 * 16 * 6,
            floatArrayOf(0f, 0f, 0f, 1.25f, 0.25f, 1.25f))
    }

    @Test
    fun `p3t4 payload expands into the shared record`() {
        // Wire record: [pos3 | quat4] little-endian, 28 bytes/vertex,
        // already in native space — the decoder copies it verbatim,
        // then fabricates uv=[0,0] and white color.
        val mesh = MeshFactory.fromPayload(
            wire(
                1f, 2f, 3f, 0.1f, -0.2f, 0.3f, -0.4f,
                -4f, 0.5f, 7f, 0.9f, 0.8f, -0.7f, 0.6f,
            ),
            "p3t4", null, null,
            MeshFactory.Topology.TRIANGLES, false, null)

        assertEquals(2, mesh.vertexCount)
        assertEquals(52, mesh.vertexStrideBytes)
        assertEquals(2 * 52, mesh.vertices.capacity())
        assertTrue(mesh.hasUvColor)
        assertFalse(mesh.hasSkinning)
        // No index payload → sequential uint16 indices.
        assertEquals(MeshFactory.IndexWidth.UINT16, mesh.indexWidth)
        assertEquals(2, mesh.indexCount)
        assertEquals(0, indexAt(mesh, 0))
        assertEquals(1, indexAt(mesh, 1))

        // Deliberately non-unit quats: verbatim copy is what proves no
        // repack or mirror happened on the p3t4 path.
        val a = record(mesh, 0)
        val va = floatArrayOf(1f, 2f, 3f, 0.1f, -0.2f, 0.3f, -0.4f)
        for (c in 0 until 7) assertEquals(va[c], a[c], 0f)
        assertEquals(0f, a[7], 0f)
        assertEquals(0f, a[8], 0f)
        for (c in 9 until 13) assertEquals(1f, a[c], 0f)

        val b = record(mesh, 1)
        val vb = floatArrayOf(-4f, 0.5f, 7f, 0.9f, 0.8f, -0.7f, 0.6f)
        for (c in 0 until 7) assertEquals(vb[c], b[c], 0f)

        // Bounds scanned from the decoded positions (p3t4 is native
        // space, so z is unmirrored): center + half-extents.
        assertArrayEquals(
            floatArrayOf(-1.5f, 1.25f, 5f, 2.5f, 0.75f, 2f), mesh.bounds, EPS)
    }

    @Test
    fun `interleaved payload decodes channels at the declared offsets`() {
        // `unskinned` wire record: [pos3 | normal3 | uv2 | color4]
        // (48 bytes) → the same 52-byte record, with the tangent quat
        // derived from the normal and z mirrored into native space.
        val mesh = MeshFactory.fromPayload(
            wire(
                1f, 2f, 3f,
                0f, 0f, 1f,
                0.25f, 0.75f,
                0.5f, 0.25f, 0.125f, 1f,
            ),
            "unskinned", null, null,
            MeshFactory.Topology.TRIANGLES, false, null)

        assertEquals(1, mesh.vertexCount)
        assertEquals(52, mesh.vertexStrideBytes)
        assertEquals(52, mesh.vertices.capacity())
        assertFalse(mesh.hasSkinning)

        val r = record(mesh, 0)
        assertEquals(1f, r[0], 0f)
        assertEquals(2f, r[1], 0f)
        assertEquals(-3f, r[2], 0f) // upstream → native: z mirrored
        val qLen = sqrt(r[3] * r[3] + r[4] * r[4] +
            r[5] * r[5] + r[6] * r[6])
        assertEquals(1f, qLen, 1e-4f)
        assertEquals(0.25f, r[7], 0f)
        assertEquals(0.75f, r[8], 0f)
        assertEquals(0.5f, r[9], 0f)
        assertEquals(0.25f, r[10], 0f)
        assertEquals(0.125f, r[11], 0f)
        assertEquals(1f, r[12], 0f)

        // Single decoded (mirrored) position → degenerate bounds.
        assertArrayEquals(
            floatArrayOf(1f, 2f, -3f, 0f, 0f, 0f), mesh.bounds, EPS)
    }

    @Test
    fun `skinned payload appends the joints and weights tail`() {
        // `skinned` wire record: [pos3 | normal3 | uv2 | color4 |
        // joints f32x4 | weights f32x4] (80 bytes) → 76-byte repack:
        // the 52-byte base + [joints u16x4 | weights f32x4].
        val mesh = MeshFactory.fromPayload(
            wire(
                0f, 0f, 0f,
                0f, 1f, 0f,
                0f, 0f,
                1f, 1f, 1f, 1f,
                3f, 5f, 7f, 9f,
                0.5f, 0.25f, 0.125f, 0.125f,
            ),
            "skinned", null, null,
            MeshFactory.Topology.TRIANGLES, false, null)

        assertEquals(1, mesh.vertexCount)
        assertEquals(
            MeshFactory.PAYLOAD_SKINNED_VERTEX_STRIDE_BYTES,
            mesh.vertexStrideBytes)
        assertEquals(76, mesh.vertices.capacity())
        assertTrue(mesh.hasSkinning)
        // Joint ids arrive as whole-valued f32 and land as u16 — the
        // shader reads BONE_INDICES as uvec4.
        assertEquals(3, mesh.vertices.getShort(52).toInt() and 0xFFFF)
        assertEquals(5, mesh.vertices.getShort(54).toInt() and 0xFFFF)
        assertEquals(7, mesh.vertices.getShort(56).toInt() and 0xFFFF)
        assertEquals(9, mesh.vertices.getShort(58).toInt() and 0xFFFF)
        assertEquals(0.5f, mesh.vertices.getFloat(60), 0f)
        assertEquals(0.25f, mesh.vertices.getFloat(64), 0f)
        assertEquals(0.125f, mesh.vertices.getFloat(68), 0f)
        assertEquals(0.125f, mesh.vertices.getFloat(72), 0f)
    }

    @Test
    fun `positionsFromPayload mirrors z except on p3t4`() {
        // p3t4 is already native space — positions pass verbatim.
        assertArrayEquals(
            floatArrayOf(1f, 2f, 3f, -4f, 0.5f, 7f),
            MeshFactory.positionsFromPayload(
                wire(
                    1f, 2f, 3f, 0f, 0f, 0f, 1f,
                    -4f, 0.5f, 7f, 0f, 0f, 0f, 1f,
                ),
                "p3t4"),
            0f)
        // Upstream layouts decode into native space with z negated.
        assertArrayEquals(
            floatArrayOf(1f, 2f, -3f),
            MeshFactory.positionsFromPayload(
                wire(
                    1f, 2f, 3f,
                    0f, 0f, 1f,
                    0f, 0f,
                    1f, 1f, 1f, 1f,
                ),
                "unskinned"),
            0f)
    }

    @Test
    fun `indicesFromPayload decodes little-endian widths`() {
        assertArrayEquals(
            intArrayOf(0, 1, 65535),
            MeshFactory.indicesFromPayload(u16(0, 1, 65535), "uint16"))
        assertArrayEquals(
            intArrayOf(70000),
            MeshFactory.indicesFromPayload(
                ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN)
                    .putInt(70000).array(),
                "uint32"))
    }

    @Test
    fun `swapTriangleWinding reverses each triangle`() {
        val mesh = MeshFactory.fromPayload(
            wire(
                0f, 0f, 0f, 1f, 0f, 0f, 0f,
                1f, 0f, 0f, 1f, 0f, 0f, 0f,
                0f, 1f, 0f, 1f, 0f, 0f, 0f,
            ),
            "p3t4", u16(0, 1, 2), "uint16",
            MeshFactory.Topology.TRIANGLES, true, null)
        assertEquals(0, indexAt(mesh, 0))
        assertEquals(2, indexAt(mesh, 1))
        assertEquals(1, indexAt(mesh, 2))
    }

    @Test
    fun `malformed payloads fail loudly`() {
        // Unknown layout name.
        assertThrows(MeshFactory.PayloadDecodeException::class.java) {
            MeshFactory.fromPayload(
                wire(0f), "nonsense", null, null,
                MeshFactory.Topology.TRIANGLES, false, null)
        }
        // Wire bytes not divisible by the layout stride.
        assertThrows(MeshFactory.PayloadDecodeException::class.java) {
            MeshFactory.fromPayload(
                wire(0f, 0f, 0f), "p3t4", null, null,
                MeshFactory.Topology.TRIANGLES, false, null)
        }
        // Index outside the vertex range.
        assertThrows(MeshFactory.PayloadDecodeException::class.java) {
            MeshFactory.fromPayload(
                wire(0f, 0f, 0f, 1f, 0f, 0f, 0f),
                "p3t4", u16(7), "uint16",
                MeshFactory.Topology.TRIANGLES, false, null)
        }
    }

    // ---- helpers ----

    // Reads the first 13 floats of vertex `v` from the packed record.
    private fun record(mesh: MeshFactory.MeshData, v: Int): FloatArray {
        val base = v * mesh.vertexStrideBytes
        return FloatArray(MeshFactory.FLOATS_PER_VERTEX) {
            mesh.vertices.getFloat(base + it * 4)
        }
    }

    private fun indexAt(mesh: MeshFactory.MeshData, i: Int): Int =
        mesh.indices.getShort(i * 2).toInt() and 0xFFFF

    // Shared record contract: positions inside the declared bounds,
    // unit-length tangent quat, non-degenerate uvs in [0,1], white
    // vertex color.
    private fun assertProceduralMesh(
        mesh: MeshFactory.MeshData,
        vertexCount: Int,
        indexCount: Int,
        bounds: FloatArray,
    ) {
        assertEquals(vertexCount, mesh.vertexCount)
        assertEquals(indexCount, mesh.indexCount)
        assertEquals(
            MeshFactory.PROCEDURAL_VERTEX_STRIDE_BYTES, mesh.vertexStrideBytes)
        assertEquals(vertexCount * 52, mesh.vertices.capacity())
        assertTrue(mesh.hasUvColor)
        assertFalse(mesh.hasSkinning)
        assertArrayEquals(bounds, mesh.bounds, EPS)

        val first = record(mesh, 0)
        var uvDegenerate = true
        for (v in 0 until mesh.vertexCount) {
            val r = record(mesh, v)
            for (c in 0 until 3) {
                assertTrue(abs(r[c]) <= bounds[3 + c] + EPS)
            }
            val qLen = sqrt(r[3] * r[3] + r[4] * r[4] +
                r[5] * r[5] + r[6] * r[6])
            assertEquals(1f, qLen, 1e-4f)
            assertTrue(r[7] in -EPS..1f + EPS)
            assertTrue(r[8] in -EPS..1f + EPS)
            if (r[7] != first[7] || r[8] != first[8]) uvDegenerate = false
            for (c in 9 until 13) assertEquals(1f, r[c], 0f)
        }
        assertFalse("uv channel is degenerate", uvDegenerate)
    }

    // Wire bytes are little-endian — the byte order fromPayload reads.
    private fun wire(vararg floats: Float): ByteArray =
        ByteBuffer.allocate(floats.size * 4).order(ByteOrder.LITTLE_ENDIAN)
            .also { buf -> floats.forEach { buf.putFloat(it) } }
            .array()

    private fun u16(vararg indices: Int): ByteArray =
        ByteBuffer.allocate(indices.size * 2).order(ByteOrder.LITTLE_ENDIAN)
            .also { buf -> indices.forEach { buf.putShort(it.toShort()) } }
            .array()

    private companion object {
        const val EPS = 1e-5f
    }
}
