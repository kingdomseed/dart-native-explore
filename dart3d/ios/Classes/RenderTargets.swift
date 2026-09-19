import Foundation
import Metal
import SceneKit

/// W14: render textures and views. W24 adds iOS split-screen.
///
/// A `kind:'renderTexture'` resource realizes to an `MTLTexture` pair
/// the offscreen passes draw into; a material slot referencing it binds
/// the color texture live (FsceneRealizer `applyTextureSlot`). The
/// top-level `views` array declares per-camera draws — `target` absent
/// means the screen, `target:'rt:<tok>'` draws into that rt via an
/// `SCNRenderer` sharing the SAME scene object, scheduled from
/// `renderer(_:willRenderScene:atTime:)` so the pass sees the same
/// post-physics pose as the screen frame.
///
/// Screen views (W24): a single target-absent view with no `viewport`
/// keeps the W14 path — its camera takes the host `SCNView`'s
/// `pointOfView`. Two or more screen views, or any `viewport` rect,
/// switch to split mode: the host's point of view becomes a blank
/// camera (mask 0 — its pass contributes clear/background only) and
/// every screen view owns a sibling `SCNView` laid out over the host
/// at its rect (`[l,b,w,h]` target pixels, bottom-left origin; absent
/// rect = full bounds), added in `order` so later views draw on top.
/// A sibling is `isPlaying:false` + `rendersContinuously:false` — it
/// shares the scene object but advances no scene time of its own (no
/// second physics step); the host's delegate syncs each sibling's
/// point of view in `willRenderScene` and pokes `setNeedsDisplay` in
/// `didRenderScene`, so sibling draws follow the host's frame.
///
/// Update policies: `everyFrame` draws every vsync, `interval` draws
/// when `intervalMilliseconds` have elapsed since the last pass,
/// `manual` draws once per `{"op":"render"}` dirty mark. A fresh or
/// upserted rt starts dirty so the texture holds a frame before the
/// first explicit render.

/// One decoded `views` entry — the wire fields plus the texture-target
/// runtime (`renderer` is created lazily on the view's first due pass;
/// `msaa*` caches the multisample pair a resolved 'msaa' AA needs).
struct ViewRec {
    var cameraKey: UInt64          // node id — 'n:<tok>'
    var targetKey: UInt64?         // 'rt:<tok>'; nil → screen
    var layerMask: UInt32          // 0xFFFFFFFF (default) = all
    var order: Int
    var aaMode: String?            // 'none'|'msaa'|'fxaa'|'auto'
    var renderScale: Double?
    var filterQuality: String?
    var viewport: [Double]?        // dart3d ext — [l,b,w,h] target px, W24 screen views
    // Texture-target runtime — never populated on screen views.
    var renderer: SCNRenderer?
    var msaaColorTex: MTLTexture?
    var msaaDepthTex: MTLTexture?
    var msaaSamples = 1
}

/// W24 split-screen — the render-queue half of one screen view's
/// sibling `SCNView`: the rec snapshot it syncs from and the sibling's
/// point-of-view. `pov` is the real camera node for the lowest-order
/// view when resolvable (`drivesRealNode` — `allowsCameraControl` and
/// authored motion keep the single-view semantics) or a detached
/// proxy node whose transform+camera are copied in each frame. The
/// sibling `UIView` objects live in `mainScreenSubviews` (main
/// thread); the two lists pair by index.
struct ScreenSubview {
    var rec: ViewRec
    var pov: SCNNode
    var drivesRealNode: Bool
}

/// A `kind:'renderTexture'` resource record: the spec fields, the
/// color/depth pair every pass renders into (same allocation for all
/// the rt's views — they draw in `order`), and the schedule state.
struct RenderTargetRec {
    var width: Int
    var height: Int
    var update: String             // 'everyFrame' | 'interval' | 'manual'
    var intervalMilliseconds: Int?
    var filter: String             // 'linear' | 'nearest'
    var wrap: String               // 'clampToEdge' | 'repeat' | 'mirror'
    var colorTex: MTLTexture
    var depthTex: MTLTexture
    var views: [ViewRec] = []
    var lastRenderTime: TimeInterval?
    var dirty = true               // fresh texture → one pass so it holds a frame
}

// MARK: - Decode (FsceneRealizer.Context)

extension FsceneRealizer.Context {

    /// `kind:'renderTexture'` — allocates the Metal color/depth pair on
    /// the view's device and records the update/sampling spec. Runs in
    /// `decodeResources`' first pass (with `texture`) so material slots
    /// resolve rt refs in the rest pass.
    func decodeRenderTexture(_ key: UInt64, _ r: [String: Any]) {
        let w = (r["width"] as? NSNumber)?.intValue ?? 0
        let h = (r["height"] as? NSNumber)?.intValue ?? 0
        guard w > 0, h > 0 else {
            host.logOnce("w14.rt.\(key).dims",
                "renderTexture \(key): invalid width/height; skipped")
            return
        }
        var update = r["update"] as? String ?? "everyFrame"
        if update != "everyFrame" && update != "interval"
            && update != "manual" {
            host.logOnce("w14.rt.\(key).update.\(update)",
                "renderTexture \(key): unknown update '\(update)'; "
                + "using everyFrame")
            update = "everyFrame"
        }
        var filter = r["filter"] as? String ?? "linear"
        if filter != "linear" && filter != "nearest" {
            host.logOnce("w14.rt.\(key).filter.\(filter)",
                "renderTexture \(key): unknown filter '\(filter)'; "
                + "using linear")
            filter = "linear"
        }
        var wrap = r["wrap"] as? String ?? "clampToEdge"
        if wrap != "clampToEdge" && wrap != "repeat" && wrap != "mirror" {
            host.logOnce("w14.rt.\(key).wrap.\(wrap)",
                "renderTexture \(key): unknown wrap '\(wrap)'; "
                + "using clampToEdge")
            wrap = "clampToEdge"
        }
        guard let device = host.renderDevice() else {
            host.logOnce("w14.rt.\(key).device",
                "renderTexture \(key): no Metal device; skipped")
            return
        }
        // Color doubles as pass attachment and material contents; depth
        // is scratch. Both live GPU-side.
        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: host.colorPixelFormat, width: w, height: h,
            mipmapped: false)
        colorDesc.usage = [.renderTarget, .shaderRead]
        colorDesc.storageMode = .private
        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float, width: w, height: h,
            mipmapped: false)
        depthDesc.usage = .renderTarget
        depthDesc.storageMode = .private
        guard let colorTex = device.makeTexture(descriptor: colorDesc),
              let depthTex = device.makeTexture(descriptor: depthDesc)
        else {
            host.logOnce("w14.rt.\(key).alloc",
                "renderTexture \(key): texture allocation failed; skipped")
            return
        }
        renderTargets[key] = RenderTargetRec(
            width: w, height: h, update: update,
            intervalMilliseconds:
                (r["intervalMilliseconds"] as? NSNumber)?.intValue,
            filter: filter, wrap: wrap,
            colorTex: colorTex, depthTex: depthTex)
        d3Log("renderTexture \(key): \(w)x\(h) update=\(update)")
    }

    /// Top-level `views` decode — wholesale-replaces `views` (absent
    /// key → empty). `camera` is required and must resolve to a node
    /// (manifest pass reads `nodes`; a surgical ctx falls back to the
    /// live registry); `target` absent = screen, present = a live
    /// renderTexture id. Skipped entries warn once. Distribution into
    /// each rt record happens at `installViews`.
    func decodeViews(_ any: Any?) {
        views = []
        for entry in any as? [Any] ?? [] {
            guard let e = entry as? [String: Any] else { continue }
            // Contract tokens are plain strings; the tagged rref/nref
            // form is accepted for robustness.
            guard let camKey = (e["camera"] as? String)
                    .flatMap(D3Wire.localIdKey) ?? d3Ref(e["camera"])
            else {
                host.logOnce("w14.view.camera",
                    "view entry lacks a resolvable 'camera'; skipped")
                continue
            }
            guard resolveNode(camKey) != nil else {
                host.logOnce("w14.view.camera.\(camKey)",
                    "view camera node \(camKey) unresolved; view skipped")
                continue
            }
            var targetKey: UInt64?
            if let tk = (e["target"] as? String)
                    .flatMap(D3Wire.localIdKey) ?? d3Ref(e["target"]) {
                guard renderTargets[tk] != nil else {
                    host.logOnce("w14.view.target.\(tk)",
                        "view target \(tk) is not a live renderTexture; "
                        + "view skipped")
                    continue
                }
                targetKey = tk
            } else if let t = e["target"], !(t is NSNull) {
                host.logOnce("w14.view.targetToken",
                    "view 'target' is malformed; treating as screen")
            }
            views.append(ViewRec(
                cameraKey: camKey,
                targetKey: targetKey,
                layerMask: (e["layerMask"] as? NSNumber)
                    .map { UInt32(truncatingIfNeeded: $0.intValue) }
                    ?? UInt32.max,
                order: (e["order"] as? NSNumber)?.intValue ?? 0,
                aaMode: e["antiAliasing"] as? String
                    ?? d3String(e["antiAliasing"]),
                renderScale: (e["renderScale"] as? NSNumber)?.doubleValue
                    ?? d3Double(e["renderScale"]),
                filterQuality: e["filterQuality"] as? String
                    ?? d3String(e["filterQuality"]),
                viewport: (e["viewport"] as? [NSNumber])
                    .map { $0.map { $0.doubleValue } }))
        }
        // Feature-present warnings — decode time is when "requested"
        // is known.
        if views.contains(where: {
            $0.targetKey != nil && $0.renderScale != nil }) {
            host.logOnce("w14.renderScale.rt",
                "renderScale on a texture-target view is ignored on iOS")
        }
        if views.contains(where: { $0.filterQuality != nil }) {
            host.logOnce("w14.filterQuality.view",
                "per-view filterQuality unsupported on SceneKit; ignored")
        }
    }
}

// MARK: - Offscreen pass scheduler (SceneViewHost)

extension SceneViewHost {

    /// The Metal device every offscreen object is created on — the
    /// view's, so command buffers on `commandQueue` match; the system
    /// default is the same device in practice and covers decode
    /// running before the view's first frame.
    func renderDevice() -> MTLDevice? {
        device ?? MTLCreateSystemDefaultDevice()
    }

    /// The scheduler — runs from `renderer(_:willRenderScene:atTime:)`
    /// (post-physics, pre-drawable) so offscreen passes draw the same
    /// pose as the screen frame. Command buffers commit on the view's
    /// own queue ahead of the view's pass — no waitUntilCompleted; the
    /// frame boundary provides ordering.
    func renderDueTargets(at time: TimeInterval) {
        guard !renderTargets.isEmpty, let queue = commandQueue
        else { return }
        for key in renderTargets.keys.sorted() {
            guard let rec = renderTargets[key], !rec.views.isEmpty
            else { continue }
            let scheduled: Bool
            switch rec.update {
            case "interval":
                let seconds =
                    Double(rec.intervalMilliseconds ?? 0) / 1000.0
                scheduled = rec.lastRenderTime
                    .map { time - $0 >= seconds } ?? true
            case "manual":
                scheduled = false
            default:
                // 'everyFrame' — unknown strings decode-normalized.
                scheduled = true
            }
            // dirty forces one pass on any mode — that's the `render`
            // op's meaning; manual draws ONLY on dirty.
            guard scheduled || rec.dirty else { continue }
            // Clear BEFORE the passes: this frame's renders answer the
            // mark even when a view's camera fails to resolve.
            renderTargets[key]?.dirty = false
            renderTargets[key]?.lastRenderTime = time
            for i in rec.views.indices {
                renderTextureView(key: key, viewIndex: i, queue: queue)
            }
        }
    }

    /// One texture-target view's pass: resolve the camera, lazily build
    /// the SCNRenderer (SAME scene object — render-only, the SCNView
    /// owns update+simulate) and the MSAA pair when the resolved AA
    /// calls for it, then encode renderWithViewport and commit.
    private func renderTextureView(key: UInt64, viewIndex: Int,
                                   queue: MTLCommandQueue) {
        guard var rec = renderTargets[key],
              viewIndex < rec.views.count else { return }
        var view = rec.views[viewIndex]
        guard let camNode = nodesById[view.cameraKey],
              let cam = camNode.camera else {
            logOnce("w14.viewCam.\(view.cameraKey)",
                "view camera \(view.cameraKey) unresolved or "
                + "camera-less; pass skipped")
            return
        }
        // layerMask is the CAMERA's category mask — applied for the
        // pass then restored: a camera shared with a screen view keeps
        // that view's mask for the drawable draw (SceneKit captures
        // camera state at renderWithViewport encode, so the restore
        // can't leak into this pass).
        let savedMask = cam.categoryBitMask
        cam.categoryBitMask = view.layerMask == UInt32.max
            ? Int(bitPattern: UInt.max) : Int(view.layerMask)
        defer { cam.categoryBitMask = savedMask }
        if view.renderer == nil {
            let r = SCNRenderer(device: device)
            r.scene = scene
            view.renderer = r
        }
        let samples = resolvedViewAASamples(view)
        if samples > 1,
           view.msaaSamples != samples || view.msaaColorTex == nil {
            // A prior frame's pass may still be resolving through the
            // replaced pair — retire, don't drop.
            if let t = view.msaaColorTex { retire(t) }
            if let t = view.msaaDepthTex { retire(t) }
            view.msaaColorTex = msaaTexture(
                pixelFormat: rec.colorTex.pixelFormat,
                width: rec.width, height: rec.height, samples: samples)
            view.msaaDepthTex = msaaTexture(
                pixelFormat: .depth32Float,
                width: rec.width, height: rec.height, samples: samples)
            view.msaaSamples = samples
        } else if samples <= 1 {
            // AA dropped to single-sample — the pair is dead weight;
            // retire it and forget it.
            if let t = view.msaaColorTex { retire(t) }
            if let t = view.msaaDepthTex { retire(t) }
            view.msaaColorTex = nil
            view.msaaDepthTex = nil
            view.msaaSamples = 1
        }
        rec.views[viewIndex] = view
        renderTargets[key] = rec
        guard let renderer = view.renderer else { return }
        renderer.pointOfView = camNode

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor =
            MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1.0
        if samples > 1, view.msaaColorTex != nil,
           view.msaaDepthTex != nil {
            // MSAA: draw into the multisample pair, resolve into the
            // rt's color texture (depth has no resolve — dontCare).
            pass.colorAttachments[0].texture = view.msaaColorTex
            pass.colorAttachments[0].resolveTexture = rec.colorTex
            pass.colorAttachments[0].storeAction = .multisampleResolve
            pass.depthAttachment.texture = view.msaaDepthTex
            pass.depthAttachment.storeAction = .dontCare
        } else {
            pass.colorAttachments[0].texture = rec.colorTex
            pass.colorAttachments[0].storeAction = .store
            pass.depthAttachment.texture = rec.depthTex
            pass.depthAttachment.storeAction = .dontCare
        }
        guard let cb = queue.makeCommandBuffer() else { return }
        renderer.render(
            withViewport: CGRect(x: 0, y: 0,
                                 width: rec.width, height: rec.height),
            commandBuffer: cb, passDescriptor: pass)
        cb.commit()
    }

    /// Offscreen AA resolution — view mode (non-'auto') > stage
    /// (non-'auto') > the view's `antialiasingMode` (the viewConfig
    /// value or the .multisampling4X setup default). Returns the MSAA
    /// sample count; 1 = single-sample. 'fxaa' has no Metal attachment
    /// form — warn once, single-sample.
    func resolvedViewAASamples(_ v: ViewRec) -> Int {
        let req = v.aaMode.flatMap { $0 == "auto" ? nil : $0 }
            ?? (stageAntiAliasing != "auto" ? stageAntiAliasing : nil)
        if let req {
            switch req {
            case "none": return 1
            case "msaa": return 4
            default:
                logOnce("w14.aa.\(req)",
                    "antiAliasing '\(req)' unsupported on SceneKit "
                    + "offscreen passes; using none")
                return 1
            }
        }
        switch antialiasingMode {
        case .none: return 1
        case .multisampling2X: return 2
        default: return 4
        }
    }

    /// A `type2DMultisample` scratch texture for an MSAA pass.
    private func msaaTexture(pixelFormat: MTLPixelFormat, width: Int,
                             height: Int, samples: Int) -> MTLTexture? {
        let d = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat, width: width, height: height,
            mipmapped: false)
        d.textureType = .type2DMultisample
        d.sampleCount = samples
        d.usage = .renderTarget
        d.storageMode = .private
        return renderDevice()?.makeTexture(descriptor: d)
    }

    /// Retires a view's lazily-created pass objects — the in-flight
    /// pass may still reference them, so they join the graveyard
    /// rather than dropping.
    func retireViewRuntime(_ v: ViewRec) {
        if let r = v.renderer { retire(r) }
        if let t = v.msaaColorTex { retire(t) }
        if let t = v.msaaDepthTex { retire(t) }
    }

    /// Destroys every rt's textures and per-view renderers through the
    /// graveyard — called from `install` (the renderers hold the
    /// replaced scene) and `willMove(toWindow:)` detach. The W24
    /// sibling views die with them (their `SCNView`s hold the replaced
    /// scene object too).
    func teardownRenderTargets() {
        for rec in renderTargets.values {
            retire(rec.colorTex)
            retire(rec.depthTex)
            for v in rec.views { retireViewRuntime(v) }
        }
        renderTargets = [:]
        views = []
        screenViews = []
        teardownScreenSubviews()
        multiScreenMode = false
        blankPov = nil
        rendersContinuously = false
    }

    // MARK: - W24 split-screen siblings

    /// Whether the current screen-view set needs sibling mode: more
    /// than one screen view, or any view carrying a `viewport` rect.
    private var wantsScreenSubviews: Bool {
        screenViews.count > 1
            || screenViews.contains { $0.viewport != nil }
    }

    /// Rebuilds the split-screen state after `screenViews` changes —
    /// called from `installViews` (render queue). The sibling `SCNView`
    /// objects are UIKit: their build and teardown hop to the main
    /// thread, generation-gated so a superseded build can't install.
    /// The render-queue `screenSubviews` list (rec + proxy) is written
    /// here so per-frame sync never touches UIKit state.
    func updateScreenSubviews() {
        screenSubviewBuild += 1
        let gen = screenSubviewBuild
        multiScreenMode = wantsScreenSubviews
        screenSubviews = []
        teardownScreenSubviews()
        guard multiScreenMode else { return }
        let recs = screenViews
        // Index 0's point-of-view is the real camera node when
        // resolvable — the lowest-order view keeps the single-view
        // semantics (allowsCameraControl mutates the real node,
        // authored motion reads it directly). Later views draw
        // through detached proxies synced per frame.
        screenSubviews = recs.enumerated().map { i, rec in
            let real = i == 0 ? nodesById[rec.cameraKey] : nil
            return ScreenSubview(
                rec: rec, pov: real ?? SCNNode(), drivesRealNode: real != nil)
        }
        let povs = screenSubviews.map { $0.pov }
        let snapScene = scene
        let snapControl = allowsCameraControl
        let snapAA = antialiasingMode
        let snapScale = contentScaleFactor
        let snapBg = backgroundColor
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.screenSubviewBuild == gen,
                  self.multiScreenMode else { return }
            for (i, rec) in recs.enumerated() {
                let sub = SCNView(frame: self.screenSubviewFrame(rec.viewport))
                sub.scene = snapScene
                // Paused + on-demand: the sibling shares the scene but
                // owns no clock — no second update/sim step. The host
                // pokes setNeedsDisplay once per host frame.
                sub.isPlaying = false
                sub.rendersContinuously = false
                sub.autoenablesDefaultLighting = false
                sub.isUserInteractionEnabled = i == 0
                sub.allowsCameraControl = i == 0 && snapControl
                sub.backgroundColor = snapBg
                sub.antialiasingMode = snapAA
                sub.contentScaleFactor = snapScale
                sub.pointOfView = povs[i]
                self.addSubview(sub)
                self.mainScreenSubviews.append((view: sub, rec: rec))
            }
            self.applyScreenSubviewQuality()
        }
    }

    /// Tears down the sibling views — render-queue side drops its
    /// list now; the UIView removal hops to main (the sibling may be
    /// mid-draw there; removeFromSuperview sequences on main).
    func teardownScreenSubviews() {
        screenSubviews = []
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for s in self.mainScreenSubviews {
                s.view.removeFromSuperview()
            }
            self.mainScreenSubviews = []
        }
    }

    /// Per-frame sibling point-of-view sync — runs in
    /// `willRenderScene` (post-physics, same hook the offscreen
    /// scheduler uses) so a sibling's next draw sees the pose this
    /// frame's screen pass is about to. The proxy gets a COPY of the
    /// node's camera each frame: the copy carries the view's own
    /// `layerMask` (the wire mask is per-view; the SCNCamera mask is
    /// per-object) plus whatever exposure/effects the stage last
    /// wrote. Index 0's pov is the real node — the mask write lands
    /// there instead (the same write `applyScreenViewCamera` does).
    /// A camera that stops resolving keeps its sibling's last pose.
    func syncScreenSubviews() {
        for s in screenSubviews {
            guard let camNode = nodesById[s.rec.cameraKey],
                  let cam = camNode.camera else { continue }
            let mask = s.rec.layerMask == UInt32.max
                ? Int(bitPattern: UInt.max) : Int(s.rec.layerMask)
            if s.drivesRealNode {
                cam.categoryBitMask = mask
                continue
            }
            s.pov.transform = camNode.presentation.worldTransform
            if let copy = cam.copy() as? SCNCamera {
                copy.categoryBitMask = mask
                s.pov.camera = copy
            }
        }
    }

    /// Pokes every sibling for a redraw — called from
    /// `didRenderScene`. The list lives on main; the hop is once per
    /// host frame and the draws land on the next display commit.
    func pokeScreenSubviews() {
        guard multiScreenMode else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            for s in self.mainScreenSubviews {
                s.view.setNeedsDisplay()
            }
        }
    }

    /// Re-lays the sibling frames after a bounds change — called from
    /// `layoutSubviews` (main thread) and at build time.
    func layoutScreenSubviews() {
        for s in mainScreenSubviews {
            s.view.frame = screenSubviewFrame(s.rec.viewport)
        }
    }

    /// `[l,b,w,h]` target-pixel rect → a UIKit points frame. The wire
    /// origin is bottom-left (Filament's convention — the dart3d
    /// contract mirrors it); UIKit's is top-left, so y flips against
    /// the target height. Target pixels = the host drawable:
    /// bounds × contentScaleFactor (renderScale rides it, so a scaled
    /// pass keeps the rect proportional). Absent/malformed → bounds.
    private func screenSubviewFrame(_ vp: [Double]?) -> CGRect {
        guard let vp, vp.count == 4 else { return bounds }
        let s = contentScaleFactor > 0 ? contentScaleFactor : 1.0
        let targetH = bounds.height * s
        return CGRect(
            x: vp[0] / s,
            y: (targetH - vp[1] - vp[3]) / s,
            width: vp[2] / s,
            height: vp[3] / s)
    }

    /// Per-sibling quality resolve — view `antiAliasing` (non-'auto')
    /// > stage (non-'auto') > the sibling's init mode (the host's at
    /// build); `renderScale` (view > stage) multiplies the screen
    /// scale into `contentScaleFactor`, the same approximate path
    /// `applyStageQuality` uses. Runs on main — called from
    /// `applyStageQuality` and at build.
    func applyScreenSubviewQuality() {
        for s in mainScreenSubviews {
            let req = s.rec.aaMode.flatMap { $0 == "auto" ? nil : $0 }
                ?? (stageAntiAliasing != "auto" ? stageAntiAliasing : nil)
            switch req {
            case "none": s.view.antialiasingMode = .none
            case "msaa": s.view.antialiasingMode = .multisampling4X
            case nil: break
            default:
                logOnce("w24.aa.screen.\(req!)",
                    "antiAliasing '\(req!)' unsupported on SceneKit "
                    + "screen views; using the view's mode")
            }
            s.view.contentScaleFactor =
                (s.rec.renderScale ?? stageRenderScale)
                    * (window?.screen.scale ?? UIScreen.main.scale)
        }
    }
}
