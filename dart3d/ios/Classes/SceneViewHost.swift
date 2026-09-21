import Foundation
import SceneKit
import simd
import UIKit

/// The native view behind `SceneView`: an `SCNView` that owns the live
/// scene, the id→object registries the mutations address, and the binary
/// payload store resources realize from.
///
/// Ids on the Dart side are `LocalId(session, index)` pairs; everything
/// here is keyed by the packed `UInt64` from `D3Wire.idKey` so the binary
/// mutation path and the `.fscene` token path address the same objects.
final class SceneViewHost: SCNView {

    /// Node registry for `setTransforms`, `command` ops, and physics.
    private(set) var nodesById: [UInt64: SCNNode] = [:]

    /// Keys of nodes carrying a `dynamic` rigid body — the set the
    /// settle detector polls after every simulated physics step.
    private(set) var dynamicBodyKeys: Set<UInt64> = []

    /// Reverse of `nodesById` — contact callbacks hand us `SCNNode`s,
    /// so each pair resolves to its wire id through this map.
    private(set) var nodeToKey: [ObjectIdentifier: UInt64] = [:]

    /// Node key → index of its `collider` component inside the spec's
    /// `components` array — the `ca`/`cb`/`collider` fields contact
    /// events and query hits report (best-effort: absent → 0).
    private(set) var colliderIndexByKey: [UInt64: Int] = [:]

    /// W15: node key → the node's raw `instance` spec member, present
    /// only on lazy prefab placeholders. The natives never resolve it
    /// — `SceneController.loadSubtree` composes the subtree Dart-side
    /// and ships it as ordinary ops; this registry is the tag check
    /// (`loadSubtree` on an untagged node warns) and survives until
    /// the placeholder's own re-spec or a `removeNode` drops it.
    private(set) var instanceSpecs: [UInt64: [String: Any]] = [:]

    /// Raw payload chunks received via `payload` mutations, keyed by
    /// payload id. Document-scoped — `loadScene` clears it since the
    /// (session,index) keys are document-local and collide across
    /// unrelated manifests (bundled assets share the importer's
    /// session salt, so index 4 in doc A is index 4 in doc B).
    private(set) var payloadStore: [UInt64: Data] = [:]

    /// Retained resource registries from the last `install` — the
    /// surgical ops (`upsertResource`, `upsertPayload`) re-decode
    /// single resources into these instead of re-realizing the whole
    /// doc, which would respawn physics bodies mid-scene.
    private(set) var geometriesById: [UInt64: SCNGeometry] = [:]
    private(set) var materialsById: [UInt64: SCNMaterial] = [:]
    private(set) var texturesById: [UInt64: FsceneRealizer.DecodedTexture] = [:]

    /// Raw manifest entry per resource id, for surgical re-decodes;
    /// slot rebinding also reads material factors back out of it.
    private(set) var resourceDefs: [UInt64: [String: Any]] = [:]

    /// Payload manifest specs from the last `install` — a single-
    /// resource re-decode still needs them (rgba8 dims, formats).
    private(set) var payloadSpecs:
        [UInt64: FsceneRealizer.Context.PayloadSpec] = [:]

    /// Specs that arrived on `upsertPayload` ops rather than the
    /// manifest — a full re-realize rebuilds `payloadSpecs` from the
    /// manifest alone, so these merge back on top at `install`.
    private var opPayloadSpecs:
        [UInt64: FsceneRealizer.Context.PayloadSpec] = [:]

    /// Texture id → every (material, slot) binding consuming it — a
    /// texture upsert re-applies each one with the new image.
    private(set) var textureConsumers:
        [UInt64: [FsceneRealizer.TextureBinding]] = [:]

    /// Material id → geometries whose `.materials` reference it — a
    /// material upsert re-attaches the re-decoded instance.
    private(set) var materialConsumers: [UInt64: [SCNGeometry]] = [:]

    /// Geometry id → nodes whose mesh consumed it — a geometry
    /// upsert re-decodes the resource and swaps the result onto each
    /// consumer's `.geometry`.
    private(set) var geometryConsumers: [UInt64: [SCNNode]] = [:]

    /// Texture id → payload id backing it, so an `upsertPayload` chunk
    /// finds the textures it unblocks.
    private(set) var texturePayloadKeys: [UInt64: UInt64] = [:]

    /// Geometry id → payload ids backing it (vertices plus indices),
    /// so an `upsertPayload` chunk finds the geometries it unblocks.
    private(set) var geometryPayloadKeys: [UInt64: Set<UInt64>] = [:]

    /// Environment id → payload id backing its equirect source, so an
    /// `upsertPayload` chunk re-runs `decodeStage` on arrival (W7).
    private(set) var environmentPayloadKeys: [UInt64: UInt64] = [:]

    /// W25: environment id → payload id backing its
    /// `effects.colorGrading.lut` table — the chunk's arrival re-runs
    /// `decodeStage` like an env equirect claim.
    private(set) var lutPayloadKeys: [UInt64: UInt64] = [:]

    /// W25: decoded LUT strip images, keyed by `ref + sep + blend`
    /// (the blend bakes into the pixels). Entries drop when a
    /// `payload`/`upsertPayload` chunk rewrites the ref's bytes.
    private var lutImages: [String: CGImage] = [:]

    /// W11 stores — decoded skins, decoded animations, absolute morph
    /// targets per geometry, the node→skin bindings, and the raw defs
    /// surgical re-decodes replay. `pendingSkinNodes` holds nodes whose
    /// skinner waits on a joint/skeleton/geometry/IBM still in flight.
    private(set) var skinsById:
        [UInt64: FsceneRealizer.DecodedSkin] = [:]
    private(set) var animationsById:
        [UInt64: FsceneRealizer.DecodedAnimation] = [:]
    private(set) var morphTargetsById:
        [UInt64: FsceneRealizer.DecodedMorph] = [:]
    private(set) var nodeSkinKeys: [UInt64: UInt64] = [:]
    private(set) var pendingSkinNodes: Set<UInt64> = []
    /// Node key → the derived shape type its collider wants
    /// (`boundingBox`/`convexHull`/`concavePolyhedron`), recorded when
    /// the collider decoded while the node's geometry was still
    /// payload-deferred — the body attaches shapeless and SceneKit
    /// never re-derives it, so `decodeMesh` refills the shape when the
    /// geometry lands. Host-side (not the ctx tuple): both writers
    /// reach it through `host` on every decode path.
    var pendingColliderShapes: [UInt64: SCNPhysicsShape.ShapeType] = [:]
    private(set) var skinPayloadKeys: [UInt64: UInt64] = [:]
    private(set) var animPayloadKeys: [UInt64: Set<UInt64>] = [:]
    private(set) var skinDefs: [UInt64: [String: Any]] = [:]
    private(set) var animDefs: [UInt64: [String: Any]] = [:]

    /// The last `stage` JSON applied — the manifest's on install, then
    /// `updateStage` ops. A payload-arrival stage re-decode replays it.
    private(set) var lastStage: [String: Any]?

    /// Linear pre-tonemap exposure from the decoded stage — applied to
    /// the point-of-view camera as `exposureOffset = log2(exposure)`
    /// with `wantsHDR = true` (SceneKit's HDR path is per-camera).
    private(set) var stageExposure: Double = 1.0

    /// W13: the last decoded `effects` post stack — retained across
    /// stage re-decodes whose `effects` key is absent (the wire's
    /// "don't touch" rule), wholesale-replaced when the key is
    /// present. `applyStageEffects` re-writes every supported knob.
    private(set) var lastEffects: StageEffects? = nil

    /// W14: the render-target registry — `rt:` key → record (spec,
    /// texture pair, the views targeting it, schedule state). Internal
    /// rather than `private(set)`: the offscreen scheduler in
    /// RenderTargets.swift mutates pass state (dirty/lastRenderTime/
    /// lazy renderers) from the same render thread.
    var renderTargets: [UInt64: RenderTargetRec] = [:]

    /// W14: the decoded `views` list (wholesale-replaced by manifest
    /// decode and `updateViews`); `screenViews` is the target-absent
    /// subset, order-sorted — texture-target views live order-sorted
    /// inside their rt record's `views` instead.
    var views: [ViewRec] = []
    var screenViews: [ViewRec] = []

    /// W24 split-screen — render-queue state: one rec per screen view
    /// while `multiScreenMode` is on (≥2 screen views or any
    /// `viewport` rect). The sibling `SCNView` objects live in
    /// `mainScreenSubviews` on the main thread; the lists pair by
    /// index. `screenSubviewBuild` generation-gates the main-side
    /// builds so a superseded one can't install.
    var screenSubviews: [ScreenSubview] = []
    var multiScreenMode = false
    var screenSubviewBuild = 0

    /// MAIN-THREAD state — the sibling `SCNView`s and their recs,
    /// built and torn down inside main hops only (`layoutSubviews`
    /// and the per-frame poke read it there). Stored on the host
    /// rather than behind a lock: every access site is main-thread.
    var mainScreenSubviews: [(view: SCNView, rec: ViewRec)] = []

    /// The host's point-of-view in split mode — a detached node whose
    /// camera sees nothing (mask 0), so the host pass contributes
    /// clear/background only while every declared screen view owns a
    /// sibling `SCNView`.
    var blankPov: SCNNode?

    /// W14 stage quality — decoded off `stage` itself (not the env
    /// resource). `applyStageQuality` maps them onto the view;
    /// `resolvedViewAASamples` reads `stageAntiAliasing` for the
    /// offscreen precedence chain.
    private(set) var stageAntiAliasing = "auto"
    private(set) var stageRenderScale = 1.0
    private(set) var stageFilterQuality = "medium"

    /// `viewConfig.quality` tier — "low"|"medium"|"high", or nil for
    /// 'default'. A set tier owns the pipeline: it writes
    /// `antialiasingMode` (the viewConfig level — stage/view modes
    /// still outrank through `applyStageQuality`), gates `castsShadow`
    /// at light decode, and lifts `shadowMapSize` at 'high'.
    var viewQuality: String? = nil
    /// Lights that authored `castsShadow` — keyed by light object so a
    /// 'low'→'default' transition restores rather than flattens.
    var shadowAuthored = Set<ObjectIdentifier>()

    /// Settle bookkeeping: SceneKit's `isResting` threshold is a fixed
    /// units/s floor, so contact-solver noise at mm-scale gravity
    /// (±40 u/s of jitter) keeps bodies awake forever. A body whose
    /// speed stays under a gravity-scaled floor for ~0.5s of sim ticks
    /// counts as asleep alongside `isResting`.
    var quietTicks: [UInt64: Int] = [:]
    /// `physicsWorld.gravity` magnitude — the scale signal for the
    /// quiet-floor epsilons (mm-scale worlds need mm-scale eps).
    var worldGravityScale = 9.8

    /// Stores the stage exposure and applies it to the current
    /// point-of-view camera. Called on install (after the camera is
    /// chosen), on `updateStage`, and after a payload-arrival stage
    /// re-decode; `promoteCamera`/`restoreFallbackCamera` re-apply it
    /// when the camera node itself changes.
    func applyStageExposure(_ exposure: Double) {
        stageExposure = exposure
        // W13: colorGrading.brightness stacks multiplicatively on the
        // stage exposure — both are linear pre-tonemap scales.
        let e = exposure * (lastEffects?.colorGrading.brightness ?? 1.0)
        // W14: exposure is per-camera in SceneKit — write every view
        // camera, not just the point of view.
        for camera in viewCameras() {
            camera.wantsHDR = true
            camera.exposureOffset = CGFloat(e > 0 ? log2(e) : 0)
        }
    }

    /// Every camera the stage look applies to — the point of view
    /// plus each declared view's camera (W14: effects are per-camera
    /// in SceneKit, so texture-target view cameras need the same
    /// writes; views sharing a camera dedupe).
    private func viewCameras() -> [SCNCamera] {
        var cams: [SCNCamera] = []
        if let c = pointOfView?.camera { cams.append(c) }
        for v in views {
            guard let c = nodesById[v.cameraKey]?.camera,
                  !cams.contains(where: { $0 === c }) else { continue }
            cams.append(c)
        }
        return cams
    }

    /// W13: applies the decoded `effects` post stack absolutely —
    /// every supported knob is written each run (enabled → the
    /// decoded value, disabled → the engine's off value) so a
    /// re-decode under re-realization storms leaves no stale state.
    /// Camera knobs land on `pointOfView` AND each declared view's
    /// camera (W14 — effects are per-camera in SceneKit), TAA on the
    /// view itself, fog on `scene` — each part applies independently
    /// when its target exists. Unsupported blocks log once and are
    /// ignored.
    func applyStageEffects() {
        guard let fx = lastEffects else { return }

        for camera in viewCameras() {
            camera.bloomThreshold = CGFloat(fx.bloom.threshold)
            camera.bloomIntensity =
                CGFloat(fx.bloom.enabled ? fx.bloom.intensity : 0)
            // scatter is a 0..1 spread; SceneKit wants blur pixels.
            camera.bloomBlurRadius = CGFloat(4 + 12 * fx.bloom.scatter)

            // vignettingPower is the edge-rolloff exponent (0 = off);
            // upstream radius has no counterpart — smoothness×2
            // approximates the rolloff.
            camera.vignettingIntensity =
                CGFloat(fx.vignette.enabled ? fx.vignette.intensity : 0)
            camera.vignettingPower = CGFloat(fx.vignette.enabled
                ? max(0.1, fx.vignette.smoothness * 2) : 0)

            camera.colorFringeStrength =
                CGFloat(fx.chromaticAberration.enabled
                    ? fx.chromaticAberration.intensity : 0)

            // W25: SceneKit has no lens-flare pass — approximated.
            // The flare's visible terms map onto the post knobs the
            // camera already carries: intensity widens bloom (the
            // halo body), haloRadius spreads it, and the flare's
            // chromaticAberration adds a radial fringe. Ghost/halo
            // geometry is a documented platform limit.
            if fx.lensFlare.enabled {
                let lf = fx.lensFlare
                camera.bloomIntensity +=
                    CGFloat(lf.intensity * 0.5)
                camera.bloomBlurRadius +=
                    CGFloat(lf.haloRadius * 24 * lf.haloIntensity)
                camera.colorFringeStrength +=
                    CGFloat(lf.chromaticAberration * 200)
                logOnce("fx.lensFlare.approx",
                    "lensFlare approximated on SceneKit as widened "
                    + "bloom + color fringe; ghost/halo geometry is "
                    + "a platform limit")
            }

            let cg = fx.colorGrading
            camera.saturation =
                CGFloat(cg.enabled ? cg.saturation : 1.0)
            // Upstream contrast is 1.0-neutral multiplicative;
            // SceneKit's is 0.0-neutral additive in [-1, 1].
            camera.contrast = CGFloat(min(1, max(-1,
                cg.enabled ? cg.contrast - 1.0 : 0)))
            camera.whiteBalanceTemperature =
                CGFloat(cg.enabled ? cg.temperature : 0)
            camera.whiteBalanceTint = CGFloat(cg.enabled ? cg.tint : 0)
            // W25: the LUT grades independently of `enabled`
            // (upstream's rule). A `chunk:`/id-token ref resolves
            // through the payload store — its decode-time claim
            // re-runs the stage when the bytes land; an asset path
            // resolves from the main bundle.
            camera.colorGrading.contents =
                (cg.lut.flatMap { $0.isEmpty ? nil : $0 })
                    .flatMap { resolveLutImage($0, blend: cg.lutBlend) }
            if cg.enabled {
                if cg.lift != SIMD3<Float>(0, 0, 0)
                    || cg.gamma != SIMD3<Float>(1, 1, 1)
                    || cg.gain != SIMD3<Float>(1, 1, 1) {
                    logOnce("fx.colorGrading.lgg",
                        "colorGrading lift/gamma/gain need "
                        + "SCNTechnique/LUT on SceneKit; ignored")
                }
            }

            camera.grainIntensity =
                CGFloat(fx.filmGrain.enabled ? fx.filmGrain.intensity : 0)

            let ao = fx.ambientOcclusion
            camera.screenSpaceAmbientOcclusionIntensity =
                CGFloat(ao.enabled ? ao.intensity : 0)
            camera.screenSpaceAmbientOcclusionRadius =
                CGFloat(ao.radius)
            camera.screenSpaceAmbientOcclusionBias = CGFloat(ao.bias)
            // power/detail/slices/samples/specularMode/etc. have no
            // SSAO-knob counterpart — skipped.
            if ao.enabled && ao.method == "groundTruth" {
                logOnce("fx.ao.method",
                    "ambientOcclusion.method 'groundTruth' not "
                    + "available on SceneKit; using SSAO")
            }

            let dof = fx.depthOfField
            camera.wantsDepthOfField = dof.enabled
            camera.focusDistance = CGFloat(dof.focusDistance)
            camera.fStop = CGFloat(dof.fStop)
            // Upstream bladeCount <3 means a circular aperture;
            // SceneKit wants ≥3, so fall back to its 6-blade default.
            camera.apertureBladeCount =
                dof.bladeCount >= 3 ? dof.bladeCount : 6
            camera.focalBlurSampleCount =
                dof.quality == "low" ? 8
                : dof.quality == "high" ? 25 : 16

            let ae = fx.autoExposure
            camera.wantsExposureAdaptation = ae.enabled
            camera.minimumExposure = CGFloat(ae.minEv)
            camera.maximumExposure = CGFloat(ae.maxEv)
            camera.exposureAdaptationBrighteningSpeedFactor =
                CGFloat(ae.speedUp)
            camera.exposureAdaptationDarkeningSpeedFactor =
                CGFloat(ae.speedDown)
            if ae.enabled
                && (ae.strength != 0.55 || ae.compensation != 0) {
                logOnce("fx.autoExposure.params",
                    "autoExposure strength/compensation unsupported "
                    + "on SceneKit; ignored")
            }
        }

        // TAA toggles on the SCNView, not the camera.
        let taa = fx.temporalAntiAliasing
        #if targetEnvironment(simulator)
        if taa.enabled {
            logOnce("fx.taa.sim",
                "TAA is unreliable on the iOS Simulator; skipped")
        }
        #else
        isTemporalAntialiasingEnabled = taa.enabled
        #endif
        if taa.enabled
            && (taa.minimumCurrentWeight != 0.1
                || taa.varianceGamma != 1.0 || taa.sharpness != 0
                || taa.jitterSequenceLength != 16
                || taa.jitterScale != 1.0 || !taa.objectMotion
                || !taa.skinnedMotion) {
            logOnce("fx.taa.params",
                "TAA tuning params unsupported on SceneKit; "
                + "toggle only")
        }

        // Fog is scene-level. SceneKit has no height falloff or
        // in-scatter term, and exp modes carry no end distance —
        // estimate the fade-out at ≈4 optical depths.
        if let scene = scene {
            let fog = fx.fog
            if !fog.enabled || fog.mode == "none" {
                scene.fogEndDistance = 0   // 0 disables SceneKit fog
            } else {
                scene.fogColor = UIColor(
                    red: CGFloat(fog.color.x),
                    green: CGFloat(fog.color.y),
                    blue: CGFloat(fog.color.z), alpha: 1)
                switch fog.mode {
                case "linear":
                    scene.fogStartDistance = CGFloat(fog.start)
                    scene.fogEndDistance = CGFloat(fog.end)
                    scene.fogDensityExponent = 1
                case "exponentialSquared":
                    scene.fogStartDistance = 0
                    scene.fogEndDistance = CGFloat(fog.density > 0
                        ? max(1, 4 / fog.density) : 0)
                    scene.fogDensityExponent = 3
                default: // 'exponential' + unknown modes
                    scene.fogStartDistance = 0
                    scene.fogEndDistance = CGFloat(fog.density > 0
                        ? max(1, 4 / fog.density) : 0)
                    scene.fogDensityExponent = 2
                }
            }
            if fog.enabled
                && (fog.height != 0 || fog.heightFalloff != 0
                    || fog.sunInScatter != 0
                    || fog.skyColorInfluence != 0) {
                logOnce("fx.fog.params",
                    "fog height/in-scatter fields unsupported on "
                    + "SceneKit; approximated")
            }
        }

        // W25 documented platform limits — no SceneKit surface exists
        // for these blocks; each logs once and the decoded value still
        // participates in blending/parity.
        if fx.screenSpaceReflections.enabled {
            logOnce("fx.screenSpaceReflections.limit",
                "screenSpaceReflections: platform limit — SceneKit "
                + "has no screen-space reflection pass; ignored")
        }
        if fx.globalIllumination.enabled {
            logOnce("fx.globalIllumination.limit",
                "globalIllumination: platform limit — SceneKit has "
                + "no dynamic GI/probe-volume API; the IBL "
                + "environment stands; ignored")
        }
        if fx.godRays.enabled {
            logOnce("fx.godRays.limit",
                "godRays: platform limit — SceneKit has no "
                + "light-shaft/volumetric post pass; ignored")
        }
    }

    /// W25: resolves a `colorGrading.lut` ref to the strip image
    /// `SCNCamera.colorGrading.contents` samples. `chunk:`/id-token
    /// refs read the payload store (nil while deferred — the
    /// realizer's claim re-runs the stage on arrival); other strings
    /// are bundle asset paths. Parses are cached by ref+blend (the
    /// blend bakes into the strip); a `payload`/`upsertPayload`
    /// landing on the ref's id drops the stale entries.
    private func resolveLutImage(_ ref: String, blend: Double)
        -> CGImage?
    {
        let cacheKey = "\(ref)\u{1F}\(blend)"
        if let img = lutImages[cacheKey] { return img }
        let data: Data?
        if let pid = D3Wire.localIdKey(ref) {
            data = payloadStore[pid]
        } else if let url = FlutterAssets.url(forResource: ref) {
            data = try? Data(contentsOf: url)
            if data == nil {
                logOnce("fx.lut.asset.\(ref)",
                    "colorGrading LUT asset '\(ref)' unreadable")
            }
        } else {
            data = nil
            logOnce("fx.lut.asset.\(ref)",
                "colorGrading LUT asset '\(ref)' not in bundle")
        }
        guard let data else { return nil }
        guard let table = try? StageLut.parse(data: data) else {
            logOnce("fx.lut.parse.\(ref)",
                "colorGrading LUT '\(ref)' is not a valid 3D .cube")
            return nil
        }
        guard let img = table.stripImage(blend: blend) else {
            return nil
        }
        lutImages[cacheKey] = img
        return img
    }

    /// Drops cached LUT strips whose ref names payload id [key] —
    /// called when a `payload`/`upsertPayload` chunk rewrites those
    /// bytes, so the next apply rebuilds from the new table.
    private func invalidateLuts(backedBy key: UInt64) {
        lutImages = lutImages.filter { entry in
            let ref = entry.key.prefix { $0 != "\u{1F}" }
            return D3Wire.localIdKey(String(ref)) != key
        }
    }

    /// `fscene` format version of the last manifest — the seeded
    /// decode context for surgical ops needs it for legacy rules.
    private(set) var lastFormatVersion = 5

    /// This view's framework viewId — the token native→Dart events
    /// carry so the right `SceneController` picks them up. Stamped by
    /// the mutation router (it arrives with every mutation).
    var viewId: Int64 = 0

    /// Set by `applyHello`. Mutations arriving earlier are still
    /// processed — the protocol tolerates reordering — but logged once.
    private(set) var sawHello = false

    /// The install-time default camera, present only when the doc
    /// brought no camera of its own — an `addNode`/`updateNode` that
    /// decodes a camera promotes it over this placeholder.
    private var fallbackCameraNode: SCNNode?

    /// The document pick — the doc camera, a diff-promoted camera,
    /// or the install-time fallback — that owns `pointOfView` while
    /// no screen view is declared. Written at the same sites the
    /// fallback path picks `pointOfView` (install, `promoteCamera`,
    /// `restoreFallbackCamera`), so an emptied `views` list can hand
    /// the host's pass back to it (W24 fix-round). Non-private like
    /// `blankPov` — `teardownRenderTargets` clears it cross-file.
    var docPov: SCNNode?

    /// Warnings already emitted, keyed by caller-chosen tag, so
    /// payload-triggered re-realization can't repeat them.
    private var loggedOnce: Set<String> = []

    /// Logs `msg` only the first time `key` is seen.
    func logOnce(_ key: String, _ msg: String) {
        if loggedOnce.insert(key).inserted { d3Log(msg) }
    }

    /// Resource ids whose realization waits on payload bytes — a
    /// `payload` arrival re-runs `loadScene` while this is non-empty.
    private var deferredResourceIds: Set<UInt64> = []
    private var lastManifest: Data?

    /// Bodies awake as of the previous simulated step — the settle
    /// detector fires on transitions, not levels.
    private var lastAwakeCount = 0

    /// Simulated-step counter for throttled physics diagnostics.
    private var _simTick = 0

    /// Overlap probes armed by `query` ops. `contactTest` crashes on a
    /// body the physics world has not registered and reads the
    /// transform the last step synced in, so each probe is posed and
    /// attached at query time, then tested once two
    /// `didSimulatePhysicsAtTime` boundaries have passed (a probe
    /// attached mid-step can miss that step's registration pass).
    /// Guarded by `overlapLock`: arming happens on the mutation
    /// thread, draining on the render thread.
    private var pendingOverlaps:
        [(q: Int, probe: SCNNode, armedTick: Int)] = []
    private let overlapLock = NSLock()

    /// W9 joint bookkeeping, keyed by the caller-chosen u32 handle.
    /// `behavior` is nil while the record waits on an endpoint body —
    /// a joint arriving before its nodes defers like a payload claim
    /// and resolves when the body lands (`retryPendingJoints`).
    /// Guarded by `jointLock` for the same mutation-thread/render-
    /// thread split as `pendingOverlaps` (break polling drains in
    /// `didSimulatePhysicsAtTime`).
    private var joints: [UInt32: JointRecord] = [:]
    private let jointLock = NSLock()

    /// W12: declarative joint components register into `joints` under
    /// a reserved handle range — deferral, rebinding and break polling
    /// treat them identically to command-created joints. The map keeps
    /// (declaring nodeKey → component index → handle) so a components
    /// re-decode or node removal drops exactly its own records.
    private var componentJointIds: [UInt64: [Int: UInt32]] = [:]
    private var nextComponentJointHandle: UInt32 = 0x4000_0000

    /// W23 `collide:false` bookkeeping (all under `jointLock`).
    /// SceneKit exposes no per-pair collision switch, so exclusion
    /// borrows category bits the wire can't reach: the decoder shifts
    /// wire layers <<2 (bits 2–33 on the 64-bit Int), leaving bits
    /// 40–63 for private per-body categories. A privatized body's
    /// category is its dedicated bit; every body's masks are then
    /// DERIVED, never patched — `rebuildPairMasksLocked` re-runs the
    /// upstream `(a.layer & b.mask) && (b.layer & a.mask)` rule per
    /// body against the wire truth (`jointWireMasks`), so a pair
    /// exclusion is just clearing the partner's bit on both sides'
    /// collision and contact-test masks — the Jolt `GroupFilterTable`
    /// pair disable's twin, contact-event suppression included.
    private struct JointPair: Hashable {
        let lo: UInt64, hi: UInt64
        init(_ a: UInt64, _ b: UInt64) {
            lo = min(a, b); hi = max(a, b)
        }
        func contains(_ k: UInt64) -> Bool { k == lo || k == hi }
        func other(_ k: UInt64) -> UInt64 { k == lo ? hi : lo }
    }
    /// Category bits reserved for pair exclusion — bits 40–63, above
    /// the wire's <<2 layer space.
    private static let jointPrivateBits = Int(0xFF_FFFF) << 40
    /// Node key → its private category bit (implies a wire-masks save).
    private var jointPrivBits: [UInt64: Int] = [:]
    /// Privatized node key → (category, collision mask) as the wire
    /// authored it — the truth masks re-derive from.
    private var jointWireMasks: [UInt64: (cat: Int, mask: Int)] = [:]
    /// Body pair → count of live joint records excluding it.
    private var jointExcludedPairs: [JointPair: Int] = [:]

    /// The shared world anchor for joints declared without an
    /// `otherNode` — upstream attaches to a fixed body at the identity
    /// pose, so a single hidden static body at the origin serves every
    /// world-anchored joint (SceneKit's single-body joint inits take
    /// node-local anchors; routing through this body keeps `anchorB`
    /// world-space).
    private var worldAnchorNode: SCNNode?

    /// W12: `materialsVariants` components — declaring nodeKey → spec.
    /// Bindings re-resolve lazily at apply time so a target node or
    /// geometry that lands later still binds (the deferred-resource
    /// pattern). Owned here because `selectVariant` ops and node/geometry
    /// landings both consult it.
    var variantComponents: [UInt64: FsceneRealizer.VariantComponentSpec] =
        [:]

    /// W12: components decoded with `enabled:false` — recorded for
    /// parity reporting; upstream gates component ticks only.
    var disabledComponents: [UInt64: Set<Int>] = [:]

    /// W16: node key → live `trail` state (spec + recorded path +
    /// `d3trail:` child). The render-callback pass records the node's
    /// world position and rebuilds the ribbon — inside the drain like
    /// the animation sampler, never on the mutation thread.
    private(set) var trailStates:
        [UInt64: FsceneRealizer.TrailState] = [:]
    /// W16: node key → decoded `lod` spec; `lodResourceConsumers`
    /// routes resource landings to `rebindLod`, `pendingLodNodes`
    /// holds the unresolved ones (`pendingSkinNodes` pattern). The
    /// per-frame pass in `updateLods` selects + binds the level —
    /// SceneKit's `levelsOfDetail` is not used (its screen-space
    /// metric can't reproduce upstream's `lodScreenSize`).
    private(set) var lodSpecs:
        [UInt64: FsceneRealizer.LodSpec] = [:]
    private(set) var lodResourceConsumers:
        [UInt64: Set<UInt64>] = [:]
    private(set) var pendingLodNodes: Set<UInt64> = []
    private var lastTrailTime: TimeInterval?

    /// W11 animation runtime. A clip exists only after an `anim` op
    /// names its animation — upstream's `createAnimationClip` shape:
    /// no clip, no contribution (so doc load never snaps animated
    /// nodes to a key-0 pose). `AnimClipState` carries only playback
    /// fields; channel data is read live from `animationsById` so an
    /// `upsertAnimation`/payload re-decode refreshes the curves
    /// underneath a live clip.
    private struct AnimClipState {
        var playing = false
        var time = 0.0            // playbackTime, seconds
        var timeScale = 1.0
        var weight = 1.0          // clamped [0,1] on assignment
        var loop = false
    }

    /// Per-node captured bind state — upstream's `AnimationTransforms`.
    /// Captured ONCE when a channel first binds the node and kept even
    /// after its clips go away (upstream keeps `_targetTransforms`
    /// entries on `removeClip`; the per-frame write-back then holds the
    /// node at bind pose — deliberate).
    private struct AnimTargetState {
        var bindP = simd_float3()
        var bindR = simd_quatf(real: 1, imag: simd_float3())
        var bindS = simd_float3(repeating: 1)
        /// Any bound non-weights channel drives TRS writes; a node
        /// bound only by weights channels keeps its manual transform.
        var drivesTransform = false
        /// Rest morph weights captured at first weights-channel bind —
        /// nil when the node had no morpher (the channel then no-ops).
        var bindWeights: [Float]?
    }

    private var animClips: [UInt64: AnimClipState] = [:]
    private var animTargets: [UInt64: AnimTargetState] = [:]

    /// Guards `animClips`/`animTargets` — the ops run on the mutation
    /// thread, the sampler on the render thread (same split as
    /// `jointLock`/`overlapLock`).
    private let animLock = NSLock()

    /// Previous `updateAtTime` — the sampler advances clips by the
    /// frame delta, not the absolute clock.
    private var lastAnimTime: TimeInterval?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// SCNView's designated initializer is `init(frame:options:)` — its
    /// `init(frame:)` convenience forwards here, so overriding it is the
    /// required one (overriding only `init(frame:)` fatals on dispatch).
    override init(frame: CGRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: options)
        setup()
    }

    private func setup() {
        scene = SCNScene()
        scene?.physicsWorld.contactDelegate = self
        autoenablesDefaultLighting = false
        allowsCameraControl = false
        antialiasingMode = .multisampling4X
        backgroundColor = .black
        isPlaying = true
        delegate = self
    }

    /// View detach → the offscreen rt machinery tears down through the
    /// graveyard. Enqueued like every other mutation: this hook runs
    /// on the UIKit thread and mustn't touch `renderTargets`/
    /// `retiredThisFrame` mid-drain. If the render loop has already
    /// stopped, the work just never drains — the records stay
    /// retained on the host and die with it.
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            enqueueSceneWork { [weak self] in
                self?.teardownRenderTargets()
            }
        }
    }

    /// W24: sibling frames track the host's bounds — each screen
    /// view's `viewport` rect re-maps into the new target space.
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutScreenSubviews()
    }

    // MARK: - Mutation application (called from Dart3dPlugin.swift)

    /// Scene/physics mutations are only safe between SceneKit frames —
    /// the solver iterates its constraint array inside the render loop's
    /// step with no external lock (a delivery-thread `removeBehavior`
    /// during that step is an EXC_BAD_ACCESS in `solveConstraints`).
    /// Every mutation handler enqueues here; `renderer(_:updateAtTime:)`
    /// drains on the render queue just before the step, so writes never
    /// overlap simulation. FIFO preserves the delivery order the
    /// hello-gate and diff streams were written against.
    private var pendingWork: [() -> Void] = []
    private let pendingWorkLock = NSLock()

    /// SceneKit's render pass keeps references into the graph it is
    /// drawing — the frozen model-value storage
    /// (`C3DModelValueStoragePrepareNextFrame` walks it) and the
    /// captured `pointOfView`. Swapping `scene` or freeing a detached
    /// node mid-pass can release storage the pass still touches
    /// (EXC_BAD_ACCESS at ~0x28). Retired objects stay alive for two
    /// drains so every in-flight pass finishes first.
    private var retiredThisFrame: [AnyObject] = []
    private var retiredLastFrame: [AnyObject] = []

    /// Payload arrivals flag a re-realize instead of running one
    /// inline: a doc's N chunks drained in one pass then cost one
    /// decode, not N. Only touched on the render queue.
    private var realizePending = false

    func retire(_ obj: AnyObject) { retiredThisFrame.append(obj) }

    func enqueueSceneWork(_ work: @escaping () -> Void) {
        pendingWorkLock.lock()
        pendingWork.append(work)
        pendingWorkLock.unlock()
    }

    /// Runs every queued mutation. Called on the render queue at the
    /// top of `updateAtTime`.
    private func drainPendingWork() {
        // Rotating the graveyard drops objects retired two drains ago —
        // the passes that could still reference them have finished.
        retiredLastFrame = retiredThisFrame
        retiredThisFrame = []
        pendingWorkLock.lock()
        let work = pendingWork
        pendingWork.removeAll()
        pendingWorkLock.unlock()
        for item in work { item() }
        // Payload chunks in this drain may have unblocked deferred
        // resources — a single re-realize resolves every landed claim
        // at once (previously one full decode ran per chunk).
        if realizePending {
            realizePending = false
            if !deferredResourceIds.isEmpty, let manifest = lastManifest {
                // The shadow registry repopulates with this pass's
                // light objects. The retry is not a stage re-apply:
                // preserveStage re-decodes the LIVE stage so
                // updateStage/LUT/effects state survives.
                shadowAuthored.removeAll()
                FsceneRealizer.realize(manifest: manifest, into: self,
                                       preserveStage: true)
                // W15: the re-realize discarded the surgically
                // streamed subtrees with the rest of the scene —
                // rebuild each from its recorded load batch.
                replayStreamedSubtrees()
            }
        }
    }

    func applyHello(_ data: Data) {
        sawHello = true
        guard data.count >= 2 else { return }
        let major = data[data.startIndex], minor = data[data.startIndex + 1]
        d3Log("protocol hello: Dart v\(major).\(minor)")
        if major != 1 {
            d3Log("WARNING: unsupported protocol major v\(major); "
                + "expect 1.x — mutations may be misread")
        }
    }

    func applyViewConfig(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any] else { return }
        if let v = json["allowsCameraControl"] as? Bool {
            allowsCameraControl = v
            // W24: in split mode the flag lives on sibling 0 (the
            // lowest-order view, whose pov is the real camera node) —
            // the host's own pov is the blank pass.
            DispatchQueue.main.async { [weak self] in
                self?.mainScreenSubviews.first?.view.allowsCameraControl = v
            }
        }
        if let v = json["showsStatistics"] as? Bool {
            showsStatistics = v
        }
        if let v = json["antialiasingMode"] as? Int {
            antialiasingMode = v >= 4 ? .multisampling4X
                : v >= 2 ? .multisampling2X : .none
        }
        if let q = json["quality"] as? String {
            viewQuality = (q == "low" || q == "medium" || q == "high")
                ? q : nil
            applyViewQuality()
        }
        if let argb = json["backgroundColor"] as? Int {
            backgroundColor = UIColor(
                red: CGFloat((argb >> 16) & 0xFF) / 255.0,
                green: CGFloat((argb >> 8) & 0xFF) / 255.0,
                blue: CGFloat(argb & 0xFF) / 255.0,
                alpha: CGFloat((argb >> 24) & 0xFF) / 255.0
            )
        }
        // W14: a viewConfig AA write loses to a non-'auto' stage/view
        // mode — re-apply the precedence chain after the config lands.
        applyStageQuality()
    }

    func applyLoadScene(_ data: Data) {
        lastManifest = data
        // Payload ids are document-local — a previous document's bytes
        // would shadow this doc's chunks at colliding keys. The
        // manifest's own chunks arrive next, so the store starts empty
        // and every payload claim defers until its own bytes land.
        payloadStore.removeAll()
        realizePending = false
        // W15: the new document's session keys invalidate every
        // recorded subtree batch — drop them before the realize, and
        // any pending visible-stamp with them (its node id belongs to
        // the outgoing scene).
        streamedSubtreeOps.removeAll()
        subtreeVisibleStamp = nil
        // Shadow-tier registry is per-scene — repopulated by the
        // coming decode's light pass.
        shadowAuthored.removeAll()
        FsceneRealizer.realize(manifest: data, into: self)
    }

    func applyPayload(_ data: Data) {
        guard data.count > 8 else { return }
        let id = D3Wire.readLocalId(data, data.startIndex)
        let bytes = data.subdata(in: data.startIndex + 8..<data.endIndex)
        payloadStore[id] = bytes
        // W25: a rewritten LUT chunk invalidates its cached strips.
        invalidateLuts(backedBy: id)
        // W7/W25: an env equirect or LUT chunk re-runs `decodeStage`
        // on the live scene — the same early-out `upsertPayload`
        // takes, and the only path that doesn't depend on other
        // resources still being pending. No early return: a chunk the
        // stage shares with another claimant must still reach the
        // checks below.
        if environmentPayloadKeys.values.contains(id)
            || lutPayloadKeys.values.contains(id) {
            let ctx = surgicalContext()
            ctx.decodeStage(ctx.stageJSON)
            publish(ctx)
            applyStageExposure(ctx.stageExposure)
            applyStageEffects()
        }
        // W11 claims run surgically first — a skin's IBM chunk or an
        // animation's timeline/keyframes chunk re-decodes just its
        // owner, like the `upsertPayload` path (and keeps live clips
        // alive where a full re-realize would reset them).
        for (skinKey, pid) in skinPayloadKeys where pid == id {
            if let def = skinDefs[skinKey] {
                redecodeSkin(skinKey, def)
            }
        }
        for (animKey, pids) in animPayloadKeys where pids.contains(id) {
            if let def = animDefs[animKey] {
                redecodeAnimation(animKey, def)
            }
        }
        // W25 fix-2: only a chunk a still-deferred texture or
        // geometry awaits earns the manifest re-realize — the
        // deferred set holds resource ids, so map through the claim
        // tables. Never-landing sibling refs (or an env/LUT/skin/anim
        // claim served above) must not re-arm it: a stray re-realize
        // re-decodes the manifest's stale stage and reverts the live
        // stage's LUT/effects state — the silent W25 regression. One
        // armed drain retries every pending ref at once; a decoder
        // still missing its payload re-defers.
        if lastManifest != nil, deferredRefClaims(id) {
            realizePending = true
        }
    }

    /// W25 fix-2: true when [id] is a chunk some still-deferred
    /// texture or geometry awaits — the only pending kinds this path
    /// has no surgical handler for. Env/LUT/skin/anim claims are
    /// consumed above before the check runs, so they never gate the
    /// manifest re-realize.
    private func deferredRefClaims(_ id: UInt64) -> Bool {
        deferredResourceIds.contains {
            texturePayloadKeys[$0] == id
                || (geometryPayloadKeys[$0]?.contains(id) ?? false)
        }
    }

    /// `[u32 count]` × `[8B id][u8 mask][masked t/r/s f32s]`.
    func applySetTransforms(_ data: Data) {
        let base = data.startIndex
        guard data.count >= 4 else { return }
        let count = Int(D3Wire.u32LE(data, base))
        var off = base + 4
        for _ in 0..<count {
            guard off + 9 <= data.endIndex else { return }
            let id = D3Wire.readLocalId(data, off)
            let mask = data[off + 8]
            off += 9
            guard let node = nodesById[id] else {
                // Read past the masked fields anyway so the walk stays aligned.
                off += (mask & 1 != 0 ? 12 : 0) + (mask & 2 != 0 ? 16 : 0)
                    + (mask & 4 != 0 ? 12 : 0)
                continue
            }
            if mask & 1 != 0 {
                node.position = D3Wire.position([
                    Double(D3Wire.f32LE(data, off)),
                    Double(D3Wire.f32LE(data, off + 4)),
                    Double(D3Wire.f32LE(data, off + 8)),
                ])
                off += 12
            }
            if mask & 2 != 0 {
                node.orientation = D3Wire.quaternion([
                    Double(D3Wire.f32LE(data, off)),
                    Double(D3Wire.f32LE(data, off + 4)),
                    Double(D3Wire.f32LE(data, off + 8)),
                    Double(D3Wire.f32LE(data, off + 12)),
                ])
                off += 16
            }
            if mask & 4 != 0 {
                node.scale = D3Wire.scale([
                    Double(D3Wire.f32LE(data, off)),
                    Double(D3Wire.f32LE(data, off + 4)),
                    Double(D3Wire.f32LE(data, off + 8)),
                ])
                off += 12
            }
        }
    }

    /// Structural ops between snapshots (`{"op": …}`). Ops that replace
    /// content carry the new values — the Dart side derives them from
    /// `diffScene` output rather than sending flags.
    func applyCommand(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any] else { return }
        applyCommandJson(json)
    }

    /// The decoded-op dispatch — also the recursion point for the W15
    /// `loadSubtree`/`unloadSubtree` envelopes, whose nested `ops` run
    /// through the same handlers.
    private func applyCommandJson(_ json: [String: Any]) {
        guard let op = json["op"] as? String else { return }
        switch op {
        case "removeNode":
            guard let token = json["node"] as? String,
                  let key = D3Wire.localIdKey(token) else { return }
            guard let node = nodesById[key] else {
                logOnce("removeNode.missing.\(key)",
                    "removeNode on missing node \(key); ignoring")
                return
            }
            removeSubtree(node)
        case "addNode":
            applyAddNode(json)
        case "updateNode":
            applyUpdateNode(json)
        case "applyImpulse":
            guard let node = physicsNode(json),
                  let body = node.physicsBody,
                  let v = vec(json["impulse"]) else { return }
            // SceneKit wakes a resting body on force/impulse apply.
            let impulse = D3Wire.position(v)
            if let at = vec(json["position"]) {
                body.applyForce(
                    impulse, at: D3Wire.position(at), asImpulse: true)
            } else {
                body.applyForce(impulse, asImpulse: true)
            }
        case "applyTorque":
            guard let node = physicsNode(json),
                  let body = node.physicsBody,
                  let t = vec(json["torque"]), t.count == 4 else { return }
            // Axis is a pseudovector: mirrors like a quaternion axis.
            body.applyTorque(
                SCNVector4(Float(-t[0]), Float(-t[1]), Float(t[2]), Float(t[3])),
                asImpulse: true)
        case "setVelocity":
            guard let node = physicsNode(json),
                  let body = node.physicsBody else { return }
            // A velocity write on a resting body can be ignored — a
            // zero impulse wakes it first without changing momentum.
            body.applyForce(SCNVector3Zero, asImpulse: true)
            if let v = vec(json["velocity"]) {
                body.velocity = D3Wire.position(v)
            }
            if let a = vec(json["angularVelocity"]), a.count == 4 {
                body.angularVelocity = SCNVector4(
                    Float(-a[0]), Float(-a[1]), Float(a[2]), Float(a[3]))
            }
        case "clearForces":
            physicsNode(json)?.physicsBody?.clearAllForces()
        case "upsertResource":
            applyUpsertResource(json)
        case "upsertPayload":
            applyUpsertPayload(json)
        case "updateStage":
            applyUpdateStage(json)
        case "query":
            applyQuery(json)
        case "addJoint":
            applyJoint(json, update: false)
        case "updateJoint":
            applyJoint(json, update: true)
        case "removeJoint":
            applyRemoveJoint(json)
        case "anim":
            applyAnim(json)
        case "upsertSkin":
            applyUpsertSkin(json)
        case "upsertAnimation":
            applyUpsertAnimation(json)
        case "removeSkin":
            applyRemoveSkin(json)
        case "removeAnimation":
            applyRemoveAnimation(json)
        case "setMorphWeights":
            applySetMorphWeights(json)
        case "selectVariant":
            applySelectVariant(json)
        case "render":
            applyRenderOp(json)
        case "updateViews":
            applyUpdateViews(json)
        case "loadSubtree":
            applySubtree(json, loading: true)
        case "unloadSubtree":
            applySubtree(json, loading: false)
        default:
            d3Log("unknown command op '\(op)'")
        }
    }

    /// `{"op":"loadSubtree"|"unloadSubtree","node":"<token>",
    /// "ops":[<op>,…]}` — the W15 streaming envelope. `node` must be
    /// live (it is the placeholder); the nested ops apply in order
    /// through the ordinary dispatch inside this one drain, so the
    /// subtree lands or drops atomically between frames. A tag state
    /// that disagrees with the op (load on an untagged node, unload
    /// on a still-tagged one) means the Dart-side bookkeeping
    /// disagrees with the wire — warn and apply anyway, since the
    /// batch is self-describing.
    private func applySubtree(_ json: [String: Any], loading: Bool) {
        let opName = loading ? "loadSubtree" : "unloadSubtree"
        guard let token = json["node"] as? String,
              let key = D3Wire.localIdKey(token),
              let ops = json["ops"] as? [Any] else {
            logOnce("\(opName).malformed",
                "\(opName): missing node/ops")
            return
        }
        // The batch doubles as this subtree's replay record — a
        // payload-arrival re-realize wipes surgical adds along with
        // the manifest's nodes, and the drain-end replay rebuilds
        // each live subtree from its recorded load batch. An unload
        // drops the record first so a wiped placeholder can't
        // resurrect its subtree; a load records only once the
        // placeholder is known live. A re-load replaces the record
        // in place — replay order stays load order, so a subtree
        // another stream's members parent into still replays before
        // its dependents (Android's LinkedHashMap re-put semantics).
        let existing = streamedSubtreeOps.firstIndex { $0.key == key }
        guard nodesById[key] != nil else {
            if let i = existing { streamedSubtreeOps.remove(at: i) }
            logOnce("\(opName).missing.\(key)",
                "\(opName) on missing node \(key); ignoring")
            return
        }
        if loading {
            if let i = existing {
                streamedSubtreeOps[i] = (key: key, ops: ops)
            } else {
                streamedSubtreeOps.append((key: key, ops: ops))
            }
        } else if let i = existing {
            streamedSubtreeOps.remove(at: i)
        }
        // The tag state that disagrees with the op is the mismatch —
        // a load expects the placeholder still tagged (its first
        // nested op clears it); an unload expects it cleared already
        // (the batch re-tags it last).
        if loading, instanceSpecs[key] == nil {
            logOnce("loadSubtree.untagged.\(key)",
                "loadSubtree on node \(key) without an instance tag; "
                + "applying anyway")
        } else if !loading, instanceSpecs[key] != nil {
            logOnce("unloadSubtree.tagged.\(key)",
                "unloadSubtree on node \(key) still tagged; "
                + "applying anyway")
        }
        for case let opJson as [String: Any] in ops {
            applyCommandJson(opJson)
        }
        // The drain applying a subtree runs inside updateAtTime — the
        // frame rendered right after is the first it's visible in;
        // `didRenderScene` stamps it for the latency lane.
        subtreeVisibleStamp = (node: key,
                               applied: ProcessInfo.processInfo.systemUptime,
                               op: opName, count: ops.count)
    }

    /// W15: set by `applySubtree`, consumed by the next
    /// `didRenderScene` — the first frame the landed/cleared subtree
    /// is on screen, logged for the manifest-to-visible latency lane.
    private var subtreeVisibleStamp:
        (node: UInt64, applied: TimeInterval, op: String, count: Int)?

    /// W15: live subtree replay records — (placeholder key, the load
    /// batch's nested ops) in load order. A payload-arrival
    /// re-realize (the deferred-resource retry) rebuilds the
    /// manifest scene wholesale, discarding every surgical add; the
    /// recorded batches replay after `realize` to restore what was
    /// streamed. A `removeNode` that dooms a placeholder drops its
    /// record, and `applyLoadScene` clears the list — a new
    /// document's session keys invalidate the old batches.
    private var streamedSubtreeOps: [(key: UInt64, ops: [Any])] = []

    /// Replays each live subtree's recorded load batch through the
    /// ordinary op dispatch — called right after a payload-arrival
    /// re-realize has rebuilt the manifest scene.
    private func replayStreamedSubtrees() {
        if streamedSubtreeOps.isEmpty { return }
        var dead: Set<UInt64> = []
        for (key, ops) in streamedSubtreeOps {
            // A replayed batch can doom a later record's placeholder
            // (a priorRoots `removeNode` taking a placeholder grafted
            // into the doomed subtree): `removeSubtree` drops the
            // record from the live list but the loop still iterates
            // the COW snapshot, and its addNodes would resolve a dead
            // parent — rooting the resurrected members at scene root.
            guard nodesById[key] != nil else {
                dead.insert(key)
                continue
            }
            for case let opJson as [String: Any] in ops {
                applyCommandJson(opJson)
            }
            if nodesById[key] == nil {
                d3Log("subtree replay: placeholder \(key) missing"
                    + " after re-realize")
            }
        }
        if !dead.isEmpty {
            streamedSubtreeOps.removeAll { dead.contains($0.key) }
        }
    }

    /// Detaches `node`'s whole subtree and drops every doomed id from
    /// the registries — nodes, dynamic bodies, and the consumer maps,
    /// where the subtree's node and geometry instances sit in the
    /// value lists (a stale consumer would rebind a dead object on the
    /// next `upsertResource`). `textureConsumers` needs no per-node
    /// pass: its bindings key off shared material instances, and the
    /// material re-decode path already drops stale entries.
    private func removeSubtree(_ node: SCNNode) {
        var subtree: Set<ObjectIdentifier> = [ObjectIdentifier(node)]
        var subtreeGeos: Set<ObjectIdentifier> = []
        if let geo = node.geometry {
            subtreeGeos.insert(ObjectIdentifier(geo))
        }
        var stack = node.childNodes
        while let n = stack.popLast() {
            subtree.insert(ObjectIdentifier(n))
            if let geo = n.geometry {
                subtreeGeos.insert(ObjectIdentifier(geo))
            }
            stack.append(contentsOf: n.childNodes)
        }
        node.removeFromParentNode()
        retire(node)
        for oid in subtree { nodeToKey.removeValue(forKey: oid) }
        let doomed = nodesById
            .filter { subtree.contains(ObjectIdentifier($0.value)) }
            .map(\.key)
        for k in doomed {
            nodesById.removeValue(forKey: k)
            dynamicBodyKeys.remove(k)
            colliderIndexByKey.removeValue(forKey: k)
            instanceSpecs.removeValue(forKey: k)
            deferredResourceIds.remove(k)
            // W15: a doomed placeholder's replay record dies with it
            // — otherwise the next payload-arrival re-realize would
            // resurrect the streamed subtree.
            streamedSubtreeOps.removeAll { $0.key == k }
            // Node ids can't collide with the resource ids keying the
            // consumer maps — these drops are defensive; the real
            // cleanup is the value-list pass below.
            textureConsumers.removeValue(forKey: k)
            materialConsumers.removeValue(forKey: k)
            geometryConsumers.removeValue(forKey: k)
            // W11: the node's skin binding and pending attach die with
            // it; a captured bind pose would be stale for a recycled id.
            nodeSkinKeys.removeValue(forKey: k)
            pendingSkinNodes.remove(k)
            pendingColliderShapes.removeValue(forKey: k)
            // W16: the trail child drops with the subtree (it rides
            // the doomed node); the lod spec's level copies purge
            // from materialConsumers below.
            if let tr = trailStates.removeValue(forKey: k) {
                if let g = tr.child.geometry { retire(g) }
            }
            pendingLodNodes.remove(k)
        }
        for (lk, spec) in lodSpecs where doomed.contains(lk) {
            for copy in spec.geoCopies {
                for mk in materialConsumers.keys {
                    materialConsumers[mk]?.removeAll { $0 === copy }
                }
            }
            lodSpecs.removeValue(forKey: lk)
        }
        for rk in lodResourceConsumers.keys {
            for k in doomed {
                lodResourceConsumers[rk]?.remove(k)
            }
        }
        animLock.lock()
        for k in doomed { animTargets.removeValue(forKey: k) }
        animLock.unlock()
        // W11: a doomed joint/skeleton sends its consuming skinned
        // nodes back to pending — the skinner keeps the dead node
        // alive upstream-style, but a re-`addNode`ed id rebinds.
        for (nk, sk) in nodeSkinKeys {
            guard !doomed.contains(nk),
                  let skin = skinsById[sk],
                  skin.jointKeys.contains(where: { doomed.contains($0) })
                      || skin.skeletonKey.map({ doomed.contains($0) })
                         ?? false
            else { continue }
            pendingSkinNodes.insert(nk)
        }
        // Joints referencing removed nodes die with them — a live
        // behavior would keep constraining a detached body.
        jointLock.lock()
        let orphaned = joints.keys.filter {
            joints[$0].map {
                doomed.contains($0.a)
                    || ($0.b.map { doomed.contains($0) } ?? false)
            } ?? false
        }
        for id in orphaned { dropJointLocked(id) }
        for key in doomed { componentJointIds.removeValue(forKey: key) }
        jointLock.unlock()
        // Variant components die with the declaring node; bindings
        // TARGETING a removed node un-resolve so a re-added node
        // rebinds on the next apply.
        for key in doomed {
            variantComponents.removeValue(forKey: key)
            disabledComponents.removeValue(forKey: key)
        }
        for (ck, vc) in variantComponents {
            var vc = vc
            var dirty = false
            for i in vc.bindings.indices
            where doomed.contains(vc.bindings[i].nodeKey) {
                vc.bindings[i].resolved = false
                vc.bindings[i].applied = nil
                dirty = true
            }
            if dirty { variantComponents[ck] = vc }
        }
        for gk in geometryConsumers.keys {
            geometryConsumers[gk]?.removeAll {
                subtree.contains(ObjectIdentifier($0))
            }
        }
        for mk in materialConsumers.keys {
            materialConsumers[mk]?.removeAll {
                subtreeGeos.contains(ObjectIdentifier($0))
            }
        }
    }

    /// `{"op":"addNode","node":"<token>","parent":"<token>"|null,
    /// "spec":{…manifest node json…}}` — creates the node, applies
    /// every spec field, attaches under `parent` (absent/null →
    /// scene root). `spec.children` is ignored: each child attaches
    /// itself via its own `addNode`, so ops are order-independent
    /// within a batch. On a live id the op degrades to a full update
    /// so a re-sent batch stays idempotent.
    private func applyAddNode(_ json: [String: Any]) {
        guard let token = json["node"] as? String,
              let key = D3Wire.localIdKey(token),
              let spec = json["spec"] as? [String: Any] else {
            logOnce("addNode.malformed", "addNode: missing node/spec")
            return
        }
        if let existing = nodesById[key] {
            d3Log("addNode on live id; treating as update")
            applyNodeUpdate(key: key, node: existing, spec: spec,
                            parent: json["parent"],
                            flags: Self.nodeUpdateFlags)
            return
        }
        let ctx = surgicalContext()
        let node = SCNNode()
        ctx.decodeNodeFields(key: key, node: node, spec: spec)
        ctx.nodes[key] = node
        ctx.decodePhysicsDeferred()
        ctx.applyVariantComponents()
        attachNode(node, under: json["parent"])
        nodesById[key] = node
        nodeToKey[ObjectIdentifier(node)] = key
        // W11: the landing node may be the joint or skeleton a pending
        // skinned node waits on — retry every pending attach.
        retryPendingSkins(ctx)
        publish(ctx)
        promoteCamera(ctx)
        retryPendingJoints()
    }

    /// `{"op":"updateNode","node":"<token>","flags":[…],"spec":{…},
    /// "parent":"<token>"?}` — applies only the flagged fields of
    /// `spec`. A missing node warns and no-ops so a stale or re-sent
    /// batch survives.
    private func applyUpdateNode(_ json: [String: Any]) {
        guard let token = json["node"] as? String,
              let key = D3Wire.localIdKey(token),
              let spec = json["spec"] as? [String: Any] else {
            logOnce("updateNode.malformed", "updateNode: missing node/spec")
            return
        }
        guard let node = nodesById[key] else {
            logOnce("updateNode.missing.\(key)",
                "updateNode on missing node \(key); ignoring")
            return
        }
        let flags = Set(json["flags"] as? [String] ?? [])
        applyNodeUpdate(key: key, node: node, spec: spec,
                        parent: json["parent"], flags: flags)
    }

    /// Upstream `NodeChange` field names — also the "all flags" set an
    /// `addNode` on a live id degrades to.
    private static let nodeUpdateFlags: Set<String> =
        ["transform", "name", "layers", "visible",
         "reparented", "components", "skin"]

    /// Applies `flags`-selected fields of `spec` onto a live node.
    /// `reparented` reads the command's `parent` (null → root);
    /// `components` clears the realized component state (geometry,
    /// material refs, light, camera, physics body) then re-decodes
    /// `spec.components` — a rebuilt rigid body is a replace,
    /// matching upstream's component re-realize.
    private func applyNodeUpdate(key: UInt64, node: SCNNode,
                                 spec: [String: Any], parent: Any?,
                                 flags: Set<String>) {
        let ctx = surgicalContext()
        if flags.contains("transform") {
            ctx.decodeTransform(node, spec["transform"])
        }
        if flags.contains("name") {
            node.name = spec["name"] as? String
        }
        // `layers`/`visible` are only encoded off-default upstream —
        // flagged-but-absent means the default (mask 1, visible).
        if flags.contains("layers") {
            node.categoryBitMask = (spec["layers"] as? Int) ?? 1
        }
        if flags.contains("visible") {
            node.isHidden = (spec["visible"] as? Bool) == false
        }
        if flags.contains("reparented") {
            attachNode(node, under: parent)
        }
        // `skin` is a node member, not a component — update the
        // binding BEFORE a components re-decode so `decodeMesh`'s
        // attachSkin sees the new value. Absent `skin` in the spec
        // means the member cleared.
        if flags.contains("skin") {
            if let token = spec["skin"] as? String,
               let skinKey = D3Wire.localIdKey(token) {
                ctx.nodeSkinKeys[key] = skinKey
            } else {
                ctx.nodeSkinKeys.removeValue(forKey: key)
            }
            ctx.attachSkin(key, node)
        }
        if flags.contains("components") {
            clearComponentState(key: key, node: node, ctx: ctx)
            // The re-encoded spec carries the current `skin` member —
            // refresh the binding so the rebuilt mesh's attachSkin
            // reads it even when the diff didn't flag `skin`.
            if let token = spec["skin"] as? String,
               let skinKey = D3Wire.localIdKey(token) {
                ctx.nodeSkinKeys[key] = skinKey
            } else {
                ctx.nodeSkinKeys.removeValue(forKey: key)
            }
            let comps = spec["components"] as? [Any] ?? []
            ctx.colliderIndexByKey[key] = comps.firstIndex {
                ($0 as? [String: Any])?["type"] as? String == "collider"
            }
            for (i, c) in comps.enumerated() {
                ctx.decodeComponent(key: key, node: node, index: i, spec: c)
            }
            ctx.nodes[key] = node
            ctx.decodePhysicsDeferred()
            ctx.applyVariantComponents()
        }
        for f in flags.subtracting(Self.nodeUpdateFlags) {
            logOnce("updateNode.flag.\(f)",
                "updateNode flag '\(f)' not implemented")
        }
        // W15: `instance` in the spec is the placeholder tag's
        // post-update state — a dict sets it (an unload's restore),
        // explicit null clears it (the load's instance update), and
        // an absent key preserves it: a reparent-only update carries
        // no spec fields and must not strip the tag.
        if spec.keys.contains("instance") {
            if let inst = spec["instance"] as? [String: Any] {
                ctx.instanceSpecs[key] = inst
            } else {
                ctx.instanceSpecs.removeValue(forKey: key)
            }
        }
        publish(ctx)
        promoteCamera(ctx)
        if pointOfView === node, node.camera == nil {
            restoreFallbackCamera()
        }
        retryPendingJoints()
    }

    /// Drops `node`'s realized component state ahead of a components
    /// re-decode and unregisters it from the consumer maps — geometry
    /// (plus the material lists that held its copy), light, camera,
    /// physics body.
    private func clearComponentState(
        key: UInt64, node: SCNNode, ctx: FsceneRealizer.Context
    ) {
        let old = node.geometry
        // Detached objects go to the graveyard — a behavior still
        // attached to the world can reference the body, and the
        // in-flight pass's frozen storage can reference the rest.
        if let body = node.physicsBody { retire(body) }
        if let sk = node.skinner { retire(sk) }
        if let mo = node.morpher { retire(mo) }
        if let cam = node.camera { retire(cam) }
        if let lt = node.light { retire(lt) }
        if let geo = old { retire(geo) }
        node.geometry = nil
        node.light = nil
        node.camera = nil
        node.physicsBody = nil
        // W18: particle systems ride on the node — retire each before
        // detaching so an in-flight pass still holding one renders
        // safely, then drop the whole set (a components re-decode
        // re-adds whatever the new spec carries).
        for ps in node.particleSystems ?? [] {
            retire(ps)
        }
        node.removeAllParticleSystems()
        // W11: the skinner/morpher ride on the geometry — drop them
        // with it; `decodeMesh` re-attaches on the rebuild.
        node.skinner = nil
        node.morpher = nil
        ctx.dynamicBodyKeys.remove(key)
        // A joint holding the dropped body re-defers — the post-decode
        // retry rebinds it to the rebuilt body. Component-declared
        // joints drop outright: the re-decode re-registers the ones
        // still present (a removed joint component dies with its
        // record, upstream's unmount).
        jointLock.lock()
        let rebind = joints.keys.filter {
            joints[$0].map { $0.behavior != nil && ($0.a == key || $0.b == key) }
                ?? false
        }
        for id in rebind {
            if let b = joints[id]?.behavior {
                scene?.physicsWorld.removeBehavior(b)
                retire(b)
            }
            joints[id]?.behavior = nil
        }
        if let owned = componentJointIds.removeValue(forKey: key) {
            for (_, handle) in owned { dropJointLocked(handle) }
        }
        jointLock.unlock()
        ctx.variantComponents.removeValue(forKey: key)
        ctx.disabledComponents.removeValue(forKey: key)
        // W16: the `d3trail:` child dies like a `d3prim:` — its
        // geometry retires and the state drops (the path is runtime
        // state; a re-decode starts empty, matching upstream).
        if let tr = ctx.trails.removeValue(forKey: key) {
            if let g = tr.child.geometry { retire(g) }
            tr.child.removeFromParentNode()
            retire(tr.child)
        }
        // W16: the lod spec and its pending mark drop; the level
        // geometry copies' material-consumer entries purge below
        // (the bound copy rides `old`'s sweep — it IS node.geometry;
        // the unbound ones are not).
        if let spec = ctx.lods.removeValue(forKey: key) {
            for copy in spec.geoCopies where copy !== old {
                for mk in ctx.materialConsumers.keys {
                    ctx.materialConsumers[mk]?.removeAll { $0 === copy }
                }
            }
        }
        ctx.pendingLodNodes.remove(key)
        for rk in ctx.lodResourceConsumers.keys {
            ctx.lodResourceConsumers[rk]?.remove(key)
        }
        if let old {
            for mk in ctx.materialConsumers.keys {
                ctx.materialConsumers[mk]?.removeAll { $0 === old }
            }
        }
        // Multi-primitive meshes park extra primitives on anonymous
        // `d3prim:` children — they die with the node, so their
        // consumer entries and geometry refs purge here too.
        let primChildren = node.childNodes.filter {
            $0.name?.hasPrefix("d3prim:") == true
        }
        for child in primChildren {
            if let g = child.geometry {
                for mk in ctx.materialConsumers.keys {
                    ctx.materialConsumers[mk]?.removeAll { $0 === g }
                }
            }
            for gk in ctx.geometryConsumers.keys {
                ctx.geometryConsumers[gk]?.removeAll { $0 === child }
            }
        }
        for gk in ctx.geometryConsumers.keys {
            ctx.geometryConsumers[gk]?.removeAll { $0 === node }
        }
    }

    /// Attaches `node` under the command's `parent` value — absent,
    /// null, or unresolvable all mean scene root. A parent inside the
    /// node's own subtree would cycle the graph; the diff should never
    /// emit that, but lane 10 requires surviving it — warn and root.
    private func attachNode(_ node: SCNNode, under parent: Any?) {
        var p = scene?.rootNode
        if let token = parent as? String {
            if let key = D3Wire.localIdKey(token), let found = nodesById[key] {
                p = found
            } else {
                logOnce("attach.parent.\(token)",
                    "node attach: parent '\(token)' unresolved; rooting")
            }
        }
        var ancestor = p
        while let a = ancestor {
            if a === node {
                d3Log("node attach: parent is inside the node's own "
                    + "subtree; rooting")
                p = scene?.rootNode
                break
            }
            ancestor = a.parent
        }
        node.removeFromParentNode()
        p?.addChildNode(node)
    }

    /// Writes back the registries a node op can mutate — the same
    /// write-back `redecodeResource` does per kind.
    private func publish(_ ctx: FsceneRealizer.Context) {
        materialConsumers = ctx.materialConsumers
        geometryConsumers = ctx.geometryConsumers
        dynamicBodyKeys = ctx.dynamicBodyKeys
        colliderIndexByKey = ctx.colliderIndexByKey
        instanceSpecs = ctx.instanceSpecs
        deferredResourceIds = ctx.deferredResourceIds
        environmentPayloadKeys = ctx.environmentPayloadKeys
        lutPayloadKeys = ctx.lutPayloadKeys
        resourceDefs = ctx.resourceDefs
        lastStage = ctx.stageJSON
        // W14: rt registry + view list + stage quality fields — a
        // `renderTexture` upsert rebuilds a rec, `updateViews`/
        // `updateStage` rewrite theirs; other ops publish the seeded
        // copies back unchanged.
        renderTargets = ctx.renderTargets
        views = ctx.views
        stageAntiAliasing = ctx.stageAntiAliasing
        stageRenderScale = ctx.stageRenderScale
        stageFilterQuality = ctx.stageFilterQuality
        // W13 retention: nil (absent key) keeps the prior effects.
        if let fx = ctx.stageEffects { lastEffects = fx }
        // W11 stores — skin/animation decode and attach mutate these.
        skinsById = ctx.skins
        animationsById = ctx.animations
        morphTargetsById = ctx.morphTargets
        nodeSkinKeys = ctx.nodeSkinKeys
        pendingSkinNodes = ctx.pendingSkinNodes
        skinPayloadKeys = ctx.skinPayloadKeys
        animPayloadKeys = ctx.animPayloadKeys
        skinDefs = ctx.skinDefs
        animDefs = ctx.animDefs
        geometryPayloadKeys = ctx.geometryPayloadKeys
        geometriesById = ctx.geometries
        materialsById = ctx.materials
        texturesById = ctx.textures
        textureConsumers = ctx.textureConsumers
        texturePayloadKeys = ctx.texturePayloadKeys
        variantComponents = ctx.variantComponents
        disabledComponents = ctx.disabledComponents
        // W16: trail/lod state mutate through surgical decodes too —
        // a components re-decode rebuilds both registries wholesale.
        trailStates = ctx.trails
        lodSpecs = ctx.lods
        lodResourceConsumers = ctx.lodResourceConsumers
        pendingLodNodes = ctx.pendingLodNodes
    }

    /// A node op that decoded a camera takes the point of view only
    /// when the scene still runs on the install-time fallback — a doc
    /// camera is never displaced by a diff-added one, and a declared
    /// screen view (W14) is never displaced either.
    private func promoteCamera(_ ctx: FsceneRealizer.Context) {
        guard screenViews.isEmpty else { return }
        guard let cam = ctx.firstCameraNode, let fb = fallbackCameraNode
        else { return }
        pointOfView = cam
        docPov = cam
        fb.removeFromParentNode()
        retire(fb)
        fallbackCameraNode = nil
        applyStageExposure(stageExposure)
        applyStageEffects()
    }

    /// Re-installs the default camera — the node's camera component
    /// was just dropped while it held the point of view. Gated on no
    /// declared screen view (W14): the view's camera pick owns the
    /// point of view.
    private func restoreFallbackCamera() {
        guard screenViews.isEmpty else { return }
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.position = SCNVector3(0, 0, 5)
        scene?.rootNode.addChildNode(cam)
        pointOfView = cam
        fallbackCameraNode = cam
        docPov = cam
        applyStageExposure(stageExposure)
        applyStageEffects()
    }

    /// W24 fix-round: an emptied screen-view set hands the host's
    /// pass back to the document pick — leaving `pointOfView` on
    /// `blankPov` (category mask 0) or a retired view camera drew the
    /// mask-0 clear pass every vsync. Reuses the fallback path's own
    /// picks: `docPov` while it's still a live scene camera, else
    /// `restoreFallbackCamera` installs the default — a removed or
    /// camera-less pick gets the same default the camera-drop path
    /// installs.
    private func restoreDocumentPov() {
        // `removeSubtree` only detaches the root — interior nodes keep
        // `parent` set, so scene membership needs the full climb.
        var top = docPov
        while let parent = top?.parent { top = parent }
        if let scene, let pov = docPov, pov.camera != nil,
            top === scene.rootNode
        {
            pointOfView = pov
            applyStageExposure(stageExposure)
            applyStageEffects()
            return
        }
        // The pick is gone or camera-less — the same default the
        // camera-drop path installs (it applies the stage itself).
        restoreFallbackCamera()
    }

    /// `{"op":"upsertResource","id":"<token>","resource":{…}}` — a
    /// single-resource decode against the retained registries, then
    /// every recorded consumer rebinds. `texture`/`material` are the
    /// W4 kinds, `geometry` the W5 kind; anything else logs once.
    private func applyUpsertResource(_ json: [String: Any]) {
        guard let token = json["id"] as? String,
              let key = D3Wire.localIdKey(token),
              let resource = json["resource"] as? [String: Any],
              let kind = resource["kind"] as? String else {
            logOnce("upsertResource.malformed",
                "upsertResource: missing id/resource/kind")
            return
        }
        switch kind {
        case "texture", "material", "geometry", "renderTexture":
            redecodeResource(key, resource)
        case "environment":
            redecodeEnvironment(key, resource)
        default:
            logOnce("upsertResource.\(kind)",
                "upsertResource kind '\(kind)' not implemented")
        }
    }

    /// `{"op":"updateStage","stage":{…}}` — re-runs `decodeStage`
    /// against the live context (W7). The diff ships the referenced
    /// env resource's `upsertResource` first, so `environmentRef`
    /// resolves here; a payload-backed env still in flight defers and
    /// re-runs when the chunk lands.
    private func applyUpdateStage(_ json: [String: Any]) {
        guard let stage = json["stage"] as? [String: Any] else {
            logOnce("updateStage.malformed",
                "updateStage: missing stage")
            return
        }
        let ctx = surgicalContext()
        ctx.decodeStage(stage)
        publish(ctx)
        applyStageQuality()
        applyStageExposure(ctx.stageExposure)
        applyStageEffects()
    }

    /// An environment resource holds no realized object of its own —
    /// the stage consumes it — so an env upsert stores the def and,
    /// when the current stage names it, re-runs `decodeStage` on the
    /// live scene (the diff's `updateStage` op does the same; running
    /// here too keeps a lone env upsert meaningful).
    private func redecodeEnvironment(_ key: UInt64,
                                     _ r: [String: Any]) {
        let ctx = surgicalContext()
        ctx.resourceDefs[key] = r
        ctx.environments[key] = r
        let stageRef = (ctx.stageJSON?["environmentRef"] as? String)
            .flatMap(D3Wire.localIdKey)
        if stageRef == key {
            ctx.decodeStage(ctx.stageJSON)
        }
        publish(ctx)
        // W13: the applies run after publish so `applyStageExposure`'s
        // brightness compose and `applyStageEffects` both read the
        // freshly decoded `lastEffects`, not the retained prior value.
        if stageRef == key {
            applyStageQuality()
            applyStageExposure(ctx.stageExposure)
            applyStageEffects()
        }
    }

    /// `{"op":"upsertPayload","id":"<token>","bytes":<base64|[ints]>}` —
    /// stores the chunk like a `payload` mutation, then re-decodes and
    /// rebinds every resource the payload backs: textures (W4 image
    /// path), geometries (W5 vertex/index chunks), and the environment
    /// (W7 — an env equirect chunk re-runs `decodeStage`, which is why
    /// that claim is checked first: env payloads also carry
    /// `encoding:'image'`). A payload claimed by none falls back to the
    /// W3 deferred re-realize while resources still await payloads,
    /// else logs once.
    private func applyUpsertPayload(_ json: [String: Any]) {
        guard let token = json["id"] as? String,
              let key = D3Wire.localIdKey(token) else { return }
        guard let bytes = commandBytes(json["bytes"]) else {
            logOnce("upsertPayload.\(key).bytes",
                "upsertPayload \(key): undecodable bytes")
            return
        }
        // A runtime-minted chunk carries its spec on the op — the
        // manifest's `payloads` block only describes install-time
        // chunks, so without this its consumers never decode.
        if let encoding = json["encoding"] as? String {
            let spec: FsceneRealizer.Context.PayloadSpec = (
                encoding, json["layout"] as? String,
                json["format"] as? String,
                (json["width"] as? NSNumber)?.intValue,
                (json["height"] as? NSNumber)?.intValue,
                (json["length"] as? NSNumber)?.intValue)
            payloadSpecs[key] = spec
            opPayloadSpecs[key] = spec
        }
        payloadStore[key] = bytes
        // W25: a rewritten LUT chunk invalidates its cached strips
        // before the claim check below re-applies the stage.
        invalidateLuts(backedBy: key)
        if environmentPayloadKeys.values.contains(key)
            || lutPayloadKeys.values.contains(key) {
            // W7/W25: an environment equirect or LUT chunk — re-run
            // `decodeStage` on the live scene (its payload deferral
            // unblocks here).
            let ctx = surgicalContext()
            ctx.decodeStage(ctx.stageJSON)
            publish(ctx)
            applyStageExposure(ctx.stageExposure)
            applyStageEffects()
        // A texture claims this payload → image path, even when the
        // payload spec is absent or carries an unexpected encoding.
        } else if payloadSpecs[key]?.encoding == "image"
            || texturePayloadKeys.values.contains(key) {
            var rebound = false
            for (texKey, pid) in texturePayloadKeys where pid == key {
                guard let def = resourceDefs[texKey] else { continue }
                redecodeResource(texKey, def)
                rebound = true
            }
            if !rebound {
                logOnce("upsertPayload.\(key).unclaimed",
                    "upsertPayload \(key): image payload backs no "
                    + "known texture")
            }
        } else if geometryPayloadKeys.values
            .contains(where: { $0.contains(key) }) {
            // A vertex/index chunk — re-decode each claiming geometry;
            // the rebind swaps the rebuilt SCNGeometry onto consumers.
            var rebound = false
            for (geoKey, pids) in geometryPayloadKeys
            where pids.contains(key) {
                guard let def = resourceDefs[geoKey] else { continue }
                redecodeResource(geoKey, def)
                rebound = true
            }
            if !rebound {
                logOnce("upsertPayload.\(key).unclaimed",
                    "upsertPayload \(key): payload backs no "
                    + "known geometry")
            }
        } else if skinPayloadKeys.values.contains(key)
            || animPayloadKeys.values
                .contains(where: { $0.contains(key) }) {
            // W11: an inverseBindMatrices chunk re-decodes its skin and
            // rebinds consumers; a timeline/keyframes chunk re-decodes
            // its animation under any live clip.
            for (skinKey, pid) in skinPayloadKeys where pid == key {
                if let def = skinDefs[skinKey] {
                    redecodeSkin(skinKey, def)
                }
            }
            for (animKey, pids) in animPayloadKeys
            where pids.contains(key) {
                if let def = animDefs[animKey] {
                    redecodeAnimation(animKey, def)
                }
            }
        } else {
            // W25 fix-2: every claim map was checked surgically above
            // — reaching here means no installed or deferred resource
            // awaits this chunk, so a manifest re-realize would gain
            // nothing (and a stray one reverts the live stage; see
            // applyPayload's deferred-claim gate).
            logOnce("upsertPayload.\(key)",
                "upsertPayload \(key): encoding "
                + "'\(payloadSpecs[key]?.encoding ?? "?")' backs no "
                + "known texture or geometry")
        }
    }

    /// Seeds a decode context with the retained state — the shared
    /// start of every surgical op. Dictionaries are value types:
    /// seeding shares storage until the decode mutates its own copy,
    /// which the caller writes back. `scene` is the live one so a
    /// `physicsWorld` component lands on the real graph.
    private func surgicalContext() -> FsceneRealizer.Context {
        let ctx = FsceneRealizer.Context(
            host: self, formatVersion: lastFormatVersion,
            scene: scene ?? SCNScene())
        ctx.payloadSpecs = payloadSpecs
        ctx.resourceDefs = resourceDefs
        ctx.instanceSpecs = instanceSpecs
        ctx.textures = texturesById
        ctx.materials = materialsById
        ctx.geometries = geometriesById
        ctx.textureConsumers = textureConsumers
        ctx.materialConsumers = materialConsumers
        ctx.geometryConsumers = geometryConsumers
        ctx.texturePayloadKeys = texturePayloadKeys
        ctx.geometryPayloadKeys = geometryPayloadKeys
        ctx.environmentPayloadKeys = environmentPayloadKeys
        ctx.lutPayloadKeys = lutPayloadKeys
        // Environment resources are raw defs — the environments map a
        // manifest decode fills is rebuilt from them here.
        ctx.environments = resourceDefs.compactMapValues {
            $0["kind"] as? String == "environment" ? $0 : nil
        }
        ctx.stageJSON = lastStage
        ctx.stageExposure = stageExposure
        ctx.deferredResourceIds = deferredResourceIds
        ctx.dynamicBodyKeys = dynamicBodyKeys
        ctx.colliderIndexByKey = colliderIndexByKey
        // W11 stores — a skin/animation re-decode or a node attach
        // mutates these; `publish` writes them back.
        ctx.skins = skinsById
        ctx.animations = animationsById
        ctx.morphTargets = morphTargetsById
        ctx.nodeSkinKeys = nodeSkinKeys
        ctx.pendingSkinNodes = pendingSkinNodes
        ctx.skinPayloadKeys = skinPayloadKeys
        ctx.animPayloadKeys = animPayloadKeys
        ctx.skinDefs = skinDefs
        ctx.animDefs = animDefs
        // W12: variant specs + disabled-component marks mutate through
        // the surgical decode (components re-decode, selectVariant) —
        // publish writes them back.
        ctx.variantComponents = variantComponents
        ctx.disabledComponents = disabledComponents
        // W16 stores — a components re-decode rebuilds the trail/lod
        // registries; publish writes them back.
        ctx.trails = trailStates
        ctx.lods = lodSpecs
        ctx.lodResourceConsumers = lodResourceConsumers
        ctx.pendingLodNodes = pendingLodNodes
        // W14 stores — an rt upsert mutates `renderTargets`, an
        // `updateViews` op wholesale-replaces `views`; the quality
        // fields ride along so publish's write-back is a no-op for
        // ops that never re-decode the stage.
        ctx.renderTargets = renderTargets
        ctx.views = views
        ctx.stageAntiAliasing = stageAntiAliasing
        ctx.stageRenderScale = stageRenderScale
        ctx.stageFilterQuality = stageFilterQuality
        ctx.resolvesLiveNodes = true
        return ctx
    }

    /// Re-decodes ONE resource into the retained registries and rebinds
    /// its consumers — the surgical alternative to a payload-arrival
    /// re-realize, which would respawn physics bodies mid-scene. A
    /// texture rebinds every recorded (material, slot) — redoing the
    /// factor×texture bake; a material re-attaches to every geometry
    /// that referenced it; a geometry rebuilds and swaps onto every
    /// consuming node, carrying its per-node materials over.
    /// W16: resource `key` just (re)decoded — re-resolve every `lod`
    /// spec that consumes it. `rebindLod` rebuilds the whole level
    /// copy set, so a geometry or material landing on ANY level
    /// rewrites it and re-applies the bound level onto the fresh
    /// copies; publishing happens in the caller's own write-back.
    private func rebindLodConsumers(
        _ key: UInt64, _ ctx: FsceneRealizer.Context
    ) {
        for nk in ctx.lodResourceConsumers[key] ?? [] {
            guard let node = nodesById[nk] else { continue }
            ctx.rebindLod(nk, node)
        }
        pendingLodNodes = ctx.pendingLodNodes
        lodSpecs = ctx.lods
        materialConsumers = ctx.materialConsumers
    }

    private func redecodeResource(_ key: UInt64, _ r: [String: Any]) {
        let ctx = surgicalContext()
        ctx.resourceDefs[key] = r
        // W14: a non-renderTexture upsert landing on an rt id replaces
        // the resource wholesale — tear the rt down so material slots
        // stop binding its (about-to-be-dead) pixels. View entries
        // targeting it go inert until the next updateViews re-decode.
        if r["kind"] as? String != "renderTexture",
           let old = ctx.renderTargets.removeValue(forKey: key) {
            retire(old.colorTex)
            retire(old.depthTex)
            for v in old.views { retireViewRuntime(v) }
            renderTargets = ctx.renderTargets
            updateContinuousRendering()
        }
        switch r["kind"] as? String {
        case "texture":
            // Drop the stale decode first: a deferred or malformed
            // upsert rebinds consumers to the factor-only fallback.
            ctx.textures.removeValue(forKey: key)
            ctx.decodeTexture(key, r)
            if ctx.textures[key] != nil {
                ctx.deferredResourceIds.remove(key)
            }
            texturesById = ctx.textures
            texturePayloadKeys = ctx.texturePayloadKeys
            deferredResourceIds = ctx.deferredResourceIds
            resourceDefs = ctx.resourceDefs
            // SCNMaterial is a reference type — rebinding through the
            // seeded map mutates the live instance. The consumer map
            // itself is a value type: applyTextureSlot can register a
            // NEW binding on ctx's copy, so it must publish back.
            for binding in textureConsumers[key] ?? [] {
                ctx.applyTextureSlot(binding.material,
                                     materialKey: binding.materialKey,
                                     slot: binding.slot)
            }
            textureConsumers = ctx.textureConsumers
        case "material":
            let old = ctx.materials[key]
            // Stale bindings for this material go first — the re-decode
            // registers the new instance's slots fresh.
            for texKey in Array(ctx.textureConsumers.keys) {
                ctx.textureConsumers[texKey]?.removeAll {
                    $0.materialKey == key
                }
            }
            ctx.decodeMaterial(key, r)
            materialsById = ctx.materials
            textureConsumers = ctx.textureConsumers
            resourceDefs = ctx.resourceDefs
            if let old, let new = materialsById[key] {
                for geo in materialConsumers[key] ?? [] {
                    geo.materials = geo.materials.map {
                        $0 === old ? new : $0
                    }
                }
            }
            // A variant/default material refresh re-applies selections
            // onto the new instance (the rebase rule keeps a foreign
            // rebind as the default).
            ctx.applyVariantComponents()
            variantComponents = ctx.variantComponents
            // W16: a material an `lod` level references — re-resolve
            // each consuming spec against the fresh instance.
            rebindLodConsumers(key, ctx)
        case "geometry":
            // Same surgical contract as texture: drop the stale decode
            // first — a deferred or malformed upsert rebinds consumers
            // to nothing (a mesh has no factor-only fallback).
            ctx.geometries.removeValue(forKey: key)
            ctx.decodeGeometry(key, r)
            if ctx.geometries[key] != nil {
                ctx.deferredResourceIds.remove(key)
            }
            geometriesById = ctx.geometries
            geometryPayloadKeys = ctx.geometryPayloadKeys
            deferredResourceIds = ctx.deferredResourceIds
            resourceDefs = ctx.resourceDefs
            morphTargetsById = ctx.morphTargets
            for node in geometryConsumers[key] ?? [] {
                // W16: an `lod` owning the node's draw slot isn't a
                // mesh-geometry rebind target — the level copies
                // refresh through `rebindLodConsumers` below
                // (Android's rebuildRenderable skips an lod-owned
                // renderable).
                if let nk = nodeToKey[ObjectIdentifier(node)],
                   let spec = ctx.lods[nk],
                   spec.ownsRenderable, !spec.suspended {
                    continue
                }
                let old = node.geometry
                let rebound = ctx.geometries[key]
                    .flatMap { ($0.copy() as? SCNGeometry) ?? $0 }
                if let old {
                    // Per-node material refs live on the old copy —
                    // carry them over and repoint the material→geometry
                    // consumer lists at the new instance.
                    if let rebound { rebound.materials = old.materials }
                    for mk in ctx.materialConsumers.keys {
                        ctx.materialConsumers[mk] =
                            ctx.materialConsumers[mk]?
                                .compactMap { $0 === old ? rebound : $0 }
                            ?? []
                    }
                }
                node.geometry = rebound
                // W11: the rebuilt geometry may carry morph targets,
                // and a skinned node's skinner holds the old base
                // geometry — re-attach both on the new copy.
                if let morph = ctx.morphTargets[key] {
                    ctx.attachMorph(node, morph)
                } else {
                    node.morpher = nil
                }
                if let nk = nodeToKey[ObjectIdentifier(node)] {
                    ctx.attachSkin(nk, node)
                }
            }
            materialConsumers = ctx.materialConsumers
            pendingSkinNodes = ctx.pendingSkinNodes
            // A geometry that just landed (or a rebound copy) re-runs
            // pending variant bindings against the fresh instance.
            ctx.applyVariantComponents()
            variantComponents = ctx.variantComponents
            // W16: an `lod` level geometry — re-resolve each
            // consuming spec (a pending spec builds its whole level
            // set; a live one rebuilds on the fresh resource).
            rebindLodConsumers(key, ctx)
        case "renderTexture":
            // W14: the old pixels die — a consumer may still be
            // sampling the colorTex in the in-flight pass, so retire,
            // don't drop. Views survive the rebuild: they target the
            // id, not the textures.
            let old = ctx.renderTargets[key]
            if let old {
                retire(old.colorTex)
                retire(old.depthTex)
                for v in old.views { retireViewRuntime(v) }
            }
            ctx.renderTargets.removeValue(forKey: key)
            ctx.decodeRenderTexture(key, r)
            if var rec = ctx.renderTargets[key] {
                // View declarations survive; their runtime objects were
                // just retired — clear them so the next pass lazily
                // rebuilds against the new textures (also re-fits the
                // MSAA pair if the rt resized).
                rec.views = (old?.views ?? []).map { v in
                    var v = v
                    v.renderer = nil
                    v.msaaColorTex = nil
                    v.msaaDepthTex = nil
                    v.msaaSamples = 1
                    return v
                }
                rec.dirty = true   // fresh pixels need one pass
                ctx.renderTargets[key] = rec
            }
            renderTargets = ctx.renderTargets
            resourceDefs = ctx.resourceDefs
            for binding in textureConsumers[key] ?? [] {
                ctx.applyTextureSlot(binding.material,
                                     materialKey: binding.materialKey,
                                     slot: binding.slot)
            }
            textureConsumers = ctx.textureConsumers
            updateContinuousRendering()
        default:
            break
        }
    }

    /// `{"op":"render","target":"rt:<tok>"}` — marks that rt dirty for
    /// one pass; the scheduler clears the flag after drawing.
    private func applyRenderOp(_ json: [String: Any]) {
        guard let token = json["target"] as? String,
              let key = D3Wire.localIdKey(token),
              renderTargets[key] != nil else {
            logOnce("render.missing",
                "render op on unknown render target; ignoring")
            return
        }
        renderTargets[key]?.dirty = true
        // A manual-only registry leaves rendersContinuously off —
        // the dirty flag isn't scene state, so poke the view or the
        // scheduler never gets a frame to run the pass in.
        setNeedsDisplay()
    }

    /// `{"op":"updateViews","views":[<entries>]}` — wholesale replace
    /// of the view list: re-decode against the live registries, then
    /// re-distribute onto the rt records and re-pick the screen view.
    /// An absent or non-array `views` member warns and no-ops — the
    /// same `updateViews.malformed` shape Android logs (silently
    /// clearing a live list on a decode hiccup hid real bugs).
    private func applyUpdateViews(_ json: [String: Any]) {
        guard json["views"] is [Any] else {
            logOnce("updateViews.malformed",
                "updateViews: missing views array")
            return
        }
        let ctx = surgicalContext()
        ctx.decodeViews(json["views"])
        publish(ctx)
        installViews()
        applyScreenViewCamera()
        applyStageQuality()
        applyStageExposure(stageExposure)
        applyStageEffects()
    }

    /// W14: distributes the decoded view list — texture-target views
    /// attach (order-sorted) to their rt record, the target-absent
    /// subset becomes `screenViews`. Renderers on replaced views
    /// retire; install and `updateViews` share this path.
    func installViews() {
        for key in renderTargets.keys {
            for v in renderTargets[key]?.views ?? [] {
                retireViewRuntime(v)
            }
            renderTargets[key]?.views = []
        }
        screenViews = []
        for v in views {
            if let t = v.targetKey {
                // decodeViews already skipped views whose target isn't
                // a live rt — an absent rec here is a no-op.
                renderTargets[t]?.views.append(v)
            } else {
                screenViews.append(v)
            }
        }
        for key in renderTargets.keys {
            renderTargets[key]?.views.sort { $0.order < $1.order }
        }
        screenViews.sort { $0.order < $1.order }
        // W24: ≥2 screen views (or any viewport rect) switch the host
        // into sibling mode — every screen view gets its own SCNView
        // laid out over the host's clear pass.
        updateScreenSubviews()
        updateContinuousRendering()
    }

    /// The lowest-order screen view's camera takes `pointOfView` —
    /// over the doc camera and the install-time fallback (which is
    /// removed like a promoted camera does). While `screenViews` is
    /// non-empty, `promoteCamera`/`restoreFallbackCamera` stand down.
    /// W24: in split mode the host's point-of-view is the blank
    /// camera instead — its pass contributes clear/background under
    /// the sibling views, which carry every declared screen view.
    /// An empty resolved set hands `pointOfView` back to the document
    /// pick (`restoreDocumentPov`) — the split-mode blank pass must
    /// not outlive the views that justified it.
    func applyScreenViewCamera() {
        guard let v = screenViews.first else {
            restoreDocumentPov()
            return
        }
        if multiScreenMode {
            // Split: the host's pass is clear/background under the
            // siblings — the blank pov is set whether or not the
            // lowest-order camera resolves (its sibling draws
            // through a proxy until it does).
            if blankPov == nil {
                let node = SCNNode()
                let blank = SCNCamera()
                blank.categoryBitMask = 0
                node.camera = blank
                blankPov = node
            }
            pointOfView = blankPov
        }
        guard let camNode = nodesById[v.cameraKey],
              let cam = camNode.camera else {
            logOnce("w14.screenCam.\(v.cameraKey)",
                "screen view camera node \(v.cameraKey) unresolved or "
                + "camera-less; pointOfView unchanged")
            return
        }
        cam.categoryBitMask = v.layerMask == UInt32.max
            ? Int(bitPattern: UInt.max) : Int(v.layerMask)
        if let fb = fallbackCameraNode {
            fb.removeFromParentNode()
            retire(fb)
            fallbackCameraNode = nil
        }
        if !multiScreenMode {
            pointOfView = camNode
        }
    }

    /// Applies the view-quality tier — runs whenever `viewConfig`
    /// carries a `quality` key. The tier writes `antialiasingMode`
    /// (the viewConfig level in the precedence chain, so
    /// `applyStageQuality` still lets a non-'auto' stage/view mode
    /// outrank it) and walks the scene's authored shadow-casting
    /// lights: 'low' drops `castsShadow`, anything else restores it.
    func applyViewQuality() {
        switch viewQuality {
        case "low": antialiasingMode = .none
        case "medium": antialiasingMode = .multisampling2X
        case "high": antialiasingMode = .multisampling4X
        default: break   // 'default' — leave the widget's mode
        }
        let shadows = viewQuality != "low"
        scene?.rootNode.enumerateChildNodes { node, _ in
            if let l = node.light,
               shadowAuthored.contains(ObjectIdentifier(l)) {
                l.castsShadow = shadows
            }
        }
        applyStageQuality()
    }

    /// W14 stage quality applied to the view: AA precedence = the
    /// screen view's own mode (non-'auto') > stage (non-'auto') >
    /// viewConfig > the .multisampling4X setup default — the last two
    /// already live in `antialiasingMode`, so only a resolved
    /// non-'auto' value is written. `renderScale` →
    /// `contentScaleFactor` (the approximate path — it scales the
    /// CAMetalLayer drawable, not a renderer knob; texture-target
    /// views ignore it). `filterQuality` has no SceneKit counterpart.
    func applyStageQuality() {
        let requested = screenViews.first?.aaMode
            .flatMap { $0 == "auto" ? nil : $0 }
            ?? (stageAntiAliasing != "auto" ? stageAntiAliasing : nil)
        if let requested {
            switch requested {
            case "none": antialiasingMode = .none
            case "msaa": antialiasingMode = .multisampling4X
            default:
                logOnce("w14.aa.\(requested)",
                    "antiAliasing '\(requested)' unsupported on "
                    + "SceneKit; keeping the current mode")
            }
        }
        // Approximate path: scales the drawable backing factor.
        let scale = screenViews.first?.renderScale ?? stageRenderScale
        contentScaleFactor =
            scale * (window?.screen.scale ?? UIScreen.main.scale)
        if stageFilterQuality != "medium" {
            logOnce("w14.filterQuality",
                "filterQuality '\(stageFilterQuality)' unsupported on "
                + "SceneKit; ignored")
        }
        // W24: each sibling resolves its own view's AA/scale — the
        // sibling list is main-thread state.
        if multiScreenMode {
            DispatchQueue.main.async { [weak self] in
                self?.applyScreenSubviewQuality()
            }
        }
    }

    /// `rendersContinuously` stays on while any everyFrame/interval
    /// rt exists — a manual-only (or empty) registry lets the view
    /// idle again. W24: split mode keeps it on too — the host frame
    /// is the siblings' poke source, so it must draw every vsync.
    func updateContinuousRendering() {
        rendersContinuously = multiScreenMode
            || renderTargets.values.contains {
                $0.update == "everyFrame" || $0.update == "interval"
            }
    }

    /// Decodes a command's `bytes` field — JSON carries no raw bytes,
    /// so `upsertPayload` sends base64 (a plain int array works too).
    private func commandBytes(_ any: Any?) -> Data? {
        if let s = any as? String { return Data(base64Encoded: s) }
        if let list = any as? [NSNumber] {
            return Data(list.map { UInt8(clamping: $0.intValue) })
        }
        return nil
    }

    /// Resolves the `"node"` id token of a command payload to its node.
    /// A well-formed id with no live node warns once — lane 10's stale
    /// ops must no-op without crashing.
    private func physicsNode(_ json: [String: Any]) -> SCNNode? {
        guard let token = json["node"] as? String,
              let key = D3Wire.localIdKey(token) else { return nil }
        guard let node = nodesById[key] else {
            logOnce("physics.missing.\(key)",
                "physics command on missing node \(key); ignoring")
            return nil
        }
        return node
    }

    /// Reads a plain (untagged) `[x,y,z]`/`[x,y,z,w]` array from a
    /// command payload — commands carry raw JSON, not tagged values.
    private func vec(_ any: Any?) -> [Double]? {
        (any as? [NSNumber])?.map { $0.doubleValue }
    }

    // MARK: - Physics queries (W8)

    /// `{"op":"query","q":<u32>,"type":…,…}` — answered on the
    /// queryReply channel (`d3FireToDart` type 4) as
    /// `{"q":…,"type":…,…}`, or `{"q":…,"error":…}` when malformed.
    /// pose/raycast/shapecast run inline; overlap poses a probe and
    /// answers once the physics world has registered it.
    private func applyQuery(_ json: [String: Any]) {
        let q = (json["q"] as? Int) ?? 0
        guard let type = json["type"] as? String else {
            queryError(q, "malformed query: missing type")
            return
        }
        switch type {
        case "pose":      queryPose(q, json)
        case "raycast":   queryRaycast(q, json)
        case "overlap":   queryOverlap(q, json)
        case "shapecast": queryShapecast(q, json)
        default:
            queryError(q, "unknown query type '\(type)'")
        }
    }

    private func queryError(_ q: Int, _ msg: String) {
        fireEvent(type: 4, payload:
            "{\"q\":\(q),\"error\":\"\(jsonEscape(msg))\"}")
    }

    /// `{"s":session,"i":index}` — the LocalId shape node references
    /// carry on the wire.
    private func refJSON(_ key: UInt64) -> String {
        "{\"s\":\(UInt32(key >> 32)),\"i\":\(UInt32(key & 0xFFFFFFFF))}"
    }

    private func jsonEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// `"nodes":["all"]` or an absent `nodes` returns every rigid-body
    /// node; otherwise each listed token resolves through `nodesById`.
    /// Poses read the presentation node — mid-animation queries see
    /// the rendered pose, like the settle event.
    private func queryPose(_ q: Int, _ json: [String: Any]) {
        var keys = dynamicBodyKeys.sorted()
        if let list = json["nodes"] as? [Any],
           !list.contains(where: { ($0 as? String) == "all" }) {
            keys = list.compactMap {
                ($0 as? String).flatMap(D3Wire.localIdKey)
            }
        }
        var poses: [String] = []
        for key in keys {
            guard let node = nodesById[key] else { continue }
            let p = node.presentation.worldPosition
            let r = node.presentation.worldOrientation
            poses.append("{\"node\":\(refJSON(key)),"
                + "\"p\":[\(p.x),\(p.y),\(-p.z)],"
                + "\"r\":[\(-r.x),\(-r.y),\(r.z),\(r.w)]}")
        }
        fireEvent(type: 4, payload: "{\"q\":\(q),\"type\":\"pose\","
            + "\"poses\":[\(poses.joined(separator: ","))]}")
    }

    /// `{"origin":[x,y,z],"direction":[x,y,z],"maxDistance":d,"all":b}`
    /// → `rayTestWithSegment`; hits carry `p`/`n`/`d` (distance from
    /// origin) converted back to `.fscene` space, nearest first.
    private func queryRaycast(_ q: Int, _ json: [String: Any]) {
        guard let o = vec(json["origin"]), o.count == 3,
              let dv = vec(json["direction"]), dv.count == 3 else {
            queryError(q, "malformed raycast: need origin and direction")
            return
        }
        let dir = D3Wire.position(dv)
        let len = (dir.x * dir.x + dir.y * dir.y + dir.z * dir.z)
            .squareRoot()
        guard len > 0 else {
            queryError(q, "malformed raycast: zero direction")
            return
        }
        let maxD = Float((json["maxDistance"] as? Double) ?? 100.0)
        let from = D3Wire.position(o)
        let to = SCNVector3(
            from.x + dir.x / len * maxD,
            from.y + dir.y / len * maxD,
            from.z + dir.z / len * maxD)
        let mode: SCNPhysicsWorld.TestSearchMode =
            (json["all"] as? Bool) == true ? .all : .closest
        let results = scene?.physicsWorld.rayTestWithSegment(
            from: from, to: to, options: [.searchMode: mode]) ?? []
        var hits: [(d: Float, json: String)] = []
        for hit in results {
            guard let key = nodeToKey[ObjectIdentifier(hit.node)]
            else { continue }
            let p = hit.worldCoordinates, n = hit.worldNormal
            let dx = p.x - from.x, dy = p.y - from.y, dz = p.z - from.z
            let d = (dx * dx + dy * dy + dz * dz).squareRoot()
            hits.append((d, "{\"node\":\(refJSON(key)),"
                + "\"collider\":\(colliderIndexByKey[key] ?? 0),"
                + "\"p\":[\(p.x),\(p.y),\(-p.z)],"
                + "\"n\":[\(n.x),\(n.y),\(-n.z)],\"d\":\(d)}"))
        }
        hits.sort { $0.d < $1.d }
        fireEvent(type: 4, payload: "{\"q\":\(q),\"type\":\"raycast\","
            + "\"hits\":[\(hits.map(\.json).joined(separator: ","))]}")
    }

    /// `{"shape":{…},"position":[x,y,z],"rotation":[x,y,z,w]?}` →
    /// `contactTest` against a kinematic probe posed at the query
    /// transform. The zero `collisionBitMask` keeps the probe
    /// sensor-like — it senses but never perturbs.
    private func queryOverlap(_ q: Int, _ json: [String: Any]) {
        guard let shape = queryShape(json["shape"]),
              let pos = vec(json["position"]), pos.count == 3 else {
            queryError(q, "malformed overlap: need shape and position")
            return
        }
        let probe = SCNNode()
        let body = SCNPhysicsBody(type: .kinematic, shape: shape)
        body.collisionBitMask = 0       // sense only — no response
        body.contactTestBitMask = ~0    // broadphase pair still forms
        probe.physicsBody = body
        probe.position = D3Wire.position(pos)
        if let r = vec(json["rotation"]), r.count == 4 {
            probe.orientation = D3Wire.quaternion(r)
        }
        scene?.rootNode.addChildNode(probe)
        overlapLock.lock()
        pendingOverlaps.append((q: q, probe: probe, armedTick: _simTick))
        overlapLock.unlock()
    }

    /// Runs inside `didSimulatePhysicsAtTime` once the probe's body is
    /// registered and its pose synced; every contact's non-probe node
    /// is a hit.
    private func replyOverlap(_ q: Int, _ probe: SCNNode) {
        var hits: [String] = []
        var seen: Set<UInt64> = []
        let contacts = probe.physicsBody.flatMap {
            scene?.physicsWorld.contactTest(with: $0, options: nil)
        } ?? []
        for c in contacts {
            guard let other = [c.nodeA, c.nodeB].compactMap({ $0 })
                    .first(where: { $0 !== probe }),
                  let key = nodeToKey[ObjectIdentifier(other)],
                  seen.insert(key).inserted else { continue }
            hits.append("{\"node\":\(refJSON(key)),"
                + "\"collider\":\(colliderIndexByKey[key] ?? 0)}")
        }
        fireEvent(type: 4, payload: "{\"q\":\(q),\"type\":\"overlap\","
            + "\"hits\":[\(hits.joined(separator: ","))]}")
    }

    /// `{"shape":{…},"from":[x,y,z],"to":[x,y,z]}` →
    /// `convexSweepTest`. `d` is the distance ALONG the cast at
    /// contact — `SCNPhysicsContact.sweepTestFraction` × the segment
    /// length, upstream's distance-along-cast semantic (a grazing hit
    /// whose contact point sits off the ray line would over-report as
    /// a point distance). One hit per node, nearest first.
    private func queryShapecast(_ q: Int, _ json: [String: Any]) {
        guard let shape = queryShape(json["shape"]),
              let f = vec(json["from"]), f.count == 3,
              let t = vec(json["to"]), t.count == 3 else {
            queryError(q, "malformed shapecast: need shape, from and to")
            return
        }
        let fv = D3Wire.position(f), tv = D3Wire.position(t)
        let results = scene?.physicsWorld.convexSweepTest(
            with: shape,
            from: SCNMatrix4MakeTranslation(fv.x, fv.y, fv.z),
            to: SCNMatrix4MakeTranslation(tv.x, tv.y, tv.z),
            options: [.searchMode: SCNPhysicsWorld.TestSearchMode.all])
            ?? []
        let sdx = tv.x - fv.x, sdy = tv.y - fv.y, sdz = tv.z - fv.z
        let segLen = (sdx * sdx + sdy * sdy + sdz * sdz).squareRoot()
        var hits: [(d: Float, json: String)] = []
        var seen: Set<UInt64> = []
        for c in results {
            guard let node = [c.nodeA, c.nodeB].compactMap({ $0 })
                    .first(where: {
                        nodeToKey[ObjectIdentifier($0)] != nil }),
                  let key = nodeToKey[ObjectIdentifier(node)],
                  seen.insert(key).inserted else { continue }
            let p = c.contactPoint, n = c.contactNormal
            let d = Float(c.sweepTestFraction) * segLen
            hits.append((d, "{\"node\":\(refJSON(key)),"
                + "\"collider\":\(colliderIndexByKey[key] ?? 0),"
                + "\"p\":[\(p.x),\(p.y),\(-p.z)],"
                + "\"n\":[\(n.x),\(n.y),\(-n.z)],\"d\":\(d)}"))
        }
        hits.sort { $0.d < $1.d }
        fireEvent(type: 4, payload: "{\"q\":\(q),\"type\":\"shapecast\","
            + "\"hits\":[\(hits.map(\.json).joined(separator: ","))]}")
    }

    /// Wire `shape` → `SCNPhysicsShape` for the overlap/shapecast
    /// probes: `{"type":"sphere","radius":r}` or
    /// `{"type":"box","extents":[x,y,z]}` (full extents).
    private func queryShape(_ any: Any?) -> SCNPhysicsShape? {
        guard let m = any as? [String: Any] else { return nil }
        switch m["type"] as? String {
        case "sphere":
            guard let r = m["radius"] as? Double else { return nil }
            return SCNPhysicsShape(geometry: SCNSphere(radius: CGFloat(r)))
        case "box":
            guard let e = vec(m["extents"]), e.count == 3 else {
                return nil
            }
            return SCNPhysicsShape(geometry: SCNBox(
                width: CGFloat(e[0]), height: CGFloat(e[1]),
                length: CGFloat(e[2]), chamferRadius: 0))
        default:
            return nil
        }
    }

    // MARK: - Joints (W9)

    /// One joint's decoded wire fields — retained so `updateJoint`
    /// can recreate the behavior and the break poller can read the
    /// anchors back. `behavior` is nil while the record waits on an
    /// endpoint body that hasn't landed yet.
    private struct JointRecord {
        var behavior: SCNPhysicsBehavior?
        let type: String
        let a: UInt64          // node keys in D3Wire.localIdKey space
        let b: UInt64?         // nil → world-anchored (W12 component
                               // joints declared without `otherNode`)
        let ca: Int            // collider indices — informational: a
        let cb: Int            // node's colliders compose one body
        let collide: Bool
        var anchorA = SCNVector3()   // SceneKit space, body-local
        var anchorB = SCNVector3()
        var axisA: SCNVector3?       // SceneKit space — the mirror is
        var axisB: SCNVector3?       // type-dependent (see decodeJoint)
        var lower: Double?
        var upper: Double?
        var motorVelocity: Double?
        var motorMaxForce: Double?
        var breakDistance: Double?
        var basisA: SCNQuaternion?   // generic only, SceneKit space
        var basisB: SCNQuaternion?
        var axes = [JointAxis](repeating: JointAxis(), count: 6)
        var excluded = false         // this record holds a pair count
    }

    /// One `generic` axis config (`axes` order: linearX…angularZ).
    /// `hasMotor` flags the fields SceneKit's velocity motors can't
    /// express (stiffness/damping/targetPosition/model) for the
    /// warn-once — the wire emits them whenever a motor exists.
    private struct JointAxis {
        enum Motion { case locked, free, limited }
        var motion: Motion = .free
        var lower: Double = 0
        var upper: Double = 0
        var motorVelocity: Double?
        var motorMaxForce: Double?
        var hasMotor = false
    }

    /// `{"op":"addJoint"|"updateJoint","id":7,"type":…,…}` — both store
    /// the record, then realize it; `updateJoint` (upstream's
    /// recreate-in-place contract) drops the old behavior first, and
    /// an `addJoint` reusing a live id does the same so a re-sent op
    /// stays idempotent.
    private func applyJoint(_ json: [String: Any], update: Bool) {
        guard let raw = json["id"] as? Int else {
            logOnce("joint.malformed.id", "joint op: missing id")
            return
        }
        let id = UInt32(truncatingIfNeeded: raw)
        guard let rec = decodeJoint(json) else { return }
        jointLock.lock()
        defer { jointLock.unlock() }
        if update, joints[id] == nil {
            logOnce("updateJoint.missing.\(id)",
                "updateJoint on unknown joint \(id); ignoring")
            return
        }
        if !update, joints[id] != nil {
            d3Log("addJoint on live id \(id); recreating")
        }
        dropJointLocked(id)
        joints[id] = rec
        realizeJointLocked(id)
    }

    /// `{"op":"removeJoint","id":7}` — drops the record and its
    /// behavior; the handle becomes reusable.
    private func applyRemoveJoint(_ json: [String: Any]) {
        guard let raw = json["id"] as? Int else { return }
        let id = UInt32(truncatingIfNeeded: raw)
        jointLock.lock()
        let known = joints[id] != nil
        dropJointLocked(id)
        jointLock.unlock()
        if !known {
            logOnce("removeJoint.missing.\(id)",
                "removeJoint on unknown joint \(id); ignoring")
        }
    }

    /// Decodes the shared `addJoint`/`updateJoint` field set into a
    /// record (`behavior` still nil). Anchors and axes are body-local
    /// in .fscene space on the wire; SceneKit also takes body-local,
    /// so only the z-mirror applies — anchors as positions, a
    /// revolute axis as a pseudovector (−x,−y,z, the map angular
    /// velocity takes, so wire limit/motor signs keep their sense), a
    /// prismatic axis as a plain direction.
    private func decodeJoint(_ json: [String: Any]) -> JointRecord? {
        guard let type = json["type"] as? String,
              let aT = json["a"] as? String,
              let a = D3Wire.localIdKey(aT) else {
            logOnce("joint.malformed", "joint op: missing type/a")
            return nil
        }
        // `b` is optional — a component-declared joint without an
        // `otherNode` anchors to the world (upstream's fixed body at
        // the identity pose; see worldAnchorBody). Command ops always
        // send it.
        let b = (json["b"] as? String).flatMap(D3Wire.localIdKey)
        if let b, a == b {
            logOnce("joint.self.\(a)",
                "joint \(a): both endpoints are the same node; ignored")
            return nil
        }
        var rec = JointRecord(
            type: type, a: a, b: b,
            ca: (json["ca"] as? Int) ?? 0,
            cb: (json["cb"] as? Int) ?? 0,
            collide: (json["collide"] as? Bool) ?? false)
        if let v = vec(json["anchorA"]), v.count == 3 {
            rec.anchorA = D3Wire.position(v)
        }
        if let v = vec(json["anchorB"]), v.count == 3 {
            rec.anchorB = D3Wire.position(v)
        }
        let axis: ([Double]) -> SCNVector3 = type == "revolute"
            ? { SCNVector3(Float(-$0[0]), Float(-$0[1]), Float($0[2])) }
            : { D3Wire.position($0) }
        if let v = vec(json["axisA"]), v.count == 3 {
            rec.axisA = axis(v)
        }
        if let v = vec(json["axisB"]), v.count == 3 {
            rec.axisB = axis(v)
        }
        // Scalars pass through on iOS: the revolute axis above is
        // decoded as a pseudovector (−S·a), so a wire rotation θ about
        // the wire axis is a SceneKit rotation +θ about the stored
        // axis and limits/motor keep their wire sign. Android takes
        // the equivalent representation instead — a direction-mapped
        // axis (S·a) with limits swapped ([−upper, −lower]) and motor
        // negated — same physical constraint either way.
        rec.lower = (json["lower"] as? NSNumber)?.doubleValue
        rec.upper = (json["upper"] as? NSNumber)?.doubleValue
        rec.motorVelocity =
            (json["motorVelocity"] as? NSNumber)?.doubleValue
        rec.motorMaxForce =
            (json["motorMaxForce"] as? NSNumber)?.doubleValue
        rec.breakDistance =
            (json["breakDistance"] as? NSNumber)?.doubleValue
        if let v = vec(json["basisA"]), v.count == 4 {
            rec.basisA = D3Wire.quaternion(v)
        }
        if let v = vec(json["basisB"]), v.count == 4 {
            rec.basisB = D3Wire.quaternion(v)
        }
        rec.axes = decodeJointAxes(json["axes"])
        return rec
    }

    /// Six `{"motion":"locked|free|limited","lower":f,"upper":f,
    /// "motor":{…}?}` entries in JointAxis order; an absent or
    /// malformed entry leaves the axis FREE — upstream's
    /// `JointAxisConfig` default (matches Android's decoder; a command
    /// `generic` joint without `axes` frees all six DOFs).
    private func decodeJointAxes(_ any: Any?) -> [JointAxis] {
        var axes = [JointAxis](repeating: JointAxis(), count: 6)
        for (i, entry) in (any as? [Any] ?? []).prefix(6).enumerated() {
            guard let m = entry as? [String: Any] else { continue }
            switch m["motion"] as? String {
            case "locked":  axes[i].motion = .locked
            case "free":    axes[i].motion = .free
            case "limited": axes[i].motion = .limited
            default:
                if let s = m["motion"] as? String {
                    logOnce("joint.axes.motion.\(s)",
                        "generic axis motion '\(s)' unknown; " +
                            "treating as free")
                }
                axes[i].motion = .free
            }
            // Scalars pass through unmirrored: `genericAxis` bakes
            // the z-mirror into each axis's DIRECTION (linear maps
            // polar, angular axial), so the wire scalar keeps its
            // sense about the produced SceneKit axis. Android's
            // per-index negation (linearZ, angularX/Y) exists because
            // Jolt measures the scalar inside the mirrored constraint
            // frame — a different representation of the same physics.
            axes[i].lower = (m["lower"] as? NSNumber)?.doubleValue ?? 0
            axes[i].upper = (m["upper"] as? NSNumber)?.doubleValue ?? 0
            guard let motor = m["motor"] as? [String: Any] else { continue }
            axes[i].hasMotor = true
            axes[i].motorVelocity =
                (motor["targetVelocity"] as? NSNumber)?.doubleValue
            axes[i].motorMaxForce =
                (motor["maxForce"] as? NSNumber)?.doubleValue
        }
        return axes
    }

    /// Re-attempts every deferred joint — endpoints resolve on node
    /// landings (addNode/updateNode) and scene installs.
    private func retryPendingJoints() {
        jointLock.lock()
        for id in joints.keys.sorted() { realizeJointLocked(id) }
        jointLock.unlock()
    }

    /// The shared static body world-anchored joints bind to — a hidden
    /// node at the scene origin carrying a `.static` body, matching
    /// upstream's fixed body at the identity pose (so `anchorB` is
    /// world-space). Lazily created against the installed scene.
    private func worldAnchorBody() -> SCNPhysicsBody? {
        if let body = worldAnchorNode?.physicsBody { return body }
        guard let scene else { return nil }
        let node = SCNNode()
        node.isHidden = true
        node.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        scene.rootNode.addChildNode(node)
        worldAnchorNode = node
        return node.physicsBody
    }

    /// W12: registers one decoded joint component under a reserved
    /// component handle — the record joins `joints` so deferral,
    /// rebinding around body rebuilds and the break sweep apply
    /// unchanged. A re-decode of the same component index replaces the
    /// old record.
    func registerComponentJoint(nodeKey key: UInt64,
                                componentIndex index: Int,
                                json: [String: Any]) {
        guard let rec = decodeJoint(json) else { return }
        jointLock.lock()
        defer { jointLock.unlock() }
        if let old = componentJointIds[key]?[index] {
            dropJointLocked(old)
        }
        let id = nextComponentJointHandle
        nextComponentJointHandle += 1
        if nextComponentJointHandle < 0x4000_0000 {
            // Wrapped past the component range — restart it.
            nextComponentJointHandle = 0x4000_0000
        }
        componentJointIds[key, default: [:]][index] = id
        joints[id] = rec
        realizeJointLocked(id)
    }

    /// Drops every component-declared joint — the manifest path calls
    /// this before decode so a re-install never duplicates the previous
    /// document's records (op-created joints are untouched: they are
    /// runtime state, not document state).
    func beginComponentJointRegistration() {
        jointLock.lock()
        defer { jointLock.unlock() }
        for (_, byIndex) in componentJointIds {
            for (_, handle) in byIndex { dropJointLocked(handle) }
        }
        componentJointIds.removeAll()
    }

    /// Builds and installs the behavior for a deferred joint when
    /// both endpoints are live bodied nodes (a static or kinematic
    /// body qualifies — SceneKit joints anchor to them). A still-
    /// missing endpoint keeps the record deferred. Caller holds
    /// `jointLock`.
    private func realizeJointLocked(_ id: UInt32) {
        guard var rec = joints[id], rec.behavior == nil else { return }
        // `parent != nil` rejects stale registry entries: between a
        // scene reset and install, `nodesById` still maps to detached
        // nodes whose physicsBody objects are dead — binding one
        // would strand the constraint (and its pair bookkeeping) on a
        // body that never simulates again.
        guard let nodeA = nodesById[rec.a], nodeA.parent != nil,
              let bodyA = nodeA.physicsBody else {
            logOnce("joint.\(id).deferred",
                "joint \(id): endpoint not a live body yet; deferred")
            return
        }
        let bodyB: SCNPhysicsBody
        if let b = rec.b {
            guard let nodeB = nodesById[b], nodeB.parent != nil,
                  let found = nodeB.physicsBody else {
                logOnce("joint.\(id).deferred",
                    "joint \(id): endpoint not a live body yet; deferred")
                return
            }
            bodyB = found
        } else {
            guard let anchor = worldAnchorBody() else {
                logOnce("joint.\(id).deferred",
                    "joint \(id): no scene for the world anchor yet; "
                    + "deferred")
                return
            }
            bodyB = anchor
        }
        guard let behavior = buildJoint(rec, bodyA, bodyB) else {
            joints.removeValue(forKey: id)
            return
        }
        scene?.physicsWorld.addBehavior(behavior)
        rec.behavior = behavior
        // collide:false → pairwise exclusion (the world anchor is
        // shapeless — nothing to exclude).
        if !rec.collide, rec.b != nil, !rec.excluded {
            recordPairLocked(&rec)
        }
        joints[id] = rec
    }

    /// Removes joint `id`'s behavior and record. Caller holds
    /// `jointLock`.
    private func dropJointLocked(_ id: UInt32) {
        if let rec = joints[id] {
            if rec.excluded { releasePairLocked(rec) }
            if let b = rec.behavior {
                scene?.physicsWorld.removeBehavior(b)
                retire(b)
            }
        }
        joints.removeValue(forKey: id)
    }

    /// `collide:false` — counts the pair and attempts the carve. A
    /// pair that can't collide at the wire level stays recorded only;
    /// `applyJointPairMasks` retries the carve on every body rebuild.
    /// Caller holds `jointLock`.
    private func recordPairLocked(_ rec: inout JointRecord) {
        guard let bKey = rec.b else { return }
        rec.excluded = true
        let pair = JointPair(rec.a, bKey)
        jointExcludedPairs[pair] = (jointExcludedPairs[pair] ?? 0) + 1
        carvePairLocked(pair)
    }

    /// Reverses one record's [recordPairLocked]: the last record off
    /// a pair frees the endpoints' private bits (each only when no
    /// other pair still excludes it), then all masks re-derive.
    /// Caller holds `jointLock`.
    private func releasePairLocked(_ rec: JointRecord) {
        guard let bKey = rec.b else { return }
        let pair = JointPair(rec.a, bKey)
        guard let n = jointExcludedPairs[pair] else { return }
        if n > 1 {
            jointExcludedPairs[pair] = n - 1
            return
        }
        jointExcludedPairs.removeValue(forKey: pair)
        for key in [pair.lo, pair.hi]
        where !jointExcludedPairs.keys.contains(where: {
            $0.contains(key)
        }) {
            unprivatizeLocked(key)
        }
        rebuildPairMasksLocked()
    }

    /// Privatizes both endpoints and re-derives the mask space when
    /// the pair can collide at the wire level — idempotent, so a
    /// recorded pair retries here on every rebuild it touches. An
    /// already-excluded pair no-ops at the wire-collide check (the
    /// wire truth doesn't move under carving). Both private bits are
    /// reserved before either installs: privatizing `lo` and then
    /// hitting the 24-bit cap on `hi` would orphan `lo`'s private
    /// category — no mask references it — leaving it colliding with
    /// nothing until a rebuild heals it, instead of the pair
    /// documentedly keeping colliding. Caller holds `jointLock`.
    private func carvePairLocked(_ pair: JointPair) {
        guard let wA = wireMasksLocked(pair.lo),
              let wB = wireMasksLocked(pair.hi),
              (wA.cat & wB.mask) != 0,
              (wB.cat & wA.mask) != 0 else { return }
        var reserved: [UInt64: Int] = [:]
        for key in [pair.lo, pair.hi] where jointPrivBits[key] == nil {
            guard nodesById[key]?.parent != nil,
                  nodesById[key]?.physicsBody != nil,
                  let bit = freePrivateBitLocked(
                      excluding: Set(reserved.values))
            else { return }
            reserved[key] = bit
        }
        for (key, bit) in reserved { privatizeLocked(key, bit: bit) }
        rebuildPairMasksLocked()
    }

    /// A node's wire-truth (category, collision mask): privatized
    /// nodes read their save; live bodies read their realizer values
    /// minus the private range. Nil for a node without a LIVE body —
    /// `parent != nil` keeps detached pre-install registry entries
    /// (dead nodes that still hold a physicsBody) from answering.
    /// Caller holds `jointLock`.
    private func wireMasksLocked(_ key: UInt64)
        -> (cat: Int, mask: Int)?
    {
        if let w = jointWireMasks[key] { return w }
        guard let node = nodesById[key], node.parent != nil,
              let b = node.physicsBody else { return nil }
        return (b.categoryBitMask,
                b.collisionBitMask & ~Self.jointPrivateBits)
    }

    /// The first free private category bit (top-down from bit 63,
    /// inside `jointPrivateBits`), skipping bits a carve has reserved
    /// but not yet installed. Nil past 24 privatized bodies — the
    /// pair then keeps colliding, and the recorded pair's carve
    /// retries on every rebuild so a bit freed later still completes
    /// it. Caller holds `jointLock`.
    private func freePrivateBitLocked(excluding reserved: Set<Int>)
        -> Int?
    {
        for i in 0..<24 {
            let cand = 1 << (63 - i)
            if !jointPrivBits.values.contains(cand),
               !reserved.contains(cand) { return cand }
        }
        logOnce("joint.collide.bits",
            "collide=false joints exhausted the private category "
            + "bits; the pair keeps colliding")
        return nil
    }

    /// Installs the node's reserved private category bit and saves
    /// its wire masks. Caller holds `jointLock`.
    private func privatizeLocked(_ key: UInt64, bit: Int) {
        guard let body = nodesById[key]?.physicsBody else { return }
        jointPrivBits[key] = bit
        jointWireMasks[key] = (body.categoryBitMask,
            body.collisionBitMask & ~Self.jointPrivateBits)
        body.categoryBitMask = bit
    }

    /// Frees the node's private bit and restores its saved wire
    /// category/mask (skipped cleanly when the body is already gone).
    /// Caller holds `jointLock`.
    private func unprivatizeLocked(_ key: UInt64) {
        guard jointPrivBits.removeValue(forKey: key) != nil
        else { return }
        if let (cat, mask) = jointWireMasks.removeValue(forKey: key),
           let body = nodesById[key]?.physicsBody {
            body.categoryBitMask = cat
            body.collisionBitMask = mask
            body.contactTestBitMask = ~0
        }
    }

    /// One body's derived (category, collision mask, contact mask)
    /// under the live exclusion state — pure: wire truth in, masks
    /// out. Caller holds `jointLock`.
    private func pairMasks(_ key: UInt64, _ body: SCNPhysicsBody)
        -> (cat: Int, mask: Int, contact: Int)
    {
        let wire = wireMasksLocked(key)
            ?? (body.categoryBitMask,
                body.collisionBitMask & ~Self.jointPrivateBits)
        var mask = wire.mask
        var contact: Int = ~0
        // See a privatized body exactly when the wire mask saw its
        // wire category; excluded partners lose their bit outright.
        for (k, bit) in jointPrivBits where k != key {
            guard let (wCat, _) = jointWireMasks[k],
                  (wCat & wire.mask) != 0 else { continue }
            mask |= bit
        }
        for pair in jointExcludedPairs.keys where pair.contains(key) {
            if let bit = jointPrivBits[pair.other(key)] {
                mask &= ~bit
                contact &= ~bit
            }
        }
        return (jointPrivBits[key] ?? wire.cat, mask, contact)
    }

    /// Re-derives every registered body's masks via [pairMasks] —
    /// the ONE place the pair scheme writes them, so rebuilds can
    /// never leak a freed or stale private bit. Caller holds
    /// `jointLock`.
    private func rebuildPairMasksLocked() {
        for (key, node) in nodesById where node.parent != nil {
            guard let body = node.physicsBody else { continue }
            let (cat, mask, contact) = pairMasks(key, body)
            body.categoryBitMask = cat
            body.collisionBitMask = mask
            body.contactTestBitMask = contact
        }
    }

    /// Re-attempts every recorded pair's carve, then re-derives —
    /// `install` calls this once `nodesById` holds the new scene, so
    /// pairs that recorded against the outgoing registry (or couldn't
    /// collide then) converge instead of waiting on a body rebuild.
    private func settleJointPairMasks() {
        jointLock.lock()
        defer { jointLock.unlock() }
        for pair in jointExcludedPairs.keys { carvePairLocked(pair) }
        rebuildPairMasksLocked()
    }

    /// Re-derives a freshly (re)built body's pair masks: refreshes a
    /// privatized node's wire save, retries the carve on every
    /// recorded pair it touches (a pair that couldn't collide at
    /// joint time may collide on the new masks), and re-derives. The
    /// body gets its own pass too — during an initial decode it isn't
    /// in `nodesById` yet. FsceneRealizer calls this right after
    /// `node.physicsBody =`.
    func applyJointPairMasks(_ key: UInt64, _ body: SCNPhysicsBody) {
        jointLock.lock()
        defer { jointLock.unlock() }
        guard !jointExcludedPairs.isEmpty || !jointPrivBits.isEmpty
        else { return }
        if jointPrivBits[key] != nil {
            jointWireMasks[key] = (body.categoryBitMask,
                body.collisionBitMask & ~Self.jointPrivateBits)
        }
        for pair in jointExcludedPairs.keys where pair.contains(key) {
            carvePairLocked(pair)
        }
        rebuildPairMasksLocked()
        let (cat, mask, contact) = pairMasks(key, body)
        body.categoryBitMask = cat
        body.collisionBitMask = mask
        body.contactTestBitMask = contact
    }

    /// Maps a record to its SceneKit behavior. iOS has no
    /// `SCNPhysicsFixedJoint` (macOS-only) and `SCNPhysicsHingeJoint`
    /// exposes no limits or motor — a `SCNPhysicsSliderJoint` with the
    /// unused half zeroed stands in for both: linear pinned → a hinge
    /// that takes angular limits/motor; angular pinned → a slider;
    /// both pinned → the fixed weld.
    private func buildJoint(_ rec: JointRecord, _ a: SCNPhysicsBody,
                            _ b: SCNPhysicsBody) -> SCNPhysicsBehavior? {
        switch rec.type {
        case "fixed":
            return weldJoint(rec.anchorA, rec.anchorB, a, b)
        case "spherical":
            return SCNPhysicsBallSocketJoint(
                bodyA: a, anchorA: rec.anchorA,
                bodyB: b, anchorB: rec.anchorB)
        case "revolute":
            return revoluteJoint(
                axisA: rec.axisA, axisB: rec.axisB,
                anchorA: rec.anchorA, anchorB: rec.anchorB,
                lower: rec.lower, upper: rec.upper,
                motorVelocity: rec.motorVelocity,
                motorMaxForce: rec.motorMaxForce, a, b)
        case "prismatic":
            return prismaticJoint(
                axisA: rec.axisA, axisB: rec.axisB,
                anchorA: rec.anchorA, anchorB: rec.anchorB,
                lower: rec.lower, upper: rec.upper,
                motorVelocity: rec.motorVelocity,
                motorMaxForce: rec.motorMaxForce,
                freeAngular: false, a, b)
        case "generic":
            return genericJoint(rec, a, b)
        default:
            logOnce("joint.type.\(rec.type)",
                "unknown joint type '\(rec.type)'; joint dropped")
            return nil
        }
    }

    /// The iOS fixed-joint stand-in: a slider with every degree of
    /// freedom pinned at zero welds the bodies at their creation-time
    /// relative pose.
    private func weldJoint(_ anchorA: SCNVector3, _ anchorB: SCNVector3,
                           _ a: SCNPhysicsBody, _ b: SCNPhysicsBody)
        -> SCNPhysicsBehavior
    {
        let s = SCNPhysicsSliderJoint(
            bodyA: a, axisA: SCNVector3(0, 0, 1), anchorA: anchorA,
            bodyB: b, axisB: SCNVector3(0, 0, 1), anchorB: anchorB)
        s.minimumLinearLimit = 0
        s.maximumLinearLimit = 0
        s.minimumAngularLimit = 0
        s.maximumAngularLimit = 0
        return s
    }

    /// A hinge — or, when the wire asks for angular limits or a motor
    /// (which `SCNPhysicsHingeJoint` doesn't expose), a slider with
    /// its linear range pinned at zero, the same constraint with both
    /// dials available.
    private func revoluteJoint(
        axisA: SCNVector3?, axisB: SCNVector3?,
        anchorA: SCNVector3, anchorB: SCNVector3,
        lower: Double?, upper: Double?,
        motorVelocity: Double?, motorMaxForce: Double?,
        _ a: SCNPhysicsBody, _ b: SCNPhysicsBody
    ) -> SCNPhysicsBehavior {
        let axA = jointAxis(axisA ?? axisB)
        let axB = jointAxis(axisB ?? axisA)
        if lower == nil && upper == nil
            && motorVelocity == nil && motorMaxForce == nil {
            return SCNPhysicsHingeJoint(
                bodyA: a, axisA: axA, anchorA: anchorA,
                bodyB: b, axisB: axB, anchorB: anchorB)
        }
        let s = SCNPhysicsSliderJoint(
            bodyA: a, axisA: axA, anchorA: anchorA,
            bodyB: b, axisB: axB, anchorB: anchorB)
        s.minimumLinearLimit = 0
        s.maximumLinearLimit = 0
        // The slider's angular coordinate spans (−π, π] — an absent
        // wire limit takes that bound, covering the full circle.
        s.minimumAngularLimit = CGFloat(lower ?? -.pi)
        s.maximumAngularLimit = CGFloat(upper ?? .pi)
        if let v = motorVelocity {
            s.motorTargetAngularVelocity = CGFloat(v)
        }
        if let f = motorMaxForce {
            s.motorMaximumTorque = CGFloat(f)
        }
        return s
    }

    /// A slider with its angular range pinned — a prismatic joint
    /// never rotates. `freeAngular` (the generic fallback) instead
    /// opens rotation about the slide axis, the closest covering.
    private func prismaticJoint(
        axisA: SCNVector3?, axisB: SCNVector3?,
        anchorA: SCNVector3, anchorB: SCNVector3,
        lower: Double?, upper: Double?,
        motorVelocity: Double?, motorMaxForce: Double?,
        freeAngular: Bool,
        _ a: SCNPhysicsBody, _ b: SCNPhysicsBody
    ) -> SCNPhysicsBehavior {
        let axA = jointAxis(axisA ?? axisB)
        let axB = jointAxis(axisB ?? axisA)
        let s = SCNPhysicsSliderJoint(
            bodyA: a, axisA: axA, anchorA: anchorA,
            bodyB: b, axisB: axB, anchorB: anchorB)
        s.minimumAngularLimit = freeAngular ? -.pi : 0
        s.maximumAngularLimit = freeAngular ? .pi : 0
        // An absent wire limit takes a far bound — Bullet's own
        // free-sentinel (lower > upper) isn't a documented SceneKit
        // input, so "unbounded" reads as beyond any real scene.
        s.minimumLinearLimit = CGFloat(lower ?? -1e9)
        s.maximumLinearLimit = CGFloat(upper ?? 1e9)
        if let v = motorVelocity {
            s.motorTargetLinearVelocity = CGFloat(v)
        }
        if let f = motorMaxForce {
            s.motorMaximumForce = CGFloat(f)
        }
        return s
    }

    /// SceneKit has no 6-DOF constraint — `generic` decomposes by
    /// axis config: all locked → the weld; linear locked with one
    /// angular freed → the hinge path; angular locked with one linear
    /// freed → the slider path; anything else warns once and falls
    /// back to the nearest primitive covering the free axes (a ball
    /// socket frees all rotation; a slider frees its axis plus
    /// rotation about it).
    private func genericJoint(_ rec: JointRecord, _ a: SCNPhysicsBody,
                              _ b: SCNPhysicsBody) -> SCNPhysicsBehavior {
        let freeLin = (0..<3).filter { rec.axes[$0].motion != .locked }
        let freeAng = (3..<6).filter { rec.axes[$0].motion != .locked }
        if (freeLin + freeAng).contains(where: { rec.axes[$0].hasMotor }) {
            logOnce("joint.generic.motor",
                "generic joint motor: SceneKit velocity motors take "
                + "only targetVelocity/maxForce; stiffness/damping/"
                + "targetPosition/model dropped")
        }
        if freeLin.isEmpty && freeAng.isEmpty {
            return weldJoint(rec.anchorA, rec.anchorB, a, b)
        }
        if freeLin.isEmpty, freeAng.count == 1 {
            let i = freeAng[0], ax = rec.axes[i]
            return revoluteJoint(
                axisA: genericAxis(i, rec.basisA),
                axisB: genericAxis(i, rec.basisB),
                anchorA: rec.anchorA, anchorB: rec.anchorB,
                lower: ax.motion == .limited ? ax.lower : nil,
                upper: ax.motion == .limited ? ax.upper : nil,
                motorVelocity: ax.motorVelocity,
                motorMaxForce: ax.motorMaxForce, a, b)
        }
        if freeAng.isEmpty, freeLin.count == 1 {
            let i = freeLin[0], ax = rec.axes[i]
            return prismaticJoint(
                axisA: genericAxis(i, rec.basisA),
                axisB: genericAxis(i, rec.basisB),
                anchorA: rec.anchorA, anchorB: rec.anchorB,
                lower: ax.motion == .limited ? ax.lower : nil,
                upper: ax.motion == .limited ? ax.upper : nil,
                motorVelocity: ax.motorVelocity,
                motorMaxForce: ax.motorMaxForce,
                freeAngular: false, a, b)
        }
        logOnce("joint.generic.fallback",
            "generic joint: axis set exceeds SceneKit primitives; "
            + "using the nearest covering joint")
        if freeLin.isEmpty {
            return SCNPhysicsBallSocketJoint(
                bodyA: a, anchorA: rec.anchorA,
                bodyB: b, anchorB: rec.anchorB)
        }
        let i = freeLin[0], ax = rec.axes[i]
        return prismaticJoint(
            axisA: genericAxis(i, rec.basisA),
            axisB: genericAxis(i, rec.basisB),
            anchorA: rec.anchorA, anchorB: rec.anchorB,
            lower: ax.motion == .limited ? ax.lower : nil,
            upper: ax.motion == .limited ? ax.upper : nil,
            motorVelocity: ax.motorVelocity,
            motorMaxForce: ax.motorMaxForce,
            freeAngular: !freeAng.isEmpty, a, b)
    }

    /// The body-local direction of generic axis `i`: its unit vector
    /// is mirrored first (angular axes take the pseudovector map, as
    /// `revolute` does), then rotated out of the basis frame — nil
    /// basis is identity.
    private func genericAxis(_ i: Int, _ basis: SCNQuaternion?)
        -> SCNVector3
    {
        var u = SCNVector3(0, 0, 0)
        switch i % 3 {
        case 0: u.x = 1
        case 1: u.y = 1
        default: u.z = 1
        }
        u = i >= 3 ? SCNVector3(-u.x, -u.y, u.z)
                   : SCNVector3(u.x, u.y, -u.z)
        guard let basis else { return u }
        let r = simd_act(
            simd_quaternion(basis.x, basis.y, basis.z, basis.w),
            simd_float3(u.x, u.y, u.z))
        return SCNVector3(r.x, r.y, r.z)
    }

    /// A joint axis must be a nonzero unit vector — a missing or
    /// zero wire axis defaults to +z with one warning.
    private func jointAxis(_ v: SCNVector3?) -> SCNVector3 {
        guard let v else {
            logOnce("joint.axis.missing",
                "joint op carries no axis; defaulting to +z")
            return SCNVector3(0, 0, 1)
        }
        let l = (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
        guard l > 0 else {
            logOnce("joint.axis.zero",
                "joint axis is zero-length; defaulting to +z")
            return SCNVector3(0, 0, 1)
        }
        return SCNVector3(v.x / l, v.y / l, v.z / l)
    }

    // MARK: - Skins / morphs / animations (W11)

    /// `{"op":"anim","anim":"<id>",…}` — the runtime clip control.
    /// The clip is created lazily, paused at t=0, on first reference —
    /// upstream's `createAnimationClip` contract (a doc's animations
    /// exist as defs; nothing autoplays). Verbs apply in
    /// pause→stop→play order so `play` trumps; `time` then seeks
    /// (clamped to `[0, endTime]` — `play`+`time` is `gotoAndPlay`);
    /// `timeScale`/`weight`/`loop` are the knob writes.
    private func applyAnim(_ json: [String: Any]) {
        guard let token = json["anim"] as? String,
              let key = D3Wire.localIdKey(token) else { return }
        guard let def = animationsById[key] else {
            logOnce("anim.missing.\(key)",
                "anim on unknown animation \(key); ignoring")
            return
        }
        animLock.lock()
        var clip = animClips[key] ?? AnimClipState()
        if (json["pause"] as? Bool) == true { clip.playing = false }
        if (json["stop"] as? Bool) == true {
            clip.playing = false
            clip.time = 0
        }
        if (json["play"] as? Bool) == true { clip.playing = true }
        if let t = (json["time"] as? NSNumber)?.doubleValue {
            clip.time = min(max(t, 0), def.endTime)
        }
        if let ts = (json["timeScale"] as? NSNumber)?.doubleValue {
            clip.timeScale = ts
        }
        if let w = (json["weight"] as? NSNumber)?.doubleValue {
            clip.weight = min(max(w, 0), 1)
        }
        if let l = json["loop"] as? Bool { clip.loop = l }
        animClips[key] = clip
        animLock.unlock()
    }

    /// `{"op":"upsertSkin","id":"<id>","skin":{…}}` — re-decode one
    /// manifest `skins` entry and rebind every node whose `skin`
    /// member names it (the upsertResource consumer contract).
    private func applyUpsertSkin(_ json: [String: Any]) {
        guard let token = json["id"] as? String,
              let key = D3Wire.localIdKey(token),
              let skin = json["skin"] as? [String: Any] else {
            logOnce("upsertSkin.malformed",
                "upsertSkin: missing id/skin")
            return
        }
        redecodeSkin(key, skin)
    }

    /// `{"op":"upsertAnimation","id":"<id>","animation":{…}}` —
    /// re-decode one `animations` entry; a live clip keeps its
    /// playback state (upstream `rebind`), clamped to the new endTime.
    private func applyUpsertAnimation(_ json: [String: Any]) {
        guard let token = json["id"] as? String,
              let key = D3Wire.localIdKey(token),
              let anim = json["animation"] as? [String: Any] else {
            logOnce("upsertAnimation.malformed",
                "upsertAnimation: missing id/animation")
            return
        }
        redecodeAnimation(key, anim)
    }

    /// `{"op":"removeSkin","id":"<id>"}` — drop the def; every bound
    /// node detaches (its `skin` member stays, so a later upsert of
    /// the same id re-binds — the consumers refresh path leaves them
    /// pending while the def is absent).
    private func applyRemoveSkin(_ json: [String: Any]) {
        guard let token = json["id"] as? String,
              let key = D3Wire.localIdKey(token) else { return }
        let ctx = surgicalContext()
        ctx.skins.removeValue(forKey: key)
        ctx.skinDefs.removeValue(forKey: key)
        ctx.skinPayloadKeys.removeValue(forKey: key)
        ctx.refreshSkinConsumers(key)
        publish(ctx)
    }

    /// `{"op":"removeAnimation","id":"<id>"}` — drop the def and its
    /// clip. Bound nodes keep their captured bind entries, so the next
    /// sampled frame writes them back to bind pose — upstream's
    /// `removeClip` behavior.
    private func applyRemoveAnimation(_ json: [String: Any]) {
        guard let token = json["id"] as? String,
              let key = D3Wire.localIdKey(token) else { return }
        let ctx = surgicalContext()
        ctx.animations.removeValue(forKey: key)
        ctx.animDefs.removeValue(forKey: key)
        ctx.animPayloadKeys.removeValue(forKey: key)
        publish(ctx)
        animLock.lock()
        animClips.removeValue(forKey: key)
        animLock.unlock()
    }

    /// `{"op":"setMorphWeights","node":"<id>","weights":[f,…]}` —
    /// direct write: listed targets take the value, unlisted trailing
    /// targets keep theirs, excess entries are ignored.
    private func applySetMorphWeights(_ json: [String: Any]) {
        guard let token = json["node"] as? String,
              let key = D3Wire.localIdKey(token),
              let node = nodesById[key] else { return }
        guard let morpher = node.morpher else {
            logOnce("setMorphWeights.\(key)",
                "setMorphWeights on node \(key) with no morpher")
            return
        }
        let weights = (json["weights"] as? [NSNumber] ?? [])
            .map { $0.doubleValue }
        for i in 0..<min(weights.count, morpher.targets.count) {
            morpher.setWeight(CGFloat(weights[i]), forTargetAt: i)
        }
    }

    /// `{"op":"selectVariant","node":"<id>","selected":"<name>"|null}`
    /// — upstream `MaterialsVariantsComponent.select`: reselects the
    /// named variant across the component's resolved bindings; a null
    /// or unknown name re-applies the defaults.
    private func applySelectVariant(_ json: [String: Any]) {
        guard let token = json["node"] as? String,
              let key = D3Wire.localIdKey(token) else { return }
        let ctx = surgicalContext()
        guard var vc = ctx.variantComponents[key] else {
            logOnce("selectVariant.missing.\(key)",
                "selectVariant on node \(key) with no materialsVariants "
                + "component; ignoring")
            return
        }
        let name = json["selected"] as? String
        d3Log("selectVariant node=\(key) selected=\(name ?? "null")")
        if let name, !vc.variants.contains(name) {
            logOnce("selectVariant.unknown.\(name)",
                "selectVariant '\(name)' is not a declared variant on "
                + "node \(key); re-applying defaults")
        }
        vc.selected = name
        ctx.variantComponents[key] = vc
        ctx.applyVariantComponents()
        publish(ctx)
    }

    /// Re-decodes one skin def into the stores and re-binds every
    /// consumer — the `upsertSkin` and payload-arrival shared path.
    private func redecodeSkin(_ key: UInt64, _ def: [String: Any]) {
        let ctx = surgicalContext()
        ctx.skinDefs[key] = def
        ctx.decodeSkin(key, def)
        ctx.refreshSkinConsumers(key)
        retryPendingSkins(ctx)
        publish(ctx)
    }

    /// Re-decodes one animation def — a live clip keeps playback
    /// state, its `time` clamped to the new `endTime` (upstream
    /// `rebind`'s clamp).
    private func redecodeAnimation(_ key: UInt64, _ def: [String: Any]) {
        let ctx = surgicalContext()
        ctx.animDefs[key] = def
        ctx.decodeAnimation(key, def)
        publish(ctx)
        animLock.lock()
        if var clip = animClips[key] {
            clip.time = min(max(clip.time, 0),
                            animationsById[key]?.endTime ?? 0)
            animClips[key] = clip
        }
        animLock.unlock()
    }

    /// Retries every pending skin attach — called after node landings
    /// and skin re-decodes. Mutates `ctx.pendingSkinNodes`; callers
    /// `publish` after.
    private func retryPendingSkins(_ ctx: FsceneRealizer.Context) {
        for nk in Array(ctx.pendingSkinNodes) {
            if let node = nodesById[nk] {
                ctx.attachSkin(nk, node)
            } else {
                ctx.pendingSkinNodes.remove(nk)
            }
        }
    }

    /// Per-frame animation sampler — upstream `AnimationPlayer.update`:
    /// advance every clip by `dt × timeScale` (clamping+pausing at the
    /// endTime boundary, or wrapping when `loop`), reset each bound
    /// node to its bind pose, accumulate each channel's contribution
    /// (`weight × 1/Σweights` when the sum exceeds 1), and write the
    /// blended TRS onto `SCNNode` transform fields plus morph weights
    /// onto `SCNMorpher`. Runs in `renderer(_:updateAtTime:)` — the
    /// spec's per-frame hook — on the render thread; `animLock`
    /// serializes against the mutation-thread ops.
    func sampleAnimations(at now: TimeInterval) {
        animLock.lock()
        defer { animLock.unlock() }
        let dt = lastAnimTime.map { now - $0 } ?? 0
        lastAnimTime = now
        // Recorded targets reset to bind pose and write every frame —
        // even with zero clips (upstream's update touches every
        // `_targetTransforms` entry, so a clip removal snaps its nodes
        // back to bind).
        guard !animClips.isEmpty || !animTargets.isEmpty else { return }

        // Advance + drop clips whose def was removed.
        for key in Array(animClips.keys) {
            guard let def = animationsById[key] else {
                animClips.removeValue(forKey: key)
                continue
            }
            var clip = animClips[key]!
            guard clip.playing, dt > 0 else { continue }
            var t = clip.time + dt * clip.timeScale
            if def.endTime == 0 {
                t = 0
            } else if !clip.loop, t < 0 || t > def.endTime {
                clip.playing = false
                t = min(max(t, 0), def.endTime)
            } else if t > def.endTime {
                t = abs(t).truncatingRemainder(dividingBy: def.endTime)
            } else if t < 0 {
                t = def.endTime
                    - abs(t).truncatingRemainder(dividingBy: def.endTime)
            }
            clip.time = t
            animClips[key] = clip
        }

        // Resolve bindings and total the clip weights — upstream
        // normalizes by Σ every registered clip's weight.
        var totalWeight = 0.0
        for clip in animClips.values { totalWeight += clip.weight }
        let mult = totalWeight > 1 ? 1 / totalWeight : 1

        /// Accumulating pose state for one bound node this frame.
        struct PoseAcc {
            var p = simd_float3()
            var r = simd_quatf(real: 1, imag: simd_float3())
            var s = simd_float3(repeating: 1)
            var weights: [Float]?
        }
        var accs: [UInt64: PoseAcc] = [:]

        // Channels apply in channel order; clips in id order (upstream
        // applies in registration order — key order is the stable
        // analog). Binding happens for EVERY clip — a zero-weight clip
        // still registers its nodes' bind poses and drives them (to
        // bind) per upstream's createAnimationClip; only the value
        // contribution gates on w.
        for animKey in animClips.keys.sorted() {
            guard let clip = animClips[animKey],
                  let def = animationsById[animKey] else { continue }
            let w = Float(clip.weight * mult)
            for ch in def.channels {
                guard let (nk, node) = animTarget(ch) else { continue }
                // Bind-pose capture — once, at first bind, never
                // re-captured while the entry lives (upstream's
                // corruption rule).
                if animTargets[nk] == nil {
                    animTargets[nk] = AnimTargetState(
                        bindP: simd_float3(node.position.x,
                                           node.position.y,
                                           node.position.z),
                        bindR: simd_quatf(
                            real: node.orientation.w,
                            imag: simd_float3(node.orientation.x,
                                                   node.orientation.y,
                                                   node.orientation.z)),
                        bindS: simd_float3(node.scale.x, node.scale.y,
                                           node.scale.z))
                }
                var st = animTargets[nk]!
                var acc = accs[nk] ?? PoseAcc(
                    p: st.bindP, r: st.bindR, s: st.bindS,
                    weights: st.bindWeights)
                switch ch.kind {
                case .translation:
                    st.drivesTransform = true
                    if w > 0, let v = sampleVec3(ch, clip.time) {
                        acc.p += (v - st.bindP) * w
                    }
                case .scale:
                    st.drivesTransform = true
                    if w > 0, let v = sampleVec3(ch, clip.time) {
                        // Multiplicative vs bind scale — lerp(1,
                        // v/bind, w) then multiply in (upstream's
                        // ScaleTimelineResolver).
                        let f = simd_float3(repeating: 1)
                            + (v / st.bindS
                               - simd_float3(repeating: 1)) * w
                        acc.s *= f
                    }
                case .rotation:
                    st.drivesTransform = true
                    if w > 0, let v = sampleQuat(ch, clip.time) {
                        acc.r = simd_slerp(acc.r, v, w)
                    }
                case .weights:
                    // Capture rest weights once — the node without a
                    // morpher keeps nil and the channel no-ops.
                    if st.bindWeights == nil, let m = node.morpher {
                        st.bindWeights = (0..<m.targets.count).map {
                            Float(m.weight(forTargetAt: $0))
                        }
                    }
                    if let bind = st.bindWeights {
                        if acc.weights == nil { acc.weights = bind }
                        if w > 0 {
                            let n = min(ch.targetCount, bind.count)
                            for i in 0..<n {
                                let v = sampleWeight(ch, clip.time, i)
                                acc.weights![i] += (v - bind[i]) * w
                            }
                        }
                    }
                }
                animTargets[nk] = st
                accs[nk] = acc
            }
        }

        // Write back: bound nodes get their accumulated pose; recorded
        // nodes no channel bound this frame reset to bind — upstream
        // writes every `_targetTransforms` entry each update.
        var stale: [UInt64] = []
        for (nk, st) in animTargets {
            guard let node = nodesById[nk] else {
                stale.append(nk)
                continue
            }
            let acc = accs[nk] ?? PoseAcc(
                p: st.bindP, r: st.bindR, s: st.bindS,
                weights: st.bindWeights)
            if st.drivesTransform {
                node.position = SCNVector3(acc.p.x, acc.p.y, acc.p.z)
                node.orientation = SCNQuaternion(
                    acc.r.imag.x, acc.r.imag.y, acc.r.imag.z,
                    acc.r.real)
                node.scale = SCNVector3(acc.s.x, acc.s.y, acc.s.z)
            }
            if let weights = acc.weights, let m = node.morpher {
                for i in 0..<min(weights.count, m.targets.count) {
                    m.setWeight(CGFloat(weights[i]), forTargetAt: i)
                }
            }
        }
        for nk in stale { animTargets.removeValue(forKey: nk) }
    }

    /// Channel binding — `target` id first, `targetName` fallback
    /// (upstream's `skin_animation.dart` order). The id path returns
    /// the node under its own key; the name path scans the registry so
    /// a retargeted clone still binds.
    private func animTarget(_ ch: FsceneRealizer.DecodedChannel)
        -> (UInt64, SCNNode)? {
        if let node = nodesById[ch.target] { return (ch.target, node) }
        guard let name = ch.targetName, !name.isEmpty else { return nil }
        for (k, n) in nodesById where n.name == name {
            return (k, n)
        }
        return nil
    }

    /// Upstream `TimelineResolver._getTimelineKey`: the index of the
    /// first key at-or-after `t` and the lerp back to the previous key
    /// (1 means "exactly on a key / out of range" → take the key as-is).
    private func timelineKey(_ times: [Double], _ t: Double)
        -> (index: Int, lerp: Double) {
        guard times.count > 1, let first = times.first,
              t > first else { return (0, 1) }
        if t >= times.last! { return (times.count - 1, 1) }
        var next = times.count - 1
        for i in 0..<times.count where times[i] >= t {
            next = i
            break
        }
        let prev = next - 1
        let span = times[next] - times[prev]
        return (next, span > 0 ? (t - times[prev]) / span : 1)
    }

    private func sampleVec3(_ ch: FsceneRealizer.DecodedChannel,
                            _ t: Double) -> simd_float3? {
        guard !ch.vec3.isEmpty, !ch.times.isEmpty else { return nil }
        let key = timelineKey(ch.times, t)
        let i = min(key.index, ch.vec3.count - 1)
        var v = ch.vec3[i]
        if key.lerp < 1, i > 0 {
            v = simd_mix(ch.vec3[i - 1], v,
                         simd_float3(repeating: Float(key.lerp)))
        }
        return v
    }

    private func sampleQuat(_ ch: FsceneRealizer.DecodedChannel,
                            _ t: Double) -> simd_quatf? {
        guard !ch.quat.isEmpty, !ch.times.isEmpty else { return nil }
        let key = timelineKey(ch.times, t)
        let i = min(key.index, ch.quat.count - 1)
        var v = ch.quat[i]
        if key.lerp < 1, i > 0 {
            v = simd_slerp(ch.quat[i - 1], v, Float(key.lerp))
        }
        return v
    }

    /// One target's keyframed morph weight at `t` — the flattened
    /// `targetCount`-per-key layout, linear between bracketing keys.
    private func sampleWeight(_ ch: FsceneRealizer.DecodedChannel,
                              _ t: Double, _ target: Int) -> Float {
        let tc = ch.targetCount
        guard tc > 0, !ch.times.isEmpty,
              target < tc else { return 0 }
        let key = timelineKey(ch.times, t)
        let i = min(key.index, ch.times.count - 1)
        var v = ch.weights[i * tc + target]
        if key.lerp < 1, i > 0 {
            let p = ch.weights[(i - 1) * tc + target]
            v = p + (v - p) * Float(key.lerp)
        }
        return v
    }

    // MARK: - Realizer interface

    /// Returns the bound scene to a clean slate so `realize` can
    /// decode the replacement document into it in place. Runs inside
    /// the drain — every write targets the rendered scene from its own
    /// update callback, the mutation window SceneKit sanctions.
    /// Joint behaviors detach while their bodies are certainly alive
    /// — the sweep below kills the nodes they constrain — and
    /// stage-owned fields clear to `SCNScene()` defaults: a deferred
    /// env leaves both contents slots untouched until its payload
    /// lands, so the replaced document's look must not linger.
    func beginSceneReset() {
        guard let scene else { return }
        jointLock.lock()
        for (id, rec) in joints where rec.behavior != nil {
            scene.physicsWorld.removeBehavior(rec.behavior!)
            retire(rec.behavior!)
            joints[id]?.behavior = nil
        }
        // Exclusion state dies with the scene's bodies — records
        // re-exclude as they re-realize on the new scene's bodies.
        for id in joints.keys { joints[id]?.excluded = false }
        jointPrivBits.removeAll()
        jointWireMasks.removeAll()
        jointExcludedPairs.removeAll()
        jointLock.unlock()
        for child in scene.rootNode.childNodes {
            child.removeFromParentNode()
            retire(child)
        }
        scene.background.contents = nil
        scene.lightingEnvironment.contents = nil
        scene.fogStartDistance = 0
        scene.fogEndDistance = 0
        scene.fogDensityExponent = 1
        scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        scene.physicsWorld.timeStep = 1.0 / 60.0
        worldGravityScale = 9.8
        worldAnchorNode = nil
    }

    /// Installs a freshly realized scene. Called by `FsceneRealizer`.
    /// The resource registries are retained so `upsertResource`/
    /// `upsertPayload` can re-decode and rebind single resources
    /// without a full re-realize.
    func install(
        scene newScene: SCNScene,
        nodes: [UInt64: SCNNode],
        resources: (geometries: [UInt64: SCNGeometry],
                    materials: [UInt64: SCNMaterial],
                    textures: [UInt64: FsceneRealizer.DecodedTexture],
                    defs: [UInt64: [String: Any]],
                    payloadSpecs:
                        [UInt64: FsceneRealizer.Context.PayloadSpec],
                    instanceSpecs: [UInt64: [String: Any]],
                    textureConsumers:
                        [UInt64: [FsceneRealizer.TextureBinding]],
                    materialConsumers: [UInt64: [SCNGeometry]],
                    geometryConsumers: [UInt64: [SCNNode]],
                    texturePayloadKeys: [UInt64: UInt64],
                    geometryPayloadKeys: [UInt64: Set<UInt64>],
                    environmentPayloadKeys: [UInt64: UInt64],
                    lutPayloadKeys: [UInt64: UInt64],
                    skins:
                        [UInt64: FsceneRealizer.DecodedSkin],
                    animations:
                        [UInt64: FsceneRealizer.DecodedAnimation],
                    morphTargets:
                        [UInt64: FsceneRealizer.DecodedMorph],
                    nodeSkinKeys: [UInt64: UInt64],
                    pendingSkinNodes: Set<UInt64>,
                    skinPayloadKeys: [UInt64: UInt64],
                    animPayloadKeys: [UInt64: Set<UInt64>],
                    skinDefs: [UInt64: [String: Any]],
                    animDefs: [UInt64: [String: Any]],
                    variantComponents:
                        [UInt64: FsceneRealizer.VariantComponentSpec],
                    disabledComponents: [UInt64: Set<Int>],
                    trails: [UInt64: FsceneRealizer.TrailState],
                    lods: [UInt64: FsceneRealizer.LodSpec],
                    lodResourceConsumers: [UInt64: Set<UInt64>],
                    pendingLodNodes: Set<UInt64>,
                    renderTargets: [UInt64: RenderTargetRec]),
        deferred: Set<UInt64>,
        camera: SCNNode?,
        dynamicBodies: Set<UInt64>,
        colliderIndices: [UInt64: Int],
        formatVersion: Int,
        stage: (json: [String: Any]?, exposure: Double,
                effects: StageEffects?, antiAliasing: String,
                renderScale: Double, filterQuality: String),
        views: [ViewRec]
    ) {
        // Joint behaviors were detached from the world at reset —
        // before the node sweep killed their bodies and before this
        // decode's own joints registered. The scene object itself is
        // only retired when it is actually replaced (a pre-setup
        // fallback): in-place realizes keep it bound.
        if let old = scene, old !== newScene { retire(old) }
        // W14: the outgoing offscreen machinery dies with the replaced
        // scene — its SCNRenderers hold that scene's graph, and its
        // textures may still be bound as material contents sampled by
        // the in-flight pass, so everything goes to the graveyard.
        teardownRenderTargets()
        scene = newScene
        newScene.physicsWorld.contactDelegate = self
        nodesById = nodes
        nodeToKey = Dictionary(uniqueKeysWithValues:
            nodes.map { (ObjectIdentifier($0.value), $0.key) })
        colliderIndexByKey = colliderIndices
        geometriesById = resources.geometries
        materialsById = resources.materials
        texturesById = resources.textures
        resourceDefs = resources.defs
        payloadSpecs = resources.payloadSpecs
            .merging(opPayloadSpecs) { _, op in op }
        instanceSpecs = resources.instanceSpecs
        textureConsumers = resources.textureConsumers
        materialConsumers = resources.materialConsumers
        geometryConsumers = resources.geometryConsumers
        texturePayloadKeys = resources.texturePayloadKeys
        geometryPayloadKeys = resources.geometryPayloadKeys
        environmentPayloadKeys = resources.environmentPayloadKeys
        lutPayloadKeys = resources.lutPayloadKeys
        // W14: the rt records arrive with empty view lists — the
        // decoded views distribute onto them below.
        renderTargets = resources.renderTargets
        self.views = views
        // W11 stores — clips and captured bind poses belonged to the
        // replaced scene, so the runtime resets too (a doc's animations
        // start clip-less and paused; nothing autoplays).
        skinsById = resources.skins
        animationsById = resources.animations
        morphTargetsById = resources.morphTargets
        nodeSkinKeys = resources.nodeSkinKeys
        pendingSkinNodes = resources.pendingSkinNodes
        skinPayloadKeys = resources.skinPayloadKeys
        animPayloadKeys = resources.animPayloadKeys
        skinDefs = resources.skinDefs
        animDefs = resources.animDefs
        // W12: variant bindings belong to the installing document;
        // unresolved ones stay pending and retry on landings.
        variantComponents = resources.variantComponents
        disabledComponents = resources.disabledComponents
        // W16: trail/lod runtime state belongs to the installing
        // document — the replaced scene's children and levels die
        // with their nodes (the trail's path is runtime state and
        // never persists, upstream's codec rule).
        trailStates = resources.trails
        lodSpecs = resources.lods
        lodResourceConsumers = resources.lodResourceConsumers
        pendingLodNodes = resources.pendingLodNodes
        lastTrailTime = nil
        animLock.lock()
        animClips.removeAll()
        animTargets.removeAll()
        lastAnimTime = nil
        animLock.unlock()
        deferredResourceIds = deferred
        dynamicBodyKeys = dynamicBodies
        quietTicks.removeAll()
        lastFormatVersion = formatVersion
        lastStage = stage.json
        stageAntiAliasing = stage.antiAliasing
        stageRenderScale = stage.renderScale
        stageFilterQuality = stage.filterQuality
        // W13: absent `effects` key → keep the prior decode.
        if let fx = stage.effects { lastEffects = fx }
        lastAwakeCount = 0
        // Armed probes belonged to the replaced scene — fail their
        // queries fast instead of leaving the replies hanging.
        overlapLock.lock()
        let stranded = pendingOverlaps
        pendingOverlaps.removeAll()
        overlapLock.unlock()
        for item in stranded {
            item.probe.removeFromParentNode()
            retire(item.probe)
            queryError(item.q, "scene reloaded")
        }
        // Joint behaviors were detached from the replaced world at the
        // top of install — every record re-realizes against the new
        // bodies; endpoints still missing re-defer. The pair-mask
        // settle then converges whatever the pre-install registry
        // couldn't see.
        retryPendingJoints()
        settleJointPairMasks()
        if let camera {
            pointOfView = camera
            fallbackCameraNode = nil
        } else {
            // No camera in the doc — install a default so content renders.
            let cam = SCNNode()
            cam.camera = SCNCamera()
            cam.position = SCNVector3(0, 0, 5)
            newScene.rootNode.addChildNode(cam)
            pointOfView = cam
            fallbackCameraNode = cam
        }
        docPov = pointOfView
        // W14: distribute the decoded views onto their rt records, let
        // a screen view's camera take the point of view (displacing
        // the doc/fallback pick), then apply stage quality before the
        // exposure/effects writes reach every view camera.
        installViews()
        applyScreenViewCamera()
        applyStageQuality()
        applyStageExposure(stage.exposure)
        applyStageEffects()
    }
}

// MARK: - Settle detection (SCNSceneRendererDelegate)
//
// SceneKit steps physics with the render loop (no public step API — and
// none needed: the sim owns the bodies). After each simulated step we
// count awake dynamic bodies and fire on transitions: 0→>0 is `awake`,
// >0→0 is `settled` with each body's final world pose converted back to
// `.fscene` space (position negates z; quaternion applies the same
// (−x,−y,z,w) map — both conversions are involutions).
extension SceneViewHost: SCNSceneRendererDelegate {
    /// W11 per-frame hook — the animation sampler. Runs before physics
    /// (updateAtTime precedes the sim step in SceneKit's render loop)
    /// so a sampled transform lands in this frame's pose.
    func renderer(_ renderer: SCNSceneRenderer,
                  updateAtTime time: TimeInterval) {
        drainPendingWork()
        sampleAnimations(at: time)
        // W16: trails record after the sampler — the head follows
        // this frame's sampled pose; lods then re-select and rebind
        // against this frame's camera (Android's `updateTrailsLods`
        // slot — post-camera, pre-render).
        updateTrails(at: time)
        updateLods()
    }

    /// W16 per-frame trail pass — `TrailComponent.update` ported:
    /// record the node's world position, then rebase the path into
    /// node-local space and rebuild the camera-facing ribbon. The
    /// ribbon geometry rebuilds each frame (a fresh `SCNGeometry`
    /// gets fresh bounds — a shared geometry could cull on stale
    /// ones); the outgoing one retires to the graveyard.
    private func updateTrails(at time: TimeInterval) {
        let dt = lastTrailTime.map { time - $0 } ?? 0
        lastTrailTime = time
        guard !trailStates.isEmpty, let pov = pointOfView else {
            return
        }
        let camWorld = simd_float3(
            Float(pov.simdWorldPosition.x),
            Float(pov.simdWorldPosition.y),
            Float(pov.simdWorldPosition.z))
        for (key, st) in trailStates {
            // Hidden nodes still tick upstream — the `d3trail:`
            // child hides with the node's subtree for free.
            guard let node = nodesById[key] else { continue }
            let wm = node.simdWorldTransform
            let world = simd_float3(
                wm.columns.3.x, wm.columns.3.y, wm.columns.3.z)
            st.record(dt: dt, world: world)
            rebuildTrailRibbon(st, node: node, camWorld: camWorld)
        }
    }

    /// Rebuilds the ribbon geometry for one frame: the recorded
    /// world points transform into the node's local space (the
    /// `d3trail:` child inherits the transform — the trail hangs in
    /// the world where the node has been, upstream's rebase), then
    /// each anchor expands toward the camera along
    /// `normalize(tangent × view)` — upstream's `expandPolyline`
    /// path. Dead strip verts (beyond the live tail) collapse onto
    /// the last anchor with zero width/alpha, keeping the topology
    /// fixed like upstream's `_TrailGeometry.setTrail`.
    private func rebuildTrailRibbon(
        _ st: FsceneRealizer.TrailState, node: SCNNode,
        camWorld: simd_float3
    ) {
        let live = min(st.points.count, st.maxPoints)
        st.child.isHidden = live < 2
        guard live >= 2 else { return }
        let inv = simd_inverse(node.simdWorldTransform)
        let localCam = inv * simd_float4(camWorld, 1)
        let n = st.maxPoints
        var local = [simd_float3](
            repeating: simd_float3(), count: n)
        var widths = [Float](repeating: 0, count: n)
        var colors = [simd_float4](
            repeating: simd_float4(), count: n)
        for i in 0..<n {
            let c = min(i, live - 1)
            let t = live > 1 ? Double(c) / Double(live - 1) : 0
            let p = inv * simd_float4(st.points[c], 1)
            local[i] = simd_float3(p.x, p.y, p.z)
            if i < live {
                widths[i] = Float(st.width * st.widthAt(t))
                let col = st.colorAt(t)
                colors[i] = col
            } else {
                // Beyond the tail: upstream writes the clamped
                // position, zero width and zero alpha.
                let col = st.colorAt(t)
                colors[i] = simd_float4(col.x, col.y, col.z, 0)
            }
        }
        var pos = [Float](repeating: 0, count: n * 6)
        var col = [Float](repeating: 0, count: n * 8)
        let cam3 = simd_float3(localCam.x, localCam.y, localCam.z)
        var lastSide = simd_float3(1, 0, 0)
        let up = simd_float3(0, 1, 0)
        for i in 0..<n {
            let prev = local[i == 0 ? 0 : i - 1]
            let next = local[i == n - 1 ? n - 1 : i + 1]
            var tangent = prev - next
            if simd_length_squared(tangent) < 1e-12, n > 1 {
                tangent = i == 0
                    ? local[0] - local[1]
                    : local[i - 1] - local[i]
            }
            var side = lastSide
            if simd_length_squared(tangent) >= 1e-12 {
                let view = cam3 - local[i]
                let c = simd_cross(tangent, view)
                if simd_length_squared(c) >= 1e-12 {
                    side = simd_normalize(c)
                } else {
                    let f = simd_cross(tangent, up)
                    side = simd_length_squared(f) >= 1e-12
                        ? simd_normalize(f)
                        : simd_normalize(
                            simd_cross(tangent, simd_float3(1, 0, 0)))
                }
            }
            lastSide = side
            let half = widths[i] * 0.5
            let l = local[i] + side * half
            let r = local[i] - side * half
            pos[i * 6] = l.x; pos[i * 6 + 1] = l.y
            pos[i * 6 + 2] = l.z
            pos[i * 6 + 3] = r.x; pos[i * 6 + 4] = r.y
            pos[i * 6 + 5] = r.z
            let c = colors[i]
            col[i * 8] = c.x; col[i * 8 + 1] = c.y
            col[i * 8 + 2] = c.z; col[i * 8 + 3] = c.w
            col[i * 8 + 4] = c.x; col[i * 8 + 5] = c.y
            col[i * 8 + 6] = c.z; col[i * 8 + 7] = c.w
        }
        let posSource = SCNGeometrySource(
            data: pos.withUnsafeBytes { Data($0) },
            semantic: .vertex, vectorCount: n * 2,
            usesFloatComponents: true, componentsPerVector: 3,
            bytesPerComponent: 4, dataOffset: 0, dataStride: 12)
        let colSource = SCNGeometrySource(
            data: col.withUnsafeBytes { Data($0) },
            semantic: .color, vectorCount: n * 2,
            usesFloatComponents: true, componentsPerVector: 4,
            bytesPerComponent: 4, dataOffset: 0, dataStride: 16)
        let geo = SCNGeometry(
            sources: [posSource, colSource, st.normalSource],
            elements: [st.indexElement])
        geo.materials = [FsceneRealizer.TrailState.material]
        if let old = st.child.geometry, old !== geo { retire(old) }
        st.child.geometry = geo
    }

    /// W16 per-frame LOD pass — Android's `updateLod`
    /// (FsceneRealizer.kt) ported field-for-field: upstream
    /// `_resolveLod`. This replaces the earlier `SCNLevelOfDetail`
    /// delegation, which probe-verified can't reproduce the upstream
    /// metric (its `screenSpaceRadius` is a max-projection-axis,
    /// half-viewport-diagonal measure on view depth, and the tight
    /// level-0 bounding sphere isn't overridable).
    private func updateLods() {
        guard !lodSpecs.isEmpty,
              let pov = pointOfView, let cam = pov.camera
        else { return }
        let perspective = !cam.usesOrthographicProjection
        // `fovRadiansY` decodes onto a `.vertical` fieldOfView
        // (degrees); a horizontal-declared fov converts through the
        // viewport aspect.
        var fovRadY = Double(cam.fieldOfView) * .pi / 180
        if cam.projectionDirection == .horizontal {
            let aspect =
                Double(bounds.width) / Double(max(bounds.height, 1))
            fovRadY = 2 * atan(tan(fovRadY / 2) / max(aspect, 1e-9))
        }
        // Both positions live in the same LH→RH-mirrored space — a
        // mirror is an isometry, so the Euclidean distances the
        // metric wants match the authored ones.
        let camPos = simd_float3(
            Float(pov.simdWorldPosition.x),
            Float(pov.simdWorldPosition.y),
            Float(pov.simdWorldPosition.z))
        for (key, spec) in lodSpecs where !spec.suspended {
            guard let node = nodesById[key] else { continue }
            updateLod(spec, node: node, camPos: camPos,
                      fovRadY: fovRadY, perspective: perspective)
        }
    }

    /// One node's selection for this frame: the level-0 local AABB's
    /// 8 corners through the node's world transform give the world
    /// AABB (rotation and non-uniform scale both land); its
    /// circumscribed sphere — center plus half-diagonal radius —
    /// projects through upstream `lodScreenSize`: `∞` when the
    /// camera is inside, else `radius / (dist·tan(fovY/2))` at the
    /// Euclidean distance. `lodBias` scales the size, then the
    /// `hysteresis` dead-band picks against the descending
    /// thresholds with `spec.bound` as memory; `-1` culls. A
    /// non-perspective camera or an unresolved level set binds
    /// level 0 — upstream's orthographic/unresolved rules.
    private func updateLod(_ spec: FsceneRealizer.LodSpec,
                           node: SCNNode, camPos: simd_float3,
                           fovRadY: Double, perspective: Bool) {
        if !perspective || !spec.resolved {
            bindLodLevel(spec, node, 0)
            return
        }
        let m = node.simdWorldTransform
        var lo = simd_float3(repeating: Float.greatestFiniteMagnitude)
        var hi = simd_float3(repeating: -Float.greatestFiniteMagnitude)
        for xs in [spec.boundMin.x, spec.boundMax.x] {
            for ys in [spec.boundMin.y, spec.boundMax.y] {
                for zs in [spec.boundMin.z, spec.boundMax.z] {
                    let w = m * simd_float4(xs, ys, zs, 1)
                    lo = simd_min(lo, simd_float3(w.x, w.y, w.z))
                    hi = simd_max(hi, simd_float3(w.x, w.y, w.z))
                }
            }
        }
        // The circumscribed sphere — upstream's conservative choice
        // (detail kept slightly longer than a tight sphere would).
        let center = (lo + hi) * 0.5
        let radius = Double(simd_length(hi - lo) * 0.5)
        let dist = Double(simd_length(center - camPos))
        let size = dist <= radius
            ? Double.infinity
            : radius / (dist * tan(fovRadY * 0.5))
        let sel = SceneViewHost.selectLodLevel(
            size * spec.lodBias,
            thresholds: spec.levels.map { $0.screenSize },
            hysteresis: spec.hysteresis,
            currentLevel: spec.bound)
        bindLodLevel(spec, node, sel)
    }

    /// Upstream `selectLodLevel` — the first level whose descending
    /// threshold the (already biased) `size` meets, then the
    /// `hysteresis` dead-band around `currentLevel`'s boundaries: an
    /// adjacent crossing holds until the size clears the boundary by
    /// the fractional margin — finer at `t·(1+h)`, coarser at
    /// `t·(1−h)`; the cull floor is the boundary below the last
    /// level in both directions. A non-adjacent jump switches
    /// immediately. `-1` culls below the smallest threshold (a last
    /// threshold of `0` never culls).
    private static func selectLodLevel(
        _ size: Double, thresholds: [Double],
        hysteresis: Double, currentLevel: Int
    ) -> Int {
        var naive = -1
        for (i, t) in thresholds.enumerated() {
            if size >= t {
                naive = i
                break
            }
        }
        if naive == currentLevel || hysteresis <= 0 { return naive }
        let last = thresholds.count - 1
        if currentLevel >= 1 && naive == currentLevel - 1 {
            return size >= thresholds[currentLevel - 1] * (1 + hysteresis)
                ? naive : currentLevel
        }
        if currentLevel >= 0 && naive == currentLevel + 1 {
            return size < thresholds[currentLevel] * (1 - hysteresis)
                ? naive : currentLevel
        }
        if currentLevel == last && naive == -1 {
            return size < thresholds[last] * (1 - hysteresis)
                ? -1 : currentLevel
        }
        if currentLevel == -1 && naive == last {
            return size >= thresholds[last] * (1 + hysteresis)
                ? naive : -1
        }
        return naive
    }

    /// Binds level `idx` of `spec` to `node.geometry` — the swap the
    /// frame pass drives, dirty-checked so an unchanged level doesn't
    /// rewrite the slot. `idx` -1 is the cull floor: the node's own
    /// geometry drops to nil while children keep drawing — the
    /// closest match to Android's `scene.removeEntity(entity)` unbind
    /// (which detaches the renderable without touching the subtree).
    /// `force` rebinds the same index: the resource-landing rebind's
    /// fresh copies must replace the bound ones.
    func bindLodLevel(_ spec: FsceneRealizer.LodSpec, _ node: SCNNode,
                      _ idx: Int, force: Bool = false) {
        if spec.suspended { return }
        if idx < 0 {
            // Culled — only a bound level drops its geometry; `bound`
            // -1 also marks a never-bound spec, whose slot belongs to
            // whatever wrote it (a pending mesh's geometry).
            if spec.bound >= 0 {
                node.geometry = nil
                spec.bound = -1
            }
            return
        }
        if !force && spec.bound == idx { return }
        guard idx < spec.geoCopies.count else { return }
        let g = spec.geoCopies[idx]
        if let old = node.geometry, old !== g,
           !spec.geoCopies.contains(where: { $0 === old }) {
            // A foreign geometry (a `mesh`'s) retires here; the
            // spec's own level copies stay alive on the spec.
            retire(old)
        }
        node.geometry = g
        spec.bound = idx
        spec.ownsRenderable = true
    }

    /// W14: post-physics, pre-drawable — the offscreen passes draw the
    /// same pose the screen frame is about to. Only fires for the
    /// SCNView; the per-view SCNRenderers have no delegate set. W24:
    /// sibling proxies sync in the same hook so their poke-drawn
    /// frames share this pose.
    func renderer(_ renderer: SCNSceneRenderer,
                  willRenderScene scene: SCNScene,
                  atTime time: TimeInterval) {
        renderDueTargets(at: time)
        syncScreenSubviews()
    }

    /// W15: the frame carrying a just-applied subtree is the first
    /// it's visible in — stamped for the latency measurement (the
    /// Dart side logs the send time against this). `atTime` is the
    /// frame's scheduled time — it can precede the apply wall stamp
    /// by a few ms, so the delta measures against a fresh uptime
    /// taken inside the callback (the Android twin does the same).
    func renderer(_ renderer: SCNSceneRenderer,
                  didRenderScene scene: SCNScene,
                  atTime time: TimeInterval) {
        // W24: the host's completed frame is the siblings' signal to
        // draw — poke before the early-out below.
        pokeScreenSubviews()
        guard let stamp = subtreeVisibleStamp else { return }
        subtreeVisibleStamp = nil
        let now = ProcessInfo.processInfo.systemUptime
        d3Log("\(stamp.op) node=\(stamp.node) ops=\(stamp.count)"
            + " visible t=\(now)"
            + " applyToVisible=\((now - stamp.applied) * 1000)ms")
    }

    func renderer(_ renderer: SCNSceneRenderer,
                  didSimulatePhysicsAtTime time: TimeInterval) {
        var awake = 0
        // Quiet floor — gravity-scaled so an m-scale world keeps
        // sub-m/s sensitivity while a mm-scale world treats ±50 u/s
        // of contact noise as stillness. Angular speed uses the same
        // scale: |g|^0.5 ≈ angular-noise growth with gravity.
        let epsLin = max(worldGravityScale * 0.006, 0.05)
        let epsAng = max(worldGravityScale.squareRoot() * 0.05, 0.05)
        for key in dynamicBodyKeys {
            guard let body = nodesById[key]?.physicsBody,
                  !body.isResting else {
                quietTicks[key] = 0
                continue
            }
            let v = body.velocity
            let lin2 = Double(v.x * v.x + v.y * v.y + v.z * v.z)
            // SCNVector4: x/y/z is the axis, w the magnitude (rad/s).
            let w = Double(body.angularVelocity.w)
            if lin2 < epsLin * epsLin && w * w < epsAng * epsAng {
                let t = (quietTicks[key] ?? 0) + 1
                quietTicks[key] = t
                if t < 30 { awake += 1 }   // ~0.5s quiet → asleep
            } else {
                quietTicks[key] = 0
                awake += 1
            }
        }
        _simTick += 1
        // Overlap probes armed ≥2 steps ago are registered and posed
        // in the world — run their contactTest and reply now.
        overlapLock.lock()
        let ready = pendingOverlaps.filter {
            $0.armedTick + 2 <= _simTick
        }
        pendingOverlaps.removeAll { $0.armedTick + 2 <= _simTick }
        overlapLock.unlock()
        for item in ready {
            replyOverlap(item.q, item.probe)
            item.probe.removeFromParentNode()
            retire(item.probe)
        }
        pollJointBreaks()
        if _simTick % (awake > 0 ? 3 : 60) == 0 {
            let states = dynamicBodyKeys.map { key -> String in
                guard let n = nodesById[key] else { return "\(key):gone" }
                let p = n.presentation.worldPosition
                return String(format: "%@:p=(%.2f,%.2f,%.2f)", "\(key)",
                              p.x, p.y, p.z)
                    + " rest=\(n.physicsBody?.isResting ?? true)"
            }
            d3Log("sim tick \(time.formatted(.number.precision(.fractionLength(2))))"
                + " dyn=\(dynamicBodyKeys.count) awake=\(awake)"
                + " [\(states.joined(separator: " "))]")
        }
        if awake > 0, lastAwakeCount == 0 {
            fireEvent(type: 1, payload: "{\"awake\":\(awake)}")
        } else if awake == 0, lastAwakeCount > 0, !dynamicBodyKeys.isEmpty {
            var parts: [String] = []
            for key in dynamicBodyKeys {
                guard let node = nodesById[key] else { continue }
                let p = node.presentation.worldPosition
                let q = node.presentation.worldOrientation
                let s = UInt32(key >> 32), i = UInt32(key & 0xFFFFFFFF)
                parts.append(
                    "{\"s\":\(s),\"i\":\(i),"
                    + "\"p\":[\(p.x),\(p.y),\(-p.z)],"
                    + "\"r\":[\(-q.x),\(-q.y),\(q.z),\(q.w)]}"
                )
            }
            fireEvent(type: 2,
                      payload: "{\"nodes\":[\(parts.joined(separator: ","))]}")
        }
        lastAwakeCount = awake
    }

    /// W9 break polling — geometric, since SceneKit reports no
    /// constraint forces: each simulated step, a joint whose world
    /// anchors have separated past `breakDistance` loses its behavior
    /// and fires the `broke` joint event (D3Event type 5). Anchor
    /// world positions read the presentation nodes, like the settle
    /// and query paths.
    private func pollJointBreaks() {
        var broke: [(id: UInt32, a: UInt64, b: UInt64?)] = []
        jointLock.lock()
        for (id, rec) in joints {
            guard rec.behavior != nil, let bd = rec.breakDistance,
                  let na = nodesById[rec.a],
                  let nb = rec.b.flatMap({ nodesById[$0] })
                          ?? worldAnchorNode
            else { continue }
            let wa = na.presentation.convertPosition(rec.anchorA, to: nil)
            let wb = nb.presentation.convertPosition(rec.anchorB, to: nil)
            let dx = wa.x - wb.x, dy = wa.y - wb.y, dz = wa.z - wb.z
            if Double(dx * dx + dy * dy + dz * dz) > bd * bd {
                broke.append((id, rec.a, rec.b))
            }
        }
        for item in broke { dropJointLocked(item.id) }
        jointLock.unlock()
        for item in broke {
            fireEvent(type: 5, payload: "{\"kind\":\"broke\","
                + "\"id\":\(item.id),\"a\":\(refJSON(item.a)),"
                + "\"b\":\(item.b.map(refJSON) ?? "null")}")
        }
    }

    /// Hops to the main thread (renderer callbacks are not guaranteed to
    /// arrive there) and fires one event frame through the plugin slot.
    private func fireEvent(type: Int32, payload: String) {
        let token = viewId
        guard token != 0 else { return }
        DispatchQueue.main.async {
            d3FireToDart(token: token, type: type, payload: payload)
        }
    }
}

// MARK: - Contact events (SCNPhysicsContactDelegate)
//
// `contactTestBitMask = ~0` on every realized collider body keeps the
// delegate gate open for every pair — upstream reports all contacts,
// sensors included (a zero `collisionBitMask` suppresses only the
// response). `didUpdate` has no upstream counterpart and is not
// implemented. Callbacks arrive on the render thread; `fireEvent`
// hops to main like the settle path.
extension SceneViewHost: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld,
                      didBegin contact: SCNPhysicsContact) {
        fireContact(contact, began: true)
    }

    func physicsWorld(_ world: SCNPhysicsWorld,
                      didEnd contact: SCNPhysicsContact) {
        fireContact(contact, began: false)
    }

    /// Fires the wire contact event for one pair transition. A sensor
    /// collider on either side (zero `collisionBitMask`) swaps
    /// began/ended for triggerEntered/triggerExited; contact points
    /// ship only on `began`, converted back to `.fscene` space.
    private func fireContact(_ contact: SCNPhysicsContact,
                             began: Bool) {
        guard let ka = nodeToKey[ObjectIdentifier(contact.nodeA)],
              let kb = nodeToKey[ObjectIdentifier(contact.nodeB)]
        else { return }   // probes and already-removed nodes have no id
        let trigger = contact.nodeA.physicsBody?.collisionBitMask == 0
            || contact.nodeB.physicsBody?.collisionBitMask == 0
        let kind = began
            ? (trigger ? "triggerEntered" : "began")
            : (trigger ? "triggerExited" : "ended")
        var payload = "{\"kind\":\"\(kind)\",\"a\":\(refJSON(ka)),"
            + "\"ca\":\(colliderIndexByKey[ka] ?? 0),"
            + "\"b\":\(refJSON(kb)),\"cb\":\(colliderIndexByKey[kb] ?? 0)"
        if began && !trigger {
            let p = contact.contactPoint, n = contact.contactNormal
            payload += ",\"points\":[{\"p\":[\(p.x),\(p.y),\(-p.z)],"
                + "\"n\":[\(n.x),\(n.y),\(-n.z)],"
                + "\"imp\":\(contact.collisionImpulse),"
                + "\"sep\":\(-contact.penetrationDistance)}]"
        }
        payload += "}"
        fireEvent(type: 3, payload: payload)
    }
}
