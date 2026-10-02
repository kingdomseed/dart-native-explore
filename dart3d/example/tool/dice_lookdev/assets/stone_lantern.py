"""Carved garden lantern with a hollow fire chamber and swept square roof."""
import math
import bpy
from . import geometry as G, materials as M
import env_common as E


def build(name="Garden stone lantern",loc=(0,0,0),rot_z=0,height=75,radius=17,
          tone=(.12,.14,.12),energy=700,wear=.6,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);stone=M.stone(name+" weathered granite",tone,wear,seed)
    a.lathe("Moulded hexagonal foot",[(0,0),(radius*.66,0),(radius*.78,height*.025),(radius*.72,height*.07),(radius*.44,height*.11),(radius*.28,height*.13)],stone,segments=6)
    a.lathe("Entasis lantern stem",[(radius*.28,height*.12),(radius*.25,height*.18),(radius*.23,height*.39),(radius*.29,height*.47),(radius*.56,height*.49),(radius*.66,height*.53)],stone,segments=8)
    floor=height*.54;roof=height*.77;r=radius*.43
    a.block("Chamber sill",(r*2.5,r*2.5,height*.045),(0,0,floor),stone,.5)
    for x in (-r,r):
        for y in (-r,r):a.block("Chamfered chamber pier",(radius*.18,radius*.18,roof-floor),(x,y,(roof+floor)/2),stone,.4)
    for side in (-1,1):
        a.block("Chamber side panel",(.6,r*2,roof-floor),(side*r,0,(roof+floor)/2),stone,.15)
    ember=E.emissive(name+" sheltered flame",(1,.33,.045),3)
    a.sphere("Amber flame",1.4,(0,0,floor+height*.075),ember,scale=(.5,.5,2),subdiv=2)
    a.light("Sheltered amber pool",(0,-r*.8,floor+height*.07),energy,(1,.46,.12),2)
    levels=[(1,roof),(.97,roof+height*.04),(.66,roof+height*.095),(.27,roof+height*.14)]
    verts=[]
    for size,z in levels:
        for i in range(40):
            t=math.tau*i/40;d=max(abs(math.cos(t)),abs(math.sin(t)))
            x=radius*size*math.cos(t)/d;y=radius*size*math.sin(t)/d
            corner=(min(abs(x),abs(y))/(radius*size))**5
            verts.append((x,y,z+corner*height*.04*size))
    a.mesh("Swept carved roof",verts,[(j*40+i,j*40+(i+1)%40,(j+1)*40+(i+1)%40,(j+1)*40+i) for j in range(3) for i in range(40)],stone,bevel=.3)
    a.lathe("Lotus roof finial",[(0,height*.90),(radius*.23,height*.90),(radius*.16,height*.94),(radius*.20,height*.965),(0,height)],stone,segments=24)
    return a.root
