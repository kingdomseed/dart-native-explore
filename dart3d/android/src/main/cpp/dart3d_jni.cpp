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
#include <mutex>
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

// ------------------------------------------------------------------
// W21 KTX2 decode via gltfio's Ktx2Provider.
//
// The pinned Filament (1.71.6) ships no Java-side standalone KTX2
// reader — filament-utils only exposes KTX1Loader, and gltfio's Java
// ResourceLoader decodes KTX2 solely into FilamentAsset members. The
// native side is reachable though: libgltfio-jni.so exports
// filament::gltfio::createKtx2Provider(Engine*), which wraps the same
// ktxreader::Ktx2Reader glTF loading uses, and libgltfio-jni.so
// DT_NEEDEDs the same libfilament-jni.so the Java Engine wraps — so
// Engine*/Texture* pointers round-trip between the Java objects and
// the provider. We dlsym the factory, drive
// pushTexture → waitForCompletion → updateQueue → popTexture on the
// Filament thread, and hand the Texture* back to Kotlin, which wraps
// it in com.google.android.filament.Texture's public (long) ctor.
//
// The class declaration below mirrors filament 1.71.6's
// libs/gltfio/include/gltfio/TextureProvider.h verbatim — vtable order
// is contractual. Never instantiate or subclass it; calls go through
// the provider's own vtable.

namespace filament { class Engine; class Texture; }
namespace filament { namespace gltfio {

class TextureProvider {
public:
    using Texture = filament::Texture;
    enum class TextureFlags : uint64_t { NONE = 0, sRGB = 1 << 0 };
    virtual Texture* pushTexture(const uint8_t* data, size_t byteCount,
            const char* mimeType, TextureFlags flags) = 0;
    virtual Texture* popTexture() = 0;
    virtual void updateQueue() = 0;
    virtual const char* getPushMessage() const = 0;
    virtual const char* getPopMessage() const = 0;
    virtual void waitForCompletion() = 0;
    virtual void cancelDecoding() = 0;
    virtual size_t getPushedCount() const = 0;
    virtual size_t getPoppedCount() const = 0;
    virtual size_t getDecodedCount() const = 0;
    virtual ~TextureProvider() = default;
};

}} // namespace filament::gltfio

typedef filament::gltfio::TextureProvider* (*CreateKtx2ProviderFn)(
    filament::Engine*);
// Engine::destroy(const Texture*) — a plain member function; on the
// Itanium ABI it is just a function taking `this` first.
typedef void (*DestroyTextureFn)(filament::Engine*,
    const filament::Texture*);

static std::mutex g_ktx2Mutex;
static filament::gltfio::TextureProvider* g_ktx2Provider = nullptr;
static filament::Engine* g_ktx2Engine = nullptr;

static void* ktx2Symbol(const char* name) {
    void* sym = dlsym(RTLD_DEFAULT, name);
    if (!sym) {
        // The Kotlin side loadLibrary()s gltfio-jni first, but cover a
        // missed load explicitly (dlopen is a no-op when already
        // mapped into this namespace).
        void* handle = dlopen("libgltfio-jni.so", RTLD_NOW | RTLD_LOCAL);
        if (handle) sym = dlsym(handle, name);
    }
    return sym;
}

static CreateKtx2ProviderFn createKtx2Provider() {
    static CreateKtx2ProviderFn fn = (CreateKtx2ProviderFn)ktx2Symbol(
        "_ZN8filament6gltfio18createKtx2ProviderEPNS_6EngineE");
    return fn;
}

static DestroyTextureFn engineDestroyTexture() {
    static DestroyTextureFn fn = (DestroyTextureFn)dlsym(RTLD_DEFAULT,
        "_ZN8filament6Engine7destroyEPKNS_7TextureE");
    return fn;
}

/**
 * Synchronously transcodes one KTX2 payload to a Filament texture.
 * Returns the native `filament::Texture*` (0 on failure); the Kotlin
 * caller wraps it in `com.google.android.filament.Texture` and owns
 * its engine-side destruction.
 */
extern "C" JNIEXPORT jlong JNICALL
Java_com_jasonholtdigital_dart3d_TextureFactory_nKtx2Decode(
        JNIEnv* env, jobject, jlong nativeEngine, jbyteArray bytes,
        jboolean srgb) {
    auto* engine = reinterpret_cast<filament::Engine*>(nativeEngine);
    if (!engine || !bytes) return 0;
    CreateKtx2ProviderFn create = createKtx2Provider();
    if (!create) {
        LOGW("ktx2: filament::gltfio::createKtx2Provider not found — "
             "is libgltfio-jni.so packaged?");
        return 0;
    }
    jsize len = env->GetArrayLength(bytes);
    if (len <= 0) return 0;

    std::lock_guard<std::mutex> lock(g_ktx2Mutex);
    if (g_ktx2Engine != engine || g_ktx2Provider == nullptr) {
        // A stale provider's Engine may already be destroyed — deleting
        // it would dereference the dead engine, so abandon it (a
        // provider is a reader object + an empty queue; it dies with
        // the process/engine teardown).
        g_ktx2Provider = create(engine);
        g_ktx2Engine = engine;
    }
    if (!g_ktx2Provider) {
        LOGW("ktx2: createKtx2Provider returned null");
        return 0;
    }

    jbyte* data = env->GetByteArrayElements(bytes, nullptr);
    if (!data) return 0;
    filament::Texture* pushed = g_ktx2Provider->pushTexture(
        reinterpret_cast<const uint8_t*>(data), (size_t)len,
        "image/ktx2",
        srgb ? filament::gltfio::TextureProvider::TextureFlags::sRGB
             : filament::gltfio::TextureProvider::TextureFlags::NONE);
    env->ReleaseByteArrayElements(bytes, data, JNI_ABORT);
    if (!pushed) {
        const char* msg = g_ktx2Provider->getPushMessage();
        LOGW("ktx2: pushTexture failed: %s", msg ? msg : "no message");
        return 0;
    }

    // Transcoding ran on the engine's JobSystem; wait it out, then let
    // updateQueue() perform the Texture::setImage uploads and move the
    // item to the poppable set.
    g_ktx2Provider->waitForCompletion();
    filament::Texture* ours = nullptr;
    bool oursComplete = false;
    for (int i = 0; i < 8 && !ours; i++) {
        g_ktx2Provider->updateQueue();
        filament::Texture* popped;
        while ((popped = g_ktx2Provider->popTexture()) != nullptr) {
            const char* msg = g_ktx2Provider->getPopMessage();
            if (popped == pushed) {
                ours = popped;
                oursComplete = (msg == nullptr);
                if (msg) {
                    LOGW("ktx2: transcode incomplete: %s", msg);
                }
            } else {
                // Pushes are mutex-serialized, so a foreign item here is
                // a stale leftover — destroy it through the engine.
                LOGW("ktx2: discarding a stale queue texture (%s)",
                     msg ? msg : "ok");
                DestroyTextureFn destroy = engineDestroyTexture();
                if (destroy) destroy(engine, popped);
            }
        }
    }
    if (!ours) {
        LOGW("ktx2: texture never became poppable");
        return 0;
    }
    if (!oursComplete) {
        DestroyTextureFn destroy = engineDestroyTexture();
        if (destroy) destroy(engine, ours);
        return 0;
    }
    return reinterpret_cast<jlong>(ours);
}
