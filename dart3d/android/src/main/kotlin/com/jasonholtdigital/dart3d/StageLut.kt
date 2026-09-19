package com.jasonholtdigital.dart3d

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * W25: a parsed `.cube` 3D color-grading table — the cube edge
 * length plus the red-fastest RGB triples — and its upload shape
 * for `ColorGrading.Builder.customLut`.
 *
 * Port of upstream `parseCubeTable`
 * (`flutter_scene/lib/src/post_process/color_lut.dart`): Adobe/IRIDAS
 * `.cube` text — `TITLE`/`DOMAIN_MIN`/`DOMAIN_MAX` tolerated,
 * `LUT_1D_SIZE` rejected, `LUT_3D_SIZE` 2…64, exactly `size³` RGB
 * rows in red-fastest order.
 */
class StageLut private constructor(
    val size: Int,
    /** `size³ × 3` floats, red-fastest (`r + g·N + b·N²` cells). */
    val values: FloatArray,
) {
    class ParseException(message: String) : Exception(message)

    /**
     * The table as the direct little-endian `float3` buffer
     * `customLut` consumes — `size³` RGB cells in the same red-fastest
     * cube order Filament indexes (`r + g·N + b·N²`).
     *
     * [blend] is the wire `lutBlend`: Filament's `customLut` has no
     * mix knob, so each output texel lerps toward the identity value
     * at its cube coordinate — `0` is a no-op grade, `1` the authored
     * table.
     */
    fun directBuffer(blend: Double = 1.0): ByteBuffer {
        val n = size
        val b01 = blend.coerceIn(0.0, 1.0).toFloat()
        val denom = (n - 1).toFloat()
        val buf = ByteBuffer.allocateDirect(n * n * n * 3 * 4)
            .order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until n * n * n) {
            val r = i % n
            val g = (i / n) % n
            val b = i / (n * n)
            buf.putFloat(r / denom + (values[i * 3] - r / denom) * b01)
            buf.putFloat(g / denom + (values[i * 3 + 1] - g / denom) * b01)
            buf.putFloat(b / denom + (values[i * 3 + 2] - b / denom) * b01)
        }
        buf.flip()
        return buf
    }

    companion object {
        /**
         * Parses `.cube` text into a table. Throws [ParseException]
         * on the same conditions upstream does; non-table lines that
         * carry fewer than three tokens are skipped, matching the
         * upstream tolerance.
         */
        @Throws(ParseException::class)
        fun parse(content: String): StageLut {
            var size = 0
            var values: FloatArray? = null
            var cursor = 0
            for (rawLine in content.split('\n')) {
                val line = rawLine.trim()
                if (line.isEmpty() || line.startsWith("#")) continue
                val tokens = line.split(Regex("\\s+"))
                val keyword = tokens[0].uppercase()
                if (keyword == "TITLE" || keyword == "DOMAIN_MIN" ||
                    keyword == "DOMAIN_MAX") {
                    continue
                }
                if (keyword == "LUT_1D_SIZE") {
                    throw ParseException(
                        "1D .cube tables are not supported.")
                }
                if (keyword == "LUT_3D_SIZE") {
                    size = tokens.getOrNull(1)?.toIntOrNull() ?: 0
                    if (size < 2 || size > 64) {
                        throw ParseException(
                            "LUT_3D_SIZE must be between 2 and 64.")
                    }
                    values = FloatArray(size * size * size * 3)
                    continue
                }
                val table = values
                if (table == null || tokens.size < 3) continue
                if (cursor + 3 > table.size) {
                    throw ParseException(
                        "The .cube table has more rows than its size.")
                }
                table[cursor] = tokens[0].toFloatOrNull() ?: 0f
                table[cursor + 1] = tokens[1].toFloatOrNull() ?: 0f
                table[cursor + 2] = tokens[2].toFloatOrNull() ?: 0f
                cursor += 3
            }
            val table = values
            if (table == null || cursor != table.size) {
                throw ParseException("The .cube table is missing rows.")
            }
            return StageLut(size, table)
        }

        @Throws(ParseException::class)
        fun parse(bytes: ByteArray): StageLut =
            parse(String(bytes, Charsets.UTF_8))
    }
}
