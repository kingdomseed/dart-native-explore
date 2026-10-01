"""Entasis columns, carved capitals, dressed arches and turned balustrades."""
import math
import bpy
from . import geometry as G, materials as M


def column(a, x, y, height, radius, mat):
    r, h = radius, height
    a.block("Column plinth", (r*2.8,r*2.8,h*0.035), (x,y,h*0.0175), mat, 0.5)
    profile=[(r*1.24,h*.035),(r*1.28,h*.05),(r*1.16,h*.068),(r,h*.075),
             (r*1.08,h*.09),(r*1.08,h*.11),(r*.87,h*.12)]
    for i in range(25):
        t=i/24
        profile.append((r*(.87-.14*t+.06*math.sin(t*math.pi)),h*(.12+.73*t)))
    profile += [(r*.85,h*.86),(r*.86,h*.88),(r*.77,h*.89),(r*1.1,h*.93),
                (r*1.24,h*.955),(r*1.24,h*.98),(0,h*.98)]
    a.lathe("Moulded entasis column",profile,mat,(x,y,0),segments=64)
    for j in range(12):
        theta=math.tau*j/12
        pts=[]
        for i in range(13):
            t=i/12
            rr=r*(.80+.38*t+.13*math.sin(math.pi*t))
            pts.append((x+rr*math.cos(theta),y+rr*math.sin(theta),h*(.887+.064*t)))
        a.tube("Carved capital leaf rib",pts,r*.068,mat)
        tip=pts[-1]
        a.sphere("Capital leaf curl",r*.11,tip,mat,scale=(1,1,.7))
    a.block("Capital abacus",(r*2.7,r*2.7,h*.025),(x,y,h*.988),mat,.6)


def build(name="Marble loggia", loc=(0,0,0), rot_z=0, bays=3, span=110, height=125,
          radius=9, depth=22, balustrade_height=61, rail_offset=0, rail_base=0, tone=(.46,.43,.37), wear=.35, seed=3) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    mat=M.fine_marble(name+" statuary marble",tone,wear,seed)
    for i in range(bays+1):
        x=(i-bays/2)*span
        column(a,x,0,height,radius,mat)
        a.block("Balustrade pier",(radius*1.65,depth,balustrade_height),
                (x,rail_offset-3,rail_base+balustrade_height/2),mat,.5)
        a.lathe("Pier finial",[(0,0),(radius*.92,0),(radius*.92,1.5),(radius*.6,3),
                (radius*.45,4),(radius*.7,6),(radius*.68,8),(radius*.34,10),(0,12)],
                mat,(x,rail_offset-3,rail_base+balustrade_height),segments=32)
    arch_r=span/2
    for bay in range(bays):
        cx=(bay-(bays-1)/2)*span
        for j in range(25):
            G.arch_block(a,"Arch voussoir",arch_r-radius*.5,arch_r+radius*.9,
                         math.pi*j/25+.002,math.pi*(j+1)/25-.002,depth,(cx,0,height),mat,.2)
        for rr,thick,y in ((arch_r-radius*.5,.65,-depth/2-.3),(arch_r+radius*.5,.55,-depth/2-.5),
                            (arch_r+radius*.85,.8,-depth/2-.6)):
            a.tube("Moulded archivolt",[(cx+rr*math.cos(t*math.pi/96),y,height+rr*math.sin(t*math.pi/96))
                                        for t in range(97)],thick,mat)
        a.block("Balustrade bottom rail",(span-radius,depth*.67,5),(cx,rail_offset-3,rail_base+2.5),mat,.6)
        a.block("Balustrade handrail",(span-radius,depth*.8,5),(cx,rail_offset-3,rail_base+balustrade_height-2.5),mat,.8)
        count=max(3,int(span/15))
        for j in range(count):
            x=cx+(j-(count-1)/2)*(span-radius*2)/count
            h=balustrade_height-10
            profile=[(0,0),(3.7,0),(3.7,2),(2.8,3),(2.4,5),(2.2,h*.24),
                     (3.7,h*.42),(4,h*.51),(3.4,h*.61),(2,h*.74),(1.7,h*.85),
                     (2.8,h*.92),(3.3,h*.94),(3.3,h),(0,h)]
            a.lathe("Turned marble baluster",profile,mat,(x,rail_offset-3,rail_base+5),segments=24)
    return a.root
