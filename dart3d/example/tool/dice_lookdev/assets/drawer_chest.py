"""Joinered specimen chest with recessed drawer fronts and turned brass pulls."""
import math
import random
import bpy
from . import geometry as G, materials as M


def build(name="Specimen drawer chest",loc=(0,0,0),rot_z=0,width=54,depth=26,height=49,
          columns=3,rows=5,wood_tone=(.13,.044,.017),metal_finish="brass",wear=.6,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    wood=M.oak(name+" carcass",wood_tone,wear,seed,axis="Z")
    brass=M.machined_metal(name+" pulls",metal_finish,wear,seed)
    dark=M.leather(name+" recessed joints",(.007,.004,.002),seed=seed)
    for x in (-width/2+1,width/2-1):a.block("Joined chest side",(2,depth,height-3),(x,0,height/2),wood,.32)
    a.block("Recessed chest back",(width-3,1.2,height-4),(0,depth/2-.7,height/2),wood,.2)
    for z in (1.1,height-1.1):
        a.block("Projecting moulded cornice",(width+3,depth+2,2.2),(0,-.2,z),wood,.45)
        a.block("Cornice beading",(width+2.2,1,1),(0,-depth/2-1,z),brass,.28)
    a.block("Drawer shadow interiors",(width-3,1,height-4),(0,-depth/2+1.8,height/2),dark,.1)
    cw=(width-4)/columns;rh=(height-5)/rows
    for col in range(columns):
        for row in range(rows):
            x=-width/2+2+cw*(col+.5);z=2.5+rh*(row+.5)
            tone=tuple(c*rng.uniform(.78,1.2) for c in wood_tone)
            face=M.oak(name+f" drawer {col} {row}",tone,wear,seed+col*rows+row)
            a.block("Separate inset drawer",(cw-.38,1.45,rh-.34),(x,-depth/2+.55,z),face,.22)
            for zz in (z-rh*.36,z+rh*.36):a.block("Drawer edge moulding",(cw-1.3,.24,.23),(x,-depth/2-.3,zz),face,.1)
            disk=a.cylinder("Pull escutcheon",.83,.16,(x,-depth/2-.32,z),brass);disk.rotation_euler.x=math.pi/2
            neck=a.cylinder("Turned pull neck",.22,.85,(x,-depth/2-.73,z),brass);neck.rotation_euler.x=math.pi/2
            a.sphere("Rounded brass knob",.58,(x,-depth/2-1.2,z),brass,scale=(1,.65,1))
    for sx in (-1,1):
        a.block("Side inset raised panel",(.65,depth-5,height-10),(sx*(width/2+.08),0,height/2),wood,.7)
        for y in (-depth/2+4,depth/2-4):a.cylinder("Bun foot",2,1.4,(sx*(width/2-4),y,.7),wood,bevel=.3)
    return a.root
