"""Bevelled involute spur teeth, open spoke web and a bored stepped hub.

Radius is the pitch radius. Equal-module gears mesh at the sum of their
pitch radii. Phase is in radians; the default shaft points along local Y.
"""
import math
import bpy
from . import geometry as G, materials as M


def outline(radius,teeth,phase=0,pressure_angle=20):
    module=2*radius/teeth
    base=radius*math.cos(math.radians(pressure_angle))
    root=max(radius*.3,radius-1.25*module);tip=radius+module
    def inv(r):
        t=math.sqrt(max(0,(r/base)**2-1))
        return t-math.atan(t)
    half=math.pi/(2*teeth)+inv(radius)
    pts=[]
    for tooth in range(teeth):
        center=phase+tooth*math.tau/teeth
        pts.append((root,center-math.pi/teeth))
        pts.append((root,center-half))
        for i in range(6):
            r=max(base,root)+(tip-max(base,root))*i/5
            pts.append((r,center-half+inv(r)))
        for i in range(1,4):
            pts.append((tip,center+(half-inv(tip))*(-1+2*i/3)))
        for i in range(4,-1,-1):
            r=max(base,root)+(tip-max(base,root))*i/5
            pts.append((r,center+half-inv(r)))
        pts.append((root,center+half))
    return pts,root


def build(name="Clockwork spur wheel",loc=(0,0,0),rot_z=0,radius=8,teeth=32,
          thickness=1.2,spokes=6,bore=.75,phase=0,axis="Y",metal_finish="brass",
          wear=.55,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    metal=M.machined_metal(name+" wheel",metal_finish,wear,seed)
    cut=M.machined_metal(name+" turned hub",metal_finish,wear*.55,seed+1)
    pts,root=outline(radius,teeth,phase);n=len(pts);inner=root*.74
    verts=[]
    for y in (-thickness/2,thickness/2):
        verts += [(r*math.cos(t),y,r*math.sin(t)) for r,t in pts]
        verts += [(inner*math.cos(t),y,inner*math.sin(t)) for _,t in pts]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend(((i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
                      (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)))
    a.mesh("Involute teeth and open rim",verts,faces,metal,bevel=min(.07,radius/180))
    hub=max(bore*1.8,radius*.20)
    for i in range(spokes):
        t=phase+i*math.tau/spokes
        a.beam("Tapered spoke",(hub*.75*math.cos(t),0,hub*.75*math.sin(t)),
               (inner*1.02*math.cos(t+.07),0,inner*1.02*math.sin(t+.07)),
               radius*.12,thickness*.80,metal,min(.10,thickness*.15))
    ob=a.lathe("Bored raised hub",[(bore,-thickness*.95),(hub*.87,-thickness*.95),
                    (hub,-thickness*.68),(hub,thickness*.68),(hub*.87,thickness*.95),
                    (bore,thickness*.95),(bore,-thickness*.95)],cut,segments=40)
    ob.rotation_euler.x=math.pi/2
    for side in (-1,1):
        a.ring("Turned rim highlight",inner+.18,.045,(0,side*(thickness/2+.025),0),cut,plane="XZ",segments=96)
    if axis=="Z":a.root.rotation_euler.x=math.pi/2
    return a.root
