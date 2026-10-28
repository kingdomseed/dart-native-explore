import AppKit
import Foundation

let root = "/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-snapshots"
func image(_ name: String) -> NSBitmapImageRep {
    NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: "\(root)/\(name).png")))!
}
func rgb(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) -> [Int] {
    let c = image.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
    return [c.redComponent, c.greenComponent, c.blueComponent].map { Int(($0 * 255).rounded()) }
}
func diff(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep, _ rect: [Int]) -> [String: Int] {
    var changed = 0, maximum = 0
    for y in rect[1]..<(rect[1]+rect[3]) { for x in rect[0]..<(rect[0]+rect[2]) {
        let d = zip(rgb(a, x, y), rgb(b, x, y)).map { abs($0 - $1) }.max()!
        if d > 0 { changed += 1 }
        maximum = max(maximum, d)
    }}
    return ["changedPixels": changed, "maximumChannelDifference": maximum]
}
let names = ["00-initial", "01-quarter-seek1", "02-ordinary-image-arrival", "03-first-sprite-snapshot", "04-current-seek2", "05-sprite-image-arrival", "06-refreshed-ready-snapshot", "07-source-only-seek1", "08-variant-other", "09-restored-snapshot"]
let both = [100,275,210,95], current = [105,280,85,90], snapshot = [210,280,90,90]
var comparisons: [String: [String: Int]] = [:]
for name in names {
    let match = diff(image(name), image("clean-\(name)"), both)
    precondition(match["changedPixels"] == 0, name)
    comparisons["cleanMatch-\(name)"] = match
}
for (label, before, after) in [("ordinaryLateTexture",1,2),("spriteLateTexture",4,5),("seekKeepsSnapshot",6,7)] {
    let a = image("clean-\(names[before])"), b = image("clean-\(names[after])")
    let c = diff(a,b,current), s = diff(a,b,snapshot)
    precondition(c["changedPixels"]! > 100)
    precondition(s["changedPixels"] == 0)
    comparisons["\(label)-current"] = c
    comparisons["\(label)-snapshot"] = s
}
let refreshCurrent = diff(image("clean-\(names[5])"), image("clean-\(names[6])"), current)
let refreshSnapshot = diff(image("clean-\(names[5])"), image("clean-\(names[6])"), snapshot)
precondition(refreshCurrent["changedPixels"] == 0)
precondition(refreshSnapshot["changedPixels"]! > 100)
comparisons["readyRefresh-current"] = refreshCurrent
comparisons["readyRefresh-snapshot"] = refreshSnapshot
let restored = diff(image("clean-\(names[7])"), image("clean-\(names[9])"), both)
precondition(restored["changedPixels"] == 0)
comparisons["variantRoundTrip"] = restored
let firstRefresh = image("clean-\(names[3])")
precondition(rgb(firstRefresh,147,320) == rgb(firstRefresh,254,320))
let result: [String: Any] = ["comparisons":comparisons,"bothCrop":both,"currentCrop":current,"snapshotCrop":snapshot,"firstRefreshCenterSamples":[rgb(firstRefresh,147,320),rgb(firstRefresh,254,320)],"boundary":"Decoded PNGs converted to sRGB, exact crop comparisons; no linear color calibration, raw visibility or latency claim."]
let data = try! JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted,.sortedKeys])
try! data.write(to: URL(fileURLWithPath: "\(root)/image-proof.json"))
print("PASS: 10 clean matches; late textures and seek preserve snapshot crop; refresh updates only snapshot; variant round trip exact.")
