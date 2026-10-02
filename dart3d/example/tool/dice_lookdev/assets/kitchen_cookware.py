"""Spun stainless cooking pot and a wall rail with a skillet, ladle and slotted turner."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Kitchen cookware",loc=(0,0,0),rot_z=0,kind="pot",radius=10,height=16,
          width=50,wear=.5,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    steel=M.polished_metal(name+" brushed steel",(.44,.46,.45),wear,seed,.27)
    iron=M.metal(name+" seasoned iron","iron",wear,seed)
    grip=M.aged_plastic(name+" bakelite",(.022,.017,.011),wear,seed)
    if kind=="pot":
        r,h=radius,height
        a.lathe("Spun pot wall",[(0,0),(r*.85,0),(r,.9),(r,h-.7),(r*.98,h),(r-.4,h),(r-.4,1.3),(0,1.3)],steel)
        a.lathe("Domed fitted lid",[(0,h+2),(r*.8,h+1.4),(r,h+.3),(r*.98,h),(0,h+1.65)],steel)
        a.sphere("Lid knob",1.9,(0,0,h+3.1),grip,scale=(1,1,.7))
        for side in (-1,1):
            a.tube("Riveted pot handle",[(side*r,-3,h*.67),(side*(r+3),-3,h*.68),(side*(r+3),3,h*.68),(side*r,3,h*.67)],.8,grip,resolution=3)
            for y in (-3,3):a.sphere("Handle rivet",.4,(side*(r+.1),y,h*.67),steel)
    else:
        a.tube("Utensil rail",[(-width/2,0,height),(width/2,0,height)],.8,steel)
        for x in (-width/2,width/2):
            plate=a.cylinder("Rail wall plate",2,1,(x,2.5,height),steel)
            plate.rotation_euler.x=math.pi/2
            a.tube("Rail bracket",[(x,2.5,height),(x,0,height)],.6,steel)
        for i,x in enumerate((-width*.32,0,width*.32)):
            a.tube("Hanging S hook",[(x,0,height+1),(x,-2,height+1),(x,-2,height-2),(x,0,height-3)],.24,steel)
            a.ring("Utensil hanging eye",.8,.22,(x,-1,height-4),steel,plane="XZ")
            a.beam("Utensil grip",(x,-1,height-4),(x,-1,height-19),1.7,1.2,grip,.4)
            if i==0:
                pan=a.lathe("Hanging skillet",[(0,0),(7,0),(9,2),(9,3),(8.5,3),(6.7,.5),(0,.5)],iron)
                pan.location=(x,-1,height-27);pan.rotation_euler.x=math.pi/2
            elif i==1:
                a.tube("Ladle bent shank",[(x,-1,height-19),(x,-1,height-26),(x,-4,height-28)],.35,steel)
                a.lathe("Deep ladle cup",[(0,0),(2,1),(3.5,3),(3.4,3.3),(3.1,3),(1.7,1.3),(0,.4)],steel,loc=(x,-4,height-31))
            else:
                a.beam("Turner shank",(x,-1,height-19),(x,-1,height-24),.7,.4,steel,.1)
                for q in range(5):a.block("Turner slotted blade",(.7,.3,7),(x+(q-2)*1.1,-1,height-27),steel,.2)
                for z in (height-24,height-30):a.block("Turner blade edge",(5.5,.3,.7),(x,-1,z),steel,.2)
    return a.root
