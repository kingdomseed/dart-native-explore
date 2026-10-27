import Foundation
import Metal
import SceneKit
import UIKit

struct ShadowCatcherConfiguration: Equatable {
    enum Mode: Equatable {
        case live
        case baked
    }

    let mode: Mode
    let softness: Double
}

final class ShadowCatcherMaterialBinding {
    weak var node: SCNNode?
    weak var geometry: SCNGeometry?
    var material: SCNMaterial
    let materialIndex: Int
    let isSnapshotClone: Bool

    init(node: SCNNode, geometry: SCNGeometry, material: SCNMaterial,
         materialIndex: Int, isSnapshotClone: Bool) {
        self.node = node
        self.geometry = geometry
        self.material = material
        self.materialIndex = materialIndex
        self.isSnapshotClone = isSnapshotClone
    }

    var isCurrentDraw: Bool {
        guard let node, let geometry,
              node.geometry === geometry,
              geometry.materials.indices.contains(materialIndex),
              geometry.materials[materialIndex] === material
        else { return false }
        return true
    }
}

final class BakedShadowCatcherRegistry {
    private struct Entry {
        var configuration: ShadowCatcherConfiguration
        var bindings: [ShadowCatcherMaterialBinding]
        var texture: MTLTexture?
        var region: SIMD4<Float>?
        var dirty = true
    }

    private static let geometryModifier = """
    #pragma arguments
    float4 d3CatcherRegion;
    #pragma body
    float2 d3CatcherPosition = _geometry.position.xz;
    _geometry.texcoords[0] = float2(
        1.0 - (d3CatcherPosition.x - d3CatcherRegion.x) * d3CatcherRegion.z,
        (d3CatcherRegion.y - d3CatcherPosition.y) * d3CatcherRegion.w);
    """

    private static let blurSource = """
    #include <metal_stdlib>
    using namespace metal;

    float d3CatcherWeight(int offset) {
        switch (abs(offset)) {
        case 0: return 0.153170;
        case 1: return 0.144893;
        case 2: return 0.122649;
        case 3: return 0.092902;
        default: return 0.062970;
        }
    }

    kernel void d3CatcherBlur(
        texture2d<float, access::read> source [[texture(0)]],
        texture2d<float, access::write> target [[texture(1)]],
        constant uint &axis [[buffer(0)]],
        uint2 position [[thread_position_in_grid]]) {
        if (position.x >= target.get_width()
            || position.y >= target.get_height()) return;
        float4 sum = float4(0.0);
        float weightSum = 0.0;
        for (int offset = -4; offset <= 4; offset++) {
            int2 samplePosition = int2(position);
            if (axis == 0) samplePosition.x += offset;
            else samplePosition.y += offset;
            samplePosition = clamp(
                samplePosition,
                int2(0),
                int2(source.get_width() - 1, source.get_height() - 1));
            float weight = d3CatcherWeight(offset);
            sum += source.read(uint2(samplePosition)) * weight;
            weightSum += weight;
        }
        target.write(sum / weightSum, position);
    }
    """

    private var entries: [UInt64: Entry] = [:]
    private var blurPipeline: MTLComputePipelineState?

    func install(
        configurations: [UInt64: ShadowCatcherConfiguration],
        bindings: [UInt64: [ShadowCatcherMaterialBinding]],
        preserveExistingCaches: Bool,
        host: SceneViewHost
    ) {
        let previous = entries
        var next: [UInt64: Entry] = [:]
        for (key, configuration) in configurations
        where configuration.mode == .baked {
            if preserveExistingCaches, var entry = previous[key] {
                entry.configuration = configuration
                entry.bindings = bindings[key] ?? []
                next[key] = entry
            } else {
                next[key] = Entry(
                    configuration: configuration,
                    bindings: bindings[key] ?? [])
            }
        }
        for (key, entry) in previous where next[key] == nil {
            if let texture = entry.texture { host.retire(texture) }
        }
        entries = next
        for key in entries.keys {
            bind(key)
        }
    }

    func updateBindings(
        _ bindings: [UInt64: [ShadowCatcherMaterialBinding]]
    ) {
        for key in entries.keys {
            guard var entry = entries[key] else { continue }
            entry.bindings = bindings[key] ?? []
            entries[key] = entry
            bind(key)
        }
    }

    func materialWasUpserted(
        key: UInt64,
        configuration: ShadowCatcherConfiguration?,
        bindings: [ShadowCatcherMaterialBinding],
        host: SceneViewHost
    ) {
        guard let configuration, configuration.mode == .baked else {
            if let old = entries.removeValue(forKey: key),
               let texture = old.texture {
                host.retire(texture)
            }
            return
        }
        var entry = entries[key] ?? Entry(
            configuration: configuration, bindings: bindings)
        entry.configuration = configuration
        entry.bindings = bindings
        entry.dirty = true
        entries[key] = entry
        bind(key)
        d3Log("shadowCatcher \(key): explicit material upsert queued baked refresh")
    }

    func renderDirty(at time: TimeInterval, host: SceneViewHost) {
        guard let scene = host.scene,
              let queue = host.commandQueue,
              let device = host.renderDevice() else { return }
        for key in entries.keys.sorted() where entries[key]?.dirty == true {
            guard let binding = entries[key]?.bindings.first(where: {
                $0.isCurrentDraw
            }), let sourceNode = binding.node,
                  let sourceGeometry = binding.geometry
            else {
                continue
            }
            bake(
                key: key,
                binding: binding,
                geometry: sourceGeometry,
                sourceNode: sourceNode,
                scene: scene,
                renderTargets: host.renderTargets,
                time: time,
                queue: queue,
                device: device,
                host: host)
        }
    }

    private func bake(
        key: UInt64,
        binding: ShadowCatcherMaterialBinding,
        geometry: SCNGeometry,
        sourceNode: SCNNode,
        scene: SCNScene,
        renderTargets: [UInt64: RenderTargetRec],
        time: TimeInterval,
        queue: MTLCommandQueue,
        device: MTLDevice,
        host: SceneViewHost
    ) {
        let bounds = geometry.boundingBox
        let sizeX = max(bounds.max.x - bounds.min.x, 1e-6)
        let sizeZ = max(bounds.max.z - bounds.min.z, 1e-6)
        let localCenter = SIMD3<Float>(
            (bounds.min.x + bounds.max.x) * 0.5,
            (bounds.min.y + bounds.max.y) * 0.5,
            (bounds.min.z + bounds.max.z) * 0.5)
        let presentation = sourceNode.presentation
        let worldCenter = presentation.simdConvertPosition(localCenter, to: nil)
        let worldXAxis = presentation.simdConvertVector(
            SIMD3<Float>(1, 0, 0), to: nil)
        let worldYAxis = presentation.simdConvertVector(
            SIMD3<Float>(0, 1, 0), to: nil)
        let worldZAxis = presentation.simdConvertVector(
            SIMD3<Float>(0, 0, 1), to: nil)
        let worldExtentX = sizeX * simd_length(worldXAxis)
        let worldExtentZ = sizeZ * simd_length(worldZAxis)
        let footprint = max(worldExtentX, worldExtentZ)
        let softness = entries[key]!.configuration.softness
        let resolution: Int
        if softness <= 0 || footprint <= 0 {
            resolution = 256
        } else {
            let requested = ceil(Double(footprint) / softness * 4)
            resolution = Int(min(1024, max(16, requested)))
        }
        let width = max(16, Int(ceil(
            Double(resolution) * Double(worldExtentX / footprint))))
        let height = max(16, Int(ceil(
            Double(resolution) * Double(worldExtentZ / footprint))))
        let region = SIMD4<Float>(
            bounds.min.x, bounds.max.z, 1 / sizeX, 1 / sizeZ)
        let cameraDistance: Float = 6

        let captureScene = SCNScene()
        captureScene.background.contents = UIColor.clear
        captureScene.lightingEnvironment.contents = scene.lightingEnvironment.contents
        captureScene.lightingEnvironment.intensity = scene.lightingEnvironment.intensity
        let copiedRoot = scene.rootNode.clone()
        var copiedNodes: [ObjectIdentifier: SCNNode] = [:]
        var sourcePoses: [(source: SCNNode, copy: SCNNode)] = []
        func detachAttachments(_ source: SCNNode, _ copy: SCNNode) {
            copiedNodes[ObjectIdentifier(source)] = copy
            sourcePoses.append((source, copy))
            if let sourceGeometry = source.geometry {
                let geometryCopy = sourceGeometry.copy() as! SCNGeometry
                geometryCopy.materials = sourceGeometry.materials.map {
                    $0.copy() as! SCNMaterial
                }
                copy.geometry = geometryCopy
            }
            copy.camera = source.camera?.copy() as? SCNCamera
            copy.light = source.light?.copy() as? SCNLight
            for (sourceChild, copyChild) in zip(source.childNodes, copy.childNodes) {
                detachAttachments(sourceChild, copyChild)
            }
        }
        detachAttachments(scene.rootNode, copiedRoot)
        captureScene.rootNode.addChildNode(copiedRoot)
        for (source, copy) in sourcePoses {
            copy.transform = source.presentation.transform
        }
        removeRenderTargetDisplays(
            from: captureScene,
            renderTargets: renderTargets)
        for node in captureScene.rootNode.childNodes(passingTest: { node, _ in
            node.geometry?.materials.contains(where: {
                $0.name?.hasPrefix("d3.shadowCatcher:") == true
            }) == true
        }) {
            if node !== copiedNodes[ObjectIdentifier(sourceNode)] {
                node.isHidden = true
            }
        }
        guard let captureReceiver = copiedNodes[ObjectIdentifier(sourceNode)],
              let receiverGeometry = captureReceiver.geometry else { return }
        captureReceiver.castsShadow = false
        for material in receiverGeometry.materials {
            material.lightingModel = .shadowOnly
            material.blendMode = .alpha
            material.writesToDepthBuffer = true
        }

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.projectionDirection = .vertical
        camera.orthographicScale = Double(worldExtentZ) * 0.5
        camera.automaticallyAdjustsZRange = false
        camera.zNear = Double(cameraDistance - 0.02)
        camera.zFar = Double(cameraDistance + 0.02)
        cameraNode.camera = camera
        cameraNode.simdPosition = worldCenter + simd_normalize(worldYAxis)
            * cameraDistance
        cameraNode.simdLook(
            at: worldCenter,
            up: simd_normalize(worldZAxis),
            localFront: SCNNode.simdLocalFront)
        captureScene.rootNode.addChildNode(cameraNode)

        let captureTexture = texture(
            device: device, width: width, height: height,
            usage: [.renderTarget, .shaderRead])!
        let depthTexture = texture(
            device: device, width: width, height: height,
            pixelFormat: .depth32Float, usage: .renderTarget)!
        let scratchTexture = texture(
            device: device, width: width, height: height,
            usage: [.shaderRead, .shaderWrite])!
        let outputTexture = texture(
            device: device, width: width, height: height,
            usage: [.shaderRead, .shaderWrite])!
        let commandBuffer = queue.makeCommandBuffer()!
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = captureTexture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(
            red: 0, green: 0, blue: 0, alpha: 0)
        pass.depthAttachment.texture = depthTexture
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1
        let renderer = SCNRenderer(device: device)
        renderer.scene = captureScene
        renderer.pointOfView = cameraNode
        renderer.autoenablesDefaultLighting = false
        renderer.render(
            atTime: time,
            viewport: CGRect(x: 0, y: 0, width: width, height: height),
            commandBuffer: commandBuffer,
            passDescriptor: pass)
        encodeBlur(
            source: captureTexture, target: scratchTexture,
            axis: 0, commandBuffer: commandBuffer, device: device)
        encodeBlur(
            source: scratchTexture, target: outputTexture,
            axis: 1, commandBuffer: commandBuffer, device: device)
        commandBuffer.commit()

        let previousTexture = entries[key]?.texture
        entries[key]?.texture = outputTexture
        entries[key]?.region = region
        entries[key]?.dirty = false
        bind(key)
        host.retire(captureTexture)
        host.retire(depthTexture)
        host.retire(scratchTexture)
        host.retire(renderer)
        host.retire(captureScene)
        if let previousTexture { host.retire(previousTexture) }
        d3Log("shadowCatcher \(key): captured \(width)x\(height) RGBA footprint, softness=\(softness)")
    }

    private func encodeBlur(
        source: MTLTexture,
        target: MTLTexture,
        axis: UInt32,
        commandBuffer: MTLCommandBuffer,
        device: MTLDevice
    ) {
        if blurPipeline == nil {
            let library = try! device.makeLibrary(source: Self.blurSource, options: nil)
            let function = library.makeFunction(name: "d3CatcherBlur")!
            blurPipeline = try! device.makeComputePipelineState(function: function)
        }
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(blurPipeline!)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(target, index: 1)
        var blurAxis = axis
        encoder.setBytes(
            &blurAxis, length: MemoryLayout<UInt32>.stride, index: 0)
        let width = blurPipeline!.threadExecutionWidth
        let height = max(1, blurPipeline!.maxTotalThreadsPerThreadgroup / width)
        let threads = MTLSize(width: width, height: height, depth: 1)
        let groups = MTLSize(
            width: (target.width + width - 1) / width,
            height: (target.height + height - 1) / height,
            depth: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
        encoder.endEncoding()
    }

    private func texture(
        device: MTLDevice,
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat = .rgba8Unorm,
        usage: MTLTextureUsage
    ) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat, width: width, height: height,
            mipmapped: false)
        descriptor.usage = usage
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)
    }

    private func removeRenderTargetDisplays(
        from scene: SCNScene,
        renderTargets: [UInt64: RenderTargetRec]
    ) {
        let targetIDs = Set(renderTargets.values.map {
            ObjectIdentifier($0.colorTex)
        })
        var removals: [SCNNode] = []
        scene.rootNode.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            let usesTarget = geometry.materials.contains { material in
                let properties = [
                    material.diffuse, material.ambient, material.specular,
                    material.emission, material.transparent, material.reflective,
                    material.multiply, material.normal, material.displacement,
                    material.ambientOcclusion, material.selfIllumination,
                    material.metalness, material.roughness, material.clearCoat,
                    material.clearCoatRoughness, material.clearCoatNormal,
                ]
                return properties.contains { property in
                    guard let texture = property.contents as? MTLTexture else {
                        return false
                    }
                    return targetIDs.contains(ObjectIdentifier(texture))
                }
            }
            if usesTarget { removals.append(node) }
        }
        for node in removals { node.removeFromParentNode() }
    }

    private func bind(_ key: UInt64) {
        guard let entry = entries[key] else { return }
        for binding in entry.bindings {
            binding.material.lightingModel = .constant
            binding.material.name = "d3.shadowCatcher:\(key)"
            binding.material.diffuse.contents = entry.texture ?? UIColor.clear
            binding.material.blendMode = .alpha
            binding.material.transparencyMode = .aOne
            binding.material.writesToDepthBuffer = true
            binding.material.readsFromDepthBuffer = true
            binding.material.shaderModifiers = [.geometry: Self.geometryModifier]
            if let region = entry.region {
                binding.material.setValue(
                    NSValue(scnVector4: SCNVector4(
                        region.x, region.y, region.z, region.w)),
                    forKey: "d3CatcherRegion")
            }
        }
    }
}
