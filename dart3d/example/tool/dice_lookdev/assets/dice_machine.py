"""Riveted gravity-output machine with a curved crown, sloping chute and meshed gearing."""
import math
import bpy
from . import geometry as G, materials as M, clockwork_gear, pipework


def build(name="Brass dice engine",loc=(0,0,0),rot_z=0,width=40,depth=36,height=75,
          output_height=None,metal_finish="brass",wear=.65,seed=1,
          reinforced=False,outlet_reach=.80) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    brass=M.machined_metal(name+" worked plating",metal_finish,wear,seed)
    trim=M.machined_metal(name+" rubbed edges",metal_finish,wear*.45,seed+1)
    iron=M.machined_metal(name+" dark mechanism","iron",wear,seed+2)
    steel=M.machined_metal(name+" bearing steel","steel",wear,seed+3)
    w,d,h=width,depth,height
    output=h*.56 if output_height is None else output_height
    lintel=h*.87
    front=-d*.35;back=d*.34
    for sx in (-1,1):
        a.lathe("Cast machine foot",[(0,0),(w*.17,0),(w*.19,.7),(w*.19,2),(w*.14,2.8),(w*.1,4),(0,4)],brass,
                loc=(sx*w*.37,0,0),segments=40)
        outline=[(sx*w*.48,3),(sx*w*.48,h*.72),(sx*w*.41,h*.83),
                 (sx*w*.34,h*.82),(sx*w*.34,8),(sx*w*.25,3)]
        a.extrude("Contoured cast cheek",outline,d*.77,brass,y=0,bevel=.45)
        a.beam("Polished guide column",(sx*w*.29,back,5),(sx*w*.29,back,h*.87),w*.07,w*.07,steel,.3)
        for z in (7,h*.37,h*.77):
            a.block("Bearing saddle",(w*.19,d*.86,3),(sx*w*.41,0,z),trim,.45)
            for yy in (-d*.43,d*.43):
                bolt=a.cylinder("Bearing bolt",.6,.7,(sx*w*.41,yy,z),iron,segments=6)
                bolt.rotation_euler.x=math.pi/2
    for z in (7,h*.36):a.beam("Cross shaft",(-w*.53,0,z),(w*.57,0,z),2.2,2.2,steel,.5)
    a.block("Recessed rear bulkhead",(w*.71,1.4,h*.62),(0,back,h*.39),iron,.35)
    for z in (h*.18,h*.24,h*.30,h*.36):
        a.block("Louver shadow slot",(w*.57,.6,1.3),(0,back-.8,z),iron,.4)
        a.beam("Louver rolled edge",(-w*.28,back-1,z+.7),(w*.28,back-1,z+.7),.25,.25,trim,.08)
    # A hollow arched crown: a curved roof, not a solid rounded box.
    verts=[];faces=[];segments=48
    for yy in (front,back):
        for radius,roof_height in ((w*.43,h-lintel),(w*.38,h-lintel-.8)):
            verts += [(radius*math.cos(i*math.pi/segments),yy,lintel+roof_height*math.sin(i*math.pi/segments))
                      for i in range(segments+1)]
    n=segments+1
    for i in range(segments):
        faces.extend(((i,i+1,n+i+1,n+i),(2*n+i,3*n+i,3*n+i+1,2*n+i+1),
                      (i,2*n+i,2*n+i+1,i+1),(n+i,n+i+1,3*n+i+1,3*n+i)))
    a.mesh("Hollow barrel-vault crown",verts,faces,brass,bevel=.20,smooth=True)
    for yy in (front-.18,back+.18):
        a.tube("Rolled crown seam",[(w*.43*math.cos(i*math.pi/48),yy,lintel+(h-lintel)*math.sin(i*math.pi/48)) for i in range(49)],.3,trim)
        for i in range(13):
            t=i*math.pi/12
            a.sphere("Crown seam rivet",.25,(w*.405*math.cos(t),yy-.2,lintel+(h-lintel)*math.sin(t)),iron,subdiv=1)
    crown=[(w*.425*math.cos(i*math.pi/48),lintel+(h-lintel-.25)*math.sin(i*math.pi/48)) for i in range(49)]
    a.extrude("Embossed crown face",crown,.7,brass,y=front+.6,bevel=.17)
    for sx in (-1,1):
        boss=a.cylinder("Crown inspection cap",1.8,.45,(sx*w*.26,front-.1,lintel+3),trim,segments=40,bevel=.14)
        boss.rotation_euler.x=math.pi/2
        a.ring("Cap seam",1.38,.09,(sx*w*.26,front-.4,lintel+3),iron,plane="XZ")
    a.block("Mouth lintel",(w*.82,2.2,2.5),(0,front-.4,lintel-1),trim,.35)
    inner=w*.34;exit_y=-d*outlet_reach;entry_y=back-2;entry_z=lintel-(1.4 if reinforced else 4)
    verts=[(-inner,exit_y,output),(inner,exit_y,output),(inner,entry_y,entry_z),(-inner,entry_y,entry_z)]
    chute=a.mesh("Sloped discharge chute",verts,[(0,1,2,3)],brass,bevel=.12)
    solid=chute.modifiers.new("Rolled chute plate thickness","SOLIDIFY");solid.thickness=.7
    for sx in (-1,1):
        x=sx*inner
        wall=a.mesh("Chute cheek guard",[(x,exit_y,output),(x,entry_y,entry_z),(x,entry_y,entry_z+3.3),(x,exit_y,output+2)],[(0,1,2,3)],trim,bevel=.1)
        mod=wall.modifiers.new("Guard plate thickness","SOLIDIFY");mod.thickness=.7
        a.tube("Rolled chute cheek",[(x,exit_y,output+2),(x,entry_y,entry_z+3.3)],.27,trim)
        a.beam("Chute support bracket",(sx*w*.37,front,output-12),(x,exit_y+2,output-.7),1.4,1.4,iron,.2)
    a.beam("Rounded output lip",(-inner,exit_y,output),(inner,exit_y,output),.55,.7,trim,.22)
    for z in (lintel-5,lintel-9):
        roller=a.cylinder("Feed roller",1.3,w*.68,(0,back-4,z),steel,segments=32,bevel=.2)
        roller.rotation_euler.y=math.pi/2
    for sx in (-1,1):
        for z in (output+3,lintel-2):
            boss=a.cylinder("Mouth corner boss",1.1,.6,(sx*w*.395,front-1.5,z),iron,segments=32)
            boss.rotation_euler.x=math.pi/2
            a.sphere("Boss central fastener",.37,(sx*w*.395,front-1.9,z),trim,scale=(1,.5,1),subdiv=2)
    # All three wheels use module .5 and sit on the same shaft plane.
    pitch=6;z0=output-1;x0=w*.49
    angle=math.atan2(math.sqrt(100-1.4**2),1.4)
    phase2=(angle+math.pi)-math.pi/16+angle*24/16
    phase3=1.5*math.pi-math.pi/12+(math.pi/2-phase2)*16/12
    for i,(x,z,r,t,phase) in enumerate(((x0,z0,pitch,24,0),
                  (x0+1.4,z0+math.sqrt(10**2-1.4**2),4,16,phase2),
                  (x0+1.4,z0+math.sqrt(10**2-1.4**2)+7,3,12,phase3))):
        gear=clockwork_gear.build(name+f" drive wheel {i}",loc=(x,-d*.45,z),radius=r,teeth=t,
                                  thickness=1.35,phase=phase,metal_finish="brass" if i!=1 else "steel",wear=wear,seed=seed+i)
        a.add(gear)
        shaft=a.cylinder("Gear arbor",.55,d*.78,(x,-d*.03,z),steel,segments=20)
        shaft.rotation_euler.x=math.pi/2
        a.beam("Gear bearing bridge",(w*.46,back,z),(x,back,z),1.7,2,iron,.2)
    gauge=pipework.build(name+" pressure gauge",loc=(-w*.50,-d*.12,h*.74),kind="gauge",gauge_radius=3.5,wear=wear,seed=seed)
    a.add(gauge)
    pipe=pipework.build(name+" pressure feed",points=((-w*.5,0,8),(-w*.62,0,8),(-w*.62,0,h*.65),(-w*.5,0,h*.65)),radius=.75,wear=wear,seed=seed)
    a.add(pipe)
    valve=pipework.build(name+" pressure wheel",loc=(-w*.62,0,h*.47),kind="valve",radius=.85,wheel_radius=3,wear=wear,seed=seed)
    a.add(valve)
    if reinforced:
        for sx in (-1,1):
            x=sx*w*.395
            a.block("Bolted mouth jamb",(w*.105,2.1,lintel-output+2),
                    (x,front-1.7,(lintel+output)/2),brass,.22)
            a.beam("Rubbed jamb arris",(sx*w*.345,front-2.85,output),
                   (sx*w*.345,front-2.85,lintel),.22,.22,trim,.08)
            for j in range(5):
                z=output+(lintel-output)*j/4
                a.ring("Mouth bolt washer",.57,.095,(x,front-2.85,z),iron,plane="XZ",segments=24)
                bolt=a.cylinder("Mouth hex bolt",.37,.35,(x,front-3,z),trim,segments=6,bevel=.045)
                bolt.rotation_euler.x=math.pi/2
            for t in (.16,.45,.74):
                yy=exit_y+(entry_y-exit_y)*t
                zz=output+(entry_z-output)*t
                a.sphere("Chute guard flush rivet",.16,(sx*(inner+.38),yy,zz+1.2),iron,subdiv=2)
        for yy in (front+3,back-3):
            a.tube("Crown strengthening hoop",[(w*.436*math.cos(i*math.pi/64),yy,
                   lintel+(h-lintel+.35)*math.sin(i*math.pi/64)) for i in range(65)],.38,trim)
        for sx in (-1,1):
            x=sx*w*.28
            a.cylinder("Rear piston barrel",1.45,h*.24,(x,back-1,h*.94),brass,segments=32,bevel=.18)
            for z in (h*.82,h*1.04):
                pipework.flange(a,(x,back-1,z),(0,0,1),1.4,trim,iron)
            a.cylinder("Exposed piston rod",.64,h*.14,(x,back-1,h*1.10),steel,segments=24)
        a.beam("Piston crosshead",(-w*.34,back-1,h*1.16),(w*.34,back-1,h*1.16),2.1,2.8,brass,.25)
        for yy in (front+1,back-1):
            a.beam("Casting lower tie",(-w*.44,yy,8),(w*.44,yy,8),2,2.7,brass,.25)
    return a.root
