// W14 — render textures + views.
//
// `resources['rt:<tok>']` (kind 'renderTexture') realizes to a Filament
// RenderTarget — a single-level RGBA8 color attachment a material can
// sample through {'rref':'rt:…'} plus a DEPTH24 depth attachment (the
// format GLES 3.2 guarantees — DEPTH32F is optional there). Top-level
// `views:[…]` entries each carry their own Camera (created per entry so
// it survives `view.camera` swaps); rt-targeted entries additionally own
// a Filament View bound to the target's RenderTarget.
//
// Screen semantics: `view` (the primary screen View) renders the default
// pass whenever no entry targets the screen — identical to the pre-W14
// path. Screen-targeted entries share `view` as extra passes rendered in
// `order`: each pass pushes the entry's camera, viewport (Filament's
// viewport origin is bottom-left — the dart3d `viewport:[l,b,w,h]`
// extension), layer mask, and resolved AA/renderScale. The stage look +
// effects keep writing `view`, so every screen pass gets the same post
// stack — the per-View post stack is why offscreen views get their own
// Filament defaults instead.
package com.jasonholtdigital.dart3d

import android.util.Log
import com.google.android.filament.Camera
import com.google.android.filament.Engine
import com.google.android.filament.RenderTarget
import com.google.android.filament.Texture
import com.google.android.filament.TextureSampler
import com.google.android.filament.View
import org.json.JSONObject

private const val TAG = "dart3d"

object RenderTargets {

    private val loggedOnce = mutableSetOf<String>()
    private val warnedOnce = mutableSetOf<String>()

    private fun logOnce(tag: String, msg: String) {
        if (loggedOnce.add(tag)) Log.i(TAG, msg)
    }

    private fun warnOnce(tag: String, msg: String) {
        if (warnedOnce.add(tag)) Log.w(TAG, msg)
    }

    /** A `renderTexture` resource's decoded spec. */
    class Spec(
        val width: Int,
        val height: Int,
        val update: String, // everyFrame | interval | manual
        val intervalMs: Int,
        val filter: String, // linear | nearest
        val wrap: String,   // clampToEdge | repeat | mirror
    )

    /**
     * A live `rt:` resource — the RenderTarget, its color + depth
     * textures, the per-resource sampler the spec's filter/wrap select,
     * the views drawing into it, and the update-policy scheduler state
     * (`dirty` is the `render` op's mark).
     */
    class RenderTargetRec(
        val spec: Spec,
        val rt: RenderTarget,
        val colorTex: Texture,
        val depthTex: Texture?,
        val sampler: TextureSampler,
        val views: MutableList<ViewRec> = ArrayList(),
        var lastRenderNanos: Long = 0L,
        var dirty: Boolean = false,
    )

    /**
     * One decoded `views` entry — `targetKey` null draws to the screen.
     * Every entry owns a Camera + its entity (destroyed at teardown).
     * Offscreen entries also own a View bound to the rt; screen entries
     * share the host's `view` and render as per-pass reconfigures — so
     * their engine View handle stays null and the resolved quality
     * ([msaa]/[aa]/[dsr]) is pushed per pass in render().
     */
    class ViewRec(
        val cameraKey: Long,
        val targetKey: Long?,
        val layerMask: Int,
        val order: Int,
        val aaMode: String?,
        val renderScale: Double?,
        val filterQuality: String?,
        // dart3d split-screen extension — [l,b,w,h] in target pixels,
        // Filament's bottom-left origin.
        val viewport: DoubleArray?,
    ) {
        var view: View? = null
        var camera: Camera? = null
        var cameraEntity = 0
        var msaa = View.MultiSampleAntiAliasingOptions()
        var aa = View.AntiAliasing.FXAA
        var dsr = View.DynamicResolutionOptions()
    }

    /**
     * One camera node's decoded projection props — retained for every
     * camera node so view cameras build their own projections. Defaults
     * mirror the view camera's (60° vertical fov, 0.05/1000 clip planes,
     * orthoScale 1.0 = SCNCamera's orthographicScale default).
     */
    class CameraSpec(
        val fovDeg: Double = 60.0,
        val near: Double = 0.05,
        val far: Double = 1000.0,
        val ortho: Boolean = false,
        val orthoScale: Double = 1.0,
    ) {
        /** Projects [cam] for [aspect] (target or viewport w/h). */
        fun applyTo(cam: Camera, aspect: Double) {
            if (ortho) {
                val halfH = orthoScale
                val halfW = halfH * aspect
                cam.setProjection(
                    Camera.Projection.ORTHO,
                    -halfW, halfW, -halfH, halfH, near, far
                )
            } else {
                cam.setProjection(
                    fovDeg, aspect, near, far, Camera.Fov.VERTICAL
                )
            }
        }

        companion object {
            val DEFAULT = CameraSpec()

            /** The same tagged fields applyCameraProps reads. */
            fun parse(p: JSONObject): CameraSpec = CameraSpec(
                fovDeg = (p.tag("fovRadiansY").d3Double()
                    ?: (60.0 * Math.PI / 180.0)) * 180.0 / Math.PI,
                near = p.tag("near").d3Double() ?: 0.05,
                far = p.tag("far").d3Double() ?: 1000.0,
                ortho = p.tag("projection").d3String() == "orthographic",
                orthoScale = p.tag("orthoScale").d3Double()
                    ?: p.tag("orthographicScale").d3Double() ?: 1.0,
            )
        }
    }

    /** Decodes one `renderTexture` resource spec — null on malformed. */
    fun decodeSpec(key: Long, r: JSONObject): Spec? {
        val w = r.optInt("width", 0)
        val h = r.optInt("height", 0)
        if (w <= 0 || h <= 0) {
            warnOnce("rt.$key.dims",
                "renderTexture $key: missing/invalid width/height")
            return null
        }
        var update = r.optString("update").ifEmpty { "everyFrame" }
        if (update != "everyFrame" && update != "interval" &&
            update != "manual"
        ) {
            warnOnce("rt.$key.update.$update",
                "renderTexture $key: unknown update '$update';" +
                    " using everyFrame")
            update = "everyFrame"
        }
        var intervalMs = r.optInt("intervalMilliseconds", 0)
        if (update == "interval" && intervalMs <= 0) {
            logOnce("rt.$key.interval",
                "renderTexture $key: 'interval' needs" +
                    " intervalMilliseconds; using 1000")
            intervalMs = 1000
        }
        var filter = r.optString("filter").ifEmpty { "linear" }
        if (filter != "linear" && filter != "nearest") {
            warnOnce("rt.$key.filter.$filter",
                "renderTexture $key: unknown filter '$filter';" +
                    " using linear")
            filter = "linear"
        }
        var wrap = r.optString("wrap").ifEmpty { "clampToEdge" }
        if (wrap != "clampToEdge" && wrap != "repeat" &&
            wrap != "mirror"
        ) {
            warnOnce("rt.$key.wrap.$wrap",
                "renderTexture $key: unknown wrap '$wrap';" +
                    " using clampToEdge")
            wrap = "clampToEdge"
        }
        return Spec(w, h, update, intervalMs, filter, wrap)
    }

    /**
     * Builds the textures + RenderTarget for [spec]. Color is a
     * single-level RGBA8 (COLOR_ATTACHMENT | SAMPLEABLE — views draw
     * into it, materials sample it); depth is DEPTH24 — the depth
     * format GLES 3.2 guarantees (DEPTH32F is optional there).
     */
    fun build(engine: Engine, spec: Spec): RenderTargetRec {
        val color = Texture.Builder()
            .width(spec.width).height(spec.height)
            .levels(1)
            .sampler(Texture.Sampler.SAMPLER_2D)
            .format(Texture.InternalFormat.RGBA8)
            .usage(
                Texture.Usage.COLOR_ATTACHMENT or
                    Texture.Usage.SAMPLEABLE
            )
            .build(engine)
        val depth = Texture.Builder()
            .width(spec.width).height(spec.height)
            .levels(1)
            .sampler(Texture.Sampler.SAMPLER_2D)
            .format(Texture.InternalFormat.DEPTH24)
            .usage(Texture.Usage.DEPTH_ATTACHMENT)
            .build(engine)
        val rt = RenderTarget.Builder()
            .texture(RenderTarget.AttachmentPoint.COLOR, color)
            .texture(RenderTarget.AttachmentPoint.DEPTH, depth)
            .build(engine)
        // Fresh pixels start dirty — even a `manual` rt draws once so
        // the texture holds a frame before the first explicit render.
        return RenderTargetRec(
            spec, rt, color, depth, sampler(spec), dirty = true)
    }

    /** The spec's filter/wrap → the sampler materials bind this rt with. */
    private fun sampler(spec: Spec): TextureSampler {
        val linear = spec.filter == "linear"
        val wrap = when (spec.wrap) {
            "repeat" -> TextureSampler.WrapMode.REPEAT
            "mirror" -> TextureSampler.WrapMode.MIRRORED_REPEAT
            else -> TextureSampler.WrapMode.CLAMP_TO_EDGE
        }
        // levels(1) — no mip chain — so the min filter stays non-mipmap.
        return TextureSampler(
            if (linear) TextureSampler.MinFilter.LINEAR
            else TextureSampler.MinFilter.NEAREST,
            if (linear) TextureSampler.MagFilter.LINEAR
            else TextureSampler.MagFilter.NEAREST,
            wrap
        )
    }

    /**
     * Decodes one `views` entry — [nodeExists]/[rtExists] resolve the
     * camera/target tokens against the live registries; an unresolved
     * ref warns once and skips the view (deferred-node views take the
     * same skip-and-warn as other unresolved refs).
     */
    fun decodeViewEntry(
        index: Int,
        e: JSONObject,
        nodeExists: (Long) -> Boolean,
        rtExists: (Long) -> Boolean,
    ): ViewRec? {
        val camToken = e.optString("camera")
        val camKey = D3Wire.localIdKey(camToken)
        if (camKey == null || !nodeExists(camKey)) {
            warnOnce("views.$index.camera",
                "view $index: camera '$camToken' unresolved; skipped")
            return null
        }
        var targetKey: Long? = null
        val targetToken =
            e.optString("target").takeIf { it.isNotEmpty() }
        if (targetToken != null) {
            val tk = D3Wire.localIdKey(targetToken)
            if (tk == null || !rtExists(tk)) {
                warnOnce("views.$index.target",
                    "view $index: target '$targetToken' unresolved;" +
                        " skipped")
                return null
            }
            targetKey = tk
        }
        // The wire mask is 32-bit (default all-ones); Filament views
        // see 8 — the host applies `and 0xFF` at build.
        val layerMask =
            if (e.has("layerMask")) e.optInt("layerMask") else 0xFF
        if (layerMask and 0xFFFFFF00.toInt() != 0) {
            logOnce("w14.layerMask",
                "layerMask is 8-bit on Filament; high bits ignored")
        }
        val vp = e.optJSONArray("viewport")?.toDoubleArray()
        if (vp != null && vp.size != 4) {
            warnOnce("views.$index.viewport",
                "view $index: viewport needs [l,b,w,h]; ignored")
        }
        return ViewRec(
            cameraKey = camKey,
            targetKey = targetKey,
            layerMask = layerMask,
            order = e.optInt("order", 0),
            aaMode =
                e.optString("antiAliasing").takeIf { it.isNotEmpty() },
            renderScale =
                if (e.has("renderScale")) e.optDouble("renderScale")
                else null,
            filterQuality = e.optString("filterQuality")
                .takeIf { it.isNotEmpty() },
            viewport = vp?.takeIf { it.size == 4 },
        )
    }

    /**
     * The update-policy gate — everyFrame always; interval by elapsed
     * nanos (a `render` op's dirty mark also forces an early refresh);
     * manual only while dirty.
     */
    fun due(rec: RenderTargetRec, tNanos: Long): Boolean =
        when (rec.spec.update) {
            "manual" -> rec.dirty
            "interval" -> rec.dirty ||
                tNanos - rec.lastRenderNanos >=
                    rec.spec.intervalMs * 1_000_000L
            else -> true
        }

    /** One view's resolved anti-aliasing pair. */
    class ViewAa(
        val msaa: View.MultiSampleAntiAliasingOptions,
        val aa: View.AntiAliasing,
    )

    /**
     * The AA resolve chain: entry `antiAliasing` (non-'auto') → stage
     * `antiAliasing` (non-'auto') → the widget's antialiasingMode →
     * Filament's default (FXAA, no MSAA). 'smaa' has no Filament knob
     * and 'taa' lives in the effects block (temporalAntiAliasing), not
     * the View AA field — both log once and inherit.
     */
    fun resolveAa(
        entryMode: String?,
        stageMode: String?,
        viewConfigV: Int?,
    ): ViewAa {
        for (m in listOf(entryMode, stageMode)) {
            when (m) {
                null, "auto" -> continue
                "none" -> return ViewAa(
                    msaaOptions(false, 0), View.AntiAliasing.NONE)
                "msaa" -> return ViewAa(
                    msaaOptions(true, 4), View.AntiAliasing.NONE)
                "fxaa" -> return ViewAa(
                    msaaOptions(false, 0), View.AntiAliasing.FXAA)
                else -> logOnce("w14.aa.$m",
                    if (m == "smaa" || m == "taa")
                        "antiAliasing '$m' isn't a View-level AA on" +
                            " Filament (taa is the effects block);" +
                            " inheriting"
                    else
                        "antiAliasing '$m' unknown; inheriting")
            }
        }
        if (viewConfigV != null) {
            // The widget antialiasingMode — the same sample-count clamp
            // and MSAA+FXAA pairing as the default-path write.
            val count = when {
                viewConfigV <= 0 -> 0
                viewConfigV == 2 || viewConfigV == 4 -> viewConfigV
                viewConfigV < 4 -> 2
                else -> 4
            }
            return ViewAa(
                msaaOptions(viewConfigV > 0, count),
                if (viewConfigV > 0) View.AntiAliasing.FXAA
                else View.AntiAliasing.NONE
            )
        }
        return ViewAa(
            msaaOptions(false, 0), View.AntiAliasing.FXAA)
    }

    private fun msaaOptions(
        enabled: Boolean, samples: Int,
    ): View.MultiSampleAntiAliasingOptions =
        View.MultiSampleAntiAliasingOptions().apply {
            this.enabled = enabled
            if (samples > 0) this.sampleCount = samples
        }

    /**
     * `renderScale` → DynamicResolutionOptions — min==max pins a FIXED
     * scale through the DSR knob (not the semantic dynamic-resolution
     * feature); disabled at the default 1.0 so no scale pass runs.
     */
    fun dsrOptions(scale: Double): View.DynamicResolutionOptions {
        val o = View.DynamicResolutionOptions()
        if (scale > 0.0 && scale != 1.0) {
            o.enabled = true
            o.homogeneousScaling = true
            o.minScale = scale.toFloat()
            o.maxScale = scale.toFloat()
        }
        return o
    }
}
