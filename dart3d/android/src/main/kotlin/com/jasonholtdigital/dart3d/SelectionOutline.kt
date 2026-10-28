package com.jasonholtdigital.dart3d

import android.util.Log
import com.google.android.filament.Box
import com.google.android.filament.Camera
import com.google.android.filament.EntityManager
import com.google.android.filament.IndexBuffer
import com.google.android.filament.Material
import com.google.android.filament.MaterialInstance
import com.google.android.filament.RenderTarget
import com.google.android.filament.RenderableManager
import com.google.android.filament.Renderer
import com.google.android.filament.Scene
import com.google.android.filament.Texture
import com.google.android.filament.TextureSampler
import com.google.android.filament.VertexBuffer
import com.google.android.filament.View
import com.google.android.filament.Viewport
import com.google.android.filament.filamat.MaterialBuilder
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.roundToInt

internal class SelectionOutline {
    data class LinearRgba(val r: Float, val g: Float, val b: Float, val a: Float)
    data class Change(val node: Long, val color: LinearRgba?)

    private val colors = HashMap<Long, LinearRgba>()

    val isEmpty: Boolean get() = colors.isEmpty()

    fun forEachActive(visit: (Long, LinearRgba) -> Unit) {
        for (id in colors.keys.sorted()) {
            visit(id, colors.getValue(id))
        }
    }

    fun apply(changes: List<Change>) {
        for ((node, color) in changes) {
            if (color == null) colors.remove(node) else colors[node] = color
        }
    }

    fun removeNodes(ids: Set<Long>) {
        colors.keys.removeAll(ids)
    }

    fun retainNodes(ids: Set<Long>) {
        colors.keys.retainAll(ids)
    }

    fun clearScene() {
        colors.clear()
    }
}

internal class SelectionOutlineRenderer(private val host: Dart3dView) {
    data class Request(
        val destinationRt: RenderTarget?,
        val destWidth: Int,
        val destHeight: Int,
        val camera: Camera,
        val viewport: Viewport,
        val layerMask: Int,
    )

    private data class Slot(
        val instance: Int,
        val primitive: Int,
        val material: MaterialInstance,
    )

    private data class Pass(
        val width: Int,
        val height: Int,
        val destinationRt: RenderTarget?,
        val maskColor: Texture,
        val maskDepth: Texture,
        val maskRt: RenderTarget,
        val capture: View,
        val overlay: View,
        val scene: Scene,
        val entity: Int,
        val material: MaterialInstance,
    )

    private val engine get() = host.engine
    private var maskScene: Scene? = null
    private var maskMaterial: Material? = null
    private val maskInstances = HashMap<SelectionOutline.LinearRgba, MaterialInstance>()
    private var overlayMaterial: Material? = null
    private var vertices: VertexBuffer? = null
    private var indices: IndexBuffer? = null
    private val maskSampler = TextureSampler(
        TextureSampler.MinFilter.NEAREST,
        TextureSampler.MagFilter.NEAREST,
        TextureSampler.WrapMode.CLAMP_TO_EDGE,
    )
    private val passes = ArrayList<Pass>()
    private var logged = ""

    private fun compile(name: String, recipe: MaterialRecipe): Material {
        val bytes = checkNotNull(MaterialPackages.compile(
            MaterialPackages.Spec("outline|$name|${engine.backend}", recipe)))
        return Material.Builder().payload(ByteBuffer.wrap(bytes), bytes.size)
            .fenced { build(engine) }
    }

    private fun prepareMaterials() {
        if (maskMaterial != null) return
        maskScene = engine.createScene()
        val api = MaterialPackages.apiFor(engine.backend)
        maskMaterial = compile("mask", MaterialRecipe()
            .platform(MaterialBuilder.Platform.MOBILE).targetApi(api)
            .name("private_outline_mask").shading(MaterialBuilder.Shading.UNLIT)
            .instanced(true).doubleSided(true)
            .culling(MaterialBuilder.CullingMode.NONE)
            .uniformParameter(MaterialBuilder.UniformType.FLOAT4, "maskColor")
            .material("""
                void material(inout MaterialInputs material) {
                    prepareMaterial(material);
                    material.baseColor = materialParams.maskColor;
                }
            """.trimIndent()))
        overlayMaterial = compile("overlay", MaterialRecipe()
            .platform(MaterialBuilder.Platform.MOBILE).targetApi(api)
            .name("private_outline_overlay").shading(MaterialBuilder.Shading.UNLIT)
            .vertexDomain(MaterialBuilder.VertexDomain.DEVICE)
            .blending(MaterialBuilder.BlendingMode.TRANSPARENT).depthWrite(false)
            .culling(MaterialBuilder.CullingMode.NONE).flipUV(false)
            .require(MaterialBuilder.VertexAttribute.UV0)
            .samplerParameter(MaterialBuilder.SamplerType.SAMPLER_2D,
                MaterialBuilder.SamplerFormat.FLOAT,
                MaterialBuilder.ParameterPrecision.HIGH, "mask")
            .uniformParameter(MaterialBuilder.UniformType.FLOAT2, "texel")
            .uniformParameter(MaterialBuilder.UniformType.FLOAT4, "viewportNorm")
            .uniformParameter(MaterialBuilder.UniformType.INT, "mode")
            .material("""
                void material(inout MaterialInputs material) {
                    prepareMaterial(material);
                    if (materialParams.mode == 1) {
                        material.baseColor = vec4(0.0);
                        return;
                    }
                    vec2 subUv = (getUV0() - materialParams.viewportNorm.xy) /
                        materialParams.viewportNorm.zw;
                    if (subUv.x < 0.0 || subUv.x > 1.0 || subUv.y < 0.0 || subUv.y > 1.0) {
                        material.baseColor = vec4(0.0);
                        return;
                    }
                    vec2 uv = uvToRenderTargetUV(subUv);
                    vec4 center = texture(materialParams_mask, uv);
                    if (materialParams.mode == 3) {
                        material.baseColor = vec4(center.rgb * center.a, 1.0);
                        return;
                    }
                    float bestCoverage = 0.0;
                    vec3 outlineColor = vec3(0.0);
                    for (int y = -3; y <= 3; y++) {
                        for (int x = -3; x <= 3; x++) {
                            if (x * x + y * y > 9) continue;
                            vec4 neighbor = texture(materialParams_mask,
                                uv + vec2(float(x), float(y)) * materialParams.texel);
                            if (neighbor.a > bestCoverage) {
                                bestCoverage = neighbor.a;
                                outlineColor = neighbor.rgb;
                            }
                        }
                    }
                    if (center.a < 0.001 && bestCoverage > 0.001) {
                        material.baseColor = vec4(outlineColor, 1.0);
                    } else {
                        material.baseColor = vec4(0.0);
                    }
                }
            """.trimIndent()))
        vertices = VertexBuffer.Builder().vertexCount(4).bufferCount(1)
            .attribute(VertexBuffer.VertexAttribute.POSITION, 0,
                VertexBuffer.AttributeType.FLOAT3, 0, 20)
            .attribute(VertexBuffer.VertexAttribute.UV0, 0,
                VertexBuffer.AttributeType.FLOAT2, 12, 20)
            .fenced { build(engine) }.also {
                val data = ByteBuffer.allocateDirect(80).order(ByteOrder.nativeOrder())
                data.asFloatBuffer().put(floatArrayOf(
                    -1f, -1f, 0f, 0f, 0f, 1f, -1f, 0f, 1f, 0f,
                    -1f, 1f, 0f, 0f, 1f, 1f, 1f, 0f, 1f, 1f))
                it.setBufferAt(engine, 0, data)
            }
        indices = IndexBuffer.Builder().indexCount(6)
            .bufferType(IndexBuffer.Builder.IndexType.USHORT)
            .fenced { build(engine) }.also {
                val data = ByteBuffer.allocateDirect(12).order(ByteOrder.nativeOrder())
                data.asShortBuffer().put(shortArrayOf(0, 1, 2, 2, 1, 3))
                it.setBuffer(engine, data)
            }
    }

    private fun isHidden(key: Long): Boolean {
        var k: Long? = key
        while (k != null) {
            val rec = host.nodesById[k] ?: return false
            if (rec.hidden) return true
            k = rec.parentKey
        }
        return false
    }

    private fun maskInstanceFor(rgba: SelectionOutline.LinearRgba): MaterialInstance {
        val eff = SelectionOutline.LinearRgba(
            rgba.r, rgba.g, rgba.b, if (rgba.a == 0f) 1f else rgba.a)
        return maskInstances.getOrPut(eff) {
            maskMaterial!!.createInstance().apply {
                setParameter("maskColor", eff.r, eff.g, eff.b, eff.a)
            }
        }
    }

    fun capture(
        renderer: Renderer,
        selection: SelectionOutline,
        requests: List<Request>,
    ) {
        val viewsProbe = host.nodesById.values.firstOrNull {
            it.name == "__u3_outline_views_probe__"
        }
        val legacyProbe = host.nodesById.values.firstOrNull {
            it.name?.startsWith("__outline_probe__:") == true
        }?.name
        val mode = when {
            viewsProbe != null -> viewsProbe.localPos[0].roundToInt()
            legacyProbe != null -> when (legacyProbe.split(':').getOrNull(2)) {
                "off" -> 0
                "control" -> 1
                "mask" -> 3
                else -> 2
            }
            !selection.isEmpty -> 2
            else -> 0
        }
        if (mode == 0 || requests.isEmpty() ||
            requests.any {
                it.viewport.width <= 0 || it.viewport.height <= 0 ||
                    it.destWidth <= 0 || it.destHeight <= 0
            }
        ) {
            clearPasses()
            return
        }
        val selectedDraws = ArrayList<Pair<FsceneRealizer.NodeRec, SelectionOutline.LinearRgba>>()
        selection.forEachActive { id, rgba ->
            val rec = host.nodesById[id] ?: return@forEachActive
            if (!isHidden(id)) selectedDraws.add(rec to rgba)
        }
        if (selectedDraws.isEmpty() && legacyProbe != null) {
            val targetName = "u3.target.${legacyProbe.split(':').getOrNull(1)}"
            host.nodesById.values.firstOrNull { it.name == targetName }?.let { rec ->
                selectedDraws.add(rec to SelectionOutline.LinearRgba(1.0f, 0.65f, 0.0f, 1.0f))
            }
        }
        if (selectedDraws.isEmpty() && viewsProbe == null && legacyProbe == null) {
            clearPasses()
            return
        }
        prepareMaterials()
        if (passes.size != requests.size || passes.indices.any { i ->
            passes[i].width != requests[i].viewport.width ||
                passes[i].height != requests[i].viewport.height ||
                passes[i].destinationRt !== requests[i].destinationRt
        }) {
            clearPasses()
            for (req in requests) passes.add(makePass(req))
        }
        val rm = engine.renderableManager
        val slots = ArrayList<Slot>()
        val scene = maskScene!!
        scene.removeAllEntities()
        var entityCount = 0
        try {
            for ((rec, rgba) in selectedDraws) {
                val mi = maskInstanceFor(rgba)
                val entities = listOf(rec.entity) + rec.instanceEntities
                for (entity in entities) {
                    if (!host.scene.hasEntity(entity)) continue
                    val ri = rm.getInstance(entity)
                    if (ri == 0) continue
                    scene.addEntity(entity)
                    entityCount++
                    for (p in 0 until rm.getPrimitiveCount(ri)) {
                        slots.add(Slot(ri, p, rm.getMaterialInstanceAt(ri, p)))
                        rm.setMaterialInstanceAt(ri, p, mi)
                    }
                }
            }
            val savedClear = renderer.clearOptions
            try {
                renderer.clearOptions = Renderer.ClearOptions().apply {
                    clear = true
                    discard = true
                    clearColor = doubleArrayOf(0.0, 0.0, 0.0, 0.0)
                }
                for ((i, pass) in passes.withIndex()) {
                    val req = requests[i]
                    pass.capture.camera = req.camera
                    pass.capture.setVisibleLayers(0xFF, req.layerMask and 0xFF)
                    pass.overlay.camera = req.camera
                    // Filament's non-post-processed render path initializes the
                    // FrameGraph colorPassDescriptor scissor at (0, 0, vp.w, vp.h)
                    // while RenderPassParams.viewport uses (vp.left, vp.bottom, vp.w, vp.h),
                    // clipping any non-zero-origin sub-viewport. Keep the overlay view
                    // at (0, 0, destWidth, destHeight) and map UV0 onto req.viewport
                    // through `viewportNorm`.
                    pass.overlay.viewport = Viewport(0, 0, req.destWidth, req.destHeight)
                    pass.material.setParameter(
                        "viewportNorm",
                        req.viewport.left.toFloat() / req.destWidth.toFloat(),
                        req.viewport.bottom.toFloat() / req.destHeight.toFloat(),
                        req.viewport.width.toFloat() / req.destWidth.toFloat(),
                        req.viewport.height.toFloat() / req.destHeight.toFloat(),
                    )
                    pass.material.setParameter("mode", mode)
                    renderer.renderStandaloneView(pass.capture)
                }
            } finally {
                renderer.clearOptions = savedClear
            }
        } finally {
            for (slot in slots) {
                rm.setMaterialInstanceAt(slot.instance, slot.primitive, slot.material)
            }
            scene.removeAllEntities()
        }
        val summary = "mode=$mode nodes=${selectedDraws.size} entities=$entityCount slots=${slots.size} passes=${passes.size}"
        if (logged != summary) {
            Log.i("dart3d", "selection outline $summary")
            logged = summary
        }
    }

    fun composite(renderer: Renderer, index: Int) {
        val pass = passes.getOrNull(index) ?: return
        val savedClear = renderer.clearOptions
        try {
            renderer.clearOptions = Renderer.ClearOptions().apply {
                clear = false
                discard = false
            }
            renderer.render(pass.overlay)
        } finally {
            renderer.clearOptions = savedClear
        }
    }

    private fun makePass(req: Request): Pass {
        val w = req.viewport.width
        val h = req.viewport.height
        val maskColor = Texture.Builder()
            .width(w).height(h).levels(1)
            .sampler(Texture.Sampler.SAMPLER_2D)
            .format(Texture.InternalFormat.RGBA16F)
            .usage(Texture.Usage.COLOR_ATTACHMENT or Texture.Usage.SAMPLEABLE)
            .fenced { build(engine) }
        val maskDepth = Texture.Builder()
            .width(w).height(h).levels(1)
            .sampler(Texture.Sampler.SAMPLER_2D)
            .format(Texture.InternalFormat.DEPTH24)
            .usage(Texture.Usage.DEPTH_ATTACHMENT)
            .fenced { build(engine) }
        val maskRt = RenderTarget.Builder()
            .texture(RenderTarget.AttachmentPoint.COLOR, maskColor)
            .texture(RenderTarget.AttachmentPoint.DEPTH, maskDepth)
            .fenced { build(engine) }
        val capture = engine.createView().apply {
            scene = maskScene
            camera = req.camera
            viewport = Viewport(0, 0, w, h)
            setRenderTarget(maskRt)
            setPostProcessingEnabled(false)
            setShadowingEnabled(false)
            setFrustumCullingEnabled(false)
        }
        val material = overlayMaterial!!.createInstance().apply {
            setDepthCulling(false)
            setParameter("mask", maskColor, maskSampler)
            setParameter("texel", 1f / w, 1f / h)
            setParameter(
                "viewportNorm",
                req.viewport.left.toFloat() / req.destWidth.toFloat(),
                req.viewport.bottom.toFloat() / req.destHeight.toFloat(),
                req.viewport.width.toFloat() / req.destWidth.toFloat(),
                req.viewport.height.toFloat() / req.destHeight.toFloat(),
            )
        }
        val entity = EntityManager.get().create()
        RenderableManager.Builder(1).boundingBox(Box(0f, 0f, 0f, 1f, 1f, 1f))
            .culling(false).castShadows(false).receiveShadows(false)
            .geometry(0, RenderableManager.PrimitiveType.TRIANGLES, vertices!!, indices!!)
            .material(0, material).fenced { build(engine, entity) }
        val scene = engine.createScene().apply { addEntity(entity) }
        val overlay = engine.createView().apply {
            this.scene = scene
            camera = req.camera
            viewport = Viewport(0, 0, req.destWidth, req.destHeight)
            setRenderTarget(req.destinationRt)
            setBlendMode(View.BlendMode.TRANSLUCENT)
            setPostProcessingEnabled(false)
            setShadowingEnabled(false)
            setFrustumCullingEnabled(false)
        }
        return Pass(w, h, req.destinationRt, maskColor, maskDepth, maskRt,
            capture, overlay, scene, entity, material)
    }

    fun clearPasses() {
        for (pass in passes) {
            pass.capture.setRenderTarget(null)
            pass.overlay.setRenderTarget(null)
            engine.destroyView(pass.capture)
            engine.destroyView(pass.overlay)
            engine.destroyScene(pass.scene)
            engine.destroyEntity(pass.entity)
            EntityManager.get().destroy(pass.entity)
            engine.destroyMaterialInstance(pass.material)
            engine.destroyRenderTarget(pass.maskRt)
            engine.destroyTexture(pass.maskColor)
            engine.destroyTexture(pass.maskDepth)
        }
        passes.clear()
    }

    fun dispose() {
        clearPasses()
        for (mi in maskInstances.values) engine.destroyMaterialInstance(mi)
        maskInstances.clear()
        maskScene?.let(engine::destroyScene)
        maskScene = null
        maskMaterial?.let(engine::destroyMaterial)
        maskMaterial = null
        overlayMaterial?.let(engine::destroyMaterial)
        overlayMaterial = null
        vertices?.let(engine::destroyVertexBuffer)
        vertices = null
        indices?.let(engine::destroyIndexBuffer)
        indices = null
    }
}
