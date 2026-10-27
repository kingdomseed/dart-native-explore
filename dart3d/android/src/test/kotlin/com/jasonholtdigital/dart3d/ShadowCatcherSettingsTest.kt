package com.jasonholtdigital.dart3d

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ShadowCatcherSettingsTest {

    @Test
    fun `live remains the default catcher mode`() {
        val settings = FsceneRealizer.parseShadowCatcherSettings(
            JSONObject("""{"type":"shadowCatcher"}"""))

        assertEquals(FsceneRealizer.ShadowCatcherMode.LIVE, settings?.mode)
        assertEquals(0f, settings?.softness)
    }

    @Test
    fun `baked mode and softness are parsed into the typed boundary`() {
        val settings = FsceneRealizer.parseShadowCatcherSettings(
            JSONObject("""{"type":"shadowCatcher","properties":{"mode":"baked","softness":0.4}}"""))

        assertEquals(FsceneRealizer.ShadowCatcherMode.BAKED, settings?.mode)
        assertEquals(0.4f, settings?.softness)
    }

    @Test
    fun `other material resources do not create catcher settings`() {
        assertNull(FsceneRealizer.parseShadowCatcherSettings(
            JSONObject("""{"type":"physicallyBased"}""")))
    }
}
