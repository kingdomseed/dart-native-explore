package com.jasonholtdigital.dart3d

import org.json.JSONObject

/**
 * The decoded `effects` post-stack of a `kind:"environment"` resource
 * (W13) — mirrors upstream's `_decodeEnvironmentEffects` /
 * `EnvironmentEffectsSpec`. The wire is delta-encoded: `enabled`
 * ships only when true and leaves only when non-default, so every
 * field carries its upstream default and an absent block decodes to
 * defaults. A present `effects` object — even `{}` — wholesale
 * replaces the host's [Dart3dView.lastEffects]; an absent key leaves
 * it untouched ([decode] returns null on null).
 *
 * vec3 leaves decode to `FloatArray(3)` like the manifest's TRS
 * vectors; Android feeds them straight into Filament's float-array
 * setters (slopeOffsetPower, fog color).
 */
data class StageEffects(
    val colorGrading: ColorGrading = ColorGrading(),
    val bloom: Bloom = Bloom(),
    val lensFlare: LensFlare = LensFlare(),
    val vignette: Vignette = Vignette(),
    val chromaticAberration: ChromaticAberration = ChromaticAberration(),
    val filmGrain: FilmGrain = FilmGrain(),
    val ambientOcclusion: AmbientOcclusion = AmbientOcclusion(),
    val screenSpaceReflections: ScreenSpaceReflections =
        ScreenSpaceReflections(),
    val globalIllumination: GlobalIllumination = GlobalIllumination(),
    val temporalAntiAliasing: TemporalAntiAliasing =
        TemporalAntiAliasing(),
    val fog: Fog = Fog(),
    val godRays: GodRays = GodRays(),
    val depthOfField: DepthOfField = DepthOfField(),
    val autoExposure: AutoExposure = AutoExposure(),
) {
    data class ColorGrading(
        val enabled: Boolean = false,
        val brightness: Double = 1.0,
        val contrast: Double = 1.0,
        val saturation: Double = 1.0,
        val temperature: Double = 0.0,
        val tint: Double = 0.0,
        val lift: FloatArray = floatArrayOf(0f, 0f, 0f),
        val gamma: FloatArray = floatArrayOf(1f, 1f, 1f),
        val gain: FloatArray = floatArrayOf(1f, 1f, 1f),
        val lut: String = "",
        val lutBlend: Double = 1.0,
    ) {
        companion object {
            fun decode(o: JSONObject?) = ColorGrading(
                enabled = o?.optBoolean("enabled") ?: false,
                brightness = o?.optDouble("brightness", 1.0) ?: 1.0,
                contrast = o?.optDouble("contrast", 1.0) ?: 1.0,
                saturation = o?.optDouble("saturation", 1.0) ?: 1.0,
                temperature = o?.optDouble("temperature", 0.0) ?: 0.0,
                tint = o?.optDouble("tint", 0.0) ?: 0.0,
                lift = fxVec3(o, "lift", 0f, 0f, 0f),
                gamma = fxVec3(o, "gamma", 1f, 1f, 1f),
                gain = fxVec3(o, "gain", 1f, 1f, 1f),
                lut = o?.optString("lut") ?: "",
                lutBlend = o?.optDouble("lutBlend", 1.0) ?: 1.0,
            )
        }
    }

    data class Bloom(
        val enabled: Boolean = false,
        val threshold: Double = 1.0,
        val intensity: Double = 0.15,
        val scatter: Double = 0.7,
    ) {
        companion object {
            fun decode(o: JSONObject?) = Bloom(
                enabled = o?.optBoolean("enabled") ?: false,
                threshold = o?.optDouble("threshold", 1.0) ?: 1.0,
                intensity = o?.optDouble("intensity", 0.15) ?: 0.15,
                scatter = o?.optDouble("scatter", 0.7) ?: 0.7,
            )
        }
    }

    data class LensFlare(
        val enabled: Boolean = false,
        val intensity: Double = 1.0,
        val ghostCount: Int = 4,
        val ghostSpacing: Double = 0.3,
        val haloRadius: Double = 0.35,
        val haloIntensity: Double = 1.0,
        val chromaticAberration: Double = 0.005,
    ) {
        companion object {
            fun decode(o: JSONObject?) = LensFlare(
                enabled = o?.optBoolean("enabled") ?: false,
                intensity = o?.optDouble("intensity", 1.0) ?: 1.0,
                ghostCount = o?.optInt("ghostCount", 4) ?: 4,
                ghostSpacing = o?.optDouble("ghostSpacing", 0.3) ?: 0.3,
                haloRadius = o?.optDouble("haloRadius", 0.35) ?: 0.35,
                haloIntensity = o?.optDouble("haloIntensity", 1.0) ?: 1.0,
                chromaticAberration =
                    o?.optDouble("chromaticAberration", 0.005) ?: 0.005,
            )
        }
    }

    data class Vignette(
        val enabled: Boolean = false,
        val intensity: Double = 0.5,
        val radius: Double = 0.75,
        val smoothness: Double = 0.5,
    ) {
        companion object {
            fun decode(o: JSONObject?) = Vignette(
                enabled = o?.optBoolean("enabled") ?: false,
                intensity = o?.optDouble("intensity", 0.5) ?: 0.5,
                radius = o?.optDouble("radius", 0.75) ?: 0.75,
                smoothness = o?.optDouble("smoothness", 0.5) ?: 0.5,
            )
        }
    }

    data class ChromaticAberration(
        val enabled: Boolean = false,
        val intensity: Double = 0.2,
    ) {
        companion object {
            fun decode(o: JSONObject?) = ChromaticAberration(
                enabled = o?.optBoolean("enabled") ?: false,
                intensity = o?.optDouble("intensity", 0.2) ?: 0.2,
            )
        }
    }

    data class FilmGrain(
        val enabled: Boolean = false,
        val intensity: Double = 0.3,
    ) {
        companion object {
            fun decode(o: JSONObject?) = FilmGrain(
                enabled = o?.optBoolean("enabled") ?: false,
                intensity = o?.optDouble("intensity", 0.3) ?: 0.3,
            )
        }
    }

    data class AmbientOcclusion(
        val enabled: Boolean = false,
        val method: String = "obscurance",
        val radius: Double = 0.33,
        val intensity: Double = 1.0,
        val bias: Double = 0.07,
        val power: Double = 1.5,
        val detail: Double = 0.5,
        val horizonAngle: Double = 0.06,
        val directLightAffect: Double = 0.0,
        val multiBounce: Double = 0.0,
        val sampleCount: Int = 16,
        val sliceCount: Int = 3,
        val stepsPerSlice: Int = 3,
        val visibilityBitmask: Boolean = false,
        val thickness: Double = 0.5,
        val thicknessHeuristic: Double = 0.004,
        val bentNormals: Boolean = false,
        val indirectLight: Double = 0.0,
        val halfResolution: Boolean = true,
        val depthMipChain: Boolean = false,
        val specularMode: String = "none",
    ) {
        companion object {
            fun decode(o: JSONObject?) = AmbientOcclusion(
                enabled = o?.optBoolean("enabled") ?: false,
                method = o?.optString("method", "obscurance")
                    ?: "obscurance",
                radius = o?.optDouble("radius", 0.33) ?: 0.33,
                intensity = o?.optDouble("intensity", 1.0) ?: 1.0,
                bias = o?.optDouble("bias", 0.07) ?: 0.07,
                power = o?.optDouble("power", 1.5) ?: 1.5,
                detail = o?.optDouble("detail", 0.5) ?: 0.5,
                horizonAngle = o?.optDouble("horizonAngle", 0.06) ?: 0.06,
                directLightAffect =
                    o?.optDouble("directLightAffect", 0.0) ?: 0.0,
                multiBounce = o?.optDouble("multiBounce", 0.0) ?: 0.0,
                sampleCount = o?.optInt("sampleCount", 16) ?: 16,
                sliceCount = o?.optInt("sliceCount", 3) ?: 3,
                stepsPerSlice = o?.optInt("stepsPerSlice", 3) ?: 3,
                visibilityBitmask = o?.optBoolean("visibilityBitmask")
                    ?: false,
                thickness = o?.optDouble("thickness", 0.5) ?: 0.5,
                thicknessHeuristic =
                    o?.optDouble("thicknessHeuristic", 0.004) ?: 0.004,
                bentNormals = o?.optBoolean("bentNormals") ?: false,
                indirectLight = o?.optDouble("indirectLight", 0.0) ?: 0.0,
                halfResolution = o?.optBoolean("halfResolution", true)
                    ?: true,
                depthMipChain = o?.optBoolean("depthMipChain") ?: false,
                specularMode = o?.optString("specularMode", "none")
                    ?: "none",
            )
        }
    }

    data class ScreenSpaceReflections(
        val enabled: Boolean = false,
        val intensity: Double = 1.0,
        val maxDistance: Double = 24.4,
        val thickness: Double = 0.46,
        val stride: Double = 9.0,
        val maxSteps: Int = 90,
        val blur: Double = 0.3,
        val distanceFadeStart: Double = 0.0,
        val resolutionScale: Double = 1.0,
    ) {
        companion object {
            fun decode(o: JSONObject?) = ScreenSpaceReflections(
                enabled = o?.optBoolean("enabled") ?: false,
                intensity = o?.optDouble("intensity", 1.0) ?: 1.0,
                maxDistance = o?.optDouble("maxDistance", 24.4) ?: 24.4,
                thickness = o?.optDouble("thickness", 0.46) ?: 0.46,
                stride = o?.optDouble("stride", 9.0) ?: 9.0,
                maxSteps = o?.optInt("maxSteps", 90) ?: 90,
                blur = o?.optDouble("blur", 0.3) ?: 0.3,
                distanceFadeStart =
                    o?.optDouble("distanceFadeStart", 0.0) ?: 0.0,
                resolutionScale =
                    o?.optDouble("resolutionScale", 1.0) ?: 1.0,
            )
        }
    }

    data class GlobalIllumination(
        val enabled: Boolean = false,
        val volumeMode: String = "followCamera",
        val resolution: FloatArray = floatArrayOf(16f, 8f, 16f),
        val extents: FloatArray = floatArrayOf(20f, 10f, 20f),
        val intensity: Double = 1.0,
        val hysteresis: Double = 0.95,
        val shadowBias: Double = 0.3,
        val visibility: Double = 0.7,
        val visibilityBias: Double = 0.08,
        val probeUpdateBudget: Int = 0,
        val injectionResolution: String = "eighth",
        val fireflyClamp: Double = 8.0,
        val emissiveBoost: Double = 1.0,
        val updateWhenIdleOnly: Boolean = false,
        val bakeOnly: Boolean = false,
    ) {
        companion object {
            fun decode(o: JSONObject?) = GlobalIllumination(
                enabled = o?.optBoolean("enabled") ?: false,
                volumeMode = o?.optString("volumeMode", "followCamera")
                    ?: "followCamera",
                resolution = fxVec3(o, "resolution", 16f, 8f, 16f),
                extents = fxVec3(o, "extents", 20f, 10f, 20f),
                intensity = o?.optDouble("intensity", 1.0) ?: 1.0,
                hysteresis = o?.optDouble("hysteresis", 0.95) ?: 0.95,
                shadowBias = o?.optDouble("shadowBias", 0.3) ?: 0.3,
                visibility = o?.optDouble("visibility", 0.7) ?: 0.7,
                visibilityBias =
                    o?.optDouble("visibilityBias", 0.08) ?: 0.08,
                probeUpdateBudget =
                    o?.optInt("probeUpdateBudget", 0) ?: 0,
                injectionResolution =
                    o?.optString("injectionResolution", "eighth")
                        ?: "eighth",
                fireflyClamp = o?.optDouble("fireflyClamp", 8.0) ?: 8.0,
                emissiveBoost =
                    o?.optDouble("emissiveBoost", 1.0) ?: 1.0,
                updateWhenIdleOnly =
                    o?.optBoolean("updateWhenIdleOnly") ?: false,
                bakeOnly = o?.optBoolean("bakeOnly") ?: false,
            )
        }
    }

    data class TemporalAntiAliasing(
        val enabled: Boolean = false,
        val minimumCurrentWeight: Double = 0.1,
        val varianceGamma: Double = 1.0,
        val sharpness: Double = 0.0,
        val jitterSequenceLength: Int = 16,
        val jitterScale: Double = 1.0,
        val objectMotion: Boolean = true,
        val skinnedMotion: Boolean = true,
    ) {
        companion object {
            fun decode(o: JSONObject?) = TemporalAntiAliasing(
                enabled = o?.optBoolean("enabled") ?: false,
                minimumCurrentWeight =
                    o?.optDouble("minimumCurrentWeight", 0.1) ?: 0.1,
                varianceGamma = o?.optDouble("varianceGamma", 1.0) ?: 1.0,
                sharpness = o?.optDouble("sharpness", 0.0) ?: 0.0,
                jitterSequenceLength =
                    o?.optInt("jitterSequenceLength", 16) ?: 16,
                jitterScale = o?.optDouble("jitterScale", 1.0) ?: 1.0,
                objectMotion = o?.optBoolean("objectMotion", true)
                    ?: true,
                skinnedMotion = o?.optBoolean("skinnedMotion", true)
                    ?: true,
            )
        }
    }

    data class Fog(
        val enabled: Boolean = false,
        val mode: String = "exponential",
        val color: FloatArray = floatArrayOf(0.6f, 0.7f, 0.8f),
        val skyColorInfluence: Double = 0.0,
        val density: Double = 0.02,
        val start: Double = 0.0,
        val end: Double = 200.0,
        val maxOpacity: Double = 1.0,
        val cutoffDistance: Double = 0.0,
        val height: Double = 0.0,
        val heightFalloff: Double = 0.0,
        val sunInScatter: Double = 0.0,
        val sunInScatterExponent: Double = 8.0,
    ) {
        companion object {
            fun decode(o: JSONObject?) = Fog(
                enabled = o?.optBoolean("enabled") ?: false,
                mode = o?.optString("mode", "exponential")
                    ?: "exponential",
                color = fxVec3(o, "color", 0.6f, 0.7f, 0.8f),
                skyColorInfluence =
                    o?.optDouble("skyColorInfluence", 0.0) ?: 0.0,
                density = o?.optDouble("density", 0.02) ?: 0.02,
                start = o?.optDouble("start", 0.0) ?: 0.0,
                end = o?.optDouble("end", 200.0) ?: 200.0,
                maxOpacity = o?.optDouble("maxOpacity", 1.0) ?: 1.0,
                cutoffDistance =
                    o?.optDouble("cutoffDistance", 0.0) ?: 0.0,
                height = o?.optDouble("height", 0.0) ?: 0.0,
                heightFalloff =
                    o?.optDouble("heightFalloff", 0.0) ?: 0.0,
                sunInScatter = o?.optDouble("sunInScatter", 0.0) ?: 0.0,
                sunInScatterExponent =
                    o?.optDouble("sunInScatterExponent", 8.0) ?: 8.0,
            )
        }
    }

    data class GodRays(
        val enabled: Boolean = false,
        val intensity: Double = 1.0,
        val density: Double = 0.5,
        val anisotropy: Double = 0.7,
        val stepCount: Int = 24,
        val maxDistance: Double = 200.0,
        val jitter: Double = 1.0,
        val color: FloatArray = floatArrayOf(1f, 1f, 1f),
    ) {
        companion object {
            fun decode(o: JSONObject?) = GodRays(
                enabled = o?.optBoolean("enabled") ?: false,
                intensity = o?.optDouble("intensity", 1.0) ?: 1.0,
                density = o?.optDouble("density", 0.5) ?: 0.5,
                anisotropy = o?.optDouble("anisotropy", 0.7) ?: 0.7,
                stepCount = o?.optInt("stepCount", 24) ?: 24,
                maxDistance = o?.optDouble("maxDistance", 200.0) ?: 200.0,
                jitter = o?.optDouble("jitter", 1.0) ?: 1.0,
                color = fxVec3(o, "color", 1f, 1f, 1f),
            )
        }
    }

    data class DepthOfField(
        val enabled: Boolean = false,
        val focusDistance: Double = 10.0,
        val fStop: Double = 2.8,
        val focalLength: Double = 0.0,
        val sensorHeight: Double = 0.024,
        val blurScale: Double = 1.0,
        val maxForegroundBlur: Double = 24.0,
        val maxBackgroundBlur: Double = 32.0,
        val bladeCount: Int = 0,
        val bladeRotation: Double = 0.0,
        val bladeCurvature: Double = 0.0,
        val quality: String = "medium",
    ) {
        companion object {
            fun decode(o: JSONObject?) = DepthOfField(
                enabled = o?.optBoolean("enabled") ?: false,
                focusDistance =
                    o?.optDouble("focusDistance", 10.0) ?: 10.0,
                fStop = o?.optDouble("fStop", 2.8) ?: 2.8,
                focalLength = o?.optDouble("focalLength", 0.0) ?: 0.0,
                sensorHeight =
                    o?.optDouble("sensorHeight", 0.024) ?: 0.024,
                blurScale = o?.optDouble("blurScale", 1.0) ?: 1.0,
                maxForegroundBlur =
                    o?.optDouble("maxForegroundBlur", 24.0) ?: 24.0,
                maxBackgroundBlur =
                    o?.optDouble("maxBackgroundBlur", 32.0) ?: 32.0,
                bladeCount = o?.optInt("bladeCount", 0) ?: 0,
                bladeRotation =
                    o?.optDouble("bladeRotation", 0.0) ?: 0.0,
                bladeCurvature =
                    o?.optDouble("bladeCurvature", 0.0) ?: 0.0,
                quality = o?.optString("quality", "medium") ?: "medium",
            )
        }
    }

    data class AutoExposure(
        val enabled: Boolean = false,
        val strength: Double = 0.55,
        val compensation: Double = 0.0,
        val minEv: Double = -4.0,
        val maxEv: Double = 4.0,
        val speedUp: Double = 3.0,
        val speedDown: Double = 1.0,
    ) {
        companion object {
            fun decode(o: JSONObject?) = AutoExposure(
                enabled = o?.optBoolean("enabled") ?: false,
                strength = o?.optDouble("strength", 0.55) ?: 0.55,
                compensation = o?.optDouble("compensation", 0.0) ?: 0.0,
                minEv = o?.optDouble("minEv", -4.0) ?: -4.0,
                maxEv = o?.optDouble("maxEv", 4.0) ?: 4.0,
                speedUp = o?.optDouble("speedUp", 3.0) ?: 3.0,
                speedDown = o?.optDouble("speedDown", 1.0) ?: 1.0,
            )
        }
    }

    companion object {
        /**
         * `effects` absent → null (the caller keeps the prior stack);
         * present — even `{}` — decodes a full replacement from
         * per-block defaults.
         */
        fun decode(obj: JSONObject?): StageEffects? {
            obj ?: return null
            return StageEffects(
                colorGrading =
                    ColorGrading.decode(obj.optJSONObject("colorGrading")),
                bloom = Bloom.decode(obj.optJSONObject("bloom")),
                lensFlare =
                    LensFlare.decode(obj.optJSONObject("lensFlare")),
                vignette =
                    Vignette.decode(obj.optJSONObject("vignette")),
                chromaticAberration = ChromaticAberration.decode(
                    obj.optJSONObject("chromaticAberration")),
                filmGrain =
                    FilmGrain.decode(obj.optJSONObject("filmGrain")),
                ambientOcclusion = AmbientOcclusion.decode(
                    obj.optJSONObject("ambientOcclusion")),
                screenSpaceReflections = ScreenSpaceReflections.decode(
                    obj.optJSONObject("screenSpaceReflections")),
                globalIllumination = GlobalIllumination.decode(
                    obj.optJSONObject("globalIllumination")),
                temporalAntiAliasing = TemporalAntiAliasing.decode(
                    obj.optJSONObject("temporalAntiAliasing")),
                fog = Fog.decode(obj.optJSONObject("fog")),
                godRays = GodRays.decode(obj.optJSONObject("godRays")),
                depthOfField =
                    DepthOfField.decode(obj.optJSONObject("depthOfField")),
                autoExposure =
                    AutoExposure.decode(obj.optJSONObject("autoExposure")),
            )
        }
    }
}

/** vec3 leaf — absent or shorter than 3 falls back to the supplied
 * default (upstream's `_effectVec` rule). */
private fun fxVec3(
    o: JSONObject?, name: String, x: Float, y: Float, z: Float,
): FloatArray {
    val a = o?.optJSONArray(name)
    return if (a != null && a.length() >= 3) {
        floatArrayOf(a.optDouble(0).toFloat(), a.optDouble(1).toFloat(),
            a.optDouble(2).toFloat())
    } else {
        floatArrayOf(x, y, z)
    }
}
