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
     * Applies one `anim` op's verbs and knobs. Verbs apply in
     * pause→stop→play order so `play` trumps; [time] then seeks
     * (clamped to `[0, endTime]` — `play`+`time` is `gotoAndPlay`);
     * the rest are knob writes. Null knobs leave the field alone.
     * `stop` is upstream's: pause + rewind — the clip stays in the
     * blend at its weight (switch clips by dropping the weight to 0).
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
        }
        if (play) playing = true
        if (time != null) this.time = time.coerceIn(0.0, endTime)
        if (timeScale != null) this.timeScale = timeScale
        if (weight != null) this.weight = weight.coerceIn(0.0, 1.0)
        if (loop != null) this.loop = loop
    }
}

/**
 * Each registered clip's effective weight this frame, in key order —
 * upstream's `AnimationPlayer.update` normalization: `weight × 1/Σ`
 * once the sum of every clip's weight exceeds 1. A weight-0 clip maps
 * to 0 and contributes nothing, so a node only zero-weight clips bind
 * writes back at its bind pose.
 */
internal fun blendWeights(clips: Map<Long, AnimClipState>): Map<Long, Float> {
    var total = 0.0
    for (clip in clips.values) total += clip.weight
    val mult = if (total > 1.0) 1.0 / total else 1.0
    val out = LinkedHashMap<Long, Float>()
    for (key in clips.keys.sorted()) {
        out[key] = (clips.getValue(key).weight * mult).toFloat()
    }
    return out
}
