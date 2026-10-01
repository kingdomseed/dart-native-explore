"""Stuffed square floor cushion with pinched corners, seam and central tuft."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Zabuton",loc=(0,0,0),rot_z=0,width=48,depth=48,height=7,
          tone=(.014,.025,.045),wear=.3,seed=1) -> bpy.types.Object:
    height*=1-.15*(wear-.3)
    a=G.Asset(name,loc,rot_z);cloth=M.woven_silk(name+" brocade",tuple(c*(1+.4*(wear-.3)) for c in tone),seed)
    verts=[];n=28
    for side in (-1,1):
        for j in range(n+1):
            v=-1+2*j/n
            for i in range(n+1):
                u=-1+2*i/n
                puff=(max(0,1-u*u)*max(0,1-v*v))**.35
                tuft=math.exp(-18*(u*u+v*v))*.22
                z=height/2+side*height*.47*(puff-tuft)
                verts.append((u*width/2*(1-.035*abs(v)**8),v*depth/2*(1-.035*abs(u)**8),z))
    lowest=min(p[2] for p in verts)
    verts=[(x,y,z-lowest) for x,y,z in verts]
    faces=[];size=(n+1)**2
    for s in range(2):
        for j in range(n):
            for i in range(n):
                b=s*size+j*(n+1)+i
                faces.append((b,b+1,b+n+2,b+n+1))
    border=list(range(n+1))+[j*(n+1)+n for j in range(1,n+1)]+[n*(n+1)+i for i in range(n-1,-1,-1)]+[j*(n+1) for j in range(n-1,0,-1)]
    for k,b in enumerate(border):
        c=border[(k+1)%len(border)];faces.append((b,c,c+size,b+size))
    a.mesh("Dished stuffed cushion",verts,faces,cloth,smooth=True)
    a.tube("Hand sewn cushion welt",[verts[b] for b in border],.11,cloth,cyclic=True)
    a.tube("Central tuft stitch",[(-.6,0,height*.84),(0,0,height*.76),(.6,0,height*.84)],.095,cloth)
    return a.root
