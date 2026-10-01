"""Unlettered star charts, brass rete disks, magnifiers and pierced incense vessels."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M


def build(name="Astronomer instrument",loc=(0,0,0),rot_z=0,kind="astrolabe",radius=7,
          width=19,depth=25,metal_tone=(.56,.33,.10),wear=.35,seed=2) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z); rng=random.Random(seed)
    brass=M.polished_metal(name+" brass",metal_tone,wear,seed,.23)
    ink=E.simple(name+" aged ink",(.025,.032,.048),.85)
    if kind=="chart":
        parchment,k=E.material(name+" parchment")
        n=k.noise(k.coords().outputs["Object"],.3,3).outputs["Fac"]
        k.surface(k.bsdf(Base_Color=k.ramp(n,[(.2,(.22,.16,.085)),(.8,(.51,.4,.24))]),Roughness=.84))
        def pos(x,y):return (x,y,.06+.42*(abs(x)/(width/2))**8+.10*math.sin(y*.3))
        nx,ny=24,32
        verts=[pos((i/nx-.5)*width,(j/ny-.5)*depth) for j in range(ny+1) for i in range(nx+1)]
        a.mesh("Curled parchment chart",verts,[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i) for j in range(ny) for i in range(nx)],parchment,smooth=True)
        r=min(width,depth)*.4
        for rr in (r,r*.92,r*.65,r*.35):
            a.tube("Chart orbit",[(x,y,z+.02) for x,y,z in (pos(rr*math.cos(t*math.tau/128),rr*math.sin(t*math.tau/128)) for t in range(128))],.018,ink,cyclic=True)
        for c in range(8):
            cx,cy=rng.uniform(-r*.75,r*.75),rng.uniform(-r*.75,r*.75)
            pts=[]
            for j in range(4):
                x,y,z=pos(cx+rng.uniform(-1.8,1.8),cy+rng.uniform(-1.8,1.8))
                pts.append((x,y,z+.03));a.sphere("Chart star dot",.09,(x,y,z+.03),ink,scale=(1,1,.3),subdiv=1)
            a.tube("Chart constellation line",pts,.021,ink)
    elif kind=="magnifier":
        a.lathe("Magnifying glass rim",[(radius-.35,0),(radius+.12,0),(radius+.22,.25),
                                       (radius+.12,.55),(radius-.35,.55),(radius-.35,0)],brass,segments=64)
        a.sphere("Convex magnifying lens",radius-.32,(0,0,.24),M.clear_glass(name+" lens",.02,1.48),scale=(1,1,.055),subdiv=4)
        a.beam("Magnifier handle",(0,-radius,.26),(0,-radius*2.7,.26),.85,.7,brass,.3)
        a.sphere("Handle knop",.65,(0,-radius*2.7,.26),brass,scale=(.8,1,.6))
    elif kind=="incense":
        r=radius
        a.lathe("Incense cup",[(0,0),(r*.6,0),(r*.65,.4),(r*.45,.8),(r*.8,1.3),(r,2.3),
                              (r,3.1),(r*.92,3.1),(r*.86,2.3),(r*.4,1.4),(0,1.4)],brass)
        verts=[]; faces=[]
        for j in range(13):
            t=j/12; rr=r*(1-.8*t**1.45); z=3.1+2.1*t
            verts += [(rr*math.cos(i*math.tau/96),rr*math.sin(i*math.tau/96),z) for i in range(96)]
        for j in range(12):
            for i in range(96):
                if 3<=j<=7 and i%4 in (1,2): continue
                faces.append((j*96+i,j*96+(i+1)%96,(j+1)*96+(i+1)%96,(j+1)*96+i))
        lid=a.mesh("Pierced incense lid",verts,faces,brass,smooth=True)
        mod=lid.modifiers.new("Brass lid thickness","SOLIDIFY");mod.thickness=.07
        a.lathe("Lid finial",[(.3,5.1),(.45,5.4),(.38,5.8),(0,6.2)],brass)
        for x in (-1,1):a.ring("Incense handle",r*.45,.16,(x*r,0,2.3),brass,plane="XZ")
    else:
        a.cylinder("Astrolabe body",radius,.4,(0,0,.2),brass,segments=96,bevel=.1)
        a.cylinder("Recessed enamel face",radius*.91,.1,(0,0,.43),E.simple(name+" enamel",(.007,.018,.032),.3),segments=96)
        for rr in (radius*.94,radius*.85,radius*.61,radius*.32):a.ring("Engraved rete ring",rr,.045,(0,0,.51),brass,segments=96)
        for i in range(120):
            t=i*math.tau/120; ri=radius*(.77 if i%5==0 else .81)
            a.tube("Astrolabe graduation",[(ri*math.cos(t),ri*math.sin(t),.51),(radius*.86*math.cos(t),radius*.86*math.sin(t),.51)],.021,brass)
        for i in range(12):
            t=math.tau*i/12
            a.tube("Rete curved pointer",[(radius*.61*math.cos(t),radius*.61*math.sin(t),.55),
                                          (radius*.46*math.cos(t+.3),radius*.46*math.sin(t+.3),.55),
                                          (radius*.32*math.cos(t+.12),radius*.32*math.sin(t+.12),.55)],.06,brass)
        a.beam("Rotating alidade",(-radius*.77,-radius*.28,.7),(radius*.77,radius*.28,.7),.3,.24,brass,.07)
        a.sphere("Alidade rivet",.24,(0,0,.85),brass)
        a.ring("Astrolabe suspension loop",radius*.17,.2,(0,radius*1.09,.22),brass)
    return a.root
