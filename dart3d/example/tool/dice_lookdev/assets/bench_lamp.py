"""Adjustable jeweler's lamp with forked pivots, parallel arms and spun reflector."""
import math
import bpy
from mathutils import Vector
import env_common as E
from . import geometry as G, materials as M


def build(name="Articulated bench lamp",loc=(0,0,0),rot_z=0,height=40,reach=17,radius=9,
          metal_finish="brass",wear=.55,seed=1,energy=2000,color=(.87,.94,1),head_tilt=.28) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    brass=M.machined_metal(name+" aged shell",metal_finish,wear,seed)
    bright=M.polished_metal(name+" rubbed brightwork",(.6,.39,.15),wear,seed,.17)
    black=M.leather(name+" cord",(.009,.007,.006),seed=seed)
    a.lathe("Heavy lamp foot",[(0,0),(7,0),(7.4,.45),(7.4,1.2),(6.7,1.8),(5.8,2),(5.5,2.6),(3,2.8),(2.2,3.5),(1.2,4),(0,4)],brass)
    pts=[(0,0,4),(-reach*.3,1,height*.55),(reach,0,height)]
    for start,end in zip(pts,pts[1:]):
        for dy in (-1.15,1.15):
            a.beam("Parallel adjustable arm",(start[0],start[1]+dy,start[2]),(end[0],end[1]+dy,end[2]),.8,.7,brass,.2)
        vec=Vector(end)-Vector(start)
        mid=Vector(start)+vec*.28
        spring=[]
        for i in range(100):
            u=i/99;t=u*math.tau*12
            p=mid+vec*(u*.40)+Vector((.35*math.cos(t),.35*math.sin(t),0))
            spring.append(p)
        a.tube("Tension spring",spring,.08,bright,resolution=1)
    for x,y,z in pts:
        ax=a.cylinder("Brass pivot boss",1.8,3.7,(x,y,z),brass);ax.rotation_euler.x=math.pi/2
        for side in (-1,1):
            knob=a.cylinder("Knurled locking knob",1.13,.55,(x,y+side*2.05,z),bright);knob.rotation_euler.x=math.pi/2
            for i in range(16):
                t=i*math.tau/16
                a.tube("Knurled grip",[(x+1.13*math.cos(t),y+side*1.85,z+1.13*math.sin(t)),(x+1.13*math.cos(t),y+side*2.3,z+1.13*math.sin(t))],.07,brass,resolution=1)
    head=G.Asset(name+" swivelling shade",(reach,0,height-8));a.add(head.root)
    head.root.rotation_euler.x=head_tilt
    a.tube("Shade swivel neck",[pts[-1],(reach,-math.sin(head_tilt)*7.5,height-8+math.cos(head_tilt)*7.5)],.65,brass)
    profile=[(radius,0),(radius*1.02,.5),(radius*.98,1),(radius*.94,2),(radius*.80,4),(radius*.52,6),(radius*.28,6.8),(radius*.26,7.5),(.8,7.5),(.8,7.1),(radius*.25,6.8),(radius*.5,5.7),(radius*.77,3.7),(radius*.91,1.6),(radius*.97,.5),(radius,0)]
    head.lathe("Spun domed shade",profile,brass,segments=64)
    white=M.ceramic(name+" reflector enamel",(.72,.70,.62),wear*.25,seed)
    head.lathe("Ivory reflector",[(radius*.965,.48),(radius*.9,1.5),(radius*.76,3.6),(radius*.48,5.5),(.8,6.6)],white,segments=64)
    for z,r in ((.3,radius),(1.2,radius*.95),(6.8,radius*.3)):head.ring("Rolled shade bead",r,.17,(0,0,z),bright)
    head.cylinder("Ceramic socket",1.2,2.5,(0,0,5.6),white)
    bulb=E.emissive(name+" cool-white bulb",color,5)
    head.sphere("Frosted daylight bulb",2,(0,0,3),bulb,scale=(1,1,1.3),subdiv=3)
    if energy:head.light("Bench task light",(0,0,-.3),energy,color,radius*.8,(0,-6,-30),"AREA")
    a.tube("Trailing braided flex",[(0,1.3,3),(-2,2,1),(-7,4,.25),(-10,7,.25)],.17,black)
    return a.root
