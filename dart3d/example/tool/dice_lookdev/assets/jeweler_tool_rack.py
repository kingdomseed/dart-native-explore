"""Bench rack with staggered gravers, pivoted pliers and pear-handled gravers."""
import math
import random
import bpy
from . import geometry as G,materials as M,jeweler_tools


def build(name="Jeweler precision tool rack",loc=(0,0,0),rot_z=0,width=24,height=20,
          wood_tone=(.055,.022,.008),metal_finish="steel",wear=.7,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    wood=M.oak(name+" rack walnut",wood_tone,wear,seed)
    steel=M.machined_metal(name+" tool finish",metal_finish,wear*.5,seed)
    brass=M.machined_metal(name+" rack screws","brass",wear,seed)
    a.block("Rack foot",(width+2,7,1.5),(0,0,.75),wood,.3)
    for x in (-width*.45,width*.45):a.block("Chamfered rack upright",(2.5,1.2,height*.54),(x,2.3,height*.27),wood,.3)
    for z in (height*.3,height*.48):
        for y in (-1.95,1.95):
            a.block("Rounded retaining rail",(width,.55,1.3),(0,y,z),wood,.22)
        for x in (-width*.49,width*.49):
            a.block("Mortised rail end",(.7,4.5,1.3),(x,0,z),wood,.18)
        for x in (-width*.42,width*.42):a.sphere("Rack fixing screw",.21,(x,-2.25,z),brass,scale=(1,.2,1))
    for i in range(5):
        x=-width*.38+i*width*.13
        tool=jeweler_tools.build(name+f" graver {i}",loc=(x,0,1.5),kind="graver",length=height*rng.uniform(.8,1.1),wood_tone=wood_tone,seed=seed+i)
        a.add(tool)
    for i in range(2):
        x=width*(.28+i*.12);z=height*.6
        for side in (-1,1):
            a.tube("Curved plier handle",[(x+side*1.0,0,2),(x+side*1.1,0,z*.6),(x+side*.3,0,z)],.21,steel)
            a.beam("Tapered plier jaw",(x+side*.28,0,z),(x+side*.15,0,z+height*.25),.34,.48,steel,.07)
        pivot=a.cylinder("Riveted plier pivot",.48,.7,(x,0,z),brass);pivot.rotation_euler.x=math.pi/2
    return a.root
