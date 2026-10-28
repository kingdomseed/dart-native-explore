package com.jasonholtdigital.dart3d

import android.opengl.Matrix
import android.util.Log
import com.google.android.filament.Camera
import com.google.android.filament.Engine
import com.google.android.filament.EntityManager
import com.google.android.filament.IndexBuffer
import com.google.android.filament.LightManager
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
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

internal class BakedShadowCatcherPass(private val host: Dart3dView) {

    private sealed interface CacheState {
        data object Pending : CacheState
        data class Ready(
            val target: Target,
            val region: FloatArray,
        ) : CacheState
    }

    private data class Entry(
        val settings: FsceneRealizer.ShadowCatcherSettings,
        var state: CacheState = CacheState.Pending,
    )

    private data class Target(
        val texture: Texture,
        val renderTarget: RenderTarget,
        val depth: Texture? = null,
    )

    private data class Light(
        val entity: Int,
        val type: LightManager.Type,
        val position: FloatArray,
        val direction: FloatArray,
        val inverseRange: Float,
        val coneScale: Float,
        val coneOffset: Float,
    )

    private data class BorrowedSlot(
        val entity: Int,
        val primitive: Int,
        val original: MaterialInstance,
        val temporary: MaterialInstance,
    )

    private data class InstanceTransforms(
        val buffer: com.google.android.filament.InstanceBuffer,
        val transforms: FloatArray,
        val count: Int,
    )

    private val cache = LinkedHashMap<Long, Entry>()

    fun install(settings: Map<Long, FsceneRealizer.ShadowCatcherSettings>) {
        clear()
        for ((key, value) in settings) {
            if (value.mode == FsceneRealizer.ShadowCatcherMode.BAKED) {
                cache[key] = Entry(value)
            }
        }
    }

    fun upsert(
        materialId: Long,
        settings: FsceneRealizer.ShadowCatcherSettings?,
    ) {
        cache.remove(materialId)?.let(::destroyReady)
        if (settings?.mode == FsceneRealizer.ShadowCatcherMode.BAKED) {
            cache[materialId] = Entry(settings)
            Log.i("dart3d", "baked catcher material=$materialId refresh scheduled")
        }
    }

    fun renderDirty(renderer: Renderer, context: FsceneRealizer.Context) {
        for ((materialId, entry) in cache) {
            if (entry.state !is CacheState.Pending) continue
            val receiver = context.firstBakedCatcherReceiver(materialId)
                ?: continue
            val ready = capture(renderer, receiver, entry.settings)
                ?: continue
            context.bindBakedCatcher(materialId, ready.target.texture,
                ready.region)
            entry.state = ready
            Log.i("dart3d", "baked catcher material=$materialId captured " +
                "size=${ready.target.texture.width}")
        }
    }

    fun clear() {
        for (entry in cache.values) destroyReady(entry)
        cache.clear()
    }

    fun dispose() = clear()

    private fun destroyReady(entry: Entry) {
        val state = entry.state as? CacheState.Ready ?: return
        destroyTarget(state.target)
    }

    private fun capture(
        renderer: Renderer,
        receiver: FsceneRealizer.BakedCatcherReceiver,
        settings: FsceneRealizer.ShadowCatcherSettings,
    ): CacheState.Ready? {
        val bounds = receiver.minMaxBounds
        val minX = bounds[0]
        val minY = bounds[1]
        val minZ = bounds[2]
        val maxX = bounds[3]
        val maxY = bounds[4]
        val maxZ = bounds[5]
        val sizeX = maxX - minX
        val sizeZ = maxZ - minZ
        val worldScaleX = length(receiver.worldMatrix, 0)
        val worldScaleZ = length(receiver.worldMatrix, 8)
        val footprintWorld = max(sizeX * worldScaleX, sizeZ * worldScaleZ)
        val resolution = if (settings.softness <= 0f || footprintWorld <= 0f) {
            256
        } else {
            ceil(footprintWorld / settings.softness * 4f)
                .toInt().coerceIn(16, 1024)
        }
        val region = floatArrayOf(
            minX, maxZ,
            if (sizeX > 0f) 1f / sizeX else 1f,
            if (sizeZ > 0f) 1f / sizeZ else 1f,
        )
        val casterDepth = casterDepthBounds(receiver, minY, maxY)
            ?: return null
        val depthSpan = max(casterDepth.second - casterDepth.first, 1e-3f)
        val depthPadding = max(depthSpan * 0.05f, 0.05f)
        val cameraOffset = casterDepth.second + depthPadding
        val near = depthPadding * length(receiver.worldMatrix, 4)
        val far = max(near + 0.05f,
            (cameraOffset - casterDepth.first) * length(receiver.worldMatrix, 4))

        val engine = host.engine
        val captureTarget = createTarget(resolution, depth = true)
        val aggregateA = createTarget(resolution)
        val aggregateB = createTarget(resolution)
        val blurTarget = createTarget(resolution)
        val finalTarget = createTarget(resolution)
        val helper = UtilityRenderer(engine, host.bakedCatcherUtilityMaterial,
            host.bakedCatcherTextureSampler, host.bakedCatcherZeroShadowTexture)
        var retained = false
        try {
            helper.fill(renderer, aggregateA, 0)
            val lights = shadowLights()
            var aggregate = aggregateA
            var next = aggregateB
            val camera = createCaptureCamera(receiver, cameraOffset,
                casterDepth, near, far) ?: return null
            val captureView = engine.createView().apply {
                scene = host.scene
                this.camera = camera.camera
                setRenderTarget(captureTarget.renderTarget)
                viewport = Viewport(0, 0, resolution, resolution)
                setVisibleLayers(0xFF, 0xFF)
                setPostProcessingEnabled(false)
                setFrustumCullingEnabled(false)
                host.configureBakedCaptureView(this)
            }
            try {
                for (light in lights) {
                    helper.fill(renderer, captureTarget, 0)
                    captureLight(renderer, receiver, light, captureView)
                    helper.combine(renderer, aggregate, captureTarget, next)
                    val prior = aggregate
                    aggregate = next
                    next = prior
                }
                helper.blur(renderer, aggregate, blurTarget,
                    resolution, horizontal = true)
                helper.blur(renderer, blurTarget, finalTarget,
                    resolution, horizontal = false)
            } finally {
                captureView.setRenderTarget(null)
                engine.destroyView(captureView)
                engine.destroyCameraComponent(camera.entity)
                EntityManager.get().destroy(camera.entity)
            }
            retained = true
            return CacheState.Ready(finalTarget, region)
        } finally {
            helper.destroy()
            destroyTarget(captureTarget)
            destroyTarget(aggregateA)
            destroyTarget(aggregateB)
            destroyTarget(blurTarget)
            if (!retained) destroyTarget(finalTarget)
        }
    }

    private data class CaptureCamera(val entity: Int, val camera: Camera)

    private fun createCaptureCamera(
        receiver: FsceneRealizer.BakedCatcherReceiver,
        cameraOffset: Float,
        depth: Pair<Float, Float>,
        near: Float,
        far: Float,
    ): CaptureCamera? {
        val world = receiver.worldMatrix
        val right = unit(world[0], world[1], world[2])
        var up = unit(-world[8], -world[9], -world[10])
        var back = unit(
            right[1] * up[2] - right[2] * up[1],
            right[2] * up[0] - right[0] * up[2],
            right[0] * up[1] - right[1] * up[0],
        )
        val localY = floatArrayOf(world[4], world[5], world[6])
        if (dot(back, localY) < 0f) {
            up = floatArrayOf(-up[0], -up[1], -up[2])
            back = floatArrayOf(-back[0], -back[1], -back[2])
        }
        val cameraWorld = floatArrayOf(
            right[0], right[1], right[2], 0f,
            up[0], up[1], up[2], 0f,
            back[0], back[1], back[2], 0f,
            world[12] + back[0] * cameraOffset * length(world, 4),
            world[13] + back[1] * cameraOffset * length(world, 4),
            world[14] + back[2] * cameraOffset * length(world, 4),
            1f,
        )
        val view = FloatArray(16)
        if (!Matrix.invertM(view, 0, cameraWorld, 0)) return null
        val viewWorld = FloatArray(16)
        Matrix.multiplyMM(viewWorld, 0, view, 0, world, 0)
        val worldToView = FloatArray(16)
        if (!Matrix.invertM(worldToView, 0, viewWorld, 0)) return null

        val bounds = receiver.minMaxBounds
        val sizeX = bounds[3] - bounds[0]
        val sizeZ = bounds[5] - bounds[2]
        val depthSpan = max(depth.second - depth.first, 1e-3f)
        val localToClip = FloatArray(16)
        localToClip[0] = if (sizeX > 0f) 2f / sizeX else 1f
        localToClip[9] = if (sizeZ > 0f) -2f / sizeZ else -1f
        localToClip[6] = 2f / depthSpan
        localToClip[12] = if (sizeX > 0f) -2f * bounds[0] / sizeX - 1f else 0f
        localToClip[13] = if (sizeZ > 0f) 2f * bounds[5] / sizeZ - 1f else 0f
        localToClip[14] = -2f * depth.first / depthSpan - 1f
        localToClip[15] = 1f
        val projection = FloatArray(16)
        Matrix.multiplyMM(projection, 0, localToClip, 0, worldToView, 0)

        val entity = EntityManager.get().create()
        val camera = host.engine.createCamera(entity)
        camera.setModelMatrix(cameraWorld)
        val projectionD = DoubleArray(16) { projection[it].toDouble() }
        camera.setCustomProjection(projectionD, projectionD,
            max(near.toDouble(), 0.001), max(far.toDouble(), near + 0.01).toDouble())
        return CaptureCamera(entity, camera)
    }

    private fun casterDepthBounds(
        receiver: FsceneRealizer.BakedCatcherReceiver,
        receiverMinY: Float,
        receiverMaxY: Float,
    ): Pair<Float, Float>? {
        val receiverInverse = FloatArray(16)
        if (!Matrix.invertM(receiverInverse, 0, receiver.worldMatrix, 0)) {
            return null
        }
        var minY = min(receiverMinY, receiverMaxY)
        var maxY = max(receiverMinY, receiverMaxY)
        val rm = host.engine.renderableManager
        val tm = host.engine.transformManager
        host.scene.forEach { entity ->
            if (!rm.hasComponent(entity)) return@forEach
            val renderable = rm.getInstance(entity)
            if (!rm.isShadowCaster(renderable)) return@forEach
            if (entity == receiver.entity &&
                rm.getPrimitiveCount(renderable) == 1) return@forEach
            val box = rm.getAxisAlignedBoundingBox(renderable)
            if (box.isEmpty) return@forEach
            val lo = box.getMin(FloatArray(3))
            val hi = box.getMax(FloatArray(3))
            val world = FloatArray(16)
            tm.getWorldTransform(tm.getInstance(entity), world)
            for (x in 0..1) for (y in 0..1) for (z in 0..1) {
                val localPoint = floatArrayOf(
                    if (x == 0) lo[0] else hi[0],
                    if (y == 0) lo[1] else hi[1],
                    if (z == 0) lo[2] else hi[2],
                    1f,
                )
                val worldPoint = FloatArray(4)
                Matrix.multiplyMV(worldPoint, 0, world, 0, localPoint, 0)
                val receiverPoint = FloatArray(4)
                Matrix.multiplyMV(receiverPoint, 0, receiverInverse, 0,
                    worldPoint, 0)
                minY = min(minY, receiverPoint[1])
                maxY = max(maxY, receiverPoint[1])
            }
        }
        return minY to maxY
    }

    private fun shadowLights(): List<Light> {
        val out = ArrayList<Light>()
        val lm = host.engine.lightManager
        var hasDirectionalCapture = false
        host.scene.forEach { entity ->
            val instance = lm.getInstance(entity)
            if (instance <= 0 || !lm.isShadowCaster(instance)) return@forEach
            val type = lm.getType(instance)
            if (type == LightManager.Type.DIRECTIONAL) {
                if (hasDirectionalCapture) return@forEach
                hasDirectionalCapture = true
            }
            if (type != LightManager.Type.DIRECTIONAL &&
                type != LightManager.Type.FOCUSED_SPOT &&
                type != LightManager.Type.SPOT
            ) return@forEach
            val direction = lm.getDirection(instance, FloatArray(3))
            val directional = type == LightManager.Type.DIRECTIONAL
            val position = if (directional) FloatArray(3)
                else lm.getPosition(instance, FloatArray(3))
            val transformManager = host.engine.transformManager
            val transform = transformManager.getInstance(entity)
            if (transform != 0) {
                val world = FloatArray(16)
                transformManager.getWorldTransform(transform, world)
                val worldPosition = FloatArray(4)
                Matrix.multiplyMV(worldPosition, 0, world, 0,
                    floatArrayOf(position[0], position[1], position[2], 1f), 0)
                System.arraycopy(worldPosition, 0, position, 0, 3)
                val inverse = FloatArray(16)
                Matrix.invertM(inverse, 0, world, 0)
                val worldDirection = unit(
                    inverse[0] * direction[0] + inverse[1] * direction[1] +
                        inverse[2] * direction[2],
                    inverse[4] * direction[0] + inverse[5] * direction[1] +
                        inverse[6] * direction[2],
                    inverse[8] * direction[0] + inverse[9] * direction[1] +
                        inverse[10] * direction[2])
                System.arraycopy(worldDirection, 0, direction, 0, 3)
            }
            val range = if (directional) 0f else lm.getFalloff(instance)
            val inverseRange = if (range > 0f) 1f / range else 0f
            val coneWidth = if (directional) 0f else
                cos(lm.getSpotLightInnerCone(instance)) -
                    cos(lm.getSpotLightOuterCone(instance))
            val coneScale = if (directional) 0f else if (coneWidth == 0f) 1e6f
                else 1f / coneWidth
            val coneOffset = if (directional) 0f else
                -cos(lm.getSpotLightOuterCone(instance)) * coneScale
            out += Light(
                entity, type, position, direction, inverseRange,
                coneScale, coneOffset)
        }
        return out
    }

    private fun captureLight(
        renderer: Renderer,
        receiver: FsceneRealizer.BakedCatcherReceiver,
        light: Light,
        view: View,
    ) {
        val engine = host.engine
        val scene = host.scene
        val rm = engine.renderableManager
        val lm = engine.lightManager
        val savedSkybox = scene.skybox
        val savedIndirect = scene.indirectLight
        val removedLights = ArrayList<Int>()
        val borrowedSlots = ArrayList<BorrowedSlot>()
        val savedInstances = saveInstanceTransforms(receiver.owner)
        val captureMaterial = host.bakedCatcherCaptureMaterial
        val receiverMaterial = captureMaterial.createInstance()
        try {
            receiverMaterial.setCullingMode(Material.CullingMode.NONE,
                Material.CullingMode.FRONT_AND_BACK)
            receiverMaterial.setDepthCulling(false)
            receiverMaterial.setParameter("lightKind",
                if (light.type == LightManager.Type.DIRECTIONAL) 0 else 1)
            receiverMaterial.setParameter("lightPosition",
                light.position[0], light.position[1], light.position[2])
            receiverMaterial.setParameter("lightDirection",
                light.direction[0], light.direction[1], light.direction[2])
            receiverMaterial.setParameter("inverseRange", light.inverseRange)
            receiverMaterial.setParameter("coneScale", light.coneScale)
            receiverMaterial.setParameter("coneOffset", light.coneOffset)
            isolateReceiverInstances(savedInstances)
            scene.setSkybox(null)
            scene.setIndirectLight(null)
            val otherLights = ArrayList<Int>()
            scene.forEach { entity ->
                val instance = lm.getInstance(entity)
                if (instance > 0 && entity != light.entity &&
                    (light.type != LightManager.Type.DIRECTIONAL ||
                        lm.getType(instance) != LightManager.Type.DIRECTIONAL)) {
                    otherLights.add(entity)
                }
            }
            for (entity in otherLights) {
                scene.remove(entity)
                removedLights.add(entity)
            }
            val entities = ArrayList<Int>()
            scene.forEach { entities.add(it) }
            for (entity in entities) {
                if (!rm.hasComponent(entity)) continue
                val renderable = rm.getInstance(entity)
                for (primitive in 0 until rm.getPrimitiveCount(renderable)) {
                    val original = rm.getMaterialInstanceAt(renderable, primitive)
                    val temporary = if (entity == receiver.entity &&
                        primitive == receiver.primitive
                    ) {
                        receiverMaterial
                    } else {
                        MaterialInstance.duplicate(original,
                            "d3bake_${entity}_$primitive").also {
                            it.setCullingMode(
                                Material.CullingMode.FRONT_AND_BACK,
                                original.shadowCullingMode)
                        }
                    }
                    borrowedSlots.add(BorrowedSlot(entity, primitive,
                        original, temporary))
                    rm.setMaterialInstanceAt(renderable, primitive, temporary)
                }
            }
            host.configureBakedCaptureView(view)
            renderer.renderStandaloneView(view)
        } finally {
            for (slot in borrowedSlots.asReversed()) {
                if (rm.hasComponent(slot.entity)) {
                    rm.setMaterialInstanceAt(rm.getInstance(slot.entity),
                        slot.primitive, slot.original)
                }
                if (slot.temporary !== receiverMaterial) {
                    engine.destroyMaterialInstance(slot.temporary)
                }
            }
            engine.destroyMaterialInstance(receiverMaterial)
            restoreInstanceTransforms(savedInstances)
            for (entity in removedLights) scene.addEntity(entity)
            scene.setIndirectLight(savedIndirect)
            scene.setSkybox(savedSkybox)
        }
    }

    private fun saveInstanceTransforms(
        owner: FsceneRealizer.NodeRec,
    ): List<InstanceTransforms> {
        if (owner.instancesProps == null || owner.instanceBuffers.isEmpty()) {
            return emptyList()
        }
        val saved = ArrayList<InstanceTransforms>(owner.instanceBuffers.size)
        for ((bufferIndex, buffer) in owner.instanceBuffers.withIndex()) {
            val count = buffer.instanceCount
            val transforms = FloatArray(count * 16)
            for (index in 0 until count) {
                val transform = FloatArray(16)
                buffer.getLocalTransform(index, transform)
                transform.copyInto(transforms, index * 16)
            }
            saved += InstanceTransforms(buffer, transforms, count)
        }
        return saved
    }

    private fun isolateReceiverInstances(saved: List<InstanceTransforms>) {
        for ((bufferIndex, item) in saved.withIndex()) {
            val count = item.count
            val transforms = item.transforms
            val visible = transforms.copyOf()
            for (index in 0 until count) {
                if (bufferIndex == 0 && index == 0) continue
                visible[index * 16 + 12] = 1e6f
                visible[index * 16 + 13] = 1e6f
                visible[index * 16 + 14] = 1e6f
            }
            item.buffer.setLocalTransforms(visible, count, 0)
        }
    }

    private fun restoreInstanceTransforms(saved: List<InstanceTransforms>) {
        for (item in saved) {
            item.buffer.setLocalTransforms(item.transforms, item.count, 0)
        }
    }

    private fun createTarget(size: Int, depth: Boolean = false): Target {
        val engine = host.engine
        val color = Texture.Builder()
            .width(size).height(size).levels(1)
            .sampler(Texture.Sampler.SAMPLER_2D)
            .format(Texture.InternalFormat.RGBA8)
            .usage(Texture.Usage.COLOR_ATTACHMENT or Texture.Usage.SAMPLEABLE)
            .fenced { build(engine) }
        val depthTexture = if (depth) {
            Texture.Builder()
                .width(size).height(size).levels(1)
                .sampler(Texture.Sampler.SAMPLER_2D)
                .format(Texture.InternalFormat.DEPTH24)
                .usage(Texture.Usage.DEPTH_ATTACHMENT)
                .fenced { build(engine) }
        } else null
        val builder = RenderTarget.Builder()
            .texture(RenderTarget.AttachmentPoint.COLOR, color)
        if (depthTexture != null) {
            builder.texture(RenderTarget.AttachmentPoint.DEPTH, depthTexture)
        }
        return Target(color, builder.fenced { build(engine) }, depthTexture)
    }

    private fun destroyTarget(target: Target) {
        host.engine.destroyRenderTarget(target.renderTarget)
        host.engine.destroyTexture(target.texture)
        target.depth?.let(host.engine::destroyTexture)
    }

    private fun length(matrix: FloatArray, offset: Int): Float = sqrt(
        matrix[offset] * matrix[offset] +
            matrix[offset + 1] * matrix[offset + 1] +
            matrix[offset + 2] * matrix[offset + 2])

    private fun unit(x: Float, y: Float, z: Float): FloatArray {
        val length = sqrt(x * x + y * y + z * z)
        return floatArrayOf(x / length, y / length, z / length)
    }

    private fun dot(a: FloatArray, b: FloatArray): Float =
        a[0] * b[0] + a[1] * b[1] + a[2] * b[2]

    private class UtilityRenderer(
        private val engine: Engine,
        material: Material,
        private val sampler: TextureSampler,
        private val fallback: Texture,
    ) {
        private val scene = engine.createScene()
        private val entity = EntityManager.get().create()
        private val cameraEntity = EntityManager.get().create()
        private val camera = engine.createCamera(cameraEntity)
        private val view = engine.createView()
        private val instance = material.createInstance()
        private val vertexBuffer: VertexBuffer
        private val indexBuffer: IndexBuffer

        init {
            camera.setProjection(Camera.Projection.ORTHO,
                -1.0, 1.0, -1.0, 1.0, 0.1, 10.0)
            camera.setModelMatrix(floatArrayOf(
                1f, 0f, 0f, 0f,
                0f, 1f, 0f, 0f,
                0f, 0f, 1f, 0f,
                0f, 0f, 1f, 1f,
            ))
            val bytesPerVertex = 20
            vertexBuffer = VertexBuffer.Builder()
                .vertexCount(4)
                .bufferCount(1)
                .attribute(VertexBuffer.VertexAttribute.POSITION, 0,
                    VertexBuffer.AttributeType.FLOAT3, 0, bytesPerVertex)
                .attribute(VertexBuffer.VertexAttribute.UV0, 0,
                    VertexBuffer.AttributeType.FLOAT2, 12, bytesPerVertex)
                .fenced { build(engine) }
            val vertices = floatArrayOf(
                -1f, -1f, 0f, 0f, 0f,
                1f, -1f, 0f, 1f, 0f,
                -1f, 1f, 0f, 0f, 1f,
                1f, 1f, 0f, 1f, 1f,
            )
            val vertexBytes = ByteBuffer.allocateDirect(vertices.size * 4)
                .order(ByteOrder.nativeOrder())
            vertexBytes.asFloatBuffer().put(vertices)
            vertexBytes.position(0)
            vertexBuffer.setBufferAt(engine, 0, vertexBytes)
            indexBuffer = IndexBuffer.Builder()
                .indexCount(6)
                .bufferType(IndexBuffer.Builder.IndexType.USHORT)
                .fenced { build(engine) }
                .also { index ->
                    val indices = ByteBuffer.allocateDirect(12)
                        .order(ByteOrder.nativeOrder())
                    indices.asShortBuffer().put(shortArrayOf(0, 1, 2, 2, 1, 3))
                    indices.position(0)
                    index.setBuffer(engine, indices)
                }
            RenderableManager.Builder(1)
                .boundingBox(com.google.android.filament.Box(
                    -1f, -1f, 0f, 1f, 1f, 0f))
                .culling(false)
                .geometry(0, RenderableManager.PrimitiveType.TRIANGLES,
                    vertexBuffer, indexBuffer)
                .material(0, instance)
                .fenced { build(engine, entity) }
            instance.setDepthCulling(false)
            scene.addEntity(entity)
            view.scene = scene
            view.camera = camera
            view.setPostProcessingEnabled(false)
            view.setShadowingEnabled(false)
            view.setFrustumCullingEnabled(false)
        }

        fun fill(renderer: Renderer, target: Target, operation: Int) {
            draw(renderer, target, operation, fallback, fallback)
        }

        fun combine(renderer: Renderer, a: Target, b: Target, out: Target) {
            draw(renderer, out, 1, a.texture, b.texture)
        }

        fun blur(
            renderer: Renderer,
            source: Target,
            out: Target,
            resolution: Int,
            horizontal: Boolean,
        ) {
            instance.setParameter("blurStep",
                if (horizontal) 1f / resolution else 0f,
                if (horizontal) 0f else 1f / resolution)
            draw(renderer, out, if (horizontal) 2 else 3,
                source.texture, fallback)
        }

        private fun draw(
            renderer: Renderer,
            target: Target,
            operation: Int,
            inputA: Texture,
            inputB: Texture,
        ) {
            instance.setParameter("operation", operation)
            instance.setParameter("inputA", inputA, sampler)
            instance.setParameter("inputB", inputB, sampler)
            view.setRenderTarget(target.renderTarget)
            view.setViewport(Viewport(0, 0,
                target.texture.width, target.texture.height))
            // Surface uniforms and samplers upload at frame preparation, not render().
            renderer.renderStandaloneView(view)
        }

        fun destroy() {
            view.setRenderTarget(null)
            engine.destroyView(view)
            scene.remove(entity)
            engine.renderableManager.destroy(entity)
            engine.destroyMaterialInstance(instance)
            engine.destroyIndexBuffer(indexBuffer)
            engine.destroyVertexBuffer(vertexBuffer)
            engine.destroyScene(scene)
            engine.destroyCameraComponent(cameraEntity)
            EntityManager.get().destroy(entity)
            EntityManager.get().destroy(cameraEntity)
        }
    }
}
