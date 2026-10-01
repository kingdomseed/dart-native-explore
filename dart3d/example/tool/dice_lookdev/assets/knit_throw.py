"""Draped knitted wool: a soft support sheet, interlocking yarn loops and fringe."""
import math
import bpy
from mathutils import Vector
from . import geometry as G, materials as M


def build(name="Knitted throw",loc=(0,0,0),rot_z=0,width=36,
          path=((40,108),(33,114),(24,104),(8,72),(-24,69),(-38,66),(-43,12)),
          pitch=2.7,fold=1.4,tone=(.13,.012,.027),wear=.5,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    yarn=M.wool(name+" wool",tuple(c*(1+wear*.18) for c in tone),seed)
    knots=[Vector(p) for p in path]
    curve=[]
    for i in range(len(knots)-1):
        p0,p1,p2,p3=knots[max(0,i-1)],knots[i],knots[i+1],knots[min(len(knots)-1,i+2)]
        count=max(4,int((p2-p1).length/.7))
        for j in range(count):
            t=j/count
            curve.append((p1*2+(p2-p0)*t+(p0*2-p1*5+p2*4-p3)*t*t+(-p0+p1*3-p2*3+p3)*t*t*t)*.5)
    curve.append(knots[-1])
    lengths=[0]
    for p,q in zip(curve,curve[1:]): lengths.append(lengths[-1]+(p-q).length)
    total=lengths[-1]
    def surface(x,s):
        import bisect
        s=max(0,min(total-.001,s))
        j=max(0,bisect.bisect_right(lengths,s)-1)
        t=(s-lengths[j])/(lengths[j+1]-lengths[j])
        yz=curve[j].lerp(curve[j+1],t)
        tangent=(curve[j+1]-curve[j]).normalized()
        normal=Vector((0,tangent.y,-tangent.x))
        ridge=fold*(math.sin(x*.38+s*.032)+.4*math.sin(x*.73-s*.04))
        crown=4.0*math.cos(x/width*math.pi)
        return Vector((x,yz.x,yz.y))+normal*(ridge+crown),normal
    nx=max(16,int(width/.8));ny=int(total/.8)
    verts=[tuple(surface(width*(i/nx-.5),total*j/ny)[0]) for j in range(ny+1) for i in range(nx+1)]
    faces=[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i) for j in range(ny) for i in range(nx)]
    a.mesh("Soft knitted backing",verts,faces,yarn,smooth=True)
    verts=[];faces=[]
    rows=int(total/pitch);cols=int(width/pitch)
    radius=pitch*.15
    for row in range(rows-1):
        for col in range(cols):
            x=(col-(cols-1)/2)*pitch
            s=(row+1)*pitch
            points=[]
            for j in range(12):
                t=math.tau*j/11
                xx=x+pitch*.43*math.sin(t)
                ss=s+pitch*.62*math.cos(t)
                p,n=surface(xx,ss)
                points.append(p+n*(radius*.8+radius*.48*math.sin(t*2)))
            for j,p in enumerate(points):
                tangent=(points[min(j+1,11)]-points[max(j-1,0)]).normalized()
                u=tangent.cross(Vector((1,0,0))).normalized();v=tangent.cross(u)
                base=len(verts)
                for k in range(5):
                    t=math.tau*k/5
                    verts.append(tuple(p+radius*(math.cos(t)*u+math.sin(t)*v)))
                if j:
                    faces.extend((base-5+k,base-5+(k+1)%5,base+(k+1)%5,base+k) for k in range(5))
    a.mesh("Interlocking wool stitches",verts,faces,yarn,smooth=True)
    for side in (-1,1):
        a.tube("Rolled knit selvedge",[tuple(surface(side*width/2,total*j/100)[0]) for j in range(101)],pitch*.24,yarn)
    for i in range(cols*2):
        x=width*(i/(cols*2-1)-.5)
        p,n=surface(x,total-.1)
        a.tube("Twisted wool fringe",[tuple(p),tuple(p+Vector((.3,0,-2))),tuple(p+Vector((.6,.3,-4.5)))],pitch*.12,yarn,resolution=1)
    return a.root
