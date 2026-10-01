"""Hinged walnut specimen case, velvet cells, brass fittings and cut stones."""
import math
import random
import bpy
from . import geometry as G, materials as M, cut_gem


def build(name="Velvet gem case",loc=(0,0,0),rot_z=0,width=23,depth=15,height=3.7,
          columns=3,rows=2,lid_angle=110,wood_tone=(.13,.045,.018),
          velvet_tone=(.016,.012,.028),wear=.55,seed=1,stones=True) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z); rng=random.Random(seed)
    wood=M.oak(name+" walnut",wood_tone,wear,seed)
    velvet=M.velvet(name+" lining",velvet_tone,seed=seed,sheen_tone=(.10,.07,.15))
    brass=M.polished_metal(name+" fittings",(.57,.35,.12),wear,seed,.18)
    a.block("Recessed case bottom",(width-.8,depth-.8,.8),(0,0,.45),wood,.18)
    for x in (-width/2+.45,width/2-.45):
        a.block("Dovetailed case side",(.9,depth,height),(x,0,height/2),wood,.16)
    for y in (-depth/2+.45,depth/2-.45):
        a.block("Case end rail",(width-1,.9,height),(0,y,height/2),wood,.16)
    a.block("Padded velvet floor",(width-1.9,depth-1.9,.65),(0,0,1.05),velvet,.28)
    for i in range(1,columns):
        a.block("Velvet partition",(.42,depth-1.8,1.5),(-width/2+.9+(width-1.8)*i/columns,0,1.7),velvet,.19)
    for i in range(1,rows):
        a.block("Velvet partition",(width-1.8,.42,1.5),(0,-depth/2+.9+(depth-1.8)*i/rows,1.7),velvet,.19)
    for x in (-width*.36,width*.36):
        a.block("Protective corner brass",(2.3,.25,1.2),(x,-depth/2-.02,1),brass,.12)
        for xx in (-.72,.72):
            screw=a.cylinder("Slotted case screw",.12,.12,(x+xx,-depth/2-.18,1),brass,segments=12)
            screw.rotation_euler.x=math.pi/2
        a.cylinder("Hinge barrel",.24,3,(x,depth/2-.1,height),brass).rotation_euler.y=math.pi/2
    a.block("Latch escutcheon",(2,.3,1.7),(0,-depth/2-.17,2.7),brass,.25)
    a.ring("Latch bow",.55,.12,(0,-depth/2-.55,2.6),brass,plane="XZ",ellipse=.8,segments=24)
    lid=G.Asset(name+" hinged lid",(0,depth/2-.1,height))
    lid.root.rotation_euler.x=-math.radians(lid_angle)
    a.add(lid.root)
    lid.block("Moulded walnut lid",(width,depth,.8),(0,-depth/2,.4),wood,.22)
    lid.block("Padded lid inset",(width-2,depth-2,.5),(0,-depth/2,-.22),velvet,.3)
    for x in (-width/2+.9,width/2-.9):
        lid.block("Fine brass lid inlay",(.10,depth-1.7,.04),(x,-depth/2,-.015),brass,.03)
    colors=[(.018,.46,.18),(.62,.018,.07),(.025,.13,.60),(.85,.66,.23),(.34,.08,.5),(.82,.89,.96)]
    if stones:
        for iy in range(rows):
            for ix in range(columns):
                x=-width/2+.9+(ix+.5)*(width-1.8)/columns
                y=-depth/2+.9+(iy+.5)*(depth-1.8)/rows
                a.add(cut_gem.build(name+" specimen",loc=(x,y,1.38),radius=rng.uniform(1.05,1.6),
                    rot_z=rng.random()*3,cut="emerald" if (ix+iy)%3==0 else "brilliant",tone=colors[(ix+iy*columns+seed)%6],seed=seed+ix+iy))
    return a.root
