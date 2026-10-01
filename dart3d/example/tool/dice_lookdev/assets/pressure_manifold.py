"""Floor-mounted receiver with flanged copper feeds, valves and pressure dials."""
import bpy
from . import geometry as G, materials as M, pipework


def build(name="Pressure receiver",loc=(0,0,0),rot_z=0,height=52,radius=5,
          metal_finish="brass",wear=.7,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    metal=M.machined_metal(name+" hammered receiver",metal_finish,wear,seed)
    trim=M.machined_metal(name+" flange edges",metal_finish,wear*.4,seed+1)
    iron=M.machined_metal(name+" dark straps","iron",wear,seed+2)
    r=radius;h=height
    profile=[(0,4),(r*.55,4),(r*.85,5),(r,7),(r,h*.80),
             (r*.96,h*.85),(r*.8,h*.89),(r*.4,h*.92),(0,h*.925)]
    a.lathe("Spun pressure vessel",profile,metal,segments=64)
    for sx in (-1,1):
        a.block("Receiver mounting shoe",(r*.72,r*1.5,1),(sx*r*.72,0,.5),iron,.18)
        a.beam("Receiver support leg",(sx*r*.72,0,1),(sx*r*.65,0,6),.8,1,trim,.14)
        for yy in (-r*.56,r*.56):
            a.cylinder("Foundation bolt",.26,.45,(sx*r*.72,yy,1.15),trim,segments=6,bevel=.035)
    for z in (8,h*.77):pipework.flange(a,(0,0,z),(0,0,1),r*.68,trim,iron,.75)
    for i,(xx,z,reading) in enumerate(((-r*1.75,h*.64,.64),(r*1.65,h*.36,.42))):
        feed=pipework.build(name+f" dial feed {i}",points=((0,0,z-r),(xx,0,z-r),(xx,0,z)),radius=.65,wear=wear,seed=seed+i)
        a.add(feed)
        a.add(pipework.build(name+f" pressure dial {i}",loc=(xx,0,z+r*.42),kind="gauge",gauge_radius=r*.67,reading=reading,wear=wear,seed=seed+i))
    a.add(pipework.build(name+" supply riser",points=((-r*2.3,r*.8,.88),(-r*2.3,r*.8,h*.98),(0,r*.8,h*.98),(0,0,h*.88)),radius=.9,wear=wear,seed=seed+4))
    a.add(pipework.build(name+" lower isolator",loc=(-r*2.3,r*.8,h*.31),kind="valve",radius=.9,wheel_radius=2.6,wear=wear,seed=seed+4))
    a.add(pipework.build(name+" return bend",points=((0,0,h*.15),(r*2.7,0,h*.15),(r*2.7,0,h*.63)),radius=.8,wear=wear,seed=seed+5))
    return a.root
