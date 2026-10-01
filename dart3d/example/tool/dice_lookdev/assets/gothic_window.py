"""Pointed stone reveal, intersecting lancet tracery and a layered moonlit town."""
import math
import bpy
import env_common as E
from . import geometry as G, materials as M
from .night_vista import citadel, cloud


def pointed(width, spring, base=0, samples=32):
    r=width/2
    left=[(r+2*r*math.cos(math.pi-j*math.pi/3/samples),spring+2*r*math.sin(math.pi-j*math.pi/3/samples)) for j in range(samples+1)]
    right=[(-x,z) for x,z in reversed(left[:-1])]
    return [(-r,base)]+left+right+[(r,base)]


def build(name="Gothic study window",loc=(0,0,0),rot_z=0,width=132,height=210,reveal=18,
          stone_tone=(.10,.085,.065),wear=.5,seed=7,energy=85000,
          sky_strength=1.7,moon_strength=2.0,exterior_slope=.4,moon_offset=.55) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);w=width;r=w/2
    spring=height-math.sqrt(3)*r
    stone=M.stone(name+" carved limestone",stone_tone,wear,seed)
    lead=M.metal(name+" old black iron","iron",wear,seed)
    brass=M.metal(name+" window catches","brass",wear,seed)
    path=pointed(w,spring)
    outer=pointed(w+20,spring)
    n=len(path);verts=[];faces=[]
    for yy in (0,reveal):
        for ring in (path,outer):verts += [(x,yy,z) for x,z in ring]
    for i in range(n-1):
        faces.extend(((i,i+1,n+i+1,n+i),(2*n+i,3*n+i,3*n+i+1,2*n+i+1),
                      (i,2*n+i,2*n+i+1,i+1),(n+i,n+i+1,3*n+i+1,3*n+i)))
    faces.extend(((0,n,3*n,2*n),(n-1,2*n-1,4*n-1,3*n-1)))
    a.mesh("Dressed pointed arch reveal",verts,faces,stone,bevel=.5)
    for offset,rr,yy in ((0,1.15,-.7),(5,1.5,-1.5),(10,1.1,-.4)):
        a.tube("Moulded pointed archivolt",[(x,yy,z) for x,z in pointed(w+offset,spring)],rr,stone)
    a.block("Moulded stone sill",(w+30,reveal+15,7),(0,reveal/2-5,0),stone,.8)
    pane=M.glass(name+" faint old glazing",(.53,.66,.83),reflection=.012)
    a.mesh("Pointed clear glazing",[(x,reveal-1,z) for x,z in path],[tuple(range(n))],pane)
    lancet=w/3
    small_spring=spring*.63
    for i in (-1,0,1):
        cx=i*lancet
        a.tube("Stone lancet tracery",[(x+cx,reveal-3,z) for x,z in pointed(lancet-2,small_spring)],1.15,stone)
        a.block("Vertical window mullion",(1.9,4,small_spring),(cx-lancet/2,reveal-3,small_spring/2),lead,.25)
        for z in (small_spring*.3,small_spring*.70):
            a.tube("Window saddle bar",[(cx-lancet/2+1,reveal-2,z),(cx+lancet/2-1,reveal-2,z)],.32,lead,resolution=1)
        if i==1:
            a.block("Window latch",(3,1,5),(cx-lancet/2,reveal-5,small_spring*.4),brass,.3)
    cz=spring+w*.38; rr=w*.09
    for i in range(4):
        t=i*math.pi/2
        center=(rr*.86*math.cos(t),reveal-3,cz+rr*.86*math.sin(t))
        a.ring("Quatrefoil stone tracery",rr,1.05,center,stone,plane="XZ",segments=48)
    for side in (-1,1):
        a.tube("Tracery branching rib",[(side*w/3,reveal-3,small_spring+math.sqrt(3)*(lancet-2)/2),
                  (side*w*.23,reveal-3,cz-rr*.45),(side*rr*.86,reveal-3,cz)],1.05,stone)
    a.tube("Tracery crown rib",[(0,reveal-3,cz+rr*1.86),(0,reveal-3,height)],1.05,stone)
    a.tube("Tracery central stem",[(0,reveal-3,small_spring+math.sqrt(3)*(lancet-2)/2),
                (0,reveal-3,cz-rr*1.86)],1.05,stone)
    for side in (-1,1):
        upper=pointed(w+22,spring)[1:34]
        outline=[(side*x,z) for x,z in upper]+[(0,height+23),(side*(-w/2-24),height+23),
                                                         (side*(-w/2-24),spring)]
        a.extrude("Carved arch spandrel",outline,reveal*.75,stone,y=reveal*.55,bevel=.3)
    sky,k=E.material(name+" clouded midnight")
    v=k.coords().outputs["Generated"]
    n=k.noise(v,5,4,.65,dist=.3).outputs["Fac"]
    col=k.ramp(n,[(.2,(.007,.014,.045)),(.49,(.026,.048,.12)),(.72,(.085,.13,.24))])
    k.surface(k.emission(col,sky_strength))
    a.block("Moonlit night sky",(w*6,1,height*7),(0,480,height*.5-480*exterior_slope),sky,0)
    moon=a.sphere("Cratered pale moon",w*.116,(w*moon_offset,410,height*.81-410*exterior_slope),
                  M.moon_surface(name+" moon maria",moon_strength,seed),subdiv=5)
    moon.visible_shadow=False
    for i,(xx,yy,ww,hh) in enumerate(((-w*.35,300,w*1.05,height*.40),(w*.15,210,w*.76,height*.53))):
        citadel(a,f"Distant study town {i}",xx,yy,12-yy*exterior_slope,ww,hh,seed+i*7,fade=.16+i*.05)
    for i in range(2):
        cloud(a,"Distant soft cloud",(0,370+i*30,height*.57-(370+i*30)*exterior_slope),
              w*3,height*.23,M.cloud_bank(name+f" soft cloud {i}",(.1,.14,.22),seed+i),seed+i)
    a.light("Moon through pointed window",(w*.1,reveal-7,height*.66),energy,(.32,.48,1),w*.65,
            target=(-15,-180,-55),kind="AREA")
    return a.root
