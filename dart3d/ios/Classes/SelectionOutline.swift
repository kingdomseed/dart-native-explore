import Foundation

final class SelectionOutline {
    struct LinearRGBA {
        let r, g, b, a: Float
    }

    struct Change {
        let node: UInt64
        let color: LinearRGBA?
    }

    private var colors: [UInt64: LinearRGBA] = [:]

    var isEmpty: Bool { colors.isEmpty }

    func forEachActive(_ visit: (UInt64, LinearRGBA) -> Void) {
        for id in colors.keys.sorted() { visit(id, colors[id]!) }
    }

    func apply(_ changes: [Change]) {
        for change in changes {
            colors[change.node] = change.color
        }
    }

    func removeNodes(_ ids: [UInt64]) {
        for id in ids { colors.removeValue(forKey: id) }
    }

    func retainNodes(_ ids: Set<UInt64>) {
        colors = colors.filter { ids.contains($0.key) }
    }

    func clearScene() {
        colors.removeAll()
    }
}
