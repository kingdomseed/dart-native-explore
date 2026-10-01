"""Tapered woody branches bearing modeled five-petal blossoms; loose petal option."""
import math
import random
import bpy
from mathutils import Vector
from . import geometry as G, materials as M
import env_common as E


def blossom_mesh(a,centres,mat,seed=1,petals=5,normal=None):
    rng=random.Random(seed);verts=[];faces=[]
    for center,radius in centres:
        axis=Vector(normal or (rng.uniform(-.4,.4),-1,rng.uniform(-.4,.8))).normalized()
        u=axis.cross(Vector((0,1,0) if abs(axis.z)>.9 else (0,0,1))).normalized();v=axis.cross(u)
        phase=rng.uniform(0,math.tau)
        for p in range(petals):
            theta=phase+math.tau*p/petals;d=u*math.cos(theta)+v*math.sin(theta);q=axis.cross(d)
            start=len(verts)
            for i in range(5):
                t=i/4
                for side in (-1,0,1):
                    point=Vector(center)+d*(radius*t)+q*(side*radius*.34*math.sin(math.pi*t)**.6)+axis*(radius*.18*t*t+abs(side)*radius*.1)
                    verts.append(tuple(point))
            for i in range(4):
                for j in range(2):
                    b=start+i*3+j;faces.append((b,b+1,b+4,b+3))
    return a.mesh("Cupped cherry petals",verts,faces,mat,smooth=True)


def build(name="Flowering cherry",loc=(0,0,0),rot_z=0,width=165,height=135,count=350,
          tone=(.65,.23,.30),kind="branch",wear=.4,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    mat=E.simple(name+" pink petal",tone,.58,Subsurface_Weight=.18)
    if kind=="petals":
        centers=[((rng.uniform(-width/2,width/2),rng.uniform(-height/2,height/2),rng.uniform(.025,.05)),rng.uniform(.55,1.15)) for _ in range(count)]
        blossom_mesh(a,centers,mat,seed,petals=1,normal=(0,0,1))
        return a.root
    bark=M.bark(name+" cherry bark",(.058,.026,.024),wear,seed)
    def branch(points,r0,r1):
        verts=[]
        for i,p in enumerate(points):
            direction=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
            direction.normalize();u=direction.cross(Vector((0,1,0))).normalized();v=direction.cross(u)
            r=r0+(r1-r0)*i/(len(points)-1)
            verts.extend(tuple(Vector(p)+r*(u*math.cos(j*math.tau/8)+v*math.sin(j*math.tau/8))) for j in range(8))
        a.mesh("Tapered cherry limb",verts,[(i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j) for i in range(len(points)-1) for j in range(8)],bark,smooth=True)
    trunk=[(-width*.48+width*.8*t,5*math.sin(t*3),height*(t*.5+.12*math.sin(t*2))) for t in [i/24 for i in range(25)]]
    branch(trunk,4,.9);centres=[];twigs=[];twig_faces=[]
    for i in range(12):
        t=.13+i*.071;start=Vector(trunk[int(t*24)])
        end=start+Vector((rng.uniform(-.14,.24)*width,rng.uniform(-15,15),rng.uniform(.19,.46)*height))
        pts=[tuple(start+(end-start)*u+Vector((math.sin(u*math.pi)*8,0,0))) for u in [j/12 for j in range(13)]]
        branch(pts,1.4,.16)
        for j in range(max(1,count//12)):
            u=rng.uniform(.25,1)
            attach=start+(end-start)*u+Vector((math.sin(u*math.pi)*8,0,0))
            c=attach+Vector((rng.gauss(0,4),rng.gauss(0,3),rng.gauss(0,3)))
            direction=(c-attach).normalized();cross=direction.cross(Vector((0,1,0))).normalized();other=direction.cross(cross)
            b=len(twigs)
            for center,r in ((attach,.12),(c,.045)):
                twigs.extend(tuple(center+r*(cross*math.cos(q*math.tau/5)+other*math.sin(q*math.tau/5))) for q in range(5))
            twig_faces.extend((b+q,b+(q+1)%5,b+5+(q+1)%5,b+5+q) for q in range(5))
            centres.append((tuple(c),rng.uniform(.9,1.8)))
    a.mesh("Fine blossom bearing twigs",twigs,twig_faces,bark,smooth=True)
    blossom_mesh(a,centres,mat,seed)
    return a.root
