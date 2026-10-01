"""Graduated brass armillary or celestial globe on a turned pedestal."""
import math
import random
import bpy
from mathutils import Vector
import env_common as E
from . import geometry as G, materials as M


def band(a,name,r,width,thickness,mat,rotation=(0,0,0),center=(0,0,0),ticks=False):
    ob=a.lathe(name,[(r-thickness/2,-width/2),(r+thickness/2,-width/2),
                    (r+thickness/2,width/2),(r-thickness/2,width/2),(r-thickness/2,-width/2)],mat,segments=128)
    ob.location=center; ob.rotation_euler=rotation
    if ticks:
        from mathutils import Euler
        transform=Euler(rotation).to_matrix()
        ink=M.metal(name+" recessed marks","iron",.2)
        verts=[]; faces=[]
        for j in range(120):
            t=math.tau*j/120
            w=width*(.38 if j%5 else .78)
            pts=[((r+thickness*.51)*math.cos(t+dt),(r+thickness*.51)*math.sin(t+dt),z)
                 for dt,z in ((-.002,-w/2),(.002,-w/2),(.002,w/2),(-.002,w/2))]
            start=len(verts); verts += [tuple(transform@Vector(p)+Vector(center)) for p in pts]
            faces.append(tuple(range(start,start+4)))
        a.mesh("Engraved scale divisions",verts,faces,ink)
    return ob


def build(name="Armillary sphere",loc=(0,0,0),rot_z=0,radius=20,pedestal=18,kind="armillary",
          metal_tone=(.55,.32,.09),wear=.35,seed=3) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z); r=radius
    brass=M.polished_metal(name+" polished brass",metal_tone,wear,seed,.19)
    a.lathe("Turned brass pedestal",[(0,0),(r*.65,0),(r*.69,1),(r*.64,2.5),(r*.47,4),
                                    (r*.28,5),(r*.22,pedestal*.6),(r*.3,pedestal*.75),
                                    (r*.24,pedestal*.85),(r*.18,pedestal),(0,pedestal)],brass)
    center=(0,0,pedestal+r)
    band(a,"Meridian cradle",r*1.09,r*.12,r*.036,brass,(math.pi/2,0,0),center,True)
    band(a,"Horizon ring",r*1.13,r*.10,r*.035,brass,(0,0,0),center,True)
    if kind=="armillary":
        for i,rot in enumerate(((.42,.42,.1),(1.15,.3,.2),(.25,1.14,.4))):
            band(a,"Orbital brass band",r*(.92-i*.085),r*.12,r*.027,brass,rot,center,True)
        a.sphere("Central polished globe",r*.26,center,brass,subdiv=4)
    else:
        globe=E.simple(name+" midnight enamel",(.008,.021,.055),.22,Coat_Weight=.7)
        a.sphere("Celestial globe",r*.94,center,globe,subdiv=5)
        for latitude in (-60,-30,0,30,60):
            t=math.radians(latitude)
            a.ring("Globe latitude",r*.946*math.cos(t),.027,(0,0,center[2]+r*.946*math.sin(t)),brass)
        for j in range(6):
            ring=a.ring("Globe longitude",r*.946,.027,(0,0,0),brass,plane="XZ",segments=96)
            ring.rotation_euler.z=math.pi*j/6; ring.location=center
        rng=random.Random(seed)
        stars=[]
        for i in range(55):
            az=rng.uniform(0,math.tau); el=rng.uniform(-1.25,1.25)
            p=Vector((math.cos(az)*math.cos(el),math.sin(az)*math.cos(el),math.sin(el)))*(r*.951)+Vector(center)
            a.sphere("Inlaid globe star",r*.009,p,brass,subdiv=1); stars.append(p)
        for i in range(0,45,3):
            p,q=stars[i:i+2]
            if (p-q).length<r*.8: a.tube("Globe constellation",[p,q],.023,brass)
    a.beam("Polar axis",(0,0,pedestal-.7),(0,0,pedestal+2*r+1),r*.045,r*.045,brass,.1)
    for z in (pedestal-.5,pedestal+2*r+1): a.sphere("Axis knop",r*.075,(0,0,z),brass)
    return a.root
