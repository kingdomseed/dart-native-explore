import AppKit
import Foundation

let root = "/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-lights"
let names = ["00-initial","01-full-t1","02-full-t2","03-quarter-t1","04-replaced","05-replaced-t2","06-removed","07-readded","08-readded-t1"]
func image(_ name: String) -> NSBitmapImageRep { NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath:"\(root)/\(name).png")))! }
func rgb(_ im: NSBitmapImageRep, _ x: Int, _ y: Int) -> [Int] {
    let c = im.colorAt(x:x,y:y)!.usingColorSpace(.sRGB)!
    return [c.redComponent,c.greenComponent,c.blueComponent].map { Int(($0*255).rounded()) }
}
var matches: [String:[String:Int]] = [:]
var samples: [String:[[Int]]] = [:]
for name in names {
    let a=image("area-\(name)"), b=image("area-clean-\(name)")
    var changed=0, maximum=0
    for y in 300..<385 { for x in 95..<310 {
        let d=zip(rgb(a,x,y),rgb(b,x,y)).map {abs($0-$1)}.max()!
        if d>0 {changed += 1}; maximum=max(maximum,d)
    }}
    precondition(changed==0,name)
    matches[name] = ["changedPixels":changed,"maximumChannelDifference":maximum]
    for lane in ["point","spot","area"] { samples["\(lane)-\(name)"] = [129,201,274].map {rgb(image("\(lane)-\(name)"),$0,342)} }
}
for lane in ["point","spot","area"] {
    let lit=samples["\(lane)-05-replaced-t2"]!, removed=samples["\(lane)-06-removed"]!, restored=samples["\(lane)-07-readded"]!
    precondition(lit[2].contains(where:{$0>0}) && removed[2]==[0,0,0] && restored[2].contains(where:{$0>0}))
    precondition(lit[0]==removed[0] && removed[0]==restored[0] && lit[1]==removed[1] && removed[1]==restored[1])
}
let result:[String:Any] = ["areaCleanMatches":matches,"crop":[95,300,215,85],"samplesSRGB8":samples,"lightRemovalAndRestorationSamplesPass":true,"boundary":"Exact decoded PNGs converted to sRGB. Samples illustrate scene output; actual native field logs establish unit conversions. No photometric calibration or monotonic area-size/brightness claim."]
let data=try! JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
try! data.write(to:URL(fileURLWithPath:"\(root)/image-proof.json"))

let cellW=120, cellH=281, width=cellW*9, height=cellH*3
let canvas=NSImage(size:NSSize(width:width,height:height))
canvas.lockFocus()
NSColor.black.setFill(); NSRect(x:0,y:0,width:width,height:height).fill()
for (row,lane) in ["point","spot","area"].enumerated() {
    for (col,name) in names.enumerated() {
        let x=col*cellW, y=height-(row+1)*cellH
        let source=NSImage(contentsOfFile:"\(root)/\(lane)-\(name).png")!
        source.draw(in:NSRect(x:x,y:y+20,width:120,height:261))
        let title="\(lane) \(name.prefix(2))" as NSString
        title.draw(at:NSPoint(x:x+4,y:y+3),withAttributes:[.foregroundColor:NSColor.white,.font:NSFont.monospacedSystemFont(ofSize:11,weight:.regular)])
    }
}
canvas.unlockFocus()
let bitmap=NSBitmapImageRep(data:canvas.tiffRepresentation!)!
try! bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"\(root)/all-lanes-contact.png"))
print("PASS: nine clean area crops match exactly; all27 lane images sampled and assembled.")
