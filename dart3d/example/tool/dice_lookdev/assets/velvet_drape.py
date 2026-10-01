"""Tailored velvet runner folding over a table edge, with stitched star embroidery."""
import math
import random
import bpy
from . import geometry as G, materials as M


def build(name="Astronomer velvet",loc=(0,0,0),rot_z=0,width=25,length=38,drop=16,
          tone=(.045,.008,.075),wear=.35,seed=1,stars=9,sheen_tone=(.16,.025,.26),stitch_width=.033,
          heap=0,sweep=0,edge_fraction=.20,star_scale=1,star_spacing=0,rest_patches=(),star_band=None,
          sweep_peak=None,sweep_spread=.28,fabric="velvet") -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z); rng=random.Random(seed)
    velvet=(M.wool(name+" wool",tone,seed,plaid=True,plaid_axes=("X","Y")) if fabric=="wool"
            else M.velvet(name+" velvet",tone,wear,seed,sheen_tone=sheen_tone))
    gold=(M.wool(name+" sewn wool edge",(.28,.16,.07),seed) if fabric=="wool"
          else M.polished_metal(name+" gold thread",(.54,.34,.105),.3,seed,.36))
    def point(u,v):
        shift=sweep*(1-v) if sweep_peak is None else sweep*math.exp(-((v-sweep_peak)/sweep_spread)**2)
        x=u*width/2-shift; y=(v-.5)*length
        fall=max(0,edge_fraction-v)/edge_fraction
        z=.22+.30*math.sin(u*10+v*5)+.17*math.sin(u*19-v*4)
        if heap:
            envelope=math.sin(math.pi*min(1,max(0,(v-edge_fraction)/(1-edge_fraction))))**.6
            pleat=math.sin(u*7+v*13+1.1*math.sin(v*9))
            billow=.5+.5*math.sin(u*3.1-v*10+.7*math.cos(u*4))
            z=.15+heap*envelope*(.14+.55*pleat**2+.65*billow**3)
            x+=heap*.18*envelope*math.sin(v*17+u*5)
        for px,py,radius in rest_patches:
            weight=min(1,max(0,(math.hypot(x-px,y-py)-radius)/2))
            z=.15+(z-.15)*weight*weight*(3-2*weight)
        if fall:
            y=(edge_fraction-.5)*length-math.sin(fall*math.pi/2)*1.2
            z-=drop*(1-math.cos(fall*math.pi/2))
            x+=.7*math.sin(v*15+u*7)*fall
        return (x,y,z)
    nu,nv=(96,128) if heap else (56,76)
    verts=[point(-1+2*i/nu,j/nv) for j in range(nv+1) for i in range(nu+1)]
    faces=[(j*(nu+1)+i,j*(nu+1)+i+1,(j+1)*(nu+1)+i+1,(j+1)*(nu+1)+i) for j in range(nv) for i in range(nu)]
    ob=a.mesh("Draped velvet folds",verts,faces,velvet,smooth=True)
    mod=ob.modifiers.new("Woven fabric thickness","SOLIDIFY");mod.thickness=.06
    for u in (-.93,.93):
        a.tube("Gold sewn selvedge",[(x,y,z+.065) for x,y,z in (point(u,j/100) for j in range(101))],.025,gold)
    centers=[]
    band=star_band or (-.74,.74,.16 if heap else .32,.86)
    for i in range(stars):
        for attempt in range(100):
            u=rng.uniform(band[0],band[1]); v=rng.uniform(band[2],band[3])
            center=point(u,v)
            if all(math.dist(center,other)>=star_spacing for other in centers):
                break
        else:
            continue
        centers.append(center)
        rr=rng.uniform(.6,1.4)*star_scale
        if heap:
            rr=min(rr,(1-abs(u))*width*.46,min(v,1-v)*length*.92)
        pts=[]
        for j in range(16):
            t=j*math.tau/16; r=rr if j%2==0 else rr*.21
            t1=(j+1)*math.tau/16; r1=rr*.21 if j%2==0 else rr
            for step in range(8 if heap else 1):
                f=step/8 if heap else 0
                du=(1-f)*r*math.cos(t)+f*r1*math.cos(t1)
                dv=(1-f)*r*math.sin(t)+f*r1*math.sin(t1)
                x,y,z=point(u+2*du/width,v+dv/length)
                pts.append((x,y,z+.08))
        a.tube("Eight-point gold star embroidery",pts,stitch_width,gold,cyclic=True)
    if fabric=="wool":
        count=max(12,int(width*2))
        for i in range(count):
            u=-.96+1.92*i/(count-1);x,y,z=point(u,0)
            a.tube("Twisted blanket fringe",[(x,y,z),(x+.2*math.sin(i),y-.4,z-1.5),(x+.3*math.cos(i),y-.7,z-3.0)],.09,gold,resolution=1)
    return a.root
