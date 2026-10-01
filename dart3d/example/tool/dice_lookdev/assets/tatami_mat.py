"""Individually bound rush-straw mats with softly compressed edges."""
import bpy
from . import geometry as G, materials as M


def build(name="Tatami",loc=(0,0,0),rot_z=0,width=90,depth=180,thickness=4.5,
          tone=(.28,.25,.11),border_tone=(.017,.031,.025),wear=.35,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    straw=M.rush_weave(name+" rush weave",tuple(c*(1+.3*(wear-.35)) for c in tone),seed)
    cloth=M.woven_silk(name+" bound cloth",border_tone,seed)
    a.block("Pressed straw core",(width,depth,thickness),(0,0,thickness/2),straw,.65)
    for x in (-width/2+1.8,width/2-1.8):
        a.block("Woven cloth edge binding",(3.6,depth-.25,thickness+.07),(x,0,thickness/2+.02),cloth,.5)
    return a.root
