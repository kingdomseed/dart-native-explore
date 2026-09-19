import Foundation
import CoreGraphics

/// W25: a parsed `.cube` 3D color-grading table — the cube edge
/// length plus the red-fastest RGB triples. Pure value type; the
/// SceneKit upload happens through `stripImage`.
///
/// Port of upstream `parseCubeTable`/`packCubeStrip`
/// (`flutter_scene/lib/src/post_process/color_lut.dart`): Adobe/IRIDAS
/// `.cube` text — `TITLE`/`DOMAIN_MIN`/`DOMAIN_MAX` tolerated,
/// `LUT_1D_SIZE` rejected, `LUT_3D_SIZE` 2…64, exactly `size³` RGB
/// rows in red-fastest order.
struct StageLut {

    let size: Int
    /// `size³ × 3` floats, red-fastest (`r + g·N + b·N²` cells).
    let values: [Float]

    enum ParseError: Error, CustomStringConvertible {
        case oneDimensional
        case badSize
        case tooManyRows
        case missingRows
        var description: String {
            switch self {
            case .oneDimensional:
                return "1D .cube tables are not supported."
            case .badSize:
                return "LUT_3D_SIZE must be between 2 and 64."
            case .tooManyRows:
                return "The .cube table has more rows than its size."
            case .missingRows:
                return "The .cube table is missing rows."
            }
        }
    }

    /// Parses `.cube` text into a table. Throws `ParseError` on the
    /// same conditions upstream does; non-table lines that carry
    /// fewer than three tokens are skipped, matching the upstream
    /// tolerance.
    static func parse(_ content: String) throws -> StageLut {
        var size = 0
        var values: [Float] = []
        var cursor = 0
        for rawLine in content.split(separator: "\n",
                                     omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(
                in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let tokens = line.split(
                whereSeparator: { $0 == " " || $0 == "\t" })
            guard let first = tokens.first else { continue }
            let keyword = first.uppercased()
            if keyword == "TITLE" || keyword == "DOMAIN_MIN"
                || keyword == "DOMAIN_MAX" {
                continue
            }
            if keyword == "LUT_1D_SIZE" { throw ParseError.oneDimensional }
            if keyword == "LUT_3D_SIZE" {
                size = tokens.count > 1 ? (Int(tokens[1]) ?? 0) : 0
                guard size >= 2 && size <= 64 else {
                    throw ParseError.badSize
                }
                values = [Float](repeating: 0,
                                 count: size * size * size * 3)
                continue
            }
            if values.isEmpty || tokens.count < 3 { continue }
            if cursor + 3 > values.count {
                throw ParseError.tooManyRows
            }
            values[cursor] = Float(tokens[0]) ?? 0
            values[cursor + 1] = Float(tokens[1]) ?? 0
            values[cursor + 2] = Float(tokens[2]) ?? 0
            cursor += 3
        }
        guard !values.isEmpty, cursor == values.count else {
            throw ParseError.missingRows
        }
        return StageLut(size: size, values: values)
    }

    static func parse(data: Data) throws -> StageLut {
        try parse(String(decoding: data, as: UTF8.self))
    }

    /// Packs the table into the blue-slice strip `SCNCamera`
    /// .`colorGrading` expects: `N*N` wide by `N` tall RGBA8, each
    /// blue slice side by side, red fastest inside a slice —
    /// upstream's `packCubeStrip` layout
    /// (`pixel = g·N² + b·N + r` RGBA cells).
    ///
    /// `blend` is the wire `lutBlend`: each output texel lerps toward
    /// the identity value at its cube coordinate, so `0` is a no-op
    /// grade and `1` the authored table — SceneKit's
    /// `SCNMaterialProperty.intensity` has no documented LUT blend
    /// semantics, so the mix bakes into the pixels.
    func stripBytes(blend: Double = 1.0) -> Data {
        let n = size
        var bytes = [UInt8](repeating: 255, count: n * n * n * 4)
        let stripWidth = n * n
        let b01 = Float(min(max(blend, 0), 1))
        let denom = Float(n - 1)
        for i in 0..<(n * n * n) {
            let r = i % n
            let g = (i / n) % n
            let b = i / (n * n)
            let pixel = (g * stripWidth + b * n + r) * 4
            // Identity value at this cube coordinate, blended per
            // lutBlend: out = id + (lut - id) · blend.
            let idr = Float(r) / denom
            let idg = Float(g) / denom
            let idb = Float(b) / denom
            let vr = idr + (values[i * 3] - idr) * b01
            let vg = idg + (values[i * 3 + 1] - idg) * b01
            let vb = idb + (values[i * 3 + 2] - idb) * b01
            bytes[pixel] = UInt8((min(max(vr, 0), 1) * 255).rounded())
            bytes[pixel + 1] = UInt8((min(max(vg, 0), 1) * 255).rounded())
            bytes[pixel + 2] = UInt8((min(max(vb, 0), 1) * 255).rounded())
            bytes[pixel + 3] = 255
        }
        return Data(bytes)
    }

    /// The strip as a `CGImage` for `SCNCamera.colorGrading.contents`
    /// — `N*N` × `N` sRGB8, provider-referenced so the image owns its
    /// bytes (no context copy needed for a static table).
    func stripImage(blend: Double = 1.0) -> CGImage? {
        let bytes = stripBytes(blend: blend)
        let n = size
        guard let provider = CGDataProvider(data: bytes as CFData)
        else { return nil }
        return CGImage(
            width: n * n, height: n,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: n * n * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil, shouldInterpolate: true,
            intent: .defaultIntent)
    }
}
