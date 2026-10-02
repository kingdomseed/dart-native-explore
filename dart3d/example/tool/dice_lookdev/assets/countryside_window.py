"""Painted kitchen casement, gathered curtains, radiator and a deep northern field vista."""
import math
import random
import bpy
from mathutils import Vector
import env_common as E
from . import geometry as G, materials as M


def build(name="Countryside window",loc=(0,0,0),rot_z=0,width=122,height=134,
          tone=(.67,.63,.51),wear=.4,seed=1,view=True,curtains=True,radiator=True,
          machine_x=1150,machine_height=540,exterior_slope=.2,machine_width=1,barn_x=180,exterior_elevation=0,barn_scale=1,field_clearing=None) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z);rng=random.Random(seed);w,h=width,height
    paint=M.aged_plastic(name+" old ivory paint",tone,wear,seed)
    metal=M.polished_metal(name+" catches",(.4,.43,.43),wear,seed,.28)
    for x in (-w/2-4,w/2+4):
        a.block("Deep plastered reveal",(8,18,h+17),(x,6,h/2),paint,.65)
        a.block("Stepped window architrave",(4,4,h+23),(x,-5,h/2),paint,.6)
    for z in (-5,h+5):
        a.block("Window horizontal reveal",(w+16,18,8),(0,6,z),paint,.7)
        a.block("Architrave bead",(w+24,4,3),(0,-5,z),paint,.65)
    a.block("Projecting sill",(w+26,31,4),(0,-4,-11),paint,1.4)
    for x in (-w/2,w/2,0):a.block("Casement stile",(3.2,5,h),(x,0,h/2),paint,.5)
    for z in (0,h,h*.48):a.block("Glazing cross bar",(w,4,2.5),(0,0,z),paint,.4)
    pane=M.rain_pane(name+" clear old glass",.1)
    a.block("Thin clear window glazing",(w,.12,h),(0,1,h/2),pane,.02)
    for x in (-3,3):
        a.block("Casement catch",(1,1,5),(x,-3,h*.4),metal,.25)
        a.tube("Window handle",[(x,-3,h*.4),(x,-5,h*.4+1),(x,-5,h*.4+5)],.42,metal)
    if curtains:
        cloth=M.retro_flower(name+" cotton floral curtains",(.57,.54,.42),(.11,.18,.045),scale=.055,seed=seed)
        rod=M.oak(name+" curtain rod",(.18,.083,.024),.4,seed,axis="X")
        a.tube("Curtain pole",[(-w*.82,-9,h+19),(w*.82,-9,h+19)],1.1,rod)
        for side in (-1,1):
            verts=[];nx,ny=36,32
            for j in range(ny+1):
                v=j/ny
                for i in range(nx+1):
                    u=i/nx
                    x=side*(w*.52+(u-.28)*w*.30+3*math.sin(v*math.pi))
                    y=-9+2.0*math.cos(u*math.pi*10)*( .7+.3*v)
                    z=h+12-v*(h+30)+.8*math.cos(u*math.pi*10)*v
                    verts.append((x,y,z))
            faces=[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i) for j in range(ny) for i in range(nx)]
            ob=a.mesh("Gathered floral cotton curtain",verts,faces,cloth,smooth=True)
            mod=ob.modifiers.new("Cotton hem thickness","SOLIDIFY");mod.thickness=.07
            for i in range(10):
                x=side*(w*.52+(i/9-.28)*w*.3)
                a.ring("Curtain hanging ring",1.35,.16,(x,-9,h+17),metal,plane="YZ",segments=16)
                a.tube("Curtain header hook",[(x,-9,h+16),(x,-9,h+13),(x,-9+1.4*math.cos(i/9*math.pi*10),h+11.8)],.12,metal)
    if radiator:
        for i in range(16):
            x=-w*.42+i*w*.056
            a.tube("Radiator loop",[(x,-4,-57),(x,-6,-61),(x,-10,-61),(x,-12,-57),(x,-12,-24),(x,-10,-20),(x,-6,-20),(x,-4,-24),(x,-4,-57)],1.35,paint,resolution=3)
        for z in (-25,-57):a.tube("Radiator manifold",[(-w*.49,-7,z),(w*.49,-7,z)],1.8,paint)
        a.tube("Radiator valve pipe",[(w*.49,-7,-25),(w*.55,-7,-25),(w*.55,-7,-70)],.9,metal)
        a.cylinder("Radiator valve knob",2.3,3,(w*.55,-7,-20),paint,bevel=.4)
    if view:
        before=set(a.root.children)
        sky,k=E.material(name+" grey Scandinavian sky")
        vec=k.coords().outputs["Generated"]
        sep=k.node("ShaderNodeSeparateXYZ");k.link(vec,sep.inputs[0])
        clouds=k.noise(vec,7,5,.65,dist=.25).outputs["Fac"]
        col=k.ramp(sep.outputs["Z"],[(0,(.34,.41,.48)),(.5,(.22,.30,.40)),(1,(.085,.13,.21))])
        col=k.mix(.30,col,k.ramp(clouds,[(.25,(.12,.17,.23)),(.75,(.39,.46,.52))]))
        k.surface(k.emission(col,1.35))
        a.block("Clouded daylight sky",(6500,2,3000),(500,3900,600),sky,0)
        field,k=E.material(name+" winter stubble")
        vec=M.mapped(k,(.05,.003,.03),seed)
        n=k.noise(vec,1,4).outputs["Fac"]
        col=k.ramp(n,[(.22,(.15,.14,.095)),(.55,(.29,.29,.21)),(.8,(.39,.4,.32))])
        k.surface(k.bsdf(Base_Color=col,Roughness=.97,Emission_Color=col,Emission_Strength=.28,Normal=k.bump(n,.3,.3)))
        verts=[]
        for j in range(41):
            y=300+j*85
            t=max(0,min(1,(y-1700)/650))
            z=-150-300*t*t*(3-2*t)
            for i in range(25):verts.append((-1900+i*200,y,z))
        faces=[(j*25+i,j*25+i+1,(j+1)*25+i+1,(j+1)*25+i) for j in range(40) for i in range(24)]
        a.mesh("Northern field",verts,faces,field,smooth=True)
        # Each stand is a different distance and haze value, with individual branch tiers.
        for layer,(yy,tone_tree) in enumerate(((1600,(.18,.23,.25)),(1150,(.095,.15,.16)),(830,(.055,.10,.10)))):
            fir=E.simple(name+f" fir stand {layer}",tone_tree,.95,Emission_Color=(*tone_tree,1),Emission_Strength=.45)
            for i in range(100):
                x=-1100+i*30+rng.uniform(-13,13);th=rng.uniform(65,125)
                if field_clearing and field_clearing[0]*yy<x<field_clearing[1]*yy:continue
                a.cylinder("Distant spruce trunk",2.7,th,(x,yy,-150+th/2),fir,segments=5,bevel=0)
                for tier in range(6):
                    base=-150+th*(.07+tier*.135)
                    rr=th*(.19-tier*.026)
                    verts=[(x,yy,base+th*.31)]
                    for j in range(20):
                        t=j*math.tau/20+tier*.25
                        r=rr*rng.uniform(.8,1.2)*(1 if j%2 else .65)
                        verts.append((x+r*math.cos(t),yy+r*math.sin(t),base+rng.uniform(-1,1)*th*.025))
                    a.mesh("Irregular spruce boughs",verts,[(0,j+1,(j+1)%20+1) for j in range(20)],fir)
        before_barn=set(a.root.children)
        barn=E.simple(name+" red barn weatherboards",(.22,.058,.045),.85,Emission_Color=(.14,.055,.045,1),Emission_Strength=.35)
        roof=E.simple(name+" grey barn roof",(.22,.27,.29),.6)
        bx,by=barn_x,640
        a.block("Red field barn",(160,100,100),(bx,by,-100),barn,.8)
        a.extrude("Barn gable",[(bx-80,-50),(bx,3),(bx+80,-50)],100,barn,y=by,bevel=.3)
        for side in (-1,1):
            ob=a.block("Pitched tin roof",(98,113,2),(bx+side*41,by,-23),roof,.4);ob.rotation_euler.y=side*.58
        a.block("Barn doorway",(30,1,62),(bx,by-50.6,-119),paint,.2)
        for i in range(22):a.tube("Barn vertical siding",[(bx-77+i*7.3,by-50.8,-148),(bx-77+i*7.3,by-50.8,-51)],.22,roof)
        if barn_scale!=1:
            barn_group=G.Asset(name+" distant barn",loc=((1-barn_scale)*bx,(1-barn_scale)*by,(1-barn_scale)*-150))
            a.add(barn_group.root)
            for ob in set(a.root.children)-before_barn-{barn_group.root}:barn_group.add(ob)
            barn_group.root.scale=(barn_scale,)*3
        steel=E.simple(name+" remote machine haze",(.16,.21,.25),.73,Emission_Color=(.15,.20,.24,1),Emission_Strength=.5)
        mx,my,mh=machine_x,2700,machine_height;ground=-450;top=ground+mh
        a.sphere("Remote machine carapace",63*machine_width,(mx,my,top),steel,scale=(1.45,1,.35),subdiv=2)
        a.cylinder("Machine upper turret",39*machine_width,15,(mx,my,top+18),steel,segments=12,bevel=2)
        for i in range(3):
            theta=i*math.tau/3+.3
            hip=Vector((mx+35*machine_width*math.cos(theta),my+35*machine_width*math.sin(theta),top-16))
            knee=Vector((mx+85*machine_width*math.cos(theta),my+85*machine_width*math.sin(theta),top-mh*.48))
            foot=Vector((mx+150*machine_width*math.cos(theta),my+150*machine_width*math.sin(theta),ground))
            a.beam("Tripod machine upper leg",hip,knee,12,15,steel,2)
            a.sphere("Tripod knee joint",12,knee,steel)
            a.beam("Tripod machine lower leg",knee,foot,9,11,steel,1.5)
            a.sphere("Broad machine foot",17,foot,steel,scale=(1.6,1,.35))
        a.sphere("Distant red warning light",3,(mx+20*machine_width,my-62*machine_width,top-2),E.emissive(name+" warning glow",(.8,.035,.015),2),subdiv=2)
        landscape=G.Asset(name+" descending field vista")
        a.add(landscape.root)
        for ob in set(a.root.children)-before-{landscape.root}:
            landscape.add(ob)
        landscape.root.location.z=exterior_elevation
        landscape.root.rotation_euler.x=-math.atan(exterior_slope)
    return a.root
