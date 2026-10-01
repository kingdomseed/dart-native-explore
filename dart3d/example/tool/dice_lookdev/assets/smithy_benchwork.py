"""Small bench work: a worn hone, cut leather and square-shanked forged nails."""
import random
import bpy
from . import geometry as G, materials as M


def build(name="Smithy bench work",loc=(0,0,0),rot_z=0,width=16,wood_tone=(.09,.033,.014),
          metal_finish="iron",wear=.7,seed=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed);s=width/16
    stone=M.stone(name+" oilstone",(.11,.105,.09),wear,seed)
    leather=M.leather(name+" leather offcut",wood_tone,wear,seed)
    iron=M.metal(name+" forged nails",metal_finish,wear,seed)
    a.hewn_block("Hollowed sharpening stone",(9*s,3.5*s,1.2*s),(-2*s,1*s,.6*s),stone,.22*s,.018,seed)
    outline=[(3,-5),(7,-4.3),(7.6,-1),(6.3,.4),(3.3,-.2),(2.1,-2.8)]
    n=len(outline)
    a.mesh("Cut leather offcut",[(x*s,y*s,z*s) for z in (0,.18) for x,y in outline],
           [tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],leather,bevel=.055*s)
    for j in range(5):
        x=(-6+j*1.65)*s;y=(-3+rng.uniform(-.5,.5))*s;length=rng.uniform(2.3,3.7)*s
        tip=(x+length*.26,y-length,.07*s)
        a.beam("Square tapered nail shank",(x,y,.16*s),tip,.14*s,.14*s,iron,.025*s)
        head=a.block("Hammered square nail head",(.48*s,.15*s,.38*s),(x,y,.20*s),iron,.075*s)
        head.rotation_euler.z=rng.uniform(-.2,.2)
    return a.root
