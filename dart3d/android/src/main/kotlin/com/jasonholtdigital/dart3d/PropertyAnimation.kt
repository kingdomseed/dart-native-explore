package com.jasonholtdigital.dart3d

import org.json.JSONObject

class AnimationDefinition(val ordinary: List<Ordinary>, val properties: List<Property>) {
    class Ordinary(val target: Long, val targetName: String?, val kind: String,
        val timeline: Long, val keyframes: Long)
    enum class Kind(val wire: String, val arity: Int) {
        COLOR("materialBaseColor", 4), INTENSITY("lightIntensity", 1),
        FOV("cameraFovRadiansY", 1)
    }
    class Property(val kind: Kind, val target: Long, val timeline: Long, val keyframes: Long)

    val claims: MutableSet<Long> get() = HashSet<Long>().also { ids ->
        ordinary.forEach { ids.add(it.timeline); ids.add(it.keyframes) }
        properties.forEach { ids.add(it.timeline); ids.add(it.keyframes) }
    }

    companion object {
        fun parse(def: JSONObject): AnimationDefinition {
            require(!def.has("name") || def.isNull("name") || def.opt("name") is String) {
                "animation name must be a string"
            }
            fun ref(c: JSONObject, name: String): Long {
                val value = c.opt(name) as? String
                require(value != null) {
                    "invalid $name reference"
                }
                return requireNotNull(D3Wire.localIdKey(value)) { "invalid $name reference" }
            }
            fun entries(name: String): List<JSONObject> {
                if (!def.has(name) || name == "channels" && def.isNull(name)) return emptyList()
                val a = requireNotNull(def.optJSONArray(name)) { "$name must be a list" }
                return (0 until a.length()).map {
                    requireNotNull(a.optJSONObject(it)) { "$name entry must be an object" }
                }
            }
            val ordinary = entries("channels").map { c ->
                val kind = c.optString("property")
                require(kind in listOf("translation", "rotation", "scale", "weights")) {
                    "unknown ordinary property $kind"
                }
                require(!c.has("targetName") || c.isNull("targetName") || c.opt("targetName") is String) {
                    "targetName must be a string"
                }
                Ordinary(ref(c, "target"), (c.opt("targetName") as? String)?.takeIf { it.isNotEmpty() },
                    kind, ref(c, "timeline"), ref(c, "keyframes"))
            }
            val endpoints = HashSet<Pair<Kind, Long>>()
            val properties = entries("d3:properties").map { c ->
                val kind = requireNotNull(Kind.entries.find { it.wire == c.optString("kind") }) {
                    "unknown property kind"
                }
                val targetField = if (kind == Kind.COLOR) "material" else "node"
                val fields = setOf("kind", targetField, "timeline", "keyframes")
                require(c.keys().asSequence().toSet() == fields) { "invalid property fields" }
                val target = ref(c, targetField)
                require(endpoints.add(kind to target)) { "duplicate property endpoint" }
                Property(kind, target, ref(c, "timeline"), ref(c, "keyframes"))
            }
            return AnimationDefinition(ordinary, properties)
        }
    }
}

class PropertyCurve(val spec: AnimationDefinition.Property, val times: DoubleArray,
    val values: FloatArray) {
    fun sample(time: Double): FloatArray {
        val n = spec.kind.arity
        var hi = times.indexOfFirst { it >= time }
        if (hi < 0) hi = times.lastIndex
        if (hi == 0 || time >= times[hi]) return values.copyOfRange(hi * n, (hi + 1) * n)
        val f = ((time - times[hi - 1]) / (times[hi] - times[hi - 1])).toFloat()
        return FloatArray(n) { c ->
            val a = values[(hi - 1) * n + c]
            a + (values[hi * n + c] - a) * f
        }
    }

    companion object {
        fun decode(spec: AnimationDefinition.Property, timeline: ByteArray?, keyframes: ByteArray?,
            timelineMeta: FsceneRealizer.Context.PayloadMeta?,
            keyframesMeta: FsceneRealizer.Context.PayloadMeta?): PropertyCurve? {
            if (timeline == null || keyframes == null || timelineMeta == null || keyframesMeta == null)
                return null
            fun floats(bytes: ByteArray, meta: FsceneRealizer.Context.PayloadMeta): FloatArray {
                require(meta.encoding == "floats" && bytes.size % 4 == 0 &&
                    (meta.length == null || meta.length >= 0 && meta.length % 4 == 0)) {
                    "property payload must contain aligned f32 values"
                }
                return FloatArray(bytes.size / 4) { D3Wire.f32LE(bytes, it * 4) }
            }
            val times = floats(timeline, timelineMeta).map { it.toDouble() }.toDoubleArray()
            val values = floats(keyframes, keyframesMeta)
            require(times.isNotEmpty() && times.indices.all {
                times[it].isFinite() && times[it] >= 0 && (it == 0 || times[it] > times[it - 1])
            }) { "invalid property timeline" }
            require(values.size == times.size * spec.kind.arity && values.indices.all { i ->
                val v = values[i]
                v.isFinite() && when (spec.kind) {
                    AnimationDefinition.Kind.COLOR -> v >= 0 && (i % 4 != 3 || v <= 1)
                    AnimationDefinition.Kind.INTENSITY -> v >= 0
                    AnimationDefinition.Kind.FOV -> v > 0 && v < Math.PI
                }
            }) { "invalid property values or arity" }
            return PropertyCurve(spec, times, values)
        }
    }
}

class AnimatedProperty(val rest: FloatArray) {
    var effective = rest.copyOf()
    var driven = false

    fun accumulate(acc: FloatArray, curve: PropertyCurve, time: Double, weight: Float) {
        val sample = curve.sample(time)
        for (i in acc.indices) acc[i] += weight * (sample[i] - rest[i])
    }

    fun apply(acc: FloatArray?, write: (FloatArray) -> Unit) {
        if (acc == null && !driven) return
        effective = acc ?: rest.copyOf()
        write(effective)
        driven = acc != null
    }
}
