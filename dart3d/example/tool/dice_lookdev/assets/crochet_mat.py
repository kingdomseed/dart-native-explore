"""Open cotton crochet with interlocking flower loops and a scalloped border."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Crochet placemat",loc=(0,0,0),rot_z=0,width=23,depth=32,
          tone=(.52,.43,.29),stitch=1.55,wear=.4,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    cotton=M.wool(name+" twisted cotton",tone,wear,seed,weave=True)
    nx=max(4,round(width/stitch));ny=max(4,round(depth/stitch))
    sx=width/nx;sy=depth/ny
    for j in range(ny):
        for i in range(nx):
            x=(i+.5)*sx-width/2;y=(j+.5)*sy-depth/2
            pts=[]
            for q in range(16):
                t=q*math.tau/16;r=.53+.11*math.cos(t*4)
                pts.append((x+sx*r*math.cos(t),y+sy*r*math.sin(t),.11+.045*math.sin(4*t)))
            a.tube("Interlocked cotton flower",pts,.075,cotton,True,resolution=0)
    for side in (-1,1):
        for i in range(nx):
            x=(i+.5)*sx-width/2
            pts=[(x+sx*.49*math.cos(q*math.pi/12),side*(depth/2+sy*.43*math.sin(q*math.pi/12)),.10) for q in range(13)]
            a.tube("Scalloped end",pts,.09,cotton,resolution=0)
        for j in range(ny):
            y=(j+.5)*sy-depth/2
            pts=[(side*(width/2+sx*.43*math.sin(q*math.pi/12)),y+sy*.49*math.cos(q*math.pi/12),.10) for q in range(13)]
            a.tube("Scalloped side",pts,.09,cotton,resolution=0)
    return a.root
