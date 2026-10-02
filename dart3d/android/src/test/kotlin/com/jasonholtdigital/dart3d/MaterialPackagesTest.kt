package com.jasonholtdigital.dart3d

import com.google.android.filament.filamat.MaterialBuilder
import com.google.android.filament.filamat.MaterialBuilder.BlendingMode
import com.google.android.filament.filamat.MaterialBuilder.TargetApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Which material packages exist and how they are named. */
class MaterialPackagesTest {

    private val apis = MaterialPackages.BAKED_APIS

    @Test
    fun `packages are baked for OpenGL and Vulkan`() {
        assertEquals(listOf(TargetApi.OPENGL, TargetApi.VULKAN), apis)
    }

    @Test
    fun `the base set is lit x3, unlit x3 and the trail, in bind order`() {
        assertEquals(
            listOf(
                "lit|false|OPAQUE|e0|s31|VULKAN",
                "lit|false|MASKED|e0|s31|VULKAN",
                "lit|false|TRANSPARENT|e0|s31|VULKAN",
                "lit|true|OPAQUE|e0|s31|VULKAN",
                "lit|true|MASKED|e0|s31|VULKAN",
                "lit|true|TRANSPARENT|e0|s31|VULKAN",
                "trail|VULKAN",
            ),
            MaterialPackages.baseSet(TargetApi.VULKAN).map { it.key })
    }

    @Test
    fun `the fixed set adds the catcher and both particle blends`() {
        for (api in apis) {
            val fixed = MaterialPackages.fixedSet(api).map { it.key }
            val base = MaterialPackages.baseSet(api).map { it.key }
            assertEquals(base, fixed.take(base.size))
            assertEquals(
                listOf("catcher|$api", "particle|false|$api",
                    "particle|true|$api"),
                fixed.drop(base.size))
        }
    }

    @Test
    fun `every fixed package has its own key and fingerprint`() {
        val specs = apis.flatMap { MaterialPackages.fixedSet(it) }
        assertEquals(20, specs.size)
        assertEquals(20, specs.map { it.key }.toSet().size)
        assertEquals(20, specs.map { it.fingerprint }.toSet().size)
    }

    @Test
    fun `a variant key carries extension flags, bound slots and the API`() {
        val spec = MaterialPackages.litSpec(false, BlendingMode.OPAQUE,
            FsceneRealizer.EXT_CLEARCOAT, 0b10001, TargetApi.OPENGL)
        assertEquals(
            "lit|false|OPAQUE|e${FsceneRealizer.EXT_CLEARCOAT}|s17|OPENGL",
            spec.key)
    }

    @Test
    fun `the fingerprint is stable for equal inputs`() {
        fun spec() = MaterialPackages.litSpec(false, BlendingMode.MASKED, 0,
            FsceneRealizer.ALL_BASE_SLOTS, TargetApi.VULKAN)
        assertEquals(spec().fingerprint, spec().fingerprint)
        assertTrue(Regex("[0-9a-f]{32}").matches(spec().fingerprint))
    }

    @Test
    fun `the fingerprint follows the Filament version`() {
        val recipe = MaterialPackages.trailSpec(TargetApi.VULKAN).recipe
        assertEquals(recipe.fingerprint(BuildConfig.FILAMENT_VERSION),
            MaterialPackages.trailSpec(TargetApi.VULKAN).fingerprint)
        assertNotEquals(recipe.fingerprint("1.71.6"),
            recipe.fingerprint("1.71.7"))
    }

    @Test
    fun `the fingerprint follows every builder input`() {
        fun recipe(code: String = "void material(){}", filter: Int = 0x80) =
            MaterialRecipe()
                .name("m")
                .shading(MaterialBuilder.Shading.LIT)
                .variantFilter(filter)
                .material(code)
        val base = recipe().fingerprint("v")
        assertEquals(base, recipe().fingerprint("v"))
        assertNotEquals(base, recipe(code = "void material(){ }").fingerprint("v"))
        assertNotEquals(base, recipe(filter = 0).fingerprint("v"))
        assertNotEquals(base,
            recipe().doubleSided(true).fingerprint("v"))
    }

    @Test
    fun `bound slots and extension flags change the package`() {
        fun fp(ext: Int, slots: Int) = MaterialPackages.litSpec(false,
            BlendingMode.OPAQUE, ext, slots, TargetApi.VULKAN).fingerprint
        val base = fp(0, FsceneRealizer.ALL_BASE_SLOTS)
        assertNotEquals(base, fp(0, 0b00001))
        assertNotEquals(base,
            fp(FsceneRealizer.EXT_CLEARCOAT, FsceneRealizer.ALL_BASE_SLOTS))
    }
}
