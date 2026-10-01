"""Chamfered granite altar, carved trestles and bronze inlaid geometric panels."""
import math
import bpy
from . import geometry as G, materials as M


def build(name="Carved stone altar",loc=(0,0,0),rot_z=0,width=108,depth=40,height=76,
          tone=(.13,.17,.22),metal_tone=(.37,.21,.075),frost=.65,wear=.6,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    stone=M.frozen_stone(name+" granite",tone,frost,wear,seed)
    bronze=M.polished_metal(name+" aged bronze",metal_tone,wear,seed,.32)
    a.block("Chamfered altar mensa",(width,depth,5),(0,0,height-2.5),stone,.75)
    a.block("Recessed cornice",(width-3,depth-2,2.5),(0,0,height-6.25),stone,.5)
    a.block("Lower moulding",(width-1,depth,1.6),(0,0,height-8.3),stone,.5)
    leg_scale=min(1,width/70)
    for x in (-width*.32,width*.32):
        a.block("Splayed stone foot",(20*leg_scale,depth*.90,5),(x,0,2.5),stone,.8)
        outline=[(x-9*leg_scale,5),(x-6*leg_scale,12),(x-6*leg_scale,height-17),(x-10*leg_scale,height-9),(x+10*leg_scale,height-9),
                 (x+6*leg_scale,height-17),(x+6*leg_scale,12),(x+9*leg_scale,5)]
        a.extrude("Carved altar trestle",outline,depth*.68,stone,bevel=.75)
        for side in (-1,1):
            y=side*(depth*.34+.06)
            a.tube("Trestle recessed border",[(x-4.8*leg_scale,y,15),(x-4.8*leg_scale,y,height-22),
                    (x,y,height-16),(x+4.8*leg_scale,y,height-22),(x+4.8*leg_scale,y,15)],.18,bronze)
            for z in (22,37,52):
                a.tube("Carved diamond inlay",[(x,y,z+4),(x+3.8*leg_scale,y,z),(x,y,z-4),(x-3.8*leg_scale,y,z)],.13,bronze,cyclic=True)
    a.block("Stone stretcher",(width*.64,7,7),(0,0,14),stone,.6)
    for side in (-1,1):
        y=side*(depth/2+.02)
        for x in (-width*.40,0,width*.40):
            a.tube("Mensa bronze chevron",[(x-5,y,height-3.5),(x,y,height-1.5),(x+5,y,height-3.5)],.075,bronze)
    return a.root
