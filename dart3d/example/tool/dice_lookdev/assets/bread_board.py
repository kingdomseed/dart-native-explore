"""Hand-shaped scored loaf on a rounded wooden trencher, with scattered crumbs."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M


def build(name="Bread trencher",loc=(0,0,0),rot_z=0,width=25,depth=16,loaf_height=8,
          wood_tone=(.13,.065,.023),wear=.7,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    wood=M.oak(name+" cut board",wood_tone,wear,seed,grain_scale=2)
    crust=M.bread_crust(name+" browned crust",seed)
    crumb=E.simple(name+" pale open crumb",(.46,.29,.12),.85,Subsurface_Weight=.04)
    a.block("Rounded oak trencher",(width,depth,1.5),(0,0,.75),wood,.35)
    a.block("Trencher handle",(8,5,1.5),(width/2+3,0,.75),wood,.35)
    for i in range(12):
        x=rng.uniform(-width*.42,width*.4);y=rng.uniform(-depth*.4,depth*.4)
        a.tube("Knife mark",[(x,y,1.505),(x+rng.uniform(1,4),y+.2,1.505)],.012,wood,resolution=1)
    nr=80;nt=192;verts=[];score=[]
    for j in range(nr+1):
        r=j/nr
        for i in range(nt):
            t=i*math.tau/nt
            x=width*.39*r*math.cos(t);y=depth*.36*r*math.sin(t)
            z=1.52+loaf_height*max(0,1-r*r)**.63
            dist=min(abs(x+.5*y+.13*math.sin(y*2)-s) for s in (-width*.20,0,width*.20))
            cut=math.exp(-(dist/.44)**2)*max(0,1-(r/.88)**8)
            z-=.7*cut
            z+=.16*math.sin(x*1.2+y*.7)*math.sin(y*1.7)*r
            verts.append((x,y,z));score.append(cut)
    faces=[(j*nt+i,j*nt+(i+1)%nt,(j+1)*nt+(i+1)%nt,(j+1)*nt+i) for j in range(nr) for i in range(nt)]
    faces.append(tuple(reversed(range(nr*nt,(nr+1)*nt))))
    loaf=a.mesh("Hand-shaped scored country loaf",verts,faces,crust,smooth=True);cuts=loaf.data.attributes.new("Bread scoring","FLOAT","POINT")
    for datum,value in zip(cuts.data,score):datum.value=value
    for i in range(14):
        x=rng.uniform(-width*.46,width*.46);y=rng.choice((-1,1))*rng.uniform(depth*.38,depth*.44)
        a.sphere("Bread crumb",rng.uniform(.09,.25),(x,y,1.58),crumb,scale=(1,.7,.55),subdiv=1)
    return a.root
