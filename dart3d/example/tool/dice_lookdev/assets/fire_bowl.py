"""Raised bronze brazier with embossed bands, fractured coals and layered flame tongues."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M
from .forge import flame_sheet


def build(name="Bronze fire bowl",loc=(0,0,0),rot_z=0,radius=14,height=14,flame_height=26,
          metal_tone=(.40,.24,.085),wear=.6,seed=2,energy=7000,flames=11) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed);r=radius;h=height
    bronze=M.polished_metal(name+" hammered bronze",metal_tone,wear,seed,.28)
    dark=M.metal(name+" tarnished recesses","brass",.8,seed)
    a.lathe("Spun brazier bowl",[(0,0),(r*.62,0),(r*.66,h*.06),(r*.60,h*.15),(r*.40,h*.22),
        (r*.38,h*.32),(r*.52,h*.37),(r*.70,h*.49),(r*.86,h*.65),(r*.98,h*.85),
        (r,h*.96),(r*.98,h),(r*.92,h),(r*.89,h*.83),(r*.77,h*.64),(r*.59,h*.5),
        (r*.36,h*.43),(0,h*.43)],bronze,segments=64)
    for zz,rr,thick in ((h*.09,r*.63,.16),(h*.37,r*.5,.15),(h*.82,r*.96,.23),(h*.97,r*.98,.3)):
        a.ring("Rolled bronze moulding",rr,thick,(0,0,zz),bronze,segments=64)
    for j in range(24):
        t=j*math.tau/24
        a.sphere("Rim rivet",r*.022,(r*.97*math.cos(t),r*.97*math.sin(t),h*.87),bronze,subdiv=2)
        pts=[(r*rr*math.cos(t+dt),r*rr*math.sin(t+dt),h*z)
             for rr,dt,z in ((.82,-.065,.62),(.91,0,.77),(.82,.065,.62),(.70,0,.51))]
        a.tube("Embossed bowl lozenge",pts,r*.012,bronze,cyclic=True)
    for side in (-1,1):
        a.ring("Brazier ring handle",r*.22,.22,(side*r*.98,0,h*.72),dark,plane="XZ")
    crust=[M.coal(name+f" coal crust {i}",heat) for i,heat in enumerate((.0,.25,.6))]
    core=[E.emissive(name+f" buried heat {i}",color,power) for i,(color,power) in enumerate(
        (((1,.045,.001),2),((1,.19,.008),5),((1,.47,.03),9))) ]
    a.sphere("Heaped dark coke bed",r*.84,(0,0,h*.69),crust[0],scale=(1,1,.23),subdiv=3)
    for j in range(95):
        t=rng.uniform(0,math.tau);rr=r*.80*math.sqrt(rng.random());hot=2 if rr<r*.37 else 1 if rr<r*.64 else 0
        x,y=rr*math.cos(t),rr*math.sin(t);z=h*.77+(1-(rr/r)**2)*r*.12
        size=r*rng.uniform(.09,.15)
        a.add(E.rock("Buried glowing coal",size*.84,(x,y,z-.17),core[hot],seed=seed*100+j,
                     subdiv=1,squash=(1,1,.43),strength=.30))
        a.add(E.rock("Black coal crust",size,(x,y,z+.13),crust[hot],seed=seed*200+j,
                     subdiv=1,squash=(1.15,.9,.48),strength=.35))
    mat=M.forge_flame(name+" gradient fire",18)
    for j in range(flames):
        t=rng.uniform(0,math.tau);rr=rng.uniform(.02,.64)*r
        hh=flame_height*(rng.uniform(.64,1) if j<5 else rng.uniform(.22,.65))
        flame_sheet(a,(rr*math.cos(t),rr*math.sin(t),h*.83),rng.uniform(.11,.20)*r,hh,
                    mat,rng.uniform(-.48,.48)*r,rng.uniform(0,math.tau),rng.uniform(-1.5,1.5))
    spark=E.emissive(name+" sparks",(1,.40,.025),8)
    for j in range(3):
        x,y=rng.uniform(-r*.5,r*.5),rng.uniform(-r*.4,r*.4);z=h+flame_height*rng.uniform(.45,.95)
        a.tube("Sparse lifting spark",[(x,y,z),(x+.1,y,z+.55)],.035,spark,resolution=1)
    a.light("Warm brazier pool",(0,0,h+2),energy,(1,.42,.10),r*.3)
    return a.root
