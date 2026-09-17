// dart3d native→Dart event bridge for Android.
//
// Mirrors Dart3dPlugin.swift on iOS: Dart hands ONE C callback pointer
// to `Dart3dSetDispatcher` at startup (d3DispatcherPointer in
// lib/src/dispatch.dart); native re-reads the slot before every call so
// a stale pointer can never fire after a hot restart. Events carry the
// view's viewId token so one pointer serves every scene view.
//
// The Kotlin side calls nativeFireToDart(); the symbol lookup from Dart
// uses DynamicLibrary.open("libdart3d_jni.so") which resolves to this
// already-loaded library.

#include <jni.h>
#include <stdint.h>
#include <dlfcn.h>
#include <android/log.h>

#define LOG_TAG "dart3d"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)

// void (*)(int64_t viewId, int32_t type, const char* utf8Payload)
typedef void (*D3DispatchFn)(int64_t, int32_t, const char*);
// uint64_t DN_IsolateGen() — libdartnative_android's isolate generation,
// bumped before the old isolate dies on hot restart.
typedef uint64_t (*D3IsolateGenFn)();

static D3DispatchFn g_dispatch = nullptr;
static uint64_t g_dispatchGen = 0;

static D3IsolateGenFn isolateGen() {
    static D3IsolateGenFn fn =
        (D3IsolateGenFn)dlsym(RTLD_DEFAULT, "DN_IsolateGen");
    return fn;
}

// Called by Dart's FFI layer (ffi_bindings.dart). Plain C symbol so
// dlsym finds it — same contract as iOS.
extern "C" JNIEXPORT void JNICALL
Dart3dSetDispatcher(int64_t fnPtr) {
    g_dispatch = reinterpret_cast<D3DispatchFn>(fnPtr);
    // Capture the generation WITH the pointer: the trampoline it names
    // dies with the isolate that registered it.
    D3IsolateGenFn gen = isolateGen();
    g_dispatchGen = gen ? gen() : 0;
    LOGI("Dart3dSetDispatcher: slot %s", fnPtr ? "armed" : "cleared");
}

extern "C" JNIEXPORT void JNICALL
Java_com_jasonholtdigital_dart3d_Dart3dJni_nativeFireToDart(
        JNIEnv* env, jclass, jlong token, jint type, jstring payload) {
    D3DispatchFn fn = g_dispatch;   // re-read every call: hot-restart safe
    if (!fn) {
        LOGW("fireToDart dropped (no dispatcher): type=%d", type);
        return;
    }
    D3IsolateGenFn gen = isolateGen();
    if (gen && gen() != g_dispatchGen) {
        LOGW("fireToDart dropped (stale isolate generation): type=%d",
            type);
        return;
    }
    const char* utf = env->GetStringUTFChars(payload, nullptr);
    fn(token, type, utf);
    env->ReleaseStringUTFChars(payload, utf);
}
