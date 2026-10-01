"""Thick fractured cave ice, uneven hanging icicles and low settled snow drifts."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M


def build(name="Cave ice formation",loc=(0,0,0),rot_z=0,kind="wall",width=90,depth=26,height=160,
          count=18,tone=(.55,.78,.90),glow=.18,wear=.3,seed=2) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    mat=M.frozen_ice(name+" blue ice",tone,glow,wear,seed)
    if kind=="drift":
        mat=M.snow(name+" soft snow",seed=seed)
        rings,segments=18,96
        verts=[(0,0,height*.70)]
        for j in range(1,rings+1):
            t=j/rings
            for i in range(segments):
                angle=i*math.tau/segments
                outline=1+.07*math.sin(angle*7+seed)+.035*math.sin(angle*17-seed)
                u,v=t*outline*math.cos(angle),t*outline*math.sin(angle)
                z=height*(1-t*t)**1.5*(.70+.12*math.sin(u*6+v*5+seed)+.08*math.sin(u*15-v*11))
                verts.append((u*width*.5,v*depth*.5,z))
        faces=[(0,1+i,1+(i+1)%segments) for i in range(segments)]
        faces += [(1+j*segments+i,1+j*segments+(i+1)%segments,
                   1+(j+1)*segments+(i+1)%segments,1+(j+1)*segments+i)
                  for j in range(rings-1) for i in range(segments)]
        a.mesh("Scalloped wind-shaped snow bank",verts,faces,mat,smooth=True)
    elif kind=="icicles":
        for j in range(count):
            x=(j+.3+rng.random()*.4)/count*width-width/2;y=rng.uniform(-depth/2,depth/2)
            length=height*rng.uniform(.25,1);r=length*rng.uniform(.026,.052);phase=rng.uniform(0,6)
            rings,segments=13,12;verts=[]
            for row in range(rings):
                t=row/(rings-1);rr=max(.035,r*(1-t)**.8*(1+.11*math.sin(t*18+phase)))
                for n in range(segments):
                    angle=math.tau*n/segments
                    verts.append((x+.35*r*math.sin(t*2+phase)*t+rr*math.cos(angle),
                                  y+.20*r*t*t+rr*math.sin(angle),-length*t))
            faces=[tuple(reversed(range(segments)))]
            faces += [(row*segments+n,row*segments+(n+1)%segments,(row+1)*segments+(n+1)%segments,(row+1)*segments+n)
                      for row in range(rings-1) for n in range(segments)]
            a.mesh("Tapered frozen drip",verts,faces,mat,smooth=True)
    else:
        nx,nz=18,24;verts=[]
        def front(x,z):return -depth*.35+depth*(.16*math.sin(x*.13+z*.029)+.10*math.sin(x*.28-z*.043+seed))
        for back in (False,True):
            for j in range(nz+1):
                v=j/nz
                for i in range(nx+1):
                    u=i/nx;x=(u-.5)*width
                    cap=height*(.81+.13*math.sin(u*9+seed)+.06*math.cos(u*21))
                    z=v*cap
                    xx=x+math.sin(v*8+seed)*width*.025*math.sin(math.pi*u)
                    verts.append((xx,depth*.45+math.sin(u*7+v*9)*depth*.08 if back else front(xx,z),z))
        stride=nx+1;side=stride*(nz+1);faces=[]
        for offset in (0,side):
            faces += [(offset+j*stride+i,offset+j*stride+i+1,offset+(j+1)*stride+i+1,offset+(j+1)*stride+i)
                      for j in range(nz) for i in range(nx)]
        boundary=list(range(stride))+[j*stride+nx for j in range(1,nz+1)]+list(range(nz*stride+nx-1,nz*stride-1,-1))+[j*stride for j in range(nz-1,0,-1)]
        faces += [(v,boundary[(i+1)%len(boundary)],boundary[(i+1)%len(boundary)]+side,v+side) for i,v in enumerate(boundary)]
        a.mesh("Layered glacial wall",verts,faces,mat,smooth=True)
        inner=E.simple(name+" deep blue mineral core",(.013,.12,.24),.3,
                       Emission_Color=(.035,.25,.43,1),Emission_Strength=glow*.65)
        core_verts=[(x*.96,depth*.26,z*.96+.15) for x,y,z in verts[:side]]
        core_faces=[(j*stride+i,j*stride+i+1,(j+1)*stride+i+1,(j+1)*stride+i)
                    for j in range(nz) for i in range(nx)]
        a.mesh("Blue depth behind ice",core_verts,core_faces,inner,smooth=True)
        crack=E.simple(name+" trapped frost cracks",(.45,.73,.84),.3,
                       Emission_Color=(.12,.43,.63,1),Emission_Strength=glow)
        for j in range(count):
            x=rng.uniform(-width*.43,width*.43);z=rng.uniform(height*.1,height*.85)
            pts=[]
            for n in range(rng.randint(4,8)):
                x=max(-width*.48,min(width*.48,x+rng.uniform(-5,5)));z=max(3,min(height*.86,z+rng.uniform(-12,6)))
                pts.append((x,front(x,z)+.9,z))
            a.tube("Internal branching ice fracture",pts,.045,crack,resolution=1)
            if j%2==0:
                x,y,z=pts[1];a.tube("Fine fracture fork",[(x,y,z),(x+3,y+.12,z-4),(x+7,y+.2,z-6)],.022,crack,resolution=1)
    return a.root
