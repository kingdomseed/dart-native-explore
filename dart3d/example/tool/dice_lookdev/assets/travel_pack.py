"""Weathered canvas rucksack, sewn bellows pocket, buckled hide straps and rolled wool."""
import math
import bpy
from . import geometry as G, materials as M, vessel
from .wing_armchair import cushion


def build(name="Wayfarer pack",loc=(0,0,0),rot_z=0,width=36,depth=23,height=48,
          tone=(.135,.12,.072),leather_tone=(.10,.033,.012),roll_tone=(.055,.071,.036),
          wear=.75,seed=1,bedroll=True,cup=True,buckle_height=.38,cup_height=.17) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    canvas=M.canvas(name+" canvas",tone,wear,seed)
    hide=M.leather(name+" saddle hide",leather_tone,wear,seed)
    thread=M.wool(name+" waxed linen",(.28,.19,.105),seed)
    brass=M.metal(name+" strap fittings","brass",wear,seed)
    dark=M.leather(name+" punched holes",(.012,.009,.006),wear,seed)
    body=cushion(a,"Soft loaded canvas body",(0,0,height*.45),(width/2,depth/2,height*.45),canvas,.43)
    body.data.materials.append(hide)
    for poly in body.data.polygons:
        if sum(body.data.vertices[i].co.z for i in poly.vertices)/len(poly.vertices)+height*.45<height*.19:poly.material_index=1
    pocket=cushion(a,"Expanding front bellows pocket",(0,-depth/2-1.2,height*.29),(width*.36,3.5,height*.20),canvas,.48)
    for side in (-1,1):
        a.tube("Pocket sewn gusset",[(side*width*.32,-depth/2-3,height*.10),(side*width*.37,-depth/2-3.4,height*.27),(side*width*.32,-depth/2-3,height*.47)],.15,hide)
    flap_path=[(depth*.44,height*.86),(depth*.25,height*.99),(0,height*1.01),(-depth*.44,height*.92),(-depth*.59,height*.68),(-depth*.62,height*.58)]
    def ribbon(label,path,x,w,mat):
        verts=[(x+side*w/2,y,z) for y,z in path for side in (-1,1)]
        faces=[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(path)-1)]
        ob=a.mesh(label,verts,faces,mat,smooth=True)
        sol=ob.modifiers.new("Worked leather thickness","SOLIDIFY");sol.thickness=.22
        bevel=ob.modifiers.new("Soft hide edges","BEVEL");bevel.width=.12;bevel.segments=2
        return ob
    verts=[]
    for j,(y,z) in enumerate(flap_path):
        for i in range(33):
            u=-1+2*i/32
            verts.append((u*width*.5*(1-.13*j/5),y-.6*math.cos(u*math.pi),z-.8*u*u+.3*math.cos(u*9)))
    faces=[(j*33+i,j*33+i+1,(j+1)*33+i+1,(j+1)*33+i) for j in range(5) for i in range(32)]
    flap=a.mesh("Curved leather storm flap",verts,faces,hide,smooth=True)
    sol=flap.modifiers.new("Flap hide thickness","SOLIDIFY");sol.thickness=.28
    for side in (-1,1):
        x=side*width*.26
        path=[(-depth*.73,height*.11),(-depth*.75,height*.37),(-depth*.64,height*.61),(-depth*.51,height*.87),(0,height*1.025),(depth*.40,height*.9)]
        ribbon("Load strap",path,x,3.0,hide)
        z=height*buckle_height
        strap_depth=.75 if buckle_height<=.37 else .75-(buckle_height-.37)*.46
        y=-depth*strap_depth-.25
        a.tube("Rounded buckle frame",[(x-1.9,y,z-2),(x+1.9,y,z-2),(x+1.9,y,z+2),(x-1.9,y,z+2)],.25,brass,cyclic=True)
        a.tube("Buckle tongue",[(x,y-.1,z-1.8),(x,y-.3,z+.6)],.14,brass)
        for h in (.16,.21,.26,.31):
            a.sphere("Strap adjustment hole",.18,(x,-depth*.75-.16,height*h),dark,scale=(1,.2,1),subdiv=1)
        for h in range(12):
            zz=height*(.18+h*.052)
            yst=-depth*(.75 if zz<height*.38 else .75-(zz/height-.38)*.42)-.26
            for dx in (-1.16,1.16):a.tube("Hand saddle stitch",[(x+dx,yst,zz),(x+dx,yst,zz+.5)],.045,thread,resolution=1)
        ribbon("Padded shoulder loop",[(depth*.38,height*.84),(depth*.8,height*.61),(depth*.86,height*.28),(depth*.41,height*.14)],side*width*.30,4.1,hide)
    a.tube("Pack carry handle",[(-5,depth*.35,height*.90),(-5,depth*.43,height*1.08),(5,depth*.43,height*1.08),(5,depth*.35,height*.90)],.65,hide)
    if bedroll:
        wool=M.wool(name+" rolled blanket",roll_tone,seed)
        rr=height*.15;zc=height+rr*.90;n=280;verts=[];turns=4.2
        for i in range(n+1):
            f=i/n;t=f*math.tau*turns;r=rr*(.14+.86*f)
            for x in (-width*.60,width*.60):verts.append((x,2+r*math.cos(t),zc+r*math.sin(t)))
        faces=[(i*2,i*2+1,i*2+3,i*2+2) for i in range(n)]
        roll=a.mesh("Spirally rolled wool layers",verts,faces,wool,smooth=True)
        sol=roll.modifiers.new("Blanket thickness","SOLIDIFY");sol.thickness=.26
        for x in (-width*.6,width*.6):
            a.tube("Worn spiral end selvedge",[(x,2+rr*(.14+.86*i/n)*math.cos(i/n*math.tau*turns),zc+rr*(.14+.86*i/n)*math.sin(i/n*math.tau*turns)) for i in range(n+1)],.14,wool,resolution=1)
        for x in (-width*.28,width*.28):
            path=[(2+(rr+.25)*math.cos(i*math.tau/64),zc+(rr+.25)*math.sin(i*math.tau/64)) for i in range(65)]
            ribbon("Bedroll cinch",path,x,2.5,hide)
    if cup:
        x=width*.58;y=-depth*.55;z=height*cup_height
        child=vessel.build(name+" hanging pewter cup",loc=(x,y,z),rot_z=math.pi,kind="tankard",height=9,radius=3.5,metal_finish="pewter",seed=seed)
        child.rotation_euler.y=-.12;a.add(child)
        anchor=(width*.45,-depth*.55,height*(cup_height+.26))
        if bedroll and cup_height>.65:
            anchor=(width*.28,2-(rr+.25)*.6,zc+(rr+.25)*.8)
        a.tube("Cup suspension thong",[anchor,(x-4.5,y,height*(cup_height+.20)),(x-4.5,y,height*(cup_height+.12))],.23,hide)
    return a.root
