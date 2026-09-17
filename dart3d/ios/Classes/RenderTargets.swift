import Foundation
import Metal
import SceneKit

/// W14: render textures and views.
///
/// A `kind:'renderTexture'` resource realizes to an `MTLTexture` pair
/// the offscreen passes draw into; a material slot referencing it binds
/// the color texture live (FsceneRealizer `applyTextureSlot`). The
/// top-level `views` array declares per-camera draws — `target` absent
/// means the screen (iOS has no split-screen: lowest `order` wins
/// `pointOfView`), `target:'rt:<tok>'` draws into that rt via an
/// `SCNRenderer` sharing the SAME scene object, scheduled from
/// `renderer(_:willRenderScene:atTime:)` so the pass sees the same
/// post-physics pose as the screen frame.
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
    var viewport: [Double]?        // dart3d additive ext — iOS ignores it
    // Texture-target runtime — never populated on screen views.
    var renderer: SCNRenderer?
    var msaaColorTex: MTLTexture?
    var msaaDepthTex: MTLTexture?
    var msaaSamples = 1
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
        if views.contains(where: { $0.viewport != nil }) {
            host.logOnce("w14.viewport",
                "view 'viewport' is ignored on iOS — split-screen is "
                + "offscreen-only on this platform")
        }
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
    /// replaced scene) and `willMove(toWindow:)` detach.
    func teardownRenderTargets() {
        for rec in renderTargets.values {
            retire(rec.colorTex)
            retire(rec.depthTex)
            for v in rec.views { retireViewRuntime(v) }
        }
        renderTargets = [:]
        views = []
        screenViews = []
        rendersContinuously = false
    }
}
