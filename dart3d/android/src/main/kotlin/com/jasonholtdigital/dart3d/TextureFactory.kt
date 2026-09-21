package com.jasonholtdigital.dart3d

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.SystemClock
import android.util.Log
import com.google.android.filament.Engine
import com.google.android.filament.Texture
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * `.fscene` texture resources → Filament textures (W4).
 *
 * Three byte forms per the wire spec: `rgba8` (raw, needs width/height
 * from the payload manifest entry), `ktx2` (Basis Universal transcoded
 * through gltfio's native Ktx2Provider — see dart3d_jni.cpp; W21), and
 * anything else as an encoded container (PNG/JPEG) decoded through
 * `BitmapFactory`. `ref` resources read from `context.assets` and take
 * the encoded path. Uploads are `RGBA8`/`SRGB8_A8` by `content` with a
 * generated mip chain; ktx2 keeps its authored chain and whichever
 * compressed internal format the device supports.
 */
object TextureFactory {

    private const val TAG = "dart3d"

    init {
        // dart3d_jni carries nKtx2Decode; gltfio-jni carries the
        // exported createKtx2Provider it dlsyms. Both resolve lazily at
        // first call — a missing gltfio lib degrades ktx2 payloads to
        // the Failed result (with a warnOnce), not a crash.
        System.loadLibrary("dart3d_jni")
        try {
            System.loadLibrary("gltfio-jni")
        } catch (e: UnsatisfiedLinkError) {
            Log.w(TAG, "libgltfio-jni.so not packaged —" +
                " ktx2 textures will fail to decode", e)
        }
    }

    /**
     * JNI entry into gltfio's Ktx2Provider (dart3d_jni.cpp). Returns
     * the native `filament::Texture*` — wrapped by `Texture(ptr)` — or
     * 0 on failure (reason already logged natively).
     */
    private external fun nKtx2Decode(
        nativeEngine: Long, bytes: ByteArray, srgb: Boolean): Long

    /** Outcome of one texture-resource decode. */
    sealed class Result {
        /** Upload succeeded — bind this texture. */
        class Ready(val texture: Texture) : Result()

        /** The payload token is valid but its bytes haven't landed. */
        object Pending : Result()

        /** Malformed or unsupported — bind the neutral fallback instead. */
        object Failed : Result()
    }

    private val loggedOnce = mutableSetOf<String>()
    private val warnedOnce = mutableSetOf<String>()

    private fun logOnce(tag: String, msg: String) {
        if (loggedOnce.add(tag)) Log.i(TAG, msg)
    }

    private fun warnOnce(tag: String, msg: String) {
        if (warnedOnce.add(tag)) Log.w(TAG, msg)
    }

    /**
     * Resolves one texture resource spec to a GPU texture. Shared by the
     * manifest realize pass and the `upsertResource`/`upsertPayload`
     * surgical path — [payloadSpecs] is the manifest `payloads` section
     * (carries `format`/`width`/`height` for image payloads).
     */
    fun realize(
        host: Dart3dView,
        key: Long,
        spec: JSONObject,
        payloadSpecs: Map<Long, FsceneRealizer.Context.PayloadMeta>,
    ): Result {
        val content = spec.optString("content").ifEmpty { "color" }
        val payloadToken = spec.optString("payload")
        if (payloadToken.isNotEmpty()) {
            val pid = D3Wire.localIdKey(payloadToken)
            if (pid == null) {
                warnOnce("texture:$key:payloadToken",
                    "texture $key: invalid payload token '$payloadToken'")
                return Result.Failed
            }
            val bytes = host.payloadStore[pid] ?: return Result.Pending
            val meta = payloadSpecs[pid]
            if (meta != null && meta.encoding.isNotEmpty() &&
                meta.encoding != "image") {
                warnOnce("texture:$key:encoding",
                    "texture $key: payload encoding '${meta.encoding}' is not image")
                return Result.Failed
            }
            return uploadBytes(host, key, bytes, meta?.format,
                meta?.width, meta?.height, content)
        }
        val ref = spec.optString("ref")
        if (ref.isNotEmpty()) {
            val bytes = FlutterAssets.readBytes(host.context, ref)
            if (bytes == null) {
                logOnce("texture:$key:ref:$ref",
                    "texture $key: asset '$ref' not found")
                return Result.Failed
            }
            return uploadBytes(host, key, bytes, null, null, null, content)
        }
        warnOnce("texture:$key:empty", "texture $key: neither payload nor ref")
        return Result.Failed
    }

    private fun uploadBytes(
        host: Dart3dView, key: Long, bytes: ByteArray,
        format: String?, width: Int?, height: Int?, content: String,
    ): Result = when (format) {
        "rgba8" -> uploadRgba8(host, key, bytes, width, height, content)
        "ktx2" -> uploadKtx2(host, key, bytes, content)
        else -> uploadEncoded(host, key, bytes, content)
    }

    /**
     * KTX2 (Basis Universal) via gltfio's native Ktx2Provider — the
     * pinned Filament ships no Java-side KTX2 reader, so dart3d_jni.cpp
     * dlsyms `filament::gltfio::createKtx2Provider` out of
     * libgltfio-jni.so and drives push→wait→updateQueue→pop on this
     * (Filament) thread. The reader picks the best supported internal
     * format (ETC2/BC/uncompressed fallback) and uploads the file's own
     * mip chain; sRGB follows `content` like the uncompressed paths.
     */
    private fun uploadKtx2(
        host: Dart3dView, key: Long, bytes: ByteArray, content: String,
    ): Result {
        val start = SystemClock.uptimeMillis()
        val ptr = try {
            nKtx2Decode(host.engine.getNativeObject(), bytes,
                content == "color")
        } catch (e: UnsatisfiedLinkError) {
            warnOnce("texture:$key:ktx2:jni",
                "texture $key: ktx2 JNI unavailable: ${e.message}")
            return Result.Failed
        }
        if (ptr == 0L) {
            warnOnce("texture:$key:ktx2",
                "texture $key: ktx2 transcode failed (see native log)")
            return Result.Failed
        }
        val tex = Texture(ptr)
        Log.i(TAG, "texture $key: ktx2 ${tex.getWidth(0)}x" +
            "${tex.getHeight(0)} ${tex.getFormat()} " +
            "levels=${tex.getLevels()} in " +
            "${SystemClock.uptimeMillis() - start}ms")
        return Result.Ready(tex)
    }

    /** Raw RGBA8 payload — `length == width*height*4` per the wire spec. */
    private fun uploadRgba8(
        host: Dart3dView, key: Long, bytes: ByteArray,
        width: Int?, height: Int?, content: String,
    ): Result {
        val w = width ?: 0
        val h = height ?: 0
        if (w <= 0 || h <= 0) {
            warnOnce("texture:$key:rgba8:dims",
                "texture $key: rgba8 payload needs width/height in the manifest spec")
            return Result.Failed
        }
        if (bytes.size != w * h * 4) {
            warnOnce("texture:$key:rgba8:length",
                "texture $key: rgba8 length ${bytes.size} != $w*$h*4")
            return Result.Failed
        }
        val start = SystemClock.uptimeMillis()
        val buf = ByteBuffer.allocateDirect(bytes.size)
            .order(ByteOrder.nativeOrder())
            .put(bytes)
        buf.flip()
        val tex = upload(host.engine, key, buf, w, h,
            Texture.Format.RGBA, srgb = content == "color",
            fmt = "rgba8", startMs = start)
        return Result.Ready(tex)
    }

    /**
     * Encoded container (PNG/JPEG) via BitmapFactory. `ARGB_8888`
     * little-endian memory is B,G,R,A and the Java `Texture.Format` enum
     * has no `BGRA`, so the upload repacks to RGBA in-place (B↔R swap).
     */
    private fun uploadEncoded(
        host: Dart3dView, key: Long, bytes: ByteArray, content: String,
    ): Result {
        val start = SystemClock.uptimeMillis()
        val decoded = try {
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (e: Exception) {
            null
        }
        if (decoded == null) {
            warnOnce("texture:$key:decode",
                "texture $key: undecodable image container")
            return Result.Failed
        }
        var bitmap = decoded
        if (bitmap.config != Bitmap.Config.ARGB_8888) {
            val converted = bitmap.copy(Bitmap.Config.ARGB_8888, false)
            bitmap.recycle()
            if (converted == null) {
                warnOnce("texture:$key:config",
                    "texture $key: could not convert bitmap to ARGB_8888")
                return Result.Failed
            }
            bitmap = converted
        }
        val w = bitmap.width
        val h = bitmap.height
        val buf = ByteBuffer.allocateDirect(bitmap.byteCount)
            .order(ByteOrder.nativeOrder())
        bitmap.copyPixelsToBuffer(buf)
        bitmap.recycle()
        // B,G,R,A → R,G,B,A in place.
        for (i in 0 until w * h) {
            val p = i * 4
            val b = buf.get(p)
            buf.put(p, buf.get(p + 2))
            buf.put(p + 2, b)
        }
        buf.rewind()
        val tex = upload(host.engine, key, buf, w, h,
            Texture.Format.RGBA, srgb = content == "color",
            fmt = "encoded", startMs = start)
        return Result.Ready(tex)
    }

    /** Uploads level 0 then generates the rest of the mip chain. */
    private fun upload(
        engine: Engine, key: Long, pixels: ByteBuffer, w: Int, h: Int,
        format: Texture.Format, srgb: Boolean, fmt: String, startMs: Long,
    ): Texture {
        val internal = if (srgb) Texture.InternalFormat.SRGB8_A8
            else Texture.InternalFormat.RGBA8
        var levels = 1
        var m = maxOf(w, h)
        while (m > 1) {
            m = m shr 1
            levels++
        }
        val tex = Texture.Builder()
            .width(w).height(h)
            .levels(levels)
            .sampler(Texture.Sampler.SAMPLER_2D)
            .format(internal)
            .usage(Texture.Usage.DEFAULT or Texture.Usage.GEN_MIPMAPPABLE)
            .build(engine)
        tex.setImage(engine, 0, Texture.PixelBufferDescriptor(
            pixels, format, Texture.Type.UBYTE))
        if (levels > 1) tex.generateMipmaps(engine)
        Log.i(TAG, "texture $key: ${w}x$h $fmt in " +
            "${SystemClock.uptimeMillis() - startMs}ms")
        return tex
    }

    /**
     * Neutral 1×1 — bound on every slot that has no texture so the shader
     * samples a factor-preserving value. Always linear RGBA8: the values
     * here (white, flat normal, black) survive either decode unchanged,
     * and a normal map MUST NOT be sRGB-decoded.
     */
    fun solid(engine: Engine, r: Int, g: Int, b: Int, a: Int): Texture {
        val buf = ByteBuffer.allocateDirect(4)
            .order(ByteOrder.nativeOrder())
            .put(byteArrayOf(
                r.toByte(), g.toByte(), b.toByte(), a.toByte()))
        buf.flip()
        val tex = Texture.Builder()
            .width(1).height(1)
            .levels(1)
            .sampler(Texture.Sampler.SAMPLER_2D)
            .format(Texture.InternalFormat.RGBA8)
            .build(engine)
        tex.setImage(engine, 0, Texture.PixelBufferDescriptor(
            buf, Texture.Format.RGBA, Texture.Type.UBYTE))
        return tex
    }
}
