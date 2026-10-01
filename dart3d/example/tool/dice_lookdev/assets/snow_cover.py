"""Granular snow ledges with tapered edges, clear footprints and sparse ice glints."""
import math
import random
import bpy
from mathutils import noise, Vector
from . import geometry as G, materials as M


def build(name="Accumulated ledge snow",loc=(0,0,0),rot_z=0,width=30,depth=30,
          thickness=.8,tone=(.82,.88,.94),quiet=None,quiet_center=(0,0),holes=(),
          shape="rectangle",sparkle=40,wear=0,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    mat=M.snow(name+" granular powder",tone,seed,sparkle=.35,mask_attribute="snow_coverage")
    def height(x,y):
        border=min(width/2-abs(x),depth/2-abs(y))
        if shape=="disk":border=(1-math.hypot(x/(width/2),y/(depth/2)))*min(width,depth)/2
        border+=.18*math.sin(x*4.1+y*3.2+seed)
        if quiet:
            edge=max(abs(x-quiet_center[0])-quiet[0],abs(y-quiet_center[1])-quiet[1])
            drift=2.2+1.8*noise.noise_vector(Vector((x*.3,y*.3,seed))).x
            border=min(border,(edge-drift)*.4)
        for hx,hy,r in holes:border=min(border,math.hypot(x-hx,y-hy)-r)
        if border<=0:return 0
        n=noise.noise_vector(Vector((x*.43,y*.43,seed*.7))).x
        return thickness*(.72+.26*n)*min(1,border/max(.2,thickness*1.5))
    nx=max(12,min(96,math.ceil(width/.65)));ny=max(12,min(96,math.ceil(depth/.65)))
    verts=[((i/nx-.5)*width,(j/ny-.5)*depth,height((i/nx-.5)*width,(j/ny-.5)*depth))
           for j in range(ny+1) for i in range(nx+1)]
    faces=[]
    for j in range(ny):
        for i in range(nx):
            n=j*(nx+1)+i;ids=(n,n+1,n+nx+2,n+nx+1)
            if max(verts[k][2] for k in ids)>.02:faces.append(ids)
    ob=a.mesh("Wind-packed granular snow",verts,faces,mat,smooth=True)
    coverage=ob.data.attributes.new("snow_coverage","FLOAT","POINT")
    coverage.data.foreach_set("value",[min(1,z/max(.01,thickness*.30)) for x,y,z in verts])
    glint=M.frozen_ice(name+" crystalline grains",(.83,.94,1),.6,.05,seed,edge_glow=.35)
    for i in range(sparkle):
        x,y=rng.uniform(-width/2,width/2),rng.uniform(-depth/2,depth/2);z=height(x,y)
        if z<.07:continue
        ob=a.sphere("Sparse snow crystal",rng.uniform(.045,.13),(x,y,z),glint,scale=(1,.65,.42),subdiv=1)
        ob.rotation_euler=(rng.uniform(0,1),rng.uniform(0,1),rng.uniform(0,math.tau))
    return a.root
