"""Flanged glass charge column with porcelain insulators and a luminous helix."""
import math
import bpy
import env_common as E
from . import geometry as G, materials as M


def build(name="Tesla charge column",loc=(0,0,0),rot_z=0,radius=7,height=48,turns=5,
          metal_finish="brass",tone=(.045,1,.72),strength=7,energy=1200,
          wear=.5,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    metal=M.machined_metal(name+" casing",metal_finish,wear,seed)
    copper=M.machined_metal(name+" winding","copper",wear*.5,seed+1)
    iron=M.machined_metal(name+" steel bolts","steel",wear,seed+2)
    porcelain=M.ceramic(name+" insulators",(.30,.32,.25),wear,seed)
    r=radius;bottom=height*.17;top=height*.83
    for z,flip in ((0,1),(height,-1)):
        profile=[(0,0),(r*1.17,0),(r*1.23,.5),(r*1.23,1.5),(r*1.02,2),
                 (r*1.02,3.1),(r*.83,3.5),(r*.83,bottom*.70),(r,bottom*.78),(r,bottom),
                 (r*.86,bottom+.25),(0,bottom+.25)]
        a.lathe("Spun electrode cap",[(rr,z+flip*zz) for rr,zz in profile],metal,segments=64)
        for i in range(10):
            t=i*math.tau/10
            a.cylinder("Electrode flange bolt",r*.075,.5,(r*1.1*math.cos(t),r*1.1*math.sin(t),z+flip*1.6),iron,segments=6,bevel=.035)
    for i in range(4):
        t=math.pi/4+i*math.pi/2
        a.cylinder("External tie rod",r*.07,height-2,(r*1.09*math.cos(t),r*1.09*math.sin(t),height/2),metal,segments=16)
    glass=M.glass(name+" clear borosilicate",(.78,.95,.92),.13)
    a.lathe("Thin glass envelope",[(r*.84,bottom),(r*.87,bottom),(r*.87,top),
                                   (r*.84,top),(r*.84,bottom)],glass,segments=72)
    for z in (bottom,top):
        for i in range(4):
            zz=z+(1 if z==bottom else -1)*(i*.9+1)
            a.lathe("Glazed porcelain shed",[(0,zz-.3),(r*.3,zz-.3),(r*.36,zz),
                       (r*.23,zz+.4),(0,zz+.4)],porcelain,segments=32)
    a.cylinder("Central electrode",r*.12,top-bottom,(0,0,height/2),copper,segments=24)
    coil=E.emissive(name+" teal discharge",tone,strength)
    hot=E.emissive(name+" pale discharge centre",(.53,1,.86),strength*1.7)
    pts=[]
    for j in range(241):
        t=j/240;angle=t*math.tau*turns
        pts.append((r*.52*math.cos(angle),r*.52*math.sin(angle),bottom+4+(top-bottom-8)*t))
    a.tube("Continuous teal helical discharge",pts,r*.033,coil,resolution=2)
    a.tube("Bright thin discharge core",[(x,y-r*.012,z) for x,y,z in pts],r*.009,hot,resolution=1)
    for z in (height*.34,height*.65):a.light("Charge column teal spill",(0,-r*.8,z),energy/2,tone,r)
    return a.root
