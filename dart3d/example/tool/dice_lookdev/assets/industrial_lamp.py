"""A spun work shade with a protective bulb cage, collar rivets and real suspension."""
import math
import bpy
from . import geometry as G, materials as M, dome_pendant


def build(name="Caged industrial lamp",loc=(0,0,0),rot_z=0,radius=14,height=11,drop=60,
          metal_finish="brass",wear=.6,seed=1,energy=18000,color=(1,.66,.32)) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    tone={"brass":(.54,.32,.095),"copper":(.53,.22,.10),"iron":(.09,.095,.10),"steel":(.43,.47,.49)}[metal_finish]
    shade=dome_pendant.build(name+" shade",radius=radius,height=height,drop=drop,tone=tone,
                             wear=wear,seed=seed,energy=energy,color=color)
    a.add(shade)
    metal=M.machined_metal(name+" cage",metal_finish,wear,seed)
    for ob in shade.children_recursive:
        if ob.name.startswith(("Spun metal dome","Rolled shade lip","Cable socket")):
            ob.data.materials.clear();ob.data.materials.append(metal)
    for i in range(6):
        t=i*math.tau/6
        pts=[]
        for j in range(25):
            v=j/24;r=radius*.48*math.cos(v*math.pi/2);z=-radius*.92*math.sin(v*math.pi/2)
            pts.append((r*math.cos(t),r*math.sin(t),z))
        a.tube("Bowed bulb guard",pts,.16,metal)
    for z,r in ((-.12,radius*.48),(-radius*.52,radius*.39)):
        a.ring("Cage reinforcing hoop",r,.15,(0,0,z),metal,segments=48)
    a.sphere("Cage foot rivet",.36,(0,0,-radius*.92),metal)
    for i in range(12):
        t=i*math.tau/12
        a.sphere("Shade lip rivet",.19,(radius*.96*math.cos(t),radius*.96*math.sin(t),height*.12),metal,subdiv=1)
    return a.root
