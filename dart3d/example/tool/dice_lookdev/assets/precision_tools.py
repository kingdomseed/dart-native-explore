"""Resting steel calipers, hinged dividers and a turned wooden-handled screwdriver."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Precision workshop tool",loc=(0,0,0),rot_z=0,kind="caliper",length=18,
          opening=3.5,wood_tone=(.065,.025,.008),metal_finish="steel",wear=.55,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    steel=M.machined_metal(name+" steel",metal_finish,wear,seed)
    brass=M.machined_metal(name+" brass","brass",wear,seed)
    if kind=="dividers":
        for side in (-1,1):
            tip=side*opening/2
            leg=a.mesh("Forged tapering divider leg",[(side*.35,0,.28),(side*.75,-length*.22,.28),
                     (tip,-length,.28),(tip-side*.28,-length*.79,.28)],[(0,1,2,3)],steel,bevel=.035)
            leg.modifiers.new("Forged leg thickness","SOLIDIFY").thickness=.2
            a.tube("Divider raised spine",[(side*.35,0,.31),(side*.65,-length*.22,.31),(tip,-length*.87,.31)],.16,steel)
        a.cylinder("Divider pivot",.75,.62,(0,0,.34),brass,segments=32)
        a.beam("Divider adjustment screw",(-opening*.4,-length*.42,.65),(opening*.4,-length*.42,.65),.22,.22,steel,.05)
        nut=a.cylinder("Divider knurled nut",.48,.45,(opening*.35,-length*.42,.65),brass,segments=16)
        nut.rotation_euler.y=math.pi/2
    elif kind=="pencil":
        wood=M.oak(name+" cedar",wood_tone,wear*.3,seed,axis="Z")
        paint=M.leather(name+" worn painted barrel",(.11,.055,.018),wear,seed)
        graphite=M.machined_metal(name+" graphite","iron",.7,seed)
        span=length-2.2
        verts=[(.32*math.cos(j*math.tau/6),span*(i/24-.5),.29+.32*math.sin(j*math.tau/6))
               for i in range(25) for j in range(6)]
        faces=[(i*6+j,i*6+(j+1)%6,(i+1)*6+(j+1)%6,(i+1)*6+j)
               for i in range(24) for j in range(6)]
        faces.extend((tuple(reversed(range(6))),tuple(range(144,150))))
        a.mesh("Hexagonal drafting pencil",verts,faces,paint,bevel=.018)
        tip=a.cylinder("Exposed sharpened cedar",.32,1.8,(0,-length/2+.2,.29),wood,segments=6,r2=.075,bevel=.015)
        tip.rotation_euler.x=math.pi/2
        lead=a.cylinder("Graphite point",.075,.40,(0,-length/2-.9,.29),graphite,segments=12,r2=0,bevel=0)
        lead.rotation_euler.x=math.pi/2
    elif kind=="screwdriver":
        wood=M.oak(name+" worn handle",wood_tone,wear,seed,axis="Z")
        handle=a.lathe("Turned wooden tool handle",[(0,0),(.6,0),(1,.5),(1.1,1.7),(.95,length*.35),(.7,length*.42),(0,length*.42)],wood,segments=40)
        handle.rotation_euler.x=math.pi/2;handle.location.z=1.1
        a.beam("Screwdriver shaft",(0,0,1.1),(0,length*.55,.15),.43,.43,steel,.1)
        a.block("Ground screwdriver blade",(.65,length*.13,.18),(0,length*.6,.10),steel,.07)
        collar=a.cylinder("Brass handle ferrule",.74,1,(0,0,1.1),brass,segments=32);collar.rotation_euler.x=math.pi/2
    else:
        a.block("Caliper graduated beam",(1.3,length,.4),(0,0,.2),steel,.08)
        for y in (-length*.43,-length*.43+opening):
            a.block("Caliper cross head",(2.1,1.2,.75),(-.05,y,.375),brass if y>-length*.43 else steel,.15)
            jaw=a.mesh("Curved caliper jaw",[(-.4,y-.5,.45),(-3.8,y-.5,.45),(-4.7,y-.1,.45),
                       (-3.1,y+.35,.45),(-.4,y+.55,.45)],[(0,1,2,3,4)],steel,bevel=.07)
            jaw.modifiers.new("Ground jaw thickness","SOLIDIFY").thickness=.4
        for i in range(31):
            y=-length*.34+i*length*.023
            a.tube("Caliper scale tick",[(-.5,y,.565),(-.1 if i%5 else .3,y,.565)],.012,brass,resolution=1)
        a.cylinder("Slider lock screw",.44,.5,(.30,-length*.43+opening,.95),brass,segments=16)
    return a.root
