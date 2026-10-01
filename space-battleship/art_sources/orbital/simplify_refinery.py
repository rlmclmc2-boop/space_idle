"""Rebuild only the refinery as three readable masses at its orbital pixel size.

Run from the project directory with Blender --background --python this_file.
The existing Facility/Motion pivots and studio remain authoritative. No textures,
thin rods, solar grids or small service parts are added to the runtime model.
"""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parents[1] / "assets/planets/orbital/models"
bpy.ops.wm.open_mainfile(filepath=str(ROOT / "refinery.blend"))
root = bpy.data.objects["Facility"]
motion = bpy.data.objects["Motion"]
for obj in list(root.children_recursive):
    if obj.type == "MESH":
        bpy.data.objects.remove(obj, do_unlink=True)


def xyz(point):
    return Vector((point[0], -point[2], point[1]))


def material(name, hex_color):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    values = [int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4)]
    rgb = tuple(v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in values)
    mat.diffuse_color = (*rgb, 1)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = 0
    bsdf.inputs["Roughness"].default_value = .88
    bsdf.inputs["Specular IOR Level"].default_value = .08
    return mat


amber = material("Refinery amber storage", "fbc455")
cream = material("Refinery pale tank caps", "f5efd9")
navy = material("Refinery navy pump body", "264756")
cyan = material("Refinery broad pump indicator", "49cfb7")


def attach(obj, parent):
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world
    return obj


def block(name, position, dimensions, mat, parent, bevel=.16):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz(position))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (dimensions[0], dimensions[2], dimensions[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    mod = obj.modifiers.new("Broad rounded silhouette", "BEVEL")
    mod.width = bevel
    mod.segments = 1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    attach(obj, parent)
    obj.select_set(False)
    return obj


def tank(x):
    # One continuous chunky capsule; pale endcaps occupy broad areas, no seams.
    profile = [(-1.95, .22), (-1.72, .66), (-1.38, .90),
               (1.38, .90), (1.72, .66), (1.95, .22)]
    count = 12
    vertices = [xyz((x + radius * math.cos(a * math.tau / count),
                     radius * math.sin(a * math.tau / count), z))
                for z, radius in profile for a in range(count)]
    faces = []
    slots = []
    for ring in range(len(profile) - 1):
        for a in range(count):
            faces.append((ring*count+a, ring*count+(a+1)%count,
                          (ring+1)*count+(a+1)%count, (ring+1)*count+a))
            slots.append(0 if ring == 2 else 1)
    faces.extend([tuple(reversed(range(count))), tuple(range((len(profile)-1)*count, len(profile)*count))])
    slots.extend([1, 1])
    mesh = bpy.data.meshes.new("Twelve-sided storage capsule")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(amber)
    mesh.materials.append(cream)
    for face, slot in zip(mesh.polygons, slots):
        face.material_index = slot
    mesh.update()
    obj = bpy.data.objects.new("Oversized storage tank", mesh)
    bpy.context.collection.objects.link(obj)
    attach(obj, root)


tank(-1.55)
tank(1.55)
block("Single central pump body", (0, .25, 0), (1.65, 1.70, 3.30), navy, root)
# The moving lid remains on the original nonzero Motion pivot. Its broad face
# replaces the tiny rotor, using the same owner-driven rotation in Godot.
pivot = motion.matrix_world.translation
cap_position = (pivot.x, pivot.z, -pivot.y)
block("Large moving pump lid", cap_position, (1.55, .30, 1.55), cream, motion, .12)
block("One broad pump indicator", (cap_position[0], cap_position[1]+.17, cap_position[2]),
      (.90, .045, .70), cyan, motion, .015)

for parent, name in [(root, "StaticHull"), (motion, "AnimatedHardware")]:
    objects = [obj for obj in parent.children if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    original = list(obj.data.materials)
    unique = list(dict.fromkeys(original))
    indices = [unique.index(original[face.material_index]) for face in obj.data.polygons]
    obj.data.materials.clear()
    for mat in unique:
        obj.data.materials.append(mat)
    for face, slot in zip(obj.data.polygons, indices):
        face.material_index = slot

objects = [root, *root.children_recursive]
bpy.ops.object.select_all(action="DESELECT")
for obj in objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=str(OUT / "refinery.glb"), export_format="GLB",
                         use_selection=True, export_animations=False,
                         export_cameras=False, export_lights=False, export_yup=True)
meshes = [obj for obj in objects if obj.type == "MESH"]
stats = json.loads((OUT / "model-stats.json").read_text())
for row in stats:
    if row["kind"] == "refinery":
        row.update(triangles=sum(sum(len(face.vertices)-2 for face in obj.data.polygons) for obj in meshes),
                   mesh_objects=len(meshes), material_surfaces=sum(len(obj.data.materials) for obj in meshes))
(OUT / "model-stats.json").write_text(json.dumps(stats, indent=2))
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.film_transparent = True
scene.render.filepath = str(OUT / "refinery-icon.png")
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "refinery.blend"))
bpy.ops.render.render(write_still=True)
print("REFINERY SAMPLE", next(row for row in stats if row["kind"] == "refinery"))
