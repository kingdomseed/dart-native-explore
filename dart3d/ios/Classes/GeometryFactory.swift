import Foundation
import SceneKit
import simd

/// W26 procedural geometry — the expanded `d3:procMesh`/`d3:instances`
/// vocabulary, realized as CPU-built `SCNGeometry`. Mirrors
/// `MeshFactory.kt` (same generators, same parameter names) and
/// `proc.dart`'s `build*` functions, so all three produce equivalent
/// meshes. All output is native SceneKit space — wire point lists are
/// z-mirrored by the decoders before they reach these functions.
enum GeometryFactory {

    /// CPU mesh parts — the baking path transforms these per instance.
    /// `tangents` are the (xyz, w) stream — w is the bitangent
    /// handedness like the wire's `tangent4`; `uv1s` carries the
    /// second texcoord channel (procedural verts emit (0,0), matching
    /// the zero-filled tail of Android's 15-float record).
    struct MeshParts {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var colors: [SIMD4<Float>] = []
        var tangents: [SIMD4<Float>] = []
        var uv1s: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        var vertexCount: Int { positions.count }
    }

    // MARK: - SCNGeometry assembly

    /// [stride] must be the ELEMENT stride of the source buffer —
    /// `[SIMD3<Float>]` is 16 B (padded), not 12. Passing the packed
    /// `components*4` reads a padding lane + shifted components for
    /// every vertex past index 0.
    private static func floatSource(_ values: UnsafeRawBufferPointer,
                                    _ semantic: SCNGeometrySource.Semantic,
                                    _ count: Int, _ components: Int,
                                    stride: Int? = nil)
        -> SCNGeometrySource
    {
        SCNGeometrySource(
            data: Data(bytes: values.baseAddress!,
                       count: values.count),
            semantic: semantic, vectorCount: count,
            usesFloatComponents: true,
            componentsPerVector: components,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: stride ?? components * MemoryLayout<Float>.size)
    }

    /// Builds an `SCNGeometry` from [parts] — vertex/normal/texcoord/
    /// color float sources plus a uint32 triangle element. The same
    /// sources the payload decoder emits, so materials bind
    /// identically on procedural and payload meshes.
    static func makeGeometry(_ parts: MeshParts) -> SCNGeometry {
        guard parts.vertexCount > 0 else { return SCNGeometry() }
        var sources = [SCNGeometrySource]()
        parts.positions.withUnsafeBufferPointer {
            sources.append(floatSource(
                UnsafeRawBufferPointer($0), .vertex,
                parts.vertexCount, 3,
                stride: MemoryLayout<SIMD3<Float>>.stride))
        }
        if parts.normals.count == parts.vertexCount {
            parts.normals.withUnsafeBufferPointer {
                sources.append(floatSource(
                    UnsafeRawBufferPointer($0), .normal,
                    parts.vertexCount, 3,
                    stride: MemoryLayout<SIMD3<Float>>.stride))
            }
        }
        if parts.uvs.count == parts.vertexCount {
            parts.uvs.withUnsafeBufferPointer {
                sources.append(floatSource(
                    UnsafeRawBufferPointer($0), .texcoord,
                    parts.vertexCount, 2))
            }
        }
        if parts.colors.count == parts.vertexCount {
            parts.colors.withUnsafeBufferPointer {
                sources.append(floatSource(
                    UnsafeRawBufferPointer($0), .color,
                    parts.vertexCount, 4))
            }
        }
        // Same source set the payload decoder emits: a complete
        // tangent stream lands as `.tangent`, a second texcoord source
        // carries uv1 (mappingChannel 1 indexes texcoord sources in
        // declaration order — uv0 must stay first).
        if parts.tangents.count == parts.vertexCount {
            parts.tangents.withUnsafeBufferPointer {
                sources.append(floatSource(
                    UnsafeRawBufferPointer($0), .tangent,
                    parts.vertexCount, 4))
            }
        }
        if parts.uv1s.count == parts.vertexCount {
            parts.uv1s.withUnsafeBufferPointer {
                sources.append(floatSource(
                    UnsafeRawBufferPointer($0), .texcoord,
                    parts.vertexCount, 2))
            }
        }
        var indices = parts.indices
        let indexData = indices.withUnsafeMutableBufferPointer {
            Data(bytes: $0.baseAddress!,
                 count: $0.count * MemoryLayout<UInt32>.size)
        }
        let element = SCNGeometryElement(
            data: indexData, primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<UInt32>.size)
        return SCNGeometry(sources: sources, elements: [element])
    }

    /// Reads back the CPU vertex data of an already-realized geometry
    /// — the `geometry`-ref instancing path bakes from whatever the
    /// resource decoded to (payload or procedural). Only `.triangles`
    /// elements and float sources are supported; anything else
    /// returns nil and the decoder falls back to a log line.
    static func extractParts(_ geometry: SCNGeometry) -> MeshParts? {
        var parts = MeshParts()
        for source in geometry.sources {
            let stride = max(source.dataStride, 1)
            let comps = source.componentsPerVector
            let bpc = source.bytesPerComponent
            guard source.vectorCount > 0,
                  source.dataOffset >= 0,
                  source.data.count >= source.dataOffset + stride * (source.vectorCount - 1) + comps * bpc
            else { return nil }
            func floatAt(_ v: Int, _ c: Int) -> Float {
                let off = source.dataOffset + v * stride + c * bpc
                if source.usesFloatComponents {
                    return source.data.subdata(in: off..<off + 4)
                        .withUnsafeBytes { $0.load(as: Float.self) }
                }
                // Normalize integer components to 0…1 like SceneKit
                // presents them to shaders.
                switch bpc {
                case 1:
                    return Float(source.data[off]) / 255
                case 2:
                    let u = source.data.subdata(in: off..<off + 2)
                        .withUnsafeBytes { $0.load(as: UInt16.self) }
                    return Float(u) / 65535
                default:
                    return 0
                }
            }
            switch source.semantic {
            case .vertex:
                parts.positions = (0..<source.vectorCount).map {
                    SIMD3(floatAt($0, 0), floatAt($0, 1), floatAt($0, 2))
                }
            case .normal:
                parts.normals = (0..<source.vectorCount).map {
                    SIMD3(floatAt($0, 0), floatAt($0, 1), floatAt($0, 2))
                }
            case .texcoord:
                if parts.uvs.isEmpty {
                    parts.uvs = (0..<source.vectorCount).map {
                        SIMD2(floatAt($0, 0), floatAt($0, 1))
                    }
                } else if parts.uv1s.isEmpty {
                    // Second texcoord source = uv1 (mappingChannel 1).
                    parts.uv1s = (0..<source.vectorCount).map {
                        SIMD2(floatAt($0, 0), floatAt($0, 1))
                    }
                }
            case .color:
                parts.colors = (0..<source.vectorCount).map {
                    SIMD4(floatAt($0, 0), floatAt($0, 1),
                          floatAt($0, 2), comps > 3 ? floatAt($0, 3) : 1)
                }
            case .tangent:
                parts.tangents = (0..<source.vectorCount).map {
                    SIMD4(floatAt($0, 0), floatAt($0, 1), floatAt($0, 2),
                          comps > 3 ? floatAt($0, 3) : 1)
                }
            default:
                continue
            }
        }
        guard let element = geometry.elements.first,
              element.primitiveType == .triangles,
              element.bytesPerIndex == 2 || element.bytesPerIndex == 4
        else { return nil }
        let indexCount = element.primitiveCount * 3
        parts.indices.reserveCapacity(indexCount)
        for i in 0..<indexCount {
            let off = i * element.bytesPerIndex
            if element.bytesPerIndex == 2 {
                let v = element.data.subdata(in: off..<off + 2)
                    .withUnsafeBytes { $0.load(as: UInt16.self) }
                parts.indices.append(UInt32(v))
            } else {
                let v = element.data.subdata(in: off..<off + 4)
                    .withUnsafeBytes { $0.load(as: UInt32.self) }
                parts.indices.append(v)
            }
        }
        guard parts.vertexCount > 0 else { return nil }
        if parts.normals.count != parts.vertexCount {
            parts.normals = [SIMD3<Float>](
                repeating: SIMD3(0, 0, 1), count: parts.vertexCount)
        }
        if parts.uvs.count != parts.vertexCount {
            parts.uvs = [SIMD2<Float>](
                repeating: .zero, count: parts.vertexCount)
        }
        if parts.colors.count != parts.vertexCount {
            parts.colors = [SIMD4<Float>](
                repeating: SIMD4(1, 1, 1, 1), count: parts.vertexCount)
        }
        return parts
    }

    // MARK: - Mesh accumulator

    /// A perpendicular tangent for [n] — the same axis-pick rule
    /// MeshFactory.ProcBuilder.emit synthesizes, so a vertex without
    /// wire tangent data carries an equivalent w=+1 frame on both
    /// platforms.
    private static func synthesizedTangent(_ n: SIMD3<Float>)
        -> SIMD4<Float>
    {
        let axis: SIMD3<Float> = abs(n.x) < 0.9
            ? SIMD3(1, 0, 0) : SIMD3(0, 1, 0)
        let t = simd_cross(n, axis)
        let tn = simd_length_squared(t) > 1e-12
            ? simd_normalize(t) : SIMD3<Float>(1, 0, 0)
        return SIMD4(tn, 1)
    }

    private struct ProcBuilder {
        var parts = MeshParts()
        var vertexCount: Int { parts.positions.count }

        /// Emits a vertex; a nil [tangent] synthesizes the same
        /// perpendicular frame MeshFactory picks, a nil [uv1]
        /// zero-fills the second texcoord channel.
        @discardableResult
        mutating func emit(_ p: SIMD3<Float>, _ n: SIMD3<Float>,
                           _ u: Float, _ v: Float,
                           _ color: SIMD4<Float> = SIMD4(1, 1, 1, 1),
                           tangent: SIMD4<Float>? = nil,
                           uv1: SIMD2<Float>? = nil) -> Int {
            let i = vertexCount
            parts.positions.append(p)
            parts.normals.append(n)
            parts.uvs.append(SIMD2(u, v))
            parts.colors.append(color)
            parts.tangents.append(
                tangent ?? GeometryFactory.synthesizedTangent(n))
            parts.uv1s.append(uv1 ?? .zero)
            return i
        }

        mutating func tri(_ a: Int, _ b: Int, _ c: Int) {
            parts.indices.append(contentsOf:
                [UInt32(a), UInt32(b), UInt32(c)])
        }

        mutating func quad(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
            tri(a, b, c); tri(b, d, c)
        }
    }

    // MARK: - Primitives

    /// A cylinder/cone along Y with optional end caps — mirrors
    /// proc.dart's buildCylinder (sloped side normals, apex-fan
    /// handling, flip-wound bottom cap).
    static func cylinder(
        bottomRadius: Float, topRadius: Float, height: Float,
        radialSegments: Int, heightSegments: Int,
        bottomCap: Bool, topCap: Bool
    ) -> MeshParts {
        var b = ProcBuilder()
        let slopeY = bottomRadius - topRadius
        let columns = radialSegments + 1
        for r in 0...heightSegments {
            let t = Float(r) / Float(heightSegments)
            let y = height / 2 - height * t
            let radius = topRadius + (bottomRadius - topRadius) * t
            for s in 0...radialSegments {
                let theta = Float(2 * Double.pi * Double(s) / Double(radialSegments))
                let c = cos(theta), sn = sin(theta)
                let n = simd_normalize(
                    SIMD3(height * c, slopeY, height * sn))
                b.emit(SIMD3(radius * c, y, radius * sn), n,
                       Float(s) / Float(radialSegments), t)
            }
        }
        for r in 0..<heightSegments {
            let topApex = r == 0 && topRadius == 0
            let bottomApex = r + 1 == heightSegments && bottomRadius == 0
            for s in 0..<radialSegments {
                let a = r * columns + s
                let bv = a + 1
                let c = a + columns
                let d = c + 1
                if !topApex { b.tri(a, bv, c) }
                if !bottomApex { b.tri(bv, d, c) }
            }
        }

        func addCap(_ y: Float, _ radius: Float, _ ny: Float, flip: Bool) {
            guard radius > 0 else { return }
            let n = SIMD3<Float>(0, ny, 0)
            let center = b.emit(SIMD3(0, y, 0), n, 0.5, 0.5)
            let rimBase = b.vertexCount
            for s in 0...radialSegments {
                let theta = Float(2 * Double.pi * Double(s) / Double(radialSegments))
                let c = cos(theta), sn = sin(theta)
                b.emit(SIMD3(radius * c, y, radius * sn), n,
                       0.5 + 0.5 * c, 0.5 + 0.5 * sn)
            }
            for s in 0..<radialSegments {
                let r0 = rimBase + s, r1 = rimBase + s + 1
                if flip { b.tri(center, r0, r1) }
                else { b.tri(center, r1, r0) }
            }
        }
        if bottomCap { addCap(-height / 2, bottomRadius, -1, flip: true) }
        if topCap { addCap(height / 2, topRadius, 1, flip: false) }
        return b.parts
    }

    /// A capsule along Y — hemisphere rings sharing the mid-section
    /// equators (proc.dart's buildCapsule).
    static func capsule(
        radius: Float, height: Float,
        radialSegments: Int, capRings: Int
    ) -> MeshParts {
        let halfH = height / 2
        var rings: [(posY: Float, posR: Float,
                     normY: Float, normR: Float)] = []
        for r in 0...capRings {
            let phi = Float(Double.pi / 2) * (Float(r) / Float(capRings))
            rings.append((halfH + radius * cos(phi),
                          radius * sin(phi), cos(phi), sin(phi)))
        }
        for r in 0...capRings {
            let phi = Float(Double.pi / 2) +
                Float(Double.pi / 2) * (Float(r) / Float(capRings))
            rings.append((-halfH + radius * cos(phi),
                          radius * sin(phi), cos(phi), sin(phi)))
        }
        var b = ProcBuilder()
        let columns = radialSegments + 1
        for (ri, ring) in rings.enumerated() {
            for s in 0...radialSegments {
                let theta = Float(2 * Double.pi * Double(s) / Double(radialSegments))
                let c = cos(theta), sn = sin(theta)
                b.emit(
                    SIMD3(ring.posR * c, ring.posY, ring.posR * sn),
                    SIMD3(ring.normR * c, ring.normY, ring.normR * sn),
                    Float(s) / Float(radialSegments),
                    Float(ri) / Float(rings.count - 1))
            }
        }
        for r in 0..<(rings.count - 1) {
            for s in 0..<radialSegments {
                let a = r * columns + s
                b.quad(a, a + 1, a + columns, a + columns + 1)
            }
        }
        return b.parts
    }

    /// A filled disc in the XZ plane facing +Y (proc.dart buildDisc).
    static func disc(radius: Float, segments: Int) -> MeshParts {
        var b = ProcBuilder()
        let n = SIMD3<Float>(0, 1, 0)
        let center = b.emit(.zero, n, 0.5, 0.5)
        let rimBase = b.vertexCount
        for s in 0...segments {
            let theta = Float(2 * Double.pi * Double(s) / Double(segments))
            let c = cos(theta), sn = sin(theta)
            b.emit(SIMD3(radius * c, 0, radius * sn), n,
                   0.5 + 0.5 * c, 0.5 + 0.5 * sn)
        }
        for s in 0..<segments {
            b.tri(center, rimBase + s + 1, rimBase + s)
        }
        return b.parts
    }

    /// An XZ grid plane facing +Y — proc.dart's buildPlane. Replaces
    /// the SCNPlane stand-in, whose XY/+Z orientation never matched
    /// the wire contract (`width` spans X, `depth` spans Z).
    static func plane(
        width: Float, depth: Float,
        segmentsX: Int, segmentsZ: Int
    ) -> MeshParts {
        var b = ProcBuilder()
        let n = SIMD3<Float>(0, 1, 0)
        // The UV-aligned frame: +X is the u-gradient; +Z is the
        // v-gradient, which is −(n×t) — the w<0 handedness marker
        // (MeshFactory.plane packs the same reflected frame).
        let tangent = SIMD4<Float>(1, 0, 0, -1)
        for z in 0...segmentsZ {
            for x in 0...segmentsX {
                b.emit(
                    SIMD3((Float(x) / Float(segmentsX) - 0.5) * width,
                          0,
                          (Float(z) / Float(segmentsZ) - 0.5) * depth),
                    n,
                    Float(x) / Float(segmentsX),
                    Float(z) / Float(segmentsZ),
                    tangent: tangent)
            }
        }
        let cols = segmentsX + 1
        for z in 0..<segmentsZ {
            for x in 0..<segmentsX {
                let a = z * cols + x
                b.quad(a, a + cols, a + 1, a + cols + 1)
            }
        }
        return b.parts
    }

    /// A UV sphere — proc.dart's buildSphere (rows run pole to pole,
    /// outward winding, `segments` around the equator, `rings` pole
    /// to pole). Honors the wire segment counts SCNSphere can't.
    static func sphere(
        radius: Float, segments: Int, rings: Int
    ) -> MeshParts {
        var b = ProcBuilder()
        let cols = segments + 1
        for r in 0...rings {
            let lat = Float.pi * Float(r) / Float(rings)
            let sinLat = sin(lat), cosLat = cos(lat)
            for s in 0...segments {
                let lon = Float(2 * Double.pi) * Float(s) / Float(segments)
                let n = SIMD3<Float>(
                    sinLat * cos(lon), cosLat, sinLat * sin(lon))
                // The analytic ∂pos/∂u tangent — MeshFactory.sphere
                // packs the same UV-aligned frame.
                b.emit(n * radius, n,
                       Float(s) / Float(segments), Float(r) / Float(rings),
                       tangent: SIMD4(-sin(lon), 0, cos(lon), 1))
            }
        }
        for r in 0..<rings {
            for s in 0..<segments {
                let a = r * cols + s
                b.quad(a, a + 1, a + cols, a + cols + 1)
            }
        }
        return b.parts
    }

    /// A torus around Y — proc.dart's buildTorus (`radialSegments`
    /// around the main ring, `tubularSegments` around the tube;
    /// SCNTorus takes the counts but the CPU port keeps vertex
    /// streams identical to Android's MeshFactory).
    static func torus(
        radius: Float, tubeRadius: Float,
        radialSegments: Int, tubularSegments: Int
    ) -> MeshParts {
        var b = ProcBuilder()
        let cols = tubularSegments + 1
        for i in 0...radialSegments {
            let u = Float(2 * Double.pi) * Float(i) / Float(radialSegments)
            let cu = cos(u), su = sin(u)
            for j in 0...tubularSegments {
                let v = Float(2 * Double.pi) * Float(j) / Float(tubularSegments)
                let cv = cos(v), sv = sin(v)
                let ringRadius = radius + tubeRadius * cv
                // The uv.x gradient runs around the tube — the
                // tangent is ∂pos/∂v (MeshFactory.torus packs the
                // same frame).
                b.emit(
                    SIMD3(ringRadius * cu, tubeRadius * sv,
                          ringRadius * su),
                    SIMD3(cv * cu, sv, cv * su),
                    Float(j) / Float(tubularSegments),
                    Float(i) / Float(radialSegments),
                    tangent: SIMD4(-sv * cu, cv, -sv * su, 1))
            }
        }
        for i in 0..<radialSegments {
            for j in 0..<tubularSegments {
                let a = i * cols + j
                b.quad(a, a + 1, a + cols, a + cols + 1)
            }
        }
        return b.parts
    }

    /// A box — 24 verts, four per face (proc.dart's buildCuboid).
    /// `debugColors` keys each vertex color to its corner sign bits,
    /// matching the Dart/MeshFactory debug mode.
    static func cuboid(
        extents: SIMD3<Float>, debugColors: Bool
    ) -> MeshParts {
        var b = ProcBuilder()
        let hx = extents.x / 2, hy = extents.y / 2, hz = extents.z / 2
        func color(_ v: SIMD3<Float>) -> SIMD4<Float> {
            debugColors
                ? SIMD4(v.x >= 0 ? 1 : 0, v.y >= 0 ? 1 : 0,
                        v.z >= 0 ? 1 : 0, 1)
                : SIMD4(1, 1, 1, 1)
        }
        func face(_ n: SIMD3<Float>, _ v0: SIMD3<Float>,
                  _ v1: SIMD3<Float>, _ v2: SIMD3<Float>,
                  _ v3: SIMD3<Float>) {
            let base = b.vertexCount
            b.emit(v0, n, 0, 1, color(v0))
            b.emit(v1, n, 1, 1, color(v1))
            b.emit(v2, n, 0, 0, color(v2))
            b.emit(v3, n, 1, 0, color(v3))
            b.quad(base, base + 1, base + 2, base + 3)
        }
        face(SIMD3(0, 0, 1),
             SIMD3(-hx, -hy, hz), SIMD3(hx, -hy, hz),
             SIMD3(-hx, hy, hz), SIMD3(hx, hy, hz))
        face(SIMD3(0, 0, -1),
             SIMD3(hx, -hy, -hz), SIMD3(-hx, -hy, -hz),
             SIMD3(hx, hy, -hz), SIMD3(-hx, hy, -hz))
        face(SIMD3(1, 0, 0),
             SIMD3(hx, -hy, hz), SIMD3(hx, -hy, -hz),
             SIMD3(hx, hy, hz), SIMD3(hx, hy, -hz))
        face(SIMD3(-1, 0, 0),
             SIMD3(-hx, -hy, -hz), SIMD3(-hx, -hy, hz),
             SIMD3(-hx, hy, -hz), SIMD3(-hx, hy, hz))
        face(SIMD3(0, 1, 0),
             SIMD3(-hx, hy, hz), SIMD3(hx, hy, hz),
             SIMD3(-hx, hy, -hz), SIMD3(hx, hy, -hz))
        face(SIMD3(0, -1, 0),
             SIMD3(-hx, -hy, -hz), SIMD3(hx, -hy, -hz),
             SIMD3(-hx, -hy, hz), SIMD3(hx, -hy, hz))
        return b.parts
    }

    /// A real subdivided icosahedron projected to `radius` — replaces
    /// the SCNSphere stand-in for `icosphere` (midpoint edge cache,
    /// spherical UVs, outward winding; proc.dart buildIcosphere).
    static func icosphere(radius: Float, subdivisions: Int) -> MeshParts {
        let t = Float((1 + sqrt(5.0)) / 2)
        var verts: [SIMD3<Float>] = [
            SIMD3(-1, t, 0), SIMD3(1, t, 0), SIMD3(-1, -t, 0), SIMD3(1, -t, 0),
            SIMD3(0, -1, t), SIMD3(0, 1, t), SIMD3(0, -1, -t), SIMD3(0, 1, -t),
            SIMD3(t, 0, -1), SIMD3(t, 0, 1), SIMD3(-t, 0, -1), SIMD3(-t, 0, 1),
        ]
        var faces: [[Int]] = [
            [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
            [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
            [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
        ]
        var midpointCache = [Int: Int]()
        func midpoint(_ a: Int, _ b: Int) -> Int {
            let key = a < b ? (a << 16) | b : (b << 16) | a
            if let cached = midpointCache[key] { return cached }
            let index = verts.count
            verts.append((verts[a] + verts[b]) * 0.5)
            midpointCache[key] = index
            return index
        }
        for _ in 0..<max(subdivisions, 0) {
            var next: [[Int]] = []
            next.reserveCapacity(faces.count * 4)
            for f in faces {
                let ab = midpoint(f[0], f[1])
                let bc = midpoint(f[1], f[2])
                let ca = midpoint(f[2], f[0])
                next.append([f[0], ab, ca])
                next.append([f[1], bc, ab])
                next.append([f[2], ca, bc])
                next.append([ab, bc, ca])
            }
            faces = next
        }
        var b = ProcBuilder()
        for v in verts {
            let n = simd_normalize(v)
            b.emit(n * radius, n,
                   Float(0.5 + atan2(Double(n.z), Double(n.x)) / (2 * Double.pi)),
                   Float(0.5 - asin(Double(
                        simd_clamp(n.y, -1, 1))) / Double.pi))
        }
        for f in faces { b.tri(f[0], f[1], f[2]) }
        return b.parts
    }

    // MARK: - Path evaluation (paths.dart port — tube/ribbon)

    private struct PathFrame {
        var position, tangent, normal, binormal: SIMD3<Float>
    }

    /// Arc-length-parameterized curve eval — the compact port of
    /// paths.dart's ScenePath bake (sampled positions/tangents,
    /// cumulative-length table, rotation-minimizing normals).
    private struct PathEval {
        let positionAt: (Float) -> SIMD3<Float>
        let tangentAt: (Float) -> SIMD3<Float>
        let params: [Float]
        let tangents: [SIMD3<Float>]
        let normals: [SIMD3<Float>]
        let cumulative: [Float]
        let length: Float

        init(positionAt: @escaping (Float) -> SIMD3<Float>,
             tangentAt: @escaping (Float) -> SIMD3<Float>,
             params: [Float]) {
            self.positionAt = positionAt
            self.tangentAt = tangentAt
            self.params = params
            let positions = params.map { positionAt($0) }
            tangents = params.map { tangentAt($0) }
            var cumulative = [Float](repeating: 0, count: params.count)
            for i in 1..<params.count {
                cumulative[i] = cumulative[i - 1] +
                    simd_length(positions[i] - positions[i - 1])
            }
            self.cumulative = cumulative
            length = cumulative.last ?? 0
            normals = PathEval.rotationMinimizingNormals(
                positions, tangents)
        }

        private static func perpendicular(
            _ direction: SIMD3<Float>
        ) -> SIMD3<Float> {
            let ax = abs(direction.x), ay = abs(direction.y),
                az = abs(direction.z)
            let axis: SIMD3<Float>
            if ax <= ay && ax <= az { axis = SIMD3(1, 0, 0) }
            else if ay <= az { axis = SIMD3(0, 1, 0) }
            else { axis = SIMD3(0, 0, 1) }
            let result = simd_cross(axis, direction)
            return simd_length_squared(result) < 1e-12
                ? SIMD3(0, 1, 0) : simd_normalize(result)
        }

        private static func rotationMinimizingNormals(
            _ positions: [SIMD3<Float>], _ tangents: [SIMD3<Float>]
        ) -> [SIMD3<Float>] {
            let count = positions.count
            var normals = [SIMD3<Float>](
                repeating: .zero, count: count)
            normals[0] = perpendicular(tangents[0])
            for i in 0..<count - 1 {
                var reference = normals[i]
                let v1 = positions[i + 1] - positions[i]
                let c1 = simd_dot(v1, v1)
                if c1 > 1e-12 {
                    let reflectedRef = reference -
                        v1 * (2 / c1 * simd_dot(v1, reference))
                    let reflectedTan = tangents[i] -
                        v1 * (2 / c1 * simd_dot(v1, tangents[i]))
                    let v2 = tangents[i + 1] - reflectedTan
                    let c2 = simd_dot(v2, v2)
                    reference = c2 > 1e-12
                        ? reflectedRef - v2 * (2 / c2 * simd_dot(v2, reflectedRef))
                        : reflectedRef
                }
                reference -= tangents[i + 1] *
                    simd_dot(reference, tangents[i + 1])
                normals[i + 1] = simd_length_squared(reference) < 1e-12
                    ? perpendicular(tangents[i + 1])
                    : simd_normalize(reference)
            }
            return normals
        }

        func parameterAtDistance(_ d: Float) -> Float {
            let total = length
            if total <= 0 { return 0 }
            let target = min(max(d, 0), total)
            var lo = 0, hi = cumulative.count - 1
            while lo + 1 < hi {
                let mid = (lo + hi) >> 1
                if cumulative[mid] <= target { lo = mid } else { hi = mid }
            }
            let segment = cumulative[hi] - cumulative[lo]
            let local = segment > 1e-12
                ? (target - cumulative[lo]) / segment : 0
            return params[lo] + (params[hi] - params[lo]) * local
        }

        func frameAtDistance(_ d: Float) -> PathFrame {
            let t = parameterAtDistance(d)
            var hi = 1
            while hi < params.count - 1 && params[hi] < t { hi += 1 }
            let lo = hi - 1
            let span = params[hi] - params[lo]
            let local = span > 1e-12 ? (t - params[lo]) / span : 0
            let position = positionAt(t)
            var tangent = tangentAt(t)
            if simd_length_squared(tangent) < 1e-12 {
                tangent = tangents[hi]
            }
            tangent = simd_normalize(tangent)
            var normal = normals[lo] * (1 - local) + normals[hi] * local
            normal -= tangent * simd_dot(normal, tangent)
            normal = simd_length_squared(normal) < 1e-12
                ? PathEval.perpendicular(tangent)
                : simd_normalize(normal)
            return PathFrame(
                position: position, tangent: tangent, normal: normal,
                binormal: simd_normalize(simd_cross(tangent, normal)))
        }

        func evenlySpacedFrames(_ stations: Int) -> [PathFrame] {
            (0..<stations).map { i in
                frameAtDistance(stations == 1
                    ? 0 : length * Float(i) / Float(stations - 1))
            }
        }
    }

    /// Uniform Catmull-Rom through [points] — paths.dart port;
    /// endpoints repeat so end segments interpolate cleanly.
    private static func catmullRomPath(
        _ points: [SIMD3<Float>], closed: Bool
    ) -> PathEval {
        let pts = closed ? points + [points[0]] : points
        func cp(_ i: Int) -> SIMD3<Float> {
            pts[min(max(i, 0), pts.count - 1)]
        }
        func segmentOf(_ t: Float) -> (Int, Float) {
            let segs = pts.count - 1
            let scaled = min(max(t, 0), 1) * Float(segs)
            var seg = Int(scaled)
            if seg >= segs { seg = segs - 1 }
            return (seg, scaled - Float(seg))
        }
        var params: [Float] = []
        let segs = pts.count - 1
        for s in 0..<segs {
            for k in 0..<24 {
                params.append(
                    (Float(s) + Float(k) / 24) / Float(segs))
            }
        }
        params.append(1)
        return PathEval(
            positionAt: { t in
                let (seg, s) = segmentOf(t)
                let p0 = cp(seg - 1), p1 = cp(seg)
                let p2 = cp(seg + 1), p3 = cp(seg + 2)
                let s2 = s * s, s3 = s2 * s
                return (p1 * 2 + (p2 - p0) * s +
                    (p0 * 2 - p1 * 5 + p2 * 4 - p3) * s2 +
                    (p1 * 3 - p0 - p2 * 3 + p3) * s3) * 0.5
            },
            tangentAt: { t in
                let (seg, s) = segmentOf(t)
                let p0 = cp(seg - 1), p1 = cp(seg)
                let p2 = cp(seg + 1), p3 = cp(seg + 2)
                let d = ((p2 - p0) +
                    (p0 * 2 - p1 * 5 + p2 * 4 - p3) * (2 * s) +
                    (p1 * 3 - p0 - p2 * 3 + p3) * (3 * s * s)) * 0.5
                return simd_length_squared(d) < 1e-12
                    ? SIMD3(1, 0, 0) : simd_normalize(d)
            },
            params: params)
    }

    private static func stitchRings(
        _ b: inout ProcBuilder, _ ringBases: [Int], _ ringSize: Int
    ) {
        for s in 0..<ringBases.count - 1 {
            let base = ringBases[s], nextBase = ringBases[s + 1]
            for j in 0..<ringSize - 1 {
                b.quad(base + j, base + j + 1,
                       nextBase + j, nextBase + j + 1)
            }
        }
    }

    /// A round cross-section swept along a Catmull-Rom path —
    /// proc.dart's buildTube. [points] are native-space.
    static func tube(
        _ points: [SIMD3<Float>], radius: Float, radialSegments: Int,
        stations: Int, caps: Bool, closed: Bool
    ) -> MeshParts {
        guard points.count >= 2 else { return MeshParts() }
        let path = catmullRomPath(points, closed: closed)
        let frames = path.evenlySpacedFrames(stations)
        let length = path.length
        var b = ProcBuilder()
        var ringBases = [Int]()
        for i in 0..<stations {
            let frame = frames[i]
            let v = length * Float(i) / Float(stations - 1)
            ringBases.append(b.vertexCount)
            for k in 0...radialSegments {
                let theta = Float(2 * Double.pi * Double(k) / Double(radialSegments))
                let radial = frame.normal * cos(theta) +
                    frame.binormal * sin(theta)
                b.emit(frame.position + radial * radius, radial,
                       Float(k) / Float(radialSegments), v)
            }
        }
        stitchRings(&b, ringBases, radialSegments + 1)
        if caps {
            tubeCap(&b, frames.first!, radius, radialSegments, atEnd: false)
            tubeCap(&b, frames.last!, radius, radialSegments, atEnd: true)
        }
        return b.parts
    }

    private static func tubeCap(
        _ b: inout ProcBuilder, _ frame: PathFrame,
        _ radius: Float, _ radialSegments: Int, atEnd: Bool
    ) {
        let normal = atEnd ? frame.tangent : -frame.tangent
        let center = b.emit(frame.position, normal, 0.5, 0.5)
        var ringIndices = [Int]()
        ringIndices.reserveCapacity(radialSegments)
        for k in 0..<radialSegments {
            let theta = Float(2 * Double.pi * Double(k) / Double(radialSegments))
            let radial = frame.normal * cos(theta) +
                frame.binormal * sin(theta)
            ringIndices.append(b.emit(
                frame.position + radial * radius, normal,
                0.5 + 0.5 * cos(theta), 0.5 + 0.5 * sin(theta)))
        }
        for k in 0..<radialSegments {
            let next = (k + 1) % radialSegments
            if atEnd { b.tri(center, ringIndices[k], ringIndices[next]) }
            else { b.tri(center, ringIndices[next], ringIndices[k]) }
        }
    }

    /// A flat strip swept along a Catmull-Rom path — proc.dart's
    /// buildRibbon ground alignment. [points] are native-space.
    static func ribbon(
        _ points: [SIMD3<Float>], width: Float, stations: Int,
        up: SIMD3<Float>, closed: Bool
    ) -> MeshParts {
        guard points.count >= 2 else { return MeshParts() }
        let path = catmullRomPath(points, closed: closed)
        let frames = path.evenlySpacedFrames(stations)
        let length = path.length
        let half = width / 2
        var b = ProcBuilder()
        var ringBases = [Int]()
        for i in 0..<stations {
            let frame = frames[i]
            var sideways = simd_cross(frame.tangent, up)
            if simd_length_squared(sideways) < 1e-12 {
                sideways = frame.binormal
            }
            let across = simd_normalize(sideways)
            let normal = simd_normalize(up)
            let v = stations == 1
                ? Float(0) : length * Float(i) / Float(stations - 1)
            ringBases.append(b.vertexCount)
            b.emit(frame.position - across * half, normal, 0, v)
            b.emit(frame.position + across * half, normal, 1, v)
        }
        stitchRings(&b, ringBases, 2)
        return b.parts
    }

    // MARK: - Camera-facing expansion (lines / billboards)

    /// One quad for the span a→c, expanded perpendicular to the
    /// segment direction and [viewDir] (the camera-forward hint);
    /// [wa]/[wb] are the half-width multipliers at each end.
    private static func emitLineQuad(
        _ b: inout ProcBuilder, _ a: SIMD3<Float>, _ c: SIMD3<Float>,
        _ wa: Float, _ wb: Float, _ viewDir: SIMD3<Float>,
        _ ca: SIMD4<Float>?, _ cb: SIMD4<Float>?
    ) {
        var d = c - a
        guard simd_length_squared(d) >= 1e-20 else { return }
        d = simd_normalize(d)
        var side = simd_cross(d, viewDir)
        if simd_length_squared(side) < 1e-12 {
            side = simd_cross(d, SIMD3(0, 1, 0))
        }
        if simd_length_squared(side) < 1e-12 { side = SIMD3(1, 0, 0) }
        side = simd_normalize(side)
        let sa = side * (wa / 2), sb = side * (wb / 2)
        let n = simd_normalize(simd_cross(d, side))
        let ra = ca ?? SIMD4<Float>(1, 1, 1, 1)
        let rb = cb ?? SIMD4<Float>(1, 1, 1, 1)
        // The tangent runs along the line — MeshFactory's
        // emitLineQuad packs the same frame.
        let tangent = SIMD4<Float>(d, 1)
        let v0 = b.emit(a - sa, n, 0, 0, ra, tangent: tangent)
        b.emit(c - sb, n, 1, 0, rb, tangent: tangent)
        b.emit(a + sa, n, 0, 1, ra, tangent: tangent)
        b.emit(c + sb, n, 1, 1, rb, tangent: tangent)
        b.quad(v0, v0 + 1, v0 + 2, v0 + 3)
    }

    /// Solid camera-facing polyline — one quad per segment pair.
    static func polyline(
        _ points: [SIMD3<Float>], width: Float, viewDir: SIMD3<Float>,
        colors: [SIMD4<Float>]?, widths: [Float]?, closed: Bool
    ) -> MeshParts {
        guard points.count >= 2 else { return MeshParts() }
        let pts = closed ? points + [points[0]] : points
        var b = ProcBuilder()
        for i in 0..<pts.count - 1 {
            emitLineQuad(&b, pts[i], pts[i + 1],
                         i < (widths?.count ?? 0) ? widths![i] : width,
                         i + 1 < (widths?.count ?? 0) ? widths![i + 1] : width,
                         viewDir,
                         i < (colors?.count ?? 0) ? colors?[i] : nil,
                         i + 1 < (colors?.count ?? 0) ? colors?[i + 1] : nil)
        }
        return b.parts
    }

    /// Dashed polyline — walks each segment's arc length with a
    /// global (on, off) cursor, one quad per kept span
    /// (proc.dart's _expandDashed).
    static func dashedPolyline(
        _ points: [SIMD3<Float>], width: Float, viewDir: SIMD3<Float>,
        onLen: Float, offLen: Float,
        colors: [SIMD4<Float>]?, widths: [Float]?, closed: Bool
    ) -> MeshParts {
        guard points.count >= 2 else { return MeshParts() }
        let pts = closed ? points + [points[0]] : points
        var b = ProcBuilder()
        var distance = Float(0)
        var on = true
        var nextBoundary = onLen
        func lerpColor(_ ia: Int, _ ib: Int, _ t: Float) -> SIMD4<Float>? {
            guard let colors, ia < colors.count else { return nil }
            let ca = colors[ia]
            guard ib < colors.count else { return ca }
            return ca + (colors[ib] - ca) * t
        }
        for i in 0..<pts.count - 1 {
            let a = pts[i], c = pts[i + 1]
            let dir = c - a
            let segLen = simd_length(dir)
            guard segLen >= 1e-12 else { continue }
            var t0 = Float(0)
            while t0 < 1 - 1e-9 {
                let remain = distance + segLen - nextBoundary
                let t1 = remain > 0
                    ? (nextBoundary - distance) / segLen : 1
                if on {
                    let w0 = i < (widths?.count ?? 0) ? widths![i] : width
                    let w1 = i + 1 < (widths?.count ?? 0)
                        ? widths![i + 1] : width
                    emitLineQuad(&b, a + dir * t0, a + dir * t1,
                                 w0 + (w1 - w0) * t0, w0 + (w1 - w0) * t1,
                                 viewDir, lerpColor(i, i + 1, t0),
                                 lerpColor(i, i + 1, t1))
                }
                t0 = t1
                if distance + t0 * segLen >= nextBoundary - 1e-9 {
                    on = !on
                    nextBoundary += on ? onLen : offLen
                }
            }
            distance += segLen
        }
        return b.parts
    }

    /// Independent camera-facing quads, one per point pair.
    static func lineSegments(
        _ points: [SIMD3<Float>], width: Float, viewDir: SIMD3<Float>,
        colors: [SIMD4<Float>]?
    ) -> MeshParts {
        var b = ProcBuilder()
        var i = 0
        while i + 1 < points.count {
            emitLineQuad(&b, points[i], points[i + 1], width, width,
                         viewDir,
                         i < (colors?.count ?? 0) ? colors?[i] : nil,
                         i + 1 < (colors?.count ?? 0) ? colors?[i + 1] : nil)
            i += 2
        }
        return b.parts
    }

    /// The billboard facing basis for [facing] — `spherical` aims the
    /// quad's normal at the node-local camera position and keeps the
    /// camera's up vector; `axisY` rotates about node-local +Y only
    /// (cylindrical); `screen` (and any degenerate aim) keeps the
    /// camera plane basis [camRight]/[camUp].
    static func facingBasis(
        _ facing: String, center: SIMD3<Float>, camPos: SIMD3<Float>,
        camRight: SIMD3<Float>, camUp: SIMD3<Float>
    ) -> (SIMD3<Float>, SIMD3<Float>) {
        switch facing {
        case "axisY":
            var n = camPos - center
            n.y = 0
            guard simd_length_squared(n) > 1e-12 else { break }
            n = simd_normalize(n)
            let up = SIMD3<Float>(0, 1, 0)
            return (simd_normalize(simd_cross(up, n)), up)
        case "spherical":
            let toCam = camPos - center
            guard simd_length_squared(toCam) > 1e-12 else { break }
            let n = simd_normalize(toCam)
            var right = simd_cross(camUp, n)
            guard simd_length_squared(right) > 1e-12 else { break }
            right = simd_normalize(right)
            return (right, simd_cross(n, right))
        default:
            break
        }
        return (camRight, camUp)
    }

    /// A camera-facing quad at the origin — [right]/[up] supply the
    /// facing basis (node-local at decode, camera-derived at reface).
    /// [facing] + [camPos] (node-local camera position) realize the
    /// `spherical`/`axisY` modes; `screen` keeps the passed basis.
    static func billboardQuad(
        sizeX: Float, sizeY: Float, rotation: Float,
        color: SIMD4<Float>, right: SIMD3<Float>, up: SIMD3<Float>,
        facing: String = "screen", camPos: SIMD3<Float> = .zero
    ) -> MeshParts {
        var r = right, u = up
        if facing != "screen" {
            (r, u) = facingBasis(facing, center: .zero, camPos: camPos,
                                 camRight: right, camUp: up)
        }
        let cosR = cos(rotation), sinR = sin(rotation)
        let n = simd_normalize(simd_cross(r, u))
        var b = ProcBuilder()
        for (dx, dy) in [(-0.5, -0.5), (0.5, -0.5),
                         (-0.5, 0.5), (0.5, 0.5)] as [(Float, Float)] {
            let rx = dx * cosR - dy * sinR
            let ry = dx * sinR + dy * cosR
            b.emit(r * (rx * sizeX) + u * (ry * sizeY), n,
                   dx + 0.5, dy + 0.5, color)
        }
        b.quad(0, 1, 2, 3)
        return b.parts
    }

    // MARK: - Instance baking (`d3:instances`)

    /// Bakes `matrices.count` transformed copies of [base] into one
    /// geometry — the iOS `d3:instances` realization: one node, one
    /// draw, per-instance colors stamped into the color stream.
    /// Matrices are native-space `simd_float4x4` (column-major);
    /// normals transform by the inverse-transpose upper 3×3, tangents
    /// transform by the matrix itself (re-orthogonalized against the
    /// new normal, bitangent handedness `w` flipping with the
    /// determinant), and uv0/color/uv1 pass through per vertex.
    static func bakeInstances(
        _ base: MeshParts, _ matrices: [simd_float4x4],
        colors: [SIMD4<Float>]?
    ) -> MeshParts {
        var b = ProcBuilder()
        let hasTangents = base.tangents.count == base.vertexCount
        let hasUv1 = base.uv1s.count == base.vertexCount
        for (i, m) in matrices.enumerated() {
            let c0 = m.columns.0, c1 = m.columns.1, c2 = m.columns.2
            let upper = simd_float3x3(
                SIMD3(c0.x, c0.y, c0.z),
                SIMD3(c1.x, c1.y, c1.z),
                SIMD3(c2.x, c2.y, c2.z))
            let normalM = simd_transpose(simd_inverse(upper))
            // A reflection flips the frame's handedness — the
            // bitangent sign channel follows the determinant.
            let flip: Float = simd_determinant(upper) < 0 ? -1 : 1
            let ic = i < (colors?.count ?? 0) ? colors?[i] : nil
            let base0 = b.vertexCount
            for v in 0..<base.vertexCount {
                let p = base.positions[v]
                let wp = m * SIMD4<Float>(p, 1)
                var n = normalM * base.normals[v]
                n = simd_length_squared(n) > 1e-20 &&
                    n.x.isFinite && n.y.isFinite && n.z.isFinite
                    ? simd_normalize(n) : base.normals[v]
                var tangent: SIMD4<Float>?
                if hasTangents {
                    let t4 = base.tangents[v]
                    var t = upper * SIMD3(t4.x, t4.y, t4.z)
                    // Re-orthogonalize against the transformed normal —
                    // a shearing/nonuniform matrix tilts t off the
                    // surface otherwise.
                    t -= n * simd_dot(n, t)
                    if simd_length_squared(t) > 1e-12,
                       t.x.isFinite, t.y.isFinite, t.z.isFinite {
                        tangent = SIMD4(simd_normalize(t), t4.w * flip)
                    }
                    // Degenerate/non-finite tangent → nil: emit
                    // synthesizes a fresh frame from the new normal.
                }
                b.emit(SIMD3(wp.x, wp.y, wp.z), n,
                       base.uvs[v].x, base.uvs[v].y,
                       (ic ?? SIMD4<Float>(1, 1, 1, 1)) * base.colors[v],
                       tangent: tangent,
                       uv1: hasUv1 ? base.uv1s[v] : nil)
            }
            for idx in base.indices {
                b.parts.indices.append(idx + UInt32(base0))
            }
        }
        return b.parts
    }

    /// One camera-facing quad per instance center — billboard mode of
    /// `d3:instances`; [right]/[up] re-face per frame. A non-`screen`
    /// [facing] computes the basis per center from the node-local
    /// camera position [camPos] (spherical quads aim individually).
    static func bakeBillboardInstances(
        _ centers: [SIMD3<Float>], sizeX: Float, sizeY: Float,
        rotation: Float, colors: [SIMD4<Float>]?,
        right: SIMD3<Float>, up: SIMD3<Float>,
        facing: String = "screen", camPos: SIMD3<Float> = .zero
    ) -> MeshParts {
        let cosR = cos(rotation), sinR = sin(rotation)
        var b = ProcBuilder()
        for (i, c) in centers.enumerated() {
            var r = right, u = up
            if facing != "screen" {
                (r, u) = facingBasis(facing, center: c, camPos: camPos,
                                     camRight: right, camUp: up)
            }
            let n = simd_normalize(simd_cross(r, u))
            let col = i < (colors?.count ?? 0)
                ? colors![i] : SIMD4<Float>(1, 1, 1, 1)
            let v0 = b.vertexCount
            for (dx, dy) in [(-0.5, -0.5), (0.5, -0.5),
                             (-0.5, 0.5), (0.5, 0.5)] as [(Float, Float)] {
                let rx = dx * cosR - dy * sinR
                let ry = dx * sinR + dy * cosR
                b.emit(c + r * (rx * sizeX) + u * (ry * sizeY), n,
                       dx + 0.5, dy + 0.5, col)
            }
            b.quad(v0, v0 + 1, v0 + 2, v0 + 3)
        }
        return b.parts
    }
}
