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
        case nonFinite
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
            case .nonFinite:
                return "The .cube table contains a non-finite value "
                    + "(nan/inf or an overflowing exponent)."
            }
        }
    }

    /// Parses `.cube` text into a table. Throws `ParseError` on the
    /// same structural conditions upstream does; non-table lines
    /// that carry fewer than three tokens are skipped, matching the
    /// upstream tolerance. A malformed numeric token in a data row
    /// becomes `0` (`?? 0`) where upstream's `double.parse` throws —
    /// a deliberate robustness choice, not strict parity. A token that
    /// parses to a NON-finite value (`nan`, `inf`, `1e999`) rejects the
    /// whole table with `.nonFinite`: Swift's `Float(String)` accepts
    /// them, and a NaN survives the clamp in `stripBytes` (`min`/`max`
    /// propagate it) into a trapping `UInt8` conversion; an infinity
    /// times a `lutBlend` of 0 is NaN too.
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
            for c in 0..<3 {
                let v = Float(tokens[c]) ?? 0
                guard v.isFinite else { throw ParseError.nonFinite }
                values[cursor + c] = v
            }
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
        let b01 = blend.isFinite ? Float(min(max(blend, 0), 1)) : 1
        let denom = Float(n - 1)
        // Defense in depth — `parse` already rejects non-finite rows, but
        // a NaN reaching `UInt8(_:)` traps the process, so no value
        // gets there unguarded (a table built another way, or a
        // non-finite blend, lands on the identity/0 instead).
        func byte(_ v: Float) -> UInt8 {
            guard v.isFinite else { return 0 }
            return UInt8((min(max(v, 0), 1) * 255).rounded())
        }
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
            bytes[pixel] = byte(vr)
            bytes[pixel + 1] = byte(vg)
            bytes[pixel + 2] = byte(vb)
            bytes[pixel + 3] = 255
        }
        return Data(bytes)
    }

    /// The strip as a `CGImage` for the resolve pass's LUT sampler —
    /// `N*N` × `N` RGBA8, provider-referenced so the image owns its
    /// bytes (no context copy needed for a static table). Tagged
    /// linear so SceneKit uploads the bytes as they are: the table
    /// holds encoded colours and the pass does the encoding itself.
    func stripImage(blend: Double = 1.0) -> CGImage? {
        let bytes = stripBytes(blend: blend)
        let n = size
        guard let provider = CGDataProvider(data: bytes as CFData)
        else { return nil }
        return CGImage(
            width: n * n, height: n,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: n * n * 4,
            space: CGColorSpace(name: CGColorSpace.linearSRGB)
                ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil, shouldInterpolate: true,
            intent: .defaultIntent)
    }
}
