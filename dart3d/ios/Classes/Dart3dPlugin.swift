import UIKit
import SceneKit
import OSLog

/// dart3d plugin provider (iOS).
///
/// Registers `SceneViewHost` as the native view for the
/// `com.jasonholtdigital.dart3d/sceneView` view type and routes
/// `PluginMutation` bytes to it. Registration is `dlsym`-based — see
/// "Why dlsym, not import dartnative_ios" in docs/plugin_development.md.

private let _d3Logger = Logger(
    subsystem: "com.jasonholtdigital.dart3d", category: "scene")

/// Plugin logging — `os_log`, not `print`, so lines reach the unified
/// log (`simctl spawn … log stream --level debug` for a live feed).
func d3Log(_ msg: String) { _d3Logger.log("\(msg)") }

// Must match kSceneViewTypeKey in lib/src/scene_view.dart.
private let D3_TYPE_KEY = "com.jasonholtdigital.dart3d/sceneView"

// Message kinds — must match D3Protocol in lib/src/protocol.dart.
private let D3_MSG_HELLO: Int32 = 1
private let D3_MSG_LOAD_SCENE: Int32 = 2
private let D3_MSG_PAYLOAD: Int32 = 3
private let D3_MSG_SET_TRANSFORMS: Int32 = 4
private let D3_MSG_COMMAND: Int32 = 5
private let D3_MSG_VIEW_CONFIG: Int32 = 6

/// Claimed lazily on first use. Same key as the Dart side → same index,
/// assigned by the framework at runtime.
private let D3_TYPE_INDEX: Int32 = {
    typealias ClaimFn = @convention(c) (UnsafePointer<CChar>) -> Int32
    guard let s = dlsym(dlopen(nil, RTLD_NOLOAD), "DNViewTypeClaim") else {
        return -1
    }
    return D3_TYPE_KEY.withCString { unsafeBitCast(s, to: ClaimFn.self)($0) }
}()

private let _d3CreateView: @convention(c) (Int32) -> Int64 = { typeIndex in
    guard typeIndex == D3_TYPE_INDEX else { return 0 }
    return Int64(
        Int(bitPattern: Unmanaged.passRetained(SceneViewHost(frame: .zero)).toOpaque())
    )
}

private let _d3HandleMutation: @convention(c)
    (Int64, Int32, UnsafePointer<UInt8>?, Int32) -> Void =
{ viewId, eventTag, dataPtr, dataLen in
    guard let host = _d3ViewFor(viewId) as? SceneViewHost else { return }
    let data = (dataPtr != nil && dataLen > 0)
        ? Data(bytes: dataPtr!, count: Int(dataLen))
        : Data()
    // Scene/physics mutation must not run on the delivery thread — the
    // render queue's physics step iterates live constraint/body arrays
    // with no external lock. Everything enqueues and drains at the top
    // of `renderer(_:updateAtTime:)`; the FIFO keeps the hello-gate's
    // ordering semantics intact.
    host.enqueueSceneWork { [weak host] in
        guard let host else { return }
        host.viewId = viewId
        if eventTag != D3_MSG_HELLO && !host.sawHello {
            host.logOnce("preHello",
                "WARNING: mutation \(eventTag) received before protocol "
                + "hello")
        }
        switch eventTag {
        case D3_MSG_HELLO:          host.applyHello(data)
        case D3_MSG_LOAD_SCENE:     host.applyLoadScene(data)
        case D3_MSG_PAYLOAD:        host.applyPayload(data)
        case D3_MSG_SET_TRANSFORMS: host.applySetTransforms(data)
        case D3_MSG_COMMAND:        host.applyCommand(data)
        case D3_MSG_VIEW_CONFIG:    host.applyViewConfig(data)
        default:
            d3Log("unknown eventTag=\(eventTag)")
        }
    }
}

// ── Plumbing (do not edit) ───────────────────────────────────────────────
private typealias _GetViewFn = @convention(c) (Int64) -> Int64
private let _dnGetView: _GetViewFn? = {
    guard let s = dlsym(dlopen(nil, RTLD_NOLOAD), "DNViewRegistryGetView")
    else { return nil }
    return unsafeBitCast(s, to: _GetViewFn.self)
}()
private func _d3ViewFor(_ id: Int64) -> UIView? {
    guard let fn = _dnGetView else { return nil }
    let p = fn(id)
    guard p != 0 else { return nil }
    return Unmanaged<UIView>.fromOpaque(
        UnsafeRawPointer(bitPattern: Int(p))!
    ).takeUnretainedValue()
}

@_cdecl("DNDart3dRegisterProvider")
public func DNDart3dRegisterProvider() {
    guard let s = dlsym(dlopen(nil, RTLD_NOLOAD), "DNRegisterPluginProvider")
    else {
        d3Log("dlsym DNRegisterPluginProvider FAILED — is dartnative_ios linked?")
        return
    }
    typealias _RegFn = @convention(c) (Int64, Int64) -> Void
    let reg = unsafeBitCast(s, to: _RegFn.self)
    reg(
        unsafeBitCast(
            _d3CreateView as @convention(c) (Int32) -> Int64,
            to: Int64.self
        ),
        unsafeBitCast(
            _d3HandleMutation as @convention(c)
                (Int64, Int32, UnsafePointer<UInt8>?, Int32) -> Void,
            to: Int64.self
        ),
    )
}

// ── Native→Dart event channel (dispatcher slot) ──────────────────────────
// The standard pattern from docs/plugin_async_callbacks.md: one callback
// pointer for the whole plugin, stored in ONE heap slot the framework can
// zero on hot restart, re-read before every call. Events carry the view's
// viewId as the token so one pointer serves every SceneView.

private let _d3DispatcherSlot: UnsafeMutablePointer<Int64> = {
    let p = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
    p.pointee = 0
    return p
}()
private var _d3SlotRegistered = false

@_cdecl("Dart3dSetDispatcher")
public func Dart3dSetDispatcher(_ callbackPtr: Int64) {
    _d3DispatcherSlot.pointee = callbackPtr
    if !_d3SlotRegistered {
        _d3SlotRegistered = true
        typealias RegFn = @convention(c) (UnsafeMutablePointer<Int64>) -> Void
        if let sym = dlsym(dlopen(nil, RTLD_NOLOAD),
                          "DNRegisterAsyncDispatcherSlot") {
            unsafeBitCast(sym, to: RegFn.self)(_d3DispatcherSlot)
        }
    }
}

private typealias _D3Dispatch =
    @convention(c) (Int64, Int32, UnsafePointer<CChar>) -> Void

/// Fires one `(token, type, json)` frame to Dart. Event types match
/// `D3Event` in lib/src/dispatch.dart: 1 = awake, 2 = settled. Callers
/// must already be on the main thread (SceneViewHost hops first).
func d3FireToDart(token: Int64, type: Int32, payload: String) {
    let addr = _d3DispatcherSlot.pointee   // read fresh — never cache
    guard addr != 0 else { return }        // hot restart → drop quietly
    payload.withCString { cStr in
        unsafeBitCast(addr, to: _D3Dispatch.self)(token, type, cStr)
    }
}
