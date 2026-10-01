"""Overstuffed wing chair with rolled arms, upholstered seams and turned oak feet."""
import math
import bpy
from . import geometry as G, materials as M, knit_throw


def cushion(a,name,center,half,mat,power=.42,tilt=0):
    def signed(v,p): return math.copysign(abs(v)**p,v)
    verts=[]
    for j in range(33):
        v=-math.pi/2+math.pi*j/32
        for i in range(64):
            u=math.tau*i/64
            x=half[0]*signed(math.cos(v),power)*signed(math.cos(u),power)
            y=half[1]*signed(math.cos(v),power)*signed(math.sin(u),power)
            z=half[2]*signed(math.sin(v),power)
            z+=.12*math.sin(x*.8+y*.24)*abs(math.sin(v))
            verts.append((x,y*math.cos(tilt)-z*math.sin(tilt),y*math.sin(tilt)+z*math.cos(tilt)))
    faces=[(j*64+i,j*64+(i+1)%64,(j+1)*64+(i+1)%64,(j+1)*64+i) for j in range(32) for i in range(64)]
    ob=a.mesh(name,verts,faces,mat,smooth=True);ob.location=center
    return ob


def build(name="Wing armchair",loc=(0,0,0),rot_z=0,width=89,depth=92,height=114,
          tone=(.115,.029,.015),wood_tone=(.075,.028,.009),wear=.65,seed=1,
          throw=True,throw_tone=(.16,.012,.026),pillow=True) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    hide=M.upholstery(name+" leather",tone,wear,seed)
    piping=M.leather(name+" dark piping",tuple(c*.36 for c in tone),wear,seed)
    wood=M.oak(name+" carved oak",wood_tone,wear,seed)
    brass=M.metal(name+" aged upholstery nails","brass",wear,seed)
    for x in (-31,31):
        for y in (-30,28):
            a.lathe("Turned bun foot",[(0,0),(3.5,0),(4.3,1.3),(4.1,3),(3.2,5),(2.9,7),(3.7,10),(4,14),(0,14)],wood,(x,y,0),32)
    a.block("Carved seat rail",(71,74,9),(0,-1,17),wood,1.7)
    for z in (13.5,20): a.tube("Oak rail moulding",[(-34,-38,z),(34,-38,z)],.5,wood)
    cushion(a,"Stuffed seat apron",(0,-1,27),(37,38,10),hide)
    cushion(a,"Overstuffed loose seat",(0,-7,40),(31,33,7),hide,.46)
    pts=[]
    for i in range(129):
        t=math.tau*i/128
        pts.append((31*math.copysign(abs(math.cos(t))**.4,math.cos(t)),
                    -7+33*math.copysign(abs(math.sin(t))**.4,math.sin(t)),40))
    a.tube("Seat welt seam",pts,.22,piping,True)
    cushion(a,"Reclining upholstered back",(0,28,77),(33,9,35),hide,.5,math.radians(-9))
    cushion(a,"Lumbar pad",(0,15,54),(29,8,13),hide,.62,math.radians(-8))
    for side in (-1,1):
        outline=[(side*x,z) for x,z in ((26,50),(38,51),(46,76),(46,99),(42,113),(33,114),(29,101),(29,78))]
        ob=a.extrude("Padded curved wing",outline,19,hide,y=22,bevel=5)
        for p in ob.data.polygons:p.use_smooth=True
        cushion(a,"Deep padded arm flank",(side*34,-4,43),(10,34,15),hide,.58)
        verts=[]
        for j in range(33):
            t=j/32
            y=-39+67*t
            radius=9*(.78+.22*math.sin(math.pi*t)**.3)
            for i in range(48):
                ang=math.tau*i/48
                verts.append((side*35+radius*math.cos(ang),y,59+7*t+radius*math.sin(ang)))
        faces=[(j*48+i,j*48+(i+1)%48,(j+1)*48+(i+1)%48,(j+1)*48+i) for j in range(32) for i in range(48)]
        faces.extend([tuple(reversed(range(48))),tuple(range(32*48,33*48))])
        a.mesh("Rolled leather arm",verts,faces,hide,smooth=True)
        a.ring("Arm scroll welt",6.5,.24,(side*35,-39.1,59),piping,plane="XZ")
        for i in range(16):
            t=math.tau*i/16
            a.sphere("Hand-set brass nail",.31,(side*35+6.65*math.cos(t),-39.35,59+6.65*math.sin(t)),brass,scale=(1,.48,1),subdiv=1)
        a.tube("Wing seam",[(side*30,12,60),(side*36,12,79),(side*37,12,96),(side*34,14,106)],.23,piping)
    if pillow:
        plaid=M.wool(name+" woven tartan",(.22,.085,.027),seed,plaid=True)
        cushion(a,"Soft tartan cushion",(-2,2,63),(20,7,16),plaid,.6,math.radians(-12))
    if throw:
        child=knit_throw.build(name+" wine throw",loc=(32,0,0),width=36,tone=throw_tone,seed=seed)
        a.add(child)
    a.root.scale=(width/92,depth/92,height/114)
    return a.root
