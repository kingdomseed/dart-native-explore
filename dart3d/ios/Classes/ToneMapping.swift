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

/// The resolve pass that turns SceneKit's exposed linear HDR image
/// into the display image the way upstream does: tone map, then the
/// grading LUT on the sRGB-encoded colour.
///
/// SceneKit has no tone-mapper choice. With `whitePoint = 1` and
/// exposure adaptation off its own curve is the identity, and an
/// `SCNTechnique` quad pass runs after the camera's exposure, bloom
/// and grading on the unclamped result (measured with an offscreen
/// `SCNRenderer`) — so the pass below sees what upstream's resolve
/// shader sees after `color *= exposure`.
///
/// `pbrNeutral`, `reinhard` and `linear` are evaluated in Rec. 2020
/// primaries, not upstream's Rec. 709: that is where Filament's
/// colour grading runs them on Android, and the two natives have to
/// agree first. Greys are unaffected; a saturated colour keeps more of
/// its saturation than upstream's (pure green under `pbrNeutral` ends
/// at (0, 0.92, 0), upstream's at (0.016, 0.88, 0.016)).
enum ToneMapTechnique {

    /// The operators are upstream's `shaders/tone_mapping.glsl` and
    /// the LUT lookup its `ApplyGradingLut`, ported to Metal.
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct D3ResolveIn { float4 position [[attribute(0)]]; };
    struct D3ResolveOut { float4 position [[position]]; float2 uv; };
    struct D3ResolveParams {
        float4 d3Mode;
        float4 d3Agx;
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

    fragment float4 d3_resolve_fragment(
        D3ResolveOut in [[stage_in]],
        texture2d<float> colorSampler [[texture(0)]],
        texture2d<float> d3Lut [[texture(1)]],
        constant D3ResolveParams& params [[buffer(0)]])
    {
        constexpr sampler s(filter::nearest, address::clamp_to_edge);
        float4 hdr = colorSampler.sample(s, in.uv);
        float3 color = max(hdr.rgb, float3(0.0));
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
        if (params.d3Mode.y > 0.5) {
            mapped = d3_decode(d3_lut(d3Lut, d3_encode(saturate(mapped)),
                                      params.d3Mode.y));
        }
        return float4(mapped, hdr.a);
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

    /// A technique with the resolve pass; nil when the shader library
    /// cannot be built on [device].
    static func make(device: MTLDevice) -> SCNTechnique? {
        guard let lib = library(for: device) else { return nil }
        let pass: [String: Any] = [
            "draw": "DRAW_QUAD",
            "metalVertexShader": "d3_resolve_vertex",
            "metalFragmentShader": "d3_resolve_fragment",
            "inputs": [
                "colorSampler": "COLOR",
                "d3Lut": "d3LutSymbol",
                "d3Mode": "d3ModeSymbol",
                "d3Agx": "d3AgxSymbol",
            ],
            "outputs": ["color": "COLOR"],
        ]
        let definition: [String: Any] = [
            "passes": ["d3_resolve": pass],
            "sequence": ["d3_resolve"],
            "symbols": [
                "d3LutSymbol": ["type": "sampler2D"],
                "d3ModeSymbol": ["type": "vec4"],
                "d3AgxSymbol": ["type": "vec4"],
            ],
        ]
        guard let technique = SCNTechnique(dictionary: definition)
        else { return nil }
        technique.library = lib
        return technique
    }

    /// Writes the operator and the LUT into [technique]. [lut] is the
    /// strip image of a cube with [lutSize] cells per edge, or nil.
    static func configure(_ technique: SCNTechnique, map: StageToneMap,
                          lut: CGImage?, lutSize: Int) {
        let hasLut = lut != nil && lutSize >= 2
        technique.setObject(
            NSValue(scnVector4: SCNVector4(
                Float(map.modeIndex ?? 0),
                hasLut ? Float(lutSize) : 0, 0, 0)),
            forKeyedSubscript: "d3ModeSymbol" as NSCopying)
        technique.setObject(
            NSValue(scnVector4: map.agxParams),
            forKeyedSubscript: "d3AgxSymbol" as NSCopying)
        let property = SCNMaterialProperty(
            contents: (hasLut ? lut : noLut) as Any)
        property.minificationFilter = .linear
        property.magnificationFilter = .linear
        property.mipFilter = .none
        property.wrapS = .clamp
        property.wrapT = .clamp
        technique.setObject(
            property, forKeyedSubscript: "d3LutSymbol" as NSCopying)
    }
}
