# jolt-jni's native layer looks its Custom* callback methods up by
# name via JNI GetMethodID when the wrapper's ctor runs — nothing in
# Java calls them, so R8 would rename/strip them (release-only crash:
# NoSuchMethodError inside createCustomContactListener). Keep the
# class names and the public methods; the second rule keeps the
# overrides on CustomContactListener subclasses — removing one would
# bind the base no-op and silently drop every contact event.
-keepnames class com.github.stephengold.joltjni.Custom*
-keepclassmembers class com.github.stephengold.joltjni.Custom* {
    public *;
}
-keepclassmembers class * extends com.github.stephengold.joltjni.CustomContactListener {
    public *;
}
-keepclassmembers class * extends com.github.stephengold.joltjni.CustomCharacterContactListener {
    public *;
}

-keep class com.jasonholtdigital.dart3d.JoltStairWidth {
    native <methods>;
}

# dart3d_jni's nativeMaterialBuilderInstanced reads MaterialBuilder's
# private mNativeObject pointer via JNI GetFieldID.
-keepclassmembers class com.google.android.filament.filamat.MaterialBuilder {
    long mNativeObject;
}

# Filament's nGetShadowOptions resolves ShadowOptions fields by name.
-keep class com.google.android.filament.LightManager$ShadowOptions { *; }

# Filament's nForEach resolves accept(int) by name on the callback object.
-keep interface com.google.android.filament.Scene$ForEachCallback {
    public void accept(int);
}
-keepclassmembers class * implements com.google.android.filament.Scene$ForEachCallback {
    public void accept(int);
}

# Filament's bounding-box getter writes these fields through JNI.
-keepclassmembers class com.google.android.filament.Box {
    float mCenterX;
    float mCenterY;
    float mCenterZ;
    float mHalfExtentX;
    float mHalfExtentY;
    float mHalfExtentZ;
}
