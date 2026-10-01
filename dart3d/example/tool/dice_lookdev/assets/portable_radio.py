"""Portable cassette radio with woven speaker grille, tuning scale and folding handle."""
import math
import bpy
import env_common as E
from . import geometry as G, materials as M


def build(name="Cassette radio",loc=(0,0,0),rot_z=0,width=30,height=18,depth=9,
          tone=(.11,.055,.018),wear=.4,seed=1,antenna=32) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z); w,h,d=width,height,depth
    case=M.aged_plastic(name+" brown case",tone,wear,seed)
    black=M.aged_plastic(name+" black inserts",(.012,.014,.013),wear,seed)
    metal=M.polished_metal(name+" brushed aluminium",(.56,.52,.4),wear,seed,.25)
    for x in (-w*.34,w*.34): a.block("Rubber foot",(3,d*.7,.6),(x,0,.3),black,.2)
    a.block("Radiused cabinet",(w,d,h),(0,0,h/2+.6),case,.9)
    a.block("Front inset",(w-1,.4,h-1),(0,-d/2-.05,h/2+.6),black,.45)
    a.block("Speaker cloth",(w*.50,.15,h*.71),(-w*.20,-d/2-.33,h*.50),M.canvas(name+" speaker weave",(.03,.025,.015),wear,seed),.25)
    for i in range(31):
        x=-w*.45+i*w*.0164
        a.beam("Grille warp",(x,-d/2-.48,h*.145),(x,-d/2-.48,h*.855),.055,.07,metal,.02)
    for i in range(28):
        z=h*.145+i*h*.0263
        a.beam("Grille weft",(-w*.45,-d/2-.49,z),(w*.05,-d/2-.49,z),.04,.06,metal,.02)
    a.block("Cassette door rim",(w*.32,.3,h*.37),(w*.27,-d/2-.36,h*.50),metal,.4)
    a.block("Cassette smoked lid",(w*.29,.12,h*.32),(w*.27,-d/2-.56,h*.50),black,.3)
    for x in (w*.20,w*.33):
        wheel=a.cylinder("Tape reel",1.15,.09,(x,-d/2-.66,h*.50),metal,segments=24)
        wheel.rotation_euler.x=math.pi/2
        for j in range(6):
            t=j*math.tau/6
            a.sphere("Reel aperture",.19,(x+.65*math.cos(t),-d/2-.73,h*.5+.65*math.sin(t)),black,scale=(1,.2,1))
    a.block("Tuning scale inset",(w*.32,.22,1.7),(w*.27,-d/2-.48,h*.82),metal,.14)
    for i in range(31):
        a.block("Unnumbered tuner tick",(.045,.025,.48 if i%5 else .85),(w*.12+i*w*.01,-d/2-.61,h*.82),black,.01)
    a.block("Orange tuning needle",(.09,.035,1.22),(w*.29,-d/2-.66,h*.82),E.simple(name+" orange index",(.7,.19,.025),.45),.02)
    for x in (w*.16,w*.37):
        knob=a.cylinder("Knurled control",1.3,.65,(x,-d/2-.65,h*.16),metal,segments=48,bevel=.13)
        knob.rotation_euler.x=math.pi/2
        for i in range(32):
            t=i*math.tau/32
            a.tube("Knob knurl",[(x+1.26*math.cos(t),-d/2-.94,h*.16+1.26*math.sin(t)),(x+1.26*math.cos(t),-d/2-.44,h*.16+1.26*math.sin(t))],.025,black)
    for i in range(6): a.block("Cassette transport key",(1.55,2,.6),(w*.10+i*1.72,-1,h+.8),metal,.15)
    for x in (-w*.33,w*.33): a.cylinder("Handle hinge",.8,1.0,(x,0,h+.4),metal,bevel=.15)
    a.tube("Folding carry handle",[(-w*.33,0,h),(-w*.33,0,h+3.7),(-w*.28,0,h+4.3),(w*.28,0,h+4.3),(w*.33,0,h+3.7),(w*.33,0,h)],.65,black)
    if antenna:
        for i in range(3):
            a.tube("Telescoping aerial",[(w*.40+i*antenna*.09,1,h+i*antenna/3),(w*.40+(i+1)*antenna*.09,1,h+(i+1)*antenna/3)],.13-i*.027,metal)
    return a.root
