"""Full-size smithing tools resting on a tabletop at their lowest contact point."""
import math
import bpy
from mathutils import Vector
from . import geometry as G, materials as M, tool_rack


def build(name="Resting smithing tool", loc=(0, 0, 0), rot_z=0, kind="tongs", length=45,
          wood_tone=(0.12, 0.06, 0.022), metal_finish="iron", wear=0.75, seed=7) -> bpy.types.Object:
    a = G.Asset(name, loc, rot_z)
    tool = G.Asset(f"{name} geometry")
    a.add(tool.root)
    iron = M.metal(f"{name} scale", metal_finish, wear, seed)
    steel = M.metal(f"{name} working edges", "steel", wear, seed)
    if kind == "tongs":
        tool_rack.tongs(tool, 0, 0, length, iron, steel)
    elif kind in {"cross_peen", "ball_peen"}:
        wood = M.oak(f"{name} handle", wood_tone, wear, seed, axis="Z")
        tool_rack.hammer(tool, 0, 0, length, wood, iron, steel, ball=kind == "ball_peen")
    else:
        raise ValueError(f"Unknown smithing tool: {kind}")
    tool.root.rotation_euler = (math.pi / 2, 0, math.pi / 2)
    tool.root.location.x = length / 2
    bpy.context.view_layer.update()
    low = min((ob.matrix_world @ Vector(p)).z for ob in tool.root.children_recursive
              if ob.type in {"MESH", "CURVE"} for p in ob.bound_box)
    tool.root.location.z += loc[2] - low
    return a.root
