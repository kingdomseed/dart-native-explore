"""Turned brass assay balance, knife-edge beam, suspension links and dished pans."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Assay balance",loc=(0,0,0),rot_z=0,height=34,width=30,pan_radius=5.2,
          metal_finish="brass",wear=.45,seed=1,tilt=.025) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    brass=M.machined_metal(name+" turned brass",metal_finish,wear,seed)
    edge=M.polished_metal(name+" rubbed rims",(.62,.4,.14),wear*.4,seed)
    a.lathe("Weighted circular foot",[(0,0),(6.8,0),(7,.6),(7,1),(6.6,1.4),(5.6,1.65),(5.5,2.3),(3,2.5),(2.4,3.2),(1.4,4.2),(.9,5),(0,5)],brass)
    a.lathe("Turned column",[(.9,3),(.85,4),(1.25,5),(1.3,5.6),(.8,6.2),(.7,height-5),(1.2,height-4.7),(1.2,height-4),(.65,height-3),(.5,height+1),(.8,height+1.8),(.3,height+2.7),(0,height+3)],brass)
    for z in (5.5,7,height-5):a.ring("Column collar",1,.12,(0,0,z),edge)
    outline=[(-width/2,height-.2),(-width*.46,height+1),(-width*.30,height+.45),(-1.8,height-.9),(-.65,height-1.3),(.65,height-1.3),(1.8,height-.9),(width*.30,height+.45),(width*.46,height+1),(width/2,height-.2),(width*.33,height-.25),(1.6,height-2.2),(-1.6,height-2.2),(-width*.33,height-.25)]
    beam=a.extrude("Arched knife-edge balance beam",outline,.65,brass,y=-.9,bevel=.18)
    beam.rotation_euler.y=tilt
    pin=a.cylinder("Central fulcrum axle",.65,2.6,(0,-.45,height-1.4),edge);pin.rotation_euler.x=math.pi/2
    a.tube("Balance pointer",[(0,-1.8,height-1.5),(0,-1.8,height-8)],.09,edge)
    for side in (-1,1):
        x=side*width*.47; z=height-.3-side*width*.47*tilt
        a.ring("Suspension ring",.57,.13,(x,-.9,z-.3),edge,plane="XZ",segments=24)
        pz=height*.39
        a.lathe("Shallow spun weighing pan",[(0,0),(pan_radius*.35,0),(pan_radius*.66,.35),(pan_radius*.89,1),(pan_radius,1.8),(pan_radius,2),(pan_radius*.97,2.1),(pan_radius*.85,1.15),(pan_radius*.60,.56),(0,.3)],brass,loc=(x,-.9,pz))
        a.ring("Rolled pan lip",pan_radius,.13,(x,-.9,pz+1.9),edge)
        for t in (math.pi/6,5*math.pi/6,3*math.pi/2):
            start=(x,-.9,z-.7);end=(x+pan_radius*.91*math.cos(t),-.9+pan_radius*.91*math.sin(t),pz+1.65)
            a.tube("Fine pan chain",[start,end],.065,edge,resolution=1)
            for i in range(1,18):
                u=i/18;p=tuple(start[j]*(1-u)+end[j]*u for j in range(3))
                a.ring("Chain link glint",.12,.035,p,edge,plane="XZ" if i%2 else "YZ",ellipse=1.3,segments=8)
    return a.root
