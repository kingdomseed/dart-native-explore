package com.jasonholtdigital.dart3d

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.util.Log
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import com.dartnative.DNAndroidPluginProvider
import com.dartnative.DNAppContext
import com.dartnative.DNPluginRegistry
import com.dartnative.DNViewRegistry
import com.google.android.filament.filamat.MaterialBuilder

private const val TAG = "dart3d"

// Must match kSceneViewTypeKey in lib/src/scene_view.dart.
private const val D3_TYPE_KEY = "com.jasonholtdigital.dart3d/sceneView"

object Dart3dBridge : DNAndroidPluginProvider {

    /** Same key as the Dart side → same index, assigned at runtime. */
    private val sceneViewType: Int by lazy {
        DNPluginRegistry.claimViewType(D3_TYPE_KEY)
    }

    /**
     * True when the running framework's provider interface carries the
     * `disposeView` hook (DartNative ≥ 2026-09-17). With it, a scene
     * view's Engine lives until the framework disposes the view — a
     * window detach (activity recreate, re-parenting) only pauses it.
     * Without it, detach stays the release point (the old contract).
     */
    val frameworkDisposes: Boolean by lazy {
        try {
            DNAndroidPluginProvider::class.java.methods.any {
                it.name == "disposeView"
            }
        } catch (t: Throwable) {
            false
        }
    }

    /** Called by DartNativeDart3dPlugin.onAttachedToEngine. */
    fun register() {
        DNPluginRegistry.register(this)
        Log.i(TAG, "dart3d provider registered " +
            "(disposeView=${frameworkDisposes})")
        prewarmMaterials()
    }

    /**
     * Starts compiling the base material packages off the main thread
     * so the first `createView` loads them instead of running filamat
     * on main (the captured ANR). Targets the backend `auto` resolves
     * to; a forced other backend compiles on its own first use.
     */
    private fun prewarmMaterials() {
        try {
            val ctx: Context? = DNAppContext.get()
            val vulkan = ctx?.packageManager?.hasSystemFeature(
                PackageManager.FEATURE_VULKAN_HARDWARE_VERSION) ?: true
            MaterialPackages.prewarm(
                if (vulkan) MaterialBuilder.TargetApi.VULKAN
                else MaterialBuilder.TargetApi.OPENGL)
        } catch (t: Throwable) {
            Log.w(TAG, "material prewarm not started", t)
        }
    }

    override fun createView(typeIndex: Int): View? {
        if (typeIndex != sceneViewType) return null
        val ctx = DNAppContext.get() ?: return null
        // The framework's JNI caller swallows a throwing createView and
        // hands Dart a dead view id — the "zombie" blank screen. Catch
        // here, say so loudly, and return a visible error view instead.
        return try {
            Dart3dView(ctx)
        } catch (t: Throwable) {
            Log.e(TAG, "dart3d: SceneView init FAILED — the scene will " +
                "not render (${t.javaClass.simpleName}: ${t.message})", t)
            InitFailedView(ctx, t)
        }
    }

    override fun handleMutation(viewId: Long, eventTag: Int, data: ByteArray) {
        when (val view = DNViewRegistry.view(viewId)) {
            is Dart3dView -> view.onMutation(viewId, eventTag, data)
            is InitFailedView -> view.dropped(viewId, eventTag)
            else -> {}
        }
    }

    /**
     * Framework-driven disposal — the view's Dart element unmounted or
     * the app hot restarted. Releases the Engine, Jolt world and the
     * KTX2 provider immediately rather than waiting on GC/detach.
     */
    override fun disposeView(viewId: Long, view: View) {
        try {
            (view as? Dart3dView)?.release("disposeView($viewId)")
        } catch (t: Throwable) {
            Log.e(TAG, "dart3d: disposeView($viewId) failed", t)
        }
    }

    /**
     * Stand-in for a scene view whose construction threw. Renders the
     * failure on screen (never a silent blank) and logs every dropped
     * mutation kind once, so a Dart side driving it is visible in
     * logcat too.
     */
    class InitFailedView(ctx: Context, cause: Throwable) : FrameLayout(ctx) {
        private val droppedTags = HashSet<Int>()

        init {
            setBackgroundColor(Color.rgb(40, 0, 0))
            addView(TextView(ctx).apply {
                setTextColor(Color.rgb(255, 180, 180))
                textSize = 14f
                gravity = Gravity.CENTER
                text = "dart3d: scene view failed to initialize\n" +
                    "${cause.javaClass.simpleName}: ${cause.message}"
            }, LayoutParams(LayoutParams.MATCH_PARENT,
                LayoutParams.MATCH_PARENT))
        }

        fun dropped(viewId: Long, eventTag: Int) {
            if (droppedTags.add(eventTag)) {
                Log.e(TAG, "dart3d view $viewId is dead (init failed): " +
                    "dropping eventTag=$eventTag mutations")
            }
        }
    }
}
