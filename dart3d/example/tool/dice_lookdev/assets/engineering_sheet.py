"""Curled engineering paper with gear elevations, section lines and dimension ticks; no text."""
import math
import bpy
import env_common as E
from . import geometry as G, materials as M
from .clockwork_gear import outline


def build(name="Workshop drawing",loc=(0,0,0),rot_z=0,width=28,depth=35,blueprint=False,
          curl=.7,pinned=False,wear=.5,seed=1,ink_width=.023) -> bpy.types.Object:
    a=G.Asset(name,loc,rot_z)
    paper=M.parchment(name+" paper",seed=seed) if not blueprint else M.parchment(name+" cyanotype",tone=(.018,.062,.095),seed=seed)
    ink=E.simple(name+" drafting ink",(.39,.66,.72) if blueprint else (.024,.033,.032),.8)
    metal=M.machined_metal(name+" drawing tacks","brass",wear,seed)
    def point(x,y,z=0):
        return (x,y,.05+curl*(abs(x)/(width/2))**12+.11*math.sin(y*.18)+z)
    nx,ny=32,40
    vertices=[point((i/nx-.5)*width,(j/ny-.5)*depth) for j in range(ny+1) for i in range(nx+1)]
    a.mesh("Curled drafting paper",vertices,[(j*(nx+1)+i,j*(nx+1)+i+1,(j+1)*(nx+1)+i+1,(j+1)*(nx+1)+i)
               for j in range(ny) for i in range(nx)],paper,smooth=True)
    def line(points,r=.023,closed=False):a.tube("Unlettered technical line",[point(x,y,.045) for x,y in points],r*ink_width/.023,ink,cyclic=closed,resolution=1)
    def circle(cx,cy,r):line([(cx+r*math.cos(i*math.tau/96),cy+r*math.sin(i*math.tau/96)) for i in range(96)],closed=True)
    for cx,cy,r,n in ((-width*.12,depth*.15,width*.22,28),(width*.21,depth*.23,width*.12,16),(-width*.16,-depth*.25,width*.12,18)):
        pts,_=outline(r,n)
        line([(cx+rr*math.cos(t),cy+rr*math.sin(t)) for rr,t in pts],closed=True)
        for rr in (r*.16,r*.4,r*.77):circle(cx,cy,rr)
        for i in range(6):
            t=i*math.tau/6
            line([(cx+r*.4*math.cos(t),cy+r*.4*math.sin(t)),(cx+r*.72*math.cos(t),cy+r*.72*math.sin(t))])
        line([(cx-r*1.25,cy),(cx+r*1.25,cy)],.012)
        line([(cx,cy-r*1.25),(cx,cy+r*1.25)],.012)
    x0,y0=width*.08,-depth*.12
    line([(x0,y0),(width*.37,y0),(width*.37,-depth*.34),(x0,-depth*.34)],closed=True)
    for i in range(7):line([(x0+i*width*.04,y0),(x0+i*width*.04,-depth*.34)],.012)
    for x in (-width*.43,width*.43):
        line([(x,-depth*.4),(x,depth*.41)],.014)
        for j in range(9):
            y=-depth*.36+j*depth*.09
            line([(x-.22,y-.3),(x+.22,y+.3)],.02)
    if pinned:
        for x in (-width*.44,width*.44):
            for y in (-depth*.44,depth*.44):a.sphere("Drawing pin",.22,point(x,y,.1),metal,scale=(1,1,.35),subdiv=2)
    return a.root
