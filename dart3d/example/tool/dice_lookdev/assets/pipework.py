"""Swept copper plumbing, bolted unions, wheel valves and unlettered gauges."""
import math
import bpy
from mathutils import Vector
import env_common as E
from . import geometry as G, materials as M


def flange(a,center,direction,radius,metal,bolts,thickness=.65):
    center=Vector(center);direction=Vector(direction).normalized()
    root=G.Asset("Bolted pipe union",center);a.add(root.root)
    root.root.rotation_mode="QUATERNION"
    root.root.rotation_quaternion=direction.to_track_quat("Z","Y")
    root.cylinder("Flange disk",radius*1.7,thickness,(0,0,0),metal,segments=40,bevel=.10)
    root.cylinder("Flange neck",radius*1.12,thickness*2.7,(0,0,0),metal,segments=32,bevel=.1)
    for j in range(8):
        t=j*math.tau/8
        root.cylinder("Hexagonal union nut",radius*.19,thickness*1.7,
                      (radius*1.36*math.cos(t),radius*1.36*math.sin(t),0),bolts,segments=6,bevel=.04)


def build(name="Workshop pipe",loc=(0,0,0),rot_z=0,kind="pipe",points=((0,0,0),(0,0,50)),
          radius=2,metal_finish="copper",wear=.6,seed=1,gauge_radius=5,reading=.66,
          wheel_radius=5) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    metal=M.machined_metal(name+" metal",metal_finish,wear,seed)
    brass=M.machined_metal(name+" brass fittings","brass",wear*.75,seed+1)
    iron=M.machined_metal(name+" fasteners","iron",wear,seed+2)
    if kind=="gauge":
        r=gauge_radius
        body=a.lathe("Gauge bezel",[(0,0),(r*.85,0),(r,.25),(r,.9),(r*.91,1.1),
                                    (r*.86,.98),(r*.86,.35),(0,.35)],brass,segments=64)
        body.rotation_euler.x=math.pi/2
        enamel=E.simple(name+" ivory dial",(.53,.46,.31),.65)
        dial=a.cylinder("Recessed gauge dial",r*.865,.08,(0,-.37,0),enamel,segments=64,bevel=.02)
        dial.rotation_euler.x=math.pi/2
        for j in range(41):
            t=math.radians(-220+j*7)
            inner=r*(.66 if j%5==0 else .73)
            a.tube("Dial graduation",[(inner*math.cos(t),-.45,inner*math.sin(t)),
                    (r*.82*math.cos(t),-.45,r*.82*math.sin(t))],r*.009,iron,resolution=1)
        t=math.radians(-220+280*reading)
        dx,dz=math.cos(t),math.sin(t)
        a.mesh("Tapered pressure needle",[(-dx*r*.18,-.54,-dz*r*.18),
                    (-dz*.14,-.54,dx*.14),(r*.72*dx,-.54,r*.72*dz),
                    (dz*.14,-.54,-dx*.14)],[(0,1,2,3)],iron)
        pivot=a.cylinder("Needle arbor",r*.09,.13,(0,-.58,0),brass,segments=24)
        pivot.rotation_euler.x=math.pi/2
        glass=a.sphere("Convex gauge glass",r*.86,(0,-.73,0),M.glass(name+" gauge glass",(.93,.96,1),.1),scale=(1,.075,1),subdiv=3)
        a.cylinder("Gauge threaded inlet",r*.20,r*.50,(0,0,-r*1.13),brass,segments=12)
    elif kind=="valve":
        a.cylinder("Valve barrel",radius*1.6,radius*4,(0,0,0),brass,segments=40)
        for z in (-radius*2,radius*2):flange(a,(0,0,z),(0,0,1),radius,metal,iron)
        a.beam("Valve spindle",(0,0,0),(0,-radius*3.5,0),radius*.48,radius*.48,brass,.15)
        y=-radius*3.5
        a.ring("Cast handwheel",wheel_radius,.28,(0,y,0),iron,plane="XZ",segments=64)
        for i in range(5):
            t=i*math.tau/5
            a.tube("Valve wheel curved spoke",[(0,y,0),(wheel_radius*.5*math.cos(t+.15),y-.2,wheel_radius*.5*math.sin(t+.15)),
                    (wheel_radius*math.cos(t),y,wheel_radius*math.sin(t))],.2,iron)
        cap=a.cylinder("Wheel hub nut",.65,.65,(0,y,0),brass,segments=6);cap.rotation_euler.x=math.pi/2
    else:
        pts=[Vector(p) for p in points];rounded=[pts[0]]
        for i in range(1,len(pts)-1):
            incoming=(pts[i]-pts[i-1]);outgoing=(pts[i+1]-pts[i])
            trim=min(radius*3,incoming.length*.35,outgoing.length*.35)
            p0=pts[i]-incoming.normalized()*trim;p2=pts[i]+outgoing.normalized()*trim
            rounded += [(1-t)**2*p0+2*(1-t)*t*pts[i]+t*t*p2 for t in (j/12 for j in range(13))]
        rounded.append(pts[-1])
        a.tube("Swept pipe and radiused elbows",rounded,radius,metal,resolution=3)
        for i in (0,-1):
            direction=pts[1]-pts[0] if i==0 else pts[-1]-pts[-2]
            flange(a,pts[i],direction,radius,brass,iron)
        for left,right in zip(pts[:-1],pts[1:]):
            if (right-left).length>radius*10:
                flange(a,(left+right)/2,right-left,radius,brass,iron,thickness=.45)
    return a.root
