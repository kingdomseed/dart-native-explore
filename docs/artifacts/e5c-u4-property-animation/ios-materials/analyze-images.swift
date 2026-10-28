import AppKit
import Foundation

let directory = "/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-materials"
func image(_ name: String) -> NSBitmapImageRep {
    NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: "\(directory)/\(name)")))!
}
func rgb(_ bitmap: NSBitmapImageRep, _ x: Int, _ y: Int) -> [Int] {
    let color = bitmap.colorAt(x:x,y:y)!.usingColorSpace(.sRGB)!
    return [color.redComponent,color.greenComponent,color.blueComponent].map { Int(($0*255).rounded()) }
}
func differences(_ a:NSBitmapImageRep,_ b:NSBitmapImageRep,x:Int,y:Int,w:Int,h:Int) -> [String:Int] {
    var count=0, maximum=0
    for row in y..<(y+h) { for column in x..<(x+w) {
        let difference=zip(rgb(a,column,row),rgb(b,column,row)).map { abs($0-$1) }.max()!
        if difference>0 { count += 1 }; maximum=max(maximum,difference)
    }}
    return ["changedPixels":count,"maximumChannelDifference":maximum]
}
var samples:[String:[String:[Int]]]=[:]
for name in ["t0.png","t1.png","t2.png","quarter-t1.png","clean-t0.png","clean-t1.png","alpha-candidate-t0.png","alpha-candidate-t1.png","alpha-candidate-t2.png","final-t0.png","final-t1.png","final-t2.png"] {
    let bitmap=image(name)
    samples[name] = [
        "sharedWhite":rgb(bitmap,107,191),"sharedGray":rgb(bitmap,165,191),
        "sharedPeerWhite":rgb(bitmap,236,191),
        "pbrWhite":rgb(bitmap,107,290),"pbrGray":rgb(bitmap,165,290),
        "referenceWhite":rgb(bitmap,236,290),"referenceGray":rgb(bitmap,294,290),
        "alphaWhite":rgb(bitmap,107,389),"alphaGray":rgb(bitmap,165,389),
        "alphaBacking":rgb(bitmap,94,414),"snapshotCenter":rgb(bitmap,265,414),
    ]
    precondition(samples[name]!["sharedWhite"]==samples[name]!["sharedPeerWhite"])
    precondition(samples[name]!["snapshotCenter"]==[0,0,0])
}
let referenceCrop=differences(image("t0.png"),image("t2.png"),x:225,y:280,w:80,h:80)
let snapshotCrop=differences(image("t0.png"),image("t2.png"),x:221,y:374,w:88,h:89)
let clean0=differences(image("t0.png"),image("clean-t0.png"),x:90,y:175,w:222,h:290)
let clean1=differences(image("t1.png"),image("clean-t1.png"),x:90,y:175,w:222,h:290)
precondition(referenceCrop["changedPixels"]==0)
precondition(snapshotCrop["changedPixels"]==0)
precondition(clean0["changedPixels"]==0 && clean1["changedPixels"]==0)
var corrected:[String:[String:Int]]=[:]
for state in 0...2 {
    let before=image("t\(state).png"), after=image("final-t\(state).png")
    let upper=differences(before,after,x:90,y:175,w:222,h:190)
    let snapshot=differences(before,after,x:221,y:374,w:88,h:89)
    let candidate=differences(image("alpha-candidate-t\(state).png"),after,x:90,y:175,w:222,h:290)
    precondition(upper["changedPixels"]==0 && snapshot["changedPixels"]==0 && candidate["changedPixels"]==0)
    corrected["t\(state)UnchangedUpperFaces"]=upper
    corrected["t\(state)UnchangedSnapshot"]=snapshot
    corrected["t\(state)CleanVsCandidate"]=candidate
}
precondition(samples["t0.png"]!["alphaWhite"]![0] < samples["t0.png"]!["alphaBacking"]![0])
precondition(samples["final-t0.png"]!["alphaWhite"]![0] > samples["final-t0.png"]!["alphaBacking"]![0])
let result:[String:Any] = ["sRgbSamples":samples,"referenceUnchanged":referenceCrop,
    "snapshotUnchanged":snapshotCrop,"cleanT0Crop":clean0,"cleanT1Crop":clean1,
    "correctedComparisons":corrected,
    "boundary":"Encoded PNG samples converted to sRGB; not a calibrated linear alpha/color measurement. Reference/snapshot comparisons and clean-probe comparisons are exact pixel differences."]
let data=try! JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
try! data.write(to:URL(fileURLWithPath:"\(directory)/image-checks.json"))
print(String(data:data,encoding:.utf8)!)
