"""Loose graded stones in irregular sorting groups, with an optional quiet rectangle."""
import math
import random
import bpy
from mathutils import Vector,Quaternion
from . import geometry as G,cut_gem


def build(name="Loose sorted gemstones",loc=(0,0,0),rot_z=0,width=24,depth=12,count=32,
          radius=(.35,1.1),quiet=None,occupied=(),wear=.08,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed);placed=[]
    tones=[(.84,.92,.99),(.025,.45,.21),(.025,.09,.48),(.49,.012,.037),(.74,.44,.16)]
    cuts=["brilliant","emerald","oval","pear","cushion"]
    for i in range(count):
        r=rng.uniform(*radius)
        for attempt in range(100):
            x=rng.uniform(-width/2,width/2);y=rng.uniform(-depth/2,depth/2)
            gx=x*math.cos(rot_z)-y*math.sin(rot_z)+loc[0]
            gy=x*math.sin(rot_z)+y*math.cos(rot_z)+loc[1]
            if quiet and abs(gx)<quiet[0]+r*1.4 and abs(gy)<quiet[1]+r*1.4:continue
            if any(abs(gx-cx)<hx+r*1.4 and abs(gy-cy)<hy+r*1.4 for cx,cy,hx,hy in occupied):continue
            if all(math.hypot(x-px,y-py)>1.4*(r+pr)+.12 for px,py,pr in placed):break
        else:continue
        placed.append((x,y,r))
        gem=cut_gem.build(name+f" stone {i}",loc=(x,y,0),radius=r,cut=cuts[i%5],
             tone=tones[i%5],ior=2.42 if i%5==0 else 1.77,glints=2,wear=wear,seed=seed+i,rot_z=rng.uniform(0,math.tau))
        mesh=next(ob.data for ob in gem.children if ob.type=="MESH" and ob.name.startswith("Polished optical facets"))
        center=sum((v.co for v in mesh.vertices),Vector())/len(mesh.vertices)
        supports=[]
        for face in mesh.polygons:
            if face.normal.z>=-.1:continue
            verts=[mesh.vertices[j].co for j in face.vertices]
            projected=center-face.normal*(center-verts[0]).dot(face.normal)
            if all((v2-v1).cross(projected-v1).dot(face.normal)>=-1e-6 for v1,v2 in zip(verts,verts[1:]+verts[:1])):
                supports.append(face)
        face=rng.choice(supports)
        rotation=Quaternion((0,0,1),rng.uniform(0,math.tau)) @ face.normal.rotation_difference(Vector((0,0,-1)))
        gem.rotation_euler=rotation.to_euler()
        rotation=rotation.to_matrix()
        low=min((rotation @ v.co).z for ob in gem.children if ob.type=="MESH" for v in ob.data.vertices)
        gem.location.z=-low+.002
        a.add(gem)
    return a.root
