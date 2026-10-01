"""Tailored velvet runner folding over a table edge, with stitched star embroidery."""
import math
import random
import bpy
from . import geometry as G, materials as M


def build(name="Astronomer velvet",loc=(0,0,0),rot_z=0,width=25,length=38,drop=16,
          tone=(.045,.008,.075),wear=.35,seed=1,stars=9,sheen_tone=(.16,.025,.26),stitch_width=.033) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z); rng=random.Random(seed)
    velvet=M.velvet(name+" velvet",tone,wear,seed,sheen_tone=sheen_tone)
    gold=M.polished_metal(name+" gold thread",(.54,.34,.105),.3,seed,.36)
    def point(u,v):
        x=u*width/2; y=(v-.5)*length
        fall=max(0,.20-v)/.20
        z=.22+.30*math.sin(u*10+v*5)+.17*math.sin(u*19-v*4)
        if fall:
            y=-length*.30-math.sin(fall*math.pi/2)*1.2
            z-=drop*(1-math.cos(fall*math.pi/2))
            x+=.7*math.sin(v*15+u*7)*fall
        return (x,y,z)
    nu,nv=56,76
    verts=[point(-1+2*i/nu,j/nv) for j in range(nv+1) for i in range(nu+1)]
    faces=[(j*(nu+1)+i,j*(nu+1)+i+1,(j+1)*(nu+1)+i+1,(j+1)*(nu+1)+i) for j in range(nv) for i in range(nu)]
    ob=a.mesh("Draped velvet folds",verts,faces,velvet,smooth=True)
    mod=ob.modifiers.new("Woven fabric thickness","SOLIDIFY");mod.thickness=.06
    for u in (-.93,.93):
        a.tube("Gold sewn selvedge",[(x,y,z+.065) for x,y,z in (point(u,j/100) for j in range(101))],.025,gold)
    for i in range(stars):
        u=rng.uniform(-.74,.74); v=rng.uniform(.32,.86); rr=rng.uniform(.6,1.4)
        pts=[]
        for j in range(16):
            t=j*math.tau/16; r=rr if j%2==0 else rr*.21
            x,y,z=point(u+2*r*math.cos(t)/width,v+r*math.sin(t)/length)
            pts.append((x,y,z+.08))
        a.tube("Eight-point gold star embroidery",pts,stitch_width,gold,cyclic=True)
    return a.root
