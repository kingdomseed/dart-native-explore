package com.jasonholtdigital.dart3d

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.google.android.filament.Engine
import com.google.android.filament.Texture
import org.json.JSONArray
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * W7 environment/IBL pixel math and decoders — the Android half of
 * upstream flutter_scene's environment pipeline. The studio generator
 * and the SH projection are verbatim ports of
 * `flutter_scene/lib/src/material/environment.dart`; the HDR decoder,
 * box blur and column transforms port `FsceneRealizer.swift`.
 *
 * Conventions. `EnvPixels` is a row-0-up equirect; `isFloat` selects
 * little-endian RGBA float32 storage, otherwise sRGB-encoded RGBA8.
 *
 * Filament samples equirect textures as
 * `u = 0.5 + atan2(d.x, d.z)/2π, v = 0.5 − asin(d.y)/π`
 * (libs/iblprefilter's `equirectToCube.mat`), while upstream writes
 * `u = 0.5 + atan2(d.z, d.x)/2π`. The dart3d LH→RH z-mirror plus
 * upstream's `RotY(θ)` env transform collapse to a single column shift
 * under Filament's convention — `out[x] = src[(x − w/4 − s) mod w]`,
 * `s = round(θ·w/2π)` (see [filamentShifted] for the derivation).
 *
 * Filament's `IndirectLight.Builder.irradiance(3, sh)` wants
 * coefficients already folded for the shader's bare-polynomial
 * reconstruction `Σ sh_i·poly_i(n)` (Fd_Lambert's 1/π is baked in) —
 * i.e. upstream's post-fold coefficients multiplied by the unsigned
 * basis constants; see [projectEquirectSH].
 */
object EnvironmentFactory {

    private const val TAG = "dart3d"

    /** One equirect radiance image — `data` is RGBA8 sRGB when
     * [isFloat] is false, little-endian RGBA float32 otherwise. */
    class EnvPixels(
        val width: Int,
        val height: Int,
        val isFloat: Boolean,
        val data: ByteArray,
    )

    private val loggedOnce = mutableSetOf<String>()
    private val warnedOnce = mutableSetOf<String>()

    fun logOnce(tag: String, msg: String) {
        if (loggedOnce.add(tag)) Log.i(TAG, msg)
    }

    fun warnOnce(tag: String, msg: String) {
        if (warnedOnce.add(tag)) Log.w(TAG, msg)
    }

    // MARK: - Environment generators

    /**
     * Verbatim port of flutter_scene's `_generateStudioEquirectPixels`:
     * a cool-neutral ceiling gradient over a warm-dim floor, a broad
     * dirY² top fill ("ceiling softbox"), a warm pow²⁶ key lobe at
     * normalize(0.45, 0.55, 0.70), and a cool pow¹⁶ fill at
     * normalize(−0.70, 0.22, −0.35). Row 0 is the up pole; pixels are
     * sRGB-encoded RGBA8.
     */
    fun studioEquirectPixels(width: Int, height: Int): ByteArray {
        val pixels = ByteArray(width * height * 4)
        val keyLen = sqrt(0.45 * 0.45 + 0.55 * 0.55 + 0.70 * 0.70)
        val keyX = 0.45 / keyLen
        val keyY = 0.55 / keyLen
        val keyZ = 0.70 / keyLen
        val fillLen = sqrt(0.70 * 0.70 + 0.22 * 0.22 + 0.35 * 0.35)
        val fillX = -0.70 / fillLen
        val fillY = 0.22 / fillLen
        val fillZ = -0.35 / fillLen
        val twoPi = 2.0 * Math.PI
        for (py in 0 until height) {
            val v = (py + 0.5) / height.toDouble()
            // Row 0 (the top of the image) is the up hemisphere.
            val latitude = (0.5 - v) * Math.PI
            val cosLat = cos(latitude)
            val dirY = sin(latitude)
            for (px in 0 until width) {
                val u = (px + 0.5) / width.toDouble()
                val longitude = (u - 0.5) * twoPi
                val dirX = cosLat * cos(longitude)
                val dirZ = cosLat * sin(longitude)

                var r: Double
                var g: Double
                var b: Double
                if (dirY >= 0.0) {
                    val t = smoothstep01(dirY)
                    r = lerp(0.50, 0.76, t)
                    g = lerp(0.51, 0.78, t)
                    b = lerp(0.52, 0.82, t)
                } else {
                    val t = smoothstep01(-dirY)
                    r = lerp(0.50, 0.20, t)
                    g = lerp(0.51, 0.19, t)
                    b = lerp(0.52, 0.17, t)
                }
                val top = max(dirY, 0.0)
                val topL = top * top
                r += 0.85 * topL
                g += 0.86 * topL
                b += 0.88 * topL
                val keyC = max(dirX * keyX + dirY * keyY + dirZ * keyZ, 0.0)
                val keyL = keyC.pow(26.0)
                r += 1.10 * keyL
                g += 1.06 * keyL
                b += 1.00 * keyL
                val fillC = max(dirX * fillX + dirY * fillY + dirZ * fillZ, 0.0)
                val fillL = fillC.pow(16.0)
                r += 0.46 * fillL
                g += 0.50 * fillL
                b += 0.56 * fillL
                val o = (py * width + px) * 4
                pixels[o] = encodeSrgb(r)
                pixels[o + 1] = encodeSrgb(g)
                pixels[o + 2] = encodeSrgb(b)
                pixels[o + 3] = 255.toByte()
            }
        }
        return pixels
    }

    /**
     * `gradient` sky — mirrors upstream's SkyGradientFragment:
     * horizon→zenith / horizon→ground blends on sqrt(|dirY|), the
     * pow(dot(sun), sharpness) HDR sun disk, and its 0.15·s⁸ halo.
     * Float pixels, each multiplied by [scale]: the caller scales a
     * sky Filament is going to draw at some other intensity than its
     * own (see FsceneRealizer's gradient sky).
     */
    fun gradientEquirectPixels(
        source: JSONObject?,
        scale: Double = 1.0,
        width: Int = 128,
        height: Int = 64,
    ): EnvPixels {
        val zenith = rawVec3(source?.optJSONArray("zenithColor"))
            ?: doubleArrayOf(0.05, 0.18, 0.55)
        val horizon = rawVec3(source?.optJSONArray("horizonColor"))
            ?: doubleArrayOf(0.45, 0.62, 0.90)
        val ground = rawVec3(source?.optJSONArray("groundColor"))
            ?: doubleArrayOf(0.16, 0.14, 0.12)
        val sun = rawVec3(source?.optJSONArray("sunDirection"))
            ?: doubleArrayOf(0.4, 0.5, 0.6)
        val sunColor = rawVec3(source?.optJSONArray("sunColor"))
            ?: doubleArrayOf(3.0, 2.7, 2.2)
        val sharpness = source?.optDouble("sunSharpness", 400.0) ?: 400.0
        val sunLen = sqrt(sun[0] * sun[0] + sun[1] * sun[1] + sun[2] * sun[2])
        val sunX = if (sunLen > 0) sun[0] / sunLen else 0.0
        val sunY = if (sunLen > 0) sun[1] / sunLen else 0.0
        val sunZ = if (sunLen > 0) sun[2] / sunLen else 0.0
        val pixels = ByteBuffer.allocate(width * height * 16)
            .order(ByteOrder.LITTLE_ENDIAN)
        val twoPi = 2.0 * Math.PI
        for (py in 0 until height) {
            val v = (py + 0.5) / height.toDouble()
            val latitude = (0.5 - v) * Math.PI
            val cosLat = cos(latitude)
            val dirY = sin(latitude)
            for (px in 0 until width) {
                val u = (px + 0.5) / width.toDouble()
                val longitude = (u - 0.5) * twoPi
                val dirX = cosLat * cos(longitude)
                val dirZ = cosLat * sin(longitude)
                var r: Double
                var g: Double
                var b: Double
                val t = sqrt(abs(dirY))
                if (dirY >= 0) {
                    r = lerp(horizon[0], zenith[0], t)
                    g = lerp(horizon[1], zenith[1], t)
                    b = lerp(horizon[2], zenith[2], t)
                } else {
                    r = lerp(horizon[0], ground[0], t)
                    g = lerp(horizon[1], ground[1], t)
                    b = lerp(horizon[2], ground[2], t)
                }
                val s = max(dirX * sunX + dirY * sunY + dirZ * sunZ, 0.0)
                val disk = s.pow(sharpness) + 0.15 * s.pow(8.0)
                r += sunColor[0] * disk
                g += sunColor[1] * disk
                b += sunColor[2] * disk
                pixels.putFloat((max(r, 0.0) * scale).toFloat())
                pixels.putFloat((max(g, 0.0) * scale).toFloat())
                pixels.putFloat((max(b, 0.0) * scale).toFloat())
                pixels.putFloat(1f)
            }
        }
        return EnvPixels(width, height, isFloat = true, data = pixels.array())
    }

    private const val RAYLEIGH_ZENITH_SIZE = 8400.0
    private const val MIE_ZENITH_SIZE = 1250.0
    private var logged1kPerf = false

    /**
     * `physical` sky — mirrors upstream's `flutter_scene_sky_physical.frag`:
     * analytic Preetham single-scattering daylight model with Rayleigh and
     * Mie phase functions, zenith-angle optical mass, low-sun extinction
     * re-saturation, ground fade below the horizon, and an atmospheric-
     * attenuated HDR sun disk.
     *
     * Row-dependent optical mass and extinction and column-dependent
     * longitude trig are hoisted outside the inner pixel loop so a 1024×512
     * float equirect generates well inside the A142 200 ms budget (~8 ms).
     * When [conserveSunEnergy] is true, sub-pixel sun disks on coarse
     * progressive equirects (`64×32`, `128×64`, `256×128`) are widened to a
     * minimum filter radius of `1.75·π/height` with matching `(r0/rEff)²`
     * peak scaling so total integrated sun flux is invariant across steps.
     */
    fun physicalEquirectPixels(
        source: JSONObject?,
        scale: Double = 1.0,
        width: Int = 256,
        height: Int = 128,
        conserveSunEnergy: Boolean = false,
    ): EnvPixels {
        if (!logged1kPerf) {
            logged1kPerf = true
            val t0 = System.nanoTime()
            val bench = buildPhysicalEquirect(
                source, scale = 1.0, width = 1024, height = 512,
                conserveSunEnergy = false)
            val ms = (System.nanoTime() - t0) / 1_000_000.0
            Log.i(TAG, String.format(
                java.util.Locale.US,
                "w17 physicalSky 1k (%dx%d) generated in %.2f ms",
                bench.width, bench.height, ms))
        }
        return buildPhysicalEquirect(
            source, scale, width, height, conserveSunEnergy)
    }

    private fun buildPhysicalEquirect(
        source: JSONObject?,
        scale: Double,
        width: Int,
        height: Int,
        conserveSunEnergy: Boolean,
    ): EnvPixels {
        val sun = rawVec3(source?.optJSONArray("sunDirection"))
            ?: doubleArrayOf(0.4, 0.5, 0.6)
        val sunAngularRadius = max(
            0.0, source?.optDouble("sunAngularRadius", 0.0175) ?: 0.0175)
        val rayleighCoefficient =
            source?.optDouble("rayleighCoefficient", 2.0) ?: 2.0
        val rayleighColor = rawVec3(source?.optJSONArray("rayleighColor"))
            ?: doubleArrayOf(0.26, 0.41, 0.58)
        val mieCoefficient =
            source?.optDouble("mieCoefficient", 0.005) ?: 0.005
        val mieEccentricity =
            source?.optDouble("mieEccentricity", 0.8) ?: 0.8
        val mieColor = rawVec3(source?.optJSONArray("mieColor"))
            ?: doubleArrayOf(0.69, 0.73, 0.81)
        val turbidity = source?.optDouble("turbidity", 10.0) ?: 10.0
        val groundColor = rawVec3(source?.optJSONArray("groundColor"))
            ?: doubleArrayOf(0.12, 0.12, 0.13)
        val energy = source?.optDouble("energy", 1.0) ?: 1.0

        val sunLen = sqrt(sun[0] * sun[0] + sun[1] * sun[1] + sun[2] * sun[2])
        val sunX = if (sunLen > 1e-12) sun[0] / sunLen else 0.0
        val sunY = if (sunLen > 1e-12) sun[1] / sunLen else 1.0
        val sunZ = if (sunLen > 1e-12) sun[2] / sunLen else 0.0

        val sunZenithCos = sunY.coerceIn(-1.0, 1.0)
        val sunEnergy = max(
            0.0,
            1.0 - exp(-((Math.PI * 0.5) - acos(sunZenithCos)))) * 60.0 * energy
        val sunFade = 1.0 - (1.0 - exp(sunY)).coerceIn(0.0, 1.0)

        val rayleighScale =
            max(rayleighCoefficient - (1.0 - sunFade), 0.0) * 0.0001
        val rayleighBetaR = rayleighColor[0] * rayleighScale
        val rayleighBetaG = rayleighColor[1] * rayleighScale
        val rayleighBetaB = rayleighColor[2] * rayleighScale

        val mieScale = turbidity * mieCoefficient * 0.000434
        val mieBetaR = mieColor[0] * mieScale
        val mieBetaG = mieColor[1] * mieScale
        val mieBetaB = mieColor[2] * mieScale

        val denomR = max(rayleighBetaR + mieBetaR, 1e-12)
        val denomG = max(rayleighBetaG + mieBetaG, 1e-12)
        val denomB = max(rayleighBetaB + mieBetaB, 1e-12)

        val extCoeffR =
            rayleighBetaR * RAYLEIGH_ZENITH_SIZE + mieBetaR * MIE_ZENITH_SIZE
        val extCoeffG =
            rayleighBetaG * RAYLEIGH_ZENITH_SIZE + mieBetaG * MIE_ZENITH_SIZE
        val extCoeffB =
            rayleighBetaB * RAYLEIGH_ZENITH_SIZE + mieBetaB * MIE_ZENITH_SIZE

        val sunsetMix = (1.0 - sunZenithCos).pow(5.0).coerceIn(0.0, 1.0)
        val g2 = mieEccentricity * mieEccentricity
        val oneMinusG2 = 1.0 - g2
        val invFourPi = 1.0 / (4.0 * Math.PI)
        val rayleighConst = 3.0 / (16.0 * Math.PI)

        val minGridRadius = 1.75 * Math.PI / max(1, height)
        val rEff = if (conserveSunEnergy && sunAngularRadius > 0.0 && sunAngularRadius < minGridRadius)
            minGridRadius else sunAngularRadius
        val directSunScale = if (conserveSunEnergy && rEff > sunAngularRadius && rEff > 0.0)
            (sunAngularRadius / rEff) * (sunAngularRadius / rEff) else 1.0
        val diskOuter = cos(rEff)
        val diskInner = cos(rEff * 0.5)

        val twoPi = 2.0 * Math.PI
        val cosLon = DoubleArray(width)
        val sinLon = DoubleArray(width)
        for (px in 0 until width) {
            val u = (px + 0.5) / width.toDouble()
            val lon = (u - 0.5) * twoPi
            cosLon[px] = cos(lon)
            sinLon[px] = sin(lon)
        }

        val pixels = ByteBuffer.allocate(width * height * 16)
            .order(ByteOrder.LITTLE_ENDIAN)
        for (py in 0 until height) {
            val v = (py + 0.5) / height.toDouble()
            val latitude = (0.5 - v) * Math.PI
            val cosLat = cos(latitude)
            val dirY = sin(latitude)

            val zenith = acos(max(0.0, dirY))
            val opticalMass = 1.0 /
                (cos(zenith) + 0.00094 * (1.6386 - zenith).pow(-1.253))
            val extR = exp(-extCoeffR * opticalMass)
            val extG = exp(-extCoeffG * opticalMass)
            val extB = exp(-extCoeffB * opticalMass)
            val oneMinusExtR = 1.0 - extR
            val oneMinusExtG = 1.0 - extG
            val oneMinusExtB = 1.0 - extB

            val groundBlend = smoothstep(-0.1, 0.1, dirY)
            val groundFactorR = lerp(groundColor[0], 1.0, groundBlend)
            val groundFactorG = lerp(groundColor[1], 1.0, groundBlend)
            val groundFactorB = lerp(groundColor[2], 1.0, groundBlend)

            val rowDirectR = sunEnergy * extR * directSunScale
            val rowDirectG = sunEnergy * extG * directSunScale
            val rowDirectB = sunEnergy * extB * directSunScale

            for (px in 0 until width) {
                val dirX = cosLat * cosLon[px]
                val dirZ = cosLat * sinLon[px]
                val cosTheta = dirX * sunX + dirY * sunY + dirZ * sunZ

                val halfCos = cosTheta * 0.5 + 0.5
                val rayleighPhase = rayleighConst * (1.0 + halfCos * halfCos)
                val d = max(1.0 + g2 - 2.0 * mieEccentricity * cosTheta, 1e-12)
                val miePhase = invFourPi * (oneMinusG2 / (d * sqrt(d)))

                val scatterR =
                    (rayleighBetaR * rayleighPhase + mieBetaR * miePhase) / denomR
                val scatterG =
                    (rayleighBetaG * rayleighPhase + mieBetaG * miePhase) / denomG
                val scatterB =
                    (rayleighBetaB * rayleighPhase + mieBetaB * miePhase) / denomB

                val sR = max(sunEnergy * scatterR * oneMinusExtR, 0.0)
                val sG = max(sunEnergy * scatterG * oneMinusExtG, 0.0)
                val sB = max(sunEnergy * scatterB * oneMinusExtB, 0.0)
                var r = sR * sqrt(sR)
                var g = sG * sqrt(sG)
                var b = sB * sqrt(sB)

                if (sunsetMix > 0.0) {
                    val seR = sqrt(max(sunEnergy * scatterR * extR, 0.0))
                    val seG = sqrt(max(sunEnergy * scatterG * extG, 0.0))
                    val seB = sqrt(max(sunEnergy * scatterB * extB, 0.0))
                    r *= lerp(1.0, seR, sunsetMix)
                    g *= lerp(1.0, seG, sunsetMix)
                    b *= lerp(1.0, seB, sunsetMix)
                }

                r *= groundFactorR
                g *= groundFactorG
                b *= groundFactorB

                if (cosTheta > diskOuter) {
                    val sunDisk = smoothstep(diskOuter, diskInner, cosTheta)
                    r += rowDirectR * sunDisk
                    g += rowDirectG * sunDisk
                    b += rowDirectB * sunDisk
                }

                pixels.putFloat((max(r, 0.0) * scale).toFloat())
                pixels.putFloat((max(g, 0.0) * scale).toFloat())
                pixels.putFloat((max(b, 0.0) * scale).toFloat())
                pixels.putFloat(1f)
            }
        }
        return EnvPixels(width, height, isFloat = true, data = pixels.array())
    }

    /** `constant` env — a tiny solid equirect of the linear color,
     * sRGB-encoded like every LDR source here. */
    fun solidEquirectPixels(c: DoubleArray, width: Int, height: Int): ByteArray {
        val r = encodeSrgb(c[0])
        val g = encodeSrgb(c[1])
        val b = encodeSrgb(c[2])
        val data = ByteArray(width * height * 4)
        var i = 0
        while (i < data.size) {
            data[i] = r
            data[i + 1] = g
            data[i + 2] = b
            data[i + 3] = 255.toByte()
            i += 4
        }
        return data
    }

    // MARK: - Equirect byte decoding

    /**
     * Equirect bytes — decoder picked by magic: Radiance HDR
     * (`#?RADIANCE`/`#?RGBE`) decodes to float32 on the CPU (Filament's
     * HDRLoader returns a GPU texture with no pixel access — the SH
     * projection and the column-shift bake both need CPU pixels);
     * OpenEXR warns once (deferred); everything else goes through
     * `BitmapFactory` (png/jpg/…; the spec `format` tag is
     * informational).
     */
    fun envPixelsFromBytes(data: ByteArray, tag: String): EnvPixels? {
        if (isRadianceHDR(data)) {
            return decodeRadianceHDR(data, tag)
        }
        if (isOpenEXR(data)) {
            warnOnce("env.exr.$tag",
                "$tag: OpenEXR equirect is deferred — use .hdr or an LDR image")
            return null
        }
        val decoded = try {
            BitmapFactory.decodeByteArray(data, 0, data.size)
        } catch (e: Exception) {
            null
        }
        if (decoded == null) {
            warnOnce("env.bytes.$tag", "$tag: undecodable environment image")
            return null
        }
        var bitmap = decoded
        if (bitmap.config != Bitmap.Config.ARGB_8888) {
            val converted = bitmap.copy(Bitmap.Config.ARGB_8888, false)
            bitmap.recycle()
            if (converted == null) {
                warnOnce("env.config.$tag",
                    "$tag: could not convert bitmap to ARGB_8888")
                return null
            }
            bitmap = converted
        }
        val w = bitmap.width
        val h = bitmap.height
        val buf = ByteBuffer.allocate(bitmap.byteCount)
            .order(ByteOrder.nativeOrder())
        bitmap.copyPixelsToBuffer(buf)
        bitmap.recycle()
        // ARGB_8888 little-endian memory is B,G,R,A — repack to RGBA.
        val bytes = buf.array()
        for (i in 0 until w * h) {
            val p = i * 4
            val t = bytes[p]
            bytes[p] = bytes[p + 2]
            bytes[p + 2] = t
        }
        return EnvPixels(w, h, isFloat = false, data = bytes)
    }

    fun isRadianceHDR(data: ByteArray): Boolean {
        if (data.size <= 10 || data[0] != 0x23.toByte() || data[1] != 0x3F.toByte()) {
            return false
        }
        val head = String(data, 0, 10, Charsets.US_ASCII)
        return head.startsWith("#?RADIANCE") || head.startsWith("#?RGBE")
    }

    /** OpenEXR magic 0x01312F76, little-endian on the wire. */
    fun isOpenEXR(data: ByteArray): Boolean =
        data.size > 4 && data[0] == 0x76.toByte() && data[1] == 0x2F.toByte() &&
            data[2] == 0x31.toByte() && data[3] == 0x01.toByte()

    /**
     * Minimal Radiance .hdr (RGBE) decoder: header lines up to a blank
     * line, a `-Y h +X w` resolution row, then per-scanline new-style
     * RLE or flat RGBE data. Output is linear RGBA float32 (little
     * endian), row 0 = top of the image.
     */
    fun decodeRadianceHDR(data: ByteArray, tag: String): EnvPixels? {
        fun fail(why: String): EnvPixels? {
            warnOnce("env.hdr.$tag.$why", "$tag: malformed .hdr equirect ($why)")
            return null
        }
        var i = 0
        // Header: text lines through the first empty one.
        var sawHeaderEnd = false
        while (i < data.size) {
            val nl = data.indexOf(0x0A.toByte(), i)
            if (nl < 0) return fail("unterminated header")
            var len = nl - i
            if (len > 0 && data[nl - 1] == 0x0D.toByte()) len-- // tolerate \r\n
            i = nl + 1
            if (len == 0) {
                sawHeaderEnd = true
                break
            }
        }
        if (!sawHeaderEnd) return fail("unterminated header")
        // Resolution row: "±Y h ±X w" (Y-major only).
        val nl = data.indexOf(0x0A.toByte(), i)
        if (nl < 0) return fail("missing resolution line")
        var rlen = nl - i
        if (rlen > 0 && data[nl - 1] == 0x0D.toByte()) rlen--
        val tokens = String(data, i, rlen, Charsets.US_ASCII)
            .split(' ').filter { it.isNotEmpty() }
        i = nl + 1
        if (tokens.size != 4) return fail("bad resolution line")
        val n1 = tokens[1].toIntOrNull() ?: return fail("bad resolution line")
        val n2 = tokens[3].toIntOrNull() ?: return fail("bad resolution line")
        if (n1 <= 0 || n2 <= 0) return fail("bad resolution line")
        if (!tokens[0].endsWith("Y")) {
            return fail("X-major scanlines unsupported")
        }
        val height = n1
        val width = n2
        // "-Y": first scanline is the image top (the standard); "+Y"
        // starts at the bottom. "+X": left-to-right pixels.
        val bottomUp = tokens[0].startsWith("+")
        val rightToLeft = tokens[2].startsWith("-")
        val floats = FloatArray(width * height * 4)
        val rle = width >= 8 && width < 32768
        val rgb = ByteArray(width * 4)
        for (y in 0 until height) {
            val row = if (bottomUp) height - 1 - y else y
            if (rle) {
                if (i + 4 > data.size || data[i] != 2.toByte() ||
                    data[i + 1] != 2.toByte() ||
                    (data[i + 2].toInt() and 0x80) != 0 ||
                    ((data[i + 2].toInt() and 0xFF) shl 8 or
                        (data[i + 3].toInt() and 0xFF)) != width) {
                    return fail("bad RLE scanline $y")
                }
                i += 4
                for (c in 0 until 4) {
                    var x = 0
                    while (x < width) {
                        if (i >= data.size) return fail("truncated RLE")
                        val count = data[i].toInt() and 0xFF
                        i++
                        if (count > 128) {
                            val run = count - 128
                            if (i >= data.size || x + run > width) {
                                return fail("bad RLE run")
                            }
                            val v = data[i]
                            i++
                            for (k in 0 until run) {
                                rgb[(x + k) * 4 + c] = v
                            }
                            x += run
                        } else {
                            if (i + count > data.size || x + count > width) {
                                return fail("bad RLE literal")
                            }
                            for (k in 0 until count) {
                                rgb[(x + k) * 4 + c] = data[i + k]
                            }
                            i += count
                            x += count
                        }
                    }
                }
            } else {
                if (i + width * 4 > data.size) return fail("truncated flat data")
                for (k in 0 until width * 4) rgb[k] = data[i + k]
                i += width * 4
            }
            for (x in 0 until width) {
                val sx = if (rightToLeft) width - 1 - x else x
                val o = (row * width + x) * 4
                val e = rgb[sx * 4 + 3].toInt() and 0xFF
                if (e != 0) {
                    val f = 2.0.pow(e - 136.0).toFloat()
                    floats[o] = (rgb[sx * 4].toInt() and 0xFF) * f
                    floats[o + 1] = (rgb[sx * 4 + 1].toInt() and 0xFF) * f
                    floats[o + 2] = (rgb[sx * 4 + 2].toInt() and 0xFF) * f
                }
                floats[o + 3] = 1.0f
            }
        }
        val bytes = ByteArray(floats.size * 4)
        ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            .asFloatBuffer().put(floats)
        return EnvPixels(width, height, isFloat = true, data = bytes)
    }

    // MARK: - Pixel transforms

    /**
     * Bakes the LH→RH z-mirror plus `environmentRotationY` for
     * Filament's equirect sampler — both compose to a pure column
     * shift under its convention.
     *
     * Derivation: upstream samples `u = 0.5 + atan2(d.z, d.x)/2π`;
     * Filament samples `u = 0.5 + atan2(d.x, d.z)/2π`, i.e.
     * `u_F = 0.75 − u_up (mod 1)` — a mirror plus a quarter-turn. The
     * env content must read as `E_up(RotY(θ)·S·d)` where
     * `S = diag(1,1,−1)`; substituting gives `out[x] =
     * src[(x − w/4 − round(θ·w/2π)) mod w]`. iOS bakes the same content
     * with `src[w−1−x−s]` because SceneKit samples the upstream
     * convention directly.
     */
    fun filamentShifted(env: EnvPixels, rotationY: Double): EnvPixels {
        val bpp = if (env.isFloat) 16 else 4
        val w = env.width
        val h = env.height
        val shift = w / 4 +
            (rotationY / (2.0 * Math.PI) * w).roundToInt()
        val s = ((shift % w) + w) % w
        val out = ByteArray(env.data.size)
        val src = env.data
        for (y in 0 until h) {
            for (x in 0 until w) {
                val sx = ((x - s) % w + w) % w
                val so = (y * w + sx) * bpp
                val dOff = (y * w + x) * bpp
                for (k in 0 until bpp) {
                    out[dOff + k] = src[so + k]
                }
            }
        }
        return EnvPixels(w, h, env.isFloat, out)
    }

    /**
     * Cheap separable box blur for `skybox.blurriness` — longitude
     * wraps, latitude clamps (equirect-aware edges). Runs in storage
     * space (sRGB for LDR): approximate by design, and the caller
     * warn-onces that.
     */
    fun boxBlurredPixels(env: EnvPixels, radius: Int): EnvPixels {
        if (radius <= 0) return env
        val w = env.width
        val h = env.height
        val count = 2 * radius + 1
        if (env.isFloat) {
            val px = FloatArray(w * h * 4)
            ByteBuffer.wrap(env.data).order(ByteOrder.LITTLE_ENDIAN)
                .asFloatBuffer().get(px)
            val tmp = FloatArray(w * h * 4)
            val f = 1.0f / count
            for (y in 0 until h) {
                for (x in 0 until w) {
                    var a0 = 0f; var a1 = 0f; var a2 = 0f; var a3 = 0f
                    for (k in -radius..radius) {
                        val sx = ((x + k) % w + w) % w
                        val o = (y * w + sx) * 4
                        a0 += px[o]; a1 += px[o + 1]
                        a2 += px[o + 2]; a3 += px[o + 3]
                    }
                    val o = (y * w + x) * 4
                    tmp[o] = a0 * f; tmp[o + 1] = a1 * f
                    tmp[o + 2] = a2 * f; tmp[o + 3] = a3 * f
                }
            }
            for (y in 0 until h) {
                for (x in 0 until w) {
                    var a0 = 0f; var a1 = 0f; var a2 = 0f; var a3 = 0f
                    for (k in -radius..radius) {
                        val sy = min(max(y + k, 0), h - 1)
                        val o = (sy * w + x) * 4
                        a0 += tmp[o]; a1 += tmp[o + 1]
                        a2 += tmp[o + 2]; a3 += tmp[o + 3]
                    }
                    val o = (y * w + x) * 4
                    px[o] = a0 * f; px[o + 1] = a1 * f
                    px[o + 2] = a2 * f; px[o + 3] = a3 * f
                }
            }
            val bytes = ByteArray(px.size * 4)
            ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
                .asFloatBuffer().put(px)
            return EnvPixels(w, h, isFloat = true, data = bytes)
        }
        val px = env.data
        val tmp = ByteArray(px.size)
        val out = ByteArray(px.size)
        val f = 1.0 / count
        for (y in 0 until h) {
            for (x in 0 until w) {
                var a0 = 0.0; var a1 = 0.0; var a2 = 0.0; var a3 = 0.0
                for (k in -radius..radius) {
                    val sx = ((x + k) % w + w) % w
                    val o = (y * w + sx) * 4
                    a0 += px[o].toInt() and 0xFF
                    a1 += px[o + 1].toInt() and 0xFF
                    a2 += px[o + 2].toInt() and 0xFF
                    a3 += px[o + 3].toInt() and 0xFF
                }
                val o = (y * w + x) * 4
                tmp[o] = (a0 * f).roundToInt().toByte()
                tmp[o + 1] = (a1 * f).roundToInt().toByte()
                tmp[o + 2] = (a2 * f).roundToInt().toByte()
                tmp[o + 3] = (a3 * f).roundToInt().toByte()
            }
        }
        for (y in 0 until h) {
            for (x in 0 until w) {
                var a0 = 0.0; var a1 = 0.0; var a2 = 0.0; var a3 = 0.0
                for (k in -radius..radius) {
                    val sy = min(max(y + k, 0), h - 1)
                    val o = (sy * w + x) * 4
                    a0 += tmp[o].toInt() and 0xFF
                    a1 += tmp[o + 1].toInt() and 0xFF
                    a2 += tmp[o + 2].toInt() and 0xFF
                    a3 += tmp[o + 3].toInt() and 0xFF
                }
                val o = (y * w + x) * 4
                out[o] = (a0 * f).roundToInt().toByte()
                out[o + 1] = (a1 * f).roundToInt().toByte()
                out[o + 2] = (a2 * f).roundToInt().toByte()
                out[o + 3] = (a3 * f).roundToInt().toByte()
            }
        }
        return EnvPixels(w, h, isFloat = false, data = out)
    }

    /**
     * Bilinear resample to `newWidth`×`newHeight` — longitude wraps,
     * latitude clamps. sRGB8 sources filter in sRGB space
     * (approximate); float sources filter in linear space.
     */
    fun resampleEquirect(
        env: EnvPixels,
        newWidth: Int,
        newHeight: Int,
    ): EnvPixels {
        if (env.width == newWidth && env.height == newHeight) return env
        val w = env.width
        val h = env.height
        if (env.isFloat) {
            val src = FloatArray(w * h * 4)
            ByteBuffer.wrap(env.data).order(ByteOrder.LITTLE_ENDIAN)
                .asFloatBuffer().get(src)
            val dst = FloatArray(newWidth * newHeight * 4)
            for (y in 0 until newHeight) {
                val fy = (y + 0.5f) * h / newHeight - 0.5f
                val y0 = floor(fy).toInt().coerceIn(0, h - 1)
                val y1 = (y0 + 1).coerceAtMost(h - 1)
                val ty = (fy - floor(fy)).coerceIn(0f, 1f)
                for (x in 0 until newWidth) {
                    var fx = (x + 0.5f) * w / newWidth - 0.5f
                    fx %= w
                    if (fx < 0) fx += w
                    val x0 = floor(fx).toInt()
                    val x1 = (x0 + 1) % w
                    val tx = fx - floor(fx)
                    val i00 = (y0 * w + x0) * 4
                    val i01 = (y0 * w + x1) * 4
                    val i10 = (y1 * w + x0) * 4
                    val i11 = (y1 * w + x1) * 4
                    val o = (y * newWidth + x) * 4
                    for (c in 0 until 4) {
                        val top = src[i00 + c] * (1 - tx) + src[i01 + c] * tx
                        val bot = src[i10 + c] * (1 - tx) + src[i11 + c] * tx
                        dst[o + c] = top * (1 - ty) + bot * ty
                    }
                }
            }
            val bytes = ByteArray(dst.size * 4)
            ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
                .asFloatBuffer().put(dst)
            return EnvPixels(newWidth, newHeight, isFloat = true, data = bytes)
        }
        val src = env.data
        val dst = ByteArray(newWidth * newHeight * 4)
        for (y in 0 until newHeight) {
            val fy = (y + 0.5) * h / newHeight - 0.5
            val y0 = floor(fy).toInt().coerceIn(0, h - 1)
            val y1 = (y0 + 1).coerceAtMost(h - 1)
            val ty = (fy - floor(fy)).coerceIn(0.0, 1.0)
            for (x in 0 until newWidth) {
                var fx = (x + 0.5) * w / newWidth - 0.5
                fx %= w
                if (fx < 0) fx += w
                val x0 = floor(fx).toInt()
                val x1 = (x0 + 1) % w
                val tx = fx - floor(fx)
                val i00 = (y0 * w + x0) * 4
                val i01 = (y0 * w + x1) * 4
                val i10 = (y1 * w + x0) * 4
                val i11 = (y1 * w + x1) * 4
                val o = (y * newWidth + x) * 4
                for (c in 0 until 4) {
                    val top = (src[i00 + c].toInt() and 0xFF) * (1 - tx) +
                        (src[i01 + c].toInt() and 0xFF) * tx
                    val bot = (src[i10 + c].toInt() and 0xFF) * (1 - tx) +
                        (src[i11 + c].toInt() and 0xFF) * tx
                    dst[o + c] = (top * (1 - ty) + bot * ty)
                        .roundToInt().toByte()
                }
            }
        }
        return EnvPixels(newWidth, newHeight, isFloat = false, data = dst)
    }

    /**
     * `EquirectangularToCubemap` preconditions a 2:1 source — a
     * non-conforming decode is resampled to height
     * `min(h, w/2)`'s 2:1 frame rather than dropped.
     */
    fun normalizeEquirect(env: EnvPixels): EnvPixels {
        if (env.width == 2 * env.height) return env
        val h = min(env.height, env.width / 2).coerceAtLeast(1)
        return resampleEquirect(env, 2 * h, h)
    }

    // MARK: - Spherical harmonics

    /**
     * Upstream-true SH3 of [env], in the coefficient form Filament's
     * `IndirectLight.Builder.irradiance(3, …)` wants. Verbatim port of
     * `_projectEquirect`'s 192×96 quadrature and band fold, with two
     * Filament-convention adaptations:
     *
     * 1. [env] is the Filament-convention equirect (post
     *    [filamentShifted]), so the basis evaluates at
     *    `(dirZ, dirY, dirX)` — the x/z swap maps upstream's
     *    atan2(z,x) longitude onto Filament's atan2(x,z).
     * 2. Each folded coefficient is multiplied by the unsigned basis
     *    constant — Filament's shader reconstructs
     *    `Σ sh_i·poly_i(n)` with bare polynomials where upstream's
     *    evaluates `Σ c_i·(b_i·poly_i)`; folding `b_i` in makes the
     *    two identical term-by-term.
     *
     * Result: 9 RGB triples (27 floats), `E(n)/π` folded.
     */
    fun projectEquirectSH(env: EnvPixels): FloatArray {
        val width = env.width
        val height = env.height
        val coefficients = DoubleArray(27)
        // Quadrature over a regular grid in equirectangular UV space.
        // The grid resolution is independent of the source image;
        // sampling 192x96 cells keeps the L2 projection accurate while
        // staying fast on the CPU.
        val numPhi = min(192, max(64, width))
        val numTheta = min(96, max(32, height))
        val twoPi = 2.0 * Math.PI
        val cellSolidAngle = twoPi * Math.PI / (numPhi * numTheta)
        val cosLon = DoubleArray(numPhi)
        val sinLon = DoubleArray(numPhi)
        val pxTable = IntArray(numPhi)
        for (i in 0 until numPhi) {
            val u = (i + 0.5) / numPhi
            val longitude = (u - 0.5) * twoPi
            cosLon[i] = cos(longitude)
            sinLon[i] = sin(longitude)
            pxTable[i] = floor(u * width).toInt().coerceIn(0, width - 1)
        }
        for (j in 0 until numTheta) {
            val v = (j + 0.5) / numTheta
            val latitude = (v - 0.5) * Math.PI // asin(direction.y)
            val cosLat = cos(latitude)
            val dirY = sin(latitude)
            val weightRow = cosLat * cellSolidAngle
            // The source equirect stores +y (up) at the top of the
            // image (row 0), but increasing v here maps to increasing
            // latitude (up). Flip the row lookup so the up hemisphere
            // reads the top of the image.
            val py = floor((1.0 - v) * height).toInt().coerceIn(0, height - 1)
            val rowOffset = py * width
            for (i in 0 until numPhi) {
                val dirX = cosLat * cosLon[i]
                val dirZ = cosLat * sinLon[i]
                val px = pxTable[i]

                val o = (rowOffset + px) * 4
                val r: Double
                val g: Double
                val b: Double
                if (env.isFloat) {
                    val bo = o * 4
                    r = f32le(env.data, bo).toDouble()
                    g = f32le(env.data, bo + 4).toDouble()
                    b = f32le(env.data, bo + 8).toDouble()
                } else {
                    r = srgbToLinear((env.data[o].toInt() and 0xFF) / 255.0)
                    g = srgbToLinear((env.data[o + 1].toInt() and 0xFF) / 255.0)
                    b = srgbToLinear((env.data[o + 2].toInt() and 0xFF) / 255.0)
                }
                // Filament-convention direction: swap x/z — upstream's
                // atan2(z,x) longitude → Filament's atan2(x,z).
                accumulateSh(coefficients, dirZ, dirY, dirX, r, g, b, weightRow)
            }
        }
        // Fold in the Lambertian convolution band factors (A_l) divided
        // by pi: A_0/pi = 1, A_1/pi = 2/3, A_2/pi = 1/4.
        for (k in 1..3) {
            coefficients[k * 3] *= 2.0 / 3.0
            coefficients[k * 3 + 1] *= 2.0 / 3.0
            coefficients[k * 3 + 2] *= 2.0 / 3.0
        }
        for (k in 4..8) {
            coefficients[k * 3] *= 0.25
            coefficients[k * 3 + 1] *= 0.25
            coefficients[k * 3 + 2] *= 0.25
        }
        // Upstream's shader applies the basis constants at evaluation;
        // Filament's bare-polynomial reconstruction wants them folded
        // into the coefficients (signed-basis signs cancel out — see
        // IndirectLight.cpp's A[] table).
        val out = FloatArray(27)
        for (k in 0 until 9) {
            out[k * 3] = (coefficients[k * 3] * SH_BASIS_CONST[k]).toFloat()
            out[k * 3 + 1] = (coefficients[k * 3 + 1] * SH_BASIS_CONST[k]).toFloat()
            out[k * 3 + 2] = (coefficients[k * 3 + 2] * SH_BASIS_CONST[k]).toFloat()
        }
        return out
    }

    private fun accumulateSh(
        coefficients: DoubleArray,
        x: Double, y: Double, z: Double,
        r: Double, g: Double, b: Double,
        weight: Double,
    ) {
        // Real spherical-harmonic basis, bands 0..2. Must match the
        // basis upstream's fragment shader evaluates with. Unrolled to
        // avoid allocating a 9-element DoubleArray per quadrature sample.
        val rw = r * weight
        val gw = g * weight
        val bw = b * weight

        val b0 = 0.282095
        coefficients[0] += rw * b0; coefficients[1] += gw * b0; coefficients[2] += bw * b0

        val b1 = 0.488603 * y
        coefficients[3] += rw * b1; coefficients[4] += gw * b1; coefficients[5] += bw * b1

        val b2 = 0.488603 * z
        coefficients[6] += rw * b2; coefficients[7] += gw * b2; coefficients[8] += bw * b2

        val b3 = 0.488603 * x
        coefficients[9] += rw * b3; coefficients[10] += gw * b3; coefficients[11] += bw * b3

        val b4 = 1.092548 * x * y
        coefficients[12] += rw * b4; coefficients[13] += gw * b4; coefficients[14] += bw * b4

        val b5 = 1.092548 * y * z
        coefficients[15] += rw * b5; coefficients[16] += gw * b5; coefficients[17] += bw * b5

        val b6 = 0.315392 * (3.0 * z * z - 1.0)
        coefficients[18] += rw * b6; coefficients[19] += gw * b6; coefficients[20] += bw * b6

        val b7 = 1.092548 * x * z
        coefficients[21] += rw * b7; coefficients[22] += gw * b7; coefficients[23] += bw * b7

        val b8 = 0.546274 * (x * x - y * y)
        coefficients[24] += rw * b8; coefficients[25] += gw * b8; coefficients[26] += bw * b8
    }

    // MARK: - Texture upload

    /**
     * Uploads an equirect as a fully mipmapped `SAMPLER_2D` —
     * `EquirectangularToCubemap` preconditions `ilogb(width)+1`
     * allocated levels. sRGB8 sources land as `SRGB8_A8` (the
     * converter's samples decode to linear); float sources land as
     * `RGBA16F` (unconditionally filterable — `RGBA32F` filtering
     * isn't guaranteed on GLES3).
     */
    fun equirectTexture(engine: Engine, env: EnvPixels): Texture {
        val w = env.width
        val h = env.height
        var levels = 1
        var m = w
        while (m > 1) {
            m = m shr 1
            levels++
        }
        val tex = Texture.Builder()
            .width(w).height(h)
            .levels(levels)
            .sampler(Texture.Sampler.SAMPLER_2D)
            .format(if (env.isFloat) Texture.InternalFormat.RGBA16F
                else Texture.InternalFormat.SRGB8_A8)
            .usage(Texture.Usage.DEFAULT or Texture.Usage.GEN_MIPMAPPABLE)
            .fenced { build(engine) }
        if (env.isFloat) {
            val floats = env.data.size / 4
            val buf = ByteBuffer.allocateDirect(floats * 2)
                .order(ByteOrder.nativeOrder())
            for (i in 0 until floats) {
                buf.putShort(
                    floatToHalfBits(f32le(env.data, i * 4)).toShort())
            }
            buf.flip()
            tex.setImage(engine, 0, Texture.PixelBufferDescriptor(
                buf, Texture.Format.RGBA, Texture.Type.HALF))
        } else {
            val buf = ByteBuffer.allocateDirect(env.data.size)
                .order(ByteOrder.nativeOrder())
                .put(env.data)
            buf.flip()
            tex.setImage(engine, 0, Texture.PixelBufferDescriptor(
                buf, Texture.Format.RGBA, Texture.Type.UBYTE))
        }
        if (levels > 1) tex.generateMipmaps(engine)
        return tex
    }

    private class CubeUvTable(val faceSize: Int) {
        val u = FloatArray(6 * faceSize * faceSize)
        val v = FloatArray(6 * faceSize * faceSize)

        init {
            val invTwoPi = (1.0 / (2.0 * Math.PI)).toFloat()
            val invPi = (1.0 / Math.PI).toFloat()
            var idx = 0
            for (face in 0 until 6) {
                for (y in 0 until faceSize) {
                    val t = 2.0 * (y + 0.5) / faceSize - 1.0
                    for (x in 0 until faceSize) {
                        val s = 2.0 * (x + 0.5) / faceSize - 1.0
                        val dx: Double
                        val dy: Double
                        val dz: Double
                        when (face) {
                            0 -> { dx = 1.0; dy = -t; dz = -s }   // +X
                            1 -> { dx = -1.0; dy = -t; dz = s }   // -X
                            2 -> { dx = s; dy = 1.0; dz = t }     // +Y
                            3 -> { dx = s; dy = -1.0; dz = -t }   // -Y
                            4 -> { dx = s; dy = -t; dz = 1.0 }    // +Z
                            else -> { dx = -s; dy = -t; dz = -1.0 } // -Z
                        }
                        val invLen = 1.0 / sqrt(dx * dx + dy * dy + dz * dz)
                        val nx = dx * invLen
                        val ny = (dy * invLen).coerceIn(-1.0, 1.0)
                        val nz = dz * invLen
                        var uf = 0.5f + atan2(nx, nz).toFloat() * invTwoPi
                        if (uf < 0f) uf += 1f else if (uf >= 1f) uf -= 1f
                        val vf = (0.5f - asin(ny).toFloat() * invPi).coerceIn(0f, 1f)
                        u[idx] = uf
                        v[idx] = vf
                        idx++
                    }
                }
            }
        }
    }

    private val cubeUvTables = HashMap<Int, CubeUvTable>()

    @Synchronized
    private fun uvTableFor(faceSize: Int): CubeUvTable =
        cubeUvTables.getOrPut(faceSize) { CubeUvTable(faceSize) }

    /**
     * Builds a `SAMPLER_CUBEMAP` (`RGBA16F`) directly from [env] (already
     * shifted via [filamentShifted]) and uploads its mip levels via
     * asynchronous `setImage` calls without invoking `IBLPrefilterContext`'s
     * blocking `flushAndWait()`. Mip levels 1..L-1 are progressively
     * downsampled and smoothed across each cube face to approximate
     * roughness-band prefiltering during real-time sun sweeps.
     */
    fun cubemapTextureFromEquirect(
        engine: Engine,
        env: EnvPixels,
        faceSize: Int,
        maxMipLevels: Int = 6,
    ): Texture {
        val mips = prepareCubemapMipBuffers(env, faceSize, maxMipLevels)
        return uploadCubemapTexture(engine, faceSize, mips)
    }

    /**
     * Pure-CPU preparation of all cubemap mip `HALF` buffers from [env]
     * (safe to run on a background worker thread).
     */
    fun prepareCubemapMipBuffers(
        env: EnvPixels,
        faceSize: Int,
        maxMipLevels: Int = 6,
    ): List<Pair<Int, ByteBuffer>> {
        var levels = 1
        var m = faceSize
        while (m > 1 && levels < maxMipLevels) {
            m = m shr 1
            levels++
        }

        val w = env.width
        val h = env.height
        val srcFloats = FloatArray(w * h * 4)
        if (env.isFloat) {
            ByteBuffer.wrap(env.data).order(ByteOrder.LITTLE_ENDIAN)
                .asFloatBuffer().get(srcFloats)
        } else {
            for (i in 0 until w * h) {
                val o = i * 4
                srcFloats[o] = srgbToLinear((env.data[o].toInt() and 0xFF) / 255.0).toFloat()
                srcFloats[o + 1] = srgbToLinear((env.data[o + 1].toInt() and 0xFF) / 255.0).toFloat()
                srcFloats[o + 2] = srgbToLinear((env.data[o + 2].toInt() and 0xFF) / 255.0).toFloat()
                srcFloats[o + 3] = 1f
            }
        }

        val table = uvTableFor(faceSize)
        val totalBaseTexels = 6 * faceSize * faceSize
        var curSize = faceSize
        var curFaces = FloatArray(totalBaseTexels * 3)
        for (idx in 0 until totalBaseTexels) {
            val fx = table.u[idx] * w - 0.5f
            val fy = table.v[idx] * h - 0.5f
            var x0 = floor(fx).toInt()
            val tx = fx - x0
            x0 = ((x0 % w) + w) % w
            val x1 = (x0 + 1) % w
            val y0 = floor(fy).toInt().coerceIn(0, h - 1)
            val y1 = (y0 + 1).coerceAtMost(h - 1)
            val ty = (fy - floor(fy)).coerceIn(0f, 1f)

            val i00 = (y0 * w + x0) * 4
            val i10 = (y0 * w + x1) * 4
            val i01 = (y1 * w + x0) * 4
            val i11 = (y1 * w + x1) * 4
            val o = idx * 3
            val w00 = (1f - tx) * (1f - ty)
            val w10 = tx * (1f - ty)
            val w01 = (1f - tx) * ty
            val w11 = tx * ty
            curFaces[o] = srcFloats[i00] * w00 + srcFloats[i10] * w10 +
                srcFloats[i01] * w01 + srcFloats[i11] * w11
            curFaces[o + 1] = srcFloats[i00 + 1] * w00 + srcFloats[i10 + 1] * w10 +
                srcFloats[i01 + 1] * w01 + srcFloats[i11 + 1] * w11
            curFaces[o + 2] = srcFloats[i00 + 2] * w00 + srcFloats[i10 + 2] * w10 +
                srcFloats[i01 + 2] * w01 + srcFloats[i11 + 2] * w11
        }

        val mips = ArrayList<Pair<Int, ByteBuffer>>(levels)
        val oneBits = 0x3C00.toShort()
        for (level in 0 until levels) {
            val levelTexels = 6 * curSize * curSize
            val buf = ByteBuffer.allocateDirect(levelTexels * 8)
                .order(ByteOrder.nativeOrder())
            for (i in 0 until levelTexels) {
                val o = i * 3
                buf.putShort(floatToHalfBits(curFaces[o]).toShort())
                buf.putShort(floatToHalfBits(curFaces[o + 1]).toShort())
                buf.putShort(floatToHalfBits(curFaces[o + 2]).toShort())
                buf.putShort(oneBits)
            }
            buf.flip()
            mips.add(curSize to buf)

            if (level + 1 < levels) {
                val nextSize = maxOf(1, curSize shr 1)
                val down = FloatArray(6 * nextSize * nextSize * 3)
                for (f in 0 until 6) {
                    val fIn = f * curSize * curSize
                    val fOut = f * nextSize * nextSize
                    for (y in 0 until nextSize) {
                        val sy0 = (y * 2).coerceAtMost(curSize - 1)
                        val sy1 = (y * 2 + 1).coerceAtMost(curSize - 1)
                        for (x in 0 until nextSize) {
                            val sx0 = (x * 2).coerceAtMost(curSize - 1)
                            val sx1 = (x * 2 + 1).coerceAtMost(curSize - 1)
                            val p00 = (fIn + sy0 * curSize + sx0) * 3
                            val p10 = (fIn + sy0 * curSize + sx1) * 3
                            val p01 = (fIn + sy1 * curSize + sx0) * 3
                            val p11 = (fIn + sy1 * curSize + sx1) * 3
                            val d = (fOut + y * nextSize + x) * 3
                            down[d] = (curFaces[p00] + curFaces[p10] + curFaces[p01] + curFaces[p11]) * 0.25f
                            down[d + 1] = (curFaces[p00 + 1] + curFaces[p10 + 1] + curFaces[p01 + 1] + curFaces[p11 + 1]) * 0.25f
                            down[d + 2] = (curFaces[p00 + 2] + curFaces[p10 + 2] + curFaces[p01 + 2] + curFaces[p11 + 2]) * 0.25f
                        }
                    }
                }
                curFaces = down
                curSize = nextSize
            }
        }
        return mips
    }

    /**
     * Uploads pre-built cubemap mip buffers [mips] to a `SAMPLER_CUBEMAP`
     * texture on the render thread (~0.3 ms, no `flushAndWait()`).
     */
    fun uploadCubemapTexture(
        engine: Engine,
        faceSize: Int,
        mips: List<Pair<Int, ByteBuffer>>,
    ): Texture {
        val tex = Texture.Builder()
            .width(faceSize).height(faceSize)
            .levels(mips.size)
            .sampler(Texture.Sampler.SAMPLER_CUBEMAP)
            .format(Texture.InternalFormat.RGBA16F)
            .usage(Texture.Usage.DEFAULT)
            .fenced { build(engine) }
        for ((level, pair) in mips.withIndex()) {
            val (curSize, buf) = pair
            tex.setImage(
                engine, level, 0, 0, 0, curSize, curSize, 6,
                Texture.PixelBufferDescriptor(
                    buf, Texture.Format.RGBA, Texture.Type.HALF))
        }
        return tex
    }

    // MARK: - Scalar helpers

    /** Plain (untagged) JSON `[r,g,b]` — env/sky fields serialize as
     * raw arrays, not the `{'v3':…}` node-property form. */
    fun rawVec3(a: JSONArray?): DoubleArray? {
        if (a == null || a.length() < 3) return null
        return doubleArrayOf(
            a.optDouble(0), a.optDouble(1), a.optDouble(2))
    }

    private fun f32le(data: ByteArray, offset: Int): Float {
        val bits = (data[offset].toInt() and 0xFF) or
            ((data[offset + 1].toInt() and 0xFF) shl 8) or
            ((data[offset + 2].toInt() and 0xFF) shl 16) or
            ((data[offset + 3].toInt() and 0xFF) shl 24)
        return Float.fromBits(bits)
    }

    /** IEEE-754 binary32 → binary16 (round-to-nearest-even). */
    private fun floatToHalfBits(f: Float): Int {
        val bits = f.toRawBits()
        val sign = (bits ushr 16) and 0x8000
        var value = bits and 0x7FFFFFFF
        if (value >= 0x7F800000) {          // Inf/NaN
            return sign or 0x7C00 or if (value and 0x007FFFFF != 0) 1 else 0
        }
        if (value > 0x477FEFFF) return sign or 0x7C00   // overflow → Inf
        if (value < 0x38800000) {            // underflow → subnormal/zero
            if (value < 0x33000000) return sign
            val shift = 125 - (value ushr 23)
            value = value or 0x800000
            var half = (value ushr (24 - shift)) and 0x7FFF
            // round to nearest even
            val roundBit = (value ushr (23 - shift)) and 1
            val sticky = value and ((1 shl (23 - shift)) - 1)
            if (roundBit != 0 && (sticky != 0 || (half and 1) != 0)) half++
            return sign or half
        }
        // Normal range: rebias the exponent (float 127 → half 15, i.e.
        // subtract 112 from the exponent field) before the 13-bit
        // mantissa shift. Without the rebias every texel ≥ ~0.5
        // decodes as Inf or a wildly wrong value — the specular cube
        // then whites out the scene at any intensity.
        var half = (value - 0x38000000 + 0x00001000 +
            ((value ushr 13) and 1)) ushr 13  // round-to-nearest-even
        return sign or (half and 0x7FFF)
    }

    private fun encodeSrgb(linear: Double): Byte {
        val c = linear.coerceIn(0.0, 1.0)
        val encoded = if (c <= 0.0031308) c * 12.92
            else 1.055 * c.pow(1.0 / 2.4) - 0.055
        return (encoded * 255.0).roundToInt().coerceIn(0, 255).toByte()
    }

    private fun srgbToLinear(c: Double): Double =
        if (c <= 0.04045) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)

    private fun smoothstep01(x: Double): Double {
        val t = x.coerceIn(0.0, 1.0)
        return t * t * (3.0 - 2.0 * t)
    }

    private fun smoothstep(edge0: Double, edge1: Double, x: Double): Double {
        if (abs(edge1 - edge0) < 1e-12) return if (x >= edge1) 1.0 else 0.0
        return smoothstep01((x - edge0) / (edge1 - edge0))
    }

    private fun lerp(a: Double, b: Double, t: Double) = a + (b - a) * t

    private fun ByteArray.indexOf(b: Byte, from: Int): Int {
        for (i in from until size) if (this[i] == b) return i
        return -1
    }

    private val SH_BASIS_CONST = doubleArrayOf(
        0.282095, 0.488603, 0.488603, 0.488603,
        1.092548, 1.092548, 0.315392, 1.092548, 0.546274)
}
