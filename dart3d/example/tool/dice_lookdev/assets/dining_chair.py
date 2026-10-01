"""Bent plywood kitchen chair with scooped seat, bowed back and splayed beech legs."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Bentwood chair",loc=(0,0,0),rot_z=0,width=44,depth=43,seat_height=45,height=80,
          wood_tone=(.19,.078,.018),wear=.45,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);w,d=width,depth
    wood=M.wood_laminate(name+" figured veneer",wood_tone,wear,seed)
    legs=M.oak(name+" beech",wood_tone,wear,seed,axis="Z",grain_scale=2)
    for x in (-w*.36,w*.36):
        for y in (-d*.34,d*.34):
            a.beam("Splayed beech leg",(x*1.14,y*1.13,0),(x,y,seat_height-2),3,3.5,legs,.55)
        a.beam("Side stretcher",(x,-d*.37,22),(x,d*.37,22),2,2,legs,.4)
        a.beam("Rising back stile",(x,d*.34,seat_height-6),(x*.97,d*.47,height-2),2.8,3.8,legs,.55)
    def shell(label,back=False):
        verts=[];nx,ny=32,18
        for j in range(ny+1):
            v=j/ny
            for i in range(nx+1):
                u=i/nx*2-1
                if back:
                    verts.append((u*w*.47,(d*.44+2.5*u*u)+v*2,seat_height+13+v*(height-seat_height-14)-2.5*u*u))
                else:verts.append((u*w*.49, (v-.5)*d*.97,seat_height-1.5*(1-u*u)*math.sin(v*math.pi)))
        faces=[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i) for j in range(ny) for i in range(nx)]
        ob=a.mesh(label,verts,faces,wood,smooth=True)
        mod=ob.modifiers.new("Laminated plywood thickness","SOLIDIFY");mod.thickness=1.4
        mod=ob.modifiers.new("Rounded plywood edge","BEVEL");mod.width=.55;mod.segments=3
    shell("Scooped veneer seat");shell("Bowed veneer back",True)
    return a.root
