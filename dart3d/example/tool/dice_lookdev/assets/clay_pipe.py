"""Open fired-clay tobacco bowl, engraved lozenges and a tapered bent mouthpiece."""
import math
import bpy
import env_common as E
from . import geometry as G, materials as M


def build(name="Clay pipe",loc=(0,0,0),rot_z=0,length=19,bowl_height=5.2,radius=2.4,
          tone=(.20,.065,.025),metal_finish="brass",wear=.7,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    clay=M.stoneware(name+" fired clay",tone,wear,seed)
    char=E.simple(name+" smoked interior",(.012,.009,.007),.96)
    dark=M.leather(name+" black horn",(.014,.009,.006),wear,seed)
    brass=M.metal(name+" stem ferrule",metal_finish,wear,seed)
    h=bowl_height;r=radius
    profile=[(0,0),(.55,0),(.84,.10),(1,.48),(.93,.87),(.88,1),(.70,1),(.66,.89),(.61,.31),(0,.28)]
    a.lathe("Hollow clay bowl",[(rr*r,z*h) for rr,z in profile],clay,segments=48)
    a.lathe("Blackened bowl well",[(0,.29*h),(.60*r,.31*h),(.67*r,.9*h),(.70*r,h-.06)],char,segments=48)
    a.ring("Rubbed bowl lip",r*.8,.16,(0,0,h),clay)
    verts=[];n=64
    for j in range(n+1):
        t=j/n;x=r*.73+(length-r*.73)*t;z=1.35+1.1*math.sin(math.pi*t)-.78*t
        rr=.62*(1-t)+.3*t
        for i in range(16):
            th=i*math.tau/16
            verts.append((x,rr*math.cos(th),z+rr*math.sin(th)))
    faces=[(j*16+i,j*16+(i+1)%16,(j+1)*16+(i+1)%16,(j+1)*16+i) for j in range(n) for i in range(16)]
    a.mesh("Tapered horn mouthpiece",verts,faces,dark,smooth=True)
    a.cylinder("Brass mortise band",.72,1.3,(r+1.1,0,1.6),brass).rotation_euler.y=math.pi/2
    for i in range(12):
        th=i*math.tau/12;pts=[]
        for j in range(5):
            dt,z=((- .18,.35),(0,.67),(.18,.35),(0,.23),(-.18,.35))[j]
            rr=r*(.98 if z<.5 else .965)
            pts.append((rr*math.cos(th+dt),rr*math.sin(th+dt),z*h))
        a.tube("Impressed clay lozenge",pts,.04,char)
    return a.root
