package com.jasonholtdigital.dart3d

import android.util.Log
import com.google.android.filament.*
import com.google.android.filament.filamat.MaterialBuilder
import java.nio.ByteBuffer
import java.nio.ByteOrder

internal class SelectionOutlineProbe(private val host: Dart3dView) {
    private data class Slot(val instance: Int, val primitive: Int,
                            val material: MaterialInstance)
    private data class Pass(val target: RenderTargets.RenderTargetRec,
                            val capture: View, val overlay: View,
                            val scene: Scene, val entity: Int,
                            val material: MaterialInstance)

    private val engine get() = host.engine
    private val maskScene by lazy { engine.createScene() }
    private var maskMaterial: Material? = null
    private var maskInstance: MaterialInstance? = null
    private var overlayMaterial: Material? = null
    private var vertices: VertexBuffer? = null
    private var indices: IndexBuffer? = null
    private val passes = ArrayList<Pass>()
    private var logged = ""

    private fun compile(name: String, recipe: MaterialRecipe): Material {
        val bytes = checkNotNull(MaterialPackages.compile(
            MaterialPackages.Spec("outline-probe|$name|${engine.backend}", recipe)))
        return Material.Builder().payload(ByteBuffer.wrap(bytes), bytes.size)
            .fenced { build(engine) }
    }

    private fun prepareMaterials() {
        if (maskMaterial != null) return
        val api = MaterialPackages.apiFor(engine.backend)
        maskMaterial = compile("mask", MaterialRecipe()
            .platform(MaterialBuilder.Platform.MOBILE).targetApi(api)
            .name("private_outline_mask").shading(MaterialBuilder.Shading.UNLIT)
            .instanced(true).doubleSided(true)
            .culling(MaterialBuilder.CullingMode.NONE)
            .material("""
                void material(inout MaterialInputs material) {
                    prepareMaterial(material);
                    material.baseColor = vec4(1.0);
                }
            """.trimIndent()))
        maskInstance = maskMaterial!!.createInstance()
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
            .uniformParameter(MaterialBuilder.UniformType.INT, "mode")
            .material("""
                void material(inout MaterialInputs material) {
                    prepareMaterial(material);
                    vec2 uv = uvToRenderTargetUV(getUV0());
                    float center = texture(materialParams_mask, uv).r;
                    float edge = 0.0;
                    for (int y = -3; y <= 3; y++) {
                        for (int x = -3; x <= 3; x++) {
                            if (x*x + y*y > 9) continue;
                            edge = max(edge, texture(materialParams_mask,
                                uv + vec2(float(x), float(y)) * materialParams.texel).r);
                        }
                    }
                    float a = max(0.0, edge - center);
                    if (materialParams.mode == 1) {
                        material.baseColor = vec4(vec3(center), 1.0);
                    } else if (materialParams.mode == 2) {
                        material.baseColor = vec4(0.0);
                    } else {
                        material.baseColor = vec4(vec3(1.0, 0.65, 0.0) * a, a);
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
                    -1f,-1f,0f,0f,0f, 1f,-1f,0f,1f,0f,
                    -1f,1f,0f,0f,1f, 1f,1f,0f,1f,1f))
                it.setBufferAt(engine, 0, data)
            }
        indices = IndexBuffer.Builder().indexCount(6)
            .bufferType(IndexBuffer.Builder.IndexType.USHORT)
            .fenced { build(engine) }.also {
                val data = ByteBuffer.allocateDirect(12).order(ByteOrder.nativeOrder())
                data.asShortBuffer().put(shortArrayOf(0,1,2,2,1,3))
                it.setBuffer(engine, data)
            }
    }

    /** All standalone submissions precede beginFrame; each normal pass gets its own mask. */
    fun capture(renderer: Renderer, cameras: List<Pair<Camera, Viewport>>,
                layerMasks: List<Int>) {
        val control = host.nodesById.values.firstOrNull {
            it.name?.startsWith("__outline_probe__:") == true
        }?.name
        if (control == null) {
            clearPasses()
            return
        }
        val parts = control.split(':')
        val mode = parts[2]
        if (mode == "off") {
            clearPasses()
            return
        }
        val selected = host.nodesById.values.single { it.name == "u3.target.${parts[1]}" }
        prepareMaterials()
        if (passes.size != cameras.size || passes.indices.any {
            passes[it].target.spec.width != cameras[it].second.width ||
                passes[it].target.spec.height != cameras[it].second.height
        }) {
            clearPasses()
            for ((camera, viewport) in cameras) passes.add(makePass(camera, viewport))
        }
        val rm = engine.renderableManager
        val slots = ArrayList<Slot>()
        val entities = listOf(selected.entity) + selected.instanceEntities
        maskScene.removeAllEntities()
        try {
            for (entity in entities) {
                val ri = rm.getInstance(entity)
                if (ri == 0) continue
                maskScene.addEntity(entity)
                for (p in 0 until rm.getPrimitiveCount(ri)) {
                    slots.add(Slot(ri, p, rm.getMaterialInstanceAt(ri, p)))
                    rm.setMaterialInstanceAt(ri, p, maskInstance!!)
                }
            }
            val clear = renderer.clearOptions
            try {
                renderer.clearOptions = Renderer.ClearOptions().apply {
                    this.clear = true
                    clearColor = doubleArrayOf(0.0,0.0,0.0,0.0)
                }
                for ((i, pass) in passes.withIndex()) {
                    pass.capture.camera = cameras[i].first
                    pass.capture.setVisibleLayers(0xFF, layerMasks[i] and 0xFF)
                    pass.overlay.camera = cameras[i].first
                    pass.overlay.viewport = cameras[i].second
                    pass.material.setParameter("mode", when (mode) {
                        "mask" -> 1; "control" -> 2; else -> 0
                    })
                    renderer.renderStandaloneView(pass.capture)
                }
            } finally {
                renderer.clearOptions = clear
            }
        } finally {
            for (slot in slots) rm.setMaterialInstanceAt(
                slot.instance, slot.primitive, slot.material)
            maskScene.removeAllEntities()
        }
        if (logged != control) {
            Log.i("dart3d", "outline probe $control entities=${entities.size} slots=${slots.size} passes=${passes.size}")
            logged = control
        }
    }

    fun composite(renderer: Renderer, index: Int) {
        passes.getOrNull(index)?.let { renderer.render(it.overlay) }
    }

    private fun makePass(camera: Camera, viewport: Viewport): Pass {
        val target = RenderTargets.build(engine, RenderTargets.Spec(
            viewport.width, viewport.height, "everyFrame", 0, "nearest", "clampToEdge"))
        val capture = engine.createView().apply {
            scene = maskScene
            this.camera = camera
            this.viewport = Viewport(0, 0, viewport.width, viewport.height)
            setRenderTarget(target.rt)
            setPostProcessingEnabled(false)
            setShadowingEnabled(false)
            setFrustumCullingEnabled(false)
        }
        val material = overlayMaterial!!.createInstance().apply {
            setDepthCulling(false)
            setParameter("mask", target.colorTex, target.sampler)
            setParameter("texel", 1f / viewport.width, 1f / viewport.height)
        }
        val entity = EntityManager.get().create()
        RenderableManager.Builder(1).boundingBox(Box(0f,0f,0f,1f,1f,1f))
            .culling(false).castShadows(false).receiveShadows(false)
            .geometry(0, RenderableManager.PrimitiveType.TRIANGLES, vertices!!, indices!!)
            .material(0, material).fenced { build(engine, entity) }
        val scene = engine.createScene().apply { addEntity(entity) }
        val overlay = engine.createView().apply {
            this.scene = scene
            this.camera = camera
            this.viewport = viewport
            setBlendMode(View.BlendMode.TRANSLUCENT)
            setPostProcessingEnabled(false)
            setShadowingEnabled(false)
            setFrustumCullingEnabled(false)
        }
        return Pass(target, capture, overlay, scene, entity, material)
    }

    fun clearPasses() {
        for (pass in passes) {
            pass.capture.setRenderTarget(null)
            engine.destroyView(pass.capture)
            engine.destroyView(pass.overlay)
            engine.destroyScene(pass.scene)
            engine.destroyEntity(pass.entity)
            EntityManager.get().destroy(pass.entity)
            engine.destroyMaterialInstance(pass.material)
            engine.destroyRenderTarget(pass.target.rt)
            engine.destroyTexture(pass.target.colorTex)
            pass.target.depthTex?.let(engine::destroyTexture)
        }
        passes.clear()
    }

    fun dispose() {
        clearPasses()
        if (maskMaterial == null) return
        engine.destroyScene(maskScene)
        engine.destroyMaterialInstance(maskInstance!!)
        engine.destroyMaterial(maskMaterial!!)
        engine.destroyMaterial(overlayMaterial!!)
        engine.destroyVertexBuffer(vertices!!)
        engine.destroyIndexBuffer(indices!!)
    }
}
