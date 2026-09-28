package com.jasonholtdigital.dart3d

import android.util.Log
import com.google.android.filament.Engine
import com.google.android.filament.Material
import com.google.android.filament.filamat.MaterialBuilder
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap

/**
 * Process-wide cache of compiled filamat material packages.
 *
 * `MaterialBuilder.build()` runs the full shader toolchain (GLSL →
 * SPIR-V/ESSL, optimization) — hundreds of ms per package on the A142,
 * and a `Dart3dView` needs seven at construction. Every screen switch
 * in the example re-creates the view, and `DNPluginRegistry.createView`
 * runs on the main thread, so compiling there parked main long enough
 * to trip Android's 5 s input-dispatch ANR (captured trace: main in
 * `MaterialBuilder.nBuilderBuild` ← `Dart3dView.<init>` ←
 * `DNPluginRegistry.createView`).
 *
 * Packages depend only on the builder inputs + target API — never on
 * an Engine — so they're compiled once per process and loaded into
 * each Engine with the cheap `Material.Builder().payload()`. [prewarm]
 * compiles the base set on a background thread at plugin registration
 * so the first view usually finds them ready.
 */
internal object MaterialPackages {

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
     * Returns the package bytes for [key], compiling [builder]'s output
     * on a miss. Null when filamat rejects the package (cached as a
     * failure so a bad variant isn't recompiled per decode).
     */
    fun compile(key: String, builder: () -> MaterialBuilder): ByteArray? {
        lookup(key)?.let { return it }
        if (key in failed) return null
        synchronized(compileLock) {
            lookup(key)?.let { return it }
            if (key in failed) return null
            ensureInit()
            val start = android.os.SystemClock.uptimeMillis()
            val pkg = try {
                builder().build()
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
            Log.i(TAG, "material package $key compiled in " +
                "${android.os.SystemClock.uptimeMillis() - start}ms")
            return bytes
        }
    }

    /** Cached bytes for [key] without compiling (null while pending). */
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
        variantExecutor.execute {
            val bytes = try {
                litPackage(unlit, blending, extFlags, boundSlots, api)
            } catch (t: Throwable) {
                Log.w(TAG, "variant compile failed", t)
                null
            }
            done(bytes)
        }
    }

    /** The API a live view actually needs — speculative work for any
     * other API stops so it can't hold the compile lock. */
    @Volatile private var activeApi: MaterialBuilder.TargetApi? = null

    /** Called by a view for its engine's API (non-blocking). */
    fun prewarm(api: MaterialBuilder.TargetApi) {
        activeApi = api
        startPrewarm(api)
    }

    /**
     * Plugin-registration prewarm. The app's backend pref
     * (Dart3dSetBackend) lands from Dart main a few hundred ms after
     * registration, so wait briefly, then compile for the pref — or
     * [guess] (the `auto` resolution) when none was set.
     */
    fun prewarmSpeculative(guess: MaterialBuilder.TargetApi) {
        val t = Thread({
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

    private fun startPrewarm(api: MaterialBuilder.TargetApi) {
        if (!prewarmStarted.add(api.name)) return
        val t = Thread({
            // Abandon a speculative API once a view needs another one.
            fun stale() = activeApi.let { it != null && it != api }
            try {
                for (unlit in listOf(false, true)) {
                    for (mode in listOf(MaterialBuilder.BlendingMode.OPAQUE,
                            MaterialBuilder.BlendingMode.MASKED,
                            MaterialBuilder.BlendingMode.TRANSPARENT)) {
                        if (stale()) return@Thread
                        litPackage(unlit, mode, 0,
                            FsceneRealizer.ALL_BASE_SLOTS, api)
                    }
                }
                if (stale()) return@Thread
                trailPackage(api)
                // The lazily-used catcher + particle packages are NOT
                // prewarmed (integration, 2026-09-28): compiling them
                // here — i.e. concurrently with the first realized
                // frames — reproducibly ended in a Mali CS_BUS_FAULT /
                // GPU page fault ("cpu queue set unrecoverable error")
                // ~0.5 s after the last one finished on the A142
                // Vulkan materials lane (4/4 runs; 0/1 without them,
                // GL unaffected). Mechanism not yet understood — see
                // docs/triage/integration.md. A view compiles them on
                // main at first use, as before 6b4dcca.
            } catch (t: Throwable) {
                // A prewarm failure only costs the cache — the view
                // compiles (and reports) on its own path.
                Log.w(TAG, "material prewarm failed", t)
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
    fun catcherPackage(api: MaterialBuilder.TargetApi): ByteArray? =
        compile("catcher|$api") {
            MaterialBuilder()
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
                    "}\n")
        }

    /** W16 trail ribbon — vertex-color unlit + blend. */
    fun trailPackage(api: MaterialBuilder.TargetApi): ByteArray? =
        compile(trailKey(api)) {
            MaterialBuilder()
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
                        "}\n")
        }

    /** W18 sprite billboard material — see Dart3dView.particleMaterial. */
    fun particlePackage(
        additive: Boolean, api: MaterialBuilder.TargetApi,
    ): ByteArray? = compile("particle|$additive|$api") {
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
        MaterialBuilder()
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
            .material(frag.toString())
    }

    /**
     * The `d3_lit`/`d3_unlit` family: one package per (shading,
     * blending, extension flags, bound slots, API). Returns null when
     * filamat rejects it — the caller degrades (variants) or fatals
     * (the six prebuilts, which have no fallback).
     */
    fun litPackage(
        unlit: Boolean,
        blending: MaterialBuilder.BlendingMode,
        extFlags: Int,
        boundSlots: Int,
        api: MaterialBuilder.TargetApi,
    ): ByteArray? {
        ensureInit()
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
        val key = litKey(unlit, blending, extFlags, boundSlots, api)
        return compile(key) { b.material(body.toString()) }
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
