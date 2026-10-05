package com.jasonholtdigital.dart3d

import android.content.Context
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
    // Eager allocations run before `init`'s cleanup guard — each is
    // wrapped so a throw destroys the Engine (and all it owns) before
    // the exception reaches the bridge.
    private val renderer: Renderer = guarded { engine.createRenderer() }
    val scene: Scene = guarded { engine.createScene() }
    private val view: View = guarded { engine.createView() }
    private var swapChain: SwapChain? = null

    private val surfaceView = guarded { SurfaceView(context) }
    private val uiHelper =
        guarded { UiHelper(UiHelper.ContextErrorPolicy.DONT_CHECK) }

    /**
     * Runs an eager property allocation; on a throw frees the Engine
     * (which destroys the renderer/scene/view it created) and the KTX2
     * provider, then rethrows. Used only for initializers that run
     * before `init` (whose own catch covers the rest).
     */
    private inline fun <T> guarded(block: () -> T): T = try {
        block()
    } catch (t: Throwable) {
        try { TextureFactory.releaseEngine(engine) } catch (_: Throwable) {}
        try { engine.destroy() } catch (_: Throwable) {}
        throw t
    }

    /**
     * W30 backend selection, resolved once per engine. An explicit
     * `Dart3dSetBackend` pref (the example's `DART3D_BACKEND` define)
     * wins; `auto` takes [DEFAULT_BACKEND] when the device declares
     * Vulkan and falls back to OpenGL when it does not, or when the
     * device is [DeviceTier.LOW]. A backend that
     * fails to build (Vulkan claimed but unusable) retries on OpenGL.
     */
    private fun createEngine(): Engine {
        val pref = Dart3dJni.nativeBackendPref()
        var backend = when {
            MaterialPackages.isBakeRun() -> Engine.Backend.OPENGL
            pref == BACKEND_OPENGL -> Engine.Backend.OPENGL
            pref == BACKEND_VULKAN -> Engine.Backend.VULKAN
            else -> if (DeviceTier.autoBackendIsVulkan(context)) {
                DEFAULT_BACKEND
            } else {
                Engine.Backend.OPENGL
            }
        }
        val engine = try {
            Engine.Builder().backend(backend).fenced { build() }
        } catch (e: Exception) {
            if (backend == Engine.Backend.OPENGL) throw e
            Log.w(TAG, "Filament $backend engine failed, retrying on OpenGL", e)
            backend = Engine.Backend.OPENGL
            Engine.Builder().backend(backend).fenced { build() }
        }
        Log.i(TAG, "Filament engine backend: $backend (pref=$pref," +
            " tier=${DeviceTier.of(context)})")
        ColdStart.mark("engine created")
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
    lateinit var litMaterial: Material
        private set
    lateinit var litMaskedMaterial: Material
        private set
    lateinit var litBlendMaterial: Material
        private set
    lateinit var unlitMaterial: Material
        private set
    lateinit var unlitMaskedMaterial: Material
        private set
    lateinit var unlitBlendMaterial: Material
        private set

    /**
     * False until the base prebuilts + trail material are loaded. The
     * packages compile on a background thread ([MaterialPackages]
     * prewarm — ~4 s each for the lit set on the A142); construction
     * and the frame loop never wait on filamat. Until ready, stepFrame
     * leaves mutations queued (nothing can realize without materials)
     * and polls the cache once per frame.
     */
    private var materialsReady = false
    private var materialsFailed = false
    /** True once `init` finished. Declared before `init` on purpose:
     * properties declared after it (pendingWork, terminalReason, …)
     * aren't initialized yet while `init` runs. */
    private var constructed = false
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
    lateinit var trailMaterial: Material
        private set

    // MARK: - Jolt world

    val world = guarded { JoltWorld() }

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

    // MARK: - W26 camera-facing geometry

    /**
     * Nodes whose vertex buffers re-expand toward the live camera each
     * frame — `d3:procMesh` polylines/line-segments/billboards and
     * `d3:instances` billboard quads. Filament's line primitives are
     * thin; thick lines ride camera-facing ribbon quads instead.
     */
    internal val cameraFacing = HashMap<Long, FacingSpec>()

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

    private val deviceTier = DeviceTier.of(context)

    /** True while the device picks the pipeline: no `quality` tier is
     *  set and the device is [DeviceTier.LOW]. */
    private val lowDeviceProfile: Boolean
        get() = DeviceProfile.isLow(deviceTier, viewQuality)

    /** The AA source for resolve chains — the tier when set, else the
     *  widget's antialiasingMode ([DeviceProfile.aaSource]). */
    private fun effectiveViewConfigAa(): Int? =
        DeviceProfile.aaSource(viewQuality, viewConfigAa, lowDeviceProfile)

    /** DPCF (dithered PCF) keeps a soft edge — PCSS's blocker search
     *  runs ~300ms/frame on Mali at these world scales. On the Fire
     *  tablet DPCF itself costs about 48 ms a dice frame over hard PCF,
     *  so the low device profile takes PCF. */
    private fun shadowType(): View.ShadowType =
        if (lowDeviceProfile) View.ShadowType.PCF else View.ShadowType.DPCF

    /** The default pass's resolution: no view entry exists there, and
     *  the stage's `renderScale` reaches view entries only. */
    private fun defaultResolution(): View.DynamicResolutionOptions =
        RenderTargets.dsrOptions(
            DeviceProfile.renderScale(null, null, lowDeviceProfile))

    /** Writes the parts of the device profile that live on the shared
     *  [view] and follow `quality`: shadow filter, HDR buffer size and,
     *  for the default pass, resolution. */
    private fun applyDeviceProfile() {
        view.setShadowType(shadowType())
        view.renderQuality = View.RenderQuality().apply {
            hdrColorBuffer = if (lowDeviceProfile) View.QualityLevel.LOW
                else View.QualityLevel.HIGH
        }
        if (screenViews.isEmpty()) {
            view.dynamicResolutionOptions = defaultResolution()
        }
    }

    /** Stage-level view-quality defaults (W14) — a views entry's
     *  absent antiAliasing/renderScale/filterQuality inherits these. */
    private var stageAntiAliasing: String? = null
    /** Null while the stage carries no `renderScale` key. */
    private var stageRenderScale: Double? = null
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

    /** W25: decoded `.cube` tables → the direct `customLut` buffers,
     * keyed by `ref + sep + blend` (the blend bakes into the texels).
     * Entries drop when a `payload`/`upsertPayload` chunk rewrites the
     * ref's bytes. */
    private val lutBuffers =
        object : LinkedHashMap<String, Pair<java.nio.ByteBuffer, Int>>(
            8, 0.75f, true) {
            // A 64³ table is ~3 MiB and every distinct ref+blend is its
            // own entry — an animated lutBlend or document churn grew
            // this without bound. Keep the few most recently used.
            override fun removeEldestEntry(
                eldest: MutableMap.MutableEntry<String,
                    Pair<java.nio.ByteBuffer, Int>>?,
            ): Boolean = size > MAX_LUT_CACHE_ENTRIES
        }

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
            val t0 = android.os.SystemClock.uptimeMillis()
            stepFrame(tNanos)
            val ms = android.os.SystemClock.uptimeMillis() - t0
            // Everything here runs on main (Choreographer) — a long
            // frame blocks input dispatch. Surface it so an ANR has a
            // culprit in logcat even from a release build.
            if (ms >= SLOW_FRAME_MS) {
                Log.w(TAG, "slow frame ${ms}ms on main: ops=$lastDrainCount" +
                    " realize=$lastFrameRealized")
            }
            // failTerminal()/release() inside stepFrame removed the
            // callback, but this doFrame is still executing — don't
            // re-arm a dead view (it would poll every vsync forever).
            if (detached || materialsFailed) return
            Choreographer.getInstance().postFrameCallback(this)
        }
    }

    init {
        try {
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
            // Never compile on main here: DNPluginRegistry.createView runs
            // on the UI thread, and a cold compile of the lit set parked it
            // for ~12 s (the captured ANR). prewarm reads the shipped or
            // disk-cached packages (a few ms); only when one is missing
            // does it start a background compile for this engine's API
            // and leave stepFrame to finish init.
            MaterialPackages.attach(context)
            MaterialPackages.prewarm(MaterialPackages.apiFor(engine.backend))
            materialsReady = tryLoadBaseMaterials()

            fallbackWhite = TextureFactory.solid(engine, 255, 255, 255, 255)
            fallbackNormal = TextureFactory.solid(engine, 128, 128, 255, 255)
            fallbackEmissive = TextureFactory.solid(engine, 0, 0, 0, 255)

            cameraEntity = EntityManager.get().create()
            camera = engine.createCamera(cameraEntity)
            setCameraExposure(camera, 1.0f)

            view.scene = scene
            view.camera = camera
            // Filament shows layer 0 only by default; the upstream view
            // mask is all-layers — widen so node `layers` is the only gate.
            view.setVisibleLayers(0xFF, 0xFF)
            // Lights declaring castsShadow need a shadow type on the view —
            // Filament renders no shadow maps without one.
            applyDeviceProfile()
            // W22: KHR_materials_transmission variants render through
            // screen-space refraction — without the flag Filament skips
            // the refraction pass even for refraction-enabled materials.
            view.setScreenSpaceRefractionEnabled(true)
            applyClearColor()

            uiHelper.renderCallback = object : UiHelper.RendererCallback {
                override fun onNativeWindowChanged(surface: Surface) {
                    // A still-queued destroy of the old swapchain would
                    // leave its VkSurfaceKHR on the window when the new
                    // one is created (NATIVE_WINDOW_IN_USE) — drain it.
                    destroySwapChainAndWait("native window changed")
                    swapChain = engine.createSwapChain(surface, uiHelper.swapChainFlags)
                    Log.i(TAG, "dart3d view $viewId swapchain created")
                    ColdStart.mark("swapchain created")
                }
                override fun onDetachedFromSurface() {
                    destroySwapChainAndWait("surface destroyed")
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
            constructed = true
        } catch (t: Throwable) {
            // The bridge turns this into an InitFailedView and never
            // sees this object again — free the eagerly created Engine
            // (and everything it owns), Jolt world and KTX2 provider
            // before the exception leaves, or every failed attempt
            // leaks them until process death.
            releasePartial()
            throw t
        }
    }

    /**
     * Destroys the swapchain and blocks until the driver thread has run
     * the destroy. `engine.destroySwapChain` only enqueues; returning
     * from `surfaceDestroyed` with it still queued lets Android tear the
     * ANativeWindow down while the Vulkan driver still owns a swapchain
     * and VkSurfaceKHR on it. The next flush (the first `beginFrame`
     * after a warm relaunch) then destroys those against a dead window
     * and creates the new swapchain beside them — SURFACE_LOST,
     * "enumerate size error", or NATIVE_WINDOW_IN_USE (#18). Filament's
     * UiHelper contract: flushAndWait before returning. Main thread only.
     */
    private fun destroySwapChainAndWait(why: String) {
        val sc = swapChain ?: return
        swapChain = null
        engine.destroySwapChain(sc)
        val t0 = android.os.SystemClock.uptimeMillis()
        engine.flushAndWait()
        Log.i(TAG, "dart3d view $viewId swapchain destroyed ($why); " +
            "driver drained in ${android.os.SystemClock.uptimeMillis() - t0}ms")
    }

    private fun releasePartial() {
        detached = true
        releaseReason = "construction failed"
        try { Choreographer.getInstance().removeFrameCallback(frameCallback) }
        catch (_: Throwable) {}
        try { uiHelper.detach() } catch (_: Throwable) {}
        try { world.close() } catch (_: Throwable) {}
        try { TextureFactory.releaseEngine(engine) } catch (_: Throwable) {}
        // Engine.destroy() frees every object still owned by the
        // engine (renderer, scene, view, textures, materials).
        try { engine.destroy() } catch (_: Throwable) {}
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
        materialKey: Long? = null,
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
        // A cold variant compile is seconds on the A142 (3.4 s seen
        // for d3_lit_e20) and this runs inside the main-thread frame
        // drain. Compile it in the background, render the base
        // prebuilt meanwhile, and re-decode the waiting material
        // resources when the package lands.
        val api = MaterialPackages.apiFor(engine.backend)
        val spec = MaterialPackages.litSpec(unlit, blendingForMode(mode),
            flags, boundSlots, api)
        var bytes = MaterialPackages.cached(spec)
        var built: Material? = null
        if (bytes != null) {
            built = try {
                MaterialPackages.load(engine, bytes)
            } catch (e: Exception) {
                null
            }
            // A shipped or cached package this engine refuses (the app
            // resolved another Filament) is compiled here instead.
            if (built == null && MaterialPackages.rejectStored(spec)) {
                Log.w(TAG, "stored package ${spec.key} did not load;" +
                    " compiling it")
                bytes = null
            }
        }
        if (bytes == null && !MaterialPackages.hasFailed(spec.key)) {
            materialKey?.let {
                variantWaiters.getOrPut(key) { HashSet() }.add(it)
            }
            if (variantInflight.add(key)) {
                Log.i(TAG, "material variant d3_lit_e$flags/$mode " +
                    "compiling in background; base material meanwhile")
                MaterialPackages.litPackageAsync(unlit,
                    blendingForMode(mode), flags, boundSlots, api) {
                    pendingWork.offer { onVariantCompiled(key) }
                }
            }
            return base()
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

    /** Variant keys with a background compile in flight. */
    private val variantInflight = HashSet<VariantKey>()
    /** Material resource keys rendering a base stand-in while their
     * variant compiles — re-decoded when it lands. */
    private val variantWaiters = HashMap<VariantKey, MutableSet<Long>>()

    /** Frame-thread continuation of a background variant compile. */
    private fun onVariantCompiled(key: VariantKey) {
        variantInflight.remove(key)
        val waiters = variantWaiters.remove(key) ?: return
        val ctx = FsceneRealizer.surgicalContext(this)
        for (mk in waiters) {
            resources.materialResources[mk]?.let { upsertMaterial(mk, it) }
            // doubleSided d3:instances snapshots aren't consumers of
            // the shared instance — re-bake them against the variant.
            ctx.redecodeDoubleSidedInstancesForMaterial(mk)
        }
    }

    /**
     * Terminal init failure: the view can never render. Shows the
     * on-screen notice, stops the frame loop, drops queued work and
     * makes [onMutation] reject (and log) everything after. Resources
     * are still released by disposeView/detach as usual.
     */
    private fun failTerminal(reason: String) {
        // During construction (a cached compile failure found by the
        // first tryLoadBaseMaterials) throw instead: the bridge turns
        // it into the visible InitFailedView, and later-declared state
        // this path touches isn't initialized yet.
        if (!constructed) throw IllegalStateException(reason)
        if (materialsFailed) return
        materialsFailed = true
        terminalReason = reason
        Choreographer.getInstance().removeFrameCallback(frameCallback)
        pendingWork.clear()
        showInitFailure(reason)
    }
    private var terminalReason = ""

    /** Overlays a visible, non-interactive init-failure notice. */
    private fun showInitFailure(reason: String) {
        if (initFailureShown) return
        initFailureShown = true
        addView(TextView(context).apply {
            setBackgroundColor(android.graphics.Color.rgb(40, 0, 0))
            setTextColor(android.graphics.Color.rgb(255, 180, 180))
            textSize = 14f
            gravity = Gravity.CENTER
            text = "dart3d: scene view failed to initialize\n$reason"
        }, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    }
    private var initFailureShown = false

    /**
     * Loads the six base prebuilts + the trail material from the
     * process package cache. Returns false (loading nothing) while any
     * package is still compiling; a package filamat rejected is fatal
     * for this view and is reported loudly once.
     */
    private fun tryLoadBaseMaterials(): Boolean {
        if (materialsReady) return true
        if (materialsFailed) return false
        val api = MaterialPackages.apiFor(engine.backend)
        val specs = MaterialPackages.baseSet(api)
        val keys = specs.map { it.key }
        val failed = keys.filter { MaterialPackages.hasFailed(it) }
        if (failed.isNotEmpty()) {
            Log.e(TAG, "dart3d: base material compile FAILED ($failed) —" +
                " this scene view cannot render")
            // The compile runs after createView returned, so the
            // bridge's InitFailedView can't catch this — show the same
            // on-screen failure here instead of a live blank surface.
            failTerminal("base material compile failed for " +
                "${api.name}: ${failed.joinToString()}")
            return false
        }
        val bytes = keys.map { MaterialPackages.peek(it) ?: return false }
        val loaded = ArrayList<Material>(bytes.size)
        try {
            for (b in bytes) loaded += MaterialPackages.load(engine, b)
        } catch (t: Throwable) {
            // Runs from stepFrame on a cold start — outside the
            // bridge's constructor catch. Free what loaded, then go
            // terminal instead of crashing the UI thread.
            for (m in loaded) engine.destroyMaterial(m)
            val refused = specs[loaded.size]
            if (MaterialPackages.rejectStored(refused)) {
                // A shipped or cached package this engine refuses (the
                // app resolved another Filament): compile it instead,
                // and let stepFrame retry when it lands.
                Log.w(TAG, "stored package ${refused.key} did not load" +
                    " (${t.message}); compiling it")
                MaterialPackages.compileAsync(refused)
                return false
            }
            Log.e(TAG, "dart3d: base material load FAILED", t)
            failTerminal("base material load failed for ${api.name}: " +
                "${t.javaClass.simpleName}: ${t.message}")
            return false
        }
        ColdStart.mark("base materials loaded")
        litMaterial = loaded[0]
        litMaskedMaterial = loaded[1]
        litBlendMaterial = loaded[2]
        unlitMaterial = loaded[3]
        unlitMaskedMaterial = loaded[4]
        unlitBlendMaterial = loaded[5]
        trailMaterial = loaded[6]
        // The materials are compiled double-sided-capable; keep the
        // default single-sided unless a resource's doubleSided says so.
        // Packages compiled doubleSided bake culling to NONE, so cull back
        // faces explicitly (the material-less fallbacks use these).
        for (m in loaded.subList(0, 6)) {
            m.defaultInstance.setDoubleSided(false)
            m.defaultInstance.setCullingMode(
                com.google.android.filament.Material.CullingMode.BACK)
        }
        // W16: the trail ribbon's own material — upstream's default is
        // translucent unlit driven fully by vertex color (incl. alpha),
        // drawn without culling (a camera-facing strip's winding flips
        // where the path doubles back). One shared instance: the
        // shader has no parameters, so every trail binds the same one.
        trailMaterial.defaultInstance.setDoubleSided(true)
        return true
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
        return loadFixed(MaterialPackages.catcherSpec(
            MaterialPackages.apiFor(engine.backend)))
    }

    /**
     * Loads a fixed package that is fetched at first use. A stored copy
     * the engine refuses is compiled here, on the calling thread.
     */
    private fun loadFixed(spec: MaterialPackages.Spec): Material {
        fun bytes() = checkNotNull(MaterialPackages.compile(spec))
            { "material package ${spec.key} failed to compile" }
        return try {
            MaterialPackages.load(engine, bytes())
        } catch (e: Exception) {
            if (!MaterialPackages.rejectStored(spec)) throw e
            Log.w(TAG, "stored package ${spec.key} did not load;" +
                " compiling it")
            MaterialPackages.load(engine, bytes())
        }
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
     * world space and the sprite entity's transform is identity, so
     * OBJECT domain passes them through unchanged. (WORLD domain is
     * tempting here but misplaces geometry on this backend — see the
     * W18 report.) UV0/UV1 carry the two flipbook cells; CUSTOM0 is
     * the blend factor, forwarded through a custom interpolant.
     * `flipUV(false)` keeps v=0 = the uploaded image's top row
     * (upstream's quad UVs are authored v-top).
     */
    private fun buildParticleMaterial(additive: Boolean): Material {
        return loadFixed(MaterialPackages.particleSpec(additive,
            MaterialPackages.apiFor(engine.backend)))
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
        // Identity transform — every other renderable in this layer
        // owns a TransformManager component; vertex data is already
        // world-space so identity preserves positions.
        engine.transformManager.setTransform(
            engine.transformManager.create(entity), IDENTITY16)
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
            .fenced { build(engine, entity) }
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
    private fun tickParticles(dt: Double) {
        if (particleRuntimes.isEmpty()) return
        val camPos = FloatArray(3)
        camera.getPosition(camPos)
        val camFwd = FloatArray(3)
        camera.getForwardVector(camFwd)
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
            for (rt in list) rt.tick(dt, camPos, wm, camFwd)
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

    /** The last effective stage exposure (exposure × 2^AE comp). */
    private var lastEffExposure = 1.0f

    /**
     * Sets the camera's exposure to exactly [e], the stage's linear
     * multiplier (upstream's `exposure`; lights and the environment are
     * in upstream's units, see FsceneRealizer's unit note). Filament
     * computes exposure as `t·S / (1.2·N²·100)`, so `N = 1`,
     * `t = 1.2 s`, `S = 100·e` gives `e`. It clamps `S` to
     * [10, 204800]; outside that the remainder moves into the shutter
     * time.
     */
    private fun setCameraExposure(cam: Camera, e: Float) {
        val iso = 100.0f * e
        when {
            iso < 10f -> cam.setExposure(1.0f, 1.2f * (iso / 10f), 10f)
            iso > 204800f -> cam.setExposure(1.0f,
                1.2f * (iso / 204800f), 204800f)
            else -> cam.setExposure(1.0f, 1.2f, iso)
        }
    }

    internal fun applyStageLook(
        exposure: Float, toneMapping: String,
        agxWhite: Double, agxContrast: Double,
        fx: StageEffects? = null,
    ) {
        // W25: autoExposure's static term — upstream adds
        // `compensation` (EV) to the metered target; metering itself
        // is a documented platform limit (see applyStageEffects), so
        // the compensation folds into the base exposure as a ×2^c
        // multiplier.
        val aeComp = fx?.autoExposure
            ?.takeIf { it.enabled }?.compensation ?: 0.0
        val effExposure = (exposure *
            Math.pow(2.0, aeComp)).toFloat()
        lastEffExposure = effExposure
        setCameraExposure(camera, effExposure)
        // W14: exposure is a Camera property — every screen-bound view
        // camera takes it (offscreen views stay at exposure 1, the
        // same policy as the per-View post stack). applyViews
        // re-applies [lastEffExposure] to cameras it creates later.
        for (rec in screenViews) {
            rec.camera?.let { setCameraExposure(it, effExposure) }
        }
        val mapper: ToneMapper = when (toneMapping) {
            "pbrNeutral" -> ToneMapper.PBRNeutralToneMapper()
            "agx" -> ToneMapper.Agx()
            "filmic" -> ToneMapper.Filmic()
            // Upstream's `aces` is the Hill fit with its 1/0.6 input
            // gain; Filament's ACESLegacy is its ACES with that gain.
            "aces" -> ToneMapper.ACESLegacy()
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
        }
        // W25: the LUT grades independently of `enabled` (upstream's
        // rule). A `chunk:`/id-token ref resolves through the payload
        // store — its decode-time claim re-runs the stage when the
        // bytes land; an asset path resolves from the app assets.
        // `lutBlend` bakes into the uploaded texels (lerp toward the
        // identity cell) since `customLut` has no mix knob.
        val lut = fx?.colorGrading?.lut?.takeIf { it.isNotEmpty() }
            ?.let { ref -> resolveLutBuffer(ref, fx.colorGrading.lutBlend) }
        lut?.let { (buf, size) -> cgBuilder.customLut(buf, size) }
        val cg = cgBuilder.build(engine)
        // Reachability fence (minSdk 26 has no Reference.
        // reachabilityFence): the Java Builder, the ToneMapper and the
        // LUT buffer each own native memory freed by a finalizer, and
        // the Builder only holds raw native pointers to the other two.
        // In the R8-minified release build ART may treat an object as
        // dead as soon as its `long` handle is loaded, so a GC between
        // toneMapper()/customLut() and build() (the W25 LUT resolve
        // allocates MiBs) finalized them mid-apply. A142 crashes at the
        // harness W25 LUT lanes: SIGBUS pc=0x12 in
        // ColorGrading::Builder::build, SIGSEGV in
        // ColorGrading::Builder::customLut. The field write after
        // build keeps all three alive through every native call.
        colorGradingKeepAlive = arrayOf(cgBuilder, mapper, lut?.first)
        view.colorGrading = cg
        envColorGrading?.let {
            if (it !== cg) engine.destroyColorGrading(it) }
        envColorGrading = cg
    }

    /** Last ColorGrading inputs (Builder, ToneMapper, LUT buffer) —
     * written after `build` purely as a reachability fence. */
    @Volatile
    private var colorGradingKeepAlive: Array<Any?>? = null

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

        // Bloom + lens flare — Filament folds flare into BloomOptions:
        // the bloom pass must be enabled for ghosts/halo to render, and
        // its `strength` doubles as the flare composite weight. A
        // flare-only stage therefore enables the pass at
        // lensFlare.intensity — real ghosts/halo/CA render, at the cost
        // of a mild bloom halo the same gain (not separable; iOS widens
        // SceneKit bloomIntensity the same way). Never silent.
        view.bloomOptions = View.BloomOptions().apply {
            enabled = fx.bloom.enabled || fx.lensFlare.enabled
            strength = if (fx.bloom.enabled) fx.bloom.intensity.toFloat()
                else fx.lensFlare.intensity.toFloat().coerceIn(0f, 1f)
            // Filament's `threshold` is a bool: keep what is above 1.
            // Upstream's cutoff is passed as `highlight`, the value
            // bright input is compressed toward — but Filament raises
            // a highlight below 10 to 10, so an upstream threshold in
            // its usual 0…2 range changes nothing here. iOS's resolve
            // pass does the same (ToneMapping.swift).
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
        if (fx.lensFlare.enabled && fx.bloom.enabled &&
            fx.lensFlare.intensity != fx.bloom.intensity) {
            // One shared `strength` weights bloom AND the flare
            // composite — the authored flare intensity can't apply
            // separately while bloom is on. Say so (PR #8 review).
            logCommandOnce("fx.lensFlare.intensityWithBloom",
                "lensFlare.intensity is not separable from" +
                    " bloom.intensity on Filament (one BloomOptions" +
                    " strength); flare follows bloom.intensity")
        }
        // W25: standalone chromaticAberration (enabled without
        // lensFlare) has no Filament surface — the platform-limit
        // note logs at the bottom of this function.
        if (fx.lensFlare.enabled && !fx.bloom.enabled) {
            logCommandOnce("fx.lensFlare.standalone",
                "lensFlare without bloom: Filament's flare rides the" +
                    " bloom pass — enabled at lensFlare.intensity" +
                    " strength, so a mild bloom halo comes with the" +
                    " ghosts (flare gain is not separable)")
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
        if (ssr.enabled) {
            // Coverage note (W25 fix-2): SSR shades only lit materials
            // — compiled with reflectionMode SCREEN_SPACE — whose
            // reflection rays land on on-screen content; misses fall
            // back to IBL specular, rough surfaces show little, and
            // frame N needs N-1's color+depth history (the first
            // SSR-enabled frame seeds it). Unlit materials never
            // reflect.
            logCommandOnce("fx.ssr.conditions",
                "screenSpaceReflections: applies to lit materials;" +
                    " off-screen/rough surfaces keep IBL specular")
        }
        if (ssr.enabled && (ssr.intensity != 1.0 || ssr.maxSteps != 90 ||
                ssr.blur != 0.3 || ssr.distanceFadeStart != 0.0 ||
                ssr.resolutionScale != 1.0)) {
            logCommandOnce("fx.ssr.params",
                "some SSR fields unmapped on Filament 1.71.6" +
                    " (thickness/maxDistance/stride only)")
        }

        // W25 film grain — Filament has no grain pass; approximated
        // by temporal dithering (the post pipeline's animated noise,
        // intensity unmapped).
        // Grain off must keep Filament's default TEMPORAL dithering —
        // writing NONE stripped the normal anti-banding from every
        // scene with an effects block.
        view.dithering = View.Dithering.TEMPORAL
        if (fx.filmGrain.enabled) {
            logCommandOnce("fx.filmGrain.approx",
                "filmGrain approximated on Filament as temporal" +
                    " dithering; grain intensity unmapped")
        }

        // W25 documented platform limits — no Java-binding surface
        // exists for these blocks; each logs once and the decoded
        // value still participates in blending/parity.
        if (fx.chromaticAberration.enabled && !fx.lensFlare.enabled) {
            logCommandOnce("fx.ca.limit",
                "chromaticAberration standalone: platform limit —" +
                    " Filament's CA only shades the lens-flare" +
                    " ghosts/halo (flare.mat); no post-material" +
                    " binding exists; ignored")
        }
        if (fx.autoExposure.enabled) {
            logCommandOnce("fx.autoExposure.limit",
                "autoExposure metering: platform limit — Filament's" +
                    " readPixels is debug/testing-grade (in-frame," +
                    " perf-heavy); `compensation` is applied as a" +
                    " static EV offset in applyStageLook," +
                    " strength/speeds/EV range unmapped")
        }
        if (fx.globalIllumination.enabled) logCommandOnce("fx.gi.limit",
            "globalIllumination: platform limit — no dynamic" +
                " GI/probe-volume API in the Java bindings; the IBL" +
                " environment stands; ignored")
        if (fx.godRays.enabled) logCommandOnce("fx.godRays.limit",
            "godRays: platform limit — no light-shaft/volumetric" +
                " post pass in the Java bindings; ignored")
    }

    /**
     * W25: resolves a `colorGrading.lut` ref to the direct
     * `float3`-cube buffer `ColorGrading.Builder.customLut` consumes.
     * `chunk:`/id-token refs read the payload store (null while
     * deferred — the realizer's claim re-runs the stage on arrival);
     * other strings are app-asset paths (same lookup the `asset` env
     * type uses). Results cache by ref+blend; a `payload`/
     * `upsertPayload` landing on the ref's id drops stale entries.
     */
    private fun resolveLutBuffer(
        ref: String, blend: Double,
    ): Pair<java.nio.ByteBuffer, Int>? {
        val cacheKey = "$ref\u001F$blend"
        lutBuffers[cacheKey]?.let { return it }
        // A token ref reads the payload store only — a miss is the
        // deferred-claim state, not an asset lookup (the claim
        // re-runs the stage when the chunk lands; iOS parity — no
        // bundle attempt and no 'not found' log for chunk ids).
        val pid = D3Wire.localIdKey(ref)
        val bytes: ByteArray? = if (pid != null) {
            payloadStore[pid]
        } else {
            FlutterAssets.readBytes(context, ref).also {
                if (it == null) {
                    logCommandOnce("fx.lut.asset.$ref",
                        "colorGrading LUT asset '$ref' not found")
                }
            }
        }
        bytes ?: return null
        val table = try {
            StageLut.parse(bytes)
        } catch (e: StageLut.ParseException) {
            logCommandOnce("fx.lut.parse.$ref",
                "colorGrading LUT '$ref': ${e.message}")
            return null
        }
        val pair = table.directBuffer(blend) to table.size
        lutBuffers[cacheKey] = pair
        return pair
    }

    /** Drops cached LUT buffers whose ref names payload id [key] —
     * called when a `payload`/`upsertPayload` chunk rewrites those
     * bytes, so the next apply rebuilds from the new table. */
    private fun invalidateLuts(backedBy: Long) {
        lutBuffers.entries.removeIf { entry ->
            val ref = entry.key.substringBefore('\u001F')
            D3Wire.localIdKey(ref) == backedBy
        }
    }

    // MARK: - Lifecycle

    /** True while the view is off-window but not released — the frame
     * loop is parked and resumes on the next attach. */
    private var paused = false

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (detached) {
            // Re-attached after release: nothing can draw. Say so —
            // this is the silent-blank "zombie" the audit flagged.
            Log.e(TAG, "dart3d view $viewId re-attached after release " +
                "($releaseReason) — it cannot render; the framework " +
                "should have created a new view")
            return
        }
        if (paused && !materialsFailed) {
            paused = false
            lastFrameNanos = 0L
            Choreographer.getInstance().postFrameCallback(frameCallback)
            Log.i(TAG, "dart3d view $viewId re-attached; frame loop resumed")
        }
    }

    override fun onDetachedFromWindow() {
        if (Dart3dBridge.frameworkDisposes && !detached) {
            // The framework will call disposeView when the element
            // really goes away; a window detach (activity recreate,
            // re-parenting on a warm relaunch) only parks the loop.
            // Releasing here left a re-attached view with a destroyed
            // Engine that Dart kept driving — blank, no error.
            paused = true
            Choreographer.getInstance().removeFrameCallback(frameCallback)
        } else {
            release("onDetachedFromWindow")
        }
        super.onDetachedFromWindow()
    }

    private var releaseReason = ""

    /**
     * Destroys every Filament/Jolt object this view owns. Idempotent;
     * runs on main (disposeView, or detach on frameworks without it).
     */
    fun release(reason: String) {
        if (!detached) {
            detached = true
            releaseReason = reason
            Log.i(TAG, "dart3d view $viewId released ($reason)")
            Choreographer.getInstance().removeFrameCallback(frameCallback)
            // detach() fires onDetachedFromSurface → destroys the swap
            // chain (and drains the driver) while the engine is alive.
            uiHelper.detach()
            destroySwapChainAndWait("release")
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
            // Read (not just written) so R8 can't strip the fence field.
            if (colorGradingKeepAlive?.isNotEmpty() == true) {
                colorGradingKeepAlive = null
            }
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
                destroyLightCluster(rec)
                scene.removeEntity(rec.entity)
                engine.destroyEntity(rec.entity)
                EntityManager.get().destroy(rec.entity)
                rec.procGpuMesh?.destroy(engine)
                rec.procMaterialInstance?.let {
                    engine.destroyMaterialInstance(it)
                }
            }
            nodesById.clear()
            cameraFacing.clear()
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
            if (materialsReady) {
                engine.destroyMaterial(litMaterial)
                engine.destroyMaterial(litMaskedMaterial)
                engine.destroyMaterial(litBlendMaterial)
                engine.destroyMaterial(unlitMaterial)
                engine.destroyMaterial(unlitMaskedMaterial)
                engine.destroyMaterial(unlitBlendMaterial)
                engine.destroyMaterial(trailMaterial)
            }
            catcherMaterialBacking?.let { engine.destroyMaterial(it) }
            // W18: the lazily-built sprite materials.
            particleAlphaMaterial?.let { engine.destroyMaterial(it) }
            particleAdditiveMaterial?.let { engine.destroyMaterial(it) }
            particleAlphaMaterial = null
            particleAdditiveMaterial = null
            for ((_, m) in materialVariants) engine.destroyMaterial(m)
            materialVariants.clear()
            engine.destroyRenderer(renderer)
            engine.destroyView(view)
            engine.destroyScene(scene)
            engine.destroyCameraComponent(cameraEntity)
            EntityManager.get().destroy(cameraEntity)
            // The KTX2 provider references this Engine — free it
            // first so a later Engine at the same address can never
            // inherit it (audit P1: leak + use-after-free).
            TextureFactory.releaseEngine(engine)
            engine.destroy()
            dropDocumentState()
        }
    }

    /**
     * A rectAreaLight's cluster lights are scene entities of their own;
     * destroying the node's entity does not take them with it.
     */
    private fun destroyLightCluster(rec: FsceneRealizer.NodeRec) {
        for (child in rec.lightEntities) {
            scene.removeEntity(child)
            engine.destroyEntity(child)
            EntityManager.get().destroy(child)
        }
        rec.lightEntities.clear()
    }

    /**
     * Lets go of the document a released view was showing: payload
     * chunks, the manifest, the op journal and everything decoded from
     * them. Nothing can use them once the engine is gone, and the view
     * object itself can outlive its release for as long as the host
     * framework keeps a reference to it or to anything above it in the
     * view tree, so what it still holds is what that costs.
     */
    private fun dropDocumentState() {
        payloadStore.clear()
        opPayloadSpecs.clear()
        pendingPayloadRefs.clear()
        pendingParents.clear()
        lastManifest = null
        lastStage = null
        lutBuffers.clear()
        pendingWork.clear()
        surgicalJournal.clear()
        streamedSubtreeOps.clear()
        transformWrites.clear()
        variantWaiters.clear()
        savedCameraTrs = null
        manipulator = null
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

    private var warnedDeadMutation = false

    fun onMutation(id: Long, eventTag: Int, data: ByteArray) {
        if (materialsFailed) {
            if (!warnedDeadMutation) {
                warnedDeadMutation = true
                Log.e(TAG, "dart3d view $id: mutation on a view whose " +
                    "init failed ($terminalReason) — dropped")
            }
            return
        }
        if (detached) {
            if (!warnedDeadMutation) {
                warnedDeadMutation = true
                Log.e(TAG, "dart3d view $id: mutation after release " +
                    "($releaseReason) — dropped; the view is dead")
            }
            return
        }
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
            if (v == 1 || v == 3) {
                logCommandOnce("aa.$v",
                    "antialiasingMode $v: clamped to MSAA x2")
            } else if (v > 4) {
                logCommandOnce("aa.$v",
                    "antialiasingMode $v: clamped to MSAA x4")
            }
            // iOS pairs its MSAA with its own filtering — FXAA stays
            // on top, same as the previous boolean mapping.
            val resolved = RenderTargets.resolveAa(
                null, null, effectiveViewConfigAa())
            view.multiSampleAntiAliasingOptions = resolved.msaa
            view.antiAliasing = resolved.aa
            Log.i(TAG, "antialiasingMode=$v → MSAA" +
                " enabled=${resolved.msaa.enabled}" +
                " sampleCount=${resolved.msaa.sampleCount}" +
                " aa=${resolved.aa}")
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
        applyDeviceProfile()
        for (rec in viewRecs) {
            rec.view?.setShadowingEnabled(shadows)
            rec.view?.setShadowType(shadowType())
            resolveViewQuality(rec)
        }
        if (screenViews.isEmpty()) {
            val restored = RenderTargets.resolveAa(
                null, null, effectiveViewConfigAa())
            view.multiSampleAntiAliasingOptions = restored.msaa
            view.antiAliasing = restored.aa
        }
        Log.i(TAG, "quality=${viewQuality ?: "default"} → " +
            "shadows=$shadows aaSrc=${effectiveViewConfigAa()}" +
            " tier=$deviceTier shadowType=${shadowType()}")
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
        surgicalJournal.clear()
        transformWrites.clear()
        // Payload-backed LUT refs are document-local ids.
        lutBuffers.clear()
        subtreeVisibleStamp = null
        FsceneRealizer.realize(data, this)
    }

    private fun applyPayload(data: ByteArray) {
        if (data.size <= 8) return
        val id = D3Wire.readLocalId(data, 0)
        payloadStore[id] = data.copyOfRange(8, data.size)
        // W25: a rewritten LUT chunk invalidates its cached tables.
        invalidateLuts(backedBy = id)
        // W7: an environment equirect chunk re-runs decodeStage on the
        // live scene — the same early-out `upsertPayload` takes, and
        // the only path that doesn't depend on other resources still
        // being pending. No early return: a chunk the env shares with
        // another claimant must still reach the checks below.
        if (resources.environmentPayloadIds.values.contains(id) ||
            resources.lutPayloadIds.values.contains(id)) {
            // W7/W25: an env equirect or LUT chunk — decodeStage
            // re-runs and the stage's deferred claim unblocks.
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
        // W26: a rewritten instance matrices/color chunk re-bakes its
        // already-resolved consumers (pending ones retry below).
        FsceneRealizer.surgicalContext(this).redecodeInstancesForPayload(id)
        // W25 fix-2: only a chunk a still-deferred texture or geometry
        // awaits earns the manifest re-realize — the deferred set holds
        // resource ids, so map through the claim tables. Never-landing
        // sibling refs (or an env/LUT/skin/anim claim served above)
        // must not re-arm it: a stray re-realize re-decodes the
        // manifest's stale stage and reverts the live stage's
        // LUT/effects state — the silent W25 regression. One armed
        // drain retries every pending ref at once; a decoder whose
        // payload is still missing re-marks itself pending.
        if (lastManifest != null &&
            resources.pendingClaims(id, pendingPayloadRefs)) {
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
            transformWrites.record(id, mask)
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
        applyTopLevelCommand(json)
    }

    /**
     * One top-level command. `{"op":"batch","ops":[…]}` — a whole
     * `applyCommands` call in one mutation — unwraps here, so each
     * nested op takes exactly the path it would as its own mutation
     * (journaled, then dispatched) while all of them apply inside this
     * one drain item: nothing between two ops of a batch is ever
     * sampled or rendered.
     */
    private fun applyTopLevelCommand(json: JSONObject) {
        if (json.optString("op") != "batch") {
            journalTopLevel(json)
            applyCommandJson(json)
            return
        }
        val ops = json.optJSONArray("ops") ?: run {
            logCommandOnce("batch.malformed", "batch: missing ops")
            return
        }
        logCommandOnce("batch.first",
            "command batch: ${ops.length()} ops applied in one drain")
        for (i in 0 until ops.length()) {
            ops.optJSONObject(i)?.let { applyTopLevelCommand(it) }
        }
    }

    /**
     * One entry of the surgical replay journal — a top-level structural
     * op, or a pointer to a streamed subtree's recorded load batch.
     */
    private sealed class JournalEntry {
        class Plain(val op: JSONObject) : JournalEntry()
        class Subtree(val key: Long) : JournalEntry()
    }

    /**
     * Top-level structural commands since the last `loadScene`, in
     * arrival order. A payload-arrival re-realize rebuilds the manifest
     * scene wholesale; replaying this journal restores what commands
     * built on top of it — plain `addNode`s included (previously only
     * streamed subtrees replayed, so command-added nodes vanished on
     * the first deferred chunk; audit P1). Nested ops inside a
     * subtree batch are not journaled — the batch replays them.
     */
    private val surgicalJournal = ArrayList<JournalEntry>()
    private var replayingJournal = false

    private val transformWrites = TransformWrites()

    /** Puts the `setTransforms` state captured before a re-realize back
     * on the rebuilt nodes. Fields first, then the pushes: a body's
     * teleport composes through its parents' restored transforms. */
    private fun restoreTransformWrites(carried: List<TransformWrites.Pose>) {
        val recs = ArrayList<FsceneRealizer.NodeRec>(carried.size)
        for (pose in carried) {
            val rec = nodesById[pose.id] ?: continue
            if (pose.mask and TransformWrites.TRANSLATION != 0) {
                rec.localPos = pose.pos
            }
            if (pose.mask and TransformWrites.ROTATION != 0) {
                rec.localQuat = pose.quat
            }
            if (pose.mask and TransformWrites.SCALE != 0) {
                rec.localScale = pose.scale
            }
            recs.add(rec)
        }
        for (rec in recs) applyLocalTransform(rec)
        if (recs.isNotEmpty()) {
            Log.i(TAG, "re-realize: restored ${recs.size} written transform(s)")
        }
    }

    /**
     * Puts the simulation state captured before a re-realize back on
     * the rebuilt bodies, after the written transforms: a restored
     * write teleports its body to where the write put it, and the body
     * has moved since. Every body first, then the nodes follow their
     * bodies, parents before children: a node's local transform comes
     * from its parent's world transform, and the per-frame sync skips
     * sleeping bodies, so a child synced against a parent that has not
     * moved yet would stay wrong.
     */
    private fun restoreBodyMotion(carried: BodyCarry) {
        val restored = carried.restore(
            rebuiltKind = { key -> bodies[key]?.let(world::kindOf) },
        ) { key, motion ->
            bodies[key]?.let { world.restoreMotion(it, motion) }
        }
        val ordered = BodyCarry.parentsFirst(restored.keys) {
            nodesById[it]?.parentKey
        }
        for (key in ordered) {
            val rec = nodesById[key] ?: continue
            val body = bodies[key] ?: continue
            syncBody(rec, body)
        }
        if (restored.bodies > 0) {
            Log.i(TAG, "re-realize: restored ${restored.bodies} body " +
                "state(s), ${restored.awake} awake, fastest " +
                "${"%.2f".format(java.util.Locale.US, restored.fastest)} u/s")
        }
    }

    /**
     * The supersession key of a latest-wins journaled op: ops with the
     * same key replace each other. Null for ops outside that set.
     */
    private fun replaySlotKey(op: JSONObject): String? =
        when (op.optString("op")) {
            "upsertResource" -> "res:" + op.optString("id")
            "upsertSkin", "removeSkin" -> "skin:" + op.optString("id")
            "upsertAnimation", "removeAnimation" ->
                "animres:" + op.optString("id")
            "selectVariant" -> "variant:" + op.optString("node")
            "setMorphWeights" -> "morph:" + op.optString("node")
            "updateViews" -> "views"
            else -> null
        }

    /** The flag set of an `updateNode` op (empty for other ops). */
    private fun opFlags(json: JSONObject): Set<String> {
        val a = json.optJSONArray("flags") ?: return emptySet()
        return (0 until a.length()).mapTo(HashSet()) { a.optString(it) }
    }

    private fun opNode(e: JournalEntry): Long? =
        (e as? JournalEntry.Plain)?.op?.let { jsonKey(it) }

    /**
     * Appends a structural op, pruning what it makes obsolete so the
     * journal tracks current structure rather than full history
     * (a long-lived document's repeated updates would otherwise grow
     * memory and the main-thread replay without bound):
     *  - `updateNode` drops earlier updates of the same node whose flag
     *    set it covers — the later spec rewrites those fields;
     *  - `removeNode` drops the node's earlier updates, and when the
     *    node itself was command-added (its `addNode` is journaled) and
     *    no journaled op still names it as a parent, the add and the
     *    remove cancel out entirely.
     */
    private fun compactInto(op: String, json: JSONObject) {
        val key = jsonKey(json)
        if (key != null) {
            when (op) {
                "updateNode" -> {
                    val flags = opFlags(json)
                    if (flags.isNotEmpty()) {
                        surgicalJournal.removeAll { e ->
                            e is JournalEntry.Plain &&
                                e.op.optString("op") == "updateNode" &&
                                opNode(e) == key &&
                                flags.containsAll(opFlags(e.op))
                        }
                    }
                }
                "removeNode" -> {
                    surgicalJournal.removeAll { e ->
                        e is JournalEntry.Plain &&
                            e.op.optString("op") in NODE_STATE_OPS &&
                            opNode(e) == key
                    }
                    val add = surgicalJournal.indexOfFirst { e ->
                        e is JournalEntry.Plain &&
                            e.op.optString("op") == "addNode" &&
                            opNode(e) == key
                    }
                    val token = json.optString("node")
                    val parentOfOthers = surgicalJournal.any { e ->
                        e is JournalEntry.Plain &&
                            e.op.optString("parent") == token
                    }
                    if (add >= 0 && !parentOfOthers) {
                        surgicalJournal.removeAt(add)
                        return
                    }
                }
            }
        }
        surgicalJournal.add(JournalEntry.Plain(json))
        if (surgicalJournal.size == JOURNAL_WARN_SIZE) {
            Log.w(TAG, "surgical journal reached $JOURNAL_WARN_SIZE " +
                "entries — a deferred-payload re-realize replays them all")
        }
    }

    private fun journalTopLevel(json: JSONObject) {
        if (replayingJournal) return
        when (val op = json.optString("op")) {
            "addNode", "updateNode", "removeNode" -> compactInto(op, json)
            // install() swaps the live resource registries, skins/
            // animations, variant selections, morph weights and the view
            // list for the manifest's on a re-realize, so these replay
            // too — in arrival order, ahead of the structural ops that
            // reference them. Each keeps only its LATEST op per target
            // (a later upsert/remove of the same id, or a later
            // selection/weights for the same node, supersedes it).
            "upsertResource", "upsertSkin", "removeSkin",
            "upsertAnimation", "removeAnimation",
            "selectVariant", "setMorphWeights", "updateViews" -> {
                val slot = replaySlotKey(json)
                if (slot != null) {
                    surgicalJournal.removeAll { e ->
                        e is JournalEntry.Plain && replaySlotKey(e.op) == slot
                    }
                }
                surgicalJournal.add(JournalEntry.Plain(json))
            }
            "loadSubtree" -> {
                val key = jsonKey(json) ?: return
                val slot = surgicalJournal.indexOfFirst {
                    it is JournalEntry.Subtree && it.key == key }
                if (slot < 0) {
                    surgicalJournal.add(JournalEntry.Subtree(key))
                } else {
                    // A re-load keeps its FIRST slot (load order): a
                    // subtree grafted under one of its members after
                    // the first load must still replay after it —
                    // re-sequencing would break that (same choice as
                    // iOS, PR #15). The re-load's batch supersedes any
                    // later top-level op on its members, so prune those
                    // instead; replay then yields the re-loaded state.
                    // Members = the batch's node ids AND its resource
                    // slots (subtree_stream.dart ships each load batch
                    // with its upsertResource ops) — a later top-level
                    // override of either was superseded by the reload.
                    val members = HashSet<Long>()
                    val slots = HashSet<String>()
                    json.optJSONArray("ops")?.let { ops ->
                        for (i in 0 until ops.length()) {
                            ops.optJSONObject(i)?.let { o ->
                                jsonKey(o)?.let { members += it }
                                replaySlotKey(o)?.let { slots += it }
                            }
                        }
                    }
                    if (members.isNotEmpty() || slots.isNotEmpty()) {
                        var i = surgicalJournal.size - 1
                        while (i > slot) {
                            val e = surgicalJournal[i]
                            if (e is JournalEntry.Plain &&
                                (opNode(e) in members ||
                                    replaySlotKey(e.op) in slots)) {
                                surgicalJournal.removeAt(i)
                            }
                            i--
                        }
                    }
                }
            }
            "unloadSubtree" -> {
                val key = jsonKey(json) ?: return
                surgicalJournal.removeAll {
                    it is JournalEntry.Subtree && it.key == key }
            }
        }
    }

    /**
     * The decoded-op dispatch — also the recursion point for the W15
     * `loadSubtree`/`unloadSubtree` envelopes, whose nested `ops` run
     * through the same handlers.
     */
    private fun applyCommandJson(json: JSONObject) {
        val op = json.optString("op")
        when (op) {
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
                    // W26: component-owned mesh buffers, a doubleSided
                    // duplicate instance and the facing registration
                    // aren't owned by the entity — route removal
                    // through the same cleanup teardownComponents does
                    // (repeated subtree streaming leaked them).
                    cameraFacing.remove(id)
                    rec.procGpuMesh?.destroy(engine)
                    rec.procGpuMesh = null
                    rec.procMaterialInstance?.let { dup ->
                        for ((_, list) in resources.textureConsumers) {
                            list.removeAll { it.first === dup }
                        }
                        engine.destroyMaterialInstance(dup)
                    }
                    rec.procMaterialInstance = null
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
                    destroyLightCluster(rec)
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
                if (!replayingJournal) transformWrites.supersedeAll(doomed)
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

    /** Replays each live subtree's recorded load batch through the
     * ordinary op dispatch — called right after a payload-arrival
     * re-realize has rebuilt the manifest scene. */
    private fun replayStreamedSubtrees() {
        if (streamedSubtreeOps.isEmpty() && surgicalJournal.isEmpty()) {
            return
        }
        // A replayed batch can doom a later record's placeholder
        // (a priorRoots removeNode taking a placeholder grafted
        // into the doomed subtree): removeNode prunes the map
        // inline, so iterate snapshots — and skip records whose
        // placeholder is already dead, since their addNodes would
        // resolve a dead parent and root the resurrected members
        // at scene root.
        val dead = HashSet<Long>()
        val replayed = HashSet<Long>()
        fun replaySubtree(key: Long) {
            val ops = streamedSubtreeOps[key] ?: return
            if (!replayed.add(key)) return
            if (nodesById[key] == null) {
                dead += key
                return
            }
            for (i in 0 until ops.length()) {
                ops.optJSONObject(i)?.let { applyCommandJson(it) }
            }
            if (nodesById[key] == null) {
                Log.w(TAG, "subtree replay: placeholder $key" +
                    " missing after re-realize")
            }
        }
        var plain = 0
        replayingJournal = true
        try {
            // Journal order interleaves plain ops and subtree loads
            // exactly as they arrived, so a plain node parented under
            // a streamed member (or vice versa) resolves.
            // updateViews resolves render targets and cameras but
            // nothing depends on it, while latest-wins compaction can
            // move a render-target upsert after it — so the (single,
            // latest) views entry replays after everything else.
            var views: JSONObject? = null
            for (e in surgicalJournal.toList()) {
                when (e) {
                    is JournalEntry.Plain -> {
                        if (e.op.optString("op") == "updateViews") {
                            views = e.op
                            continue
                        }
                        applyCommandJson(e.op)
                        plain++
                    }
                    is JournalEntry.Subtree -> replaySubtree(e.key)
                }
            }
            // Records not reached through the journal (a subtree
            // loaded by a nested batch) keep the old replay path.
            for (key in streamedSubtreeOps.keys.toList()) replaySubtree(key)
            views?.let {
                applyCommandJson(it)
                plain++
            }
        } finally {
            replayingJournal = false
        }
        streamedSubtreeOps.keys.removeAll(dead)
        surgicalJournal.removeAll {
            it is JournalEntry.Subtree && it.key !in streamedSubtreeOps }
        Log.i(TAG, "re-realize replay: $plain plain op(s), " +
            "${replayed.size - dead.size} subtree(s)")
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
            // decodeStage may have run before these cameras existed
            // (initial load / re-realize) — carry the stage exposure.
            // An offscreen view renders at exposure 1, never at
            // Filament's photographic default.
            setCameraExposure(cam,
                if (rec.targetKey == null) lastEffExposure else 1.0f)
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
                v.setShadowType(shadowType())
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
            view.dynamicResolutionOptions = defaultResolution()
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
        aa: String?, renderScale: Double?, filterQuality: String,
    ) {
        stageAntiAliasing = aa
        stageRenderScale = renderScale
        stageFilterQuality = filterQuality
        for (rec in viewRecs) resolveViewQuality(rec)
    }

    /**
     * Resolves one view's quality trio ONCE at build/re-resolve —
     * AA (entry → stage → viewConfig → Filament default), renderScale
     * (screen entries only — an authored scale is fixed through
     * DynamicResolutionOptions, min==max; with none authored the low
     * device profile gets the real dynamic-res knob; rt dims are
     * authoritative), and filterQuality (decoded +
     * retained only — no Java-binding knob; non-'medium' logs once).
     */
    private fun resolveViewQuality(rec: RenderTargets.ViewRec) {
        val resolved = RenderTargets.resolveAa(
            rec.aaMode, stageAntiAliasing, effectiveViewConfigAa())
        rec.msaa = resolved.msaa
        rec.aa = resolved.aa
        rec.dsr = RenderTargets.dsrOptions(DeviceProfile.renderScale(
            rec.renderScale, stageRenderScale, lowDeviceProfile))
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
            // A destroyed MaterialInstance can't stay bound or
            // re-attach. A slot showing the old instance as its variant
            // is not a material consumer (the slot's own material is
            // another one), so nothing above rebound it: left alone, the
            // re-apply below would read the dead instance back off the
            // renderable and adopt it as the binding's default.
            val oldPtr = old.nativeObject
            for ((_, vc) in resources.variantComponents) {
                for (b in vc.bindings) {
                    if (b.applied?.nativeObject == oldPtr) {
                        val entity = nodesById[b.nodeKey]?.entity
                        if (entity != null && rm.hasComponent(entity)) {
                            rm.setMaterialInstanceAt(
                                rm.getInstance(entity), b.primitive, mi)
                        }
                        b.applied = mi
                    }
                    if (b.defaultMaterial?.nativeObject == oldPtr) {
                        b.defaultMaterial = mi
                    }
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
        // Only an op that gets this far rewrites the node. One rejected
        // above changes nothing, so the transform written before it
        // must still carry across a re-realize.
        if (!replayingJournal) transformWrites.supersede(key)
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
        if (!replayingJournal && "transform" in flags) {
            transformWrites.supersede(key)
        }
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
            .fenced { build(Manipulator.Mode.ORBIT) }
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
        // W25: a rewritten LUT chunk invalidates its cached tables.
        invalidateLuts(backedBy = key)
        // W7/W25: an environment equirect or LUT chunk re-runs
        // decodeStage on the live scene (its payload deferral unblocks
        // here). Checked first — env payloads also carry
        // encoding:'image'.
        if (resources.environmentPayloadIds.values.contains(key) ||
            resources.lutPayloadIds.values.contains(key)) {
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
        // Every claimant is serviced — one chunk may back several
        // consumers (instance matrices reused as skin IBMs, floats
        // shared by an animation), like applyPayload's binary path.
        var claimed = false
        // W26: instance transform/color chunks re-bake their nodes.
        if (FsceneRealizer.surgicalContext(this)
                .redecodeInstancesForPayload(key) > 0) {
            claimed = true
        }
        val geoKeys = resources.geometryPayloadIds
            .filter { key in it.value }.keys.toList()
        if (geoKeys.isNotEmpty()) {
            val ctx = FsceneRealizer.surgicalContext(this)
            for (geoKey in geoKeys) {
                val spec = resources.geometryResources[geoKey] ?: continue
                ctx.redecodeGeometry(geoKey, spec)
            }
            claimed = true
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
            claimed = true
        }
        val animKeys = resources.animPayloadIds
            .filter { key in it.value }.keys.toList()
        if (animKeys.isNotEmpty()) {
            for (animKey in animKeys) {
                resources.animDefs[animKey]?.let {
                    redecodeAnimation(animKey, it)
                }
            }
            claimed = true
        }
        if (claimed) return
        // W25 fix-2: every claim map was checked surgically above —
        // reaching here means no installed or deferred resource awaits
        // this chunk, so a manifest re-realize would gain nothing (and
        // a stray one reverts the live stage; see applyPayload's
        // pending-claim gate). Log the unclaimed landing instead of
        // arming.
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
        // A deferred-payload re-realize prunes joints only after the
        // journal replay, when command-added nodes exist again —
        // pruning against the bare manifest dropped joints on them.
        if (!deferJointPrune) world.retainJointsForNodes(nodes.keys)
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
            destroyLightCluster(rec)
            scene.removeEntity(rec.entity)
            engine.destroyEntity(rec.entity)
            EntityManager.get().destroy(rec.entity)
            // W26: component-owned proc/instances buffers aren't in
            // the shared gpuMeshes map — they die with their node, as
            // does a doubleSided duplicate material instance.
            rec.procGpuMesh?.destroy(engine)
            rec.procMaterialInstance?.let { engine.destroyMaterialInstance(it) }
        }
        // W26: facing-spec VertexBuffers belonged to the old scene's
        // component-owned meshes — the fresh decode re-registers.
        cameraFacing.clear()
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
        if (nodes.isNotEmpty()) ColdStart.mark("scene installed")
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
    /// exist as defs; nothing autoplays). Verb order and the knob
    /// writes live in [AnimClipState.applyOp].
    private fun applyAnim(json: JSONObject) {
        val token = json.optString("anim")
        val key = D3Wire.localIdKey(token) ?: return
        val def = resources.animations[key] ?: run {
            logCommandOnce("anim.missing.$key",
                "anim on unknown animation $key; ignoring")
            return
        }
        animClips.getOrPut(key) { AnimClipState() }.applyOp(
            endTime = def.endTime,
            play = json.optBoolean("play"),
            pause = json.optBoolean("pause"),
            stop = json.optBoolean("stop"),
            time = if (json.has("time")) json.optDouble("time") else null,
            timeScale =
                if (json.has("timeScale")) json.optDouble("timeScale")
                else null,
            weight = if (json.has("weight")) json.optDouble("weight") else null,
            loop = if (json.has("loop")) json.optBoolean("loop") else null,
        )
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

        // Effective per-clip weights — upstream normalizes by Σ every
        // registered clip's weight; a weight-0 clip contributes nothing.
        val weights = blendWeights(animClips)

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
        for ((animKey, w) in weights) {
            val clip = animClips[animKey] ?: continue
            val def = resources.animations[animKey] ?: continue
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

    private var lastDrainCount = 0
    /** Set around a deferred-payload re-realize + replay. */
    private var deferJointPrune = false
    private var lastFrameRealized = false

    private fun stepFrame(tNanos: Long) {
        val perf = perfEnabled()
        val frameStart = if (perf) System.nanoTime() else 0L
        // Particle systems apply their own authored maxFrameTime —
        // they get the unclamped interval (bounded only against a
        // resume's first frame); everything else keeps the 100 ms cap.
        val rawDt = if (lastFrameNanos == 0L) 0.0
            else ((tNanos - lastFrameNanos).coerceIn(0L, 10_000_000_000L)) / 1e9
        // lastFrameNanos == 0 is the first frame (or a re-attach
        // resume): no time has elapsed for the sim, animations, trails.
        val dt = if (lastFrameNanos == 0L) 0f
            else ((tNanos - lastFrameNanos).coerceIn(0L, 100_000_000L)) / 1e9f
        lastFrameNanos = tNanos

        if (!materialsReady) {
            // Idempotent while a prewarm runs; restarts one whose
            // thread threw (bounded retries, then a visible failure).
            MaterialPackages.prewarm(MaterialPackages.apiFor(engine.backend))
            materialsReady = tryLoadBaseMaterials()
            if (materialsFailed) return  // failTerminal stopped the loop
            if (!materialsReady) {
                // Mutations stay queued (FIFO preserved) until the
                // background compile lands; nothing to draw yet.
                return
            }
            Log.i(TAG, "dart3d view $viewId: base materials ready")
        }
        // Drain queued mutations before touching any scene/Jolt state —
        // the iOS twin drains at `updateAtTime`, the same pre-step slot.
        lastDrainCount = 0
        lastFrameRealized = false
        while (true) {
            val work = pendingWork.poll() ?: break
            work()
            lastDrainCount++
        }
        // Payload chunks in this drain may have unblocked deferred
        // resources — a single re-realize resolves every landed claim
        // at once (previously one full decode ran per chunk). The
        // retry is not a stage re-apply: preserveStage re-decodes the
        // LIVE stage so updateStage/LUT/effects state survives.
        if (realizePending) {
            realizePending = false
            val manifest = lastManifest
            if (manifest != null && pendingPayloadRefs.isNotEmpty()) {
                lastFrameRealized = true
                // Clip playback (anim ops) is live state, not document
                // state: install() clears it. Carry it across instead
                // of replaying the anim-op history, so playback time
                // continues where it was.
                val clips = HashMap(animClips)
                val written = transformWrites.capture(
                    clipDriven = { animTargets[it]?.drivesTransform == true },
                ) { id ->
                    nodesById[id]?.let {
                        arrayOf(it.localPos, it.localQuat, it.localScale)
                    }
                }
                val moving = BodyCarry()
                for ((key, body) in bodies) {
                    // A clip-driven node is left to the manifest pose
                    // for the same reason its written transform is:
                    // the sampler takes the rebuilt pose as the bind
                    // pose, and re-poses the body on its next sample.
                    if (animTargets[key]?.drivesTransform == true) continue
                    moving.capture(key, world.motionOf(body))
                }
                val awakeBefore = lastAwakeCount
                deferJointPrune = true
                try {
                    FsceneRealizer.realize(manifest, this,
                        preserveStage = true)
                    // W15: the re-realize discarded the surgically
                    // streamed subtrees with the rest of the scene —
                    // rebuild each from its recorded load batch.
                    replayStreamedSubtrees()
                    restoreTransformWrites(written)
                    restoreBodyMotion(moving)
                    // install() zeroes the settle bookkeeping for a new
                    // scene. This is the same scene: a rebuild is not
                    // a wake-up, so bodies that were awake must not
                    // announce it again.
                    lastAwakeCount = awakeBefore
                } finally {
                    deferJointPrune = false
                }
                // Joints on nodes that didn't come back die now;
                // joints on replayed nodes re-realize as their bodies
                // are re-added (JoltWorld re-pends on removeBody).
                world.retainJointsForNodes(nodesById.keys)
                for ((k, c) in clips) {
                    if (resources.animations.containsKey(k) &&
                        !animClips.containsKey(k)) {
                        animClips[k] = c
                    }
                }
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
        val physicsStart = if (perf) System.nanoTime() else 0L
        if (steps > 0) {
            world.update(stepDt * steps, steps)
            physicsAcc -= stepDt * steps
        }
        val physicsMs =
            if (perf) (System.nanoTime() - physicsStart) / 1e6f else 0f
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
        tickParticles(rawDt)
        // W16: trails record/refill and lods rebind for this frame's
        // camera — the same pre-render slot iOS's renderer delegate
        // uses (node poses and camera are final here).
        updateTrailsLods(dt)
        // W26: camera-facing lines/billboards re-expand against this
        // frame's camera pose — after every camera write, before draw.
        updateCameraFacing()
        val simEnd = if (perf) System.nanoTime() else 0L
        val didRender = render(tNanos)
        if (perf) {
            // Before the frame-history read: that JNI copy and the sort
            // behind it are the log's own cost, not the frame's.
            val submitMs = (System.nanoTime() - simEnd) / 1e6f
            val n = Dart3dJni.nativeFrameInfoHistory(
                renderer.nativeObject, perfRecords)
            if (n > 0) framePerf.timings(perfRecords, n)
            framePerf.frame(tNanos, (simEnd - frameStart) / 1e6f,
                physicsMs, submitMs, didRender, steps,
            )?.let { Log.i(TAG, it) }
        }
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
        for (key in dynamicBodyKeys) {
            val rec = nodesById[key] ?: continue
            val body = rec.body ?: continue
            if (!body.isActive) continue
            syncBody(rec, body)
        }
    }

    private fun syncBody(rec: FsceneRealizer.NodeRec, body: Body) {
        val tcm = engine.transformManager
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

    /**
     * W26: re-expands each registered camera-facing vertex buffer
     * against the live camera basis. The camera's world right/up/
     * forward are pulled into each node's local space by the inverse
     * world transform (a direction transform — translation dropped),
     * so node rotation/scale composes correctly and the emitted quads
     * face the camera after the node matrix applies.
     */
    private fun updateCameraFacing() {
        if (cameraFacing.isEmpty()) return
        val camWorld = camera.getModelMatrix(FloatArray(16))
        // Filament looks down −Z in camera space: forward = −col2.
        val fWorld = floatArrayOf(-camWorld[8], -camWorld[9], -camWorld[10])
        val rWorld = floatArrayOf(camWorld[0], camWorld[1], camWorld[2])
        val uWorld = floatArrayOf(camWorld[4], camWorld[5], camWorld[6])
        val pWorld = floatArrayOf(camWorld[12], camWorld[13], camWorld[14])
        val tm = engine.transformManager
        val rm = engine.renderableManager
        val wm = FloatArray(16)
        val inv = FloatArray(16)
        for ((_, spec) in cameraFacing) {
            val inst = tm.getInstance(spec.entity)
            if (inst == 0) continue
            tm.getWorldTransform(inst, wm)
            if (!Matrix.invertM(inv, 0, wm, 0)) {
                Matrix.setIdentityM(inv, 0)
            }
            val f = transformDir(inv, fWorld)
            val r = transformDir(inv, rWorld)
            val u = transformDir(inv, uWorld)
            // Node-local camera position — `spherical`/`axisY`
            // billboards aim at it; `screen` ignores it.
            val camPos = MeshFactory.V3(
                inv[0] * pWorld[0] + inv[4] * pWorld[1] +
                    inv[8] * pWorld[2] + inv[12],
                inv[1] * pWorld[0] + inv[5] * pWorld[1] +
                    inv[9] * pWorld[2] + inv[13],
                inv[2] * pWorld[0] + inv[6] * pWorld[1] +
                    inv[10] * pWorld[2] + inv[14])
            val md = when (spec.shape) {
                "polyline" ->
                    if (spec.dashes != null) MeshFactory.dashedPolyline(
                        spec.points, spec.width, f,
                        spec.dashes[0].toFloat(), spec.dashes[1].toFloat(),
                        spec.colors, spec.widths, spec.closed)
                    else MeshFactory.polyline(
                        spec.points, spec.width, f,
                        spec.colors, spec.widths, spec.closed)
                "lineSegments" -> MeshFactory.lineSegments(
                    spec.points, spec.width, f, spec.colors)
                "billboard" -> MeshFactory.billboardQuad(
                    spec.sizeX, spec.sizeY, spec.rotation, spec.tint,
                    r, u, facing = spec.facing, camPos = camPos)
                "billboardInstances" -> MeshFactory.bakeBillboardInstances(
                    spec.points, spec.sizeX, spec.sizeY, spec.rotation,
                    spec.colors, r, u, facing = spec.facing,
                    camPos = camPos)
                else -> continue
            }
            md.vertices.rewind()
            spec.vertexBuffer.setBufferAt(engine, 0, md.vertices)
            // The re-faced vertices moved — Filament culls (frustum and
            // shadow) against the renderable's AABB, which still held
            // the decode-time orientation (a billboard baked in XY had
            // zero Z extent seen side-on and could vanish).
            val ri = rm.getInstance(spec.entity)
            if (ri != 0) {
                val b = md.bounds
                rm.setAxisAlignedBoundingBox(ri,
                    Box(b[0], b[1], b[2], b[3], b[4], b[5]))
            }
        }
    }

    /** world direction → node-local direction (column-major inv, w=0). */
    private fun transformDir(inv: FloatArray, d: FloatArray): MeshFactory.V3 =
        MeshFactory.V3(
            inv[0] * d[0] + inv[4] * d[1] + inv[8] * d[2],
            inv[1] * d[0] + inv[5] * d[1] + inv[9] * d[2],
            inv[2] * d[0] + inv[6] * d[1] + inv[10] * d[2])

    /** False when no frame was drawn: no surface, or Filament's frame
     *  pacing asked to skip this vsync. */
    private fun render(tNanos: Long): Boolean {
        // No surface, no frame: UiHelper clears readiness in
        // onDetachedFromSurface, before Android destroys the window.
        if (!uiHelper.isReadyToRender) return false
        val sc = swapChain ?: return false
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
            if (!firstSceneFrameDone && nodesById.isNotEmpty()) {
                firstSceneFrameDone = true
                ColdStart.mark("first frame submitted")
                if (perfEnabled()) {
                    engine.flushAndWait()
                    ColdStart.mark("first frame rendered")
                }
            }
            tickStats(tNanos)
            return true
        }
        return false
    }

    private var firstSceneFrameDone = false

    private val framePerf = FramePerf()
    private val perfRecords = LongArray(FramePerf.HISTORY * 4)
    private var perfOn = false
    private var perfPoll = 0

    /** The `dart3d.perf` log tag, re-read about once a second. */
    private fun perfEnabled(): Boolean {
        if (perfPoll++ % 64 != 0) return perfOn
        val on = Log.isLoggable(FramePerf.TAG, Log.DEBUG)
        if (on && !perfOn) {
            framePerf.reset()
            Log.i(TAG, "perf view: ${describeViewSettings()}")
        }
        perfOn = on
        return on
    }

    private fun describeViewSettings(): String {
        val vp = view.viewport
        val msaa = view.multiSampleAntiAliasingOptions
        val bloom = view.bloomOptions
        val dsr = view.dynamicResolutionOptions
        return "backend=${engine.backend} viewport=${vp.width}x${vp.height}" +
            " msaa=${if (msaa.enabled) msaa.sampleCount else 0}" +
            " aa=${view.antiAliasing}" +
            " post=${view.isPostProcessingEnabled}" +
            " hdr=${view.renderQuality.hdrColorBuffer}" +
            " bloom=${bloom.enabled}(levels=${bloom.levels}" +
            " res=${bloom.resolution} q=${bloom.quality})" +
            " ssao=${view.ambientOcclusionOptions.enabled}" +
            " taa=${view.temporalAntiAliasingOptions.enabled}" +
            " ssr=${view.screenSpaceReflectionsOptions.enabled}" +
            " dsr=${dsr.enabled}(${dsr.minScale}..${dsr.maxScale})" +
            " dither=${view.dithering}" +
            " quality=${viewQuality ?: "default"}" +
            " physics=${Math.round(1f / world.fixedTimestep)}Hz" +
            "x${world.maxSubsteps}" +
            " entities=${nodesById.size} bodies=${bodies.size}"
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
        private const val SLOW_FRAME_MS = 250L
        private const val JOURNAL_WARN_SIZE = 2048
        /** Journaled ops that target one node's live state. */
        private val NODE_STATE_OPS =
            setOf("updateNode", "selectVariant", "setMorphWeights")
        private const val MAX_LUT_CACHE_ENTRIES = 4
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
