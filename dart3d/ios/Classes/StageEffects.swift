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
