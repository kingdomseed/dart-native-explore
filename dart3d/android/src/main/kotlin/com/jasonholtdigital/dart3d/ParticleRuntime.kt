package com.jasonholtdigital.dart3d

import com.google.android.filament.Box
import com.google.android.filament.Engine
import com.google.android.filament.EntityManager
import com.google.android.filament.IndexBuffer
import com.google.android.filament.MaterialInstance
import com.google.android.filament.RenderableManager
import com.google.android.filament.Scene
import com.google.android.filament.VertexBuffer
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Random
import kotlin.math.PI
import kotlin.math.acos
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * The Android particle runtime (W18) — the Kotlin mirror of
 * `particle_sim.dart` (itself a line-for-line port of flutter_scene's
 * CPU particle stack) plus the Filament render binding upstream's
 * `ParticleEmitterComponent`/`MeshParticleEmitterComponent` perform.
 *
 * Coordinate convention: the wire (and the Dart reference sim) is
 * left-handed +Y up +Z forward. This runtime simulates directly in
 * Filament's right-handed node space the way the iOS twin maps onto
 * `SCNParticleSystem`: every directional spec input (shape directions,
 * gravity, acceleration, turbulence scroll) is z-mirrored at decode
 * (`d3Vec3Dir`), and shape-generated positions/velocities negate their
 * z on write. The tumble axis maps like a quaternion — (-x,-y,z) —
 * keeping the same angle. Determinism comes from [java.util.Random]
 * seeded by `seed`; the stream differs from Dart's `math.Random` but
 * each engine is self-consistent — the contract `seed` sells.
 *
 * Rendering:
 *  - `particleEmitter` → [SpriteParticleRuntime]: one renderable whose
 *    VertexBuffer carries `capacity*4` CPU-expanded billboard verts
 *    ([pos3 | uv0-2 | color4 | uv1-2 | frameBlend1] = 48B), repacked
 *    every frame the gate allows — the CPU twin of upstream's
 *    `BillboardGeometry` + `flutter_scene_billboard.vert` expansion
 *    math (verbatim, with the camera basis taken from the view's
 *    camera instead of a FrameInfo uniform).
 *  - `meshParticleEmitter` → [MeshParticleRuntime]: a baked pool of
 *    per-particle renderables. Filament's Java binding exposes
 *    `RenderableManager.Builder.instances` but no `InstanceBuffer`, so
 *    true instancing is unreachable — each live slot is a child entity
 *    of the emitter node with a per-frame TRS (docs/particles-spec.md
 *    carries the deviation).
 */

// ---------------------------------------------------------------------------
// Storage — the structure-of-arrays live set with swap-with-last kill.
// ---------------------------------------------------------------------------

class ParticleStorage(val capacity: Int) {
    val posX = FloatArray(capacity)
    val posY = FloatArray(capacity)
    val posZ = FloatArray(capacity)
    val velX = FloatArray(capacity)
    val velY = FloatArray(capacity)
    val velZ = FloatArray(capacity)
    val age = FloatArray(capacity)
    val lifetime = FloatArray(capacity)
    val rotation = FloatArray(capacity)
    val angularVelocity = FloatArray(capacity)
    val size = FloatArray(capacity)
    val baseSize = FloatArray(capacity)
    val colorR = FloatArray(capacity)
    val colorG = FloatArray(capacity)
    val colorB = FloatArray(capacity)
    val colorA = FloatArray(capacity)
    val frame = FloatArray(capacity)
    val axisX = FloatArray(capacity)
    val axisY = FloatArray(capacity)
    val axisZ = FloatArray(capacity)
    val random01 = FloatArray(capacity)

    var aliveCount = 0
        private set
    val isFull get() = aliveCount >= capacity

    fun spawn(): Int {
        if (aliveCount >= capacity) return -1
        return aliveCount++
    }

    fun kill(index: Int) {
        val last = aliveCount - 1
        if (index != last) copy(last, index)
        aliveCount--
    }

    fun clear() {
        aliveCount = 0
    }

    /** Upstream's `randomFor` — same double arithmetic as the Dart twin. */
    fun randomFor(index: Int, salt: Int): Double {
        val x = sin(random01[index].toDouble() * 127.1 +
            salt.toDouble() * 311.7) * 43758.5453
        return x - floor(x)
    }

    private fun copy(from: Int, to: Int) {
        posX[to] = posX[from]; posY[to] = posY[from]; posZ[to] = posZ[from]
        velX[to] = velX[from]; velY[to] = velY[from]; velZ[to] = velZ[from]
        age[to] = age[from]; lifetime[to] = lifetime[from]
        rotation[to] = rotation[from]; angularVelocity[to] = angularVelocity[from]
        size[to] = size[from]; baseSize[to] = baseSize[from]
        colorR[to] = colorR[from]; colorG[to] = colorG[from]
        colorB[to] = colorB[from]; colorA[to] = colorA[from]
        frame[to] = frame[from]
        axisX[to] = axisX[from]; axisY[to] = axisY[from]; axisZ[to] = axisZ[from]
        random01[to] = random01[from]
    }
}

// ---------------------------------------------------------------------------
// Curves / gradients — baked LUTs over normalized time (resolution 64).
// ---------------------------------------------------------------------------

class ParticleKeyframe(val t: Double, val v: Double)

class ParticleCurve(keyframes: List<ParticleKeyframe>, val resolution: Int = 64) {
    val keyframes: List<ParticleKeyframe> =
        keyframes.sortedBy { it.t }
    private val lut = FloatArray(resolution)

    init {
        for (i in 0 until resolution) {
            val t = i.toDouble() / (resolution - 1)
            lut[i] = evaluate(this.keyframes, t).toFloat()
        }
    }

    companion object {
        fun constant(value: Double) =
            ParticleCurve(listOf(ParticleKeyframe(0.0, value)), 2)

        private fun evaluate(sorted: List<ParticleKeyframe>, t: Double): Double {
            if (sorted.isEmpty()) return 0.0
            if (t <= sorted.first().t) return sorted.first().v
            if (t >= sorted.last().t) return sorted.last().v
            for (i in 0 until sorted.size - 1) {
                val a = sorted[i]
                val b = sorted[i + 1]
                if (t >= a.t && t <= b.t) {
                    val span = b.t - a.t
                    if (span <= 0) return b.v
                    return a.v + (b.v - a.v) * ((t - a.t) / span)
                }
            }
            return sorted.last().v
        }
    }

    fun sample(t: Double): Double {
        val clamped = if (t < 0.0) 0.0 else if (t > 1.0) 1.0 else t
        val x = clamped * (resolution - 1)
        val i = floor(x).toInt()
        if (i >= resolution - 1) return lut[resolution - 1].toDouble()
        val f = x - i
        return lut[i] + (lut[i + 1] - lut[i]) * f
    }
}

class ColorStop(val t: Double, val color: FloatArray)

class ColorGradient(stops: List<ColorStop>, val resolution: Int = 64) {
    val stops = stops.sortedBy { it.t }
    private val lut = FloatArray(resolution * 4)

    init {
        for (i in 0 until resolution) {
            val c = evaluate(this.stops, i.toDouble() / (resolution - 1))
            lut[i * 4] = c[0]; lut[i * 4 + 1] = c[1]
            lut[i * 4 + 2] = c[2]; lut[i * 4 + 3] = c[3]
        }
    }

    companion object {
        fun constant(color: FloatArray) =
            ColorGradient(listOf(ColorStop(0.0, color)), 2)

        private fun evaluate(sorted: List<ColorStop>, t: Double): FloatArray {
            if (sorted.isEmpty()) return floatArrayOf(1f, 1f, 1f, 1f)
            if (t <= sorted.first().t) return sorted.first().color
            if (t >= sorted.last().t) return sorted.last().color
            for (i in 0 until sorted.size - 1) {
                val a = sorted[i]
                val b = sorted[i + 1]
                if (t >= a.t && t <= b.t) {
                    val span = b.t - a.t
                    if (span <= 0) return b.color
                    val f = ((t - a.t) / span).toFloat()
                    return floatArrayOf(
                        a.color[0] + (b.color[0] - a.color[0]) * f,
                        a.color[1] + (b.color[1] - a.color[1]) * f,
                        a.color[2] + (b.color[2] - a.color[2]) * f,
                        a.color[3] + (b.color[3] - a.color[3]) * f,
                    )
                }
            }
            return sorted.last().color
        }
    }

    fun sample(t: Double, out: FloatArray) {
        val clamped = if (t < 0.0) 0.0 else if (t > 1.0) 1.0 else t
        val x = clamped * (resolution - 1)
        val i = floor(x).toInt()
        if (i >= resolution - 1) {
            val o = (resolution - 1) * 4
            out[0] = lut[o]; out[1] = lut[o + 1]
            out[2] = lut[o + 2]; out[3] = lut[o + 3]
            return
        }
        val f = (x - i).toFloat()
        val o = i * 4
        val n = o + 4
        out[0] = lut[o] + (lut[n] - lut[o]) * f
        out[1] = lut[o + 1] + (lut[n + 1] - lut[o + 1]) * f
        out[2] = lut[o + 2] + (lut[n + 2] - lut[o + 2]) * f
        out[3] = lut[o + 3] + (lut[n + 3] - lut[o + 3]) * f
    }
}

// ---------------------------------------------------------------------------
// Distributions
// ---------------------------------------------------------------------------

sealed class FloatDist {
    abstract fun sample(normalizedAge: Double, random01: Double): Double
}

class ConstantFloat(private val value: Double) : FloatDist() {
    override fun sample(normalizedAge: Double, random01: Double) = value
}

class UniformFloat(private val min: Double, private val max: Double) :
    FloatDist() {
    override fun sample(normalizedAge: Double, random01: Double) =
        min + (max - min) * random01
}

class CurveFloat(
    private val curve: ParticleCurve, private val scale: Double = 1.0,
) : FloatDist() {
    override fun sample(normalizedAge: Double, random01: Double) =
        curve.sample(normalizedAge) * scale
}

class UniformCurveFloat(
    private val min: ParticleCurve, private val max: ParticleCurve,
) : FloatDist() {
    override fun sample(normalizedAge: Double, random01: Double): Double {
        val lo = min.sample(normalizedAge)
        val hi = max.sample(normalizedAge)
        return lo + (hi - lo) * random01
    }
}

sealed class ColorDist {
    abstract fun sample(
        normalizedAge: Double, random01: Double, out: FloatArray,
    )
}

class ConstantColor(private val color: FloatArray) : ColorDist() {
    override fun sample(
        normalizedAge: Double, random01: Double, out: FloatArray,
    ) {
        out[0] = color[0]; out[1] = color[1]
        out[2] = color[2]; out[3] = color[3]
    }
}

class GradientColor(private val gradient: ColorGradient) : ColorDist() {
    override fun sample(
        normalizedAge: Double, random01: Double, out: FloatArray,
    ) = gradient.sample(normalizedAge, out)
}

class UniformColor(private val a: FloatArray, private val b: FloatArray) :
    ColorDist() {
    override fun sample(
        normalizedAge: Double, random01: Double, out: FloatArray,
    ) {
        val r = random01.toFloat()
        out[0] = a[0] + (b[0] - a[0]) * r
        out[1] = a[1] + (b[1] - a[1]) * r
        out[2] = a[2] + (b[2] - a[2]) * r
        out[3] = a[3] + (b[3] - a[3]) * r
    }
}

// ---------------------------------------------------------------------------
// Emitter shapes — spawn position + unit direction into storage. The
// generated z component negates on write so storage holds Filament's
// right-handed node space (spec-input directions arrive pre-mirrored).
// ---------------------------------------------------------------------------

private const val SALT_A = 20
private const val SALT_B = 21
private const val SALT_C = 22
private const val SALT_D = 23

sealed class EmitterShape {
    abstract fun sample(s: ParticleStorage, index: Int)
}

class PointEmitterShape(direction: FloatArray) : EmitterShape() {
    private val dir = normalize3(direction)
    override fun sample(s: ParticleStorage, index: Int) {
        s.posX[index] = 0f; s.posY[index] = 0f; s.posZ[index] = 0f
        s.velX[index] = dir[0]; s.velY[index] = dir[1]; s.velZ[index] = dir[2]
    }
}

class SphereEmitterShape(
    private val radius: Double = 1.0,
    private val surfaceOnly: Boolean = false,
    private val hemisphere: Boolean = false,
) : EmitterShape() {
    override fun sample(s: ParticleStorage, index: Int) {
        val u = s.randomFor(index, SALT_A)
        val v = s.randomFor(index, SALT_B)
        val y = if (hemisphere) u else (2.0 * u - 1.0)
        val ring = sqrt(max(0.0, 1.0 - y * y))
        val phi = 2.0 * PI * v
        val dx = ring * cos(phi)
        val dy = y
        val dz = ring * sin(phi)
        var magnitude = radius
        if (!surfaceOnly && radius > 0.0) {
            val w = s.randomFor(index, SALT_C)
            magnitude = radius * w.pow(1.0 / 3.0)
        }
        s.posX[index] = (dx * magnitude).toFloat()
        s.posY[index] = (dy * magnitude).toFloat()
        s.posZ[index] = (-dz * magnitude).toFloat()
        s.velX[index] = dx.toFloat()
        s.velY[index] = dy.toFloat()
        s.velZ[index] = (-dz).toFloat()
    }
}

class ConeEmitterShape(
    private val angle: Double = 0.5, private val radius: Double = 0.0,
) : EmitterShape() {
    override fun sample(s: ParticleStorage, index: Int) {
        val rr = radius * sqrt(s.randomFor(index, SALT_A))
        val theta = 2.0 * PI * s.randomFor(index, SALT_B)
        s.posX[index] = (rr * cos(theta)).toFloat()
        s.posY[index] = 0f
        s.posZ[index] = (-rr * sin(theta)).toFloat()
        val cosT = 1.0 - s.randomFor(index, SALT_C) * (1.0 - cos(angle))
        val sinT = sqrt(max(0.0, 1.0 - cosT * cosT))
        val phi = 2.0 * PI * s.randomFor(index, SALT_D)
        s.velX[index] = (sinT * cos(phi)).toFloat()
        s.velY[index] = cosT.toFloat()
        s.velZ[index] = (-sinT * sin(phi)).toFloat()
    }
}

class BoxEmitterShape(halfExtents: FloatArray, direction: FloatArray) :
    EmitterShape() {
    private val he = halfExtents
    private val dir = normalize3(direction)
    override fun sample(s: ParticleStorage, index: Int) {
        val rx = s.randomFor(index, SALT_A)
        val ry = s.randomFor(index, SALT_B)
        val rz = s.randomFor(index, SALT_C)
        s.posX[index] = (-he[0] + 2f * he[0] * rx).toFloat()
        s.posY[index] = (-he[1] + 2f * he[1] * ry).toFloat()
        // uniform over [-hz, +hz], mirrored — same distribution, the
        // consistent LH→RH sign convention.
        s.posZ[index] = -(-he[2] + 2f * he[2] * rz).toFloat()
        s.velX[index] = dir[0]; s.velY[index] = dir[1]; s.velZ[index] = dir[2]
    }
}

private fun normalize3(v: FloatArray): FloatArray {
    val l = sqrt((v[0] * v[0] + v[1] * v[1] + v[2] * v[2]).toDouble())
    return if (l > 0.0) floatArrayOf(
        (v[0] / l).toFloat(), (v[1] / l).toFloat(), (v[2] / l).toFloat())
    else floatArrayOf(0f, 1f, 0f)
}

// ---------------------------------------------------------------------------
// Spawner — fractional rate accumulation + half-open burst windows.
// ---------------------------------------------------------------------------

class ParticleBurst(
    val time: Double,
    val count: Int,
    val interval: Double = 0.0,
    val cycles: Int? = null,
)

class Spawner(var rate: Double = 0.0, val bursts: List<ParticleBurst>) {
    private var accumulator = 0.0

    fun emit(dt: Double, time: Double): Int {
        var count = 0
        if (rate > 0.0) {
            accumulator += rate * dt
            val whole = floor(accumulator)
            accumulator -= whole
            count += whole.toInt()
        }
        if (bursts.isNotEmpty()) {
            val end = time + dt
            for (burst in bursts) {
                if (burst.interval > 0.0) {
                    val inverse = 1.0 / burst.interval
                    var first = ceil((time - burst.time) * inverse).toInt()
                    if (first < 0) first = 0
                    var last = ceil((end - burst.time) * inverse).toInt() - 1
                    val cycles = burst.cycles
                    if (cycles != null && last > cycles - 1) last = cycles - 1
                    if (last >= first) count += (last - first + 1) * burst.count
                } else if (burst.time >= time && burst.time < end) {
                    count += burst.count
                }
            }
        }
        return count
    }

    fun reset() {
        accumulator = 0.0
    }
}

// ---------------------------------------------------------------------------
// Modules — spawn/update hooks applied in list order.
// ---------------------------------------------------------------------------

abstract class ParticleModule {
    open fun spawn(s: ParticleStorage, index: Int) {}
    open fun update(s: ParticleStorage, dt: Double) {}
}

class AccelerationModule(private val acceleration: FloatArray) :
    ParticleModule() {
    override fun update(s: ParticleStorage, dt: Double) {
        val ax = (acceleration[0] * dt).toFloat()
        val ay = (acceleration[1] * dt).toFloat()
        val az = (acceleration[2] * dt).toFloat()
        for (i in 0 until s.aliveCount) {
            s.velX[i] += ax; s.velY[i] += ay; s.velZ[i] += az
        }
    }
}

class LinearDragModule(private val coefficient: Double) : ParticleModule() {
    override fun update(s: ParticleStorage, dt: Double) {
        var factor = 1.0 - coefficient * dt
        if (factor < 0.0) factor = 0.0
        val f = factor.toFloat()
        for (i in 0 until s.aliveCount) {
            s.velX[i] *= f; s.velY[i] *= f; s.velZ[i] *= f
        }
    }
}

class SizeOverLifeModule(private val scale: FloatDist) : ParticleModule() {
    override fun update(s: ParticleStorage, dt: Double) {
        for (i in 0 until s.aliveCount) {
            val life = s.lifetime[i]
            val nAge = if (life > 0.0f) s.age[i] / life else 0f
            s.size[i] = (s.baseSize[i] *
                scale.sample(nAge.toDouble(), s.random01[i].toDouble()))
                .toFloat()
        }
    }
}

class ColorOverLifeModule(private val color: ColorDist) : ParticleModule() {
    private val tmp = FloatArray(4)
    override fun update(s: ParticleStorage, dt: Double) {
        for (i in 0 until s.aliveCount) {
            val life = s.lifetime[i]
            val nAge = if (life > 0.0f) s.age[i] / life else 0f
            color.sample(nAge.toDouble(), s.random01[i].toDouble(), tmp)
            s.colorR[i] = tmp[0]; s.colorG[i] = tmp[1]
            s.colorB[i] = tmp[2]; s.colorA[i] = tmp[3]
        }
    }
}

private const val SALT_FLIPBOOK_START = 10

class FlipbookModule(
    private val frameCount: Int,
    private val framesPerSecond: Double?,
    private val randomStartFrame: Boolean = false,
) : ParticleModule() {
    override fun update(s: ParticleStorage, dt: Double) {
        val count = frameCount.toDouble()
        for (i in 0 until s.aliveCount) {
            var frame = 0.0
            val fps = framesPerSecond
            if (fps == null) {
                val life = s.lifetime[i]
                val nAge = if (life > 0.0f) s.age[i] / life else 0f
                frame = nAge * count
                if (frame > count - 1.0) frame = count - 1.0
            } else {
                frame = s.age[i].toDouble() * fps
            }
            if (randomStartFrame) {
                frame += s.randomFor(i, SALT_FLIPBOOK_START) * count
            }
            s.frame[i] = (frame % count).toFloat()
        }
    }
}

/** Curl-noise advection — see the OpenSimplex2 port below. */
class TurbulenceModule(
    var strength: Double = 1.0,
    var frequency: Double = 1.0,
    scroll: FloatArray = floatArrayOf(0f, 0f, 0f),
    val seed: Int = 1337,
) : ParticleModule() {
    private val scroll = scroll
    private var time = 0.0
    private val curl = FloatArray(3)
    override fun update(s: ParticleStorage, dt: Double) {
        time += dt
        val ox = scroll[0] * time * frequency
        val oy = scroll[1] * time * frequency
        val oz = scroll[2] * time * frequency
        for (i in 0 until s.aliveCount) {
            noiseCurl3(
                s.posX[i] * frequency - ox,
                s.posY[i] * frequency - oy,
                s.posZ[i] * frequency - oz,
                seed = seed, out = curl,
            )
            s.velX[i] += (curl[0] * strength * dt).toFloat()
            s.velY[i] += (curl[1] * strength * dt).toFloat()
            s.velZ[i] += (curl[2] * strength * dt).toFloat()
        }
    }
}

class RotationModule : ParticleModule() {
    override fun update(s: ParticleStorage, dt: Double) {
        val d = dt.toFloat()
        for (i in 0 until s.aliveCount) {
            s.rotation[i] += s.angularVelocity[i] * d
        }
    }
}

// ---------------------------------------------------------------------------
// Curl noise — the OpenSimplex2-3D single octave of upstream's
// fast_noise_lite.dart, ported verbatim (Kotlin Ints are already
// wrapping 32-bit, so the `_i32` calls disappear). The gradient table
// is transcribed verbatim.
// ---------------------------------------------------------------------------

fun noiseCurl3(
    x: Double, y: Double, z: Double,
    seed: Int = 1337, epsilon: Double = 0.25,
    out: FloatArray,
) {
    val inv = 1.0 / (2.0 * epsilon)
    val p0y1 = potential(seed, x, y + epsilon, z)
    val p0y0 = potential(seed, x, y - epsilon, z)
    val p0z1 = potential(seed, x, y, z + epsilon)
    val p0z0 = potential(seed, x, y, z - epsilon)
    val p1x1 = potential(seed + 1, x + epsilon, y, z)
    val p1x0 = potential(seed + 1, x - epsilon, y, z)
    val p1z1 = potential(seed + 1, x, y, z + epsilon)
    val p1z0 = potential(seed + 1, x, y, z - epsilon)
    val p2x1 = potential(seed + 2, x + epsilon, y, z)
    val p2x0 = potential(seed + 2, x - epsilon, y, z)
    val p2y1 = potential(seed + 2, x, y + epsilon, z)
    val p2y0 = potential(seed + 2, x, y - epsilon, z)
    out[0] = (((p2y1 - p2y0) - (p1z1 - p1z0)) * inv).toFloat()
    out[1] = (((p0z1 - p0z0) - (p2x1 - p2x0)) * inv).toFloat()
    out[2] = (((p1x1 - p1x0) - (p0y1 - p0y0)) * inv).toFloat()
}

private fun potential(seed: Int, x: Double, y: Double, z: Double): Double {
    // getNoise3's OpenSimplex2 pre-rotation (r3 = 2/3) then the single
    // octave — frequency is 1.0 at the call site.
    val r3 = 2.0 / 3.0
    val r = (x + y + z) * r3
    return singleOpenSimplex2_3(seed, r - x, r - y, r - z)
}

private const val PRIME_X = 501125321
private const val PRIME_Y = 1136930381
private const val PRIME_Z = 1720413743

private fun fastRound(f: Double) = if (f >= 0) (f + 0.5).toInt()
else (f - 0.5).toInt()

private fun hash3(seed: Int, xPrimed: Int, yPrimed: Int, zPrimed: Int): Int {
    var hash = seed xor xPrimed xor yPrimed xor zPrimed
    hash *= 0x27d4eb2d
    return hash
}

private fun gradCoord3(
    seed: Int, xPrimed: Int, yPrimed: Int, zPrimed: Int,
    xd: Double, yd: Double, zd: Double,
): Double {
    var hash = hash3(seed, xPrimed, yPrimed, zPrimed)
    hash = hash xor (hash shr 15)
    hash = hash and (63 shl 2)
    val xg = GRADIENTS_3D[hash]
    val yg = GRADIENTS_3D[hash or 1]
    val zg = GRADIENTS_3D[hash or 2]
    return xd * xg + yd * yg + zd * zg
}

private fun singleOpenSimplex2_3(
    seedIn: Int, x: Double, y: Double, z: Double,
): Double {
    var seed = seedIn
    var i = fastRound(x)
    var j = fastRound(y)
    var k = fastRound(z)
    var x0 = x - i
    var y0 = y - j
    var z0 = z - k

    var xNSign = (-1.0 - x0).toInt() or 1
    var yNSign = (-1.0 - y0).toInt() or 1
    var zNSign = (-1.0 - z0).toInt() or 1

    var ax0 = xNSign * -x0
    var ay0 = yNSign * -y0
    var az0 = zNSign * -z0

    i *= PRIME_X
    j *= PRIME_Y
    k *= PRIME_Z

    var value = 0.0
    var a = (0.6 - x0 * x0) - (y0 * y0 + z0 * z0)

    var l = 0
    while (true) {
        if (a > 0) {
            value += (a * a) * (a * a) * gradCoord3(seed, i, j, k, x0, y0, z0)
        }

        if (ax0 >= ay0 && ax0 >= az0) {
            var b = a + ax0 + ax0
            if (b > 1) {
                b -= 1
                value += (b * b) * (b * b) * gradCoord3(
                    seed, i - xNSign * PRIME_X, j, k,
                    x0 + xNSign, y0, z0)
            }
        } else if (ay0 > ax0 && ay0 >= az0) {
            var b = a + ay0 + ay0
            if (b > 1) {
                b -= 1
                value += (b * b) * (b * b) * gradCoord3(
                    seed, i, j - yNSign * PRIME_Y, k,
                    x0, y0 + yNSign, z0)
            }
        } else {
            var b = a + az0 + az0
            if (b > 1) {
                b -= 1
                value += (b * b) * (b * b) * gradCoord3(
                    seed, i, j, k - zNSign * PRIME_Z,
                    x0, y0, z0 + zNSign)
            }
        }

        if (l == 1) break

        ax0 = 0.5 - ax0
        ay0 = 0.5 - ay0
        az0 = 0.5 - az0

        x0 = xNSign * ax0
        y0 = yNSign * ay0
        z0 = zNSign * az0

        a += (0.75 - ax0) - (ay0 + az0)

        i += (xNSign shr 1) and PRIME_X
        j += (yNSign shr 1) and PRIME_Y
        k += (zNSign shr 1) and PRIME_Z

        xNSign = -xNSign
        yNSign = -yNSign
        zNSign = -zNSign

        seed = seed.inv()
        l++
    }

    return value * 32.69428253173828125
}

// 64 gradient vectors, stride 4 (w padded 0) — transcribed verbatim
// from upstream fast_noise_lite.dart's `_gradients3D`.
private val GRADIENTS_3D = doubleArrayOf(
    0.0, 1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0, 1.0, -1.0, 0.0,
    0.0, -1.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0,
    1.0, 0.0, -1.0, 0.0, -1.0, 0.0, -1.0, 0.0, 0.0, 1.0, 1.0, 0.0,
    0.0, -1.0, 1.0, 0.0, 0.0, 1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0,
    0.0, 0.0, 1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0, 1.0, -1.0, 0.0,
    0.0, -1.0, -1.0, 0.0, 0.0, 0.0, 1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0,
    0.0, 1.0, 0.0, -1.0, 0.0, -1.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0,
    -1.0, 0.0, -1.0, 0.0, 0.0, 1.0, 0.0, -1.0, 0.0, -1.0, 0.0, -1.0, 0.0,
    0.0, 1.0, 1.0, 0.0, 1.0, 0.0, -1.0, 0.0, -1.0, 1.0, 0.0, 0.0,
    -1.0, -1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0,
    -1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 0.0,
    1.0, 0.0, -1.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0,
    0.0, -1.0, 0.0, -1.0, 0.0, -1.0, -1.0, 0.0, -1.0, 0.0, 0.0, -1.0,
    -1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, -1.0, 0.0, -1.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, 0.0, 1.0, 0.0,
    -1.0, 0.0, 0.0, -1.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, -1.0, 0.0,
    -1.0, 0.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0, 1.0, -1.0, 0.0,
    0.0, -1.0, -1.0, 0.0, 1.0, 1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0,
    1.0, -1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 1.0, 1.0, 0.0, -1.0, -1.0,
    1.0, 0.0, -1.0, 1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0, 1.0, 0.0, -1.0,
    0.0, -1.0, 0.0, -1.0, 0.0, -1.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0,
    -1.0, 0.0, -1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0,
    0.0, 1.0, -1.0, -1.0, 0.0, -1.0, 0.0, -1.0, 1.0, 0.0, 0.0, -1.0,
    -1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0, 1.0, -1.0, 0.0, 0.0, 1.0,
    1.0, 0.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0,
    1.0, -1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 0.0,
)

// ---------------------------------------------------------------------------
// The system — upstream ParticleSystem verbatim modulo naming.
// ---------------------------------------------------------------------------

private const val SALT_LIFETIME = 1
private const val SALT_SPEED = 2
private const val SALT_SIZE = 3
private const val SALT_ROTATION = 4
private const val SALT_ANGULAR_VELOCITY = 5
private const val SALT_COLOR = 6
private const val SALT_AXIS_THETA = 7
private const val SALT_AXIS_Z = 8

private const val MIN_LIFETIME = 1e-4

class ParticleSystem(
    maxParticles: Int = 1024,
    var shape: EmitterShape,
    val spawner: Spawner,
    val modules: List<ParticleModule> = emptyList(),
    var lifetime: FloatDist = ConstantFloat(1.0),
    var startSpeed: FloatDist = ConstantFloat(0.0),
    var startSize: FloatDist = ConstantFloat(1.0),
    var startRotation: FloatDist = ConstantFloat(0.0),
    var startAngularVelocity: FloatDist = ConstantFloat(0.0),
    var startColor: ColorDist = ConstantColor(floatArrayOf(1f, 1f, 1f, 1f)),
    gravity: FloatArray = floatArrayOf(0f, 0f, 0f),
    var looping: Boolean = true,
    var duration: Double = 5.0,
    val fixedStep: Double = 1.0 / 60.0,
    val maxFrameTime: Double = 0.25,
    val seed: Int = 0,
    val prewarm: Double = 0.0,
) {
    val storage = ParticleStorage(maxParticles)
    val gravity = gravity
    private var random = Random(seed.toLong())
    private var accumulator = 0.0
    var systemTime = 0.0
        private set
    private val tmpColor = FloatArray(4)

    init {
        if (prewarm > 0.0) {
            val steps = floor(prewarm / fixedStep).toInt()
            for (i in 0 until steps) {
                stepFixed(fixedStep)
            }
        }
    }

    fun step(dtIn: Double) {
        var frame = dtIn
        if (frame < 0.0) frame = 0.0
        if (frame > maxFrameTime) frame = maxFrameTime
        accumulator += frame
        while (accumulator >= fixedStep) {
            stepFixed(fixedStep)
            accumulator -= fixedStep
        }
    }

    fun reset() {
        storage.clear()
        spawner.reset()
        random = Random(seed.toLong())
        accumulator = 0.0
        systemTime = 0.0
    }

    private fun stepFixed(dt: Double) {
        if (looping || systemTime < duration) {
            val toSpawn = spawner.emit(dt, systemTime)
            var i = 0
            while (i < toSpawn) {
                val index = storage.spawn()
                if (index < 0) break
                initParticle(index)
                i++
            }
        }
        for (module in modules) {
            module.update(storage, dt)
        }
        val gx = (gravity[0] * dt).toFloat()
        val gy = (gravity[1] * dt).toFloat()
        val gz = (gravity[2] * dt).toFloat()
        val n = storage.aliveCount
        for (i in 0 until n) {
            storage.velX[i] += gx
            storage.velY[i] += gy
            storage.velZ[i] += gz
            storage.posX[i] += storage.velX[i] * dt.toFloat()
            storage.posY[i] += storage.velY[i] * dt.toFloat()
            storage.posZ[i] += storage.velZ[i] * dt.toFloat()
        }
        var i = storage.aliveCount - 1
        while (i >= 0) {
            storage.age[i] += dt.toFloat()
            if (storage.age[i] >= storage.lifetime[i]) {
                storage.kill(i)
            }
            i--
        }
        systemTime += dt
    }

    private fun initParticle(index: Int) {
        val s = storage
        s.random01[index] = random.nextDouble().toFloat()
        s.age[index] = 0f

        shape.sample(s, index)

        var life = lifetime.sample(0.0, s.randomFor(index, SALT_LIFETIME))
        if (life < MIN_LIFETIME) life = MIN_LIFETIME
        s.lifetime[index] = life.toFloat()

        val speed = startSpeed.sample(0.0, s.randomFor(index, SALT_SPEED))
        s.velX[index] *= speed.toFloat()
        s.velY[index] *= speed.toFloat()
        s.velZ[index] *= speed.toFloat()

        val size = startSize.sample(0.0, s.randomFor(index, SALT_SIZE))
        s.size[index] = size.toFloat()
        s.baseSize[index] = size.toFloat()

        s.rotation[index] = startRotation
            .sample(0.0, s.randomFor(index, SALT_ROTATION)).toFloat()
        s.angularVelocity[index] = startAngularVelocity
            .sample(0.0, s.randomFor(index, SALT_ANGULAR_VELOCITY)).toFloat()

        startColor.sample(0.0, s.randomFor(index, SALT_COLOR), tmpColor)
        s.colorR[index] = tmpColor[0]
        s.colorG[index] = tmpColor[1]
        s.colorB[index] = tmpColor[2]
        s.colorA[index] = tmpColor[3]

        s.frame[index] = 0f

        val az = s.randomFor(index, SALT_AXIS_Z) * 2.0 - 1.0
        val at = s.randomFor(index, SALT_AXIS_THETA) * 2.0 * PI
        val ar = sqrt(max(0.0, 1.0 - az * az))
        // LH tumble axis → RH under the wire z-mirror convention the
        // quaternion mapping uses: (-x, -y, z), angle unchanged.
        s.axisX[index] = (-ar * cos(at)).toFloat()
        s.axisY[index] = (-ar * sin(at)).toFloat()
        s.axisZ[index] = az.toFloat()

        for (module in modules) {
            module.spawn(s, index)
        }
    }
}

// ---------------------------------------------------------------------------
// Spec decode — the tagged-JSONObject twin of particle_sim.dart's
// `particleSystemFromProperties`/`spriteEmitterSpecFromProperties`/
// `meshEmitterSpecFromProperties`, legacy flat keys included.
// ---------------------------------------------------------------------------

object ParticleSpec {
    const val MAX_PARTICLES = 512
    const val EMIT_RATE = 32.0
    const val LIFETIME = 1.5
    const val START_SPEED = 1.5
    const val START_SIZE = 0.3
    const val SHAPE_RADIUS = 0.25
    const val SHAPE_ANGLE = 0.3
    const val DURATION = 5.0
    const val FIXED_STEP = 1.0 / 60.0
    const val MAX_FRAME_TIME = 0.25

    fun nonNegative(v: Double) = if (v < 0) 0.0 else v

    // Tagged-value readers mirroring _num/_int/_bool/_str/_vec3 —
    // `_int` on a DoubleValue ROUNDS (Dart .round()), so these wrap
    // the d3* helpers rather than reusing them bare.
    fun num(p: JSONObject, key: String, fallback: Double): Double {
        val o = p.tag(key) as? JSONObject ?: return fallback
        val raw = if (o.has("d")) o.opt("d") else o.opt("i") ?: return fallback
        return (raw as? Number)?.toDouble() ?: fallback
    }

    fun int(p: JSONObject, key: String, fallback: Int): Int {
        val o = p.tag(key) as? JSONObject ?: return fallback
        if (o.has("i")) (o.opt("i") as? Number)?.let { return it.toInt() }
        (o.opt("d") as? Number)?.let { return it.toDouble().roundToInt() }
        return fallback
    }

    fun bool(p: JSONObject, key: String, fallback: Boolean): Boolean {
        val o = p.tag(key) as? JSONObject ?: return fallback
        return if (o.has("b")) o.optBoolean("b") else fallback
    }

    fun str(p: JSONObject, key: String, fallback: String): String =
        p.tag(key).d3String() ?: fallback

    /** vec3 field read verbatim (wire/LH space). */
    fun vec3(p: JSONObject, key: String, fallback: FloatArray): FloatArray {
        val a = p.tag(key).d3Vec3()
        return if (a != null && a.size >= 3) floatArrayOf(
            a[0].toFloat(), a[1].toFloat(), a[2].toFloat()) else fallback
    }

    /** vec3 direction field read into engine space (z negated). */
    fun vec3Dir(p: JSONObject, key: String, fallback: FloatArray): FloatArray {
        val a = p.tag(key).d3Vec3()
        return if (a != null && a.size >= 3) floatArrayOf(
            a[0].toFloat(), a[1].toFloat(), (-a[2]).toFloat()) else fallback
    }

    fun color(p: JSONObject, key: String, fallback: FloatArray): FloatArray =
        p.tag(key).d3Color() ?: fallback

    private fun colorValue(v: Any?, fallback: FloatArray): FloatArray =
        v.d3Color() ?: fallback

    fun curve(v: Any?): ParticleCurve {
        val keys = ArrayList<ParticleKeyframe>()
        val list = (v as? JSONObject)?.d3Map()?.tag("keys")?.d3List()
        if (list != null) {
            for (i in 0 until list.length()) {
                val k = list.optJSONObject(i)?.d3Map() ?: continue
                keys.add(ParticleKeyframe(num(k, "t", 0.0), num(k, "v", 0.0)))
            }
        }
        return ParticleCurve(keys)
    }

    fun gradient(v: Any?): ColorGradient {
        val stops = ArrayList<ColorStop>()
        val list = (v as? JSONObject)?.d3Map()?.tag("stops")?.d3List()
        if (list != null) {
            for (i in 0 until list.length()) {
                val s = list.optJSONObject(i)?.d3Map() ?: continue
                stops.add(ColorStop(num(s, "t", 0.0),
                    colorValue(s.tag("color"), floatArrayOf(1f, 1f, 1f, 1f))))
            }
        }
        return ColorGradient(stops)
    }

    fun floatDist(v: Any?, fallback: Double): FloatDist {
        val m = (v as? JSONObject)?.d3Map()
            ?: return ConstantFloat(fallback)
        return when (str(m, "kind", "constant")) {
            "uniform" -> UniformFloat(
                num(m, "min", fallback), num(m, "max", fallback))
            "curve" -> CurveFloat(
                curve(m.tag("curve")), num(m, "scale", 1.0))
            "uniformCurve" -> UniformCurveFloat(
                curve(m.tag("min")), curve(m.tag("max")))
            else -> ConstantFloat(num(m, "value", fallback))
        }
    }

    fun colorDist(v: Any?, fallback: FloatArray = floatArrayOf(1f, 1f, 1f, 1f)):
        ColorDist {
        val m = (v as? JSONObject)?.d3Map()
            ?: return ConstantColor(fallback)
        return when (str(m, "kind", "constant")) {
            "gradient" -> GradientColor(gradient(m.tag("gradient")))
            "uniform" -> UniformColor(
                colorValue(m.tag("a"), fallback),
                colorValue(m.tag("b"), fallback))
            else -> ConstantColor(colorValue(m.tag("color"), fallback))
        }
    }

    fun emitterShape(v: Any?): EmitterShape {
        val m = (v as? JSONObject)?.d3Map() ?: return defaultShape()
        return when (str(m, "kind", "cone")) {
            "point" -> PointEmitterShape(
                vec3Dir(m, "direction", floatArrayOf(0f, 1f, 0f)))
            "sphere" -> SphereEmitterShape(
                radius = nonNegative(num(m, "radius", 1.0)),
                surfaceOnly = bool(m, "surfaceOnly", false),
                hemisphere = bool(m, "hemisphere", false))
            "box" -> BoxEmitterShape(
                halfExtents = vec3(m, "halfExtents",
                    floatArrayOf(0.5f, 0.5f, 0.5f)),
                direction = vec3Dir(m, "direction",
                    floatArrayOf(0f, 1f, 0f)))
            else -> ConeEmitterShape(
                radius = nonNegative(num(m, "radius", 0.0)),
                angle = nonNegative(num(m, "angle", 0.5)))
        }
    }

    fun module(v: Any?): ParticleModule? {
        val m = (v as? JSONObject)?.d3Map() ?: return null
        return when (str(m, "kind", "")) {
            "acceleration" -> AccelerationModule(
                vec3Dir(m, "acceleration", floatArrayOf(0f, 0f, 0f)))
            "linearDrag" -> LinearDragModule(
                nonNegative(num(m, "coefficient", 0.0)))
            "sizeOverLife" -> SizeOverLifeModule(
                floatDist(m.tag("scale"), 1.0))
            "colorOverLife" -> ColorOverLifeModule(
                colorDist(m.tag("color")))
            "flipbook" -> {
                val frameCount = int(m, "frameCount", 1)
                val fps = num(m, "framesPerSecond", 0.0)
                FlipbookModule(
                    frameCount = if (frameCount < 1) 1 else frameCount,
                    framesPerSecond = if (fps > 0) fps else null,
                    randomStartFrame = bool(m, "randomStartFrame", false))
            }
            "turbulence" -> TurbulenceModule(
                strength = num(m, "strength", 1.0),
                frequency = num(m, "frequency", 1.0),
                scroll = vec3Dir(m, "scroll", floatArrayOf(0f, 0f, 0f)),
                seed = int(m, "seed", 1337))
            "rotation" -> RotationModule()
            else -> null
        }
    }

    fun burst(v: Any?): ParticleBurst? {
        val m = (v as? JSONObject)?.d3Map() ?: return null
        val cyclesV = m.tag("cycles")
        val cyclesI = (cyclesV as? JSONObject)?.opt("i") as? Number
        return ParticleBurst(
            time = nonNegative(num(m, "time", 0.0)),
            count = max(0, int(m, "count", 0)),
            interval = num(m, "interval", 0.0),
            cycles = cyclesI?.toInt()?.let { if (it < 1) 1 else it })
    }

    fun defaultShape() = ConeEmitterShape(
        angle = SHAPE_ANGLE, radius = SHAPE_RADIUS)

    private fun shapeFromProperties(p: JSONObject): EmitterShape {
        if (p.tag("shape") is JSONObject &&
            (p.tag("shape") as JSONObject).d3Map() != null) {
            return emitterShape(p.tag("shape"))
        }
        val radius = nonNegative(num(p, "shapeRadius", SHAPE_RADIUS))
        val angle = nonNegative(num(p, "shapeAngle", SHAPE_ANGLE))
        return when (str(p, "shapeType", "cone")) {
            "point" -> PointEmitterShape(floatArrayOf(0f, 1f, 0f))
            "sphere" -> SphereEmitterShape(radius = radius)
            "box" -> BoxEmitterShape(
                halfExtents = floatArrayOf(
                    radius.toFloat(), radius.toFloat(), radius.toFloat()),
                direction = floatArrayOf(0f, 1f, 0f))
            else -> ConeEmitterShape(angle = angle, radius = radius)
        }
    }

    private fun modulesFromProperties(p: JSONObject): List<ParticleModule> {
        val list = p.tag("modules")?.d3List()
        if (list != null) {
            val out = ArrayList<ParticleModule>()
            for (i in 0 until list.length()) {
                module(list.opt(i))?.let { out.add(it) }
            }
            return out
        }
        // Legacy fixed stack — absent curve/gradient means "no shaping".
        val drag = num(p, "drag", 0.0)
        val sizeOverLife = p.tag("sizeOverLife")
        val colorOverLife = p.tag("colorOverLife")
        val out = ArrayList<ParticleModule>()
        if (drag > 0) out.add(LinearDragModule(drag))
        out.add(SizeOverLifeModule(CurveFloat(
            if (sizeOverLife != null) curve(sizeOverLife)
            else ParticleCurve.constant(1.0))))
        out.add(ColorOverLifeModule(GradientColor(
            if (colorOverLife != null) gradient(colorOverLife)
            else ColorGradient.constant(floatArrayOf(1f, 1f, 1f, 1f)))))
        out.add(RotationModule())
        return out
    }

    private fun burstsFromProperties(p: JSONObject): List<ParticleBurst> {
        val list = p.tag("bursts")?.d3List() ?: return emptyList()
        val out = ArrayList<ParticleBurst>()
        for (i in 0 until list.length()) {
            burst(list.opt(i))?.let { out.add(it) }
        }
        return out
    }

    /** Port of upstream `particleSystemFromProperties`. */
    fun system(p: JSONObject): ParticleSystem {
        val stepIn = num(p, "fixedStep", FIXED_STEP)
        val fixedStep = if (stepIn > 0) stepIn else FIXED_STEP
        var maxFrameTime = num(p, "maxFrameTime", MAX_FRAME_TIME)
        if (maxFrameTime < fixedStep) maxFrameTime = fixedStep
        val duration = num(p, "duration", DURATION)
        val maxParticles = int(p, "maxParticles", MAX_PARTICLES)
        return ParticleSystem(
            maxParticles = if (maxParticles < 1) 1 else maxParticles,
            shape = shapeFromProperties(p),
            spawner = Spawner(
                rate = nonNegative(num(p, "emitRate", EMIT_RATE)),
                bursts = burstsFromProperties(p)),
            modules = modulesFromProperties(p),
            lifetime = floatDist(p.tag("lifetime"), LIFETIME),
            startSpeed = floatDist(p.tag("startSpeed"), START_SPEED),
            startSize = floatDist(p.tag("startSize"), START_SIZE),
            startRotation = floatDist(p.tag("startRotation"), 0.0),
            startAngularVelocity =
                floatDist(p.tag("startAngularVelocity"), 0.0),
            startColor = colorDist(p.tag("startColor")),
            gravity = vec3Dir(p, "gravity", floatArrayOf(0f, 0f, 0f)),
            looping = bool(p, "looping", true),
            duration = if (duration > 0) duration else DURATION,
            fixedStep = fixedStep,
            maxFrameTime = maxFrameTime,
            seed = int(p, "seed", 0),
            prewarm = nonNegative(num(p, "prewarm", 0.0)),
        )
    }
}

/** The render-side half of a `particleEmitter` spec. */
class SpriteEmitterSpec(p: JSONObject) {
    val blendMode = ParticleSpec.str(p, "blendMode", "alpha")
    val facing = ParticleSpec.str(p, "facing", "spherical")
    val velocityStretch =
        ParticleSpec.nonNegative(ParticleSpec.num(p, "velocityStretch", 0.0))
    val paused = ParticleSpec.bool(p, "paused", false)
    val flipbookColumns =
        max(1, ParticleSpec.int(p, "flipbookColumns", 1))
    val flipbookRows = max(1, ParticleSpec.int(p, "flipbookRows", 1))
    val flipbookBlend = ParticleSpec.bool(p, "flipbookBlend", false)
    val randomFlipX = ParticleSpec.bool(p, "randomFlipX", false)
    val aspectRatio =
        ParticleSpec.nonNegative(ParticleSpec.num(p, "aspectRatio", 1.0))
    val texture = p.tag("texture").d3Ref()
    val enabled = ParticleSpec.bool(p, "enabled", true)
}

/** The render-side half of a `meshParticleEmitter` spec. */
class MeshEmitterSpec(p: JSONObject) {
    val geometries: List<Long> = run {
        val out = ArrayList<Long>()
        val list = p.tag("geometries")?.d3List()
        if (list != null) {
            for (i in 0 until list.length()) {
                list.opt(i).d3Ref()?.let { out.add(it) }
            }
        }
        out
    }
    val material = p.tag("material").d3Ref()
    val facing = ParticleSpec.str(p, "facing", "tumble")
    val paused = ParticleSpec.bool(p, "paused", false)
    val enabled = ParticleSpec.bool(p, "enabled", true)
}

// ---------------------------------------------------------------------------
// Runtimes — the per-component live objects the frame tick drives.
// ---------------------------------------------------------------------------

/**
 * A live emitter component on a node. `enabled:false` skips creation
 * entirely at decode (upstream gates update AND repack — the
 * equivalent is no system at all, same as the iOS twin), so a live
 * runtime is always enabled; [paused] holds the sim while the last
 * repacked state keeps drawing (upstream `Component.update` parity).
 */
abstract class ParticleRuntime(
    val host: Dart3dView,
    val system: ParticleSystem,
    var paused: Boolean,
) {
    /** Whether the runtime's entities are currently scene members. */
    var attached = false
        private set
    var layers = 1

    /** Advance (unless paused) then repack — upstream update() order. */
    fun tick(dt: Double, camPos: FloatArray, nodeWorld: FloatArray) {
        if (!paused) system.step(dt)
        repack(camPos, nodeWorld)
    }

    protected abstract fun repack(camPos: FloatArray, nodeWorld: FloatArray)
    protected abstract fun attach(scene: Scene)
    protected abstract fun detach(scene: Scene)

    /** Scene membership follows the node's resolved visibility. */
    fun setSceneVisible(visible: Boolean) {
        if (visible && !attached) {
            attach(host.scene)
            attached = true
        } else if (!visible && attached) {
            detach(host.scene)
            attached = false
        }
    }

    /** `updateNode` layers flag — retarget the runtime's mask. */
    open fun applyLayers(layers: Int) {
        this.layers = layers
    }

    abstract fun destroy()
}

/**
 * `particleEmitter` — one entity drawing all live particles as
 * camera-facing quads expanded on the CPU into world space (the
 * renderable takes an identity transform; `vertexDomain: WORLD`
 * materials pass the positions through). Port of upstream
 * `BillboardGeometry.commit` + `flutter_scene_billboard.vert`.
 */
class SpriteParticleRuntime(
    host: Dart3dView,
    system: ParticleSystem,
    private val spec: SpriteEmitterSpec,
    val entity: Int,
    private val vertexBuffer: VertexBuffer,
    private val indexBuffer: IndexBuffer,
    val materialInstance: MaterialInstance,
    private val textureKey: Long?,
) : ParticleRuntime(host, system, spec.paused) {

    private val engine get() = host.engine

    // Quad corners + UVs — upstream's shared unit quad verbatim:
    // corner (-0.5,-0.5)→uv (0,1), (0.5,-0.5)→(1,1),
    // (-0.5,0.5)→(0,0), (0.5,0.5)→(1,0); indices 0,1,2, 2,1,3.
    private val cornerX = floatArrayOf(-0.5f, 0.5f, -0.5f, 0.5f)
    private val cornerY = floatArrayOf(-0.5f, -0.5f, 0.5f, 0.5f)
    private val quadU = floatArrayOf(0f, 1f, 0f, 1f)
    private val quadV = floatArrayOf(1f, 1f, 0f, 0f)

    private val cpuBuf = ByteBuffer
        .allocateDirect(system.storage.capacity * 4 * VERTEX_BYTES)
        .order(ByteOrder.nativeOrder())
    private val floats = cpuBuf.asFloatBuffer()
    private var liveDrawCount = -1

    override fun repack(camPos: FloatArray, nodeWorld: FloatArray) {
        val s = system.storage
        val count = s.aliveCount
        val buf = floats
        buf.clear()

        val cols = max(1, spec.flipbookColumns).toDouble()
        val rows = max(1, spec.flipbookRows).toDouble()
        val total = cols * rows
        val cellW = 1.0 / cols
        val cellH = 1.0 / rows
        val blendOn = if (spec.flipbookBlend) 1.0 else 0.0

        // world_up — upstream BillboardGeometry.worldUp default +Y;
        // the z-mirror convention leaves it unchanged.
        val wux = 0f; val wuy = 1f; val wuz = 0f

        // Scratch basis vectors reused across particles — the repack
        // runs per emitter per frame, so per-particle allocation here
        // is GC churn at 1000+ particles.
        val right = FloatArray(3)
        val up = FloatArray(3)

        for (i in 0 until count) {
            val size = s.size[i]
            var width = (size * spec.aspectRatio).toFloat()
            if (spec.randomFlipX && s.random01[i] < 0.5f) width = -width
            val height = size

            // world_center = nodeWorld · local (column-major m[c*4+r]).
            val lx = s.posX[i]; val ly = s.posY[i]; val lz = s.posZ[i]
            val wcx = nodeWorld[0] * lx + nodeWorld[4] * ly +
                nodeWorld[8] * lz + nodeWorld[12]
            val wcy = nodeWorld[1] * lx + nodeWorld[5] * ly +
                nodeWorld[9] * lz + nodeWorld[13]
            val wcz = nodeWorld[2] * lx + nodeWorld[6] * ly +
                nodeWorld[10] * lz + nodeWorld[14]

            val vdx = wcx - camPos[0]
            val vdy = wcy - camPos[1]
            val vdz = wcz - camPos[2]
            val vd2 = vdx * vdx + vdy * vdy + vdz * vdz
            val tex: Float; val tey: Float; val tez: Float
            if (vd2 > 1e-12f) {
                val inv = 1f / sqrt(vd2)
                tex = -vdx * inv; tey = -vdy * inv; tez = -vdz * inv
            } else {
                tex = 0f; tey = 0f; tez = 1f
            }

            var stretchLen = 0f
            when (spec.facing) {
                "velocityStretched" -> {
                    // world_vel = mat3(nodeWorld) · local vel.
                    val lvx = s.velX[i]; val lvy = s.velY[i]
                    val lvz = s.velZ[i]
                    val wvx = nodeWorld[0] * lvx + nodeWorld[4] * lvy +
                        nodeWorld[8] * lvz
                    val wvy = nodeWorld[1] * lvx + nodeWorld[5] * lvy +
                        nodeWorld[9] * lvz
                    val wvz = nodeWorld[2] * lvx + nodeWorld[6] * lvy +
                        nodeWorld[10] * lvz
                    val speed = sqrt(wvx * wvx + wvy * wvy + wvz * wvz)
                    if (speed > 1e-5f) {
                        up[0] = wvx / speed; up[1] = wvy / speed
                        up[2] = wvz / speed
                        var rx = up[1] * tez - up[2] * tey
                        var ry = up[2] * tex - up[0] * tez
                        var rz = up[0] * tey - up[1] * tex
                        val rl = sqrt(rx * rx + ry * ry + rz * rz)
                        if (rl > 1e-5f) {
                            rx /= rl; ry /= rl; rz /= rl
                        } else {
                            // right = normalize(cross(up, world_up))
                            var fx = up[1] * wuz - up[2] * wuy
                            var fy = up[2] * wux - up[0] * wuz
                            var fz = up[0] * wuy - up[1] * wux
                            val fl = sqrt(fx * fx + fy * fy + fz * fz)
                            if (fl > 1e-5f) { fx /= fl; fy /= fl; fz /= fl }
                            rx = fx; ry = fy; rz = fz
                        }
                        right[0] = rx; right[1] = ry; right[2] = rz
                        stretchLen = speed * spec.velocityStretch.toFloat()
                    } else {
                        val fwdX = tex; val fwdY = tey; val fwdZ = tez
                        // right = normalize(cross(world_up, fwd))
                        var rx = wuy * fwdZ - wuz * fwdY
                        var ry = wuz * fwdX - wux * fwdZ
                        var rz = wux * fwdY - wuy * fwdX
                        val rl = sqrt(rx * rx + ry * ry + rz * rz)
                        if (rl > 1e-5f) { rx /= rl; ry /= rl; rz /= rl }
                        right[0] = rx; right[1] = ry; right[2] = rz
                        up[0] = fwdY * rz - fwdZ * ry
                        up[1] = fwdZ * rx - fwdX * rz
                        up[2] = fwdX * ry - fwdY * rx
                    }
                }
                "axisLocked" -> {
                    up[0] = wux; up[1] = wuy; up[2] = wuz  // already unit
                    var rx = up[1] * tez - up[2] * tey
                    var ry = up[2] * tex - up[0] * tez
                    var rz = up[0] * tey - up[1] * tex
                    val rl = sqrt(rx * rx + ry * ry + rz * rz)
                    if (rl > 1e-5f) {
                        rx /= rl; ry /= rl; rz /= rl
                    } else {
                        rx = 1f; ry = 0f; rz = 0f
                    }
                    right[0] = rx; right[1] = ry; right[2] = rz
                }
                else -> {
                    // spherical — per-particle camera-position facing.
                    val fwdX = tex; val fwdY = tey; val fwdZ = tez
                    var rx = wuy * fwdZ - wuz * fwdY
                    var ry = wuz * fwdX - wux * fwdZ
                    var rz = wux * fwdY - wuy * fwdX
                    val rl = sqrt(rx * rx + ry * ry + rz * rz)
                    if (rl > 1e-5f) { rx /= rl; ry /= rl; rz /= rl }
                    right[0] = rx; right[1] = ry; right[2] = rz
                    up[0] = fwdY * rz - fwdZ * ry
                    up[1] = fwdZ * rx - fwdX * rz
                    up[2] = fwdX * ry - fwdY * rx
                }
            }

            // Flipbook cells — the shader math verbatim.
            val frame = s.frame[i].toDouble()
            val frame0 = if (blendOn > 0.0) floor(frame)
                else floor(frame + 0.5)
            val frame1 = (frame0 + 1.0) % total
            val blend = ((frame - frame0) * blendOn).toFloat()
            val f0col = frame0 % cols
            val f0row = floor(frame0 / cols)
            val f1col = frame1 % cols
            val f1row = floor(frame1 / cols)

            val rot = s.rotation[i]
            val rs = sin(rot.toDouble()).toFloat()
            val rc = cos(rot.toDouble()).toFloat()
            val rotating = spec.facing != "velocityStretched"

            for (c in 0 until 4) {
                var sx = cornerX[c] * width
                var sy = cornerY[c] * height
                if (spec.facing == "velocityStretched" && stretchLen != 0f) {
                    // corner.y stretches by speed·velocityStretch.
                    sy = cornerY[c] * (height + stretchLen)
                }
                if (rotating) {
                    val tx = sx * rc - sy * rs
                    val ty = sx * rs + sy * rc
                    sx = tx; sy = ty
                }
                val px = wcx + right[0] * sx + up[0] * sy
                val py = wcy + right[1] * sx + up[1] * sy
                val pz = wcz + right[2] * sx + up[2] * sy
                buf.put(px); buf.put(py); buf.put(pz)
                buf.put(((f0col + quadU[c]) * cellW).toFloat())
                buf.put(((f0row + quadV[c]) * cellH).toFloat())
                buf.put(s.colorR[i]); buf.put(s.colorG[i])
                buf.put(s.colorB[i]); buf.put(s.colorA[i])
                buf.put(((f1col + quadU[c]) * cellW).toFloat())
                buf.put(((f1row + quadV[c]) * cellH).toFloat())
                buf.put(blend)
            }
        }

        cpuBuf.clear()
        // Upload only the live vertex prefix — the draw range below
        // never reads past it.
        if (count > 0) {
            // setBufferAt's last arg is BYTES — count*4 vertices at
            // VERTEX_BYTES each, not a vertex count.
            vertexBuffer.setBufferAt(engine, 0, cpuBuf, 0,
                count * 4 * VERTEX_BYTES)
        }

        val ri = engine.renderableManager.getInstance(entity)
        if (ri != 0 && liveDrawCount != count) {
            engine.renderableManager.setGeometryAt(
                ri, 0, RenderableManager.PrimitiveType.TRIANGLES,
                vertexBuffer, indexBuffer, 0, count * 6)
            liveDrawCount = count
        }
    }

    override fun attach(scene: Scene) {
        scene.addEntity(entity)
    }

    override fun detach(scene: Scene) {
        scene.removeEntity(entity)
    }

    override fun applyLayers(layers: Int) {
        super.applyLayers(layers)
        val rm = engine.renderableManager
        val ri = rm.getInstance(entity)
        if (ri != 0) rm.setLayerMask(ri, 0xFF, layers and 0xFF)
    }

    override fun destroy() {
        host.scene.removeEntity(entity)
        // destroyEntity cascades to the renderable component.
        engine.destroyEntity(entity)
        EntityManager.get().destroy(entity)
        engine.destroyVertexBuffer(vertexBuffer)
        engine.destroyIndexBuffer(indexBuffer)
        // The sprite MaterialInstance is runtime-owned (created off
        // the shared compiled material) — destroy it and prune the
        // texture-consumer binding so a later upsert can't write a
        // dead instance.
        textureKey?.let { tk ->
            host.resources.textureConsumers[tk]
                ?.removeAll { it.first === materialInstance }
        }
        engine.destroyMaterialInstance(materialInstance)
    }

    companion object {
        /** [pos3 | uv0-2 | color4 | uv1-2 | frameBlend1] = 12 floats. */
        const val FLOATS_PER_VERTEX = 12
        const val VERTEX_BYTES = FLOATS_PER_VERTEX * 4

        /** Static quad index buffer, shared pattern per particle. */
        fun buildIndexBuffer(engine: Engine, capacity: Int): IndexBuffer {
            val count = capacity * 6
            val short = capacity * 4 <= 0x10000
            val bytes = ByteBuffer.allocateDirect(count * (if (short) 2 else 4))
                .order(ByteOrder.nativeOrder())
            for (p in 0 until capacity) {
                val base = p * 4
                if (short) {
                    bytes.putShort(base.toShort())
                    bytes.putShort((base + 1).toShort())
                    bytes.putShort((base + 2).toShort())
                    bytes.putShort((base + 2).toShort())
                    bytes.putShort((base + 1).toShort())
                    bytes.putShort((base + 3).toShort())
                } else {
                    bytes.putInt(base)
                    bytes.putInt(base + 1)
                    bytes.putInt(base + 2)
                    bytes.putInt(base + 2)
                    bytes.putInt(base + 1)
                    bytes.putInt(base + 3)
                }
            }
            bytes.flip()
            val ib = IndexBuffer.Builder()
                .indexCount(count)
                .bufferType(if (short) IndexBuffer.Builder.IndexType.USHORT
                    else IndexBuffer.Builder.IndexType.UINT)
                .build(engine)
            ib.setBuffer(engine, bytes)
            return ib
        }

        fun buildVertexBuffer(engine: Engine, capacity: Int): VertexBuffer {
            return VertexBuffer.Builder()
                .vertexCount(capacity * 4)
                .bufferCount(1)
                .attribute(VertexBuffer.VertexAttribute.POSITION, 0,
                    VertexBuffer.AttributeType.FLOAT3, 0, VERTEX_BYTES)
                .attribute(VertexBuffer.VertexAttribute.UV0, 0,
                    VertexBuffer.AttributeType.FLOAT2, 12, VERTEX_BYTES)
                .attribute(VertexBuffer.VertexAttribute.COLOR, 0,
                    VertexBuffer.AttributeType.FLOAT4, 20, VERTEX_BYTES)
                .attribute(VertexBuffer.VertexAttribute.UV1, 0,
                    VertexBuffer.AttributeType.FLOAT2, 36, VERTEX_BYTES)
                .attribute(VertexBuffer.VertexAttribute.CUSTOM0, 0,
                    VertexBuffer.AttributeType.FLOAT, 44, VERTEX_BYTES)
                .build(engine)
        }
    }
}

/**
 * `meshParticleEmitter` — a baked pool of per-particle renderables
 * (Filament's Java binding has no InstanceBuffer — see the file
 * header). Each live slot is a child entity of the emitter node whose
 * TRS is the particle's local pos / facing rotation / uniform size
 * scale. Pool slots are created lazily and collapsed to a degenerate
 * transform when unused — upstream's `_hiddenTransform` approach.
 */
class MeshParticleRuntime(
    host: Dart3dView,
    system: ParticleSystem,
    private val spec: MeshEmitterSpec,
    private val geoKeys: List<Long>,
    private val buckets: MutableList<GpuMesh?>,
    private val materialKey: Long?,
    private val parentEntity: Int,
    layers: Int,
) : ParticleRuntime(host, system, spec.paused) {

    private val engine get() = host.engine

    init {
        this.layers = layers
    }

    /** Lazily-grown entity pool per geometry bucket. */
    private val pool = Array(buckets.size) { ArrayList<Int>() }
    private val liveCounts = IntArray(buckets.size)

    // Collapsed to nothing far below any plausible scene — upstream's
    // _hiddenTransform (a zero-scale renderable never rasterizes, but
    // Filament still walks it, so keep the count tight via liveCounts).
    private val hiddenTransform = floatArrayOf(
        1e-6f, 0f, 0f, 0f,
        0f, 1e-6f, 0f, 0f,
        0f, 0f, 1e-6f, 0f,
        0f, -1e5f, 0f, 1f)

    /** The material a fresh slot binds — resolved lazily so a slot
     *  created after a material upsert binds the current instance. */
    private fun materialFor(): MaterialInstance =
        materialKey?.let { host.materialInstances[it] }
            ?: host.litMaterial.defaultInstance

    private fun ensureSlot(bucket: Int, slot: Int): Int {
        val list = pool[bucket]
        val mesh = buckets[bucket] ?: return -1
        while (list.size <= slot) {
            val e = EntityManager.get().create()
            val mi = materialFor()
            RenderableManager.Builder(1)
                .geometry(0, mesh.primitiveType,
                    mesh.vertexBuffer, mesh.indexBuffer)
                .material(0, mi)
                .boundingBox(Box(
                    mesh.bounds[0], mesh.bounds[1], mesh.bounds[2],
                    mesh.bounds[3], mesh.bounds[4], mesh.bounds[5]))
                .layerMask(0xFF, layers and 0xFF)
                .castShadows(true)
                .receiveShadows(true)
                // Particles move per frame — a stale box under-culls.
                .culling(false)
                .build(engine, e)
            // The pool slot consumes the material — register so a
            // material upsert re-attaches it (same (entity, slot)
            // contract mesh components use).
            materialKey?.let { mk ->
                host.resources.materialConsumers
                    .getOrPut(mk) { ArrayList() }
                    .add(Pair(e, 0))
            }
            val tcm = engine.transformManager
            tcm.setTransform(tcm.create(e), hiddenTransform)
            // Child of the emitter node — particle transforms are
            // node-local, the node's world pose carries them.
            tcm.setParent(tcm.getInstance(e),
                tcm.getInstance(parentEntity))
            if (attached) host.scene.addEntity(e)
            list.add(e)
        }
        return list[slot]
    }

    /**
     * Geometry rebind — a `upsertResource`/`upsertPayload` re-decode
     * swapped this key's GpuMesh: buckets referencing it re-point, and
     * pooled slots take the new buffers (mirrors redecodeGeometry's
     * consumer loop; the old mesh is destroyed after all consumers
     * swap).
     */
    fun onGeometryRebound(geoKey: Long, gm: GpuMesh) {
        for (b in geoKeys.indices) {
            if (geoKeys[b] != geoKey) continue
            val prev = buckets[b]
            buckets[b] = gm
            if (prev != null) {
                // Live slots rebind; a null→mesh landing only feeds
                // slots created from here on.
                val rm = engine.renderableManager
                for (e in pool[b]) {
                    val ri = rm.getInstance(e)
                    if (ri != 0) {
                        rm.setGeometryAt(ri, 0, gm.primitiveType,
                            gm.vertexBuffer, gm.indexBuffer)
                        rm.setAxisAlignedBoundingBox(ri, Box(
                            gm.bounds[0], gm.bounds[1], gm.bounds[2],
                            gm.bounds[3], gm.bounds[4], gm.bounds[5]))
                    }
                }
            }
        }
    }

    override fun repack(camPos: FloatArray, nodeWorld: FloatArray) {
        if (buckets.isEmpty()) return   // spec declared no geometries
        val s = system.storage
        val tcm = engine.transformManager
        val counts = IntArray(buckets.size)
        val m = FloatArray(16)
        for (i in 0 until s.aliveCount) {
            var bucket = (s.random01[i] * buckets.size).toInt()
            if (bucket >= buckets.size) bucket = buckets.size - 1
            if (buckets[bucket] == null) continue   // geometry pending
            val slot = counts[bucket]++
            val e = ensureSlot(bucket, slot)
            if (e <= 0) continue
            val q = orient(s, i)
            val size = s.size[i]
            composeTrs(m, s.posX[i], s.posY[i], s.posZ[i],
                q[0], q[1], q[2], q[3], size, size, size)
            tcm.setTransform(tcm.getInstance(e), m)
        }
        // Hide only the slots that were live last frame and no longer
        // are — upstream's repack verbatim.
        for (b in 0 until buckets.size) {
            for (slot in counts[b] until liveCounts[b]) {
                val e = pool[b][slot]
                tcm.setTransform(tcm.getInstance(e), hiddenTransform)
            }
        }
        liveCounts.fill(0)
        for (b in 0 until buckets.size) liveCounts[b] = counts[b]
    }

    /** The particle's local rotation — upstream `_orient` verbatim. */
    private fun orient(s: ParticleStorage, i: Int): FloatArray {
        if (spec.facing == "tumble") {
            return quatAxisAngle(
                s.axisX[i], s.axisY[i], s.axisZ[i], s.rotation[i])
        }
        // velocityAligned: rotate +Y onto the velocity direction,
        // then spin around it. A near-still particle falls back to
        // its tumble axis.
        val vx = s.velX[i]; val vy = s.velY[i]; val vz = s.velZ[i]
        val speed = sqrt(vx * vx + vy * vy + vz * vz)
        if (speed < 1e-5f) {
            return quatAxisAngle(
                s.axisX[i], s.axisY[i], s.axisZ[i], s.rotation[i])
        }
        val dx = vx / speed; val dy = vy / speed; val dz = vz / speed
        val dotUp = dy.coerceIn(-1f, 1f)
        val align: FloatArray
        if (dotUp > 1f - 1e-6f) {
            align = quatAxisAngle(dx, dy, dz, s.rotation[i])
            return align
        }
        if (dotUp < -1f + 1e-6f) {
            // Antiparallel: flip around any horizontal axis.
            align = quatAxisAngle(1f, 0f, 0f, PI.toFloat())
        } else {
            // Axis = up × velocity, angle = acos(up · velocity).
            var ax = dz; var ay = 0f; var az = -dx
            val al = sqrt(ax * ax + az * az)
            ax /= al; az /= al
            align = quatAxisAngle(ax, ay, az,
                acos(dotUp.toDouble()).toFloat())
        }
        val spin = quatAxisAngle(dx, dy, dz, s.rotation[i])
        return quatMul(spin, align)
    }

    override fun attach(scene: Scene) {
        for (list in pool) for (e in list) scene.addEntity(e)
    }

    override fun detach(scene: Scene) {
        for (list in pool) for (e in list) scene.removeEntity(e)
    }

    override fun applyLayers(layers: Int) {
        super.applyLayers(layers)
        val rm = engine.renderableManager
        for (list in pool) for (e in list) {
            val ri = rm.getInstance(e)
            if (ri != 0) rm.setLayerMask(ri, 0xFF, layers and 0xFF)
        }
    }

    override fun destroy() {
        val poolIds = HashSet<Int>()
        for (list in pool) {
            for (e in list) {
                host.scene.removeEntity(e)
                // destroyEntity cascades to the renderable + transform
                // components (same contract as removeNode's teardown).
                engine.destroyEntity(e)
                EntityManager.get().destroy(e)
                poolIds.add(e)
            }
            list.clear()
        }
        liveCounts.fill(0)
        // Prune the slot consumer entries — a dead entity can't take a
        // re-attached material on the next upsert.
        materialKey?.let { mk ->
            host.resources.materialConsumers[mk]
                ?.removeAll { it.first in poolIds }
        }
        // The shared material instance belongs to the material
        // registry — NOT destroyed here.
    }
}

// ---------------------------------------------------------------------------
// Small math helpers (column-major TRS + quaternion ops, no deps).
// ---------------------------------------------------------------------------

private fun composeTrs(
    m: FloatArray,
    tx: Float, ty: Float, tz: Float,
    qx: Float, qy: Float, qz: Float, qw: Float,
    sx: Float, sy: Float, sz: Float,
) {
    val x2 = qx + qx; val y2 = qy + qy; val z2 = qz + qz
    val xx = qx * x2; val xy = qx * y2; val xz = qx * z2
    val yy = qy * y2; val yz = qy * z2; val zz = qz * z2
    val wx = qw * x2; val wy = qw * y2; val wz = qw * z2
    m[0] = (1 - (yy + zz)) * sx
    m[1] = (xy + wz) * sx
    m[2] = (xz - wy) * sx
    m[3] = 0f
    m[4] = (xy - wz) * sy
    m[5] = (1 - (xx + zz)) * sy
    m[6] = (yz + wx) * sy
    m[7] = 0f
    m[8] = (xz + wy) * sz
    m[9] = (yz - wx) * sz
    m[10] = (1 - (xx + yy)) * sz
    m[11] = 0f
    m[12] = tx; m[13] = ty; m[14] = tz; m[15] = 1f
}

private fun quatAxisAngle(
    ax: Float, ay: Float, az: Float, angle: Float,
): FloatArray {
    val half = angle * 0.5f
    val s = sin(half.toDouble()).toFloat()
    return floatArrayOf(ax * s, ay * s, az * s,
        cos(half.toDouble()).toFloat())
}

private fun quatMul(a: FloatArray, b: FloatArray): FloatArray {
    val (ax, ay, az, aw) = a
    val (bx, by, bz, bw) = b
    return floatArrayOf(
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz)
}
