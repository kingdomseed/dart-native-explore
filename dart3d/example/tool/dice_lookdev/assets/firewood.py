"""Irregular log section with bark, sawn ends and optional glowing char fissures."""
import math
import random
import bpy
from . import geometry as G, materials as M


def build(name="Firewood log",loc=(0,0,0),rot_z=0,length=46,radius=4.5,
          tone=(.12,.055,.022),wear=.8,heat=0,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    rng=random.Random(seed)
    bark=M.charred_wood(name+" char",heat,seed) if heat else M.bark(name+" bark",tone,wear,seed)
    end=M.charred_wood(name+" char end",heat*.5,seed+1) if heat else M.end_grain(name+" sawn ends",tone,wear,seed)
    n=32;rings=9
    profile=[rng.uniform(.87,1.12) for _ in range(n)]
    verts=[]
    for j in range(rings):
        t=j/(rings-1)
        for i in range(n):
            th=math.tau*i/n
            r=radius*profile[i]*(1-.12*t+.025*math.sin(t*10+i))
            verts.append((r*math.cos(th),r*math.sin(th),length*(t-.5)))
    faces=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(rings-1) for i in range(n)]
    ob=a.mesh("Split ridged bark",verts,faces,bark,smooth=True)
    ob.rotation_euler.y=math.pi/2;ob.location.z=radius
    for j in (0,rings-1):
        vs=[(0,0,length*(j/(rings-1)-.5))]+verts[j*n:(j+1)*n]
        fs=[(0,i+1,(i+1)%n+1) for i in range(n)]
        cap=a.mesh("Sawn log end",vs,fs,end)
        cap.rotation_euler.y=math.pi/2;cap.location.z=radius
    return a.root
