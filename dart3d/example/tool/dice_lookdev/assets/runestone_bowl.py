"""Repousse brass basin containing faceted stones with geometric luminous inlays."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M


def build(name="Runestone bowl",loc=(0,0,0),rot_z=0,radius=8,height=4.8,count=11,
          tone=(.009,.035,.17),metal_finish="brass",wear=.4,seed=3,energy=180) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z); rng=random.Random(seed); r=radius; h=height
    metal=M.metal(name+" aged basin",metal_finish,wear,seed)
    bright=M.polished_metal(name+" rubbed relief",(.55,.31,.085),wear,seed,.24)
    a.lathe("Repousse basin",[(0,0),(r*.45,0),(r*.51,.35),(r*.44,.8),(r*.48,1.3),
        (r*.70,h*.45),(r*.92,h*.76),(r,h),(r*.97,h+.2),(r*.93,h),
        (r*.85,h*.74),(r*.62,h*.42),(r*.3,1.05),(0,1.05)],metal,segments=64)
    for z,rr in ((.3,r*.49),(h*.79,r*.93),(h,r*.982)):
        a.ring("Raised bowl moulding",rr,.10,(0,0,z),bright,segments=64)
    for j in range(18):
        t=j*math.tau/18
        pts=[]
        for n in range(8):
            angle=n*math.tau/8; radial=.43 if n%2 else .9
            tt=t+math.cos(angle)*radial/(r*.85); zz=h*.65+math.sin(angle)*radial
            rr=r*(.7+.22*(zz-h*.45)/(h*.31))+.06
            pts.append((rr*math.cos(tt),rr*math.sin(tt),zz))
        a.tube("Embossed four-point basin ornament",pts,.06,bright,cyclic=True,resolution=1)
    stone=M.rune_stone(name+" lapis glass",tone,seed)
    inlay=E.emissive(name+" blue geometric inlay",(.025,.25,1),12)
    trench=E.simple(name+" inlay recess",(.001,.004,.025),.32)
    for i in range(count):
        angle=i*2.39996; rr=math.sqrt(i/max(1,count-1))*r*.67
        x,y=rr*math.cos(angle),rr*math.sin(angle)
        size=rng.uniform(1.3,1.9)*r/8; ht=size*rng.uniform(1.3,1.8)
        b=G.Asset("Inscribed tumbled stone",(x,y,h*.53+(rr/r)**2*h*.75));a.add(b.root)
        verts=[(-size*.62,-size*.45,0),(size*.66,-size*.42,0),(size*.65,size*.5,0),(-size*.6,size*.48,0),
               (-size,-size*.65,ht*.55),(size*.9,-size*.65,ht*.55),(size*.72,size*.58,ht*.62),(-size*.83,size*.6,ht*.60),
               (-size*.61,-size*.32,ht),(size*.52,-size*.32,ht),(size*.48,size*.43,ht*.89),(-size*.5,size*.4,ht*.9)]
        faces=[(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),
               (4,5,9,8),(5,6,10,9),(6,7,11,10),(7,4,8,11),(8,9,10,11)]
        b.mesh("Chipped blue glass stone",verts,faces,stone,bevel=.045)
        b.root.rotation_euler=(rng.uniform(-.12,.22),rng.uniform(-.23,.23),angle)
        # The front face slopes from the shoulder to the crown; paths sit on that plane.
        def point(u,v):
            z=ht*(.60+v*.29); y=-size*.65+(z-ht*.55)/(ht*.45)*size*.33-.014
            return (u*size,y,z)
        if i%3==0: path=[(-.4,0),(.4,0),(0,1),(-.4,0)]
        elif i%3==1: path=[(0,0),(-.38,.5),(0,1),(.38,.5),(0,0)]
        else: path=[(math.cos(j*math.tau/32)*.35,.5+math.sin(j*math.tau/32)*.45) for j in range(33)]
        pts=[point(u,v) for u,v in path]
        b.tube("Dark cut inlay bed",pts,.067,trench,resolution=1)
        b.tube("Light inside engraved line",[(x,y-.077,z) for x,y,z in pts],.033,inlay,resolution=1)
    a.light("Runestone reflected blue",(0,0,h+2),energy,(.035,.21,1),r*.55)
    return a.root
