"""Closed brilliant and emerald cuts, with planar crown and pavilion facets."""
import math
import random
import env_common as E
import bpy
from . import geometry as G, materials as M


def build(name="Cut gemstone", loc=(0,0,0), rot_z=0, radius=1.25,
          cut="brilliant", tone=(.025,.46,.19), wear=.1, seed=1, ior=1.78, glints=0) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    mat=M.cut_stone(name+" optical crystal",tone,wear,seed,ior)
    if cut=="emerald":
        outline=[(-.65,-1),(.65,-1),(1,-.65),(1,.65),(.65,1),(-.65,1),(-1,.65),(-1,-.65)]
        levels=[(.06,.02),(.72,.48),(1,.75),(1,.80),(.72,1.12),(.57,1.18)]
        verts=[(x*radius*r,y*radius*r*.78,z*radius) for r,z in levels for x,y in outline]
        faces=[tuple(reversed(range(8))),tuple(range(40,48))]
        faces += [(8*j+i,8*j+(i+1)%8,8*(j+1)+(i+1)%8,8*(j+1)+i) for j in range(5) for i in range(8)]
    else:
        levels=[(.025,.02),(.72,.40),(1,.80),(1,.84),(.73,1.10),(.48,1.25)]
        verts=[]
        for j,(r,z) in enumerate(levels):
            for i in range(16):
                t=math.tau*i/16
                verts.append((radius*r*math.cos(t),radius*r*math.sin(t),radius*z))
        faces=[tuple(reversed(range(16))),tuple(range(80,96))]
        for j in range(5):
            for i in range(16):
                v0,v1=j*16+i,j*16+(i+1)%16
                v2,v3=(j+1)*16+(i+1)%16,(j+1)*16+i
                if j in (0,2,3): faces.extend([(v0,v1,v2),(v0,v2,v3)])
                else: faces.append((v0,v1,v2,v3))
    if cut in {"oval","pear","cushion"}:
        if cut=="oval":verts=[(x*.78,y*1.16,z) for x,y,z in verts]
        elif cut=="pear":verts=[(x*(.70-.26*y/radius),y*1.18,z) for x,y,z in verts]
        else:verts=[(math.copysign(abs(x/radius)**.65,x)*radius*.85,math.copysign(abs(y/radius)**.65,y)*radius*.85,z) for x,y,z in verts]
    a.mesh("Polished optical facets",verts,faces,mat)
    rng=random.Random(seed)
    for i in range(glints):
        j=rng.randrange(len(verts)//6*4,len(verts))
        x,y,z=verts[j];w=radius*rng.uniform(.012,.025)
        color=((.56,.82,1),(1,.72,.36),(.90,.98,1))[i%3]
        sparkle=E.emissive(name+f" refracted glint {i}",color,1.5)
        a.mesh("Tiny facet caustic",[(x-w,y,z+.004),(x,y-w,z+.004),(x+w,y,z+.004),(x,y+w,z+.004)],[(0,1,2,3)],sparkle)
    return a.root
