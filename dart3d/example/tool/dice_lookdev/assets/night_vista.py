"""Procedural star field, shaded moon, floating spired citadels and soft cloud layers."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M


def cloud(a,name,center,width,height,mat,seed):
    rng=random.Random(seed)
    nx,nz=32,12; verts=[]
    phase=rng.uniform(0,6)
    for j in range(nz+1):
        v=j/nz
        for i in range(nx+1):
            u=i/nx
            verts.append((center[0]+(u-.5)*width,center[1]+math.sin(u*8+phase)*20,
                          center[2]+(v-.5)*height+math.sin(u*15+phase)*height*.10))
    faces=[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i) for j in range(nz) for i in range(nx)]
    ob=a.mesh(name,verts,faces,mat,smooth=True)
    uv=ob.data.uv_layers.new()
    for p in ob.data.polygons:
        for index in p.loop_indices:
            vi=ob.data.loops[index].vertex_index
            uv.data[index].uv=(vi%(nx+1)/nx,vi//(nx+1)/nz)
    ob.visible_shadow=False
    return ob


def citadel(a,name,x,y,z,width,height,seed,fade=0):
    rng=random.Random(seed)
    tone=tuple(v*(1-fade)+b*fade for v,b in zip((.037,.047,.083),(.12,.16,.24)))
    stone=E.simple(name+" distant stone",tone,.85,Emission_Color=(*tone,1),Emission_Strength=.6)
    roof=E.simple(name+" slate roofs",tuple(c*.6 for c in tone),.6,Emission_Color=(*tone,1),Emission_Strength=.35)
    rock=M.stone(name+" island rock",tuple(c*.8 for c in tone),wear=.8,seed=seed)
    warm=E.emissive(name+" lamplit windows",(1,.52,.19),13*(1-fade*.55))
    cool=E.emissive(name+" pale windows",(.40,.59,.9),4)
    verts=[]; faces=[]; n=32
    for ring,(r,zz) in enumerate(((.84,3),(1,-8),(.84,-30),(.48,-height*.42),(.08,-height*.74))):
        for j in range(n):
            t=j*math.tau/n; rr=r*rng.uniform(.85,1.1)
            verts.append((x+math.cos(t)*width*.52*rr,y+math.sin(t)*width*.21*rr,z+zz+rng.uniform(-6,6)))
    faces.append(tuple(range(n)))
    faces += [(r*n+j,r*n+(j+1)%n,(r+1)*n+(j+1)%n,(r+1)*n+j) for r in range(4) for j in range(n)]
    a.mesh("Suspended crag "+name,verts,faces,rock)
    window_verts=[]; window_faces=[]
    for i in range(21):
        xx=x+rng.uniform(-width*.42,width*.42); yy=y+rng.uniform(-width*.10,width*.10)
        h=height*(1 if i==0 else rng.uniform(.2,.74)); r=width*rng.uniform(.017,.041)
        if i==0:xx=x;yy=y
        a.cylinder("Citadel octagonal tower",r,h,(xx,yy,z+h/2),stone,segments=8,bevel=.3)
        for zz in (z+h*.12,z+h*.73,z+h*.95):
            a.cylinder("Tower cornice",r*1.13,1.6,(xx,yy,zz),stone,segments=8,bevel=.2)
        a.cylinder("Pointed slate spire",r*1.25,h*.37,(xx,yy,z+h*1.185),roof,r2=.15,segments=8,bevel=0)
        a.sphere("Spire finial",.65,(xx,yy,z+h*1.37),warm,subdiv=1)
        for level in range(1,max(2,int(h/10))):
            for side in range(8):
                if rng.random()<.48:continue
                t=(side+.5)*math.tau/8
                rx,ry=math.cos(t),math.sin(t); rr=r*.93
                cx,cy=xx+rr*rx,yy+rr*ry; zz=z+level*9
                ww=min(1.8,r*.25); hh=3.4
                start=len(window_verts)
                window_verts += [(cx+dx*-ry,cy+dx*rx,zz+dz) for dx,dz in ((-ww/2,0),(ww/2,0),(ww/2,hh*.78),(0,hh),(-ww/2,hh*.78))]
                window_faces.append(tuple(range(start,start+5)))
        if i%4==0:
            a.block("Citadel connecting hall",(r*4,14,h*.24),(xx+2*r,yy+3,z+h*.12),stone,.8)
            a.extrude("Hall slate roof",[(xx-r,z+h*.24),(xx+2*r,z+h*.34),(xx+5*r,z+h*.24)],15,roof,y=yy+3,bevel=.2)
    ob=a.mesh("Warm citadel lancet windows",window_verts,window_faces,warm)
    ob.data.materials.append(cool)
    for f in ob.data.polygons:f.material_index=1 if rng.random()<.1 else 0


def build(name="Celestial night vista",loc=(0,0,0),rot_z=0,width=3000,depth=1800,
          sky_strength=1.4,moon_strength=1.7,slope=.46,wear=0,seed=5) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    sky=M.night_sky(name+" galaxy",sky_strength,seed)
    z=35-depth*slope
    a.mesh("Deep indigo sky",[(-width/2,depth,z-700),(width/2,depth,z-700),
                              (width/2,depth,z+900),(-width/2,depth,z+900)],[(0,1,2,3)],sky)
    moon=a.sphere("Maria and terminator moon",89,(95,depth*.84,35-depth*.84*slope+170),
                  M.moon_surface(name+" pale moon",moon_strength,seed),subdiv=6)
    moon.visible_shadow=False
    planet=a.sphere("Small distant planet",20,(190,depth*.9,35-depth*.9*slope+210),
                    M.moon_surface(name+" distant planet",.9,seed+7),subdiv=4)
    planet.visible_shadow=False
    for i,(x,y,w,h) in enumerate(((-300,1150,250,130),(0,870,360,105),(340,1330,220,125))):
        citadel(a,f"Floating citadel {i}",x,y,35-y*slope+15,w,h,seed+i*13,fade=.13+i*.08)
    for i,(y,cz,w,h,x) in enumerate(((1480,-680,2200,210,0),(1240,-570,1600,200,-170),
                                    (1060,-475,1800,170,90),(960,-405,760,140,-350),
                                    (815,-370,1300,180,30),(680,-355,1100,155,-50))):
        cloud(a,"Moonlit cloud bank",(x,y,cz+25-(slope-.46)*y),w,h*.8,M.cloud_bank(name+f" cloud {i}",(.12+i*.009,.155+i*.008,.235+i*.013),seed+i),seed+i)
    glint=E.emissive(name+" bright star glints",(.63,.76,1),4)
    for x,y,zz,r in ((240,1650,-500,7),(-480,1600,-435,5),(90,1660,-600,3)):
        zz-=(slope-.46)*y
        a.mesh("Four-point star glint",[(x,y,zz+r),(x+r*.12,y,zz+r*.12),(x+r,y,zz),
                 (x+r*.12,y,zz-r*.12),(x,y,zz-r),(x-r*.12,y,zz-r*.12),(x-r,y,zz),(x-r*.12,y,zz+r*.12)],
                 [tuple(range(8))],glint)
    return a.root
