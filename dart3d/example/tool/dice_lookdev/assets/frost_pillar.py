"""Segmented stone shaft with entasis, carved capital, bronze collars and snow ledges."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Frost-carved pillar",loc=(0,0,0),rot_z=0,height=185,radius=13,
          tone=(.16,.19,.23),frost=.8,metal_tone=(.36,.22,.085),wear=.65,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);r=radius;h=height
    mat=M.frozen_stone(name+" granite",tone,frost,wear,seed)
    metal=M.polished_metal(name+" bronze collars",metal_tone,wear,seed,.35)
    a.block("Stepped square plinth",(r*2.8,r*2.8,h*.035),(0,0,h*.0175),mat,.65)
    a.lathe("Moulded torus base",[(0,h*.035),(r*1.28,h*.035),(r*1.28,h*.055),(r,h*.075),
                                (r*1.12,h*.09),(r*1.08,h*.11),(r*.87,h*.13),(0,h*.13)],mat,segments=48)
    for j in range(6):
        z0=h*(.13+j*.115);z1=z0+h*.115-.16
        profile=[]
        for i in range(5):
            z=z0+(z1-z0)*i/4;t=(z/h-.13)/.69
            profile.append((r*(.87-.11*t+.055*math.sin(math.pi*t)),z))
        segments=96
        verts=[(rr*(1-.038*((1+math.cos(t*12))/2)**4)*math.cos(t),
                rr*(1-.038*((1+math.cos(t*12))/2)**4)*math.sin(t),z)
               for rr,z in profile for t in (i*math.tau/segments for i in range(segments))]
        faces=[(j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i)
               for j in range(len(profile)-1) for i in range(segments)]
        a.mesh("Fluted dressed shaft drum",verts,faces,mat,smooth=True)
    a.lathe("Carved capital",[(r*.77,h*.82),(r*.87,h*.835),(r*.88,h*.85),(r*.76,h*.865),
                              (r*.82,h*.89),(r*1.12,h*.93),(r*1.25,h*.955),(r*1.25,h*.975),(0,h*.975)],mat,segments=48)
    for j in range(12):
        t=j*math.tau/12
        a.tube("Capital incised leaf",[(r*f*math.cos(t),r*f*math.sin(t),h*z)
                 for f,z in ((.82,.855),(.78,.875),(.9,.895),(1.10,.93),(1.21,.95))],r*.06,mat)
    a.block("Capital abacus",(r*2.8,r*2.8,h*.025),(0,0,h*.9875),mat,.6)
    for z,rr in ((h*.12,r*.91),(h*.84,r*.9)):
        a.lathe("Aged bronze collar",[(rr-.14,z-.55),(rr+.1,z-.55),(rr+.1,z+.55),(rr-.14,z+.55)],metal,segments=48)
        for j in range(12):
            t=j*math.tau/12;a.sphere("Collar rivet",r*.038,((rr+.08)*math.cos(t),(rr+.08)*math.sin(t),z),metal,subdiv=1)
    return a.root
