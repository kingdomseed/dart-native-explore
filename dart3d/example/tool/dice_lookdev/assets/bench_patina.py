"""Lapidary bench scars, oil spots and curled metal filings away from the play area."""
import math
import random
import bpy
import env_common as E
from . import geometry as G,materials as M


def build(name="Jeweler bench patina",loc=(0,0,0),rot_z=0,width=110,depth=70,
          quiet=(29,22),wear=.8,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    cut=M.oak(name+" exposed cuts",(.17,.074,.031),wear,seed)
    grime=M.leather(name+" ingrained dust",(.026,.015,.007),seed=seed)
    brass=M.polished_metal(name+" gold filings",(.58,.31,.07),wear,seed)
    oil=M.workbench_stain(name+" polishing oil",seed=seed)
    def allowed(x,y,margin=0):return abs(x)>quiet[0]+margin or abs(y)>quiet[1]+margin
    for i in range(200):
        x=rng.uniform(-width/2,width/2);y=rng.uniform(-depth/2,depth/2)
        if not allowed(x,y,3):continue
        length=rng.uniform(.7,5.5);ang=rng.uniform(-1.2,1.2)
        dx=math.cos(ang)*length;dy=math.sin(ang)*length
        a.tube("Dark scored grain",[(x,y,.022),(x+dx,y+dy,.022)],rng.uniform(.012,.032),grime,resolution=1)
        a.tube("Worn score edge",[(x+.035,y+.035,.024),(x+dx,y+dy+.035,.024)],.012,cut,resolution=1)
    for cx,cy in ((-22,29),(25,29)):
        for i in range(35):
            x=cx+rng.uniform(-5,5);y=cy+rng.uniform(-1,3)
            length=rng.uniform(.6,3.0);ang=rng.uniform(-1.0,1.0)
            if not allowed(x,y,2):continue
            end=(x+math.cos(ang)*length,y+math.sin(ang)*length,.025)
            a.tube("Burnished graver score",[(x,y,.025),end],.025,cut,resolution=1)
    for x,y,r in ((-37,16,7),(34,24,8),(-21,30,5),(14,29,6),(-40,-6,7)):
        r=min(r,max(abs(x)-quiet[0],abs(y)-quiet[1])/1.4)
        if r<=0:continue
        ob=a.add(E.plane("Soft polishing-oil stain",r*2,r*1.4,(x,y,.007),oil));ob.rotation_euler.z=rng.uniform(-.5,.5)
    for cx,cy in ((-31,25),(32,28),(-38,6),(36,8)):
        for i in range(45):
            x=cx+rng.gauss(0,2.7);y=cy+rng.gauss(0,2.1)
            if not allowed(x,y,.2):continue
            r=rng.uniform(.025,.12);ang=rng.uniform(0,math.tau)
            pts=[(x+r*math.cos(ang+j*.35),y+r*math.sin(ang+j*.35),.026+j*.006) for j in range(5)]
            a.tube("Curled metal shaving",pts,.012,brass if i%3 else grime,resolution=1)
    return a.root
