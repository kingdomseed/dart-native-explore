import CoreFoundation
import Foundation
import SceneKit

struct ScreenDebugOptions: Equatable {
    enum Channel: String { case none, normals, metallic, roughness, baseColor, depth }
    var channel: Channel = .none
    var wireframe = false

    static func decode(_ value: Any?) throws -> ScreenDebugOptions {
        guard let value else { return ScreenDebugOptions() }
        guard let object = value as? [String: Any],
              let name = object["channel"] as? String,
              let channel = Channel(rawValue: name),
              let wire = object["wireframe"] as? NSNumber,
              CFGetTypeID(wire) == CFBooleanGetTypeID() else {
            throw NSError(domain: "dart3d.viewConfig.debugView", code: 1,
                          userInfo: [NSLocalizedDescriptionKey:
                            "debugView requires a known channel and boolean wireframe"])
        }
        return ScreenDebugOptions(channel: channel, wireframe: wire.boolValue)
    }
}

struct ScreenDebugFrame {
    struct LightState {
        let color: Any
        let intensity: CGFloat
        let castsShadow: Bool
        let shadowMapSize: CGSize
        let shadowBias: CGFloat
        let shadowRadius: CGFloat
        let automaticallyAdjustsShadowProjection: Bool
        let orthographicScale: CGFloat
        let maximumShadowDistance: CGFloat
        let forcesBackFaceCasters: Bool
        let shadowSampleCount: Int

        init(_ source: SCNLight) {
            color = source.color
            intensity = source.intensity
            castsShadow = source.castsShadow
            shadowMapSize = source.shadowMapSize
            shadowBias = source.shadowBias
            shadowRadius = source.shadowRadius
            automaticallyAdjustsShadowProjection = source.automaticallyAdjustsShadowProjection
            orthographicScale = source.orthographicScale
            maximumShadowDistance = source.maximumShadowDistance
            forcesBackFaceCasters = source.forcesBackFaceCasters
            shadowSampleCount = source.shadowSampleCount
        }

        func apply(to displayed: SCNLight) {
            displayed.color = color
            displayed.intensity = intensity
            displayed.castsShadow = castsShadow
            displayed.shadowMapSize = shadowMapSize
            displayed.shadowBias = shadowBias
            displayed.shadowRadius = shadowRadius
            displayed.automaticallyAdjustsShadowProjection = automaticallyAdjustsShadowProjection
            displayed.orthographicScale = orthographicScale
            displayed.maximumShadowDistance = maximumShadowDistance
            displayed.forcesBackFaceCasters = forcesBackFaceCasters
            displayed.shadowSampleCount = shadowSampleCount
        }
    }
    struct Light {
        let template: SCNLight
        let state: LightState
    }
    struct Skin {
        let identity: ObjectIdentifier
        let geometry: SCNGeometry
        let bones: [ObjectIdentifier]
        let skeleton: ObjectIdentifier?
        let inverseBinds: [NSValue]?
        let weights: SCNGeometrySource
        let indices: SCNGeometrySource
        let bind: SCNMatrix4
    }
    struct Morph {
        let identity: ObjectIdentifier
        let targets: [SCNGeometry]
        let weights: [NSNumber]
        let mode: SCNMorpherCalculationMode
        let normals: Bool
    }
    struct Node {
        let identity: ObjectIdentifier
        let parent: ObjectIdentifier?
        let transform: SCNMatrix4
        let pivot: SCNMatrix4
        let hidden: Bool
        let opacity: CGFloat
        let category: Int
        let order: Int
        let castsShadow: Bool
        let light: Light?
        let geometry: SCNGeometry?
        let skin: Skin?
        let morph: Morph?
    }
    let nodes: [Node]
}

final class ScreenDebugAttachments {
    private struct Material {
        weak var source: SCNMaterial?
        let signature: NSArray
        let channel: ScreenDebugOptions.Channel
        let displayed: SCNMaterial
    }
    private struct Geometry {
        weak var source: SCNGeometry?
        let materials: [SCNMaterial]
        let displayed: SCNGeometry
    }
    private struct LightTemplate {
        weak var source: SCNLight?
        let template: SCNLight
    }
    private var lights: [ObjectIdentifier: LightTemplate] = [:]
    private var materials: [ObjectIdentifier: Material] = [:]
    private var geometries: [ObjectIdentifier: Geometry] = [:]

    func clear() {
        lights.removeAll()
        materials.removeAll()
        geometries.removeAll()
    }

    func capture(_ scene: SCNScene, channel: ScreenDebugOptions.Channel,
                 host: SceneViewHost) -> ScreenDebugFrame {
        var rows: [ScreenDebugFrame.Node] = []
        var captured = Set<ObjectIdentifier>()
        var skinNodes: [SCNNode] = []
        var usedLights = Set<ObjectIdentifier>()
        var usedMaterials = Set<ObjectIdentifier>()
        var usedGeometries = Set<ObjectIdentifier>()
        let shadowProxies = host.blendCasterProxyIdentities
        func geometry(_ source: SCNGeometry,
                      materialChannel: ScreenDebugOptions.Channel) -> SCNGeometry {
            let key = ObjectIdentifier(source)
            usedGeometries.insert(key)
            let displayedMaterials = source.materials.map { source -> SCNMaterial in
                let key = ObjectIdentifier(source)
                usedMaterials.insert(key)
                let signature = FsceneRealizer.screenDebugMaterialSignature(source)
                if let cached = materials[key], cached.source === source,
                   cached.channel == materialChannel, cached.signature == signature {
                    return cached.displayed
                }
                let displayed = materialChannel == .none
                    ? source.copy() as! SCNMaterial
                    : FsceneRealizer.makeScreenDebugMaterial(
                        source, channel: materialChannel, host: host)
                materials[key] = Material(source: source, signature: signature,
                                          channel: materialChannel, displayed: displayed)
                return displayed
            }
            if let cached = geometries[key], cached.source === source,
               cached.materials.elementsEqual(displayedMaterials, by: { $0 === $1 }) {
                return cached.displayed
            }
            let displayed = source.copy() as! SCNGeometry
            displayed.materials = displayedMaterials
            geometries[key] = Geometry(source: source, materials: displayedMaterials,
                                       displayed: displayed)
            return displayed
        }
        func light(_ source: SCNLight) -> ScreenDebugFrame.Light {
            let key = ObjectIdentifier(source)
            usedLights.insert(key)
            let template: SCNLight
            if let cached = lights[key], cached.source === source {
                template = cached.template
            } else {
                template = source.copy() as! SCNLight
                template.removeAllAnimations()
                lights[key] = LightTemplate(source: source, template: template)
            }
            return ScreenDebugFrame.Light(template: template,
                                          state: ScreenDebugFrame.LightState(source))
        }
        func visit(_ source: SCNNode, parent: ObjectIdentifier?) {
            let key = ObjectIdentifier(source)
            captured.insert(key)
            let materialChannel: ScreenDebugOptions.Channel =
                shadowProxies.contains(key) ? .none : channel
            let pose = source.presentation
            let skin = source.skinner.map {
                skinNodes.append(contentsOf: $0.bones)
                if let skeleton = $0.skeleton { skinNodes.append(skeleton) }
                return ScreenDebugFrame.Skin(
                    identity: ObjectIdentifier($0),
                    geometry: geometry($0.baseGeometry!, materialChannel: materialChannel),
                    bones: $0.bones.map(ObjectIdentifier.init),
                    skeleton: $0.skeleton.map(ObjectIdentifier.init),
                    inverseBinds: $0.boneInverseBindTransforms,
                    weights: $0.boneWeights, indices: $0.boneIndices,
                    bind: $0.baseGeometryBindTransform)
            }
            let morph = source.morpher.map { current in
                ScreenDebugFrame.Morph(
                    identity: ObjectIdentifier(current), targets: current.targets,
                    weights: pose.morpher?.weights ?? current.weights,
                    mode: current.calculationMode, normals: current.unifiesNormals)
            }
            rows.append(ScreenDebugFrame.Node(
                identity: key, parent: parent, transform: pose.transform,
                pivot: pose.pivot, hidden: source.isHidden, opacity: pose.opacity,
                category: source.categoryBitMask, order: source.renderingOrder,
                castsShadow: source.castsShadow, light: source.light.map(light),
                geometry: source.geometry.map { geometry($0, materialChannel: materialChannel) },
                skin: skin, morph: morph))
            for child in source.childNodes { visit(child, parent: key) }
        }
        visit(scene.rootNode, parent: nil)
        func captureSkinPose(_ source: SCNNode) {
            let key = ObjectIdentifier(source)
            guard captured.insert(key).inserted else { return }
            if let parent = source.parent { captureSkinPose(parent) }
            let pose = source.presentation
            rows.append(ScreenDebugFrame.Node(
                identity: key, parent: source.parent.map(ObjectIdentifier.init),
                transform: pose.transform, pivot: pose.pivot,
                hidden: source.isHidden, opacity: pose.opacity,
                category: source.categoryBitMask, order: source.renderingOrder,
                castsShadow: source.castsShadow, light: nil,
                geometry: nil, skin: nil, morph: nil))
        }
        for node in skinNodes { captureSkinPose(node) }
        lights = lights.filter { usedLights.contains($0.key) }
        materials = materials.filter { usedMaterials.contains($0.key) }
        geometries = geometries.filter { usedGeometries.contains($0.key) }
        return ScreenDebugFrame(nodes: rows)
    }
}

final class ScreenDebugPresentation {
    let scene = SCNScene()
    private var nodes: [ObjectIdentifier: SCNNode] = [:]
    private struct LightSlot {
        let template: SCNLight
        let displayed: SCNLight
    }
    private var lights: [ObjectIdentifier: LightSlot] = [:]
    private var skins: [ObjectIdentifier: ScreenDebugFrame.Skin] = [:]
    private var morphs: [ObjectIdentifier: ScreenDebugFrame.Morph] = [:]

    func apply(_ frame: ScreenDebugFrame) {
        let live = Set(frame.nodes.map { $0.identity })
        for key in Array(nodes.keys) where !live.contains(key) {
            nodes.removeValue(forKey: key)?.removeFromParentNode()
            lights.removeValue(forKey: key)
            skins.removeValue(forKey: key)
            morphs.removeValue(forKey: key)
        }
        for row in frame.nodes where nodes[row.identity] == nil {
            nodes[row.identity] = SCNNode()
        }
        for row in frame.nodes {
            let node = nodes[row.identity]!
            let parent = row.parent.flatMap { nodes[$0] } ?? scene.rootNode
            if node.parent !== parent { parent.addChildNode(node) }
            node.transform = row.transform
            node.pivot = row.pivot
            node.isHidden = row.hidden
            node.opacity = row.opacity
            node.categoryBitMask = row.category
            node.renderingOrder = row.order
            node.castsShadow = row.castsShadow
            if let light = row.light {
                let slot: LightSlot
                if let prior = lights[row.identity], prior.template === light.template {
                    slot = prior
                } else {
                    slot = LightSlot(template: light.template,
                                     displayed: light.template.copy() as! SCNLight)
                    lights[row.identity] = slot
                    node.light = slot.displayed
                }
                light.state.apply(to: slot.displayed)
            } else {
                node.light = nil
                lights.removeValue(forKey: row.identity)
            }
            if let skin = row.skin {
                let prior = skins[row.identity]
                if prior?.identity != skin.identity || prior?.geometry !== skin.geometry
                    || prior?.bones != skin.bones || prior?.skeleton != skin.skeleton
                    || prior?.inverseBinds != skin.inverseBinds {
                    let skinner = SCNSkinner(
                        baseGeometry: skin.geometry,
                        bones: skin.bones.map { nodes[$0]! },
                        boneInverseBindTransforms: skin.inverseBinds,
                        boneWeights: skin.weights, boneIndices: skin.indices)
                    skinner.skeleton = skin.skeleton.flatMap { nodes[$0] }
                    node.skinner = skinner
                }
                node.skinner?.baseGeometryBindTransform = skin.bind
                skins[row.identity] = skin
            } else {
                node.skinner = nil
                skins.removeValue(forKey: row.identity)
            }
            if node.geometry !== row.geometry { node.geometry = row.geometry }
            if let morph = row.morph {
                let prior = morphs[row.identity]
                if prior?.identity != morph.identity
                    || !(prior?.targets.elementsEqual(morph.targets, by: { $0 === $1 }) ?? false) {
                    let morpher = SCNMorpher()
                    morpher.targets = morph.targets
                    node.morpher = morpher
                }
                node.morpher?.calculationMode = morph.mode
                node.morpher?.unifiesNormals = morph.normals
                node.morpher?.weights = morph.weights
                morphs[row.identity] = morph
            } else {
                node.morpher = nil
                morphs.removeValue(forKey: row.identity)
            }
        }
    }

    static func camera(_ source: SCNCamera) -> SCNCamera {
        let camera = source.copy() as! SCNCamera
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = CGFloat(log2(ToneMapTechnique.packGain))
        camera.whitePoint = CGFloat(ToneMapTechnique.whitePoint * ToneMapTechnique.packGain)
        camera.averageGray = 0.18
        camera.bloomIntensity = 0
        camera.screenSpaceAmbientOcclusionIntensity = 0
        camera.vignettingIntensity = 0
        camera.colorFringeIntensity = 0
        camera.colorFringeStrength = 0
        camera.grainIntensity = 0
        camera.whiteBalanceTemperature = 0
        camera.whiteBalanceTint = 0
        camera.minimumExposure = -15
        camera.maximumExposure = 15
        camera.motionBlurIntensity = 0
        camera.saturation = 1
        camera.contrast = 0
        camera.colorGrading.contents = nil
        camera.wantsDepthOfField = false
        return camera
    }
}

final class ScreenDebugWireframe {
    private weak var renderer: SCNSceneRenderer?
    private var previous = false

    func apply(_ enabled: Bool, to target: SCNSceneRenderer) {
        if !enabled { release(); return }
        if renderer !== target {
            release()
            renderer = target
            previous = target.debugOptions.contains(.showWireframe)
        }
        target.debugOptions.insert(.showWireframe)
    }

    func release() {
        if let renderer {
            if previous { renderer.debugOptions.insert(.showWireframe) }
            else { renderer.debugOptions.remove(.showWireframe) }
        }
        renderer = nil
    }
}
