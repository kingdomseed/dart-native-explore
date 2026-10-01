"""Dried lavender with branching stems and whorled buds, in a jug or tied bundle."""
import math
import random
import bpy
from mathutils import Vector
import env_common as E
from . import geometry as G, materials as M, vessel


def build(name="Dried lavender",loc=(0,0,0),rot_z=0,kind="jug",height=36,radius=6,
          stems=21,tone=(.19,.085,.26),jug_tone=(.25,.18,.10),wear=.5,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    jh=height*.48
    if kind=="jug":
        a.add(vessel.build(name+" jug",kind="jug",height=jh,radius=radius,tone=jug_tone,wear=wear,seed=seed))
    stem=E.simple(name+" dry stalk",(.085,.10,.029),.82)
    petals=[E.simple(name+f" papery calyx {i}",tuple(c*f for c in tone),.82,Sheen_Weight=.22) for i,f in enumerate((.4,.75,1,1.4))]
    bud_verts=[[] for _ in petals];bud_faces=[[] for _ in petals]
    def bud(pos,r,mi):
        v=bud_verts[mi];f=bud_faces[mi];base=len(v)
        for x,y,z in ((0,0,1.4),(0,0,-1.2),(1,0,0),(0,1,0),(-1,0,0),(0,-1,0)):
            v.append(tuple(pos+Vector((x*r,y*r,z*r))))
        f.extend(tuple(base+i for i in q) for q in ((0,2,3),(0,3,4),(0,4,5),(0,5,2),(1,3,2),(1,4,3),(1,5,4),(1,2,5)))
    for i in range(stems):
        th=rng.uniform(0,math.tau)
        spread=rng.uniform(1,4) if kind=="bundle" else rng.uniform(3,12)
        top=Vector((spread*math.cos(th),spread*math.sin(th),height*rng.uniform(.75,1.05)))
        start=Vector((rng.uniform(-1.7,1.7),rng.uniform(-1.7,1.7),jh*.30))
        mid=start.lerp(top,.56)+Vector((0,0,2))
        a.tube("Bent dry lavender stalk",[tuple(start),tuple(mid),tuple(top)],.065,stem,resolution=1)
        direction=(top-mid).normalized()
        for j in range(10):
            center=top-direction*(j*.53)
            for k in range(4):
                t=math.tau*k/4+j*.8
                pos=center+Vector((.29*math.cos(t),.29*math.sin(t),0))
                bud(pos,rng.uniform(.17,.26),rng.randrange(4))
        for side in (-1,1):
            p=mid+Vector((0,0,-rng.uniform(0,2)))
            tip=p+Vector((side*1.6,.3,3.2))
            a.mesh("Dry narrow leaf",[tuple(p),tuple(p.lerp(tip,.45)+Vector((.20,.1,0))),tuple(tip),tuple(p.lerp(tip,.45)-Vector((.20,.1,0)))],[(0,1,2,3)],stem)
    for i,mat in enumerate(petals): a.mesh("Lavender calyx whorls",bud_verts[i],bud_faces[i],mat,smooth=True)
    if kind=="bundle":
        cord=M.wool(name+" twine",(.26,.18,.065),seed)
        a.ring("Tied lavender bundle",1.8,.17,(0,0,jh*.55),cord)
        a.root.rotation_euler.x=math.pi/2
        a.root.scale.y=.2
    return a.root
