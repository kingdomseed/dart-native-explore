"""Chamfered granite altar, carved trestles and bronze inlaid geometric panels."""
import math
import random
import bpy
from . import geometry as G, materials as M


def build(name="Carved stone altar",loc=(0,0,0),rot_z=0,width=108,depth=40,height=76,
          tone=(.13,.17,.22),metal_tone=(.37,.21,.075),frost=.65,wear=.6,seed=1,carving=False,accumulation=0,quiet=None,quiet_center=(0,0)) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    stone=M.frozen_stone(name+" granite",tone,frost,wear,seed)
    bronze=M.polished_metal(name+" aged bronze",metal_tone,wear,seed,.32)
    if carving:
        rng=random.Random(seed);outline=[]
        corners=[(-width/2+1,-depth/2),(width/2-1,-depth/2),(width/2,-depth/2+1),
                 (width/2,depth/2-1),(width/2-1,depth/2),(-width/2+1,depth/2),
                 (-width/2,depth/2-1),(-width/2,-depth/2+1)]
        for j,(x,y) in enumerate(corners):
            xx,yy=corners[(j+1)%len(corners)]
            steps=max(1,math.ceil(math.hypot(xx-x,yy-y)/1.5))
            for i in range(steps):
                t=i/steps;outline.append((x*(1-t)+xx*t+rng.uniform(-.22,.22)*wear,y*(1-t)+yy*t+rng.uniform(-.22,.22)*wear))
        verts=[(x,y,z) for z in (height-5,height) for x,y in outline];n=len(outline)
        faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        a.mesh("Chipped dressed altar mensa",verts,faces,stone,bevel=.20)
    else:
        a.block("Chamfered altar mensa",(width,depth,5),(0,0,height-2.5),stone,.75)
    a.block("Recessed cornice",(width-3,depth-2,2.5),(0,0,height-6.25),stone,.5)
    a.block("Lower moulding",(width-1,depth,1.6),(0,0,height-8.3),stone,.5)
    leg_scale=min(1,width/70)
    for x in (-width*.32,width*.32):
        a.block("Splayed stone foot",(20*leg_scale,depth*.90,5),(x,0,2.5),stone,.8)
        outline=[(x-9*leg_scale,5),(x-6*leg_scale,12),(x-6*leg_scale,height-17),(x-10*leg_scale,height-9),(x+10*leg_scale,height-9),
                 (x+6*leg_scale,height-17),(x+6*leg_scale,12),(x+9*leg_scale,5)]
        a.extrude("Carved altar trestle",outline,depth*.68,stone,bevel=.75)
        for side in (-1,1):
            y=side*(depth*.34+.06)
            a.tube("Trestle recessed border",[(x-4.8*leg_scale,y,15),(x-4.8*leg_scale,y,height-22),
                    (x,y,height-16),(x+4.8*leg_scale,y,height-22),(x+4.8*leg_scale,y,15)],.18,bronze)
            for z in (22,37,52):
                a.tube("Carved diamond inlay",[(x,y,z+4),(x+3.8*leg_scale,y,z),(x,y,z-4),(x-3.8*leg_scale,y,z)],.13,bronze,cyclic=True)
    a.block("Stone stretcher",(width*.64,7,7),(0,0,14),stone,.6)
    for side in (-1,1):
        y=side*(depth/2+.02)
        for x in (-width*.40,0,width*.40):
            a.tube("Mensa bronze chevron",[(x-5,y,height-3.5),(x,y,height-1.5),(x+5,y,height-3.5)],.075,bronze)
    if carving:
        dark=M.frozen_stone(name+" recessed carving",(.018,.029,.043),.08,wear,seed)
        rime=M.snow(name+" frost in incisions",seed=seed,sparkle=.2)
        for side in (-1,1):
            for j in range(max(1,int(width/7))):
                x=-width/2+4+j*7;y=side*(depth/2+.04)
                pts=[(x-2.8,y,height-2.6),(x,y,height-1),(x+2.8,y,height-2.6),(x,y,height-4.2)]
                a.tube("Interlaced frieze recess",pts,.19,dark,cyclic=True)
                a.tube("Frost in knotwork",[(px,py-.035*side,pz-.045) for px,py,pz in pts],.055,rime,cyclic=True)
        for x in (-width*.39,width*.39):
            if quiet and abs(x-quiet_center[0])<quiet[0]+5:continue
            for y in (-depth*.25,depth*.25):
                for radius in (2.2,3.2):a.ring("Frost-filled top rosette",radius,.075,(x,y,height+.025),dark,segments=36)
                for j in range(6):
                    t=j*math.tau/6
                    a.tube("Geometric rosette spoke",[(x,y,height+.025),(x+2.8*math.cos(t),y+2.8*math.sin(t),height+.025)],.07,rime)
    if accumulation:
        from . import snow_cover
        a.add(snow_cover.build(name+" settled snow",loc=(0,0,height+.02),width=width-.6,depth=depth-.6,
                              thickness=accumulation,quiet=quiet,quiet_center=quiet_center,sparkle=160,seed=seed))
    return a.root
