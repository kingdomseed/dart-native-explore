import AppKit
import Foundation

let input = URL(fileURLWithPath: "/private/tmp/dart3d-e5c-u4-runtime-20261027/ios")
let output = URL(fileURLWithPath: "/private/tmp/dart3d-e5c-u4-ios-basic-review-20261027/r1")
func load(_ name: String) -> NSBitmapImageRep {
    NSBitmapImageRep(data: try! Data(contentsOf: input.appendingPathComponent(name)))!
}
func pixel(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int) -> [Int] {
    let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
    return [color.redComponent, color.greenComponent, color.blueComponent].map { Int(($0 * 255).rounded()) }
}
var samples: [String: [[Int]]] = [:]
for name in ["color-t0.png", "color-t1.png", "color-t2.png", "color-quarter-t1.png"] {
    let bitmap = load(name)
    precondition(bitmap.pixelsWide == 402 && bitmap.pixelsHigh == 874)
    samples[name] = [129, 200, 273].map { pixel(bitmap, $0, 340) }
    precondition(samples[name]![0] == samples[name]![1])
}
var camera: [String: [[String: Int]]] = [:]
for name in ["camera-t0.png", "camera-t1.png", "camera-t2.png"] {
    let bitmap = load(name)
    var active = Set<Int>()
    for y in 180..<600 {
        for x in 0..<402 where pixel(bitmap, x, y).max()! > 16 {
            active.insert(y * 402 + x)
        }
    }
    var boxes: [[String: Int]] = []
    while let start = active.first {
        active.remove(start)
        var queue = [start], cursor = 0, minX = start % 402, maxX = minX
        var minY = start / 402, maxY = minY
        while cursor < queue.count {
            let value = queue[cursor]; cursor += 1
            let x = value % 402, y = value / 402
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
            for next in [value - 402, value + 402, value - 1, value + 1] {
                if active.remove(next) != nil { queue.append(next) }
            }
        }
        boxes.append(["x": minX, "y": minY, "width": maxX - minX + 1, "height": maxY - minY + 1])
    }
    boxes.sort { $0["x"]! < $1["x"]! }
    precondition(boxes.count == 3)
    precondition(boxes.allSatisfy { $0["y"]! + $0["height"]! < 707 })
    camera[name] = boxes
}
let canonical = load("color-t1.png"), raw = load("raw-clean-t1.png")
var changed = 0, maxDifference = 0
for y in 280..<410 {
    for x in 80..<330 {
        let differences = zip(pixel(canonical, x, y), pixel(raw, x, y)).map { abs($0 - $1) }
        let difference = differences.max()!
        if difference != 0 { changed += 1 }
        maxDifference = max(maxDifference, difference)
    }
}
let receipt: [String: Any] = ["sRgbCenterSamples": samples, "cameraFaceBounds": camera,
    "rawVsCanonicalCrop": ["x": 80, "y": 280, "width": 250, "height": 130,
        "changedPixels": changed, "maximumChannelDifference": maxDifference],
    "method": "Independent connected-component bounds, actual AppKit sRGB pixels; offline screenshot measurements only"]
let expected = try! JSONSerialization.jsonObject(with: Data(contentsOf: input.appendingPathComponent("image-checks.json"))) as! [String: Any]
for key in ["sRgbCenterSamples", "cameraFaceBounds", "rawVsCanonicalCrop"] {
    precondition(NSDictionary(dictionary: [key: receipt[key]!]).isEqual(to: [key: expected[key]!]))
}
let data = try! JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
try! data.write(to: output.appendingPathComponent("image-receipt.json"))
print(String(data: data, encoding: .utf8)!)
