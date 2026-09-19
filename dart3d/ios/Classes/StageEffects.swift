import Foundation
import simd

/// W13: the decoded `effects` block of a `kind:'environment'`
/// resource — upstream `EnvironmentEffectsSpec` (package:scene
/// `specs.dart`). The wire form is delta-encoded by
/// `_decodeEnvironmentEffects`: `enabled` is emitted only when true
/// and each leaf only when it differs from its default, so every
/// field below carries that wire default. One nested struct per
/// block, stored under the wire key's name.
///
/// `decode` returns nil for an absent `effects` key — "don't touch
/// live settings"; a present key (even `{}`) wholesale-replaces the
/// decoded values. `SceneViewHost.applyStageEffects` maps the result
/// onto SceneKit's camera/scene knobs.
struct StageEffects {

    struct ColorGrading {
        var enabled = false
        var brightness = 1.0
        var contrast = 1.0
        var saturation = 1.0
        var temperature = 0.0
        var tint = 0.0
        var lift = SIMD3<Float>(0, 0, 0)
        var gamma = SIMD3<Float>(1, 1, 1)
        var gain = SIMD3<Float>(1, 1, 1)
        var lut: String? = nil
        var lutBlend = 1.0

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            brightness = fxNum(m["brightness"], 1.0)
            contrast = fxNum(m["contrast"], 1.0)
            saturation = fxNum(m["saturation"], 1.0)
            temperature = fxNum(m["temperature"], 0.0)
            tint = fxNum(m["tint"], 0.0)
            lift = fxVec3(m["lift"], SIMD3<Float>(0, 0, 0))
            gamma = fxVec3(m["gamma"], SIMD3<Float>(1, 1, 1))
            gain = fxVec3(m["gain"], SIMD3<Float>(1, 1, 1))
            lut = m["lut"] as? String
            lutBlend = fxNum(m["lutBlend"], 1.0)
        }
    }

    struct Bloom {
        var enabled = false
        var threshold = 1.0
        var intensity = 0.15
        var scatter = 0.7

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            threshold = fxNum(m["threshold"], 1.0)
            intensity = fxNum(m["intensity"], 0.15)
            scatter = fxNum(m["scatter"], 0.7)
        }
    }

    struct LensFlare {
        var enabled = false
        var intensity = 1.0
        var ghostCount = 4
        var ghostSpacing = 0.3
        var haloRadius = 0.35
        var haloIntensity = 1.0
        var chromaticAberration = 0.005

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            intensity = fxNum(m["intensity"], 1.0)
            ghostCount = fxInt(m["ghostCount"], 4)
            ghostSpacing = fxNum(m["ghostSpacing"], 0.3)
            haloRadius = fxNum(m["haloRadius"], 0.35)
            haloIntensity = fxNum(m["haloIntensity"], 1.0)
            chromaticAberration = fxNum(m["chromaticAberration"], 0.005)
        }
    }

    struct Vignette {
        var enabled = false
        var intensity = 0.5
        var radius = 0.75
        var smoothness = 0.5

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            intensity = fxNum(m["intensity"], 0.5)
            radius = fxNum(m["radius"], 0.75)
            smoothness = fxNum(m["smoothness"], 0.5)
        }
    }

    struct ChromaticAberration {
        var enabled = false
        var intensity = 0.2

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            intensity = fxNum(m["intensity"], 0.2)
        }
    }

    struct FilmGrain {
        var enabled = false
        var intensity = 0.3

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            intensity = fxNum(m["intensity"], 0.3)
        }
    }

    struct AmbientOcclusion {
        var enabled = false
        var method = "obscurance"   // 'obscurance'|'groundTruth'
        var radius = 0.33
        var intensity = 1.0
        var bias = 0.07
        var power = 1.5
        var detail = 0.5
        var horizonAngle = 0.06
        var directLightAffect = 0.0
        var multiBounce = 0.0
        var sampleCount = 16
        var sliceCount = 3
        var stepsPerSlice = 3
        var visibilityBitmask = false
        var thickness = 0.5
        var thicknessHeuristic = 0.004
        var bentNormals = false
        var indirectLight = 0.0
        var halfResolution = true
        var depthMipChain = false
        var specularMode = "none"   // 'none'|'simple'|'bentCone'

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            method = fxStr(m["method"], "obscurance")
            radius = fxNum(m["radius"], 0.33)
            intensity = fxNum(m["intensity"], 1.0)
            bias = fxNum(m["bias"], 0.07)
            power = fxNum(m["power"], 1.5)
            detail = fxNum(m["detail"], 0.5)
            horizonAngle = fxNum(m["horizonAngle"], 0.06)
            directLightAffect = fxNum(m["directLightAffect"], 0.0)
            multiBounce = fxNum(m["multiBounce"], 0.0)
            sampleCount = fxInt(m["sampleCount"], 16)
            sliceCount = fxInt(m["sliceCount"], 3)
            stepsPerSlice = fxInt(m["stepsPerSlice"], 3)
            visibilityBitmask = fxBool(m["visibilityBitmask"], false)
            thickness = fxNum(m["thickness"], 0.5)
            thicknessHeuristic = fxNum(m["thicknessHeuristic"], 0.004)
            bentNormals = fxBool(m["bentNormals"], false)
            indirectLight = fxNum(m["indirectLight"], 0.0)
            halfResolution = fxBool(m["halfResolution"], true)
            depthMipChain = fxBool(m["depthMipChain"], false)
            specularMode = fxStr(m["specularMode"], "none")
        }
    }

    struct ScreenSpaceReflections {
        var enabled = false
        var intensity = 1.0
        var maxDistance = 24.4
        var thickness = 0.46
        var stride = 9.0
        var maxSteps = 90
        var blur = 0.3
        var distanceFadeStart = 0.0
        var resolutionScale = 1.0

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            intensity = fxNum(m["intensity"], 1.0)
            maxDistance = fxNum(m["maxDistance"], 24.4)
            thickness = fxNum(m["thickness"], 0.46)
            stride = fxNum(m["stride"], 9.0)
            maxSteps = fxInt(m["maxSteps"], 90)
            blur = fxNum(m["blur"], 0.3)
            distanceFadeStart = fxNum(m["distanceFadeStart"], 0.0)
            resolutionScale = fxNum(m["resolutionScale"], 1.0)
        }
    }

    struct GlobalIllumination {
        var enabled = false
        var volumeMode = "followCamera" // 'followCamera'|'fitScene'|'component'
        var resolution = SIMD3<Float>(16, 8, 16)
        var extents = SIMD3<Float>(20, 10, 20)
        var intensity = 1.0
        var hysteresis = 0.95
        var shadowBias = 0.3
        var visibility = 0.7
        var visibilityBias = 0.08
        var probeUpdateBudget = 0
        var injectionResolution = "half"
        var fireflyClamp = 8.0
        var emissiveBoost = 1.0
        var updateWhenIdleOnly = false
        var bakeOnly = false

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            volumeMode = fxStr(m["volumeMode"], "followCamera")
            resolution = fxVec3(m["resolution"], SIMD3<Float>(16, 8, 16))
            extents = fxVec3(m["extents"], SIMD3<Float>(20, 10, 20))
            intensity = fxNum(m["intensity"], 1.0)
            hysteresis = fxNum(m["hysteresis"], 0.95)
            shadowBias = fxNum(m["shadowBias"], 0.3)
            visibility = fxNum(m["visibility"], 0.7)
            visibilityBias = fxNum(m["visibilityBias"], 0.08)
            probeUpdateBudget = fxInt(m["probeUpdateBudget"], 0)
            injectionResolution = fxStr(m["injectionResolution"], "half")
            fireflyClamp = fxNum(m["fireflyClamp"], 8.0)
            emissiveBoost = fxNum(m["emissiveBoost"], 1.0)
            updateWhenIdleOnly = fxBool(m["updateWhenIdleOnly"], false)
            bakeOnly = fxBool(m["bakeOnly"], false)
        }
    }

    struct TemporalAntiAliasing {
        var enabled = false
        var minimumCurrentWeight = 0.1
        var varianceGamma = 1.0
        var sharpness = 0.0
        var jitterSequenceLength = 16
        var jitterScale = 1.0
        var objectMotion = true
        var skinnedMotion = true

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            minimumCurrentWeight =
                fxNum(m["minimumCurrentWeight"], 0.1)
            varianceGamma = fxNum(m["varianceGamma"], 1.0)
            sharpness = fxNum(m["sharpness"], 0.0)
            jitterSequenceLength = fxInt(m["jitterSequenceLength"], 16)
            jitterScale = fxNum(m["jitterScale"], 1.0)
            objectMotion = fxBool(m["objectMotion"], true)
            skinnedMotion = fxBool(m["skinnedMotion"], true)
        }
    }

    struct Fog {
        var enabled = false
        var mode = "exponential"    // 'exponential'|'none'|'linear'|'exponentialSquared'
        var color = SIMD3<Float>(0.6, 0.7, 0.8)
        var skyColorInfluence = 0.0
        var density = 0.02
        var start = 0.0
        var end = 200.0
        var maxOpacity = 1.0
        var cutoffDistance = 0.0
        var height = 0.0
        var heightFalloff = 0.0
        var sunInScatter = 0.0
        var sunInScatterExponent = 8.0

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            mode = fxStr(m["mode"], "exponential")
            color = fxVec3(m["color"], SIMD3<Float>(0.6, 0.7, 0.8))
            skyColorInfluence = fxNum(m["skyColorInfluence"], 0.0)
            density = fxNum(m["density"], 0.02)
            start = fxNum(m["start"], 0.0)
            end = fxNum(m["end"], 200.0)
            maxOpacity = fxNum(m["maxOpacity"], 1.0)
            cutoffDistance = fxNum(m["cutoffDistance"], 0.0)
            height = fxNum(m["height"], 0.0)
            heightFalloff = fxNum(m["heightFalloff"], 0.0)
            sunInScatter = fxNum(m["sunInScatter"], 0.0)
            sunInScatterExponent = fxNum(m["sunInScatterExponent"], 8.0)
        }
    }

    struct GodRays {
        var enabled = false
        var intensity = 1.0
        var density = 0.5
        var anisotropy = 0.7
        var stepCount = 24
        var maxDistance = 200.0
        var jitter = 1.0
        var color = SIMD3<Float>(1, 1, 1)

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            intensity = fxNum(m["intensity"], 1.0)
            density = fxNum(m["density"], 0.5)
            anisotropy = fxNum(m["anisotropy"], 0.7)
            stepCount = fxInt(m["stepCount"], 24)
            maxDistance = fxNum(m["maxDistance"], 200.0)
            jitter = fxNum(m["jitter"], 1.0)
            color = fxVec3(m["color"], SIMD3<Float>(1, 1, 1))
        }
    }

    struct DepthOfField {
        var enabled = false
        var focusDistance = 10.0
        var fStop = 2.8
        var focalLength = 0.0
        var sensorHeight = 0.024
        var blurScale = 1.0
        var maxForegroundBlur = 24.0
        var maxBackgroundBlur = 32.0
        var bladeCount = 0
        var bladeRotation = 0.0
        var bladeCurvature = 0.0
        var quality = "medium"      // 'low'|'medium'|'high'

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            focusDistance = fxNum(m["focusDistance"], 10.0)
            fStop = fxNum(m["fStop"], 2.8)
            focalLength = fxNum(m["focalLength"], 0.0)
            sensorHeight = fxNum(m["sensorHeight"], 0.024)
            blurScale = fxNum(m["blurScale"], 1.0)
            maxForegroundBlur = fxNum(m["maxForegroundBlur"], 24.0)
            maxBackgroundBlur = fxNum(m["maxBackgroundBlur"], 32.0)
            bladeCount = fxInt(m["bladeCount"], 0)
            bladeRotation = fxNum(m["bladeRotation"], 0.0)
            bladeCurvature = fxNum(m["bladeCurvature"], 0.0)
            quality = fxStr(m["quality"], "medium")
        }
    }

    struct AutoExposure {
        var enabled = false
        var strength = 0.55
        var compensation = 0.0
        var minEv = -4.0
        var maxEv = 4.0
        var speedUp = 3.0
        var speedDown = 1.0

        init(_ m: [String: Any]? = nil) {
            let m = m ?? [:]
            enabled = fxBool(m["enabled"], false)
            strength = fxNum(m["strength"], 0.55)
            compensation = fxNum(m["compensation"], 0.0)
            minEv = fxNum(m["minEv"], -4.0)
            maxEv = fxNum(m["maxEv"], 4.0)
            speedUp = fxNum(m["speedUp"], 3.0)
            speedDown = fxNum(m["speedDown"], 1.0)
        }
    }

    var colorGrading = ColorGrading()
    var bloom = Bloom()
    var lensFlare = LensFlare()
    var vignette = Vignette()
    var chromaticAberration = ChromaticAberration()
    var filmGrain = FilmGrain()
    var ambientOcclusion = AmbientOcclusion()
    var screenSpaceReflections = ScreenSpaceReflections()
    var globalIllumination = GlobalIllumination()
    var temporalAntiAliasing = TemporalAntiAliasing()
    var fog = Fog()
    var godRays = GodRays()
    var depthOfField = DepthOfField()
    var autoExposure = AutoExposure()

    /// Decodes one `effects` object: nil in → nil out (the absent key
    /// leaves live settings untouched); a present dict decodes every
    /// block, each absent block/key falling back to its wire default.
    static func decode(_ dict: [String: Any]?) -> StageEffects? {
        guard let dict else { return nil }
        var fx = StageEffects()
        fx.colorGrading =
            ColorGrading(dict["colorGrading"] as? [String: Any])
        fx.bloom = Bloom(dict["bloom"] as? [String: Any])
        fx.lensFlare = LensFlare(dict["lensFlare"] as? [String: Any])
        fx.vignette = Vignette(dict["vignette"] as? [String: Any])
        fx.chromaticAberration = ChromaticAberration(
            dict["chromaticAberration"] as? [String: Any])
        fx.filmGrain = FilmGrain(dict["filmGrain"] as? [String: Any])
        fx.ambientOcclusion = AmbientOcclusion(
            dict["ambientOcclusion"] as? [String: Any])
        fx.screenSpaceReflections = ScreenSpaceReflections(
            dict["screenSpaceReflections"] as? [String: Any])
        fx.globalIllumination = GlobalIllumination(
            dict["globalIllumination"] as? [String: Any])
        fx.temporalAntiAliasing = TemporalAntiAliasing(
            dict["temporalAntiAliasing"] as? [String: Any])
        fx.fog = Fog(dict["fog"] as? [String: Any])
        fx.godRays = GodRays(dict["godRays"] as? [String: Any])
        fx.depthOfField =
            DepthOfField(dict["depthOfField"] as? [String: Any])
        fx.autoExposure =
            AutoExposure(dict["autoExposure"] as? [String: Any])
        return fx
    }
}

// MARK: - W20 groundwork: per-volume blending

extension StageEffects {

    /// One resolved environment contribution to blend over the base —
    /// upstream `EnvironmentContribution` (`environment_volume.dart`).
    /// `weight` is the effective 0..1 strength (volume coverage ×
    /// master weight, already folded by the caller); `priority` orders
    /// the fold so a higher-priority volume applies later (on top).
    struct Contribution {
        var effects: StageEffects
        var weight: Double
        var priority: Double
    }

    /// Upstream `blendEnvironmentContributions`: drops weight-0
    /// contributions, sorts ascending by priority, folds `lerp` left
    /// over `base` so the strongest, highest-priority look lands last.
    static func blendContributions(
        _ base: StageEffects,
        _ contributions: [Contribution]
    ) -> StageEffects {
        let active = contributions
            .filter { $0.weight > 0 }
            .sorted { $0.priority < $1.priority }
        var result = base
        for c in active {
            result = lerp(result, c.effects, t: min(max(c.weight, 0), 1))
        }
        return result
    }

    /// Upstream `EnvironmentSettings.lerp`: every numeric leaf
    /// interpolates `a + (b - a) * t`; discrete fields — `enabled`
    /// flags, mode/quality strings, sample/step counts, LUT identity,
    /// the GI resolution/extents — switch to `b` once `t >= 0.5`.
    /// Starting from `d` (the discrete pick) then overwriting the
    /// continuous leaves keeps the split a per-field list instead of
    /// a per-field constructor.
    static func lerp(_ a: StageEffects, _ b: StageEffects, t: Double) -> StageEffects {
        var r = t >= 0.5 ? b : a

        r.colorGrading.brightness = fxLerp(a.colorGrading.brightness, b.colorGrading.brightness, t)
        r.colorGrading.contrast = fxLerp(a.colorGrading.contrast, b.colorGrading.contrast, t)
        r.colorGrading.saturation = fxLerp(a.colorGrading.saturation, b.colorGrading.saturation, t)
        r.colorGrading.temperature = fxLerp(a.colorGrading.temperature, b.colorGrading.temperature, t)
        r.colorGrading.tint = fxLerp(a.colorGrading.tint, b.colorGrading.tint, t)
        r.colorGrading.lift = fxLerp3(a.colorGrading.lift, b.colorGrading.lift, t)
        r.colorGrading.gamma = fxLerp3(a.colorGrading.gamma, b.colorGrading.gamma, t)
        r.colorGrading.gain = fxLerp3(a.colorGrading.gain, b.colorGrading.gain, t)
        r.colorGrading.lutBlend = fxLerp(a.colorGrading.lutBlend, b.colorGrading.lutBlend, t)

        r.bloom.threshold = fxLerp(a.bloom.threshold, b.bloom.threshold, t)
        r.bloom.intensity = fxLerp(a.bloom.intensity, b.bloom.intensity, t)
        r.bloom.scatter = fxLerp(a.bloom.scatter, b.bloom.scatter, t)

        r.lensFlare.intensity = fxLerp(a.lensFlare.intensity, b.lensFlare.intensity, t)
        r.lensFlare.ghostSpacing = fxLerp(a.lensFlare.ghostSpacing, b.lensFlare.ghostSpacing, t)
        r.lensFlare.haloRadius = fxLerp(a.lensFlare.haloRadius, b.lensFlare.haloRadius, t)
        r.lensFlare.haloIntensity = fxLerp(a.lensFlare.haloIntensity, b.lensFlare.haloIntensity, t)
        r.lensFlare.chromaticAberration = fxLerp(
            a.lensFlare.chromaticAberration, b.lensFlare.chromaticAberration, t)

        r.vignette.intensity = fxLerp(a.vignette.intensity, b.vignette.intensity, t)
        r.vignette.radius = fxLerp(a.vignette.radius, b.vignette.radius, t)
        r.vignette.smoothness = fxLerp(a.vignette.smoothness, b.vignette.smoothness, t)

        r.chromaticAberration.intensity = fxLerp(
            a.chromaticAberration.intensity, b.chromaticAberration.intensity, t)

        r.filmGrain.intensity = fxLerp(a.filmGrain.intensity, b.filmGrain.intensity, t)

        r.ambientOcclusion.radius = fxLerp(a.ambientOcclusion.radius, b.ambientOcclusion.radius, t)
        r.ambientOcclusion.intensity = fxLerp(
            a.ambientOcclusion.intensity, b.ambientOcclusion.intensity, t)
        r.ambientOcclusion.bias = fxLerp(a.ambientOcclusion.bias, b.ambientOcclusion.bias, t)
        r.ambientOcclusion.power = fxLerp(a.ambientOcclusion.power, b.ambientOcclusion.power, t)
        r.ambientOcclusion.detail = fxLerp(a.ambientOcclusion.detail, b.ambientOcclusion.detail, t)
        r.ambientOcclusion.horizonAngle = fxLerp(
            a.ambientOcclusion.horizonAngle, b.ambientOcclusion.horizonAngle, t)
        r.ambientOcclusion.directLightAffect = fxLerp(
            a.ambientOcclusion.directLightAffect, b.ambientOcclusion.directLightAffect, t)
        r.ambientOcclusion.multiBounce = fxLerp(
            a.ambientOcclusion.multiBounce, b.ambientOcclusion.multiBounce, t)
        r.ambientOcclusion.thickness = fxLerp(
            a.ambientOcclusion.thickness, b.ambientOcclusion.thickness, t)
        r.ambientOcclusion.thicknessHeuristic = fxLerp(
            a.ambientOcclusion.thicknessHeuristic, b.ambientOcclusion.thicknessHeuristic, t)
        r.ambientOcclusion.indirectLight = fxLerp(
            a.ambientOcclusion.indirectLight, b.ambientOcclusion.indirectLight, t)

        r.screenSpaceReflections.intensity = fxLerp(
            a.screenSpaceReflections.intensity, b.screenSpaceReflections.intensity, t)
        r.screenSpaceReflections.maxDistance = fxLerp(
            a.screenSpaceReflections.maxDistance, b.screenSpaceReflections.maxDistance, t)
        r.screenSpaceReflections.thickness = fxLerp(
            a.screenSpaceReflections.thickness, b.screenSpaceReflections.thickness, t)
        r.screenSpaceReflections.stride = fxLerp(
            a.screenSpaceReflections.stride, b.screenSpaceReflections.stride, t)
        r.screenSpaceReflections.blur = fxLerp(
            a.screenSpaceReflections.blur, b.screenSpaceReflections.blur, t)
        r.screenSpaceReflections.distanceFadeStart = fxLerp(
            a.screenSpaceReflections.distanceFadeStart,
            b.screenSpaceReflections.distanceFadeStart, t)
        r.screenSpaceReflections.resolutionScale = fxLerp(
            a.screenSpaceReflections.resolutionScale,
            b.screenSpaceReflections.resolutionScale, t)

        r.globalIllumination.intensity = fxLerp(
            a.globalIllumination.intensity, b.globalIllumination.intensity, t)
        r.globalIllumination.visibility = fxLerp(
            a.globalIllumination.visibility, b.globalIllumination.visibility, t)

        r.temporalAntiAliasing.minimumCurrentWeight = fxLerp(
            a.temporalAntiAliasing.minimumCurrentWeight,
            b.temporalAntiAliasing.minimumCurrentWeight, t)
        r.temporalAntiAliasing.varianceGamma = fxLerp(
            a.temporalAntiAliasing.varianceGamma, b.temporalAntiAliasing.varianceGamma, t)
        r.temporalAntiAliasing.sharpness = fxLerp(
            a.temporalAntiAliasing.sharpness, b.temporalAntiAliasing.sharpness, t)
        r.temporalAntiAliasing.jitterScale = fxLerp(
            a.temporalAntiAliasing.jitterScale, b.temporalAntiAliasing.jitterScale, t)

        r.fog.color = fxLerp3(a.fog.color, b.fog.color, t)
        r.fog.skyColorInfluence = fxLerp(a.fog.skyColorInfluence, b.fog.skyColorInfluence, t)
        r.fog.density = fxLerp(a.fog.density, b.fog.density, t)
        r.fog.start = fxLerp(a.fog.start, b.fog.start, t)
        r.fog.end = fxLerp(a.fog.end, b.fog.end, t)
        r.fog.maxOpacity = fxLerp(a.fog.maxOpacity, b.fog.maxOpacity, t)
        r.fog.cutoffDistance = fxLerp(a.fog.cutoffDistance, b.fog.cutoffDistance, t)
        r.fog.height = fxLerp(a.fog.height, b.fog.height, t)
        r.fog.heightFalloff = fxLerp(a.fog.heightFalloff, b.fog.heightFalloff, t)
        r.fog.sunInScatter = fxLerp(a.fog.sunInScatter, b.fog.sunInScatter, t)
        r.fog.sunInScatterExponent = fxLerp(
            a.fog.sunInScatterExponent, b.fog.sunInScatterExponent, t)

        r.godRays.intensity = fxLerp(a.godRays.intensity, b.godRays.intensity, t)
        r.godRays.density = fxLerp(a.godRays.density, b.godRays.density, t)
        r.godRays.anisotropy = fxLerp(a.godRays.anisotropy, b.godRays.anisotropy, t)
        r.godRays.maxDistance = fxLerp(a.godRays.maxDistance, b.godRays.maxDistance, t)
        r.godRays.jitter = fxLerp(a.godRays.jitter, b.godRays.jitter, t)
        r.godRays.color = fxLerp3(a.godRays.color, b.godRays.color, t)

        r.depthOfField.focusDistance = fxLerp(
            a.depthOfField.focusDistance, b.depthOfField.focusDistance, t)
        r.depthOfField.fStop = fxLerp(a.depthOfField.fStop, b.depthOfField.fStop, t)
        r.depthOfField.focalLength = fxLerp(
            a.depthOfField.focalLength, b.depthOfField.focalLength, t)
        r.depthOfField.sensorHeight = fxLerp(
            a.depthOfField.sensorHeight, b.depthOfField.sensorHeight, t)
        r.depthOfField.blurScale = fxLerp(a.depthOfField.blurScale, b.depthOfField.blurScale, t)
        r.depthOfField.maxForegroundBlur = fxLerp(
            a.depthOfField.maxForegroundBlur, b.depthOfField.maxForegroundBlur, t)
        r.depthOfField.maxBackgroundBlur = fxLerp(
            a.depthOfField.maxBackgroundBlur, b.depthOfField.maxBackgroundBlur, t)
        r.depthOfField.bladeRotation = fxLerp(
            a.depthOfField.bladeRotation, b.depthOfField.bladeRotation, t)
        r.depthOfField.bladeCurvature = fxLerp(
            a.depthOfField.bladeCurvature, b.depthOfField.bladeCurvature, t)

        r.autoExposure.strength = fxLerp(a.autoExposure.strength, b.autoExposure.strength, t)
        r.autoExposure.compensation = fxLerp(
            a.autoExposure.compensation, b.autoExposure.compensation, t)
        r.autoExposure.minEv = fxLerp(a.autoExposure.minEv, b.autoExposure.minEv, t)
        r.autoExposure.maxEv = fxLerp(a.autoExposure.maxEv, b.autoExposure.maxEv, t)
        r.autoExposure.speedUp = fxLerp(a.autoExposure.speedUp, b.autoExposure.speedUp, t)
        r.autoExposure.speedDown = fxLerp(a.autoExposure.speedDown, b.autoExposure.speedDown, t)

        return r
    }
}

// MARK: - Untagged JSON helpers

/// The `effects` block serializes as plain JSON values (no `{'d':…}`
/// tags) — these mirror `Context.plainDouble`/`rawVec3` in
/// FsceneRealizer, which are instance helpers this static decode
/// can't reach.
private func fxNum(_ v: Any?, _ d: Double) -> Double {
    (v as? NSNumber)?.doubleValue ?? d
}

private func fxInt(_ v: Any?, _ d: Int) -> Int {
    (v as? NSNumber)?.intValue ?? d
}

private func fxBool(_ v: Any?, _ d: Bool) -> Bool {
    (v as? NSNumber)?.boolValue ?? d
}

private func fxStr(_ v: Any?, _ d: String) -> String {
    v as? String ?? d
}

private func fxVec3(_ v: Any?, _ d: SIMD3<Float>) -> SIMD3<Float> {
    guard let a = v as? [Any], a.count >= 3,
          let x = (a[0] as? NSNumber)?.floatValue,
          let y = (a[1] as? NSNumber)?.floatValue,
          let z = (a[2] as? NSNumber)?.floatValue
    else { return d }
    return SIMD3<Float>(x, y, z)
}

private func fxLerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

private func fxLerp3(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Double) -> SIMD3<Float> {
    a + (b - a) * Float(t)
}
