import AppKit
import Foundation

let root = "/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-owners"
func image(_ name: String) -> NSBitmapImageRep {
    NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: "\(root)/\(name).png")))!
}
func rgb(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) -> [Int] {
    let c = image.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
    return [c.redComponent, c.greenComponent, c.blueComponent].map { Int(($0 * 255).rounded()) }
}
func diff(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep) -> [String: Int] {
    var changed = 0, maximum = 0
    for y in 275..<370 { for x in 65..<335 {
        let d = zip(rgb(a, x, y), rgb(b, x, y)).map { abs($0 - $1) }.max()!
        if d > 0 { changed += 1 }
        maximum = max(maximum, d)
    }}
    return ["changedPixels": changed, "maximumChannelDifference": maximum]
}
let names = ["00-initial", "01-shared-quarter-seek1", "02-other-seek2", "03-default-current-A", "04-hidden-old-A", "05-replace-A-while-hidden", "06-old-default-restored", "07-foreign-rebind", "08-current-owner-only", "09-foreign-overridden", "10-foreign-restored"]
var comparisons: [String: [String: Int]] = [:]
var samples: [String: [[Int]]] = [:]
for name in names {
    let clean = image("clean-\(name)")
    let match = diff(image(name), clean)
    precondition(match["changedPixels"] == 0, name)
    comparisons[name] = match
    samples[name] = [110, 200, 290].map { rgb(clean, $0, 320) }
}
precondition(samples["01-shared-quarter-seek1"]![1] == samples["06-old-default-restored"]![1])
precondition(samples["06-old-default-restored"]![1] == samples["10-foreign-restored"]![1])
precondition(samples["07-foreign-rebind"]![2] == samples["10-foreign-restored"]![2])
precondition(samples["08-current-owner-only"]![0] != samples["06-old-default-restored"]![0])
let result: [String: Any] = ["comparisons": comparisons, "samplesSRGB8": samples, "crop": [65, 275, 270, 95], "sampleY": 320, "sampleX": [110, 200, 290], "boundary": "Decoded PNG RGB in sRGB. Exact clean/observed crop equality and retained-card equality; no calibrated linear color or performance claim."]
let data = try! JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try! data.write(to: URL(fileURLWithPath: "\(root)/image-proof.json"))
print("PASS: 11 clean replay crops match observed crops exactly; retained default and foreign-card samples unchanged.")
