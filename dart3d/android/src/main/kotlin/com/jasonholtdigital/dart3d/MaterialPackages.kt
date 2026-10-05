package com.jasonholtdigital.dart3d

import android.content.Context
import android.util.Log
import com.google.android.filament.Engine
import com.google.android.filament.Material
import com.google.android.filament.filamat.MaterialBuilder
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap

/**
 * The plugin's Filament material packages: what each one is
 * ([MaterialRecipe]) and where its compiled bytes come from.
 *
 * Compiling a lit package with filamat takes 3–6 s on a phone, nearly
 * all of it in the SPIR-V optimizer, so the runtime compiler is the
 * last resort. A package is looked up, in order:
 *
 * 1. in this process's memory;
 * 2. among the packages shipped as assets — the fixed set
 *    ([fixedSet]) is built ahead of time and packaged with the plugin,
 *    and an app can add the variants its documents use;
 * 3. in the install's on-disk cache of earlier compiles;
 * 4. and only then compiled, on a background thread, and written to
 *    that cache.
 *
 * Packages depend only on the builder inputs, the target API and the
 * filamat version — never on an Engine — so one copy serves every
 * view, loaded with the cheap `Material.Builder().payload()`.
 * Compiles never run on the main thread: `DNPluginRegistry.createView`
 * runs there, and a cold compile of the lit set once parked it past
 * Android's 5 s input-dispatch ANR.
 *
 * Shipped packages are regenerated with `tool/bake_materials.sh`.
 */
internal object MaterialPackages {

    /** A package's cache key and the recipe that compiles it. */
    class Spec(val key: String, val recipe: MaterialRecipe) {
        val fingerprint: String by lazy {
            recipe.fingerprint(BuildConfig.FILAMENT_VERSION)
        }
    }

    private const val TAG = "dart3d"

    /** Variant packages kept in the process LRU (~100–300 KiB each). */
    private const val MAX_VARIANT_PACKAGES = 12

    // filament::UserVariantFilterBit
    private const val VARIANT_STE = 0x80

    // Fixed-vocabulary packages (the base lit/unlit set, trail,
    // catcher, particles — a bounded handful per target API) stay for
    // the process. On-demand KHR variants are keyed by extension flags
    // × bound-slot mask × blend × API — unbounded across documents —
    // so they live in a small LRU; an evicted variant just recompiles
    // (in the background) if a later document needs it again.
    private val cache = ConcurrentHashMap<String, ByteArray>()
    private val variantCache = object :
        LinkedHashMap<String, ByteArray>(16, 0.75f, true) {
        override fun removeEldestEntry(
            eldest: MutableMap.MutableEntry<String, ByteArray>?,
        ): Boolean = size > MAX_VARIANT_PACKAGES
    }

    /** Lit packages with a non-zero extension mask are variants. */
    private fun isVariant(key: String): Boolean =
        key.startsWith("lit|") && !key.contains("|e0|")

    private fun lookup(key: String): ByteArray? =
        if (isVariant(key)) synchronized(variantCache) { variantCache[key] }
        else cache[key]

    private fun store(key: String, bytes: ByteArray) {
        if (isVariant(key)) synchronized(variantCache) { variantCache[key] = bytes }
        else cache[key] = bytes
    }
    private val failed = ConcurrentHashMap.newKeySet<String>()

    @Volatile private var store: MaterialStore? = null
    @Volatile private var baking = false
    private val storeMisses = ConcurrentHashMap.newKeySet<String>()
    private val fromStore = ConcurrentHashMap.newKeySet<String>()
    private val storeLock = Any()

    /** Log tag that turns a run into a bake: `setprop log.tag.dart3d.bake DEBUG`. */
    private const val BAKE_TAG = "dart3d.bake"

    /**
     * Points the package lookup at [context]'s assets and code cache
     * (which Android empties on every app update). While baking,
     * neither is read: everything compiles and is exported to the
     * app's external files directory for `tool/bake_materials.sh`.
     */
    fun attach(context: Context) {
        if (store != null) return
        val app = context.applicationContext ?: context
        if (isBakeRun()) {
            val dir = File(app.getExternalFilesDir(null), "dart3d-materials")
            store = MaterialStore({ null }, null, dir)
            baking = true
            Log.i(TAG, "bake: exporting material packages to $dir")
            startBake()
            return
        }
        val assets = app.assets
        attachStore(MaterialStore(
            shipped = { name ->
                try {
                    assets.open("${MaterialStore.ASSET_DIR}/$name")
                        .use { it.readBytes() }
                } catch (e: java.io.IOException) {
                    null
                }
            },
            cacheDir = File(app.codeCacheDir, "dart3d-materials"),
        ))
    }

    fun attachStore(store: MaterialStore) {
        this.store = store
    }

    /**
     * True while the bake log tag is set. A bake renders on OpenGL:
     * it compiles the catcher and particle packages while frames are
     * drawn, which faults the Mali Vulkan driver (see [startPrewarm]).
     * filamat builds both backends' packages whichever one renders.
     */
    fun isBakeRun(): Boolean = Log.isLoggable(BAKE_TAG, Log.DEBUG)

    /** The target APIs the plugin runs on, and so ships packages for. */
    val BAKED_APIS = listOf(MaterialBuilder.TargetApi.OPENGL,
        MaterialBuilder.TargetApi.VULKAN)

    private val bakeProgress = BakeProgress { Log.i(TAG, it) }

    private fun startBake() {
        val t = Thread({
            try {
                val rejected = ArrayList<String>()
                var expected = 0
                for (api in BAKED_APIS) {
                    for (spec in fixedSet(api)) {
                        expected++
                        if (compile(spec) == null) rejected.add(spec.key)
                    }
                }
                val line = BakeProgress.fixedSetLine(expected, rejected)
                if (rejected.isEmpty()) Log.i(TAG, line) else Log.e(TAG, line)
            } catch (t: Throwable) {
                Log.e(TAG, "bake failed", t)
            }
        }, "dart3d-matbake")
        t.isDaemon = true
        t.start()
    }

    // filamat's toolchain (glslang process state) is initialized once
    // and compiles are serialized — the prewarm thread and a view on
    // main never run the toolchain concurrently.
    private val compileLock = Any()
    @Volatile private var ready = false

    fun ensureInit() {
        if (ready) return
        synchronized(compileLock) {
            if (!ready) {
                MaterialBuilder.init()
                ready = true
            }
        }
    }

    fun apiFor(backend: Engine.Backend): MaterialBuilder.TargetApi =
        if (backend == Engine.Backend.VULKAN) MaterialBuilder.TargetApi.VULKAN
        else MaterialBuilder.TargetApi.OPENGL

    /**
     * Returns [spec]'s package bytes: from memory, the store, or a
     * compile (which blocks for seconds — never call it on main for a
     * package that may be missing). Null when filamat rejects the
     * package (remembered, so a bad variant isn't recompiled per decode).
     */
    fun compile(spec: Spec): ByteArray? {
        val key = spec.key
        cached(spec)?.let { return it }
        if (key in failed) return null
        synchronized(compileLock) {
            lookup(key)?.let { return it }
            if (key in failed) return null
            ensureInit()
            val start = android.os.SystemClock.uptimeMillis()
            val pkg = try {
                spec.recipe.toBuilder().build()
            } catch (e: Exception) {
                null
            }
            if (pkg == null || !pkg.isValid) {
                failed.add(key)
                return null
            }
            val buf = pkg.buffer
            val bytes = ByteArray(buf.remaining())
            buf.get(bytes)
            store(key, bytes)
            store?.save(spec.fingerprint, key, bytes)
            storeMisses.remove(key)
            Log.i(TAG, "material package $key compiled in " +
                "${android.os.SystemClock.uptimeMillis() - start}ms" +
                " (${bytes.size} B)")
            return bytes
        }
    }

    /**
     * [spec]'s bytes if they can be had without compiling: from memory,
     * or read once from the store (a few ms of file I/O).
     */
    fun cached(spec: Spec): ByteArray? {
        lookup(spec.key)?.let { return it }
        val store = store ?: return null
        // One reader at a time: a second caller waits out the read
        // instead of taking the package for missing and compiling it.
        synchronized(storeLock) {
            lookup(spec.key)?.let { return it }
            if (spec.key in storeMisses) return null
            val bytes = store.find(spec.fingerprint)
            if (bytes == null) {
                storeMisses.add(spec.key)
                return null
            }
            store(spec.key, bytes)
            fromStore.add(spec.key)
            return bytes
        }
    }

    /**
     * Call when the engine refused to load [spec]'s bytes. True when
     * they came from the store (shipped or cached): they are dropped,
     * the store will not serve them again, and the caller should
     * compile. False when they were compiled by this process, which
     * leaves nothing to fall back to.
     */
    fun rejectStored(spec: Spec): Boolean {
        if (!fromStore.remove(spec.key)) return false
        if (isVariant(spec.key)) {
            synchronized(variantCache) { variantCache.remove(spec.key) }
        } else {
            cache.remove(spec.key)
        }
        store?.reject(spec.fingerprint)
        return true
    }

    /** Compiles [spec] off the calling thread; poll [peek] for it. */
    fun compileAsync(spec: Spec) {
        variantExecutor.execute {
            try {
                compile(spec)
            } catch (t: Throwable) {
                Log.w(TAG, "compile of ${spec.key} failed", t)
                failed.add(spec.key)
            }
        }
    }

    /** Reads [api]'s base set from the store into memory; no compile. */
    fun preload(api: MaterialBuilder.TargetApi): Boolean {
        var all = true
        for (spec in baseSet(api)) {
            if (cached(spec) == null) all = false
        }
        return all
    }

    /** In-memory bytes for [key] (null while pending). */
    fun peek(key: String): ByteArray? = lookup(key)

    /** True when filamat rejected [key]'s package. */
    fun hasFailed(key: String): Boolean = key in failed

    fun litKey(unlit: Boolean, blending: MaterialBuilder.BlendingMode,
               extFlags: Int, boundSlots: Int,
               api: MaterialBuilder.TargetApi): String =
        "lit|$unlit|$blending|e$extFlags|s$boundSlots|$api"

    fun trailKey(api: MaterialBuilder.TargetApi): String = "trail|$api"

    /** Loads cached package bytes into [engine] (cheap; no compile). */
    fun load(engine: Engine, bytes: ByteArray): Material {
        val buf = ByteBuffer.allocateDirect(bytes.size)
            .order(ByteOrder.nativeOrder())
        buf.put(bytes)
        buf.flip()
        return Material.Builder().payload(buf, bytes.size).build(engine)
    }

    /**
     * Compiles the six base prebuilts for [api] off the main thread.
     * Idempotent — cache hits return immediately.
     */
    private val prewarmStarted = ConcurrentHashMap.newKeySet<String>()

    /** Background lane for on-demand variant compiles. */
    private val variantExecutor = java.util.concurrent.Executors
        .newSingleThreadExecutor { r ->
            Thread(r, "dart3d-matvariant").also {
                it.isDaemon = true
                it.priority = Thread.NORM_PRIORITY - 1
            }
        }

    /**
     * Compiles a lit variant off the calling thread; [done] runs on the
     * compile thread with the bytes (null when filamat rejected it).
     */
    fun litPackageAsync(
        unlit: Boolean, blending: MaterialBuilder.BlendingMode,
        extFlags: Int, boundSlots: Int, api: MaterialBuilder.TargetApi,
        done: (ByteArray?) -> Unit,
    ) {
        if (baking) bakeProgress.started()
        variantExecutor.execute {
            val bytes = try {
                if (baking) {
                    // A bake exports each variant for both backends,
                    // whichever one this device renders with.
                    for (other in BAKED_APIS) {
                        compile(litSpec(unlit, blending, extFlags,
                            boundSlots, other))
                    }
                }
                compile(litSpec(unlit, blending, extFlags, boundSlots, api))
            } catch (t: Throwable) {
                Log.w(TAG, "variant compile failed", t)
                null
            }
            if (baking) bakeProgress.finished()
            done(bytes)
        }
    }

    /** The API a live view actually needs — speculative work for any
     * other API stops so it can't hold the compile lock. */
    @Volatile private var activeApi: MaterialBuilder.TargetApi? = null

    /** Called by a view for its engine's API (non-blocking). */
    fun prewarm(api: MaterialBuilder.TargetApi) {
        activeApi = api
        if (preload(api)) return
        startPrewarm(api)
    }

    /**
     * Plugin-registration prewarm: reads [guess]'s base set (the `auto`
     * resolution) from the store right away. Only if that leaves a
     * package to compile does it wait for the app's backend pref
     * (Dart3dSetBackend lands from Dart main a few hundred ms after
     * registration) and compile for the pref, or [guess] when none
     * was set.
     */
    fun prewarmSpeculative(guess: MaterialBuilder.TargetApi) {
        val t = Thread({
            if (preload(guess)) return@Thread
            try {
                Thread.sleep(400)
            } catch (e: InterruptedException) {
                return@Thread
            }
            val pref = try {
                Dart3dJni.nativeBackendPref()
            } catch (t: Throwable) {
                0
            }
            val api = activeApi ?: when (pref) {
                1 -> MaterialBuilder.TargetApi.OPENGL
                2 -> MaterialBuilder.TargetApi.VULKAN
                else -> guess
            }
            startPrewarm(api)
        }, "dart3d-matprewarm-wait")
        t.isDaemon = true
        t.start()
    }

    private val prewarmAttempts = ConcurrentHashMap<String, Int>()
    private const val MAX_PREWARM_ATTEMPTS = 2

    private val BLEND_MODES = listOf(
        MaterialBuilder.BlendingMode.OPAQUE,
        MaterialBuilder.BlendingMode.MASKED,
        MaterialBuilder.BlendingMode.TRANSPARENT)

    /**
     * The packages a view needs before it can render, in the order
     * `Dart3dView` binds them: lit ×3 blend modes, unlit ×3, trail.
     */
    fun baseSet(api: MaterialBuilder.TargetApi): List<Spec> {
        val specs = ArrayList<Spec>()
        for (unlit in listOf(false, true)) {
            for (mode in BLEND_MODES) {
                specs += litSpec(unlit, mode, 0,
                    FsceneRealizer.ALL_BASE_SLOTS, api)
            }
        }
        specs += trailSpec(api)
        return specs
    }

    /**
     * Every package whose recipe does not depend on a document: the
     * base set, the shadow catcher and both particle blends. These ship
     * with the plugin for both target APIs. Lit variants (extension
     * flags × bound slots) depend on the document and are open-ended.
     */
    fun fixedSet(api: MaterialBuilder.TargetApi): List<Spec> =
        baseSet(api) + catcherSpec(api) +
            particleSpec(false, api) + particleSpec(true, api)

    private fun startPrewarm(api: MaterialBuilder.TargetApi) {
        if (!prewarmStarted.add(api.name)) return
        val t = Thread({
            // Abandon a speculative API once a view needs another one.
            fun stale() = activeApi.let { it != null && it != api }
            try {
                for (spec in baseSet(api)) {
                    if (stale()) return@Thread
                    compile(spec)
                }
                // The lazily-used catcher + particle packages are NOT
                // compiled here (integration, 2026-09-28): compiling
                // them concurrently with the first realized frames
                // reproducibly ended in a Mali CS_BUS_FAULT / GPU page
                // fault ("cpu queue set unrecoverable error") ~0.5 s
                // after the last one finished on the A142 Vulkan
                // materials lane (4/4 runs; 0/1 without them, GL
                // unaffected). Mechanism not yet understood — see
                // docs/triage/integration.md. They ship with the
                // plugin; if one is ever missing, a view compiles it
                // on main at first use, as before 6b4dcca.
            } catch (t: Throwable) {
                // A throw (MaterialBuilder.init, a native linkage or
                // runtime error) creates neither a cache entry nor a
                // `failed` key, and views only poll the cache for the
                // base set — so without handling this they'd wait
                // forever behind a blank surface. Clear the started
                // marker so the next view's prewarm retries; after
                // MAX_PREWARM_ATTEMPTS mark the missing base packages
                // failed, which views surface as a visible init error.
                Log.w(TAG, "material prewarm failed", t)
                val attempts = prewarmAttempts.merge(api.name, 1, Int::plus) ?: 1
                if (attempts >= MAX_PREWARM_ATTEMPTS) {
                    for (spec in baseSet(api)) {
                        if (lookup(spec.key) == null) failed.add(spec.key)
                    }
                    Log.e(TAG, "material prewarm for ${api.name} failed" +
                        " $attempts times — base packages marked failed")
                }
                prewarmStarted.remove(api.name)
            } finally {
                if (stale()) prewarmStarted.remove(api.name)
            }
        }, "dart3d-matprewarm")
        t.isDaemon = true
        t.priority = Thread.NORM_PRIORITY - 1
        t.start()
    }

    /**
     * W24 `shadowCatcher` — see Dart3dView.catcherMaterial. UNLIT +
     * `shadowMultiplier`; the engine multiplies the final color by the
     * shadow factor downstream.
     */
    fun catcherSpec(api: MaterialBuilder.TargetApi): Spec =
        Spec("catcher|$api",
            MaterialRecipe()
                .platform(MaterialBuilder.Platform.MOBILE)
                .targetApi(api)
                .name("d3_shadow_catcher")
                .shading(MaterialBuilder.Shading.UNLIT)
                .doubleSided(true)
                .blending(MaterialBuilder.BlendingMode.TRANSPARENT)
                // The catcher is still a real surface — it joins the
                // depth prepass like upstream's catcher does, so
                // contact shadows and occlusion read its depth.
                .depthWrite(true)
                .shadowMultiplier(true)
                .uniformParameter(MaterialBuilder.UniformType.FLOAT4,
                    "shadowColor")
                .uniformParameter(MaterialBuilder.UniformType.FLOAT,
                    "shadowIntensity")
                // `shadowMultiplier` makes the engine multiply the
                // FINAL color — alpha included — by the shadow factor;
                // no MaterialInputs field exposes it to read. The
                // material only declares the catcher's max
                // tint/opacity.
                .material("void material(inout MaterialInputs material) {\n" +
                    "    prepareMaterial(material);\n" +
                    "    material.baseColor = vec4(" +
                    "materialParams.shadowColor.rgb," +
                    " materialParams.shadowColor.a * " +
                    "materialParams.shadowIntensity);\n" +
                    "}\n"))

    /** W16 trail ribbon — vertex-color unlit + blend. */
    fun trailSpec(api: MaterialBuilder.TargetApi): Spec =
        Spec(trailKey(api),
            MaterialRecipe()
                .platform(MaterialBuilder.Platform.MOBILE)
                .targetApi(api)
                .name("d3_trail")
                .shading(MaterialBuilder.Shading.UNLIT)
                .doubleSided(true)
                .blending(MaterialBuilder.BlendingMode.TRANSPARENT)
                .require(MaterialBuilder.VertexAttribute.COLOR)
                .material(
                    "void material(inout MaterialInputs material) {\n" +
                        "    prepareMaterial(material);\n" +
                        "    material.baseColor = getColor();\n" +
                        "}\n"))

    /** W18 sprite billboard material — see Dart3dView.particleMaterial. */
    fun particleSpec(
        additive: Boolean, api: MaterialBuilder.TargetApi,
    ): Spec {
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
        return Spec("particle|$additive|$api", MaterialRecipe()
            .platform(MaterialBuilder.Platform.MOBILE)
            .targetApi(api)
            .name(if (additive) "d3_particle_add" else "d3_particle_alpha")
            .shading(MaterialBuilder.Shading.UNLIT)
            .vertexDomain(MaterialBuilder.VertexDomain.OBJECT)
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
            .material(frag.toString()))
    }

    /**
     * The `d3_lit`/`d3_unlit` family: one package per (shading,
     * blending, extension flags, bound slots, API). Returns null when
     * filamat rejects it — the caller degrades (variants) or fatals
     * (the six prebuilts, which have no fallback).
     */
    fun litSpec(
        unlit: Boolean,
        blending: MaterialBuilder.BlendingMode,
        extFlags: Int,
        boundSlots: Int,
        api: MaterialBuilder.TargetApi,
    ): Spec {
        val blendSuffix = when (blending) {
            MaterialBuilder.BlendingMode.OPAQUE -> ""
            MaterialBuilder.BlendingMode.MASKED -> "_mask"
            else -> "_blend"
        }
        val extSuffix = if (extFlags != 0) "_e$extFlags" else ""
        val b = MaterialRecipe()
            .platform(MaterialBuilder.Platform.MOBILE)
            // W30: SPIR-V under Vulkan, GLSL under OpenGL — matched to
            // the backend the engine actually resolved (incl. fallback).
            // (TargetApi.ALL would be tempting; it doesn't emit Vulkan.)
            .targetApi(api)
            .name((if (unlit) "d3_unlit" else "d3_lit") + blendSuffix +
                extSuffix)
            .shading(if (unlit) MaterialBuilder.Shading.UNLIT
                else MaterialBuilder.Shading.LIT)
            // Baked capability so MaterialInstance.setDoubleSided works —
            // every instance is reset to single-sided at decode unless the
            // resource opts in (glTF/SceneKit default).
            .doubleSided(true)
            .blending(blending)
            // Filament's MaterialBuilder defaults flipUV to TRUE (the
            // vertex shader rewrites v → 1 − v). Wire UVs are glTF
            // V=0-top and TextureFactory uploads top-row-first, so the
            // flip samples every texture upside down (dash-materials
            // investigation). The particle package already opts out.
            .flipUV(false)
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
            // W26: COLOR rides every wire vertex record (white when
            // absent upstream); instances bake per-instance colors
            // into it. Meshes lacking the attribute read Filament's
            // vec4(1) default, so baseColor stays unchanged there.
            .require(MaterialBuilder.VertexAttribute.COLOR)
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
                // W25 fix-2: SSR needs materials compiled with
                // reflectionMode SCREEN_SPACE — without it the shader
                // never samples the SSR buffer (MATERIAL_HAS_REFLECTIONS
                // stays off) and the view option alone is a no-op.
                // Harmless when SSR is disabled: the bound buffer's
                // zero coverage falls back to IBL specular.
                .reflectionMode(MaterialBuilder.ReflectionMode
                    .SCREEN_SPACE)
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
        // first at texel v=0, so the builder above disables Filament's
        // default flipUV.
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
                    " * texture(materialParams_baseColorMap, baseColorUv)" +
                    " * getColor();\n")
        } else {
            body.append("    material.baseColor = materialParams" +
                ".baseColor * getColor();\n")
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
        // Stereo (STE) variants are never rendered — filtering them
        // trims the compile. (VSM must stay: 1.71.6 requests the 0x40
        // variant bit for DPCF/SSR passes too — filtering it aborted
        // with "Requested variant 71 does not exist".)
        b.variantFilter(VARIANT_STE)
        return Spec(litKey(unlit, blending, extFlags, boundSlots, api),
            b.material(body.toString()))
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
}
