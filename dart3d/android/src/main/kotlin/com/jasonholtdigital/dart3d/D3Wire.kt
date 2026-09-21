package com.jasonholtdigital.dart3d

import org.json.JSONArray
import org.json.JSONObject

/**
 * Wire helpers for the dart3d protocol — little-endian readers, the
 * Crockford base32 `LocalId` token codec, and the `.fscene` → right-
 * handed coordinate conversion. Mirrors D3Wire.swift exactly.
 *
 * `.fscene` is left-handed, +Y up, +Z forward. Filament is right-handed
 * looking down −Z (same convention as SceneKit), so the conversion is
 * the identical z-mirror: positions negate z, quaternions map
 * `(x,y,z,w) → (−x,−y,z,w)`, matrices get `S·M·S` with
 * `S = diag(1,1,−1,1)`.
 */
object D3Wire {

    // MARK: - LocalId (8 raw bytes: session u32 LE + index u32 LE)

    fun idKey(session: Long, index: Long): Long =
        (session shl 32) or (index and 0xFFFFFFFFL)

    /** Reads an 8-byte wire id (little-endian halves) at [offset]. */
    fun readLocalId(d: ByteArray, offset: Int): Long =
        idKey(u32LE(d, offset).toLong(), u32LE(d, offset + 4).toLong())

    /**
     * Decodes an `.fscene` id token to the same 64-bit key. Tokens are
     * Crockford base32 of the 8 big-endian id bytes, optionally carrying
     * a readability prefix (`geo:ABC…` — everything through the last
     * colon is stripped, matching `LocalId.parse`).
     */
    fun localIdKey(token: String): Long? {
        val t = token.substringAfterLast(':')
        val bytes = base32Decode(t) ?: return null
        if (bytes.size != 8) return null
        val session = ((bytes[0].toLong() and 0xFF) shl 24) or
            ((bytes[1].toLong() and 0xFF) shl 16) or
            ((bytes[2].toLong() and 0xFF) shl 8) or
            (bytes[3].toLong() and 0xFF)
        val index = ((bytes[4].toLong() and 0xFF) shl 24) or
            ((bytes[5].toLong() and 0xFF) shl 16) or
            ((bytes[6].toLong() and 0xFF) shl 8) or
            (bytes[7].toLong() and 0xFF)
        return idKey(session, index)
    }

    /**
     * Encodes a 64-bit key back to its 13-char Crockford base32 token —
     * the inverse of [localIdKey] (mirrors D3Wire.swift's
     * `localIdToken`; the component-joint translator emits `a`/`b`
     * tokens through it).
     */
    fun localIdToken(key: Long): String {
        val sb = StringBuilder(13)
        var shift = 59
        while (shift >= 0) {
            sb.append(B32[((key ushr shift) and 0x1F).toInt()])
            shift -= 5
        }
        sb.append(B32[((key and 0xF) shl 1).toInt()])
        return sb.toString()
    }

    private const val B32 = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

    /** Crockford base32 decode, MSB first; mirrors package:scene. */
    fun base32Decode(token: String): ByteArray? {
        val out = ArrayList<Byte>(token.length * 5 / 8)
        var buffer = 0
        var bits = 0
        for (raw in token) {
            var c = raw.uppercaseChar()
            if (c == 'I' || c == 'L') c = '1'
            if (c == 'O') c = '0'
            val idx = B32.indexOf(c)
            if (idx < 0) return null
            buffer = (buffer shl 5) or idx
            bits += 5
            if (bits >= 8) {
                bits -= 8
                out.add(((buffer ushr bits) and 0xFF).toByte())
                buffer = buffer and ((1 shl bits) - 1)
            }
        }
        return out.toByteArray()
    }

    // MARK: - Little-endian readers

    fun u32LE(d: ByteArray, offset: Int): Int =
        (d[offset].toInt() and 0xFF) or
            ((d[offset + 1].toInt() and 0xFF) shl 8) or
            ((d[offset + 2].toInt() and 0xFF) shl 16) or
            ((d[offset + 3].toInt() and 0xFF) shl 24)

    fun f32LE(d: ByteArray, offset: Int): Float =
        Float.fromBits(u32LE(d, offset))

    // MARK: - LH → RH coordinate conversion (z-mirror)

    /** [x,y,z] LH → [x,y,−z] RH. */
    fun position(t: DoubleArray): FloatArray =
        floatArrayOf(t[0].toFloat(), t[1].toFloat(), -t[2].toFloat())

    /** [x,y,z,w] LH → [−x,−y,z,w] RH. */
    fun quaternion(r: DoubleArray): FloatArray =
        floatArrayOf(-r[0].toFloat(), -r[1].toFloat(), r[2].toFloat(), r[3].toFloat())

    fun scale(s: DoubleArray): FloatArray =
        floatArrayOf(s[0].toFloat(), s[1].toFloat(), s[2].toFloat())

    /**
     * `S·M·S` with `S = diag(1,1,−1,1)` — negates every element whose
     * row or column (but not both) is the z axis. Input and output are
     * column-major 16-element arrays (OpenGL/Filament order).
     */
    fun matrix(m: DoubleArray): FloatArray {
        val f = FloatArray(16) { m[it].toFloat() }
        for (j in 0..3) {
            for (i in 0..3) {
                if ((i == 2) != (j == 2)) f[j * 4 + i] = -f[j * 4 + i]
            }
        }
        return f
    }

    // MARK: - Quaternion → matrix helpers

    /** Builds a column-major TRS matrix from RH-space t/r/s. */
    fun trs(t: FloatArray, q: FloatArray, s: FloatArray): FloatArray {
        val (x, y, z, w) = q
        val m = FloatArray(16)
        val x2 = x + x; val y2 = y + y; val z2 = z + z
        val xx = x * x2; val xy = x * y2; val xz = x * z2
        val yy = y * y2; val yz = y * z2; val zz = z * z2
        val wx = w * x2; val wy = w * y2; val wz = w * z2
        m[0] = (1 - (yy + zz)) * s[0]
        m[1] = (xy + wz) * s[0]
        m[2] = (xz - wy) * s[0]
        m[3] = 0f
        m[4] = (xy - wz) * s[1]
        m[5] = (1 - (xx + zz)) * s[1]
        m[6] = (yz + wx) * s[1]
        m[7] = 0f
        m[8] = (xz + wy) * s[2]
        m[9] = (yz - wx) * s[2]
        m[10] = (1 - (xx + yy)) * s[2]
        m[11] = 0f
        m[12] = t[0]; m[13] = t[1]; m[14] = t[2]; m[15] = 1f
        return m
    }
}

// MARK: - Tagged property values (single-key {'d':…}/{'c':…} objects)
//
// Mirrors the d3* helpers at the bottom of FsceneRealizer.swift.

fun JSONObject.tag(key: String): Any? = opt(key)

// All d3* readers accept the bare (untagged) JSON upstream's
// `_encodeProcedural` emits — raw bools/numbers/strings, `[[x,y,z],…]`
// lists, plain maps — alongside our tagged {'d':…}-style envelopes.
// Tagged wins when both parse.

fun Any?.d3Bool(): Boolean? =
    (this as? JSONObject)?.optBoolean("b") ?: (this as? Boolean)

fun Any?.d3Double(): Double? {
    val o = this as? JSONObject
    if (o != null) {
        val raw = if (o.has("d")) o.opt("d") else o.opt("i")
        (raw as? Number)?.let { return it.toDouble() }
    }
    return (this as? Number)?.toDouble()
}

fun Any?.d3Int(): Int? {
    val o = this as? JSONObject
    if (o != null) {
        val raw = if (o.has("i")) o.opt("i") else o.opt("d")
        (raw as? Number)?.let { return it.toInt() }
    }
    return (this as? Number)?.toInt()
}

// Procedural spec fields (e.g. cuboid `extents`) serialize as bare
// arrays upstream — accept both the tagged `{'vN':[…]}` and raw forms.

fun Any?.d3Vec2(): DoubleArray? =
    (this as? JSONObject)?.optJSONArray("v2")?.toDoubleArray()
        ?: (this as? JSONArray)?.toDoubleArray()

fun Any?.d3Vec3(): DoubleArray? =
    (this as? JSONObject)?.optJSONArray("v3")?.toDoubleArray()
        ?: (this as? JSONArray)?.toDoubleArray()

fun Any?.d3Vec4(): DoubleArray? =
    (this as? JSONObject)?.optJSONArray("v4")?.toDoubleArray()
        ?: (this as? JSONArray)?.toDoubleArray()

fun Any?.d3String(): String? =
    (this as? JSONObject)?.optString("s")?.takeIf { it.isNotEmpty() }
        ?: (this as? String)

fun Any?.d3Color(): FloatArray? {
    val a = (this as? JSONObject)?.optJSONArray("c")
        ?: (this as? JSONArray)
    if (a == null || a.length() != 4) return null
    return FloatArray(4) { a.optDouble(it).toFloat() }
}

fun Any?.d3Ref(): Long? {
    val o = this as? JSONObject ?: return null
    val token = o.optString("rref").ifEmpty { o.optString("nref") }
    if (token.isEmpty()) return null
    return D3Wire.localIdKey(token)
}

fun Any?.d3List(): JSONArray? =
    (this as? JSONObject)?.optJSONArray("list") ?: (this as? JSONArray)

/** Single-key tag envelopes — a bare map holding only e.g.
 *  {"d": 5} is a scalar envelope, not a map. */
private val envelopeKeys = setOf(
    "b", "d", "i", "v2", "v3", "v4", "q", "c", "s", "m4",
    "list", "map", "rref", "nref",
)

/** MapValue — `{'map': {key: taggedValue, ...}}`, or a bare
 *  (untagged) JSON object as upstream's _encodeProcedural emits. */
fun Any?.d3Map(): JSONObject? {
    val o = this as? JSONObject ?: return null
    o.optJSONObject("map")?.let { return it }
    if (o.length() == 1 && envelopeKeys.contains(o.keys().next()))
        return null
    return o
}

/**
 * Ordered (geometryKey, materialKey) pairs of a `mesh` component's
 * primitives. Upstream emits direct `geometry`/`material` refs for a
 * single-primitive mesh and a `primitives` list — whose entries are
 * tagged `{"map":{geometry,material}}` PropertyValues — for a
 * multi-primitive one. Index i is renderable primitive slot i.
 */
fun meshPrimitiveKeys(p: JSONObject):
    Pair<List<Long>, List<Long?>> {
    val geoKeys = ArrayList<Long>()
    val matKeys = ArrayList<Long?>()
    val directGeo = p.tag("geometry").d3Ref()
    if (directGeo != null) {
        geoKeys.add(directGeo)
        matKeys.add(p.tag("material").d3Ref())
        return geoKeys to matKeys
    }
    val prims = p.tag("primitives").d3List() ?: return geoKeys to matKeys
    for (i in 0 until prims.length()) {
        val entry = prims.optJSONObject(i)?.d3Map() ?: continue
        val g = entry.tag("geometry").d3Ref() ?: continue
        geoKeys.add(g)
        matKeys.add(entry.tag("material").d3Ref())
    }
    return geoKeys to matKeys
}

/** Matrix4Value — `{'m4': [16]}` column-major (vector_math storage). */
fun Any?.d3Mat4(): DoubleArray? =
    (this as? JSONObject)?.optJSONArray("m4")?.toDoubleArray()

fun JSONArray.toDoubleArray(): DoubleArray =
    DoubleArray(length()) { optDouble(it) }

fun JSONArray.toFloatArray(): FloatArray =
    FloatArray(length()) { optDouble(it).toFloat() }
