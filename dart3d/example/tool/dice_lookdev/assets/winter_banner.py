"""Hanging woven banner with a pointed hem and stitched, unlettered snowflake motifs."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Winter sanctuary banner",loc=(0,0,0),rot_z=0,width=40,height=105,
          tone=(.009,.028,.085),metal_tone=(.42,.26,.10),wear=.5,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    cloth=M.velvet(name+" woven wool",tone,wear,seed)
    gold=M.polished_metal(name+" gold embroidery",metal_tone,wear,seed,.42)
    def pos(u,v):
        return (u*width/2,1.4*math.sin(u*8+v*3+seed)+.5*math.sin(v*9),
                -v*height+max(0,v-.80)/.20*height*.12*abs(u))
    nx,ny=32,42
    verts=[pos(i/nx*2-1,j/ny) for j in range(ny+1) for i in range(nx+1)]
    ob=a.mesh("Woven pointed cloth",verts,[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i)
                  for j in range(ny) for i in range(nx)],cloth,smooth=True)
    mod=ob.modifiers.new("Cloth weight","SOLIDIFY");mod.thickness=.12
    for u in (-.93,.93):
        a.tube("Gold edge stitching",[(x,y-.13,z) for x,y,z in (pos(u,j/100) for j in range(101))],.09,gold)
    a.tube("Pointed hem trim",[(x,y-.13,z) for x,y,z in (pos(-.93+j*.0186,.98) for j in range(101))],.11,gold)
    for v0,r in ((.26,width*.30),(.66,width*.24)):
        for j in range(6):
            t=j*math.tau/6
            def point(rad,angle):
                u=rad*math.cos(angle)*2/width;v=v0-rad*math.sin(angle)/height
                x,y,z=pos(u,v);return (x,y-.17,z)
            a.tube("Sixfold stitched snow star",[point(r*k/24,t) for k in range(25)],.13,gold)
            for q in (.5,.76):
                bx,bz=r*q*math.cos(t),r*q*math.sin(t)
                for sign in (-1,1):
                    ex=bx+r*.23*math.cos(t+sign*.82);ez=bz+r*.23*math.sin(t+sign*.82)
                    pts=[]
                    for k in range(13):
                        q=k/12;x=bx*(1-q)+ex*q;z=bz*(1-q)+ez*q
                        px,py,pz=pos(x*2/width,v0-z/height);pts.append((px,py-.17,pz))
                    a.tube("Branch embroidery",pts,.09,gold)
    a.beam("Banner crossbar",(-width*.60,0,2),(width*.60,0,2),1.3,1.3,gold,.3)
    for x in (-width*.60,width*.60):a.sphere("Crossbar finial",1.7,(x,0,2),gold,subdiv=2)
    return a.root
