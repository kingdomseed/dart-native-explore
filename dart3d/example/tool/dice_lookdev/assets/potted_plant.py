"""Pilea-like kitchen plant with curved petioles and dished leaves in a glazed pot."""
import math
import random
import bpy
from mathutils import Vector
import env_common as E
from . import geometry as G, materials as M


def build(name="Kitchen plant",loc=(0,0,0),rot_z=0,height=32,radius=7,tone=(.13,.21,.028),
          pot_tone=(.28,.115,.05),wear=.4,seed=1,leaves=28) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed);r=radius;h=height
    ceramic=M.ceramic(name+" mottled pot",pot_tone,wear,seed)
    a.lathe("Hollow flowerpot",[(0,.4),(r*.68,.4),(r*.72,0),(r*.83,0),(r*.99,h*.33),(r,h*.37),(r*.9,h*.38),(r*.85,h*.35),(r*.65,1.2),(0,1.2)],ceramic)
    a.cylinder("Dark potting soil",r*.85,.25,(0,0,h*.32),E.simple(name+" soil",(.018,.012,.006),.95),bevel=0)
    leaf=M.foliage(name+" waxy leaf",tone,seed)
    stem=E.simple(name+" stems",tuple(c*.7 for c in tone),.57)
    for i in range(leaves):
        theta=i*2.39996;z=h*.43+(h*.50)*i/leaves
        reach=rng.uniform(.8,1.7)*r*(1-.4*i/leaves)
        center=Vector((math.cos(theta)*reach,math.sin(theta)*reach,z))
        a.tube("Curving leaf stalk",[(center.x*t*t,center.y*t*t,h*.31+(z-h*.31)*t) for t in [j/12 for j in range(13)]],.11,stem)
        rr=rng.uniform(2.2,3.6)*(h/32)
        tilt=rng.uniform(-.6,.8)
        verts=[tuple(center)]
        for ring in range(1,5):
            s=ring/4
            for j in range(32):
                t=j*math.tau/32
                verts.append(tuple(center+Vector((rr*s*math.cos(t),rr*.85*s*math.sin(t),rr*(tilt*s*math.cos(t-theta)+.22*s*s+.035*math.sin(t*7)*s*s)))))
        faces=[(0,j+1,(j+1)%32+1) for j in range(32)]
        faces += [(1+i*32+j,1+i*32+(j+1)%32,1+(i+1)*32+(j+1)%32,1+(i+1)*32+j) for i in range(3) for j in range(32)]
        a.mesh("Dished round leaf",verts,faces,leaf,smooth=True)
    return a.root
