import Foundation

/// W25 fix-2: one resolver for every wire asset `ref`. DartNative —
/// like Flutter — nests the pubspec `assets/` tree at
/// `Frameworks/App.framework/flutter_assets/<ref>` inside the app
/// bundle, so a bare `Bundle.main.url(forResource:)` misses packaged
/// assets. Try the nested path first, then the bundle root (non-
/// Flutter-packaged resources still resolve); a ref already carrying
/// the prefix skips the double-prefix.
enum FlutterAssets {
    static func url(forResource ref: String) -> URL? {
        guard !ref.isEmpty else { return nil }
        if let dir = Bundle.main.privateFrameworksPath {
            let nested = ref.hasPrefix("flutter_assets/") ? ref
                : "flutter_assets/" + ref
            let url = URL(fileURLWithPath: dir)
                .appendingPathComponent("App.framework")
                .appendingPathComponent(nested)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return Bundle.main.url(forResource: ref, withExtension: nil)
    }

    static func data(forResource ref: String) -> Data? {
        url(forResource: ref).flatMap { try? Data(contentsOf: $0) }
    }
}
