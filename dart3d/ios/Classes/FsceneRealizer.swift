import CoreImage
import Foundation
import Metal
import MetalKit
import ModelIO
import SceneKit
import simd
import UIKit

/// Realizes a `.fscene` manifest (canonical JSON) into a live `SCNScene`.
///
/// The manifest shape mirrors `encodeDocument` in package:scene:
/// `resources`/`nodes`/`skins`/`animations`/`payloads` are id-token-keyed
/// maps, `roots` orders the root node ids, `stage` holds scene-wide
/// settings. Property values are single-key tagged objects
/// (`{'d': …}`, `{'c': [r,g,b,a]}`, `{'rref': token}`, …).
///
/// Component types mirror the upstream flutter_scene vocabulary so
/// documents stay interchangeable: `mesh`, `camera`, `directionalLight`,
/// `pointLight`, `spotLight`, `rectAreaLight`,
/// `rigidBody`, `collider`, `physicsWorld`. Unknown types log and skip —
/// a document never fails to load over an unsupported component.
enum FsceneRealizer {

    // MARK: - Entry

    /// Replaces `host`'s scene with the realized manifest. Payload-backed
    /// resources whose bytes have not arrived stay deferred and are
    /// re-realized when a payload lands (`SceneViewHost.applyPayload`).
    static func realize(manifest: Data, into host: SceneViewHost) {
        guard let json = try? JSONSerialization.jsonObject(with: manifest)
                as? [String: Any] else {
            d3Log("loadScene: manifest is not a JSON object"); return
        }

        let version = (json["fscene"] as? NSNumber)?.intValue ?? 5
        let ctx = Context(host: host, formatVersion: version)
        // W12: the installing document re-declares its component
        // joints — drop the previous document's registrations so a
        // re-install never duplicates them.
        host.beginComponentJointRegistration()
        ctx.decodePayloadSpecs(json["payloads"] as? [String: Any] ?? [:])
        ctx.decodeResources(json["resources"] as? [String: Any] ?? [:])
        ctx.decodeNodes(json["nodes"] as? [String: Any] ?? [:])
        ctx.decodeSkins(json["skins"] as? [String: Any] ?? [:])
        ctx.decodeAnimations(json["animations"] as? [String: Any] ?? [:])
        ctx.attachRoots(json["roots"] as? [Any] ?? [])
        ctx.resolveSkinAttachments()
        ctx.decodePhysicsDeferred()
        ctx.applyVariantComponents()
        ctx.decodeStage(json["stage"] as? [String: Any])
        // W14: view decode runs after stage (it needs nothing from it,
        // but the rt records and node registry must already exist).
        ctx.decodeViews(json["views"])
        ctx.installScene()
    }

    /// A realized texture: the `UIImage` material slots bind plus, for
    /// `rgba8` payloads, the straight-alpha source pixels so factor
    /// bakes and channel splits skip a GPU round-trip. Encoded
    /// containers and `ref` assets leave `rgba` nil — `sourcePixels`
    /// re-decodes the image when a slot needs raw bytes.
    ///
    /// W21: `mtlTexture` carries a Metal-side copy when one was
    /// uploaded — a KTX2 container decode (which may be the ONLY
    /// realized form, e.g. ASTC blocks with no CPU image) or the
    /// renormalized mip chain sRGB sources get. `image` is nil for
    /// GPU-only textures, and `contents` is what a slot binds.
    struct DecodedTexture {
        let key: UInt64
        let image: UIImage?      // nil on GPU-only (compressed) decodes
        let mtlTexture: MTLTexture?
        let rgba: Data?          // straight RGBA8, rgba8 payloads only
        let width: Int
        let height: Int
        let content: String      // 'color' | 'data' | 'normal'

        /// What a material slot binds: the MTLTexture when one exists
        /// (it carries the mip chain), else the UIImage.
        var contents: Any? { mtlTexture ?? image }
    }

    /// One material slot's texture dependency. `upsertResource`
    /// re-applies every recorded binding so a texture swap re-does the
    /// factor bake; `materialKey` reaches back into `resourceDefs` for
    /// the material's raw properties (the factors).
    struct TextureBinding {
        let material: SCNMaterial
        let materialKey: UInt64
        let slot: String         // wire name: 'baseColorTexture', …
    }

    /// An equirect environment image in the upstream (.fscene, LH)
    /// convention: row 0 is the up pole (+y), column u maps longitude
    /// (u−0.5)·2π with dirX=cosLat·cos(λ), dirZ=cosLat·sin(λ). Two
    /// storages: sRGB-encoded RGBA8 bytes (LDR and generated sources)
    /// or linear float32 RGBA (Radiance HDR payloads).
    struct EnvPixels {
        var width: Int
        var height: Int
        var isFloat: Bool       // false → sRGB8 bytes, true → RGBA float32
        var data: Data
    }

    /// W12: one decoded `materialsVariants` binding — upstream's
    /// `MaterialsVariantBinding` shape: the target node + primitive
    /// index, the declared default material ref, and the variant-index
    /// → material-ref map. `resolved` records the applied state (the
    /// geometry/material actually written + the default in force after
    /// the rebase rule), so a select can restore the right material
    /// and a mesh-material rebind can rebase onto it.
    struct VariantBindingSpec {
        let nodeKey: UInt64
        let primitive: Int
        let defaultMaterialKey: UInt64?
        let materialsByVariant: [Int: UInt64]
        /// Last material this binding wrote (nil until first apply).
        var applied: SCNMaterial?
        /// The default currently in force — the declared default, or
        /// a mesh material the rebase rule adopted.
        var defaultMaterial: SCNMaterial?
        /// False while the target node/geometry hasn't resolved — the
        /// landing retries re-attempt it.
        var resolved = false
    }

    /// W12: a decoded `materialsVariants` component — the variant name
    /// list, the selected name, and the (possibly still-unresolved)
    /// bindings.
    struct VariantComponentSpec {
        let nodeKey: UInt64
        let compIndex: Int
        var variants: [String]
        var selected: String?
        var bindings: [VariantBindingSpec]
    }

    /// A decoded `skins` entry (W11): joint node keys in authored order,
    /// the per-joint inverse-bind matrices (already z-mirrored, identity
    /// when the `matrices` payload is absent — upstream's null-tolerant
    /// rule), and the optional skeleton root key. A null joint upstream
    /// renders as identity — `attachSkin` substitutes a detached node
    /// for unresolved joints and keeps the consumer pending.
    struct DecodedSkin {
        var jointKeys: [UInt64]
        var ibms: [SCNMatrix4]
        var skeletonKey: UInt64?
        var awaitingIBM: Bool
    }

    /// A decoded `morphTargets` block (W11): absolute target geometries
    /// (`base + delta`, positions always, normals/tangents when the
    /// spec declares those slabs), the mesh `defaultWeights`, and the
    /// target count. Keyed by the geometry id, like `geometries`.
    struct DecodedMorph {
        var targets: [SCNGeometry]
        var defaultWeights: [Float]
        var targetCount: Int
    }

    /// One animation channel's decoded timeline + values, converted to
    /// SceneKit space at decode: translation negates z, rotation takes
    /// the pseudovector map (−x,−y,z,w), scale and weights pass through.
    /// `vec3`/`quat`/`weights` are populated by kind; `times` is f32
    /// seconds widened to Double.
    struct DecodedChannel {
        enum Kind { case translation, rotation, scale, weights }
        var target: UInt64
        var targetName: String?
        var kind: Kind
        var times: [Double] = []
        var vec3: [simd_float3] = []
        var quat: [simd_quatf] = []
        var weights: [Float] = []
        var targetCount = 0
    }

    /// A decoded `animations` entry (W11): the channels plus
    /// `endTime` (max channel last-key — upstream's
    /// `Animation.endTime`). The doc's clips aren't created until an
    /// `anim` op asks (no autoplay).
    struct DecodedAnimation {
        var name: String
        var channels: [DecodedChannel]
        var endTime: Double
    }

    // MARK: - Context

    final class Context {
        typealias PayloadSpec =
            (encoding: String, layout: String?, format: String?,
             width: Int?, height: Int?, length: Int?)

        let host: SceneViewHost
        let formatVersion: Int
        let scene: SCNScene
        var nodes: [UInt64: SCNNode] = [:]
        var geometries: [UInt64: SCNGeometry] = [:]
        var materials: [UInt64: SCNMaterial] = [:]
        var textures: [UInt64: DecodedTexture] = [:]
        var environments: [UInt64: [String: Any]] = [:]
        var payloadSpecs: [UInt64: PayloadSpec] = [:]
        var deferredResourceIds: Set<UInt64> = []
        var firstCameraNode: SCNNode?
        var dynamicBodyKeys: Set<UInt64> = []

        /// Node key → index of its `collider` component inside the
        /// spec's `components` array — the `ca`/`cb`/`collider` fields
        /// W8 contact events and query hits report (absent → 0).
        var colliderIndexByKey: [UInt64: Int] = [:]

        /// Raw manifest entry per resource id — the surgical ops
        /// (`upsertResource`, `upsertPayload`) re-decode a single
        /// resource out of this map, and slot rebinding reads material
        /// factors back out of it.
        var resourceDefs: [UInt64: [String: Any]] = [:]

        /// Texture id → every (material, slot) that consumed it — a
        /// texture `upsertResource` re-applies each binding.
        var textureConsumers: [UInt64: [TextureBinding]] = [:]

        /// Material id → geometries whose `.materials` reference it —
        /// a material `upsertResource` re-attaches the re-decoded
        /// material on each.
        var materialConsumers: [UInt64: [SCNGeometry]] = [:]

        /// Geometry id → every node whose mesh consumed it — a
        /// geometry `upsertResource`/`upsertPayload` re-decodes the
        /// resource and swaps the result onto each consumer's
        /// `.geometry`. Recorded at `decodeMesh` even when the
        /// geometry is still unresolved, so a deferred resource
        /// rebinds when its payload lands.
        var geometryConsumers: [UInt64: [SCNNode]] = [:]

        /// Texture id → payload id backing it, so an `upsertPayload`
        /// chunk can find the textures it unblocks.
        var texturePayloadKeys: [UInt64: UInt64] = [:]

        /// Geometry id → the payload ids backing it (vertices plus
        /// indices), so an `upsertPayload` chunk can find the
        /// geometries it unblocks.
        var geometryPayloadKeys: [UInt64: Set<UInt64>] = [:]

        /// Environment id → payload id backing its equirect source,
        /// so an `upsertPayload` chunk can re-run `decodeStage` on the
        /// env it unblocks (W7).
        var environmentPayloadKeys: [UInt64: UInt64] = [:]

        /// Decoded `skins` entries (W11) — joint keys, IBMs, optional
        /// skeleton. Populated by `decodeSkins` after the node pass.
        var skins: [UInt64: DecodedSkin] = [:]

        /// Decoded `animations` entries (W11) — the defs the `anim`
        /// op instantiates clips from.
        var animations: [UInt64: DecodedAnimation] = [:]

        /// Geometry id → absolute morph targets for `SCNMorpher` (W11).
        var morphTargets: [UInt64: DecodedMorph] = [:]

        /// Node key → its `skin` member's skin key (W11) — the node's
        /// declared binding, tracked separately from the attached
        /// `SCNSkinner` so skin removal/upsert can re-drive it.
        var nodeSkinKeys: [UInt64: UInt64] = [:]

        /// Nodes whose skinner attach isn't fully resolved (geometry
        /// pending, joint nodes missing, skeleton unresolved, IBM
        /// payload in flight) — retried on node landings and payload
        /// arrivals, the W9-deferred-joint pattern.
        var pendingSkinNodes: Set<UInt64> = []

        /// Skin id → its `inverseBindMatrices` payload key, so an
        /// `upsertPayload` chunk re-decodes the skin it unblocks.
        var skinPayloadKeys: [UInt64: UInt64] = [:]

        /// Animation id → its channels' payload keys (timelines +
        /// keyframes), so an `upsertPayload` chunk re-decodes the
        /// animation it unblocks.
        var animPayloadKeys: [UInt64: Set<UInt64>] = [:]

        /// Raw manifest entries per skin/animation id — the surgical
        /// ops (`upsertSkin`, `upsertAnimation`, `upsertPayload`)
        /// re-decode a single entry out of these, like `resourceDefs`.
        var skinDefs: [UInt64: [String: Any]] = [:]
        var animDefs: [UInt64: [String: Any]] = [:]

        /// Set on surgical contexts (seeded from live registries): node
        /// lookups fall back to `host.nodesById`. Manifest decode leaves
        /// it false — `nodes` is the new scene's complete map, and the
        /// host registry still holds the OLD scene's nodes then.
        var resolvesLiveNodes = false

        /// The last `stage` JSON decoded — `updateStage` ops and
        /// payload-arrival re-decodes replay it against the live scene.
        var stageJSON: [String: Any]? = nil

        /// Linear pre-tonemap exposure from the decoded environment —
        /// the caller applies it to the view camera (`exposureOffset =
        /// log2(exposure)`, `wantsHDR = true`) once `pointOfView` is
        /// known (after `install`, or live for `updateStage`).
        var stageExposure: Double = 1.0

        /// Set by `decodeStage` when the env's equirect payload hasn't
        /// arrived — the stage application defers env/skybox contents
        /// and re-runs on payload arrival (W4 deferral pattern).
        var stageEnvDeferred = false

        /// W13: the env resource's decoded `effects` post stack — nil
        /// when the wire key is absent ("don't touch live settings"),
        /// wholesale-decoded when present. The host applies it to the
        /// point-of-view camera and scene after install / on
        /// `updateStage` (retention rule: absent → keep prior values).
        var stageEffects: StageEffects? = nil

        /// W14: `rt:` render-target records decoded from
        /// `kind:'renderTexture'` resources — the Metal texture pair
        /// plus update/sampling spec; the decoded `views` attach to
        /// them at the host's `installViews`.
        var renderTargets: [UInt64: RenderTargetRec] = [:]

        /// W14: the decoded top-level `views` list — wholesale-
        /// replaced by `decodeViews` on both the manifest path and the
        /// `updateViews` op.
        var views: [ViewRec] = []

        /// W14 stage quality fields — decoded off `stage` itself (NOT
        /// the env resource). `antiAliasing` 'auto' defers to
        /// viewConfig; `filterQuality` has no SceneKit counterpart.
        var stageAntiAliasing = "auto"
        var stageRenderScale = 1.0
        var stageFilterQuality = "medium"

        /// Physics components deferred until after mesh decode — a
        /// `convexHull`/`concaveMesh` collider reads the node's geometry,
        /// and a body reads its collider, so neither can be built inline.
        var physicsDeferred:
            [(key: UInt64, node: SCNNode, type: String, props: [String: Any])] =
            []

        /// W12 declarative joint components — translated to the wire
        /// joint shape and registered under a reserved handle range in
        /// `decodePhysicsDeferred` (bodies must exist first, and an
        /// `otherNode` may land after the declaring node).
        var jointComponentsDeferred:
            [(key: UInt64, index: Int, type: String, props: [String: Any])] =
            []

        /// W12: components decoded with `enabled:false` — nodeKey →
        /// component indices. Upstream `Component.enabled` gates the
        /// component's update/fixedUpdate callbacks only; dart3d's
        /// realized components have no per-component tick surface, so
        /// the flag is recorded (for parity reporting and any future
        /// tick-bearing component) rather than applied to the render,
        /// light or physics state.
        var disabledComponents: [UInt64: Set<Int>] = [:]

        /// W12: decoded `materialsVariants` components — component
        /// node key → the spec. Bindings resolve against `nodes`/
        /// `geometries` lazily at apply time (an unresolved binding is
        /// retried on node/geometry landings, like a deferred payload
        /// claim).
        var variantComponents: [UInt64: VariantComponentSpec] = [:]

        /// `scene` defaults to a fresh scene for the manifest path; the
        /// surgical ops pass the host's live scene so a `physicsWorld`
        /// component or a `pointOfView` camera lands on the real graph.
        init(host: SceneViewHost, formatVersion: Int,
             scene: SCNScene = SCNScene()) {
            self.host = host
            self.formatVersion = formatVersion
            self.scene = scene
        }

        func installScene() {
            host.install(scene: scene, nodes: nodes,
                         resources: (geometries: geometries,
                                     materials: materials,
                                     textures: textures,
                                     defs: resourceDefs,
                                     payloadSpecs: payloadSpecs,
                                     textureConsumers: textureConsumers,
                                     materialConsumers: materialConsumers,
                                     geometryConsumers: geometryConsumers,
                                     texturePayloadKeys: texturePayloadKeys,
                                     geometryPayloadKeys: geometryPayloadKeys,
                                     environmentPayloadKeys:
                                        environmentPayloadKeys,
                                     skins: skins,
                                     animations: animations,
                                     morphTargets: morphTargets,
                                     nodeSkinKeys: nodeSkinKeys,
                                     pendingSkinNodes: pendingSkinNodes,
                                     skinPayloadKeys: skinPayloadKeys,
                                     animPayloadKeys: animPayloadKeys,
                                     skinDefs: skinDefs,
                                     animDefs: animDefs,
                                     variantComponents:
                                        variantComponents,
                                     disabledComponents:
                                        disabledComponents,
                                     renderTargets: renderTargets),
                         deferred: deferredResourceIds,
                         camera: firstCameraNode,
                         dynamicBodies: dynamicBodyKeys,
                         colliderIndices: colliderIndexByKey,
                         formatVersion: formatVersion,
                         stage: (json: stageJSON, exposure: stageExposure,
                                 effects: stageEffects,
                                 antiAliasing: stageAntiAliasing,
                                 renderScale: stageRenderScale,
                                 filterQuality: stageFilterQuality),
                         views: views)
        }

        // MARK: Resources

        func decodePayloadSpecs(_ map: [String: Any]) {
            for (token, any) in map {
                guard let key = D3Wire.localIdKey(token),
                      let spec = any as? [String: Any],
                      let encoding = spec["encoding"] as? String else {
                    d3Log("payload spec '\(token)' is malformed")
                    continue
                }
                payloadSpecs[key] = (
                    encoding, spec["layout"] as? String,
                    spec["format"] as? String,
                    (spec["width"] as? NSNumber)?.intValue,
                    (spec["height"] as? NSNumber)?.intValue,
                    (spec["length"] as? NSNumber)?.intValue)
            }
        }

        func decodeResources(_ map: [String: Any]) {
            // Textures decode ahead of every other kind: material slots
            // resolve texture refs at material-decode time and map
            // iteration order is arbitrary. Raw defs are retained for
            // the surgical ops (upsertResource/upsertPayload), which
            // re-decode a single resource out of `resourceDefs`.
            var rest: [(UInt64, [String: Any])] = []
            for (token, any) in map {
                guard let key = D3Wire.localIdKey(token),
                      let r = any as? [String: Any],
                      let kind = r["kind"] as? String else { continue }
                resourceDefs[key] = r
                if kind == "texture" {
                    decodeTexture(key, r)
                } else if kind == "renderTexture" {
                    // W14: decode with the textures so material slots
                    // resolve rt refs in the rest pass below.
                    decodeRenderTexture(key, r)
                } else {
                    rest.append((key, r))
                }
            }
            for (key, r) in rest {
                switch r["kind"] as? String ?? "" {
                case "geometry":   decodeGeometry(key, r)
                case "material":   decodeMaterial(key, r)
                case "environment":
                    // Retained raw — `decodeStage` consumes the entry
                    // the stage's `environmentRef` names, and the
                    // surgical ops rebuild `environments` from
                    // `resourceDefs`.
                    environments[key] = r
                default:
                    d3Log("unknown resource kind "
                        + "'\(r["kind"] ?? "<absent>")'")
                }
            }
        }

        struct DecodedVertices {
            var positions: [Float] = []
            var normals: [Float] = []
            var uv0: [Float] = []
            /// TEXCOORD_1 — populated only by the `*_uv1_tangent`
            /// layouts; lands as the geometry's second `.texcoord`
            /// source so `mappingChannel` 1 selects it.
            var uv1: [Float] = []
            var colors: [Float] = []
            var tangents: [Float] = []
            /// JOINTS — the four bone indices per vertex the
            /// `skinned*` layouts carry as f32 (converted to int32 for
            /// the `.boneIndices` source). Empty on unskinned layouts.
            var boneIndices: [Int32] = []
            /// WEIGHTS — four bone weights per vertex (`.boneWeights`).
            var boneWeights: [Float] = []
            let count: Int
            let nativeSpace: Bool

            init(count: Int, nativeSpace: Bool) {
                self.count = count
                self.nativeSpace = nativeSpace
                positions.reserveCapacity(count * 3)
                normals.reserveCapacity(count * 3)
                uv0.reserveCapacity(count * 2)
                colors.reserveCapacity(count * 4)
                tangents.reserveCapacity(count * 4)
            }
        }

        enum ElementResult {
            case ready(SCNGeometryElement)
            case deferred
            case invalid
        }

        /// Stored bytes must match the manifest's declared `length` —
        /// a mismatch means the chunk under `payloadKey` isn't this
        /// document's (a stale key from a previous doc, or a partial
        /// write), so the consumer defers until the real chunk lands
        /// rather than decoding garbage. Undeclared lengths pass.
        func payloadLengthMatches(
            _ key: UInt64, payloadKey: UInt64,
            spec: PayloadSpec, bytes: Data
        ) -> Bool {
            guard let declared = spec.length else { return true }
            if declared == bytes.count { return true }
            host.logOnce("geometry.\(key).payloadLen.\(payloadKey)",
                "geometry \(key): payload \(payloadKey) is "
                + "\(bytes.count) B, manifest declares \(declared) B — "
                + "awaiting real chunk")
            return false
        }

        func decodeGeometry(_ key: UInt64, _ r: [String: Any]) {
            if let proc = r["procedural"] as? [String: Any],
               let shape = proc["shape"] as? String {
                geometries[key] = procedural(shape, proc)
                return
            }
            guard let token = r["vertices"] as? String,
                  let payloadKey = D3Wire.localIdKey(token) else {
                host.logOnce("geometry.\(key).vertices",
                    "geometry \(key): missing or invalid vertices payload token")
                return
            }
            // Record the claim before resolution — an `upsertPayload`
            // chunk re-decodes every geometry that references it.
            geometryPayloadKeys[key, default: []].insert(payloadKey)
            guard let spec = payloadSpecs[payloadKey] else {
                host.logOnce("geometry.\(key).vertexSpec",
                    "geometry \(key): vertices payload has no spec")
                return
            }
            guard spec.encoding == "vertexBuffer" else {
                host.logOnce("geometry.\(key).vertexEncoding",
                    "geometry \(key): vertices payload encoding "
                    + "'\(spec.encoding)' is not vertexBuffer")
                return
            }
            guard let bytes = host.payloadStore[payloadKey],
                  payloadLengthMatches(key, payloadKey: payloadKey,
                                       spec: spec, bytes: bytes) else {
                deferredResourceIds.insert(key)
                host.logOnce("geometry.\(key).awaiting",
                    "geometry \(key): awaiting payload")
                return
            }

            let started = DispatchTime.now().uptimeNanoseconds
            guard let decoded = decodeVertexPayload(
                bytes, layout: spec.layout, geometryKey: key) else { return }
            guard case let .ready(element) = decodeGeometryElement(
                key, r, vertexCount: decoded.count,
                nativeSpace: decoded.nativeSpace) else { return }

            var sources = [
                floatSource(decoded.positions, .vertex, decoded.count, 3),
                floatSource(decoded.normals, .normal, decoded.count, 3),
                floatSource(decoded.uv0, .texcoord, decoded.count, 2),
                floatSource(decoded.colors, .color, decoded.count, 4),
                floatSource(decoded.tangents, .tangent, decoded.count, 4),
            ]
            // W21: a second `.texcoord` source is UV set 1 —
            // `SCNMaterialProperty.mappingChannel` indexes texcoord
            // sources in declaration order.
            if decoded.uv1.count == decoded.count * 2 {
                sources.append(
                    floatSource(decoded.uv1, .texcoord, decoded.count, 2))
            }
            if decoded.boneWeights.count == decoded.count * 4,
               decoded.boneIndices.count == decoded.count * 4 {
                sources.append(floatSource(
                    decoded.boneWeights, .boneWeights, decoded.count, 4))
                sources.append(intSource(
                    decoded.boneIndices, .boneIndices, decoded.count, 4))
            }
            let geometry = SCNGeometry(sources: sources, elements: [element])
            if let bounds = decodeBounds(r["bounds"],
                                         nativeSpace: decoded.nativeSpace) {
                geometry.boundingBox = bounds
            }
            if let morph = r["morphTargets"] as? [String: Any] {
                decodeMorphTargets(key, morph, decoded: decoded,
                                   element: element)
            } else if r["morphTargets"] != nil {
                host.logOnce("geometry.\(key).morphTargets",
                    "geometry \(key): malformed morphTargets block")
            }
            geometries[key] = geometry

            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started)
                / 1_000_000.0
            d3Log("geometry \(key): decoded \(decoded.count) verts in "
                + "\(String(format: "%.2f", elapsed))ms")
        }

        func decodeVertexPayload(_ data: Data, layout rawLayout: String?,
                                 geometryKey key: UInt64)
            -> DecodedVertices?
        {
            let layout = rawLayout ?? "unskinned"
            let stride: Int
            switch layout {
            case "unskinned_uv1_tangent", "unskinned_soa_uv1_tangent":
                stride = 72
            case "skinned_uv1_tangent":
                stride = 104
            case "unskinned", "unskinned_soa":
                stride = 48
            case "skinned":
                stride = 80
            case "p3t4":
                stride = 28
            default:
                host.logOnce("geometry.\(key).layout.\(layout)",
                    "geometry \(key): unknown vertex layout '\(layout)'")
                return nil
            }
            guard !data.isEmpty else {
                host.logOnce("geometry.\(key).emptyVertices",
                    "geometry \(key): vertex payload is empty")
                return nil
            }
            guard data.count % stride == 0 else {
                host.logOnce("geometry.\(key).stride.\(layout)",
                    "geometry \(key): layout '\(layout)' stride \(stride) "
                    + "does not divide \(data.count) bytes")
                return nil
            }

            let count = data.count / stride
            var out = DecodedVertices(count: count,
                                      nativeSpace: layout == "p3t4")
            func f(_ offset: Int) -> Float {
                D3Wire.f32LE(data, data.startIndex + offset)
            }
            func appendPosition(_ offset: Int, mirror: Bool = true) {
                out.positions.append(f(offset))
                out.positions.append(f(offset + 4))
                out.positions.append(mirror ? -f(offset + 8) : f(offset + 8))
            }
            func appendNormal(_ offset: Int, mirror: Bool = true) {
                out.normals.append(f(offset))
                out.normals.append(f(offset + 4))
                out.normals.append(mirror ? -f(offset + 8) : f(offset + 8))
            }
            func appendUv(_ offset: Int) {
                out.uv0.append(f(offset))
                out.uv0.append(f(offset + 4))
            }
            func appendUv1(_ offset: Int) {
                out.uv1.append(f(offset))
                out.uv1.append(f(offset + 4))
            }
            func appendColor(_ offset: Int) {
                for j in 0..<4 { out.colors.append(f(offset + j * 4)) }
            }
            func appendTangent(_ offset: Int) {
                out.tangents.append(f(offset))
                out.tangents.append(f(offset + 4))
                out.tangents.append(-f(offset + 8))
                out.tangents.append(-f(offset + 12))
            }
            func appendNeutralTangent() {
                out.tangents.append(contentsOf: [1, 0, 0, -1])
            }
            // JOINTS are f32 on the wire; the `.boneIndices` source takes
            // integer components (upstream stores them float-typed but the
            // values are whole).
            func appendJoints(_ offset: Int) {
                for j in 0..<4 {
                    out.boneIndices.append(
                        Int32(clamping: max(0, Int(f(offset + j * 4)
                            .rounded()))))
                }
            }
            func appendWeights(_ offset: Int) {
                for j in 0..<4 { out.boneWeights.append(f(offset + j * 4)) }
            }

            switch layout {
            case "unskinned_uv1_tangent", "skinned_uv1_tangent":
                let skinned = layout == "skinned_uv1_tangent"
                if skinned {
                    out.boneIndices.reserveCapacity(count * 4)
                    out.boneWeights.reserveCapacity(count * 4)
                }
                out.uv1.reserveCapacity(count * 2)
                for i in 0..<count {
                    let base = i * stride
                    appendPosition(base)
                    appendNormal(base + 12)
                    appendUv(base + 24)
                    appendUv1(base + 32)
                    appendColor(base + 40)
                    appendTangent(base + 56)
                    if skinned {
                        appendJoints(base + 72)
                        appendWeights(base + 88)
                    }
                }
            case "unskinned_soa_uv1_tangent":
                let normalBase = count * 12
                let uv0Base = normalBase + count * 12
                let uv1Base = uv0Base + count * 8
                let colorBase = uv1Base + count * 8
                let tangentBase = colorBase + count * 16
                out.uv1.reserveCapacity(count * 2)
                for i in 0..<count {
                    appendPosition(i * 12)
                    appendNormal(normalBase + i * 12)
                    appendUv(uv0Base + i * 8)
                    appendUv1(uv1Base + i * 8)
                    appendColor(colorBase + i * 16)
                    appendTangent(tangentBase + i * 16)
                }
            case "unskinned", "skinned":
                let skinned = layout == "skinned"
                if skinned {
                    out.boneIndices.reserveCapacity(count * 4)
                    out.boneWeights.reserveCapacity(count * 4)
                }
                for i in 0..<count {
                    let base = i * stride
                    appendPosition(base)
                    appendNormal(base + 12)
                    appendUv(base + 24)
                    appendColor(base + 32)
                    appendNeutralTangent()
                    if skinned {
                        appendJoints(base + 48)
                        appendWeights(base + 64)
                    }
                }
            case "unskinned_soa":
                let normalBase = count * 12
                let uvBase = normalBase + count * 12
                let colorBase = uvBase + count * 8
                for i in 0..<count {
                    appendPosition(i * 12)
                    appendNormal(normalBase + i * 12)
                    appendUv(uvBase + i * 8)
                    appendColor(colorBase + i * 16)
                    appendNeutralTangent()
                }
            case "p3t4":
                for i in 0..<count {
                    let base = i * stride
                    appendPosition(base, mirror: false)
                    let x = f(base + 12), y = f(base + 16)
                    let z = f(base + 20), w = f(base + 24)
                    let norm = x * x + y * y + z * z + w * w
                    let s: Float = norm > 0 ? 2 / norm : 0
                    out.tangents.append(1 - s * (y * y + z * z))
                    out.tangents.append(s * (x * y + z * w))
                    out.tangents.append(s * (x * z - y * w))
                    out.tangents.append(1)
                    out.normals.append(s * (x * z + y * w))
                    out.normals.append(s * (y * z - x * w))
                    out.normals.append(1 - s * (x * x + y * y))
                    out.uv0.append(contentsOf: [0, 0])
                    out.colors.append(contentsOf: [1, 1, 1, 1])
                }
            default:
                return nil
            }
            return out
        }

        func decodeGeometryElement(
            _ key: UInt64, _ r: [String: Any], vertexCount: Int,
            nativeSpace: Bool
        ) -> ElementResult {
            let topology = r["topology"] as? String ?? "triangle"
            let primitiveType: SCNGeometryPrimitiveType
            switch topology {
            case "triangle":      primitiveType = .triangles
            case "triangleStrip": primitiveType = .triangleStrip
            case "lineStrip":     primitiveType = .line
            // `.line` is unconnected pairs — upstream 'line' is already
            // pairs; 'lineStrip' is expanded below.
            case "line":          primitiveType = .line
            case "point":         primitiveType = .point
            default:
                host.logOnce("geometry.\(key).topology.\(topology)",
                    "geometry \(key): unknown topology '\(topology)'")
                return .invalid
            }

            var indices: [UInt32] = []
            var bytesPerIndex: Int
            let indexed = r["indices"] != nil
            if indexed {
                guard let token = r["indices"] as? String,
                      let payloadKey = D3Wire.localIdKey(token) else {
                    host.logOnce("geometry.\(key).indices",
                        "geometry \(key): invalid indices payload token")
                    return .invalid
                }
                geometryPayloadKeys[key, default: []].insert(payloadKey)
                guard let spec = payloadSpecs[payloadKey] else {
                    host.logOnce("geometry.\(key).indexSpec",
                        "geometry \(key): indices payload has no spec")
                    return .invalid
                }
                guard spec.encoding == "indexBuffer" else {
                    host.logOnce("geometry.\(key).indexEncoding",
                        "geometry \(key): indices payload encoding "
                        + "'\(spec.encoding)' is not indexBuffer")
                    return .invalid
                }
                let format = spec.format ?? "uint16"
                switch format {
                case "uint16": bytesPerIndex = 2
                case "uint32": bytesPerIndex = 4
                default:
                    host.logOnce("geometry.\(key).indexFormat.\(format)",
                        "geometry \(key): unknown index format '\(format)'")
                    return .invalid
                }
                guard let data = host.payloadStore[payloadKey],
                      payloadLengthMatches(key, payloadKey: payloadKey,
                                           spec: spec, bytes: data) else {
                    deferredResourceIds.insert(key)
                    host.logOnce("geometry.\(key).awaiting",
                        "geometry \(key): awaiting payload")
                    return .deferred
                }
                guard !data.isEmpty, data.count % bytesPerIndex == 0 else {
                    host.logOnce("geometry.\(key).indexStride",
                        "geometry \(key): index payload size \(data.count) "
                        + "is invalid for \(format)")
                    return .invalid
                }
                indices.reserveCapacity(data.count / bytesPerIndex)
                for offset in stride(from: 0, to: data.count,
                                     by: bytesPerIndex) {
                    if bytesPerIndex == 2 {
                        let lo = UInt16(data[data.startIndex + offset])
                        let hi = UInt16(data[data.startIndex + offset + 1])
                        indices.append(UInt32(lo | hi << 8))
                    } else {
                        indices.append(D3Wire.u32LE(
                            data, data.startIndex + offset))
                    }
                }
            } else {
                bytesPerIndex = vertexCount <= Int(UInt16.max) ? 2 : 4
                indices = (0..<vertexCount).map(UInt32.init)
            }

            if !nativeSpace {
                if topology == "triangle", indexed {
                    let legacy = (r["legacyWinding"] as? Bool == true)
                        || formatVersion < 5
                    if !legacy {
                        for i in stride(from: 0, to: indices.count - 2, by: 3) {
                            indices.swapAt(i + 1, i + 2)
                        }
                    }
                } else {
                    host.logOnce("geometry.\(key).winding.\(topology).\(indexed)",
                        "geometry \(key): winding migration does not apply "
                        + "to \(indexed ? topology : "non-indexed") geometry")
                }
            }

            // `.line` takes pairs; a strip index list expands to pairs.
            if topology == "lineStrip" {
                var pairs: [UInt32] = []
                if indices.count >= 2 {
                    pairs.reserveCapacity((indices.count - 1) * 2)
                    for i in 0..<(indices.count - 1) {
                        pairs.append(indices[i]); pairs.append(indices[i + 1])
                    }
                }
                indices = pairs
            }
            let primitiveCount: Int
            switch topology {
            case "triangle":
                guard indices.count % 3 == 0 else {
                    host.logOnce("geometry.\(key).triangleIndices",
                        "geometry \(key): triangle index count is not "
                        + "divisible by 3")
                    return .invalid
                }
                primitiveCount = indices.count / 3
            case "triangleStrip": primitiveCount = max(indices.count - 2, 0)
            case "line", "lineStrip": primitiveCount = indices.count / 2
            case "point": primitiveCount = indices.count
            default: return .invalid
            }
            guard primitiveCount > 0 else {
                host.logOnce("geometry.\(key).emptyElements",
                    "geometry \(key): topology '\(topology)' has no primitives")
                return .invalid
            }

            var elementData = Data(capacity: indices.count * bytesPerIndex)
            for index in indices {
                if bytesPerIndex == 2 {
                    guard index <= UInt32(UInt16.max) else {
                        host.logOnce("geometry.\(key).indexOverflow",
                            "geometry \(key): uint16 index exceeds 65535")
                        return .invalid
                    }
                    var value = UInt16(index).littleEndian
                    withUnsafeBytes(of: &value) {
                        elementData.append(contentsOf: $0)
                    }
                } else {
                    var value = index.littleEndian
                    withUnsafeBytes(of: &value) {
                        elementData.append(contentsOf: $0)
                    }
                }
            }
            return .ready(SCNGeometryElement(
                data: elementData, primitiveType: primitiveType,
                primitiveCount: primitiveCount, bytesPerIndex: bytesPerIndex))
        }

        func floatSource(_ values: [Float],
                         _ semantic: SCNGeometrySource.Semantic,
                         _ count: Int, _ components: Int) -> SCNGeometrySource {
            let data = values.withUnsafeBufferPointer {
                Data(bytes: $0.baseAddress!,
                     count: $0.count * MemoryLayout<Float>.size)
            }
            return SCNGeometrySource(
                data: data, semantic: semantic, vectorCount: count,
                usesFloatComponents: true, componentsPerVector: components,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: components * MemoryLayout<Float>.size)
        }

        /// Integer-component source — the `.boneIndices` lane of a
        /// skinned geometry. SceneKit caps bone index components at
        /// 2 bytes, so the f32-decoded indices pack as uint16.
        func intSource(_ values: [Int32],
                       _ semantic: SCNGeometrySource.Semantic,
                       _ count: Int, _ components: Int) -> SCNGeometrySource {
            var packed = [UInt16](repeating: 0, count: values.count)
            for i in values.indices {
                packed[i] = UInt16(clamping: max(values[i], 0))
            }
            let data = packed.withUnsafeBufferPointer {
                Data(bytes: $0.baseAddress!,
                     count: $0.count * MemoryLayout<UInt16>.size)
            }
            return SCNGeometrySource(
                data: data, semantic: semantic, vectorCount: count,
                usesFloatComponents: false,
                componentsPerVector: components,
                bytesPerComponent: MemoryLayout<UInt16>.size,
                dataOffset: 0,
                dataStride: components * MemoryLayout<UInt16>.size)
        }

        /// Reads a payload's bytes as little-endian f32s — the `floats`
        /// and `matrices` encodings' shared storage.
        func f32List(_ data: Data) -> [Float] {
            (0..<data.count / 4).map {
                D3Wire.f32LE(data, data.startIndex + $0 * 4)
            }
        }

        func decodeBounds(_ any: Any?, nativeSpace: Bool)
            -> (min: SCNVector3, max: SCNVector3)?
        {
            guard let map = any as? [String: Any],
                  let min = rawVec3(map["min"]),
                  let max = rawVec3(map["max"]) else { return nil }
            if nativeSpace {
                return (SCNVector3(min[0], min[1], min[2]),
                        SCNVector3(max[0], max[1], max[2]))
            }
            return (SCNVector3(min[0], min[1], -max[2]),
                    SCNVector3(max[0], max[1], -min[2]))
        }

        func rawVec3(_ any: Any?) -> [Float]? {
            guard let values = any as? [Any], values.count == 3 else {
                return nil
            }
            let floats = values.compactMap { ($0 as? NSNumber)?.floatValue }
            return floats.count == 3 ? floats : nil
        }

        /// Decodes a geometry's `morphTargets` block into absolute
        /// target geometries for `SCNMorpher` — the wire carries
        /// target-major delta slabs (all position deltas, then normal
        /// deltas when `normals`, then tangent deltas when `tangents`,
        /// each `targetCount × vertexCount × 3` f32), and SceneKit's
        /// targets hold absolute attributes, so each target is
        /// `base + delta`. Delta z negates like positions on the base
        /// decode — unless the geometry is `nativeSpace` (already
        /// right-handed). A missing deltas payload defers the geometry
        /// like any other claim.
        func decodeMorphTargets(_ key: UInt64, _ m: [String: Any],
                                decoded: DecodedVertices,
                                element: SCNGeometryElement) {
            guard let token = m["deltas"] as? String,
                  let pid = D3Wire.localIdKey(token),
                  let targetCount = (m["targetCount"] as? NSNumber)?
                      .intValue,
                  targetCount > 0 else {
                host.logOnce("geometry.\(key).morph.malformed",
                    "geometry \(key): morphTargets lacks deltas/"
                    + "targetCount")
                return
            }
            // Record the claim before resolution — an `upsertPayload`
            // chunk re-decodes this whole geometry on arrival.
            geometryPayloadKeys[key, default: []].insert(pid)
            guard let data = host.payloadStore[pid] else {
                deferredResourceIds.insert(key)
                host.logOnce("geometry.\(key).morph.awaiting",
                    "geometry \(key): awaiting morph delta payload")
                return
            }
            let floats = f32List(data)
            // Wire flags size the delta slabs; a slab is only applied
            // when the base actually carries that attribute.
            let hasN = m["normals"] as? Bool == true
            let hasT = m["tangents"] as? Bool == true
            let canN = decoded.normals.count >= decoded.count * 3
            let canT = decoded.tangents.count >= decoded.count * 4
            let slab = targetCount * decoded.count * 3
            let sections = 1 + (hasN ? 1 : 0) + (hasT ? 1 : 0)
            guard floats.count >= slab * sections else {
                host.logOnce("geometry.\(key).morph.size",
                    "geometry \(key): morph delta payload has "
                    + "\(floats.count) floats; expected "
                    + "\(slab * sections) for \(targetCount) targets")
                return
            }
            let mirror = !decoded.nativeSpace
            let normalBase = slab
            let tangentBase = slab + (hasN ? slab : 0)
            let names = m["names"] as? [String] ?? []
            var targets: [SCNGeometry] = []
            targets.reserveCapacity(targetCount)
            for ti in 0..<targetCount {
                var pos = [Float](repeating: 0, count: decoded.count * 3)
                var nrm: [Float]? =
                    hasN && canN
                        ? [Float](repeating: 0, count: decoded.count * 3)
                        : nil
                var tan: [Float]? =
                    hasT && canT
                        ? [Float](repeating: 0, count: decoded.count * 4)
                        : nil
                for v in 0..<decoded.count {
                    let vb3 = v * 3
                    let d3 = (ti * decoded.count + v) * 3
                    pos[vb3]     = decoded.positions[vb3]
                        + floats[d3]
                    pos[vb3 + 1] = decoded.positions[vb3 + 1]
                        + floats[d3 + 1]
                    pos[vb3 + 2] = decoded.positions[vb3 + 2]
                        + (mirror ? -floats[d3 + 2] : floats[d3 + 2])
                    if nrm != nil {
                        nrm![vb3]     = decoded.normals[vb3]
                            + floats[normalBase + d3]
                        nrm![vb3 + 1] = decoded.normals[vb3 + 1]
                            + floats[normalBase + d3 + 1]
                        nrm![vb3 + 2] = decoded.normals[vb3 + 2]
                            + (mirror ? -floats[normalBase + d3 + 2]
                                      : floats[normalBase + d3 + 2])
                    }
                    if tan != nil {
                        // Tangent deltas are xyz slabs; the handedness
                        // w stays the base's (base decode already
                        // negated it for the z-mirror).
                        let vb4 = v * 4
                        tan![vb4]     = decoded.tangents[vb4]
                            + floats[tangentBase + d3]
                        tan![vb4 + 1] = decoded.tangents[vb4 + 1]
                            + floats[tangentBase + d3 + 1]
                        tan![vb4 + 2] = decoded.tangents[vb4 + 2]
                            + (mirror ? -floats[tangentBase + d3 + 2]
                                      : floats[tangentBase + d3 + 2])
                        tan![vb4 + 3] = decoded.tangents[vb4 + 3]
                    }
                }
                var tsrcs = [
                    floatSource(pos, .vertex, decoded.count, 3)
                ]
                if let nrm {
                    tsrcs.append(
                        floatSource(nrm, .normal, decoded.count, 3))
                }
                if let tan {
                    tsrcs.append(
                        floatSource(tan, .tangent, decoded.count, 4))
                }
                let target = SCNGeometry(sources: tsrcs,
                                         elements: [element])
                if ti < names.count { target.name = names[ti] }
                targets.append(target)
            }
            let weights = (m["weights"] as? [NSNumber] ?? [])
                .map { $0.floatValue }
            morphTargets[key] = DecodedMorph(
                targets: targets, defaultWeights: weights,
                targetCount: targetCount)
        }

        func procedural(_ shape: String, _ p: [String: Any]) -> SCNGeometry? {
            switch shape {
            case "cuboid":
                let e = d3Vec3(p["extents"]) ?? [1, 1, 1]
                return SCNBox(width: CGFloat(e[0]), height: CGFloat(e[1]),
                              length: CGFloat(e[2]), chamferRadius: 0)
            case "sphere":
                return SCNSphere(radius: CGFloat(d3Double(p["radius"]) ?? 0.5))
            case "icosphere":
                // SceneKit has no geodesic primitive; a high-segment UV
                // sphere is the closest native analog.
                let s = SCNSphere(radius: CGFloat(d3Double(p["radius"]) ?? 0.5))
                s.segmentCount = 48
                d3Log("icosphere approximated with UV sphere")
                return s
            case "plane":
                return SCNPlane(width: CGFloat(d3Double(p["width"]) ?? 1),
                                height: CGFloat(d3Double(p["depth"]) ?? 1))
            case "torus":
                return SCNTorus(ringRadius: CGFloat(d3Double(p["radius"]) ?? 0.5),
                                pipeRadius: CGFloat(d3Double(p["tubeRadius"]) ?? 0.125))
            default:
                d3Log("unknown procedural shape '\(shape)'"); return nil
            }
        }

        /// Realizes one `material` resource. Factor properties decode
        /// first; each texture slot then replaces its property's
        /// `contents` — a texture-backed `SCNMaterialProperty` never
        /// multiplies a color factor, so factor×texture is baked into
        /// the pixels (`bakeFactor`). A slot whose texture is
        /// unresolved keeps the factor-only contents (the deferred
        /// lane's fallback) and records a consumer binding so a later
        /// `upsertResource`/`upsertPayload` rebinds it.
        func decodeMaterial(_ key: UInt64, _ r: [String: Any]) {
            let m = SCNMaterial()
            let type = r["type"] as? String ?? "physicallyBased"
            m.lightingModel = type == "unlit"
                ? .constant : .physicallyBased
            let props = r["properties"] as? [String: Any] ?? [:]
            if let c = d3Color(props["baseColor"]) { m.diffuse.contents = c }
            if let v = d3Double(props["metallic"]) {
                m.metalness.contents = NSNumber(value: v)
            }
            if let v = d3Double(props["roughness"]) {
                m.roughness.contents = NSNumber(value: v)
            }
            if let v = d3Double(props["emissiveStrength"]) {
                m.emission.intensity = CGFloat(v)
            }
            if let c = d3Color(props["emissive"]) { m.emission.contents = c }
            if d3Bool(props["doubleSided"]) == true { m.isDoubleSided = true }
            // W21: glTF alphaMode (wire values are lowercase
            // 'opaque|mask|blend'; compared case-insensitively).
            // `blend` puts the material in SceneKit's alpha-blended
            // transparent pass with depth writes OFF — a blended
            // surface that writes depth occludes the surfaces sorted
            // behind it and visibly disappears; depth reads stay on
            // so it still hides behind opaque geometry.
            // `mask` is a true alpha test: SCNTransparencyMode has no
            // alpha-test mode (.aOne/.rgbZero pick a transparency
            // source, they don't discard), so a `.fragment` shader
            // modifier drops texels below `alphaCutoff` and pins the
            // survivors to a=1 — a mask is binary-opaque where it
            // survives even if the material still lands in the blend
            // pass on texture-alpha contents.
            let alphaMode = d3String(props["alphaMode"])
                ?? (props["alphaMode"] as? String)
            switch (alphaMode ?? "opaque").lowercased() {
            case "opaque":
                break
            case "blend":
                m.blendMode = .alpha
                m.transparencyMode = .aOne
                m.writesToDepthBuffer = false
                m.readsFromDepthBuffer = true
            case "mask":
                let cutoff = d3Double(props["alphaCutoff"])
                    ?? (props["alphaCutoff"] as? NSNumber)?.doubleValue
                    ?? 0.5
                m.shaderModifiers = [
                    .fragment: String(format:
                        "if (_output.color.a < %.6f) "
                        + "{ discard_fragment(); }\n"
                        + "_output.color.a = 1.0;", cutoff)
                ]
            default:
                host.logOnce("material.\(key).alphaMode.\(alphaMode ?? "?")",
                    "material \(key): unknown alphaMode "
                    + "'\(alphaMode ?? "?")'; kept opaque")
            }
            for slot in ["baseColorTexture", "metallicRoughnessTexture",
                         "normalTexture", "occlusionTexture",
                         "emissiveTexture"]
            where props[slot] != nil {
                applyTextureSlot(m, materialKey: key, slot: slot)
            }
            materials[key] = m
        }

        /// Binds (or rebinds) one texture slot on `m`; `slot` is the
        /// wire property name (`baseColorTexture`, …). The raw
        /// properties come back out of `resourceDefs[materialKey]` so a
        /// rebind redoes the factor×texture bake exactly like the
        /// manifest pass. An unresolved texture binds the factor-only
        /// fallback — also the unbind path when an upserted texture
        /// fails to decode.
        func applyTextureSlot(_ m: SCNMaterial, materialKey: UInt64,
                              slot: String) {
            let props = (resourceDefs[materialKey]?["properties"]
                         as? [String: Any]) ?? [:]
            guard let texKey = d3Ref(props[slot]) else { return }
            var list = textureConsumers[texKey] ?? []
            if !list.contains(where: {
                $0.material === m && $0.slot == slot
            }) {
                list.append(TextureBinding(
                    material: m, materialKey: materialKey, slot: slot))
                textureConsumers[texKey] = list
            }
            // W14: a renderTexture ref binds the live color texture —
            // the slot samples whatever the offscreen passes last drew.
            // A renderTexture def without a live rec (failed decode)
            // falls through to the image path → factor-only fallback.
            if let rt = renderTargets[texKey] {
                applyRenderTextureSlot(m, rt: rt, slot: slot)
                return
            }
            let tex = textures[texKey]
            let transform = props["\(slot)Transform"]
            switch slot {
            case "baseColorTexture":
                if let tex {
                    bindTextureContents(
                        m.diffuse, tex: tex,
                        baked: bakeFactor(
                            tex,
                            color: d3ColorComponents(props["baseColor"]),
                            rgbOnly: false),
                        logKey: "material.\(materialKey).diffuse.mips")
                    applyContentsTransform(
                        m.diffuse, transform, materialKey: materialKey,
                        slot: slot)
                } else {
                    m.diffuse.contents = d3Color(props["baseColor"])
                }
            case "metallicRoughnessTexture":
                if let tex {
                    let mf = d3Double(props["metallic"]) ?? 0.0
                    let rf = d3Double(props["roughness"]) ?? 0.5
                    let (metal, rough) = splitMetallicRoughness(
                        tex, metallic: mf, roughness: rf)
                    // A failed split keeps the factor-only contents.
                    m.metalness.contents = metal ?? NSNumber(value: mf)
                    m.roughness.contents = rough ?? NSNumber(value: rf)
                    applyContentsTransform(
                        m.metalness, transform, materialKey: materialKey,
                        slot: slot)
                    applyContentsTransform(
                        m.roughness, transform, materialKey: materialKey,
                        slot: slot)
                } else {
                    m.metalness.contents = d3Double(props["metallic"])
                        .map { NSNumber(value: $0) }
                    m.roughness.contents = d3Double(props["roughness"])
                        .map { NSNumber(value: $0) }
                }
            case "normalTexture":
                // W21: upstream ships renormalized mips for normal
                // maps — a box-filtered mip shrinks average normal
                // length, softening the map at distance. SceneKit
                // generates its own chain and can't steer it, so the
                // chain is built CPU-side with renormalized texels
                // and bound as an MTLTexture. Falls back to the plain
                // image (SceneKit's unrenormalized mips) when pixels
                // or Metal are unavailable — `renormalizedNormalMips`
                // logs once per cause.
                m.normal.contents = tex.flatMap {
                    $0.mtlTexture
                        ?? renormalizedNormalMips($0, materialKey: materialKey)
                } ?? tex?.contents
                if tex != nil {
                    m.normal.mipFilter = .linear
                    applyContentsTransform(
                        m.normal, transform, materialKey: materialKey,
                        slot: slot)
                }
                if let v = d3Double(props["normalScale"]) {
                    m.normal.intensity = CGFloat(v)
                }
            case "occlusionTexture":
                m.ambientOcclusion.contents = tex?.contents
                if tex != nil {
                    applyContentsTransform(
                        m.ambientOcclusion, transform,
                        materialKey: materialKey, slot: slot)
                }
                if let v = d3Double(props["occlusionStrength"]) {
                    m.ambientOcclusion.intensity = CGFloat(v)
                }
            case "emissiveTexture":
                if let tex {
                    // The emissive factor default is black — a lone
                    // emissiveTexture emits nothing (glTF semantics).
                    bindTextureContents(
                        m.emission, tex: tex,
                        baked: bakeFactor(
                            tex,
                            color: d3ColorComponents(props["emissive"])
                                ?? [0, 0, 0, 1],
                            rgbOnly: true),
                        logKey: "material.\(materialKey).emission.mips")
                    applyContentsTransform(
                        m.emission, transform, materialKey: materialKey,
                        slot: slot)
                } else {
                    m.emission.contents = d3Color(props["emissive"])
                }
                if let v = d3Double(props["emissiveStrength"]) {
                    m.emission.intensity = CGFloat(v)
                }
            default:
                break
            }
        }

        /// Binds a texture's contents on `prop` (W21). An unbaked
        /// bind takes `tex.contents` — the MTLTexture when one was
        /// uploaded (a KTX2 decode, or the sRGB renormalized mip
        /// chain `color` contents get) so the GPU chain is what
        /// samples. A `baked` factor×texture image re-uploads
        /// through `mipRenormalizedTexture` so the slot keeps the
        /// renorm semantic; a failed upload keeps the UIImage and
        /// SceneKit's own chain. `mipFilter` pins `.linear` whenever
        /// a GPU chain backs the slot (a mipmapped MTLTexture with
        /// `mipFilter == .none` would alias at distance).
        func bindTextureContents(_ prop: SCNMaterialProperty,
                                 tex: DecodedTexture, baked: UIImage?,
                                 logKey: String) {
            if let baked {
                prop.contents = mipRenormalizedTexture(
                    baked, srgb: tex.content == "color",
                    logKey: logKey) ?? baked
                prop.mipFilter = .linear
            } else {
                prop.contents = tex.contents
                if tex.mtlTexture != nil { prop.mipFilter = .linear }
            }
        }

        /// W14 rt branch of `applyTextureSlot`: binds the render
        /// target's live `colorTex` as the slot's contents and maps
        /// the spec's `filter`/`wrap` onto the slot's sampling state.
        /// `bakeFactor` is SKIPPED — a dynamic texture can't be
        /// CPU-baked, so the factor isn't multiplied, matching this
        /// codebase's existing texture-factor rule. For the packed
        /// metallicRoughness slot both scalar properties take the
        /// color texture — a live texture has no CPU channel split.
        func applyRenderTextureSlot(_ m: SCNMaterial,
                                    rt: RenderTargetRec, slot: String) {
            let props: [SCNMaterialProperty]
            switch slot {
            case "baseColorTexture":         props = [m.diffuse]
            case "metallicRoughnessTexture":
                props = [m.metalness, m.roughness]
            case "normalTexture":            props = [m.normal]
            case "occlusionTexture":         props = [m.ambientOcclusion]
            case "emissiveTexture":          props = [m.emission]
            default:                         props = []
            }
            let f: SCNFilterMode =
                rt.filter == "nearest" ? .nearest : .linear
            let w: SCNWrapMode
            switch rt.wrap {
            case "repeat": w = .repeat
            case "mirror": w = .mirror
            default: w = .clamp   // 'clampToEdge' (+ decode-normalized)
            }
            for p in props {
                p.contents = rt.colorTex
                p.minificationFilter = f
                p.magnificationFilter = f
                p.wrapS = w
                p.wrapT = w
            }
        }

        /// KHR_texture_transform → `contentsTransform`: the glTF uv is
        /// `uv' = offset + Rz(rotation)·scale ⊙ uv` (offset applied
        /// after scale+rotation). `SCNMatrix4` uses the row-vector
        /// convention — `SCNMatrix4Mult(a, b)` applies `a` first — so
        /// the chain is scale → rotate → translate, built left to
        /// right. `texCoord` selects the UV set: `mappingChannel` N
        /// samples the geometry's Nth `.texcoord` source (uv1-carrying
        /// layouts land one — `decodeVertexPayload`). The wire tops
        /// out at two sets, so `texCoord` ≥ 2 can't resolve today; it
        /// is passed through unclamped rather than silently sampled as
        /// uv0, and logged once.
        func applyContentsTransform(
            _ prop: SCNMaterialProperty, _ any: Any?,
            materialKey: UInt64, slot: String
        ) {
            guard let tm = d3Map(any) ?? (any as? [String: Any])
            else { return }
            let offset = d3Vec2(tm["offset"]) ?? [0, 0]
            let scale = d3Vec2(tm["scale"]) ?? [1, 1]
            let rotation = d3Double(tm["rotation"])
                ?? (tm["rotation"] as? NSNumber)?.doubleValue ?? 0
            let texCoord = d3Int(tm["texCoord"])
                ?? (tm["texCoord"] as? NSNumber)?.intValue ?? 0
            if texCoord >= 2 {
                host.logOnce("material.\(materialKey).\(slot).texCoord",
                    "material \(materialKey) \(slot): texCoord \(texCoord) "
                    + "exceeds the wire's two UV sets — passed through; "
                    + "a geometry without that UV set won't resolve it")
            }
            prop.mappingChannel = texCoord
            var t = SCNMatrix4MakeScale(Float(scale[0]), Float(scale[1]), 1)
            t = SCNMatrix4Mult(
                t, SCNMatrix4MakeRotation(Float(rotation), 0, 0, 1))
            t = SCNMatrix4Mult(
                t, SCNMatrix4MakeTranslation(
                    Float(offset[0]), Float(offset[1]), 0))
            prop.contentsTransform = t
        }

        /// Realizes one `texture` resource. A `payload` source resolves
        /// against `payloadStore` by the spec's `format`: `rgba8` wraps
        /// the raw bytes in a CGImage (dims from the payload spec),
        /// `ktx2` goes through `decodeKTX2` (W21 — MTKTextureLoader or
        /// the in-tree non-supercompressed upload; BasisU warns once),
        /// and anything else — png/jpg or an absent format — goes
        /// through `UIImage`'s container sniffing. A `ref` source loads
        /// from the asset catalog, then the main bundle. `color`
        /// contents also get a GPU upload carrying a renormalized mip
        /// chain (`mipRenormalizedTexture`, W21). A payload whose bytes
        /// haven't landed defers (re-realized when they do); malformed
        /// content logs once and leaves the slot empty — the material
        /// keeps its factor-only fallback.
        func decodeTexture(_ key: UInt64, _ r: [String: Any]) {
            let started = DispatchTime.now().uptimeNanoseconds
            let content = r["content"] as? String ?? "color"
            if r["payload"] != nil {
                guard let token = r["payload"] as? String,
                      let pid = D3Wire.localIdKey(token) else {
                    host.logOnce("texture.\(key).payloadToken",
                        "texture \(key): invalid payload token")
                    return
                }
                texturePayloadKeys[key] = pid
                guard let data = host.payloadStore[pid] else {
                    deferredResourceIds.insert(key)
                    host.logOnce("texture.\(key).awaiting",
                        "texture \(key): awaiting payload")
                    return
                }
                let spec = payloadSpecs[pid]
                switch spec?.format {
                case "rgba8":
                    guard let w = spec?.width, let h = spec?.height,
                          w > 0, h > 0 else {
                        host.logOnce("texture.\(key).rgba8.dims",
                            "texture \(key): rgba8 payload spec lacks "
                            + "width/height")
                        return
                    }
                    guard data.count == w * h * 4 else {
                        host.logOnce("texture.\(key).rgba8.size",
                            "texture \(key): rgba8 needs w*h*4 bytes")
                        return
                    }
                    guard let cg = rgbaCGImage(
                        data, width: w, height: h, content: content)
                    else {
                        host.logOnce("texture.\(key).rgba8.cg",
                            "texture \(key): rgba8 CGImage failed")
                        return
                    }
                    let image = UIImage(cgImage: cg)
                    recordTexture(key, DecodedTexture(
                        key: key, image: image,
                        mtlTexture: content == "color"
                            ? mipRenormalizedTexture(
                                image, logKey: "texture.\(key).mips")
                            : nil,
                        rgba: data,
                        width: w, height: h, content: content),
                        format: "rgba8", bytes: data.count,
                        since: started)
                case "ktx2":
                    if let tex = decodeKTX2(data, key: key,
                                            content: content) {
                        recordTexture(key, tex, format: "ktx2",
                                      bytes: data.count,
                                      since: started)
                    }
                default:
                    // Encoded container (png/jpg) or an undeclared
                    // format — UIImage decides by the magic bytes and
                    // tags the colorspace itself.
                    guard let image = UIImage(data: data),
                          let cg = image.cgImage else {
                        host.logOnce("texture.\(key).undecodable",
                            "texture \(key): undecodable image payload")
                        return
                    }
                    recordTexture(key, DecodedTexture(
                        key: key, image: image,
                        mtlTexture: content == "color"
                            ? mipRenormalizedTexture(
                                image, logKey: "texture.\(key).mips")
                            : nil,
                        rgba: nil, width: cg.width,
                        height: cg.height, content: content),
                        format: spec?.format ?? "encoded",
                        bytes: data.count, since: started)
                }
                return
            }
            if let asset = r["ref"] as? String {
                var image = UIImage(named: asset)
                if image == nil,
                   let url = Bundle.main.url(forResource: asset,
                                             withExtension: nil) {
                    image = UIImage(contentsOfFile: url.path)
                }
                guard let image, let cg = image.cgImage else {
                    host.logOnce("texture.\(key).ref",
                        "texture \(key): asset '\(asset)' not found")
                    return
                }
                recordTexture(key, DecodedTexture(
                    key: key, image: image,
                    mtlTexture: content == "color"
                        ? mipRenormalizedTexture(
                            image, logKey: "texture.\(key).mips")
                        : nil,
                    rgba: nil, width: cg.width,
                    height: cg.height, content: content),
                    format: "ref", bytes: 0, since: started)
                return
            }
            host.logOnce("texture.\(key).source",
                "texture \(key): neither payload nor ref — slot absent")
        }

        /// Records a decoded texture and logs the upload line.
        func recordTexture(_ key: UInt64, _ tex: DecodedTexture,
                           format: String, bytes: Int, since start: UInt64) {
            textures[key] = tex
            let ms = Double(DispatchTime.now().uptimeNanoseconds - start)
                / 1_000_000.0
            d3Log("texture \(key): \(tex.width)x\(tex.height) \(format) "
                + "(\(bytes) B in \(String(format: "%.2f", ms)) ms)")
        }

        /// W21 mip renormalization for sRGB sources that ship without
        /// a chain (`rgba8`, encoded, `ref`): `MTKTextureLoader`
        /// uploads the image with `generateMipmaps` — on the
        /// `*_srgb` pixel format Metal produces, each downsample
        /// filters the decoded (linear) values and re-encodes, which
        /// is upstream's renormalizing-mip semantic. SceneKit's own
        /// implicit chain makes no sRGB-filtering guarantee, so the
        /// uploaded texture is what material slots bind. Returns nil
        /// when Metal can't take the image — the caller keeps the
        /// `UIImage` contents and SceneKit generates its own chain;
        /// `logKey` scopes the warn-once.
        func mipRenormalizedTexture(_ image: UIImage, srgb: Bool = true,
                                    logKey: String) -> MTLTexture? {
            guard let cg = image.cgImage else {
                host.logOnce("\(logKey).cg",
                    "\(logKey): no CGImage — SceneKit's own mip chain "
                    + "(sRGB-aware filtering not guaranteed)")
                return nil
            }
            guard let device = host.renderDevice() else {
                host.logOnce("\(logKey).device",
                    "\(logKey): no Metal device — SceneKit's own mip "
                    + "chain (sRGB-aware filtering not guaranteed)")
                return nil
            }
            guard let tex = try? MTKTextureLoader(device: device)
                .newTexture(cgImage: cg, options: [
                    .generateMipmaps: NSNumber(value: true),
                    .SRGB: NSNumber(value: srgb),
                    .textureUsage: NSNumber(
                        value: MTLTextureUsage.shaderRead.rawValue),
                ])
            else {
                host.logOnce("\(logKey).mtl",
                    "\(logKey): MTK mip upload failed — SceneKit's own "
                    + "mip chain (sRGB-aware filtering not guaranteed)")
                return nil
            }
            return tex
        }

        /// Level-0 readback of an uncompressed 8-bit MTLTexture into
        /// straight RGBA8 — the `sourcePixels` lane for textures that
        /// only exist GPU-side (a decoded KTX2). BGRA swaps to RGBA;
        /// the sRGB variants' bytes are already encoded like the
        /// `rgba8` path's. Private or non-8-bit formats return nil.
        func rgbaPixels(fromMetal tex: MTLTexture)
            -> (data: Data, width: Int, height: Int)?
        {
            guard tex.storageMode != .private else { return nil }
            let bgra: Bool
            switch tex.pixelFormat {
            case .rgba8Unorm, .rgba8Unorm_srgb: bgra = false
            case .bgra8Unorm, .bgra8Unorm_srgb: bgra = true
            default: return nil
            }
            let w = tex.width, h = tex.height
            var data = Data(count: w * h * 4)
            data.withUnsafeMutableBytes { ptr in
                guard let base = ptr.baseAddress else { return }
                tex.getBytes(base, bytesPerRow: w * 4,
                             from: MTLRegionMake2D(0, 0, w, h),
                             mipmapLevel: 0)
            }
            if bgra {
                data.withUnsafeMutableBytes { ptr in
                    guard let p = ptr.baseAddress?
                        .assumingMemoryBound(to: UInt8.self)
                    else { return }
                    for i in stride(from: 0, to: w * h * 4, by: 4) {
                        let b = p[i]
                        p[i] = p[i + 2]
                        p[i + 2] = b
                    }
                }
            }
            return (data, w, h)
        }

        /// One parsed KTX2 level-index row.
        struct KTX2Level {
            let offset: Int
            let length: Int
        }

        /// Parsed KTX2 fixed header (Khronos KTX 2.0 spec §3.2): the
        /// 12-byte identifier, then `vkFormat`/`typeSize`, the pixel
        /// dims, `layerCount`/`faceCount`/`levelCount`,
        /// `supercompressionScheme`, DFD/KVD/SGD offsets, and at byte
        /// 80 the `levelCount` × 24-byte levelIndex rows (offset,
        /// length, uncompressedLength — level 0 is the base/largest
        /// level regardless of file order). All little-endian.
        struct KTX2Header {
            let vkFormat: UInt32
            let pixelWidth, pixelHeight, pixelDepth: Int
            let layerCount, faceCount: Int
            let supercompression: UInt32
            let levels: [KTX2Level]
        }

        /// KTX2 (Basis Universal container) — W21. Dispatch order:
        /// `MTKTextureLoader` first — it reads any texture container
        /// the SDK understands natively — then an in-tree upload for
        /// NON-supercompressed 2D files whose `vkFormat` maps to an
        /// `MTLPixelFormat` (uncompressed RGBA 8/16/32-bit and ASTC
        /// LDR blocks, each mip level landed via `replace`).
        /// BasisU-supercompressed payloads — ETC1S
        /// (`supercompressionScheme` 1) and UASTC (`vkFormat`
        /// UNDEFINED) — need a transcoder the pod doesn't vendor;
        /// they warn once and the slot keeps its factor-only
        /// fallback. No silent drop at any stage.
        func decodeKTX2(_ data: Data, key: UInt64, content: String)
            -> DecodedTexture?
        {
            if let device = host.renderDevice(),
               let tex = try? MTKTextureLoader(device: device)
                   .newTexture(data: data, options: [
                       .SRGB: NSNumber(value: content == "color"),
                       .textureUsage: NSNumber(
                           value: MTLTextureUsage.shaderRead.rawValue),
                   ]) {
                return DecodedTexture(key: key, image: nil,
                                      mtlTexture: tex, rgba: nil,
                                      width: tex.width,
                                      height: tex.height,
                                      content: content)
            }
            guard let h = parseKTX2(data) else {
                host.logOnce("texture.\(key).ktx2.parse",
                    "texture \(key): malformed KTX2 container")
                return nil
            }
            guard h.vkFormat != 0, h.supercompression == 0 else {
                host.logOnce("texture.\(key).ktx2.basisu",
                    "texture \(key): KTX2 carries BasisU "
                    + "supercompression (vkFormat \(h.vkFormat), "
                    + "scheme \(h.supercompression)) — a transcode "
                    + "path isn't vendored; slot keeps factor-only")
                return nil
            }
            guard h.pixelDepth == 0, h.layerCount == 0,
                  h.faceCount == 1 else {
                host.logOnce("texture.\(key).ktx2.dims",
                    "texture \(key): KTX2 cubes/arrays/3D unsupported "
                    + "(faces \(h.faceCount), layers \(h.layerCount), "
                    + "depth \(h.pixelDepth))")
                return nil
            }
            guard let fmt = ktx2PixelFormat(h.vkFormat) else {
                host.logOnce("texture.\(key).ktx2.vk\(h.vkFormat)",
                    "texture \(key): KTX2 vkFormat \(h.vkFormat) has "
                    + "no MTLPixelFormat mapping")
                return nil
            }
            guard let device = host.renderDevice() else {
                host.logOnce("texture.\(key).ktx2.device",
                    "texture \(key): no Metal device for KTX2 upload")
                return nil
            }
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: fmt.format, width: h.pixelWidth,
                height: h.pixelHeight, mipmapped: h.levels.count > 1)
            desc.storageMode = .shared   // CPU readback for factor bakes
            desc.usage = .shaderRead
            desc.mipmapLevelCount = h.levels.count
            guard let mtl = device.makeTexture(descriptor: desc) else {
                host.logOnce("texture.\(key).ktx2.alloc",
                    "texture \(key): MTLTexture allocation failed")
                return nil
            }
            // KTX2 stores level rows tightly packed; `bytesPerRow` is
            // the row-of-blocks pitch for block formats, w·bpp for
            // uncompressed.
            var rgba: Data? = nil
            for (i, level) in h.levels.enumerated() {
                let lw = max(1, h.pixelWidth >> i)
                let lh = max(1, h.pixelHeight >> i)
                let blocksW = (lw + fmt.blockW - 1) / fmt.blockW
                let blocksH = (lh + fmt.blockH - 1) / fmt.blockH
                let rowBytes = blocksW * fmt.blockBytes
                let needed = rowBytes * blocksH
                guard level.length >= needed else {
                    host.logOnce("texture.\(key).ktx2.level\(i)",
                        "texture \(key): KTX2 level \(i) is "
                        + "\(level.length) B, expected ≥ \(needed) B")
                    return nil
                }
                let start = data.startIndex + level.offset
                let bytes = data.subdata(in: start..<start + needed)
                bytes.withUnsafeBytes { buf in
                    guard let base = buf.baseAddress else { return }
                    mtl.replace(region: MTLRegionMake2D(0, 0, lw, lh),
                                mipmapLevel: i, withBytes: base,
                                bytesPerRow: rowBytes)
                }
                if i == 0, fmt.format == .rgba8Unorm
                    || fmt.format == .rgba8Unorm_srgb {
                    rgba = bytes   // already straight RGBA8
                }
            }
            return DecodedTexture(key: key, image: nil,
                                  mtlTexture: mtl, rgba: rgba,
                                  width: h.pixelWidth,
                                  height: h.pixelHeight,
                                  content: content)
        }

        /// Parses the KTX2 fixed header + level index. Returns nil on
        /// a bad identifier, a truncated header, `levelCount` < 1, or
        /// a level range running past the data. `typeSize`, DFD, KVD
        /// and SGD fields are skipped — vkFormat carries the format.
        func parseKTX2(_ data: Data) -> KTX2Header? {
            let magic: [UInt8] = [0xAB, 0x4B, 0x54, 0x58, 0x20, 0x32,
                                  0x30, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A]
            guard data.count >= 80 else { return nil }
            for (i, b) in magic.enumerated()
            where data[data.startIndex + i] != b {
                return nil
            }
            func u32(_ o: Int) -> UInt32 {
                D3Wire.u32LE(data, data.startIndex + o)
            }
            func u64(_ o: Int) -> UInt64 {
                UInt64(u32(o)) | UInt64(u32(o + 4)) << 32
            }
            let levelCount = Int(u32(40))
            guard levelCount >= 1,
                  levelCount <= 64,   // sanity — caps the index walk
                  data.count >= 80 + levelCount * 24
            else { return nil }
            var levels: [KTX2Level] = []
            for i in 0..<levelCount {
                let off = u64(80 + i * 24)
                let len = u64(80 + i * 24 + 8)
                guard len <= UInt64(Int.max), off <= UInt64(Int.max),
                      off + len <= UInt64(data.count)
                else { return nil }
                levels.append(KTX2Level(offset: Int(off),
                                        length: Int(len)))
            }
            return KTX2Header(
                vkFormat: u32(12),
                pixelWidth: Int(u32(20)), pixelHeight: Int(u32(24)),
                pixelDepth: Int(u32(28)),
                layerCount: Int(u32(32)), faceCount: Int(u32(36)),
                supercompression: u32(44), levels: levels)
        }

        /// KTX2 `vkFormat` → `MTLPixelFormat` plus the block geometry
        /// `replace` needs. Covers uncompressed RGBA 8/16/32-bit and
        /// every ASTC LDR block size (Vulkan's ASTC range is
        /// contiguous UNORM/sRGB pairs in the same block-size order as
        /// Metal's). Everything else — BCn, ETC, PVRTC, HDR ASTC —
        /// returns nil and the caller warns.
        func ktx2PixelFormat(_ vk: UInt32)
            -> (format: MTLPixelFormat, blockW: Int, blockH: Int,
                blockBytes: Int)?
        {
            switch vk {
            // VK_FORMAT_R8G8B8A8_{UNORM,SRGB}, B8G8R8A8_{UNORM,SRGB},
            // R16G16B16A16_SFLOAT, R32G32B32A32_SFLOAT.
            case 37:  return (.rgba8Unorm,      1, 1, 4)
            case 43:  return (.rgba8Unorm_srgb, 1, 1, 4)
            case 44:  return (.bgra8Unorm,      1, 1, 4)
            case 50:  return (.bgra8Unorm_srgb, 1, 1, 4)
            case 97:  return (.rgba16Float,     1, 1, 8)
            case 109: return (.rgba32Float,     1, 1, 16)
            case 157...184:   // VK_FORMAT_ASTC_{4x4…12x12}_{UNORM,SRGB}
                let i = Int(vk - 157) / 2
                let srgb = (vk - 157) % 2 == 1
                let blocks: [(Int, Int)] = [
                    (4, 4), (5, 4), (5, 5), (6, 5), (6, 6), (8, 5),
                    (8, 6), (8, 8), (10, 5), (10, 6), (10, 8),
                    (10, 10), (12, 10), (12, 12)]
                let ldrFormats: [MTLPixelFormat] = [
                    .astc_4x4_ldr, .astc_5x4_ldr, .astc_5x5_ldr,
                    .astc_6x5_ldr, .astc_6x6_ldr, .astc_8x5_ldr,
                    .astc_8x6_ldr, .astc_8x8_ldr, .astc_10x5_ldr,
                    .astc_10x6_ldr, .astc_10x8_ldr, .astc_10x10_ldr,
                    .astc_12x10_ldr, .astc_12x12_ldr]
                let srgbFormats: [MTLPixelFormat] = [
                    .astc_4x4_srgb, .astc_5x4_srgb, .astc_5x5_srgb,
                    .astc_6x5_srgb, .astc_6x6_srgb, .astc_8x5_srgb,
                    .astc_8x6_srgb, .astc_8x8_srgb, .astc_10x5_srgb,
                    .astc_10x6_srgb, .astc_10x8_srgb, .astc_10x10_srgb,
                    .astc_12x10_srgb, .astc_12x12_srgb]
                let f = srgb ? srgbFormats[i] : ldrFormats[i]
                return (f, blocks[i].0, blocks[i].1, 16)
            default:
                return nil
            }
        }

        /// Raw RGBA8 access for a decoded texture — the payload buffer
        /// for `rgba8` sources, a CPU re-decode of the UIImage for
        /// encoded/`ref` ones. `wantAlpha` picks the re-decode format:
        /// premultiplied-last when the caller needs real alpha (a
        /// baseColor bake), none-skip-last when it only reads RGB (the
        /// MR channel split — premultiplying would corrupt G/B under
        /// transparent pixels).
        func sourcePixels(_ tex: DecodedTexture, wantAlpha: Bool)
            -> (data: Data, width: Int, height: Int, premultiplied: Bool)?
        {
            if let rgba = tex.rgba {
                return (rgba, tex.width, tex.height, false)
            }
            // GPU-only textures (a KTX2 that never made a UIImage)
            // read back level 0 when the pixel format is an
            // uncompressed 8-bit one — bakes and channel splits keep
            // working. Compressed/float formats return nil here and
            // the caller's fallback (factor-only) logs itself.
            if let mt = tex.mtlTexture,
               let p = rgbaPixels(fromMetal: mt) {
                return (p.data, p.width, p.height, false)
            }
            guard let image = tex.image,
                  let (data, w, h) = rgbaPixels(image, alpha: wantAlpha)
            else { return nil }
            return (data, w, h, wantAlpha)
        }

        /// Factor × texture, baked CPU-side — a texture-backed
        /// `SCNMaterialProperty` never multiplies a color factor.
        /// `rgbOnly` leaves alpha alone (emissive); otherwise the
        /// factor's alpha multiplies too (baseColor). Returns nil when
        /// no factor is given (texture binds unbaked); when a factor
        /// IS given but the pixels are unreachable (a GPU-only
        /// compressed decode) the bind falls back to the raw texture
        /// and the factor is lost — logged once.
        func bakeFactor(_ tex: DecodedTexture, color fc: [Double]?,
                        rgbOnly: Bool) -> UIImage? {
            guard let fc else { return nil }
            guard let src = sourcePixels(tex, wantAlpha: !rgbOnly)
            else {
                host.logOnce("texture.\(tex.key).bake",
                    "texture \(tex.key): factor×texture bake needs CPU "
                    + "pixels — binding the texture unbaked "
                    + "(approximation)")
                return nil
            }
            var data = src.data
            let fa = fc[3]
            data.withUnsafeMutableBytes { ptr in
                guard let p = ptr.baseAddress?
                    .assumingMemoryBound(to: UInt8.self) else { return }
                for i in stride(from: 0, to: src.width * src.height * 4,
                                by: 4) {
                    if src.premultiplied {
                        // p.rgb already carries the tex alpha; the
                        // straight result r·fR·fA comes out as pR·fR·fA.
                        p[i]     = scaleByte(p[i],     fc[0] * fa)
                        p[i + 1] = scaleByte(p[i + 1], fc[1] * fa)
                        p[i + 2] = scaleByte(p[i + 2], fc[2] * fa)
                        p[i + 3] = scaleByte(p[i + 3], fa)
                    } else {
                        p[i]     = scaleByte(p[i],     fc[0])
                        p[i + 1] = scaleByte(p[i + 1], fc[1])
                        p[i + 2] = scaleByte(p[i + 2], fc[2])
                        if !rgbOnly { p[i + 3] = scaleByte(p[i + 3], fa) }
                    }
                }
            }
            return rgbaCGImage(data, width: src.width, height: src.height,
                               content: tex.content,
                               premultiplied: src.premultiplied)
                .map { UIImage(cgImage: $0) }
        }

        /// glTF packs metallic in B and roughness in G; SceneKit samples
        /// `metalness`/`roughness` as scalars, so the channels split
        /// into two gray images CPU-side — with the factors baked in,
        /// since a texture-backed property can't multiply them either.
        /// A nil half keeps the factor-only contents — for a GPU-only
        /// texture (a compressed KTX2) that drops the map entirely,
        /// so the miss warns once.
        func splitMetallicRoughness(_ tex: DecodedTexture,
                                    metallic mf: Double,
                                    roughness rf: Double)
            -> (metal: UIImage?, rough: UIImage?)
        {
            guard let src = sourcePixels(tex, wantAlpha: false)
            else {
                host.logOnce("texture.\(tex.key).mrSplit",
                    "texture \(tex.key): metallic/roughness channel "
                    + "split needs CPU pixels — binding factors only "
                    + "(approximation)")
                return (nil, nil)
            }
            var metal = Data(count: src.width * src.height)
            var rough = Data(count: src.width * src.height)
            src.data.withUnsafeBytes { ptr in
                guard let p = ptr.baseAddress?
                    .assumingMemoryBound(to: UInt8.self) else { return }
                metal.withUnsafeMutableBytes { mp in
                    rough.withUnsafeMutableBytes { rp in
                        let m = mp.baseAddress!
                            .assumingMemoryBound(to: UInt8.self)
                        let r = rp.baseAddress!
                            .assumingMemoryBound(to: UInt8.self)
                        for i in 0..<src.width * src.height {
                            m[i] = scaleByte(p[i * 4 + 2], mf)
                            r[i] = scaleByte(p[i * 4 + 1], rf)
                        }
                    }
                }
            }
            return (grayCGImage(metal, width: src.width, height: src.height)
                        .map { UIImage(cgImage: $0) },
                    grayCGImage(rough, width: src.width, height: src.height)
                        .map { UIImage(cgImage: $0) })
        }

        /// Byte channel × unit factor, clamped to 0…255.
        func scaleByte(_ b: UInt8, _ f: Double) -> UInt8 {
            UInt8(clamping: Int((Double(b) * f).rounded()))
        }

        /// Builds a full mip chain for a normal-map texture CPU-side
        /// and returns it as an `MTLTexture` (W21). Each level is a
        /// 2×2 box average of the previous one with the averaged
        /// normal renormalized — decode → [-1,1], normalize,
        /// re-encode — so distant mips keep unit-length normals
        /// instead of the shrunken vectors a plain box filter
        /// produces. A degenerate (near-zero) average falls back to
        /// the flat +z normal rather than inventing a direction.
        /// Alpha is box-averaged unrenormalized. Level 0 ships
        /// verbatim. Returns nil (caller binds `tex.contents`) when the
        /// pixels are unreachable or Metal can't make the texture —
        /// each cause logs once.
        func renormalizedNormalMips(_ tex: DecodedTexture,
                                  materialKey: UInt64) -> MTLTexture? {
            guard let src = sourcePixels(tex, wantAlpha: false)
            else {
                host.logOnce("material.\(materialKey).normal.mips.pixels",
                    "material \(materialKey): normal texture pixels "
                    + "unreachable; SceneKit's unrenormalized mips "
                    + "(approximation — upstream renormalizes)")
                return nil
            }
            guard let device = host.renderDevice() else {
                host.logOnce("material.\(materialKey).normal.mips.device",
                    "material \(materialKey): no Metal device; "
                    + "SceneKit's unrenormalized mips (approximation — "
                    + "upstream renormalizes)")
                return nil
            }
            var levels: [[UInt8]] = [[UInt8](src.data)]
            var w = src.width, h = src.height
            while w > 1 || h > 1 {
                let prev = levels[levels.count - 1]
                let nw = max(1, w / 2), nh = max(1, h / 2)
                var next = [UInt8](repeating: 0, count: nw * nh * 4)
                for y in 0..<nh {
                    for x in 0..<nw {
                        var sx = 0.0, sy = 0.0, sz = 0.0
                        var sa = 0
                        // Clamped taps: odd dims reweight the edge
                        // texel — a small bias at NPOT edges, noted.
                        for dy in 0..<2 {
                            for dx in 0..<2 {
                                let px = min(x * 2 + dx, w - 1)
                                let py = min(y * 2 + dy, h - 1)
                                let o = (py * w + px) * 4
                                sx += Double(prev[o]) / 127.5 - 1.0
                                sy += Double(prev[o + 1]) / 127.5 - 1.0
                                sz += Double(prev[o + 2]) / 127.5 - 1.0
                                sa += Int(prev[o + 3])
                            }
                        }
                        let d = (y * nw + x) * 4
                        let len = (sx * sx + sy * sy + sz * sz)
                            .squareRoot()
                        if len > 1e-6 {
                            next[d] = UInt8(clamping: Int(
                                ((sx / len + 1.0) * 127.5).rounded()))
                            next[d + 1] = UInt8(clamping: Int(
                                ((sy / len + 1.0) * 127.5).rounded()))
                            next[d + 2] = UInt8(clamping: Int(
                                ((sz / len + 1.0) * 127.5).rounded()))
                        } else {
                            // Cancelled-out average — flat +z normal.
                            next[d] = 128; next[d + 1] = 128
                            next[d + 2] = 255
                        }
                        next[d + 3] = UInt8(clamping: sa / 4)
                    }
                }
                levels.append(next)
                w = nw; h = nh
            }
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,  // linear — normal data, no sRGB
                width: src.width, height: src.height, mipmapped: true)
            desc.storageMode = .shared
            desc.usage = .shaderRead
            desc.mipmapLevelCount = levels.count
            guard let mtl = device.makeTexture(descriptor: desc) else {
                host.logOnce("material.\(materialKey).normal.mips.mtl",
                    "material \(materialKey): MTLTexture creation "
                    + "failed; SceneKit's unrenormalized mips "
                    + "(approximation — upstream renormalizes)")
                return nil
            }
            for (level, pixels) in levels.enumerated() {
                let lw = max(1, src.width >> level)
                let lh = max(1, src.height >> level)
                pixels.withUnsafeBytes { buf in
                    guard let base = buf.baseAddress else { return }
                    mtl.replace(
                        region: MTLRegionMake2D(0, 0, lw, lh),
                        mipmapLevel: level, withBytes: base,
                        bytesPerRow: lw * 4)
                }
            }
            return mtl
        }

        /// Re-decodes an encoded/`ref` image to raw 8-bit RGBA.
        /// `alpha: true` draws premultiplied-last; `false` draws
        /// none-skip-last for channel-split reads where premultiplying
        /// would corrupt the G/B channels.
        func rgbaPixels(_ image: UIImage, alpha: Bool)
            -> (data: Data, width: Int, height: Int)?
        {
            guard let cg = image.cgImage else { return nil }
            let w = cg.width, h = cg.height
            var data = Data(count: w * h * 4)
            let info = CGBitmapInfo(rawValue:
                (alpha ? CGImageAlphaInfo.premultipliedLast
                       : CGImageAlphaInfo.noneSkipLast).rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue)
            let ok = data.withUnsafeMutableBytes { ptr -> Bool in
                guard let base = ptr.baseAddress,
                      let space = CGColorSpace(name: CGColorSpace.sRGB),
                      let ctx = CGContext(
                          data: base, width: w, height: h,
                          bitsPerComponent: 8, bytesPerRow: w * 4,
                          space: space, bitmapInfo: info.rawValue)
                else { return false }
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
                return true
            }
            return ok ? (data, w, h) : nil
        }

        /// Wraps raw RGBA8 bytes as a CGImage — 8bpc/32bpp, w·4 bytes a
        /// row, `byteOrder32Big | alphaLast` for straight alpha (the
        /// wire convention) or `premultipliedLast` for re-decoded
        /// sources. Colorspace comes from `content`: `color` → sRGB,
        /// `data`/`normal` → linear sRGB.
        func rgbaCGImage(_ data: Data, width w: Int, height h: Int,
                         content: String, premultiplied: Bool = false)
            -> CGImage?
        {
            guard let provider = CGDataProvider(data: data as CFData),
                  let space = CGColorSpace(name:
                      content == "color" ? CGColorSpace.sRGB
                                         : CGColorSpace.linearSRGB)
            else { return nil }
            let info = CGBitmapInfo(rawValue:
                (premultiplied ? CGImageAlphaInfo.premultipliedLast
                               : CGImageAlphaInfo.last).rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue)
            return CGImage(width: w, height: h,
                           bitsPerComponent: 8, bitsPerPixel: 32,
                           bytesPerRow: w * 4, space: space,
                           bitmapInfo: info, provider: provider,
                           decode: nil, shouldInterpolate: true,
                           intent: .defaultIntent)
        }

        /// One-channel gray image for the metallic/roughness split —
        /// scalar data, so linear gray (no sRGB decode).
        func grayCGImage(_ data: Data, width w: Int, height h: Int)
            -> CGImage?
        {
            guard let provider = CGDataProvider(data: data as CFData),
                  let space = CGColorSpace(name: CGColorSpace.linearGray)
            else { return nil }
            return CGImage(width: w, height: h,
                           bitsPerComponent: 8, bitsPerPixel: 8,
                           bytesPerRow: w, space: space,
                           bitmapInfo: CGBitmapInfo(
                               rawValue: CGImageAlphaInfo.none.rawValue),
                           provider: provider, decode: nil,
                           shouldInterpolate: true, intent: .defaultIntent)
        }

        // MARK: Nodes

        func decodeNodes(_ map: [String: Any]) {
            // Pass 1: create every node so children/animation bindings can
            // reference ids declared later in the map.
            for (token, any) in map {
                guard let key = D3Wire.localIdKey(token),
                      let spec = any as? [String: Any] else { continue }
                let node = SCNNode()
                decodeNodeFields(key: key, node: node, spec: spec)
                nodes[key] = node
            }
            // Pass 2: wire the hierarchy.
            for (token, any) in map {
                guard let key = D3Wire.localIdKey(token),
                      let parent = nodes[key],
                      let spec = any as? [String: Any] else { continue }
                for childToken in spec["children"] as? [Any] ?? [] {
                    guard let ct = childToken as? String,
                          let ck = D3Wire.localIdKey(ct),
                          let child = nodes[ck] else { continue }
                    parent.addChildNode(child)
                }
            }
        }

        /// Pass-1 decode of one node entry — name, transform,
        /// visibility, layers, then components. Children are wired
        /// separately: the manifest's pass 2 handles `spec.children`,
        /// while an `addNode` command attaches via its own `parent`
        /// field, so the surgical ops share this body.
        func decodeNodeFields(key: UInt64, node: SCNNode,
                              spec: [String: Any]) {
            if let name = spec["name"] as? String { node.name = name }
            decodeTransform(node, spec["transform"])
            if spec["visible"] as? Bool == false { node.isHidden = true }
            if let layers = spec["layers"] as? Int, layers != 1 {
                node.categoryBitMask = layers
            }
            // `skin` is a node member, not a component — record the
            // binding; the skinner attaches once the skin record and
            // the mesh's geometry both exist (`resolveSkinAttachments`
            // on the manifest path, the op paths re-attach inline).
            if let token = spec["skin"] as? String,
               let skinKey = D3Wire.localIdKey(token) {
                nodeSkinKeys[key] = skinKey
            } else {
                nodeSkinKeys.removeValue(forKey: key)
            }
            let comps = spec["components"] as? [Any] ?? []
            colliderIndexByKey[key] = comps.firstIndex {
                ($0 as? [String: Any])?["type"] as? String == "collider"
            }
            for (i, c) in comps.enumerated() {
                decodeComponent(key: key, node: node, index: i, spec: c)
            }
        }

        func attachRoots(_ roots: [Any]) {
            for any in roots {
                guard let token = any as? String,
                      let key = D3Wire.localIdKey(token),
                      let node = nodes[key] else { continue }
                scene.rootNode.addChildNode(node)
            }
        }

        func decodeTransform(_ node: SCNNode, _ any: Any?) {
            guard let t = any as? [String: Any] else { return }
            if let trs = t["trs"] as? [String: Any] {
                if let v = trs["t"] as? [Double] { node.position = D3Wire.position(v) }
                if let v = trs["r"] as? [Double] { node.orientation = D3Wire.quaternion(v) }
                if let v = trs["s"] as? [Double] { node.scale = D3Wire.scale(v) }
            } else if let m = t["matrix"] as? [Double], m.count == 16 {
                node.transform = D3Wire.matrix(m)
            }
        }

        // MARK: Components

        func decodeComponent(key: UInt64, node: SCNNode, index: Int,
                             spec any: Any) {
            guard let spec = any as? [String: Any],
                  let type = spec["type"] as? String else { return }
            let props = spec["properties"] as? [String: Any] ?? [:]
            // Universal `enabled` (W12) — upstream's component wrapper
            // applies it around update/fixedUpdate callbacks only; it
            // does not remove the realized state (an enabled:false
            // light still lights). dart3d components have no tick
            // surface, so the flag is recorded for parity, not applied.
            if d3Bool(props["enabled"]) == false {
                disabledComponents[key, default: []].insert(index)
                host.logOnce("enabled.\(key).\(index)",
                    "component '\(type)' on node \(key): enabled:false "
                    + "gates upstream component ticks only; dart3d has "
                    + "no tick surface — recorded, not applied")
            }
            switch type {
            case "mesh":            decodeMesh(key, node, props)
            case "camera":          decodeCamera(node, props)
            case "directionalLight": decodeLight(node, props, .directional)
            case "pointLight":       decodeLight(node, props, .omni)
            case "spotLight":        decodeLight(node, props, .spot)
            case "rectAreaLight":    decodeLight(node, props, .area)
            case "rigidBody", "collider", "physicsWorld":
                physicsDeferred.append((key, node, type, props))
            case "fixedJoint", "sphericalJoint", "revoluteJoint",
                 "prismaticJoint", "genericJoint":
                jointComponentsDeferred.append((key, index, type, props))
            case "materialsVariants":
                decodeMaterialsVariants(key: key, index: index, props: props)
            default:
                d3Log("unhandled component type '\(type)'")
            }
        }

        /// W12: maps a declarative joint component's upstream property
        /// names onto the `addJoint`/`updateJoint` wire shape, so the
        /// host's one constraint path serves both. An absent or
        /// self-referencing `otherNode` produces no `b` — the record
        /// anchors to the world, matching upstream's fixed world body.
        private func translateJointComponent(
            key: UInt64, type: String, props: [String: Any]
        ) -> [String: Any]? {
            let jt: String
            switch type {
            case "fixedJoint":     jt = "fixed"
            case "sphericalJoint": jt = "spherical"
            case "revoluteJoint":  jt = "revolute"
            case "prismaticJoint": jt = "prismatic"
            case "genericJoint":   jt = "generic"
            default: return nil
            }
            var json: [String: Any] = [
                "type": jt,
                "a": D3Wire.localIdToken(key),
                "collide": d3Bool(props["collisionsEnabled"]) ?? false,
            ]
            if let b = d3Ref(props["otherNode"]) {
                json["b"] = D3Wire.localIdToken(b)
            }
            if let v = d3Vec3(props["localAnchorA"]) { json["anchorA"] = v }
            if let v = d3Vec3(props["localAnchorB"]) { json["anchorB"] = v }
            if let v = d3Vec3(props["localAxisA"]) { json["axisA"] = v }
            if let v = d3Vec3(props["localAxisB"]) { json["axisB"] = v }
            if let d = d3Double(props["lowerLimit"]) { json["lower"] = d }
            if let d = d3Double(props["upperLimit"]) { json["upper"] = d }
            if let d = d3Double(props["motorTargetVelocity"]) {
                json["motorVelocity"] = d
            }
            if let d = d3Double(props["motorMaxForce"]) {
                json["motorMaxForce"] = d
            }
            if let q = d3Quat(props["localBasisA"]) { json["basisA"] = q }
            if let q = d3Quat(props["localBasisB"]) { json["basisB"] = q }
            // Generic axes arrive keyed by name; the wire carries them
            // as the ordered array decodeJointAxes expects. An absent
            // axis (or a wholly absent `axes` member) defaults to free
            // — upstream's GenericJointDesc default.
            if jt == "generic" {
                let cfg = d3Map(props["axes"]) ?? [:]
                var axes: [[String: Any]] = []
                for name in ["linearX", "linearY", "linearZ",
                             "angularX", "angularY", "angularZ"] {
                    let m = d3Map(cfg[name]) ?? [:]
                    var axis: [String: Any] = [
                        "motion": d3String(m["motion"]) ?? "free"
                    ]
                    if let d = d3Double(m["lowerLimit"]) {
                        axis["lower"] = d
                    }
                    if let d = d3Double(m["upperLimit"]) {
                        axis["upper"] = d
                    }
                    if let motor = d3Map(m["motor"]) {
                        var mj: [String: Any] = [:]
                        for f in ["targetPosition", "targetVelocity",
                                  "stiffness", "damping", "maxForce"] {
                            if let d = d3Double(motor[f]) { mj[f] = d }
                        }
                        if let s = d3String(motor["model"]) {
                            mj["model"] = s
                        }
                        if !mj.isEmpty { axis["motor"] = mj }
                    }
                    axes.append(axis)
                }
                json["axes"] = axes
            }
            return json
        }

        // MARK: Material variants (W12)

        /// Decodes a `materialsVariants` component (upstream
        /// `KHR_materials_variants`): the variant name list, the
        /// selected name, and the bindings — each a node ref +
        /// primitive index + declared default material + a
        /// variant-index → material map. Bindings resolve at apply
        /// time so a target node that lands later still binds.
        private func decodeMaterialsVariants(
            key: UInt64, index: Int, props: [String: Any]
        ) {
            let variants = (d3List(props["variants"]) ?? [])
                .compactMap { d3String($0) }
            var bindings: [VariantBindingSpec] = []
            for entry in d3List(props["bindings"]) ?? [] {
                guard let m = d3Map(entry),
                      let nodeKey = d3Ref(m["node"]),
                      let primitive = d3Int(m["primitive"]),
                      primitive >= 0 else { continue }
                var byVariant: [Int: UInt64] = [:]
                for (name, ref) in d3Map(m["materials"]) ?? [:] {
                    guard let idx = Int(name),
                          let matKey = d3Ref(ref) else { continue }
                    byVariant[idx] = matKey
                }
                bindings.append(VariantBindingSpec(
                    nodeKey: nodeKey, primitive: primitive,
                    defaultMaterialKey: d3Ref(m["default"]),
                    materialsByVariant: byVariant))
            }
            variantComponents[key] = VariantComponentSpec(
                nodeKey: key, compIndex: index, variants: variants,
                selected: d3String(props["selected"]),
                bindings: bindings)
            host.logOnce("variants.\(key).\(index)",
                "materialsVariants on node \(key): \(variants.count) "
                + "variants, \(bindings.count) bindings"
                + ", selected=\(d3String(props["selected"]) ?? "-")")
        }

        /// Applies every variant component's selection — called after
        /// the node pass on the manifest path, after a surgical
        /// components decode, and by the host's `selectVariant` op.
        /// Unresolved bindings (target node or geometry not yet live)
        /// stay pending; the landing retries re-attempt them.
        func applyVariantComponents() {
            for key in variantComponents.keys.sorted() {
                guard var vc = variantComponents[key] else { continue }
                let selIdx = vc.selected
                    .flatMap { vc.variants.firstIndex(of: $0) }
                for i in vc.bindings.indices {
                    applyVariantBinding(&vc.bindings[i],
                                        variantIndex: selIdx)
                }
                variantComponents[key] = vc
            }
        }

        /// Applies one binding: writes `geometry.materials[primitive]`
        /// with the variant's mapped material, or the binding's default
        /// when the variant has no mapping (or none is selected).
        /// Upstream's rebase rule: a slot content that is neither this
        /// binding's last write nor a variant-mapped material wins and
        /// becomes the new default — an explicitly assigned mesh
        /// material is not silently reverted.
        private func applyVariantBinding(
            _ b: inout VariantBindingSpec, variantIndex: Int?
        ) {
            guard let node = resolveNode(b.nodeKey) else {
                host.logOnce("variant.unresolved.\(b.nodeKey)",
                    "materialsVariants binding: node \(b.nodeKey) not "
                    + "live yet; pending")
                return
            }
            // The binding's `primitive` indexes the mesh's primitives —
            // prim 0 rides node.geometry; extras park on `d3prim:i`
            // children, each carrying exactly one material slot.
            let geo: SCNGeometry?
            if b.primitive == 0 {
                geo = node.geometry
            } else {
                geo = node.childNodes
                    .first { $0.name == "d3prim:\(b.primitive)" }?
                    .geometry
            }
            guard let geo else {
                host.logOnce("variant.unresolved.\(b.nodeKey)",
                    "materialsVariants binding: node \(b.nodeKey) or its "
                    + "geometry not live yet; pending")
                return
            }
            guard !geo.materials.isEmpty else {
                b.resolved = true
                host.logOnce("variant.binding.\(b.nodeKey).\(b.primitive)",
                    "materialsVariants binding: node \(b.nodeKey) has "
                    + "no primitive \(b.primitive); dropped")
                return
            }
            let current = geo.materials[0]
            if b.defaultMaterial == nil {
                b.defaultMaterial =
                    b.defaultMaterialKey.flatMap { materials[$0] }
            }
            let variantMats = b.materialsByVariant.values
                .compactMap { materials[$0] }
            if current !== b.applied
                && current !== b.defaultMaterial
                && !variantMats.contains(where: { $0 === current }) {
                b.defaultMaterial = current
            }
            let variantKey = variantIndex
                .flatMap { b.materialsByVariant[$0] }
            let target = variantKey
                .flatMap { materials[$0] }
                ?? b.defaultMaterial ?? current
            var which = "current"
            if target === b.defaultMaterial { which = "default" }
            else if let vk = variantKey,
                    target === materials[vk] { which = "variant" }
            d3Log("variant apply node=\(b.nodeKey) prim=\(b.primitive) "
                + "selIdx=\(variantIndex.map(String.init) ?? "-") "
                + "vkey=\(variantKey.map(String.init) ?? "-") "
                + "vmap=\(b.materialsByVariant.count) target=\(which)")
            geo.materials[0] = target
            b.applied = target
            b.resolved = true
        }

        // MARK: Physics

        /// Runs after the node pass: colliders produce shapes (possibly
        /// from node geometry), bodies attach those shapes, `physicsWorld`
        /// configures the scene. Upstream keeps surface material and the
        /// collision layer/mask on the collider; SceneKit has no per-shape
        /// material, so they fold onto the body at attach time.
        func decodePhysicsDeferred() {
            var colliders: [UInt64:
                (shape: SCNPhysicsShape?, friction: Double?,
                 restitution: Double?, layer: Int?, mask: Int?,
                 trigger: Bool)] = [:]
            for item in physicsDeferred where item.type == "collider" {
                colliders[item.key] = decodeCollider(item.node, item.props)
                // Geometry-derived kinds return a nil shape while the
                // node's geometry is still payload-deferred — the body
                // then attaches shapeless and SceneKit never re-derives
                // it (Android defers the body instead). Record the
                // intended derivation; `decodeMesh` refills the shape
                // when the geometry lands.
                if colliders[item.key]?.shape == nil,
                   item.node.geometry == nil,
                   let kind = d3String(
                       d3Map(item.props["shape"])?["kind"]) {
                    let t: SCNPhysicsShape.ShapeType?
                    switch kind {
                    case "boundingBox": t = .boundingBox
                    case "convexHull": t = .convexHull
                    case "triMesh", "concaveMesh":
                        t = .concavePolyhedron
                    default: t = nil
                    }
                    if let t {
                        host.pendingColliderShapes[item.key] = t
                    }
                }
            }
            for item in physicsDeferred where item.type == "rigidBody" {
                decodeRigidBody(item.key, item.node, item.props,
                                collider: colliders[item.key])
            }
            for item in physicsDeferred where item.type == "physicsWorld" {
                if let g = d3Vec3(item.props["gravity"]), g.count >= 3 {
                    scene.physicsWorld.gravity = D3Wire.position(g)
                    host.worldGravityScale =
                        (g[0] * g[0] + g[1] * g[1] + g[2] * g[2])
                            .squareRoot()
                }
                if let dt = d3Double(item.props["fixedTimestep"]),
                   dt > 0 {
                    // SceneKit steps the world at this fixed interval —
                    // halving it quarters the contact-overshoot noise
                    // that keeps mm-scale bodies awake forever.
                    scene.physicsWorld.timeStep = dt
                }
                if let backend = d3String(item.props["backend"]),
                   backend != "basic" {
                    host.logOnce("world.backend.\(backend)",
                        "physicsWorld backend '\(backend)' requested; "
                        + "iOS always uses SceneKit physics")
                }
                // `maxSubsteps` is accepted but advisory: SceneKit
                // clamps substeps internally (and drops time rather
                // than spiral).
            }
            // W12 declarative joint components ride the command-built
            // constraint machinery — translated to the wire joint shape
            // and registered under the component handle range, so
            // deferral, rebinding and the break sweep apply unchanged.
            for item in jointComponentsDeferred {
                guard let json = translateJointComponent(
                    key: item.key, type: item.type, props: item.props)
                else { continue }
                host.registerComponentJoint(
                    nodeKey: item.key, componentIndex: item.index,
                    json: json)
            }
            for (key, node) in nodes {
                let b = node.physicsBody
                let kind = b.map { String(describing: $0.type) } ?? "nil"
                let hasShape = b?.physicsShape != nil
                d3Log("node \(key): body=\(kind)"
                    + " shape=\(hasShape) pos=\(node.position.y)"
                    + " cat=\(b.map { String($0.categoryBitMask, radix: 16) } ?? "-")"
                    + " mask=\(b.map { String($0.collisionBitMask, radix: 16) } ?? "-")")
            }
        }

        /// Decodes one collider component: the `shape` tagged union, the
        /// `material` map (friction/restitution fold onto the body;
        /// density and combine rules have no SceneKit home), the
        /// `collisionLayer`/`collisionMask` bitmasks, `isTrigger`, and the
        /// `localPose` offset applied as a shape transform.
        func decodeCollider(_ node: SCNNode, _ p: [String: Any])
            -> (shape: SCNPhysicsShape?, friction: Double?,
                restitution: Double?, layer: Int?, mask: Int?,
                trigger: Bool)
        {
            var shape: SCNPhysicsShape?
            if let m = d3Map(p["shape"]) {
                shape = decodeShape(m, node: node)
            } else if p["shape"] != nil {
                d3Log("collider 'shape': expected a tagged-union map")
            } else {
                // Absent → the schema default: unit box.
                shape = decodeShape(["kind": ["s": "box"]], node: node)
            }
            if let pose = d3Mat4(p["localPose"]) {
                if let built = shape {
                    // Per-shape transforms only exist on compound shapes,
                    // so a lone shape wraps as a one-child compound.
                    shape = SCNPhysicsShape(
                        shapes: [built],
                        transforms: [NSValue(scnMatrix4: pose)])
                } else {
                    d3Log("collider localPose: no concrete shape to offset")
                }
            }
            var friction: Double?
            var restitution: Double?
            if let material = d3Map(p["material"]) {
                friction = d3Double(material["friction"])
                restitution = d3Double(material["restitution"])
                for key in ["frictionCombine", "restitutionCombine"] {
                    if let rule = d3String(material[key]),
                       rule != "average" {
                        host.logOnce("material.\(key).\(rule)",
                            "collider material \(key) '\(rule)' is not "
                            + "expressible on SceneKit; using average")
                    }
                }
                // `density` is accepted and ignored — SceneKit derives
                // no mass from it; body.mass is the only override.
            }
            let layer = d3Int(p["collisionLayer"])
            let mask = d3Int(p["collisionMask"])
            // A trigger gives no contact response — bodies pass through.
            // SceneKit expresses that as a zero collisionBitMask; the
            // category stays intact so W8's contact events can still
            // sense the overlap.
            let trigger = d3Bool(p["isTrigger"]) == true
            if trigger {
                host.logOnce("collider.isTrigger",
                    "collider isTrigger: pass-through via "
                    + "collisionBitMask=0; trigger events land in W8")
            }
            return (shape, friction, restitution, layer, mask, trigger)
        }

        /// One level of the collider `shape` tagged union; `compound`
        /// recurses through it for each child. `convexHull`/`triMesh`
        /// (and the `concaveMesh` extension) keep the dart3d behaviour of
        /// deriving the shape from the node's realized geometry — explicit
        /// payload tokens resolve in W3. `boundingBox` returns nil so the
        /// body falls back to the geometry's box.
        func decodeShape(_ m: [String: Any], node: SCNNode)
            -> SCNPhysicsShape?
        {
            let kind = d3String(m["kind"]) ?? "box"
            switch kind {
            case "box":
                // `halfExtents` is already half size — the old `extents`
                // field was full size and is gone.
                let h = d3Vec3(m["halfExtents"]) ?? [0.5, 0.5, 0.5]
                return SCNPhysicsShape(geometry: SCNBox(
                    width: CGFloat(h[0] * 2), height: CGFloat(h[1] * 2),
                    length: CGFloat(h[2] * 2), chamferRadius: 0))
            case "sphere":
                return SCNPhysicsShape(geometry: SCNSphere(
                    radius: CGFloat(d3Double(m["radius"]) ?? 0.5)))
            case "capsule":
                let r = d3Double(m["radius"]) ?? 0.5
                // `halfHeight` is the cylindrical section's half length;
                // SCNCapsule wants the total height, caps included.
                let h = d3Double(m["halfHeight"]) ?? 0.5
                return SCNPhysicsShape(geometry: SCNCapsule(
                    capRadius: CGFloat(r),
                    height: CGFloat(2 * h + 2 * r)))
            case "cylinder":
                let r = d3Double(m["radius"]) ?? 0.5
                let h = d3Double(m["halfHeight"]) ?? 0.5
                return SCNPhysicsShape(geometry: SCNCylinder(
                    radius: CGFloat(r), height: CGFloat(2 * h)))
            case "convexHull":
                let value = m["vertices"] ?? m["points"]
                if let token = payloadToken(value),
                   let geometry = colliderGeometry(
                        vertices: token, indices: nil, kind: kind) {
                    return SCNPhysicsShape(
                        geometry: geometry,
                        options: [.type: SCNPhysicsShape.ShapeType.convexHull])
                }
                if value != nil, payloadToken(value) == nil {
                    host.logOnce("shape.\(kind).vertexToken",
                        "collider '\(kind)': invalid vertices payload token; "
                        + "deriving from node geometry")
                }
                return derivedShape(node, .convexHull, kind)
            case "triMesh", "concaveMesh":
                let vertexValue = m["vertices"]
                let indexValue = m["indices"]
                if let vertexToken = payloadToken(vertexValue),
                   let indexToken = payloadToken(indexValue),
                   let geometry = colliderGeometry(
                        vertices: vertexToken, indices: indexToken,
                        kind: kind) {
                    return SCNPhysicsShape(
                        geometry: geometry,
                        options: [.type:
                            SCNPhysicsShape.ShapeType.concavePolyhedron])
                }
                if vertexValue != nil || indexValue != nil,
                   payloadToken(vertexValue) == nil
                    || payloadToken(indexValue) == nil {
                    host.logOnce("shape.\(kind).payloadTokens",
                        "collider '\(kind)': vertices and indices payload "
                        + "tokens are required; deriving from node geometry")
                }
                return derivedShape(node, .concavePolyhedron, kind)
            case "heightField":
                host.logOnce("shape.heightField",
                    "collider 'heightField': deferred to W3+; skipped")
                return nil
            case "compound":
                var shapes: [SCNPhysicsShape] = []
                var transforms: [NSValue] = []
                for entry in d3List(m["children"]) ?? [] {
                    guard let child = d3Map(entry),
                          let childShape = d3Map(child["shape"])
                            .flatMap({ decodeShape($0, node: node) })
                    else { continue }
                    shapes.append(childShape)
                    transforms.append(NSValue(scnMatrix4:
                        d3Mat4(child["localPose"]) ?? SCNMatrix4Identity))
                }
                guard !shapes.isEmpty else {
                    d3Log("collider 'compound': no decodable children")
                    return nil
                }
                return SCNPhysicsShape(shapes: shapes,
                                       transforms: transforms)
            case "boundingBox":
                // Upstream semantics: the geometry's *declared* bounds
                // (payload `bounds` spec), which may be wider than the
                // vertices. `.boundingBox` shape-type derives from the
                // vertex box instead, so build the box explicitly.
                if let geo = node.geometry { return boundsBoxShape(geo) }
                return nil   // deferred fill when the geometry lands
            default:
                d3Log("unknown collider shape kind '\(kind)'")
                return nil
            }
        }

        func payloadToken(_ any: Any?) -> String? {
            any as? String ?? d3String(any)
        }

        func colliderGeometry(vertices token: String, indices: String?,
                              kind: String) -> SCNGeometry? {
            guard let key = D3Wire.localIdKey(token) else {
                host.logOnce("shape.\(kind).vertices.id",
                    "collider '\(kind)': invalid vertices payload token; "
                    + "deriving from node geometry")
                return nil
            }
            guard let spec = payloadSpecs[key] else {
                host.logOnce("shape.\(kind).vertices.spec.\(key)",
                    "collider '\(kind)': vertices payload has no spec; "
                    + "deriving from node geometry")
                return nil
            }
            guard let data = host.payloadStore[key] else {
                host.logOnce("shape.\(kind).vertices.awaiting.\(key)",
                    "collider '\(kind)': vertices payload unavailable; "
                    + "deriving from node geometry")
                return nil
            }
            guard let positions = colliderPositions(
                data, spec: spec, payloadKey: key, kind: kind) else {
                return nil
            }
            let count = positions.count / 3
            let source = floatSource(positions, .vertex, count, 3)
            guard let indexToken = indices else {
                return SCNGeometry(sources: [source], elements: [])
            }
            guard let element = colliderElement(
                indexToken, vertexCount: count, kind: kind) else { return nil }
            return SCNGeometry(sources: [source], elements: [element])
        }

        func colliderPositions(
            _ data: Data, spec: PayloadSpec, payloadKey: UInt64, kind: String
        ) -> [Float]? {
            let layout = spec.layout ?? "unskinned"
            let stride: Int
            let soa: Bool
            let nativeSpace: Bool
            switch spec.encoding {
            case "floats":
                stride = 12; soa = false; nativeSpace = false
            case "vertexBuffer":
                switch layout {
                case "unskinned_uv1_tangent":
                    stride = 72; soa = false; nativeSpace = false
                case "unskinned_soa_uv1_tangent":
                    stride = 72; soa = true; nativeSpace = false
                case "skinned_uv1_tangent":
                    stride = 104; soa = false; nativeSpace = false
                case "unskinned":
                    stride = 48; soa = false; nativeSpace = false
                case "unskinned_soa":
                    stride = 48; soa = true; nativeSpace = false
                case "skinned":
                    stride = 80; soa = false; nativeSpace = false
                case "p3t4":
                    stride = 28; soa = false; nativeSpace = true
                default:
                    host.logOnce("shape.\(kind).layout.\(layout)",
                        "collider '\(kind)': unknown vertex layout "
                        + "'\(layout)'; deriving from node geometry")
                    return nil
                }
            default:
                host.logOnce("shape.\(kind).encoding.\(spec.encoding)",
                    "collider '\(kind)': vertices encoding "
                    + "'\(spec.encoding)' is not floats or vertexBuffer; "
                    + "deriving from node geometry")
                return nil
            }
            guard !data.isEmpty, data.count % stride == 0 else {
                host.logOnce("shape.\(kind).vertexStride.\(payloadKey)",
                    "collider '\(kind)': malformed vertices payload; "
                    + "deriving from node geometry")
                return nil
            }
            let count = data.count / stride
            var positions: [Float] = []
            positions.reserveCapacity(count * 3)
            for i in 0..<count {
                let offset = data.startIndex + (soa ? i * 12 : i * stride)
                positions.append(D3Wire.f32LE(data, offset))
                positions.append(D3Wire.f32LE(data, offset + 4))
                let z = D3Wire.f32LE(data, offset + 8)
                positions.append(nativeSpace ? z : -z)
            }
            return positions
        }

        func colliderElement(_ token: String, vertexCount: Int, kind: String)
            -> SCNGeometryElement? {
            guard let key = D3Wire.localIdKey(token) else {
                host.logOnce("shape.\(kind).indices.id",
                    "collider '\(kind)': invalid indices payload token; "
                    + "deriving from node geometry")
                return nil
            }
            guard let spec = payloadSpecs[key] else {
                host.logOnce("shape.\(kind).indices.spec.\(key)",
                    "collider '\(kind)': indices payload has no spec; "
                    + "deriving from node geometry")
                return nil
            }
            guard spec.encoding == "indexBuffer" else {
                host.logOnce("shape.\(kind).indices.encoding.\(key)",
                    "collider '\(kind)': indices encoding "
                    + "'\(spec.encoding)' is not indexBuffer; deriving "
                    + "from node geometry")
                return nil
            }
            let format = spec.format ?? "uint16"
            let bytesPerIndex: Int
            switch format {
            case "uint16": bytesPerIndex = 2
            case "uint32": bytesPerIndex = 4
            default:
                host.logOnce("shape.\(kind).indices.format.\(format)",
                    "collider '\(kind)': unknown index format '\(format)'; "
                    + "deriving from node geometry")
                return nil
            }
            guard let data = host.payloadStore[key] else {
                host.logOnce("shape.\(kind).indices.awaiting.\(key)",
                    "collider '\(kind)': indices payload unavailable; "
                    + "deriving from node geometry")
                return nil
            }
            guard !data.isEmpty, data.count % (bytesPerIndex * 3) == 0 else {
                host.logOnce("shape.\(kind).indexStride.\(key)",
                    "collider '\(kind)': malformed triangle indices; "
                    + "deriving from node geometry")
                return nil
            }
            for offset in stride(from: 0, to: data.count,
                                 by: bytesPerIndex) {
                let index: UInt32
                if bytesPerIndex == 2 {
                    let lo = UInt16(data[data.startIndex + offset])
                    let hi = UInt16(data[data.startIndex + offset + 1])
                    index = UInt32(lo | hi << 8)
                } else {
                    index = D3Wire.u32LE(data, data.startIndex + offset)
                }
                guard index < UInt32(vertexCount) else {
                    host.logOnce("shape.\(kind).indexRange.\(key)",
                        "collider '\(kind)': triangle index is out of range; "
                        + "deriving from node geometry")
                    return nil
                }
            }
            return SCNGeometryElement(
                data: data, primitiveType: .triangles,
                primitiveCount: data.count / (bytesPerIndex * 3),
                bytesPerIndex: bytesPerIndex)
        }

        /// Builds a physics shape from the node's realized geometry.
        func derivedShape(_ node: SCNNode, _ t: SCNPhysicsShape.ShapeType,
                          _ kind: String) -> SCNPhysicsShape? {
            guard let geo = node.geometry else {
                d3Log("collider '\(kind)': node has no geometry")
                return nil
            }
            // Multi-primitive meshes park extra primitives on `d3prim:`
            // children — the shape covers every primitive; deriving
            // from primitive 0 alone under-covers the mesh.
            let extras = node.childNodes
                .filter { $0.name?.hasPrefix("d3prim:") == true }
                .compactMap { $0.geometry }
            guard !extras.isEmpty else {
                if t == .boundingBox { return boundsBoxShape(geo) }
                return SCNPhysicsShape(geometry: geo, options: [.type: t])
            }
            if t == .boundingBox {
                var lo = geo.boundingBox.min
                var hi = geo.boundingBox.max
                for g in extras {
                    lo = SCNVector3(
                        min(lo.x, g.boundingBox.min.x),
                        min(lo.y, g.boundingBox.min.y),
                        min(lo.z, g.boundingBox.min.z))
                    hi = SCNVector3(
                        max(hi.x, g.boundingBox.max.x),
                        max(hi.y, g.boundingBox.max.y),
                        max(hi.z, g.boundingBox.max.z))
                }
                return boundsBoxShape(min: lo, max: hi)
            }
            // Compound of per-primitive shapes — exact for
            // concaveMesh, a conservative union for convexHull.
            let parts = ([geo] + extras).map {
                SCNPhysicsShape(geometry: $0, options: [.type: t])
            }
            return SCNPhysicsShape(shapes: parts, transforms: nil)
        }

        /// A box collider matching the geometry's *declared* bounds —
        /// authored `bounds` win over vertex extents (that's the margin
        /// behavior boundsQuad-style colliders exist for). Falls back
        /// to nil for a degenerate (zero-size) box so callers can
        /// choose the auto-derive path.
        func boundsBoxShape(_ geo: SCNGeometry) -> SCNPhysicsShape? {
            boundsBoxShape(min: geo.boundingBox.min,
                           max: geo.boundingBox.max)
        }

        func boundsBoxShape(min bMin: SCNVector3,
                            max bMax: SCNVector3) -> SCNPhysicsShape? {
            let w = bMax.x - bMin.x
            let h = bMax.y - bMin.y
            let l = bMax.z - bMin.z
            guard w > 0, h > 0, l > 0 else { return nil }
            let shape = SCNPhysicsShape(geometry: SCNBox(
                width: CGFloat(w), height: CGFloat(h),
                length: CGFloat(l), chamferRadius: 0))
            let cx = (bMin.x + bMax.x) / 2
            let cy = (bMin.y + bMax.y) / 2
            let cz = (bMin.z + bMax.z) / 2
            if cx == 0 && cy == 0 && cz == 0 { return shape }
            return SCNPhysicsShape(shapes: [shape], transforms: [
                NSValue(scnMatrix4: SCNMatrix4Translate(
                    SCNMatrix4Identity, cx, cy, cz)),
            ])
        }

        /// Decodes one rigidBody component. Surface material and
        /// collision masks live on the sibling collider upstream;
        /// `velocity`/`angularVelocity` are dart3d extension properties
        /// (initial launch state upstream chooses not to persist).
        func decodeRigidBody(
            _ key: UInt64, _ node: SCNNode, _ p: [String: Any],
            collider: (shape: SCNPhysicsShape?, friction: Double?,
                       restitution: Double?, layer: Int?, mask: Int?,
                       trigger: Bool)?
        ) {
            let typeName = d3String(p["type"]) ?? "dynamic"
            let type: SCNPhysicsBodyType
            switch typeName {
            case "fixed":     type = .static
            case "kinematic": type = .kinematic
            case "dynamic":   type = .dynamic
            default:
                d3Log("unknown rigidBody type '\(typeName)'; using dynamic")
                type = .dynamic
            }
            let body = SCNPhysicsBody(type: type, shape: collider?.shape ?? nil)
            if let v = d3Double(p["mass"]) { body.mass = CGFloat(v) }
            if let v = collider?.friction { body.friction = CGFloat(v) }
            if let v = collider?.restitution { body.restitution = CGFloat(v) }
            if let v = d3Double(p["linearDamping"]) {
                body.damping = CGFloat(v)
            }
            if let v = d3Double(p["angularDamping"]) {
                body.angularDamping = CGFloat(v)
            }
            // Axis locks are per-axis motion factors (1 free, 0 locked) —
            // applied unmirrored, like every other factor field.
            if let v = d3Vec3(p["linearAxisLocks"]) {
                body.velocityFactor = SCNVector3(
                    Float(v[0]), Float(v[1]), Float(v[2]))
            }
            if let v = d3Vec3(p["angularAxisLocks"]) {
                body.angularVelocityFactor = SCNVector3(
                    Float(v[0]), Float(v[1]), Float(v[2]))
            }
            if let v = d3Bool(p["useGravity"]) {
                body.isAffectedByGravity = v
            }
            if let v = d3Bool(p["allowsResting"]) {
                body.allowsResting = v
            }
            if d3Bool(p["ccdEnabled"]) == true {
                // The threshold is the minimum per-step travel that
                // engages CCD — and 0.0 is Apple's "off" sentinel
                // ("discrete collision detection at all times"), not
                // always-on. The smallest nonzero threshold is the
                // closest SceneKit gets to the spec's always-on intent.
                body.continuousCollisionDetectionThreshold =
                    .leastNonzeroMagnitude
            }
            // SceneKit reserves category bits 0 (Default) and 1 (Static),
            // and static bodies force-exclude bit 1 from their collision
            // mask — a body categorised exactly 0x2 can never contact any
            // static. The wire's layer space shifts left 2 to clear the
            // reserved bits; an absent layer maps to user bit 0 so an
            // explicit mask of 0x1 still reaches unlayered bodies.
            body.categoryBitMask = (collider?.layer ?? 1) << 2
            if let v = collider?.mask { body.collisionBitMask = v << 2 }
            if collider?.trigger == true { body.collisionBitMask = 0 }
            // Upstream reports every contact, so the delegate gate is
            // open for all pairs — sensors included (their zero
            // collisionBitMask suppresses only the response).
            body.contactTestBitMask = ~0
            // dart3d extensions: initial velocities. Both convert through
            // the LH→RH z-mirror — linear as a vector, angular as
            // axis+rate with the axis mirrored like a quaternion axis.
            if let v = d3Vec3(p["velocity"]) {
                let w = D3Wire.position(v)
                body.velocity = SCNVector3(w.x, w.y, w.z)
            }
            if let a = d3Vec4(p["angularVelocity"]) {
                body.angularVelocity = SCNVector4(
                    Float(-a[0]), Float(-a[1]), Float(a[2]), Float(a[3]))
            }
            node.physicsBody = body
            if type == .dynamic { dynamicBodyKeys.insert(key) }
        }

        func decodeMesh(_ key: UInt64, _ node: SCNNode,
                        _ p: [String: Any]) {
            // Upstream mesh vocab: a single-primitive mesh carries
            // direct `geometry`/`material` refs; a multi-primitive
            // mesh carries `primitives` — a tagged list whose entries
            // are `{"map":{geometry,material}}` PropertyValues.
            var primGeoKeys: [UInt64] = []
            var primMatKeys: [UInt64?] = []
            if let g = d3Ref(p["geometry"]) {
                primGeoKeys = [g]
                primMatKeys = [d3Ref(p["material"])]
            } else if let list = d3List(p["primitives"]) {
                for e in list {
                    guard let m = d3Map(e),
                          let g = d3Ref(m["geometry"]) else { continue }
                    primGeoKeys.append(g)
                    primMatKeys.append(d3Ref(m["material"]))
                }
            }
            // The consumer registers on the first primitive's key even
            // while the geometry is unresolved — a deferred geometry
            // still rebinds this node when its upsert/payload lands.
            // Extra primitives' consumers are their own child nodes,
            // registered once those children exist below.
            if let g0 = primGeoKeys.first {
                var list = geometryConsumers[g0] ?? []
                if !list.contains(where: { $0 === node }) {
                    list.append(node)
                    geometryConsumers[g0] = list
                }
            }
            // All-or-nothing — a partial build renders a fraction of
            // the mesh. Unresolved primitives defer the whole decode;
            // the manifest re-realizes when the payload lands.
            var primGeos: [SCNGeometry] = []
            for gk in primGeoKeys {
                guard let base = geometries[gk] else {
                    // No geometry yet — a skinned node can't take its
                    // skinner (the skinner holds the base geometry), so
                    // hold it pending for the geometry's arrival.
                    if nodeSkinKeys[key] != nil {
                        pendingSkinNodes.insert(key)
                    }
                    d3Log("mesh node '\(node.name ?? "?")': geometry unresolved")
                    return
                }
                primGeos.append((base.copy() as? SCNGeometry) ?? base)
            }
            guard let geo = primGeos.first else {
                if nodeSkinKeys[key] != nil {
                    pendingSkinNodes.insert(key)
                }
                d3Log("mesh node '\(node.name ?? "?")': geometry unresolved")
                return
            }
            // Per-primitive materials — each geometry copy registers
            // itself as the material's consumer so a surgical upsert
            // retargets the right primitive.
            for (i, g) in primGeos.enumerated() {
                guard let ref = primMatKeys[i],
                      let m = materials[ref] else { continue }
                g.materials = [m]
                let existing = materialConsumers[ref] ?? []
                if !existing.contains(where: { $0 === g }) {
                    materialConsumers[ref] = existing + [g]
                }
            }
            // SceneKit binds one geometry per node — extra primitives
            // ride anonymous children that inherit the node transform.
            // Rebuilt each decode so re-realizes don't duplicate them;
            // stale children are purged from the consumer maps so a
            // surgical upsert never retargets a detached node.
            let stalePrims = node.childNodes.filter {
                $0.name?.hasPrefix("d3prim:") == true
            }
            for child in stalePrims {
                for gk in geometryConsumers.keys {
                    geometryConsumers[gk]?.removeAll { $0 === child }
                }
                for mk in materialConsumers.keys {
                    materialConsumers[mk]?.removeAll {
                        $0 === child.geometry
                    }
                }
                child.removeFromParentNode()
            }
            for i in 1..<primGeos.count {
                let child = SCNNode(geometry: primGeos[i])
                child.name = "d3prim:\(i)"
                child.categoryBitMask = node.categoryBitMask
                node.addChildNode(child)
                var list = geometryConsumers[primGeoKeys[i]] ?? []
                if !list.contains(where: { $0 === child }) {
                    list.append(child)
                    geometryConsumers[primGeoKeys[i]] = list
                }
                if let morph = morphTargets[primGeoKeys[i]] {
                    attachMorph(child, morph)
                }
            }
            // A replaced geometry goes to the graveyard — the in-flight
            // pass's frozen storage can still reference it.
            if let old = node.geometry, old !== geo { host.retire(old) }
            node.geometry = geo
            // A collider decoded a nil shape while this geometry was
            // payload-deferred, so the body attached shapeless. Refit
            // the recorded derivation now that the geometry exists.
            if let t = host.pendingColliderShapes.removeValue(forKey: key) {
                if let body = node.physicsBody, body.physicsShape == nil {
                    body.physicsShape = derivedShape(node, t, "deferred")
                }
            }
            // W11: the geometry may carry morph targets; the node may
            // carry a `skin` member. Attach what's resolvable; anything
            // short registers in `pendingSkinNodes`. Morphs ride the
            // first primitive's streams (upstream's morphing contract).
            if let g0 = primGeoKeys.first,
               let morph = morphTargets[g0] {
                attachMorph(node, morph)
            } else if let old = node.morpher {
                host.retire(old)
                node.morpher = nil
            }
            attachSkin(key, node)
        }

        func decodeCamera(_ node: SCNNode, _ p: [String: Any]) {
            let cam = SCNCamera()
            if let fov = d3Double(p["fovRadiansY"]) {
                cam.fieldOfView = CGFloat(fov * 180.0 / .pi)
                // The wire field is vertical (Filament's Fov.VERTICAL
                // on Android); SCNCamera defaults to horizontal.
                cam.projectionDirection = .vertical
            }
            if let n = d3Double(p["near"]) { cam.zNear = n }
            if let f = d3Double(p["far"]) { cam.zFar = f }
            if (p["projection"] as? [String: Any])?["s"] as? String == "orthographic" {
                cam.usesOrthographicProjection = true
                if let s = d3Double(p["orthoScale"] ?? p["orthographicScale"]) {
                    cam.orthographicScale = CGFloat(s)
                }
            }
            node.camera = cam
            if firstCameraNode == nil { firstCameraNode = node }
        }

        func decodeLight(_ node: SCNNode, _ p: [String: Any],
                         _ type: SCNLight.LightType) {
            let light = SCNLight()
            light.type = type
            if let c = d3Color(p["color"]) { light.color = c }
            if let i = d3Double(p["intensity"]) { light.intensity = CGFloat(i) }
            if let range = d3Double(p["range"]) {
                light.attenuationStartDistance = 0
                light.attenuationEndDistance = CGFloat(range)
            }
            if let inner = d3Double(p["innerConeAngle"]),
               type == .spot {
                light.spotInnerAngle = CGFloat(inner * 180.0 / .pi)
            }
            if let outer = d3Double(p["outerConeAngle"]),
               type == .spot {
                light.spotOuterAngle = CGFloat(outer * 180.0 / .pi)
            }
            if type == .area {
                // rectAreaLight (W12): the emitter's rectangle — the
                // width/height pair SceneKit's area light needs before
                // it illuminates; drawsArea renders the source itself.
                light.areaType = .rectangle
                light.areaExtents = simd_float3(
                    Float(d3Double(p["width"]) ?? 1),
                    Float(d3Double(p["height"]) ?? 1), 0)
                light.drawsArea = true
            }
            if d3Bool(p["castsShadow"]) == true {
                // The 'low' view tier suppresses shadow casting;
                // 'high' doubles the map. `shadowAuthored` remembers
                // the flag so a tier change restores the light.
                host.shadowAuthored.insert(ObjectIdentifier(light))
                light.castsShadow = host.viewQuality != "low"
                if host.viewQuality == "high" {
                    light.shadowMapSize = CGSize(width: 2048,
                                                 height: 2048)
                }
                if let v = d3Double(p["shadowRadius"]) {
                    light.shadowRadius = CGFloat(v)
                }
                if let v = d3Double(p["shadowDepthBias"]) {
                    light.shadowBias = CGFloat(v)
                }
            }
            node.light = light
        }

        // MARK: Skins / morphs / animations (W11)

        /// Node lookup that also consults the live registry when this
        /// context is surgical — manifest decode leaves
        /// `resolvesLiveNodes` false so a fresh scene never sees the
        /// OLD scene's nodes, while the op contexts (seeded from the
        /// live registries) need the fallthrough for skin joint refs
        /// that point at pre-existing nodes.
        func resolveNode(_ key: UInt64) -> SCNNode? {
            nodes[key] ?? (resolvesLiveNodes ? host.nodesById[key] : nil)
        }

        /// `skins` block decode. Each entry keeps its raw def in
        /// `skinDefs` so `upsertSkin`/`upsertPayload` re-decodes the
        /// single skin; consumers re-attach via `attachSkin` after the
        /// decode updates `skins`.
        func decodeSkins(_ map: [String: Any]) {
            for (id, any) in map {
                guard let key = D3Wire.localIdKey(id),
                      let def = any as? [String: Any] else { continue }
                skinDefs[key] = def
                decodeSkin(key, def)
            }
        }

        /// One `skins` entry: joint node refs in authored order, the
        /// `inverseBindMatrices` payload (16 f32 per joint, z-mirrored
        /// through `D3Wire.matrix`; absent or in-flight → identity, and
        /// `awaitingIBM` keeps the consumers pending so the payload's
        /// arrival re-binds), and the optional `skeleton` root.
        func decodeSkin(_ key: UInt64, _ def: [String: Any]) {
            let jointKeys = (def["joints"] as? [Any] ?? [])
                .compactMap {
                    ($0 as? String).flatMap(D3Wire.localIdKey)
                }
            let skeletonKey = (def["skeleton"] as? String)
                .flatMap(D3Wire.localIdKey)
            var ibms = [SCNMatrix4](repeating: SCNMatrix4Identity,
                                    count: jointKeys.count)
            var awaiting = false
            if let token = def["inverseBindMatrices"] as? String,
               let pid = D3Wire.localIdKey(token) {
                skinPayloadKeys[key] = pid
                if let data = host.payloadStore[pid] {
                    let floats = f32List(data)
                    let need = jointKeys.count * 16
                    if floats.count < need {
                        d3Log("skin \(key): inverseBindMatrices has "
                            + "\(floats.count) floats; expected \(need)")
                    }
                    for j in 0..<jointKeys.count {
                        let b = j * 16
                        guard b + 16 <= floats.count else { break }
                        ibms[j] = D3Wire.matrix(
                            (0..<16).map { Double(floats[b + $0]) })
                    }
                } else {
                    awaiting = true
                }
            } else {
                skinPayloadKeys.removeValue(forKey: key)
            }
            skins[key] = DecodedSkin(jointKeys: jointKeys, ibms: ibms,
                                     skeletonKey: skeletonKey,
                                     awaitingIBM: awaiting)
        }

        /// `animations` block decode — raw defs kept in `animDefs` for
        /// `upsertAnimation`/`upsertPayload` re-decodes.
        func decodeAnimations(_ map: [String: Any]) {
            for (id, any) in map {
                guard let key = D3Wire.localIdKey(id),
                      let def = any as? [String: Any] else { continue }
                animDefs[key] = def
                decodeAnimation(key, def)
            }
        }

        /// One `animations` entry. Each channel's timeline (f32 seconds)
        /// and keyframes are payload refs — recorded as claims first so
        /// an `upsertPayload` chunk re-decodes the animation it
        /// unblocks; a channel whose payloads haven't landed is skipped
        /// this pass. Values convert to SceneKit space here:
        /// translation negates z, rotation takes the (−x,−y,z,w)
        /// pseudovector map, scale and weights pass through. `weights`
        /// channels carry flattened per-key values — `targetCount` is
        /// `values.count / times.count`, trailing floats that don't
        /// complete a keyframe are dropped (upstream's rule).
        func decodeAnimation(_ key: UInt64, _ def: [String: Any]) {
            let name = def["name"] as? String ?? ""
            var channels: [DecodedChannel] = []
            var endTime = 0.0
            var claims = animPayloadKeys[key] ?? []
            for any in def["channels"] as? [Any] ?? [] {
                guard let c = any as? [String: Any],
                      let targetTok = c["target"] as? String,
                      let target = D3Wire.localIdKey(targetTok)
                else { continue }
                var ch = DecodedChannel(
                    target: target,
                    targetName: c["targetName"] as? String,
                    kind: .translation)
                switch c["property"] as? String {
                case "rotation": ch.kind = .rotation
                case "scale":    ch.kind = .scale
                case "weights":  ch.kind = .weights
                default:         ch.kind = .translation
                }
                guard let tTok = c["timeline"] as? String,
                      let kTok = c["keyframes"] as? String,
                      let tPid = D3Wire.localIdKey(tTok),
                      let kPid = D3Wire.localIdKey(kTok) else {
                    d3Log("animation \(key): channel missing "
                        + "timeline/keyframes")
                    continue
                }
                claims.insert(tPid)
                claims.insert(kPid)
                guard let tData = host.payloadStore[tPid],
                      let kData = host.payloadStore[kPid] else {
                    host.logOnce("anim.\(key).awaiting",
                        "animation \(key): awaiting channel payloads")
                    continue
                }
                let times = f32List(tData).map(Double.init)
                let vals = f32List(kData)
                switch ch.kind {
                case .translation:
                    ch.vec3 = (0..<min(times.count, vals.count / 3))
                        .map {
                            let b = $0 * 3
                            return simd_float3(vals[b], vals[b + 1],
                                               -vals[b + 2])
                        }
                case .scale:
                    ch.vec3 = (0..<min(times.count, vals.count / 3))
                        .map {
                            let b = $0 * 3
                            return simd_float3(vals[b], vals[b + 1],
                                               vals[b + 2])
                        }
                case .rotation:
                    ch.quat = (0..<min(times.count, vals.count / 4))
                        .map {
                            let b = $0 * 4
                            return simd_quatf(
                                real: vals[b + 3],
                                imag: simd_float3(
                                    -vals[b], -vals[b + 1],
                                    vals[b + 2]))
                        }
                case .weights:
                    let keyCount = times.count
                    let tc = keyCount > 0 ? vals.count / keyCount : 0
                    ch.targetCount = tc
                    ch.weights = Array(vals.prefix(tc * keyCount))
                }
                ch.times = times
                if let last = times.last {
                    endTime = max(endTime, last)
                }
                channels.append(ch)
            }
            animPayloadKeys[key] = claims
            animations[key] = DecodedAnimation(
                name: name, channels: channels, endTime: endTime)
        }

        /// Attaches the geometry's morph targets as a `SCNMorpher` —
        /// `.normalized` mode (upstream `MorphTargetData` normalizes)
        /// with the mesh's `defaultWeights` applied up front.
        func attachMorph(_ node: SCNNode, _ morph: DecodedMorph) {
            let morpher = SCNMorpher()
            morpher.targets = morph.targets
            morpher.calculationMode = .normalized
            for i in 0..<morph.targetCount {
                let w = i < morph.defaultWeights.count
                    ? morph.defaultWeights[i] : 0
                morpher.setWeight(CGFloat(w), forTargetAt: i)
            }
            // A replaced morpher goes to the graveyard — the in-flight
            // pass's frozen storage can still reference it.
            if let old = node.morpher { host.retire(old) }
            node.morpher = morpher
        }

        /// Attaches a `SCNSkinner` for the node's declared `skin`.
        /// Bone slots follow the authored joint order; a joint that
        /// hasn't landed (or was destroyed) substitutes a detached
        /// node — upstream renders a missing joint as identity, and
        /// keeping the slot preserves IBM/bone-index alignment — and
        /// the node stays in `pendingSkinNodes` so the joint's
        /// `addNode` arrival re-binds. `bones`, the IBMs, and the two
        /// bone geometry sources are retained by the skinner; the
        /// `skeleton` property is weak, so the skeleton's registry
        /// entry (`nodesById` / `nodes`) is what keeps it alive.
        func attachSkin(_ nodeKey: UInt64, _ node: SCNNode) {
            func dropSkinner() {
                if let old = node.skinner { host.retire(old) }
                node.skinner = nil
            }
            guard let skinKey = nodeSkinKeys[nodeKey] else {
                dropSkinner()
                pendingSkinNodes.remove(nodeKey)
                return
            }
            guard let skin = skins[skinKey],
                  let geo = node.geometry else {
                dropSkinner()
                pendingSkinNodes.insert(nodeKey)
                return
            }
            guard let weightSource = geo.sources.first(where: {
                      $0.semantic == .boneWeights }),
                  let indexSource = geo.sources.first(where: {
                      $0.semantic == .boneIndices }) else {
                host.logOnce("skin.\(nodeKey).unskinned",
                    "node \(nodeKey): has skin \(skinKey) but its "
                    + "geometry carries no bone sources")
                dropSkinner()
                pendingSkinNodes.insert(nodeKey)
                return
            }
            var complete = !skin.awaitingIBM
            var bones: [SCNNode] = []
            bones.reserveCapacity(skin.jointKeys.count)
            for jk in skin.jointKeys {
                if let joint = resolveNode(jk) {
                    bones.append(joint)
                } else {
                    bones.append(SCNNode())
                    complete = false
                }
            }
            var skeleton: SCNNode? = nil
            if let sk = skin.skeletonKey {
                if let s = resolveNode(sk) {
                    skeleton = s
                } else {
                    complete = false
                }
            }
            let skinner = SCNSkinner(
                baseGeometry: geo,
                bones: bones,
                boneInverseBindTransforms: skin.ibms.map {
                    NSValue(scnMatrix4: $0)
                },
                boneWeights: weightSource,
                boneIndices: indexSource)
            skinner.skeleton = skeleton
            // A replaced skinner goes to the graveyard — the in-flight
            // pass's frozen storage can still reference it.
            if let old = node.skinner { host.retire(old) }
            node.skinner = skinner
            if complete {
                pendingSkinNodes.remove(nodeKey)
            } else {
                pendingSkinNodes.insert(nodeKey)
            }
        }

        /// Manifest-path post-pass — runs after `attachRoots` so every
        /// joint named by a skin has had its node built. Anything still
        /// unresolved lands in `pendingSkinNodes` for the op paths to
        /// retry (`addNode` landings, `upsertSkin`, payload arrival,
        /// `upsertGeometry` re-attach).
        func resolveSkinAttachments() {
            for (nodeKey, _) in nodeSkinKeys {
                if let node = nodes[nodeKey] {
                    attachSkin(nodeKey, node)
                }
            }
        }

        /// Re-attaches every node bound to `skinKey` — the
        /// `upsertSkin`/`removeSkin`-adjacent refresh after `decodeSkin`
        /// rewrites (or removes) the skin record.
        func refreshSkinConsumers(_ skinKey: UInt64) {
            for (nodeKey, key) in nodeSkinKeys where key == skinKey {
                if let node = resolveNode(nodeKey) {
                    attachSkin(nodeKey, node)
                } else {
                    pendingSkinNodes.remove(nodeKey)
                }
            }
        }

        // MARK: Stage / environment (W7)

        /// Applies the manifest `stage` block: the `environmentRef` →
        /// `kind:'environment'` resource drives the lighting env
        /// (`scene.lightingEnvironment`), the skybox background, and
        /// the camera exposure. An absent or unresolvable ref defaults
        /// to the built-in **studio** env — upstream behavior. Every
        /// env field is re-assigned (or cleared) each run so a re-decode
        /// — `updateStage`, env `upsertResource`, payload arrival —
        /// replaces the previous look without accumulation.
        func decodeStage(_ stage: [String: Any]?) {
            // A ref swap retires the previous env's deferral/claim —
            // otherwise the old key sits in `deferredResourceIds` and
            // every later payload chunk triggers a full re-realize.
            if let oldToken = stageJSON?["environmentRef"] as? String,
               let oldKey = D3Wire.localIdKey(oldToken),
               (stage?["environmentRef"] as? String) != oldToken {
                deferredResourceIds.remove(oldKey)
                environmentPayloadKeys.removeValue(forKey: oldKey)
            }
            stageJSON = stage
            stageEnvDeferred = false

            // W14 stage quality — these live on `stage` itself, not
            // on the env resource's "look" fields. Absent → the wire
            // defaults; the host's `applyStageQuality` consumes them.
            stageAntiAliasing = (stage?["antiAliasing"] as? String)
                ?? d3String(stage?["antiAliasing"]) ?? "auto"
            stageRenderScale =
                (stage?["renderScale"] as? NSNumber)?.doubleValue
                ?? d3Double(stage?["renderScale"]) ?? 1.0
            stageFilterQuality = (stage?["filterQuality"] as? String)
                ?? d3String(stage?["filterQuality"]) ?? "medium"

            var envKey: UInt64?
            var env: [String: Any]?
            if let token = stage?["environmentRef"] as? String {
                if let ref = D3Wire.localIdKey(token) {
                    envKey = ref
                    env = environments[ref]
                    if env == nil {
                        host.logOnce("stage.envRef.\(ref)",
                            "stage environmentRef '\(token)' unresolved; "
                            + "using the studio default")
                    }
                } else {
                    host.logOnce("stage.envRef.token",
                        "stage environmentRef '\(token)' is malformed; "
                        + "using the studio default")
                }
            }
            // Upstream's zero-config default: a document with no
            // environment still gets the procedural studio IBL.
            let envRes = env ?? ["environment": ["type": "studio"]]

            // The "look" fields serialize as plain JSON values (the
            // tagged `{'d': …}` form is only for node/material
            // properties).
            stageExposure = plainDouble(envRes["exposure"]) ?? 1.0
            if let toneMapping = envRes["toneMapping"] as? String {
                host.logOnce("stage.toneMapping.\(toneMapping)",
                    "toneMapping '\(toneMapping)': iOS keeps SceneKit's "
                    + "filmic operator — approximation")
            }
            if envRes["skyEnvironment"] != nil {
                host.logOnce("stage.skyEnvironment",
                    "skyEnvironment (procedural sky re-lighting) is "
                    + "deferred")
            }
            // W13: absent key → nil ("don't touch"); present (even
            // `{}`) → a wholesale decode the host applies absolutely.
            stageEffects =
                StageEffects.decode(envRes["effects"] as? [String: Any])

            let intensity = plainDouble(envRes["environmentIntensity"])
                ?? 1.0
            let rotationY = plainDouble(envRes["environmentRotationY"])
                ?? 0.0

            let envPixels = realizeEnvironmentSource(envRes,
                                                     envKey: envKey)
            // Baked transforms: z-mirror + rotationY are column ops;
            // intensity is a per-pixel scale. SceneKit has no native
            // knobs for either, so they live in the pixels.
            let lighting = envPixels.map {
                scaledPixels(mirroredRotated($0, rotationY), intensity)
            }
            if !stageEnvDeferred {
                scene.lightingEnvironment.contents =
                    lighting.flatMap(envContents)
                if let envKey { deferredResourceIds.remove(envKey) }
            }

            // The skybox is a separate draw of (usually) the same env —
            // `skybox.intensity` stacks on top of environmentIntensity.
            let sky = envRes["skybox"] as? [String: Any]
            let source = sky?["source"] as? [String: Any]
            let skyIntensity = plainDouble(sky?["intensity"]) ?? 1.0
            switch source?["type"] as? String {
            case "environment":
                guard !stageEnvDeferred else { break }
                var background = lighting.map {
                    scaledPixels($0, skyIntensity)
                }
                let blurriness =
                    plainDouble(source?["blurriness"]) ?? 0.0
                if blurriness > 0, let p = background {
                    background = boxBlurredPixels(p,
                        radius: max(1, Int((blurriness
                            * Double(p.width) / 32).rounded())))
                    host.logOnce("skybox.blurriness",
                        "skybox blurriness \(blurriness): approximated "
                        + "with a CPU box blur on the equirect")
                }
                scene.background.contents =
                    background.flatMap(envContents)
            case "gradient":
                // The sky is its own source — env intensity/rotation
                // don't reach it, but the z-mirror does (world space).
                let background = scaledPixels(
                    mirroredRotated(gradientEquirectPixels(source ?? [:]),
                                    0), skyIntensity)
                scene.background.contents = envContents(background)
            case "fmat", "physical":
                host.logOnce("skybox.\(source?["type"] ?? "")",
                    "skybox source '\(source?["type"] ?? "")' is "
                    + "deferred; background cleared")
                scene.background.contents = nil
            default:
                if source != nil {
                    host.logOnce("skybox.\(source?["type"] ?? "?")",
                        "skybox source '\(source?["type"] ?? "?")' "
                        + "unknown; background cleared")
                }
                scene.background.contents = nil
            }
        }

        /// Realizes the env resource's `environment` member into
        /// equirect pixels. Returns nil for `empty` and for sources
        /// that fail to decode; a `payload` whose bytes haven't landed
        /// sets `stageEnvDeferred` and records the payload claim.
        func realizeEnvironmentSource(_ env: [String: Any],
                                      envKey: UInt64?) -> EnvPixels? {
            let spec = env["environment"] as? [String: Any]
                ?? ["type": "studio"]
            let tag = envKey.map { "environment \($0)" } ?? "environment"
            switch spec["type"] as? String ?? "studio" {
            case "studio":
                return EnvPixels(width: 256, height: 128, isFloat: false,
                                 data: studioEquirectPixels(256, 128))
            case "constant":
                // The wire color is linear radiance; the equirect
                // stores sRGB like every LDR source here.
                let c = rawVec3(spec["color"]) ?? [0, 0, 0]
                return EnvPixels(width: 16, height: 8, isFloat: false,
                                 data: solidEquirectPixels(c,
                                                           width: 16,
                                                           height: 8))
            case "empty":
                return nil
            case "asset":
                guard let ref = spec["ref"] as? String else {
                    host.logOnce("env.\(envKey ?? 0).asset",
                        "\(tag): asset environment lacks 'ref'")
                    return nil
                }
                return envPixels(fromAsset: ref, tag: tag)
            case "payload":
                guard let token = spec["payload"] as? String,
                      let pid = D3Wire.localIdKey(token) else {
                    host.logOnce("env.\(envKey ?? 0).payloadToken",
                        "\(tag): invalid payload token")
                    return nil
                }
                if let envKey { environmentPayloadKeys[envKey] = pid }
                guard let data = host.payloadStore[pid] else {
                    stageEnvDeferred = true
                    if let envKey { deferredResourceIds.insert(envKey) }
                    host.logOnce("env.\(envKey ?? 0).awaiting",
                        "\(tag): awaiting payload")
                    return nil
                }
                return envPixels(fromBytes: data, tag: tag)
            default:
                host.logOnce("env.\(envKey ?? 0).type",
                    "\(tag): unknown environment type "
                    + "'\(spec["type"] ?? "?")'; using studio")
                return EnvPixels(width: 256, height: 128, isFloat: false,
                                 data: studioEquirectPixels(256, 128))
            }
        }

        /// Verbatim port of flutter_scene's
        /// `_generateStudioEquirectPixels`
        /// (lib/src/material/environment.dart): a cool-neutral ceiling
        /// gradient over a warm-dim floor, a broad dirY² top fill, a
        /// warm pow²⁶ key lobe at normalize(0.45, 0.55, 0.70), and a
        /// cool pow¹⁶ fill at normalize(−0.70, 0.22, −0.35). Row 0 is
        /// the up pole; pixels are sRGB-encoded RGBA8.
        func studioEquirectPixels(_ width: Int, _ height: Int) -> Data {
            var pixels = Data(count: width * height * 4)
            let keyLen = (0.45 * 0.45 + 0.55 * 0.55 + 0.70 * 0.70)
                .squareRoot()
            let keyX = 0.45 / keyLen, keyY = 0.55 / keyLen
            let keyZ = 0.70 / keyLen
            let fillLen = (0.70 * 0.70 + 0.22 * 0.22 + 0.35 * 0.35)
                .squareRoot()
            let fillX = -0.70 / fillLen, fillY = 0.22 / fillLen
            let fillZ = -0.35 / fillLen
            let twoPi = 2.0 * Double.pi
            pixels.withUnsafeMutableBytes { buf in
                guard let p = buf.baseAddress?
                    .assumingMemoryBound(to: UInt8.self) else { return }
                for py in 0..<height {
                    let v = (Double(py) + 0.5) / Double(height)
                    // Row 0 (top of the image) is the up hemisphere.
                    let latitude = (0.5 - v) * Double.pi
                    let cosLat = cos(latitude)
                    let dirY = sin(latitude)
                    for px in 0..<width {
                        let u = (Double(px) + 0.5) / Double(width)
                        let longitude = (u - 0.5) * twoPi
                        let dirX = cosLat * cos(longitude)
                        let dirZ = cosLat * sin(longitude)
                        var r: Double, g: Double, b: Double
                        if dirY >= 0 {
                            let t = smoothstep01(dirY)
                            r = lerp(0.50, 0.76, t)
                            g = lerp(0.51, 0.78, t)
                            b = lerp(0.52, 0.82, t)
                        } else {
                            let t = smoothstep01(-dirY)
                            r = lerp(0.50, 0.20, t)
                            g = lerp(0.51, 0.19, t)
                            b = lerp(0.52, 0.17, t)
                        }
                        let top = max(dirY, 0.0)
                        let topL = top * top
                        r += 0.85 * topL
                        g += 0.86 * topL
                        b += 0.88 * topL
                        let keyC = max(
                            dirX * keyX + dirY * keyY + dirZ * keyZ, 0.0)
                        let keyL = pow(keyC, 26.0)
                        r += 1.10 * keyL
                        g += 1.06 * keyL
                        b += 1.00 * keyL
                        let fillC = max(
                            dirX * fillX + dirY * fillY + dirZ * fillZ,
                            0.0)
                        let fillL = pow(fillC, 16.0)
                        r += 0.46 * fillL
                        g += 0.50 * fillL
                        b += 0.56 * fillL
                        let o = (py * width + px) * 4
                        p[o] = encodeSrgb(r)
                        p[o + 1] = encodeSrgb(g)
                        p[o + 2] = encodeSrgb(b)
                        p[o + 3] = 255
                    }
                }
            }
            return pixels
        }

        /// `constant` env — a tiny solid equirect of the linear color.
        /// Uniform diffuse ambient; the flat "reflections" are the
        /// cheapest SceneKit gets to upstream's black-spec +
        /// SH-diffuse form.
        func solidEquirectPixels(_ c: [Float], width: Int,
                                 height: Int) -> Data {
            let r = encodeSrgb(Double(c[0]))
            let g = encodeSrgb(Double(c[1]))
            let b = encodeSrgb(Double(c[2]))
            var data = Data(count: width * height * 4)
            data.withUnsafeMutableBytes { buf in
                guard let p = buf.baseAddress?
                    .assumingMemoryBound(to: UInt8.self) else { return }
                for i in stride(from: 0, to: width * height * 4, by: 4) {
                    p[i] = r; p[i + 1] = g; p[i + 2] = b; p[i + 3] = 255
                }
            }
            return data
        }

        /// `gradient` sky — mirrors upstream's SkyGradientFragment:
        /// horizon→zenith / horizon→ground blends on sqrt(|dirY|), the
        /// pow(dot(sun), sharpness) HDR sun disk, and its 0.15·s⁸ halo.
        /// Output clips to LDR sRGB — the sun disk saturates white
        /// instead of staying HDR (approximation; backgrounds only).
        func gradientEquirectPixels(_ source: [String: Any],
                                    width: Int = 128,
                                    height: Int = 64) -> EnvPixels {
            let zenith = rawVec3(source["zenithColor"])
                ?? [0.05, 0.18, 0.55]
            let horizon = rawVec3(source["horizonColor"])
                ?? [0.45, 0.62, 0.90]
            let ground = rawVec3(source["groundColor"])
                ?? [0.16, 0.14, 0.12]
            let sun = rawVec3(source["sunDirection"]) ?? [0.4, 0.5, 0.6]
            let sunColor = rawVec3(source["sunColor"]) ?? [3.0, 2.7, 2.2]
            let sharpness = plainDouble(source["sunSharpness"]) ?? 400.0
            let sunLen = sqrt(Double(sun[0] * sun[0] + sun[1] * sun[1]
                                     + sun[2] * sun[2]))
            let sunX = sunLen > 0 ? Double(sun[0]) / sunLen : 0.0
            let sunY = sunLen > 0 ? Double(sun[1]) / sunLen : 0.0
            let sunZ = sunLen > 0 ? Double(sun[2]) / sunLen : 0.0
            var pixels = Data(count: width * height * 4)
            let twoPi = 2.0 * Double.pi
            pixels.withUnsafeMutableBytes { buf in
                guard let p = buf.baseAddress?
                    .assumingMemoryBound(to: UInt8.self) else { return }
                for py in 0..<height {
                    let v = (Double(py) + 0.5) / Double(height)
                    let latitude = (0.5 - v) * Double.pi
                    let cosLat = cos(latitude)
                    let dirY = sin(latitude)
                    for px in 0..<width {
                        let u = (Double(px) + 0.5) / Double(width)
                        let longitude = (u - 0.5) * twoPi
                        let dirX = cosLat * cos(longitude)
                        let dirZ = cosLat * sin(longitude)
                        var r: Double, g: Double, b: Double
                        let t = sqrt(abs(dirY))
                        if dirY >= 0 {
                            r = lerp(Double(horizon[0]),
                                     Double(zenith[0]), t)
                            g = lerp(Double(horizon[1]),
                                     Double(zenith[1]), t)
                            b = lerp(Double(horizon[2]),
                                     Double(zenith[2]), t)
                        } else {
                            r = lerp(Double(horizon[0]),
                                     Double(ground[0]), t)
                            g = lerp(Double(horizon[1]),
                                     Double(ground[1]), t)
                            b = lerp(Double(horizon[2]),
                                     Double(ground[2]), t)
                        }
                        let s = max(
                            dirX * sunX + dirY * sunY + dirZ * sunZ, 0.0)
                        let disk = pow(s, sharpness)
                            + 0.15 * pow(s, 8.0)
                        r += Double(sunColor[0]) * disk
                        g += Double(sunColor[1]) * disk
                        b += Double(sunColor[2]) * disk
                        let o = (py * width + px) * 4
                        p[o] = encodeSrgb(r)
                        p[o + 1] = encodeSrgb(g)
                        p[o + 2] = encodeSrgb(b)
                        p[o + 3] = 255
                    }
                }
            }
            return EnvPixels(width: width, height: height,
                             isFloat: false, data: pixels)
        }

        /// `asset` env — bundle bytes sniffed by magic (an asset
        /// catalog image has no file, so `UIImage(named:)` is the
        /// fallback for those).
        func envPixels(fromAsset ref: String, tag: String)
            -> EnvPixels?
        {
            if let url = Bundle.main.url(forResource: ref,
                                         withExtension: nil),
               let data = try? Data(contentsOf: url) {
                return envPixels(fromBytes: data, tag: tag)
            }
            if let image = UIImage(named: ref),
               let pixels = envPixels(from: image) {
                return pixels
            }
            host.logOnce("env.asset.\(ref)",
                "\(tag): asset '\(ref)' not found")
            return nil
        }

        /// Equirect bytes — decoder picked by magic: Radiance HDR
        /// (`#?RADIANCE`/`#?RGBE`) decodes to float32, OpenEXR goes
        /// through the platform HDR loaders (`decodeEXR`), everything
        /// else goes through `UIImage`'s container sniffing (png/jpg/…;
        /// the spec `format` tag is informational).
        func envPixels(fromBytes data: Data, tag: String) -> EnvPixels? {
            if isRadianceHDR(data) {
                return decodeRadianceHDR(data, tag: tag)
            }
            if isOpenEXR(data) {
                return decodeEXR(data, tag: tag)
            }
            guard let image = UIImage(data: data),
                  let pixels = envPixels(from: image) else {
                host.logOnce("env.bytes.\(tag)",
                    "\(tag): undecodable environment image")
                return nil
            }
            return pixels
        }

        /// A `UIImage` → sRGB8 equirect (the `rgbaPixels` re-decode).
        func envPixels(from image: UIImage) -> EnvPixels? {
            guard let (data, w, h) = rgbaPixels(image, alpha: false)
            else { return nil }
            return EnvPixels(width: w, height: h, isFloat: false,
                             data: data)
        }

        func isRadianceHDR(_ data: Data) -> Bool {
            guard data.count > 10,
                  data[data.startIndex] == 0x23,      // '#'
                  data[data.startIndex + 1] == 0x3F   // '?'
            else { return false }
            let head = data.prefix(10)
            return head.starts(with: Data("#?RADIANCE".utf8))
                || head.starts(with: Data("#?RGBE".utf8))
        }

        /// OpenEXR magic 0x01312F76, little-endian on the wire.
        func isOpenEXR(_ data: Data) -> Bool {
            guard data.count > 4 else { return false }
            let i = data.startIndex
            return data[i] == 0x76 && data[i + 1] == 0x2F
                && data[i + 2] == 0x31 && data[i + 3] == 0x01
        }

        /// Minimal Radiance .hdr (RGBE) decoder: header lines up to a
        /// blank line, a `-Y h +X w` resolution row, then per-scanline
        /// new-style RLE or flat RGBE data. Output is linear RGBA
        /// float32, row 0 = top of the image.
        func decodeRadianceHDR(_ data: Data, tag: String) -> EnvPixels? {
            func fail(_ why: String) -> EnvPixels? {
                host.logOnce("env.hdr.\(tag).\(why)",
                    "\(tag): malformed .hdr equirect (\(why))")
                return nil
            }
            var i = data.startIndex
            // Header: text lines through the first empty one.
            var sawHeaderEnd = false
            while i < data.endIndex {
                guard let nl = data[i...].firstIndex(of: 0x0A)
                else { return fail("unterminated header") }
                let line = data[i..<nl]
                    .filter { $0 != 0x0D }      // tolerate \r\n
                i = nl + 1
                if line.isEmpty { sawHeaderEnd = true; break }
            }
            guard sawHeaderEnd else { return fail("unterminated header") }
            // Resolution row: "±Y h ±X w" (Y-major only).
            guard let nl = data[i...].firstIndex(of: 0x0A)
            else { return fail("missing resolution line") }
            let tokens = String(decoding: data[i..<nl]
                                    .filter { $0 != 0x0D },
                                as: UTF8.self)
                .split(separator: " ").map(String.init)
            i = nl + 1
            guard tokens.count == 4,
                  let n1 = Int(tokens[1]), let n2 = Int(tokens[3]),
                  n1 > 0, n2 > 0
            else { return fail("bad resolution line") }
            let yMajor = tokens[0].hasSuffix("Y")
            guard yMajor else {
                return fail("X-major scanlines unsupported")
            }
            let height = n1, width = n2
            // "-Y": first scanline is the image top (the standard);
            // "+Y" starts at the bottom. "+X": left-to-right pixels.
            let bottomUp = tokens[0].hasPrefix("+")
            let rightToLeft = tokens[2].hasPrefix("-")
            var floats = [Float](repeating: 0, count: width * height * 4)
            let rle = width >= 8 && width < 32768
            for y in 0..<height {
                let row = bottomUp ? height - 1 - y : y
                var rgb = [UInt8](repeating: 0, count: width * 4)
                if rle {
                    guard i + 4 <= data.endIndex,
                          data[i] == 2, data[i + 1] == 2,
                          (data[i + 2] & 0x80) == 0,
                          (Int(data[i + 2]) << 8 | Int(data[i + 3]))
                            == width
                    else { return fail("bad RLE scanline \(y)") }
                    i += 4
                    for c in 0..<4 {
                        var x = 0
                        while x < width {
                            guard i < data.endIndex
                            else { return fail("truncated RLE") }
                            let count = Int(data[i]); i += 1
                            if count > 128 {
                                let run = count - 128
                                guard i < data.endIndex, x + run <= width
                                else { return fail("bad RLE run") }
                                let v = data[i]; i += 1
                                for k in 0..<run {
                                    rgb[(x + k) * 4 + c] = v
                                }
                                x += run
                            } else {
                                guard i + count <= data.endIndex,
                                      x + count <= width
                                else { return fail("bad RLE literal") }
                                for k in 0..<count {
                                    rgb[(x + k) * 4 + c] = data[i + k]
                                }
                                i += count
                                x += count
                            }
                        }
                    }
                } else {
                    guard i + width * 4 <= data.endIndex
                    else { return fail("truncated flat data") }
                    for k in 0..<width * 4 {
                        rgb[k] = data[i + k]
                    }
                    i += width * 4
                }
                for x in 0..<width {
                    let sx = rightToLeft ? width - 1 - x : x
                    let o = (row * width + x) * 4
                    let e = Int(rgb[sx * 4 + 3])
                    if e != 0 {
                        let f = Float(pow(2.0, Double(e) - 136.0))
                        floats[o] = Float(rgb[sx * 4]) * f
                        floats[o + 1] = Float(rgb[sx * 4 + 1]) * f
                        floats[o + 2] = Float(rgb[sx * 4 + 2]) * f
                    }
                    floats[o + 3] = 1.0
                }
            }
            return EnvPixels(width: width, height: height,
                             isFloat: true,
                             data: floats.withUnsafeBufferPointer {
                                 Data(bytes: $0.baseAddress!,
                                      count: $0.count
                                        * MemoryLayout<Float>.size)
                             })
        }

        /// OpenEXR equirect → linear float32 RGBA `EnvPixels` (W21) —
        /// the same float storage the .hdr decoder produces, so the
        /// mirror/rotate/intensity bakes and `envContents`' MDLTexture
        /// binding apply unchanged. Primary path is
        /// `MTKTextureLoader` (ImageIO's EXR codec under Metal,
        /// `.SRGB: false` keeps the linear values); when it can't
        /// produce a readable texture, `CIImage` → `CIContext` RGBAf
        /// in extended-linear-sRGB is the fallback. Both verified to
        /// preserve >1.0 texels. No decoder on the OS → warn-once +
        /// nil (the env keeps whatever the stage defaults to — the
        /// pre-W21 behavior, now logged from the loader failures).
        func decodeEXR(_ data: Data, tag: String) -> EnvPixels? {
            if let device = host.renderDevice(),
               let env = exrMetalPixels(data, device: device, tag: tag) {
                return env
            }
            if let env = exrCoreImagePixels(data) {
                return env
            }
            host.logOnce("env.exr.\(tag).unsupported",
                "\(tag): EXR equirect undecodable on this OS — "
                + "MTKTextureLoader and CIImage both failed")
            return nil
        }

        /// EXR via `MTKTextureLoader` → `getBytes` readback. Handles
        /// the float formats ImageIO's codec emits (rgba16Float,
        /// rgba32Float); an 8-bit delivery means the loader clamped
        /// HDR — converted anyway and warn-onced rather than silently
        /// flattened. `.topLeft` origin keeps row 0 = image top (the
        /// `EnvPixels` convention). Row pitch is w·component-count·
        /// component-size — Metal rows are tightly packed here.
        func exrMetalPixels(_ data: Data, device: MTLDevice, tag: String)
            -> EnvPixels?
        {
            guard let tex = try? MTKTextureLoader(device: device)
                .newTexture(data: data, options: [
                    .SRGB: NSNumber(value: false),
                    .generateMipmaps: NSNumber(value: false),
                    .origin: MTKTextureLoader.Origin.topLeft as NSString,
                ]),
                tex.textureType == .type2D,
                tex.storageMode != .private   // getBytes needs CPU access
            else { return nil }
            let w = tex.width, h = tex.height
            var floats = [Float](repeating: 0, count: w * h * 4)
            switch tex.pixelFormat {
            case .rgba16Float:
                // `Float16` is iOS 14+ and the pod targets 13 —
                // decode the halfs manually (halfToFloat below).
                var halfs = [UInt16](repeating: 0, count: w * h * 4)
                halfs.withUnsafeMutableBytes { buf in
                    tex.getBytes(buf.baseAddress!, bytesPerRow: w * 8,
                                 from: MTLRegionMake2D(0, 0, w, h),
                                 mipmapLevel: 0)
                }
                for i in 0..<w * h * 4 {
                    floats[i] = halfToFloat(halfs[i])
                }
            case .rgba32Float:
                floats.withUnsafeMutableBytes { buf in
                    tex.getBytes(buf.baseAddress!, bytesPerRow: w * 16,
                                 from: MTLRegionMake2D(0, 0, w, h),
                                 mipmapLevel: 0)
                }
            case .rgba8Unorm, .rgba8Unorm_srgb,
                 .bgra8Unorm, .bgra8Unorm_srgb:
                var bytes = [UInt8](repeating: 0, count: w * h * 4)
                bytes.withUnsafeMutableBytes { buf in
                    tex.getBytes(buf.baseAddress!, bytesPerRow: w * 4,
                                 from: MTLRegionMake2D(0, 0, w, h),
                                 mipmapLevel: 0)
                }
                let bgra = tex.pixelFormat == .bgra8Unorm
                    || tex.pixelFormat == .bgra8Unorm_srgb
                host.logOnce("env.exr.\(tag).ldr",
                    "\(tag): EXR decoded to \(tex.pixelFormat) — HDR "
                    + "range clamped by the loader (approximation)")
                for i in 0..<w * h {
                    let o = i * 4
                    floats[o]     = Float(bytes[o + (bgra ? 2 : 0)]) / 255
                    floats[o + 1] = Float(bytes[o + 1]) / 255
                    floats[o + 2] = Float(bytes[o + (bgra ? 0 : 2)]) / 255
                    floats[o + 3] = Float(bytes[o + 3]) / 255
                }
            default:
                host.logOnce("env.exr.\(tag).fmt.\(tex.pixelFormat.rawValue)",
                    "\(tag): EXR decoded to unhandled pixelFormat "
                    + "\(tex.pixelFormat)")
                return nil
            }
            return EnvPixels(width: w, height: h, isFloat: true,
                             data: floats.withUnsafeBufferPointer {
                                 Data(bytes: $0.baseAddress!,
                                      count: $0.count
                                        * MemoryLayout<Float>.size)
                             })
        }

        /// EXR via `CIImage` → `CIContext` RGBAf — the fallback when
        /// Metal can't produce a readable texture. Rendering into
        /// extended-linear-sRGB keeps values >1.0 (a clamped working
        /// space would flatten HDR). `render(toBitmap:)` writes
        /// top-down rows, matching the `EnvPixels` convention.
        func exrCoreImagePixels(_ data: Data) -> EnvPixels? {
            guard let ci = CIImage(data: data),
                  ci.extent.width > 0, ci.extent.height > 0,
                  let space = CGColorSpace(
                      name: CGColorSpace.extendedLinearSRGB)
            else { return nil }
            let w = Int(ci.extent.width.rounded())
            let h = Int(ci.extent.height.rounded())
            // The render bounds are rect-anchored — move a non-zero
            // extent origin to (0,0) so the whole image renders.
            let moved = ci.extent.origin == .zero ? ci :
                ci.transformed(by: CGAffineTransform(
                    translationX: -ci.extent.minX, y: -ci.extent.minY))
            var floats = [Float](repeating: 0, count: w * h * 4)
            floats.withUnsafeMutableBytes { buf in
                CIContext().render(
                    moved, toBitmap: buf.baseAddress!,
                    rowBytes: w * 4 * MemoryLayout<Float>.size,
                    bounds: CGRect(x: 0, y: 0, width: w, height: h),
                    format: .RGBAf, colorSpace: space)
            }
            return EnvPixels(width: w, height: h, isFloat: true,
                             data: floats.withUnsafeBufferPointer {
                                 Data(bytes: $0.baseAddress!,
                                      count: $0.count
                                        * MemoryLayout<Float>.size)
                             })
        }

        // MARK: Environment pixel transforms

        /// The object SceneKit binds: `UIImage` for sRGB8 sources, an
        /// `MDLTexture` (linear float) for HDR — both equirect, both
        /// cube-converted internally by SceneKit.
        func envContents(_ env: EnvPixels) -> Any? {
            if env.isFloat {
                return MDLTexture(
                    data: env.data, topLeftOrigin: true, name: nil,
                    dimensions: vector_int2(Int32(env.width),
                                            Int32(env.height)),
                    rowStride: env.width * 4 * MemoryLayout<Float>.size,
                    channelCount: 4, channelEncoding: .float32,
                    isCube: false)
            }
            return rgbaCGImage(env.data, width: env.width,
                               height: env.height, content: "color")
                .map { UIImage(cgImage: $0) }
        }

        /// Bakes the LH→RH z-mirror plus `environmentRotationY` — both
        /// exact column ops on an equirect. The mirror flips longitude
        /// (upstream LH dir (x,y,z) lands at RH (x,y,−z), negating the
        /// atan2 longitude), and upstream's `Matrix3.rotationY(θ)` env
        /// transform moves content toward +longitude by θ — so output
        /// column x reads source column `w−1−x−shift` with
        /// `shift = round(θ·w/2π)`.
        func mirroredRotated(_ env: EnvPixels, _ rotationY: Double)
            -> EnvPixels
        {
            let bpp = env.isFloat ? 16 : 4
            let w = env.width, h = env.height
            let shift = (rotationY / (2 * .pi) * Double(w)).rounded()
            let s = ((Int(shift) % w) + w) % w
            var out = Data(count: env.data.count)
            env.data.withUnsafeBytes { srcBuf in
                out.withUnsafeMutableBytes { dstBuf in
                    guard let sp = srcBuf.baseAddress?
                        .assumingMemoryBound(to: UInt8.self),
                          let dp = dstBuf.baseAddress?
                        .assumingMemoryBound(to: UInt8.self)
                    else { return }
                    for y in 0..<h {
                        for x in 0..<w {
                            let sx = ((w - 1 - x - s) % w + w) % w
                            let so = (y * w + sx) * bpp
                            let dOff = (y * w + x) * bpp
                            for k in 0..<bpp {
                                dp[dOff + k] = sp[so + k]
                            }
                        }
                    }
                }
            }
            return EnvPixels(width: w, height: h, isFloat: env.isFloat,
                             data: out)
        }

        /// `environmentIntensity`/`skybox.intensity` baked into pixels —
        /// sRGB bytes decode to linear, scale, and re-encode (a plain
        /// byte multiply would mis-darken); float texels multiply in
        /// place. Alpha passes through.
        func scaledPixels(_ env: EnvPixels, _ k: Double) -> EnvPixels {
            if k == 1 { return env }
            var out = Data(count: env.data.count)
            if env.isFloat {
                env.data.withUnsafeBytes { srcBuf in
                    out.withUnsafeMutableBytes { dstBuf in
                        guard let sp = srcBuf.baseAddress?
                            .assumingMemoryBound(to: Float.self),
                              let dp = dstBuf.baseAddress?
                            .assumingMemoryBound(to: Float.self)
                        else { return }
                        let kf = Float(k)
                        for i in stride(from: 0,
                                        to: env.width * env.height * 4,
                                        by: 4) {
                            dp[i] = sp[i] * kf
                            dp[i + 1] = sp[i + 1] * kf
                            dp[i + 2] = sp[i + 2] * kf
                            dp[i + 3] = sp[i + 3]
                        }
                    }
                }
            } else {
                env.data.withUnsafeBytes { srcBuf in
                    out.withUnsafeMutableBytes { dstBuf in
                        guard let sp = srcBuf.baseAddress?
                            .assumingMemoryBound(to: UInt8.self),
                              let dp = dstBuf.baseAddress?
                            .assumingMemoryBound(to: UInt8.self)
                        else { return }
                        for i in stride(from: 0,
                                        to: env.width * env.height * 4,
                                        by: 4) {
                            for c in 0..<3 {
                                dp[i + c] = encodeSrgb(
                                    srgbToLinear(Double(sp[i + c])
                                                 / 255.0) * k)
                            }
                            dp[i + 3] = sp[i + 3]
                        }
                    }
                }
            }
            return EnvPixels(width: env.width, height: env.height,
                             isFloat: env.isFloat, data: out)
        }

        /// Cheap separable box blur for `skybox.blurriness` — longitude
        /// wraps, latitude clamps (equirect-aware edges). Runs in
        /// storage space (sRGB for LDR): approximate by design, and the
        /// caller warn-onces that.
        func boxBlurredPixels(_ env: EnvPixels, radius r: Int)
            -> EnvPixels
        {
            guard r > 0 else { return env }
            let w = env.width, h = env.height
            let count = 2 * r + 1
            if env.isFloat {
                var px = env.data.withUnsafeBytes {
                    [Float]($0.bindMemory(to: Float.self))
                }
                var tmp = [Float](repeating: 0, count: w * h * 4)
                let f = 1.0 / Float(count)
                for y in 0..<h {
                    for x in 0..<w {
                        var acc: (Float, Float, Float, Float) = (0, 0, 0, 0)
                        for k in -r...r {
                            let sx = ((x + k) % w + w) % w
                            let o = (y * w + sx) * 4
                            acc.0 += px[o]; acc.1 += px[o + 1]
                            acc.2 += px[o + 2]; acc.3 += px[o + 3]
                        }
                        let o = (y * w + x) * 4
                        tmp[o] = acc.0 * f; tmp[o + 1] = acc.1 * f
                        tmp[o + 2] = acc.2 * f; tmp[o + 3] = acc.3 * f
                    }
                }
                for y in 0..<h {
                    for x in 0..<w {
                        var acc: (Float, Float, Float, Float) = (0, 0, 0, 0)
                        for k in -r...r {
                            let sy = min(max(y + k, 0), h - 1)
                            let o = (sy * w + x) * 4
                            acc.0 += tmp[o]; acc.1 += tmp[o + 1]
                            acc.2 += tmp[o + 2]; acc.3 += tmp[o + 3]
                        }
                        let o = (y * w + x) * 4
                        px[o] = acc.0 * f; px[o + 1] = acc.1 * f
                        px[o + 2] = acc.2 * f; px[o + 3] = acc.3 * f
                    }
                }
                return EnvPixels(width: w, height: h, isFloat: true,
                                 data: px.withUnsafeBufferPointer {
                                     Data(bytes: $0.baseAddress!,
                                          count: $0.count
                                            * MemoryLayout<Float>.size)
                                 })
            }
            var px = env.data
            var tmp = Data(count: px.count)
            px.withUnsafeMutableBytes { srcBuf in
                tmp.withUnsafeMutableBytes { tmpBuf in
                    guard let sp = srcBuf.baseAddress?
                        .assumingMemoryBound(to: UInt8.self),
                          let tp = tmpBuf.baseAddress?
                        .assumingMemoryBound(to: UInt8.self)
                    else { return }
                    for y in 0..<h {
                        for x in 0..<w {
                            var acc: (Int, Int, Int, Int) = (0, 0, 0, 0)
                            for k in -r...r {
                                let sx = ((x + k) % w + w) % w
                                let o = (y * w + sx) * 4
                                acc.0 += Int(sp[o])
                                acc.1 += Int(sp[o + 1])
                                acc.2 += Int(sp[o + 2])
                                acc.3 += Int(sp[o + 3])
                            }
                            let o = (y * w + x) * 4
                            tp[o] = UInt8(acc.0 / count)
                            tp[o + 1] = UInt8(acc.1 / count)
                            tp[o + 2] = UInt8(acc.2 / count)
                            tp[o + 3] = UInt8(acc.3 / count)
                        }
                    }
                }
            }
            tmp.withUnsafeBytes { tmpBuf in
                px.withUnsafeMutableBytes { dstBuf in
                    guard let tp = tmpBuf.baseAddress?
                        .assumingMemoryBound(to: UInt8.self),
                          let dp = dstBuf.baseAddress?
                        .assumingMemoryBound(to: UInt8.self)
                    else { return }
                    for y in 0..<h {
                        for x in 0..<w {
                            var acc: (Int, Int, Int, Int) = (0, 0, 0, 0)
                            for k in -r...r {
                                let sy = min(max(y + k, 0), h - 1)
                                let o = (sy * w + x) * 4
                                acc.0 += Int(tp[o])
                                acc.1 += Int(tp[o + 1])
                                acc.2 += Int(tp[o + 2])
                                acc.3 += Int(tp[o + 3])
                            }
                            let o = (y * w + x) * 4
                            dp[o] = UInt8(acc.0 / count)
                            dp[o + 1] = UInt8(acc.1 / count)
                            dp[o + 2] = UInt8(acc.2 / count)
                            dp[o + 3] = UInt8(acc.3 / count)
                        }
                    }
                }
            }
            return EnvPixels(width: w, height: h, isFloat: false,
                             data: px)
        }

        /// Untagged JSON number — the env "look" fields serialize raw,
        /// unlike the `{'d': …}` tagged property values.
        func plainDouble(_ v: Any?) -> Double? {
            (v as? NSNumber)?.doubleValue
        }

        func smoothstep01(_ x: Double) -> Double {
            let t = min(max(x, 0.0), 1.0)
            return t * t * (3.0 - 2.0 * t)
        }

        func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
            a + (b - a) * t
        }

        /// Upstream `_encodeSrgb` — linear → sRGB-encoded byte.
        func encodeSrgb(_ linear: Double) -> UInt8 {
            let c = min(max(linear, 0.0), 1.0)
            let e = c <= 0.0031308
                ? c * 12.92
                : 1.055 * pow(c, 1.0 / 2.4) - 0.055
            return UInt8(min(max(Int((e * 255.0).rounded()), 0), 255))
        }

        /// Upstream `_srgbToLinear` — sRGB byte → linear.
        func srgbToLinear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92
                : pow((c + 0.055) / 1.055, 2.4)
        }

        /// IEEE-754 half → float32. Hand-rolled because `Float16`
        /// needs iOS 14 and the pod targets 13. Sign, 5-bit exponent
        /// (bias 15), 10-bit mantissa; subnormals scale by 2⁻²⁴,
        /// exp=31 maps to inf/NaN.
        func halfToFloat(_ h: UInt16) -> Float {
            let sign: Float = (h & 0x8000) != 0 ? -1 : 1
            let exp = Int((h >> 10) & 0x1F)
            let mant = Int(h & 0x3FF)
            if exp == 0 { return sign * Float(mant) * powf(2, -24) }
            if exp == 31 {
                return mant != 0 ? .nan : sign * .infinity
            }
            return sign * (1 + Float(mant) / 1024)
                * powf(2, Float(exp - 15))
        }

        // MARK: Tagged property values

        func d3Bool(_ v: Any?) -> Bool? {
            (v as? [String: Any])?["b"] as? Bool
        }

        func d3Double(_ v: Any?) -> Double? {
            ((v as? [String: Any])?["d"] ?? (v as? [String: Any])?["i"]) as? Double
                ?? (((v as? [String: Any])?["d"] ?? (v as? [String: Any])?["i"]) as? Int)
                    .map(Double.init)
        }

        /// `{'v3': [x,y,z]}` — bare `[x,y,z]` fallback: procedural spec
        /// fields (e.g. cuboid `extents`) serialize untagged upstream.
        func d3Vec3(_ v: Any?) -> [Double]? {
            if let tagged = (v as? [String: Any])?["v3"] as? [Double] {
                return tagged
            }
            return v as? [Double]
        }

        func d3Vec4(_ v: Any?) -> [Double]? {
            if let tagged = (v as? [String: Any])?["v4"] as? [Double] {
                return tagged
            }
            return v as? [Double]
        }

        /// `{'q': [x,y,z,w]}` — quaternion (basis fields).
        func d3Quat(_ v: Any?) -> [Double]? {
            if let tagged = (v as? [String: Any])?["q"] as? [Double],
               tagged.count == 4 {
                return tagged
            }
            return v as? [Double]
        }

        func d3String(_ v: Any?) -> String? {
            (v as? [String: Any])?["s"] as? String
        }

        func d3Int(_ v: Any?) -> Int? {
            let raw = (v as? [String: Any])?["i"]
                ?? (v as? [String: Any])?["d"]
            if let i = raw as? Int { return i }
            return (raw as? Double).map(Int.init)
        }

        /// `{'v2': [x,y]}` — with a bare `[x,y]` fallback so a raw
        /// (untagged) transform map decodes the same way.
        func d3Vec2(_ v: Any?) -> [Double]? {
            if let tagged = (v as? [String: Any])?["v2"] as? [Double] {
                return tagged
            }
            return v as? [Double]
        }

        /// Raw [r,g,b,a] for a `{'c': …}` color — the bake path needs
        /// the components, not a UIColor.
        func d3ColorComponents(_ v: Any?) -> [Double]? {
            guard let c = (v as? [String: Any])?["c"] as? [Double],
                  c.count == 4 else { return nil }
            return c
        }

        func d3Color(_ v: Any?) -> UIColor? {
            guard let c = d3ColorComponents(v) else { return nil }
            return UIColor(red: c[0], green: c[1], blue: c[2], alpha: c[3])
        }

        func d3Ref(_ v: Any?) -> UInt64? {
            guard let token = (v as? [String: Any])?["rref"] as? String
                    ?? (v as? [String: Any])?["nref"] as? String
            else { return nil }
            return D3Wire.localIdKey(token)
        }

        func d3List(_ v: Any?) -> [Any]? {
            (v as? [String: Any])?["list"] as? [Any]
        }

        func d3Map(_ v: Any?) -> [String: Any]? {
            (v as? [String: Any])?["map"] as? [String: Any]
        }

        /// Column-major 16-element `Matrix4` storage, converted LH→RH.
        func d3Mat4(_ v: Any?) -> SCNMatrix4? {
            guard let m = (v as? [String: Any])?["m4"] as? [Double],
                  m.count == 16 else { return nil }
            return D3Wire.matrix(m)
        }
    }
}
