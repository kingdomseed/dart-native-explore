"""Planked bench with inset apron drawers, brass pulls and a removable bench pin."""
import bpy
from . import geometry as G, materials as M, oak_table


def build(name="Jeweler walnut bench",loc=(0,0,0),rot_z=0,width=112,depth=75,height=75,
          wood_tone=(.11,.046,.018),wear=.65,seed=1,bench_pin=True,rear_recess=None) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    a.add(oak_table.build(name+" joinery",width=width,depth=depth,height=height,thickness=4,
          wood_tone=wood_tone,wear=wear,seed=seed,scorch=.03,leg_width=6,leg_inset=(10,10),grain_scale=1.7,rear_recess=rear_recess))
    for i,ob in enumerate(a.root.children_recursive):
        if ob.type=="MESH" and ob.name.startswith("Oak plank"):
            ob.data.materials.clear()
            ob.data.materials.append(M.bench_walnut(name+f" rubbed board {i}",tuple(c*(.85+i%3*.1) for c in wood_tone),wear,seed+i))
    wood=M.oak(name+" drawers",wood_tone,wear,seed)
    brass=M.machined_metal(name+" hardware","brass",wear,seed)
    for sx in (-1,1):
        x=sx*width*.29
        a.block("Inset apron drawer",(width*.30,2,10),(x,-depth/2+6,height-10),wood,.3)
        for z in (height-14,height-6):a.block("Drawer beading",(width*.28,.3,.45),(x,-depth/2+4.9,z),wood,.15)
        a.ring("Drop drawer pull",1.7,.28,(x,-depth/2+4.25,height-10),brass,plane="XZ",ellipse=.65)
        a.sphere("Pull rose",.75,(x,-depth/2+4.65,height-9),brass,scale=(1,.3,1))
    if bench_pin:
        pin=G.Asset(name+" bench pin",(0,-depth/2+1,height-1));a.add(pin.root)
        outline=[(-3.5,0),(-3.5,-13),(-1.2,-13),(0,-8),(1.2,-13),(3.5,-13),(3.5,0)]
        verts=[(x,y,z) for z in (-1.5,0) for x,y in outline];n=len(outline)
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        pin.mesh("V-notched sacrificial bench pin",verts,faces,M.oak(name+" cut beech",(.28,.15,.06),wear,seed,axis="Y"),.15)
        pin.block("Bench pin clamp",(9,3,2.5),(0,.7,-.6),brass,.25)
    return a.root
