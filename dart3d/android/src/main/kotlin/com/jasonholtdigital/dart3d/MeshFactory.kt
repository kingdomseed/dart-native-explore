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
 * `[position3 | tangent-frame-quaternion4 | uv0-2 | color4 | uv1-2]` — the
 * same 15-float record upstream payload layouts decode to, so textured
 * materials bind identically on procedural and payload meshes. uv1 rides
 * the record's tail (W21: `texCoord` selects the UV set per texture
 * slot); wire layouts without a second UV channel zero-fill it, matching
 * upstream's `pack*` fills.
 */
object MeshFactory {

    // Procedural verts: [pos3 | tangent-quat4 | uv0-2 | color4 | uv1-2]
    // — the same 15-float record the payload path decodes, so textured
    // materials (UV0/UV1) and vertex-color variants bind on procedural
    // meshes the way they do on payload meshes.
    const val FLOATS_PER_VERTEX = 15
    const val PAYLOAD_FLOATS_PER_VERTEX = 15
    const val PROCEDURAL_VERTEX_STRIDE_BYTES = FLOATS_PER_VERTEX * 4
    const val PAYLOAD_VERTEX_STRIDE_BYTES = PAYLOAD_FLOATS_PER_VERTEX * 4
    // Skinned payload repack: the 60-byte base record plus
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
        // Wire layouts carrying a TEXCOORD_1 channel (`*_uv1_tangent`).
        // Absent → the decoded record's uv1 tail is zero-filled.
        val hasUv1: Boolean = false,
    )

    private data class VertexFields(
        val px: Float, val py: Float, val pz: Float,
        val nx: Float, val ny: Float, val nz: Float,
        val u: Float, val v: Float,
        val r: Float, val g: Float, val b: Float, val a: Float,
        val tx: Float, val ty: Float, val tz: Float, val tw: Float,
        // TEXCOORD_1 — only the `*_uv1_tangent` layouts carry it.
        val u1: Float = 0f, val v1: Float = 0f,
        // JOINTS_0/WEIGHTS_0 — wire-f32 on the skinned layouts; null
        // when the layout carries neither.
        val joints: IntArray? = null,
        val weights: FloatArray? = null,
    )

    private fun layoutInfo(layout: String?): LayoutInfo = when (layout ?: "unskinned") {
        "unskinned_uv1_tangent" -> LayoutInfo(
            "unskinned_uv1_tangent", 72, LayoutForm.INTERLEAVED, true,
            false, hasUv1 = true)
        "unskinned_soa_uv1_tangent" -> LayoutInfo(
            "unskinned_soa_uv1_tangent", 72, LayoutForm.SOA, true,
            false, hasUv1 = true)
        "skinned_uv1_tangent" -> LayoutInfo(
            "skinned_uv1_tangent", 104, LayoutForm.INTERLEAVED, true,
            true, hasUv1 = true)
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
            // (no z-mirror). Expand into the 60-byte record with
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
                        out.putFloat(0f); out.putFloat(0f)   // uv0
                        repeat(4) { out.putFloat(1f) }       // color
                        out.putFloat(0f); out.putFloat(0f)   // uv1
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
            // uv1 tails the base record — zero when the wire layout
            // lacks a second UV channel (upstream's pack* fill).
            output.putFloat(v.u1)
            output.putFloat(v.v1)
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
            // `unskinned_soa_uv1_tangent` slabs: pos|n|uv0|uv1|color|tan
            val uv1 = count * 8
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
                u1 = if (info.hasUv1) f(input, uv1 + i * 2) else 0f,
                v1 = if (info.hasUv1) f(input, uv1 + i * 2 + 1) else 0f,
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
            // Interleaved uv1 sits between uv0 and color (floats 8-9)
            // on the *_uv1_tangent layouts; zero otherwise.
            u1 = if (info.hasUv1) f(input, base + 8) else 0f,
            v1 = if (info.hasUv1) f(input, base + 9) else 0f,
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

    /** A box — 24 vertices (four per face so normals stay
     *  axis-aligned), proc.dart's buildCuboid corner order and UVs.
     *  [debugColors] keys each vertex color to its corner sign bits
     *  (the d3 debug mode — a centered box gets the eight corners
     *  black/red/green/yellow/blue/magenta/cyan/white). */
    fun cuboid(
        ex: Float, ey: Float, ez: Float, debugColors: Boolean = false,
    ): MeshData {
        val hx = ex / 2; val hy = ey / 2; val hz = ez / 2
        val b = ProcBuilder()
        fun color(v: V3): FloatArray = if (debugColors) floatArrayOf(
            if (v.x >= 0f) 1f else 0f,
            if (v.y >= 0f) 1f else 0f,
            if (v.z >= 0f) 1f else 0f, 1f)
        else WHITE4
        fun face(n: V3, v0: V3, v1: V3, v2: V3, v3: V3) {
            val base = b.vertexCount
            var c = color(v0)
            b.emit(v0, n, 0f, 1f, c[0], c[1], c[2], c[3])
            c = color(v1)
            b.emit(v1, n, 1f, 1f, c[0], c[1], c[2], c[3])
            c = color(v2)
            b.emit(v2, n, 0f, 0f, c[0], c[1], c[2], c[3])
            c = color(v3)
            b.emit(v3, n, 1f, 0f, c[0], c[1], c[2], c[3])
            b.quad(base, base + 1, base + 2, base + 3)
        }
        face(V3(0f, 0f, 1f),
            V3(-hx, -hy, hz), V3(hx, -hy, hz),
            V3(-hx, hy, hz), V3(hx, hy, hz))
        face(V3(0f, 0f, -1f),
            V3(hx, -hy, -hz), V3(-hx, -hy, -hz),
            V3(hx, hy, -hz), V3(-hx, hy, -hz))
        face(V3(1f, 0f, 0f),
            V3(hx, -hy, hz), V3(hx, -hy, -hz),
            V3(hx, hy, hz), V3(hx, hy, -hz))
        face(V3(-1f, 0f, 0f),
            V3(-hx, -hy, -hz), V3(-hx, -hy, hz),
            V3(-hx, hy, -hz), V3(-hx, hy, hz))
        face(V3(0f, 1f, 0f),
            V3(-hx, hy, hz), V3(hx, hy, hz),
            V3(-hx, hy, -hz), V3(hx, hy, -hz))
        face(V3(0f, -1f, 0f),
            V3(hx, -hy, -hz), V3(-hx, -hy, -hz),
            V3(-hx, -hy, hz), V3(hx, -hy, hz))
        return b.build(floatArrayOf(0f, 0f, 0f, hx, hy, hz))
    }

    /** A UV sphere — proc.dart's buildSphere: `segments` around the
     *  equator, `rings` pole to pole, outward winding (the previous
     *  transposed index order faced inward). The tangent is the
     *  analytic ∂pos/∂u — UV-aligned like GeometryFactory.swift's. */
    fun sphere(radius: Float, segments: Int = 32, rings: Int = 16): MeshData {
        val seg = maxOf(1, segments); val rgs = maxOf(1, rings)
        val verts = ArrayList<Float>()
        val idx = ArrayList<Int>()
        for (r in 0..rgs) {
            val v = r.toFloat() / rgs
            val phi = v * PI.toFloat()
            val sp = sin(phi); val cp = cos(phi)
            for (s in 0..seg) {
                val u = s.toFloat() / seg
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
                // Spherical UVs — u along the segment, v down the
                // ring; white vertex color; no uv1.
                verts.add(u); verts.add(v)
                for (k in 0 until 4) verts.add(1f)
                verts.add(0f); verts.add(0f)
            }
        }
        for (r in 0 until rgs) {
            for (s in 0 until seg) {
                val a = r * (seg + 1) + s
                val b = a + seg + 1
                // quad(a, a+1, a+cols, a+cols+1) — outward.
                idx.addAll(listOf(a, a + 1, b, a + 1, b + 1, b))
            }
        }
        return MeshData(
            bufferOf(verts), indexBufferOf(idx),
            verts.size / FLOATS_PER_VERTEX, idx.size,
            floatArrayOf(0f, 0f, 0f, radius, radius, radius),
            hasUvColor = true,
        )
    }

    /** An XZ grid plane facing +Y — the wire contract (proc.dart's
     *  buildPlane): `width` spans X, `depth` spans Z, `segmentsX` ×
     *  `segmentsZ` cells, winding wound so the geometric normal
     *  agrees with the +Y attribute normal. The tangent frame is the
     *  UV-aligned (+X, +Z) pair — the reflected-frame w<0 encoding. */
    fun plane(
        width: Float, depth: Float,
        segmentsX: Int = 1, segmentsZ: Int = 1,
    ): MeshData {
        val sx = maxOf(1, segmentsX); val sz = maxOf(1, segmentsZ)
        val b = ProcBuilder()
        val n = V3(0f, 1f, 0f)
        for (z in 0..sz) {
            for (x in 0..sx) {
                b.emit(
                    V3((x.toFloat() / sx - 0.5f) * width, 0f,
                        (z.toFloat() / sz - 0.5f) * depth),
                    n, x.toFloat() / sx, z.toFloat() / sz,
                    t = V3(1f, 0f, 0f), w = -1f)
            }
        }
        val cols = sx + 1
        for (z in 0 until sz) {
            for (x in 0 until sx) {
                val a = z * cols + x
                // quad(a, a+cols, a+1, a+cols+1) — the +Y order.
                b.quad(a, a + cols, a + 1, a + cols + 1)
            }
        }
        return b.build(floatArrayOf(0f, 0f, 0f, width / 2, 0f, depth / 2))
    }

    /** A torus around Y — proc.dart's buildTorus: `rings` (the wire's
     *  `radialSegments`) around the main ring, `sectors`
     *  (`tubularSegments`) around the tube; uv = (v-tube, u-ring)
     *  matching the Dart emit order, outward winding, and the
     *  UV-aligned ∂pos/∂v tangent. */
    fun torus(ringR: Float, tubeR: Float, rings: Int = 32, sectors: Int = 16): MeshData {
        val rg = maxOf(1, rings); val sc = maxOf(1, sectors)
        val verts = ArrayList<Float>()
        val idx = ArrayList<Int>()
        for (r in 0..rg) {
            val u = r.toFloat() / rg * 2f * PI.toFloat()
            val cu = cos(u); val su = sin(u)
            for (s in 0..sc) {
                val v = s.toFloat() / sc * 2f * PI.toFloat()
                val cv = cos(v); val sv = sin(v)
                val nx = cu * cv; val ny = sv; val nz = su * cv
                verts.add((ringR + tubeR * cv) * cu)
                verts.add(tubeR * sv)
                verts.add((ringR + tubeR * cv) * su)
                // The uv.x gradient runs around the tube — the
                // tangent is ∂pos/∂v; n×t lands on the ring direction.
                val tx = -sv * cu; val ty = cv; val tz = -sv * su
                val bx = ny * tz - nz * ty
                val by = nz * tx - nx * tz
                val bz = nx * ty - ny * tx
                verts.addAll(
                    packTangentFrame(tx, ty, tz, bx, by, bz, nx, ny, nz).toList()
                )
                // uv = (v-frac, u-frac) — Dart emits
                // (j/tubularSegments, i/radialSegments).
                verts.add(v / (2f * PI.toFloat()))
                verts.add(u / (2f * PI.toFloat()))
                for (k in 0 until 4) verts.add(1f)
                verts.add(0f); verts.add(0f)
            }
        }
        for (r in 0 until rg) {
            for (s in 0 until sc) {
                val a = r * (sc + 1) + s
                val b = a + sc + 1
                idx.addAll(listOf(a, a + 1, b, a + 1, b + 1, b))
            }
        }
        return MeshData(
            bufferOf(verts), indexBufferOf(idx),
            verts.size / FLOATS_PER_VERTEX, idx.size,
            floatArrayOf(0f, 0f, 0f, ringR + tubeR, tubeR, ringR + tubeR),
            hasUvColor = true,
        )
    }

    // ------------------------------------------------------------------
    // W26: expanded procedural vocabulary — the `d3:procMesh` /
    // `d3:instances` shapes. Generators mirror proc.dart's build*
    // functions and emit the same 15-float record the payload path
    // decodes, so textured/vertex-color materials bind identically.
    // Point-driven shapes take native-space (z-mirrored) points —
    // the decoders convert at the wire boundary like every other
    // vertex source.
    // ------------------------------------------------------------------

    /** Minimal float3 for the W26 generators — the decoders build
     *  point lists in native space. */
    data class V3(var x: Float, var y: Float, var z: Float) {
        operator fun plus(o: V3) = V3(x + o.x, y + o.y, z + o.z)
        operator fun minus(o: V3) = V3(x - o.x, y - o.y, z - o.z)
        operator fun times(s: Float) = V3(x * s, y * s, z * s)
        fun dot(o: V3) = x * o.x + y * o.y + z * o.z
        fun cross(o: V3) = V3(
            y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x)
        val length2 get() = x * x + y * y + z * z
        val length get() = sqrt(length2)
        fun normalized(fallback: V3 = V3(0f, 0f, 1f)): V3 {
            val l = length
            return if (l.isFinite() && l > 1e-8f) V3(x / l, y / l, z / l)
            else fallback
        }
    }

    /** Accumulates 15-float records + triangles into a [MeshData]. */
    private class ProcBuilder {
        val verts = ArrayList<Float>()
        val idx = ArrayList<Int>()
        val vertexCount get() = verts.size / FLOATS_PER_VERTEX

        /** Emits a vertex; the tangent frame is synthesized from the
         *  normal when [t] is null (perpendicular pick). [w] is the
         *  bitangent handedness — a −1 flips the derived bitangent so
         *  UV-aligned frames can mark the reflected case. */
        fun emit(
            p: V3, n: V3, u: Float, v: Float,
            r: Float = 1f, g: Float = 1f, b: Float = 1f, a: Float = 1f,
            t: V3? = null, w: Float = 1f,
        ): Int {
            val i = vertexCount
            var tan = t
            if (tan == null || tan.length2 < 1e-12f) {
                val axis = if (abs(n.x) < 0.9f) V3(1f, 0f, 0f)
                    else V3(0f, 1f, 0f)
                tan = n.cross(axis).normalized(V3(1f, 0f, 0f))
            }
            val bit = (n.cross(tan) * w).normalized()
            val q = packTangentFrame(
                tan.x, tan.y, tan.z, bit.x, bit.y, bit.z, n.x, n.y, n.z)
            verts.add(p.x); verts.add(p.y); verts.add(p.z)
            verts.addAll(q.toList())
            verts.add(u); verts.add(v)
            verts.add(r); verts.add(g); verts.add(b); verts.add(a)
            verts.add(0f); verts.add(0f)
            return i
        }

        fun tri(a: Int, b: Int, c: Int) { idx.add(a); idx.add(b); idx.add(c) }
        fun quad(a: Int, b: Int, c: Int, d: Int) {
            tri(a, b, c); tri(b, d, c)
        }

        fun build(
            bounds: FloatArray? = null,
            topology: Topology = Topology.TRIANGLES,
        ): MeshData {
            val vc = vertexCount
            val width = if (vc <= 0x10000) IndexWidth.UINT16 else IndexWidth.UINT32
            val vb = bufferOf(verts)
            val b = bounds ?: scanBounds(vb, vc, PROCEDURAL_VERTEX_STRIDE_BYTES)
            vb.rewind()
            return MeshData(
                vb, indexBufferOf(idx.toIntArray(), width),
                vc, idx.size, b,
                hasUvColor = true, indexWidth = width, topology = topology)
        }
    }

    /** A cylinder/cone along Y with optional end caps — mirrors
     *  proc.dart's buildCylinder (sloped side normals, apex-fan
     *  handling, flip-wound bottom cap). */
    fun cylinder(
        bottomRadius: Float, topRadius: Float, height: Float,
        radialSegments: Int, heightSegments: Int,
        bottomCap: Boolean, topCap: Boolean,
    ): MeshData {
        val b = ProcBuilder()
        val slopeY = bottomRadius - topRadius
        val columns = radialSegments + 1
        for (r in 0..heightSegments) {
            val t = r.toFloat() / heightSegments
            val y = height / 2 - height * t
            val radius = topRadius + (bottomRadius - topRadius) * t
            for (s in 0..radialSegments) {
                val theta = (2 * PI * s / radialSegments).toFloat()
                val cos = cos(theta); val sin = sin(theta)
                val n = V3(height * cos, slopeY, height * sin).normalized()
                b.emit(
                    V3(radius * cos, y, radius * sin), n,
                    s.toFloat() / radialSegments, t)
            }
        }
        for (r in 0 until heightSegments) {
            val topApex = r == 0 && topRadius == 0f
            val bottomApex = r + 1 == heightSegments && bottomRadius == 0f
            for (s in 0 until radialSegments) {
                val a = r * columns + s
                val bv = a + 1
                val c = a + columns
                val d = c + 1
                if (!topApex) b.tri(a, bv, c)
                if (!bottomApex) b.tri(bv, d, c)
            }
        }

        fun addCap(y: Float, radius: Float, ny: Float, flip: Boolean) {
            if (radius <= 0f) return
            val n = V3(0f, ny, 0f)
            val center = b.emit(V3(0f, y, 0f), n, 0.5f, 0.5f)
            val rimBase = b.vertexCount
            for (s in 0..radialSegments) {
                val theta = (2 * PI * s / radialSegments).toFloat()
                val cos = cos(theta); val sin = sin(theta)
                b.emit(V3(radius * cos, y, radius * sin), n,
                    0.5f + 0.5f * cos, 0.5f + 0.5f * sin)
            }
            for (s in 0 until radialSegments) {
                val r0 = rimBase + s
                val r1 = rimBase + s + 1
                if (flip) b.tri(center, r0, r1) else b.tri(center, r1, r0)
            }
        }

        if (bottomCap) addCap(-height / 2, bottomRadius, -1f, flip = true)
        if (topCap) addCap(height / 2, topRadius, 1f, flip = false)
        return b.build()
    }

    /** A capsule along Y — mirrors proc.dart's buildCapsule:
     *  hemisphere rings sharing the mid-section equators. */
    fun capsule(
        radius: Float, height: Float,
        radialSegments: Int, capRings: Int,
    ): MeshData {
        val halfH = height / 2
        data class Ring(val posY: Float, val posR: Float,
                        val normY: Float, val normR: Float)
        val rings = ArrayList<Ring>()
        for (r in 0..capRings) {
            val phi = (PI / 2) * (r.toDouble() / capRings)
            rings.add(Ring(
                halfH + radius * cos(phi).toFloat(),
                radius * sin(phi).toFloat(),
                cos(phi).toFloat(), sin(phi).toFloat()))
        }
        for (r in 0..capRings) {
            val phi = (PI / 2) + (PI / 2) * (r.toDouble() / capRings)
            rings.add(Ring(
                -halfH + radius * cos(phi).toFloat(),
                radius * sin(phi).toFloat(),
                cos(phi).toFloat(), sin(phi).toFloat()))
        }
        val b = ProcBuilder()
        val columns = radialSegments + 1
        for ((ri, ring) in rings.withIndex()) {
            for (s in 0..radialSegments) {
                val theta = (2 * PI * s / radialSegments).toFloat()
                val cos = cos(theta); val sin = sin(theta)
                b.emit(
                    V3(ring.posR * cos, ring.posY, ring.posR * sin),
                    V3(ring.normR * cos, ring.normY, ring.normR * sin),
                    s.toFloat() / radialSegments,
                    ri.toFloat() / (rings.size - 1))
            }
        }
        for (r in 0 until rings.size - 1) {
            for (s in 0 until radialSegments) {
                val a = r * columns + s
                b.quad(a, a + 1, a + columns, a + columns + 1)
            }
        }
        return b.build()
    }

    /** A filled disc in the XZ plane facing +Y — proc.dart buildDisc. */
    fun disc(radius: Float, segments: Int): MeshData {
        val b = ProcBuilder()
        val n = V3(0f, 1f, 0f)
        val center = b.emit(V3(0f, 0f, 0f), n, 0.5f, 0.5f)
        val rimBase = b.vertexCount
        for (s in 0..segments) {
            val theta = (2 * PI * s / segments).toFloat()
            val cos = cos(theta); val sin = sin(theta)
            b.emit(V3(radius * cos, 0f, radius * sin), n,
                0.5f + 0.5f * cos, 0.5f + 0.5f * sin)
        }
        for (s in 0 until segments) {
            b.tri(center, rimBase + s + 1, rimBase + s)
        }
        return b.build()
    }

    /** A real subdivided icosahedron projected to [radius] — replaces
     *  the UV-sphere stand-in for `icosphere` (midpoint edge cache,
     *  spherical UVs, outward winding; proc.dart buildIcosphere). */
    fun icosphere(radius: Float, subdivisions: Int): MeshData {
        val t = ((1 + sqrt(5.0)) / 2).toFloat()
        val verts = mutableListOf(
            V3(-1f, t, 0f), V3(1f, t, 0f), V3(-1f, -t, 0f), V3(1f, -t, 0f),
            V3(0f, -1f, t), V3(0f, 1f, t), V3(0f, -1f, -t), V3(0f, 1f, -t),
            V3(t, 0f, -1f), V3(t, 0f, 1f), V3(-t, 0f, -1f), V3(-t, 0f, 1f),
        )
        var faces = mutableListOf(
            intArrayOf(0, 11, 5), intArrayOf(0, 5, 1), intArrayOf(0, 1, 7),
            intArrayOf(0, 7, 10), intArrayOf(0, 10, 11), intArrayOf(1, 5, 9),
            intArrayOf(5, 11, 4), intArrayOf(11, 10, 2), intArrayOf(10, 7, 6),
            intArrayOf(7, 1, 8), intArrayOf(3, 9, 4), intArrayOf(3, 4, 2),
            intArrayOf(3, 2, 6), intArrayOf(3, 6, 8), intArrayOf(3, 8, 9),
            intArrayOf(4, 9, 5), intArrayOf(2, 4, 11), intArrayOf(6, 2, 10),
            intArrayOf(8, 6, 7), intArrayOf(9, 8, 1),
        )
        val midpointCache = HashMap<Int, Int>()
        fun midpoint(a: Int, bv: Int): Int {
            val key = if (a < bv) (a shl 16) or bv else (bv shl 16) or a
            midpointCache[key]?.let { return it }
            val index = verts.size
            verts.add((verts[a] + verts[bv]) * 0.5f)
            midpointCache[key] = index
            return index
        }
        repeat(maxOf(subdivisions, 0)) {
            val next = ArrayList<IntArray>(faces.size * 4)
            for (f in faces) {
                val ab = midpoint(f[0], f[1])
                val bc = midpoint(f[1], f[2])
                val ca = midpoint(f[2], f[0])
                next.add(intArrayOf(f[0], ab, ca))
                next.add(intArrayOf(f[1], bc, ab))
                next.add(intArrayOf(f[2], ca, bc))
                next.add(intArrayOf(ab, bc, ca))
            }
            faces = next
        }
        val b = ProcBuilder()
        for (v in verts) {
            val n = v.normalized()
            b.emit(n * radius, n,
                (0.5 + kotlin.math.atan2(n.z, n.x) / (2 * PI)).toFloat(),
                (0.5 - kotlin.math.asin(
                    n.y.coerceIn(-1f, 1f).toDouble()) / PI).toFloat())
        }
        for (f in faces) b.tri(f[0], f[1], f[2])
        return b.build()
    }

    // MARK: - Path evaluation (W26 tube/ribbon — paths.dart port)

    private data class PathFrame(
        val position: V3, val tangent: V3,
        val normal: V3, val binormal: V3)

    /** Arc-length-parameterized curve eval — a compact port of
     *  paths.dart's ScenePath bake: sampled positions/tangents, the
     *  cumulative-length table, and rotation-minimizing normals. */
    private class PathEval(
        private val positionAt: (Float) -> V3,
        private val tangentAt: (Float) -> V3,
        sampleParams: List<Float>,
    ) {
        private val params = sampleParams
        private val tangents: List<V3>
        private val normals: List<V3>
        private val cumulative: FloatArray
        val length: Float

        init {
            val positions = params.map { positionAt(it) }
            tangents = params.map { tangentAt(it) }
            cumulative = FloatArray(params.size)
            for (i in 1 until params.size) {
                cumulative[i] = cumulative[i - 1] +
                    (positions[i] - positions[i - 1]).length
            }
            length = cumulative.last()
            normals = rotationMinimizingNormals(positions, tangents)
        }

        fun parameterAtDistance(d: Float): Float {
            val total = length
            if (total <= 0f) return 0f
            val target = d.coerceIn(0f, total)
            var lo = 0
            var hi = cumulative.size - 1
            while (lo + 1 < hi) {
                val mid = (lo + hi) ushr 1
                if (cumulative[mid] <= target) lo = mid else hi = mid
            }
            val segment = cumulative[hi] - cumulative[lo]
            val local = if (segment > 1e-12f)
                (target - cumulative[lo]) / segment else 0f
            return params[lo] + (params[hi] - params[lo]) * local
        }

        fun frameAtDistance(d: Float): PathFrame {
            val t = parameterAtDistance(d)
            var hi = 1
            while (hi < params.size - 1 && params[hi] < t) hi++
            val lo = hi - 1
            val span = params[hi] - params[lo]
            val local = if (span > 1e-12f) (t - params[lo]) / span else 0f
            val position = positionAt(t)
            var tangent = tangentAt(t)
            if (tangent.length2 < 1e-12f) tangent = tangents[hi]
            tangent = tangent.normalized()
            var normal = normals[lo] * (1f - local) + normals[hi] * local
            normal -= tangent * normal.dot(tangent)
            normal = if (normal.length2 < 1e-12f) perpendicularTo(tangent)
                else normal.normalized()
            return PathFrame(position, tangent, normal,
                tangent.cross(normal).normalized())
        }

        fun evenlySpacedFrames(stations: Int): List<PathFrame> {
            val total = length
            return List(stations) { i ->
                frameAtDistance(
                    if (stations == 1) 0f else total * i / (stations - 1))
            }
        }
    }

    private fun perpendicularTo(direction: V3): V3 {
        val ax = abs(direction.x); val ay = abs(direction.y)
        val az = abs(direction.z)
        val axis = if (ax <= ay && ax <= az) V3(1f, 0f, 0f)
            else if (ay <= az) V3(0f, 1f, 0f)
            else V3(0f, 0f, 1f)
        val result = axis.cross(direction)
        return if (result.length2 < 1e-12f) V3(0f, 1f, 0f)
            else result.normalized()
    }

    private fun rotationMinimizingNormals(
        positions: List<V3>, tangents: List<V3>,
    ): List<V3> {
        val count = positions.size
        val normals = MutableList(count) { V3(0f, 0f, 0f) }
        normals[0] = perpendicularTo(tangents[0])
        for (i in 0 until count - 1) {
            var reference = normals[i]
            val v1 = positions[i + 1] - positions[i]
            val c1 = v1.dot(v1)
            if (c1 > 1e-12f) {
                val reflectedRef = reference - v1 * (2f / c1 * v1.dot(reference))
                val reflectedTan = tangents[i] - v1 * (2f / c1 * v1.dot(tangents[i]))
                val v2 = tangents[i + 1] - reflectedTan
                val c2 = v2.dot(v2)
                reference = if (c2 > 1e-12f)
                    reflectedRef - v2 * (2f / c2 * v2.dot(reflectedRef))
                    else reflectedRef
            }
            reference -= tangents[i + 1] * reference.dot(tangents[i + 1])
            normals[i + 1] = if (reference.length2 < 1e-12f)
                perpendicularTo(tangents[i + 1]) else reference.normalized()
        }
        return normals
    }

    private const val SMOOTH_SAMPLES_PER_SEGMENT = 24

    private fun subdividedParams(segments: Int): List<Float> {
        val params = ArrayList<Float>()
        for (s in 0 until segments) {
            for (k in 0 until SMOOTH_SAMPLES_PER_SEGMENT) {
                params.add((s + k.toFloat() / SMOOTH_SAMPLES_PER_SEGMENT) / segments)
            }
        }
        params.add(1f)
        return params
    }

    /** Uniform Catmull-Rom through [points] — paths.dart port; the
     *  endpoints repeat so end segments interpolate cleanly. */
    private fun catmullRomPath(points: List<V3>, closed: Boolean): PathEval {
        val pts = if (closed) points + points.first() else points
        fun cp(i: Int) = pts[i.coerceIn(0, pts.size - 1)]
        fun segmentOf(t: Float): Pair<Int, Float> {
            val segs = pts.size - 1
            val scaled = t.coerceIn(0f, 1f) * segs
            var seg = scaled.toInt()
            if (seg >= segs) seg = segs - 1
            return seg to scaled - seg
        }
        return PathEval(
            positionAt = { t ->
                val (seg, s) = segmentOf(t)
                val p0 = cp(seg - 1); val p1 = cp(seg)
                val p2 = cp(seg + 1); val p3 = cp(seg + 2)
                val s2 = s * s; val s3 = s2 * s
                (p1 * 2f + (p2 - p0) * s +
                    (p0 * 2f - p1 * 5f + p2 * 4f - p3) * s2 +
                    (p1 * 3f - p0 - p2 * 3f + p3) * s3) * 0.5f
            },
            tangentAt = { t ->
                val (seg, s) = segmentOf(t)
                val p0 = cp(seg - 1); val p1 = cp(seg)
                val p2 = cp(seg + 1); val p3 = cp(seg + 2)
                val d = ((p2 - p0) +
                    (p0 * 2f - p1 * 5f + p2 * 4f - p3) * (2f * s) +
                    (p1 * 3f - p0 - p2 * 3f + p3) * (3f * s * s)) * 0.5f
                d.normalized(V3(1f, 0f, 0f))
            },
            sampleParams = subdividedParams(pts.size - 1))
    }

    private fun stitchRings(b: ProcBuilder, ringBases: List<Int>, ringSize: Int) {
        for (s in 0 until ringBases.size - 1) {
            val base = ringBases[s]
            val nextBase = ringBases[s + 1]
            for (j in 0 until ringSize - 1) {
                b.quad(base + j, base + j + 1, nextBase + j, nextBase + j + 1)
            }
        }
    }

    /** A round cross-section swept along a Catmull-Rom path — mirrors
     *  proc.dart's buildTube (rotation-minimizing frames, ring
     *  stitching, fan caps). [points] are native-space. */
    fun tube(
        points: List<V3>, radius: Float, radialSegments: Int,
        stations: Int, caps: Boolean, closed: Boolean,
    ): MeshData {
        val path = catmullRomPath(points, closed)
        val frames = path.evenlySpacedFrames(stations)
        val length = path.length
        val b = ProcBuilder()
        val ringBases = ArrayList<Int>(stations)
        for (i in 0 until stations) {
            val frame = frames[i]
            val v = length * i / (stations - 1)
            ringBases.add(b.vertexCount)
            for (k in 0..radialSegments) {
                val theta = (2 * PI * k / radialSegments).toFloat()
                val radial = frame.normal * cos(theta) +
                    frame.binormal * sin(theta)
                b.emit(frame.position + radial * radius, radial,
                    k.toFloat() / radialSegments, v)
            }
        }
        stitchRings(b, ringBases, radialSegments + 1)
        if (caps) {
            tubeCap(b, frames.first(), radius, radialSegments, atEnd = false)
            tubeCap(b, frames.last(), radius, radialSegments, atEnd = true)
        }
        return b.build()
    }

    private fun tubeCap(
        b: ProcBuilder, frame: PathFrame,
        radius: Float, radialSegments: Int, atEnd: Boolean,
    ) {
        val normal = if (atEnd) frame.tangent else frame.tangent * -1f
        val center = b.emit(frame.position, normal, 0.5f, 0.5f)
        val ringIndices = IntArray(radialSegments) { k ->
            val theta = (2 * PI * k / radialSegments).toFloat()
            val radial = frame.normal * cos(theta) +
                frame.binormal * sin(theta)
            b.emit(frame.position + radial * radius, normal,
                0.5f + 0.5f * cos(theta), 0.5f + 0.5f * sin(theta))
        }
        for (k in 0 until radialSegments) {
            val next = (k + 1) % radialSegments
            if (atEnd) b.tri(center, ringIndices[k], ringIndices[next])
            else b.tri(center, ringIndices[next], ringIndices[k])
        }
    }

    /** A flat strip swept along a Catmull-Rom path — proc.dart's
     *  buildRibbon ground alignment (width perpendicular to the path
     *  as seen from [up]). [points] are native-space. */
    fun ribbon(
        points: List<V3>, width: Float, stations: Int,
        up: V3, closed: Boolean,
    ): MeshData {
        val path = catmullRomPath(points, closed)
        val frames = path.evenlySpacedFrames(stations)
        val length = path.length
        val half = width / 2f
        val b = ProcBuilder()
        val ringBases = ArrayList<Int>(stations)
        for (i in 0 until stations) {
            val frame = frames[i]
            var sideways = frame.tangent.cross(up)
            if (sideways.length2 < 1e-12f) sideways = frame.binormal
            val across = sideways.normalized()
            val normal = up.normalized()
            val v = if (stations == 1) 0f else length * i / (stations - 1)
            ringBases.add(b.vertexCount)
            b.emit(frame.position - across * half, normal, 0f, v)
            b.emit(frame.position + across * half, normal, 1f, v)
        }
        stitchRings(b, ringBases, 2)
        return b.build()
    }

    // MARK: - Camera-facing expansion (W26 lines / billboards)

    /**
     * Emits one quad for the span [a]→[c] into [b]. The quad expands
     * perpendicular to the segment direction and [viewDir] (the
     * camera-forward hint — Dart's `right`/`sideHint` parameter); at
     * frame time the host re-expands toward the live camera.
     * [wa]/[wb] are half-width multipliers at each end.
     */
    private fun emitLineQuad(
        b: ProcBuilder, a: V3, c: V3,
        wa: Float, wb: Float, viewDir: V3,
        ca: FloatArray?, cb: FloatArray?,
    ) {
        var d = c - a
        if (d.length2 < 1e-20f) return
        d = d.normalized()
        var side = d.cross(viewDir)
        if (side.length2 < 1e-12f) side = d.cross(V3(0f, 1f, 0f))
        if (side.length2 < 1e-12f) side = V3(1f, 0f, 0f)
        side = side.normalized()
        val sa = side * (wa / 2)
        val sb = side * (wb / 2)
        // Face normal toward the camera — cross(d, side) approximates
        // the view direction for a perpendicular expansion.
        val n = d.cross(side).normalized()
        val ra = ca ?: WHITE4
        val rb = cb ?: WHITE4
        val v0 = b.emit(a - sa, n, 0f, 0f,
            ra[0], ra[1], ra[2], ra[3], t = d)
        b.emit(c - sb, n, 1f, 0f, rb[0], rb[1], rb[2], rb[3], t = d)
        b.emit(a + sa, n, 0f, 1f, ra[0], ra[1], ra[2], ra[3], t = d)
        b.emit(c + sb, n, 1f, 1f, rb[0], rb[1], rb[2], rb[3], t = d)
        b.quad(v0, v0 + 1, v0 + 2, v0 + 3)
    }

    private val WHITE4 = floatArrayOf(1f, 1f, 1f, 1f)

    /** Solid camera-facing polyline — one quad per segment pair.
     *  [points] native-space, [viewDir] the expansion hint. */
    fun polyline(
        points: List<V3>, width: Float, viewDir: V3,
        colors: List<FloatArray>? = null, widths: List<Float>? = null,
        closed: Boolean = false,
    ): MeshData {
        val pts = if (closed) points + points.first() else points
        val b = ProcBuilder()
        for (i in 0 until pts.size - 1) {
            emitLineQuad(b, pts[i], pts[i + 1],
                widths?.getOrNull(i) ?: width,
                widths?.getOrNull(i + 1) ?: width,
                viewDir, colors?.getOrNull(i), colors?.getOrNull(i + 1))
        }
        return b.build()
    }

    /** Dashed polyline — walks each segment's arc length with a
     *  global `(on, off)` cursor, emitting one quad per kept span
     *  (proc.dart's _expandDashed). */
    fun dashedPolyline(
        points: List<V3>, width: Float, viewDir: V3,
        onLen: Float, offLen: Float,
        colors: List<FloatArray>? = null, widths: List<Float>? = null,
        closed: Boolean = false,
    ): MeshData {
        val pts = if (closed) points + points.first() else points
        val b = ProcBuilder()
        var distance = 0f
        var on = true
        var nextBoundary = onLen
        fun lerpColor(ia: Int, ib: Int, t: Float): FloatArray? {
            val ca = colors?.getOrNull(ia) ?: return colors?.getOrNull(ib)
            val cb = colors.getOrNull(ib) ?: return ca
            return FloatArray(4) { ca[it] + (cb[it] - ca[it]) * t }
        }
        for (i in 0 until pts.size - 1) {
            val a = pts[i]
            val c = pts[i + 1]
            val dir = c - a
            val segLen = dir.length
            if (segLen < 1e-12f) continue
            var t0 = 0f
            while (t0 < 1f - 1e-9f) {
                val remain = distance + segLen - nextBoundary
                val t1 = if (remain > 0f)
                    (nextBoundary - distance) / segLen else 1f
                if (on) {
                    val wa = (widths?.getOrNull(i) ?: width) +
                        ((widths?.getOrNull(i + 1) ?: width) -
                            (widths?.getOrNull(i) ?: width)) * t0
                    val wb = (widths?.getOrNull(i) ?: width) +
                        ((widths?.getOrNull(i + 1) ?: width) -
                            (widths?.getOrNull(i) ?: width)) * t1
                    emitLineQuad(b, a + dir * t0, a + dir * t1,
                        wa, wb, viewDir, lerpColor(i, i + 1, t0),
                        lerpColor(i, i + 1, t1))
                }
                t0 = t1
                if (distance + t0 * segLen >= nextBoundary - 1e-9f) {
                    on = !on
                    nextBoundary += if (on) onLen else offLen
                }
            }
            distance += segLen
        }
        return b.build()
    }

    /** Independent camera-facing quads, one per point pair —
     *  thick line segments without join stitching. */
    fun lineSegments(
        points: List<V3>, width: Float, viewDir: V3,
        colors: List<FloatArray>? = null,
    ): MeshData {
        val b = ProcBuilder()
        var i = 0
        while (i + 1 < points.size) {
            emitLineQuad(b, points[i], points[i + 1], width, width,
                viewDir, colors?.getOrNull(i), colors?.getOrNull(i + 1))
            i += 2
        }
        return b.build()
    }

    /** The billboard facing basis for [facing] — `spherical` aims the
     *  quad's normal at the node-local camera position [camPos] and
     *  keeps the camera's up vector; `axisY` rotates about
     *  node-local +Y only (cylindrical); `screen` (and any degenerate
     *  aim) keeps the camera-plane basis [camRight]/[camUp]. Mirrors
     *  GeometryFactory.facingBasis. */
    fun facingBasis(
        facing: String, center: V3, camPos: V3,
        camRight: V3, camUp: V3,
    ): Pair<V3, V3> = when (facing) {
        "axisY" -> {
            val nx = camPos.x - center.x
            val nz = camPos.z - center.z
            val l2 = nx * nx + nz * nz
            if (l2 > 1e-12f) {
                val l = sqrt(l2)
                val nxn = nx / l; val nzn = nz / l
                // right = (0,1,0) × n — the yaw-only basis.
                Pair(V3(nzn, 0f, -nxn).normalized(), V3(0f, 1f, 0f))
            } else Pair(camRight, camUp)
        }
        "spherical" -> {
            val toCam = camPos - center
            if (toCam.length2 > 1e-12f) {
                val n = toCam.normalized()
                val r = camUp.cross(n)
                if (r.length2 > 1e-12f) {
                    val rn = r.normalized()
                    Pair(rn, n.cross(rn))
                } else Pair(camRight, camUp)
            } else Pair(camRight, camUp)
        }
        else -> Pair(camRight, camUp)
    }

    /** A camera-facing quad at the origin — [right]/[up] supply the
     *  facing basis (node-local at decode, camera-derived at frame
     *  reface). [facing] + [camPos] (node-local camera position)
     *  realize the `spherical`/`axisY` modes; `screen` keeps the
     *  passed basis. */
    fun billboardQuad(
        sizeX: Float, sizeY: Float, rotation: Float,
        color: FloatArray, right: V3, up: V3,
        facing: String = "screen", camPos: V3 = V3(0f, 0f, 0f),
    ): MeshData {
        var r = right; var u = up
        if (facing != "screen") {
            val fb = facingBasis(facing, V3(0f, 0f, 0f), camPos, right, up)
            r = fb.first; u = fb.second
        }
        val cosR = cos(rotation); val sinR = sin(rotation)
        val n = r.cross(u).normalized()
        val b = ProcBuilder()
        val corners = listOf(-0.5f to -0.5f, 0.5f to -0.5f,
            -0.5f to 0.5f, 0.5f to 0.5f)
        for ((dx, dy) in corners) {
            val rx = dx * cosR - dy * sinR
            val ry = dx * sinR + dy * cosR
            b.emit(r * (rx * sizeX) + u * (ry * sizeY), n,
                dx + 0.5f, dy + 0.5f, color[0], color[1], color[2], color[3])
        }
        b.quad(0, 1, 2, 3)
        return b.build()
    }

    // MARK: - Instance baking (W26 `d3:instances`)

    /**
     * Bakes `matrices.size` transformed copies of [base] into one
     * vertex buffer — the Android `d3:instances` realization.
     * Filament 1.71.6's Java binding exposes
     * `RenderableManager.Builder.instances(int)` but not the native
     * `InstanceBuffer` overload, so per-instance transforms/
     * attributes can't reach the GPU through the bound API; a single
     * baked renderable keeps the one-node/one-draw contract with
     * per-instance colors stamped into the COLOR stream.
     * [matrices] are native-space column-major 16-float arrays;
     * [colors] (nullable) is one rgba quad per instance.
     *
     * Normals transform by the exact inverse-transpose of the upper
     * 3×3 (the cofactor identity — exact under non-uniform scale,
     * mirror, and shear, where the old normalize-columns/quaternion
     * path drifted); the tangent column transforms by the matrix
     * itself, re-orthogonalized against the new normal, and the
     * frame's bitangent handedness flips with the determinant's
     * sign. A non-invertible/non-finite transform carries the source
     * frame through unchanged.
     */
    fun bakeInstances(
        base: MeshData, matrices: List<FloatArray>,
        colors: List<FloatArray>? = null,
    ): MeshData {
        val b = ProcBuilder()
        val src = base.vertices
        val stride = base.vertexStrideBytes
        val frame = FloatArray(9)   // unpacked (t, b, n) columns
        for ((i, m) in matrices.withIndex()) {
            val c0x = m[0]; val c0y = m[1]; val c0z = m[2]
            val c1x = m[4]; val c1y = m[5]; val c1z = m[6]
            val c2x = m[8]; val c2y = m[9]; val c2z = m[10]
            // For column-basis (c0, c1, c2), M^-1's ROWS are the
            // cofactor triples r0 = c1×c2, r1 = c2×c0, r2 = c0×c1
            // scaled by 1/det — so M^-T·n = (n.x·r0 + n.y·r1 +
            // n.z·r2)/det. Normalizing folds the |det| scale away;
            // only its sign survives.
            val r0x = c1y * c2z - c1z * c2y
            val r0y = c1z * c2x - c1x * c2z
            val r0z = c1x * c2y - c1y * c2x
            val r1x = c2y * c0z - c2z * c0y
            val r1y = c2z * c0x - c2x * c0z
            val r1z = c2x * c0y - c2y * c0x
            val r2x = c0y * c1z - c0z * c1y
            val r2y = c0z * c1x - c0x * c1z
            val r2z = c0x * c1y - c0y * c1x
            val det = c0x * r0x + c0y * r0y + c0z * r0z
            val invertible = det.isFinite() && abs(det) > 1e-20f &&
                c0x.isFinite() && c0y.isFinite() && c0z.isFinite() &&
                c1x.isFinite() && c1y.isFinite() && c1z.isFinite() &&
                c2x.isFinite() && c2y.isFinite() && c2z.isFinite() &&
                m[12].isFinite() && m[13].isFinite() && m[14].isFinite()
            // A reflection flips the frame's handedness — the
            // bitangent sign channel follows the determinant.
            val flip = if (det < 0f) -1f else 1f
            val ic = colors?.getOrNull(i)
            val base0 = b.vertexCount
            src.rewind()
            for (vi in 0 until base.vertexCount) {
                val off = vi * stride
                val px = src.getFloat(off)
                val py = src.getFloat(off + 4)
                val pz = src.getFloat(off + 8)
                // Position: M * (p, 1), column-major.
                val wx = m[0] * px + m[4] * py + m[8] * pz + m[12]
                val wy = m[1] * px + m[5] * py + m[9] * pz + m[13]
                val wz = m[2] * px + m[6] * py + m[10] * pz + m[14]
                b.verts.add(wx); b.verts.add(wy); b.verts.add(wz)
                val qx = src.getFloat(off + 12)
                val qy = src.getFloat(off + 16)
                val qz = src.getFloat(off + 20)
                val qw = src.getFloat(off + 24)
                if (invertible) {
                    // Unpack (t, b, n) + the encoded handedness,
                    // transform, repack.
                    val handed = unpackTangentFrame(
                        qx, qy, qz, qw, frame)
                    var nx = r0x * frame[6] + r1x * frame[7] +
                        r2x * frame[8]
                    var ny = r0y * frame[6] + r1y * frame[7] +
                        r2y * frame[8]
                    var nz = r0z * frame[6] + r1z * frame[7] +
                        r2z * frame[8]
                    nx *= flip; ny *= flip; nz *= flip
                    val nl = sqrt(nx * nx + ny * ny + nz * nz)
                    if (nl.isFinite() && nl > 1e-12f) {
                        nx /= nl; ny /= nl; nz /= nl
                    } else {
                        nx = frame[6]; ny = frame[7]; nz = frame[8]
                    }
                    var tx = c0x * frame[0] + c1x * frame[1] +
                        c2x * frame[2]
                    var ty = c0y * frame[0] + c1y * frame[1] +
                        c2y * frame[2]
                    var tz = c0z * frame[0] + c1z * frame[1] +
                        c2z * frame[2]
                    // Re-orthogonalize against the transformed
                    // normal — a shearing/nonuniform matrix tilts t
                    // off the surface otherwise.
                    val d = nx * tx + ny * ty + nz * tz
                    tx -= nx * d; ty -= ny * d; tz -= nz * d
                    val tl = sqrt(tx * tx + ty * ty + tz * tz)
                    if (tl.isFinite() && tl > 1e-12f) {
                        tx /= tl; ty /= tl; tz /= tl
                    } else {
                        val axis = if (abs(nx) < 0.9f) V3(1f, 0f, 0f)
                            else V3(0f, 1f, 0f)
                        val t3 = V3(nx, ny, nz).cross(axis)
                            .normalized(V3(1f, 0f, 0f))
                        tx = t3.x; ty = t3.y; tz = t3.z
                    }
                    val hs = handed * flip
                    val bx = (ny * tz - nz * ty) * hs
                    val by = (nz * tx - nx * tz) * hs
                    val bz = (nx * ty - ny * tx) * hs
                    val q = packTangentFrame(
                        tx, ty, tz, bx, by, bz, nx, ny, nz)
                    for (k in 0 until 4) b.verts.add(q[k])
                } else {
                    // Degenerate transform — the source frame rides
                    // through unchanged.
                    b.verts.add(qx); b.verts.add(qy)
                    b.verts.add(qz); b.verts.add(qw)
                }
                // uv0, color (instance color × vertex color), uv1.
                b.verts.add(src.getFloat(off + 28))
                b.verts.add(src.getFloat(off + 32))
                for (k in 0 until 4) {
                    b.verts.add(
                        (ic?.get(k) ?: 1f) * src.getFloat(off + 36 + k * 4))
                }
                b.verts.add(src.getFloat(off + 52))
                b.verts.add(src.getFloat(off + 56))
            }
            src.rewind()
            val ints = base.indices
            when (base.indexWidth) {
                IndexWidth.UINT16 -> {
                    val shorts = ints.asShortBuffer()
                    for (k in 0 until base.indexCount) {
                        b.idx.add((shorts.get(k).toInt() and 0xFFFF) + base0)
                    }
                }
                IndexWidth.UINT32 -> {
                    val ib = ints.asIntBuffer()
                    for (k in 0 until base.indexCount) {
                        b.idx.add(ib.get(k) + base0)
                    }
                }
            }
        }
        return b.build()
    }

    /** Decodes a packed tangent-frame quaternion into [out] as the
     *  (t, b, n) columns; returns the frame's handedness (−1 when the
     *  packed w<0 sign channel marks a reflected basis — see
     *  packTangentFrame). A degenerate quat yields the identity
     *  frame. */
    private fun unpackTangentFrame(
        qx: Float, qy: Float, qz: Float, qw: Float, out: FloatArray,
    ): Float {
        var x = qx; var y = qy; var z = qz; var w = qw
        val l = sqrt(x * x + y * y + z * z + w * w)
        if (!l.isFinite() || l < 1e-12f) {
            out[0] = 1f; out[1] = 0f; out[2] = 0f
            out[3] = 0f; out[4] = 1f; out[5] = 0f
            out[6] = 0f; out[7] = 0f; out[8] = 1f
            return 1f
        }
        x /= l; y /= l; z /= l; w /= l
        val reflected = w < 0f
        if (reflected) { x = -x; y = -y; z = -z; w = -w }
        val xx = x * x; val yy = y * y; val zz = z * z
        val xy = x * y; val xz = x * z; val yz = y * z
        val wx = w * x; val wy = w * y; val wz = w * z
        out[0] = 1f - 2f * (yy + zz); out[1] = 2f * (xy + wz)
        out[2] = 2f * (xz - wy)
        out[3] = 2f * (xy - wz); out[4] = 1f - 2f * (xx + zz)
        out[5] = 2f * (yz + wx)
        out[6] = 2f * (xz + wy); out[7] = 2f * (yz - wx)
        out[8] = 1f - 2f * (xx + yy)
        // The packed basis stores −b when the source frame was
        // reflected; restore the true bitangent.
        if (reflected) { out[3] = -out[3]; out[4] = -out[4]; out[5] = -out[5] }
        return if (reflected) -1f else 1f
    }

    /** Bakes one camera-facing quad per instance center — billboard
     *  mode of `d3:instances`. [centers] are the instance transforms'
     *  translations in node space; [right]/[up] supply the facing
     *  basis the host refreshes per frame. A non-`screen` [facing]
     *  computes the basis per center from the node-local camera
     *  position [camPos] (spherical quads aim individually). */
    fun bakeBillboardInstances(
        centers: List<V3>, sizeX: Float, sizeY: Float, rotation: Float,
        colors: List<FloatArray>?, right: V3, up: V3,
        facing: String = "screen", camPos: V3 = V3(0f, 0f, 0f),
    ): MeshData {
        val cosR = cos(rotation); val sinR = sin(rotation)
        val b = ProcBuilder()
        val corners = listOf(-0.5f to -0.5f, 0.5f to -0.5f,
            -0.5f to 0.5f, 0.5f to 0.5f)
        for ((i, c) in centers.withIndex()) {
            var r = right; var u = up
            if (facing != "screen") {
                val fb = facingBasis(facing, c, camPos, right, up)
                r = fb.first; u = fb.second
            }
            val n = r.cross(u).normalized()
            val col = colors?.getOrNull(i) ?: WHITE4
            val v0 = b.vertexCount
            for ((dx, dy) in corners) {
                val rx = dx * cosR - dy * sinR
                val ry = dx * sinR + dy * cosR
                b.emit(c + r * (rx * sizeX) + u * (ry * sizeY), n,
                    dx + 0.5f, dy + 0.5f, col[0], col[1], col[2], col[3])
            }
            b.quad(v0, v0 + 1, v0 + 2, v0 + 3)
        }
        return b.build()
    }
}
