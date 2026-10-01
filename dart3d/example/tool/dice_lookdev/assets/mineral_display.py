"""A rough crystalline specimen on a padded, turned brass assay stand."""
import math
import random
import bpy
from . import geometry as G,materials as M


def build(name="Rough emerald display",loc=(0,0,0),rot_z=0,radius=4,height=7,
          tone=(.018,.33,.14),metal_finish="brass",wear=.5,seed=3) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    brass=M.machined_metal(name+" stand",metal_finish,wear,seed)
    velvet=M.velvet(name+" velvet pad",(.015,.011,.025),seed=seed)
    h=height*.42
    a.lathe("Turned specimen pedestal",[(0,0),(radius*.7,0),(radius*.8,.35),(radius*.76,.65),(radius*.5,.9),
         (radius*.22,1.2),(radius*.19,h*.65),(radius*.35,h*.83),(radius*.88,h),(radius,h+.3),(radius*.98,h+.5),
         (radius*.9,h+.32),(radius*.4,h+.25),(0,h+.25)],brass,segments=64)
    a.sphere("Soft oval velvet cushion",radius*.85,(0,0,h+.36),velvet,scale=(1,.86,.16),subdiv=3)
    crystal=M.rough_mineral(name+" rough beryl",tone,wear,seed)
    matrix=M.stone(name+" dark schist matrix",(.06,.07,.063),.7,seed)
    for i in range(7):
        r=radius*(.62 if i==0 else rng.uniform(.16,.32));hh=(height-h)*(1 if i==0 else rng.uniform(.25,.55))
        x=0 if i==0 else rng.uniform(-radius*.64,radius*.64);y=0 if i==0 else rng.uniform(-radius*.54,radius*.54)
        verts=[]
        for row,(rr,z) in enumerate(((.78,0),(1,hh*.33),(.86,hh*.81),(.31,hh))):
            for j in range(7):
                t=j*math.tau/7;rrr=r*rr*rng.uniform(.85,1.12)
                verts.append((x+rrr*math.cos(t),y+rrr*math.sin(t),h+.7+z+rng.uniform(-.10,.10)))
        faces=[tuple(reversed(range(7))),tuple(range(21,28))]
        for j in range(3):
            for k in range(7):
                q=j*7+k;n=j*7+(k+1)%7;faces.extend([(q,n,n+7),(q,n+7,q+7)])
        a.mesh("Fractured raw beryl crystal" if i<5 else "Schist matrix flake",verts,faces,crystal if i<5 else matrix)
    return a.root
