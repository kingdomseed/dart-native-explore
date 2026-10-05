import CoreGraphics
import Foundation
import Metal
import SceneKit

/// The stage's tone-mapping operator and its AgX parameters (the env
/// resource's `toneMapping`, `agxWhite`, `agxContrast`).
struct StageToneMap: Equatable {
    var mode = "pbrNeutral"
    var agxWhite = 16.29
    var agxContrast = 1.25

    /// The operator's index in the resolve shader; nil for a name
    /// upstream does not define.
    var modeIndex: Int? {
        switch mode {
        case "pbrNeutral": return 0
        case "aces": return 1
        case "reinhard": return 2
        case "linear": return 3
        case "agx": return 4
        default: return nil
        }
    }

    /// Upstream's AgX curve parameters (`resolve_info.dart`): contrast,
    /// toe coefficient, slope at the crossover, shoulder scale.
    var agxParams: SCNVector4 {
        let crossover = 0.18
        let shoulderMax = 1.0 - crossover
        let contrast = max(agxContrast, 0.01)
        let white = max(agxWhite, 2.0)
        let crossoverPower = pow(crossover, contrast)
        let toeA = (1.0 / crossover - 1.0) * crossoverPower
        let denominator = crossoverPower + toeA
        let slope = contrast * pow(crossover, contrast - 1.0) * toeA
            / (denominator * denominator)
        let shoulderWidth = white - crossover
        return SCNVector4(
            Float(contrast), Float(toeA), Float(slope),
            Float(shoulderWidth * shoulderWidth / shoulderMax * slope))
    }
}

/// What the resolve pass applies besides the tone map: upstream's
/// colour grading (before the tone map), its vignette (after) and the
/// grading LUT (last, on the encoded colour).
struct StageResolve {
    var toneMap = StageToneMap()
    /// Nil leaves the colour ungraded.
    var grading: StageEffects.ColorGrading?
    /// Nil draws no vignette.
    var vignette: StageEffects.Vignette?
    /// The LUT's strip image; its height is the cube's edge length.
    var lut: CGImage?
}

/// The resolve pass that turns SceneKit's image into the display image
/// the way upstream's resolve shader does: grade, tone map, vignette,
/// then the grading LUT on the sRGB-encoded colour.
///
/// SceneKit has no tone-mapper choice, and what it hands an
/// `SCNTechnique` pass in an `SCNView` is already clamped to 0…1. Its
/// own curve, though, is an extended Reinhard with the camera's
/// `whitePoint` as the value that maps to 1 (measured:
/// `x (1 + x / w²) / (1 + x)`, per channel, after exposure and bloom).
/// So the camera runs with a white point of [whitePoint], which packs
/// exposed radiance up to that value into 0…1, and the pass inverts
/// the curve exactly to recover the linear image upstream's shader
/// sees after `color *= exposure`.
///
/// SceneKit applies its own saturation, contrast and vignette after
/// that curve, where they would be inverted along with it; the host
/// leaves them off and the pass does upstream's instead.
///
/// `pbrNeutral`, `reinhard` and `linear` are evaluated in Rec. 2020
/// primaries, not upstream's Rec. 709: that is where Filament's
/// colour grading runs them on Android, and the two natives have to
/// agree first. Greys are unaffected; a saturated colour keeps more of
/// its saturation than upstream's (pure green under `pbrNeutral` ends
/// at (0, 0.92, 0), upstream's at (0.016, 0.88, 0.016)).
enum ToneMapTechnique {

    /// The radiance SceneKit's curve maps to 1. Brighter values clip.
    static let whitePoint = 16.0

    /// The operators are upstream's `shaders/tone_mapping.glsl`, the
    /// grading, vignette and LUT lookup its
    /// `flutter_scene_resolve.frag`, ported to Metal.
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct D3ResolveIn { float4 position [[attribute(0)]]; };
    struct D3ResolveOut { float4 position [[position]]; float2 uv; };
    struct D3ResolveParams {
        float4 d3Mode;
        float4 d3Agx;
        float4 d3Grade;
        float4 d3Lift;
        float4 d3Gamma;
        float4 d3Gain;
        float4 d3Vignette;
    };

    vertex D3ResolveOut d3_resolve_vertex(D3ResolveIn in [[stage_in]]) {
        D3ResolveOut out;
        out.position = in.position;
        out.uv = float2((in.position.x + 1.0) * 0.5,
                        (1.0 - in.position.y) * 0.5);
        return out;
    }

    static float3 d3_rrt_odt_fit(float3 v) {
        float3 a = v * (v + 0.0245786) - 0.000090537;
        float3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
        return a / b;
    }

    static float3 d3_aces(float3 color) {
        const float3x3 inputMat = float3x3(
            float3(0.59719, 0.07600, 0.02840),
            float3(0.35458, 0.90834, 0.13383),
            float3(0.04823, 0.01566, 0.83777));
        const float3x3 outputMat = float3x3(
            float3(1.60475, -0.10208, -0.00327),
            float3(-0.53108, 1.10813, -0.07276),
            float3(-0.07367, -0.00605, 1.07602));
        color *= 1.0 / 0.6;
        color = inputMat * color;
        color = d3_rrt_odt_fit(color);
        color = outputMat * color;
        return saturate(color);
    }

    static float3 d3_pbr_neutral(float3 color) {
        const float startCompression = 0.8 - 0.04;
        const float desaturation = 0.15;
        float x = min(color.r, min(color.g, color.b));
        float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
        color -= offset;
        float peak = max(color.r, max(color.g, color.b));
        if (peak < startCompression) { return color; }
        const float d = 1.0 - startCompression;
        float newPeak = 1.0 - d * d / (peak + d - startCompression);
        color *= newPeak / peak;
        float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
        return mix(color, float3(newPeak), g);
    }

    static float3 d3_allen_wp(float3 x, float4 params) {
        const float crossover = 0.18;
        const float shoulderMax = 1.0 - crossover;
        float3 s = x - crossover;
        float3 slopeS = params.z * s;
        s = slopeS * (1.0 + s / params.w) / (1.0 + slopeS / shoulderMax);
        s += crossover;
        float3 p = pow(x, float3(params.x));
        float3 t = p / (p + params.y);
        return select(s, t, x < float3(crossover));
    }

    static float3 d3_agx(float3 color, float4 params) {
        const float3x3 inset = float3x3(
            float3(0.544814746488245, 0.140416948464053, 0.0888104196149096),
            float3(0.373787398372697, 0.754137554567394, 0.178871756420858),
            float3(0.0813978551390581, 0.105445496968552, 0.732317823964232));
        const float3x3 outset = float3x3(
            float3(1.96488741169489, -0.299313364904742, -0.164352742528393),
            float3(-0.855988495690215, 1.32639796461980, -0.238183969428088),
            float3(-0.108898916004672, -0.0270845997150571, 1.40253671195648));
        color = inset * max(color, float3(0.0));
        color = d3_allen_wp(color, params);
        color = min(color, float3(1.0));
        return saturate(outset * color);
    }

    static float3 d3_encode(float3 c) {
        return select(1.055 * pow(c, float3(1.0 / 2.4)) - 0.055,
                      c * 12.92, c <= float3(0.0031308));
    }

    static float3 d3_decode(float3 c) {
        return select(pow((c + 0.055) / 1.055, float3(2.4)),
                      c / 12.92, c <= float3(0.04045));
    }

    static float3 d3_lut(texture2d<float> lut, float3 c, float size) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float3 scaled = saturate(c) * (size - 1.0);
        float slice0 = floor(scaled.z);
        float slice1 = min(slice0 + 1.0, size - 1.0);
        float2 texel = float2(1.0 / (size * size), 1.0 / size);
        float2 base = float2(scaled.x + 0.5, scaled.y + 0.5);
        float3 tap0 = lut.sample(s, (base + float2(slice0 * size, 0.0)) * texel).rgb;
        float3 tap1 = lut.sample(s, (base + float2(slice1 * size, 0.0)) * texel).rgb;
        return mix(tap0, tap1, scaled.z - slice0);
    }

    // y = x (1 + x / w²) / (1 + x), solved for x.
    static float3 d3_scene_radiance(float3 y, float w) {
        float3 b = 1.0 - y;
        float w2 = w * w;
        return 0.5 * w2 * (sqrt(b * b + 4.0 * y / w2) - b);
    }

    static float3 d3_grade(float3 color, D3ResolveParams params) {
        float temperature = params.d3Grade.z;
        float tint = params.d3Grade.w;
        color *= float3(1.0 + temperature * 0.2, 1.0 + tint * 0.2,
                        1.0 - temperature * 0.2);
        color = params.d3Gain.rgb
            * (color + params.d3Lift.rgb * (1.0 - color));
        color = pow(max(color, float3(0.0)),
                    1.0 / max(params.d3Gamma.rgb, float3(1e-4)));
        const float midGray = 0.18;
        color = (color - midGray) * params.d3Grade.x + midGray;
        color = max(color, float3(0.0));
        float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
        return mix(float3(luma), color, params.d3Grade.y);
    }

    fragment float4 d3_resolve_fragment(
        D3ResolveOut in [[stage_in]],
        texture2d<float> colorSampler [[texture(0)]],
        texture2d<float> d3Lut [[texture(1)]],
        constant D3ResolveParams& params [[buffer(0)]])
    {
        constexpr sampler s(filter::nearest, address::clamp_to_edge);
        float4 packed = colorSampler.sample(s, in.uv);
        float3 color = d3_scene_radiance(saturate(packed.rgb),
                                         params.d3Mode.z);
        if (params.d3Mode.w > 0.5) {
            color = d3_grade(color, params);
        }
        const float3x3 toRec2020 = float3x3(
            float3(0.627404, 0.069097, 0.016391),
            float3(0.329283, 0.919540, 0.088013),
            float3(0.043313, 0.011362, 0.895595));
        const float3x3 toRec709 = float3x3(
            float3(1.660491, -0.124550, -0.018151),
            float3(-0.587641, 1.132900, -0.100579),
            float3(-0.072850, -0.008349, 1.118730));
        float mode = params.d3Mode.x;
        float3 mapped;
        if (mode > 0.5 && mode < 1.5) {
            mapped = d3_aces(color);
        } else if (mode > 3.5) {
            mapped = d3_agx(color, params.d3Agx);
        } else {
            float3 wide = toRec2020 * color;
            if (mode < 0.5) {
                wide = d3_pbr_neutral(wide);
            } else if (mode < 2.5) {
                wide = wide / (1.0 + wide);
            } else {
                wide = saturate(wide);
            }
            mapped = saturate(toRec709 * wide);
        }
        if (params.d3Vignette.x > 0.0) {
            float dist = length((in.uv - 0.5) * 2.0);
            float falloff = smoothstep(
                params.d3Vignette.y,
                params.d3Vignette.y + params.d3Vignette.z, dist);
            mapped *= 1.0 - falloff * params.d3Vignette.x;
        }
        if (params.d3Mode.y > 0.5) {
            mapped = d3_decode(d3_lut(d3Lut, d3_encode(saturate(mapped)),
                                      params.d3Mode.y));
        }
        return float4(mapped, packed.a);
    }
    """

    private static var libraries: [ObjectIdentifier: MTLLibrary] = [:]

    private static func library(for device: MTLDevice) -> MTLLibrary? {
        let id = ObjectIdentifier(device)
        if let lib = libraries[id] { return lib }
        guard let lib = try? device.makeLibrary(source: source, options: nil)
        else { return nil }
        libraries[id] = lib
        return lib
    }

    /// A 1×1 texture for the LUT slot while no LUT is set.
    private static let noLut: CGImage? = {
        guard let provider = CGDataProvider(
                  data: Data([255, 255, 255, 255]) as CFData),
              let space = CGColorSpace(name: CGColorSpace.linearSRGB)
        else { return nil }
        return CGImage(
            width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: 4, space: space,
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent)
    }()

    private static let vectorSymbols = [
        "d3Mode", "d3Agx", "d3Grade", "d3Lift", "d3Gamma", "d3Gain",
        "d3Vignette",
    ]

    /// A technique with the resolve pass; nil when the shader library
    /// cannot be built on [device].
    static func make(device: MTLDevice) -> SCNTechnique? {
        guard let lib = library(for: device) else { return nil }
        var inputs: [String: Any] = [
            "colorSampler": "COLOR",
            "d3Lut": "d3LutSymbol",
        ]
        var symbols: [String: Any] = ["d3LutSymbol": ["type": "sampler2D"]]
        for name in vectorSymbols {
            inputs[name] = name + "Symbol"
            symbols[name + "Symbol"] = ["type": "vec4"]
        }
        let pass: [String: Any] = [
            "draw": "DRAW_QUAD",
            "metalVertexShader": "d3_resolve_vertex",
            "metalFragmentShader": "d3_resolve_fragment",
            "inputs": inputs,
            "outputs": ["color": "COLOR"],
        ]
        let definition: [String: Any] = [
            "passes": ["d3_resolve": pass],
            "sequence": ["d3_resolve"],
            "symbols": symbols,
        ]
        guard let technique = SCNTechnique(dictionary: definition)
        else { return nil }
        technique.library = lib
        return technique
    }

    /// Writes [resolve] into [technique].
    static func configure(_ technique: SCNTechnique, _ resolve: StageResolve) {
        func set(_ name: String, _ x: Double, _ y: Double, _ z: Double,
                 _ w: Double) {
            technique.setObject(
                NSValue(scnVector4: SCNVector4(
                    Float(x), Float(y), Float(z), Float(w))),
                forKeyedSubscript: (name + "Symbol") as NSCopying)
        }
        let lutSize = resolve.lut.map { $0.height } ?? 0
        let hasLut = lutSize >= 2
        let grading = resolve.grading
        set("d3Mode", Double(resolve.toneMap.modeIndex ?? 0),
            hasLut ? Double(lutSize) : 0, whitePoint,
            grading == nil ? 0 : 1)
        technique.setObject(
            NSValue(scnVector4: resolve.toneMap.agxParams),
            forKeyedSubscript: "d3AgxSymbol" as NSCopying)
        set("d3Grade", grading?.contrast ?? 1, grading?.saturation ?? 1,
            grading?.temperature ?? 0, grading?.tint ?? 0)
        let lift = grading?.lift ?? SIMD3<Float>(0, 0, 0)
        let gamma = grading?.gamma ?? SIMD3<Float>(1, 1, 1)
        let gain = grading?.gain ?? SIMD3<Float>(1, 1, 1)
        set("d3Lift", Double(lift.x), Double(lift.y), Double(lift.z), 0)
        set("d3Gamma", Double(gamma.x), Double(gamma.y), Double(gamma.z), 0)
        set("d3Gain", Double(gain.x), Double(gain.y), Double(gain.z), 0)
        let vignette = resolve.vignette
        set("d3Vignette", vignette?.intensity ?? 0, vignette?.radius ?? 0,
            vignette?.smoothness ?? 0, 0)
        let property = SCNMaterialProperty(
            contents: (hasLut ? resolve.lut : noLut) as Any)
        property.minificationFilter = .linear
        property.magnificationFilter = .linear
        property.mipFilter = .none
        property.wrapS = .clamp
        property.wrapT = .clamp
        technique.setObject(
            property, forKeyedSubscript: "d3LutSymbol" as NSCopying)
    }
}
