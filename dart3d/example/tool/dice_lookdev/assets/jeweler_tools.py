"""Optical loupe, tapered spring tweezers and gravers with pear-shaped handles."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Jeweler instrument",loc=(0,0,0),rot_z=0,kind="loupe",length=14,radius=2.3,
          wood_tone=(.13,.045,.013),metal_finish="brass",wear=.5,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    brass=M.machined_metal(name+" brass",metal_finish,wear,seed)
    steel=M.polished_metal(name+" steel",(.58,.62,.65),wear*.6,seed,.16)
    if kind=="loupe":
        h=radius*1.6
        a.lathe("Hollow loupe barrel",[(radius,0),(radius,.35),(radius*.89,.5),(radius*.89,h-.45),(radius,h-.3),(radius,h),(radius*.78,h),(radius*.78,.2),(radius,0)],brass,segments=64)
        for z in (.22,h-.22):a.ring("Rolled lens retaining ring",radius,.1,(0,0,z),steel)
        for i in range(64):
            t=math.tau*i/64
            a.tube("Fine barrel knurl",[(radius*.9*math.cos(t),radius*.9*math.sin(t),.8),(radius*.9*math.cos(t),radius*.9*math.sin(t),h-.7)],.027,brass,resolution=1)
        a.lathe("Convex optical lens",[(0,h-.34),(radius*.4,h-.4),(radius*.73,h-.6),(radius*.79,h-.72),(radius*.74,h-.8),(radius*.4,h-.91),(0,h-.96)],M.clear_glass(name+" lens",.018,1.52),segments=64)
    elif kind=="tweezers":
        for side in (-1,1):
            verts=[]
            for y,w,g,z in ((0,.46,.10,.30),(length*.22,.5,.19,.37),(length*.65,.36,.49,.25),(length*.9,.16,.25,.13),(length,.055,.09,.09)):
                for x,dz in ((-w/2,-.07),(w/2,-.07),(w/2,.07),(-w/2,.07)):verts.append((side*g+x,y-length/2,z+dz))
            faces=[(3,2,1,0),(16,17,18,19)]+[(4*j+i,4*j+(i+1)%4,4*(j+1)+(i+1)%4,4*(j+1)+i) for j in range(4) for i in range(4)]
            a.mesh("Drawn spring-steel jaw",verts,faces,steel,.035)
            for j in range(12):
                y=length*(.26+j*.022)-length/2
                a.tube("Grip crosshatch",[(side*.24-.17,y,.475),(side*.24+.17,y+.12,.475)],.015,brass,resolution=1)
        a.block("Joined tweezer heel",(.65,.5,.17),(0,-length/2,.3),steel,.1)
    elif kind=="graver":
        wood=M.oak(name+" pear handle",wood_tone,wear,seed,axis="Z")
        a.lathe("Pear-shaped graver handle",[(0,0),(1.1,.1),(1.5,.8),(1.55,1.5),(1.3,2.5),(.8,3.5),(.55,4.1),(0,4.1)],wood)
        a.cylinder("Ferrule",.57,1,(0,0,4.3),brass)
        a.cylinder("Graver tang",.18,length-4.7,(0,0,(length+4.7)/2),steel,segments=4)
    else:raise ValueError(kind)
    return a.root
