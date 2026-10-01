"""Low lacquer table with rounded mouldings, scalloped aprons and cabriole feet."""
import math
import bpy
from . import geometry as G, materials as M


def outline(width,depth,radius,segments=12):
    points=[]
    for x,y,angle in ((width/2-radius,depth/2-radius,0),(-width/2+radius,depth/2-radius,math.pi/2),(-width/2+radius,-depth/2+radius,math.pi),(width/2-radius,-depth/2+radius,math.pi*1.5)):
        for j in range(segments+1):
            t=angle+j*math.pi/2/segments
            points.append((x+radius*math.cos(t),y+radius*math.sin(t)))
    return points


def build(name="Low lacquer table",loc=(0,0,0),rot_z=0,width=98,depth=65,height=32,
          thickness=2.4,tone=(.018,.005,.004),wear=.4,seed=1,gilt=True) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    lacquer=M.urushi(name+" rubbed urushi",tone,wear,seed)
    gold=M.metal(name+" fine gilt moulding","brass",wear,seed)
    perimeter=outline(width,depth,4)
    n=len(perimeter)
    verts=[(x,y,z) for z in (height-thickness,height) for x,y in perimeter]
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    a.mesh("Rounded solid lacquer top",verts,faces,lacquer,bevel=.35)
    for z in (height-thickness+.5,height-.5):
        a.tube("Fine edge moulding",[(x,y,z) for x,y in perimeter],.085,gold if gilt else lacquer,cyclic=True)
    for sy in (-1,1):
        pts=[(-width/2+7,height-thickness),(width/2-7,height-thickness),(width/2-7,height-10)]
        pts.extend((width/2-7-(width-14)*i/24,height-8+2*math.sin(math.pi*i/24)**2) for i in range(25))
        a.extrude("Scalloped long apron",pts,1.8,lacquer,y=sy*(depth/2-6),bevel=.25)
    for sx in (-1,1):a.block("Tenoned short apron",(2,depth-12,6),(sx*(width/2-6),0,height-5.2),lacquer,.3)
    for sx in (-1,1):
        for sy in (-1,1):
            verts=[]
            for i in range(13):
                t=i/12;z=height-thickness-t*(height-thickness-1)
                x=sx*(width/2-8+3.5*math.sin(math.pi*t*.8));y=sy*(depth/2-8+2.5*math.sin(math.pi*t*.8))
                w=2.6*(1-.35*t)+.8*math.sin(math.pi*t)
                verts.extend((x+dx*w,y+dy*w,z) for dx,dy in ((-1,-1),(1,-1),(1,1),(-1,1)))
            faces=[(i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j) for i in range(12) for j in range(4)]
            faces += [(0,3,2,1),(48,49,50,51)]
            a.mesh("Curved cabriole leg",verts,faces,lacquer,bevel=.4,smooth=True)
            a.block("Splayed foot",(6,6,2),(sx*(width/2-6),sy*(depth/2-6.5),1),lacquer,.7)
    return a.root
