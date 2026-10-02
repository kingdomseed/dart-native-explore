"""Fine raised petal-and-branch appliques on flat or curved lacquer surfaces."""
import math
import random
import bpy
from . import geometry as G, materials as M


def sprig(a, surface, width, height, mat, seed=1, flowers=7, relief=.012):
    rng=random.Random(seed)
    def stem(t):return (-width*.43+width*.86*t,height*(.34+.17*math.sin(t*5)))
    a.tube("Fine gold branch",[surface(*stem(i/60),relief) for i in range(61)],max(.009,height*.008),mat,resolution=1)
    verts=[];faces=[]
    for j in range(flowers):
        t=(j+.5)/flowers;u,v=stem(t)
        side=1 if j%2 else -1
        cu=u+rng.uniform(-.025,.025)*width;cv=v+side*height*.23
        a.tube("Tapering blossom twig",[surface(u,v,relief),surface((u+cu)/2,(v+cv)/2,relief),surface(cu,cv,relief)],max(.006,height*.005),mat,resolution=1)
        r=height*rng.uniform(.11,.15);phase=rng.random()*math.tau
        for p in range(5):
            angle=phase+p*math.tau/5;base=len(verts)
            verts.append(surface(cu,cv,relief))
            for k in range(13):
                q=math.tau*k/12
                along=r*(.56+.44*math.cos(q));across=r*.32*math.sin(q)
                verts.append(surface(cu+along*math.cos(angle)-across*math.sin(angle),cv+along*math.sin(angle)+across*math.cos(angle),relief))
            faces.extend((base,base+k+1,base+k+2) for k in range(12))
        a.sphere("Pollen centre",r*.09,surface(cu,cv,relief*1.5),mat,subdiv=1)
    a.mesh("Five lobed gold flowers",verts,faces,mat)


def build(name="Maki-e blossom branch",loc=(0,0,0),rot_z=0,width=22,height=2,
          radius=0,flowers=11,metal_finish="brass",wear=.2,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    mat=M.metal(name+" fine gold leaf",metal_finish,wear,seed)
    def surface(u,v,d):
        if radius:
            angle=u/radius
            return ((radius+d)*math.sin(angle),-(radius+d)*math.cos(angle),v)
        return (u,-d,v)
    sprig(a,surface,width,height,mat,seed,flowers)
    return a.root
