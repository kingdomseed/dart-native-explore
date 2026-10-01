"""Turned lacquer tea bowls, lidded tea caddy and pleated folding fan."""
import math
import bpy
from . import geometry as G, materials as M
import env_common as E


def build(name="Lacquer tea bowl",loc=(0,0,0),rot_z=0,kind="bowl",radius=5.2,height=7,
          tone=(.014,.006,.004),metal_finish="brass",wear=.35,seed=1,tea=True) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);lac=M.urushi(name+" urushi",tone,wear,seed)
    gold=M.metal(name+" maki-e",metal_finish,wear,seed)
    if kind=="fan":
        paper=M.washi(name+" vermilion washi",(.40,.037,.019),0,seed)
        verts=[];steps=32
        for r in (radius*.2,radius):
            for j in range(steps+1):
                t=-1.1+j*2.2/steps
                verts.append((r*math.sin(t),r*math.cos(t),.2+(j%2)*.23*r/radius))
        a.mesh("Folded paper fan",verts,[(i,i+1,i+steps+2,i+steps+1) for i in range(steps)],paper)
        for i in range(0,steps+1,2):
            t=-1.1+i*2.2/steps
            a.tube("Tapered fan rib",[(0,0,.16),(radius*math.sin(t),radius*math.cos(t),.16)],.055,lac)
        a.cylinder("Fan pivot pin",.21,.3,(0,0,.25),gold,segments=16)
        for r in (.72,.84):a.tube("Gilt fan arc",[(radius*r*math.sin(t),radius*r*math.cos(t),.32) for t in [-1.1+i*2.2/80 for i in range(81)]],.025,gold)
        return a.root
    if kind=="caddy":
        profile=[(0,0),(.75,0),(.84,.06),(.9,.15),(.92,.83),(.89,.93),(.8,.96),(.77,.91),(.8,.13),(0,.13)]
        a.lathe("Lacquer tea caddy",[(r*radius,z*height) for r,z in profile],lac)
        a.lathe("Close fitting domed lid",[(0,height*1.04),(.5*radius,height*1.02),(.9*radius,height*.97),(.93*radius,height*.90),(.89*radius,height*.88)],lac)
        bands=(.12,.87,.94)
    else:
        profile=[(0,0),(.49,0),(.53,.10),(.46,.17),(.6,.22),(.82,.47),(.98,.82),(1,1),(.96,1.025),(.91,.99),(.88,.82),(.71,.48),(.5,.28),(0,.24)]
        a.lathe("Hollow tea bowl",[(r*radius,z*height) for r,z in profile],lac,segments=64)
        bands=(.12,.96)
        if tea:
            liquid=E.simple(name+" dark tea",(.019,.026,.006),.13,Coat_Weight=.8,IOR=1.34)
            a.cylinder("Tea meniscus",radius*.878,.045,(0,0,height*.80),liquid,segments=64,bevel=.02)
    for z in bands:
        r=radius*(.52 if z<.2 else (.93 if kind=="caddy" else .995))
        a.ring("Fine gold rim",r,.055,(0,0,height*z),gold,segments=64)
    def surface_radius(z):
        f=z/height
        profile=((.15,.90),(.83,.92),(.93,.89)) if kind=="caddy" else ((.22,.60),(.47,.82),(.82,.98),(1,1))
        for (za,ra),(zb,rb) in zip(profile,profile[1:]):
            if f<=zb:return radius*(ra+(rb-ra)*(f-za)/(zb-za))+.035
        return radius
    for j in range(7):
        theta=j*math.tau/7
        pts=[]
        for i in range(25):
            t=i/24;z=height*(.35+.45*t)
            rr=surface_radius(z)
            ang=theta+.16*math.sin(t*4)
            pts.append(((rr+.02)*math.cos(ang),(rr+.02)*math.sin(ang),z))
        a.tube("Gold botanical stem",pts,.022,gold,resolution=1)
        for i in (7,14,21):
            x,y,z=pts[i];ang=math.atan2(y,x)
            for side in (-1,1):
                leaf=[(surface_radius(z+.6*t)*math.cos(ang+side*.08*math.sin(t*math.pi)),surface_radius(z+.6*t)*math.sin(ang+side*.08*math.sin(t*math.pi)),z+.6*t) for t in [k/8 for k in range(9)]]
                a.tube("Gold leaf stroke",leaf,.035,gold,resolution=1)
    return a.root
