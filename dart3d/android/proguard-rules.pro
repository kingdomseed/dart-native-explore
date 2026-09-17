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
