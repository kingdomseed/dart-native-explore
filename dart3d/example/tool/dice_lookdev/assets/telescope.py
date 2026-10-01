"""Sectioned brass refractor, equatorial bearings and braced wooden tripod."""
import math
import bpy
from mathutils import Vector
from . import geometry as G, materials as M


def build(name="Brass refractor",loc=(0,0,0),rot_z=0,length=100,radius=5,stand_height=112,
          elevation=24,wood_tone=(.08,.029,.008),metal_tone=(.55,.32,.09),wear=.35,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    brass=M.polished_metal(name+" brass",metal_tone,wear,seed,.19)
    dark=M.metal(name+" aged bearings","brass",wear,seed)
    wood=M.oak(name+" tripod walnut",wood_tone,wear,seed,axis="Z")
    for i in range(3):
        t=math.tau*i/3+.25
        foot=Vector((28*math.cos(t),28*math.sin(t),2))
        top=Vector((6*math.cos(t),6*math.sin(t),stand_height-10))
        a.beam("Tapered tripod leg",foot,top,3,4.5,wood,.35)
        a.beam("Brass leg shoe",foot,foot+(top-foot)*.085,3.4,4.9,dark,.3)
        a.beam("Tripod spreader",(0,0,stand_height*.35),foot+(top-foot)*.35,1,1,brass,.12)
        a.sphere("Leg hinge",2.4,top,dark)
    a.lathe("Tripod head",[(0,0),(9,0),(9,2),(6,4),(6,9),(4,12),(0,12)],dark,(0,0,stand_height-13))
    a.beam("Polar axle",(-7,0,stand_height-2),(7,0,stand_height+14),3.5,3.5,brass,.6)
    a.beam("Declination axle",(0,-12,stand_height+7),(0,12,stand_height+7),2.4,2.4,brass,.5)
    a.sphere("Equatorial bearing",5,(0,0,stand_height+6),dark)
    a.beam("Counterweight shaft",(0,-10,stand_height+7),(0,-25,stand_height+7),1,1,brass,.15)
    weight=a.cylinder("Counterweight",4,5,(0,-23,stand_height+7),dark)
    weight.rotation_euler.x=math.pi/2
    tube=G.Asset(name+" optical tube",(0,0,stand_height+15)); a.add(tube.root)
    tube.root.rotation_euler.y=math.radians(90-elevation)
    r=radius; l=length
    tube.lathe("Drawn brass tube",[(0,-l*.44),(r*.57,-l*.44),(r*.65,-l*.34),(r*.75,-l*.32),
                                  (r*.9,l*.30),(r,l*.31),(r,l*.49),(r*.88,l*.5),
                                  (r*.85,l*.35),(0,l*.35)],brass,segments=64)
    for z,rr in ((-l*.32,r*.8),(-l*.1,r*.84),(l*.11,r*.92),(l*.31,r*1.03),(l*.47,r*1.03)):
        tube.lathe("Tube collar",[(rr-.2,z-.65),(rr+.23,z-.6),(rr+.23,z+.6),(rr-.2,z+.65)],dark,segments=48)
    lens=M.clear_glass(name+" crown glass",.025,1.52)
    tube.sphere("Objective lens",r*.85,(0,0,l*.38),lens,scale=(1,1,.09),subdiv=3)
    tube.cylinder("Dark optical interior",r*.79,.2,(0,0,l*.34),M.leather(name+" optical black",(.002,.003,.005)),bevel=0)
    tube.cylinder("Focuser drawtube",r*.4,l*.12,(0,0,-l*.48),dark)
    tube.lathe("Eyepiece",[(0,-l*.55),(r*.45,-l*.55),(r*.5,-l*.57),(r*.5,-l*.60),(0,-l*.60)],brass)
    for z in (-l*.15,l*.1):
        tube.beam("Finder bracket",(0,r*.7,z),(0,r*1.7,z),1,1,brass,.12)
    tube.cylinder("Finder scope",r*.25,l*.32,(0,r*1.8,0),brass)
    tube.ring("Finder rim",r*.28,.13,(0,r*1.8,l*.16),dark)
    tube.beam("Focus spindle",(-r*.5,0,-l*.37),(r*.9,0,-l*.37),.6,.6,brass,.1)
    tube.sphere("Focus wheel",r*.36,(r*.85,0,-l*.37),dark,scale=(.3,1,1))
    return a.root
