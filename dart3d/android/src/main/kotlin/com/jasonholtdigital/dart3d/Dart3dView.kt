package com.jasonholtdigital.dart3d

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Typeface
import android.opengl.Matrix
import android.util.Base64
import android.util.Log
import android.view.Choreographer
import android.view.Gravity
import android.view.Surface
import android.view.SurfaceView
import android.widget.FrameLayout
import android.widget.TextView
import com.github.stephengold.joltjni.Body
import com.github.stephengold.joltjni.Quat
import com.github.stephengold.joltjni.RVec3
import com.github.stephengold.joltjni.Vec3
import com.google.android.filament.Box
import com.google.android.filament.Camera
import com.google.android.filament.ColorGrading
import com.google.android.filament.Engine
import com.google.android.filament.EntityManager
import com.google.android.filament.IndirectLight
import com.google.android.filament.Material
import com.google.android.filament.MaterialInstance
import com.google.android.filament.MorphTargetBuffer
import com.google.android.filament.RenderableManager
import com.google.android.filament.Renderer
import com.google.android.filament.Scene
import com.google.android.filament.SkinningBuffer
import com.google.android.filament.Skybox
import com.google.android.filament.SwapChain
import com.google.android.filament.Texture
import com.google.android.filament.TextureSampler
import com.google.android.filament.ToneMapper
import com.google.android.filament.View
import com.google.android.filament.Viewport
import com.google.android.filament.android.UiHelper
import com.google.android.filament.filamat.MaterialBuilder
import com.google.android.filament.utils.GestureDetector
import com.google.android.filament.utils.IBLPrefilterContext
import com.google.android.filament.utils.Manipulator
import com.google.android.filament.utils.Utils
import org.json.JSONArray
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.Locale
import java.util.concurrent.ConcurrentLinkedQueue
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sin
import kotlin.math.sqrt

private const val TAG = "dart3d"

/**
 * The native view behind `SceneView` on Android — mirrors
 * `SceneViewHost.swift`. Owns the Filament engine/view/swapchain, the
 * Jolt world, the id→object registries the protocol mutations address,
 * and the Choreographer loop that steps physics and renders.
 *
 * Events flow back through `Dart3dJni.fireToDart` carrying the view's
 * viewId token — the same dispatcher-slot contract as iOS's
 * `d3FireToDart`.
 */
class Dart3dView(context: Context) : FrameLayout(context) {

    // MARK: - Filament objects (created eagerly — none need the surface)

    val engine: Engine = createEngine()
    private val renderer: Renderer = engine.createRenderer()
    val scene: Scene = engine.createScene()
    private val view: View = engine.createView()
    private var swapChain: SwapChain? = null

    private val surfaceView = SurfaceView(context)
    private val uiHelper = UiHelper(UiHelper.ContextErrorPolicy.DONT_CHECK)

    /**
     * W30 backend selection, resolved once per engine. An explicit
     * `Dart3dSetBackend` pref (the example's `DART3D_BACKEND` define)
     * wins; `auto` takes [DEFAULT_BACKEND] when the device declares
     * Vulkan and falls back to OpenGL when it does not. A backend that
     * fails to build (Vulkan claimed but unusable) retries on OpenGL.
     */
    private fun createEngine(): Engine {
        val pref = Dart3dJni.nativeBackendPref()
        var backend = when (pref) {
            BACKEND_OPENGL -> Engine.Backend.OPENGL
            BACKEND_VULKAN -> Engine.Backend.VULKAN
            else -> if (context.packageManager.hasSystemFeature(
                    PackageManager.FEATURE_VULKAN_HARDWARE_VERSION)) {
                DEFAULT_BACKEND
            } else {
                Engine.Backend.OPENGL
            }
        }
        val engine = try {
            Engine.Builder().backend(backend).build()
        } catch (e: Exception) {
            if (backend == Engine.Backend.OPENGL) throw e
            Log.w(TAG, "Filament $backend engine failed, retrying on OpenGL", e)
            backend = Engine.Backend.OPENGL
            Engine.Builder().backend(backend).build()
        }
        Log.i(TAG, "Filament engine backend: $backend (pref=$pref)")
        return engine
    }

    private val cameraEntity: Int
    private val camera: Camera
    internal var cameraNodeKey: Long? = null
    private var cameraFovDeg = 60.0
    private var cameraNear = 0.05
    private var cameraFar = 1000.0
    private var cameraOrtho = false
    // SceneKit orthographicScale semantic: view half-height in world
    // units; 1.0 is the SCNCamera default when the wire omits it.
    private var cameraOrthoScale = 1.0
    private var viewportW = 0
    private var viewportH = 0

    // MARK: - W6 camera control + stats overlay

    /** filament-utils orbit manipulator — the allowsCameraControl
     * stand-in for SCNView's built-in control. Non-null while the
     * viewConfig flag is on; writes back through the camera node's
     * transform each frame so the per-frame setModelMatrix picks it
     * up. */
    private var manipulator: Manipulator? = null
    private var gestureDetector: GestureDetector? = null

    /** Camera node's authored local TRS, snapshotted at manipulator
     * attach and restored on detach (spec: detaching returns the
     * camera to the node-authored pose). */
    private var savedCameraTrs: Array<FloatArray>? = null
    private var lastManipEye: FloatArray? = null
    private var cameraMovedLogged = false

    /** showsStatistics HUD — a TextView child over the SurfaceView,
     * refreshed at ~4 Hz so it never measurably costs frames. */
    private var statsOverlay: TextView? = null
    private var statsWindowStart = 0L
    private var statsFrames = 0

    /**
     * W21: Filament bakes the blending mode into the compiled Material
     * (MaterialInstance can only vary the mask threshold), so each
     * shading family compiles three alphaMode variants — `opaque`,
     * `mask` (alpha-test discard at the instance's maskThreshold), and
     * `blend` (src-over transparency). `litMaterial`/`unlitMaterial`
     * stay the opaque defaults every existing reference expects.
     */
    val litMaterial: Material
    val litMaskedMaterial: Material
    val litBlendMaterial: Material
    val unlitMaterial: Material
    val unlitMaskedMaterial: Material
    val unlitBlendMaterial: Material
    /**
     * W24 `shadowCatcher` — the Filament unlit+shadowMultiplier path.
     * Built lazily on first use: a compile failure degrades catcher
     * surfaces to transparent instead of aborting SceneView init.
     */
    private var catcherMaterialBacking: Material? = null
    private var catcherMaterialFailed = false
    val catcherMaterial: Material?
        get() {
            if (catcherMaterialBacking == null && !catcherMaterialFailed) {
                catcherMaterialBacking = try {
                    buildShadowCatcherMaterial()
                } catch (t: Throwable) {
                    catcherMaterialFailed = true
                    Log.w(TAG, "d3.shadowCatcher: material build failed; " +
                        "catcher surfaces degrade to transparent", t)
                    null
                }
            }
            return catcherMaterialBacking
        }

    /**
     * W22: KHR_materials_* feature variants, built lazily — a material
     * resource's extension set picks its compiled variant. The six
     * prebuilts cover extFlags==0; anything beyond compiles on first
     * use inside the render callback (same lane as every decode), so
     * views that never see an extension material pay nothing.
     *
     * W22-r3: [VariantKey.boundSlots] is the bound-texture mask
     * (FsceneRealizer.boundTextureMask) — the variant declares
     * samplers only for those slots, because Filament's FL1 cap
     * counts *declared* samplers, not bound textures.
     */
    internal data class VariantKey(
        val unlit: Boolean,
        val alphaMode: String,
        val extFlags: Int,
        val boundSlots: Int,
    )
    internal val materialVariants = HashMap<VariantKey, Material>()

    /**
     * What a `materialForVariant` request resolved to. A request that
     * can't compile — over the sampler cap or a filamat/build failure
     * — degrades to the matching base prebuilt: [material] is that
     * prebuilt and [extFlags]/[boundSlots] collapse to the base
     * contract, so the instance decode never writes or binds a
     * parameter the shader lacks.
     */
    data class VariantPick(
        val material: Material,
        val extFlags: Int,
        val boundSlots: Int,
    )

    /** Variant keys whose compile already failed — logged once via
     * warnOnce and degraded; kept out of [materialVariants] so the
     * destroy pass never double-frees a shared base prebuilt. */
    private val failedVariants = HashSet<VariantKey>()

    /** W16: the `trail` ribbon material — vertex-color unlit + blend. */
    val trailMaterial: Material

    // MARK: - Jolt world

    val world = JoltWorld()

    // MARK: - Registries (mirrors SceneViewHost)

    var nodesById: MutableMap<Long, FsceneRealizer.NodeRec> = LinkedHashMap()
        private set
    internal var gpuMeshes: MutableMap<Long, GpuMesh> = HashMap()
        private set
    internal var materialInstances: MutableMap<Long, MaterialInstance> = HashMap()
        private set
    internal var bodies: MutableMap<Long, Body> = LinkedHashMap()
        private set
    var dynamicBodyKeys: MutableSet<Long> = LinkedHashSet()
        private set

    /** `.fscene` format version of the last installed manifest —
     * surgical decodes read it for the same layout rules. */
    internal var fsceneVersion = 5

    /**
     * Children whose `addNode` predated their parent's — childKey →
     * parentKey. Parked claims resolve as parents land (diff ops are
     * order-independent within a batch); cleared at install.
     */
    internal val pendingParents: MutableMap<Long, Long> = HashMap()

    /** Raw payload chunks for the live document — cleared on each
     * `loadScene` since the (session,index) keys are document-local
     * and collide across unrelated manifests (mirrors iOS). */
    val payloadStore: MutableMap<Long, ByteArray> = HashMap()

    /** Specs that arrived on `upsertPayload` ops rather than the
     *  manifest — a re-realize rebuilds `resources.payloadSpecs` from
     *  the manifest alone, so these merge back on top at install. */
    internal val opPayloadSpecs:
        MutableMap<Long, FsceneRealizer.Context.PayloadMeta> = HashMap()

    // MARK: - W12 component joints

    /**
     * Declarative joint components (W12) ride the command-joint
     * registry but get handles from a reserved range —
     * nodeKey → (component index → joint id) — so a `components`
     * re-decode replaces exactly the node's own registrations without
     * touching command `addJoint` ids (the Dart command allocator owns
     * the low range).
     */
    internal val componentJointIds:
        MutableMap<Long, MutableMap<Int, Int>> = HashMap()
    private var nextComponentJointHandle = 0x40000000

    // MARK: - W4 texture/material state

    /** Shared sampler for every texture slot — linear/repeat/mipmapped. */
    val textureSampler = TextureSampler(
        TextureSampler.MinFilter.LINEAR_MIPMAP_LINEAR,
        TextureSampler.MagFilter.LINEAR,
        TextureSampler.WrapMode.REPEAT)

    /**
     * Neutral 1×1 fallbacks — bound on every texture-less slot so the
     * shader's factor×texture math reads as factor-only. `fallbackWhite`
     * covers baseColor, metallicRoughness (G=B=1) and occlusion (R=1).
     */
    val fallbackWhite: Texture
    val fallbackNormal: Texture
    val fallbackEmissive: Texture

    /**
     * Resource dictionaries retained from the last realize pass — the
     * surgical `upsertResource`/`upsertPayload` ops read and mutate these
     * (mirrors the iOS-retained `materials`/`textures`/consumer maps).
     */
    var resources = FsceneRealizer.Context.InstalledResources()
        private set

    internal var pendingPayloadRefs: MutableSet<Long> = HashSet()
        private set
    private var lastManifest: ByteArray? = null

    // MARK: - W14 render targets + views

    /**
     * Live `rt:` resources — the RenderTarget, its color/depth
     * textures, the spec's sampler, and the views drawing into it.
     * The color texture is ALSO keyed in `resources.textures` so a
     * material's `{'rref':'rt:…'}` resolves through bindTextureSlot —
     * the rec owns its destruction (texture sweeps skip rt keys).
     * A surgical Context aliases this map.
     */
    internal var renderTargets:
        MutableMap<Long, RenderTargets.RenderTargetRec> = HashMap()
        private set

    /**
     * Every decoded `views` entry, in `order` — [screenViews] is the
     * target-less subset that shares [view] as extra swapchain passes.
     * Each entry owns a Camera + entity; offscreen entries own a View
     * bound to their rt.
     */
    internal val viewRecs = ArrayList<RenderTargets.ViewRec>()
    private val screenViews = ArrayList<RenderTargets.ViewRec>()

    /** Every camera node's decoded props — per-view projections. */
    internal var nodeCameraProps:
        MutableMap<Long, RenderTargets.CameraSpec> = HashMap()
        private set

    /** Last `antialiasingMode` from viewConfig (null = never sent) —
     *  a level in each view's AA resolve chain. */
    private var viewConfigAa: Int? = null

    /**
     * `viewConfig.quality` tier — "low"|"medium"|"high", or null for
     * 'default'. A set tier owns the pipeline: it replaces
     * [viewConfigAa] in the AA resolve chain and gates shadow maps
     * (low = no shadowing). FsceneRealizer reads it for shadow mapSize.
     */
    internal var viewQuality: String? = null

    /** The AA source for resolve chains — the tier when set, else the
     *  widget's antialiasingMode. */
    private fun effectiveViewConfigAa(): Int? = when (viewQuality) {
        "low" -> 0
        "medium" -> 1   // resolveAa maps <4 → MSAA×2 + FXAA
        "high" -> 4
        else -> viewConfigAa
    }

    /** Stage-level view-quality defaults (W14) — a views entry's
     *  absent antiAliasing/renderScale/filterQuality inherits these. */
    private var stageAntiAliasing: String? = null
    private var stageRenderScale = 1.0
    private var stageFilterQuality = "medium"

    // MARK: - W7 environment / IBL state

    /** The last `stage` JSON applied — the manifest's on install, then
     * `updateStage` ops. A payload-arrival stage re-decode replays it
     * (mirrors iOS's lastStage). */
    internal var lastStage: JSONObject? = null

    /** The last decoded `effects` post-stack (W13). `decodeStage`
     * replaces it when the env resource ships `effects` (even `{}`)
     * and retains it when absent; applied by [applyStageLook] +
     * [applyStageEffects] at the end of every stage decode. */
    internal var lastEffects: StageEffects? = null

    /** Fingerprint of the last realized stage-env inputs (stage JSON +
     * env resource JSON + env payload bytes). `decodeStage` skips the
     * equirect→cube→SH rebuild when nothing it reads has changed —
     * payload arrivals for OTHER resources re-run the stage but must
     * not re-run ~10ms of GPU work each time. */
    internal var lastEnvFingerprint: Int? = null

    /** Filament objects owned by the applied stage env — swapped and
     * destroyed by [applyEnvironment]/[applySkybox] on every
     * non-deferred `decodeStage`. `envIblTextures` holds the equirect +
     * raw cube + prefiltered cube (the reflections cube lives here even
     * when the `environment` skybox samples it); `envSkyboxTextures`
     * holds cubes built solely for the background (blur/gradient). */
    internal var envIndirectLight: IndirectLight? = null
        private set
    internal var envSkybox: Skybox? = null
        private set
    private val envIblTextures = ArrayList<Texture>()
    private val envSkyboxTextures = ArrayList<Texture>()
    private var envColorGrading: ColorGrading? = null

    private var iblPrefilter: IBLPrefilterContext? = null
    private var iblEquirect: IBLPrefilterContext.EquirectangularToCubemap? =
        null
    private var iblSpecular: IBLPrefilterContext.SpecularFilter? = null

    private var lastAwakeCount = 0
    // One-shot log dedup for command ops (spec: unknown upsert kinds
    // and unclaimed payloads log once, not per send).
    private val commandLoggedOnce = HashSet<String>()
    // Same convention for view-level warnings — W22-r3 variant
    // degrades warn once per bad variant, never per material.
    private val warnedOnce = HashSet<String>()
    private var simTick = 0
    private var sawHello = false
    private var warnedNoHello = false
    // Written on main (onDetachedFromWindow), read on the Dart delivery
    // thread (onMutation) — needs visibility across both.
    @Volatile private var detached = false

    // MARK: - W11 skins / morphs / animations

    /**
     * A live skinned renderable's GPU skinning buffer plus the bone
     * scratch the per-frame upload fills. `skinKey` keeps the binding
     * so a `removeSkin` detaches and a joint-count change rebuilds.
     * Joints resolve per-frame at upload — a joint that hasn't landed
     * (or was removed) reads identity, upstream's null-tolerant rule.
     */
    class NodeSkin(
        val skinKey: Long,
        val buffer: SkinningBuffer,
        val boneCount: Int,
    ) {
        val bones: FloatBuffer = ByteBuffer
            .allocateDirect(boneCount * 16 * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
    }
    internal var nodeSkinning: MutableMap<Long, NodeSkin> = HashMap()

    /**
     * W11 clip playback state — upstream's `AnimationClip` knobs. A
     * clip exists only after an `anim` op names its animation —
     * upstream's `createAnimationClip` shape: no clip, no
     * contribution (a doc load never snaps animated nodes to a key-0
     * pose). Channel data is read live from `resources.animations` so
     * an `upsertAnimation`/payload re-decode refreshes the curves
     * underneath a live clip.
     */
    private class AnimClipState {
        var playing = false
        var time = 0.0            // playbackTime, seconds
        var timeScale = 1.0
        var weight = 1.0          // clamped [0,1] on assignment
        var loop = false
    }

    /**
     * Per-node captured bind state — upstream's `AnimationTransforms`.
     * Captured ONCE when a channel first binds the node and kept even
     * after its clips go away (upstream keeps `_targetTransforms`
     * entries on `removeClip`; the per-frame write-back then holds
     * the node at bind pose — deliberate).
     */
    private class AnimTargetState {
        var bindP = floatArrayOf(0f, 0f, 0f)
        var bindR = floatArrayOf(0f, 0f, 0f, 1f)
        var bindS = floatArrayOf(1f, 1f, 1f)
        // Any bound non-weights channel drives TRS writes; a node
        // bound only by weights channels keeps its manual transform.
        var drivesTransform = false
        // Rest morph weights captured at first weights-channel bind —
        // null while the node has no morph renderable (the channel
        // then no-ops).
        var bindWeights: FloatArray? = null
    }
    private val animClips = HashMap<Long, AnimClipState>()
    private val animTargets = HashMap<Long, AnimTargetState>()

    /** Identity mat4 scratch for `updateSkinning`'s missing-joint path. */
    private val IDENTITY16 = FloatArray(16).also {
        android.opengl.Matrix.setIdentityM(it, 0)
    }

    /** This view's framework viewId — stamped by the mutation router. */
    var viewId: Long = 0

    var clearColor = floatArrayOf(0.06f, 0.06f, 0.08f, 1f)
        set(value) {
            field = value
            applyClearColor()
        }

    // MARK: - Frame loop

    private var lastFrameNanos = 0L
    private var physicsAcc = 0f

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(tNanos: Long) {
            if (detached) return
            stepFrame(tNanos)
            Choreographer.getInstance().postFrameCallback(this)
        }
    }

    init {
        addView(surfaceView, LayoutParams(
            LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
        // Touch events reach the manipulator only while
        // allowsCameraControl has attached one; unconsumed otherwise.
        surfaceView.setOnTouchListener { _, event ->
            gestureDetector?.let { it.onTouchEvent(event); true } ?: false
        }
        // The six prebuilts declare every base slot (instances bind
        // 1×1 fallbacks, so all five stay sampled) — boundSlots is
        // the full base mask. A prebuilt that can't compile leaves
        // nothing to fall back to; the check stays fatal there.
        litMaterial = checkNotNull(buildMaterial(unlit = false,
            MaterialBuilder.BlendingMode.OPAQUE, 0,
            FsceneRealizer.ALL_BASE_SLOTS))
            { "d3 material failed to compile" }
        litMaskedMaterial = checkNotNull(buildMaterial(unlit = false,
            MaterialBuilder.BlendingMode.MASKED, 0,
            FsceneRealizer.ALL_BASE_SLOTS))
            { "d3 material failed to compile" }
        litBlendMaterial = checkNotNull(buildMaterial(unlit = false,
            MaterialBuilder.BlendingMode.TRANSPARENT, 0,
            FsceneRealizer.ALL_BASE_SLOTS))
            { "d3 material failed to compile" }
        unlitMaterial = checkNotNull(buildMaterial(unlit = true,
            MaterialBuilder.BlendingMode.OPAQUE, 0,
            FsceneRealizer.ALL_BASE_SLOTS))
            { "d3 material failed to compile" }
        unlitMaskedMaterial = checkNotNull(buildMaterial(unlit = true,
            MaterialBuilder.BlendingMode.MASKED, 0,
            FsceneRealizer.ALL_BASE_SLOTS))
            { "d3 material failed to compile" }
        unlitBlendMaterial = checkNotNull(buildMaterial(unlit = true,
            MaterialBuilder.BlendingMode.TRANSPARENT, 0,
            FsceneRealizer.ALL_BASE_SLOTS))
            { "d3 material failed to compile" }
        // The materials are compiled double-sided-capable; keep the
        // default single-sided unless a resource's doubleSided says so.
        for (m in arrayOf(litMaterial, litMaskedMaterial, litBlendMaterial,
            unlitMaterial, unlitMaskedMaterial, unlitBlendMaterial)) {
            m.defaultInstance.setDoubleSided(false)
        }
        // W16: the trail ribbon's own material — upstream's default is
        // translucent unlit driven fully by vertex color (incl. alpha),
        // drawn without culling (a camera-facing strip's winding flips
        // where the path doubles back). One shared instance: the
        // shader has no parameters, so every trail binds the same one.
        trailMaterial = buildTrailMaterial()
        trailMaterial.defaultInstance.setDoubleSided(true)

        fallbackWhite = TextureFactory.solid(engine, 255, 255, 255, 255)
        fallbackNormal = TextureFactory.solid(engine, 128, 128, 255, 255)
        fallbackEmissive = TextureFactory.solid(engine, 0, 0, 0, 255)

        cameraEntity = EntityManager.get().create()
        camera = engine.createCamera(cameraEntity)

        view.scene = scene
        view.camera = camera
        // Filament shows layer 0 only by default; the upstream view
        // mask is all-layers — widen so node `layers` is the only gate.
        view.setVisibleLayers(0xFF, 0xFF)
        // Lights declaring castsShadow need a shadow type on the view —
        // Filament renders no shadow maps without one. DPCF (dithered
        // PCF) keeps a soft edge at fixed-kernel cost — PCSS's blocker
        // search runs ~300ms/frame on Mali at these world scales.
        view.setShadowType(View.ShadowType.DPCF)
        // W22: KHR_materials_transmission variants render through
        // screen-space refraction — without the flag Filament skips
        // the refraction pass even for refraction-enabled materials.
        view.setScreenSpaceRefractionEnabled(true)
        applyClearColor()

        uiHelper.renderCallback = object : UiHelper.RendererCallback {
            override fun onNativeWindowChanged(surface: Surface) {
                swapChain?.let { engine.destroySwapChain(it) }
                swapChain = engine.createSwapChain(surface, uiHelper.swapChainFlags)
            }
            override fun onDetachedFromSurface() {
                swapChain?.let { engine.destroySwapChain(it) }
                swapChain = null
            }
            override fun onResized(width: Int, height: Int) {
                viewportW = width; viewportH = height
                view.viewport = Viewport(0, 0, width, height)
                manipulator?.setViewport(width, height)
                applyProjection()
            }
        }
        uiHelper.attachTo(surfaceView)

        // W8: contact events surface through the same fireEvent path
        // as settled — JoltWorld reports in engine space, the encode
        // mirrors to the wire frame.
        world.onContact = { ev -> fireContactEvent(ev) }
        // W9: joint `broke` events — same sink pattern.
        world.onJointBroke = { ev -> fireJointBroke(ev) }

        Choreographer.getInstance().postFrameCallback(frameCallback)
    }

    // MARK: - Materials

    /**
     * Picks the compiled variant for a material resource's alphaMode —
     * `opaque`/`mask`/`blend` (wire strings, lowercase; anything else
     * reads as opaque). `mask` needs a `maskThreshold` on the instance
     * — the caller sets it from `alphaCutoff`.
     */
    fun materialForAlphaMode(unlit: Boolean, alphaMode: String): Material =
        when (alphaMode.lowercase()) {
            "mask" -> if (unlit) unlitMaskedMaterial else litMaskedMaterial
            "blend" -> if (unlit) unlitBlendMaterial else litBlendMaterial
            else -> if (unlit) unlitMaterial else litMaterial
        }

    private fun blendingForMode(alphaMode: String) =
        when (alphaMode.lowercase()) {
            "mask" -> MaterialBuilder.BlendingMode.MASKED
            "blend" -> MaterialBuilder.BlendingMode.TRANSPARENT
            else -> MaterialBuilder.BlendingMode.OPAQUE
        }

    /**
     * Filament feature level 1 sampler cap — *declared* samplers in
     * the compiled material. Screen-space refraction reserves one,
     * so a transmission-armed variant caps at 8.
     */
    private fun samplerCapFor(extFlags: Int) =
        if (extFlags and FsceneRealizer.EXT_TRANSMISSION != 0) 8 else 9

    /**
     * Picks (or lazily compiles) the variant carrying [extFlags]'s
     * KHR_materials_* features, declaring samplers only for the
     * [boundSlots] texture set. Unlit materials ignore extensions on
     * the wire, so flags only apply to lit variants; flag-less
     * requests short-circuit onto the six prebuilts. Compilation
     * happens on first use inside the render callback — the same lane
     * every other decode runs on.
     *
     * A request that can't produce a compilable variant — a bound
     * set over the FL1 sampler cap, or a filamat/engine failure —
     * warns once and degrades to the matching base prebuilt: the
     * scene renders the base PBR material instead of fataling.
     */
    fun materialForVariant(
        unlit: Boolean,
        alphaMode: String,
        extFlags: Int,
        boundSlots: Int,
    ): VariantPick {
        val flags = if (unlit) 0 else extFlags
        fun base() = VariantPick(
            materialForAlphaMode(unlit, alphaMode), 0,
            if (unlit) 1 else FsceneRealizer.ALL_BASE_SLOTS)
        if (flags == 0) return base()
        val mode = alphaMode.lowercase()
        val key = VariantKey(unlit, mode, flags, boundSlots)
        materialVariants[key]?.let {
            return VariantPick(it, flags, boundSlots)
        }
        // Over-cap bound sets compile nothing — degrade before
        // filamat sees a package it must reject.
        if (boundSlots.countOneBits() > samplerCapFor(flags)) {
            warnOnce("variant.e$flags.s$boundSlots.cap",
                "material variant d3_lit_e$flags/$mode binds " +
                    "${boundSlots.countOneBits()} texture slots —" +
                    " over the FL1 sampler cap of" +
                    " ${samplerCapFor(flags)}; degrading to base" +
                    " d3_lit (extension lobes dropped)")
            return base()
        }
        if (key in failedVariants) return base()
        val built = try {
            buildMaterial(unlit, blendingForMode(mode), flags,
                boundSlots)
        } catch (e: Exception) {
            null
        }
        if (built == null) {
            failedVariants.add(key)
            warnOnce("variant.e$flags.s$boundSlots.compile",
                "material variant d3_lit_e$flags/$mode failed to" +
                    " compile — degrading to base d3_lit" +
                    " (extension lobes dropped)")
            return base()
        }
        materialVariants[key] = built
        return VariantPick(built, flags, boundSlots)
    }

    private fun warnOnce(tag: String, msg: String) {
        if (warnedOnce.add(tag)) Log.w(TAG, msg)
    }

    /**
     * Compiles one material package. Returns null when filamat or the
     * engine rejects it — the caller degrades (variants) or fatals
     * (the six prebuilts, which have no fallback).
     */
    private fun buildMaterial(
        unlit: Boolean,
        blending: MaterialBuilder.BlendingMode,
        extFlags: Int = 0,
        boundSlots: Int = 0,
    ): Material? {
        // MaterialBuilder.init() is a one-time static init of the
        // filamat backend — the builder itself is a fresh instance.
        if (!filamatReady) {
            MaterialBuilder.init()
            filamatReady = true
        }
        val blendSuffix = when (blending) {
            MaterialBuilder.BlendingMode.OPAQUE -> ""
            MaterialBuilder.BlendingMode.MASKED -> "_mask"
            else -> "_blend"
        }
        val extSuffix = if (extFlags != 0) "_e$extFlags" else ""
        val b = MaterialBuilder()
            .platform(MaterialBuilder.Platform.MOBILE)
            // W30: SPIR-V under Vulkan, GLSL under OpenGL — matched to
            // the backend the engine actually resolved (incl. fallback).
            // (TargetApi.ALL would be tempting; it doesn't emit Vulkan.)
            .targetApi(if (engine.backend == Engine.Backend.VULKAN)
                MaterialBuilder.TargetApi.VULKAN
                else MaterialBuilder.TargetApi.OPENGL)
            .name((if (unlit) "d3_unlit" else "d3_lit") + blendSuffix +
                extSuffix)
            .shading(if (unlit) MaterialBuilder.Shading.UNLIT
                else MaterialBuilder.Shading.LIT)
            // Baked capability so MaterialInstance.setDoubleSided works —
            // every instance is reset to single-sided at decode unless the
            // resource opts in (glTF/SceneKit default).
            .doubleSided(true)
            .blending(blending)
        if (extFlags and FsceneRealizer.EXT_TRANSMISSION != 0) {
            // KHR_materials_transmission → screen-space refraction;
            // KHR_materials_volume (thickness>0) upgrades the variant
            // to SOLID so `material.thickness`/`dispersion` are legal
            // — THIN reads the same thickness uniform as
            // `microThickness`.
            b.refractionMode(MaterialBuilder.RefractionMode.SCREEN_SPACE)
                .refractionType(
                    if (extFlags and FsceneRealizer.EXT_VOLUME_SOLID != 0)
                        MaterialBuilder.RefractionType.SOLID
                    else MaterialBuilder.RefractionType.THIN)
        }
        if (extFlags and FsceneRealizer.EXT_CLEARCOAT != 0) {
            // glTF's fixed-IOR (1.5) coat attenuates the lobes beneath
            // it — Filament models exactly that attenuation under
            // clearCoatIorChange.
            b.clearCoatIorChange(true)
        }
        // W21: every mesh record carries uv1 (zero-filled when the
        // wire layout lacks it), so the slot's `texCoord` can pick
        // either channel per texture.
        b.require(MaterialBuilder.VertexAttribute.UV0)
            .require(MaterialBuilder.VertexAttribute.UV1)
            .uniformParameter(MaterialBuilder.UniformType.FLOAT4, "baseColor")
            .uniformParameter(MaterialBuilder.UniformType.FLOAT4,
                "baseColorUVTransform")
            .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                "baseColorUVRotation")
            .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                "baseColorUVSet")
        // W22-r3: one declared sampler per *bound* texture slot —
        // Filament's FL1 cap counts declarations, so an extension
        // flag must not cost the slots the material leaves unbound.
        // The body below emits the matching factor-only term for
        // unbound slots. Prebuilts pass ALL_BASE_SLOTS: their
        // instances bind 1×1 fallbacks everywhere, keeping every
        // declared sampler sampled.
        val baseSlotCount =
            if (unlit) 1 else FsceneRealizer.BASE_TEXTURE_SLOTS.size
        for (i in 0 until baseSlotCount) {
            if (boundSlots and (1 shl i) == 0) continue
            b.samplerParameter(MaterialBuilder.SamplerType.SAMPLER_2D,
                MaterialBuilder.SamplerFormat.FLOAT,
                MaterialBuilder.ParameterPrecision.DEFAULT,
                FsceneRealizer.BASE_TEXTURE_SLOTS[i].param)
        }
        if (!unlit) {
            b.require(MaterialBuilder.VertexAttribute.TANGENTS)
                .uniformParameter(MaterialBuilder.UniformType.FLOAT, "metallic")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT, "roughness")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT4,
                    "emissiveColor")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "emissiveStrength")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "normalScale")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "occlusionStrength")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT4,
                    "normalUVTransform")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "normalUVRotation")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "normalUVSet")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT4,
                    "mrUVTransform")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "mrUVRotation")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "mrUVSet")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT4,
                    "occlusionUVTransform")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "occlusionUVRotation")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "occlusionUVSet")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT4,
                    "emissiveUVTransform")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "emissiveUVRotation")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "emissiveUVSet")
            // W22: extension slots/factors come from the same registry
            // buildMaterialInstance walks — the builder declares what
            // the decode writes, so the shader vocabulary can't drift.
            // UV uniforms stay flag-gated (uniforms don't hit the
            // sampler cap); samplers are bound-only.
            for ((i, slot) in FsceneRealizer.EXT_TEXTURE_SLOTS.withIndex()) {
                if (extFlags and slot.flag == 0) continue
                b.uniformParameter(MaterialBuilder.UniformType.FLOAT4,
                    "${slot.prefix}UVTransform")
                    .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                        "${slot.prefix}UVRotation")
                    .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                        "${slot.prefix}UVSet")
                if (boundSlots and FsceneRealizer.extSlotBit(i) != 0) {
                    b.samplerParameter(
                        MaterialBuilder.SamplerType.SAMPLER_2D,
                        MaterialBuilder.SamplerFormat.FLOAT,
                        MaterialBuilder.ParameterPrecision.DEFAULT,
                        "${slot.prefix}Map")
                }
            }
            for (f in FsceneRealizer.EXT_FACTORS) {
                if (extFlags and f.mask == 0) continue
                b.uniformParameter(
                    if (f.isColor) MaterialBuilder.UniformType.FLOAT4
                    else MaterialBuilder.UniformType.FLOAT, f.uniform)
            }
            if (extFlags and FsceneRealizer.EXT_TRANSMISSION != 0) {
                b.uniformParameter(MaterialBuilder.UniformType.FLOAT3,
                    "absorption")
            }
            if (extFlags and FsceneRealizer.EXT_ANISOTROPY != 0) {
                // 1 when an anisotropyTexture drives the direction —
                // the flat-normal fallback decodes to direction (0,0),
                // which normalize() would turn into NaN, so the shader
                // mixes the tangent-space +X default in instead.
                b.uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "anisotropyUseMap")
            }
        }
        // Per-slot UV transform (KHR_texture_transform):
        //   uv' = offset + R(rotation)·(scale ⊙ uv)
        // <slot>UVTransform packs (offset.xy, scale.xy); the mat2 takes
        // column-major args so (c,s,-s,c) is the standard CCW rotation.
        // Wire UVs are V=0-top (glTF/SceneKit) and uploads land top-row-
        // first at texel v=0, so no flipUV — see the report.
        fun slotBound(i: Int) = boundSlots and (1 shl i) != 0
        fun extBound(i: Int) =
            boundSlots and FsceneRealizer.extSlotBit(i) != 0
        val body = StringBuilder()
            .append("void material(inout MaterialInputs material) {\n")
            .append("    vec2 uv0 = getUV0();\n")
            .append("    vec2 uv1 = getUV1();\n")
        if (slotBound(0)) {
            body.append(uvBlock("baseColor"))
                .append("    material.baseColor = materialParams.baseColor" +
                    " * texture(materialParams_baseColorMap, baseColorUv);\n")
        } else {
            body.append("    material.baseColor = materialParams" +
                ".baseColor;\n")
        }
        if (!unlit) {
            if (slotBound(2)) {
                body.append(uvBlock("mr"))
                    .append("    vec4 mrTex = texture(" +
                        "materialParams_metallicRoughnessMap, mrUv);\n")
                    .append("    material.metallic = mrTex.b" +
                        " * materialParams.metallic;\n")
                    .append("    material.roughness = mrTex.g" +
                        " * materialParams.roughness;\n")
            } else {
                body.append("    material.metallic = materialParams" +
                    ".metallic;\n")
                    .append("    material.roughness = materialParams" +
                        ".roughness;\n")
            }
            if (slotBound(3)) {
                body.append(uvBlock("occlusion"))
                    .append("    material.ambientOcclusion = mix(1.0," +
                        " texture(materialParams_occlusionMap," +
                        " occlusionUv).r," +
                        " materialParams.occlusionStrength);\n")
            } else {
                body.append("    material.ambientOcclusion = 1.0;\n")
            }
            if (slotBound(1)) {
                body.append(uvBlock("normal"))
                    .append("    vec3 nTex = texture(" +
                        "materialParams_normalMap, normalUv).xyz" +
                        " * 2.0 - 1.0;\n")
                    .append("    material.normal = normalize(vec3(" +
                        "nTex.xy * materialParams.normalScale, nTex.z));\n")
            } else {
                body.append("    material.normal =" +
                    " vec3(0.0, 0.0, 1.0);\n")
            }
            if (slotBound(4)) {
                body.append(uvBlock("emissive"))
                    .append("    material.emissive = vec4(" +
                        "materialParams.emissiveColor.rgb *" +
                        " texture(materialParams_emissiveMap," +
                        " emissiveUv).rgb *" +
                        " materialParams.emissiveStrength, 0.0);\n")
            } else {
                // fallbackEmissive is black — a texture-less emissive
                // reads as off (pre-r3 semantics, preserved).
                body.append("    material.emissive = vec4(0.0);\n")
            }
            // W22: extension lobes — one block per feature flag, each
            // factor×texture matching the glTF channel spec. The
            // slot-prefixed uvBlocks carry KHR_texture_transform per
            // extension texture.
            if (extFlags and FsceneRealizer.EXT_CLEARCOAT != 0) {
                if (extBound(0)) {
                    body.append(uvBlock("clearCoat"))
                        .append("    material.clearCoat = materialParams" +
                            ".clearCoat * texture(materialParams" +
                            "_clearCoatMap, clearCoatUv).r;\n")
                } else {
                    body.append("    material.clearCoat = materialParams" +
                        ".clearCoat;\n")
                }
                if (extBound(1)) {
                    body.append(uvBlock("clearCoatRoughness"))
                        .append("    material.clearCoatRoughness =" +
                            " materialParams.clearCoatRoughness *" +
                            " texture(materialParams" +
                            "_clearCoatRoughnessMap," +
                            " clearCoatRoughnessUv).g;\n")
                } else {
                    body.append("    material.clearCoatRoughness =" +
                        " materialParams.clearCoatRoughness;\n")
                }
                if (extBound(2)) {
                    body.append(uvBlock("clearCoatNormal"))
                        .append("    vec3 ccN = texture(materialParams" +
                            "_clearCoatNormalMap, clearCoatNormalUv).xyz" +
                            " * 2.0 - 1.0;\n")
                        .append("    material.clearCoatNormal = normalize(" +
                            "vec3(ccN.xy * materialParams" +
                            ".clearCoatNormalScale, ccN.z));\n")
                } else {
                    body.append("    material.clearCoatNormal =" +
                        " vec3(0.0, 0.0, 1.0);\n")
                }
            }
            if (extFlags and FsceneRealizer.EXT_SHEEN != 0) {
                if (extBound(3)) {
                    body.append(uvBlock("sheenColor"))
                        .append("    material.sheenColor = materialParams" +
                            ".sheenColor.rgb * texture(materialParams" +
                            "_sheenColorMap, sheenColorUv).rgb;\n")
                } else {
                    body.append("    material.sheenColor = materialParams" +
                        ".sheenColor.rgb;\n")
                }
                if (extBound(4)) {
                    body.append(uvBlock("sheenRoughness"))
                        .append("    material.sheenRoughness =" +
                            " materialParams.sheenRoughness * texture(" +
                            "materialParams_sheenRoughnessMap," +
                            " sheenRoughnessUv).a;\n")
                } else {
                    body.append("    material.sheenRoughness =" +
                        " materialParams.sheenRoughness;\n")
                }
            }
            if (extFlags and FsceneRealizer.EXT_SPECULAR != 0) {
                if (extBound(5)) {
                    body.append(uvBlock("specular"))
                        .append("    material.specularFactor =" +
                            " materialParams.specularFactor * texture(" +
                            "materialParams_specularMap, specularUv).a;\n")
                } else {
                    body.append("    material.specularFactor =" +
                        " materialParams.specularFactor;\n")
                }
                if (extBound(6)) {
                    body.append(uvBlock("specularColor"))
                        .append("    material.specularColorFactor =" +
                            " materialParams.specularColorFactor.rgb *" +
                            " texture(materialParams_specularColorMap," +
                            " specularColorUv).rgb;\n")
                } else {
                    body.append("    material.specularColorFactor =" +
                        " materialParams.specularColorFactor.rgb;\n")
                }
            }
            if (extFlags and FsceneRealizer.EXT_ANISOTROPY != 0) {
                // glTF packs the tangent-space direction in rg
                // ([0,1]→[-1,1]) and the strength in b; the factor's
                // rotation applies on top in the same space.
                body.append("    float aCos = cos(materialParams" +
                    ".anisotropyRotation);\n")
                    .append("    float aSin = sin(materialParams" +
                        ".anisotropyRotation);\n")
                if (extBound(7)) {
                    body.append(uvBlock("anisotropy"))
                        .append("    vec4 aTex = texture(materialParams" +
                            "_anisotropyMap, anisotropyUv);\n")
                        .append("    vec2 aBase = mix(vec2(1.0, 0.0)," +
                            " aTex.rg * 2.0 - 1.0, materialParams" +
                            ".anisotropyUseMap);\n")
                        .append("    vec2 aDir = mat2(aCos, aSin," +
                            " -aSin, aCos) * aBase;\n")
                        .append("    material.anisotropy =" +
                            " materialParams.anisotropy * aTex.b;\n")
                } else {
                    body.append("    vec2 aDir = mat2(aCos, aSin," +
                        " -aSin, aCos) * vec2(1.0, 0.0);\n")
                        .append("    material.anisotropy =" +
                            " materialParams.anisotropy;\n")
                }
                body.append("    material.anisotropyDirection = vec3(" +
                    "aDir, 0.0);\n")
            }
            if (extFlags and FsceneRealizer.EXT_TRANSMISSION != 0) {
                if (extBound(8)) {
                    body.append(uvBlock("transmission"))
                        .append("    material.transmission =" +
                            " materialParams.transmission * texture(" +
                            "materialParams_transmissionMap," +
                            " transmissionUv).r;\n")
                } else {
                    body.append("    material.transmission =" +
                        " materialParams.transmission;\n")
                }
                body.append("    material.ior = materialParams.ior;\n")
                    .append("    material.absorption = materialParams" +
                        ".absorption;\n")
                if (extFlags and FsceneRealizer.EXT_VOLUME_SOLID != 0) {
                    if (extBound(9)) {
                        body.append(uvBlock("thickness"))
                            .append("    material.thickness =" +
                                " materialParams.thickness * texture(" +
                                "materialParams_thicknessMap," +
                                " thicknessUv).g;\n")
                    } else {
                        body.append("    material.thickness =" +
                            " materialParams.thickness;\n")
                    }
                    if (extFlags and FsceneRealizer.EXT_DISPERSION != 0) {
                        body.append("    material.dispersion =" +
                            " materialParams.dispersion;\n")
                    }
                } else {
                    // THIN has no `thickness` field — the same uniform
                    // feeds microThickness (Filament ignores
                    // thickness/dispersion on thin volumes).
                    if (extBound(9)) {
                        body.append(uvBlock("thickness"))
                            .append("    material.microThickness =" +
                                " materialParams.thickness * texture(" +
                                "materialParams_thicknessMap," +
                                " thicknessUv).g;\n")
                    } else {
                        body.append("    material.microThickness =" +
                            " materialParams.thickness;\n")
                    }
                }
            } else if (extFlags and FsceneRealizer.EXT_IOR != 0) {
                // KHR_materials_ior without transmission still applies
                // — Filament accepts `ior` as an alternative to
                // reflectance on lit materials.
                body.append("    material.ior = materialParams.ior;\n")
            }
        }
        // prepareMaterial must run AFTER material.normal is set — it
        // snapshots shading_normal through the tangent frame at call time.
        body.append("    prepareMaterial(material);\n}\n")
        // W22-r3: no check→fatal — a rejected package returns null
        // and the caller degrades to a base prebuilt (warn-once).
        val pkg = try {
            b.material(body.toString()).build()
        } catch (e: Exception) {
            null
        }
        if (pkg == null || !pkg.isValid) return null
        return try {
            Material.Builder()
                .payload(pkg.buffer, pkg.buffer.remaining())
                .build(engine)
        } catch (e: Exception) {
            null
        }
    }

    /**
     * W24 `shadowCatcher` — upstream ShadowCatcherMaterial's live
     * mode: the surface draws only the shadow it receives. Filament's
     * recipe is UNLIT + `shadowMultiplier`, which carries the
     * aggregated shadow visibility (1 = lit) into the fragment — the
     * output is upstream's `(shadowColor * alpha, alpha)` where
     * `alpha = shadowIntensity * (1 - visibility)`; TRANSPARENT
     * blending is premultiplied, so the rgb premultiply is literal.
     * `aoStrength`/`softness`/`fadeStart`/`fadeEnd`/`mode` have no
     * per-material analog on this path — the realizer warns once per
     * authored key.
     */
    private fun buildShadowCatcherMaterial(): Material {
        if (!filamatReady) {
            MaterialBuilder.init()
            filamatReady = true
        }
        val b = MaterialBuilder()
            .platform(MaterialBuilder.Platform.MOBILE)
            .name("d3_shadow_catcher")
            .shading(MaterialBuilder.Shading.UNLIT)
            .doubleSided(true)
            .blending(MaterialBuilder.BlendingMode.TRANSPARENT)
            // The catcher is still a real surface — it joins the
            // depth prepass like upstream's catcher does, so contact
            // shadows and occlusion read its depth.
            .depthWrite(true)
            .shadowMultiplier(true)
            .uniformParameter(MaterialBuilder.UniformType.FLOAT4,
                "shadowColor")
            .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                "shadowIntensity")
        // `shadowMultiplier` makes the engine multiply the FINAL
        // color — alpha included — by the shadow factor downstream;
        // no MaterialInputs field exposes it to read (1.71.6 emits
        // `shadowStrength`, a writable attenuation output). The
        // material only declares the catcher's max tint/opacity.
        val body = "void material(inout MaterialInputs material) {\n" +
            "    prepareMaterial(material);\n" +
            "    material.baseColor = vec4(" +
            "materialParams.shadowColor.rgb," +
            " materialParams.shadowColor.a * " +
            "materialParams.shadowIntensity);\n" +
            "}\n"
        val pkg = b.material(body).build()
        check(pkg.isValid) { "d3 shadow catcher failed to compile" }
        return Material.Builder()
            .payload(pkg.buffer, pkg.buffer.remaining())
            .build(engine)
    }

    /**
     * W16: the trail ribbon material — upstream's
     * `_TrailDefaultMaterial` port: translucent unlit, base color
     * driven fully by the vertex color (`getColor()` carries rgba,
     * so the colorOverTrail alpha fades the tail), double-sided via
     * the instance flag (a camera-facing strip's winding flips where
     * the path doubles back).
     */
    private fun buildTrailMaterial(): Material {
        if (!filamatReady) {
            MaterialBuilder.init()
            filamatReady = true
        }
        val b = MaterialBuilder()
            .platform(MaterialBuilder.Platform.MOBILE)
            .name("d3_trail")
            .shading(MaterialBuilder.Shading.UNLIT)
            .doubleSided(true)
            .blending(MaterialBuilder.BlendingMode.TRANSPARENT)
            .require(MaterialBuilder.VertexAttribute.COLOR)
        val pkg = b.material(
            "void material(inout MaterialInputs material) {\n" +
                "    prepareMaterial(material);\n" +
                "    material.baseColor = getColor();\n" +
                "}\n").build()
        check(pkg.isValid) { "d3 trail material failed to compile" }
        return Material.Builder()
            .payload(pkg.buffer, pkg.buffer.remaining())
            .build(engine)
    }

    /**
     * Emits `vec2 <slot>Uv = offset + R(rot)·(scale ⊙ uvSet)` where the
     * `<slot>UVSet` uniform selects getUV0()/getUV1() — the wire's
     * `texCoord` channel index (0 → uv0, ≥1 → uv1).
     */
    private fun uvBlock(slot: String): String {
        val t = "materialParams.${slot}UVTransform"
        val r = "materialParams.${slot}UVRotation"
        val s = "materialParams.${slot}UVSet"
        return "    vec2 ${slot}Uv = $t.xy + mat2(cos($r), sin($r)," +
            " -sin($r), cos($r)) * ($t.zw * ($s > 0.5 ? uv1 : uv0));\n"
    }

    // MARK: - W18 particles

    /**
     * nodeKey → that node's live particle runtimes. A manifest
     * Context's fresh map swaps in at install (same ownership as
     * nodeSkinning); a surgical Context aliases this map. The tick
     * loop in stepFrame drives them.
     */
    internal var particleRuntimes:
        MutableMap<Long, MutableList<ParticleRuntime>> = HashMap()
        private set

    /**
     * Compiled sprite materials — one per wire `blendMode` since
     * Filament bakes blending into the Material. Lazily built on
     * first use so a scene without sprite emitters pays nothing.
     */
    private var particleAlphaMaterial: Material? = null
    private var particleAdditiveMaterial: Material? = null

    internal fun particleMaterial(blendMode: String): Material {
        val additive = blendMode == "additive"
        val existing = if (additive) particleAdditiveMaterial
            else particleAlphaMaterial
        if (existing != null) return existing
        val m = buildParticleMaterial(additive)
        if (additive) particleAdditiveMaterial = m
        else particleAlphaMaterial = m
        return m
    }

    /**
     * The billboard material — vertices arrive already expanded into
     * WORLD space (vertexDomain passes mesh_position through), so the
     * renderable transform is a no-op. UV0/UV1 carry the two flipbook
     * cells; CUSTOM0 is the blend factor, forwarded through a custom
     * interpolant. `flipUV(false)` keeps v=0 = the uploaded image's
     * top row (upstream's quad UVs are authored v-top).
     */
    private fun buildParticleMaterial(additive: Boolean): Material {
        if (!filamatReady) {
            MaterialBuilder.init()
            filamatReady = true
        }
        val frag = StringBuilder()
            .append("void material(inout MaterialInputs material) {\n")
            .append("    vec4 tex = mix(texture(materialParams_particleMap," +
                " getUV0()), texture(materialParams_particleMap," +
                " getUV1()), variable_blendData.x);\n")
            .append("    vec4 c = getColor() * tex;\n")
        if (additive) {
            // Filament ADD is ONE/ONE — premultiply so the particle
            // alpha attenuates the contribution.
            frag.append("    material.baseColor = vec4(c.rgb * c.a," +
                " c.a);\n")
        } else {
            frag.append("    material.baseColor = c;\n")
        }
        frag.append("    prepareMaterial(material);\n}\n")
        val b = MaterialBuilder()
            .platform(MaterialBuilder.Platform.MOBILE)
            .targetApi(if (engine.backend == Engine.Backend.VULKAN)
                MaterialBuilder.TargetApi.VULKAN
                else MaterialBuilder.TargetApi.OPENGL)
            .name(if (additive) "d3_particle_add" else "d3_particle_alpha")
            .shading(MaterialBuilder.Shading.UNLIT)
            .vertexDomain(MaterialBuilder.VertexDomain.WORLD)
            .doubleSided(true)
            .culling(MaterialBuilder.CullingMode.NONE)
            .blending(if (additive) MaterialBuilder.BlendingMode.ADD
                else MaterialBuilder.BlendingMode.TRANSPARENT)
            .depthWrite(false)
            .flipUV(false)
            .require(MaterialBuilder.VertexAttribute.UV0)
            .require(MaterialBuilder.VertexAttribute.UV1)
            .require(MaterialBuilder.VertexAttribute.COLOR)
            .require(MaterialBuilder.VertexAttribute.CUSTOM0)
            .variable(MaterialBuilder.Variable.CUSTOM0, "blendData")
            .samplerParameter(MaterialBuilder.SamplerType.SAMPLER_2D,
                MaterialBuilder.SamplerFormat.FLOAT,
                MaterialBuilder.ParameterPrecision.DEFAULT, "particleMap")
            .materialVertex(
                "void materialVertex(inout MaterialVertexInputs m) {\n" +
                "    m.blendData = getCustom0();\n}\n")
            .material(frag.toString())
        val pkg = b.build()
        check(pkg.isValid) { "d3 particle material failed to compile" }
        return Material.Builder()
            .payload(pkg.buffer, pkg.buffer.remaining())
            .build(engine)
    }

    /**
     * `particleEmitter` realization — one dedicated entity whose
     * dynamic vertex buffer carries capacity×4 CPU-expanded world
     * quads. A dedicated entity (not the node's) so a `mesh`
     * component can co-exist on the same node.
     */
    internal fun createSpriteParticle(
        system: ParticleSystem,
        spec: SpriteEmitterSpec,
        layers: Int,
    ): SpriteParticleRuntime {
        val cap = system.storage.capacity
        val vb = SpriteParticleRuntime.buildVertexBuffer(engine, cap)
        val ib = SpriteParticleRuntime.buildIndexBuffer(engine, cap)
        val entity = EntityManager.get().create()
        val mi = particleMaterial(spec.blendMode).createInstance()
        RenderableManager.Builder(1)
            .geometry(0, RenderableManager.PrimitiveType.TRIANGLES,
                vb, ib, 0, 0)
            .material(0, mi)
            // World-space verts roam the whole scene — the box is a
            // formality (culling is off).
            .boundingBox(Box(0f, 0f, 0f, 1e4f, 1e4f, 1e4f))
            .layerMask(0xFF, layers and 0xFF)
            .castShadows(false)
            .receiveShadows(false)
            .culling(false)
            .build(engine, entity)
        val rt = SpriteParticleRuntime(
            this, system, spec, entity, vb, ib, mi, spec.texture)
        rt.layers = layers
        return rt
    }

    /**
     * `meshParticleEmitter` realization — a lazily-grown pool of
     * per-particle renderables (no InstanceBuffer in the Java
     * binding). `buckets`/`geoKeys` are parallel lists; a null bucket
     * waits on a pending geometry payload.
     */
    internal fun createMeshParticle(
        system: ParticleSystem,
        spec: MeshEmitterSpec,
        geoKeys: List<Long>,
        buckets: MutableList<GpuMesh?>,
        materialKey: Long?,
        parentEntity: Int,
        layers: Int,
    ): MeshParticleRuntime =
        MeshParticleRuntime(
            this, system, spec, geoKeys, buckets, materialKey,
            parentEntity, layers)

    /** Advances every live emitter then repacks — before render(),
     * after the camera pose settles (billboards face it). */
    private fun tickParticles(dt: Float) {
        if (particleRuntimes.isEmpty()) return
        val camPos = FloatArray(3)
        camera.getPosition(camPos)
        val tcm = engine.transformManager
        val wm = FloatArray(16)
        val it = particleRuntimes.entries.iterator()
        while (it.hasNext()) {
            val (key, list) = it.next()
            val rec = nodesById[key]
            if (rec == null) {
                // Node died without a teardown pass — defensive prune.
                it.remove()
                for (rt in list) rt.destroy()
                continue
            }
            val inst = tcm.getInstance(rec.entity)
            if (inst == 0) continue
            tcm.getWorldTransform(inst, wm)
            for (rt in list) rt.tick(dt.toDouble(), camPos, wm)
        }
    }

    private fun applyClearColor() {
        val opts = Renderer.ClearOptions()
        opts.clearColor = doubleArrayOf(
            clearColor[0].toDouble(), clearColor[1].toDouble(),
            clearColor[2].toDouble(), clearColor[3].toDouble())
        opts.clear = true
        renderer.clearOptions = opts
    }

    private fun applyProjection() {
        if (viewportH <= 0) return
        val aspect = viewportW.toDouble() / viewportH.toDouble()
        if (cameraOrtho) {
            // iOS maps projection:'orthographic' onto SCNCamera's
            // orthographicProjection; its orthographicScale is the
            // view half-height in world units, so top=+scale and
            // left/right follow the viewport aspect.
            val halfH = cameraOrthoScale
            val halfW = halfH * aspect
            camera.setProjection(Camera.Projection.ORTHO,
                -halfW, halfW, -halfH, halfH, cameraNear, cameraFar)
            Log.i(TAG, "ortho projection applied: halfH=$halfH" +
                " aspect=$aspect near=$cameraNear far=$cameraFar")
        } else {
            camera.setProjection(
                cameraFovDeg, aspect,
                cameraNear, cameraFar, Camera.Fov.VERTICAL)
        }
    }

    // MARK: - W7 environment / IBL helpers

    /** Lazily-built IBL pipeline helpers — the context and both run()
     * objects are reusable across decodes; Utils.init loads the
     * filament-utils JNI the same way the manipulator path does. */
    internal fun iblEquirect():
        IBLPrefilterContext.EquirectangularToCubemap {
        if (iblPrefilter == null) {
            Utils.init()
            iblPrefilter = IBLPrefilterContext(engine)
            iblEquirect = IBLPrefilterContext
                .EquirectangularToCubemap(iblPrefilter!!)
            iblSpecular =
                IBLPrefilterContext.SpecularFilter(iblPrefilter!!)
        }
        return iblEquirect!!
    }

    internal fun iblSpecular(): IBLPrefilterContext.SpecularFilter {
        iblEquirect() // lazily creates the trio
        return iblSpecular!!
    }

    /**
     * Swaps the lighting env: binds [il] (`null` → IBL off) and takes
     * ownership of the textures it was built from — replaced objects
     * are destroyed. Must run AFTER [applySkybox]: the old skybox may
     * still sample the old env cube until it is unbound.
     */
    internal fun applyEnvironment(il: IndirectLight?, textures: List<Texture>) {
        Log.i(TAG, "applyEnvironment: il=${il != null} textures=${textures.size}")
        scene.indirectLight = il
        envIndirectLight?.let {
            if (it !== il) engine.destroyIndirectLight(it) }
        for (t in envIblTextures) {
            if (textures.none { it === t }) engine.destroyTexture(t) }
        envIndirectLight = il
        envIblTextures.clear()
        envIblTextures.addAll(textures)
    }

    /** Swaps the background skybox (`null` → cleared — the renderer's
     * clearColor shows). Same replace-then-destroy contract. */
    internal fun applySkybox(sb: Skybox?, textures: List<Texture>) {
        Log.i(TAG, "applySkybox: sb=${sb != null} textures=${textures.size}")
        scene.skybox = sb
        envSkybox?.let { if (it !== sb) engine.destroySkybox(it) }
        for (t in envSkyboxTextures) {
            if (textures.none { it === t }) engine.destroyTexture(t) }
        envSkybox = sb
        envSkyboxTextures.clear()
        envSkyboxTextures.addAll(textures)
    }

    /**
     * The env resource's look fields — exposure + the tone-mapping
     * operator. `exposure` is a linear multiplier on Filament's
     * photometric default (f/16, 1/125 s, ISO 100 — the exposure the
     * scene's intensities were tuned under): the 3-arg
     * `setExposure(16, 1/125, 100·exposure)` expresses exactly that —
     * matching iOS's `exposureOffset = log2(exposure)` EV-offset
     * semantics. The 1-arg `setExposure(float)` can't express it: its
     * sensitivity floor of ISO 10 clamps the default exposure
     * (~1/38400) out of range.
     */
    internal fun applyStageLook(
        exposure: Float, toneMapping: String,
        agxWhite: Double, agxContrast: Double,
        fx: StageEffects? = null,
    ) {
        camera.setExposure(16.0f, 1.0f / 125.0f, 100.0f * exposure)
        // W14: exposure is a Camera property — every screen-bound view
        // camera takes it (offscreen views keep Filament's default,
        // the same policy as the per-View post stack).
        for (rec in screenViews) {
            rec.camera?.setExposure(16.0f, 1.0f / 125.0f,
                100.0f * exposure)
        }
        val mapper: ToneMapper = when (toneMapping) {
            "pbrNeutral" -> ToneMapper.PBRNeutralToneMapper()
            "agx" -> ToneMapper.Agx()
            "filmic" -> ToneMapper.Filmic()
            "aces" -> ToneMapper.ACES()
            "linear" -> ToneMapper.Linear()
            else -> {
                logCommandOnce("stage.toneMapping.$toneMapping",
                    "toneMapping '$toneMapping' unknown; using pbrNeutral")
                ToneMapper.PBRNeutralToneMapper()
            }
        }
        if (toneMapping == "agx" &&
            (agxWhite != 16.29 || agxContrast != 1.25)) {
            logCommandOnce("stage.agxLook",
                "agxWhite/agxContrast aren't tunable through the Java" +
                    " binding (AgxLook presets only); ignored")
        }
        val cgBuilder = ColorGrading.Builder().toneMapper(mapper)
        // W13 colorGrading block — merged into the same build (a View
        // binds exactly one ColorGrading).
        fx?.colorGrading?.takeIf { it.enabled }?.let { fxCg ->
            // Upstream brightness is a linear multiplier; Filament's
            // exposure is EV — log2 converts between them.
            if (fxCg.brightness != 1.0 && fxCg.brightness > 0.0) {
                cgBuilder.exposure(
                    kotlin.math.log2(fxCg.brightness).toFloat())
            }
            cgBuilder
                .contrast(fxCg.contrast.toFloat())
                .saturation(fxCg.saturation.toFloat())
                // Filament's white balance is the same normalized
                // −1..+1 temperature/tint the wire ships.
                .whiteBalance(fxCg.temperature.toFloat(),
                    fxCg.tint.toFloat())
                // ASC CDL: wire gain→slope, lift→offset, gamma→power.
                .slopeOffsetPower(fxCg.gain, fxCg.lift, fxCg.gamma)
            if (fxCg.lut.isNotEmpty()) {
                logCommandOnce("fx.colorGrading.lut",
                    "colorGrading LUT assets aren't resolved by dart3d" +
                        " yet; ignored")
            }
        }
        val cg = cgBuilder.build(engine)
        view.colorGrading = cg
        envColorGrading?.let {
            if (it !== cg) engine.destroyColorGrading(it) }
        envColorGrading = cg
    }

    /**
     * W13 `effects` post-stack → Filament View options. Absolute
     * apply: every options object is rebuilt from [lastEffects] and
     * assigned — the setters push a JNI snapshot, and the View
     * persists across installs so re-applying is idempotent.
     * `postProcessingEnabled` stays at its default — the toggles are
     * each option's own `enabled`. Blocks with no Java-binding surface
     * (film grain, god rays, GI volumes, auto-exposure) decode into
     * the model for parity and log once when enabled.
     */
    internal fun applyStageEffects() {
        val fx = lastEffects ?: return

        // Bloom + lens flare — Filament folds flare into BloomOptions.
        view.bloomOptions = View.BloomOptions().apply {
            enabled = fx.bloom.enabled
            strength = fx.bloom.intensity.toFloat()
            // Filament's `threshold` is a bool knee toggle; upstream's
            // 0..1 luminance cutoff lands on `highlight` instead.
            threshold = true
            highlight = fx.bloom.threshold.toFloat()
            levels = (3 + 8 * fx.bloom.scatter).toInt().coerceIn(3, 11)
            lensFlare = fx.lensFlare.enabled
            starburst = false
            chromaticAberration = if (fx.lensFlare.enabled)
                fx.lensFlare.chromaticAberration.toFloat() else 0.005f
            ghostCount = fx.lensFlare.ghostCount
            ghostSpacing = fx.lensFlare.ghostSpacing.toFloat()
            haloRadius = fx.lensFlare.haloRadius.toFloat()
            // haloIntensity has no Filament knob — approximated as
            // thickness (Filament's default haloThickness is 0.1).
            haloThickness = fx.lensFlare.haloIntensity.toFloat() * 0.1f
        }
        if (fx.chromaticAberration.enabled && !fx.lensFlare.enabled) {
            logCommandOnce("fx.ca",
                "chromaticAberration is bloom/lens-flare-scoped on" +
                    " Filament; enable lensFlare to see it")
        }

        view.vignetteOptions = View.VignetteOptions().apply {
            enabled = fx.vignette.enabled
            // upstream radius .75 ≈ Filament midPoint .25-ish —
            // 1−radius is the rough equivalent.
            midPoint =
                (1.0 - fx.vignette.radius).toFloat().coerceIn(0f, 1f)
            feather = fx.vignette.smoothness.toFloat()
            // Black vignette — Filament carries the effect strength
            // in the color's alpha.
            color = floatArrayOf(
                0f, 0f, 0f, fx.vignette.intensity.toFloat())
        }

        view.ambientOcclusionOptions =
            View.AmbientOcclusionOptions().apply {
                enabled = fx.ambientOcclusion.enabled
                radius = fx.ambientOcclusion.radius.toFloat()
                power = fx.ambientOcclusion.power.toFloat()
                bias = fx.ambientOcclusion.bias.toFloat()
                intensity = fx.ambientOcclusion.intensity.toFloat()
                resolution = if (fx.ambientOcclusion.halfResolution)
                    0.5f else 1.0f
                bentNormals = fx.ambientOcclusion.bentNormals
                minHorizonAngleRad =
                    fx.ambientOcclusion.horizonAngle.toFloat()
                quality = when {
                    fx.ambientOcclusion.sampleCount >= 24 ->
                        View.QualityLevel.ULTRA
                    fx.ambientOcclusion.sampleCount >= 16 ->
                        View.QualityLevel.HIGH
                    fx.ambientOcclusion.sampleCount >= 8 ->
                        View.QualityLevel.MEDIUM
                    else -> View.QualityLevel.LOW
                }
                // Upstream 'groundTruth' ≈ Filament's SSCT contact
                // shadows; the other ssct fields keep Filament
                // defaults.
                ssctEnabled = fx.ambientOcclusion.enabled &&
                    fx.ambientOcclusion.method == "groundTruth"
            }

        view.fogOptions = View.FogOptions().apply {
            enabled = fx.fog.enabled && fx.fog.mode != "none"
            // Filament's fog is a single exponential model — a wire
            // 'linear'/'exponentialSquared' is approximated by it.
            if (fx.fog.mode == "linear") {
                logCommandOnce("fx.fog.mode",
                    "fog mode 'linear' approximated by Filament's" +
                        " exponential fog")
            }
            color = fx.fog.color
            density = fx.fog.density.toFloat()
            distance = fx.fog.start.toFloat()
            cutOffDistance = if (fx.fog.cutoffDistance > 0)
                fx.fog.cutoffDistance.toFloat()
            else fx.fog.end.toFloat()
            maximumOpacity = fx.fog.maxOpacity.toFloat()
            height = fx.fog.height.toFloat()
            heightFalloff = fx.fog.heightFalloff.toFloat()
            inScatteringStart = fx.fog.start.toFloat()
            inScatteringSize = if (fx.fog.sunInScatter > 0)
                fx.fog.sunInScatter.toFloat() else -1f
            fogColorFromIbl = fx.fog.skyColorInfluence > 0
        }

        view.depthOfFieldOptions = View.DepthOfFieldOptions().apply {
            enabled = fx.depthOfField.enabled
            cocScale = fx.depthOfField.blurScale.toFloat()
            maxForegroundCOC =
                fx.depthOfField.maxForegroundBlur.toInt()
            maxBackgroundCOC =
                fx.depthOfField.maxBackgroundBlur.toInt()
            // Wire focalLength is mm (0 → the 28mm default); Filament
            // wants the aperture diameter in meters = f/fStop.
            val flm = if (fx.depthOfField.focalLength > 0)
                fx.depthOfField.focalLength * 0.001 else 0.028
            if (fx.depthOfField.fStop > 0) {
                maxApertureDiameter =
                    (flm / fx.depthOfField.fStop).toFloat()
            }
        }
        camera.focusDistance = fx.depthOfField.focusDistance.toFloat()
        // W14: same screen-view-camera propagation as the exposure —
        // DoF reads focusDistance off the Camera, and screen passes
        // run on the entries' own cameras.
        for (rec in screenViews) {
            rec.camera?.focusDistance =
                fx.depthOfField.focusDistance.toFloat()
        }
        if (fx.depthOfField.enabled && fx.depthOfField.bladeCount >= 3) {
            logCommandOnce("fx.dof.blades",
                "DoF blade shaping unsupported on Filament;" +
                    " circular bokeh")
        }

        // Filament 1.71.6 forwards only enabled/feedback/filterWidth
        // to native — upstream's other TAA fields have no knob.
        view.temporalAntiAliasingOptions =
            View.TemporalAntiAliasingOptions().apply {
                enabled = fx.temporalAntiAliasing.enabled
                feedback =
                    (1.0 - fx.temporalAntiAliasing.minimumCurrentWeight)
                        .toFloat().coerceIn(0f, 1f)
                filterWidth = (1.0 + fx.temporalAntiAliasing.sharpness)
                    .toFloat().coerceAtLeast(0.2f)
            }

        view.screenSpaceReflectionsOptions =
            View.ScreenSpaceReflectionsOptions().apply {
                enabled = fx.screenSpaceReflections.enabled
                thickness = fx.screenSpaceReflections.thickness.toFloat()
                maxDistance =
                    fx.screenSpaceReflections.maxDistance.toFloat()
                stride = fx.screenSpaceReflections.stride.toFloat()
                bias = 0.01f
            }
        val ssr = fx.screenSpaceReflections
        if (ssr.enabled && (ssr.intensity != 1.0 || ssr.maxSteps != 90 ||
                ssr.blur != 0.3 || ssr.distanceFadeStart != 0.0 ||
                ssr.resolutionScale != 1.0)) {
            logCommandOnce("fx.ssr.params",
                "some SSR fields unmapped on Filament 1.71.6" +
                    " (thickness/maxDistance/stride only)")
        }

        // No Java-binding surface — decoded for parity, logged once.
        if (fx.autoExposure.enabled) logCommandOnce("fx.autoExposure",
            "autoExposure unsupported on Filament (no Java-binding" +
                " auto-exposure)")
        if (fx.filmGrain.enabled) logCommandOnce("fx.filmGrain",
            "filmGrain unsupported on Filament")
        if (fx.globalIllumination.enabled) logCommandOnce("fx.gi",
            "globalIllumination volumes unsupported on Filament")
        if (fx.godRays.enabled) logCommandOnce("fx.godRays",
            "godRays unsupported on Filament")
    }

    // MARK: - Lifecycle

    override fun onDetachedFromWindow() {
        if (!detached) {
            detached = true
            Choreographer.getInstance().removeFrameCallback(frameCallback)
            // detach() fires onDetachedFromSurface → destroys the swap
            // chain while the engine is still alive.
            uiHelper.detach()
            swapChain?.let { engine.destroySwapChain(it) }
            swapChain = null
            // W7 env objects — unbind from the scene first, then
            // destroy; the prefilter helpers die last.
            scene.setIndirectLight(null)
            scene.setSkybox(null)
            envIndirectLight?.let { engine.destroyIndirectLight(it) }
            envIndirectLight = null
            envSkybox?.let { engine.destroySkybox(it) }
            envSkybox = null
            for (t in envIblTextures + envSkyboxTextures) {
                engine.destroyTexture(t)
            }
            envIblTextures.clear()
            envSkyboxTextures.clear()
            envColorGrading?.let { engine.destroyColorGrading(it) }
            envColorGrading = null
            iblEquirect?.destroy()
            iblSpecular?.destroy()
            iblPrefilter?.destroy()
            iblEquirect = null
            iblSpecular = null
            iblPrefilter = null
            world.close()
            // W18: particle runtimes own entities + buffers — retire
            // them before the node entity sweep.
            for ((_, list) in particleRuntimes) {
                for (rt in list) rt.destroy()
            }
            particleRuntimes.clear()
            val sweepCtx = FsceneRealizer.surgicalContext(this)
            for ((_, rec) in nodesById) {
                // W16: trail entities/buffers and the lod consumer
                // entry die with the node — the trail's unparented
                // entity isn't covered by the entity sweep below.
                sweepCtx.destroyTrailLod(rec)
                scene.removeEntity(rec.entity)
                engine.destroyEntity(rec.entity)
                EntityManager.get().destroy(rec.entity)
            }
            nodesById.clear()
            bodies.clear()
            dynamicBodyKeys.clear()
            for ((_, g) in gpuMeshes) {
                // GpuMesh.destroy also owns the MorphTargetBuffer.
                g.destroy(engine)
            }
            gpuMeshes = HashMap()
            // W11: SkinningBuffers live outside the GpuMesh registry —
            // the engine teardown doesn't auto-free them.
            for ((_, s) in nodeSkinning) {
                engine.destroySkinningBuffer(s.buffer)
            }
            nodeSkinning.clear()
            animClips.clear()
            animTargets.clear()
            for ((_, m) in materialInstances) engine.destroyMaterialInstance(m)
            materialInstances = HashMap()
            // W14: per-entry Views/Cameras and rt recs die here — the
            // rec owns its textures, so the texture sweep skips rt
            // keys (the shared `view` lets go of rec cameras first).
            view.camera = camera
            for (rec in viewRecs) destroyViewObjects(rec)
            viewRecs.clear()
            screenViews.clear()
            for ((k, t) in resources.textures) {
                if (!renderTargets.containsKey(k)) {
                    engine.destroyTexture(t)
                }
            }
            for ((_, rec) in renderTargets) destroyRenderTargetRec(rec)
            renderTargets = HashMap()
            nodeCameraProps = HashMap()
            resources = FsceneRealizer.Context.InstalledResources()
            engine.destroyTexture(fallbackWhite)
            engine.destroyTexture(fallbackNormal)
            engine.destroyTexture(fallbackEmissive)
            engine.destroyMaterial(litMaterial)
            engine.destroyMaterial(litMaskedMaterial)
            engine.destroyMaterial(litBlendMaterial)
            engine.destroyMaterial(unlitMaterial)
            engine.destroyMaterial(unlitMaskedMaterial)
            engine.destroyMaterial(unlitBlendMaterial)
            catcherMaterialBacking?.let { engine.destroyMaterial(it) }
            // W18: the lazily-built sprite materials.
            particleAlphaMaterial?.let { engine.destroyMaterial(it) }
            particleAdditiveMaterial?.let { engine.destroyMaterial(it) }
            particleAlphaMaterial = null
            particleAdditiveMaterial = null
            for ((_, m) in materialVariants) engine.destroyMaterial(m)
            materialVariants.clear()
            engine.destroyMaterial(trailMaterial)
            engine.destroyRenderer(renderer)
            engine.destroyView(view)
            engine.destroyScene(scene)
            engine.destroyCameraComponent(cameraEntity)
            EntityManager.get().destroy(cameraEntity)
            engine.destroy()
        }
        super.onDetachedFromWindow()
    }

    // MARK: - Mutation application (mirrors SceneViewHost)

    /**
     * Scene/Jolt mutations are only safe on the frame thread —
     * `stepFrame`'s `world.update` iterates body/constraint state with
     * no external lock (the iOS twin of this race crashed inside
     * SceneKit's constraint sort). Everything enqueues here and drains
     * at the top of `stepFrame`; FIFO keeps the hello gate and diff
     * ordering identical to the old inline apply.
     */
    private val pendingWork = ConcurrentLinkedQueue<() -> Unit>()

    // Payload arrivals flag a re-realize instead of running one
    // inline: a doc's N chunks drained in one frame then cost one
    // decode, not N. Only touched on the drain thread.
    private var realizePending = false

    fun onMutation(id: Long, eventTag: Int, data: ByteArray) {
        if (detached) return
        pendingWork.offer {
            viewId = id
            if (eventTag == D3_MSG_HELLO) {
                sawHello = true
            } else if (!sawHello && !warnedNoHello) {
                warnedNoHello = true
                Log.w(TAG, "eventTag=$eventTag before hello")
            }
            when (eventTag) {
                D3_MSG_HELLO -> applyHello(data)
                D3_MSG_VIEW_CONFIG -> applyViewConfig(data)
                D3_MSG_LOAD_SCENE -> applyLoadScene(data)
                D3_MSG_PAYLOAD -> applyPayload(data)
                D3_MSG_SET_TRANSFORMS -> applySetTransforms(data)
                D3_MSG_COMMAND -> applyCommand(data)
                else -> Log.w(TAG, "unknown eventTag=$eventTag")
            }
        }
    }

    private fun applyHello(data: ByteArray) {
        if (data.size < 2) return
        Log.i(TAG, "protocol hello: Dart v${data[0]}.${data[1]}")
        if (data[0].toInt() != 1) {
            Log.w(TAG, "unsupported protocol major v${data[0]}; expect 1.x")
        }
    }

    private fun applyViewConfig(data: ByteArray) {
        val json = try { JSONObject(String(data, Charsets.UTF_8)) }
            catch (e: Exception) { return }
        if (json.has("allowsCameraControl")) {
            if (json.optBoolean("allowsCameraControl")) attachCameraControl()
            else detachCameraControl()
        }
        if (json.has("showsStatistics")) {
            setShowsStatistics(json.optBoolean("showsStatistics"))
        }
        if (json.has("antialiasingMode")) {
            val v = json.optInt("antialiasingMode")
            // W14: the viewConfig level of every view's AA resolve
            // chain — re-resolve so a mid-run toggle rewrites views
            // that inherit it.
            viewConfigAa = v
            for (rec in viewRecs) resolveViewQuality(rec)
            // iOS semantics: 0 = none, 2/4 = MSAA sample count. Other
            // values clamp to the nearest count SceneKit can express
            // (3 ties down to 2, matching its v>=4→4X / v>=2→2X map).
            val count = when {
                v <= 0 -> 0
                v == 2 || v == 4 -> v
                v < 4 -> 2.also {
                    logCommandOnce("aa.$v",
                        "antialiasingMode $v: clamped to MSAA x2")
                }
                else -> 4.also {
                    logCommandOnce("aa.$v",
                        "antialiasingMode $v: clamped to MSAA x4")
                }
            }
            val msaa = View.MultiSampleAntiAliasingOptions()
            msaa.enabled = v > 0
            if (count > 0) msaa.sampleCount = count
            view.multiSampleAntiAliasingOptions = msaa
            // iOS pairs its MSAA with its own filtering — FXAA stays
            // on top, same as the previous boolean mapping.
            view.antiAliasing = if (v > 0) View.AntiAliasing.FXAA
                else View.AntiAliasing.NONE
            Log.i(TAG, "antialiasingMode=$v → MSAA enabled=${msaa.enabled}" +
                " sampleCount=${msaa.sampleCount} aa=${view.antiAliasing}")
        }
        if (json.has("quality")) {
            val q = json.optString("quality")
            viewQuality =
                if (q == "low" || q == "medium" || q == "high") q
                else null
            applyViewQuality()
        }
        if (json.has("backgroundColor")) {
            val argb = json.optInt("backgroundColor")
            clearColor = floatArrayOf(
                ((argb shr 16) and 0xFF) / 255f,
                ((argb shr 8) and 0xFF) / 255f,
                (argb and 0xFF) / 255f,
                ((argb ushr 24) and 0xFF) / 255f)
        }
    }

    /**
     * Applies the view-quality tier — runs whenever `viewConfig`
     * carries a `quality` key. 'low' disables shadowing on every view;
     * medium/high keep it on. The tier replaces [viewConfigAa] in the
     * AA resolve chain, so re-resolving rewrites every view's MSAA/AA
     * (and the default pass's, via the restore path at next views op —
     * applied here directly too since no views op may follow).
     */
    private fun applyViewQuality() {
        val shadows = viewQuality != "low"
        view.setShadowingEnabled(shadows)
        for (rec in viewRecs) {
            rec.view?.setShadowingEnabled(shadows)
            resolveViewQuality(rec)
        }
        if (screenViews.isEmpty()) {
            val restored = RenderTargets.resolveAa(
                null, null, effectiveViewConfigAa())
            view.multiSampleAntiAliasingOptions = restored.msaa
            view.antiAliasing = restored.aa
        }
        Log.i(TAG, "quality=${viewQuality ?: "default"} → " +
            "shadows=$shadows aaSrc=${effectiveViewConfigAa()}")
    }

    private fun applyLoadScene(data: ByteArray) {
        lastManifest = data
        // Payload ids are document-local (session,index) — a previous
        // document's bytes would shadow this doc's chunks at colliding
        // keys (bundled assets share the importer's session salt, so
        // index 4 in doc A is index 4 in doc B). The manifest's own
        // chunks arrive next, so the store starts empty and every
        // payload claim defers until its own bytes land.
        payloadStore.clear()
        realizePending = false
        // W15: the new document's session keys invalidate every
        // recorded subtree batch — drop them before the realize, and
        // any pending visible-stamp with them (its node id belongs to
        // the outgoing scene).
        streamedSubtreeOps.clear()
        subtreeVisibleStamp = null
        FsceneRealizer.realize(data, this)
    }

    private fun applyPayload(data: ByteArray) {
        if (data.size <= 8) return
        val id = D3Wire.readLocalId(data, 0)
        payloadStore[id] = data.copyOfRange(8, data.size)
        // W7: an environment equirect chunk re-runs decodeStage on the
        // live scene — the same early-out `upsertPayload` takes, and
        // the only path that doesn't depend on other resources still
        // being pending. No early return: a chunk the env shares with
        // another claimant must still reach the checks below.
        if (resources.environmentPayloadIds.values.contains(id)) {
            FsceneRealizer.surgicalContext(this).decodeStage(lastStage)
        }
        // W11 claims run surgically first — a skin's IBM chunk or an
        // animation's timeline/keyframes chunk re-decodes just its
        // owner, like the `upsertPayload` path (and keeps live clips
        // alive where a full re-realize would reset them).
        for ((skinKey, pid) in resources.skinPayloadIds) {
            if (pid != id) continue
            resources.skinDefs[skinKey]?.let { redecodeSkin(skinKey, it) }
        }
        for ((animKey, pids) in resources.animPayloadIds) {
            if (id !in pids) continue
            resources.animDefs[animKey]?.let { redecodeAnimation(animKey, it) }
        }
        if (pendingPayloadRefs.isNotEmpty() && lastManifest != null) {
            // The deferred set holds resource ids, not payload ids —
            // one re-realize at the end of the drain retries them all;
            // a decoder whose payload is still missing re-marks itself
            // pending.
            realizePending = true
        }
    }

    /// `[u32 count]` × `[8B id][u8 mask][masked t/r/s f32s]` — identical
    /// to the iOS walk.
    private fun applySetTransforms(data: ByteArray) {
        if (data.size < 4) return
        val count = D3Wire.u32LE(data, 0)
        var off = 4
        for (n in 0 until count) {
            if (off + 9 > data.size) return
            val id = D3Wire.readLocalId(data, off)
            val mask = data[off + 8].toInt()
            off += 9
            val rec = nodesById[id]
            if (rec == null) {
                Log.w(TAG, "setTransforms: unknown id=$id mask=$mask")
                // Read past the masked fields to stay aligned.
                off += (if (mask and 1 != 0) 12 else 0) +
                    (if (mask and 2 != 0) 16 else 0) +
                    (if (mask and 4 != 0) 12 else 0)
                continue
            }
            if (mask and 1 != 0) {
                rec.localPos = D3Wire.position(doubleArrayOf(
                    D3Wire.f32LE(data, off).toDouble(),
                    D3Wire.f32LE(data, off + 4).toDouble(),
                    D3Wire.f32LE(data, off + 8).toDouble()))
                off += 12
            }
            if (mask and 2 != 0) {
                rec.localQuat = D3Wire.quaternion(doubleArrayOf(
                    D3Wire.f32LE(data, off).toDouble(),
                    D3Wire.f32LE(data, off + 4).toDouble(),
                    D3Wire.f32LE(data, off + 8).toDouble(),
                    D3Wire.f32LE(data, off + 12).toDouble()))
                off += 16
            }
            if (mask and 4 != 0) {
                rec.localScale = D3Wire.scale(doubleArrayOf(
                    D3Wire.f32LE(data, off).toDouble(),
                    D3Wire.f32LE(data, off + 4).toDouble(),
                    D3Wire.f32LE(data, off + 8).toDouble()))
                off += 12
            }
            applyLocalTransform(rec)
        }
    }

    /** Pushes a node's local TRS into the transform manager; teleports
     * its physics body if it carries one (the `setNodeTransforms` →
     * body write the watchdog uses). */
    internal fun applyLocalTransform(rec: FsceneRealizer.NodeRec) {
        val local = D3Wire.trs(rec.localPos, rec.localQuat, rec.localScale)
        // Instance handles go stale when another transform component is
        // destroyed (storage compacts) — resolve per use.
        engine.transformManager.setTransform(
            engine.transformManager.getInstance(rec.entity), local)
        val body = rec.body ?: return
        val wm = worldMatOf(rec)
        val (wp, wq) = FsceneRealizer.worldPoseOf(wm)
        world.teleport(body, wp, wq)
    }

    private fun worldMatOf(rec: FsceneRealizer.NodeRec): FloatArray {
        var m = D3Wire.trs(rec.localPos, rec.localQuat, rec.localScale)
        var p = rec.parentKey
        while (p != null) {
            val pr = nodesById[p] ?: break
            val pm = D3Wire.trs(pr.localPos, pr.localQuat, pr.localScale)
            val out = FloatArray(16)
            Matrix.multiplyMM(out, 0, pm, 0, m, 0)
            m = out
            p = pr.parentKey
        }
        return m
    }

    /// Structural/physics ops (`{"op": …}`) — same op vocabulary as iOS.
    private fun applyCommand(data: ByteArray) {
        val json = try { JSONObject(String(data, Charsets.UTF_8)) }
            catch (e: Exception) {
                Log.w(TAG, "command parse failed: ${data.size}B"); return }
        applyCommandJson(json)
    }

    /**
     * The decoded-op dispatch — also the recursion point for the W15
     * `loadSubtree`/`unloadSubtree` envelopes, whose nested `ops` run
     * through the same handlers.
     */
    private fun applyCommandJson(json: JSONObject) {
        when (val op = json.optString("op")) {
            "removeNode" -> {
                Log.i(TAG, "cmd removeNode")
                val key = jsonKey(json) ?: return
                if (nodesById[key] == null) {
                    Log.w(TAG, "removeNode: node $key not live — no-op")
                    return
                }
                // SCN's removeFromParentNode drops the subtree; drain
                // every node whose ancestor chain reaches `key`.
                val ids = ArrayList<Long>()
                ids.add(key)
                for ((k, rec) in nodesById) {
                    var p = rec.parentKey
                    while (p != null) {
                        if (p == key) { ids.add(k); break }
                        p = nodesById[p]?.parentKey
                    }
                }
                val doomed = ids.toSet()
                val destroyedEntities = HashSet<Int>()
                val rmCtx = FsceneRealizer.surgicalContext(this)
                for (id in ids) {
                    val rec = nodesById.remove(id) ?: continue
                    // W18: particle runtimes own entities/buffers —
                    // destroy before the node entity (mesh slots are
                    // its transform children).
                    particleRuntimes.remove(id)
                        ?.forEach { it.destroy() }
                    // W16: the trail's unparented entity + dynamic
                    // buffers and the lod consumer entry die with the
                    // node — neither rides rec.entity's teardown.
                    rmCtx.destroyTrailLod(rec)
                    scene.removeEntity(rec.entity)
                    engine.destroyEntity(rec.entity)
                    EntityManager.get().destroy(rec.entity)
                    destroyedEntities.add(rec.entity)
                    // W12: the node's own component-joint registrations
                    // first — the world sweep below then sees only
                    // command joints and other nodes' component joints
                    // that reference this node.
                    dropComponentJointsForNode(id)
                    world.removeJointsForNode(id)
                    rec.body?.let { world.removeBody(it) }
                    bodies.remove(id)
                    dynamicBodyKeys.remove(id)
                    // W11: the skinning buffer is a GPU object — the
                    // entity teardown doesn't own it.
                    nodeSkinning.remove(id)?.let {
                        engine.destroySkinningBuffer(it.buffer)
                    }
                    // W12 rectAreaLight: the cluster's child entities
                    // aren't covered by the parent entity's teardown.
                    for (child in rec.lightEntities) {
                        scene.removeEntity(child)
                        engine.destroyEntity(child)
                        EntityManager.get().destroy(child)
                    }
                }
                // Dead entities can't take a re-attached material —
                // drop them from the upsert consumer maps; node-keyed
                // registries prune by id.
                for ((_, list) in resources.materialConsumers) {
                    list.removeAll { it.first in destroyedEntities }
                }
                for ((_, set) in resources.geometryConsumers) {
                    set.removeAll(doomed)
                }
                resources.nodeSkinKeys.keys.removeAll(doomed)
                // W14: retained camera props for removed nodes — a
                // view still bound to one keeps its last pose and a
                // default projection (same tolerance as the default
                // camera path).
                nodeCameraProps.keys.removeAll(doomed)
                // W12: variant components and enabled marks keyed by
                // removed nodes (their joint registrations went above).
                resources.variantComponents.keys.removeAll(doomed)
                resources.disabledComponents.keys.removeAll(doomed)
                // Bind poses captured for removed nodes go too —
                // upstream keeps orphaned `_targetTransforms` entries
                // but they only write back when the node exists, so
                // pruning is equivalent and keeps the map small.
                animTargets.keys.removeAll(doomed)
                pendingParents.entries.removeAll {
                    it.key in doomed || it.value in doomed
                }
                // W15: a doomed placeholder's replay record dies with
                // it — otherwise the next payload-arrival re-realize
                // would resurrect the streamed subtree.
                streamedSubtreeOps.keys.removeAll(doomed)
                if (cameraNodeKey != null && cameraNodeKey in doomed) {
                    cameraNodeKey = null
                }
            }
            "applyImpulse" -> {
                val rec = physicsNode(json) ?: run {
                    Log.w(TAG, "cmd applyImpulse: no such node/body"); return }
                val body = rec.body ?: return
                val v = vec(json.optJSONArray("impulse")) ?: return
                val imp = D3Wire.position(v)
                val at = vec(json.optJSONArray("position"))
                val bi = world.bodyInterface
                // AddImpulse doesn't wake a sleeping body — it lands
                // on the velocity but never integrates. Wake first.
                bi.activateBody(body.id)
                if (at != null) {
                    val p = D3Wire.position(at)
                    bi.addImpulse(body.id, Vec3(imp[0], imp[1], imp[2]),
                        RVec3(p[0].toDouble(), p[1].toDouble(), p[2].toDouble()))
                } else {
                    bi.addImpulse(body.id, Vec3(imp[0], imp[1], imp[2]))
                }
            }
            "applyTorque" -> {
                val rec = physicsNode(json) ?: return
                val body = rec.body ?: return
                val t = vec(json.optJSONArray("torque")) ?: return
                if (t.size != 4) return
                val bi = world.bodyInterface
                bi.activateBody(body.id)
                // Axis is a pseudovector: mirrors like a quaternion axis.
                bi.addAngularImpulse(body.id, Vec3(
                    (-t[0] * t[3]).toFloat(),
                    (-t[1] * t[3]).toFloat(),
                    (t[2] * t[3]).toFloat()))
            }
            "setVelocity" -> {
                val key = jsonKey(json) ?: return
                val rec = nodesById[key] ?: run {
                    Log.w(TAG, "cmd setVelocity: no such node"); return }
                val body = rec.body ?: run {
                    Log.w(TAG, "cmd setVelocity: node $key has no body")
                    return }
                val bi = world.bodyInterface
                // Velocity writes don't wake a sleeping body either —
                // without activation a zeroed-then-impulsed die stays
                // asleep and the toss never happens.
                bi.activateBody(body.id)
                vec(json.optJSONArray("velocity"))?.let { v ->
                    val c = D3Wire.position(v)
                    bi.setLinearVelocity(body.id, Vec3(c[0], c[1], c[2]))
                }
                vec(json.optJSONArray("angularVelocity"))?.let { a ->
                    if (a.size == 4) {
                        bi.setAngularVelocity(body.id, Vec3(
                            (-a[0] * a[3]).toFloat(),
                            (-a[1] * a[3]).toFloat(),
                            (a[2] * a[3]).toFloat()))
                    }
                }
            }
            "clearForces" -> {
                // Jolt has no persistent-force accumulator (impulses
                // only) — clearing velocity is the closest analogue, but
                // that would fight `setVelocity` sends; log and no-op.
                if (physicsNode(json) != null) {
                    Log.v(TAG, "clearForces: no persistent forces in Jolt — no-op")
                }
            }
            "upsertResource" -> applyUpsertResource(json)
            "upsertPayload" -> applyUpsertPayload(json)
            "updateStage" -> applyUpdateStage(json)
            "addNode" -> applyAddNode(json)
            "updateNode" -> applyUpdateNode(json)
            "query" -> applyQuery(json)
            "addJoint" -> applyJoint(json, update = false)
            "updateJoint" -> applyJoint(json, update = true)
            "removeJoint" -> applyRemoveJoint(json)
            "selectVariant" -> applySelectVariant(json)
            "anim" -> applyAnim(json)
            "upsertSkin" -> applyUpsertSkin(json)
            "removeSkin" -> applyRemoveSkin(json)
            "upsertAnimation" -> applyUpsertAnimation(json)
            "removeAnimation" -> applyRemoveAnimation(json)
            "setMorphWeights" -> applySetMorphWeights(json)
            "render" -> applyRender(json)
            "updateViews" -> applyUpdateViews(json)
            "loadSubtree" -> applySubtree(json, loading = true)
            "unloadSubtree" -> applySubtree(json, loading = false)
            else -> Log.w(TAG, "unknown command op '$op'")
        }
    }

    /**
     * `{"op":"loadSubtree"|"unloadSubtree","node":"<token>",
     * "ops":[<op>,…]}` — the W15 streaming envelope. `node` must be
     * live (it is the placeholder); the nested ops apply in order
     * through the ordinary dispatch inside this one drain, so the
     * subtree lands or drops atomically between frames. A tag state
     * that disagrees with the op (load on an untagged node, unload
     * on a still-tagged one) means the Dart-side bookkeeping
     * disagrees with the wire — warn and apply anyway, since the
     * batch is self-describing.
     */
    private fun applySubtree(json: JSONObject, loading: Boolean) {
        val opName = if (loading) "loadSubtree" else "unloadSubtree"
        val key = jsonKey(json) ?: run {
            Log.w(TAG, "$opName: bad node token"); return }
        val ops = json.optJSONArray("ops") ?: run {
            Log.w(TAG, "$opName: missing ops"); return }
        // The batch doubles as this subtree's replay record — a
        // payload-arrival re-realize wipes surgical adds along with
        // the manifest's nodes, and the drain-end replay rebuilds
        // each live subtree from its recorded load batch. An unload
        // drops the record first so a wiped placeholder can't
        // resurrect its subtree; a load records only once the
        // placeholder is known live.
        if (!loading) streamedSubtreeOps.remove(key)
        val rec = nodesById[key] ?: run {
            // A stale record must not survive a dead placeholder —
            // unload already removed above; a load on a missing node
            // drops whatever lingered (iOS removes for both).
            streamedSubtreeOps.remove(key)
            Log.w(TAG, "$opName: node $key not live — no-op"); return }
        // A re-load's re-put keeps the record's load-order slot —
        // replay order stays load order, so a subtree another stream's
        // members parent into still replays before its dependents
        // (iOS replaces the record in place — same semantics).
        if (loading) streamedSubtreeOps[key] = ops
        // The tag state that disagrees with the op is the mismatch —
        // a load expects the placeholder still tagged (its first
        // nested op clears it); an unload expects it cleared already
        // (the batch re-tags it last).
        if (loading && rec.instanceSpec == null) {
            Log.w(TAG, "$opName: node $key has no instance tag; applying")
        } else if (!loading && rec.instanceSpec != null) {
            Log.w(TAG, "$opName: node $key still tagged; applying")
        }
        for (i in 0 until ops.length()) {
            ops.optJSONObject(i)?.let { applyCommandJson(it) }
        }
        // The drain applying a subtree runs at the top of stepFrame —
        // the frame rendered after this drain is the first it's
        // visible in; stepFrame stamps it for the latency lane.
        subtreeVisibleStamp = Triple(key, System.nanoTime(), "$opName:${ops.length()}")
    }

    /** W15: (node key, apply nanoTime, label) set by applySubtree and
     * consumed by the next stepFrame render — the first frame the
     * landed/cleared subtree is on screen, logged for the latency
     * measurement (the Dart side logs the send time against this). */
    private var subtreeVisibleStamp: Triple<Long, Long, String>? = null

    /** W15: live subtree replay records — placeholder key → the load
     * batch's nested ops, in load order. A payload-arrival re-realize
     * (the deferred-resource retry) rebuilds the manifest scene
     * wholesale, discarding every surgical add; the recorded batches
     * replay after `realize` to restore what was streamed. A plain
     * `removeNode` that dooms a placeholder also drops its record,
     * and `applyLoadScene` clears the map — a new document's session
     * keys invalidate the old batches. */
    private val streamedSubtreeOps = LinkedHashMap<Long, JSONArray>()

    /** Guards the deferred-resource re-realize during a subtree
     * replay: a replayed `upsertPayload` that leaves unrelated
     * pending refs must not re-arm `realizePending` — that would
     * rebuild the scene once per frame. */
    private var subtreeReplayActive = false

    /** Replays each live subtree's recorded load batch through the
     * ordinary op dispatch — called right after a payload-arrival
     * re-realize has rebuilt the manifest scene. */
    private fun replayStreamedSubtrees() {
        if (streamedSubtreeOps.isEmpty()) return
        subtreeReplayActive = true
        try {
            // A replayed batch can doom a later record's placeholder
            // (a priorRoots removeNode taking a placeholder grafted
            // into the doomed subtree): removeNode prunes the map
            // inline, so iterate a snapshot — and skip records whose
            // placeholder is already dead, since their addNodes would
            // resolve a dead parent and root the resurrected members
            // at scene root.
            val dead = HashSet<Long>()
            for ((key, ops) in streamedSubtreeOps.toList()) {
                if (nodesById[key] == null) {
                    dead += key
                    continue
                }
                for (i in 0 until ops.length()) {
                    ops.optJSONObject(i)?.let { applyCommandJson(it) }
                }
                if (nodesById[key] == null) {
                    Log.w(TAG, "subtree replay: placeholder $key" +
                        " missing after re-realize")
                }
            }
            streamedSubtreeOps.keys.removeAll(dead)
        } finally {
            subtreeReplayActive = false
        }
    }

    /**
     * `{"op":"upsertResource","id":"<res>","resource":{kind,…}}` — the
     * surgical lane-10 path: re-decode one resource and rebind what
     * consumed it, without a scene re-realize (physics bodies survive).
     */
    private fun applyUpsertResource(json: JSONObject) {
        val token = json.optString("id")
        val key = D3Wire.localIdKey(token) ?: run {
            Log.w(TAG, "upsertResource: bad id '$token'"); return }
        val res = json.optJSONObject("resource") ?: run {
            Log.w(TAG, "upsertResource: missing resource object"); return }
        when (val kind = res.optString("kind")) {
            "texture" -> upsertTexture(key, res)
            "material" -> upsertMaterial(key, res)
            "geometry" -> upsertGeometry(key, res)
            "renderTexture" -> upsertRenderTexture(key, res)
            // An environment resource holds no realized object of its
            // own — the stage consumes it — so an env upsert stores
            // the def and, when the current stage names it, re-runs
            // decodeStage on the live scene (the diff's updateStage
            // op does the same; running here too keeps a lone env
            // upsert meaningful).
            "environment" -> {
                resources.environments[key] = res
                val stageRef = lastStage?.optString("environmentRef")
                    ?.takeIf { it.isNotEmpty() }
                    ?.let { D3Wire.localIdKey(it) }
                if (stageRef == key) {
                    FsceneRealizer.surgicalContext(this)
                        .decodeStage(lastStage)
                }
            }
            else -> logCommandOnce("upsertResource.$kind",
                "upsertResource kind '$kind' not implemented")
        }
    }

    /**
     * `{"op":"updateStage","stage":{…}}` — re-runs `decodeStage`
     * against the live context (W7). The diff ships the referenced
     * env resource's `upsertResource` first, so `environmentRef`
     * resolves here; a payload-backed env still in flight defers and
     * re-runs when the chunk lands (mirrors iOS `applyUpdateStage`).
     */
    private fun applyUpdateStage(json: JSONObject) {
        val stage = json.optJSONObject("stage") ?: run {
            logCommandOnce("updateStage.malformed",
                "updateStage: missing stage")
            return
        }
        FsceneRealizer.surgicalContext(this).decodeStage(stage)
    }

    // MARK: - W14 render targets + views

    /**
     * `{"op":"render","target":"rt:<tok>"}` — marks a `manual` target
     * dirty for one pass; on an `interval` target the dirty mark
     * forces an early refresh (both documented on the wire).
     */
    private fun applyRender(json: JSONObject) {
        val token = json.optString("target")
        val key = D3Wire.localIdKey(token)
        val rec = key?.let { renderTargets[it] }
        if (rec == null) {
            logCommandOnce("render.$key",
                "render: target '$token' is not a live render texture")
            return
        }
        rec.dirty = true
    }

    /**
     * `{"op":"updateViews","views":[<entries>]}` — wholesale-replaces
     * the view list: re-decode against the live registries (a camera
     * node or rt shipped in the same batch resolves — the op lands
     * last), then teardown + rebuild the per-entry engine objects.
     */
    private fun applyUpdateViews(json: JSONObject) {
        val arr = json.optJSONArray("views") ?: run {
            logCommandOnce("updateViews.malformed",
                "updateViews: missing views array")
            return
        }
        val ctx = FsceneRealizer.surgicalContext(this)
        ctx.decodeViews(arr)
        applyViews(ctx.views)
    }

    /**
     * `upsertResource` of kind `renderTexture` — rebuilds the rec's
     * textures + RenderTarget, retargets the views that drew into it,
     * and rebinds material consumers BEFORE the old objects die (the
     * upsertTexture rebind-then-destroy contract).
     */
    private fun upsertRenderTexture(key: Long, res: JSONObject) {
        val old = renderTargets[key]
        val spec = RenderTargets.decodeSpec(key, res) ?: return
        val rec = RenderTargets.build(engine, spec)
        rec.dirty = true   // fresh pixels need one pass (iOS parity)
        if (old != null) {
            rec.views.addAll(old.views)
            old.views.clear()
            for (v in rec.views) {
                v.view?.setRenderTarget(rec.rt)
                // A full-target viewport follows the new dims; an
                // explicit entry viewport keeps its authored rect.
                if (v.viewport == null) {
                    v.view?.viewport =
                        Viewport(0, 0, spec.width, spec.height)
                }
            }
        }
        renderTargets[key] = rec
        // The color texture keeps the material-binding contract —
        // same key in `textures`, bound with the rec's own sampler.
        resources.textures[key] = rec.colorTex
        resources.textureSamplers[key] = rec.sampler
        var n = 0
        for ((mi, param) in resources.textureConsumers[key].orEmpty()) {
            mi.setParameter(param, rec.colorTex, rec.sampler)
            n++
        }
        if (old != null) {
            engine.destroyRenderTarget(old.rt)
            engine.destroyTexture(old.colorTex)
            old.depthTex?.let { engine.destroyTexture(it) }
        }
        Log.i(TAG, "upsertResource renderTexture $key:" +
            " ${spec.width}x${spec.height} ${spec.update}," +
            " rebound $n consumer(s)")
    }

    /**
     * Rebuilds the live view list — called from `install` (the
     * manifest's `views`) and `updateViews`. Old entries' engine
     * objects die first (a View unbinds its RenderTarget — the rt
     * outlives it across a view-list swap); each new entry gets its
     * own Camera + entity, and rt-targeted entries get their own View.
     * Screen-targeted entries share [view] — the pass loop pushes
     * their camera/viewport/quality per render — so when none exist
     * `view` is restored to the default pass exactly.
     */
    private fun applyViews(recs: List<RenderTargets.ViewRec>) {
        // The shared screen view must never hold a dying camera.
        view.camera = camera
        for (rec in viewRecs) destroyViewObjects(rec)
        viewRecs.clear()
        screenViews.clear()
        for ((_, rt) in renderTargets) rt.views.clear()
        for (rec in recs.sortedBy { it.order }) {
            val camEntity = EntityManager.get().create()
            val cam = engine.createCamera(camEntity)
            rec.cameraEntity = camEntity
            rec.camera = cam
            val tk = rec.targetKey
            if (tk != null) {
                val rtRec = renderTargets[tk]
                if (rtRec == null) {
                    // Resolved at decode; an rt that died between
                    // decode and apply drops the entry like an
                    // unresolved ref.
                    destroyViewObjects(rec)
                    continue
                }
                val v = engine.createView()
                v.scene = scene
                v.camera = cam
                // Post-processing on a user RenderTarget routes through
                // an intermediate blit — offscreen passes keep the raw
                // draw so the color attachment is the literal frame.
                v.isPostProcessingEnabled = false
                v.setShadowType(View.ShadowType.DPCF)
                v.setShadowingEnabled(viewQuality != "low")
                v.setRenderTarget(rtRec.rt)
                v.viewport = rec.viewport?.let { viewportOf(it) }
                    ?: Viewport(0, 0, rtRec.spec.width,
                        rtRec.spec.height)
                v.setVisibleLayers(0xFF, rec.layerMask and 0xFF)
                rec.view = v
                rtRec.views.add(rec)
            } else {
                // Screen entry — an extra swapchain pass on `view`,
                // rendered in `order` after the default pass is
                // skipped (entries ARE the screen view list).
                screenViews.add(rec)
            }
            resolveViewQuality(rec)
            viewRecs.add(rec)
        }
        if (screenViews.isEmpty()) {
            // No screen entries — `view` returns to the default pass:
            // restore the state a screen pass may have clobbered.
            view.viewport = Viewport(0, 0, viewportW, viewportH)
            view.setVisibleLayers(0xFF, 0xFF)
            view.dynamicResolutionOptions = View.DynamicResolutionOptions()
            val restored = RenderTargets.resolveAa(null, null,
                effectiveViewConfigAa())
            view.multiSampleAntiAliasingOptions = restored.msaa
            view.antiAliasing = restored.aa
        }
        Log.i(TAG, "views applied: ${viewRecs.size} entries" +
            " (${screenViews.size} screen," +
            " ${renderTargets.count { it.value.views.isNotEmpty() }} rts)")
    }

    /**
     * Destroys a view entry's engine objects — View (unbound from its
     * RenderTarget first), Camera component, then the entity. Safe on
     * an already-destroyed rec (fields null out).
     */
    private fun destroyViewObjects(rec: RenderTargets.ViewRec) {
        rec.view?.let {
            it.setRenderTarget(null)
            engine.destroyView(it)
        }
        rec.view = null
        rec.camera = null
        if (rec.cameraEntity != 0) {
            engine.destroyCameraComponent(rec.cameraEntity)
            EntityManager.get().destroy(rec.cameraEntity)
            rec.cameraEntity = 0
        }
    }

    /**
     * Tears down one rt rec — its views' engine objects first, then
     * the RenderTarget, then the textures. Material consumers of the
     * colorTex must already be rebound or dead — the same contract
     * `upsertTexture` keeps.
     */
    private fun destroyRenderTargetRec(rec: RenderTargets.RenderTargetRec) {
        for (v in rec.views) destroyViewObjects(v)
        rec.views.clear()
        engine.destroyRenderTarget(rec.rt)
        engine.destroyTexture(rec.colorTex)
        rec.depthTex?.let { engine.destroyTexture(it) }
    }

    /**
     * Stage view-quality defaults (W14) — `decodeStage` writes them;
     * live views re-resolve so an `updateStage` re-applies without a
     * view rebuild.
     */
    internal fun applyStageQuality(
        aa: String?, renderScale: Double, filterQuality: String,
    ) {
        stageAntiAliasing = aa
        stageRenderScale = renderScale
        stageFilterQuality = filterQuality
        for (rec in viewRecs) resolveViewQuality(rec)
    }

    /**
     * Resolves one view's quality trio ONCE at build/re-resolve —
     * AA (entry → stage → viewConfig → Filament default), renderScale
     * (screen entries only — a fixed scale through
     * DynamicResolutionOptions, min==max, not the semantic dynamic-res
     * knob; rt dims are authoritative), and filterQuality (decoded +
     * retained only — no Java-binding knob; non-'medium' logs once).
     */
    private fun resolveViewQuality(rec: RenderTargets.ViewRec) {
        val resolved = RenderTargets.resolveAa(
            rec.aaMode, stageAntiAliasing, effectiveViewConfigAa())
        rec.msaa = resolved.msaa
        rec.aa = resolved.aa
        rec.dsr = RenderTargets.dsrOptions(
            rec.renderScale ?: stageRenderScale)
        rec.view?.let {
            it.multiSampleAntiAliasingOptions = resolved.msaa
            it.antiAliasing = resolved.aa
        }
        val fq = rec.filterQuality ?: stageFilterQuality
        if (fq != "medium") {
            logCommandOnce("w14.filterQuality",
                "filterQuality '$fq' isn't settable through the Java" +
                    " binding; ignored")
        }
    }

    /**
     * Per-frame view-camera update — every view entry's Camera takes
     * its camera node's world transform and re-projects from the
     * node's retained props at the view's aspect (rt dims offscreen,
     * the entry viewport or the surface on screen).
     */
    private fun updateViewCameras() {
        if (viewRecs.isEmpty()) return
        val tcm = engine.transformManager
        val wm = FloatArray(16)
        for (rec in viewRecs) {
            val cam = rec.camera ?: continue
            val node = nodesById[rec.cameraKey] ?: continue
            val inst = tcm.getInstance(node.entity)
            if (inst == 0) continue
            tcm.getWorldTransform(inst, wm)
            cam.setModelMatrix(wm)
            val spec = nodeCameraProps[rec.cameraKey]
                ?: RenderTargets.CameraSpec.DEFAULT
            spec.applyTo(cam, viewAspect(rec))
        }
    }

    /** The aspect a view's projection uses — rt dims for offscreen
     *  views, the entry viewport (or the surface) for screen views. */
    private fun viewAspect(rec: RenderTargets.ViewRec): Double {
        val tk = rec.targetKey
        if (tk != null) {
            val s = renderTargets[tk]?.spec
            return if (s != null && s.height > 0)
                s.width.toDouble() / s.height else 1.0
        }
        val vp = rec.viewport
        if (vp != null && vp.size == 4 && vp[3] > 0.0) {
            return vp[2] / vp[3]
        }
        return if (viewportH > 0)
            viewportW.toDouble() / viewportH else 1.0
    }

    private fun viewportOf(vp: DoubleArray): Viewport =
        Viewport(vp[0].toInt(), vp[1].toInt(), vp[2].toInt(),
            vp[3].toInt())

    private fun upsertTexture(key: Long, res: JSONObject) {
        // Record the spec + payload linkage up front so a pending upsert
        // still resolves through a later upsertPayload.
        resources.textureResources[key] = res
        val pid = res.optString("payload")
            .takeIf { it.isNotEmpty() }
            ?.let { D3Wire.localIdKey(it) }
        if (pid != null) resources.texturePayloadIds[key] = pid
        else resources.texturePayloadIds.remove(key)
        when (val r = TextureFactory.realize(
            this, key, res, resources.payloadSpecs)) {
            is TextureFactory.Result.Ready -> {
                resources.textures[key]?.let { engine.destroyTexture(it) }
                resources.textures[key] = r.texture
                pendingPayloadRefs.remove(key)
                var n = 0
                val sampler =
                    resources.textureSamplers[key] ?: textureSampler
                for ((mi, param) in resources.textureConsumers[key].orEmpty()) {
                    mi.setParameter(param, r.texture, sampler)
                    n++
                }
                Log.i(TAG, "upsertResource texture $key: rebound $n consumer(s)")
            }
            TextureFactory.Result.Pending ->
                Log.i(TAG, "texture $key: awaiting payload")
            TextureFactory.Result.Failed -> Unit // reason already logged
        }
    }

    private fun upsertMaterial(key: Long, res: JSONObject) {
        val old = materialInstances[key]
        val fresh = HashMap<Long, MutableList<Pair<MaterialInstance, String>>>()
        val mi = FsceneRealizer.buildMaterialInstance(
            this, key, res, resources.textures, resources.textureSamplers,
            fresh)
        // The old instance's consumer entries die with it; the new
        // instance records its own slot bindings.
        if (old != null) {
            for ((_, list) in resources.textureConsumers) {
                list.removeAll { it.first === old }
            }
        }
        for ((texKey, list) in fresh) {
            resources.textureConsumers
                .getOrPut(texKey) { ArrayList() }
                .addAll(list)
        }
        // Re-attach to every renderable that consumed the material.
        val rm = engine.renderableManager
        var n = 0
        val it = resources.materialConsumers[key]?.iterator()
        while (it != null && it.hasNext()) {
            val (entity, primSlot) = it.next()
            if (rm.hasComponent(entity)) {
                // setMaterialInstanceAt takes the component instance,
                // not the entity — resolve per use. A multi-primitive
                // mesh re-attaches at its own slot.
                rm.setMaterialInstanceAt(
                    rm.getInstance(entity), primSlot, mi)
                n++
            } else {
                it.remove()
            }
        }
        materialInstances[key] = mi
        resources.materialResources[key] = res
        if (old != null) {
            // A destroyed MaterialInstance can't re-attach — clear it
            // from variant binding state; the re-apply below resolves
            // defaults/selections against the fresh instance.
            for ((_, vc) in resources.variantComponents) {
                for (b in vc.bindings) {
                    if (b.applied === old) b.applied = null
                    if (b.defaultMaterial === old) b.defaultMaterial = null
                }
            }
            engine.destroyMaterialInstance(old)
        }
        Log.i(TAG, "upsertResource material $key: reattached to $n renderable(s)")
        // W12: variant bindings holding the old instance re-resolve to
        // the fresh one (a rebound slot reads as a foreign write and
        // becomes the new default — the upstream rebase rule).
        FsceneRealizer.surgicalContext(this).applyVariantComponents()
    }

    private fun upsertGeometry(key: Long, res: JSONObject) {
        FsceneRealizer.surgicalContext(this).redecodeGeometry(key, res)
        // W12: rebuilt renderables reset their slots to the material
        // list — reapply selections.
        FsceneRealizer.surgicalContext(this).applyVariantComponents()
    }

    /**
     * `{"op":"addNode","node":"<token>","parent":"<token>"|null,
     * "spec":{…manifest node json…}}` — creates the node, applies every
     * spec field, and attaches under parent (absent/null → scene root).
     * `spec.children` is not wired — each child self-attaches via its
     * own addNode, so ops are order-independent within a batch.
     */
    private fun applyAddNode(json: JSONObject) {
        val key = jsonKey(json) ?: run {
            Log.w(TAG, "addNode: bad node token"); return }
        val spec = json.optJSONObject("spec") ?: run {
            Log.w(TAG, "addNode: missing spec"); return }
        val parentKey = json.optString("parent")
            .takeIf { it.isNotEmpty() }?.let { D3Wire.localIdKey(it) }
        val ctx = FsceneRealizer.surgicalContext(this)
        if (nodesById.containsKey(key)) {
            // A re-sent batch lands here — apply the spec as a full
            // update (all flags), parent included.
            Log.w(TAG, "addNode on live id; treating as update")
            ctx.updateNode(key, ALL_NODE_FLAGS, spec, parentKey)
        } else {
            ctx.addNode(key, spec, parentKey)
        }
        adoptCamera(ctx)
    }

    /**
     * `{"op":"updateNode","node":"<token>","flags":[…],"spec":{…},
     * "parent":"<token>"?}` — applies only the flagged fields;
     * `reparented` reads `parent` (null → root).
     */
    private fun applyUpdateNode(json: JSONObject) {
        val key = jsonKey(json) ?: run {
            Log.w(TAG, "updateNode: bad node token"); return }
        if (nodesById[key] == null) {
            Log.w(TAG, "updateNode: node $key not live — no-op"); return
        }
        val spec = json.optJSONObject("spec") ?: run {
            Log.w(TAG, "updateNode: missing spec"); return }
        val flags = json.optJSONArray("flags")?.let { a ->
            (0 until a.length()).mapTo(HashSet()) { a.optString(it) }
        } ?: emptySet()
        val parentKey = json.optString("parent")
            .takeIf { it.isNotEmpty() }?.let { D3Wire.localIdKey(it) }
        val ctx = FsceneRealizer.surgicalContext(this)
        ctx.updateNode(key, flags, spec, parentKey)
        adoptCamera(ctx)
    }

    /**
     * A surgical decode that produced a camera claims the view camera
     * when none is held — first-camera-wins, same as install.
     */
    private fun adoptCamera(ctx: FsceneRealizer.Context) {
        val camKey = ctx.firstCameraKey ?: return
        if (cameraNodeKey == null) {
            cameraNodeKey = camKey
            ctx.cameraProps?.let { applyCameraProps(it) }
        }
    }

    private fun applyCameraProps(props: JSONObject) {
        props.tag("fovRadiansY").d3Double()?.let {
            cameraFovDeg = it * 180.0 / Math.PI
        }
        props.tag("near").d3Double()?.let { cameraNear = it }
        props.tag("far").d3Double()?.let { cameraFar = it }
        // projection:{s:'orthographic'} — anything else (or absent) is
        // the perspective path. orthoScale is the provisional wire
        // field carrying SCN's orthographicScale (half-height); the
        // SCN default of 1.0 applies when the doc omits it.
        cameraOrtho = props.tag("projection").d3String() == "orthographic"
        cameraOrthoScale = props.tag("orthoScale").d3Double()
            ?: props.tag("orthographicScale").d3Double() ?: 1.0
        applyProjection()
    }

    /**
     * `allowsCameraControl` — attaches a filament-utils ORBIT
     * manipulator as the stand-in for SCNView's built-in orbit/pan/
     * zoom. Seeded from the camera node's current world pose; the
     * orbit pivot is the point on the camera's forward ray nearest
     * the world origin (≈ scene center for an aimed camera, which is
     * where SCN's control pivots). Also re-runs on scene install —
     * the new doc's camera re-seeds it.
     */
    private fun attachCameraControl() {
        var eye = floatArrayOf(0f, 0f, 5f)
        var target = floatArrayOf(0f, 0f, 0f)
        var up = floatArrayOf(0f, 1f, 0f)
        val rec = cameraNodeKey?.let { nodesById[it] }
        // Cleared first — a stale snapshot must never restore onto a
        // different camera node after a re-install.
        savedCameraTrs = null
        if (rec != null) {
            val wm = FloatArray(16)
            engine.transformManager.getWorldTransform(
                engine.transformManager.getInstance(rec.entity), wm)
            eye = floatArrayOf(wm[12], wm[13], wm[14])
            // Filament cameras look down local -Z with +Y up.
            val f = normalized(floatArrayOf(-wm[8], -wm[9], -wm[10]))
            up = normalized(floatArrayOf(wm[4], wm[5], wm[6]))
            val d = sqrt(eye[0] * eye[0] + eye[1] * eye[1] +
                eye[2] * eye[2])
            target = floatArrayOf(
                eye[0] + f[0] * d, eye[1] + f[1] * d, eye[2] + f[2] * d)
            savedCameraTrs = arrayOf(
                rec.localPos.copyOf(), rec.localQuat.copyOf(),
                rec.localScale.copyOf())
        }
        // Manipulator's JNI bindings live in filament-utils-jni —
        // nothing else loads it (Utils.init is idempotent).
        Utils.init()
        val m = Manipulator.Builder()
            .viewport(viewportW.coerceAtLeast(1), viewportH.coerceAtLeast(1))
            .orbitHomePosition(eye[0], eye[1], eye[2])
            .targetPosition(target[0], target[1], target[2])
            .upVector(up[0], up[1], up[2])
            .build(Manipulator.Mode.ORBIT)
        manipulator = m
        lastManipEye = null
        // GestureDetector maps 1-finger drag → orbit grab, 2-finger
        // drag → pan grab, pinch → scroll — it only translates the
        // MotionEvent stream; the write-back happens per frame in
        // updateCamera.
        gestureDetector = GestureDetector(surfaceView, m)
        Log.i(TAG, "camera manipulator attached (orbit," +
            " eye=(${eye[0]},${eye[1]},${eye[2]})" +
            " target=(${target[0]},${target[1]},${target[2]}))")
    }

    private fun detachCameraControl() {
        if (manipulator == null) return
        manipulator = null
        gestureDetector = null
        lastManipEye = null
        cameraMovedLogged = false
        // Restore the node-authored pose snapshotted at attach.
        val rec = cameraNodeKey?.let { nodesById[it] }
        val trs = savedCameraTrs
        if (rec != null && trs != null) {
            rec.localPos = trs[0]; rec.localQuat = trs[1]
            rec.localScale = trs[2]
            applyLocalTransform(rec)
        }
        savedCameraTrs = null
        Log.i(TAG, "camera manipulator detached; node-authored pose restored")
    }

    /** `showsStatistics` HUD — attaches/detaches the overlay child. */
    private fun setShowsStatistics(show: Boolean) {
        if (show == (statsOverlay != null)) return
        if (show) {
            val tv = TextView(context)
            tv.setTextColor(0xFFE8E8E8.toInt())
            tv.setBackgroundColor(0x80000000.toInt())
            tv.typeface = Typeface.MONOSPACE
            tv.textSize = 11f
            val pad = (context.resources.displayMetrics.density * 8).toInt()
            tv.setPadding(pad, pad / 2, pad, pad / 2)
            addView(tv, LayoutParams(
                LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.START))
            statsOverlay = tv
            statsWindowStart = 0L
            statsFrames = 0
            Log.i(TAG, "stats overlay attached")
        } else {
            statsOverlay?.let { removeView(it) }
            statsOverlay = null
            Log.i(TAG, "stats overlay detached")
        }
    }

    /** Per-frame stats tick — text refresh throttled to ~4 Hz. */
    private fun tickStats(tNanos: Long) {
        val tv = statsOverlay ?: return
        if (statsWindowStart == 0L) statsWindowStart = tNanos
        statsFrames++
        val elapsed = tNanos - statsWindowStart
        if (elapsed >= 250_000_000L) {
            val fps = statsFrames * 1e9 / elapsed.toDouble()
            val ms = elapsed / 1e6 / statsFrames.toDouble()
            tv.text = String.format(Locale.US,
                "%.0f fps  %.1f ms\n%d entities  %d bodies",
                fps, ms, nodesById.size, bodies.size)
            // Same numbers in logcat so the W30 backend A/B and perf
            // lanes read frame times without watching the screen.
            Log.i(TAG, String.format(Locale.US,
                "stats %.0f fps  %.1f ms/frame  %d entities  %d bodies",
                fps, ms, nodesById.size, bodies.size))
            statsWindowStart = tNanos
            statsFrames = 0
        }
    }

    private fun normalized(v: FloatArray): FloatArray {
        val l = sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
        if (l > 0f) { v[0] /= l; v[1] /= l; v[2] /= l }
        return v
    }

    private fun logCommandOnce(tag: String, msg: String) {
        if (commandLoggedOnce.add(tag)) Log.i(TAG, msg)
    }

    /**
     * `{"op":"upsertPayload","id":"<payload>","bytes":<b64|[ints]>}` —
     * stores the chunk, then re-uploads + rebinds every texture it
     * backs (W4) or re-decodes + rebinds every geometry it backs (W5).
     * An unclaimed chunk that can still unblock deferred manifest
     * resources falls back to the `payload`-mutation re-realize.
     */
    private fun applyUpsertPayload(json: JSONObject) {
        val token = json.optString("id")
        val key = D3Wire.localIdKey(token) ?: run {
            Log.w(TAG, "upsertPayload: bad id '$token'"); return }
        val raw = json.opt("bytes")
        val bytes = when (raw) {
            is String -> try {
                Base64.decode(raw, Base64.DEFAULT)
            } catch (e: Exception) { null }
            is JSONArray -> ByteArray(raw.length()) { raw.optInt(it).toByte() }
            else -> null
        } ?: run {
            Log.w(TAG, "upsertPayload: missing/undecodable bytes"); return }
        // A runtime-minted chunk carries its spec on the op — the
        // manifest's `payloads` block only describes install-time
        // chunks, so without this its consumers never decode.
        json.optString("encoding").takeIf { it.isNotEmpty() }?.let { enc ->
            val meta = FsceneRealizer.Context.PayloadMeta(
                encoding = enc,
                layout = json.optString("layout").takeIf { it.isNotEmpty() },
                format = json.optString("format").takeIf { it.isNotEmpty() },
                width = (json.opt("width") as? Number)?.toInt(),
                height = (json.opt("height") as? Number)?.toInt(),
                length = (json.opt("length") as? Number)?.toInt(),
            )
            resources.payloadSpecs[key] = meta
            opPayloadSpecs[key] = meta
        }
        payloadStore[key] = bytes
        // W7: an environment equirect chunk re-runs decodeStage on the
        // live scene (its payload deferral unblocks here). Checked
        // first — env payloads also carry encoding:'image'.
        if (resources.environmentPayloadIds.values.contains(key)) {
            FsceneRealizer.surgicalContext(this).decodeStage(lastStage)
            return
        }
        val texKeys = resources.texturePayloadIds
            .filter { it.value == key }.keys.toList()
        if (texKeys.isNotEmpty()) {
            for (texKey in texKeys) {
                val spec = resources.textureResources[texKey] ?: continue
                when (val r = TextureFactory.realize(
                    this, texKey, spec, resources.payloadSpecs)) {
                    is TextureFactory.Result.Ready -> {
                        resources.textures[texKey]?.let {
                            engine.destroyTexture(it) }
                        resources.textures[texKey] = r.texture
                        pendingPayloadRefs.remove(texKey)
                        var n = 0
                        val sampler = resources.textureSamplers[texKey]
                            ?: textureSampler
                        for ((mi, param) in
                            resources.textureConsumers[texKey].orEmpty()) {
                            mi.setParameter(param, r.texture, sampler)
                            n++
                        }
                        Log.i(TAG, "upsertPayload $key: texture $texKey" +
                            " re-uploaded, rebound $n consumer(s)")
                    }
                    else -> Log.i(TAG, "upsertPayload $key: texture $texKey" +
                        " still unresolved")
                }
            }
            return
        }
        // W5: vertex/index chunks backing geometry resources —
        // re-decode each claiming geometry and rebind its consumers.
        val geoKeys = resources.geometryPayloadIds
            .filter { key in it.value }.keys.toList()
        if (geoKeys.isNotEmpty()) {
            val ctx = FsceneRealizer.surgicalContext(this)
            for (geoKey in geoKeys) {
                val spec = resources.geometryResources[geoKey] ?: continue
                ctx.redecodeGeometry(geoKey, spec)
            }
            return
        }
        // W11: an IBM chunk re-decodes its skin; a timeline/keyframes
        // chunk re-decodes its animation (live clips keep playback —
        // the rebind clamps to the new endTime).
        val skinKeys = resources.skinPayloadIds
            .filter { it.value == key }.keys.toList()
        if (skinKeys.isNotEmpty()) {
            for (skinKey in skinKeys) {
                resources.skinDefs[skinKey]?.let { redecodeSkin(skinKey, it) }
            }
            return
        }
        val animKeys = resources.animPayloadIds
            .filter { key in it.value }.keys.toList()
        if (animKeys.isNotEmpty()) {
            for (animKey in animKeys) {
                resources.animDefs[animKey]?.let {
                    redecodeAnimation(animKey, it)
                }
            }
            return
        }
        if (pendingPayloadRefs.isNotEmpty()) {
            // W15: a chunk replayed after a subtree-restoring
            // re-realize must not re-arm the next one — the pending
            // set can outlive the replay when other refs still wait.
            if (lastManifest != null && !subtreeReplayActive) {
                realizePending = true
            }
            return
        }
        val enc = resources.payloadSpecs[key]?.encoding ?: "unknown"
        logCommandOnce("upsertPayload.$key.unclaimed",
            "upsertPayload $key (encoding '$enc'): stored; no consumers")
    }

    private fun jsonKey(json: JSONObject): Long? {
        val token = json.optString("node")
        return if (token.isEmpty()) null else D3Wire.localIdKey(token)
    }

    private fun physicsNode(json: JSONObject): FsceneRealizer.NodeRec? {
        val key = jsonKey(json) ?: return null
        return nodesById[key]
    }

    private fun vec(a: org.json.JSONArray?): DoubleArray? =
        a?.toDoubleArray()

    // MARK: - W8 contact events + physics queries

    /**
     * Engine-space [ContactEvent] → wire frame + JSON (one event per
     * pair transition). Mirrors the settled encoding: positions and
     * normals negate z. `points` ships only on began/triggerEntered —
     * jolt-jni exposes no impulse or per-point list, so the single
     * point at the manifold's baseOffset carries imp:0 (spec-known).
     */
    private fun fireContactEvent(ev: ContactEvent) {
        val sb = StringBuilder()
        sb.append("{\"kind\":\"").append(ev.kind).append("\",")
            .append("\"a\":").append(nodeRefJson(ev.nodeKeyA))
            .append(",\"ca\":0,")
            .append("\"b\":").append(nodeRefJson(ev.nodeKeyB))
            .append(",\"cb\":0")
        ev.point?.let { p ->
            sb.append(",\"points\":[{\"p\":[${p[0]},${p[1]},${-p[2]}],")
            ev.normal?.let { n ->
                sb.append("\"n\":[${n[0]},${n[1]},${-n[2]}],")
            }
            sb.append("\"imp\":0,\"sep\":${ev.separation}}]")
        }
        sb.append('}')
        fireEvent(D3Event.CONTACT, sb.toString())
    }

    /// `{"op":"query","q":<u32>,"type":…}` — every query earns exactly
    /// one queryReply: hits (possibly empty) or `error`.
    private fun applyQuery(json: JSONObject) {
        val q = json.optLong("q")
        when (val type = json.optString("type")) {
            "pose" -> queryPose(q, json)
            "raycast" -> queryRaycast(q, json)
            "overlap" -> queryOverlap(q, json)
            "shapecast" -> queryShapecast(q, json)
            else -> fireQueryError(q, "unknown query type '$type'")
        }
    }

    /** nodeKey → the wire's `{"s":session,"i":index}` LocalId form. */
    private fun nodeRefJson(key: Long): String =
        "{\"s\":${key ushr 32},\"i\":${key and 0xFFFFFFFFL}}"

    private fun fireQueryError(q: Long, msg: String) {
        fireEvent(D3Event.QUERY_REPLY,
            "{\"q\":$q,\"error\":${JSONObject.quote(msg)}}")
    }

    private fun fireQueryHits(q: Long, type: String, hits: List<QueryHit>) {
        val parts = StringBuilder()
        var first = true
        for (h in hits) {
            if (!first) parts.append(',')
            first = false
            parts.append("{\"node\":${nodeRefJson(h.nodeKey)},\"collider\":0")
            // RH engine → LH wire: negate z on points and normals.
            h.point?.let { p ->
                parts.append(",\"p\":[${p[0]},${p[1]},${-p[2]}]") }
            h.normal?.let { n ->
                parts.append(",\"n\":[${n[0]},${n[1]},${-n[2]}]") }
            parts.append(",\"d\":${h.distance}}")
        }
        fireEvent(D3Event.QUERY_REPLY,
            "{\"q\":$q,\"type\":\"$type\",\"hits\":[$parts]}")
    }

    /**
     * `{"type":"pose","nodes":[token|…|"all"]}` — body nodes read the
     * body pose (authoritative for dynamics); other nodes read the
     * realized world transform. `nodes` absent or containing "all"
     * returns every rigid-body node's pose.
     */
    private fun queryPose(q: Long, json: JSONObject) {
        val keys = ArrayList<Long>()
        val arr = json.optJSONArray("nodes")
        if (arr == null ||
            (0 until arr.length()).any { arr.optString(it) == "all" }) {
            keys.addAll(bodies.keys)
        } else {
            for (n in 0 until arr.length()) {
                D3Wire.localIdKey(arr.optString(n))?.let(keys::add)
            }
        }
        val parts = StringBuilder()
        var first = true
        for (key in keys) {
            val rec = nodesById[key] ?: continue
            val p: DoubleArray
            val r: FloatArray
            val body = rec.body
            if (body != null) {
                val bp = body.position
                val bq = body.rotation
                p = doubleArrayOf(bp.xx(), bp.yy(), bp.zz())
                r = floatArrayOf(bq.x, bq.y, bq.z, bq.w)
            } else {
                val (wp, wq) = FsceneRealizer.worldPoseOf(worldMatOf(rec))
                p = doubleArrayOf(
                    wp[0].toDouble(), wp[1].toDouble(), wp[2].toDouble())
                r = wq
            }
            if (!first) parts.append(',')
            first = false
            // RH engine → LH wire: p.z negates; r → (−x,−y,z,w).
            parts.append(
                "{\"node\":${nodeRefJson(key)}," +
                    "\"p\":[${p[0]},${p[1]},${-p[2]}]," +
                    "\"r\":[${-r[0]},${-r[1]},${r[2]},${r[3]}]}")
        }
        fireEvent(D3Event.QUERY_REPLY,
            "{\"q\":$q,\"type\":\"pose\",\"poses\":[$parts]}")
    }

    private fun queryRaycast(q: Long, json: JSONObject) {
        val o = vec(json.optJSONArray("origin"))
        val d = vec(json.optJSONArray("direction"))
        if (o == null || o.size != 3 || d == null || d.size != 3) {
            fireQueryError(q, "raycast: invalid or missing origin/direction")
            return
        }
        if (!json.has("maxDistance")) {
            fireQueryError(q, "raycast: missing 'maxDistance'"); return
        }
        val maxDist = json.optDouble("maxDistance")
        if (maxDist.isNaN() || maxDist <= 0.0 ||
            maxDist > Float.MAX_VALUE) {
            fireQueryError(q, "raycast: invalid 'maxDistance'"); return
        }
        val oc = D3Wire.position(o)
        val dc = D3Wire.position(d)
        val hits = world.raycast(
            RVec3(oc[0].toDouble(), oc[1].toDouble(), oc[2].toDouble()),
            Vec3((dc[0] * maxDist).toFloat(),
                (dc[1] * maxDist).toFloat(),
                (dc[2] * maxDist).toFloat()),
            json.optBoolean("all"))
        fireQueryHits(q, "raycast", hits)
    }

    private fun queryOverlap(q: Long, json: JSONObject) {
        val shape = json.optJSONObject("shape") ?: run {
            fireQueryError(q, "overlap: missing 'shape'"); return }
        val pos = vec(json.optJSONArray("position"))
        if (pos == null || pos.size != 3) {
            fireQueryError(q, "overlap: invalid or missing 'position'")
            return
        }
        val rot = vec(json.optJSONArray("rotation"))
        if (rot != null && rot.size != 4) {
            fireQueryError(q, "overlap: 'rotation' must be [x,y,z,w]")
            return
        }
        val pc = D3Wire.position(pos)
        val center = RVec3(pc[0].toDouble(), pc[1].toDouble(), pc[2].toDouble())
        val keys = when (shape.optString("type")) {
            "sphere" -> {
                val r = shape.optDouble("radius", Double.NaN)
                if (r.isNaN() || r <= 0.0) {
                    fireQueryError(q, "overlap: invalid sphere 'radius'")
                    return
                }
                world.overlapSphere(center, r.toFloat())
            }
            "box" -> {
                val e = vec(shape.optJSONArray("extents"))
                if (e == null || e.size != 3) {
                    fireQueryError(q, "overlap: invalid box 'extents'")
                    return
                }
                // Wire extents are full extents — halve for Jolt.
                val qc = rot?.let { D3Wire.quaternion(it) }
                    ?: floatArrayOf(0f, 0f, 0f, 1f)
                world.overlapBox(
                    center, Quat(qc[0], qc[1], qc[2], qc[3]),
                    Vec3((e[0] / 2).toFloat(), (e[1] / 2).toFloat(),
                        (e[2] / 2).toFloat()))
            }
            else -> {
                fireQueryError(q,
                    "overlap: unknown shape type '${shape.optString("type")}'")
                return
            }
        }
        val parts = StringBuilder()
        var first = true
        for (key in keys) {
            if (!first) parts.append(',')
            first = false
            parts.append("{\"node\":${nodeRefJson(key)},\"collider\":0}")
        }
        fireEvent(D3Event.QUERY_REPLY,
            "{\"q\":$q,\"type\":\"overlap\",\"hits\":[$parts]}")
    }

    private fun queryShapecast(q: Long, json: JSONObject) {
        val shape = json.optJSONObject("shape") ?: run {
            fireQueryError(q, "shapecast: missing 'shape'"); return }
        // Upstream's shapeCast bound is sphere-only — same here.
        if (shape.optString("type") != "sphere") {
            fireQueryError(q, "shapecast: only 'sphere' shapes are supported")
            return
        }
        val radius = shape.optDouble("radius", Double.NaN)
        if (radius.isNaN() || radius <= 0.0) {
            fireQueryError(q, "shapecast: invalid sphere 'radius'"); return
        }
        val f = vec(json.optJSONArray("from"))
        val t = vec(json.optJSONArray("to"))
        if (f == null || f.size != 3 || t == null || t.size != 3) {
            fireQueryError(q, "shapecast: invalid or missing from/to")
            return
        }
        val fc = D3Wire.position(f)
        val tc = D3Wire.position(t)
        val hit = world.shapeCastSphere(
            RVec3(fc[0].toDouble(), fc[1].toDouble(), fc[2].toDouble()),
            RVec3(tc[0].toDouble(), tc[1].toDouble(), tc[2].toDouble()),
            radius.toFloat())
        fireQueryHits(q, "shapecast", listOfNotNull(hit))
    }

    // MARK: - W9 joints

    /**
     * `{"op":"addJoint"/"updateJoint","id":u32, …}` — decodes the
     * upstream `JointDesc` field set and mirrors it to engine space
     * (see [decodeJoint] for the mirror rules), then hands JoltWorld a
     * pure engine-space desc. `updateJoint` recreates in place — Jolt
     * has no in-place update for anchors/axes, which upstream's
     * contract allows ("backends without in-place updates can
     * recreate internally").
     */
    private fun applyJoint(json: JSONObject, update: Boolean) {
        if (!json.has("id")) {
            Log.w(TAG, "joint op: missing 'id'"); return
        }
        val desc = decodeJoint(json) ?: return
        val id = json.optInt("id")
        if (update) world.updateJoint(id, desc) else world.addJoint(id, desc)
    }

    private fun applyRemoveJoint(json: JSONObject) {
        if (!json.has("id")) {
            Log.w(TAG, "removeJoint: missing 'id'"); return
        }
        world.removeJoint(json.optInt("id"))
    }

    /**
     * Drops every component-joint registration — called at the head of
     * a manifest realize before node decode re-registers them (command
     * joints are untouched; their lifecycle is `retainJointsForNodes`).
     */
    fun beginComponentJointRegistration() {
        for ((_, byIndex) in componentJointIds) {
            for ((_, id) in byIndex) world.removeJoint(id)
        }
        componentJointIds.clear()
        nextComponentJointHandle = 0x40000000
    }

    /**
     * Registers one decoded joint component under a reserved-range
     * handle — re-registering the same (nodeKey, componentIndex)
     * replaces the previous joint (mirrors iOS `registerComponentJoint`).
     * [json] is the translated command-shaped spec.
     */
    fun registerComponentJoint(
        nodeKey: Long, componentIndex: Int, json: JSONObject,
    ) {
        val byIndex = componentJointIds.getOrPut(nodeKey) { HashMap() }
        byIndex.remove(componentIndex)?.let { world.removeJoint(it) }
        val desc = decodeJoint(json) ?: return
        if (nextComponentJointHandle == Int.MAX_VALUE) {
            nextComponentJointHandle = 0x40000000
        }
        val id = nextComponentJointHandle++
        byIndex[componentIndex] = id
        world.addJoint(id, desc)
    }

    /**
     * Drops a node's component-joint registrations — `components`
     * teardown (the re-decode re-registers) and node removal both call
     * this before the world's own per-node joint sweep.
     */
    fun dropComponentJointsForNode(nodeKey: Long) {
        componentJointIds.remove(nodeKey)?.let { byIndex ->
            for ((_, id) in byIndex) world.removeJoint(id)
        }
    }

    /**
     * Wire joint fields → engine-space [JointDesc]. The scene→Jolt
     * mirror (`S = diag(1,1,−1)`) applied to a BODY-LOCAL vector is
     * the same z-negate as world vectors (`local_jolt = S·local`), so
     * anchors and direction axes go through `D3Wire.position` and
     * basis quats through `D3Wire.quaternion` — JoltWorld then rotates
     * them to world through the bodies' live poses at create.
     *
     * Angular SCALARS flip sign under the mirror: a rotation θ about a
     * scene axis reads −θ about the mirrored axis (same rule as the
     * angular-velocity decode). Revolute limits therefore arrive at
     * JoltWorld already swapped ([−upper, −lower], clamped to Jolt's
     * [−π,0]/[0,π] bracket around the zero angle) and its motor
     * velocity negated; prismatic limits/velocity are along-axis
     * distances — axis and displacement mirror together, so they pass
     * through unchanged (clamped to bracket the zero position, which
     * Jolt requires).
     */
    private fun decodeJoint(json: JSONObject): JointDesc? {
        val type = json.optString("type")
        if (type !in JOINT_TYPES) {
            logCommandOnce("joint.type.$type",
                "joint op: unknown type '$type'")
            return null
        }
        val keyA = D3Wire.localIdKey(json.optString("a"))
        val keyB = D3Wire.localIdKey(json.optString("b"))
        // W12: joint COMPONENTS may omit `b` — an absent otherNode
        // anchors to the world (upstream `_resolveOtherNode`), marked
        // by the translator's `worldAnchor` flag. Command joints still
        // require both endpoints.
        val worldAnchor = json.optBoolean("worldAnchor")
        if (keyA == null || (keyB == null && !worldAnchor)) {
            Log.w(TAG, "joint op: missing or bad a/b token")
            return null
        }
        if (json.optInt("ca") != 0 || json.optInt("cb") != 0) {
            // A node's colliders compose one body today — the index
            // can't pick a sub-body.
            logCommandOnce("joint.colliderIndex",
                "joint ca/cb != 0 ignored: a node's colliders" +
                    " compose one body")
        }
        val collide = json.optBoolean("collide")
        val anchorA = vec(json.optJSONArray("anchorA"))
            ?.takeIf { it.size == 3 }?.let { D3Wire.position(it) }
            ?: floatArrayOf(0f, 0f, 0f)
        val anchorB = vec(json.optJSONArray("anchorB"))
            ?.takeIf { it.size == 3 }?.let { D3Wire.position(it) }
            ?: floatArrayOf(0f, 0f, 0f)
        val breakDistance = if (json.has("breakDistance"))
            json.optDouble("breakDistance").toFloat() else null
        var axisA: FloatArray? = null
        var axisB: FloatArray? = null
        var lower: Float? = null
        var upper: Float? = null
        var motorVelocity: Float? = null
        var basisA: FloatArray? = null
        var basisB: FloatArray? = null
        var axes: List<JointAxisDesc>? = null
        when (type) {
            "revolute", "prismatic" -> {
                val aA = vec(json.optJSONArray("axisA"))
                val aB = vec(json.optJSONArray("axisB"))
                if (aA == null || aA.size != 3 ||
                    aB == null || aB.size != 3) {
                    Log.w(TAG, "joint $type: missing/malformed axisA/axisB")
                    return null
                }
                axisA = D3Wire.position(aA)
                axisB = D3Wire.position(aB)
                if (axisA.all { it == 0f } || axisB.all { it == 0f }) {
                    Log.w(TAG, "joint $type: zero axis")
                    return null
                }
                if (type == "revolute") {
                    if (json.has("lower") || json.has("upper")) {
                        // jolt limits = [−upper, −lower]; an absent
                        // side takes the full ±π range that way.
                        lower = (-json.optDouble("upper", Math.PI))
                            .toFloat().coerceIn(-PI_F, 0f)
                        upper = (-json.optDouble("lower", -Math.PI))
                            .toFloat().coerceIn(0f, PI_F)
                    }
                    if (json.has("motorVelocity")) {
                        motorVelocity =
                            (-json.optDouble("motorVelocity")).toFloat()
                    }
                } else {
                    if (json.has("lower")) {
                        lower = json.optDouble("lower")
                            .toFloat().coerceAtMost(0f)
                    }
                    if (json.has("upper")) {
                        upper = json.optDouble("upper")
                            .toFloat().coerceAtLeast(0f)
                    }
                    if (json.has("motorVelocity")) {
                        motorVelocity =
                            json.optDouble("motorVelocity").toFloat()
                    }
                }
            }
            "generic" -> {
                basisA = vec(json.optJSONArray("basisA"))
                    ?.takeIf { it.size == 4 }
                    ?.let { D3Wire.quaternion(it) }
                basisB = vec(json.optJSONArray("basisB"))
                    ?.takeIf { it.size == 4 }
                    ?.let { D3Wire.quaternion(it) }
                axes = decodeJointAxes(json.optJSONArray("axes"))
            }
        }
        val motorMaxForce = if (json.has("motorMaxForce"))
            json.optDouble("motorMaxForce").toFloat() else null
        return JointDesc(
            type = type,
            nodeKeyA = keyA,
            nodeKeyB = keyB,   // null = world-anchored (W12 components)
            collide = collide,
            anchorA = anchorA,
            anchorB = anchorB,
            axisA = axisA,
            axisB = axisB,
            basisA = basisA,
            basisB = basisB,
            lower = lower,
            upper = upper,
            motorVelocity = motorVelocity,
            motorMaxForce = motorMaxForce,
            breakDistance = breakDistance,
            axes = axes,
        )
    }

    /**
     * `axes` decode for `generic` — six entries in `JointAxis` order
     * (linearX..angularZ), mirroring `EAxis.TranslationX..RotationZ`.
     * In constraint space the z-mirror acts on each axis's scalar
     * coordinate: linear-Z and angular-X/Y negate (an angular scalar
     * about X or Y flips sign; about Z it doesn't — the axial-vector
     * rule (−x,−y,+z)); a negated interval arrives swapped. A missing
     * array defaults to all-free, matching the Dart default.
     */
    private fun decodeJointAxes(arr: JSONArray?): List<JointAxisDesc> =
        List(6) { i ->
            val a = arr?.optJSONObject(i)
            var motion = a?.optString("motion") ?: "free"
            if (motion !in JOINT_MOTIONS) {
                logCommandOnce("joint.axes.motion.$motion",
                    "generic axis motion '$motion' unknown; treating as free")
                motion = "free"
            }
            val mirror = i == 2 || i == 3 || i == 4
            var lo = 0.0
            var hi = 0.0
            if (motion == "limited") {
                if (a == null || !a.has("lower") || !a.has("upper")) {
                    logCommandOnce("joint.axes.$i.bounds",
                        "generic axis $i 'limited' without lower/upper;" +
                            " treated as free")
                    motion = "free"
                } else {
                    lo = a.optDouble("lower")
                    hi = a.optDouble("upper")
                    if (mirror) { val t = -hi; hi = -lo; lo = t }
                    if (lo > hi) { val t = lo; lo = hi; hi = t }
                }
            }
            val motor = a?.optJSONObject("motor")?.let { m ->
                var tp = m.optDouble("targetPosition")
                var tv = m.optDouble("targetVelocity")
                if (mirror) { tp = -tp; tv = -tv }
                JointMotorDesc(
                    targetPosition = tp.toFloat(),
                    targetVelocity = tv.toFloat(),
                    stiffness = m.optDouble("stiffness").toFloat(),
                    damping = m.optDouble("damping").toFloat(),
                    // Omitted when infinite — JSON can't express it.
                    maxForce = if (m.has("maxForce"))
                        m.optDouble("maxForce").toFloat() else null,
                    accelerationModel = m.optString("model") != "force",
                )
            }
            JointAxisDesc(motion, lo.toFloat(), hi.toFloat(), motor)
        }

    /**
     * Engine-space [JointBrokeEvent] → `{"kind":"broke","id":…,
     * "a":{s,i},"b":{s,i}}` — reuses the settled/contact node-ref
     * encoding; node keys need no mirroring. A world-anchored joint
     * (W12 components) emits `"b":null` — mirrors iOS.
     */
    private fun fireJointBroke(ev: JointBrokeEvent) {
        fireEvent(D3Event.JOINT,
            "{\"kind\":\"broke\",\"id\":${ev.id}," +
                "\"a\":${nodeRefJson(ev.nodeKeyA)}," +
                "\"b\":${ev.nodeKeyB?.let { nodeRefJson(it) } ?: "null"}}")
    }

    /**
     * `{"op":"selectVariant","node":"<token>","selected":<str|null>}`
     * — W12 material-variant selection: writes the component's
     * `selected` and reapplies every binding through the surgical
     * context (upstream: null or unknown → declared defaults).
     */
    private fun applySelectVariant(json: JSONObject) {
        val key = jsonKey(json) ?: run {
            Log.w(TAG, "selectVariant: bad node token"); return }
        val sel = if (json.isNull("selected")) null
            else json.optString("selected").takeIf { it.isNotEmpty() }
        val ctx = FsceneRealizer.surgicalContext(this)
        val vc = ctx.variantComponents[key] ?: run {
            Log.w(TAG, "selectVariant on node $key with no " +
                "materialsVariants component — ignored"); return }
        Log.i(TAG, "selectVariant node=$key selected=${sel ?: "null"}")
        vc.selected = sel
        ctx.applyVariantComponents()
    }

    // MARK: - Realizer interface

    /**
     * Installs a freshly realized scene (called by `FsceneRealizer`).
     * Tears down the previous entities, bodies, GPU meshes, and
     * material instances before swapping the registries — mirrors
     * iOS's wholesale `install(scene:)`.
     */
    fun install(
        nodes: MutableMap<Long, FsceneRealizer.NodeRec>,
        gpuMeshes: MutableMap<Long, GpuMesh>,
        materials: MutableMap<Long, MaterialInstance>,
        resources: FsceneRealizer.Context.InstalledResources,
        nodeSkins: MutableMap<Long, NodeSkin>,
        particles: MutableMap<Long, MutableList<ParticleRuntime>>,
        pending: MutableSet<Long>,
        cameraKey: Long?,
        cameraProps: JSONObject?,
        renderTargets: MutableMap<Long, RenderTargets.RenderTargetRec>,
        views: List<RenderTargets.ViewRec>,
        nodeCameraProps: MutableMap<Long, RenderTargets.CameraSpec>,
        bodies: MutableMap<Long, Body>,
        dynamicBodies: MutableSet<Long>,
    ) {
        // Teardown — old entities leave the scene, bodies leave the
        // world, GPU resources return to the engine. Joints referencing
        // nodes the new scene lacks die first (a node that persists
        // keeps its joint — removeBody re-pends it and the fresh
        // body's addBody re-realizes it; LocalId session keys differ
        // across documents so a stale joint can't attach).
        world.retainJointsForNodes(nodes.keys)
        // W18: particle runtimes own entities + buffers — retire them
        // BEFORE the node sweep (mesh pool slots are transform
        // children of node entities).
        for ((_, list) in particleRuntimes) {
            for (rt in list) rt.destroy()
        }
        val sweepCtx = FsceneRealizer.surgicalContext(this)
        for ((_, rec) in nodesById) {
            // W16: trail entities/buffers + the lod consumer entry
            // die with the replaced scene — the trail's unparented
            // entity isn't covered by rec.entity's teardown.
            sweepCtx.destroyTrailLod(rec)
            scene.removeEntity(rec.entity)
            engine.destroyEntity(rec.entity)
            EntityManager.get().destroy(rec.entity)
        }
        for ((_, b) in this.bodies) world.removeBody(b)
        // W11: skinning buffers are host-owned GPU objects — the
        // entity teardown doesn't destroy them. The NEW scene's
        // buffers live on its Context's map (decodeMesh can't write
        // here — destroying the map wholesale is safe).
        for ((_, s) in nodeSkinning) {
            engine.destroySkinningBuffer(s.buffer)
        }
        for ((_, g) in this.gpuMeshes) {
            g.destroy(engine)
        }
        for ((_, m) in materialInstances) engine.destroyMaterialInstance(m)
        // W14: view + render-target objects die with the scene — each
        // rt rec owns its View-bound state, RenderTarget, and textures
        // (the colorTex sweep skips rt keys; the shared `view` lets go
        // of rec cameras first).
        view.camera = camera
        for (rec in viewRecs) destroyViewObjects(rec)
        viewRecs.clear()
        screenViews.clear()
        for ((k, t) in this.resources.textures) {
            if (!this.renderTargets.containsKey(k)) {
                engine.destroyTexture(t)
            }
        }
        for ((_, rec) in this.renderTargets) destroyRenderTargetRec(rec)
        // W11 stores — clips and captured bind poses belonged to the
        // replaced scene, so the runtime resets too (a doc's
        // animations start clip-less and paused; nothing autoplays).
        animClips.clear()
        animTargets.clear()

        // Specs that arrived on `upsertPayload` ops rather than the
        // manifest — this rebuild's table is manifest-only, so they
        // merge back on top.
        resources.payloadSpecs.putAll(opPayloadSpecs)
        nodesById = nodes
        nodeSkinning = nodeSkins
        particleRuntimes = particles
        this.gpuMeshes = gpuMeshes
        materialInstances = materials
        this.resources = resources
        this.renderTargets = renderTargets
        this.nodeCameraProps = nodeCameraProps
        this.bodies = bodies
        dynamicBodyKeys = dynamicBodies
        pendingPayloadRefs = pending
        pendingParents.clear()
        lastAwakeCount = 0
        // W14: build the decoded views against the fresh rt map —
        // empty keeps the single-view default path byte-identical.
        applyViews(views)

        cameraNodeKey = cameraKey
        if (cameraProps != null) {
            applyCameraProps(cameraProps)
        } else {
            // No camera in the doc — park a default above the origin.
            cameraNodeKey = null
            cameraOrtho = false
            camera.lookAt(0.0, 0.0, 5.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0)
            applyProjection()
        }
        if (manipulator != null) {
            // A re-realized scene re-seeds the manipulator from the new
            // camera node — the attach also re-snapshots authored TRS.
            attachCameraControl()
        }
    }

    // MARK: - Skins / morphs / animations (W11)

    /// `{"op":"anim","anim":"<id>",…}` — the runtime clip control.
    /// The clip is created lazily, paused at t=0, on first reference —
    /// upstream's `createAnimationClip` contract (a doc's animations
    /// exist as defs; nothing autoplays). Verbs apply in
    /// pause→stop→play order so `play` trumps; `time` then seeks
    /// (clamped to `[0, endTime]` — `play`+`time` is `gotoAndPlay`);
    /// `timeScale`/`weight`/`loop` are the knob writes.
    private fun applyAnim(json: JSONObject) {
        val token = json.optString("anim")
        val key = D3Wire.localIdKey(token) ?: return
        val def = resources.animations[key] ?: run {
            logCommandOnce("anim.missing.$key",
                "anim on unknown animation $key; ignoring")
            return
        }
        val clip = animClips.getOrPut(key) { AnimClipState() }
        if (json.optBoolean("pause")) clip.playing = false
        if (json.optBoolean("stop")) {
            clip.playing = false
            clip.time = 0.0
        }
        if (json.optBoolean("play")) clip.playing = true
        if (json.has("time")) {
            clip.time = json.optDouble("time").coerceIn(0.0, def.endTime)
        }
        if (json.has("timeScale")) {
            clip.timeScale = json.optDouble("timeScale")
        }
        if (json.has("weight")) {
            clip.weight = json.optDouble("weight").coerceIn(0.0, 1.0)
        }
        if (json.has("loop")) clip.loop = json.optBoolean("loop")
    }

    /// `{"op":"upsertSkin","id":"<id>","skin":{…}}` — re-decode one
    /// manifest `skins` entry and rebind every node whose `skin`
    /// member names it (the upsertResource consumer contract).
    private fun applyUpsertSkin(json: JSONObject) {
        val key = D3Wire.localIdKey(json.optString("id"))
        val skin = json.optJSONObject("skin")
        if (key == null || skin == null) {
            logCommandOnce("upsertSkin.malformed",
                "upsertSkin: missing id/skin")
            return
        }
        redecodeSkin(key, skin)
    }

    /// `{"op":"upsertAnimation","id":"<id>","animation":{…}}` —
    /// re-decode one `animations` entry; a live clip keeps its
    /// playback state (upstream `rebind`), clamped to the new endTime.
    private fun applyUpsertAnimation(json: JSONObject) {
        val key = D3Wire.localIdKey(json.optString("id"))
        val anim = json.optJSONObject("animation")
        if (key == null || anim == null) {
            logCommandOnce("upsertAnimation.malformed",
                "upsertAnimation: missing id/animation")
            return
        }
        redecodeAnimation(key, anim)
    }

    /// `{"op":"removeSkin","id":"<id>"}` — drop the def; every bound
    /// node detaches (its `skin` member stays, so a later upsert of
    /// the same id re-binds — the consumers refresh path rebuilds
    /// them unskinned while the def is absent).
    private fun applyRemoveSkin(json: JSONObject) {
        val key = D3Wire.localIdKey(json.optString("id")) ?: return
        val ctx = FsceneRealizer.surgicalContext(this)
        ctx.skins.remove(key)
        ctx.skinDefs.remove(key)
        ctx.skinPayloadIds.remove(key)
        ctx.refreshSkinConsumers(key)
    }

    /// `{"op":"removeAnimation","id":"<id>"}` — drop the def and its
    /// clip. Bound nodes keep their captured bind entries, so the next
    /// sampled frame writes them back to bind pose — upstream's
    /// `removeClip` behavior.
    private fun applyRemoveAnimation(json: JSONObject) {
        val key = D3Wire.localIdKey(json.optString("id")) ?: return
        val ctx = FsceneRealizer.surgicalContext(this)
        ctx.animations.remove(key)
        ctx.animDefs.remove(key)
        ctx.animPayloadIds.remove(key)
        animClips.remove(key)
    }

    /// `{"op":"setMorphWeights","node":"<id>","weights":[f,…]}` —
    /// direct write: listed targets take the value, unlisted trailing
    /// targets keep theirs, excess entries are ignored.
    private fun applySetMorphWeights(json: JSONObject) {
        val key = D3Wire.localIdKey(json.optString("node")) ?: return
        val rec = nodesById[key] ?: return
        val live = rec.morphWeights ?: run {
            logCommandOnce("setMorphWeights.$key",
                "setMorphWeights on node $key with no morpher")
            return
        }
        val list = json.optJSONArray("weights") ?: return
        val n = minOf(list.length(), live.size)
        for (i in 0 until n) {
            live[i] = list.optDouble(i).toFloat()
        }
        val rm = engine.renderableManager
        val inst = rm.getInstance(rec.entity)
        if (inst != 0) rm.setMorphWeights(inst, live, 0)
    }

    /// Re-decodes one skin def into the stores and re-binds every
    /// consumer — the `upsertSkin` and payload-arrival shared path.
    private fun redecodeSkin(key: Long, def: JSONObject) {
        val ctx = FsceneRealizer.surgicalContext(this)
        ctx.skinDefs[key] = def
        ctx.decodeSkin(key, def)
        ctx.refreshSkinConsumers(key)
    }

    /// Re-decodes one animation def — a live clip keeps playback
    /// state, its `time` clamped to the new `endTime` (upstream
    /// `rebind`'s clamp).
    private fun redecodeAnimation(key: Long, def: JSONObject) {
        val ctx = FsceneRealizer.surgicalContext(this)
        ctx.animDefs[key] = def
        ctx.decodeAnimation(key, def)
        animClips[key]?.let { clip ->
            clip.time = clip.time.coerceIn(
                0.0, resources.animations[key]?.endTime ?: 0.0)
        }
    }

    /**
     * Per-frame animation sampler — upstream `AnimationPlayer.update`:
     * advance every clip by `dt × timeScale` (clamping+pausing at the
     * endTime boundary, or wrapping when `loop`), reset each bound
     * node to its bind pose, accumulate each channel's contribution
     * (`weight × 1/Σweights` when the sum exceeds 1), and write the
     * blended TRS onto the node's transform fields plus morph weights
     * through `RenderableManager.setMorphWeights`. Runs from
     * [stepFrame] before the physics step — the same slot iOS's
     * `updateAtTime` occupies (a sampled transform lands in this
     * frame's pose).
     */
    private fun sampleAnimations(dt: Double) {
        // Recorded targets reset to bind pose and write every frame —
        // even with zero clips (upstream's update touches every
        // `_targetTransforms` entry, so a clip removal snaps its nodes
        // back to bind).
        if (animClips.isEmpty() && animTargets.isEmpty()) return

        // Advance + drop clips whose def was removed.
        for (key in ArrayList(animClips.keys)) {
            val def = resources.animations[key] ?: run {
                animClips.remove(key)
                continue
            }
            val clip = animClips[key] ?: continue
            if (!clip.playing || dt <= 0.0) continue
            var t = clip.time + dt * clip.timeScale
            if (def.endTime == 0.0) {
                t = 0.0
            } else if (!clip.loop && (t < 0.0 || t > def.endTime)) {
                clip.playing = false
                t = t.coerceIn(0.0, def.endTime)
            } else if (t > def.endTime) {
                t = abs(t) % def.endTime
            } else if (t < 0.0) {
                t = def.endTime - (abs(t) % def.endTime)
            }
            clip.time = t
        }

        // Resolve bindings and total the clip weights — upstream
        // normalizes by Σ every registered clip's weight.
        var totalWeight = 0.0
        for (clip in animClips.values) totalWeight += clip.weight
        val mult = if (totalWeight > 1.0) 1.0 / totalWeight else 1.0

        /// Accumulating pose state for one bound node this frame —
        /// starts at the captured bind pose / rest weights.
        class PoseAcc(
            var p: FloatArray,
            var r: FloatArray,
            var s: FloatArray,
            var weights: FloatArray?,
        )

        fun freshAcc(st: AnimTargetState) = PoseAcc(
            st.bindP.copyOf(), st.bindR.copyOf(), st.bindS.copyOf(),
            st.bindWeights?.copyOf())
        val accs = HashMap<Long, PoseAcc>()

        // Channels apply in channel order; clips in id order (upstream
        // applies in registration order — key order is the stable
        // analog). Binding happens for EVERY clip — a zero-weight clip
        // still registers its nodes' bind poses and drives them (to
        // bind) per upstream's createAnimationClip; only the value
        // contribution gates on w.
        for (animKey in animClips.keys.sorted()) {
            val clip = animClips[animKey] ?: continue
            val def = resources.animations[animKey] ?: continue
            val w = (clip.weight * mult).toFloat()
            for (ch in def.channels) {
                val nk = animTarget(ch) ?: continue
                val rec = nodesById[nk] ?: continue
                // Bind-pose capture — once, at first bind, never
                // re-captured while the entry lives (upstream's
                // corruption rule).
                if (animTargets[nk] == null) {
                    animTargets[nk] = AnimTargetState().also { st ->
                        st.bindP = rec.localPos.copyOf()
                        st.bindR = rec.localQuat.copyOf()
                        st.bindS = rec.localScale.copyOf()
                    }
                }
                val st = animTargets[nk]!!
                val acc = accs.getOrPut(nk) { freshAcc(st) }
                when (ch.kind) {
                    FsceneRealizer.DecodedChannel.Kind.TRANSLATION -> {
                        st.drivesTransform = true
                        if (w > 0f) {
                            sampleVec3(ch, clip.time)?.let { v ->
                                acc.p[0] += (v[0] - st.bindP[0]) * w
                                acc.p[1] += (v[1] - st.bindP[1]) * w
                                acc.p[2] += (v[2] - st.bindP[2]) * w
                            }
                        }
                    }
                    FsceneRealizer.DecodedChannel.Kind.SCALE -> {
                        st.drivesTransform = true
                        if (w > 0f) {
                            sampleVec3(ch, clip.time)?.let { v ->
                                // Multiplicative vs bind scale —
                                // lerp(1, v/bind, w) then multiply in
                                // (upstream's ScaleTimelineResolver).
                                for (i in 0 until 3) {
                                    acc.s[i] *=
                                        1f + (v[i] / st.bindS[i] - 1f) * w
                                }
                            }
                        }
                    }
                    FsceneRealizer.DecodedChannel.Kind.ROTATION -> {
                        st.drivesTransform = true
                        if (w > 0f) {
                            sampleQuat(ch, clip.time)?.let { v ->
                                val out = FloatArray(4)
                                quatSlerp(acc.r, v, w, out)
                                out.copyInto(acc.r)
                            }
                        }
                    }
                    FsceneRealizer.DecodedChannel.Kind.WEIGHTS -> {
                        // Capture rest weights once — the node without
                        // a morph renderable keeps null and the
                        // channel no-ops.
                        if (st.bindWeights == null) {
                            rec.morphWeights?.let {
                                st.bindWeights = it.copyOf()
                            }
                        }
                        val bind = st.bindWeights
                        if (bind != null) {
                            if (acc.weights == null) {
                                acc.weights = bind.copyOf()
                            }
                            if (w > 0f) {
                                val n = minOf(ch.targetCount, bind.size)
                                for (i in 0 until n) {
                                    val v = sampleWeight(ch, clip.time, i)
                                    acc.weights!![i] += (v - bind[i]) * w
                                }
                            }
                        }
                    }
                }
            }
        }

        // Write back: bound nodes get their accumulated pose; recorded
        // nodes no channel bound this frame reset to bind — upstream
        // writes every `_targetTransforms` entry each update.
        val rm = engine.renderableManager
        val stale = ArrayList<Long>()
        for ((nk, st) in animTargets) {
            val rec = nodesById[nk] ?: run {
                stale.add(nk)
                continue
            }
            val acc = accs[nk] ?: freshAcc(st)
            if (st.drivesTransform) {
                acc.p.copyInto(rec.localPos)
                acc.r.copyInto(rec.localQuat)
                acc.s.copyInto(rec.localScale)
                applyLocalTransform(rec)
            }
            val live = rec.morphWeights
            val w = acc.weights
            if (w != null && live != null) {
                val n = minOf(w.size, live.size)
                for (i in 0 until n) live[i] = w[i]
                val inst = rm.getInstance(rec.entity)
                if (inst != 0) rm.setMorphWeights(inst, live, 0)
            }
        }
        for (nk in stale) animTargets.remove(nk)
    }

    /// Channel binding — `target` id first, `targetName` fallback
    /// (upstream's `skin_animation.dart` order). The name path scans
    /// the registry so a retargeted node still binds.
    private fun animTarget(ch: FsceneRealizer.DecodedChannel): Long? {
        if (nodesById.containsKey(ch.target)) return ch.target
        val name = ch.targetName
        if (name.isNullOrEmpty()) return null
        for ((k, n) in nodesById) {
            if (n.name == name) return k
        }
        return null
    }

    /// Upstream `TimelineResolver._getTimelineKey`: the index of the
    /// first key at-or-after `t` and the lerp back to the previous key
    /// (1 means "exactly on a key / out of range" → take the key
    /// as-is).
    private fun timelineKey(times: DoubleArray, t: Double): Pair<Int, Double> {
        if (times.size <= 1 || t <= times[0]) return Pair(0, 1.0)
        val last = times.size - 1
        if (t >= times[last]) return Pair(last, 1.0)
        var next = last
        for (i in times.indices) {
            if (times[i] >= t) { next = i; break }
        }
        val prev = next - 1
        val span = times[next] - times[prev]
        return Pair(next, if (span > 0.0) (t - times[prev]) / span else 1.0)
    }

    private fun sampleVec3(
        ch: FsceneRealizer.DecodedChannel, t: Double,
    ): FloatArray? {
        if (ch.vec3.isEmpty() || ch.times.isEmpty()) return null
        val key = timelineKey(ch.times, t)
        val i = minOf(key.first, ch.times.size - 1)
        val out = FloatArray(3)
        if (key.second < 1.0 && i > 0) {
            val f = key.second.toFloat()
            for (c in 0 until 3) {
                val a = ch.vec3[(i - 1) * 3 + c]
                val b = ch.vec3[i * 3 + c]
                out[c] = a + (b - a) * f
            }
        } else {
            out[0] = ch.vec3[i * 3]
            out[1] = ch.vec3[i * 3 + 1]
            out[2] = ch.vec3[i * 3 + 2]
        }
        return out
    }

    private fun sampleQuat(
        ch: FsceneRealizer.DecodedChannel, t: Double,
    ): FloatArray? {
        if (ch.quat.isEmpty() || ch.times.isEmpty()) return null
        val key = timelineKey(ch.times, t)
        val i = minOf(key.first, ch.times.size - 1)
        val out = FloatArray(4)
        if (key.second < 1.0 && i > 0) {
            val a = FloatArray(4) { ch.quat[(i - 1) * 4 + it] }
            val b = FloatArray(4) { ch.quat[i * 4 + it] }
            quatSlerp(a, b, key.second.toFloat(), out)
        } else {
            for (c in 0 until 4) out[c] = ch.quat[i * 4 + c]
        }
        return out
    }

    /// One target's keyframed morph weight at `t` — the flattened
    /// `targetCount`-per-key layout, linear between bracketing keys.
    private fun sampleWeight(
        ch: FsceneRealizer.DecodedChannel, t: Double, target: Int,
    ): Float {
        val tc = ch.targetCount
        if (tc <= 0 || ch.times.isEmpty() || target >= tc) return 0f
        val key = timelineKey(ch.times, t)
        val i = minOf(key.first, ch.times.size - 1)
        var v = ch.weights.getOrElse(i * tc + target) { 0f }
        if (key.second < 1.0 && i > 0) {
            val p = ch.weights.getOrElse((i - 1) * tc + target) { 0f }
            v = p + (v - p) * key.second.toFloat()
        }
        return v
    }

    /// Upstream `Quaternion.slerp` (vector_math): flip the target on a
    /// negative dot; true spherical interpolation while the cosine is
    /// below `1 − 1e-3`, otherwise normalized lerp. xyzw layout.
    private fun quatSlerp(
        a: FloatArray, bi: FloatArray, t: Float, out: FloatArray,
    ) {
        var bx = bi[0]; var by = bi[1]; var bz = bi[2]; var bw = bi[3]
        var cosW = a[0] * bx + a[1] * by + a[2] * bz + a[3] * bw
        if (cosW < 0f) {
            bx = -bx; by = -by; bz = -bz; bw = -bw; cosW = -cosW
        }
        if (cosW < 1f - 1e-3f) {
            // cosW ∈ [0, 1−1e-3) here → sin(omega) is never zero.
            val omega = atan2(sqrt(1f - cosW * cosW), cosW)
            val sinO = sin(omega)
            val ka = sin((1f - t) * omega) / sinO
            val kb = sin(t * omega) / sinO
            out[0] = a[0] * ka + bx * kb
            out[1] = a[1] * ka + by * kb
            out[2] = a[2] * ka + bz * kb
            out[3] = a[3] * ka + bw * kb
        } else {
            out[0] = a[0] + (bx - a[0]) * t
            out[1] = a[1] + (by - a[1]) * t
            out[2] = a[2] + (bz - a[2]) * t
            out[3] = a[3] + (bw - a[3]) * t
        }
        val n = sqrt(out[0] * out[0] + out[1] * out[1] +
            out[2] * out[2] + out[3] * out[3])
        if (n > 0f) {
            out[0] /= n; out[1] /= n; out[2] /= n; out[3] /= n
        }
    }

    /// Per-frame bone matrix upload — gltfio's formula:
    /// `bone = inverse(meshWorld) * jointWorld * ibm`, pushed through
    /// `SkinningBuffer.setBonesAsMatrices`. Joints that haven't
    /// landed (or were removed) read identity, matching upstream's
    /// null-tolerant skin joint path — the per-frame resolve also
    /// covers late `addNode` joint arrivals without a rebuild.
    private fun updateSkinning() {
        if (nodeSkinning.isEmpty()) return
        val tm = engine.transformManager
        val meshWorld = FloatArray(16)
        val meshInv = FloatArray(16)
        val jointWorld = FloatArray(16)
        val tmp = FloatArray(16)
        val bone = FloatArray(16)
        for ((nodeKey, skin) in nodeSkinning) {
            val def = resources.skins[skin.skinKey] ?: continue
            val rec = nodesById[nodeKey] ?: continue
            val inst = tm.getInstance(rec.entity)
            if (inst == 0) continue
            tm.getWorldTransform(inst, meshWorld)
            if (!Matrix.invertM(meshInv, 0, meshWorld, 0)) {
                Matrix.setIdentityM(meshInv, 0)
            }
            skin.bones.clear()
            for (i in 0 until skin.boneCount) {
                if (i < def.jointKeys.size && i < def.ibms.size) {
                    val joint = nodesById[def.jointKeys[i]]
                    val jinst = joint?.let { tm.getInstance(it.entity) } ?: 0
                    if (jinst != 0) {
                        tm.getWorldTransform(jinst, jointWorld)
                        Matrix.multiplyMM(tmp, 0, jointWorld, 0,
                            def.ibms[i], 0)
                        Matrix.multiplyMM(bone, 0, meshInv, 0, tmp, 0)
                        skin.bones.put(bone)
                    } else {
                        skin.bones.put(IDENTITY16)
                    }
                } else {
                    skin.bones.put(IDENTITY16)
                }
            }
            skin.bones.flip()
            skin.buffer.setBonesAsMatrices(
                engine, skin.bones, skin.boneCount, 0)
        }
    }

    // MARK: - Frame pipeline

    private fun stepFrame(tNanos: Long) {
        val dt = ((tNanos - lastFrameNanos).coerceIn(0L, 100_000_000L)) / 1e9f
        lastFrameNanos = tNanos

        // Drain queued mutations before touching any scene/Jolt state —
        // the iOS twin drains at `updateAtTime`, the same pre-step slot.
        while (true) {
            val work = pendingWork.poll() ?: break
            work()
        }
        // Payload chunks in this drain may have unblocked deferred
        // resources — a single re-realize resolves every landed claim
        // at once (previously one full decode ran per chunk).
        if (realizePending) {
            realizePending = false
            val manifest = lastManifest
            if (manifest != null && pendingPayloadRefs.isNotEmpty()) {
                FsceneRealizer.realize(manifest, this)
                // W15: the re-realize discarded the surgically
                // streamed subtrees with the rest of the scene —
                // rebuild each from its recorded load batch.
                replayStreamedSubtrees()
            }
        }

        // W11: the animation sampler runs before physics — iOS's
        // `updateAtTime` slot, so a sampled transform lands in this
        // frame's pose (and a physics step that would re-own the node
        // can still override it, same ordering as SceneKit).
        sampleAnimations(dt.toDouble())

        // Fixed-step the sim at the world's timestep; cap collision
        // steps per frame so a slow frame can't spiral (physicsWorld
        // fixedTimestep/maxSubsteps land on JoltWorld at realize).
        physicsAcc += dt
        val stepDt = world.fixedTimestep
        val steps = minOf((physicsAcc / stepDt).toInt(), world.maxSubsteps)
        if (steps > 0) {
            world.update(stepDt * steps, steps)
            physicsAcc -= stepDt * steps
        }
        if (steps == world.maxSubsteps) physicsAcc = 0f

        if (dynamicBodyKeys.isNotEmpty()) {
            syncBodies()
            pollSettle()
        }
        // W11: bone matrices follow the final joint world transforms —
        // after the sampler and the body sync, before render.
        updateSkinning()
        updateCamera(dt)
        // W14: every view entry's Camera takes its camera node's world
        // transform + retained projection — after the manipulator's
        // node write-back so a view camera sees this frame's pose.
        updateViewCameras()
        // W18: particles step on the fixed-step accumulator inside
        // each runtime, then repack render state — after the camera
        // pose settles (billboards face it), before render. Upstream's
        // update() slot.
        tickParticles(dt)
        // W16: trails record/refill and lods rebind for this frame's
        // camera — the same pre-render slot iOS's renderer delegate
        // uses (node poses and camera are final here).
        updateTrailsLods(dt)
        render(tNanos)
        // W15: this frame is the first a just-applied subtree is
        // visible in — stamp it for the latency lane (the Dart side
        // logs the send time against this). tNanos is the vsync
        // schedule time — the wall stamp is a fresh nanoTime taken
        // after render().
        subtreeVisibleStamp?.let { (key, appliedNanos, label) ->
            subtreeVisibleStamp = null
            val now = System.nanoTime()
            val dtMs = (now - appliedNanos) / 1e6
            Log.i(TAG, "$label node=$key visible t=${now / 1e9}s" +
                " applyToVisible=${dtMs}ms")
        }
    }

    /**
     * W16: advances every `trail`/`lod` for the frame — trails record
     * world-space points and refill the camera-facing ribbon; lods
     * project the level-0 bounding sphere and rebind the selected
     * level (or cull). Camera inputs come from the camera node's
     * world pose + the retained projection fields — the primary
     * camera, matching iOS's point-of-view selection (per-view LOD
     * is upstream's split-screen refinement, future work).
     */
    private fun updateTrailsLods(dt: Float) {
        var has = false
        for ((_, rec) in nodesById) {
            if (rec.trail != null || rec.lod != null) {
                has = true
                break
            }
        }
        if (!has) return
        val camPos = FloatArray(3)
        val camRec = cameraNodeKey?.let { nodesById[it] }
        if (camRec != null) {
            val tcm = engine.transformManager
            val m = FloatArray(16)
            tcm.getWorldTransform(tcm.getInstance(camRec.entity), m)
            camPos[0] = m[12]; camPos[1] = m[13]; camPos[2] = m[14]
        }
        FsceneRealizer.surgicalContext(this).updateTrailsLods(
            dt, camPos, cameraFovDeg * Math.PI / 180.0, !cameraOrtho)
    }

    /** Writes each dynamic body's world pose into its node transform. */
    private fun syncBodies() {
        val tcm = engine.transformManager
        for (key in dynamicBodyKeys) {
            val rec = nodesById[key] ?: continue
            val body = rec.body ?: continue
            if (!body.isActive) continue
            val p = body.position
            val q = body.rotation
            val wp = floatArrayOf(
                p.xx().toFloat(), p.yy().toFloat(), p.zz().toFloat())
            val wq = floatArrayOf(q.x, q.y, q.z, q.w)
            // World → local: local = inv(parentWorld) × world.
            var local = D3Wire.trs(wp, wq, rec.localScale)
            val pk = rec.parentKey
            if (pk != null) {
                val pr = nodesById[pk]
                if (pr != null) {
                    val pw = FloatArray(16)
                    tcm.getWorldTransform(tcm.getInstance(pr.entity), pw)
                    val inv = FloatArray(16)
                    if (Matrix.invertM(inv, 0, pw, 0)) {
                        val out = FloatArray(16)
                        Matrix.multiplyMM(out, 0, inv, 0, local, 0)
                        local = out
                    }
                }
            }
            tcm.setTransform(tcm.getInstance(rec.entity), local)
            // Keep the node's local TRS in sync so a later teleport
            // composes through the parent correctly.
            val d = FsceneRealizer.decompose(local)
            rec.localPos = d[0]; rec.localQuat = d[1]; rec.localScale = d[2]
        }
    }

    /** Awake/settled transitions — same event shapes as iOS. */
    private fun pollSettle() {
        var awake = 0
        for (key in dynamicBodyKeys) {
            val b = bodies[key] ?: continue
            if (b.isActive) awake++
        }
        simTick++
        if (awake > 0 && lastAwakeCount == 0) {
            fireEvent(D3Event.AWAKE, "{\"awake\":$awake}")
        } else if (awake == 0 && lastAwakeCount > 0) {
            val parts = StringBuilder()
            var first = true
            for (key in dynamicBodyKeys) {
                val rec = nodesById[key] ?: continue
                val body = rec.body ?: continue
                val p = body.position
                val q = body.rotation
                val s = (key ushr 32)
                val i = (key and 0xFFFFFFFFL)
                if (!first) parts.append(',')
                first = false
                // RH world → LH .fscene: p.z negates; r → (−x,−y,z,w).
                parts.append(
                    "{\"s\":$s,\"i\":$i," +
                        "\"p\":[${p.xx()},${p.yy()},${-p.zz()}]," +
                        "\"r\":[${-q.x},${-q.y},${q.z},${q.w}]}")
            }
            fireEvent(D3Event.SETTLED, "{\"nodes\":[$parts]}")
        }
        lastAwakeCount = awake
    }

    private fun updateCamera(dt: Float) {
        val key = cameraNodeKey ?: return
        val rec = nodesById[key] ?: return
        val tcm = engine.transformManager
        val m = manipulator
        if (m != null) {
            // While attached the manipulator owns this node's
            // transform: its lookAt writes back through the local TRS
            // so the setModelMatrix below picks it up. A
            // setNodeTransforms on the camera node fights the
            // manipulator (same as iOS's allowsCameraControl).
            m.update(dt)
            val eye = FloatArray(3)
            val center = FloatArray(3)
            val up = FloatArray(3)
            m.getLookAt(eye, center, up)
            if (!cameraMovedLogged && lastManipEye != null &&
                (abs(eye[0] - lastManipEye!![0]) > 0.001f ||
                 abs(eye[1] - lastManipEye!![1]) > 0.001f ||
                 abs(eye[2] - lastManipEye!![2]) > 0.001f)) {
                cameraMovedLogged = true
                Log.i(TAG, "camera control: gesture pose → node" +
                    " write-back, eye=(${eye[0]},${eye[1]},${eye[2]})")
            }
            lastManipEye = eye.copyOf()
            camera.lookAt(
                eye[0].toDouble(), eye[1].toDouble(), eye[2].toDouble(),
                center[0].toDouble(), center[1].toDouble(),
                center[2].toDouble(),
                up[0].toDouble(), up[1].toDouble(), up[2].toDouble())
            var local = camera.getModelMatrix(FloatArray(16))
            // World → local: local = inv(parentWorld) × world.
            val pk = rec.parentKey
            if (pk != null) {
                val pr = nodesById[pk]
                if (pr != null) {
                    val pw = FloatArray(16)
                    tcm.getWorldTransform(tcm.getInstance(pr.entity), pw)
                    val inv = FloatArray(16)
                    if (Matrix.invertM(inv, 0, pw, 0)) {
                        val out = FloatArray(16)
                        Matrix.multiplyMM(out, 0, inv, 0, local, 0)
                        local = out
                    }
                }
            }
            tcm.setTransform(tcm.getInstance(rec.entity), local)
            val d = FsceneRealizer.decompose(local)
            rec.localPos = d[0]; rec.localQuat = d[1]
            rec.localScale = d[2]
        }
        val wm = FloatArray(16)
        tcm.getWorldTransform(tcm.getInstance(rec.entity), wm)
        camera.setModelMatrix(wm)
    }

    private fun render(tNanos: Long) {
        val sc = swapChain ?: return
        if (renderer.beginFrame(sc, tNanos)) {
            // W14: due offscreen passes first — a material sampling an
            // rt reads this frame's output in the screen passes below.
            // An rt's views render in `order` (sorted at apply).
            for ((_, rec) in renderTargets) {
                if (rec.views.isEmpty() ||
                    !RenderTargets.due(rec, tNanos)) continue
                for (v in rec.views) {
                    v.view?.let {
                        renderer.render(it)
                        logCommandOnce("w14.rtpass.${rec.spec.width}",
                            "rt pass rendered ${rec.spec.width}x" +
                                "${rec.spec.height}")
                    }
                }
                rec.lastRenderNanos = tNanos
                rec.dirty = false
            }
            // Screen passes share `view`: each entry's camera,
            // viewport (Filament's origin is bottom-left), layer mask,
            // and resolved AA/renderScale push per pass. The stage
            // look/effects stay written on `view` so every screen pass
            // gets the same post stack. No screen entries → `view`
            // renders the default pass — the pre-W14 path.
            if (screenViews.isEmpty()) {
                renderer.render(view)
            } else {
                for (rec in screenViews) {
                    val cam = rec.camera ?: continue
                    view.camera = cam
                    view.viewport = rec.viewport?.let { viewportOf(it) }
                        ?: Viewport(0, 0, viewportW, viewportH)
                    view.setVisibleLayers(0xFF, rec.layerMask and 0xFF)
                    view.multiSampleAntiAliasingOptions = rec.msaa
                    view.antiAliasing = rec.aa
                    view.dynamicResolutionOptions = rec.dsr
                    renderer.render(view)
                }
            }
            renderer.endFrame()
            tickStats(tNanos)
        }
    }

    private fun fireEvent(type: Int, payload: String) {
        Dart3dJni.fireToDart(viewId, type, payload)
    }

    // MARK: - Event tags (shared with dispatch.dart)

    private object D3Event {
        const val AWAKE = 1
        const val SETTLED = 2
        const val CONTACT = 3
        const val QUERY_REPLY = 4
        const val JOINT = 5
    }

    private companion object {
        init {
            System.loadLibrary("filament-jni")
        }

        @Volatile private var filamatReady = false
        // Every NodeChange flag — the "treating as update" idempotent
        // addNode path applies the spec as a full update.
        private val ALL_NODE_FLAGS = setOf(
            "transform", "name", "layers", "visible",
            "reparented", "components", "skin")
        private val JOINT_TYPES = setOf(
            "fixed", "spherical", "revolute", "prismatic", "generic")
        private val JOINT_MOTIONS = setOf("locked", "free", "limited")
        private const val PI_F = 3.1415927f
        // W30: Dart3dSetBackend wire values, shared with the Dart caller.
        private const val BACKEND_OPENGL = 1
        private const val BACKEND_VULKAN = 2
        /** Auto-mode default, set from the W30 A142 A/B measurement. */
        private val DEFAULT_BACKEND = Engine.Backend.VULKAN
        const val D3_MSG_HELLO = 1
        const val D3_MSG_LOAD_SCENE = 2
        const val D3_MSG_PAYLOAD = 3
        const val D3_MSG_SET_TRANSFORMS = 4
        const val D3_MSG_COMMAND = 5
        const val D3_MSG_VIEW_CONFIG = 6
    }
}
