"""Turned brass pricket with a reused dripping wax candle assembly."""
import math
import bpy
from . import geometry as G, materials as M, candles


def build(name="Scholar candlestick",loc=(0,0,0),rot_z=0,height=18,radius=4,
          candle_height=12,candle_radius=1.5,metal_finish="brass",wear=.4,seed=1,energy=650,flame_strength=12) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z); r=radius; h=height
    metal=M.metal(name+" antique metal",metal_finish,wear,seed)
    a.lathe("Turned pricket foot and stem",[(0,0),(r,0),(r*1.02,.5),(r*.92,1.2),(r*.72,1.5),
        (r*.65,2),(r*.37,3),(r*.23,h*.38),(r*.47,h*.45),(r*.51,h*.5),
        (r*.45,h*.56),(r*.22,h*.63),(r*.21,h*.85),(r*.50,h*.91),
        (r*.77,h*.96),(r*.80,h),(r*.69,h+.45),(0,h+.45)],metal,segments=48)
    for j in range(12):
        t=j*math.tau/12
        a.tube("Chased stem fluting",[(r*.23*math.cos(t),r*.23*math.sin(t),h*.63),
                (r*.215*math.cos(t),r*.215*math.sin(t),h*.84)],.065,metal,resolution=1)
    root=candles.build(name+" wax",loc=(0,0,h+.3),height=candle_height,radius=candle_radius,
                       count=1,tone=(.72,.52,.27),wear=wear,seed=seed,energy=energy)
    a.add(root)
    flame=M.flame(name+" bright candle flame",flame_strength)
    for ob in root.children_recursive:
        if ob.name.startswith("Candle drip pan"):
            ob.data.materials.clear(); ob.data.materials.append(metal)
        if ob.name.startswith("Small candle flame"):
            ob.data.materials.clear(); ob.data.materials.append(flame)
    return a.root
