"""Pegged tavern chair or stool: scooped seat, turned legs and bowed back rails."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Tavern chair",loc=(0,0,0),rot_z=0,width=43,depth=43,seat_height=45,
          height=94,back=True,wood_tone=(.12,.052,.018),wear=.7,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    wood=M.oak(name+" seat oak",wood_tone,wear,seed,grain_scale=1.7)
    upright=M.oak(name+" upright grain",wood_tone,wear,seed+1,axis="Z")
    peg=M.oak(name+" dark end grain",tuple(c*.55 for c in wood_tone),wear,seed+2)
    nx=24;ny=24;verts=[]
    for j in range(ny+1):
        v=-1+2*j/ny
        for i in range(nx+1):
            u=-1+2*i/nx
            x=u*width/2*(1-.07*v);y=v*depth/2
            z=seat_height-1.25*(1-u*u)*(1-v*v)
            verts.append((x,y,z))
    faces=[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i) for j in range(ny) for i in range(nx)]
    seat=a.mesh("Saddled solid oak seat",verts,faces,wood,smooth=True)
    sol=seat.modifiers.new("Thick seat board","SOLIDIFY");sol.thickness=4
    bevel=seat.modifiers.new("Rubbed seat edge","BEVEL");bevel.width=.8;bevel.segments=3
    for x in (-width*.36,width*.36):
        for y in (-depth*.34,depth*.34):
            profile=[(0,0),(2.4,0),(2.7,1),(2.2,4),(1.6,12),(2.3,16),(2.8,19),(2.4,22),(1.8,28),(2.3,seat_height-5),(2.3,seat_height-3),(0,seat_height-3)]
            a.lathe("Turned chair leg",profile,upright,(x,y,0),segments=24)
        a.beam("Side mortised stretcher",(x,-depth*.34,17),(x,depth*.34,17),2.6,2.6,wood,.5)
    a.beam("Front worn foot rail",(-width*.36,-depth*.34,15),(width*.36,-depth*.34,15),3,3,wood,.5)
    a.beam("Rear stretcher",(-width*.36,depth*.34,20),(width*.36,depth*.34,20),2.6,2.6,wood,.5)
    if back:
        for side in (-1,1):
            x=side*width*.37
            a.beam("Leaning back stile",(x,depth*.35,seat_height-4),(x,depth*.47,height),4,4,upright,.75)
            a.sphere("Turned stile finial",2.6,(x,depth*.47,height),upright,scale=(1,1,1.25))
        for z,h in ((height-8,10),(height-25,7)):
            pts=[(-width*.40+i*width*.8/24,depth*.46+1.8*math.cos(math.pi*(-.5+i/24)),z) for i in range(25)]
            verts=[(x,y+dy,zz+dz) for x,y,zz in pts for dy,dz in ((-1.4,-h/2),(1.4,-h/2),(1.4,h/2),(-1.4,h/2))]
            faces=[(i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j) for i in range(24) for j in range(4)]
            faces.extend([(3,2,1,0),(96,97,98,99)])
            a.mesh("Bowed oak back rail",verts,faces,wood,bevel=.6)
        for x in (-width*.36,width*.36):
            for z in (height-8,height-25):
                pin=a.cylinder("Visible oak joint peg",.5,.5,(x,depth*.45-1.8,z),peg)
                pin.rotation_euler.x=math.pi/2
    return a.root
