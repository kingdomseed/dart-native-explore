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

/// What the resolve pass applies besides the tone map: bloom and
/// upstream's colour grading (before the tone map), its vignette
/// (after) and the grading LUT (last, on the encoded colour).
struct StageResolve {
    var toneMap = StageToneMap()
    /// Nil adds no bloom.
    var bloom: StageEffects.Bloom?
    /// Nil leaves the colour ungraded.
    var grading: StageEffects.ColorGrading?
    /// Nil draws no vignette.
    var vignette: StageEffects.Vignette?
    /// The LUT's strip image; its height is the cube's edge length.
    var lut: CGImage?
}

/// The size of the bloom chain a technique is built for: the pixel
/// size of its first level and how many levels it has.
struct BloomChain: Equatable {
    var width: Int
    var height: Int
    var levels: Int

    /// The chain Filament builds on Android for the same view and the
    /// same `scatter`: its first level is 384 pixels on the view's
    /// short side, each further level half the one before, and the
    /// count is `3 + 8 × scatter`, as far as a level stays a pixel
    /// wide.
    init?(viewWidth: Int, viewHeight: Int, scatter: Double) {
        let short = min(viewWidth, viewHeight)
        guard short > 0 else { return nil }
        let scale = 384.0 / Double(short)
        width = max(1, Int((Double(viewWidth) * scale).rounded()))
        height = max(1, Int((Double(viewHeight) * scale).rounded()))
        let fit = Int(log2(Double(min(width, height)))) + 1
        levels = min(max(Int(3 + 8 * scatter), 3), min(11, fit))
    }
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
/// So the camera runs with a white point that packs exposed radiance
/// up to [whitePoint] into 0…1 (after a gain, [packGain], that spends
/// more of the 8-bit codes on dark colours), and the pass inverts the
/// curve exactly to recover the linear image upstream's shader sees
/// after `color *= exposure`.
///
/// SceneKit applies its own saturation, contrast and vignette after
/// that curve, where they would be inverted along with it; the host
/// leaves them off and the pass does upstream's instead.
///
/// Bloom is Filament's, because Android's is: the part of each channel
/// above 1 is kept, compressed toward Filament's highlight limit,
/// blurred through a chain of half-size levels and added back at
/// `intensity / levels`. Android passes the stage's `threshold` as
/// that limit, and Filament raises any limit below 10 to 10, so for
/// every threshold a scene would use the knee is at 1 and the limit is
/// 10 on both natives. SceneKit's own bloom gates on luminance at the
/// threshold and adds the whole colour: a saturated emitter just over
/// 1 in one channel bloomed on Android and not on iOS, and anything
/// brighter than a low threshold washed out on iOS only.
///
/// `pbrNeutral`, `reinhard` and `linear` are evaluated in Rec. 2020
/// primaries, not upstream's Rec. 709: that is where Filament's
/// colour grading runs them on Android, and the two natives have to
/// agree first. Greys are unaffected; a saturated colour keeps more of
/// its saturation than upstream's (pure green under `pbrNeutral` ends
/// at (0, 0.92, 0), upstream's at (0.016, 0.88, 0.016)).
enum ToneMapTechnique {

    /// The radiance the resolve pass can recover. Brighter values clip.
    static let whitePoint = 16.0

    /// A gain the camera applies on top of the stage's exposure before
    /// SceneKit packs the image, and the pass divides out again. The
    /// packed image is stored in 8 bits per channel; without the gain
    /// a near-black colour falls on so few codes that PBR Neutral's
    /// toe, which subtracts almost all of it, turned (0.018, 0.021,
    /// 0.023) into sRGB (0, 14, 23) instead of (4, 12, 18).
    static let packGain = 8.0

    /// The lowest highlight limit Filament's bloom accepts.
    static let filamentHighlightFloor = 10.0

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
        float4 d3Bloom;
    };
    struct D3BloomParams {
        float4 d3Mode;
        float4 d3Bloom;
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

    // The first bloom level: Filament's threshold on the scene's
    // radiance (keep what is above 1, compress it toward the highlight
    // limit), box-filtered down to the level's size.
    fragment float4 d3_bloom_bright_fragment(
        D3ResolveOut in [[stage_in]],
        texture2d<float> colorSampler [[texture(0)]],
        constant D3BloomParams& params [[buffer(0)]])
    {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float2 texel = 1.0 / float2(colorSampler.get_width(),
                                    colorSampler.get_height());
        float3 sum = float3(0.0);
        for (int y = -1; y <= 1; y += 2) {
            for (int x = -1; x <= 1; x += 2) {
                float3 packed = colorSampler.sample(
                    s, in.uv + float2(x, y) * texel).rgb;
                float3 c = d3_scene_radiance(saturate(packed),
                                             params.d3Mode.z)
                    * params.d3Bloom.z;
                c = max(c - 1.0, float3(0.0));
                float peak = max(c.r, max(c.g, c.b));
                sum += c / (1.0 + peak * params.d3Bloom.y);
            }
        }
        return float4(sum * 0.25, 1.0);
    }

    // Half-size copy of a bloom level: four bilinear taps.
    fragment float4 d3_bloom_down_fragment(
        D3ResolveOut in [[stage_in]],
        texture2d<float> d3Source [[texture(0)]])
    {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float2 texel = 1.0 / float2(d3Source.get_width(),
                                    d3Source.get_height());
        float3 sum = float3(0.0);
        for (int y = -1; y <= 1; y += 2) {
            for (int x = -1; x <= 1; x += 2) {
                sum += d3Source.sample(
                    s, in.uv + float2(x, y) * texel).rgb;
            }
        }
        return float4(sum * 0.25, 1.0);
    }

    // The smaller levels' sum, spread with a 3 × 3 tent, plus this
    // level.
    fragment float4 d3_bloom_up_fragment(
        D3ResolveOut in [[stage_in]],
        texture2d<float> d3Low [[texture(0)]],
        texture2d<float> d3High [[texture(1)]])
    {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float2 texel = 1.0 / float2(d3Low.get_width(), d3Low.get_height());
        float3 sum = float3(0.0);
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                float weight = (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0);
                sum += weight * d3Low.sample(
                    s, in.uv + float2(x, y) * texel).rgb;
            }
        }
        return float4(sum / 16.0 + d3High.sample(s, in.uv).rgb, 1.0);
    }

    fragment float4 d3_resolve_fragment(
        D3ResolveOut in [[stage_in]],
        texture2d<float> colorSampler [[texture(0)]],
        texture2d<float> d3Lut [[texture(1)]],
        texture2d<float> d3BloomSum [[texture(2)]],
        constant D3ResolveParams& params [[buffer(0)]])
    {
        constexpr sampler s(filter::nearest, address::clamp_to_edge);
        constexpr sampler smooth(filter::linear, address::clamp_to_edge);
        float4 packed = colorSampler.sample(s, in.uv);
        float3 color = d3_scene_radiance(saturate(packed.rgb),
                                         params.d3Mode.z) * params.d3Bloom.z;
        if (params.d3Bloom.x > 0.0) {
            color += d3BloomSum.sample(smooth, in.uv).rgb * params.d3Bloom.x;
        }
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
        "d3Vignette", "d3Bloom",
    ]

    /// A technique with the resolve pass, and before it the passes of
    /// a bloom chain when [bloom] is given; nil when the shader
    /// library cannot be built on [device].
    static func make(device: MTLDevice, bloom: BloomChain? = nil)
        -> SCNTechnique?
    {
        guard let lib = library(for: device) else { return nil }
        var symbols: [String: Any] = ["d3LutSymbol": ["type": "sampler2D"]]
        for name in vectorSymbols {
            symbols[name + "Symbol"] = ["type": "vec4"]
        }
        func quad(_ fragment: String, inputs: [String: Any],
                  output: String) -> [String: Any] {
            [
                "draw": "DRAW_QUAD",
                "metalVertexShader": "d3_resolve_vertex",
                "metalFragmentShader": fragment,
                "inputs": inputs,
                "outputs": ["color": output],
            ]
        }
        var passes: [String: Any] = [:]
        var sequence: [String] = []
        var targets: [String: Any] = [:]
        var resolveInputs: [String: Any] = [
            "colorSampler": "COLOR",
            "d3Lut": "d3LutSymbol",
            // Unread without bloom; the slot still needs a texture.
            "d3BloomSum": "d3LutSymbol",
        ]
        for name in vectorSymbols {
            resolveInputs[name] = name + "Symbol"
        }
        if let bloom {
            func target(_ name: String, level: Int) {
                targets[name] = [
                    "type": "color",
                    "format": "rgba16f",
                    "size": "\(max(1, bloom.width >> level))x"
                        + "\(max(1, bloom.height >> level))",
                ]
            }
            for level in 0..<bloom.levels {
                target("d3BloomDown\(level)", level: level)
            }
            passes["d3_bloom_bright"] = quad(
                "d3_bloom_bright_fragment",
                inputs: ["colorSampler": "COLOR",
                         "d3Mode": "d3ModeSymbol",
                         "d3Bloom": "d3BloomSymbol"],
                output: "d3BloomDown0")
            sequence.append("d3_bloom_bright")
            for level in 1..<bloom.levels {
                passes["d3_bloom_down\(level)"] = quad(
                    "d3_bloom_down_fragment",
                    inputs: ["d3Source": "d3BloomDown\(level - 1)"],
                    output: "d3BloomDown\(level)")
                sequence.append("d3_bloom_down\(level)")
            }
            var sum = "d3BloomDown\(bloom.levels - 1)"
            for level in stride(from: bloom.levels - 2, through: 0, by: -1) {
                target("d3BloomUp\(level)", level: level)
                passes["d3_bloom_up\(level)"] = quad(
                    "d3_bloom_up_fragment",
                    inputs: ["d3Low": sum,
                             "d3High": "d3BloomDown\(level)"],
                    output: "d3BloomUp\(level)")
                sequence.append("d3_bloom_up\(level)")
                sum = "d3BloomUp\(level)"
            }
            resolveInputs["d3BloomSum"] = sum
        }
        passes["d3_resolve"] = quad(
            "d3_resolve_fragment", inputs: resolveInputs, output: "COLOR")
        sequence.append("d3_resolve")
        var definition: [String: Any] = [
            "passes": passes,
            "sequence": sequence,
            "symbols": symbols,
        ]
        if !targets.isEmpty { definition["targets"] = targets }
        guard let technique = SCNTechnique(dictionary: definition)
        else { return nil }
        technique.library = lib
        return technique
    }

    /// Writes [resolve] into [technique], which was made for [bloom]
    /// (nil: without a bloom chain, and then no bloom is added).
    static func configure(_ technique: SCNTechnique, _ resolve: StageResolve,
                          bloom: BloomChain? = nil) {
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
            hasLut ? Double(lutSize) : 0, whitePoint * packGain,
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
        if let bloom, let fx = resolve.bloom {
            set("d3Bloom", fx.intensity / Double(bloom.levels),
                1 / max(fx.threshold, filamentHighlightFloor),
                1 / packGain, 0)
        } else {
            set("d3Bloom", 0, 0, 1 / packGain, 0)
        }
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
