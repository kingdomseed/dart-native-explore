import Foundation
import Metal
import SceneKit
import UIKit

final class SelectionOutlineProbe {
    private var renderer: SCNRenderer?
    private let camera = SCNNode()
    private var texture: MTLTexture?
    private var depth: MTLTexture?
    private var installed = false
    private var lastControl = ""

    static let shader = """
    struct D3ProbeParams { float4 d3ProbeMode; };
    fragment float4 d3_probe_outline(
        D3ResolveOut in [[stage_in]],
        texture2d<float> colorSampler [[texture(0)]],
        texture2d<float> d3ProbeMask [[texture(1)]],
        constant D3ProbeParams &p [[buffer(0)]]) {
        constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::nearest);
        float4 base = colorSampler.sample(s, in.uv);
        if (p.d3ProbeMode.x == 2.0 || p.d3ProbeMode.x == 3.0) return base;
        float2 texel = 1.0 / float2(d3ProbeMask.get_width(), d3ProbeMask.get_height());
        float center = step(0.99, d3ProbeMask.sample(s, in.uv).r);
        float edge = 0.0;
        for (int y = -3; y <= 3; y++) {
            for (int x = -3; x <= 3; x++) {
                if (x*x + y*y > 9) continue;
                edge = max(edge, step(0.99, d3ProbeMask.sample(s,
                    in.uv + float2(x,y) * texel).r));
            }
        }
        if (p.d3ProbeMode.x == 1.0) return float4(float3(center), 1.0);
        float a = max(0.0, edge - center);
        return float4(mix(base.rgb, float3(1.0, 0.65, 0.0), a), base.a);
    }
    """

    static func append(passes: inout [String: Any], sequence: inout [String],
                       symbols: inout [String: Any]) {
        symbols["d3ProbeMaskSymbol"] = ["type": "sampler2D"]
        symbols["d3ProbeModeSymbol"] = ["type": "vec4"]
        passes["d3_probe_outline"] = [
            "draw": "DRAW_QUAD",
            "metalVertexShader": "d3_resolve_vertex",
            "metalFragmentShader": "d3_probe_outline",
            "inputs": ["colorSampler": "COLOR",
                       "d3ProbeMask": "d3ProbeMaskSymbol",
                       "d3ProbeMode": "d3ProbeModeSymbol"],
            "outputs": ["color": "COLOR"],
            "depthStates": ["enableRead": false, "enableWrite": false],
        ]
        sequence.append("d3_probe_outline")
    }

    func capture(at time: TimeInterval, host: SceneViewHost) {
        let control = host.nodesById.values.first {
            $0.name?.hasPrefix("__outline_probe__:") == true
        }?.name
        guard let control else {
            if installed {
                installed = false
                host.outlineProbeEnabled = false
                host.invalidateProbeResolve()
                renderer = nil
                if let texture { host.retire(texture) }
                if let depth { host.retire(depth) }
                texture = nil
                depth = nil
            }
            return
        }
        let parts = control.split(separator: ":").map(String.init)
        let mode = parts[2]
        guard host.screenSubviews.isEmpty else {
            if installed {
                installed = false
                host.outlineProbeEnabled = false
                host.invalidateProbeResolve()
            }
            host.logOnce("outline.probe.siblings",
                "outline probe BLOCKED: capture with sibling views is not exercised")
            return
        }
        if !installed {
            installed = true
            host.outlineProbeEnabled = true
            host.invalidateProbeResolve()
        }
        guard host.scene != nil, let pov = host.pointOfView,
              let sourceCamera = pov.camera,
              let device = host.renderDevice(), let queue = host.commandQueue,
              let technique = host.technique else { return }
        let width = max(1, Int(host.bounds.width * host.contentScaleFactor))
        let height = max(1, Int(host.bounds.height * host.contentScaleFactor))
        if texture?.width != width || texture?.height != height {
            if let texture { host.retire(texture) }
            if let depth { host.retire(depth) }
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
            desc.storageMode = .private
            desc.usage = [.renderTarget, .shaderRead]
            texture = device.makeTexture(descriptor: desc)!
            desc.pixelFormat = .depth32Float
            desc.usage = [.renderTarget]
            depth = device.makeTexture(descriptor: desc)!
        }
        let mask = texture!
        technique.setObject(SCNMaterialProperty(contents: mask),
                            forKeyedSubscript: "d3ProbeMaskSymbol" as NSCopying)
        let modeIndex: Float = mode == "mask" ? 1 : mode == "control" ? 2 : mode == "off" ? 3 : 0
        technique.setObject(NSValue(scnVector4: SCNVector4(modeIndex, 0, 0, 0)),
                            forKeyedSubscript: "d3ProbeModeSymbol" as NSCopying)
        if mode == "off" { return }
        if renderer == nil {
            renderer = SCNRenderer(device: device, options: nil)
            renderer!.autoenablesDefaultLighting = false
            renderer!.isPlaying = false
        }
        let capture = renderer!
        let captureScene = SCNScene()
        captureScene.background.contents = UIColor.black
        capture.scene = captureScene
        camera.camera = sourceCamera.copy() as? SCNCamera
        camera.camera!.categoryBitMask = 1
        camera.camera!.wantsHDR = false
        camera.camera!.wantsExposureAdaptation = false
        camera.camera!.bloomIntensity = 0
        camera.camera!.vignettingIntensity = 0
        captureScene.rootNode.addChildNode(camera)
        camera.simdWorldTransform = pov.presentation.simdWorldTransform
        capture.pointOfView = camera
        let selected = host.nodesById.values.first { $0.name == "u3.target.\(parts[1])" }!
        var selectedNodes = [selected]
        selected.enumerateChildNodes { node, _ in selectedNodes.append(node) }
        let flat = SCNMaterial()
        flat.lightingModel = .constant
        flat.isDoubleSided = true
        flat.shaderModifiers = [.fragment: "#pragma body\n_output.color = float4(1.0);"]
        var copiedNodes: [ObjectIdentifier: SCNNode] = [:]
        func captureNode(_ source: SCNNode) -> SCNNode {
            let key = ObjectIdentifier(source)
            if let copy = copiedNodes[key] { return copy }
            let copy = SCNNode()
            copiedNodes[key] = copy
            let parent = source.parent.map { captureNode($0) } ?? captureScene.rootNode
            parent.addChildNode(copy)
            let pose = source.presentation
            copy.simdTransform = pose.simdTransform
            copy.simdPivot = pose.simdPivot
            copy.isHidden = pose.isHidden
            copy.opacity = pose.opacity
            return copy
        }
        var geometryCount = 0
        var skinCount = 0
        for source in selectedNodes {
            let copy = captureNode(source)
            guard let sourceGeometry = source.geometry else { continue }
            let geometry = sourceGeometry.copy() as! SCNGeometry
            geometry.materials = sourceGeometry.materials.map { _ in flat }
            copy.geometry = geometry
            geometryCount += 1
            if let sourceSkinner = source.skinner {
                // Preserve bone order and ancestor paths so the original bind-space
                // matrices apply to the live evaluated pose in the same world space.
                let skinner = SCNSkinner(
                    baseGeometry: geometry,
                    bones: sourceSkinner.bones.map { captureNode($0) },
                    boneInverseBindTransforms: sourceSkinner.boneInverseBindTransforms,
                    boneWeights: sourceSkinner.boneWeights,
                    boneIndices: sourceSkinner.boneIndices)
                skinner.baseGeometryBindTransform = sourceSkinner.baseGeometryBindTransform
                skinner.skeleton = sourceSkinner.skeleton.map { captureNode($0) }
                copy.skinner = skinner
                skinCount += 1
            }
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = mask
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        pass.depthAttachment.texture = depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1
        let cb = queue.makeCommandBuffer()!
        // Evaluate native skinning on the copied pose. No animation or physics
        // ownership is copied from the live scene.
        capture.render(atTime: time, viewport: CGRect(x: 0, y: 0, width: width, height: height),
                       commandBuffer: cb, passDescriptor: pass)
        cb.commit()
        cb.waitUntilCompleted()
        if cb.status == .error { d3Log("outline probe capture failed: \(String(describing: cb.error))") }
        if lastControl != control {
            d3Log("outline probe \(control) geometries=\(geometryCount) skins=\(skinCount) selectedNodes=\(selectedNodes.count) captureNodes=\(copiedNodes.count) mask=\(width)x\(height) time=\(time)")
            lastControl = control
        }
    }
}
