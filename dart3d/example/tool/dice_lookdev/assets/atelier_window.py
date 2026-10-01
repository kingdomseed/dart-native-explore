"""Oak mullioned casement looking onto layered sunset roofs and slender spires."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M, cottage_window


def build(name="Sunset atelier window",loc=(0,0,0),rot_z=0,width=130,height=130,
          wood_tone=(.09,.033,.017),wear=.55,seed=1,view=True,exterior_slope=.48,
          sky_strength=1.3,energy=90000,city_style="gabled",town_altitude=0,sky_altitude=0) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    a.add(cottage_window.build(name+" casement",width=width,height=height,panes=3,rows=3,
        wood_tone=wood_tone,wear=wear,seed=seed,density=0,view=False))
    if not view:return a.root
    rng=random.Random(seed)
    sky=M.atelier_sky(name+" clouded sunset",sky_strength,seed)
    a.block("Sunset beyond the atelier",(width*9,1,height*6),(0,750,-750*exterior_slope+height*.6+sky_altitude),sky,0)
    sun=E.emissive(name+" late sun",(1,.55,.16),2.2)
    a.sphere("Sun on the horizon",17,(width*.85,720,-720*exterior_slope+height*.65+sky_altitude),sun,scale=(1,.1,1),subdiv=3)
    lit=E.emissive(name+" scattered city lights",(1,.53,.18),1.8)
    for layer in range(3):
        y=170+layer*160
        col=[(.035,.039,.053),(.067,.074,.103),(.115,.12,.17)][layer]
        wall=E.simple(name+f" distant masonry {layer}",col,.82,Emission_Color=(*col,1),Emission_Strength=.7)
        roof=E.simple(name+f" slate roof {layer}",tuple(c*.65 for c in col),.7,Emission_Color=(*col,1),Emission_Strength=.3)
        for i in range(14):
            x=(i-6.5)*(24+layer*12)+rng.uniform(-5,5)
            w=rng.uniform(16,29)+layer*5;h=rng.uniform(30,68)+layer*12
            z=-y*exterior_slope-10+town_altitude
            a.block("Distant city facade",(w,22,h+100),(x,y,z+(h-100)/2),wall,.25)
            if city_style=="spires":
                a.extrude("Low distant roof",[(x-w*.55,z+h),(x-w*.24,z+h+5),(x+w*.24,z+h+5),(x+w*.55,z+h)],27,roof,y=y,bevel=.1)
            else:
                a.extrude("Steep city gable",[(x-w*.58,z+h),(x,z+h+18),(x+w*.58,z+h)],27,roof,y=y,bevel=.1)
            if i%4==1:
                th=h+rng.uniform(28,56)
                a.cylinder("Slender skyline tower",w*.18,th,(x,y-3,z+th/2),wall,segments=8,bevel=.15)
                if city_style=="spires":
                    a.lathe("Slender sunset steeple",[(w*.24,0),(w*.24,2),(w*.15,4),(w*.12,14),(.6,35),(0,41)],roof,loc=(x,y-3,z+th),segments=12)
                    a.cylinder("Steeple collar",w*.22,2,(x,y-3,z+th+5),wall,segments=12,bevel=.15)
                else:
                    a.cylinder("Pointed skyline spire",w*.29,29,(x,y-3,z+th+14.5),roof,segments=8,r2=0,bevel=0)
            for row in range(4):
                for coln in range(3):
                    if rng.random()<.32:
                        a.block("Warm city window",(1.2,.15,2.3),(x+(coln-1)*w*.24,y-11.15,z+8+row*12),lit,.12)
    if energy:a.light("Sunset through atelier",(width*.25,8,height*.60),energy,(1,.52,.25),width*.65,(0,-140,-15),"AREA")
    return a.root
