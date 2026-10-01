"""Weighted optical inspection stand with a jointed arm and real loupe lens."""
import bpy
from . import geometry as G,materials as M,jeweler_tools


def build(name="Mounted jeweler loupe",loc=(0,0,0),rot_z=0,height=14,radius=2.5,
          metal_finish="brass",wear=.55,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    metal=M.machined_metal(name+" aged brass",metal_finish,wear,seed)
    a.lathe("Weighted loupe stand foot",[(0,0),(3.7,0),(4,.3),(4,.8),(3.5,1.1),(2.7,1.3),(1,1.6),(0,1.6)],metal)
    a.cylinder("Inspection column",.32,height,(0,0,height/2+.8),metal)
    a.ring("Column locking collar",.48,.13,(0,0,height-2),metal)
    a.beam("Articulated lens arm",(0,0,height-2),(3.4,0,height-.4),.45,.55,metal,.12)
    a.sphere("Tilting lens joint",.65,(3.4,0,height-.4),metal)
    loupe=jeweler_tools.build(name+" optical barrel",radius=radius,wear=wear,seed=seed)
    a.add(loupe);loupe.rotation_euler.y=-.45;loupe.location=(3.4+radius,0,height-1)
    a.beam("Lens mounting tang",(3.4,0,height-.4),(3.4+radius,0,height-.2),.5,.5,metal,.12)
    return a.root
