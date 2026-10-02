package com.jasonholtdigital.dart3d

import com.google.android.filament.filamat.MaterialBuilder
import java.security.MessageDigest

/**
 * Everything filamat is told about one material package, recorded so it
 * can be named before it is built.
 *
 * A package is a pure function of the builder calls and the filamat
 * version. [fingerprint] hashes both, which makes it the identity of a
 * compiled package wherever one is kept: the packages shipped in the
 * plugin's assets and the on-device cache are files named by it. A
 * changed shader, option or Filament pin yields a new name, so a stale
 * package is never picked up; it is simply not found.
 *
 * The methods mirror the `MaterialBuilder` calls the plugin uses.
 */
internal class MaterialRecipe {
    private val signature = StringBuilder()
    private val steps = ArrayList<(MaterialBuilder) -> Unit>()

    private fun step(text: String, apply: (MaterialBuilder) -> Unit): MaterialRecipe {
        signature.append(text).append('\n')
        steps += apply
        return this
    }

    fun platform(v: MaterialBuilder.Platform) =
        step("platform $v") { it.platform(v) }
    fun targetApi(v: MaterialBuilder.TargetApi) =
        step("targetApi $v") { it.targetApi(v) }
    fun name(v: String) = step("name $v") { it.name(v) }
    fun shading(v: MaterialBuilder.Shading) =
        step("shading $v") { it.shading(v) }
    fun blending(v: MaterialBuilder.BlendingMode) =
        step("blending $v") { it.blending(v) }
    fun vertexDomain(v: MaterialBuilder.VertexDomain) =
        step("vertexDomain $v") { it.vertexDomain(v) }
    fun culling(v: MaterialBuilder.CullingMode) =
        step("culling $v") { it.culling(v) }
    fun doubleSided(v: Boolean) =
        step("doubleSided $v") { it.doubleSided(v) }
    fun depthWrite(v: Boolean) = step("depthWrite $v") { it.depthWrite(v) }
    fun shadowMultiplier(v: Boolean) =
        step("shadowMultiplier $v") { it.shadowMultiplier(v) }
    fun flipUV(v: Boolean) = step("flipUV $v") { it.flipUV(v) }
    fun clearCoatIorChange(v: Boolean) =
        step("clearCoatIorChange $v") { it.clearCoatIorChange(v) }
    fun refractionMode(v: MaterialBuilder.RefractionMode) =
        step("refractionMode $v") { it.refractionMode(v) }
    fun refractionType(v: MaterialBuilder.RefractionType) =
        step("refractionType $v") { it.refractionType(v) }
    fun reflectionMode(v: MaterialBuilder.ReflectionMode) =
        step("reflectionMode $v") { it.reflectionMode(v) }
    fun require(v: MaterialBuilder.VertexAttribute) =
        step("require $v") { it.require(v) }
    fun variable(v: MaterialBuilder.Variable, name: String) =
        step("variable $v $name") { it.variable(v, name) }
    fun uniformParameter(type: MaterialBuilder.UniformType, name: String) =
        step("uniform $type $name") { it.uniformParameter(type, name) }
    fun samplerParameter(
        type: MaterialBuilder.SamplerType,
        format: MaterialBuilder.SamplerFormat,
        precision: MaterialBuilder.ParameterPrecision,
        name: String,
    ) = step("sampler $type $format $precision $name") {
        it.samplerParameter(type, format, precision, name)
    }
    fun variantFilter(v: Int) =
        step("variantFilter $v") { it.variantFilter(v) }
    fun material(code: String) = step("material\n$code") { it.material(code) }
    fun materialVertex(code: String) =
        step("materialVertex\n$code") { it.materialVertex(code) }

    /** A fresh builder with every recorded call applied, in order. */
    fun toBuilder(): MaterialBuilder {
        val b = MaterialBuilder()
        for (s in steps) s(b)
        return b
    }

    /**
     * 32 hex characters identifying the package this recipe compiles to
     * under filamat [filamentVersion].
     */
    fun fingerprint(filamentVersion: String): String {
        val md = MessageDigest.getInstance("SHA-256")
        md.update("filament $filamentVersion\n".toByteArray(Charsets.UTF_8))
        md.update(signature.toString().toByteArray(Charsets.UTF_8))
        return md.digest().take(16)
            .joinToString("") { "%02x".format(it) }
    }
}
