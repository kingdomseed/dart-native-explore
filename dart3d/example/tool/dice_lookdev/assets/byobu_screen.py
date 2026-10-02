"""Hinged gold-leaf screen with original brush-like pine and cloud motifs."""
import math
import random
import bpy
from . import geometry as G, materials as M
import env_common as E


def pine(a,width,height,ink,seed):
    rng=random.Random(seed)
    x0=-width*.25
    spine=[(x0+width*.24*math.sin(t*2.7),-.73,height*(.06+.84*t)) for t in [i/32 for i in range(33)]]
    # Flat tapered brush strokes follow the panel rather than standing off it.
    def brush(points,start,end):
        verts=[]
        for j,p in enumerate(points):
            w=start+(end-start)*j/(len(points)-1)
            verts.extend([(p[0]-w,p[1],p[2]),(p[0]+w,p[1],p[2])])
        a.mesh("Painted pine brush stroke",verts,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(points)-1)],ink)
    brush(spine,width*.042,width*.005)
    verts=[];faces=[]
    for j in range(8):
        t=.26+j*.082;index=int(t*32);start=spine[index]
        side=-1 if j%2 else 1
        end=(max(-width*.44,min(width*.44,start[0]+side*width*rng.uniform(.22,.43))),-.74,start[2]+height*.12)
        branch=[(start[0]+(end[0]-start[0])*u,-.74,start[2]+(end[2]-start[2])*(u*.6+u*u*.4)) for u in [k/12 for k in range(13)]]
        brush(branch,width*.015,width*.002)
        for k in range(39):
            x=end[0]+rng.gauss(0,width*.1);z=end[2]+rng.gauss(0,height*.018)
            if abs(x)>width*.46:continue
            r=rng.uniform(.5,1.7)*width/42
            base=len(verts)
            verts.extend((x+math.cos(q*math.tau/7)*r,-.77,z+math.sin(q*math.tau/7)*r*.46) for q in range(7))
            faces.append(tuple(range(base,base+7)))
    a.mesh("Dappled painted pine needles",verts,faces,ink)


def build(name="Pine byobu",loc=(0,0,0),rot_z=0,panels=4,panel_width=43,height=145,
          fold=.24,wood_tone=(.015,.008,.004),wear=.3,seed=1,blossoms=False) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    leaf=M.gold_leaf(name+" leaf",wear,seed)
    wood=M.urushi(name+" black frame",wood_tone,wear,seed)
    hinge=M.metal(name+" brass hinges","brass",wear,seed)
    ink=E.simple(name+" pine ink",(.012,.018,.012),.83)
    cloud=E.simple(name+" painted pale clouds",(.30,.23,.12),.72)
    start=-panels*panel_width*math.cos(fold)/2
    for i in range(panels):
        panel=G.Asset(name+f" leaf {i}",(start+(i+.5)*panel_width*math.cos(fold),panel_width*.5*math.sin(fold),0),fold if i%2==0 else -fold)
        a.add(panel.root)
        panel.block("Gold-leaf ground",(panel_width-1.6,1.2,height-2.5),(0,0,height/2),leaf,.16)
        for x in (-panel_width/2+.6,panel_width/2-.6):panel.block("Rounded black frame stile",(1.2,1.8,height),(x,0,height/2),wood,.18)
        for z in (.7,height-.7):panel.block("Black frame cross rail",(panel_width,1.8,1.4),(0,0,z),wood,.18)
        for z in (height*.13,height*.5,height*.87):
            panel.cylinder("Pinned brass hinge",.42,4,(panel_width/2,0,z),hinge,segments=16)
        for j in range(3):
            z=height*(.18+j*.29);pts=[]
            for k in range(25):
                x=-panel_width*.45+k*panel_width*.9/24
                pts.append((x,-.67,z+math.sin(k*.24+i)*height*.018))
            for off in (0,1.3,2.6):panel.tube("Gold cloud brush line",[(x,y,zz+off) for x,y,zz in pts],.14,cloud,resolution=1)
        pine(panel,panel_width,height,ink,seed+i*5)
        if blossoms:
            from .maki_e import sprig
            petal=E.simple(name+" ivory painted blossom",(.55,.35,.22),.75)
            for j in range(3):
                def surface(u,v,d):return (u,-.81-d,height*(.18+j*.24)+v)
                sprig(panel,surface,panel_width*.88,height*.18,petal,seed+i*13+j,flowers=9,relief=.007)
    return a.root
