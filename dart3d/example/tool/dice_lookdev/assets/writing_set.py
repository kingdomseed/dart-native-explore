"""Embossed metal inkwell, barbed feather quill, and genuinely rolled parchment."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M


def build(name="Scholar writing set",loc=(0,0,0),rot_z=0,kind="inkwell",width=6,height=6,
          quill_length=22,metal_finish="brass",tone=(.01,.027,.065),wear=.4,seed=2) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    brass=M.metal(name+" chased metal",metal_finish,wear,seed)
    gold=M.polished_metal(name+" worn highlights",(.54,.31,.09),wear,seed,.22)
    if kind=="scroll":
        paper=M.parchment(name+" parchment",seed=seed)
        nx,ny=30,65; verts=[]; faces=[]
        for j in range(ny+1):
            v=j/ny; t=v*math.tau*1.8
            rr=1.15+.075*t
            for i in range(nx+1):
                x=(i/nx-.5)*width
                verts.append((x,math.cos(t)*rr,2+math.sin(t)*rr+.04*math.sin(x*.6)))
        faces=[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i) for j in range(ny) for i in range(nx)]
        ob=a.mesh("Spiral rolled parchment",verts,faces,paper,smooth=True)
        mod=ob.modifiers.new("Parchment thickness","SOLIDIFY");mod.thickness=.035
        tie=M.leather(name+" leather tie",(.035,.012,.006),wear,seed)
        a.ring("Scroll leather band",1.93,.13,(0,0,2),tie,plane="YZ")
        return a.root
    w=width;h=height
    a.block("Inkwell foot",(w*1.13,w*1.13,.6),(0,0,.3),brass,.22)
    a.block("Bevelled chased inkwell",(w,w,h*.73),(0,0,h*.365+.5),brass,.48)
    for side in range(4):
        face=G.Asset("Inkwell decorative face",rot_z=side*math.pi/2);a.add(face.root)
        face.tube("Inset panel border",[(-w*.37,-w*.51,1),(w*.37,-w*.51,1),
                  (w*.37,-w*.51,h*.70),(-w*.37,-w*.51,h*.70)],.07,gold,cyclic=True)
        face.tube("Embossed botanical stem",[(0,-w*.52,1.1),(0,-w*.52,h*.58)],.065,gold)
        for j in range(4):
            z=1.4+j*h*.095
            for s in (-1,1):
                face.tube("Embossed botanical leaf",[(0,-w*.52,z),(s*w*.27,-w*.54,z+.4),
                           (s*w*.31,-w*.53,z+.85),(s*w*.11,-w*.54,z+.7),(0,-w*.52,z)],.045,gold,resolution=1)
    a.lathe("Ink reservoir neck",[(0,h*.74),(w*.37,h*.74),(w*.29,h*.86),(w*.30,h),
             (w*.39,h+.15),(w*.4,h+.5),(w*.32,h+.55),(w*.28,h+.4),(w*.23,h*.85),(0,h*.85)],brass)
    ink=E.simple(name+" blue black ink",(.001,.002,.006),.09,Coat_Weight=.5)
    a.cylinder("Dark ink meniscus",w*.25,.08,(0,0,h*.9),ink,bevel=0)
    feather=M.feather(name+" feather",tone,seed)
    bone=M.ceramic(name+" cut quill shaft",(.42,.30,.17),.4,seed)
    L=quill_length
    def center(t):return (-L*.36*t, L*.07*t,h*.88+L*.93*t)
    a.tube("Curved quill rachis",[center(j/60) for j in range(61)],.08,bone)
    verts=[];faces=[]
    for i in range(41):
        t=.23+i/40*.77; cx,cy,cz=center(t)
        ww=L*.105*math.sin(math.pi*(t-.23)/.77)**.72
        for s in (-1,0,1):verts.append((cx+s*ww,cy-.09*abs(s)*math.sin(t*9),cz-s*.18*ww))
    for i in range(40):
        for j in range(2):faces.append((i*3+j,i*3+j+1,(i+1)*3+j+1,(i+1)*3+j))
    a.mesh("Curved feather vanes",verts,faces,feather,smooth=True)
    for j in range(90):
        t=.25+j/90*.73; cx,cy,cz=center(t); ww=L*.105*math.sin(math.pi*(t-.23)/.77)**.72
        for s in (-1,1):
            stop=ww*rng.uniform(.94,1.05)
            a.tube("Fine individual feather barb",[(cx,cy-.016,cz),
               (cx+s*stop*.6,cy-.075,cz+L*.015-s*.12*stop),
               (cx+s*stop,cy-.045,cz+L*.034-s*.18*stop)],.012,feather,resolution=1)
    a.lathe("Resting inkwell lid",[(0,0),(w*.42,0),(w*.44,.3),(w*.36,.7),(w*.14,1.1),(0,1.2)],brass,(w*.88,.2,0))
    return a.root
