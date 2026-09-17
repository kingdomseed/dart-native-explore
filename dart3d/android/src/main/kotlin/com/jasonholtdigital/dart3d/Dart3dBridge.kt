package com.jasonholtdigital.dart3d

import android.util.Log
import android.view.View
import com.dartnative.DNAndroidPluginProvider
import com.dartnative.DNAppContext
import com.dartnative.DNPluginRegistry
import com.dartnative.DNViewRegistry

private const val TAG = "dart3d"

// Must match kSceneViewTypeKey in lib/src/scene_view.dart.
private const val D3_TYPE_KEY = "com.jasonholtdigital.dart3d/sceneView"

object Dart3dBridge : DNAndroidPluginProvider {

    /** Same key as the Dart side → same index, assigned at runtime. */
    private val sceneViewType: Int by lazy {
        DNPluginRegistry.claimViewType(D3_TYPE_KEY)
    }

    /** Called by DartNativeDart3dPlugin.onAttachedToEngine. */
    fun register() {
        DNPluginRegistry.register(this)
        Log.i(TAG, "dart3d provider registered")
    }

    override fun createView(typeIndex: Int): View? {
        if (typeIndex != sceneViewType) return null
        val ctx = DNAppContext.get() ?: return null
        return Dart3dView(ctx)
    }

    override fun handleMutation(viewId: Long, eventTag: Int, data: ByteArray) {
        val view = DNViewRegistry.view(viewId) as? Dart3dView ?: return
        view.onMutation(viewId, eventTag, data)
    }
}
