package com.jasonholtdigital.dart3d

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * `.fscene` geometry → Filament vertex/index data.
 *
 * Procedural generators are authored in native right-handed space and emit
 * `[position3 | tangent-frame-quaternion4 | uv0-2 | color4]` — the same
 * 13-float record upstream payload layouts decode to, so textured materials
 * bind identically on procedural and payload meshes.
 */
object MeshFactory {

    // Procedural verts: [pos3 | tangent-quat4 | uv2 | color4] — the
    // same 13-float record the payload path decodes, so textured
    // materials (UV0) and vertex-color variants bind on procedural
    // meshes the way they do on payload meshes.
    const val FLOATS_PER_VERTEX = 13
    const val PAYLOAD_FLOATS_PER_VERTEX = 13
    const val PROCEDURAL_VERTEX_STRIDE_BYTES = FLOATS_PER_VERTEX * 4
    const val PAYLOAD_VERTEX_STRIDE_BYTES = PAYLOAD_FLOATS_PER_VERTEX * 4
    // Skinned payload repack: the 52-byte base record plus
    // `[joints u16x4 | weights f32x4]` (8 + 16 bytes).
    const val PAYLOAD_SKINNED_VERTEX_STRIDE_BYTES =
        PAYLOAD_VERTEX_STRIDE_BYTES + 24

    enum class IndexWidth { UINT16, UINT32 }
    enum class Topology { TRIANGLES, TRIANGLE_STRIP, LINES, LINE_STRIP, POINTS }

    class PayloadDecodeException(message: String) : Exception(message)

    /**
     * Decoded `morphTargets` data for one geometry (W11). Filament's
     * `MorphTargetBuffer` consumes DELTAS for positions — the shader
     * does `p += Σ wᵢ·deltaᵢ` (gltfio hands it raw glTF deltas), which
     * is exactly upstream's `base + Σ wᵢ·(target−base)` normalized
     * morph — so `positions` stores the wire deltas verbatim (z
     * mirrored), `targetCount × vertexCount × 4` floats (Filament's
     * `setPositionsAt` consumes float4; w stays 0). `tangents` is
     * `targetCount × vertexCount × 4` signed-normalized shorts —
     * Filament's packed tangent-frame quats holding the ABSOLUTE
     * target frame (the shader extracts the target normal and adds
     * `w·(targetN − baseN)` itself) — present only when the spec
     * declares normal and/or tangent deltas on a layout whose base
     * carries a normal stream (`hasNormalDeltas || hasTangentDeltas`,
     * like upstream's MorphTargetData).
     */
    class MorphData(
        val targetCount: Int,
        val positions: FloatArray,
        val tangents: ShortArray?,
        val defaultWeights: FloatArray,
    )

    class MeshData(
        val vertices: ByteBuffer,   // direct, native-order floats
        val indices: ByteBuffer,    // direct, native-order uint16/uint32
        val vertexCount: Int,
        val indexCount: Int,
        val bounds: FloatArray,     // cx,cy,cz, hx,hy,hz
        val vertexStrideBytes: Int = PROCEDURAL_VERTEX_STRIDE_BYTES,
        val hasUvColor: Boolean = false,
        val indexWidth: IndexWidth = IndexWidth.UINT16,
        val topology: Topology = Topology.TRIANGLES,
        // True when `vertices` carries the `[joints u16x4 | weights
        // f32x4]` tail — the skinned repack. BONE_INDICES must be an
        // integer attribute (Filament reads it as uvec4), so the
        // wire's f32 joint ids are converted at decode.
        val hasSkinning: Boolean = false,
        var morph: MorphData? = null,
    )

    private enum class LayoutForm { INTERLEAVED, SOA, P3T4 }

    private data class LayoutInfo(
        val name: String,
        val strideBytes: Int,
        val form: LayoutForm,
        val hasTangents: Boolean,
        val skinned: Boolean,
    )

    private data class VertexFields(
        val px: Float, val py: Float, val pz: Float,
        val nx: Float, val ny: Float, val nz: Float,
        val u: Float, val v: Float,
        val r: Float, val g: Float, val b: Float, val a: Float,
        val tx: Float, val ty: Float, val tz: Float, val tw: Float,
        // JOINTS_0/WEIGHTS_0 — wire-f32 on the skinned layouts; null
        // when the layout carries neither.
        val joints: IntArray? = null,
        val weights: FloatArray? = null,
    )

    private fun layoutInfo(layout: String?): LayoutInfo = when (layout ?: "unskinned") {
        "unskinned_uv1_tangent" -> LayoutInfo(
            "unskinned_uv1_tangent", 72, LayoutForm.INTERLEAVED, true, false)
        "unskinned_soa_uv1_tangent" -> LayoutInfo(
            "unskinned_soa_uv1_tangent", 72, LayoutForm.SOA, true, false)
        "skinned_uv1_tangent" -> LayoutInfo(
            "skinned_uv1_tangent", 104, LayoutForm.INTERLEAVED, true, true)
        "unskinned" -> LayoutInfo(
            "unskinned", 48, LayoutForm.INTERLEAVED, false, false)
        "unskinned_soa" -> LayoutInfo(
            "unskinned_soa", 48, LayoutForm.SOA, false, false)
        "skinned" -> LayoutInfo(
            "skinned", 80, LayoutForm.INTERLEAVED, false, true)
        "p3t4" -> LayoutInfo("p3t4", 28, LayoutForm.P3T4, true, false)
        else -> throw PayloadDecodeException("unknown vertex layout '$layout'")
    }

    fun isSkinnedLayout(layout: String?): Boolean = layoutInfo(layout).skinned

    private val ZERO_JOINTS = IntArray(4)
    private val ZERO_WEIGHTS = FloatArray(4)

    /**
     * Decodes a `morphTargets` delta payload into Filament-shaped
     * target data. The wire stores target-major f32 delta slabs —
     * all position deltas, then normal deltas when `hasNormalDeltas`,
     * then tangent-xyz deltas when `hasTangentDeltas`. Filament's
     * position morphing is additive (`p += Σ wᵢ·deltaᵢ`), so the
     * position slab lands verbatim with z mirrored; tangents are
     * uploaded as ABSOLUTE target frames (`base + delta` quats)
     * because Filament's `morphNormal` re-deltas them against the
     * base normal internally — `n += w·(targetN − baseN)`.
     * Throws [PayloadDecodeException] when the payload is too short
     * for the declared slabs; the caller keeps the base mesh either
     * way.
     */
    fun morphDataFromPayload(
        deltaBytes: ByteArray,
        targetCount: Int,
        hasNormalDeltas: Boolean,
        hasTangentDeltas: Boolean,
        vertexBytes: ByteArray,
        layout: String?,
        defaultWeights: FloatArray,
    ): MorphData {
        val info = layoutInfo(layout)
        val count = vertexBytes.size / info.strideBytes
        val deltas = ByteBuffer.wrap(deltaBytes).order(ByteOrder.LITTLE_ENDIAN)
        val floatCount = deltaBytes.size / 4
        val slab = targetCount * count * 3
        val sections = 1 + (if (hasNormalDeltas) 1 else 0) +
            (if (hasTangentDeltas) 1 else 0)
        if (floatCount < slab * sections) {
            throw PayloadDecodeException(
                "morph delta payload has $floatCount floats; expected " +
                    "${slab * sections} for $targetCount targets")
        }
        val normalBase = slab
        val tangentBase = slab + if (hasNormalDeltas) slab else 0
        // p3t4 is already native space — its deltas land unmirrored
        // (iOS's `mirror = !decoded.nativeSpace`).
        val mirror = info.form != LayoutForm.P3T4
        // A tangent quat is only producible when a normal stream
        // exists — p3t4 carries positions + quats but no normals.
        val wantTangents = (hasNormalDeltas || hasTangentDeltas) &&
            info.form != LayoutForm.P3T4
        val positions = FloatArray(targetCount * count * 4)
        val tangents = if (wantTangents) {
            ShortArray(targetCount * count * 4)
        } else null
        val input = ByteBuffer.wrap(vertexBytes).order(ByteOrder.LITTLE_ENDIAN)
        for (v in 0 until count) {
            // Base normal/tangent in engine space — the same
            // conversions decodeUpstreamVertices applies to the vertex
            // buffer. Positions don't need the base: Filament's
            // morph shader re-adds it.
            val baseN: FloatArray
            val baseT: FloatArray
            if (info.form == LayoutForm.P3T4) {
                baseN = floatArrayOf(0f, 0f, -1f)
                baseT = floatArrayOf(1f, 0f, 0f, -1f)
            } else {
                val vf = readVertex(input, info, count, v)
                baseN = normalize(vf.nx, vf.ny, -vf.nz, 0f, 0f, -1f)
                baseT = if (info.hasTangents) {
                    floatArrayOf(vf.tx, vf.ty, -vf.tz, -vf.tw)
                } else {
                    floatArrayOf(1f, 0f, 0f, -1f)
                }
            }
            for (t in 0 until targetCount) {
                val d3 = (t * count + v) * 3
                val o4 = (t * count + v) * 4
                // Positions are raw deltas — Filament's morph shader
                // adds w·delta onto mesh_position itself.
                positions[o4] = deltas.getFloat(d3 * 4)
                positions[o4 + 1] = deltas.getFloat(d3 * 4 + 4)
                positions[o4 + 2] =
                    if (mirror) -deltas.getFloat(d3 * 4 + 8)
                    else deltas.getFloat(d3 * 4 + 8)
                positions[o4 + 3] = 0f
                if (tangents != null) {
                    var nx = baseN[0]; var ny = baseN[1]; var nz = baseN[2]
                    if (hasNormalDeltas) {
                        nx += deltas.getFloat((normalBase + d3) * 4)
                        ny += deltas.getFloat((normalBase + d3 + 1) * 4)
                        nz += if (mirror) {
                            -deltas.getFloat((normalBase + d3 + 2) * 4)
                        } else deltas.getFloat((normalBase + d3 + 2) * 4)
                    }
                    // Degenerate morphed normals keep the base's —
                    // the target frame then stays valid.
                    val nn = normalize(nx, ny, nz, baseN[0], baseN[1], baseN[2])
                    val t4 = baseT.copyOf()
                    if (hasTangentDeltas) {
                        // Tangent deltas are xyz slabs; the handedness
                        // w stays the base's (iOS rule).
                        t4[0] += deltas.getFloat((tangentBase + d3) * 4)
                        t4[1] += deltas.getFloat((tangentBase + d3 + 1) * 4)
                        t4[2] += if (mirror) {
                            -deltas.getFloat((tangentBase + d3 + 2) * 4)
                        } else deltas.getFloat((tangentBase + d3 + 2) * 4)
                    }
                    val q = tangentQuaternion(nn, t4)
                    for (c in 0 until 4) {
                        tangents[o4 + c] = (q[c].coerceIn(-1f, 1f)
                            * 32767f).roundToInt().toShort()
                    }
                }
            }
        }
        return MorphData(targetCount, positions, tangents, defaultWeights)
    }

    /**
     * Decodes one payload mesh. [wireBounds] is already converted to native
     * center/half-extents, or null to scan the decoded native positions.
     */
    fun fromPayload(
        vertexBytes: ByteArray,
        layout: String?,
        indexBytes: ByteArray?,
        indexFormat: String?,
        topology: Topology,
        swapTriangleWinding: Boolean,
        wireBounds: FloatArray?,
    ): MeshData {
        val info = layoutInfo(layout)
        if (vertexBytes.isEmpty() || vertexBytes.size % info.strideBytes != 0) {
            throw PayloadDecodeException(
                "layout '${info.name}' stride ${info.strideBytes} does not divide ${vertexBytes.size} bytes")
        }
        val vertexCount = vertexBytes.size / info.strideBytes
        val vertices = if (info.form == LayoutForm.P3T4) {
            // p3t4's wire record is [pos3 | quat4] in native space
            // (no z-mirror). Expand into the 52-byte record with
            // fabricated [0,0] uvs + white color — the same fills
            // iOS's decodeVertexPayload p3t4 branch appends.
            val input = ByteBuffer.wrap(vertexBytes)
                .order(ByteOrder.LITTLE_ENDIAN)
            ByteBuffer.allocateDirect(vertexCount * PAYLOAD_VERTEX_STRIDE_BYTES)
                .order(ByteOrder.nativeOrder()).also { out ->
                    for (i in 0 until vertexCount) {
                        val base = i * info.strideBytes
                        for (c in 0 until 7) {
                            out.putFloat(input.getFloat(base + c * 4))
                        }
                        out.putFloat(0f); out.putFloat(0f)
                        repeat(4) { out.putFloat(1f) }
                    }
                    out.flip()
                }
        } else {
            decodeUpstreamVertices(vertexBytes, info, vertexCount)
        }

        val suppliedIndices = indexBytes != null
        val indexWidth: IndexWidth
        val indices: IntArray
        if (suppliedIndices) {
            indexWidth = indexWidth(indexFormat)
            indices = indicesFromPayload(indexBytes!!, indexFormat)
        } else {
            indexWidth = if (vertexCount <= 0x10000) IndexWidth.UINT16 else IndexWidth.UINT32
            indices = IntArray(vertexCount) { it }
        }
        if (indices.isEmpty()) {
            throw PayloadDecodeException("index buffer is empty")
        }
        for (index in indices) {
            if (index < 0 || index >= vertexCount) {
                throw PayloadDecodeException(
                    "index $index is outside vertex count $vertexCount")
            }
        }
        if (swapTriangleWinding) {
            var i = 0
            while (i + 2 < indices.size) {
                val tmp = indices[i + 1]
                indices[i + 1] = indices[i + 2]
                indices[i + 2] = tmp
                i += 3
            }
        }

        val stride = when {
            info.form == LayoutForm.P3T4 -> PROCEDURAL_VERTEX_STRIDE_BYTES
            info.skinned -> PAYLOAD_SKINNED_VERTEX_STRIDE_BYTES
            else -> PAYLOAD_VERTEX_STRIDE_BYTES
        }
        val bounds = wireBounds?.copyOf() ?: scanBounds(vertices, vertexCount, stride)
        return MeshData(
            vertices = vertices,
            indices = indexBufferOf(indices, indexWidth),
            vertexCount = vertexCount,
            indexCount = indices.size,
            bounds = bounds,
            vertexStrideBytes = stride,
            hasUvColor = true,
            indexWidth = indexWidth,
            topology = topology,
            hasSkinning = info.skinned,
        )
    }

    /** Extracts native-space positions from a `vertexBuffer` payload. */
    fun positionsFromPayload(bytes: ByteArray, layout: String?): FloatArray {
        val info = layoutInfo(layout)
        if (bytes.isEmpty() || bytes.size % info.strideBytes != 0) {
            throw PayloadDecodeException(
                "layout '${info.name}' stride ${info.strideBytes} does not divide ${bytes.size} bytes")
        }
        val count = bytes.size / info.strideBytes
        val input = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val result = FloatArray(count * 3)
        for (i in 0 until count) {
            val base = if (info.form == LayoutForm.SOA) i * 12 else i * info.strideBytes
            result[i * 3] = input.getFloat(base)
            result[i * 3 + 1] = input.getFloat(base + 4)
            val z = input.getFloat(base + 8)
            result[i * 3 + 2] = if (info.form == LayoutForm.P3T4) z else -z
        }
        return result
    }

    fun indicesFromPayload(bytes: ByteArray, format: String?): IntArray {
        val width = indexWidth(format)
        val bytesPerIndex = if (width == IndexWidth.UINT16) 2 else 4
        if (bytes.isEmpty() || bytes.size % bytesPerIndex != 0) {
            throw PayloadDecodeException(
                "${format ?: "uint16"} index width does not divide ${bytes.size} bytes")
        }
        val input = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        return IntArray(bytes.size / bytesPerIndex) { i ->
            if (width == IndexWidth.UINT16) {
                input.getShort(i * 2).toInt() and 0xFFFF
            } else {
                val value = input.getInt(i * 4).toLong() and 0xFFFFFFFFL
                if (value > Int.MAX_VALUE) {
                    throw PayloadDecodeException("uint32 index $value exceeds the JVM/Jolt index range")
                }
                value.toInt()
            }
        }
    }

    private fun indexWidth(format: String?): IndexWidth = when (format ?: "uint16") {
        "uint16" -> IndexWidth.UINT16
        "uint32" -> IndexWidth.UINT32
        else -> throw PayloadDecodeException("unknown index format '$format'")
    }

    private fun decodeUpstreamVertices(
        bytes: ByteArray,
        info: LayoutInfo,
        count: Int,
    ): ByteBuffer {
        val stride = if (info.skinned) {
            PAYLOAD_SKINNED_VERTEX_STRIDE_BYTES
        } else {
            PAYLOAD_VERTEX_STRIDE_BYTES
        }
        val input = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val output = ByteBuffer.allocateDirect(count * stride)
            .order(ByteOrder.nativeOrder())
        for (i in 0 until count) {
            val v = readVertex(input, info, count, i)
            val normal = normalize(v.nx, v.ny, -v.nz, 0f, 0f, -1f)
            val tangent = if (info.hasTangents) {
                floatArrayOf(v.tx, v.ty, -v.tz, -v.tw)
            } else {
                // Legacy packUnskinned's neutral tangent is mirrored too.
                floatArrayOf(1f, 0f, 0f, -1f)
            }
            val q = tangentQuaternion(normal, tangent)
            output.putFloat(v.px)
            output.putFloat(v.py)
            output.putFloat(-v.pz)
            q.forEach { output.putFloat(it) }
            output.putFloat(v.u)
            output.putFloat(v.v)
            output.putFloat(v.r)
            output.putFloat(v.g)
            output.putFloat(v.b)
            output.putFloat(v.a)
            if (info.skinned) {
                // BONE_INDICES is an integer attribute (the shader
                // reads uvec4) — the wire's whole-valued f32s convert
                // to u16 here; BONE_WEIGHTS stays f32.
                val j = v.joints ?: ZERO_JOINTS
                for (b in 0 until 4) output.putShort(j[b].toShort())
                val w = v.weights ?: ZERO_WEIGHTS
                for (b in 0 until 4) output.putFloat(w[b])
            }
        }
        output.flip()
        return output
    }

    private fun readVertex(
        input: ByteBuffer,
        info: LayoutInfo,
        count: Int,
        i: Int,
    ): VertexFields {
        if (info.form == LayoutForm.SOA) {
            val pos = 0
            val normal = count * 3
            val uv0 = count * 6
            val color = if (info.hasTangents) count * 10 else count * 8
            val tangent = count * 14
            return VertexFields(
                f(input, pos + i * 3), f(input, pos + i * 3 + 1), f(input, pos + i * 3 + 2),
                f(input, normal + i * 3), f(input, normal + i * 3 + 1), f(input, normal + i * 3 + 2),
                f(input, uv0 + i * 2), f(input, uv0 + i * 2 + 1),
                f(input, color + i * 4), f(input, color + i * 4 + 1),
                f(input, color + i * 4 + 2), f(input, color + i * 4 + 3),
                if (info.hasTangents) f(input, tangent + i * 4) else 1f,
                if (info.hasTangents) f(input, tangent + i * 4 + 1) else 0f,
                if (info.hasTangents) f(input, tangent + i * 4 + 2) else 0f,
                if (info.hasTangents) f(input, tangent + i * 4 + 3) else 1f,
            )
        }
        val base = i * (info.strideBytes / 4)
        val color = if (info.hasTangents) base + 10 else base + 8
        val tangent = base + 14
        // Interleaved skinned layouts end with `[joints f32x4 |
        // weights f32x4]` — `skinned` at float offsets 12/16,
        // `skinned_uv1_tangent` at 18/22 (iOS FsceneRealizer.swift's
        // appendJoints/appendWeights offsets).
        val jointBase = if (info.skinned) {
            if (info.hasTangents) base + 18 else base + 12
        } else -1
        return VertexFields(
            f(input, base), f(input, base + 1), f(input, base + 2),
            f(input, base + 3), f(input, base + 4), f(input, base + 5),
            f(input, base + 6), f(input, base + 7),
            f(input, color), f(input, color + 1), f(input, color + 2), f(input, color + 3),
            if (info.hasTangents) f(input, tangent) else 1f,
            if (info.hasTangents) f(input, tangent + 1) else 0f,
            if (info.hasTangents) f(input, tangent + 2) else 0f,
            if (info.hasTangents) f(input, tangent + 3) else 1f,
            joints = if (jointBase >= 0) IntArray(4) {
                // Whole-valued f32s → integer indices; iOS clamps
                // negatives away and rounds (appendJoints).
                f(input, jointBase + it).roundToInt().coerceIn(0, 0xFFFF)
            } else null,
            weights = if (jointBase >= 0) FloatArray(4) {
                f(input, jointBase + 4 + it)
            } else null,
        )
    }

    private fun f(input: ByteBuffer, floatOffset: Int): Float =
        input.getFloat(floatOffset * 4)

    private fun tangentQuaternion(normal: FloatArray, tangent4: FloatArray): FloatArray {
        var tx = tangent4[0]
        var ty = tangent4[1]
        var tz = tangent4[2]
        val dot = tx * normal[0] + ty * normal[1] + tz * normal[2]
        tx -= dot * normal[0]
        ty -= dot * normal[1]
        tz -= dot * normal[2]
        var length = sqrt(tx * tx + ty * ty + tz * tz)
        if (!length.isFinite() || length < 1e-8f) {
            val ax = if (abs(normal[0]) < 0.9f) 1f else 0f
            val ay = if (ax == 0f) 1f else 0f
            val axisDot = ax * normal[0] + ay * normal[1]
            tx = ax - axisDot * normal[0]
            ty = ay - axisDot * normal[1]
            tz = -axisDot * normal[2]
            length = sqrt(tx * tx + ty * ty + tz * tz)
        }
        tx /= length; ty /= length; tz /= length

        // Contract convention: b = handedness * (n × t). The z-mirror has
        // already negated handedness in tangent4.w.
        val handedness = if (tangent4[3] < 0f) -1f else 1f
        val bx = handedness * (normal[1] * tz - normal[2] * ty)
        val by = handedness * (normal[2] * tx - normal[0] * tz)
        val bz = handedness * (normal[0] * ty - normal[1] * tx)
        return packTangentFrame(
            tx, ty, tz, bx, by, bz, normal[0], normal[1], normal[2])
    }

    private fun normalize(
        x: Float, y: Float, z: Float,
        fallbackX: Float, fallbackY: Float, fallbackZ: Float,
    ): FloatArray {
        val length = sqrt(x * x + y * y + z * z)
        return if (length.isFinite() && length >= 1e-8f) {
            floatArrayOf(x / length, y / length, z / length)
        } else {
            floatArrayOf(fallbackX, fallbackY, fallbackZ)
        }
    }

    private fun bufferOf(variants: List<Float>): ByteBuffer =
        ByteBuffer.allocateDirect(variants.size * 4)
            .order(ByteOrder.nativeOrder()).also { buf ->
                variants.forEach { buf.putFloat(it) }
                buf.flip()
            }

    private fun indexBufferOf(indices: List<Int>): ByteBuffer =
        indexBufferOf(indices.toIntArray(), IndexWidth.UINT16)

    private fun indexBufferOf(indices: IntArray, width: IndexWidth): ByteBuffer {
        val bytesPerIndex = if (width == IndexWidth.UINT16) 2 else 4
        return ByteBuffer.allocateDirect(indices.size * bytesPerIndex)
            .order(ByteOrder.nativeOrder()).also { buf ->
                if (width == IndexWidth.UINT16) {
                    indices.forEach { buf.putShort(it.toShort()) }
                } else {
                    indices.forEach { buf.putInt(it) }
                }
                buf.flip()
            }
    }

    private fun scanBounds(vertices: ByteBuffer, count: Int, stride: Int): FloatArray {
        var minX = Float.POSITIVE_INFINITY
        var minY = Float.POSITIVE_INFINITY
        var minZ = Float.POSITIVE_INFINITY
        var maxX = Float.NEGATIVE_INFINITY
        var maxY = Float.NEGATIVE_INFINITY
        var maxZ = Float.NEGATIVE_INFINITY
        for (i in 0 until count) {
            val base = i * stride
            val x = vertices.getFloat(base)
            val y = vertices.getFloat(base + 4)
            val z = vertices.getFloat(base + 8)
            minX = minOf(minX, x); minY = minOf(minY, y); minZ = minOf(minZ, z)
            maxX = maxOf(maxX, x); maxY = maxOf(maxY, y); maxZ = maxOf(maxZ, z)
        }
        return floatArrayOf(
            (minX + maxX) * 0.5f,
            (minY + maxY) * 0.5f,
            (minZ + maxZ) * 0.5f,
            (maxX - minX) * 0.5f,
            (maxY - minY) * 0.5f,
            (maxZ - minZ) * 0.5f,
        )
    }

    /**
     * Packs basis columns into Filament's tangent quaternion. Filament's
     * `mat3::packTangentFrame` canonicalizes the rotation quaternion to
     * positive W, then negates it for reflected frames; shader decoding uses
     * the W sign as the bitangent flip. Keep W non-zero for that sign channel.
     */
    private fun packTangentFrame(
        tx: Float, ty: Float, tz: Float,
        bx: Float, by: Float, bz: Float,
        nx: Float, ny: Float, nz: Float,
    ): FloatArray {
        val cx = ty * bz - tz * by
        val cy = tz * bx - tx * bz
        val cz = tx * by - ty * bx
        val reflected = cx * nx + cy * ny + cz * nz < 0f
        val rbX = if (reflected) -bx else bx
        val rbY = if (reflected) -by else by
        val rbZ = if (reflected) -bz else bz

        // Column-major 3×3 with columns t, adjusted-b, n.
        val m00 = tx; val m01 = rbX; val m02 = nx
        val m10 = ty; val m11 = rbY; val m12 = ny
        val m20 = tz; val m21 = rbZ; val m22 = nz
        val trace = m00 + m11 + m22
        val q = FloatArray(4)
        if (trace > 0f) {
            val s = sqrt(trace + 1f) * 2f
            q[3] = 0.25f * s
            q[0] = (m21 - m12) / s
            q[1] = (m02 - m20) / s
            q[2] = (m10 - m01) / s
        } else if (m00 > m11 && m00 > m22) {
            val s = sqrt(1f + m00 - m11 - m22) * 2f
            q[3] = (m21 - m12) / s
            q[0] = 0.25f * s
            q[1] = (m01 + m10) / s
            q[2] = (m02 + m20) / s
        } else if (m11 > m22) {
            val s = sqrt(1f + m11 - m00 - m22) * 2f
            q[3] = (m02 - m20) / s
            q[0] = (m01 + m10) / s
            q[1] = 0.25f * s
            q[2] = (m12 + m21) / s
        } else {
            val s = sqrt(1f + m22 - m00 - m11) * 2f
            q[3] = (m10 - m01) / s
            q[0] = (m02 + m20) / s
            q[1] = (m12 + m21) / s
            q[2] = 0.25f * s
        }
        val qLength = sqrt(q.sumOf { (it * it).toDouble() }).toFloat()
        for (i in q.indices) q[i] /= qLength
        if (q[3] < 0f) for (i in q.indices) q[i] = -q[i]
        val bias = 1f / Int.MAX_VALUE.toFloat()
        if (q[3] < bias) {
            q[3] = bias
            val xyzLength = sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2])
            val target = sqrt(1f - bias * bias)
            if (xyzLength > 0f) {
                val scale = target / xyzLength
                q[0] *= scale; q[1] *= scale; q[2] *= scale
            }
        }
        if (reflected) for (i in q.indices) q[i] = -q[i]
        return q
    }

    fun cuboid(ex: Float, ey: Float, ez: Float): MeshData {
        val hx = ex / 2; val hy = ey / 2; val hz = ez / 2
        val verts = ArrayList<Float>()
        val idx = ArrayList<Int>()
        // Each face: normal n, tangent t, bitangent b, 4 corners.
        // Winding is counter-clockwise looking at the face from outside.
        data class F(
            val n: FloatArray, val t: FloatArray, val b: FloatArray,
            val c: FloatArray,
        )
        val faces = listOf(
            F(floatArrayOf(0f, 0f, 1f), floatArrayOf(1f, 0f, 0f), floatArrayOf(0f, 1f, 0f), floatArrayOf(0f, 0f, hz)),
            F(floatArrayOf(0f, 0f, -1f), floatArrayOf(-1f, 0f, 0f), floatArrayOf(0f, 1f, 0f), floatArrayOf(0f, 0f, -hz)),
            F(floatArrayOf(1f, 0f, 0f), floatArrayOf(0f, 0f, -1f), floatArrayOf(0f, 1f, 0f), floatArrayOf(hx, 0f, 0f)),
            F(floatArrayOf(-1f, 0f, 0f), floatArrayOf(0f, 0f, 1f), floatArrayOf(0f, 1f, 0f), floatArrayOf(-hx, 0f, 0f)),
            F(floatArrayOf(0f, 1f, 0f), floatArrayOf(1f, 0f, 0f), floatArrayOf(0f, 0f, -1f), floatArrayOf(0f, hy, 0f)),
            F(floatArrayOf(0f, -1f, 0f), floatArrayOf(1f, 0f, 0f), floatArrayOf(0f, 0f, 1f), floatArrayOf(0f, -hy, 0f)),
        )
        val extents = floatArrayOf(hx, hy, hz)
        for ((fi, f) in faces.withIndex()) {
            val q = packTangentFrame(
                f.t[0], f.t[1], f.t[2],
                f.b[0], f.b[1], f.b[2],
                f.n[0], f.n[1], f.n[2],
            )
            val base = fi * 4
            for (ci in 0..3) {
                val su = if (ci == 1 || ci == 2) 1f else -1f
                val sv = if (ci >= 2) 1f else -1f
                val eu = extents[0] * abs(f.t[0]) +
                    extents[1] * abs(f.t[1]) + extents[2] * abs(f.t[2])
                val ev = extents[0] * abs(f.b[0]) +
                    extents[1] * abs(f.b[1]) + extents[2] * abs(f.b[2])
                verts.add(f.c[0] + f.t[0] * su * eu + f.b[0] * sv * ev)
                verts.add(f.c[1] + f.t[1] * su * eu + f.b[1] * sv * ev)
                verts.add(f.c[2] + f.t[2] * su * eu + f.b[2] * sv * ev)
                verts.addAll(q.toList())
                // Per-face [0,1]² UVs — SCNBox maps each face the
                // same way; white vertex color = neutral.
                verts.add((su + 1f) / 2f); verts.add((sv + 1f) / 2f)
                for (k in 0 until 4) verts.add(1f)
            }
            idx.addAll(listOf(base, base + 1, base + 2, base, base + 2, base + 3))
        }
        return MeshData(
            bufferOf(verts), indexBufferOf(idx),
            verts.size / FLOATS_PER_VERTEX, idx.size,
            floatArrayOf(0f, 0f, 0f, hx, hy, hz),
            hasUvColor = true,
        )
    }

    fun sphere(radius: Float, rings: Int = 16, sectors: Int = 24): MeshData {
        val verts = ArrayList<Float>()
        val idx = ArrayList<Int>()
        for (r in 0..rings) {
            val v = r.toFloat() / rings
            val phi = v * PI.toFloat()
            val sp = sin(phi); val cp = cos(phi)
            for (s in 0..sectors) {
                val u = s.toFloat() / sectors
                val theta = u * 2f * PI.toFloat()
                val st = sin(theta); val ct = cos(theta)
                val nx = sp * ct; val ny = cp; val nz = sp * st
                verts.add(radius * nx); verts.add(radius * ny); verts.add(radius * nz)
                val tx = -st; val ty = 0f; val tz = ct
                val bx = ny * tz - nz * ty
                val by = nz * tx - nx * tz
                val bz = nx * ty - ny * tx
                verts.addAll(
                    packTangentFrame(tx, ty, tz, bx, by, bz, nx, ny, nz).toList()
                )
                // Spherical UVs — u along the sector, v down the ring
                // (SCNSphere convention); white vertex color.
                verts.add(u); verts.add(v)
                for (k in 0 until 4) verts.add(1f)
            }
        }
        for (r in 0 until rings) {
            for (s in 0 until sectors) {
                val a = r * (sectors + 1) + s
                val b = a + sectors + 1
                idx.addAll(listOf(a, b, a + 1, b, b + 1, a + 1))
            }
        }
        return MeshData(
            bufferOf(verts), indexBufferOf(idx),
            verts.size / FLOATS_PER_VERTEX, idx.size,
            floatArrayOf(0f, 0f, 0f, radius, radius, radius),
            hasUvColor = true,
        )
    }

    /** XY plane facing +Z (parity with `SCNPlane`). */
    fun plane(width: Float, height: Float): MeshData {
        val hx = width / 2; val hy = height / 2
        val q = packTangentFrame(1f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 1f)
        val verts = ArrayList<Float>()
        val corners = listOf(
            floatArrayOf(-hx, -hy, 0f), floatArrayOf(hx, -hy, 0f),
            floatArrayOf(hx, hy, 0f), floatArrayOf(-hx, hy, 0f),
        )
        val uvs = listOf(
            floatArrayOf(0f, 0f), floatArrayOf(1f, 0f),
            floatArrayOf(1f, 1f), floatArrayOf(0f, 1f),
        )
        for (i in corners.indices) {
            verts.addAll(corners[i].toList()); verts.addAll(q.toList())
            verts.addAll(uvs[i].toList())
            for (k in 0 until 4) verts.add(1f)
        }
        val idx = listOf(0, 1, 2, 0, 2, 3)
        return MeshData(
            bufferOf(verts), indexBufferOf(idx), 4, idx.size,
            floatArrayOf(0f, 0f, 0f, hx, hy, 0f),
            hasUvColor = true,
        )
    }

    fun torus(ringR: Float, tubeR: Float, rings: Int = 32, sectors: Int = 16): MeshData {
        val verts = ArrayList<Float>()
        val idx = ArrayList<Int>()
        for (r in 0..rings) {
            val u = r.toFloat() / rings * 2f * PI.toFloat()
            val cu = cos(u); val su = sin(u)
            for (s in 0..sectors) {
                val v = s.toFloat() / sectors * 2f * PI.toFloat()
                val cv = cos(v); val sv = sin(v)
                val nx = cu * cv; val ny = sv; val nz = su * cv
                verts.add((ringR + tubeR * cv) * cu)
                verts.add(tubeR * sv)
                verts.add((ringR + tubeR * cv) * su)
                val tx = -su; val ty = 0f; val tz = cu
                val bx = ny * tz - nz * ty
                val by = nz * tx - nx * tz
                val bz = nx * ty - ny * tx
                verts.addAll(
                    packTangentFrame(tx, ty, tz, bx, by, bz, nx, ny, nz).toList()
                )
                // u around the ring, v along the tube; white color.
                verts.add(u / (2f * PI.toFloat()))
                verts.add(v / (2f * PI.toFloat()))
                for (k in 0 until 4) verts.add(1f)
            }
        }
        for (r in 0 until rings) {
            for (s in 0 until sectors) {
                val a = r * (sectors + 1) + s
                val b = a + sectors + 1
                idx.addAll(listOf(a, b, a + 1, b, b + 1, a + 1))
            }
        }
        return MeshData(
            bufferOf(verts), indexBufferOf(idx),
            verts.size / FLOATS_PER_VERTEX, idx.size,
            floatArrayOf(0f, 0f, 0f, ringR + tubeR, tubeR, ringR + tubeR),
            hasUvColor = true,
        )
    }
}
