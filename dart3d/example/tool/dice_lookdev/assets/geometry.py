"""Small mesh construction vocabulary shared by the room assets."""
import math
import random

import bmesh
import bpy
from mathutils import Vector

import env_common as E


class Asset:
    def __init__(self, name, loc=(0, 0, 0), rot_z=0):
        self.root = E.link(bpy.data.objects.new(name, None))
        self.root.location = loc
        self.root.rotation_euler.z = rot_z

    def add(self, ob):
        ob.parent = self.root
        return ob

    def block(self, name, size, loc, mat, bevel=0.2):
        return self.add(E.cube(name, size, loc, mat, bevel=bevel, segs=3))

    def hewn_block(self, name, size, loc, mat, bevel=0.7, wear=0.6, seed=0):
        from mathutils import noise
        rng = random.Random(seed)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1)
        bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=2, affect="EDGES")
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
        bm.normal_update()
        offset = Vector((seed * 0.13, seed * 0.31, seed * 0.17))
        for v in bm.verts:
            n = noise.noise_vector(v.co * 0.19 + offset)
            v.co += v.normal * (n.x * 3.0 * wear)
            v.co += n * (wear * 0.45)
        ob = self.add(E.mesh_object(name, bm, mat, smooth=True))
        ob.data.set_sharp_from_angle(angle=math.radians(42))
        ob.location = loc
        ob.rotation_euler = (rng.uniform(-0.008, 0.008) * wear,
                             rng.uniform(-0.028, 0.028) * wear,
                             rng.uniform(-0.009, 0.009) * wear)
        return ob

    def cylinder(self, name, radius, height, loc, mat, bevel=0.08, segments=32, r2=None):
        return self.add(E.cylinder(name, radius, height, loc, mat, segs=segments, r2=r2, bevel=bevel))

    def sphere(self, name, radius, loc, mat, scale=(1, 1, 1), subdiv=2):
        return self.add(E.sphere(name, radius, loc, mat, subdiv=subdiv, scale=scale))

    def mesh(self, name, verts, faces, mat, bevel=0, smooth=False):
        me = bpy.data.meshes.new(name)
        me.from_pydata(verts, [], faces)
        me.update()
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bm.to_mesh(me)
        bm.free()
        ob = self.add(E.link(bpy.data.objects.new(name, me)))
        me.materials.append(mat)
        for p in me.polygons:
            p.use_smooth = smooth
        if bevel:
            mod = ob.modifiers.new("Soft worked edges", "BEVEL")
            mod.width = bevel
            mod.segments = 3
            mod.harden_normals = True
            mod = ob.modifiers.new("Face normals", "WEIGHTED_NORMAL")
            mod.keep_sharp = True
        return ob

    def lathe(self, name, profile, mat, loc=(0, 0, 0), segments=48):
        verts = [(r * math.cos(j * math.tau / segments), r * math.sin(j * math.tau / segments), z)
                 for r, z in profile for j in range(segments)]
        faces = [(i * segments + j, i * segments + (j + 1) % segments,
                  (i + 1) * segments + (j + 1) % segments, (i + 1) * segments + j)
                 for i in range(len(profile) - 1) for j in range(segments)]
        ob = self.mesh(name, verts, faces, mat, smooth=True)
        ob.location = loc
        return ob

    def tube(self, name, points, radius, mat, cyclic=False, resolution=2):
        cu = bpy.data.curves.new(name, "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = radius
        cu.bevel_resolution = resolution
        cu.resolution_u = 12
        sp = cu.splines.new("POLY")
        sp.points.add(len(points) - 1)
        for p, xyz in zip(sp.points, points):
            p.co = (*xyz, 1)
        sp.use_cyclic_u = cyclic
        cu.use_fill_caps = True
        cu.materials.append(mat)
        return self.add(E.link(bpy.data.objects.new(name, cu)))

    def ring(self, name, radius, tube, loc, mat, plane="XY", ellipse=1, segments=48):
        pts = []
        for i in range(segments):
            a = math.tau * i / segments
            u, v = radius * math.cos(a), radius * ellipse * math.sin(a)
            xyz = (u, v, 0) if plane == "XY" else ((u, 0, v) if plane == "XZ" else (0, u, v))
            pts.append(tuple(x + y for x, y in zip(xyz, loc)))
        return self.tube(name, pts, tube, mat, cyclic=True)

    def beam(self, name, start, end, width, depth, mat, bevel=0.2):
        a, b = Vector(start), Vector(end)
        ob = self.block(name, (width, depth, (b - a).length), (a + b) / 2, mat, bevel)
        ob.rotation_mode = "QUATERNION"
        ob.rotation_quaternion = (b - a).to_track_quat("Z", "Y")
        return ob

    def extrude(self, name, outline, depth, mat, y=0, bevel=0.1):
        n = len(outline)
        verts = [(x, yy, z) for yy in (y - depth / 2, y + depth / 2) for x, z in outline]
        faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
        faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
        return self.mesh(name, verts, faces, mat, bevel=bevel)

    def light(self, name, loc, energy, color, size=3, target=None, kind="POINT"):
        ob = self.add(E.light(bpy.context.scene, kind, name, loc, energy, color=color, size=size, target=target))
        ob.visible_camera = False
        ob.visible_transmission = False
        if kind == "AREA":
            ob.visible_glossy = False
            ob.data.specular_factor = 0
        return ob


def arch_block(asset, name, inner, outer, a0, a1, depth, center, mat, bevel=0.4):
    cx, cy, cz = center
    outline = [(cx + r * math.cos(a), cz + r * math.sin(a))
               for r, angles in ((inner, (a0, a1)), (outer, (a1, a0))) for a in angles]
    return asset.extrude(name, outline, depth, mat, y=cy, bevel=bevel)


def chain(asset, name, start, length, mat, radius=1.5):
    count = max(1, int(length / (radius * 2.4)))
    for i in range(count):
        asset.ring(name, radius, radius * 0.23,
                   (start[0], start[1], start[2] - i * radius * 2.4), mat,
                   plane="XZ" if i % 2 == 0 else "YZ", ellipse=1.55, segments=16)
