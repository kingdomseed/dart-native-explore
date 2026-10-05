package com.jasonholtdigital.dart3d

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager

/**
 * The device class a view's defaults are chosen for when the app sets
 * no `SceneQuality`.
 *
 * [LOW] stands for a fill-rate-bound GPU. It is decided from the GPU's
 * name ([GpuProbe], [FILL_BOUND_GPUS]) and, when the name says nothing,
 * from memory. Through the standard pipeline a dice frame measured
 * (`docs/artifacts/s0-three-device-baseline/`):
 *
 * | Device | GPU | Memory | Pixels | GPU ms |
 * |---|---|---|---|---|
 * | Fire KFTUWI | Mali-G52 MC2 | 2.9 GB | 1200×1920 | 125 |
 * | Wacom DTHA116 | Mali-G57 MC2 | 8 GB | 1440×2200 | 75 |
 * | Nothing A142 | Mali-G610 MC4 | 7.6 GB | 1084×2412 | 18 |
 *
 * Two things follow from LOW, and they are decided separately:
 *
 * - The `auto` backend resolves to OpenGL, at engine creation, whatever
 *   `SceneQuality` says. Dynamic resolution needs GPU frame times, and
 *   Filament's Vulkan backend never produced them on the Fire tablet's
 *   driver. Only the backend pref (`Dart3dSetBackend`) overrides this.
 * - While no `SceneQuality` is set, the view takes the pipeline in
 *   [DeviceProfile]: hard PCF shadows, FXAA without MSAA, the small HDR
 *   buffer and dynamic resolution. A fast device misfiled as LOW keeps
 *   full resolution — the scale only drops while frames run long. That
 *   is also why screen size is not an input.
 */
internal enum class DeviceTier {
    LOW, STANDARD;

    companion object {
        /** A device sold as 4 GB reports 3.5 GB or more; one sold as
         *  3 GB reports under 3 GB. */
        const val LOW_MEMORY_BYTES = 3_200_000_000L

        /** The lowest scale dynamic resolution may reach on [LOW]. */
        const val LOW_MIN_RENDER_SCALE = 0.5f

        /**
         * GPU families filed as fill-rate bound, matched against the
         * `GL_RENDERER` string. Mali-G52 and Mali-G57 are measured (the
         * table above). The rest are listed by their market class, at
         * or below those two, and are not measured here. A GPU matching
         * none of them is decided by memory.
         */
        val FILL_BOUND_GPUS: List<Regex> = listOf(
            Regex("""Mali-(4\d\d|T\d{3})"""),
            Regex("""Mali-G(31|51|52|57)\b"""),
            Regex("""Adreno \(TM\) (3\d\d|4\d\d|50\d|51\d|61\d)\b"""),
            Regex("""PowerVR Rogue GE\d{4}"""),
        )

        /** [gpuRenderer] is the `GL_RENDERER` string, null if unknown. */
        fun classify(
            totalMemoryBytes: Long, lowRamDevice: Boolean, gpuRenderer: String?,
        ): DeviceTier = when {
            lowRamDevice -> LOW
            totalMemoryBytes in 1 until LOW_MEMORY_BYTES -> LOW
            gpuRenderer != null &&
                FILL_BOUND_GPUS.any { it.containsMatchIn(gpuRenderer) } -> LOW
            else -> STANDARD
        }

        @Volatile private var cached: DeviceTier? = null

        fun of(context: Context): DeviceTier = cached ?: run {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE)
                as? ActivityManager
            val info = ActivityManager.MemoryInfo()
            am?.getMemoryInfo(info)
            classify(info.totalMem, am?.isLowRamDevice == true,
                GpuProbe.renderer()).also { cached = it }
        }

        /** What the `auto` backend pref resolves to on this device. */
        fun autoBackendIsVulkan(context: Context): Boolean =
            of(context) != LOW && context.packageManager.hasSystemFeature(
                PackageManager.FEATURE_VULKAN_HARDWARE_VERSION)
    }
}

/**
 * The pipeline choices a [DeviceTier.LOW] device makes while the app
 * sets no `SceneQuality`. Pure decisions; `Dart3dView` writes them to
 * Filament.
 */
internal object DeviceProfile {

    /** [quality] is the `viewConfig.quality` tier, null for unset. */
    fun isLow(tier: DeviceTier, quality: String?): Boolean =
        quality == null && tier == DeviceTier.LOW

    /**
     * The widget-level input to the AA resolve chain: a `quality` tier
     * when set, else [antialiasingMode]. On the low profile a request
     * for MSAA returns null, which the chain resolves to FXAA alone; an
     * explicit 0 still means no AA.
     */
    fun aaSource(quality: String?, antialiasingMode: Int?, low: Boolean): Int? =
        when (quality) {
            "low" -> 0
            "medium" -> 1   // resolveAa maps <4 → MSAA×2 + FXAA
            "high" -> 4
            else -> antialiasingMode?.let { if (low && it > 0) null else it }
        }

    /** Render-scale bounds; equal bounds pin a fixed scale. */
    data class ScaleRange(val min: Float, val max: Float)

    /**
     * The scale a swapchain pass renders at, or null for full
     * resolution with no scale pass.
     *
     * An authored scale — the view entry's, else the stage's — is
     * always fixed, 1.0 included. Only when neither is authored does
     * the low profile get dynamic resolution. The stage's scale counts
     * as authored when its key is on the wire; the upstream codec
     * leaves a stage scale of 1.0 off the wire, so pinning 1.0 on a
     * LOW device takes a view entry's `renderScale` or a `SceneQuality`.
     */
    fun renderScale(
        entryScale: Double?, stageScale: Double?, low: Boolean,
    ): ScaleRange? {
        val authored = entryScale ?: stageScale
        if (authored != null) {
            if (authored <= 0.0 || authored == 1.0) return null
            return ScaleRange(authored.toFloat(), authored.toFloat())
        }
        return if (low) ScaleRange(DeviceTier.LOW_MIN_RENDER_SCALE, 1f) else null
    }
}
