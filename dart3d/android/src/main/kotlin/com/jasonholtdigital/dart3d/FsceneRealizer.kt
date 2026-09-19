package com.jasonholtdigital.dart3d

import android.opengl.Matrix
import android.util.Log
import com.github.stephengold.joltjni.Body
import com.github.stephengold.joltjni.BodyCreationSettings
import com.github.stephengold.joltjni.BoxShape
import com.github.stephengold.joltjni.CapsuleShape
import com.github.stephengold.joltjni.ConvexHullShapeSettings
import com.github.stephengold.joltjni.ConvexShape
import com.github.stephengold.joltjni.CylinderShape
import com.github.stephengold.joltjni.IndexedTriangle
import com.github.stephengold.joltjni.IndexedTriangleList
import com.github.stephengold.joltjni.MeshShapeSettings
import com.github.stephengold.joltjni.Quat
import com.github.stephengold.joltjni.RVec3
import com.github.stephengold.joltjni.RotatedTranslatedShape
import com.github.stephengold.joltjni.RotatedTranslatedShapeSettings
import com.github.stephengold.joltjni.SphereShape
import com.github.stephengold.joltjni.StaticCompoundShapeSettings
import com.github.stephengold.joltjni.Vec3
import com.github.stephengold.joltjni.VertexList
import com.github.stephengold.joltjni.enumerate.EAllowedDofs
import com.github.stephengold.joltjni.enumerate.EMotionQuality
import com.github.stephengold.joltjni.enumerate.EMotionType
import com.github.stephengold.joltjni.enumerate.EOverrideMassProperties
import com.github.stephengold.joltjni.readonly.ConstShape
import com.google.android.filament.Box
import com.google.android.filament.EntityManager
import com.google.android.filament.IndexBuffer
import com.google.android.filament.IndirectLight
import com.google.android.filament.LightManager
import com.google.android.filament.MaterialInstance
import com.google.android.filament.MorphTargetBuffer
import com.google.android.filament.RenderableManager
import com.google.android.filament.SkinningBuffer
import com.google.android.filament.Skybox
import com.google.android.filament.Texture
import com.google.android.filament.TextureSampler
import com.google.android.filament.VertexBuffer
import org.json.JSONArray
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

private const val TAG = "dart3d"

// W21 light-unit contract. The wire `intensity` is SceneKit-scale — a
// unitless multiplier — while Filament consumes photometric units, so
// decode converts rather than passes through:
//
//  * DIRECTIONAL → lux. DIRECTIONAL_LUX_PER_UNIT keeps the value the
//    retired bare `×10` heuristic was tuned to: a SceneKit intensity
//    of 1.0 lands at 10 lx and the ~1400 "studio key" lands at
//    14 000 lx — indoor floodlight range, short of Filament's ~110 000
//    lx full-sun reference but matching the demos' authored look.
//  * POINT / FOCUSED_SPOT → candela. The wire value is total luminous
//    flux in lumens; candela is lumen/sr, and an isotropic emitter
//    spreads its flux over the 4π sr sphere: candela = lumens / 4π.
//    (A spot concentrates the same flux inside its cone — Filament's
//    candela is axial luminous intensity and spotLightCone carries the
//    shape, so the /4π applies unchanged.)
//  * environmentIntensity → lux at ENVIRONMENT_LUX_PER_UNIT, Filament's
//    own IndirectLight/Skybox default baseline (30 000 lx) that the
//    unitless wire value scales.
private const val DIRECTIONAL_LUX_PER_UNIT = 10.0
private const val ENVIRONMENT_LUX_PER_UNIT = 30_000.0
private const val FOUR_PI_STERADIANS = 4.0 * kotlin.math.PI

/** Wire `alphaMode` vocabulary (lowercase in the spec). */
private val ALPHA_MODES = setOf("opaque", "mask", "blend")

/** GPU-side mesh: engine objects plus the CPU data physics hulls read. */
class GpuMesh(
    val vertexBuffer: VertexBuffer,
    val indexBuffer: IndexBuffer,
    val vertexCount: Int,
    val indexCount: Int,
    val bounds: FloatArray,         // cx,cy,cz, hx,hy,hz
    val positions: FloatArray,      // pos triples for hull colliders
    val indices: IntArray,          // tri indices for mesh colliders
    val primitiveType: RenderableManager.PrimitiveType,
    // W11: true when the vertex buffer carries BONE_INDICES +
    // BONE_WEIGHTS streams (the skinned repack).
    val hasSkinning: Boolean = false,
    // W11 morph targets — float4 delta positions (+ packed absolute
    // tangent quats) uploaded at build; `morphDefaults` is the mesh's
    // authored `weights` array padded to `morphTargetCount` by the
    // renderable attach.
    val morphTargetBuffer: MorphTargetBuffer? = null,
    val morphDefaults: FloatArray = FloatArray(0),
    val morphTargetCount: Int = 0,
) {
    fun destroy(engine: com.google.android.filament.Engine) {
        engine.destroyVertexBuffer(vertexBuffer)
        engine.destroyIndexBuffer(indexBuffer)
        morphTargetBuffer?.let { engine.destroyMorphTargetBuffer(it) }
    }
}

/**
 * Realizes a `.fscene` manifest (canonical JSON) into Filament entities
 * and Jolt bodies. Mirrors FsceneRealizer.swift: same component
 * vocabulary, same deferred physics pass, same tagged-value decoding.
 * Payload-backed resources stay pending until their bytes arrive.
 */
object FsceneRealizer {

    // One-shot log dedup for spec-deferred features (payload-backed
    // shapes, heightField, named backends, bad combine rules).
    private val loggedOnce = mutableSetOf<String>()
    private val warnedOnce = mutableSetOf<String>()

    private fun logOnce(tag: String, msg: String) {
        if (loggedOnce.add(tag)) Log.i(TAG, msg)
    }

    private fun warnOnce(tag: String, msg: String) {
        if (warnedOnce.add(tag)) Log.w(TAG, msg)
    }

    fun realize(manifest: ByteArray, host: Dart3dView) {
        val realizeStart = System.nanoTime()
        val json = try {
            JSONObject(String(manifest, Charsets.UTF_8))
        } catch (e: Exception) {
            Log.w(TAG, "loadScene: manifest is not a JSON object"); return
        }
        val ctx = Context(host, json.optInt("fscene", 5))
        ctx.decodePayloads(json.optJSONObject("payloads"))
        ctx.decodeResources(json.optJSONObject("resources"))
        // W11 before the node pass — decodeMesh attaches skinning at
        // renderable-build time, so the decoded skin records must
        // exist first (iOS attaches late via resolveSkinAttachments;
        // Filament's skinning buffer binds at Builder.build).
        ctx.decodeSkins(json.optJSONObject("skins"))
        ctx.decodeAnimations(json.optJSONObject("animations"))
        // W12: component-joint handles get re-minted per document —
        // drop the previous doc's registrations before node decode
        // re-registers (a same-session re-realize keeps command joints
        // whose bodies come back; component joints always re-decode).
        host.beginComponentJointRegistration()
        ctx.decodeNodes(json.optJSONObject("nodes"))
        ctx.attachToScene()
        ctx.decodePhysicsDeferred()
        ctx.applyVariantComponents()
        ctx.decodeStage(json.optJSONObject("stage"))
        // W14: after decodeStage so the stage-level quality defaults
        // are in place when views resolve theirs; rt refs resolve
        // because decodeResources already built them.
        ctx.decodeViews(json.optJSONArray("views"))
        ctx.install()
        Log.i(TAG, "realize: ${(System.nanoTime() - realizeStart) /
            1_000_000}ms")
    }

    // Upstream NodeChange field names updateNode applies.
    private val NODE_UPDATE_FLAGS = setOf(
        "transform", "name", "layers", "visible",
        "reparented", "components", "skin")

    /**
     * A Context whose registries ARE the host's live ones — decode
     * writes land directly in the installed scene state. The W5
     * command ops (addNode, updateNode, geometry upserts) run through
     * this; the manifest path builds a fresh Context and swaps at
     * install.
     */
    fun surgicalContext(host: Dart3dView): Context {
        val res = host.resources
        return Context(
            host = host,
            fsceneVersion = host.fsceneVersion,
            nodes = host.nodesById,
            geometries = res.geometries,
            gpuMeshes = host.gpuMeshes,
            materials = host.materialInstances,
            payloadSpecs = res.payloadSpecs,
            pendingPayloadRefs = host.pendingPayloadRefs,
            textures = res.textures,
            textureSamplers = res.textureSamplers,
            textureConsumers = res.textureConsumers,
            materialConsumers = res.materialConsumers,
            textureResources = res.textureResources,
            materialResources = res.materialResources,
            texturePayloadIds = res.texturePayloadIds,
            geometryResources = res.geometryResources,
            geometryConsumers = res.geometryConsumers,
            geometryPayloadIds = res.geometryPayloadIds,
            environments = res.environments,
            environmentPayloadIds = res.environmentPayloadIds,
            bodies = host.bodies,
            dynamicBodyKeys = host.dynamicBodyKeys,
            pendingParents = host.pendingParents,
            skins = res.skins,
            animations = res.animations,
            skinPayloadIds = res.skinPayloadIds,
            animPayloadIds = res.animPayloadIds,
            skinDefs = res.skinDefs,
            animDefs = res.animDefs,
            nodeSkinKeys = res.nodeSkinKeys,
            nodeSkinning = host.nodeSkinning,
            variantComponents = res.variantComponents,
            disabledComponents = res.disabledComponents,
            renderTargets = host.renderTargets,
            nodeCameraProps = host.nodeCameraProps,
        )
    }

    /**
     * A decoded `skins` entry (W11): joint node keys in authored
     * order, the per-joint inverse-bind matrices (column-major, already
     * S·M·S-converted to engine space; identity when the
     * `inverseBindMatrices` payload is absent — upstream's
     * null-tolerant rule), the optional skeleton root key, and
     * `awaitingIBM` while the IBM payload is still in flight (the
     * chunk's arrival re-decodes the skin surgically). A joint that
     * hasn't landed substitutes identity at bone-matrix upload —
     * upstream renders a missing joint as identity.
     */
    class DecodedSkin(
        val jointKeys: List<Long>,
        val ibms: List<FloatArray>,
        val skeletonKey: Long?,
        val awaitingIBM: Boolean,
    )

    /**
     * One animation channel's decoded timeline + values, converted to
     * engine space at decode: translation negates z, rotation takes the
     * pseudovector map (−x,−y,z,w), scale and weights pass through
     * (mirrors iOS `DecodedChannel`). `vec3` packs xyz triples,
     * `quat` packs xyzw; `weights` is the flattened
     * `targetCount`-per-key layout with trailing incomplete floats
     * dropped (upstream's rule).
     */
    class DecodedChannel(
        val target: Long,
        val targetName: String?,
        val kind: Kind,
        val times: DoubleArray,
        val vec3: FloatArray = FloatArray(0),
        val quat: FloatArray = FloatArray(0),
        val weights: FloatArray = FloatArray(0),
        val targetCount: Int = 0,
    ) {
        enum class Kind { TRANSLATION, ROTATION, SCALE, WEIGHTS }
    }

    /** W12: one decoded `materialsVariants` binding — target node +
     *  primitive index, the declared default material ref, and the
     *  variant-index → material-ref map. [applied]/[defaultMaterial]
     *  record the last write and the default in force (the rebase rule
     *  can adopt a foreign slot content as the new default). */
    class VariantBinding(
        val nodeKey: Long,
        val primitive: Int,
        val defaultMaterialKey: Long?,
        val materialsByVariant: Map<Int, Long>,
        var applied: MaterialInstance? = null,
        var defaultMaterial: MaterialInstance? = null,
        var resolved: Boolean = false,
    )

    /** W12: a decoded `materialsVariants` component — variant names,
     *  the selected name, and its (possibly pending) bindings. */
    class VariantComponent(
        val nodeKey: Long,
        val compIndex: Int,
        val variants: List<String>,
        var selected: String?,
        val bindings: MutableList<VariantBinding>,
    )

    /**
     * A decoded `animations` entry (W11): channels plus `endTime`
     * (max channel last-key — upstream's `Animation.endTime`). Clips
     * don't exist until an `anim` op asks — no autoplay.
     */
    class DecodedAnimation(
        val name: String,
        val channels: List<DecodedChannel>,
        val endTime: Double,
    )

    class NodeRec(
        val entity: Int,
        var parentKey: Long?,
        var localPos: FloatArray,
        var localQuat: FloatArray,
        var localScale: FloatArray,
        var body: Body? = null,
        var isCamera: Boolean = false,
        var hidden: Boolean = false,
        var name: String? = null,
        // Upstream 32-bit render-layer mask; realized onto the
        // renderable's 8-bit Filament layerMask.
        var layers: Int = 1,
        // Geometry the node's mesh component resolved to — colliders
        // read these for convexHull / boundingBox / triMesh shapes.
        var lastGeoPositions: FloatArray? = null,
        var lastGeoIndices: IntArray? = null,
        var lastGeoBounds: FloatArray? = null,
        // Retained mesh-component props — a geometry rebind first-builds
        // the renderable from these when the original decode hit a
        // pending geometry.
        var meshProps: JSONObject? = null,
        // Ordered geometry keys of the mesh's primitives (index =
        // renderable primitive slot). Null until the mesh builds; a
        // geometry upsert reads it for slot-aware setGeometryAt.
        var meshPrimGeoKeys: List<Long>? = null,
        // W12 rectAreaLight: the point-cluster approximation's extra
        // light entities — destroyed with the node (teardownComponents
        // / node removal).
        var lightEntities: MutableList<Int> = mutableListOf(),
        // W11: the node's live morph weights — non-null only while a
        // renderable with a MorphTargetBuffer is attached. Written by
        // the `setMorphWeights` op and the animation sampler's
        // weights channels; pushed through
        // RenderableManager.setMorphWeights.
        var morphWeights: FloatArray? = null,
        // W15: the node's raw `instance` spec member — non-null only
        // on lazy prefab placeholders. Recorded, never decoded here:
        // loadSubtree's nested updateNode re-spec clears it and
        // unloadSubtree's restore re-tags it; the Dart layer composes
        // the subtree and streams it as ordinary ops.
        var instanceSpec: JSONObject? = null,
        // W16: the node's `trail` / `lod` runtime state — created at
        // decode, destroyed in teardownComponents/node removal/the
        // install sweep. Riding the rec means surgical contexts see
        // the same object the host does (no extra registry).
        var trail: TrailState? = null,
        var lod: LodState? = null,
    )

    /**
     * W16: one live `trail` component — the decoded spec plus the
     * recorded path and the ribbon renderable's engine objects. The
     * entity is UNPARENTED with identity transform: the path is
     * recorded in world space and the verts write world-space
     * directly, so the ribbon hangs where the node has been
     * (upstream's world-anchored semantics without a per-frame
     * rebase).
     */
    class TrailState(
        val entity: Int,
        val vertexBuffer: VertexBuffer,
        val indexBuffer: IndexBuffer,
        val maxPoints: Int,
        var width: Float,
        var lifetime: Float,
        var minVertexDistance: Float,
        var emitting: Boolean,
        /** `widthOverTrail` (t,v) pairs sorted by t; null → 1−t. */
        val widthKeys: FloatArray?,
        /** `colorOverTrail` (t,r,g,b,a) tuples sorted by t; null →
         *  upstream's white alpha-fade. */
        val colorStops: FloatArray?,
        /** Head-first world positions, capacity maxPoints (xyz
         *  stride). `count` entries are live. */
        val points: FloatArray,
        /** Parallel birth clock of [points] (accumulated seconds). */
        val born: DoubleArray,
        /** Staging buffer the per-frame pass refills — 2 verts per
         *  anchor × (pos f3 + color f4) × 4B = 28B/vert. */
        val staging: java.nio.ByteBuffer,
        var count: Int = 0,
        var time: Double = 0.0,
        var inScene: Boolean = false,
    )

    /** W16: one level of a decoded `lod` spec. */
    class LodLevelSpec(
        val geoKey: Long,
        val matKey: Long,
        val screenSize: Double,
    )

    /**
     * W16: a decoded `lod` component — upstream `LodComponent` (which
     * EXTENDS MeshComponent upstream: the lod owns the node's draw
     * slot, so the realized renderable swaps geometry+material per
     * selection rather than spawning level children). `bound` is the
     * level currently bound to the node's renderable — -1 while
     * culled or unbuilt; `ownsRenderable` distinguishes the lod's
     * renderable from a foreign one (a `mesh` decoded earlier) so a
     * takeover rebuilds instead of slot-swapping; `suspended` marks
     * a later `mesh` decode taking the slot back (last-write-wins —
     * iOS's `node.geometry` overwrite order). `hysteresis`/
     * `blendRange` decode for wire parity but are documented
     * no-ops — dart3d hard-switches.
     */
    class LodState(
        val levels: List<LodLevelSpec>,
        var lodBias: Double,
        var hysteresis: Double,
        var blendRange: Double,
        var bound: Int = -1,
        var boundMatKey: Long? = null,
        var ownsRenderable: Boolean = false,
        var suspended: Boolean = false,
    )

    /**
     * Decode scope for one realize pass — or, when seeded with the
     * host's live maps via [surgicalContext], the vehicle for the W5
     * surgical ops (addNode/updateNode/geometry upserts) whose decode
     * writes land directly in the installed registries.
     */
    class Context(
        val host: Dart3dView,
        private val fsceneVersion: Int,
        val nodes: MutableMap<Long, NodeRec> = LinkedHashMap(),
        val geometries: MutableMap<Long, MeshFactory.MeshData> = HashMap(),
        val gpuMeshes: MutableMap<Long, GpuMesh> = HashMap(),
        val materials: MutableMap<Long, MaterialInstance> = HashMap(),
        val payloadSpecs: MutableMap<Long, PayloadMeta> = HashMap(),
        val pendingPayloadRefs: MutableSet<Long> = HashSet(),
        // W4: texture uploads + the binding maps the host's surgical
        // upsert ops replay. textureConsumers: texKey → (instance, slot
        // param name); materialConsumers: matKey → (renderable entity,
        // primitive slot) pairs — a multi-primitive mesh binds its
        // material at its own slot, not slot 0.
        // W14: textureSamplers carries a per-resource sampler (a
        // renderTexture's own filter/wrap) consulted at bind + rebind;
        // absent → the shared host.textureSampler.
        val textures: MutableMap<Long, Texture> = HashMap(),
        val textureSamplers: MutableMap<Long, TextureSampler> = HashMap(),
        val textureConsumers: MutableMap<Long,
            MutableList<Pair<MaterialInstance, String>>> = HashMap(),
        val materialConsumers: MutableMap<Long,
            MutableList<Pair<Int, Int>>> = HashMap(),
        val textureResources: MutableMap<Long, JSONObject> = HashMap(),
        val materialResources: MutableMap<Long, JSONObject> = HashMap(),
        val texturePayloadIds: MutableMap<Long, Long> = HashMap(),
        // W5: geometry decode state. geometryConsumers: geoKey → node
        // keys; geometryPayloadIds: geoKey → the payload keys it
        // decodes from.
        val geometryResources: MutableMap<Long, JSONObject> = HashMap(),
        val geometryConsumers: MutableMap<Long,
            MutableSet<Long>> = HashMap(),
        val geometryPayloadIds: MutableMap<Long,
            MutableSet<Long>> = HashMap(),
        // W7: `kind:"environment"` resource defs (the stage consumes
        // them — they hold no realized object of their own) and the
        // envKey → payloadKey claims an `upsertPayload` chunk
        // satisfies by re-running decodeStage.
        val environments: MutableMap<Long, JSONObject> = HashMap(),
        val environmentPayloadIds: MutableMap<Long, Long> = HashMap(),
        val bodies: MutableMap<Long, Body> = HashMap(),
        val dynamicBodyKeys: MutableSet<Long> = HashSet(),
        // Children whose addNode predated their parent's — childKey →
        // parentKey; resolved as parents land (ops are
        // order-independent within a batch).
        val pendingParents: MutableMap<Long, Long> = HashMap(),
        // W11: decoded skin + animation defs, their payload claims
        // (skinKey → IBM payload key; animKey → the channel payload
        // keys it reads), the raw defs a surgical re-decode replays,
        // and the nodeKey → skinKey binding declared by a node's
        // `skin` member. The `skin` binding is a node MEMBER, not a
        // component — it survives `components` rebuilds like iOS's
        // `nodeSkinKeys`.
        val skins: MutableMap<Long, DecodedSkin> = HashMap(),
        val animations: MutableMap<Long, DecodedAnimation> = HashMap(),
        val skinPayloadIds: MutableMap<Long, Long> = HashMap(),
        val animPayloadIds: MutableMap<Long, MutableSet<Long>> = HashMap(),
        val skinDefs: MutableMap<Long, JSONObject> = HashMap(),
        val animDefs: MutableMap<Long, JSONObject> = HashMap(),
        val nodeSkinKeys: MutableMap<Long, Long> = HashMap(),
        // W12: decoded materialsVariants components (declaring nodeKey
        // → spec) and the enabled:false component marks. Surgical
        // contexts alias the host's installed maps.
        val variantComponents: MutableMap<Long, VariantComponent> =
            HashMap(),
        val disabledComponents: MutableMap<Long, MutableSet<Int>> =
            HashMap(),
        // The skinning buffers `decodeMesh` builds — a manifest
        // Context owns a fresh map swapped onto the host at install;
        // a surgical Context aliases the host's live one. Keeps the
        // install teardown from destroying buffers decoded in the
        // same pass.
        val nodeSkinning: MutableMap<Long, Dart3dView.NodeSkin> = HashMap(),
        // W14: `rt:` key → live RenderTarget rec (built eagerly in
        // decodeResources pass 1 so materials bind the color texture);
        // every camera node's decoded props (per-view projections);
        // and the decoded `views` list install hands to the host.
        val renderTargets: MutableMap<Long, RenderTargets.RenderTargetRec> =
            HashMap(),
        val nodeCameraProps: MutableMap<Long, RenderTargets.CameraSpec> =
            HashMap(),
        val views: MutableList<RenderTargets.ViewRec> = ArrayList(),
    ) {
        data class PayloadMeta(
            val encoding: String,
            val layout: String?,
            val format: String?,
            val width: Int? = null,   // image payloads (W4): pixel width
            val height: Int? = null,  // image payloads (W4): pixel height
            val length: Int? = null,  // declared byte length (rgba8 check)
        )

        /**
         * The resource dictionaries handed to the host at install so the
         * `upsertResource`/`upsertPayload` ops can re-decode and rebind
         * without a scene re-realize.
         */
        class InstalledResources(
            val textures: MutableMap<Long, Texture> = HashMap(),
            val textureSamplers: MutableMap<Long, TextureSampler> =
                HashMap(),
            val textureConsumers: MutableMap<Long,
                MutableList<Pair<MaterialInstance, String>>> = HashMap(),
            val materialConsumers: MutableMap<Long,
                MutableList<Pair<Int, Int>>> = HashMap(),
            val textureResources: MutableMap<Long, JSONObject> = HashMap(),
            val materialResources: MutableMap<Long, JSONObject> = HashMap(),
            val texturePayloadIds: MutableMap<Long, Long> = HashMap(),
            val geometries: MutableMap<Long,
                MeshFactory.MeshData> = HashMap(),
            val geometryResources: MutableMap<Long, JSONObject> = HashMap(),
            val geometryConsumers: MutableMap<Long,
                MutableSet<Long>> = HashMap(),
            val geometryPayloadIds: MutableMap<Long,
                MutableSet<Long>> = HashMap(),
            val environments: MutableMap<Long, JSONObject> = HashMap(),
            val environmentPayloadIds: MutableMap<Long, Long> = HashMap(),
            val payloadSpecs: MutableMap<Long, PayloadMeta> = HashMap(),
            val skins: MutableMap<Long, DecodedSkin> = HashMap(),
            val animations: MutableMap<Long, DecodedAnimation> = HashMap(),
            val skinPayloadIds: MutableMap<Long, Long> = HashMap(),
            val animPayloadIds: MutableMap<Long,
                MutableSet<Long>> = HashMap(),
            val skinDefs: MutableMap<Long, JSONObject> = HashMap(),
            val animDefs: MutableMap<Long, JSONObject> = HashMap(),
            val nodeSkinKeys: MutableMap<Long, Long> = HashMap(),
            val variantComponents: MutableMap<Long, VariantComponent> =
                HashMap(),
            val disabledComponents:
                MutableMap<Long, MutableSet<Int>> = HashMap(),
        )

        var firstCameraKey: Long? = null
        var cameraProps: JSONObject? = null
        val nodeWorld = HashMap<Long, FloatArray>()

        /// Set by `decodeStage` when the env's equirect payload hasn't
        /// arrived — the stage application defers the env + the
        /// `environment`-sourced skybox until the chunk lands (mirrors
        /// iOS's stageEnvDeferred).
        var stageEnvDeferred = false

        private data class PhysicsItem(
            val key: Long, val rec: NodeRec,
            val type: String, val props: JSONObject,
        )
        private val physicsDeferred = ArrayList<PhysicsItem>()

        /** W12: a declarative joint component awaiting the physics
         *  pass — [index] is its position in the node's component list
         *  so a re-decode replaces exactly its own registration. */
        private data class JointItem(
            val key: Long, val index: Int,
            val type: String, val props: JSONObject,
        )
        private val jointComponentsDeferred = ArrayList<JointItem>()

        private val em get() = EntityManager.get()
        private val tcm get() = host.engine.transformManager

        // MARK: Resources

        fun decodePayloads(map: JSONObject?) {
            if (map == null) return
            for (token in map.keys()) {
                val key = D3Wire.localIdKey(token) ?: continue
                val spec = map.optJSONObject(token) ?: continue
                payloadSpecs[key] = PayloadMeta(
                    encoding = spec.optString("encoding"),
                    layout = spec.optString("layout").takeIf { it.isNotEmpty() },
                    format = spec.optString("format").takeIf { it.isNotEmpty() },
                    width = (spec.opt("width") as? Number)?.toInt(),
                    height = (spec.opt("height") as? Number)?.toInt(),
                    length = (spec.opt("length") as? Number)?.toInt(),
                )
            }
        }

        fun decodeResources(map: JSONObject?) {
            if (map == null) return
            // Pass 1: textures + environments + render textures, so a
            // material decoding in pass 2 sees its `*Texture` refs —
            // including {'rref':'rt:…'} color textures — already
            // uploaded regardless of manifest ordering.
            for (token in map.keys()) {
                val key = D3Wire.localIdKey(token) ?: continue
                val r = map.optJSONObject(token) ?: continue
                when (r.optString("kind")) {
                    "texture" -> decodeTexture(key, r)
                    "environment" -> environments[key] = r
                    "renderTexture" -> decodeRenderTexture(key, r)
                }
            }
            for (token in map.keys()) {
                val key = D3Wire.localIdKey(token) ?: continue
                val r = map.optJSONObject(token) ?: continue
                when (r.optString("kind")) {
                    "geometry" -> decodeGeometry(key, r)
                    "material" -> decodeMaterial(key, r)
                    "texture", "environment", "renderTexture" -> {} // pass 1
                    else -> Log.i(TAG, "unknown resource kind '${r.optString("kind")}'")
                }
            }
        }

        /**
         * W14: a `renderTexture` resource → a live RenderTarget rec —
         * the textures + RenderTarget are built eagerly here (pass 1)
         * so pass-2 material decode can bind `{'rref':'rt:…'}`. The
         * color texture also keys into `textures` (rec-owned — the
         * host's texture sweeps skip rt keys) and its spec sampler into
         * `textureSamplers`.
         */
        private fun decodeRenderTexture(key: Long, r: JSONObject) {
            val spec = RenderTargets.decodeSpec(key, r) ?: return
            val rec = RenderTargets.build(host.engine, spec)
            renderTargets[key] = rec
            textures[key] = rec.colorTex
            textureSamplers[key] = rec.sampler
        }

        /**
         * Stored bytes must match the manifest's declared `length` —
         * a mismatch means the chunk under [payloadKey] isn't this
         * document's (a stale key from a previous doc, or a partial
         * write), so the consumer defers until the real chunk lands
         * rather than decoding garbage. Undeclared lengths pass.
         */
        private fun payloadLengthMatches(
            key: Long, payloadKey: Long, meta: PayloadMeta, bytes: ByteArray,
        ): Boolean {
            val declared = meta.length ?: return true
            if (declared == bytes.size) return true
            warnOnce("geometry:$key:payloadLen.$payloadKey",
                "geometry $key: payload $payloadKey is ${bytes.size} B, " +
                    "manifest declares $declared B — awaiting real chunk")
            return false
        }

        private fun decodeGeometry(key: Long, r: JSONObject) {
            geometryResources[key] = r
            val proc = r.optJSONObject("procedural")
            if (proc != null) {
                val shape = proc.optString("shape")
                val md = procedural(shape, proc)
                if (md != null) geometries[key] = md
                geometryPayloadIds.remove(key)
                return
            }

            val vertexToken = r.optString("vertices")
            val vertexKey = D3Wire.localIdKey(vertexToken)
            val indexToken = r.optString("indices").takeIf { it.isNotEmpty() }
            val indexKey = indexToken?.let { D3Wire.localIdKey(it) }
            // Record the payload linkage even while a chunk is missing —
            // upsertPayload finds claiming geometries through this map.
            val payloadIds = LinkedHashSet<Long>()
            vertexKey?.let(payloadIds::add)
            indexKey?.let(payloadIds::add)
            if (payloadIds.isEmpty()) geometryPayloadIds.remove(key)
            else geometryPayloadIds[key] = payloadIds
            if (vertexToken.isEmpty() || vertexKey == null) {
                warnOnce("geometry:$key:vertices",
                    "geometry $key: missing or invalid vertices payload token")
                return
            }
            val vertexMeta = payloadSpecs[vertexKey]
            if (vertexMeta == null) {
                warnOnce("geometry:$key:vertexSpec",
                    "geometry $key: payload '$vertexToken' has no manifest spec")
                return
            }
            if (vertexMeta.encoding != "vertexBuffer") {
                warnOnce("geometry:$key:vertexEncoding",
                    "geometry $key: vertices payload encoding '${vertexMeta.encoding}' is not vertexBuffer")
                return
            }
            val vertexBytes = host.payloadStore[vertexKey]
            if (vertexBytes == null ||
                !payloadLengthMatches(key, vertexKey, vertexMeta, vertexBytes)) {
                pendingPayloadRefs.add(key)
                Log.i(TAG, "geometry $key: awaiting payload")
                return
            }

            var indexMeta: PayloadMeta? = null
            var indexBytes: ByteArray? = null
            if (indexToken != null) {
                if (indexKey == null) {
                    warnOnce("geometry:$key:indexToken",
                        "geometry $key: invalid indices payload token '$indexToken'")
                    return
                }
                indexMeta = payloadSpecs[indexKey]
                if (indexMeta == null) {
                    warnOnce("geometry:$key:indexSpec",
                        "geometry $key: payload '$indexToken' has no manifest spec")
                    return
                }
                if (indexMeta.encoding != "indexBuffer") {
                    warnOnce("geometry:$key:indexEncoding",
                        "geometry $key: indices payload encoding '${indexMeta.encoding}' is not indexBuffer")
                    return
                }
                indexBytes = host.payloadStore[indexKey]
                if (indexBytes == null ||
                    !payloadLengthMatches(key, indexKey, indexMeta, indexBytes)) {
                    pendingPayloadRefs.add(key)
                    Log.i(TAG, "geometry $key: awaiting payload")
                    return
                }
            }

            val topology = decodeTopology(key, r.optString("topology", "triangle"))
                ?: return
            val isP3t4 = vertexMeta.layout == "p3t4"
            if (indexToken == null) {
                logOnce("geometry:$key:nonIndexed",
                    "geometry $key: non-indexed winding migration is not implemented; using sequential indices")
            }
            if (topology == MeshFactory.Topology.TRIANGLE_STRIP) {
                logOnce("geometry:$key:triangleStrip",
                    "geometry $key: triangleStrip winding migration is not implemented; using data as-is")
            }
            val start = System.nanoTime()
            try {
                val swapWinding = !isP3t4 && indexToken != null &&
                    topology == MeshFactory.Topology.TRIANGLES &&
                    !r.optBoolean("legacyWinding", false) && fsceneVersion >= 5
                val md = MeshFactory.fromPayload(
                    vertexBytes = vertexBytes,
                    layout = vertexMeta.layout,
                    indexBytes = indexBytes,
                    indexFormat = indexMeta?.format,
                    topology = topology,
                    swapTriangleWinding = swapWinding,
                    wireBounds = decodeGeometryBounds(key, r.optJSONObject("bounds")),
                )
                // W11 morph deltas — decoded alongside the base mesh;
                // a missing/short payload keeps the base either way
                // (iOS decodeMorphTargets defers rather than failing
                // the geometry).
                decodeMorphTargets(key, r, md, vertexBytes, vertexMeta.layout)
                geometries[key] = md
                val elapsedMs = (System.nanoTime() - start) / 1_000_000
                Log.i(TAG, "geometry $key: decoded ${md.vertexCount} verts in ${elapsedMs}ms")
            } catch (e: MeshFactory.PayloadDecodeException) {
                warnOnce("geometry:$key:decode:${e.message}",
                    "geometry $key: ${e.message}")
            } catch (e: Exception) {
                warnOnce("geometry:$key:decode:${e.javaClass.name}",
                    "geometry $key: payload decode failed: ${e.message ?: e.javaClass.simpleName}")
            }
        }

        /**
         * Decodes a geometry's `morphTargets` block (W11) onto
         * [MeshData.morph]. The deltas payload is another claim on the
         * geometry — recorded before resolution so an `upsertPayload`
         * chunk re-decodes the whole resource (mirrors iOS
         * `decodeMorphTargets`, which appends the delta pid to
         * `geometryPayloadKeys`). Malformed specs, missing payloads and
         * short slabs all leave `morph` null — the base mesh stands.
         */
        private fun decodeMorphTargets(
            key: Long, r: JSONObject, md: MeshFactory.MeshData,
            vertexBytes: ByteArray, layout: String?,
        ) {
            val m = r.optJSONObject("morphTargets") ?: return
            val pid = m.optString("deltas").takeIf { it.isNotEmpty() }
                ?.let { D3Wire.localIdKey(it) }
            val targetCount = m.optInt("targetCount", 0)
            if (pid == null || targetCount <= 0) {
                logOnce("geometry:$key:morph.malformed",
                    "geometry $key: morphTargets lacks deltas/targetCount")
                return
            }
            // Claim before resolution — an upsertPayload chunk
            // re-decodes this whole geometry on arrival.
            geometryPayloadIds.getOrPut(key) { LinkedHashSet() }.add(pid)
            val data = host.payloadStore[pid]
            if (data == null) {
                pendingPayloadRefs.add(key)
                logOnce("geometry:$key:morph.awaiting",
                    "geometry $key: awaiting morph delta payload")
                return
            }
            val defaults = m.optJSONArray("weights")?.toFloatArray()
                ?: FloatArray(0)
            try {
                md.morph = MeshFactory.morphDataFromPayload(
                    deltaBytes = data,
                    targetCount = targetCount,
                    hasNormalDeltas = m.optBoolean("normals"),
                    hasTangentDeltas = m.optBoolean("tangents"),
                    vertexBytes = vertexBytes,
                    layout = layout,
                    defaultWeights = defaults,
                )
            } catch (e: MeshFactory.PayloadDecodeException) {
                warnOnce("geometry:$key:morph.decode",
                    "geometry $key: ${e.message}")
            } catch (e: Exception) {
                warnOnce("geometry:$key:morph.${e.javaClass.name}",
                    "geometry $key: morph decode failed: ${e.message}")
            }
        }

        private fun decodeTopology(key: Long, raw: String): MeshFactory.Topology? =
            when (raw.ifEmpty { "triangle" }) {
                "triangle" -> MeshFactory.Topology.TRIANGLES
                "triangleStrip" -> MeshFactory.Topology.TRIANGLE_STRIP
                "line" -> MeshFactory.Topology.LINES
                "lineStrip" -> MeshFactory.Topology.LINE_STRIP
                "point" -> MeshFactory.Topology.POINTS
                else -> {
                    warnOnce("geometry:$key:topology:$raw",
                        "geometry $key: unknown topology '$raw'")
                    null
                }
            }

        private fun decodeGeometryBounds(key: Long, bounds: JSONObject?): FloatArray? {
            if (bounds == null) return null
            val min = bounds.optJSONArray("min")
            val max = bounds.optJSONArray("max")
            if (min == null || max == null || min.length() < 3 || max.length() < 3) {
                warnOnce("geometry:$key:bounds", "geometry $key: malformed bounds; scanning positions")
                return null
            }
            val minX = minOf(min.optDouble(0), max.optDouble(0)).toFloat()
            val maxX = maxOf(min.optDouble(0), max.optDouble(0)).toFloat()
            val minY = minOf(min.optDouble(1), max.optDouble(1)).toFloat()
            val maxY = maxOf(min.optDouble(1), max.optDouble(1)).toFloat()
            val nativeMinZ = -maxOf(min.optDouble(2), max.optDouble(2)).toFloat()
            val nativeMaxZ = -minOf(min.optDouble(2), max.optDouble(2)).toFloat()
            return floatArrayOf(
                (minX + maxX) * 0.5f,
                (minY + maxY) * 0.5f,
                (nativeMinZ + nativeMaxZ) * 0.5f,
                (maxX - minX) * 0.5f,
                (maxY - minY) * 0.5f,
                (nativeMaxZ - nativeMinZ) * 0.5f,
            )
        }

        private fun procedural(shape: String, p: JSONObject): MeshFactory.MeshData? {
            when (shape) {
                "cuboid" -> {
                    val e = p.tag("extents").d3Vec3() ?: doubleArrayOf(1.0, 1.0, 1.0)
                    return MeshFactory.cuboid(
                        e[0].toFloat(), e[1].toFloat(), e[2].toFloat())
                }
                "sphere" -> return MeshFactory.sphere(
                    (p.tag("radius").d3Double() ?: 0.5).toFloat())
                "icosphere" -> {
                    Log.i(TAG, "icosphere approximated with UV sphere")
                    return MeshFactory.sphere(
                        (p.tag("radius").d3Double() ?: 0.5).toFloat())
                }
                "plane" -> return MeshFactory.plane(
                    (p.tag("width").d3Double() ?: 1.0).toFloat(),
                    (p.tag("depth").d3Double() ?: 1.0).toFloat())
                "torus" -> return MeshFactory.torus(
                    (p.tag("radius").d3Double() ?: 0.5).toFloat(),
                    (p.tag("tubeRadius").d3Double() ?: 0.125).toFloat())
                else -> { Log.w(TAG, "unknown procedural shape '$shape'"); return null }
            }
        }

        private fun decodeMaterial(key: Long, r: JSONObject) {
            materialResources[key] = r
            materials[key] = buildMaterialInstance(
                host, key, r, textures, textureSamplers, textureConsumers)
        }

        private fun decodeTexture(key: Long, r: JSONObject) {
            textureResources[key] = r
            // Record the backing payload id even while pending — the
            // host's upsertPayload replays through this map.
            r.optString("payload").takeIf { it.isNotEmpty() }
                ?.let { D3Wire.localIdKey(it) }
                ?.let { texturePayloadIds[key] = it }
            when (val res = TextureFactory.realize(
                host, key, r, payloadSpecs)) {
                is TextureFactory.Result.Ready -> textures[key] = res.texture
                TextureFactory.Result.Pending -> {
                    pendingPayloadRefs.add(key)
                    Log.i(TAG, "texture $key: awaiting payload")
                }
                TextureFactory.Result.Failed -> Unit // reason already logged
            }
        }

        // MARK: Skins / animations (W11)

        /** Little-endian f32 list — the payload chunk codec every
         *  W11 slab (IBM matrices, timelines, keyframes, morph
         *  deltas) reads through. */
        private fun f32List(d: ByteArray): FloatArray =
            FloatArray(d.size / 4) { D3Wire.f32LE(d, it * 4) }

        fun decodeSkins(map: JSONObject?) {
            if (map == null) return
            for (token in map.keys()) {
                val key = D3Wire.localIdKey(token) ?: continue
                val def = map.optJSONObject(token) ?: continue
                skinDefs[key] = def
                decodeSkin(key, def)
            }
        }

        /**
         * One `skins` entry: joint node refs in authored order, the
         * `inverseBindMatrices` payload (16 f32 per joint, converted
         * through `D3Wire.matrix`; absent or in-flight → identity and
         * `awaitingIBM`), and the optional `skeleton` root
         * (informational — binding is by joints list + IBM). Mirrors
         * iOS `decodeSkin`.
         */
        fun decodeSkin(key: Long, def: JSONObject) {
            val jointKeys = ArrayList<Long>()
            def.optJSONArray("joints")?.let { a ->
                for (i in 0 until a.length()) {
                    D3Wire.localIdKey(a.optString(i))?.let(jointKeys::add)
                }
            }
            val skeletonKey = def.optString("skeleton")
                .takeIf { it.isNotEmpty() }?.let { D3Wire.localIdKey(it) }
            val ibms = MutableList(jointKeys.size) { identity16() }
            var awaiting = false
            val token = def.optString("inverseBindMatrices")
                .takeIf { it.isNotEmpty() }
            val pid = token?.let { D3Wire.localIdKey(it) }
            if (pid != null) {
                skinPayloadIds[key] = pid
                val data = host.payloadStore[pid]
                if (data != null) {
                    val floats = f32List(data)
                    val need = jointKeys.size * 16
                    if (floats.size < need) {
                        Log.i(TAG, "skin $key: inverseBindMatrices has " +
                            "${floats.size} floats; expected $need")
                    }
                    for (j in 0 until jointKeys.size) {
                        val b = j * 16
                        if (b + 16 > floats.size) break
                        ibms[j] = D3Wire.matrix(
                            DoubleArray(16) { floats[b + it].toDouble() })
                    }
                } else {
                    awaiting = true
                }
            } else {
                skinPayloadIds.remove(key)
            }
            skins[key] = DecodedSkin(jointKeys, ibms, skeletonKey, awaiting)
        }

        /**
         * `animations` block decode — raw defs kept in [animDefs] so
         * `upsertAnimation`/`upsertPayload` re-decode a single entry.
         */
        fun decodeAnimations(map: JSONObject?) {
            if (map == null) return
            for (token in map.keys()) {
                val key = D3Wire.localIdKey(token) ?: continue
                val def = map.optJSONObject(token) ?: continue
                animDefs[key] = def
                decodeAnimation(key, def)
            }
        }

        /**
         * One `animations` entry. Each channel's timeline (f32
         * seconds) and keyframes are payload refs — recorded as claims
         * first so an `upsertPayload` chunk re-decodes the animation
         * it unblocks; a channel whose payloads haven't landed is
         * skipped this pass. Values convert to engine space here:
         * translation negates z, rotation takes the (−x,−y,z,w)
         * pseudovector map, scale and weights pass through. `weights`
         * channels carry flattened per-key values — `targetCount` is
         * `values.size / times.size`, trailing floats that don't
         * complete a keyframe are dropped (upstream's rule). Mirrors
         * iOS `decodeAnimation`.
         */
        fun decodeAnimation(key: Long, def: JSONObject) {
            val name = def.optString("name")
            val channels = ArrayList<DecodedChannel>()
            var endTime = 0.0
            val claims = animPayloadIds[key] ?: HashSet()
            def.optJSONArray("channels")?.let { arr ->
                for (i in 0 until arr.length()) {
                    val c = arr.optJSONObject(i) ?: continue
                    val target = c.optString("target")
                        .takeIf { it.isNotEmpty() }
                        ?.let { D3Wire.localIdKey(it) } ?: continue
                    val kind = when (c.optString("property")) {
                        "rotation" -> DecodedChannel.Kind.ROTATION
                        "scale" -> DecodedChannel.Kind.SCALE
                        "weights" -> DecodedChannel.Kind.WEIGHTS
                        else -> DecodedChannel.Kind.TRANSLATION
                    }
                    val tPid = c.optString("timeline")
                        .takeIf { it.isNotEmpty() }
                        ?.let { D3Wire.localIdKey(it) }
                    val kPid = c.optString("keyframes")
                        .takeIf { it.isNotEmpty() }
                        ?.let { D3Wire.localIdKey(it) }
                    if (tPid == null || kPid == null) {
                        Log.i(TAG, "animation $key: channel missing " +
                            "timeline/keyframes")
                        continue
                    }
                    claims.add(tPid); claims.add(kPid)
                    val tData = host.payloadStore[tPid]
                    val kData = host.payloadStore[kPid]
                    if (tData == null || kData == null) {
                        logOnce("anim.$key.awaiting",
                            "animation $key: awaiting channel payloads")
                        continue
                    }
                    val times = DoubleArray(tData.size / 4) {
                        D3Wire.f32LE(tData, it * 4).toDouble()
                    }
                    val vals = f32List(kData)
                    var vec3 = FloatArray(0)
                    var quat = FloatArray(0)
                    var weights = FloatArray(0)
                    var targetCount = 0
                    when (kind) {
                        DecodedChannel.Kind.TRANSLATION -> {
                            val n = minOf(times.size, vals.size / 3)
                            vec3 = FloatArray(n * 3) { j ->
                                val b = (j / 3) * 3
                                val c = j % 3
                                if (c == 2) -vals[b + 2] else vals[b + c]
                            }
                        }
                        DecodedChannel.Kind.SCALE -> {
                            val n = minOf(times.size, vals.size / 3)
                            vec3 = vals.copyOfRange(0, n * 3)
                        }
                        DecodedChannel.Kind.ROTATION -> {
                            val n = minOf(times.size, vals.size / 4)
                            quat = FloatArray(n * 4) { j ->
                                val b = (j / 4) * 4
                                when (j % 4) {
                                    0 -> -vals[b]
                                    1 -> -vals[b + 1]
                                    2 -> vals[b + 2]
                                    else -> vals[b + 3]
                                }
                            }
                        }
                        DecodedChannel.Kind.WEIGHTS -> {
                            val keyCount = times.size
                            val tc = if (keyCount > 0) {
                                vals.size / keyCount
                            } else 0
                            targetCount = tc
                            weights = vals.copyOf(
                                minOf(tc * keyCount, vals.size))
                        }
                    }
                    times.lastOrNull()?.let { endTime = maxOf(endTime, it) }
                    channels.add(DecodedChannel(
                        target = target,
                        targetName = c.optString("targetName")
                            .takeIf { it.isNotEmpty() },
                        kind = kind, times = times,
                        vec3 = vec3, quat = quat,
                        weights = weights, targetCount = targetCount))
                }
            }
            animPayloadIds[key] = claims
            animations[key] = DecodedAnimation(name, channels, endTime)
        }

        /**
         * Re-attaches every node bound to `skinKey` — the
         * `upsertSkin`/`removeSkin`-adjacent refresh after
         * `decodeSkin` rewrites (or removes) the skin record. Joints
         * resolve per-frame at bone-matrix upload, so the refresh only
         * rebuilds the renderable (buffer resize / attach / detach).
         */
        fun refreshSkinConsumers(skinKey: Long) {
            for ((nodeKey, key) in nodeSkinKeys) {
                if (key != skinKey) continue
                rebuildRenderable(nodeKey)
            }
        }

        /**
         * Destroys and re-creates a node's renderable through
         * `decodeMesh` — the skin attach/detach and morph rebind
         * vehicle. Keeps the physics body, light and camera state;
         * the renderable is the only rebuilt piece.
         */
        fun rebuildRenderable(nodeKey: Long) {
            val rec = nodes[nodeKey] ?: return
            // W16: an lod-owned renderable isn't a mesh rebuild
            // target — the frame pass owns the slot (a suspended
            // lod's mesh owns it and rebuilds normally).
            rec.lod?.let {
                if (it.ownsRenderable && !it.suspended) return
            }
            val rm = host.engine.renderableManager
            if (rm.hasComponent(rec.entity)) rm.destroy(rec.entity)
            host.scene.removeEntity(rec.entity)
            for ((_, list) in materialConsumers) {
                list.removeAll { it.first == rec.entity }
            }
            nodeSkinning.remove(nodeKey)?.let {
                host.engine.destroySkinningBuffer(it.buffer)
            }
            rec.morphWeights = null
            val props = rec.meshProps ?: return
            decodeMesh(nodeKey, rec, props)
            applyVisibility(nodeKey)
        }

        private fun identity16(): FloatArray {
            val m = FloatArray(16)
            Matrix.setIdentityM(m, 0)
            return m
        }

        // MARK: Nodes

        fun decodeNodes(map: JSONObject?) {
            if (map == null) return
            // Pass 1: entities + transforms + components.
            for (token in map.keys()) {
                val key = D3Wire.localIdKey(token) ?: continue
                val spec = map.optJSONObject(token) ?: continue
                decodeNode(key, spec)
            }
            // Pass 2: hierarchy + world matrices (needed by physics BCS).
            for (token in map.keys()) {
                val key = D3Wire.localIdKey(token) ?: continue
                val rec = nodes[key] ?: continue
                val spec = map.optJSONObject(token) ?: continue
                val children = spec.optJSONArray("children") ?: continue
                for (i in 0 until children.length()) {
                    val ck = D3Wire.localIdKey(children.optString(i)) ?: continue
                    val child = nodes[ck] ?: continue
                    child.parentKey = key
                    // Instance handles are not stable across component
                    // destruction (the manager compacts), so resolve
                    // them fresh rather than caching.
                    tcm.setParent(
                        tcm.getInstance(child.entity),
                        tcm.getInstance(rec.entity))
                }
            }
            for ((key, rec) in nodes) {
                nodeWorld[key] = worldMatOf(key)
            }
        }

        /**
         * One node's pass-1 decode — entity, transform, name/layers/
         * visible, components — shared by [decodeNodes] and the W5
         * `addNode` surgical path. Hierarchy wiring is NOT done here:
         * manifest children attach in pass 2, diff children via their
         * own addNode's parent field.
         */
        private fun decodeNode(key: Long, spec: JSONObject): NodeRec {
            val entity = em.create()
            val trs = decodeTrs(spec.optJSONObject("transform"))
            tcm.setTransform(
                tcm.create(entity), D3Wire.trs(trs[0], trs[1], trs[2]))
            val rec = NodeRec(
                entity, null,
                trs[0], trs[1], trs[2],
            )
            rec.name = spec.optString("name").takeIf { it.isNotEmpty() }
            rec.layers = spec.optInt("layers", 1)
            if (spec.has("visible") && !spec.getBoolean("visible")) {
                rec.hidden = true
            }
            // W11: the `skin` member binds the node to a `skins`
            // entry — read before components so decodeMesh's skinning
            // attach sees it.
            spec.optString("skin").takeIf { it.isNotEmpty() }
                ?.let { D3Wire.localIdKey(it) }
                ?.let { nodeSkinKeys[key] = it }
            // W15: a surviving `instance` member tags the node as a
            // lazy prefab placeholder — kept raw on the rec; the
            // streaming layer resolves it.
            rec.instanceSpec = spec.optJSONObject("instance")
            val comps = spec.optJSONArray("components")
            if (comps != null) {
                for (i in 0 until comps.length()) {
                    decodeComponent(key, rec, i, comps.opt(i))
                }
            }
            nodes[key] = rec
            return rec
        }

        /** Decoded local TRS (RH space): [pos, quat, scale]. */
        private fun decodeTrs(t: JSONObject?): Array<FloatArray> {
            var p = floatArrayOf(0f, 0f, 0f)
            var q = floatArrayOf(0f, 0f, 0f, 1f)
            var s = floatArrayOf(1f, 1f, 1f)
            val trs = t?.optJSONObject("trs")
            if (trs != null) {
                trs.optJSONArray("t")?.toDoubleArray()?.let { p = D3Wire.position(it) }
                trs.optJSONArray("r")?.toDoubleArray()?.let { q = D3Wire.quaternion(it) }
                trs.optJSONArray("s")?.toDoubleArray()?.let { s = D3Wire.scale(it) }
            } else {
                val m = t?.optJSONArray("matrix")?.toDoubleArray()
                if (m != null && m.size == 16) {
                    val conv = D3Wire.matrix(m)
                    val d = decompose(conv)
                    p = d[0]; q = d[1]; s = d[2]
                }
            }
            return arrayOf(p, q, s)
        }

        /**
         * Filament's scene is flat — transform parenting doesn't pull a
         * child into the render set the way SceneKit's node tree does,
         * so every renderable/light entity is added explicitly. Hidden
         * nodes (and their subtree, matching `SCNNode.isHidden`) stay
         * out; their transform instances still exist for hierarchy math.
         */
        fun attachToScene() {
            for ((key, rec) in nodes) {
                if (isHidden(key)) continue
                attachIfRenderable(rec)
            }
        }

        /** The visibility-aware scene add — [attachToScene]'s per-node
         * body, reused by the W5 node ops. */
        private fun attachIfRenderable(rec: NodeRec) {
            // W16: an lod-culled node keeps its renderable out of the
            // scene until the frame pass rebinds a level — a
            // visibility re-eval must not re-attach it.
            rec.lod?.let {
                if (!it.suspended && it.ownsRenderable && it.bound < 0) {
                    return
                }
            }
            val rm = host.engine.renderableManager
            val lm = host.engine.lightManager
            if (rm.hasComponent(rec.entity) || lm.hasComponent(rec.entity)) {
                host.scene.addEntity(rec.entity)
            }
        }

        /** True when the node or any ancestor carries `visible:false`. */
        private fun isHidden(key: Long): Boolean {
            var k: Long? = key
            while (k != null) {
                val rec = nodes[k] ?: return false
                if (rec.hidden) return true
                k = rec.parentKey
            }
            return false
        }

        /** Composes the node's world matrix through the parent chain. */
        private fun worldMatOf(key: Long): FloatArray {
            var m = D3Wire.trs(
                nodes.getValue(key).localPos,
                nodes.getValue(key).localQuat,
                nodes.getValue(key).localScale,
            )
            var p = nodes[key]?.parentKey
            while (p != null) {
                val pr = nodes[p] ?: break
                val pm = D3Wire.trs(pr.localPos, pr.localQuat, pr.localScale)
                val out = FloatArray(16)
                Matrix.multiplyMM(out, 0, pm, 0, m, 0)
                m = out
                p = pr.parentKey
            }
            return m
        }

        // MARK: Components

        private fun decodeComponent(
            key: Long, rec: NodeRec, index: Int, any: Any?,
        ) {
            val spec = any as? JSONObject ?: return
            val type = spec.optString("type")
            val props = spec.optJSONObject("properties") ?: JSONObject()
            // Universal `enabled` (W12) — upstream's component wrapper
            // applies it around update/fixedUpdate callbacks only; it
            // does not remove realized state. dart3d components have
            // no tick surface, so the flag is recorded, not applied.
            if (props.tag("enabled").d3Bool() == false) {
                disabledComponents.getOrPut(key) { HashSet() }.add(index)
                logOnce("enabled:$key:$index",
                    "component '$type' on node $key: enabled:false " +
                        "gates upstream component ticks only; dart3d " +
                        "has no tick surface — recorded, not applied")
            }
            when (type) {
                "mesh" -> decodeMesh(key, rec, props)
                "camera" -> decodeCamera(key, rec, props)
                "directionalLight" -> decodeLight(rec, props, LightManager.Type.DIRECTIONAL)
                "pointLight" -> decodeLight(rec, props, LightManager.Type.POINT)
                "spotLight" -> decodeLight(rec, props, LightManager.Type.FOCUSED_SPOT)
                "rectAreaLight" -> decodeRectAreaLight(key, rec, props)
                "rigidBody", "collider", "physicsWorld" ->
                    physicsDeferred.add(PhysicsItem(key, rec, type, props))
                "fixedJoint", "sphericalJoint", "revoluteJoint",
                "prismaticJoint", "genericJoint" ->
                    jointComponentsDeferred.add(
                        JointItem(key, index, type, props))
                "materialsVariants" ->
                    decodeMaterialsVariants(key, index, props)
                "trail" -> decodeTrail(key, rec, props)
                "lod" -> decodeLod(key, rec, props)
                else -> Log.i(TAG, "unhandled component type '$type'")
            }
        }

        private fun decodeMesh(key: Long, rec: NodeRec, p: JSONObject) {
            rec.meshProps = p
            // W16: an `lod` decoded earlier in the same component
            // list owns the renderable slot until now — last-write-
            // wins, mirroring iOS's `node.geometry` overwrite order.
            // Its (entity,0) material-consumer entry dies with the
            // foreign renderable so a level-material upsert can't
            // stomp the mesh's slot.
            run {
                val rm = host.engine.renderableManager
                if (rm.hasComponent(rec.entity)) {
                    rm.destroy(rec.entity)
                    for ((_, list) in materialConsumers) {
                        list.removeAll { it.first == rec.entity }
                    }
                    // The lod's slot bookkeeping dies with its
                    // renderable — but it isn't suspended until the
                    // mesh actually builds, so a pending mesh
                    // geometry leaves the lod drawing (iOS's
                    // node.geometry stays the last successful write
                    // too).
                    rec.lod?.let {
                        it.ownsRenderable = false
                        it.bound = -1
                        it.boundMatKey = null
                    }
                }
            }
            // Ordered (geometry, material) pairs across the mesh's
            // primitives — see meshPrimitiveKeys for the upstream
            // tagged-map entry shape.
            val (primGeoKeys, primMatKeys) = meshPrimitiveKeys(p)
            // A consumer link rides on every geometry key — an
            // upsertResource/upsertPayload first-builds the renderable
            // from the retained mesh props once ALL primitives resolve
            // (a partial build would render a fraction of the mesh).
            for (g in primGeoKeys) {
                geometryConsumers.getOrPut(g) { LinkedHashSet() }.add(key)
            }
            val prims = primGeoKeys.mapNotNull { gpuMesh(it) }
            if (prims.size != primGeoKeys.size) {
                Log.w(TAG, "mesh node: geometry unresolved"); return
            }
            rec.meshPrimGeoKeys = primGeoKeys
            // Per-primitive materials — each consumer entry carries its
            // renderable slot so a late material upsert re-attaches at
            // the right index.
            val primInstances = ArrayList<MaterialInstance>(prims.size)
            for (i in prims.indices) {
                val mk = primMatKeys[i]
                primInstances.add(
                    mk?.let { materials[it] }
                        ?: host.litMaterial.defaultInstance)
                mk?.let {
                    materialConsumers.getOrPut(it) { ArrayList() }
                        .add(Pair(rec.entity, i))
                }
            }
            // Collider derivation sees the union of all primitives —
            // a hull or trimesh over primitive 0 alone under-covers a
            // multi-part mesh.
            aggregateGeoState(rec)
            val unionBounds = rec.lastGeoBounds ?: prims[0].bounds
            // Skinning + morphing ride the first primitive's streams —
            // upstream skinned multi-primitive meshes carry the same
            // bone channels in every primitive, and morph weights
            // apply at the renderable level.
            val mesh = prims[0]
            // W11 skin attach — the node's declared `skin` member
            // resolves a skin record and the mesh must carry the bone
            // streams. Joints resolve per-frame at bone-matrix upload
            // (a missing joint reads identity — upstream's
            // null-tolerant rule), so an in-flight IBM payload or
            // late-arriving joint never blocks the attach; the
            // `skinPayloadIds` claim + refreshSkinConsumers cover the
            // rebuild when the record itself lands.
            val skinKey = nodeSkinKeys[key]
            val skin = skinKey?.let { skins[it] }
            var skinBuf: SkinningBuffer? = null
            var boneCount = 0
            if (skinKey != null) {
                when {
                    skin == null -> logOnce("skin.$key.unresolved",
                        "node $key: skin $skinKey not realized")
                    !mesh.hasSkinning -> logOnce("skin.$key.unskinned",
                        "node $key: has skin $skinKey but its geometry" +
                            " carries no bone sources")
                    skin.jointKeys.isEmpty() -> logOnce("skin.$key.empty",
                        "node $key: skin $skinKey has no joints")
                    else -> {
                        boneCount = minOf(skin.jointKeys.size, 256)
                        skinBuf = SkinningBuffer.Builder()
                            .boneCount(boneCount)
                            .initialize(true)
                            .build(host.engine)
                    }
                }
            }
            val builder = RenderableManager.Builder(prims.size)
                .boundingBox(Box(unionBounds[0], unionBounds[1],
                    unionBounds[2], unionBounds[3], unionBounds[4],
                    unionBounds[5]))
                // Node `layers` → the renderable's 8-bit Filament mask
                // (the view sees every layer — Dart3dView.init).
                .layerMask(0xFF, rec.layers and 0xFF)
                .castShadows(true)
                .receiveShadows(true)
            for (i in prims.indices) {
                builder.geometry(i, prims[i].primitiveType,
                    prims[i].vertexBuffer, prims[i].indexBuffer)
                    .material(i, primInstances[i])
            }
            if (skinBuf != null) {
                builder.enableSkinningBuffers(true)
                    .skinning(skinBuf, boneCount, 0)
            }
            mesh.morphTargetBuffer?.let { builder.morphing(it) }
            builder.build(host.engine, rec.entity)
            // The mesh took the slot — suspend a decoded `lod` (the
            // per-frame pass skips it; a components re-decode
            // restores whichever order the wire sends).
            rec.lod?.let {
                it.suspended = true
                it.ownsRenderable = false
                it.bound = -1
                it.boundMatKey = null
            }
            if (skinBuf != null && skinKey != null) {
                nodeSkinning[key] = Dart3dView.NodeSkin(
                    skinKey, skinBuf, boneCount)
            }
            // Default morph weights land at attach (upstream applies
            // `weights` on morpher creation); the live array then
            // belongs to the node for setMorphWeights + the sampler.
            val mtb = mesh.morphTargetBuffer
            if (mtb != null) {
                val weights = FloatArray(mesh.morphTargetCount) { i ->
                    mesh.morphDefaults.getOrElse(i) { 0f }
                }
                rec.morphWeights = weights
                val rm = host.engine.renderableManager
                rm.setMorphWeights(rm.getInstance(rec.entity),
                    weights, 0)
            }
        }

        private fun gpuMesh(key: Long): GpuMesh? {
            gpuMeshes[key]?.let { return it }
            val md = geometries[key] ?: return null
            return buildGpuMesh(md).also { gpuMeshes[key] = it }
        }

        // MARK: Trails and LOD (W16)

        /**
         * Decodes a `trail` component (upstream `TrailComponent`):
         * the spec fields into a `TrailState` plus a fixed-topology
         * ribbon — 2 verts per anchor, upstream's strip winding,
         * POSITION+COLOR streams the per-frame pass refills. The
         * entity rides no parent (identity transform — the verts
         * ARE world space). Upstream serializes no trail material;
         * the shared vertex-color unlit blend instance binds here.
         * The path itself is runtime state — a re-decode starts
         * empty like upstream's codec.
         */
        private fun decodeTrail(key: Long, rec: NodeRec, p: JSONObject) {
            val maxPoints = maxOf(2,
                p.tag("maxPoints").d3Int() ?: 48)
            val entity = em.create()
            val vb = VertexBuffer.Builder()
                .vertexCount(maxPoints * 2)
                .bufferCount(1)
                .attribute(VertexBuffer.VertexAttribute.POSITION, 0,
                    VertexBuffer.AttributeType.FLOAT3, 0, 28)
                .attribute(VertexBuffer.VertexAttribute.COLOR, 0,
                    VertexBuffer.AttributeType.FLOAT4, 12, 28)
                .build(host.engine)
            // Zeroed until the first frame records a path — dead
            // verts collapse to zero width/alpha like upstream's
            // `_TrailGeometry.setTrail`.
            val staging = java.nio.ByteBuffer.allocateDirect(
                maxPoints * 2 * 28)
                .order(java.nio.ByteOrder.nativeOrder())
            vb.setBufferAt(host.engine, 0, staging)
            val indices = ShortArray((maxPoints - 1) * 6)
            for (i in 0 until maxPoints - 1) {
                val a = (i * 2).toShort()
                val o = i * 6
                indices[o] = a; indices[o + 1] = (a + 1).toShort()
                indices[o + 2] = (a + 2).toShort()
                indices[o + 3] = (a + 1).toShort()
                indices[o + 4] = (a + 3).toShort()
                indices[o + 5] = (a + 2).toShort()
            }
            val ib = IndexBuffer.Builder()
                .indexCount(indices.size)
                .bufferType(IndexBuffer.Builder.IndexType.USHORT)
                .build(host.engine)
            ib.setBuffer(host.engine,
                java.nio.ByteBuffer.allocateDirect(indices.size * 2)
                    .order(java.nio.ByteOrder.nativeOrder())
                    .also { b -> b.asShortBuffer().put(indices) }
                    .also { it.rewind() })
            RenderableManager.Builder(1)
                // The verts are dynamic world-space data — no static
                // AABB describes them (a zero box at the unparented
                // entity's identity transform is a point at the world
                // origin, which would frustum-cull every off-axis
                // trail). Culling off is the always-correct answer
                // for a ribbon rewritten per frame.
                .culling(false)
                .layerMask(0xFF, rec.layers and 0xFF)
                .castShadows(false)
                .geometry(0, RenderableManager.PrimitiveType.TRIANGLES,
                    vb, ib)
                .material(0, host.trailMaterial.defaultInstance)
                .build(host.engine, entity)
            // Identity world transform — the entity is unparented.
            val ident = FloatArray(16)
            Matrix.setIdentityM(ident, 0)
            tcm.setTransform(tcm.create(entity), ident)
            // Upstream curve `{keys:[{t,v}]}`, gradient
            // `{stops:[{t,color}]}` — decoded to flat (t,v) /
            // (t,r,g,b,a) tuples.
            fun taggedPairs(list: JSONArray?): List<FloatArray> {
                if (list == null) return emptyList()
                val out = ArrayList<FloatArray>(list.length())
                for (i in 0 until list.length()) {
                    val m = list.opt(i).d3Map() ?: continue
                    val t = m.tag("t").d3Double() ?: continue
                    val v = m.tag("v").d3Double() ?: continue
                    out.add(floatArrayOf(t.toFloat(), v.toFloat()))
                }
                return out
            }
            val wk = taggedPairs(p.tag("widthOverTrail").d3Map()
                ?.tag("keys").d3List())
            val widthKeys = if (wk.isEmpty()) null
                else FloatArray(wk.size * 2) { i -> wk[i / 2][i % 2] }
            val stops = ArrayList<FloatArray>()
            p.tag("colorOverTrail").d3Map()
                ?.tag("stops").d3List()?.let { list ->
                    for (i in 0 until list.length()) {
                        val m = list.opt(i).d3Map() ?: continue
                        val t = m.tag("t").d3Double() ?: continue
                        val c = m.tag("color").d3Color() ?: continue
                        stops.add(floatArrayOf(
                            t.toFloat(), c[0], c[1], c[2], c[3]))
                    }
                }
            val colorStops = if (stops.isEmpty()) null
                else FloatArray(stops.size * 5) { i ->
                    stops[i / 5][i % 5]
                }
            rec.trail = TrailState(
                entity = entity,
                vertexBuffer = vb,
                indexBuffer = ib,
                maxPoints = maxPoints,
                width = (p.tag("width").d3Double() ?: 0.25).toFloat(),
                lifetime =
                    (p.tag("lifetime").d3Double() ?: 0.6).toFloat(),
                minVertexDistance =
                    (p.tag("minVertexDistance").d3Double() ?: 0.05)
                        .toFloat(),
                emitting = p.tag("emitting").d3Bool() ?: true,
                widthKeys = widthKeys,
                colorStops = colorStops,
                points = FloatArray(maxPoints * 3),
                born = DoubleArray(maxPoints),
                staging = staging,
            )
        }

        /**
         * Decodes an `lod` component (upstream `LodComponent`): each
         * `levels` entry carries geometry+material refs plus a
         * `screenSize` threshold (fraction of viewport height,
         * descending); entries missing either ref are skipped like
         * upstream's codec. The lod owns the node's renderable slot —
         * a `mesh` decoded earlier in the same component list yields
         * here (iOS's `node.geometry` overwrite order), a later one
         * suspends the pass. Level resources resolve per bind; a
         * landing re-runs [refreshLodConsumers].
         */
        private fun decodeLod(key: Long, rec: NodeRec, p: JSONObject) {
            val levels = ArrayList<LodLevelSpec>()
            val list = p.tag("levels").d3List()
            if (list != null) {
                for (i in 0 until list.length()) {
                    val m = list.opt(i).d3Map() ?: continue
                    val g = m.tag("geometry").d3Ref() ?: continue
                    val mat = m.tag("material").d3Ref() ?: continue
                    // Upstream's _levelEntries drops a level only for
                    // a missing/mistyped geometry or material ref; an
                    // absent/malformed screenSize decodes as 0.0 —
                    // the never-cull threshold, NOT a dropped level.
                    val s = m.tag("screenSize").d3Double() ?: 0.0
                    levels.add(LodLevelSpec(g, mat, s))
                }
            }
            if (levels.isEmpty()) return
            rec.lod = LodState(
                levels = levels,
                lodBias = p.tag("lodBias").d3Double() ?: 1.0,
                // Decoded for wire parity — documented no-ops.
                hysteresis = p.tag("hysteresis").d3Double() ?: 0.0,
                blendRange = p.tag("blendRange").d3Double() ?: 0.0,
            )
            bindLodLevel(key, rec, 0)
        }

        /**
         * Binds level [idx] of the node's `lod` to its renderable
         * slot — the geometry+material swap the per-frame selection
         * pass drives. A foreign renderable (a `mesh` decoded
         * earlier, or none) is destroyed and rebuilt single-
         * primitive; one the lod already owns takes the cheap
         * setGeometryAt/setMaterialInstanceAt path. An unresolved
         * level leaves the current binding — a resource landing
         * retries via [refreshLodConsumers], and the frame pass
         * re-evaluates every step regardless. `idx` -1 is the cull
         * floor: the entity leaves the scene until a later
         * selection re-binds. [force] rebinds the current level —
         * the geometry-upsert path, whose new buffers must replace
         * the bound (about-to-be-destroyed) ones.
         */
        private fun bindLodLevel(key: Long, rec: NodeRec, idx: Int,
                                 force: Boolean = false) {
            val lod = rec.lod ?: return
            if (lod.suspended) return
            if (idx < 0) {
                if (lod.bound >= 0) {
                    host.scene.removeEntity(rec.entity)
                    lod.boundMatKey?.let { mk ->
                        materialConsumers[mk]?.removeAll {
                            it.first == rec.entity
                        }
                    }
                    lod.bound = -1
                    lod.boundMatKey = null
                }
                return
            }
            if (!force && lod.bound == idx) return
            val level = lod.levels[idx]
            val gm = gpuMesh(level.geoKey) ?: return
            val mi = materials[level.matKey] ?: return
            val rm = host.engine.renderableManager
            // Take a foreign renderable over wholesale — the lod
            // renders exactly one level, so a mesh's multi-primitive
            // slots can't ride setGeometryAt.
            if (!lod.ownsRenderable && rm.hasComponent(rec.entity)) {
                rm.destroy(rec.entity)
                for ((_, list) in materialConsumers) {
                    list.removeAll { it.first == rec.entity }
                }
                for ((_, set) in geometryConsumers) set.remove(key)
            }
            val b = gm.bounds
            if (!rm.hasComponent(rec.entity)) {
                RenderableManager.Builder(1)
                    .boundingBox(Box(b[0], b[1], b[2],
                        b[3], b[4], b[5]))
                    .layerMask(0xFF, rec.layers and 0xFF)
                    .castShadows(true)
                    .receiveShadows(true)
                    .geometry(0, gm.primitiveType, gm.vertexBuffer,
                        gm.indexBuffer)
                    .material(0, mi)
                    .build(host.engine, rec.entity)
            } else {
                val ri = rm.getInstance(rec.entity)
                rm.setGeometryAt(ri, 0, gm.primitiveType,
                    gm.vertexBuffer, gm.indexBuffer)
                rm.setMaterialInstanceAt(ri, 0, mi)
                rm.setAxisAlignedBoundingBox(ri,
                    Box(b[0], b[1], b[2], b[3], b[4], b[5]))
            }
            // The (entity,0) consumer entry belongs to the bound
            // level's material — one live entry at a time so a
            // material upsert writes the live level's slot.
            lod.boundMatKey?.let { mk ->
                materialConsumers[mk]?.removeAll {
                    it.first == rec.entity
                }
            }
            materialConsumers.getOrPut(level.matKey) { ArrayList() }
                .add(Pair(rec.entity, 0))
            lod.bound = idx
            lod.boundMatKey = level.matKey
            lod.ownsRenderable = true
            if (!isHidden(key)) attachIfRenderable(rec)
        }

        /**
         * Rebinds the live level of every `lod` spec consuming the
         * just-landed resource `key` — a geometry upsert swaps the
         * GpuMesh buffers under the bound renderable (stale buffers
         * are destroyed by the upsert), a material landing re-
         * resolves the instance. Unbound/culled specs need nothing:
         * the frame pass re-resolves per bind.
         */
        fun refreshLodConsumers(resKey: Long) {
            for ((key, rec) in nodes) {
                val lod = rec.lod ?: continue
                if (lod.suspended || lod.bound < 0) continue
                val l = lod.levels[lod.bound]
                if (l.geoKey == resKey || l.matKey == resKey) {
                    bindLodLevel(key, rec, lod.bound, force = true)
                }
            }
        }

        /**
         * Destroys a node's trail/lod runtime state — shared by
         * `teardownComponents`, node removal, and the install sweep.
         * The trail's unparented entity and dynamic buffers die
         * here; the lod's renderable/entity belong to the node and
         * die with it — only its consumer entry drops.
         */
        fun destroyTrailLod(rec: NodeRec) {
            val rm = host.engine.renderableManager
            rec.trail?.let { tr ->
                host.scene.removeEntity(tr.entity)
                if (rm.hasComponent(tr.entity)) rm.destroy(tr.entity)
                host.engine.destroyEntity(tr.entity)
                em.destroy(tr.entity)
                host.engine.destroyVertexBuffer(tr.vertexBuffer)
                host.engine.destroyIndexBuffer(tr.indexBuffer)
            }
            rec.trail = null
            rec.lod?.let { lod ->
                lod.boundMatKey?.let { mk ->
                    materialConsumers[mk]?.removeAll {
                        it.first == rec.entity
                    }
                }
            }
            rec.lod = null
        }

        // MARK: Trails and LOD frame pass (W16)

        /** Per-vertex color scratch for [tickTrail]'s refill — the
         *  pass runs on the frame thread only. */
        private val colorScratch = FloatArray(4)

        /**
         * Samples the flat `widthOverTrail` (t,v) pairs at the
         * head-to-tail fraction [t] — piecewise-linear, clamped to
         * the ends; the absent-ramp fallback is upstream's `1 − t`
         * taper. Port of `sampleTrailStops`.
         */
        private fun sampleTrailKeys(keys: FloatArray?, t: Float): Float {
            if (keys == null || keys.isEmpty()) return 1f - t
            val n = keys.size / 2
            if (t <= keys[0]) return keys[1]
            if (t >= keys[(n - 1) * 2]) return keys[(n - 1) * 2 + 1]
            for (i in 1 until n) {
                val bt = keys[i * 2]
                if (t <= bt) {
                    val at = keys[(i - 1) * 2]
                    val av = keys[(i - 1) * 2 + 1]
                    val bv = keys[i * 2 + 1]
                    return av + (bv - av) * (t - at) / (bt - at)
                }
            }
            return keys[(n - 1) * 2 + 1]
        }

        /**
         * Samples the flat `colorOverTrail` (t,r,g,b,a) tuples at
         * [t] into [out] — piecewise-linear rgba, clamped; the
         * absent-gradient fallback is upstream's white fading
         * alpha `1 − t`. Port of `sampleTrailColorStops`.
         */
        private fun sampleTrailColor(stops: FloatArray?, t: Float,
                                     out: FloatArray) {
            if (stops == null || stops.isEmpty()) {
                out[0] = 1f; out[1] = 1f; out[2] = 1f
                out[3] = 1f - t
                return
            }
            val n = stops.size / 5
            fun cp(i: Int) {
                out[0] = stops[i * 5 + 1]
                out[1] = stops[i * 5 + 2]
                out[2] = stops[i * 5 + 3]
                out[3] = stops[i * 5 + 4]
            }
            if (t <= stops[0]) { cp(0); return }
            if (t >= stops[(n - 1) * 5]) { cp(n - 1); return }
            for (i in 1 until n) {
                val bt = stops[i * 5]
                if (t <= bt) {
                    val at = stops[(i - 1) * 5]
                    val f = (t - at) / (bt - at)
                    for (c in 0..3) {
                        val a = stops[(i - 1) * 5 + 1 + c]
                        val bv = stops[i * 5 + 1 + c]
                        out[c] = a + (bv - a) * f
                    }
                    return
                }
            }
            cp(n - 1)
        }

        /**
         * The per-frame trail/lod pass — the host's `stepFrame`
         * calls it after the camera updates, before render (the
         * same slot iOS's renderer delegate uses). Trails record
         * head-first world points, expire by age/capacity, and
         * refill the camera-facing ribbon; lods project the
         * level-0 bounding sphere and rebind (or cull) the node.
         */
        fun updateTrailsLods(dt: Float, camPos: FloatArray,
                             fovRadY: Double, perspective: Boolean) {
            for ((key, rec) in nodes) {
                rec.trail?.let { tickTrail(key, rec, it, dt, camPos) }
                val lod = rec.lod
                if (lod != null && !lod.suspended) {
                    updateLod(key, rec, lod, camPos, fovRadY,
                        perspective)
                }
            }
        }

        /**
         * Advances one trail: the head follows the node's world
         * position, a new anchor drops after `minVertexDistance`,
         * the tail expires by `lifetime`/`maxPoints` (upstream's
         * `TrailComponent.update` policy — `emitting` false pauses
         * recording while the path still ages out). Then the
         * ribbon refills: two verts per anchor offset `±width·side`
         * where `side = normalize(tangent × toCamera)` — world
         * space, the entity is unparented. Under two live points
         * (or a hidden chain) the entity leaves the scene.
         */
        private fun tickTrail(key: Long, rec: NodeRec,
                              tr: TrailState, dt: Float,
                              camPos: FloatArray) {
            tr.time += dt
            val m = FloatArray(16)
            tcm.getWorldTransform(tcm.getInstance(rec.entity), m)
            val hx = m[12]; val hy = m[13]; val hz = m[14]
            if (tr.emitting) {
                if (tr.count == 0) {
                    tr.points[0] = hx
                    tr.points[1] = hy
                    tr.points[2] = hz
                    tr.born[0] = tr.time
                    tr.count = 1
                } else {
                    // The head follows continuously; a new anchor
                    // drops once the node has moved far enough
                    // from the previous one.
                    tr.points[0] = hx
                    tr.points[1] = hy
                    tr.points[2] = hz
                    tr.born[0] = tr.time
                    val a = if (tr.count > 1) 3 else 0
                    val dx = tr.points[a] - hx
                    val dy = tr.points[a + 1] - hy
                    val dz = tr.points[a + 2] - hz
                    val d2 = dx * dx + dy * dy + dz * dz
                    if (tr.count == 1 ||
                        d2 >= tr.minVertexDistance *
                            tr.minVertexDistance) {
                        // Insert at the head — the tail slot drops
                        // when the buffer is full (upstream's
                        // insert-then-trim, same result).
                        val n = minOf(tr.count + 1, tr.maxPoints)
                        for (i in n - 1 downTo 1) {
                            tr.points[i * 3] = tr.points[(i - 1) * 3]
                            tr.points[i * 3 + 1] =
                                tr.points[(i - 1) * 3 + 1]
                            tr.points[i * 3 + 2] =
                                tr.points[(i - 1) * 3 + 2]
                            tr.born[i] = tr.born[i - 1]
                        }
                        tr.points[0] = hx
                        tr.points[1] = hy
                        tr.points[2] = hz
                        tr.born[0] = tr.time
                        tr.count = n
                    }
                }
            }
            while (tr.count > 0 &&
                tr.time - tr.born[tr.count - 1] > tr.lifetime) {
                tr.count--
            }
            // Refill the ribbon — port of expandTrailRibbon: two
            // verts per anchor, `side = normalize(tangent ×
            // toCamera)`, degenerate tangents reuse the last good
            // side, a camera on the point falls back to any
            // perpendicular.
            val buf = tr.staging
            buf.clear()
            val live = tr.count >= 2
            var sx = 1f; var sy = 0f; var sz = 0f
            if (live) {
                for (i in 0 until tr.count) {
                    val px = tr.points[i * 3]
                    val py = tr.points[i * 3 + 1]
                    val pz = tr.points[i * 3 + 2]
                    val prev = if (i == 0) 0 else i - 1
                    val next = if (i == tr.count - 1)
                        tr.count - 1 else i + 1
                    var tx = tr.points[prev * 3] -
                        tr.points[next * 3]
                    var ty = tr.points[prev * 3 + 1] -
                        tr.points[next * 3 + 1]
                    var tz = tr.points[prev * 3 + 2] -
                        tr.points[next * 3 + 2]
                    var tl2 = tx * tx + ty * ty + tz * tz
                    if (tl2 < 1e-12f && tr.count > 1) {
                        val j = if (i == 0) 0 else i - 1
                        val k = if (i == 0) 1 else i
                        tx = tr.points[j * 3] - tr.points[k * 3]
                        ty = tr.points[j * 3 + 1] -
                            tr.points[k * 3 + 1]
                        tz = tr.points[j * 3 + 2] -
                            tr.points[k * 3 + 2]
                        tl2 = tx * tx + ty * ty + tz * tz
                    }
                    if (tl2 >= 1e-12f) {
                        val vx = camPos[0] - px
                        val vy = camPos[1] - py
                        val vz = camPos[2] - pz
                        var cx = ty * vz - tz * vy
                        var cy = tz * vx - tx * vz
                        var cz = tx * vy - ty * vx
                        var cl2 = cx * cx + cy * cy + cz * cz
                        if (cl2 < 1e-12f) {
                            // Camera on the tangent — any
                            // perpendicular (tangent × up, then
                            // tangent × X).
                            cx = tz; cy = 0f; cz = -tx
                            cl2 = cx * cx + cz * cz
                            if (cl2 < 1e-12f) {
                                cx = 0f; cy = tz; cz = -ty
                                cl2 = cy * cy + cz * cz
                            }
                        }
                        if (cl2 >= 1e-12f) {
                            val inv = (1.0 / kotlin.math.sqrt(
                                cl2.toDouble())).toFloat()
                            sx = cx * inv; sy = cy * inv; sz = cz * inv
                        }
                    }
                    val t = if (tr.count > 1)
                        i.toFloat() / (tr.count - 1) else 0f
                    val w = tr.width *
                        sampleTrailKeys(tr.widthKeys, t)
                    val half = w * 0.5f
                    sampleTrailColor(tr.colorStops, t, colorScratch)
                    buf.putFloat(px + sx * half)
                    buf.putFloat(py + sy * half)
                    buf.putFloat(pz + sz * half)
                    buf.putFloat(colorScratch[0])
                    buf.putFloat(colorScratch[1])
                    buf.putFloat(colorScratch[2])
                    buf.putFloat(colorScratch[3])
                    buf.putFloat(px - sx * half)
                    buf.putFloat(py - sy * half)
                    buf.putFloat(pz - sz * half)
                    buf.putFloat(colorScratch[0])
                    buf.putFloat(colorScratch[1])
                    buf.putFloat(colorScratch[2])
                    buf.putFloat(colorScratch[3])
                }
            }
            // Dead verts collapse to zero width/alpha (upstream's
            // `_TrailGeometry.setTrail` zero-fill).
            while (buf.position() < buf.capacity()) buf.putFloat(0f)
            buf.rewind()
            tr.vertexBuffer.setBufferAt(host.engine, 0, buf)
            val want = live && !isHidden(key)
            if (want && !tr.inScene) {
                host.scene.addEntity(tr.entity)
                tr.inScene = true
            } else if (!want && tr.inScene) {
                host.scene.removeEntity(tr.entity)
                tr.inScene = false
            }
        }

        /**
         * Resolves the node's `lod` selection for this frame —
         * upstream `_resolveLod`: the circumscribed sphere of the
         * level-0 (highest-detail) world AABB projected through
         * `lodScreenSize`, biased by `lodBias`, then the first
         * threshold the size still meets; below the smallest is
         * the cull floor (a last threshold of `0` always meets →
         * never culls). A non-perspective camera — or an
         * unresolved level-0 geometry — falls back to highest
         * detail.
         */
        private fun updateLod(key: Long, rec: NodeRec,
                              lod: LodState, camPos: FloatArray,
                              fovRadY: Double, perspective: Boolean) {
            if (!perspective) {
                bindLodLevel(key, rec, 0)
                return
            }
            val gm = gpuMesh(lod.levels[0].geoKey)
            if (gm == null) {
                bindLodLevel(key, rec, 0)
                return
            }
            // World AABB of the level-0 bounds — transform the 8
            // corners (rotation and non-uniform scale both land).
            val m = FloatArray(16)
            tcm.getWorldTransform(tcm.getInstance(rec.entity), m)
            val b = gm.bounds
            var lx = Float.MAX_VALUE
            var ly = Float.MAX_VALUE
            var lz = Float.MAX_VALUE
            var hx = -Float.MAX_VALUE
            var hy = -Float.MAX_VALUE
            var hz = -Float.MAX_VALUE
            for (cxs in intArrayOf(-1, 1)) {
                for (cys in intArrayOf(-1, 1)) {
                    for (czs in intArrayOf(-1, 1)) {
                        val x = b[0] + b[3] * cxs
                        val y = b[1] + b[4] * cys
                        val z = b[2] + b[5] * czs
                        val wx = m[0] * x + m[4] * y + m[8] * z + m[12]
                        val wy = m[1] * x + m[5] * y + m[9] * z + m[13]
                        val wz = m[2] * x + m[6] * y + m[10] * z + m[14]
                        lx = minOf(lx, wx); hx = maxOf(hx, wx)
                        ly = minOf(ly, wy); hy = maxOf(hy, wy)
                        lz = minOf(lz, wz); hz = maxOf(hz, wz)
                    }
                }
            }
            val ccx = (lx + hx) * 0.5f
            val ccy = (ly + hy) * 0.5f
            val ccz = (lz + hz) * 0.5f
            // The circumscribed sphere — upstream's conservative
            // choice (detail kept slightly longer than a tight
            // sphere would).
            val rdx = hx - lx; val rdy = hy - ly; val rdz = hz - lz
            val radius = kotlin.math.sqrt(
                (rdx * rdx + rdy * rdy + rdz * rdz).toDouble()) * 0.5
            val ddx = ccx - camPos[0]
            val ddy = ccy - camPos[1]
            val ddz = ccz - camPos[2]
            val dist = kotlin.math.sqrt(
                (ddx * ddx + ddy * ddy + ddz * ddz).toDouble())
            // lodScreenSize: inside the sphere → infinite (highest
            // detail); else the sphere's angular share of the
            // viewport height.
            val size = if (dist <= radius) Double.MAX_VALUE
                else radius /
                    (dist * kotlin.math.tan(fovRadY * 0.5))
            val scaled = size * lod.lodBias
            var sel = -1
            for (i in lod.levels.indices) {
                if (scaled >= lod.levels[i].screenSize) {
                    sel = i
                    break
                }
            }
            bindLodLevel(key, rec, sel)
        }

        /**
         * Rebuilds the node's collider-facing geometry state —
         * positions concatenated, triangle indices re-based by each
         * primitive's vertex offset, bounds unioned — across the
         * primitives recorded in `meshPrimGeoKeys`. Returns false when
         * a primitive's GPU mesh is missing (caller keeps prior state).
         */
        private fun aggregateGeoState(rec: NodeRec): Boolean {
            val keys = rec.meshPrimGeoKeys ?: return false
            val prims = ArrayList<GpuMesh>(keys.size)
            for (k in keys) prims.add(gpuMeshes[k] ?: return false)
            var posLen = 0
            var idxLen = 0
            for (m in prims) {
                posLen += m.positions.size
                idxLen += m.indices.size
            }
            val pos = FloatArray(posLen)
            val idx = IntArray(idxLen)
            var posOff = 0
            var idxOff = 0
            var vertBase = 0
            val lo = floatArrayOf(Float.MAX_VALUE, Float.MAX_VALUE,
                Float.MAX_VALUE)
            val hi = floatArrayOf(-Float.MAX_VALUE, -Float.MAX_VALUE,
                -Float.MAX_VALUE)
            for (m in prims) {
                System.arraycopy(m.positions, 0, pos, posOff,
                    m.positions.size)
                for (j in m.indices.indices) {
                    idx[idxOff + j] = m.indices[j] + vertBase
                }
                vertBase += m.positions.size / 3
                posOff += m.positions.size
                idxOff += m.indices.size
                // m.bounds = (cx,cy,cz, hx,hy,hz) → AABB union.
                for (a in 0..2) {
                    lo[a] = minOf(lo[a], m.bounds[a] - m.bounds[a + 3])
                    hi[a] = maxOf(hi[a], m.bounds[a] + m.bounds[a + 3])
                }
            }
            rec.lastGeoPositions = pos
            rec.lastGeoIndices = idx
            rec.lastGeoBounds = FloatArray(6) { a ->
                if (a < 3) (lo[a] + hi[a]) / 2f
                else (hi[a - 3] - lo[a - 3]) / 2f
            }
            return true
        }

        private fun buildGpuMesh(md: MeshFactory.MeshData): GpuMesh {
            val vbBuilder = VertexBuffer.Builder()
                .vertexCount(md.vertexCount)
                .bufferCount(1)
                .attribute(VertexBuffer.VertexAttribute.POSITION, 0,
                    VertexBuffer.AttributeType.FLOAT3, 0, md.vertexStrideBytes)
                .attribute(VertexBuffer.VertexAttribute.TANGENTS, 0,
                    VertexBuffer.AttributeType.FLOAT4, 12, md.vertexStrideBytes)
            if (md.hasUvColor) {
                vbBuilder.attribute(VertexBuffer.VertexAttribute.UV0, 0,
                    VertexBuffer.AttributeType.FLOAT2, 28, md.vertexStrideBytes)
                vbBuilder.attribute(VertexBuffer.VertexAttribute.COLOR, 0,
                    VertexBuffer.AttributeType.FLOAT4, 36, md.vertexStrideBytes)
                // W21: uv1 tails the 60-byte base record (zero-filled
                // when the wire layout lacks TEXCOORD_1) — a slot's
                // `texCoord` selects between UV0/UV1 at sample time.
                vbBuilder.attribute(VertexBuffer.VertexAttribute.UV1, 0,
                    VertexBuffer.AttributeType.FLOAT2, 52, md.vertexStrideBytes)
            }
            if (md.hasSkinning) {
                // The skinned repack tails each 60-byte record with
                // [joints u16x4 @60 | weights f32x4 @68]. BONE_INDICES
                // must be an integer attribute — the shader consumes
                // uvec4 (Filament's VertexBuffer.attribute forces
                // FLAG_INTEGER_TARGET for it).
                vbBuilder.attribute(VertexBuffer.VertexAttribute.BONE_INDICES,
                    0, VertexBuffer.AttributeType.USHORT4, 60,
                    md.vertexStrideBytes)
                vbBuilder.attribute(VertexBuffer.VertexAttribute.BONE_WEIGHTS,
                    0, VertexBuffer.AttributeType.FLOAT4, 68,
                    md.vertexStrideBytes)
            }
            val vb = vbBuilder.build(host.engine)
            vb.setBufferAt(host.engine, 0, md.vertices)
            val indexType = if (md.indexWidth == MeshFactory.IndexWidth.UINT32) {
                IndexBuffer.Builder.IndexType.UINT
            } else {
                IndexBuffer.Builder.IndexType.USHORT
            }
            val ib = IndexBuffer.Builder()
                .indexCount(md.indexCount)
                .bufferType(indexType)
                .build(host.engine)
            ib.setBuffer(host.engine, md.indices)

            val pos = FloatArray(md.vertexCount * 3)
            md.vertices.rewind()
            for (i in 0 until md.vertexCount) {
                val base = i * md.vertexStrideBytes
                pos[i * 3] = md.vertices.getFloat(base)
                pos[i * 3 + 1] = md.vertices.getFloat(base + 4)
                pos[i * 3 + 2] = md.vertices.getFloat(base + 8)
            }
            md.vertices.rewind()
            val idx = IntArray(md.indexCount)
            if (md.indexWidth == MeshFactory.IndexWidth.UINT32) {
                val ints = md.indices.asIntBuffer()
                for (i in 0 until md.indexCount) idx[i] = ints.get(i)
            } else {
                val shorts = md.indices.asShortBuffer()
                for (i in 0 until md.indexCount) {
                    idx[i] = shorts.get(i).toInt() and 0xFFFF
                }
            }
            val primitive = when (md.topology) {
                MeshFactory.Topology.TRIANGLES -> RenderableManager.PrimitiveType.TRIANGLES
                MeshFactory.Topology.TRIANGLE_STRIP -> RenderableManager.PrimitiveType.TRIANGLE_STRIP
                MeshFactory.Topology.LINES -> RenderableManager.PrimitiveType.LINES
                MeshFactory.Topology.LINE_STRIP -> RenderableManager.PrimitiveType.LINE_STRIP
                MeshFactory.Topology.POINTS -> RenderableManager.PrimitiveType.POINTS
            }
            // W11: the decoded deltas become a MorphTargetBuffer —
            // float4 delta positions (+ packed absolute tangent quats
            // when declared) per target.
            var mtb: MorphTargetBuffer? = null
            md.morph?.let { morph ->
                val bb = MorphTargetBuffer.Builder()
                    .vertexCount(md.vertexCount)
                    .count(morph.targetCount)
                    .withPositions(true)
                if (morph.tangents != null) bb.withTangents(true)
                val buf = bb.build(host.engine)
                val n = md.vertexCount
                for (t in 0 until morph.targetCount) {
                    buf.setPositionsAt(host.engine, t,
                        morph.positions.copyOfRange(t * n * 4,
                            (t + 1) * n * 4), n)
                    morph.tangents?.let {
                        buf.setTangentsAt(host.engine, t,
                            it.copyOfRange(t * n * 4, (t + 1) * n * 4), n)
                    }
                }
                mtb = buf
            }
            return GpuMesh(
                vb, ib, md.vertexCount, md.indexCount, md.bounds, pos, idx,
                primitive,
                hasSkinning = md.hasSkinning,
                morphTargetBuffer = mtb,
                morphDefaults = md.morph?.defaultWeights ?: FloatArray(0),
                morphTargetCount = md.morph?.targetCount ?: 0)
        }

        private fun decodeCamera(key: Long, rec: NodeRec, p: JSONObject) {
            rec.isCamera = true
            // W14: every camera node's props are retained — view
            // cameras build per-view projections from nodeCameraProps
            // at frame time. The FIRST camera still claims the view's
            // Camera at install (the default path is unchanged).
            nodeCameraProps[key] = RenderTargets.CameraSpec.parse(p)
            if (firstCameraKey == null) {
                firstCameraKey = key
                cameraProps = p
            }
        }

        private fun decodeLight(
            rec: NodeRec, p: JSONObject, type: LightManager.Type,
        ) {
            val builder = LightManager.Builder(type)
            p.tag("color").d3Color()?.let {
                builder.color(it[0], it[1], it[2])
            }
            p.tag("intensity").d3Double()?.let {
                // SceneKit-scale unitless intensity → photometric units
                // (see the W21 constants at file top): directional lux,
                // point/spot lumens→candela.
                when (type) {
                    LightManager.Type.DIRECTIONAL -> builder.intensity(
                        (it * DIRECTIONAL_LUX_PER_UNIT).toFloat())
                    else -> builder.intensityCandela(
                        (it / FOUR_PI_STERADIANS).toFloat())
                }
            }
            p.tag("range").d3Double()?.let {
                builder.falloff(it.toFloat())
            }
            if (type == LightManager.Type.FOCUSED_SPOT) {
                val inner = (p.tag("innerConeAngle").d3Double() ?: 0.6)
                val outer = (p.tag("outerConeAngle").d3Double() ?: 0.8)
                builder.spotLightCone(inner.toFloat(), outer.toFloat())
            }
            if (p.tag("castsShadow").d3Bool() == true) {
                builder.castShadows(true)
                // Shadow tuning → LightManager.ShadowOptions. mapSize
                // pins ≥1024 whenever a light casts (Filament's own
                // default is smaller than SceneKit's effective map);
                // the 'high' view tier doubles it.
                val so = LightManager.ShadowOptions()
                so.mapSize =
                    if (host.viewQuality == "high") 2048 else 1024
                p.tag("shadowDepthBias").d3Double()?.let {
                    // SceneKit shadowBias is a single depth offset;
                    // Filament splits constant vs normal-scaled terms —
                    // the wire value lands on constantBias and half of
                    // it again on normalBias (2:1 split) so sloped
                    // receivers stay acne-free without peter-panning.
                    so.constantBias = it.toFloat()
                    so.normalBias = (it * 0.5).toFloat()
                }
                p.tag("shadowRadius").d3Double()?.let {
                    // PCSS penumbra driver — Filament's closest
                    // semantic to SceneKit's blur radius; an
                    // approximation, not equality.
                    so.shadowBulbRadius = it.toFloat()
                }
                builder.shadowOptions(so)
                Log.i(TAG, "shadow options: mapSize=${so.mapSize}" +
                    " bias=${so.constantBias} normalBias=${so.normalBias}" +
                    " bulbRadius=${so.shadowBulbRadius}")
            }
            builder.build(host.engine, rec.entity)
        }

        /**
         * W12 `rectAreaLight` — Filament exposes no area light type in
         * this path, so the approximation is a cluster of four point
         * lights on child entities at the rectangle's corners
         * (±w/2, ±h/2 in the light node's local frame), each carrying
         * a quarter of the declared intensity. The visible emitter is
         * document-authored (an emissive mesh on the same node) — the
         * approximation covers the lighting contribution only.
         */
        private fun decodeRectAreaLight(key: Long, rec: NodeRec, p: JSONObject) {
            val w = (p.tag("width").d3Double() ?: 1.0).toFloat()
            val h = (p.tag("height").d3Double() ?: 1.0).toFloat()
            val color = p.tag("color").d3Color()
                ?: floatArrayOf(1f, 1f, 1f, 1f)
            // Each cluster member takes a quarter of the declared
            // lumens, then the same lumens→candela conversion decodeLight
            // applies to point lights (flux over the 4π sr sphere).
            val intensityCandela =
                ((p.tag("intensity").d3Double() ?: 1.0) / 4.0 /
                    FOUR_PI_STERADIANS).toFloat()
            val range = (p.tag("range").d3Double() ?: 10.0).toFloat()
            val identQ = floatArrayOf(0f, 0f, 0f, 1f)
            val unitS = floatArrayOf(1f, 1f, 1f)
            for ((sx, sy) in listOf(-1f to -1f, 1f to -1f,
                                    -1f to 1f, 1f to 1f)) {
                val child = em.create()
                LightManager.Builder(LightManager.Type.POINT)
                    .color(color[0], color[1], color[2])
                    .intensityCandela(intensityCandela)
                    .falloff(range)
                    .build(host.engine, child)
                tcm.setTransform(
                    tcm.create(child),
                    D3Wire.trs(
                        floatArrayOf(sx * w / 2f, sy * h / 2f, 0f),
                        identQ, unitS))
                tcm.setParent(
                    tcm.getInstance(child), tcm.getInstance(rec.entity))
                host.scene.addEntity(child)
                rec.lightEntities.add(child)
            }
            logOnce("rectAreaLight:$key",
                "rectAreaLight on node $key: approximated by a 4-point " +
                    "cluster (${w}×${h}); Filament has no area light type")
        }

        // MARK: Material variants (W12)

        /**
         * Decodes a `materialsVariants` component (upstream
         * `KHR_materials_variants`): variant names, the selected name,
         * and bindings — each a node ref + primitive index + declared
         * default + a variant-index → material map. Bindings resolve
         * at apply time so a target that lands later still binds.
         */
        private fun decodeMaterialsVariants(
            key: Long, index: Int, props: JSONObject,
        ) {
            val variants = mutableListOf<String>()
            props.tag("variants").d3List()?.let { list ->
                for (i in 0 until list.length()) {
                    (list.opt(i) as? JSONObject)?.optString("s")
                        ?.takeIf { it.isNotEmpty() }
                        ?.let { variants.add(it) }
                }
            }
            val bindings = mutableListOf<VariantBinding>()
            props.tag("bindings").d3List()?.let { list ->
                for (i in 0 until list.length()) {
                    val m = (list.opt(i) as? JSONObject)?.d3Map()
                        ?: continue
                    val nodeKey = m.tag("node").d3Ref() ?: continue
                    val primitive = m.tag("primitive").d3Int()
                        ?: continue
                    if (primitive < 0) continue
                    val byVariant = HashMap<Int, Long>()
                    m.tag("materials").d3Map()?.let { mats ->
                        for (name in mats.keys()) {
                            val idx = name.toIntOrNull() ?: continue
                            val mk = mats.tag(name).d3Ref() ?: continue
                            byVariant[idx] = mk
                        }
                    }
                    bindings.add(VariantBinding(
                        nodeKey = nodeKey, primitive = primitive,
                        defaultMaterialKey = m.tag("default").d3Ref(),
                        materialsByVariant = byVariant))
                }
            }
            variantComponents[key] = VariantComponent(
                nodeKey = key, compIndex = index, variants = variants,
                selected = props.tag("selected").d3String(),
                bindings = bindings)
            logOnce("variants:$key:$index",
                "materialsVariants on node $key: ${variants.size} " +
                    "variants, ${bindings.size} bindings, " +
                    "selected=${props.tag("selected").d3String() ?: "-"}")
        }

        /**
         * Applies every variant component's selection — after the
         * manifest node pass, after a surgical components decode, and
         * from the `selectVariant` op. Unresolved bindings stay pending
         * and retry on node/geometry landings.
         */
        fun applyVariantComponents() {
            for ((_, vc) in variantComponents.toMap()) {
                val selIdx = vc.selected?.let { vc.variants.indexOf(it) }
                    ?.takeIf { it >= 0 }
                for (b in vc.bindings) {
                    applyVariantBinding(b, selIdx)
                }
            }
        }

        /** One binding → `setMaterialInstanceAt(primitive)` on the
         *  target node's renderable. Upstream's rebase rule: a slot
         *  content that is neither this binding's last write nor a
         *  variant-mapped material wins and becomes the new default. */
        private fun applyVariantBinding(
            b: VariantBinding, variantIndex: Int?,
        ) {
            val rec = nodes[b.nodeKey] ?: run {
                logOnce("variant.unresolved:${b.nodeKey}",
                    "materialsVariants binding: node ${b.nodeKey} not " +
                        "live yet; pending")
                return
            }
            val rm = host.engine.renderableManager
            if (!rm.hasComponent(rec.entity)) {
                logOnce("variant.norenderable:${b.nodeKey}",
                    "materialsVariants binding: node ${b.nodeKey} has " +
                        "no renderable yet; pending")
                return
            }
            val ri = rm.getInstance(rec.entity)
            if (b.primitive >= rm.getPrimitiveCount(ri)) {
                b.resolved = true
                logOnce("variant.binding:${b.nodeKey}:${b.primitive}",
                    "materialsVariants binding: node ${b.nodeKey} has " +
                        "no primitive ${b.primitive}; dropped")
                return
            }
            if (b.defaultMaterial == null) {
                b.defaultMaterial = b.defaultMaterialKey
                    ?.let { materials[it] }
            }
            // getMaterialInstanceAt wraps the native instance fresh per
            // call — compare native pointers, not Kotlin identity.
            val current = rm.getMaterialInstanceAt(ri, b.primitive)
            val cur = current?.getNativeObject() ?: 0L
            val variantPtrs = b.materialsByVariant.values
                .mapNotNullTo(HashSet()) { materials[it]?.getNativeObject() }
            if (cur != 0L && cur != (b.applied?.getNativeObject() ?: 0L)
                && cur != (b.defaultMaterial?.getNativeObject() ?: 0L)
                && cur !in variantPtrs) {
                b.defaultMaterial = current
            }
            val variantKey = variantIndex?.let { b.materialsByVariant[it] }
            val target = variantKey?.let { materials[it] }
                ?: b.defaultMaterial ?: current ?: return
            Log.i(TAG, "variant apply node=${b.nodeKey} " +
                "prim=${b.primitive} selIdx=$variantIndex " +
                "vkey=$variantKey vmap=${b.materialsByVariant.size} " +
                "target=" + (if (target === b.defaultMaterial) "default"
                    else if (variantKey != null &&
                        target.getNativeObject() ==
                            (materials[variantKey]?.getNativeObject()
                                ?: -1L)) "variant" else "current"))
            rm.setMaterialInstanceAt(ri, b.primitive, target)
            b.applied = target
            b.resolved = true
        }

        /**
         * W12: tagged joint-component props → the command-joint wire
         * shape [Dart3dView.decodeJoint] consumes (untagged fields —
         * `anchorA`/`axisA`/`basisA` raw arrays, `lower`/`upper` raw
         * doubles — because decodeJoint applies the LH→RH mirror and
         * the per-type limit/motor rules). Upstream component names:
         * `otherNode` (absent → `worldAnchor`), `localAnchorA/B`,
         * `localAxisA/B`, `localBasisA/B`, `collisionsEnabled`,
         * `lowerLimit`/`upperLimit`, `motorTargetVelocity`,
         * `motorMaxForce`, and `axes` (a map keyed `linearX..angularZ`
         * with `lowerLimit`/`upperLimit`/`motor` entries — translated
         * into the 6-element list the command shape expects).
         */
        private fun translateJointComponent(
            key: Long, type: String, props: JSONObject,
        ): JSONObject? {
            val out = JSONObject()
            out.put("type", when (type) {
                "fixedJoint" -> "fixed"
                "sphericalJoint" -> "spherical"
                "revoluteJoint" -> "revolute"
                "prismaticJoint" -> "prismatic"
                "genericJoint" -> "generic"
                else -> return null
            })
            out.put("a", D3Wire.localIdToken(key))
            val other = props.tag("otherNode").d3Ref()
            if (other != null) {
                out.put("b", D3Wire.localIdToken(other))
            } else {
                // Upstream: an absent otherNode anchors to the world.
                out.put("worldAnchor", true)
            }
            out.put("collide",
                props.tag("collisionsEnabled").d3Bool() ?: false)
            fun putVec(name: String, outName: String) {
                props.tag(name).d3Vec3()?.let { v ->
                    if (v.size == 3) out.put(outName, JSONArray(
                        listOf(v[0], v[1], v[2])))
                }
            }
            fun putQuat(name: String, outName: String) {
                props.tag(name).d3Vec4()?.let { v ->
                    if (v.size == 4) out.put(outName, JSONArray(
                        listOf(v[0], v[1], v[2], v[3])))
                }
                // A `{'q':[…]}` tag (QuaternionValue) — same payload.
                (props.tag(name) as? JSONObject)?.optJSONArray("q")
                    ?.let { a ->
                        if (a.length() == 4) out.put(outName, a)
                    }
            }
            fun putDouble(name: String, outName: String) {
                props.tag(name).d3Double()?.let { out.put(outName, it) }
            }
            putVec("localAnchorA", "anchorA")
            putVec("localAnchorB", "anchorB")
            putVec("localAxisA", "axisA")
            putVec("localAxisB", "axisB")
            if (type == "revoluteJoint" || type == "prismaticJoint") {
                // Upstream `_axisField` default — Vector3(1, 0, 0).
                val x = JSONArray(listOf(1.0, 0.0, 0.0))
                if (!out.has("axisA")) out.put("axisA", x)
                if (!out.has("axisB")) out.put("axisB",
                    JSONArray(listOf(1.0, 0.0, 0.0)))
            }
            putQuat("localBasisA", "basisA")
            putQuat("localBasisB", "basisB")
            putDouble("lowerLimit", "lower")
            putDouble("upperLimit", "upper")
            putDouble("motorTargetVelocity", "motorVelocity")
            putDouble("motorMaxForce", "motorMaxForce")
            if (type == "genericJoint") {
                val map = props.tag("axes").d3Map()
                if (map != null) {
                    val order = listOf("linearX", "linearY", "linearZ",
                        "angularX", "angularY", "angularZ")
                    val arr = JSONArray()
                    for (axisName in order) {
                        val a = map.tag(axisName).d3Map()
                        if (a == null) { arr.put(JSONObject.NULL)
                            ; continue }
                        val entry = JSONObject()
                        a.tag("motion").d3String()
                            ?.let { entry.put("motion", it) }
                        a.tag("lowerLimit").d3Double()
                            ?.let { entry.put("lower", it) }
                        a.tag("upperLimit").d3Double()
                            ?.let { entry.put("upper", it) }
                        a.tag("motor").d3Map()?.let { m ->
                            val motor = JSONObject()
                            m.tag("targetPosition").d3Double()
                                ?.let { motor.put("targetPosition", it) }
                            m.tag("targetVelocity").d3Double()
                                ?.let { motor.put("targetVelocity", it) }
                            m.tag("stiffness").d3Double()
                                ?.let { motor.put("stiffness", it) }
                            m.tag("damping").d3Double()
                                ?.let { motor.put("damping", it) }
                            m.tag("maxForce").d3Double()
                                ?.let { motor.put("maxForce", it) }
                            m.tag("model").d3String()
                                ?.let { motor.put("model", it) }
                            entry.put("motor", motor)
                        }
                        arr.put(entry)
                    }
                    out.put("axes", arr)
                }
            }
            return out
        }

        // MARK: Physics (deferred — colliders may read realized meshes)

        /** Per-node collider decode result, consumed by decodeRigidBody. */
        private class ColliderData(
            val shape: ConstShape?,
            val friction: Float,
            val restitution: Float,
            val layer: Int,
            val mask: Int,
            val isTrigger: Boolean,
        )

        fun decodePhysicsDeferred() {
            val colliders = HashMap<Long, ColliderData>()
            for (item in physicsDeferred) {
                if (item.type == "collider") {
                    colliders[item.key] = decodeCollider(item.rec, item.props)
                }
            }
            for (item in physicsDeferred) {
                if (item.type == "rigidBody") {
                    decodeRigidBody(item.key, item.rec, item.props,
                        colliders[item.key])
                }
            }
            for (item in physicsDeferred) {
                if (item.type == "physicsWorld") {
                    decodePhysicsWorld(item.props)
                }
            }
            // W12 joint components ride the command-joint registry —
            // the host's registerComponentJoint decodes the translated
            // command-shaped spec and defers until both bodies live.
            for (item in jointComponentsDeferred) {
                translateJointComponent(item.key, item.type, item.props)
                    ?.let {
                        host.registerComponentJoint(item.key, item.index, it)
                    }
            }
            jointComponentsDeferred.clear()
            for ((key, rec) in nodes) {
                val b = rec.body
                val kind = b?.motionType?.toString() ?: "none"
                val p = nodeWorld[key] ?: continue
                Log.i(TAG, "node $key: body=$kind pos=(${p[12]},${p[13]},${p[14]})")
            }
        }

        private fun decodeCollider(rec: NodeRec, p: JSONObject): ColliderData {
            // Surface material: friction/restitution/density plus the
            // combine rules (Jolt applies them per-system — the closest
            // expressible mapping — so they route through JoltWorld).
            val mat = p.tag("material").d3Map()
            val friction = (mat?.tag("friction")?.d3Double() ?: 0.5).toFloat()
            val restitution = (mat?.tag("restitution")?.d3Double() ?: 0.0).toFloat()
            val density = (mat?.tag("density")?.d3Double() ?: 1.0).toFloat()
            applyCombineRule("frictionCombine",
                mat?.tag("frictionCombine")?.d3String() ?: "average") {
                host.world.setFrictionCombine(it)
            }
            applyCombineRule("restitutionCombine",
                mat?.tag("restitutionCombine")?.d3String() ?: "average") {
                host.world.setRestitutionCombine(it)
            }
            var shape = decodeShape(rec, p.tag("shape"), density)
            p.tag("localPose").d3Mat4()?.let { m ->
                val built = shape
                if (m.size == 16 && built != null) {
                    val (pos, rot) = localPoseOf(m)
                    if (pos[0] != 0f || pos[1] != 0f || pos[2] != 0f ||
                        rot[0] != 0f || rot[1] != 0f || rot[2] != 0f || rot[3] != 1f) {
                        shape = RotatedTranslatedShapeSettings(
                            Vec3(pos[0], pos[1], pos[2]),
                            Quat(rot[0], rot[1], rot[2], rot[3]), built,
                        ).create().get()
                    }
                }
            }
            return ColliderData(
                shape,
                friction,
                restitution,
                layer = p.tag("collisionLayer").d3Int() ?: -1,
                mask = p.tag("collisionMask").d3Int() ?: -1,
                isTrigger = p.tag("isTrigger").d3Bool() ?: false,
            )
        }

        private inline fun applyCombineRule(
            field: String, rule: String, apply: (String) -> Boolean,
        ) {
            if (!apply(rule)) {
                logOnce("combine:$field:$rule",
                    "collider material $field '$rule' isn't expressible in Jolt; using 'average'")
                apply("average")
            }
        }

        /**
         * Decodes the collider `shape` tagged union (`{'map':{kind,…}}`).
         * [density] comes from collider.material; Jolt multiplies it by
         * the shape's volume for derived body mass — it applies where
         * the shape exposes it (convex shapes; not meshes/compound
         * interiors beyond their children).
         */
        private fun decodeShape(
            rec: NodeRec, shapeVal: Any?, density: Float,
        ): ConstShape? {
            val map = shapeVal.d3Map()
            val kind = map?.tag("kind")?.d3String()
            if (map == null || kind == null) {
                // Upstream falls back to the unit box on a bad union.
                Log.w(TAG, "collider 'shape' is missing or malformed; using unit box")
                return BoxShape(Vec3(0.5f, 0.5f, 0.5f))
            }
            return when (kind) {
                // halfExtents arrive already halved — feed Jolt directly.
                "box" -> {
                    val e = map.tag("halfExtents").d3Vec3()
                        ?: doubleArrayOf(0.5, 0.5, 0.5)
                    BoxShape(Vec3(
                        e[0].toFloat(), e[1].toFloat(), e[2].toFloat()))
                        .apply { setDensity(density) }
                }
                "sphere" -> SphereShape(
                    (map.tag("radius").d3Double() ?: 0.5).toFloat())
                        .apply { setDensity(density) }
                "capsule" -> {
                    val r = (map.tag("radius").d3Double() ?: 0.5).toFloat()
                    // Upstream halfHeight IS Jolt's cylindrical
                    // half-height — no h/2-r reduction.
                    val hh = (map.tag("halfHeight").d3Double() ?: 0.5).toFloat()
                    CapsuleShape(hh, r).apply { setDensity(density) }
                }
                "cylinder" -> {
                    val r = (map.tag("radius").d3Double() ?: 0.5).toFloat()
                    val hh = (map.tag("halfHeight").d3Double() ?: 0.5).toFloat()
                    CylinderShape(hh, r).apply { setDensity(density) }
                }
                "convexHull" -> {
                    val token = payloadToken(map.tag("vertices"))
                        ?: payloadToken(map.tag("points"))
                    val payloadPositions = token?.let {
                        decodeColliderPositions("convexHull", it)
                    }
                    val pos = payloadPositions ?: hullPositions(rec)
                    if (pos != null) {
                        try {
                            ConvexHullShapeSettings(
                                pos.size / 3, floatBufferOf(pos))
                                .apply { setDensity(density) }
                                .create().get()
                        } catch (e: Exception) {
                            if (payloadPositions != null) {
                                warnOnce("collider:convexHull:create:${e.message}",
                                    "collider 'convexHull': malformed payload (${e.message}); deriving from node geometry")
                                val fallback = hullPositions(rec)
                                if (fallback != null && fallback !== payloadPositions) {
                                    try {
                                        ConvexHullShapeSettings(
                                            fallback.size / 3, floatBufferOf(fallback))
                                            .apply { setDensity(density) }
                                            .create().get()
                                    } catch (fallbackError: Exception) {
                                        warnOnce("collider:convexHull:fallback:${fallbackError.message}",
                                            "collider 'convexHull': node geometry is not a valid hull: ${fallbackError.message}")
                                        null
                                    }
                                } else null
                            } else {
                                Log.w(TAG, "collider 'convexHull': invalid hull: ${e.message}")
                                null
                            }
                        }
                    } else {
                        Log.w(TAG, "collider 'convexHull': node has no geometry")
                        null
                    }
                }
                "triMesh" -> {
                    val vertexToken = payloadToken(map.tag("vertices"))
                    val indexToken = payloadToken(map.tag("indices"))
                    if (vertexToken != null || indexToken != null) {
                        if (vertexToken == null || indexToken == null) {
                            warnOnce("collider:triMesh:tokens",
                                "collider 'triMesh': payload vertices and indices must both be present; deriving from node geometry")
                            meshShape(rec, kind)
                        } else {
                            val pos = decodeColliderPositions("triMesh", vertexToken)
                            val idx = decodeColliderIndices("triMesh", indexToken)
                            if (pos != null && idx != null) {
                                meshShape(pos, idx, kind) ?: meshShape(rec, kind)
                            } else {
                                meshShape(rec, kind)
                            }
                        }
                    } else {
                        meshShape(rec, kind)
                    }
                }
                "concaveMesh" -> meshShape(rec, kind)
                "compound" -> compoundShape(rec, map, density)
                // Extension kind: a box derived from the node's realized
                // geometry — the historical dart3d default.
                "boundingBox" -> boundingBoxShape(rec, density)
                "heightField" -> {
                    logOnce("heightField",
                        "collider 'heightField' is deferred to W3; skipping")
                    null
                }
                else -> { Log.w(TAG, "unknown collider shape '$kind'"); null }
            }
        }

        private fun payloadToken(value: Any?): String? =
            (value as? String)?.takeIf { it.isNotEmpty() } ?: value.d3String()

        private fun decodeColliderPositions(kind: String, token: String): FloatArray? {
            val key = D3Wire.localIdKey(token)
            if (key == null) {
                warnOnce("collider:$kind:vertexToken:$token",
                    "collider '$kind': invalid vertices payload token '$token'; deriving from node geometry")
                return null
            }
            val meta = payloadSpecs[key]
            if (meta == null) {
                warnOnce("collider:$kind:vertexSpec:$token",
                    "collider '$kind': vertices payload '$token' has no manifest spec; deriving from node geometry")
                return null
            }
            val bytes = host.payloadStore[key] ?: return null
            return try {
                when (meta.encoding) {
                    "floats" -> {
                        if (bytes.isEmpty() || bytes.size % 12 != 0) {
                            throw MeshFactory.PayloadDecodeException(
                                "float vertex payload length ${bytes.size} is not divisible by 12")
                        }
                        val input = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
                        FloatArray(bytes.size / 4) { i ->
                            val value = input.getFloat(i * 4)
                            if (i % 3 == 2) -value else value
                        }
                    }
                    "vertexBuffer" -> MeshFactory.positionsFromPayload(bytes, meta.layout)
                    else -> throw MeshFactory.PayloadDecodeException(
                        "vertices payload encoding '${meta.encoding}' is not floats or vertexBuffer")
                }
            } catch (e: MeshFactory.PayloadDecodeException) {
                warnOnce("collider:$kind:vertices:${e.message}",
                    "collider '$kind': ${e.message}; deriving from node geometry")
                null
            } catch (e: Exception) {
                warnOnce("collider:$kind:vertices:${e.javaClass.name}",
                    "collider '$kind': malformed vertices payload; deriving from node geometry")
                null
            }
        }

        private fun decodeColliderIndices(kind: String, token: String): IntArray? {
            val key = D3Wire.localIdKey(token)
            if (key == null) {
                warnOnce("collider:$kind:indexToken:$token",
                    "collider '$kind': invalid indices payload token '$token'; deriving from node geometry")
                return null
            }
            val meta = payloadSpecs[key]
            if (meta == null) {
                warnOnce("collider:$kind:indexSpec:$token",
                    "collider '$kind': indices payload '$token' has no manifest spec; deriving from node geometry")
                return null
            }
            if (meta.encoding != "indexBuffer") {
                warnOnce("collider:$kind:indexEncoding:${meta.encoding}",
                    "collider '$kind': indices payload encoding '${meta.encoding}' is not indexBuffer; deriving from node geometry")
                return null
            }
            val bytes = host.payloadStore[key] ?: return null
            return try {
                MeshFactory.indicesFromPayload(bytes, meta.format)
            } catch (e: MeshFactory.PayloadDecodeException) {
                warnOnce("collider:$kind:indices:${e.message}",
                    "collider '$kind': ${e.message}; deriving from node geometry")
                null
            }
        }

        /** MeshShape from the node's realized geometry (static bodies only). */
        private fun meshShape(rec: NodeRec, kind: String): ConstShape? {
            val pos = rec.lastGeoPositions
            val idx = rec.lastGeoIndices
            if (pos == null || idx == null) {
                Log.w(TAG, "collider '$kind': node has no geometry")
                return null
            }
            return meshShape(pos, idx, kind)
        }

        private fun meshShape(pos: FloatArray, idx: IntArray, kind: String): ConstShape? {
            if (pos.isEmpty() || pos.size % 3 != 0 || idx.size < 3 || idx.size % 3 != 0) {
                warnOnce("collider:$kind:meshCounts:${pos.size}:${idx.size}",
                    "collider '$kind': malformed triangle-list payload; deriving from node geometry")
                return null
            }
            val vertexCount = pos.size / 3
            if (idx.any { it < 0 || it >= vertexCount }) {
                warnOnce("collider:$kind:meshIndexRange",
                    "collider '$kind': payload index is outside vertex count $vertexCount; deriving from node geometry")
                return null
            }
            return try {
                val verts = VertexList().apply {
                    resize(vertexCount)
                    for (i in 0 until vertexCount) {
                        set(i, pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
                    }
                }
                val tris = IndexedTriangleList().apply {
                    resize(idx.size / 3)
                    for (t in 0 until idx.size / 3) {
                        set(t, IndexedTriangle(
                            idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]))
                    }
                }
                MeshShapeSettings(verts, tris).create().get()
            } catch (e: Exception) {
                warnOnce("collider:$kind:meshCreate:${e.message}",
                    "collider '$kind': invalid triangle mesh (${e.message}); deriving from node geometry")
                null
            }
        }

        /** StaticCompoundShape of `{shape, localPose}` children. */
        private fun compoundShape(
            rec: NodeRec, map: JSONObject, density: Float,
        ): ConstShape? {
            val children = map.tag("children").d3List()
            if (children == null || children.length() == 0) {
                Log.w(TAG, "collider 'compound': no children")
                return null
            }
            val settings = StaticCompoundShapeSettings()
            var added = 0
            for (i in 0 until children.length()) {
                val entry = children.opt(i).d3Map() ?: continue
                val child = decodeShape(rec, entry.tag("shape"), density)
                    ?: continue
                val (pos, rot) = entry.tag("localPose").d3Mat4()
                    ?.takeIf { it.size == 16 }
                    ?.let { localPoseOf(it) }
                    ?: Pair(floatArrayOf(0f, 0f, 0f), floatArrayOf(0f, 0f, 0f, 1f))
                settings.addShape(
                    Vec3(pos[0], pos[1], pos[2]),
                    Quat(rot[0], rot[1], rot[2], rot[3]), child)
                added++
            }
            if (added == 0) {
                Log.w(TAG, "collider 'compound': no children decoded")
                return null
            }
            return settings.create().get()
        }

        /**
         * matrix4 `localPose` → RH position + quaternion. The wire's
         * S·M·S handedness flip is the same one node matrices take;
         * scale is dropped (a pose is rigid).
         */
        private fun localPoseOf(m: DoubleArray): Pair<FloatArray, FloatArray> {
            val d = decompose(D3Wire.matrix(m))
            return Pair(d[0], d[1])
        }

        private fun hullPositions(rec: NodeRec): FloatArray? =
            rec.lastGeoPositions

        private fun boundingBoxShape(rec: NodeRec, density: Float): ConstShape? {
            val b = rec.lastGeoBounds ?: return null
            val box = BoxShape(Vec3(b[3], b[4], b[5]))
            box.setDensity(density)
            // bounds are (center, halfExtents) — an off-center mesh gets
            // its collider translated to the box center.
            if (b[0] == 0f && b[1] == 0f && b[2] == 0f) return box
            return RotatedTranslatedShape(
                Vec3(b[0], b[1], b[2]), Quat.sIdentity(), box)
        }

        private fun decodeRigidBody(
            key: Long, rec: NodeRec, p: JSONObject,
            collider: ColliderData?,
        ) {
            val type = p.tag("type").d3String() ?: "dynamic"
            var motionType = when (type) {
                "fixed" -> EMotionType.Static
                "kinematic" -> EMotionType.Kinematic
                "dynamic" -> EMotionType.Dynamic
                else -> {
                    Log.w(TAG, "rigidBody type '$type' unknown; using dynamic")
                    EMotionType.Dynamic
                }
            }
            // MeshShapes have no mass properties — Jolt only accepts
            // them on static bodies (upstream marks triMesh static-only).
            if (collider?.shape?.mustBeStatic() == true &&
                motionType != EMotionType.Static) {
                Log.w(TAG, "rigidBody on a static-only collider; forcing 'fixed'")
                motionType = EMotionType.Static
            }
            // Jolt requires a shape; SceneKit tolerates a nil one. A
            // collider whose geometry is still deferred (or failed to
            // decode) resolves to no shape here — the body materializes
            // on the payload-arrival re-realize instead of crashing on
            // a shapeless BodyCreationSettings.
            val shape = collider?.shape
            if (shape == null) {
                Log.w(TAG, "node $key: collider has no shape yet; body deferred")
                return
            }
            val bcs = BodyCreationSettings()
            bcs.setShape(shape)
            bcs.setMotionType(motionType)
            bcs.setObjectLayer(
                if (motionType == EMotionType.Static) JoltWorld.OBJ_NON_MOVING
                else JoltWorld.OBJ_MOVING)
            // Every body shares the world's GroupFilterTable so the
            // upstream layer/mask rule holds pair-wise.
            host.world.collisionGroup(
                collider?.layer ?: -1, collider?.mask ?: -1)
                ?.let { bcs.setCollisionGroup(it) }
            if (collider?.isTrigger == true) bcs.setIsSensor(true)
            val wm = nodeWorld[key] ?: FloatArray(16).also {
                Matrix.setIdentityM(it, 0)
            }
            val (wp, wq) = worldPoseOf(wm)
            bcs.setPosition(RVec3(wp[0].toDouble(), wp[1].toDouble(), wp[2].toDouble()))
            bcs.setRotation(Quat(wq[0], wq[1], wq[2], wq[3]))
            p.tag("mass").d3Double()?.let {
                bcs.massPropertiesOverride.setMass(it.toFloat())
                bcs.setOverrideMassProperties(
                    EOverrideMassProperties.CalculateInertia)
            }
            collider?.let {
                bcs.setFriction(it.friction)
                bcs.setRestitution(it.restitution)
            }
            p.tag("linearDamping").d3Double()?.let {
                bcs.setLinearDamping(it.toFloat())
            }
            p.tag("angularDamping").d3Double()?.let {
                bcs.setAngularDamping(it.toFloat())
            }
            p.tag("useGravity").d3Bool()?.let {
                if (!it) bcs.setGravityFactor(0f)
            }
            p.tag("ccdEnabled").d3Bool()?.let {
                if (it) bcs.setMotionQuality(EMotionQuality.LinearCast)
            }
            // allowsResting=false (SCNPhysicsBody) → Jolt never puts
            // the body to sleep. Absent/true keeps Jolt's default.
            if (p.tag("allowsResting").d3Bool() == false) {
                bcs.setAllowSleeping(false)
                Log.i(TAG, "node $key: allowsResting=false → allowSleeping=false")
            }
            // Axis locks (1 = free, 0 = locked) map onto Jolt's
            // allowedDOFs bitmask on BodyCreationSettings.
            val lin = p.tag("linearAxisLocks").d3Vec3()
            val ang = p.tag("angularAxisLocks").d3Vec3()
            if (lin != null || ang != null) {
                var dofs = EAllowedDofs.All
                if (lin != null && lin.size >= 3) {
                    if (lin[0] == 0.0) dofs = dofs and EAllowedDofs.TranslationX.inv()
                    if (lin[1] == 0.0) dofs = dofs and EAllowedDofs.TranslationY.inv()
                    if (lin[2] == 0.0) dofs = dofs and EAllowedDofs.TranslationZ.inv()
                }
                if (ang != null && ang.size >= 3) {
                    if (ang[0] == 0.0) dofs = dofs and EAllowedDofs.RotationX.inv()
                    if (ang[1] == 0.0) dofs = dofs and EAllowedDofs.RotationY.inv()
                    if (ang[2] == 0.0) dofs = dofs and EAllowedDofs.RotationZ.inv()
                }
                if (dofs != EAllowedDofs.All) bcs.setAllowedDofs(dofs)
            }
            // dart3d extensions: initial velocities, which upstream
            // deliberately does not persist. Linear velocity converts
            // through the z-mirror; angular axis+rate mirrors the axis
            // like a quaternion axis.
            p.tag("velocity").d3Vec3()?.let { v ->
                val c = D3Wire.position(v)
                bcs.setLinearVelocity(Vec3(c[0], c[1], c[2]))
            }
            p.tag("angularVelocity").d3Vec4()?.let { a ->
                bcs.setAngularVelocity(Vec3(
                    (-a[0] * a[3]).toFloat(),
                    (-a[1] * a[3]).toFloat(),
                    (a[2] * a[3]).toFloat()))
            }
            val body = host.world.addBody(
                bcs, activate = motionType == EMotionType.Dynamic,
                nodeKey = key)
            rec.body = body
            bodies[key] = body
            if (motionType == EMotionType.Dynamic) dynamicBodyKeys.add(key)
        }

        private fun decodePhysicsWorld(p: JSONObject) {
            p.tag("backend").d3String()?.let {
                logOnce("backend:$it",
                    "physicsWorld backend '$it' requested; Android always uses Jolt")
            }
            p.tag("gravity").d3Vec3()?.let { g ->
                val v = D3Wire.position(g)
                host.world.setGravity(v[0], v[1], v[2])
            }
            p.tag("fixedTimestep").d3Double()?.let {
                if (it > 0.0) host.world.fixedTimestep = it.toFloat()
            }
            p.tag("maxSubsteps").d3Int()?.let {
                if (it >= 1) host.world.maxSubsteps = it
            }
        }

        // MARK: W5 surgical node ops (shared-maps Context)

        /**
         * `addNode` — decodes one manifest-shape node spec into the
         * live registries, attaches it under [parentKey] (null → scene
         * root), and runs its deferred physics. `spec.children` is NOT
         * wired — each child self-attaches via its own addNode's
         * parent field, so ops are order-independent within a batch.
         */
        fun addNode(key: Long, spec: JSONObject, parentKey: Long?) {
            val rec = decodeNode(key, spec)
            attachNode(key, rec, parentKey)
            resolveParentClaims(key, rec)
            decodeNodePhysics(key)
            applyVariantComponents()
            applyVisibility(key)
        }

        /**
         * `updateNode` — applies only the flagged spec fields (`flags`
         * are upstream NodeChange field names). `reparented` reads
         * [parentKey] (null → root); `components` tears down the
         * realized component state — renderable, light, consumer
         * entries, camera claim, physics body — then re-decodes the
         * components array, so a rebuilt rigid body is a replace
         * matching upstream's component re-realize.
         */
        fun updateNode(
            key: Long, flags: Set<String>,
            spec: JSONObject, parentKey: Long?,
        ) {
            val rec = nodes[key] ?: return
            if ("name" in flags) {
                rec.name = spec.optString("name").takeIf { it.isNotEmpty() }
            }
            if ("reparented" in flags) {
                attachNode(key, rec, parentKey)
                // The body tracks the node's world pose — re-teleport
                // through the new parent chain.
                rec.body?.let { body ->
                    val (wp, wq) = worldPoseOf(worldMatOf(key))
                    host.world.teleport(body, wp, wq)
                }
            }
            if ("transform" in flags) {
                val trs = decodeTrs(spec.optJSONObject("transform"))
                rec.localPos = trs[0]
                rec.localQuat = trs[1]
                rec.localScale = trs[2]
                host.applyLocalTransform(rec)
            }
            if ("layers" in flags) {
                rec.layers = spec.optInt("layers", 1)
                val rm = host.engine.renderableManager
                if (rm.hasComponent(rec.entity)) {
                    rm.setLayerMask(rm.getInstance(rec.entity),
                        0xFF, rec.layers and 0xFF)
                }
            }
            // `skin` is a node member, not a component — update the
            // binding BEFORE a components re-decode so decodeMesh's
            // attach sees the new value (iOS applyNodeUpdate order).
            // Absent `skin` in the spec means the member cleared.
            if ("skin" in flags) {
                val sk = spec.optString("skin").takeIf { it.isNotEmpty() }
                    ?.let { D3Wire.localIdKey(it) }
                if (sk != null) nodeSkinKeys[key] = sk
                else nodeSkinKeys.remove(key)
                if ("components" !in flags) rebuildRenderable(key)
            }
            if ("components" in flags) {
                teardownComponents(key, rec)
                // The re-encoded spec carries the current `skin`
                // member — refresh the binding so the rebuilt mesh's
                // attach reads it even when the diff didn't flag
                // `skin`.
                val sk = spec.optString("skin").takeIf { it.isNotEmpty() }
                    ?.let { D3Wire.localIdKey(it) }
                if (sk != null) nodeSkinKeys[key] = sk
                else nodeSkinKeys.remove(key)
                spec.optJSONArray("components")?.let { comps ->
                    for (i in 0 until comps.length()) {
                        decodeComponent(key, rec, i, comps.opt(i))
                    }
                }
                decodeNodePhysics(key)
                applyVariantComponents()
            }
            if ("visible" in flags) {
                rec.hidden = spec.has("visible") && !spec.getBoolean("visible")
            }
            for (f in flags) {
                if (f !in NODE_UPDATE_FLAGS) {
                    logOnce("updateNode:flag:$f",
                        "updateNode flag '$f' not implemented")
                }
            }
            // W15: `instance` in the spec is the placeholder tag's
            // post-update state — a dict sets it (an unload's
            // restore), explicit null clears it (the load's instance
            // update), and an absent key preserves it: a reparent-only
            // update carries no spec fields and must not strip the
            // tag.
            if (spec.has("instance")) {
                rec.instanceSpec = spec.optJSONObject("instance")
            }
            applyVisibility(key)
        }

        /**
         * Geometry rebind — re-decodes the resource, rebuilds its
         * GpuMesh, and swaps the buffers onto every consuming
         * renderable (`upsertResource`/`upsertPayload` share this).
         * A consumer without a renderable — its mesh decode hit a
         * pending geometry — first-builds from its retained props.
         */
        fun redecodeGeometry(key: Long, r: JSONObject) {
            val before = geometries[key]
            decodeGeometry(key, r)
            val md = geometries[key]
            // A pending or failed decode leaves the map untouched —
            // consumers keep their old buffers until new data lands.
            if (md == null || md === before) return
            pendingPayloadRefs.remove(key)
            val old = gpuMeshes[key]
            val gm = buildGpuMesh(md)
            gpuMeshes[key] = gm
            // A morph/skin capability change needs a full renderable
            // rebuild — the MorphTargetBuffer binds at Builder.build
            // and a stale skinned buffer can't take new bone streams.
            val rebuild = old != null &&
                (old.hasSkinning || gm.hasSkinning ||
                    old.morphTargetBuffer != null || gm.morphTargetBuffer != null)
            val rm = host.engine.renderableManager
            var rebound = 0
            for (nodeKey in geometryConsumers[key]?.toList().orEmpty()) {
                val rec = nodes[nodeKey] ?: continue
                if (rebuild) {
                    rebuildRenderable(nodeKey)
                } else if (rm.hasComponent(rec.entity)) {
                    // Instance handles aren't entities — resolve per
                    // use, like TransformManager's. A multi-primitive
                    // mesh binds the upserted geometry at its own slot;
                    // the collider state re-unions across primitives.
                    val keys = rec.meshPrimGeoKeys
                    val slot = keys?.indexOf(key) ?: 0
                    val ri = rm.getInstance(rec.entity)
                    rm.setGeometryAt(ri, if (slot >= 0) slot else 0,
                        gm.primitiveType, gm.vertexBuffer, gm.indexBuffer)
                    if (keys != null && keys.size > 1 &&
                        aggregateGeoState(rec)) {
                        rm.setAxisAlignedBoundingBox(ri, Box(
                            rec.lastGeoBounds!![0], rec.lastGeoBounds!![1],
                            rec.lastGeoBounds!![2], rec.lastGeoBounds!![3],
                            rec.lastGeoBounds!![4], rec.lastGeoBounds!![5]))
                    } else {
                        val b = gm.bounds
                        rm.setAxisAlignedBoundingBox(ri,
                            Box(b[0], b[1], b[2], b[3], b[4], b[5]))
                        rec.lastGeoPositions = gm.positions
                        rec.lastGeoIndices = gm.indices
                        rec.lastGeoBounds = gm.bounds
                    }
                } else {
                    val props = rec.meshProps ?: continue
                    decodeMesh(nodeKey, rec, props)
                    applyVisibility(nodeKey)
                }
                rebound++
            }
            // W16: lod levels consuming this geometry rebind BEFORE
            // the old buffers die — the bound renderable's
            // VertexBuffer is the one being swapped out.
            refreshLodConsumers(key)
            // Safe only after every consumer swapped — the old buffers
            // were still bound until now.
            old?.destroy(host.engine)
            Log.i(TAG, "geometry $key: rebuilt, rebound $rebound consumer(s)")
        }

        /**
         * Wires the node's transform parent (null → scene root). A
         * parent that isn't live yet leaves a claim in
         * [pendingParents] resolved when its addNode lands. Instance
         * handles go stale across component destruction — resolved per
         * use, never cached; instance 0 is no parent.
         */
        private fun attachNode(key: Long, rec: NodeRec, parentKey: Long?) {
            val parent = parentKey?.let { nodes[it] }
            rec.parentKey = if (parent != null) parentKey else null
            tcm.setParent(
                tcm.getInstance(rec.entity),
                if (parent != null) tcm.getInstance(parent.entity) else 0)
            when {
                parent != null -> pendingParents.remove(key)
                parentKey != null -> {
                    pendingParents[key] = parentKey
                    Log.i(TAG, "node $key: parent $parentKey not live yet; claim parked")
                }
                else -> pendingParents.remove(key)
            }
        }

        /** Children that declared [key] as parent before it existed get
         * wired now — parked claims from [attachNode]. */
        private fun resolveParentClaims(key: Long, rec: NodeRec) {
            val it = pendingParents.entries.iterator()
            while (it.hasNext()) {
                val (childKey, claimed) = it.next()
                if (claimed != key) continue
                it.remove()
                val child = nodes[childKey] ?: continue
                child.parentKey = key
                tcm.setParent(
                    tcm.getInstance(child.entity),
                    tcm.getInstance(rec.entity))
                applyVisibility(childKey)
            }
        }

        /**
         * Re-evaluates scene membership for the node and its
         * descendants — the live-scene slice of [attachToScene]'s
         * [isHidden] walk. Membership follows `visible:false` on the
         * node or any ancestor.
         */
        private fun applyVisibility(key: Long) {
            for ((k, rec) in nodes) {
                if (k != key && !isDescendantOf(k, key)) continue
                if (isHidden(k)) host.scene.removeEntity(rec.entity)
                else attachIfRenderable(rec)
            }
        }

        private fun isDescendantOf(key: Long, ancestor: Long): Boolean {
            var p = nodes[key]?.parentKey
            while (p != null) {
                if (p == ancestor) return true
                p = nodes[p]?.parentKey
            }
            return false
        }

        /**
         * Clears the node's realized component state for a
         * `components` re-decode: renderable/light components, scene
         * membership, consumer-map entries, camera claim, and the
         * physics body.
         */
        private fun teardownComponents(key: Long, rec: NodeRec) {
            val entity = rec.entity
            val rm = host.engine.renderableManager
            val lm = host.engine.lightManager
            if (rm.hasComponent(entity)) rm.destroy(entity)
            if (lm.hasComponent(entity)) lm.destroy(entity)
            host.scene.removeEntity(entity)
            for ((_, list) in materialConsumers) {
                list.removeAll { it.first == entity }
            }
            for ((_, set) in geometryConsumers) set.remove(key)
            // W11: the skinning buffer and morph state ride on the
            // renderable — both die with it. The `skin` MEMBER binding
            // (nodeSkinKeys) survives — a rebuilt mesh re-attaches.
            nodeSkinning.remove(key)?.let {
                host.engine.destroySkinningBuffer(it.buffer)
            }
            rec.morphWeights = null
            rec.lastGeoPositions = null
            rec.lastGeoIndices = null
            rec.lastGeoBounds = null
            rec.meshProps = null
            rec.meshPrimGeoKeys = null
            if (rec.isCamera) {
                rec.isCamera = false
                nodeCameraProps.remove(key)
                if (host.cameraNodeKey == key) host.cameraNodeKey = null
            }
            rec.body?.let { host.world.removeBody(it) }
            rec.body = null
            bodies.remove(key)
            dynamicBodyKeys.remove(key)
            // W12: the node's component-joint registrations, variant
            // component, disabled marks, and rect-cluster light
            // entities die with the component list — a re-decode
            // replaces them wholesale.
            host.dropComponentJointsForNode(key)
            variantComponents.remove(key)
            disabledComponents.remove(key)
            for (child in rec.lightEntities) {
                host.scene.removeEntity(child)
                host.engine.destroyEntity(child)
                em.destroy(child)
            }
            rec.lightEntities.clear()
            // W16: trail/lod runtime state dies with the component
            // list — the re-decode rebuilds both (the trail's path
            // is runtime state that never persists, upstream's rule).
            destroyTrailLod(rec)
        }

        /**
         * Runs the deferred-physics pass over this Context's queued
         * items — for a surgical Context that's exactly one node's
         * colliders, rigid bodies and world props, in the manifest
         * pass's colliders → bodies → world order.
         */
        private fun decodeNodePhysics(key: Long) {
            nodeWorld[key] = worldMatOf(key)
            decodePhysicsDeferred()
        }

        // MARK: Stage + install

        /**
         * W14: decodes the top-level `views` list — each entry binds a
         * camera node to a target ('rt:<tok>', or absent for the
         * screen). Called from `realize` after decodeStage and from the
         * host's `updateViews` op; fills [views] wholesale for the
         * install/apply path.
         */
        fun decodeViews(arr: JSONArray?) {
            views.clear()
            if (arr == null) return
            for (i in 0 until arr.length()) {
                val e = arr.optJSONObject(i) ?: continue
                RenderTargets.decodeViewEntry(
                    i, e, nodes::containsKey, renderTargets::containsKey)
                    ?.let(views::add)
            }
        }

        /**
         * Applies the manifest `stage` block: the `environmentRef` →
         * `kind:"environment"` resource drives the lighting env
         * (`scene.indirectLight` = SH irradiance + prefiltered
         * reflections), the skybox background, and the camera
         * exposure/tone mapping. An absent or unresolvable ref defaults
         * to the built-in **studio** env — upstream behavior. Every
         * env-owned object is swapped and destroyed each run so a
         * re-decode — `updateStage`, env `upsertResource`, payload
         * arrival — replaces the previous look without accumulation
         * (mirrors iOS `decodeStage`).
         */
        fun decodeStage(stage: JSONObject?) {
            // A ref swap retires the previous env's deferral/claim —
            // otherwise the old key sits in pendingPayloadRefs and
            // every later payload chunk triggers a full re-realize.
            val oldToken = host.lastStage?.optString("environmentRef")
                ?.takeIf { it.isNotEmpty() }
            if (oldToken != null &&
                stage?.optString("environmentRef") != oldToken) {
                D3Wire.localIdKey(oldToken)?.let {
                    pendingPayloadRefs.remove(it)
                    environmentPayloadIds.remove(it)
                }
            }
            host.lastStage = stage
            stageEnvDeferred = false

            // W14: the stage's view-quality defaults — views entries
            // that leave antiAliasing/renderScale/filterQuality absent
            // inherit these. Always applied (updateStage re-runs this
            // and the live views re-resolve).
            host.applyStageQuality(
                stage?.optString("antiAliasing")
                    ?.takeIf { it.isNotEmpty() },
                stage?.optDouble("renderScale", 1.0) ?: 1.0,
                stage?.optString("filterQuality")
                    ?.takeIf { it.isNotEmpty() } ?: "medium")

            var envKey: Long? = null
            var env: JSONObject? = null
            val token = stage?.optString("environmentRef")
                ?.takeIf { it.isNotEmpty() }
            if (token != null) {
                val ref = D3Wire.localIdKey(token)
                if (ref != null) {
                    envKey = ref
                    env = environments[ref]
                    if (env == null) {
                        logOnce("stage.envRef.$ref",
                            "stage environmentRef '$token' unresolved;" +
                                " using the studio default")
                    }
                } else {
                    logOnce("stage.envRef.token",
                        "stage environmentRef '$token' is malformed;" +
                            " using the studio default")
                }
            }
            // Upstream's zero-config default: a document with no
            // environment still gets the procedural studio IBL.
            val envRes = env ?: JSONObject(
                mapOf("environment" to mapOf("type" to "studio")))

            // Skip the env build when every input is unchanged — a
            // payload arrival for an unrelated resource re-runs the
            // stage, and each run costs ~10ms of equirect→cube→SH GPU
            // work. The payload bytes' hash rides along so an
            // `upsertPayload` replacing the env image under the same
            // token still rebuilds. A skip while the env is deferred
            // keeps its payload claims live (the sets persist).
            val envPayloadKey = envRes.optJSONObject("environment")
                ?.optString("payload")?.takeIf { it.isNotEmpty() }
                ?.let { D3Wire.localIdKey(it) }
            // The claim must be re-registered before the skip below:
            // each re-realize installs this Context's registries
            // wholesale, so an early return would drop the deferred
            // env's claim from `environmentPayloadIds` and its marker
            // from `pendingPayloadRefs` — an env chunk landing after
            // every other payload would then trigger no re-decode and
            // the env would stay unapplied forever.
            if (envPayloadKey != null) {
                envKey?.let { environmentPayloadIds[it] = envPayloadKey }
                if (host.payloadStore[envPayloadKey] == null) {
                    envKey?.let { pendingPayloadRefs.add(it) }
                }
            }
            val envFingerprint = listOf(
                stage?.toString() ?: "∅", envRes.toString(),
                envPayloadKey?.let {
                    host.payloadStore[it]?.contentHashCode() })
                .hashCode()
            if (envFingerprint == host.lastEnvFingerprint) return
            host.lastEnvFingerprint = envFingerprint

            // The "look" fields serialize as plain JSON values (the
            // tagged {'d': …} form is only for node/material
            // properties).
            val exposure = envRes.optDouble("exposure", 1.0)
            val toneMapping = envRes.optString("toneMapping")
                .ifEmpty { "pbrNeutral" }
            val agxWhite = envRes.optDouble("agxWhite", 16.29)
            val agxContrast = envRes.optDouble("agxContrast", 1.25)
            if (envRes.has("skyEnvironment")) {
                logOnce("stage.skyEnvironment",
                    "skyEnvironment (procedural sky re-lighting) is deferred")
            }
            // W13: the env's `effects` post-stack. Absent keeps the
            // prior decoded stack (retain-on-absent); present — even
            // `{}` — wholesale-replaces it.
            StageEffects.decode(envRes.optJSONObject("effects"))?.let {
                host.lastEffects = it
            }

            val intensity = envRes.optDouble("environmentIntensity", 1.0)
            val rotationY = envRes.optDouble("environmentRotationY", 0.0)
            if (envRes.has("radianceCubeSize")) {
                logOnce("stage.radianceCubeSize",
                    "radianceCubeSize isn't settable through the Java" +
                        " IBLPrefilterContext (cube is fixed 256²); ignored")
            }

            // Lighting env → CPU pixels → SH3 + prefiltered cube. The
            // z-mirror + environmentRotationY bake into the equirect as
            // one column shift (see EnvironmentFactory.filamentShifted)
            // — Filament's Skybox has no rotation knob, so the bake
            // keeps the background and the reflections agreeing where
            // IndirectLight.rotation would rotate lighting alone.
            val pixels = realizeEnvironmentSource(envRes, envKey)
            var sh: FloatArray? = null
            var envCube: Texture? = null
            var skyEnvPixels: EnvironmentFactory.EnvPixels? = null
            val iblTextures = ArrayList<Texture>()
            if (pixels != null) {
                val start = System.nanoTime()
                val shifted =
                    EnvironmentFactory.filamentShifted(pixels, rotationY)
                sh = EnvironmentFactory.projectEquirectSH(shifted)
                val eq = EnvironmentFactory.normalizeEquirect(shifted)
                val src =
                    EnvironmentFactory.equirectTexture(host.engine, eq)
                iblTextures.add(src)
                // run() can fail (non-2:1, missing mips — both
                // pre-conditioned above, but the Java return is a
                // platform type): degrade to SH-only rather than crash.
                val cube = host.iblEquirect().run(src)
                if (cube != null) {
                    iblTextures.add(cube)
                    envCube = host.iblSpecular().run(cube)
                    if (envCube != null) iblTextures.add(envCube)
                } else {
                    warnOnce("env.cube.${envKey ?: 0}",
                        "equirect→cubemap conversion failed;" +
                            " irradiance-only IBL")
                }
                skyEnvPixels = shifted
                val elapsedMs = (System.nanoTime() - start) / 1_000_000
                Log.i(TAG, "environment ${envKey ?: "default"}:" +
                    " ${eq.width}×${eq.height} equirect →" +
                    " ${envCube?.getWidth(0) ?: 0}² cube + SH3 in" +
                    " ${elapsedMs}ms")
            }

            // --- skybox ------------------------------------------------
            // A separate draw of (usually) the same env —
            // `skybox.intensity` stacks on `environmentIntensity`
            // (upstream's skybox encoder multiplies the two).
            val sky = envRes.optJSONObject("skybox")
            val source = sky?.optJSONObject("source")
            val skyIntensity = sky?.optDouble("intensity", 1.0) ?: 1.0
            val skyType = source?.optString("type")
            val skyTextures = ArrayList<Texture>()
            var skybox: Skybox? = null
            // A deferred env leaves the `environment`-sourced
            // background untouched — its cube is still owned by the
            // previous decode. Every other source applies normally.
            val skyboxTouched =
                !stageEnvDeferred || skyType != "environment"
            when (skyType) {
                "environment" -> if (!stageEnvDeferred) {
                    var cube = envCube
                    val blurriness =
                        source?.optDouble("blurriness", 0.0) ?: 0.0
                    if (cube != null && blurriness > 0 &&
                        skyEnvPixels != null) {
                        // Filament's Skybox always samples lod 0 (no
                        // mip knob) — approximate blurriness with a CPU
                        // box blur on a dedicated equirect→cube.
                        val blurred = EnvironmentFactory.boxBlurredPixels(
                            skyEnvPixels,
                            maxOf(1, Math.round(blurriness *
                                skyEnvPixels.width / 32).toInt()))
                        val bt = EnvironmentFactory.equirectTexture(
                            host.engine,
                            EnvironmentFactory.normalizeEquirect(blurred))
                        val bc = host.iblEquirect().run(bt)
                        if (bc != null) {
                            cube = bc
                            skyTextures.add(bt)
                            skyTextures.add(bc)
                            logOnce("skybox.blurriness",
                                "skybox blurriness $blurriness:" +
                                    " approximated with a CPU box blur" +
                                    " on the equirect")
                        } else {
                            host.engine.destroyTexture(bt)
                        }
                    }
                    if (cube != null) {
                        // Filament measures env skybox/IBL intensity
                        // in lux — upstream's unitless
                        // environmentIntensity scales Filament's own
                        // 30 000 lx baseline (ENVIRONMENT_LUX_PER_UNIT)
                        // or the env renders ~15 stops under.
                        skybox = Skybox.Builder()
                            .environment(cube)
                            .intensity((intensity * skyIntensity *
                                ENVIRONMENT_LUX_PER_UNIT).toFloat())
                            .build(host.engine)
                    }
                }
                "gradient" -> {
                    // The sky is its own source — env intensity/
                    // rotation don't reach it, but the z-mirror does
                    // (world space). It does NOT light the scene —
                    // skyEnvironment re-lighting is deferred.
                    val gp = EnvironmentFactory.filamentShifted(
                        EnvironmentFactory.gradientEquirectPixels(source),
                        0.0)
                    val gt = EnvironmentFactory.equirectTexture(
                        host.engine, gp)
                    val gc = host.iblEquirect().run(gt)
                    if (gc != null) {
                        skyTextures.add(gt)
                        skyTextures.add(gc)
                        skybox = Skybox.Builder()
                            .environment(gc)
                            .intensity((skyIntensity *
                                ENVIRONMENT_LUX_PER_UNIT).toFloat())
                            .build(host.engine)
                    } else {
                        host.engine.destroyTexture(gt)
                    }
                }
                "fmat", "physical" -> logOnce("skybox.$skyType",
                    "skybox source '$skyType' is deferred; background cleared")
                else -> if (source != null) {
                    logOnce("skybox.${skyType ?: "?"}",
                        "skybox source '${skyType ?: "?"}' unknown;" +
                            " background cleared")
                }
            }

            // Apply: skybox first (unbinds the old background — which
            // may sample the old env cube — before its textures die),
            // then the indirect light + its texture set. A deferred
            // env leaves both untouched (the old env stays live until
            // the payload lands); non-environment skies still apply.
            if (skyboxTouched) host.applySkybox(skybox, skyTextures)
            if (!stageEnvDeferred) {
                val il = sh?.let {
                    val b = IndirectLight.Builder()
                        .irradiance(3, it)
                        .intensity((intensity *
                            ENVIRONMENT_LUX_PER_UNIT).toFloat())
                    if (envCube != null) b.reflections(envCube)
                    b.build(host.engine)
                }
                envKey?.let { pendingPayloadRefs.remove(it) }
                host.applyEnvironment(il, iblTextures)
            }
            // Look + effects apply even while an env payload is
            // deferred (outside the !stageEnvDeferred guard) — they're
            // JSON-decoded state, not env-owned GPU objects.
            host.applyStageLook(exposure.toFloat(), toneMapping,
                agxWhite, agxContrast, host.lastEffects)
            host.applyStageEffects()
        }

        /**
         * Realizes the env resource's `environment` member into
         * equirect pixels. Returns null for `empty` and for sources
         * that fail to decode; a `payload` whose bytes haven't landed
         * sets [stageEnvDeferred] and records the payload claim so an
         * `upsertPayload` chunk re-runs the stage.
         */
        private fun realizeEnvironmentSource(
            envRes: JSONObject,
            envKey: Long?,
        ): EnvironmentFactory.EnvPixels? {
            val spec = envRes.optJSONObject("environment")
                ?: JSONObject(mapOf("type" to "studio"))
            val type = spec.optString("type").ifEmpty { "studio" }
            val tag = envKey?.let { "environment $it" } ?: "environment"
            return when (type) {
                "studio" -> EnvironmentFactory.EnvPixels(256, 128,
                    isFloat = false,
                    data = EnvironmentFactory.studioEquirectPixels(
                        256, 128))
                "constant" -> {
                    // The wire color is linear radiance; the equirect
                    // stores sRGB like every LDR source here.
                    val c = EnvironmentFactory.rawVec3(
                        spec.optJSONArray("color"))
                        ?: doubleArrayOf(0.0, 0.0, 0.0)
                    EnvironmentFactory.EnvPixels(16, 8, isFloat = false,
                        data = EnvironmentFactory.solidEquirectPixels(
                            c, 16, 8))
                }
                "empty" -> null
                "asset" -> {
                    val ref = spec.optString("ref")
                        .takeIf { it.isNotEmpty() }
                    if (ref == null) {
                        logOnce("env.${envKey ?: 0}.asset",
                            "$tag: asset environment lacks 'ref'")
                        null
                    } else {
                        val bytes = try {
                            host.context.assets.open(ref)
                                .use { it.readBytes() }
                        } catch (e: Exception) { null }
                        if (bytes == null) {
                            logOnce("env.asset.$ref",
                                "$tag: asset '$ref' not found")
                            null
                        } else {
                            EnvironmentFactory.envPixelsFromBytes(
                                bytes, tag)
                        }
                    }
                }
                "payload" -> {
                    val pid = spec.optString("payload")
                        .takeIf { it.isNotEmpty() }
                        ?.let { D3Wire.localIdKey(it) }
                    if (pid == null) {
                        logOnce("env.${envKey ?: 0}.payloadToken",
                            "$tag: invalid payload token")
                        return null
                    }
                    envKey?.let { environmentPayloadIds[it] = pid }
                    val data = host.payloadStore[pid]
                    if (data == null) {
                        stageEnvDeferred = true
                        envKey?.let { pendingPayloadRefs.add(it) }
                        logOnce("env.${envKey ?: 0}.awaiting",
                            "$tag: awaiting payload")
                        null
                    } else {
                        EnvironmentFactory.envPixelsFromBytes(data, tag)
                    }
                }
                else -> {
                    logOnce("env.${envKey ?: 0}.type",
                        "$tag: unknown environment type '$type';" +
                            " using studio")
                    EnvironmentFactory.EnvPixels(256, 128,
                        isFloat = false,
                        data = EnvironmentFactory.studioEquirectPixels(
                            256, 128))
                }
            }
        }

        fun install() {
            host.fsceneVersion = fsceneVersion
            host.install(
                nodes = nodes,
                gpuMeshes = gpuMeshes,
                materials = materials,
                resources = InstalledResources(
                    textures = textures,
                    textureSamplers = textureSamplers,
                    textureConsumers = textureConsumers,
                    materialConsumers = materialConsumers,
                    textureResources = textureResources,
                    materialResources = materialResources,
                    texturePayloadIds = texturePayloadIds,
                    geometries = geometries,
                    geometryResources = geometryResources,
                    geometryConsumers = geometryConsumers,
                    geometryPayloadIds = geometryPayloadIds,
                    environments = environments,
                    environmentPayloadIds = environmentPayloadIds,
                    payloadSpecs = payloadSpecs,
                    skins = skins,
                    animations = animations,
                    skinPayloadIds = skinPayloadIds,
                    animPayloadIds = animPayloadIds,
                    skinDefs = skinDefs,
                    animDefs = animDefs,
                    nodeSkinKeys = nodeSkinKeys,
                    variantComponents = variantComponents,
                    disabledComponents = disabledComponents,
                ),
                nodeSkins = nodeSkinning,
                pending = pendingPayloadRefs,
                cameraKey = firstCameraKey,
                cameraProps = cameraProps,
                renderTargets = renderTargets,
                views = views,
                nodeCameraProps = nodeCameraProps,
                bodies = bodies,
                dynamicBodies = dynamicBodyKeys,
            )
        }
    }

    /**
     * Builds a `MaterialInstance` for one material resource — shared by
     * the manifest pass and the host's `upsertResource` surgical path.
     * Every texture slot binds a real upload or a neutral 1×1 fallback so
     * the shader always samples (missing texture == factor-only). When
     * [consumers] is non-null each bound slot records
     * texKey → (instance, slotParam) for surgical rebinding.
     */
    fun buildMaterialInstance(
        host: Dart3dView,
        key: Long,
        r: JSONObject,
        textures: Map<Long, Texture>,
        samplers: Map<Long, TextureSampler>,
        consumers: MutableMap<Long, MutableList<Pair<MaterialInstance, String>>>?,
    ): MaterialInstance {
        val type = r.optString("type").ifEmpty { "physicallyBased" }
        val unlit = type == "unlit"
        val props = r.optJSONObject("properties") ?: JSONObject()
        // W21 alphaMode: Filament bakes the blending mode into the
        // compiled Material, so the wire string picks the host's
        // variant; `mask` adds the per-instance discard threshold.
        // Filament sorts TRANSPARENT renderables back-to-front itself,
        // so `blend` needs no render-order fix-up here.
        val alphaMode = props.tag("alphaMode").d3String() ?: "opaque"
        if (alphaMode.lowercase() !in ALPHA_MODES) {
            warnOnce("alphaMode:$alphaMode",
                "material $key: alphaMode '$alphaMode' unknown;" +
                    " treating as opaque")
        }
        val mi = host.materialForAlphaMode(unlit, alphaMode)
            .createInstance()
        if (alphaMode.equals("mask", ignoreCase = true)) {
            mi.setMaskThreshold(
                (props.tag("alphaCutoff").d3Double() ?: 0.5).toFloat())
        }

        // Factor × texture always applies — never texture-instead-of —
        // and uniforms zero-init, so every parameter is written with its
        // spec default when the property is absent.
        val bc = props.tag("baseColor").d3Color()
            ?: floatArrayOf(1f, 1f, 1f, 1f)
        mi.setParameter("baseColor", bc[0], bc[1], bc[2], bc[3])
        setUvTransform(mi, props, "baseColorTextureTransform", "baseColor")
        bindTextureSlot(host, mi, props, textures, samplers,
            "baseColorTexture", "baseColorMap", host.fallbackWhite,
            consumers)

        mi.setDoubleSided(props.tag("doubleSided").d3Bool() ?: false)

        if (!unlit) {
            mi.setParameter("metallic",
                (props.tag("metallic").d3Double() ?: 0.0).toFloat())
            mi.setParameter("roughness",
                (props.tag("roughness").d3Double() ?: 0.5).toFloat())
            mi.setParameter("normalScale",
                (props.tag("normalScale").d3Double() ?: 1.0).toFloat())
            mi.setParameter("occlusionStrength",
                (props.tag("occlusionStrength").d3Double() ?: 1.0).toFloat())
            mi.setParameter("emissiveStrength",
                (props.tag("emissiveStrength").d3Double() ?: 1.0).toFloat())
            val em = props.tag("emissive").d3Color()
                ?: floatArrayOf(0f, 0f, 0f, 1f)
            mi.setParameter("emissiveColor", em[0], em[1], em[2], em[3])

            setUvTransform(mi, props, "normalTextureTransform", "normal")
            setUvTransform(mi, props,
                "metallicRoughnessTextureTransform", "mr")
            setUvTransform(mi, props, "occlusionTextureTransform", "occlusion")
            setUvTransform(mi, props, "emissiveTextureTransform", "emissive")

            bindTextureSlot(host, mi, props, textures, samplers,
                "normalTexture", "normalMap", host.fallbackNormal,
                consumers)
            bindTextureSlot(host, mi, props, textures, samplers,
                "metallicRoughnessTexture", "metallicRoughnessMap",
                host.fallbackWhite, consumers)
            bindTextureSlot(host, mi, props, textures, samplers,
                "occlusionTexture", "occlusionMap", host.fallbackWhite,
                consumers)
            bindTextureSlot(host, mi, props, textures, samplers,
                "emissiveTexture", "emissiveMap", host.fallbackEmissive,
                consumers)
        }
        return mi
    }

    /**
     * `<slot>TextureTransform` (KHR_texture_transform vocabulary) → the
     * `<prefix>UVTransform`/`UVRotation`/`UVSet` uniforms. The map's
     * tagged values are `offset`/`scale` (`v2`), `rotation` (`d`),
     * `texCoord` (`i`). W21 realizes `texCoord`: 0 → uv0, ≥1 → uv1 —
     * the vertex record always carries both channels (zero-filled when
     * the wire layout lacks TEXCOORD_1); a value above 1 clamps to the
     * highest realized set with a warning.
     */
    private fun setUvTransform(
        mi: MaterialInstance, props: JSONObject,
        propName: String, prefix: String,
    ) {
        var tx = 0f; var ty = 0f
        var sx = 1f; var sy = 1f
        var rot = 0f
        var uvSet = 0f
        val map = props.tag(propName).d3Map()
        if (map != null) {
            map.tag("offset").d3Vec2()?.let {
                tx = it[0].toFloat(); ty = it[1].toFloat()
            }
            map.tag("scale").d3Vec2()?.let {
                sx = it[0].toFloat(); sy = it[1].toFloat()
            }
            rot = (map.tag("rotation").d3Double() ?: 0.0).toFloat()
            val tc = map.tag("texCoord").d3Int() ?: 0
            if (tc > 1) {
                warnOnce("texCoord:$tc",
                    "textureTransform texCoord=$tc: uv1 is the highest" +
                        " realized set; clamped to 1")
            }
            if (tc > 0) uvSet = 1f
        }
        mi.setParameter("${prefix}UVTransform", tx, ty, sx, sy)
        mi.setParameter("${prefix}UVRotation", rot)
        mi.setParameter("${prefix}UVSet", uvSet)
    }

    private fun bindTextureSlot(
        host: Dart3dView,
        mi: MaterialInstance,
        props: JSONObject,
        textures: Map<Long, Texture>,
        samplers: Map<Long, TextureSampler>,
        refProp: String,
        param: String,
        fallback: Texture,
        consumers: MutableMap<Long,
            MutableList<Pair<MaterialInstance, String>>>?,
    ) {
        val texKey = props.tag(refProp).d3Ref()
        val tex = texKey?.let { textures[it] } ?: fallback
        if (texKey != null && tex === fallback) {
            Log.w(TAG, "material slot $refProp: texture $texKey not " +
                "realized — binding fallback")
        }
        // W14: a per-resource sampler (a renderTexture's filter/wrap)
        // wins over the shared host sampler.
        mi.setParameter(param, tex,
            texKey?.let { samplers[it] } ?: host.textureSampler)
        if (texKey != null && consumers != null) {
            consumers.getOrPut(texKey) { ArrayList() }.add(mi to param)
        }
    }

    private fun floatBufferOf(values: FloatArray): FloatBuffer =
        ByteBuffer.allocateDirect(values.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .also { it.put(values); it.flip() }

    /** Decomposes a column-major mat4 into [pos, quat, scale]. */
    fun decompose(m: FloatArray): Array<FloatArray> {
        val p = floatArrayOf(m[12], m[13], m[14])
        val sx = sqrt(m[0] * m[0] + m[1] * m[1] + m[2] * m[2])
        val sy = sqrt(m[4] * m[4] + m[5] * m[5] + m[6] * m[6])
        val sz = sqrt(m[8] * m[8] + m[9] * m[9] + m[10] * m[10])
        val s = floatArrayOf(sx, sy, sz)
        val r = floatArrayOf(
            m[0] / sx, m[1] / sx, m[2] / sx,
            m[4] / sy, m[5] / sy, m[6] / sy,
            m[8] / sz, m[9] / sz, m[10] / sz,
        )
        val q = quatFromMat3(r)
        return arrayOf(p, q, s)
    }

    fun worldPoseOf(m: FloatArray): Pair<FloatArray, FloatArray> {
        val d = decompose(m)
        return Pair(d[0], d[1])
    }

    private fun quatFromMat3(r: FloatArray): FloatArray {
        // r is column-major rotation [r00,r10,r20, r01,r11,r21, r02,r12,r22]
        val m00 = r[0]; val m10 = r[1]; val m20 = r[2]
        val m01 = r[3]; val m11 = r[4]; val m21 = r[5]
        val m02 = r[6]; val m12 = r[7]; val m22 = r[8]
        val trace = m00 + m11 + m22
        val q = FloatArray(4)
        if (trace > 0) {
            val s = sqrt(trace + 1f) * 2f
            q[3] = 0.25f * s
            q[0] = (m21 - m12) / s
            q[1] = (m02 - m20) / s
            q[2] = (m10 - m01) / s
        } else if (m00 > m11 && m00 > m22) {
            val s = sqrt(1f + m00 - m11 - m22) * 2f
            q[3] = (m21 - m12) / s
            q[0] = 0.25f * s
            q[1] = (m01 + m10) / s
            q[2] = (m02 + m20) / s
        } else if (m11 > m22) {
            val s = sqrt(1f + m11 - m00 - m22) * 2f
            q[3] = (m02 - m20) / s
            q[0] = (m01 + m10) / s
            q[1] = 0.25f * s
            q[2] = (m12 + m21) / s
        } else {
            val s = sqrt(1f + m22 - m00 - m11) * 2f
            q[3] = (m10 - m01) / s
            q[0] = (m02 + m20) / s
            q[1] = (m12 + m21) / s
            q[2] = 0.25f * s
        }
        return q
    }

    private fun sqrt(v: Float) = kotlin.math.sqrt(v)
}
