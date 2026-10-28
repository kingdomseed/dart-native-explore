import Foundation
import Metal
import OSLog
import SceneKit
import simd

// Throwaway instrumentation. Remove this file and the two host hooks together.
final class SpriteBlendProbe {
    private weak var lastFixture: SCNNode?
    private weak var lastScene: SCNScene?
    private let logger = Logger(subsystem: "com.jasonholtdigital.dart3d",
                                category: "SpriteBlendProbe")
    private var captures: [Capture] = []
    private let size = 64
    private let rowBytes = 512
    private let seed = [0.02, 0.03, 0.04, 0.25]
    private let finalOutput = """
    _output.color = float4(c.rgb * c.a,
        c.a * (1.0 - d3SpriteAdditive));
    """

    private struct Candidate {
        let name: String
        let blend: SCNBlendMode
        let output: String
        var writeMask: SCNColorMask = .all
    }

    // Retained by the host until after every command buffer has completed.
    private struct Capture {
        let scene: SCNScene
        let renderer: SCNRenderer
        let color: MTLTexture
        let depth: MTLTexture
        let buffer: MTLBuffer
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    func runOnce(scene: SCNScene, camera: SCNNode?, device: MTLDevice?) {
        guard let fixture = scene.rootNode.childNode(
            withName: "u3.sprite.untextured", recursively: true),
              lastFixture !== fixture || lastScene !== scene else { return }
        lastFixture = fixture
        lastScene = scene
        captures = []
        let id = UUID().uuidString
        var report: [String: Any] = [
            "id": id, "fixture": "u3.sprite.untextured",
            "seedPremultipliedRGBA": seed,
            "target": "rgba16Float, 64x64, private, single sample",
            "depthStencil": "depth32Float_stencil8, private",
            "readback": "private texture blit to shared buffer, 512 bytes per row",
            "interpretation": "Raw GPU floats. No runtime or parity PASS is assigned.",
        ]
        var results: [[String: Any]] = []
        do {
            guard let device, let queue = device.makeCommandQueue(),
                  let geometry = fixture.geometry,
                  geometry.materials.count == 1,
                  let material = geometry.firstMaterial,
                  material.name == "d3.sprite",
                  let sourceCamera = camera?.camera,
                  let modifiers = material.shaderModifiers,
                  let fragment = modifiers[.fragment],
                  let geometryModifier = modifiers[.geometry],
                  geometryModifier.contains("out.d3SpriteColor = _geometry.color;"),
                  fragment.components(separatedBy: finalOutput).count == 2
            else { throw Failure("Missing realized sprite, camera, or exact production output statement. No approximation rendered.") }
            guard let tint = material.value(forKey: "d3SpriteTint") as? NSValue,
                  let additive = material.value(forKey: "d3SpriteAdditive") as? NSNumber
            else { throw Failure("Missing production KVC uniforms.") }
            let t = tint.scnVector4Value
            let tintArray = [Double(t.x), Double(t.y), Double(t.z), Double(t.w)]
            let vertices = try vectors(geometry, .vertex)
            let colors = try vectors(geometry, .color)
            report["sourceMaterial"] = flags(material)
            report["uniforms"] = ["d3SpriteTint": tintArray,
                                   "d3SpriteAdditive": additive.doubleValue]
            report["cpuVertices"] = vertices
            report["cpuGeometryColors"] = colors
            report["productionModifiers"] = ["geometry": geometryModifier,
                                               "fragment": fragment]
            guard vertices.count == 4, vertices.allSatisfy({ $0.count == 3 }),
                  colors.count == 4, colors.allSatisfy({ $0 == [1, 1, 1, 1] }),
                  zip(tintArray, [0.2, 0.6, 0.9, 0.5]).allSatisfy({ abs($0 - $1) < 0.0001 })
            else { throw Failure("Fixture no longer has the required quad, white vertices and tint (0.2,0.6,0.9,0.5).") }

            let candidates = [
                Candidate(name: "alpha_premult_coverage", blend: .alpha,
                          output: "_output.color = float4(c.rgb * c.a, c.a);"),
                Candidate(name: "alpha_premult_zero", blend: .alpha,
                          output: "_output.color = float4(c.rgb * c.a, 0.0);"),
                Candidate(name: "add_premult_zero", blend: .add,
                          output: "_output.color = float4(c.rgb * c.a, 0.0);"),
                Candidate(name: "add_straight_coverage", blend: .add,
                          output: "_output.color = float4(c.rgb, c.a);"),
                Candidate(name: "add_premult_one", blend: .add,
                          output: "_output.color = float4(c.rgb * c.a, 1.0);"),
                Candidate(name: "add_premult_coverage", blend: .add,
                          output: "_output.color = float4(c.rgb * c.a, c.a);"),
                Candidate(name: "add_straight_coverage_rgb_only", blend: .add,
                          output: "_output.color = float4(c.rgb, c.a);",
                          writeMask: [.red, .green, .blue]),
                Candidate(name: "add_premult_one_rgb_only", blend: .add,
                          output: "_output.color = float4(c.rgb * c.a, 1.0);",
                          writeMask: [.red, .green, .blue]),
                Candidate(name: "add_premult_coverage_rgb_only", blend: .add,
                          output: "_output.color = float4(c.rgb * c.a, c.a);",
                          writeMask: [.red, .green, .blue]),
            ]
            // Separate scenes prevent cached material state or delayed encodes
            // from observing the next candidate's output statement.
            for index in 0..<(candidates.count + 2) {
                let candidate = index >= 2 ? candidates[index - 2] : nil
                let name = candidate?.name ?? (index == 0 ? "clear_only" : "empty_scene_load")
                let privateScene = SCNScene()
                privateScene.background.contents = nil
                let cameraNode = SCNNode()
                cameraNode.camera = sourceCamera.copy() as? SCNCamera
                privateScene.rootNode.addChildNode(cameraNode)
                guard let privateCamera = cameraNode.camera else {
                    throw Failure("Camera copy failed.")
                }
                // The copied camera is attached to its own scene before posing.
                privateCamera.usesOrthographicProjection = true
                privateCamera.projectionDirection = .vertical
                privateCamera.automaticallyAdjustsZRange = false
                privateCamera.zNear = 0.1
                privateCamera.zFar = 10
                privateCamera.wantsHDR = false
                privateCamera.wantsExposureAdaptation = false
                privateCamera.exposureOffset = 0
                privateCamera.whitePoint = 1
                privateCamera.bloomIntensity = 0
                privateCamera.vignettingIntensity = 0
                privateCamera.colorFringeIntensity = 0
                privateCamera.wantsDepthOfField = false
                privateCamera.categoryBitMask = Int.max
                let points = vertices.map { SIMD3<Float>(Float($0[0]), Float($0[1]), Float($0[2])) }
                let right = simd_normalize(points[1] - points[0])
                let up = simd_normalize(points[2] - points[0])
                let normal = simd_normalize(simd_cross(right, up))
                let center = points.reduce(.zero, +) / 4
                let position = center + normal * 3
                cameraNode.simdTransform = simd_float4x4(
                    SIMD4<Float>(right, 0), SIMD4<Float>(up, 0),
                    SIMD4<Float>(normal, 0), SIMD4<Float>(position, 1))
                privateCamera.orthographicScale = Double(max(
                    simd_length(points[1] - points[0]),
                    simd_length(points[2] - points[0]))) * 0.8

                var record: [String: Any] = ["case": name,
                    "camera": ["orthographicScale": privateCamera.orthographicScale,
                               "zNear": privateCamera.zNear, "zFar": privateCamera.zFar,
                               "position": [position.x, position.y, position.z],
                               "right": [right.x, right.y, right.z],
                               "up": [up.x, up.y, up.z],
                               "hdr": privateCamera.wantsHDR,
                               "exposureOffset": privateCamera.exposureOffset,
                               "whitePoint": privateCamera.whitePoint]]
                if let candidate {
                    let copiedGeometry = geometry.copy() as! SCNGeometry
                    let copiedMaterial = material.copy() as! SCNMaterial
                    // SceneKit's NSCopying API does not specify custom KVC key
                    // preservation. Copy both real shader arguments explicitly.
                    copiedMaterial.setValue(tint.copy(), forKey: "d3SpriteTint")
                    copiedMaterial.setValue(additive.copy(), forKey: "d3SpriteAdditive")
                    var copiedModifiers = modifiers
                    copiedModifiers[.fragment] = fragment.replacingOccurrences(
                        of: finalOutput, with: candidate.output)
                    copiedMaterial.shaderModifiers = copiedModifiers
                    copiedMaterial.blendMode = candidate.blend
                    copiedMaterial.colorBufferWriteMask = candidate.writeMask
                    copiedGeometry.materials = [copiedMaterial]
                    let quad = SCNNode(geometry: copiedGeometry)
                    privateScene.rootNode.addChildNode(quad)
                    record["material"] = flags(copiedMaterial)
                    record["outputStatement"] = candidate.output
                    let copiedTint = (copiedMaterial.value(forKey: "d3SpriteTint") as! NSValue).scnVector4Value
                    record["uniforms"] = [
                        "d3SpriteTint": [Double(copiedTint.x), Double(copiedTint.y), Double(copiedTint.z), Double(copiedTint.w)],
                        "d3SpriteAdditive": (copiedMaterial.value(forKey: "d3SpriteAdditive") as! NSNumber).doubleValue,
                    ]
                }
                let renderer = SCNRenderer(device: device)
                renderer.scene = privateScene
                renderer.pointOfView = cameraNode
                renderer.autoenablesDefaultLighting = false
                renderer.isJitteringEnabled = false
                let colorDesc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .rgba16Float, width: size, height: size, mipmapped: false)
                colorDesc.storageMode = .private
                colorDesc.usage = .renderTarget
                let depthDesc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .depth32Float_stencil8, width: size, height: size, mipmapped: false)
                depthDesc.storageMode = .private
                depthDesc.usage = .renderTarget
                guard let color = device.makeTexture(descriptor: colorDesc),
                      let depth = device.makeTexture(descriptor: depthDesc),
                      let buffer = device.makeBuffer(length: rowBytes * size, options: .storageModeShared),
                      let command = queue.makeCommandBuffer()
                else { throw Failure("Metal target, readback buffer or command allocation failed.") }
                captures.append(Capture(scene: privateScene, renderer: renderer,
                                        color: color, depth: depth, buffer: buffer))
                command.label = "SpriteBlendProbe.\(name)"
                let clear = MTLRenderPassDescriptor()
                clear.colorAttachments[0].texture = color
                clear.colorAttachments[0].loadAction = .clear
                clear.colorAttachments[0].storeAction = .store
                clear.colorAttachments[0].clearColor = MTLClearColor(
                    red: seed[0], green: seed[1], blue: seed[2], alpha: seed[3])
                guard let encoder = command.makeRenderCommandEncoder(descriptor: clear) else {
                    throw Failure("Clear/store encoder creation failed.")
                }
                encoder.endEncoding()
                if index != 0 {
                    let pass = MTLRenderPassDescriptor()
                    pass.colorAttachments[0].texture = color
                    pass.colorAttachments[0].loadAction = .load
                    pass.colorAttachments[0].storeAction = .store
                    pass.depthAttachment.texture = depth
                    pass.depthAttachment.loadAction = .clear
                    pass.depthAttachment.clearDepth = 1
                    pass.depthAttachment.storeAction = .dontCare
                    pass.stencilAttachment.texture = depth
                    pass.stencilAttachment.loadAction = .clear
                    pass.stencilAttachment.clearStencil = 0
                    pass.stencilAttachment.storeAction = .dontCare
                    renderer.render(withViewport: CGRect(x: 0, y: 0, width: size, height: size),
                                    commandBuffer: command, passDescriptor: pass)
                }
                guard let blit = command.makeBlitCommandEncoder() else {
                    throw Failure("Readback blit encoder creation failed.")
                }
                blit.copy(from: color, sourceSlice: 0, sourceLevel: 0,
                          sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                          sourceSize: MTLSize(width: size, height: size, depth: 1),
                          to: buffer, destinationOffset: 0,
                          destinationBytesPerRow: rowBytes,
                          destinationBytesPerImage: rowBytes * size)
                blit.endEncoding()
                command.commit()
                // Deliberately synchronous diagnostic only. No resources are
                // reused, mutated or released while a command is in flight.
                command.waitUntilCompleted()
                record["commandStatus"] = command.status.rawValue
                record["gpuError"] = command.error.map { String(describing: $0) } ?? NSNull()
                record["rendererFormats"] = ["color": renderer.colorPixelFormat.rawValue,
                    "depth": renderer.depthPixelFormat.rawValue,
                    "stencil": renderer.stencilPixelFormat.rawValue]
                guard command.status == .completed else {
                    results.append(record)
                    throw Failure("GPU command did not complete for \(name): \(String(describing: command.error))")
                }
                func patch(_ x0: Int, _ y0: Int) -> [[Double]] {
                    (y0..<(y0 + 3)).flatMap { y in
                        (x0..<(x0 + 3)).map { x in
                            (0..<4).map { channel in
                                let bits = buffer.contents().load(
                                    fromByteOffset: y * rowBytes + x * 8 + channel * 2,
                                    as: UInt16.self)
                                return Double(Float16(bitPattern: bits))
                            }
                        }
                    }
                }
                let centerPatch = patch(31, 31)
                let outerPatch = patch(3, 3)
                record["centerPatchRGBA"] = centerPatch
                record["outerPatchRGBA"] = outerPatch
                results.append(record)
                logger.notice("SpriteBlendProbe \(name, privacy: .public) center=\(String(describing: centerPatch[4]), privacy: .public) outer=\(String(describing: outerPatch[4]), privacy: .public) gpu=completed")
            }
            let baseline = (results[1]["centerPatchRGBA"] as! [[Double]])[4]
            let retained = abs(baseline[3] - seed[3]) < 0.002
                && baseline[3] > 0 && baseline[3] < 1
            report["destinationAlphaRetained"] = retained
            report["observedEmptyBaselineRGBA"] = baseline
            report["referenceFormulas"] = [
                "D": "Measured empty_scene_load center RGBA, not the requested clear.",
                "S": "Fixture straight RGB (0.2,0.6,0.9), coverage a=0.5, P=S*a.",
                "alphaControl": "RGB=P+(1-a)*D.rgb; alpha=a+(1-a)*D.a.",
                "desiredAdditive": "RGB=P+D.rgb; alpha=D.a.",
                "addHypotheses": "Compare each actual output X,q against RGB=X+D.rgb and RGB=X*q+D.rgb. Alpha may preserve D.a or accumulate q. No SDK blend-factor assumption is made.",
            ]
            report["referenceRGBAFromObservedBaseline"] = [
                "alphaControl": [0.1 + 0.5 * baseline[0],
                                 0.3 + 0.5 * baseline[1],
                                 0.45 + 0.5 * baseline[2],
                                 0.5 + 0.5 * baseline[3]],
                "desiredAdditive": [0.1 + baseline[0], 0.3 + baseline[1],
                                    0.45 + baseline[2], baseline[3]],
            ]
            report["status"] = retained ? "READBACK_RECORDED_REQUIRES_PARENT_INTERPRETATION"
                : "BLOCKED_SCENEKIT_DID_NOT_RETAIN_SEEDED_DESTINATION_ALPHA"
        } catch {
            report["status"] = "BLOCKED"
            report["error"] = String(describing: error)
            logger.error("SpriteBlendProbe BLOCKED \(String(describing: error), privacy: .public)")
        }
        report["results"] = results
        do {
            let directory = FileManager.default.urls(for: .cachesDirectory,
                in: .userDomainMask)[0].appendingPathComponent("SpriteBlendProbe", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let path = directory.appendingPathComponent("\(id).json")
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: path, options: .atomic)
            logger.notice("SpriteBlendProbe file=\(path.path, privacy: .public) status=\(String(describing: report["status"]!), privacy: .public)")
        } catch {
            logger.error("SpriteBlendProbe JSON WRITE FAILED \(String(describing: error), privacy: .public)")
        }
    }

    private func flags(_ material: SCNMaterial) -> [String: Any] {
        ["blendModeRaw": material.blendMode.rawValue,
         "colorWriteMaskRaw": material.colorBufferWriteMask.rawValue,
         "writesAlpha": material.colorBufferWriteMask.contains(.alpha),
         "readsDepth": material.readsFromDepthBuffer,
         "writesDepth": material.writesToDepthBuffer,
         "doubleSided": material.isDoubleSided,
         "transparency": material.transparency,
         "transparencyModeRaw": material.transparencyMode.rawValue,
         "lightingModel": material.lightingModel.rawValue,
         "diffuseIntensity": material.diffuse.intensity,
         "diffuseContents": String(describing: material.diffuse.contents)]
    }

    private func vectors(_ geometry: SCNGeometry, _ semantic: SCNGeometrySource.Semantic) throws -> [[Double]] {
        guard let source = geometry.sources(for: semantic).first,
              source.usesFloatComponents, source.bytesPerComponent == 4 else {
            throw Failure("Expected realized float32 \(semantic.rawValue) geometry source.")
        }
        return source.data.withUnsafeBytes { bytes in
            (0..<source.vectorCount).map { vertex in
                (0..<source.componentsPerVector).map { component in
                    Double(bytes.loadUnaligned(fromByteOffset: source.dataOffset
                        + vertex * source.dataStride + component * 4, as: Float.self))
                }
            }
        }
    }
}
