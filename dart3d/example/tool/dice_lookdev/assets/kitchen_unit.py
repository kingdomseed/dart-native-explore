"""Fitted enamel kitchen cabinet, cooker and two-door refrigerator; floor origin, front -Y."""
import math
import bpy
import env_common as E
from . import geometry as G, materials as M


def build(name="Kitchen unit",loc=(0,0,0),rot_z=0,kind="cabinet",width=60,depth=59,height=86,
          tone=(.55,.51,.39),wood_tone=(.19,.085,.025),wear=.35,seed=1,doors=2) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);w,d,h=width,depth,height
    cream=M.ceramic(name+" warm enamel",tone,wear,seed)
    dark=M.aged_plastic(name+" dark gasket",(.018,.017,.014),wear,seed)
    chrome=M.polished_metal(name+" hardware",(.47,.48,.45),wear,seed,.23)
    wood=M.wood_laminate(name+" worktop",wood_tone,wear,seed)
    def handle(x,z,length=11,vertical=False):
        offset=3 if kind=="fridge" else 0
        pts=[(x-length/2,-d/2-1-offset,z),(x-length/2,-d/2-3-offset,z),(x+length/2,-d/2-3-offset,z),(x+length/2,-d/2-1-offset,z)]
        if vertical:pts=[(x,p[1],z+p[0]-x) for p in pts]
        a.tube("Rounded cabinet pull",pts,.45,chrome,resolution=3)
    a.block("Recessed toe plinth",(w-5,d-7,7),(0,2,3.5),dark,.4)
    a.block("Enamel cabinet carcass",(w,d,h-7),(0,0,(h+7)/2),cream,.65 if kind!="fridge" else 1.8)
    if kind=="fridge":
        split=h*.70
        for lo,hi in ((8,split-1),(split+1,h-1)):
            a.block("Refrigerator door gasket",(w-1,1,hi-lo),(0,-d/2-.1,(lo+hi)/2),dark,.5)
            a.block("Rounded refrigerator door",(w-1.6,4,hi-lo-.6),(0,-d/2-1.8,(lo+hi)/2),cream,1.5)
        for z in (split-18,split+14):handle(-w*.35,z,18,True)
        for z in (16,split-6,split+8,h-10):a.block("Exposed hinge",(2.2,4,3),(w*.47,-d/2-1,z),chrome,.6)
    elif kind=="cooker":
        blackglass=E.simple(name+" oven glass",(.014,.018,.018),.16,Coat_Weight=.8)
        a.block("Oven gasket",(w-5,1,h*.67),(0,-d/2-.3,h*.42),dark,.8)
        a.block("Oven enamel door",(w-6,2.5,h*.64),(0,-d/2-1,h*.42),cream,1.2)
        a.block("Oven viewing window",(w*.70,.4,h*.40),(0,-d/2-2.4,h*.41),blackglass,1.9)
        a.tube("Oven horizontal bar handle",[(-w*.36,-d/2-2,h*.71),(-w*.36,-d/2-5,h*.71),(w*.36,-d/2-5,h*.71),(w*.36,-d/2-2,h*.71)],.8,chrome)
        for i in range(5):
            x=(i-2)*w*.17;z=h*.89
            ob=a.cylinder("Cooker control dial",2.5,1.7,(x,-d/2-1.5,z),dark,segments=32,bevel=.3);ob.rotation_euler.x=math.pi/2
            a.block("Dial index",(.14,.07,.9),(x,-d/2-2.4,z+1.3),cream,.03)
            for j in range(7):
                t=-.8+j*.28
                a.sphere("Dial tick",.10,(x+3.2*math.sin(t),-d/2-.69,z+3.2*math.cos(t)),chrome,scale=(1,.2,1))
        a.block("Cooker pressed hob",(w+1,d+1,1.8),(0,0,h+.6),cream,.7)
        for x in (-w*.25,w*.25):
            for y in (-d*.25,d*.25):
                a.cylinder("Cast iron hotplate",8,1.1,(x,y,h+1.7),dark,segments=48,bevel=.2)
                for radius in (3,4,5,6,7):a.ring("Hotplate coil",radius,.13,(x,y,h+2.28),chrome)
        a.block("Raised enamel splash lip",(w,2,6),(0,d/2,h+3),cream,.6)
    else:
        a.block("Laminate work surface",(w+2,d+3,3),(0,-.7,h+.8),wood,.8)
        drawer_h=14
        for i in range(doors):
            dw=(w-3)/doors;x=-w/2+1.5+(i+.5)*dw
            a.block("Inset door shadow gap",(dw-.6,1,h-25),(x,-d/2-.2,(h-25)/2+8),dark,.15)
            a.block("Raised panel cabinet door",(dw-1.2,2,h-26),(x,-d/2-1,(h-26)/2+8),cream,.65)
            a.block("Framed door field",(dw-6,.6,h-33),(x,-d/2-2.2,(h-26)/2+8),cream,.8)
            a.block("Cutlery drawer",(dw-1.2,2,drawer_h),(x,-d/2-1,h-9),cream,.7)
            handle(x,h-9,9);handle(x,h-30,9)
    return a.root
