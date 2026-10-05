package com.jasonholtdigital.dart3d

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.GLES20
import android.util.Log

/**
 * The GPU's name, read before any Filament engine exists.
 *
 * The backend is chosen before the engine is built and the engine is
 * what would otherwise name the GPU, so this asks the GL driver
 * directly: a 1×1 pbuffer context, `GL_RENDERER`, and the context is
 * destroyed again. The string names the GPU whichever backend the
 * engine then uses. It is read once per process.
 *
 * Null when any EGL step fails (no ES 2 pbuffer config, no context, no
 * surface) or the driver returns no string; [DeviceTier] then decides
 * from memory alone.
 *
 * The process's EGL display is shared with the system's own renderer
 * and with Filament's OpenGL backend. Android counts initializations
 * of it (`egl_display_t::refs` in libEGL): `eglTerminate` only tears
 * the display down for the last holder, so the probe gives back the
 * one reference it took and leaves everyone else's alone.
 */
internal object GpuProbe {
    private const val TAG = "dart3d"

    private val cached: String? by lazy {
        try {
            query()
        } catch (t: Throwable) {
            Log.w(TAG, "GPU probe failed", t)
            null
        }.also { Log.i(TAG, "GPU: ${it ?: "unknown"}") }
    }

    fun renderer(): String? = cached

    private fun query(): String? {
        val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (display == EGL14.EGL_NO_DISPLAY) return null
        val version = IntArray(2)
        if (!EGL14.eglInitialize(display, version, 0, version, 1)) return null
        try {
            return queryRenderer(display)
        } finally {
            EGL14.eglTerminate(display)
        }
    }

    private fun queryRenderer(display: android.opengl.EGLDisplay): String? {
        val configs = arrayOfNulls<EGLConfig>(1)
        val count = IntArray(1)
        val configAttribs = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_NONE)
        if (!EGL14.eglChooseConfig(
                display, configAttribs, 0, configs, 0, 1, count, 0)) return null
        val config = configs[0]?.takeIf { count[0] > 0 } ?: return null

        val previousContext = EGL14.eglGetCurrentContext()
        val previousDisplay = EGL14.eglGetCurrentDisplay()
        val previousDraw = EGL14.eglGetCurrentSurface(EGL14.EGL_DRAW)
        val previousRead = EGL14.eglGetCurrentSurface(EGL14.EGL_READ)

        val context = EGL14.eglCreateContext(
            display, config, EGL14.EGL_NO_CONTEXT,
            intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
        if (context == EGL14.EGL_NO_CONTEXT) return null
        val surface = EGL14.eglCreatePbufferSurface(
            display, config,
            intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0)
        try {
            if (surface == EGL14.EGL_NO_SURFACE ||
                !EGL14.eglMakeCurrent(display, surface, surface, context)) {
                return null
            }
            return GLES20.glGetString(GLES20.GL_RENDERER)
        } finally {
            if (previousContext != EGL14.EGL_NO_CONTEXT) {
                EGL14.eglMakeCurrent(
                    previousDisplay, previousDraw, previousRead, previousContext)
            } else {
                EGL14.eglMakeCurrent(
                    display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE,
                    EGL14.EGL_NO_CONTEXT)
            }
            if (surface != EGL14.EGL_NO_SURFACE) {
                EGL14.eglDestroySurface(display, surface)
            }
            EGL14.eglDestroyContext(display, context)
        }
    }
}
