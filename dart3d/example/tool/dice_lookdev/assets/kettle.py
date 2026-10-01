"""Spun enamel stovetop kettle, hollow rising spout, lid and insulated bail."""
import math
import bpy
from mathutils import Vector
import env_common as E
from . import geometry as G, materials as M


def build(name="Enamel kettle",loc=(0,0,0),rot_z=0,radius=9,height=19,tone=(.36,.16,.035),
          wear=.4,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);r,h=radius,height
    enamel=M.ceramic(name+" enamel",tone,wear,seed)
    metal=M.polished_metal(name+" rim",(.5,.52,.5),wear,seed,.24)
    black=M.aged_plastic(name+" bakelite",(.017,.012,.008),wear,seed)
    profile=[(0,0),(r*.72,0),(r*.97,.8),(r,2),(r*.99,h*.48),(r*.90,h*.63),(r*.61,h*.77),(r*.51,h*.78)]
    a.lathe("Pressed kettle body",profile,enamel,segments=64)
    a.ring("Rolled base seam",r*.95,.2,(0,0,1),metal)
    a.lathe("Domed removable lid",[(0,h*.84),(r*.32,h*.82),(r*.53,h*.79),(r*.56,h*.75)],metal)
    a.sphere("Lid insulated knob",1.4,(0,0,h*.89),black,scale=(1,1,.7))
    points=[Vector((r*.73+r*.95*t,0,h*.30+h*.56*t)) for t in [i/20 for i in range(21)]]
    direction=(points[-1]-points[0]).normalized();u=Vector((0,1,0));v=direction.cross(u)
    verts=[]
    for inner in (False,True):
        for i,p in enumerate(points):
            rr=r*(.27-.13*i/20)-( .22 if inner else 0)
            verts.extend(tuple(p+rr*(u*math.cos(j*math.tau/32)+v*math.sin(j*math.tau/32))) for j in range(32))
    n=len(points)*32
    faces=[(base+i*32+j,base+i*32+(j+1)%32,base+(i+1)*32+(j+1)%32,base+(i+1)*32+j) for base in (0,n) for i in range(20) for j in range(32)]
    faces += [(20*32+j,20*32+(j+1)%32,n+20*32+(j+1)%32,n+20*32+j) for j in range(32)]
    a.mesh("Hollow tapered pouring spout",verts,faces,enamel,smooth=True)
    for y in (-r*.80,r*.80):a.sphere("Handle anchor",1,(0,y,h*.61),metal)
    pts=[(0,r*.81*math.cos(t),h*.61+h*.54*math.sin(t)) for t in [math.pi*i/40 for i in range(41)]]
    a.tube("Swept kettle bail",pts,.6,metal)
    a.tube("Bakelite hand grip",pts[10:31],1.15,black,resolution=3)
    return a.root
