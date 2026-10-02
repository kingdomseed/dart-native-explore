"""Moulded terminal, bowed rectangular CRT and sculpted blank keyboard caps. Faces -Y."""
import math
import random
import bpy
import env_common as E
from . import geometry as G, materials as M


def rounded_rect(w,h,r,n=10):
    return [(cx+r*math.cos(a+i*math.pi/2/n),cz+r*math.sin(a+i*math.pi/2/n))
            for cx,cz,a in ((w/2-r,h/2-r,0),(-w/2+r,h/2-r,math.pi/2),
                            (-w/2+r,-h/2+r,math.pi),(w/2-r,-h/2+r,math.pi*1.5)) for i in range(n+1)]


def bezel(a,name,outer,inner,depth,y,z,mat):
    out=rounded_rect(*outer); ins=rounded_rect(*inner); n=len(out)
    verts=[(x,yy,zz+z) for yy,path in ((y-depth/2,out),(y-depth/2,ins),(y+depth/2,out),(y+depth/2,ins)) for x,zz in path]
    faces=[]
    for j in range(n):
        q=(j+1)%n
        faces += [(j,q,n+q,n+j),(j,2*n+j,2*n+q,q),(n+j,n+q,3*n+q,3*n+j),
                  (2*n+j,3*n+j,3*n+q,2*n+q)]
    return a.mesh(name,verts,faces,mat,bevel=.18,smooth=True)


def build(name="Green terminal",loc=(0,0,0),rot_z=0,width=36,height=34,depth=33,
          tone=(.52,.48,.36),wear=.45,seed=1,keyboard=True,energy=1100,optical_glass=False,phosphor_strength=.62,curvature=1) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z); rng=random.Random(seed)
    plastic=M.aged_plastic(name+" case",tone,wear,seed)
    dark=M.aged_plastic(name+" inset",(.028,.039,.022),wear,seed)
    w,h,d=width,height,depth
    a.block("Terminal pedestal",(w*.66,d*.60,3),(0,2,1.5),plastic,.9)
    cabinet=a.block("Deep ventilated cabinet",(w,d,h-5),(0,3,(h+5)/2),plastic,2.2)
    a.block("Cabinet parting seam",(w+.06,.17,h-7),(0,1.5,(h+5)/2),dark,.03)
    front=3-d/2-1
    bezel(a,"Moulded front frame",(w+1,h-4,2.2),(w*.81,h*.67,2.8),2,front,h*.57,plastic)
    bezel(a,"Recessed black reveal",(w*.825,h*.685,2.8),(w*.76,h*.62,3),.75,front+.6,h*.57,dark)
    if optical_glass:
        cutter=a.block("Hidden CRT cavity tool",(w*.84,8,h*.72),(0,front+1,h*.57),dark,1.8)
        cutter.hide_render=True;cutter.hide_set(True)
        mod=cabinet.modifiers.new("Recess behind curved CRT","BOOLEAN")
        mod.operation="DIFFERENCE";mod.object=cutter
    screen,k=E.material(name+" phosphor")
    uv=k.coords().outputs["UV"]; sp=k.node("ShaderNodeSeparateXYZ");k.link(uv,sp.inputs[0])
    scan=k.math("ADD",.83,k.math("MULTIPLY",k.math("SINE",k.math("MULTIPLY",sp.outputs["Y"],580)),.17))
    emission=k.math("MULTIPLY",scan,phosphor_strength)
    if optical_glass:
        dx=k.math("SUBTRACT",sp.outputs["X"],.5)
        dy=k.math("SUBTRACT",sp.outputs["Y"],.5)
        radius=k.math("ADD",k.math("MULTIPLY",dx,dx),k.math("MULTIPLY",dy,dy))
        falloff=k.ramp(radius,[(0,(1,1,1)),(.16,(.8,.8,.8)),(.35,(.17,.17,.17)),(.5,(.02,.02,.02))])
        emission=k.math("MULTIPLY",emission,falloff)
    k.surface(k.bsdf(Base_Color=(.008,.038,.011,1),Roughness=.16,Coat_Weight=.9,
                     Emission_Color=(.035,.65,.14,1),Emission_Strength=emission))
    outline=rounded_rect(w*.755,h*.615,3,16); n=len(outline)
    verts=[(0,front-.05,h*.57)]; uvs=[(.5,.5)]
    for ring in range(1,13):
        t=ring/12
        for x,z in outline:
            verts.append((x*t,front-.05+curvature*t*t,h*.57+z*t)); uvs.append((.5+x*t/(w*.76),.5+z*t/(h*.62)))
    faces=[(0,1+j,1+(j+1)%n) for j in range(n)]
    faces += [(1+(i-1)*n+j,1+(i-1)*n+(j+1)%n,1+i*n+(j+1)%n,1+i*n+j) for i in range(1,12) for j in range(n)]
    ob=a.mesh("Bowed rectangular CRT glass",verts,faces,screen,smooth=True)
    uv=ob.data.uv_layers.new()
    for loop in ob.data.loops: uv.data[loop.index].uv=uvs[loop.vertex_index]
    phosphor=E.emissive(name+" green marks",(.025,.8,.16),2.2)
    for row in range(8):
        z=h*.57+h*.22-row*h*.045
        for j in range(rng.randint(2,6)):
            x=-w*.30+j*w*.085
            a.block("Abstract phosphor dash",(rng.uniform(.5,1.8),.025,.12),(x,front-.10+((x/(w*.38))**2+( (z-h*.57)/(h*.31))**2)*.44*curvature,z),phosphor,.03)
    a.block("Cursor block",(.9,.03,.5),(-w*.28,front+.06,h*.33),phosphor,.04)
    for side in (-1,1):
        for i in range(13):
            a.block("Recessed cooling slot",(.05,d*.36,.27),(side*(w/2+.01),6,h*.40+i*.65),dark,.12)
    a.block("Power switch",(1.3,.45,.8),(w*.37,front-.7,5.1),dark,.12)
    a.sphere("Green power diode",.13,(w*.30,front-.83,5.1),phosphor,subdiv=2)
    if keyboard:
        ky=front-11
        a.block("Keyboard lower shell",(w+4,17,1.5),(0,ky,.85),plastic,.75)
        deck=a.block("Keyboard raised deck",(w+3,16,1.6),(0,ky,2),plastic,.6)
        deck.rotation_euler.x=.07
        a.block("Keyboard key well",(w+1,13,.4),(0,ky,2.85),dark,.5)
        cap=M.aged_plastic(name+" key caps",tuple(v*.75 for v in tone),wear,seed+7)
        for row in range(5):
            for col in range(14):
                if row==0 and 3<=col<=9: continue
                x=-w*.46+col*w*.071
                y=ky-5.15+row*2.45
                a.block("Sculpted blank keycap",(w*.065,2.12,.85),(x,y,3.35+row*.08),cap,.24)
        a.block("Concave space bar",(w*.47,2.15,.85),(-w*.065,ky-5.15,3.35),cap,.28)
        cord=M.vinyl(name+" coiled lead",(.025,.023,.019),wear,seed)
        a.tube("Keyboard cable",[(w*.48+i*.10,ky+8+math.sin(i*.9)*.6,1.3+math.cos(i*.9)*.6) for i in range(70)],.12,cord)
    light=a.light("Phosphor spill",(0,front-1,h*.56),energy,(.18,1,.32),w*.7,(0,front-35,0),"AREA")
    light.visible_glossy=True;light.data.specular_factor=1
    return a.root
