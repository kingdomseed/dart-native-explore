package com.jasonholtdigital.dart3d

import com.google.android.filament.LightManager

internal fun LightManager.setShadowOptionsPreservingTransform(
    lightInstance: Int,
    options: LightManager.ShadowOptions,
) {
    val transform = options.transform
    // Filament 1.77.3 JNI passes XYZW to a WXYZ quaternion constructor.
    options.setTransform(transform[3], transform[0], transform[1], transform[2])
    try {
        setShadowOptions(lightInstance, options)
    } finally {
        options.setTransform(transform)
    }
}
