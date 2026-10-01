"""Fine-veined beveled marble top on a pair of carved trestle pedestals."""
import bpy
from . import geometry as G, materials as M


def build(name="Marble table",loc=(0,0,0),rot_z=0,width=106,depth=70,height=75.7,thickness=3.5,
          tone=(.32,.30,.28),wear=.4,seed=1,quiet=(28,20),back_wings=0,polish=0) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    mat=M.fine_marble(name+" fine marble",tone,wear,seed,quiet,polish)
    a.block("Polished marble top",(width,depth,thickness),(0,0,height-thickness/2),mat,.65)
    a.block("Ogee lower edge",(width-1.3,depth-1.3,.65),(0,0,height-thickness+.1),mat,.25)
    if back_wings:
        for sign in (-1,1):
            a.block("Console return top",(width*.27,back_wings,thickness),
                    (sign*width*.365,depth/2+back_wings/2,height-thickness/2),mat,.65)
    for x in (-width*.29,width*.29):
        a.block("Trestle foot",(15,depth*.8,5),(x,0,2.5),mat,1)
        a.lathe("Carved pedestal",[(0,5),(9,5),(9,7),(6.5,10),(5.2,14),(4.4,22),
                                  (4,height-18),(6,height-11),(9,height-8),(9,height-thickness),(0,height-thickness)],
                mat,(x,0,0),segments=48)
    return a.root
