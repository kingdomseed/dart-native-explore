package com.jasonholtdigital.dart3d

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The plugin's assets hold exactly [MaterialPackages.fixedSet], compiled
 * for the current recipes and Filament pin. A failure here means
 * `tool/bake_materials.sh` has to be re-run.
 */
class ShippedMaterialsTest {

    private val fixed =
        MaterialPackages.BAKED_APIS.flatMap { MaterialPackages.fixedSet(it) }

    /** Gradle runs unit tests from the module directory. */
    private val shippedDir = File("src/main/assets/${MaterialStore.ASSET_DIR}")

    @Test
    fun `the plugin ships every fixed package for the pinned Filament`() {
        val missing = fixed
            .filter {
                !File(shippedDir, MaterialStore.fileName(it.fingerprint)).isFile
            }
            .map { it.key }
        assertEquals(
            "packages missing from $shippedDir — a recipe or the Filament" +
                " pin changed; re-run tool/bake_materials.sh",
            emptyList<String>(), missing)
    }

    @Test
    fun `the plugin ships nothing but the fixed set`() {
        val expected = fixed
            .map { MaterialStore.fileName(it.fingerprint) }.toSet() +
            MaterialStore.INDEX_NAME
        val extra = shippedDir.list().orEmpty().toSet() - expected
        assertEquals("stale files in $shippedDir", emptySet<String>(), extra)
    }

    @Test
    fun `the shipped index names each package's key`() {
        val index = MaterialStore.parseIndex(
            File(shippedDir, MaterialStore.INDEX_NAME).readText())
        val expected = fixed
            .associate { it.fingerprint to it.key }
        assertEquals(expected, index)
    }
}
