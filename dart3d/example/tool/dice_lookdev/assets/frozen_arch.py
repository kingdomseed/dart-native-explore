"""Open dressed-stone arch with moulded archivolts on frost-rimed carved piers."""
import math
import bpy
from . import geometry as G, materials as M, frost_pillar


def build(name="Frozen sanctuary arch",loc=(0,0,0),rot_z=0,width=150,shoulder=145,
          radius=11,depth=25,tone=(.16,.19,.24),frost=.85,wear=.6,seed=2) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    mat=M.frozen_stone(name+" voussoirs",tone,frost,wear,seed)
    for sign in (-1,1):
        a.add(frost_pillar.build(name+" pier",loc=(sign*width/2,0,0),height=shoulder,
                                radius=radius,tone=tone,frost=frost,wear=wear,seed=seed))
    r=width/2
    for j in range(23):
        G.arch_block(a,"Carved arch voussoir",r-radius*.45,r+radius*1.0,
                     math.pi*j/23+.002,math.pi*(j+1)/23-.002,depth,(0,0,shoulder),mat,.6)
    for rr,thick in ((r-radius*.38,.7),(r+radius*.35,.6),(r+radius*.93,.9)):
        a.tube("Stone archivolt",[(rr*math.cos(i*math.pi/96),-depth/2-.2,
                                  shoulder+rr*math.sin(i*math.pi/96)) for i in range(97)],thick,mat)
    return a.root
