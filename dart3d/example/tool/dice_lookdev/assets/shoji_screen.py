"""Sliding shoji with half-lap lattice, translucent paper and recessed pulls."""
import bpy
from . import geometry as G, materials as M


def build(name="Shoji",loc=(0,0,0),rot_z=0,width=85,height=190,columns=5,rows=9,
          wood_tone=(.055,.024,.009),paper_tone=(.55,.43,.30),glow=.12,wear=.3,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    wood=M.oak(name+" cedar",wood_tone,wear,seed,axis="Z")
    paper=M.washi(name+" paper",paper_tone,glow,seed)
    low=height*.16
    for x in (-width/2+2,width/2-2):a.block("Rebated stile",(4,3.2,height),(x,0,height/2),wood,.15)
    for z,h in ((2,4),(low,3),(height-2,4)):
        a.block("Mortised cross rail",(width-4,3.4,h),(0,0,z),wood,.14)
    a.block("Lower floating panel",(width-7,1.5,low-4),(0,.4,low/2),wood,.16)
    a.mesh("Translucent paper back",[(-width/2+3,1,low),(width/2-3,1,low),(width/2-3,1,height-3),(-width/2+3,1,height-3)],[(0,1,2,3)],paper)
    for i in range(1,columns):a.block("Vertical kumiko",(.85,1.3,height-low-3),(-width/2+i*width/columns,-.1,(low+height-3)/2),wood,.06)
    for i in range(1,rows):a.block("Horizontal kumiko",(width-5,1,.75),(0,-.45,low+(height-low)*i/rows),wood,.06)
    metal=M.metal(name+" iron pull","iron",wear,seed)
    a.block("Recessed finger pull",(1.4,.22,7),(-width/2+2,-1.72,height*.42),metal,.6)
    for z in (-.3,height+.3):a.block("Sliding track tongue",(width-5,1,1),(0,0,z),wood,.1)
    return a.root
