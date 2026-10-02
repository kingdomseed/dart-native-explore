package com.jasonholtdigital.dart3d

import android.os.Process
import android.os.SystemClock
import android.util.Log
import java.util.concurrent.ConcurrentHashMap

/**
 * Cold-start timeline: one `start +<ms>ms <event>` line per milestone,
 * in milliseconds since the process started. Read with
 * `adb logcat -s dart3d | grep 'start +'`.
 */
internal object ColdStart {
    private const val TAG = "dart3d"
    private val logged = ConcurrentHashMap.newKeySet<String>()

    fun sinceStartMs(): Long =
        SystemClock.uptimeMillis() - Process.getStartUptimeMillis()

    fun line(ms: Long, event: String): String = "start +${ms}ms $event"

    /** Logs [event]; with [once] only its first occurrence per process. */
    fun mark(event: String, once: Boolean = true) {
        if (once && !logged.add(event)) return
        Log.i(TAG, line(sinceStartMs(), event))
    }
}
