"""Crooked ash walking staff with carved rings, leather hand binding and an iron shoe."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Walking staff",loc=(0,0,0),rot_z=0,height=160,radius=1.7,
          wood_tone=(.10,.041,.012),metal_finish="iron",wear=.8,seed=1,carved_bands=3) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    wood=M.oak(name+" ash grain",wood_tone,wear,seed,axis="Z",grain_scale=1.6)
    hide=M.leather(name+" worn grip",(.065,.025,.010),wear,seed)
    iron=M.metal(name+" iron shoe",metal_finish,wear,seed)
    n=64;verts=[]
    def center(t):return (1.9*math.sin(t*4)*t,1.3*math.sin(t*7)*t,height*t)
    for j in range(n+1):
        t=j/n;x,y,z=center(t);rr=radius*(.72+.25*t+.10*math.sin(t*19)**2)
        if t>.91:rr*=1+.65*math.sin((t-.91)/.09*math.pi)
        for i in range(16):
            th=i*math.tau/16;r=rr*(1+.05*math.sin(th*5+t*37))
            verts.append((x+r*math.cos(th),y+r*math.sin(th),z))
    faces=[(j*16+i,j*16+(i+1)%16,(j+1)*16+(i+1)%16,(j+1)*16+i) for j in range(n) for i in range(16)]
    faces.extend([tuple(reversed(range(16))),tuple(range(n*16,(n+1)*16))])
    a.mesh("Irregular ash shaft",verts,faces,wood,smooth=True)
    a.lathe("Forged iron ferrule",[(0,0),(radius*.84,0),(radius*.89,1),(radius*.86,6),(radius*.72,6)],iron)
    for i in range(18):
        t=.74+i*.008;x,y,z=center(t)
        a.ring("Spiral leather grip",radius*1.05,.23,(x,y,z),hide)
    for t in (.72,.735,.895,.91):
        x,y,z=center(t);a.ring("Carved grip bead",radius*1.16,.25,(x,y,z),wood)
    for i in range(carved_bands):
        t=.29+i*.17
        x,y,z=center(t)
        for dz in (-1.6,-.8,.8,1.6):
            a.ring("Turned staff ornament",radius*1.04,.20,(x,y,z+dz),wood)
        for j in range(2):
            pts=[]
            for k in range(65):
                th=k*math.tau/32+j*math.pi
                pts.append((x+radius*1.04*math.cos(th),y+radius*1.04*math.sin(th),z-3+k*6/64))
            a.tube("Leather staff cross-binding",pts,.13,hide,resolution=1)
    x,y,z=center(.885)
    a.tube("Leather wrist loop",[(x,y,z),(x+5,y+1,z-6),(x+6,y+1,z-13),(x+2,y,z-15),(x,y,z-9),(x,y,z)],.25,hide)
    return a.root
