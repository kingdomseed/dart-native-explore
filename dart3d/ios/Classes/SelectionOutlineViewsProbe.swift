import Foundation
import Metal
import SceneKit
import UIKit

struct OutlineViewsFrame {
    struct Draw {
        let identity: ObjectIdentifier
        let template: SCNGeometry
        let transform, pivot: SCNMatrix4
        let hidden: Bool
        let opacity: CGFloat
        let category, order: Int
    }
    let time: TimeInterval
    let mode: Int
    let cameraCase: Int
    let publishInUpdate: Bool
    let bindBeforeInstall: Bool
    let isProbe: Bool
    let draws: [Draw]
}

final class SelectionOutlineViewsProbe {
    static let marker = "__u3_outline_views_probe__"
    private struct Template {
        weak var source: SCNGeometry?
        let signature: [Float]
        let geometry: SCNGeometry
    }
    private var templates: [ObjectIdentifier: Template] = [:]
    var frame: OutlineViewsFrame?
    var enabled = false
    var tailEnabled = false
    var hostBinding: OutlineViewsBinding?
    private var lastControl = ""

    func clear(host: SceneViewHost) {
        guard enabled else { return }
        if let hostBinding { host.retireOutlineProbe(hostBinding) }
        hostBinding = nil
        frame = nil
        templates.removeAll()
        enabled = false
        tailEnabled = false
        lastControl = ""
        host.invalidateOutlineViewsResolve()
        d3Log("U3OV retire producer/host scene-or-detach")
    }

    static func control(_ host: SceneViewHost) -> SCNNode? {
        host.nodesById.values.first { $0.name == marker }
    }

    func capture(host: SceneViewHost, selection: SelectionOutline, time: TimeInterval) {
        let control = Self.control(host)
        if control == nil && selection.isEmpty {
            if enabled {
                enabled = false
                frame = nil
                templates.removeAll()
                if let binding = hostBinding { host.retireOutlineProbe(binding) }
                hostBinding = nil
                tailEnabled = false
                for (key, var target) in host.renderTargets {
                    for i in target.views.indices {
                        if let binding = target.views[i].outlineBinding { host.retireOutlineProbe(binding) }
                        if let technique = target.views[i].renderer?.technique {
                            technique.setObject(NSValue(scnVector4: SCNVector4(0, 0, 0, 0)),
                                forKeyedSubscript: "u3ModeSymbol" as NSCopying)
                            host.retireOutlineProbe(technique)
                        }
                        target.views[i].renderer?.technique = nil
                        target.views[i].outlineBinding = nil
                    }
                    host.renderTargets[key] = target
                }
                host.invalidateOutlineViewsResolve()
                d3Log("U3OV retire marker-absent")
            }
            return
        }
        if !enabled {
            enabled = true
            d3Log("U3OV create producer requested-scale=1 general-skin-morph=DEFERRED")
        }
        let isProbe = control != nil
        let mode = control.map { Int($0.position.x.rounded()) } ?? 2
        let cameraCase = control.map { Int($0.position.y.rounded()) } ?? 0
        // Authored marker z=1 is reflected to SceneKit z=-1 at both native ingresses.
        let publishInUpdate = control.map { $0.position.z == -1 || $0.position.z == 0 } ?? true
        let bindBeforeInstall = control.map { $0.scale.x == 2 } ?? false
        if tailEnabled != (mode != 0) {
            tailEnabled = mode != 0
            host.invalidateOutlineViewsResolve()
        }
        var draws: [OutlineViewsFrame.Draw] = []
        var used = Set<ObjectIdentifier>()
        selection.forEachActive { id, rgba in
            guard let owner = host.nodesById[id] else { return }
            let owned = [owner] + owner.childNodes.filter { $0.name?.hasPrefix("d3prim:") == true }
            for source in owned {
                guard let geometry = source.geometry else { continue }
                guard source.skinner == nil, source.morpher == nil else {
                    host.logOnce("U3OV.deformer", "U3OV BLOCKED selected deformer outside finite fixture")
                    continue
                }
                let key = ObjectIdentifier(source)
                used.insert(key)
                let color = [rgba.r, rgba.g, rgba.b, rgba.a == 0 ? 1 : rgba.a]
                let materialSources = geometry.materials.isEmpty ? [SCNMaterial()] : geometry.materials
                let signature = color + materialSources.flatMap {
                    [Float($0.isDoubleSided ? 1 : 0), Float($0.cullMode.rawValue)]
                }
                let template: SCNGeometry
                if let old = templates[key], old.source === geometry, old.signature == signature {
                    template = old.geometry
                } else {
                    template = geometry.copy() as! SCNGeometry
                    template.materials = materialSources.map { authored in
                        let flat = SCNMaterial()
                        flat.lightingModel = .constant
                        flat.isDoubleSided = authored.isDoubleSided
                        flat.cullMode = authored.cullMode
                        flat.blendMode = .replace
                        flat.readsFromDepthBuffer = true
                        flat.writesToDepthBuffer = true
                        flat.shaderModifiers = [.fragment: "#pragma body\n_output.color = float4(\(color[0]), \(color[1]), \(color[2]), \(color[3]));"]
                        return flat
                    }
                    templates[key] = Template(source: geometry, signature: signature, geometry: template)
                    d3Log("U3OV template node=\(id) draw=\(key) elements=\(geometry.elements.count) rgba=\(color)")
                }
                var hidden = false
                var opacity: CGFloat = 1
                var ancestor: SCNNode? = source
                while let node = ancestor {
                    hidden = hidden || node.isHidden || node.presentation.isHidden
                    opacity *= node.presentation.opacity
                    ancestor = node.parent
                }
                draws.append(OutlineViewsFrame.Draw(identity: key, template: template,
                    transform: source.presentation.worldTransform, pivot: source.presentation.pivot,
                    hidden: hidden, opacity: opacity, category: source.categoryBitMask,
                    order: source.renderingOrder))
            }
        }
        templates = templates.filter { used.contains($0.key) }
        frame = OutlineViewsFrame(time: time, mode: mode, cameraCase: cameraCase,
            publishInUpdate: publishInUpdate, bindBeforeInstall: bindBeforeInstall,
            isProbe: isProbe, draws: draws)
        let label = "mode=\(mode) cameraCase=\(cameraCase) draws=\(draws.count) publishInUpdate=\(publishInUpdate)"
        if label != lastControl { d3Log("U3OV control \(label) time=\(time)"); lastControl = label }
        guard !host.multiScreenMode, mode != 0, let pov = host.pointOfView,
              let camera = pov.camera, let queue = host.commandQueue,
              let device = host.renderDevice(), let frame else { return }
        if hostBinding == nil { hostBinding = OutlineViewsBinding(device: device, label: "host") }
        let size = host.outlineRasterSnapshot
        guard size.width > 0, size.height > 0, let cb = queue.makeCommandBuffer() else { return }
        hostBinding?.encode(frame, camera: camera, transform: pov.presentation.worldTransform,
            layerMask: camera.categoryBitMask, width: size.width, height: size.height,
            outputWidth: size.outputWidth, outputHeight: size.outputHeight,
            commandBuffer: cb, host: host)
        hostBinding?.bind(host.technique, frame: frame)
        hostBinding?.completion(cb, label: "host-mask time=\(time)")
        cb.commit()
    }

    func storedTargets(host: SceneViewHost, label: String) {
        guard Self.control(host) != nil, let cb = host.commandQueue?.makeCommandBuffer() else { return }
        for (id, target) in host.renderTargets.sorted(by: { $0.key < $1.key }) {
            Self.readback(target.colorTex, commandBuffer: cb,
                label: "stored-\(label) target=\(id) dirty=\(target.dirty) time=\(frame?.time ?? 0)")
        }
        cb.commit()
    }

    static func readback(_ texture: MTLTexture, commandBuffer: MTLCommandBuffer, label: String) {
        let bpp: Int
        switch texture.pixelFormat {
        case .rgba16Float: bpp = 8
        case .rgba8Unorm, .rgba8Unorm_srgb, .bgra8Unorm, .bgra8Unorm_srgb: bpp = 4
        default:
            d3Log("U3OV BLOCKED readback format=\(texture.pixelFormat.rawValue) \(label)")
            return
        }
        let rowBytes = texture.width * bpp
        let stride = (rowBytes + 255) & ~255
        guard let staging = texture.device.makeBuffer(length: stride * texture.height, options: .storageModeShared),
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            d3Log("U3OV BLOCKED readback allocation \(label)"); return
        }
        blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
            to: staging, destinationOffset: 0, destinationBytesPerRow: stride,
            destinationBytesPerImage: stride * texture.height)
        blit.endEncoding()
        commandBuffer.addCompletedHandler { buffer in
            guard buffer.status == .completed else {
                d3Log("U3OV GPU-ERROR \(label) \(String(describing: buffer.error))"); return
            }
            var packed = Data()
            for y in 0..<texture.height {
                packed.append(Data(bytes: staging.contents().advanced(by: y * stride), count: rowBytes))
            }
            let filename = "u3-outline-" + label.map {
                $0.isLetter || $0.isNumber || $0 == "." ? String($0) : "-"
            }.joined()
            let path = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            do {
                try packed.write(to: path.appendingPathExtension("rgba"))
                let schema: [String: Any] = ["label": label, "width": texture.width,
                    "height": texture.height, "pixelFormat": texture.pixelFormat.rawValue,
                    "bytesPerPixel": bpp, "bytesPerRow": rowBytes,
                    "origin": "metal-texture", "encoding": "raw-unpadded-native-format"]
                try JSONSerialization.data(withJSONObject: schema, options: [.sortedKeys])
                    .write(to: path.appendingPathExtension("json"))
                d3Log("U3OV RAW file=\(path.path).rgba schema=\(path.path).json")
            } catch {
                d3Log("U3OV RAW write failed \(label): \(error)")
            }
            d3Log("U3OV RAW begin \(label) width=\(texture.width) height=\(texture.height) format=\(texture.pixelFormat.rawValue) bpp=\(bpp) rowBytes=\(rowBytes) origin=metal-texture")
            for y in 0..<texture.height {
                let data = Data(bytes: staging.contents().advanced(by: y * stride), count: rowBytes)
                d3Log("U3OV RAW row \(label) y=\(y) base64=\(data.base64EncodedString())")
            }
            d3Log("U3OV RAW end \(label)")
        }
    }
}

final class OutlineViewsBinding: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let camera = SCNNode()
    let renderer: SCNRenderer
    let label: String
    private var nodes: [ObjectIdentifier: (SCNNode, SCNGeometry)] = [:]
    private var mask: MTLTexture?
    private var depth: MTLTexture?
    private var property: SCNMaterialProperty?
    private var installed: SCNTechnique?
    private var mode = 0
    private var lastLogTime = -Double.infinity
    private var observation = ""
    private var lastDrawLogTime = -Double.infinity
    private var syntheticRenderer: SCNRenderer?
    private var pendingAlpha: (base: MTLTexture, output: MTLTexture, technique: SCNTechnique)?
    private var publication: (() -> Void)?

    init(device: MTLDevice, label: String) {
        renderer = SCNRenderer(device: device)
        self.label = label
        super.init()
        scene.rootNode.addChildNode(camera)
        renderer.scene = scene
        renderer.pointOfView = camera
        renderer.autoenablesDefaultLighting = false
        renderer.isPlaying = false
        d3Log("U3OV create binding=\(label)")
    }

    func encode(_ frame: OutlineViewsFrame, camera source: SCNCamera, transform: SCNMatrix4,
                layerMask: Int, width: Int, height: Int, outputWidth: Int, outputHeight: Int,
                commandBuffer: MTLCommandBuffer, host: SceneViewHost,
                prepareConsumer: (() -> Void)? = nil) {
        if mask?.width != width || mask?.height != height {
            if let mask { host.retireOutlineProbe(mask) }
            if let depth { host.retireOutlineProbe(depth) }
            if let property { host.retireOutlineProbe(property) }
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                width: width, height: height, mipmapped: false)
            desc.usage = [.renderTarget, .shaderRead]; desc.storageMode = .private
            mask = renderer.device?.makeTexture(descriptor: desc)
            desc.pixelFormat = .depth32Float; desc.usage = .renderTarget
            depth = renderer.device?.makeTexture(descriptor: desc)
            property = mask.map { SCNMaterialProperty(contents: $0) }
            property?.minificationFilter = .linear
            property?.magnificationFilter = .linear
            property?.wrapS = .clamp; property?.wrapT = .clamp
            d3Log("U3OV rebind binding=\(label) raster=\(width)x\(height) output=\(outputWidth)x\(outputHeight) mask=rgba16Float")
        }
        guard let mask, let depth else { d3Log("U3OV BLOCKED mask allocation \(label)"); return }
        let controlled = frame.publishInUpdate && label.hasPrefix("target=")
        let publish = { [self] in
            camera.camera = source.copy() as? SCNCamera
            camera.camera?.categoryBitMask = layerMask
            camera.camera?.wantsHDR = false
            camera.camera?.wantsExposureAdaptation = false
            camera.camera?.exposureOffset = 0
            camera.camera?.whitePoint = 1
            camera.camera?.bloomIntensity = 0
            camera.camera?.vignettingIntensity = 0
            camera.transform = transform
            let live = Set(frame.draws.map { $0.identity })
            for key in Array(nodes.keys) where !live.contains(key) {
                if let old = nodes.removeValue(forKey: key) { old.0.removeFromParentNode(); host.retireOutlineProbe(old.0) }
            }
            for draw in frame.draws {
                let node: SCNNode
                if let old = nodes[draw.identity], old.1 === draw.template { node = old.0 }
                else {
                    if let old = nodes[draw.identity] { old.0.removeFromParentNode(); host.retireOutlineProbe(old.0) }
                    let geometry = draw.template.copy() as! SCNGeometry
                    geometry.materials = draw.template.materials.map { $0.copy() as! SCNMaterial }
                    node = SCNNode(geometry: geometry)
                    scene.rootNode.addChildNode(node)
                    nodes[draw.identity] = (node, draw.template)
                }
                node.transform = draw.transform; node.pivot = draw.pivot
                node.isHidden = draw.hidden; node.opacity = draw.opacity
                node.categoryBitMask = draw.category; node.renderingOrder = draw.order
            }
            prepareConsumer?()
            if label.hasPrefix("target="), frame.isProbe, frame.mode != 0, let device = renderer.device {
                let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb,
                    width: outputWidth, height: outputHeight, mipmapped: false)
                desc.usage = [.shaderRead, .renderTarget]; desc.storageMode = .shared
                if let base = device.makeTexture(descriptor: desc) {
                    var bytes = [UInt8](repeating: 0, count: outputWidth * outputHeight * 4)
                    for y in 0..<outputHeight {
                        for x in 0..<outputWidth {
                            let rgba: [UInt8] = x < outputWidth / 3 ? [0, 0, 0, 0]
                                : x < outputWidth * 2 / 3 ? [32, 64, 16, 128] : [48, 24, 80, 255]
                            let encoded = [rgba[2], rgba[1], rgba[0], rgba[3]]
                            for c in 0..<4 { bytes[(y * outputWidth + x) * 4 + c] = encoded[c] }
                        }
                    }
                    bytes.withUnsafeBytes { base.replace(region: MTLRegionMake2D(0, 0, outputWidth, outputHeight),
                        mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: outputWidth * 4) }
                    desc.storageMode = .private
                    if let output = device.makeTexture(descriptor: desc),
                       let technique = ToneMapTechnique.make(device: device, outline: true,
                           compositeOnly: true, syntheticInput: true) {
                        if syntheticRenderer == nil {
                            let sr = SCNRenderer(device: device)
                            let sc = SCNScene()
                            sc.rootNode.addChildNode(SCNNode())
                            sr.scene = sc
                            syntheticRenderer = sr
                        }
                        let synthetic = syntheticRenderer!
                        let alphaCamera = synthetic.scene!.rootNode.childNodes[0]
                        alphaCamera.camera = camera.camera?.copy() as? SCNCamera
                        alphaCamera.transform = camera.transform
                        synthetic.pointOfView = alphaCamera
                        if let old = synthetic.technique { host.retireOutlineProbe(old) }
                        let baseProp = SCNMaterialProperty(contents: base)
                        technique.setObject(property, forKeyedSubscript: "u3MaskSymbol" as NSCopying)
                        technique.setObject(NSValue(scnVector4: SCNVector4(Float(frame.mode), 0, 0, 0)),
                            forKeyedSubscript: "u3ModeSymbol" as NSCopying)
                        technique.setObject(baseProp, forKeyedSubscript: "u3BaseSymbol" as NSCopying)
                        synthetic.technique = technique
                        synthetic.technique?.setObject(property, forKeyedSubscript: "u3MaskSymbol" as NSCopying)
                        synthetic.technique?.setObject(NSValue(scnVector4: SCNVector4(Float(frame.mode), 0, 0, 0)),
                            forKeyedSubscript: "u3ModeSymbol" as NSCopying)
                        synthetic.technique?.setObject(baseProp, forKeyedSubscript: "u3BaseSymbol" as NSCopying)
                        pendingAlpha = (base: base, output: output, technique: technique)
                    }
                }
            }
        }
        if controlled {
            publication = publish
            renderer.delegate = self
        } else {
            SCNTransaction.begin(); SCNTransaction.disableActions = true
            publish()
            SCNTransaction.commit()
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = mask
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        pass.depthAttachment.texture = depth
        pass.depthAttachment.loadAction = .clear; pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1
        renderer.render(atTime: frame.time, viewport: CGRect(x: 0, y: 0, width: width, height: height),
            commandBuffer: commandBuffer, passDescriptor: pass)
        if controlled {
            if publication != nil {
                d3Log("U3OV BLOCKED private-update callback absent binding=\(label) time=\(frame.time)")
                publication = nil
            }
            renderer.delegate = nil
        }
        observation = "binding=\(label) mode=\(frame.mode) cameraCase=\(frame.cameraCase) time=\(frame.time) camera=\(transform.m41),\(transform.m42),\(transform.m43) maskLayers=\(layerMask) raster=\(width)x\(height) output=\(outputWidth)x\(outputHeight) poses=\(frame.draws.map { "\($0.transform.m41),\($0.transform.m42),\($0.transform.m43)" })"
        if frame.time - lastLogTime >= 0.25 {
            d3Log("U3OV mask-encoded \(observation)")
            lastLogTime = frame.time
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        publication?()
        publication = nil
        d3Log("U3OV private-update-publication binding=\(label) time=\(time) draws=\(nodes.count)")
    }

    func bind(_ technique: SCNTechnique?, frame: OutlineViewsFrame?) {
        if let frame { mode = frame.mode }
        guard let technique else { d3Log("U3OV BLOCKED missing installed technique \(label)"); return }
        if installed !== technique {
            installed = technique
            d3Log("U3OV installed-copy binding=\(label) technique=\(ObjectIdentifier(technique))")
        }
        technique.setObject(property, forKeyedSubscript: "u3MaskSymbol" as NSCopying)
        technique.setObject(NSValue(scnVector4: SCNVector4(Float(mode), 0, 0, 0)),
            forKeyedSubscript: "u3ModeSymbol" as NSCopying)
    }

    func completion(_ buffer: MTLCommandBuffer, label: String) {
        buffer.addCompletedHandler { [self] cb in
            if cb.status == .error { d3Log("U3OV GPU-ERROR binding=\(self.label) \(label) \(String(describing: cb.error))") }
        }
    }

    func logRendered(time: TimeInterval, actualCamera: SCNMatrix4?, host: SceneViewHost) {
        if time - lastDrawLogTime >= 0.25 {
            let actualDraws = nodes.values.map {
                let p = $0.0.presentation.worldTransform
                return "\(p.m41),\(p.m42),\(p.m43)"
            }
            d3Log("U3OV screen-didRender \(observation) callbackTime=\(time) actualCamera=\(String(describing: actualCamera)) actualBasePoses=\(actualDraws)")
            lastDrawLogTime = time
        }
    }

    func targetProof(_ texture: MTLTexture, samples: Int, frame: OutlineViewsFrame,
                     commandBuffer: MTLCommandBuffer, host: SceneViewHost) {
        let caseLabel = "\(label) mode=\(frame.mode) cameraCase=\(frame.cameraCase) aa=\(samples) time=\(frame.time)"
        SelectionOutlineViewsProbe.readback(texture, commandBuffer: commandBuffer, label: "target \(caseLabel)")
        guard frame.mode != 0, let mask else { return }
        SelectionOutlineViewsProbe.readback(mask, commandBuffer: commandBuffer, label: "mask \(caseLabel)")
        guard let alpha = pendingAlpha, let synthetic = syntheticRenderer else {
            d3Log("U3OV BLOCKED alpha technique/output"); return
        }
        pendingAlpha = nil
        let base = alpha.base
        let output = alpha.output
        let technique = alpha.technique
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].texture = output
        if samples > 1 {
            let msaa = host.msaaTexture(pixelFormat: output.pixelFormat, width: output.width,
                height: output.height, samples: samples)
            guard let msaa else { d3Log("U3OV BLOCKED alpha MSAA allocation"); return }
            pass.colorAttachments[0].texture = msaa
            pass.colorAttachments[0].resolveTexture = output
            pass.colorAttachments[0].storeAction = .multisampleResolve
        }
        synthetic.render(withViewport: CGRect(x: 0, y: 0, width: output.width, height: output.height),
            commandBuffer: commandBuffer, passDescriptor: pass)
        SelectionOutlineViewsProbe.readback(base, commandBuffer: commandBuffer, label: "alpha-input \(caseLabel)")
        SelectionOutlineViewsProbe.readback(output, commandBuffer: commandBuffer, label: "alpha-output \(caseLabel)")
        commandBuffer.addCompletedHandler { [synthetic, technique, base, output] _ in
            _ = (synthetic, technique, base, output)
        }
    }
}
