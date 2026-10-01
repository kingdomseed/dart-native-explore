"""Joinered andon and ribbed chochin lanterns; origins at the foot/bottom cap."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Paper lantern",loc=(0,0,0),rot_z=0,kind="andon",height=85,radius=15,
          tone=(.9,.57,.25),wood_tone=(.025,.012,.006),glow=1.1,energy=6500,
          wear=.3,seed=1,drop=35) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    wood=M.oak(name+" lacquered cedar",wood_tone,wear,seed,axis="Z")
    paper=M.washi(name+" mulberry paper",tone,glow,seed)
    brass=M.metal(name+" fastenings","brass",wear,seed)
    if kind=="andon":
        bottom,top=height*.22,height*.93
        r=radius*.84
        for x in (-r,r):
            for y in (-r,r):
                a.block("Chamfered corner stile",(1.65,1.65,height),(x,y,height/2),wood,.18)
                a.cylinder("Joinery peg",.19,.07,(x,y,height*.18),brass,segments=12)
        for z in (bottom,top):
            a.block("Lantern sill",(r*2+2,r*2+2,2.2),(0,0,z),wood,.25)
        for side in (-1,1):
            for axis in (0,1):
                points=[(-r,-r,bottom+1), (r,-r,bottom+1),(r,-r,top-1),(-r,-r,top-1)]
                points=[(x,-side*r,z) if axis==0 else (-side*r,x,z) for x,y,z in points]
                ob=a.mesh("Stretched translucent washi",points,[(0,1,2,3)],paper)
                ob.visible_shadow=False
                for f in (.25,.5,.75):
                    u=-r+2*r*f
                    center=(u,-side*(r+.1),(bottom+top)/2) if axis==0 else (-side*(r+.1),u,(bottom+top)/2)
                    a.block("Fine bamboo paper batten",(.32,.32,top-bottom),center,wood,.04)
                for z in (bottom+4,top-4):
                    size=(r*2,.35,.35) if axis==0 else (.35,r*2,.35)
                    center=(0,-side*(r+.13),z) if axis==0 else (-side*(r+.13),0,z)
                    a.block("Horizontal bamboo batten",size,center,wood,.04)
        a.block("Lipped oil pan",(r*1.2,r*1.2,1.4),(0,0,bottom+1.7),brass,.4)
        center=(0,0,(bottom+top)/2)
        a.tube("Carrying handle",[(-r*.45,0,height),(-r*.45,0,height+4),(r*.45,0,height+4),(r*.45,0,height)],.36,wood)
    else:
        def rad(t):return radius*(.52+.48*math.sin(math.pi*t)**.65)
        profile=[(rad(i/48),height*i/48) for i in range(49)]
        ob=a.lathe("Continuous pleated paper shell",profile,paper,segments=64)
        ob.visible_shadow=False
        for i in range(39):
            t=(i+.5)/39
            a.ring("Bamboo spiral rib",rad(t)+.03,.085,(0,0,height*t),wood,segments=64)
        for z in (0,height):
            a.lathe("Rolled end collar",[(radius*.49,z-.2),(radius*.56,z),(radius*.56,z+1.4),(radius*.49,z+1.6)],wood)
        a.ring("Suspension loop",2,.22,(0,0,height+3),brass,plane="XZ")
        a.tube("Hanging silk cord",[(0,0,height+5),(0,0,height+drop)],.24,wood)
        center=(0,0,height*.5)
    a.light("Paper lantern warm pool",center,energy,(1,.58,.26) if tone[1]>.3 else (1,.19,.055),radius*.5)
    return a.root
