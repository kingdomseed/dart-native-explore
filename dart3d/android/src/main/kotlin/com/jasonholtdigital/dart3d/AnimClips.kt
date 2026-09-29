package com.jasonholtdigital.dart3d

/**
 * W11 clip playback state — upstream's `AnimationClip` knobs. A clip
 * exists only after an `anim` op names its animation — upstream's
 * `createAnimationClip` shape: no clip, no contribution (a doc load
 * never snaps animated nodes to a key-0 pose). Channel data is read
 * live from `resources.animations` so an `upsertAnimation`/payload
 * re-decode refreshes the curves underneath a live clip.
 *
 * Kept free of Filament so the verb/blend rules run under plain JVM
 * tests (`AnimClipsTest`); `Dart3dView.sampleAnimations` does the
 * sampling and the writes.
 */
internal class AnimClipState {
    var playing = false
    var time = 0.0            // playbackTime, seconds
    var timeScale = 1.0
    var weight = 1.0          // clamped [0,1] on assignment
    var loop = false

    /**
     * Whether the clip takes part in the blend. `stop` clears it — a
     * stopped clip contributes nothing and adds nothing to the weight
     * total, so the channels it drove return to bind (or to whatever
     * the remaining clips drive). `play` and a seek set it again.
     * Upstream's `stop` leaves the clip blending its t=0 pose at full
     * weight, which is what left Dash's eyes half-closed after cycling
     * clips (#33): every visited clip stayed in the blend as a frozen
     * t=0 layer and the playing clip fell to 1/N of the weight.
     */
    var active = true

    /**
     * Applies one `anim` op's verbs and knobs. Verbs apply in
     * pause→stop→play order so `play` trumps; [time] then seeks
     * (clamped to `[0, endTime]` — `play`+`time` is `gotoAndPlay`);
     * the rest are knob writes. Null knobs leave the field alone.
     */
    fun applyOp(
        endTime: Double,
        play: Boolean = false,
        pause: Boolean = false,
        stop: Boolean = false,
        time: Double? = null,
        timeScale: Double? = null,
        weight: Double? = null,
        loop: Boolean? = null,
    ) {
        if (pause) playing = false
        if (stop) {
            playing = false
            this.time = 0.0
            active = false
        }
        if (play) {
            playing = true
            active = true
        }
        if (time != null) {
            this.time = time.coerceIn(0.0, endTime)
            active = true
        }
        if (timeScale != null) this.timeScale = timeScale
        if (weight != null) this.weight = weight.coerceIn(0.0, 1.0)
        if (loop != null) this.loop = loop
    }
}

/**
 * Each blending clip's effective weight this frame — upstream's
 * `AnimationPlayer.update` normalization (`weight × 1/Σweights` once
 * the sum exceeds 1) over the ACTIVE clips only. Stopped clips are
 * absent from the result: they neither contribute nor dilute the
 * others (#33).
 */
internal fun blendWeights(clips: Map<Long, AnimClipState>): Map<Long, Float> {
    var total = 0.0
    for (clip in clips.values) if (clip.active) total += clip.weight
    val mult = if (total > 1.0) 1.0 / total else 1.0
    val out = LinkedHashMap<Long, Float>()
    for (key in clips.keys.sorted()) {
        val clip = clips.getValue(key)
        if (clip.active) out[key] = (clip.weight * mult).toFloat()
    }
    return out
}
