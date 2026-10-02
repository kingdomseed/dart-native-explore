package com.jasonholtdigital.dart3d

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager

/**
 * The device class a view's defaults are chosen for when the app sets
 * no `SceneQuality`.
 *
 * [LOW] stands for a fill-rate-bound GPU. Memory is the proxy: the GPU
 * can't be named before an engine exists, and the measured case — the
 * Fire tablet KFTUWI, Mali-G52 MC2, 2.9 GB, 1920×1200 — spends about
 * 125 ms of GPU on a dice frame through the standard pipeline
 * (`docs/artifacts/s0-tablet-frame-rate/`).
 *
 * A LOW view renders with hard PCF shadows, FXAA without MSAA, the
 * small HDR buffer and Filament's dynamic resolution. Dynamic
 * resolution needs GPU frame times, which Filament's Vulkan backend
 * never produced on that tablet's driver, so LOW resolves the `auto`
 * backend to OpenGL. A fast device misfiled as LOW keeps full
 * resolution — the scale only drops while frames run long.
 */
internal enum class DeviceTier {
    LOW, STANDARD;

    companion object {
        /** A device sold as 4 GB reports 3.5 GB or more; one sold as
         *  3 GB reports under 3 GB. */
        const val LOW_MEMORY_BYTES = 3_200_000_000L

        /** The lowest scale dynamic resolution may reach on [LOW]. */
        const val LOW_MIN_RENDER_SCALE = 0.5f

        fun classify(totalMemoryBytes: Long, lowRamDevice: Boolean): DeviceTier =
            if (lowRamDevice || totalMemoryBytes in 1 until LOW_MEMORY_BYTES) LOW
            else STANDARD

        @Volatile private var cached: DeviceTier? = null

        fun of(context: Context): DeviceTier = cached ?: run {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE)
                as? ActivityManager
            val info = ActivityManager.MemoryInfo()
            am?.getMemoryInfo(info)
            classify(info.totalMem, am?.isLowRamDevice == true)
                .also { cached = it }
        }

        /** What the `auto` backend pref resolves to on this device. */
        fun autoBackendIsVulkan(context: Context): Boolean =
            of(context) != LOW && context.packageManager.hasSystemFeature(
                PackageManager.FEATURE_VULKAN_HARDWARE_VERSION)
    }
}
