"""Pegged oak half-timbering over lime plaster, with true rectangular window openings."""
import math
import bpy
import room_common as RC
from . import geometry as G, materials as M


def build(name="Inn timber wall",loc=(0,0,0),rot_z=0,width=300,height=230,thickness=14,
          bays=4,openings=(),wood_tone=(.072,.030,.011),tone=(.40,.30,.18),wear=.7,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    plaster=M.limewash(name+" rough plaster",tone,wear,seed)
    post=M.oak(name+" oak posts",wood_tone,wear,seed,axis="Z",grain_scale=1.3)
    rail=M.oak(name+" oak rails",wood_tone,wear,seed+1,grain_scale=1.3)
    pegs=M.oak(name+" end-grain pegs",tuple(c*1.7 for c in wood_tone),wear,seed+2,axis="Y")
    wall=RC.wall_plane(name+" plaster infill",width,height,[(x,z+h/2,w,h) for x,z,w,h in openings],plaster,thickness=thickness)
    a.add(wall)
    def clear(x,z,margin=6):
        return all(not(cx-w/2-margin<x<cx+w/2+margin and bottom-margin<z<bottom+h+margin) for cx,bottom,w,h in openings)
    for j in range(bays+1):
        x=-width/2+j*width/bays
        cuts=[0,height]
        for cx,bottom,w,h in openings:
            if abs(x-cx)<w/2+6:cuts.extend((max(0,bottom-5),min(height,bottom+h+5)))
        cuts=sorted(set(cuts))
        for za,zb in zip(cuts,cuts[1:]):
            if clear(x,(za+zb)/2,0):a.block("Hand-hewn oak post",(9,thickness+3,zb-za),(x,-1,(za+zb)/2),post,1.0)
    for z in (5,72,height-7):
        cuts=[-width/2,width/2]
        for cx,bottom,w,h in openings:
            if bottom-6<z<bottom+h+6:cuts.extend((cx-w/2-4,cx+w/2+4))
        cuts=sorted(set(max(-width/2,min(width/2,v)) for v in cuts))
        for xa,xb in zip(cuts,cuts[1:]):
            if clear((xa+xb)/2,z,0):a.block("Mortised horizontal rail",(xb-xa,thickness+4,8),((xa+xb)/2,-1,z),rail,.9)
    for j in range(bays):
        xa=-width/2+j*width/bays+6;xb=xa+width/bays-12
        for za,zb in ((82,height-16),(14,62)):
            if all(clear(xa+(xb-xa)*t,za+(zb-za)*t) for t in (0,.2,.4,.6,.8,1)):
                a.beam("Diagonal pegged brace",(xa,-2,za),(xb,-2,zb),7,thickness+2,post,.8)
                for x,z in ((xa+5,za+6),(xb-5,zb-6)):
                    peg=a.cylinder("Wooden drawbore peg",.72,.7,(x,-thickness/2-2.2,z),pegs)
                    peg.rotation_euler.x=math.pi/2
    for cx,bottom,w,h in openings:
        for x in (cx-w/2-5,cx+w/2+5):a.block("Window trimmer post",(9,thickness+5,h+18),(x,-2,bottom+h/2),post,.8)
        for z in (bottom-5,bottom+h+5):a.block("Window header rail",(w+19,thickness+5,9),(cx,-2,z),rail,1)
    return a.root
