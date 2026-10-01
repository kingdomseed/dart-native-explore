"""Wheel-thrown breakfast plate, cut toast with porous crumb, melted butter and crumbs."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M
from .crt_terminal import rounded_rect


def build(name="Toast plate",loc=(0,0,0),rot_z=0,radius=10.5,tone=(.64,.57,.40),
          band_tone=(.10,.18,.055),wear=.3,seed=1,butter=True) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed);r=radius
    glaze=M.ceramic(name+" ironstone",tone,wear,seed)
    band=M.ceramic(name+" green glaze",band_tone,wear,seed)
    profile=[(0,.35),(r*.46,.35),(r*.49,0),(r*.60,0),(r*.62,.25),(r*.88,1.1),(r,1.65),
             (r,1.9),(r*.98,2.0),(r*.87,1.5),(r*.67,.85),(0,.85)]
    a.lathe("Hollow thrown plate",profile,glaze,segments=80)
    for rr,z in ((r*.94,1.88),(r*.89,1.67),(r*.68,.91)):a.ring("Painted plate rim",rr,.095,(0,0,z),band,segments=80)
    outline=rounded_rect(r*.98,r*.91,1.6,16)
    # Crown swelling and slight crust waviness break the sandwich-bread rectangle.
    outline=[(x*(1+.055*math.sin(i*.61)),y+.55*math.exp(-((x/r)**2)*18) if y>0 else y) for i,(x,y) in enumerate(outline)]
    crust=M.pastry(name+" dark baked crust",seed);crumb=M.toast_crumb(name+" cut face",seed)
    n=len(outline);z0=1.02
    verts=[(x*s,y*s,z) for s,z in ((1,z0),(1.01,z0+1.25),(.93,z0+1.42)) for x,y in outline]
    faces=[tuple(reversed(range(n)))]+[(i+j*n,(i+1)%n+j*n,(i+1)%n+(j+1)*n,i+(j+1)*n) for j in range(2) for i in range(n)]
    a.mesh("Craggy baked toast edge",verts,faces,crust,bevel=.12,smooth=True)
    a.mesh("Exposed porous toast face",[(x*.93,y*.93,z0+1.42+.04*math.sin(i*1.7)) for i,(x,y) in enumerate(outline)],[tuple(range(n))],crumb)
    if butter:
        butter_mat=E.simple(name+" warm butter",(.73,.48,.14),.26,Subsurface_Weight=.12,Coat_Weight=.28)
        pts=[(math.cos(t)*2.1*(1+.15*math.sin(5*t)),math.sin(t)*1.5,2.5) for t in [i*math.tau/48 for i in range(48)]]
        a.mesh("Melted butter puddle",[(0,0,2.57)]+pts,[(0,i+1,(i+1)%48+1) for i in range(48)],butter_mat,smooth=True)
        pat=a.block("Soft butter pat",(2.8,2,.36),(.4,.3,2.64),butter_mat,.16);pat.rotation_euler.z=.25
        for i in range(5):a.tube("Butter knife ridges",[(-.6+i*.35,-.4,2.84),(-.5+i*.35,.85,2.84)],.04,butter_mat)
    for i in range(35):
        t=rng.uniform(0,math.tau);rr=rng.uniform(r*.6,r*.83)
        a.sphere("Toast crumb",rng.uniform(.06,.14),(rr*math.cos(t),rr*math.sin(t),1.1),crumb,scale=(1,1,.6),subdiv=1)
    return a.root
