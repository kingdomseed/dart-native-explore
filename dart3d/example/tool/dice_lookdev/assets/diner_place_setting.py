"""Small counter service: dished saucer, formed teaspoon, folded napkin and blank sugar sachets."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Counter service",loc=(0,0,0),rot_z=0,radius=5,napkin=True,packets=2,
          tone=(.62,.57,.44),metal_tone=(.61,.65,.68),wear=.35,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);s=radius/5
    ceramic=M.ceramic(name+" saucer glaze",tone,wear,seed)
    steel=M.polished_metal(name+" teaspoon",metal_tone,wear,seed)
    cloth=M.canvas(name+" cotton napkin",(.45,.43,.38),.15,seed)
    paper=M.parchment(name+" unprinted sugar paper",(.62,.57,.44),seed)
    a.lathe("Dished coffee saucer",[(0,.18),(2.4,.18),(2.6,0),(3,0),(3.1,.2),(4.2,.45),(5,.9),
             (5.05,1.03),(4.95,1.13),(4.4,.83),(3.8,.58),(2.5,.39),(0,.39)],ceramic,segments=64).scale=(s,s,s)
    bowl=[];faces=[];rings=12;seg=32
    for j in range(rings+1):
        r=j/rings
        for i in range(seg):
            t=i*math.tau/seg
            bowl.append((s*(-1.2+1.1*r*math.cos(t)),s*(1.4*r*math.sin(t)),s*(.42+.48*r*r)))
    for j in range(rings):
        for i in range(seg):faces.append((j*seg+i,j*seg+(i+1)%seg,(j+1)*seg+(i+1)%seg,(j+1)*seg+i))
    spoon=a.mesh("Pressed teaspoon bowl",bowl,faces,steel,smooth=True)
    mod=spoon.modifiers.new("Fine silver thickness","SOLIDIFY");mod.thickness=.065*s
    handle=[(-.18,.13,.83),(.8,.12,.78),(2,.14,.91),(3.5,.24,1.15),(5.1,.33,1.15),(5.4,0,1.15),
            (5.1,-.33,1.15),(3.5,-.24,1.15),(2,-.14,.91),(.8,-.12,.78),(-.18,-.13,.83)]
    n=len(handle)
    a.mesh("Flattened spoon handle",[(x*s,y*s,(z+dz)*s) for dz in (0,.10) for x,y,z in handle],
           [tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],steel,bevel=.065*s,smooth=True)
    if napkin:
        nx,ny=18,14;v=[]
        for j in range(ny+1):
            y=j/ny
            for i in range(nx+1):
                x=i/nx;v.append((s*(-12+7*x),s*(-4+8*y),s*(.16+.10*math.sin(x*math.pi)+.035*math.sin(y*12))))
        f=[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i) for j in range(ny) for i in range(nx)]
        ob=a.mesh("Folded cotton napkin",v,f,cloth,smooth=True)
        mod=ob.modifiers.new("Four folded cotton layers","SOLIDIFY");mod.thickness=.12*s
        for y in (-3.8,3.8):a.tube("Turned stitched napkin hem",[(-11.8*s,y*s,.22*s),(-5.2*s,y*s,.22*s)],.045*s,cloth)
    for k in range(packets):
        cx,cy=(-8.7+k*2.7)*s,(k*.7)*s;nx,ny=12,16;v=[]
        for side in (-1,1):
            for j in range(ny+1):
                y=j/ny
                for i in range(nx+1):
                    x=i/nx;bulge=.15*math.sin(math.pi*x)*math.sin(math.pi*y)
                    v.append((cx+(x-.5)*2.3*s,cy+(y-.5)*4.5*s,(.46+side*(.025+bulge))*s))
        n=(nx+1)*(ny+1);f=[]
        for side in (0,1):
            for j in range(ny):
                for i in range(nx):
                    q=side*n+j*(nx+1)+i;f.append((q,q+1,q+nx+2,q+nx+1))
        edge=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
        f += [(edge[i],edge[(i+1)%len(edge)],edge[(i+1)%len(edge)]+n,edge[i]+n) for i in range(len(edge))]
        a.mesh("Blank sealed sugar sachet",v,f,paper,smooth=True)
        for y in (-2.1,2.1):a.tube("Crimped packet seal",[(cx-1.05*s,cy+y*s,.49*s),(cx+1.05*s,cy+y*s,.49*s)],.025*s,paper)
    return a.root
