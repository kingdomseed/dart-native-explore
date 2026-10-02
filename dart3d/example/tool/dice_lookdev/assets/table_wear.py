"""Low relief cup rings and rubbed scratches, with a configurable clear play area."""
import math
import random
import bpy
from . import geometry as G, materials as M


def build(name="Old tabletop wear",loc=(0,0,0),rot_z=0,width=110,depth=80,
          quiet=(33,25),wear=.6,wood_tone=(.09,.038,.012),seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    dark=M.leather(name+" ingrained water marks",(.018,.007,.002),wear,seed)
    grain=M.oak(name+" rubbed wood",wood_tone,wear,seed)
    def allowed(x,y,margin=0):return abs(x)>quiet[0]+margin or abs(y)>quiet[1]+margin
    for i in range(round(100*wear)):
        x=rng.uniform(-width/2+5,width/2-5);y=rng.uniform(-depth/2+4,depth/2-4)
        length=rng.uniform(.4,3.5);dy=rng.uniform(-.25,.25)
        if not allowed(x,y,4):continue
        a.tube("Worn oak scratch",[(x,y,.012),(x+length,y+dy,.012)],rng.uniform(.009,.025),grain,resolution=1)
    for x,y,r in ((0,33,4.1),(-39,10,4.5),(38,18,4.2)):
        if not allowed(x,y,r+1):continue
        verts=[];faces=[]
        for j in range(96):
            t=math.tau*j/96
            rr=r+.09*math.sin(7*t+seed)+.035*math.sin(17*t)
            w=rng.uniform(.07,.23)*wear
            for q in (-w,w):verts.append((x+(rr+q)*math.cos(t),y+(rr+q)*math.sin(t),.009))
            if j and rng.random()>.10:faces.append((2*j-2,2*j-1,2*j+1,2*j))
        a.mesh("Old broken cup ring",verts,faces,dark)
    return a.root
