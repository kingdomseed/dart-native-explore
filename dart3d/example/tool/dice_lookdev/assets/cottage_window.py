"""Deep oak casement with divided lights and individually modeled gentle rain."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M, rain_window


def build(name="Rainy oak casement",loc=(0,0,0),rot_z=0,width=125,height=160,
          panes=3,rows=4,wood_tone=(.08,.028,.012),wear=.65,seed=1,
          density=.026,drop_radius=.18,view=True,sky_colors=None,sky_strength=1.4,exterior_slope=0,town_altitude=0,sky_horizon=.35) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    wood=M.oak(name+" oak framing",wood_tone,wear,seed,axis="Z")
    bronze=M.metal(name+" latch brass","brass",wear,seed)
    window=rain_window.build(name+" rain",width=width,height=height,panes=panes,density=density,
                             drop_radius=drop_radius,wear=wear,seed=seed,fog=.5,large_drop_fraction=.09)
    a.add(window)
    for ob in window.children_recursive:
        if any(x in ob.name for x in ("mullion","bead","rail","gasket")) and ob.type=="MESH":
            ob.data.materials.clear();ob.data.materials.append(wood)
    for x in (-width/2-5,width/2+5):
        a.block("Deep window reveal",(9,16,height+18),(x,4,height/2),wood,1)
        a.block("Moulded oak stile",(3,3,height+22),(x,-5,height/2),wood,.8)
    for z in (-6,height+6):
        a.block("Oak window lintel",(width+20,16,9),(0,4,z),wood,1.2)
        a.block("Lintel ogee bead",(width+24,3,3),(0,-5,z),wood,.8)
    a.block("Rounded window seat sill",(width+27,28,5),(0,-4,-12),wood,1.5)
    for row in range(1,rows):
        a.block("Cross-light glazing bar",(width,3.8,2.5),(0,-1,height*row/rows),wood,.45)
    for col in range(1,panes):
        x=-width/2+width*col/panes
        a.block("Brass casement catch",(1.6,1.2,5),(x,-3.1,height*.42),bronze,.35)
        a.tube("Turned casement handle",[(x,-4,height*.42),(x,-6,height*.42+2),(x+2,-6,height*.42+3)],.45,bronze)
    if view:
        m,k=E.material(name+" blue rainy dusk")
        uv=k.coords().outputs["Generated"]
        n=k.noise(uv,4,4,.65).outputs["Fac"]
        col=k.ramp(n,[(.25,(.015,.035,.085)),(.7,(.065,.12,.26))])
        if sky_colors is not None:
            sep=k.node("ShaderNodeSeparateXYZ");k.link(uv,sep.inputs[0])
            col=k.ramp(sep.outputs["Z"],[(0,sky_colors[0]),(sky_horizon,sky_colors[1]),(1,sky_colors[2])])
            col=k.mix(.2,col,k.ramp(n,[(.2,tuple(c*.3 for c in sky_colors[1])),(.8,sky_colors[2])]))
        k.surface(k.emission(col,sky_strength))
        a.block("Clouded night beyond glass",(width*3,.5,height*(4 if sky_colors is not None else 2)),(0,210,height*.65-exterior_slope*210),m,0)
        silhouette=E.simple(name+" distant slate roofs",(.025,.041,.068),.9,Emission_Color=(.025,.039,.062,1),Emission_Strength=.4)
        lit=E.simple(name+" distant warm windows",(.6,.23,.04),.5,Emission_Color=(1,.36,.065,1),Emission_Strength=2.5)
        rng=random.Random(seed)
        for i in range(9):
            x=(i-4)*width*.24;w=rng.uniform(14,25);h=rng.uniform(30,65);z=-25-exterior_slope*140+town_altitude
            foundation=height*2 if sky_colors is not None else 0
            a.block("Distant cottage",(w,12,h+foundation),(x,140,z+(h-foundation)/2),silhouette,.3)
            a.extrude("Slate pitched roof",[(x-w*.6,z+h),(x,z+h+15),(x+w*.6,z+h)],16,silhouette,y=139,bevel=.2)
            for xx in (-w*.24,w*.24):
                if rng.random()<.6: a.block("Tiny warm window",(2.1,.3,4.3),(x+xx,133.7,z+h*.68),lit,.1)
        a.light("Blue rain-window spill",(0,20,height*.58),90000,(.32,.48,1),size=width*.6,target=(0,-100,20),kind="AREA")
    return a.root
