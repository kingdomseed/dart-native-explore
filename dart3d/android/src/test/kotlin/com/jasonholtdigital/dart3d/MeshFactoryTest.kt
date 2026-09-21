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
 * Vertex-layout invariants for [MeshFactory] — the shared 15-float
 * `[pos3 | tangent-quat4 | uv0-2 | color4 | uv1-2]` record (60-byte
 * stride) that both the procedural generators and the payload decoders
 * emit, plus the 84-byte skinned repack. Pure JVM; no Filament needed.
 */
class MeshFactoryTest {

    @Test
    fun `stride constants match the 15-float record`() {
        assertEquals(15, MeshFactory.FLOATS_PER_VERTEX)
        assertEquals(15, MeshFactory.PAYLOAD_FLOATS_PER_VERTEX)
        assertEquals(60, MeshFactory.PROCEDURAL_VERTEX_STRIDE_BYTES)
        assertEquals(60, MeshFactory.PAYLOAD_VERTEX_STRIDE_BYTES)
        // Base record + [joints u16x4 | weights f32x4] = 60 + 8 + 16.
        assertEquals(84, MeshFactory.PAYLOAD_SKINNED_VERTEX_STRIDE_BYTES)
    }

    @Test
    fun `procedural generators emit the shared record`() {
        assertProceduralMesh(
            MeshFactory.cuboid(2f, 4f, 6f), 24, 36,
            floatArrayOf(0f, 0f, 0f, 1f, 2f, 3f))
        assertProceduralMesh(
            MeshFactory.sphere(1.5f), 17 * 33, 16 * 32 * 6,
            floatArrayOf(0f, 0f, 0f, 1.5f, 1.5f, 1.5f))
        // The wire plane spans XZ — depth is the Z half-extent, not Y.
        assertProceduralMesh(
            MeshFactory.plane(2f, 3f), 4, 6,
            floatArrayOf(0f, 0f, 0f, 1f, 0f, 1.5f))
        assertProceduralMesh(
            MeshFactory.torus(1f, 0.25f), 33 * 17, 32 * 16 * 6,
            floatArrayOf(0f, 0f, 0f, 1.25f, 0.25f, 1.25f))
    }

    @Test
    fun `plane lies in XZ and winds facing +Y`() {
        val mesh = MeshFactory.plane(2f, 2f)
        assertEquals(4, mesh.vertexCount)
        // Every vertex sits at y == 0 with a +Y attribute normal.
        for (v in 0 until mesh.vertexCount) {
            val r = record(mesh, v)
            assertEquals(0f, r[1], 0f)
            assertEquals(1f, normalOf(r)[1], EPS)
        }
        // quad(a, a+cols, a+1, a+cols+1): tri (0, 2, 1) spans
        // (−x,−z) → (−x,+z) → (+x,−z); e1×e2 points +Y.
        val a = vert(mesh, indexAt(mesh, 0))
        val b = vert(mesh, indexAt(mesh, 1))
        val c = vert(mesh, indexAt(mesh, 2))
        val nx = (b[1] - a[1]) * (c[2] - a[2]) -
            (b[2] - a[2]) * (c[1] - a[1])
        val ny = (b[2] - a[2]) * (c[0] - a[0]) -
            (b[0] - a[0]) * (c[2] - a[2])
        val nz = (b[0] - a[0]) * (c[1] - a[1]) -
            (b[1] - a[1]) * (c[0] - a[0])
        assertEquals(0f, nx, EPS)
        assertTrue("plane must wind facing +Y", ny > 0f)
        assertEquals(0f, nz, EPS)
        // Segmented grids keep the same contract per cell.
        val grid = MeshFactory.plane(2f, 2f, segmentsX = 3, segmentsZ = 2)
        assertEquals(12, grid.vertexCount)
        assertEquals(36, grid.indexCount)
        for (v in 0 until grid.vertexCount) {
            assertEquals(0f, record(grid, v)[1], 0f)
        }
    }

    @Test
    fun `sphere and torus wind outward`() {
        for (mesh in listOf(
            MeshFactory.sphere(1f, segments = 8, rings = 4),
            MeshFactory.torus(1f, 0.25f, rings = 8, sectors = 4))) {
            for (t in 0 until mesh.indexCount / 3) {
                val a = vert(mesh, indexAt(mesh, t * 3))
                val b = vert(mesh, indexAt(mesh, t * 3 + 1))
                val c = vert(mesh, indexAt(mesh, t * 3 + 2))
                val e1x = b[0] - a[0]; val e1y = b[1] - a[1]
                val e1z = b[2] - a[2]
                val e2x = c[0] - a[0]; val e2y = c[1] - a[1]
                val e2z = c[2] - a[2]
                val nx = e1y * e2z - e1z * e2y
                val ny = e1z * e2x - e1x * e2z
                val nz = e1x * e2y - e1y * e2x
                if (nx * nx + ny * ny + nz * nz < 1e-10f) continue
                // The attribute normal is the normal column of each
                // vertex's packed tangent frame — the geometric normal
                // must agree (outward) on every non-degenerate tri.
                var anx = 0f; var any = 0f; var anz = 0f
                for (k in 0 until 3) {
                    val n = normalOf(record(mesh, indexAt(mesh, t * 3 + k)))
                    anx += n[0]; any += n[1]; anz += n[2]
                }
                assertTrue(
                    "triangle $t winds inward",
                    nx * anx + ny * any + nz * anz > 0f)
            }
        }
    }

    @Test
    fun `cuboid debugColors keys vertex color to corner sign bits`() {
        val mesh = MeshFactory.cuboid(2f, 2f, 2f, debugColors = true)
        assertEquals(24, mesh.vertexCount)
        for (v in 0 until mesh.vertexCount) {
            val r = record(mesh, v)
            assertEquals(if (r[0] >= 0f) 1f else 0f, r[9], 0f)
            assertEquals(if (r[1] >= 0f) 1f else 0f, r[10], 0f)
            assertEquals(if (r[2] >= 0f) 1f else 0f, r[11], 0f)
            assertEquals(1f, r[12], 0f)
        }
    }

    @Test
    fun `bakeInstances transforms normals by the exact inverse-transpose`() {
        // +Y normals everywhere.
        val base = MeshFactory.plane(2f, 2f)
        // Shear y' = y + x (column-major: M[1,0] lives at index 1 —
        // x'=x+y would leave the +Y normal invariant). M^-T·(0,1,0)
        // = (−1,1,0)/√2 — the old normalize-the-columns approximation
        // could not produce this.
        val shear = floatArrayOf(
            1f, 1f, 0f, 0f,
            0f, 1f, 0f, 0f,
            0f, 0f, 1f, 0f,
            0f, 0f, 0f, 1f)
        val baked = MeshFactory.bakeInstances(base, listOf(shear))
        for (v in 0 until baked.vertexCount) {
            val n = normalOf(record(baked, v))
            assertEquals(-0.7071f, n[0], 1e-3f)
            assertEquals(0.7071f, n[1], 1e-3f)
            assertEquals(0f, n[2], 1e-3f)
        }
        // A mirror keeps the +Y normal (M^-T·n is unchanged) but the
        // determinant's sign flips the frame's handedness — the
        // packed quat's w<0 channel marks it. The plane's own frame
        // is the w<0 reflected basis, so identity keeps w<0 and the
        // mirror flips it positive.
        val identity = FloatArray(16) { if (it % 5 == 0) 1f else 0f }
        val identBaked = MeshFactory.bakeInstances(base, listOf(identity))
        val mirror = floatArrayOf(
            -1f, 0f, 0f, 0f,
            0f, 1f, 0f, 0f,
            0f, 0f, 1f, 0f,
            0f, 0f, 0f, 1f)
        val mirrored = MeshFactory.bakeInstances(base, listOf(mirror))
        for (v in 0 until mirrored.vertexCount) {
            val ri = record(identBaked, v)
            val rm = record(mirrored, v)
            assertTrue("identity bake keeps the source frame", ri[6] < 0f)
            assertTrue("mirror must flip the frame's handedness",
                rm[6] > 0f)
            assertEquals(1f, normalOf(rm)[1], 1e-4f)
        }
        // A non-invertible transform carries the source frame through.
        val flat = floatArrayOf(
            0f, 0f, 0f, 0f,
            0f, 1f, 0f, 0f,
            0f, 0f, 1f, 0f,
            0f, 0f, 0f, 1f)
        val flatBaked = MeshFactory.bakeInstances(base, listOf(flat))
        for (v in 0 until flatBaked.vertexCount) {
            assertEquals(1f, normalOf(record(flatBaked, v))[1], 1e-4f)
        }
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
        assertEquals(60, mesh.vertexStrideBytes)
        assertEquals(2 * 60, mesh.vertices.capacity())
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
        // uv1 fabricates to [0,0].
        assertEquals(0f, a[13], 0f)
        assertEquals(0f, a[14], 0f)

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
        // (48 bytes) → the same 60-byte record, with the tangent quat
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
        assertEquals(60, mesh.vertexStrideBytes)
        assertEquals(60, mesh.vertices.capacity())
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
        // A uv1-less wire layout zero-fills the record tail.
        assertEquals(0f, r[13], 0f)
        assertEquals(0f, r[14], 0f)

        // Single decoded (mirrored) position → degenerate bounds.
        assertArrayEquals(
            floatArrayOf(1f, 2f, -3f, 0f, 0f, 0f), mesh.bounds, EPS)
    }

    @Test
    fun `uv1 layouts carry the second UV channel into the record tail`() {
        // `unskinned_uv1_tangent` wire record: [pos3 | normal3 | uv0-2 |
        // uv1-2 | color4 | tangent4] (72 bytes) → 60-byte repack.
        val mesh = MeshFactory.fromPayload(
            wire(
                1f, 2f, 3f,
                0f, 0f, 1f,
                0.25f, 0.75f,
                0.6f, 0.4f,
                0.5f, 0.25f, 0.125f, 1f,
                0f, 0f, -1f, -1f,
            ),
            "unskinned_uv1_tangent", null, null,
            MeshFactory.Topology.TRIANGLES, false, null)

        assertEquals(1, mesh.vertexCount)
        assertEquals(60, mesh.vertexStrideBytes)
        assertEquals(60, mesh.vertices.capacity())
        val r = record(mesh, 0)
        assertEquals(0.25f, r[7], 0f)
        assertEquals(0.75f, r[8], 0f)
        assertEquals(0.5f, r[9], 0f)
        assertEquals(0.6f, r[13], 0f)
        assertEquals(0.4f, r[14], 0f)

        // The SoA twin puts the uv1 slab after uv0's:
        // [pos | n | uv0 | uv1 | color | tangent] per-vertex-width slabs.
        val soa = ByteBuffer.allocate(2 * 72).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until 2) {            // pos
            soa.putFloat(i.toFloat()); soa.putFloat(0f); soa.putFloat(0f)
        }
        for (i in 0 until 2) {            // normal
            soa.putFloat(0f); soa.putFloat(0f); soa.putFloat(1f)
        }
        for (i in 0 until 2) {            // uv0
            soa.putFloat(0.1f * i); soa.putFloat(0f)
        }
        for (i in 0 until 2) {            // uv1
            soa.putFloat(0.3f * (i + 1)); soa.putFloat(0.5f)
        }
        for (i in 0 until 2) {            // color
            repeat(4) { soa.putFloat(1f) }
        }
        for (i in 0 until 2) {            // tangent
            soa.putFloat(0f); soa.putFloat(0f); soa.putFloat(-1f)
            soa.putFloat(-1f)
        }
        val soaMesh = MeshFactory.fromPayload(
            soa.array(), "unskinned_soa_uv1_tangent", null, null,
            MeshFactory.Topology.TRIANGLES, false, null)
        assertEquals(2, soaMesh.vertexCount)
        val s0 = record(soaMesh, 0)
        val s1 = record(soaMesh, 1)
        assertEquals(0.3f, s0[13], EPS)
        assertEquals(0.5f, s0[14], EPS)
        assertEquals(0.6f, s1[13], EPS)
        assertEquals(0.5f, s1[14], EPS)
    }

    @Test
    fun `skinned payload appends the joints and weights tail`() {
        // `skinned` wire record: [pos3 | normal3 | uv2 | color4 |
        // joints f32x4 | weights f32x4] (80 bytes) → 84-byte repack:
        // the 60-byte base + [joints u16x4 | weights f32x4].
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
        assertEquals(84, mesh.vertices.capacity())
        assertTrue(mesh.hasSkinning)
        // Joint ids arrive as whole-valued f32 and land as u16 — the
        // shader reads BONE_INDICES as uvec4.
        assertEquals(3, mesh.vertices.getShort(60).toInt() and 0xFFFF)
        assertEquals(5, mesh.vertices.getShort(62).toInt() and 0xFFFF)
        assertEquals(7, mesh.vertices.getShort(64).toInt() and 0xFFFF)
        assertEquals(9, mesh.vertices.getShort(66).toInt() and 0xFFFF)
        assertEquals(0.5f, mesh.vertices.getFloat(68), 0f)
        assertEquals(0.25f, mesh.vertices.getFloat(72), 0f)
        assertEquals(0.125f, mesh.vertices.getFloat(76), 0f)
        assertEquals(0.125f, mesh.vertices.getFloat(80), 0f)
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

    // Vertex `v`'s position triple.
    private fun vert(mesh: MeshFactory.MeshData, v: Int): FloatArray {
        val base = v * mesh.vertexStrideBytes
        return floatArrayOf(mesh.vertices.getFloat(base),
            mesh.vertices.getFloat(base + 4),
            mesh.vertices.getFloat(base + 8))
    }

    // The normal column of a record's packed tangent-frame quat —
    // the w<0 handedness channel doesn't change the rotation matrix.
    private fun normalOf(r: FloatArray): FloatArray {
        var x = r[3]; var y = r[4]; var z = r[5]; var w = r[6]
        if (w < 0f) { x = -x; y = -y; z = -z; w = -w }
        return floatArrayOf(
            2f * (x * z + w * y),
            2f * (y * z - w * x),
            1f - 2f * (x * x + y * y))
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
        assertEquals(vertexCount * 60, mesh.vertices.capacity())
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
