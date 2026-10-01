"""Carved oak library case with separately bound, unlettered leather volumes."""
import math
import random
import bpy
from . import geometry as G, materials as M


def build(name="Library bookcase", loc=(0, 0, 0), rot_z=0, width=125, height=220,
          depth=30, rows=6, wood_tone=(.095,.036,.012), wear=.55, seed=2,
          fullness=.92) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z); rng=random.Random(seed)
    wood=M.oak(name+" long grain",wood_tone,wear,seed,axis="Z")
    cross=M.oak(name+" cross grain",wood_tone,wear,seed+1)
    dark=M.oak(name+" recessed boards",tuple(c*.35 for c in wood_tone),wear,seed+2,axis="Z")
    gold=M.polished_metal(name+" old gilt",(.48,.27,.065),wear,seed,.28)
    page=M.parchment(name+" page edges",seed=seed)
    tones=((.12,.026,.012),(.022,.044,.029),(.018,.024,.067),(.095,.055,.022),(.07,.015,.036),(.025,.018,.012))
    leather=[M.leather(name+f" calf binding {i}",t,wear,seed+i) for i,t in enumerate(tones)]
    for j in range(7):
        a.block("Tongue-and-groove backing",(width/7-.16,1.8,height-8),
                (-width/2+(j+.5)*width/7,depth/2-1, height/2),dark,.13)
    for sx in (-1,1):
        x=sx*(width/2-4)
        a.block("Bookcase solid stile",(8,depth,height-8),(x,0,height/2),wood,.5)
        a.lathe("Turned oak pilaster",[(0,0),(4,0),(4,3),(3.4,5),(2.7,7),(2.4,15),
                    (2.1,height-32),(3,height-24),(4,height-21),(4,height-18),(0,height-18)],
                    wood,(x,-depth/2-1,8),segments=24)
        for z in (12,height-15):
            a.block("Pilaster rosette plinth",(10,5,9),(x,-depth/2-1,z),cross,.6)
            for j in range(8):
                t=j*math.tau/8
                a.tube("Carved rosette petal",[(x,-depth/2-3.7,z),
                     (x+2.7*math.cos(t+.16),-depth/2-4,z+2.7*math.sin(t+.16)),
                     (x+3.2*math.cos(t),-depth/2-3.7,z+3.2*math.sin(t)),
                     (x,-depth/2-3.7,z)],.16,wood)
    for z,w,d,h in ((3,5,4,6),(8,2,1,4),(height-7,2,2,5),(height-2,6,5,5),(height+2,9,7,3)):
        a.block("Moulded oak cornice",(width+w,depth+d,h),(0,0,z),cross,.55)
    for i in range(int(width/7)):
        a.block("Cornice dentil",(3,4,3),(-width/2+4+i*7,-depth/2-1,height-11),wood,.24)
    clear=width-17; step=(height-26)/rows
    for row in range(rows):
        z=12+row*step
        a.block("Shelved oak board",(width-10,depth-1,3.1),(0,0,z),cross,.35)
        a.block("Rounded shelf nosing",(width-9,2.1,2.6),(0,-depth/2,z+.4),cross,.7)
        x=-clear/2
        while x<clear/2-6:
            t=rng.uniform(3.2,6.5); h=step*rng.uniform(.61,.86); d=rng.uniform(depth*.57,depth*.81)
            if rng.random()>fullness:
                x+=t+2; continue
            bind=G.Asset("Bound library volume",(x+t/2,-depth/2+2,z+1.65)); a.add(bind.root)
            mat=rng.choice(leather)
            bind.block("Sewn signatures",(t-.7,d-.5,h-.7),(0,d/2,h/2),page,.2)
            for side in (-1,1):
                bind.block("Leather board",(.35,d+.6,h), (side*(t-.35)/2,d/2,h/2),mat,.15)
            bind.block("Rounded leather spine",(t,.85,h),(0,.1,h/2),mat,min(.39,t*.15))
            for zz in (.13,.27,.76,.89):
                bind.tube("Raised spine band",[(-t/2+.12,.05,h*zz),(-t*.35,-.50,h*zz),
                         (t*.35,-.50,h*zz),(t/2-.12,.05,h*zz)],.11,mat,resolution=1)
                bind.tube("Gilt spine rule",[(-t*.34,-.49,h*zz+.3),(t*.34,-.49,h*zz+.3)],.035,gold,resolution=1)
            for zz in (.40,.58):
                rr=min(t*.25,1.1)
                bind.tube("Unlettered gilt lozenge",[(0,-.49,h*zz-rr),(-rr,-.49,h*zz),
                    (0,-.49,h*zz+rr),(rr,-.49,h*zz)],.038,gold,cyclic=True,resolution=1)
            bind.root.rotation_euler.y=rng.uniform(-.028,.028)
            x+=t+rng.uniform(.35,1.3)
    return a.root
