"""Clear diner glazing with separate sparse refracting beads, runoff and a low condensation edge."""
import bpy
import math
import random
import env_common as E
from . import geometry as G, materials as M


def build(name="Rain window", loc=(0, 0, 0), rot_z=0, width=330, height=210, panes=4,
          density=0.009, drop_radius=0.16, wear=0.3, seed=1) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    chrome = M.polished_metal(f"{name} chrome", wear=wear, seed=seed)
    black = E.simple(f"{name} black frames", (0.008, 0.011, 0.014), 0.25, metal=1)
    glass = M.rain_pane(f"{name} clear pane")
    for i in range(panes):
        x = -width / 2 + (i + 0.5) * width / panes
        ob = a.block("Clear undistorted glazing", (width / panes - 3.5, 0.3, height - 4), (x, 0, height / 2), glass, 0.06)
        ob.visible_shadow = False
    for i in range(panes + 1):
        x = -width / 2 + i * width / panes
        a.block("Black window mullion", (3.4, 5, height + 5), (x, 0, height / 2), black, 0.45)
        a.block("Mullion chrome bead", (0.7, 0.8, height + 4), (x - 0.6, -2.6, height / 2), chrome, 0.25)
    for z in (0, height):
        a.block("Chrome window rail", (width + 6, 6, 4.5), (0, 0, z), chrome, 0.6)
        a.block("Rubber gasket", (width, 0.8, 1), (0, -2.5, z + (2.8 if z == 0 else -2.8)), black, 0.18)
    rng = random.Random(seed)
    water = M.clear_glass(f"{name} individual droplets", 0.045, 1.333)
    count = int(width * height * density)
    for i in range(count):
        x, z = rng.uniform(-width / 2 + 3, width / 2 - 3), rng.uniform(4, height - 3)
        if abs((x + width / 2) % (width / panes) - width / panes / 2) > width / panes / 2 - 3: continue
        r = drop_radius * rng.uniform(0.4, 1.5)
        ob = a.sphere("Rain bead", r, (x, 0.22, z), water, scale=(1, 0.38, rng.uniform(1, 1.8)), subdiv=2)
        ob.visible_shadow = False
    for i in range(max(4, count // 30)):
        x, z = rng.uniform(-width / 2 + 5, width / 2 - 5), rng.uniform(15, height - 8)
        length = rng.uniform(3, 11)
        pts = [(x + math.sin(t * 4 + i) * 0.1, 0.20, z - length * t) for t in [j / 12 for j in range(13)]]
        ob = a.tube("Running rain trail", pts, drop_radius * rng.uniform(0.18, 0.4), water, resolution=1)
        ob.visible_shadow = False
    return a.root
