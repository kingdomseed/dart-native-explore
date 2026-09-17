import Foundation
import SceneKit
import simd

/// Wire helpers for the dart3d protocol — little-endian readers, the
/// Crockford base32 `LocalId` token codec, and the `.fscene` → SceneKit
/// coordinate conversion.
///
/// `.fscene` is left-handed, +Y up, +Z forward (specs.dart). SceneKit is
/// right-handed, camera looks down −Z. Conversion is a z-mirror baked in
/// here — positions negate z, quaternions conjugate `(x,y,z,w) →
/// (−x,−y,z,w)`, matrices get `S·M·S` with `S = diag(1,1,−1,1)`. Mirroring
/// flips triangle winding, so payload-backed index buffers reverse each
/// triangle on decode (phase 5); procedural SceneKit primitives are
/// authored right-handed already and need nothing.
enum D3Wire {

    // MARK: - LocalId (8 raw bytes: session u32 LE + index u32 LE)

    /// Combines the two u32 halves into one dict key. Same function for
    /// binary-path ids and decoded tokens, so both address spaces match.
    @inline(__always)
    static func idKey(session: UInt32, index: UInt32) -> UInt64 {
        (UInt64(session) << 32) | UInt64(index)
    }

    /// Reads an 8-byte wire id (little-endian halves) at `offset`.
    static func readLocalId(_ d: Data, _ offset: Int) -> UInt64 {
        let session = d.subdata(in: offset..<offset + 4).withUnsafeBytes {
            $0.load(as: UInt32.self).littleEndian
        }
        let index = d.subdata(in: offset + 4..<offset + 8).withUnsafeBytes {
            $0.load(as: UInt32.self).littleEndian
        }
        return idKey(session: session, index: index)
    }

    /// Decodes an `.fscene` id token to the same 64-bit key. Tokens are
    /// Crockford base32 of the 8 big-endian id bytes, optionally carrying
    /// a readability prefix (`geo:ABC…` — everything through the last
    /// colon is stripped, matching `LocalId.parse`).
    static func localIdKey(_ token: String) -> UInt64? {
        var t = token
        if let colon = t.lastIndex(of: ":") { t = String(t[t.index(after: colon)...]) }
        let bytes = base32Decode(t)
        guard bytes.count == 8 else { return nil }
        let session = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16
            | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        let index = UInt32(bytes[4]) << 24 | UInt32(bytes[5]) << 16
            | UInt32(bytes[6]) << 8 | UInt32(bytes[7])
        return idKey(session: session, index: index)
    }

    /// Inverse of `localIdKey`: Crockford base32 of the 8 big-endian
    /// id bytes — 12 full 5-bit groups cover bits 63…4, the last
    /// symbol carries the low nibble left-shifted one (the decoder
    /// drops the trailing sub-byte bit). Used by realizer-minted wire
    /// dicts (W12 component joints) that need node-ref tokens.
    static func localIdToken(_ key: UInt64) -> String {
        var chars = [UInt8]()
        chars.reserveCapacity(13)
        var shift = 59
        while shift >= 0 {
            chars.append(base32Alphabet[Int((key >> shift) & 0x1F)])
            shift -= 5
        }
        chars.append(base32Alphabet[Int((key & 0xF) << 1)])
        return String(bytes: chars, encoding: .utf8) ?? ""
    }

    private static let base32Alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ".utf8)

    /// Crockford base32 decode, most-significant bit first; mirrors
    /// `decodeBase32` in package:scene (case-insensitive; I,L→1; O→0;
    /// trailing sub-byte bits dropped). Returns nil on an invalid char.
    static func base32Decode(_ token: String) -> [UInt8] {
        var out: [UInt8] = []
        var buffer = 0
        var bits = 0
        for var c in token.utf8 {
            if c >= 0x61 && c <= 0x7A { c &-= 0x20 }          // a-z -> A-Z
            if c == 0x49 || c == 0x4C { c = 0x31 }          // I, L -> 1
            if c == 0x4F { c = 0x30 }                       // O -> 0
            guard let idx = base32Alphabet.firstIndex(of: c) else { return [] }
            buffer = (buffer << 5) | idx
            bits += 5
            if bits >= 8 {
                bits -= 8
                out.append(UInt8((buffer >> bits) & 0xFF))
                buffer &= (1 << bits) - 1
            }
        }
        return out
    }

    // MARK: - Little-endian readers

    static func u32LE(_ d: Data, _ offset: Int) -> UInt32 {
        d.subdata(in: offset..<offset + 4).withUnsafeBytes {
            $0.load(as: UInt32.self).littleEndian
        }
    }

    static func f32LE(_ d: Data, _ offset: Int) -> Float {
        Float(bitPattern: u32LE(d, offset))
    }

    // MARK: - LH → RH coordinate conversion (z-mirror)

    static func position(_ t: [Double]) -> SCNVector3 {
        SCNVector3(Float(t[0]), Float(t[1]), Float(-t[2]))
    }

    static func quaternion(_ r: [Double]) -> SCNQuaternion {
        SCNQuaternion(Float(-r[0]), Float(-r[1]), Float(r[2]), Float(r[3]))
    }

    static func scale(_ s: [Double]) -> SCNVector3 {
        SCNVector3(Float(s[0]), Float(s[1]), Float(s[2]))
    }

    /// `S·M·S` with `S = diag(1,1,−1,1)` — negates every element whose
    /// row or column (but not both) is the z axis. Input is the
    /// column-major 16-element `Matrix4` storage.
    static func matrix(_ m: [Double]) -> SCNMatrix4 {
        var f = m.map(Float.init)
        // Element m[i][j] lives at f[j*4 + i] (column-major).
        for j in 0..<4 {
            for i in 0..<4 {
                if (i == 2) != (j == 2) { f[j * 4 + i] = -f[j * 4 + i] }
            }
        }
        return SCNMatrix4(
            m11: f[0], m12: f[1], m13: f[2], m14: f[3],
            m21: f[4], m22: f[5], m23: f[6], m24: f[7],
            m31: f[8], m32: f[9], m33: f[10], m34: f[11],
            m41: f[12], m42: f[13], m43: f[14], m44: f[15]
        )
    }
}
