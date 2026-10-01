"""Original abstract neon tubing: ringed planet, chevrons, orbital rings or light bars."""
import bpy
import math
import env_common as E
from . import geometry as G, materials as M


def build(name="Neon sign", loc=(0, 0, 0), rot_z=0, width=90, height=100, design="planet",
          color=(1, 0.012, 0.3), strength=6, wear=0.3, seed=1, backing=True) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    metal = M.polished_metal(f"{name} mounts", (0.065, 0.073, 0.09), wear, seed, roughness=0.3)
    tube = E.emissive(f"{name} neon", color, strength)
    if backing: a.block("Sign backing", (width * 1.08, 4, height * 1.05), (0, 3, height / 2), metal, 1.5)
    def line(label, pts, radius=0.65): return a.tube(label, pts, radius, tube, resolution=2)
    if design == "planet":
        r = min(width * 0.33, height * 0.43)
        center = height * 0.5
        line("Planet limb", [(r * math.cos(t), -1, center + r * math.sin(t)) for t in [i * math.tau / 96 for i in range(97)]])
        for j in range(-3, 4):
            z = r * j / 4
            reach = math.sqrt(r * r - z * z)
            line("Planet latitude", [(-reach, -1, center + z), (reach, -1, center + z)], 0.4)
        tilt = 0.35
        pts = []
        for i in range(129):
            t = math.tau * i / 128
            x, z = r * 1.48 * math.cos(t), r * 0.36 * math.sin(t)
            pts.append((x * math.cos(tilt) - z * math.sin(tilt), -3, center + x * math.sin(tilt) + z * math.cos(tilt)))
        line("Orbital ring", pts, 0.95)
    elif design == "chevrons":
        for i in range(3):
            z = height * (0.24 + i * 0.26)
            line("Abstract chevron", [(-width * 0.35, -1, z + height * 0.09), (0, -1, z), (width * 0.35, -1, z + height * 0.09)], 0.8)
    elif design == "rings":
        for i in range(3):
            a.ring("Neon orbit", width * 0.32, 0.7, (0, -1, height * (0.2 + i * 0.3)), tube, plane="XZ", ellipse=0.55, segments=48)
    else:
        for i in range(5):
            z = height * (0.12 + i * 0.19)
            line("Stacked neon bars", [(-width * 0.36, -1, z), (width * 0.36, -1, z)], 0.75)
    mounts = [(x, z) for x in (-width * 0.43, width * 0.43) for z in (height * 0.1, height * 0.9)]
    if design == "planet" and not backing:
        mounts = [(-r, center), (r, center), (0, center - r), (0, center + r)]
    for x, z in mounts:
        ob = a.cylinder("Ceramic standoff", 1.1, 3, (x, 0.5, z), metal)
        ob.rotation_euler.x = math.pi / 2
    return a.root
