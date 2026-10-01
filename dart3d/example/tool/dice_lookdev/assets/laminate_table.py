"""1960s-80s laminate dining table with rolled aluminium edging and tapered legs."""
import math
import bpy
import env_common as E
from . import geometry as G, materials as M
from .crt_terminal import rounded_rect


def build(name="Laminate kitchen table",loc=(0,0,0),rot_z=0,width=105,depth=76,height=75,
          thickness=2.8,wood_tone=(.24,.105,.032),wear=.45,seed=1,rear_recess=None) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    top=M.wood_laminate(name+" walnut laminate",wood_tone,wear,seed)
    wood=M.oak(name+" birch legs",tuple(c*.7 for c in wood_tone),wear,seed,axis="Z",grain_scale=2)
    metal=M.polished_metal(name+" aluminium binding",(.52,.53,.48),wear,seed,.28)
    # Rounded corners are a full profile, not an excessive box bevel.
    path=rounded_rect(width,depth,5,16)
    if rear_recess:
        rx,ry=rear_recess
        path=path[:17]+[(rx*math.cos(i*math.pi/48),depth/2-ry*math.sin(i*math.pi/48)) for i in range(49)]+path[17:]
    n=len(path)
    verts=[(x,y,z) for z in (height-thickness,height) for x,y in path]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    a.mesh("Continuous printed laminate top",verts,faces,top,bevel=.18)
    for z in (height-thickness+.35,height-.45):
        a.tube("Rolled edge bead",[(x,y,z) for x,y in path],.17,metal,True)
    a.tube("Ribbed aluminium edge band",[(x,y,height-thickness/2) for x,y in path],.38,metal,True)
    for x in (-width/2+8,width/2-8):
        a.block("End apron",(2,depth-16,7),(x,0,height-thickness-4),wood,.3)
        for y in (-depth/2+8,depth/2-8):
            a.beam("Tapered splayed table leg",(x*1.06,y*1.06,.2),(x,y,height-thickness),3.6,3.6,wood,.45)
            a.block("Black foot glide",(3.8,3.8,.4),(x*1.06,y*1.06,.2),E.simple(name+" glides",(.018,.016,.012),.65),.25)
    for y in (-depth/2+8,depth/2-8): a.block("Long apron",(width-16,2,7),(0,y,height-thickness-4),wood,.3)
    return a.root
