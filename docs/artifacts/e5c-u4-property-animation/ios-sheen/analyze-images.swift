import AppKit
import Foundation

let root="/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-sheen"
func image(_ name:String)->NSBitmapImageRep { NSBitmapImageRep(data:try! Data(contentsOf:URL(fileURLWithPath:"\(root)/\(name)")))! }
func rgb(_ image:NSBitmapImageRep,_ x:Int,_ y:Int)->[Int] {
    let c=image.colorAt(x:x,y:y)!.usingColorSpace(.sRGB)!
    return [c.redComponent,c.greenComponent,c.blueComponent].map {Int(($0*255).rounded())}
}
func diff(_ a:NSBitmapImageRep,_ b:NSBitmapImageRep,_ rect:(Int,Int,Int,Int))->[String:Int] {
    var changed=0, maximum=0
    for y in rect.1..<(rect.1+rect.3) {for x in rect.0..<(rect.0+rect.2) {
        let d=zip(rgb(a,x,y),rgb(b,x,y)).map {abs($0-$1)}.max()!
        if d>0 {changed += 1}; maximum=max(maximum,d)
    }}
    return ["changedPixels":changed,"maximumChannelDifference":maximum]
}
var checks:[String:[String:Int]]=[:]
for t in 0...2 {
    let before=image("before-observed-t\(t).png"), after=image("after-observed-t\(t).png"), clean=image("clean-t\(t).png")
    let cleanMatch=diff(after,clean,(85,170,230,300))
    precondition(cleanMatch["changedPixels"]==0)
    checks["cleanT\(t)"]=cleanMatch
    for (name,rect) in [("shared",(90,175,222,90)),("reference",(221,275,90,90)),("alphaSnapshot",(90,370,222,95))] {
        let same=diff(before,after,rect)
        precondition(same["changedPixels"]==0)
        checks["unchanged\(name)T\(t)"]=same
    }
    let pbr=diff(before,after,(90,270,94,100))
    if t==1 {precondition(pbr["changedPixels"]!>100)} else {precondition(pbr["changedPixels"]==0)}
    checks["pbrT\(t)"]=pbr
}
let defaultOld=NSBitmapImageRep(data:try! Data(contentsOf:URL(fileURLWithPath:"/private/tmp/dart3d-e5c-u4-runtime-20261027/ios-materials/final-t1.png")))!
let defaultNew=image("default-clean-t1.png")
let defaultMatch=diff(defaultOld,defaultNew,(90,175,222,290))
precondition(defaultMatch["changedPixels"]==0)
checks["defaultFixtureUnchanged"]=defaultMatch
let result:[String:Any] = ["comparisons":checks,"boundary":"Exact decoded PNG comparisons, not linear color calibration. Only the partial-alpha PBR sheen region changes; default fixture, zero/full endpoints and other faces remain identical."]
let data=try! JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
try! data.write(to:URL(fileURLWithPath:"\(root)/image-checks.json"))
print(String(data:data,encoding:.utf8)!)
