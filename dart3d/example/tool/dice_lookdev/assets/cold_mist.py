"""Low transparent mist layers with sparse airborne ice motes, without volumes."""
import random
import bpy
import env_common as E
from . import geometry as G, materials as M
from .night_vista import cloud


def build(name="Cold mist",loc=(0,0,0),rot_z=0,width=260,depth=100,height=35,layers=4,
          opacity=.30,tone=(.28,.40,.55),flakes=0,flake_height=100,wear=0,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    for j in range(layers):
        mat=M.cold_mist(name+f" layer {j}",tone,opacity,seed+j)
        cloud(a,"Drifting cold mist",(rng.uniform(-width*.1,width*.1),j*depth/max(1,layers-1),height*.5),
              width,height*rng.uniform(.7,1.2),mat,seed+j)
    snow=E.simple(name+" airborne ice",(.72,.83,.92),.7,Emission_Color=(.4,.61,.82,1),Emission_Strength=.45)
    for j in range(flakes):
        a.sphere("Sparse falling ice mote",rng.uniform(.045,.10),
                 (rng.uniform(-width*.25,width*.25),rng.uniform(0,depth),rng.uniform(height,flake_height)),snow,subdiv=1)
    return a.root
