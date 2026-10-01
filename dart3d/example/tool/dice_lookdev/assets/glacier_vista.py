"""Layered snowy peaks, a suspended stone bridge and a frozen fall in a blue chasm."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M, ice_formation, cold_mist


def mountain(a,name,x,y,z,width,height,depth,seed,tone):
    rng=random.Random(seed);nx,ny=84,32;verts=[]
    peaks=[rng.uniform(.30,1) for _ in range(12)]
    for j in range(ny+1):
        v=j/ny
        for i in range(nx+1):
            u=i/nx;p=u*(len(peaks)-1);lo=min(len(peaks)-2,int(p));f=p-lo;f=f*f*(3-2*f)
            ridge=peaks[lo]*(1-f)+peaks[lo+1]*f
            zz=height*ridge*(.08+.92*math.sin(v*math.pi)**.65)
            zz+=height*.055*math.sin(u*47+v*13+seed)*math.sin(v*math.pi)
            verts.append((x+(u-.5)*width,y+(v-.5)*depth,z+zz))
    faces=[]
    for j in range(ny):
        for i in range(nx):
            n=j*(nx+1)+i;faces += [(n,n+1,n+nx+2),(n,n+nx+2,n+nx+1)]
    mat=M.frozen_stone(name+" ice-cut rock",tone,1.2,.6,seed,rime_start=-.15)
    a.mesh(name,verts,faces,mat,smooth=True)


def build(name="Glacier valley",loc=(0,0,0),rot_z=0,width=1500,depth=1400,slope=.48,
          sky_strength=1.4,tone=(.12,.22,.33),wear=.6,seed=8) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    mat,k=E.material(name+" polar sky")
    sep=k.node("ShaderNodeSeparateXYZ");k.link(k.coords().outputs["Generated"],sep.inputs[0])
    col=k.ramp(sep.outputs["Z"],[(0,(.36,.55,.70)),(.52,(.17,.34,.56)),(1,(.024,.071,.17))])
    k.surface(k.emission(col,sky_strength))
    z=30-depth*slope
    a.mesh("Cold luminous sky",[(-width,depth,z-500),(width,depth,z-500),(width,depth,z+1000),(-width,depth,z+1000)],[(0,1,2,3)],mat)
    a.sphere("Veiled polar moon",115,(190,depth*.97,z+340),
             E.emissive(name+" pale moon",(.58,.79,.92),1.8),subdiv=4)
    for j,(x,y,w,h,d) in enumerate(((-370,1180,900,370,350),(400,1040,850,470,330),
                                   (-260,810,540,310,220),(330,730,520,320,200))):
        mountain(a,"Snow-laden distant peak",x,y,35-y*slope-70,w,h,d,seed+j,
                 tuple(c*(1+.12*j) for c in tone))
    stone=M.frozen_stone(name+" bridge granite",(.17,.23,.29),.95,wear,seed)
    y=645;base=35-y*slope+20;r=67
    for j in range(19):
        G.arch_block(a,"Valley bridge arch stone",r,r+13,math.pi*j/19+.002,
                     math.pi*(j+1)/19-.002,22,(0,y,base),stone,.4)
    a.block("Snowy bridge deck",(175,27,7),(0,y,base+82),stone,.65)
    for x in (-82,82):
        for j in range(9):
            a.hewn_block("Stone bridge pier course",(34-j*.8,36,19.5),(x,y,base-90+j*20),
                         stone,.65,.4,seed+j)
    for x in (-1,1):
        mountain(a,"Chasm rock face",x*125,y,base-110,140,175,110,seed+20+x,(.10,.17,.24))
    a.add(ice_formation.build("Frozen cascade",loc=(0,y+24,base+4),kind="icicles",width=120,depth=16,
                              height=145,count=42,tone=(.44,.70,.85),glow=.10,seed=seed))
    a.add(cold_mist.build("Valley cloud sea",loc=(0,500,35-500*slope-70),width=750,depth=500,height=75,
                         layers=4,opacity=.55,tone=(.34,.51,.66),seed=seed))
    light=a.light("Moon on snowy peaks",(-120,450,440),5500000,(.65,.81,1),450,
                   target=(0,900,-180),kind="AREA")
    receivers=bpy.data.collections.new(name+" receivers")
    for ob in a.root.children_recursive:
        if ob.type in {"MESH","CURVE"}:receivers.objects.link(ob)
    light.light_linking.receiver_collection=receivers
    return a.root
