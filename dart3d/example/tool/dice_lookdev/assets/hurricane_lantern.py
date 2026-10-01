"""Pressed tin oil lantern with a hollow globe, bowed guards, burner and bail."""
import math
import bpy
import env_common as E
from . import geometry as G, materials as M
from .forge import fire_tongue


def build(name="Road lantern",loc=(0,0,0),rot_z=0,height=32,radius=8,
          metal_finish="pewter",wear=.7,seed=1,energy=6500,glass_tone=(.93,.86,.68)) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);s=height/32;r=radius/8
    tin=M.metal(name+" worn tin",metal_finish,wear,seed)
    dark=M.metal(name+" burner iron","iron",wear,seed)
    brass=M.metal(name+" burner brass","brass",wear,seed)
    a.lathe("Pressed fuel reservoir",[(rr*r,z*s) for rr,z in ((0,0),(6,0),(7.8,.5),(8,1.2),(7.3,1.7),(6.6,2),(6.6,3.7),(5.7,5),(3.6,5.5),(0,5.5))],tin,segments=64)
    for z,rr in ((1.15,7.8),(4.8,5.8),(25.3,5.1),(27.4,5.5)):
        a.ring("Rolled tin bead",rr*r,.16*s,(0,0,z*s),tin)
    a.lathe("Perforated burner",[(0,5*s),(2.2*r,5*s),(2.4*r,6*s),(2.4*r,6.6*s),(1.8*r,7*s),(0,7*s)],brass)
    for i in range(16):
        t=i*math.tau/16
        a.block("Burner air slot",(.25,.4,.55),(2.36*r*math.cos(t),2.36*r*math.sin(t),6.4*s),dark,.1).rotation_euler.z=t
    a.cylinder("Cotton wick",.5*r,1*s,(0,0,7.2*s),E.simple(name+" charred wick",(.009,.006,.003),.9))
    glass,k=E.material(name+" clear chimney")
    pane=k.bsdf(Base_Color=(*glass_tone,1),Roughness=.085,Transmission_Weight=1,IOR=1.46)
    tr=k.node("ShaderNodeBsdfTransparent").outputs[0]
    k.surface(k.mix_shader(.20,tr,pane))
    profile=[(3.2,6.8),(4.8,7.7),(5.2,10),(5.0,14),(4.3,20),(3.7,23.6),(3.5,23.7),(4.1,20),(4.8,14),(5.0,10),(4.6,7.9),(3.0,7)]
    a.lathe("Bulged glass chimney",[(rr*r,z*s) for rr,z in profile],glass,segments=64)
    flame=M.flame(name+" oil flame",18)
    fire_tongue(a,"Oil wick flame",(0,0,7.6*s),.8*r,8*s,flame,lean=.65*r)
    a.lathe("Spun ventilator cap",[(rr*r,z*s) for rr,z in ((3.8,23),(5.2,23.6),(5.6,24.2),(5.2,25.2),(4.5,25.5),(4.3,27),(5.4,27.2),(5.5,28),(4.7,28.6),(2.9,29.5),(2.7,30.7),(0,30.7))],tin,segments=64)
    for side in (-1,1):
        pts=[(side*x*r,0,z*s) for x,z in ((6.2,3.5),(8.7,6),(9,11),(8.6,22),(7.2,27),(5.0,28))]
        a.tube("Hollow curved air tube",pts,.63*r,tin,resolution=3)
        for yy in (-1,1):
            a.tube("Crossed globe guard",[(side*4.5*r,yy*2.6*r,8*s),(0,yy*5.05*r,14*s),(-side*3.7*r,yy*2.7*r,22*s)],.15*r,dark)
        a.sphere("Bail hinge",.65*r,(side*7*r,0,27*s),brass,scale=(1,.6,1))
    for z,rr,outer in ((8,5.2,8.8),(22,4.6,8.6)):
        a.ring("Globe guard support hoop",rr*r,.16*r,(0,0,z*s),dark)
        for side in (-1,1):a.beam("Guard hoop lug",(side*rr*r,0,z*s),(side*outer*r,0,z*s),.35,.35,tin,.08)
    bail=[(7*r*math.cos(t),0,(27+6.4*math.sin(t))*s) for t in (math.pi*i/40 for i in range(41))]
    a.tube("Swinging wire bail",bail,.3*r,dark,resolution=3)
    a.cylinder("Filler cap",1.1*r,.7*s,(4.9*r,0,4.9*s),tin,bevel=.12)
    wheel=a.cylinder("Wick adjuster",.9*r,.3*r,(3*r,-1.7*r,6*s),brass,segments=20)
    wheel.rotation_euler.x=math.pi/2
    a.light("Oil lantern glow",(0,0,11*s),energy,(1,.58,.22),size=2.5*s)
    return a.root
