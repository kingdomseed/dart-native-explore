"""Six-sided quartz prisms with pyramidal terminations and luminous inclusions."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M


def build(name="Amethyst cluster",loc=(0,0,0),rot_z=0,radius=8,height=15,count=13,bowl=True,
          tone=(.21,.055,.38),metal_finish="brass",wear=.3,seed=2,energy=70) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z); rng=random.Random(seed)
    mat=M.amethyst(name+" quartz",tone,seed)
    metal=M.polished_metal(name+" bowl",(.54,.31,.095) if metal_finish=="brass" else (.5,.19,.08),wear,seed,.22)
    base=1
    if bowl:
        h=radius*.45; base=h*.36
        a.lathe("Hammered crystal bowl",[(0,0),(radius*.45,0),(radius*.5,.5),(radius*.6,h*.3),
                (radius*.88,h*.72),(radius,h),(radius*.98,h+.25),(radius*.94,h-.1),
                (radius*.82,h*.66),(radius*.52,h*.25),(0,h*.23)],metal,segments=64)
        a.ring("Rolled brass lip",radius*.99,.14,(0,0,h),metal)
    core,k=E.material(name+" luminous mineral inclusions")
    n=k.noise(k.coords().outputs["Generated"],5,3).outputs["Fac"]
    strength=k.ramp(n,[(.4,(.04,.04,.04)),(.57,(.4,.4,.4)),(.72,(1.4,1.4,1.4))])
    k.surface(k.emission((.42,.16,.7,1),k.math("MULTIPLY",strength,2.5)))
    for i in range(count):
        t=rng.uniform(0,math.tau); rr=radius*.72*math.sqrt(rng.random()) if i else 0
        h=height*(1 if i==0 else rng.uniform(.26,.8))
        r=h*rng.uniform(.13,.2)
        verts=[(r*s*math.cos(j*math.tau/6),r*s*math.sin(j*math.tau/6),z)
               for s,z in ((.78,0),(1,h*.18),(1,h*.73)) for j in range(6)]
        verts.append((r*.13,-r*.07,h))
        faces=[tuple(reversed(range(6)))]
        faces += [(row*6+j,row*6+(j+1)%6,(row+1)*6+(j+1)%6,(row+1)*6+j) for row in range(2) for j in range(6)]
        faces += [(12+j,12+(j+1)%6,18) for j in range(6)]
        ob=a.mesh("Terminated amethyst prism",verts,faces,mat,bevel=.012)
        ob.location=(rr*math.cos(t),rr*math.sin(t),base+(rr/radius)**2*radius*.35)
        ob.rotation_euler=(rng.uniform(-.28,.28),rng.uniform(-.28,.28),t)
        inner=a.mesh("Quartz internal inclusion",[(x*.36,y*.36,z*.51+h*.13) for x,y,z in verts],faces,core)
        inner.location=ob.location; inner.rotation_euler=ob.rotation_euler
    if energy:a.light("Amethyst reflected glow",(0,0,height*.5),energy,(.48,.23,1),radius*.4)
    return a.root
