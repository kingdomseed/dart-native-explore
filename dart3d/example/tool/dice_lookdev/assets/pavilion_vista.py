"""Layered dusk mountains and a timber pagoda with swept tiled roofs."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M


def pagoda(a,x,y,z,width,height,seed=1):
    wood=M.oak("Distant pagoda cedar",(.035,.021,.018),.3,seed,axis="Z")
    roof=E.simple("Blue dusk roof tiles",(.018,.031,.045),.6)
    gold=M.metal("Pagoda bronze finial","brass",.45,seed)
    glow=E.emissive("Distant amber window paper",(1,.39,.08),1.3)
    for level in range(4):
        w=width*(1-.16*level);h=height*.19;zz=z+level*h
        a.block("Timber pagoda storey",(w*.69,w*.58,h*.75),(x,y,zz+h*.37),wood,.8)
        for col in range(5):
            a.block("Warm pagoda slit",(w*.07,.16,h*.32),(x-w*.25+col*w*.125,y-w*.294,zz+h*.39),glow,.2)
        for side in (-1,1):
            a.block("Pagoda eave cross beam",(w*.83,3,3),(x,y+side*w*.34,zz+h*.77),wood,.4)
        # Four curved roof quadrants rise from the ridge and kick up at each corner.
        verts=[];faces=[];n=18
        for face in range(4):
            base=len(verts);theta=face*math.pi/2
            for i in range(n+1):
                t=i/n
                for j in range(n+1):
                    u=-1+2*j/n
                    xx=u*(w*.14+w*.40*t);yy=w*.11+w*.39*t
                    rz=zz+h*(1.16-.52*t+.19*t**6+abs(u)**6*.15*t**2)
                    verts.append((x+xx*math.cos(theta)-yy*math.sin(theta),y+xx*math.sin(theta)+yy*math.cos(theta),rz))
            for i in range(n):
                for j in range(n):
                    b=base+i*(n+1)+j;faces.append((b,b+1,b+n+2,b+n+1))
            for col in range(0,n+1,3):
                a.tube("Raised tile seam",[verts[base+i*(n+1)+col] for i in range(n+1)],.32,roof,resolution=1)
            a.tube("Turned up eave lip",[verts[base+n*(n+1)+j] for j in range(n+1)],.75,roof,resolution=1)
        a.mesh("Curved tiled pagoda roofs",verts,faces,roof,smooth=True)
    a.lathe("Ringed pagoda finial",[(0,z+height*.76),(2,z+height*.78),(1.4,z+height*1.06),(.3,z+height*1.19),(0,z+height*1.21)],gold,loc=(x,y,0))
    for i in range(7):a.ring("Bronze spire ring",3.2-i*.31,.45,(x,y,z+height*(.86+i*.032)),gold,segments=24)


def build(name="Mountain dusk",loc=(0,0,0),rot_z=0,width=2100,depth=1500,slope=.43,
          pagoda_x=270,pagoda_depth=610,pagoda_width=155,pagoda_height=195,
          sky_strength=.65,wear=.35,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    m,k=E.material(name+" layered sunset sky")
    vec=k.coords().outputs["Generated"];sep=k.node("ShaderNodeSeparateXYZ");k.link(vec,sep.inputs[0])
    col=k.ramp(sep.outputs["Z"],[(0,(.09,.105,.16)),(.23,(.34,.17,.15)),(.38,(.15,.13,.21)),(.65,(.055,.084,.15)),(1,(.024,.041,.085))])
    mp=k.node("ShaderNodeMapping");mp.inputs["Scale"].default_value=(3,.1,17);k.link(vec,mp.inputs["Vector"])
    n=k.noise(mp.outputs[0],2.4,4).outputs["Fac"]
    cloud=k.math("MULTIPLY",k.ramp(n,[(.42,(0,0,0)),(.66,(1,1,1))]),.36)
    col=k.mix(cloud,col,(.10,.105,.155,1))
    k.surface(k.emission(col,sky_strength))
    sky=a.mesh("Dusk cloud sky",[(-width,depth,-depth*slope-450),(width,depth,-depth*slope-450),(width,depth,900-depth*slope),(-width,depth,900-depth*slope)],[(0,1,2,3)],m)
    sky.visible_shadow=False
    for layer in range(4):
        y=depth*(.32+.16*layer);base=-y*slope-145
        tone=[(.032,.050,.064),(.057,.082,.11),(.09,.11,.15),(.12,.13,.18)][layer]
        mat=E.emissive("Atmospheric mountain layer",tone,.55)
        verts=[];faces=[]
        for i in range(101):
            x=-width+i*2*width/100
            peak=85+55*math.sin(i*.17+layer)+45*math.sin(i*.41+layer*2)+rng.uniform(-8,8)
            verts.extend(((x,y,base-220),(x,y,base+peak)))
        for i in range(100):faces.append((i*2,i*2+2,i*2+3,i*2+1))
        a.mesh("Layered mountain ridge",verts,faces,mat)
    y=pagoda_depth;z=-y*slope-40
    hill=M.stone("Pagoda wooded hill",(.026,.035,.031),.8+.2*(wear-.35),seed)
    # Jagged sloping rock fan anchors the distant building in the nearer ridge.
    verts=[(pagoda_x,y,z-8)]
    for i in range(41):
        t=math.tau*i/40
        verts.append((pagoda_x+math.cos(t)*pagoda_width*2.2,y+math.sin(t)*pagoda_width*1.1,z-120-rng.uniform(0,40)))
    a.mesh("Pagoda hill",verts,[(0,i,i+1) for i in range(1,41)],hill)
    pagoda(a,pagoda_x,y,z,pagoda_width,pagoda_height,seed)
    foliage=E.emissive("Dark pine silhouettes",(.019,.035,.038),.6)
    for i in range(38):
        x=pagoda_x+rng.uniform(-pagoda_width*2.4,pagoda_width*2.4);yy=y+rng.uniform(-55,65)
        zz=z-75-abs(x-pagoda_x)*.12;h=rng.uniform(20,55)
        a.cylinder("Pine trunk",.8,h,(x,yy,zz+h/2),foliage,segments=6)
        for j in range(3):a.cylinder("Layered pine crown",h*(.25-j*.055),h*.34,(x,yy,zz+h*(.45+j*.21)),foliage,segments=7,r2=0)
    return a.root
