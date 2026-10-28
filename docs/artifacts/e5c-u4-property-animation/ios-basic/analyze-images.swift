import AppKit
import Foundation

let directory = "/private/tmp/dart3d-e5c-u4-runtime-20261027/ios"
func image(_ name: String) -> NSBitmapImageRep {
    NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: "\(directory)/\(name)")))!
}
func rgb(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) -> [Int] {
    let c = image.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
    return [c.redComponent, c.greenComponent, c.blueComponent].map { Int(($0 * 255).rounded()) }
}
var samples: [String: [[Int]]] = [:]
for name in ["color-t0.png", "color-t1.png", "color-t2.png", "color-quarter-t1.png"] {
    let bitmap = image(name)
    let values = [129, 200, 273].map { rgb(bitmap, $0, 340) }
    precondition(values[0] == values[1], "Shared material differs at sampled centers")
    samples[name] = values
}
let normal = image("color-t1.png"), raw = image("raw-clean-t1.png")
var changed = 0, maximumDifference = 0
for y in 280..<410 {
    for x in 80..<330 {
        let a = rgb(normal, x, y), b = rgb(raw, x, y)
        let difference = zip(a, b).map { abs($0 - $1) }.max()!
        if difference > 0 { changed += 1 }
        maximumDifference = max(maximumDifference, difference)
    }
}
var frames: [String: [[String: Int]]] = [:]
for name in ["camera-t0.png", "camera-t1.png", "camera-t2.png"] {
    let bitmap = image(name)
    var boxes: [[String: Int]] = []
    var start: Int? = nil, minY = 600, maxY = 0
    for x in 0...402 {
        let ys = x < 402 ? (180..<600).filter { rgb(bitmap, x, $0).max()! > 16 } : []
        if !ys.isEmpty {
            if start == nil { start = x }
            minY = min(minY, ys.first!); maxY = max(maxY, ys.last!)
        } else if let first = start {
            boxes.append(["x": first, "y": minY, "width": x - first, "height": maxY - minY + 1])
            start = nil; minY = 600; maxY = 0
        }
    }
    precondition(boxes.count == 3, "Expected three visible faces")
    frames[name] = boxes
}
let widths = ["camera-t0.png", "camera-t1.png", "camera-t2.png"].map { frames[$0]![0]["width"]! }
precondition(widths[0] > widths[1] && widths[1] > widths[2])
let result: [String: Any] = ["sRgbCenterSamples": samples,
    "cameraFaceBounds": frames, "rawVsCanonicalCrop": ["x": 80, "y": 280, "width": 250, "height": 130,
        "changedPixels": changed, "maximumChannelDifference": maximumDifference],
    "boundary": "Offline NSBitmapImageRep samples converted to sRGB, not calibrated linear material or photometric measurements"]
let data = try! JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try! data.write(to: URL(fileURLWithPath: "\(directory)/image-checks.json"))
print(String(data: data, encoding: .utf8)!)
