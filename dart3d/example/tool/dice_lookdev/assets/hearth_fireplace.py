"""Domestic fieldstone hearth with a shallow stone arch, charred logs and layered fire."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M, forge, firewood


def build(name="Fieldstone fireplace",loc=(0,0,0),rot_z=0,width=150,depth=60,height=190,
          hearth_height=18,stone_tone=(.13,.115,.09),wood_tone=(.09,.036,.01),
          wear=.8,seed=1,energy=260000,rugged=False,flame_height=1.0) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed)
    stones=[M.stone(name+f" fieldstone {i}",tuple(c*(.7+i*.10) for c in stone_tone),wear,seed+i) for i in range(7)]
    arch_mats=[M.stone(name+f" smoked voussoir {i}",tuple(c*(.7+i*.10) for c in stone_tone),wear,seed+i,soot=.65 if rugged else .3) for i in range(7)]
    mortar=M.stone(name+" recessed mortar",(.036,.031,.025),.9,seed)
    firebrick=M.stone(name+" soot-blackened lining",(.065,.036,.018),.8,seed,soot=.75)
    iron=M.metal(name+" blackened andirons","iron",wear,seed)
    oak=M.oak(name+" worn oak mantel",wood_tone,wear,seed)
    def stone(label,size,pos,index=0,soot=False):
        mat=firebrick if soot else stones[index%7]
        if rugged and any(term in label.lower() for term in ("fieldstone","chimney stone")):
            ob=a.add(E.rock(label,1,pos,mat,seed=seed+index,subdiv=3,strength=.16,squash=(1,1,1)))
            ob.rotation_euler=(0,0,0)
            for v in ob.data.vertices:
                for axis in range(3):v.co[axis]=math.copysign(abs(v.co[axis])**.58,v.co[axis])
            for axis in range(3):
                low=min(v.co[axis] for v in ob.data.vertices);high=max(v.co[axis] for v in ob.data.vertices)
                for v in ob.data.vertices:v.co[axis]=(v.co[axis]-(low+high)/2)*size[axis]/(high-low)
            return ob
        return a.hewn_block(label,size,pos,mat,bevel=3.8 if rugged else 2.5,wear=wear*(.7 if rugged else 1.5),seed=seed+index)
    stone("Broad hearth flag",(width+14,depth+28,hearth_height),(0,0,hearth_height/2),0)
    mouth=width*.57; spring=hearth_height+57; rise=16
    jamb=(width-mouth)/2
    for side in (-1,1):
        a.block("Recessed jamb mortar",(jamb-3,depth*.42 if rugged else depth-3,spring-hearth_height),(side*(mouth/2+jamb/2),depth*.25 if rugged else 5,(spring+hearth_height)/2),mortar,.5)
        for row in range(4):
            z=hearth_height+(row+.5)*(spring-hearth_height)/4
            if rugged:
                for col,f in enumerate((.43,.57) if row%2 else (.59,.41)):
                    start=0 if col==0 else (1-f)*jamb
                    stone("Irregular jamb fieldstone",(jamb*f-1.5,depth+rng.uniform(-3,2),(spring-hearth_height)/4-rng.uniform(.8,2.2)),
                          (side*(mouth/2+start+jamb*f/2),4+rng.uniform(-1.3,1.3),z+rng.uniform(-.6,.6)),row*9+col+(0 if side<0 else 37))
            else:
                stone("Rounded jamb fieldstone",(jamb-1,depth,(spring-hearth_height)/4-1.1),
                      (side*(mouth/2+jamb/2),4,z),row+(0 if side<0 else 11))
    r=(mouth*mouth/4+rise*rise)/(2*rise)
    cz=spring+rise-r
    angle=math.asin(mouth/2/r)
    for i in range(11):
        a0=math.pi/2-angle+2*angle*i/11+.006;a1=math.pi/2-angle+2*angle*(i+1)/11-.006
        ob=G.arch_block(a,"Hand-cut arch voussoir",r,r+13,a0,a1,depth,(0,4,cz),arch_mats[(i+2)%7],2.6 if rugged else 2.0)
        ob.rotation_euler.y=rng.uniform(-.012,.012)
    top=spring+rise+14
    rows=max(1,math.ceil((height-top)/18) if rugged else int((height-top)/18))
    for row in range(rows):
        z=top+(row+.5)*(height-top)/rows if rugged else top+9+row*18
        n=5 if row%2 else 4
        spans=[rng.uniform(.7,1.3) for _ in range(n)]
        spans=[v/sum(spans)*width for v in spans]
        x=-width/2
        for i,w in enumerate(spans):
            stone("Random bonded chimney stone",(w-1,depth-6,16.8+rng.uniform(-1.5,1.5)),(x+w/2,7+rng.uniform(-1,1),z+rng.uniform(-.8,.8)),row*7+i)
            x+=w
    if rugged:
        a.block("Recessed chimney mortar",(width-3,depth*.32,height-top),(0,depth*.32,(height+top)/2),mortar,.8)
    mantel_z=spring+rise+24
    a.block("Thick oak mantel",(width+17,depth+12,7),(0,0,mantel_z),oak,1.2)
    for x in (-width*.35,width*.35):
        a.extrude("Scroll mantel corbel",[(x-4,mantel_z-3),(x+4,mantel_z-3),(x+4,mantel_z-16),(x,mantel_z-22),(x-4,mantel_z-16)],13,oak,y=-depth/2+6,bevel=1.5)
    stone_receivers=set(a.root.children_recursive)
    a.block("Dark rear firebrick",(mouth,6,60),(0,depth/2-3,hearth_height+30),firebrick,.7)
    for row in range(4):
        for col in range(6):
            a.block("Firebrick joints",(mouth/6-.65,.9,13.6),(-mouth/2+(col+.5)*mouth/6,depth/2-6.2,hearth_height+7+row*14.2),firebrick,.35)
    a.block("Black ash bed",(mouth-5,depth-7,1.5),(0,2,hearth_height+.9),firebrick,.5)
    stone_receivers |= set(a.root.children_recursive)
    coal=M.coal(name+" embers",.45)
    for i in range(72):
        x=rng.uniform(-mouth*.42,mouth*.42);y=rng.uniform(-depth*.31,depth*.28)
        a.add(E.rock("Ash-crusted ember",rng.uniform(1.1,2.7),(x,y,hearth_height+2),coal,seed=seed+i,subdiv=1))
    for i,(x,y,z,ang,l) in enumerate(((-8,5,2,.15,61),(10,-5,8,-.29,53),(-5,4,15,.34,47))):
        a.add(firewood.build(name+f" burning log {i}",loc=(x,y,hearth_height+z),rot_z=ang,length=l,radius=4.6,heat=.13,seed=seed+i))
    flame=M.forge_flame(name+" golden flame",18 if rugged else 16)
    for i in range(31 if rugged else 27):
        x=rng.uniform(-mouth*.34,mouth*.34);y=rng.uniform(-10,14)
        forge.flame_sheet(a,(x,y,hearth_height+rng.uniform(4,12)),rng.uniform(4.5,10) if rugged else rng.uniform(3,7),rng.uniform(19,47)*flame_height,flame,
                          lean=rng.uniform(-9,9),phase=rng.uniform(0,6),angle=rng.uniform(-.4,.4))
    for x in (-mouth*.32,mouth*.32):
        a.beam("Andiron foot",(x,-depth*.3,hearth_height),(x,-depth*.3,hearth_height+24),2,2,iron,.35)
        a.sphere("Andiron finial",2.1,(x,-depth*.3,hearth_height+26),iron)
        a.beam("Andiron log cradle",(x,-depth*.32,hearth_height+5),(x,depth*.3,hearth_height+5),2.5,2.5,iron,.4)
    spark=E.simple(name+" tiny sparks",(.5,.12,.008),.6,Emission_Color=(1,.25,.02,1),Emission_Strength=8)
    for i in range(6):
        a.sphere("Rising spark",rng.uniform(.07,.13),(rng.uniform(-25,25),rng.uniform(-12,10),hearth_height+rng.uniform(25,65)),spark,scale=(.5,.5,2),subdiv=1)
    a.light("Fire within logs",(0,-3,hearth_height+23),energy,(1,.35,.065),size=10)
    a.light("Fire on stone",(-17,-14,hearth_height+44),energy*.30,(1,.46,.12),size=14)
    a.light("Warm hearth spill",(0,-25,hearth_height+21),energy*.32,(1,.36,.07),size=20,target=(0,-100,5),kind="AREA")
    receivers=bpy.data.collections.new(name+" illuminated masonry")
    for ob in stone_receivers:
        if ob.type in {"MESH","CURVE"}: receivers.objects.link(ob)
    for ob in a.root.children_recursive:
        if ob.type=="LIGHT" and ob.name.startswith(("Fire within","Fire on")):
            ob.light_linking.receiver_collection=receivers
    return a.root
