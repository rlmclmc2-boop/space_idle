"""Apply the compact ceramic/navy/cyan orbital art pass to editable sources.

Run once on the pre-pass sources; export_models.py exports subsequent edits.
Coordinates below use Godot axes. Facility/Motion transforms remain untouched.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
PALETTE = ["e6f1ef", "203b55", "f4bb58", "226b93", "45eadb", "fff8df"]


def linear(v):
    return v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4


def block(name, position, size, material, parent):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(position[0], -position[2], position[1]))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    bevel = obj.modifiers.new("Soft ceramic corners", "BEVEL")
    bevel.width = min(.04, min(size) * .18)
    bevel.segments = 1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world
    obj.select_set(False)
    return obj


for kind in ["auto_explore", "refinery", "equipment", "shipyard"]:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / (kind + ".blend")))
    root = bpy.data.objects["Facility"]
    motion = bpy.data.objects["Motion"]
    materials = [bpy.data.materials.get(name) or bpy.data.materials.new(name) for name in [
        "01 Ceramic titanium", "02 Structural graphite", "03 Copper thermal hardware",
        "04 Photovoltaic glass", "05 Cyan navigation glass", "06 Service markings"]]
    for index, material in enumerate(materials):
        material.use_nodes = True
        rgb = tuple(linear(int(PALETTE[index][i:i+2], 16) / 255) for i in (0, 2, 4))
        material.diffuse_color = (*rgb, 1)
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Metallic"].default_value = .12 if index != 3 else .25
        bsdf.inputs["Roughness"].default_value = .42
        if index == 4:
            bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
            bsdf.inputs["Emission Strength"].default_value = .55
    ceramic, navy, amber, blue, cyan, white = materials
    if kind == "auto_explore":
        for i in range(8):
            a = i * math.tau / 8
            obj = block("Habitat luminous belt", (math.cos(a)*1.8, .32, math.sin(a)*1.8),
                        (.42, .10, .12), cyan, motion)
            obj.rotation_euler.z = -a
        block("Navigation crown", (0, 1.25, 0), (.38, .15, .38), cyan, root)
    elif kind == "refinery":
        for side in [-1, 1]:
            for y in [-.65, .65]:
                for z in [-.65, .30]:
                    block("Tank amber identifier", (side*1.28, y+.48, z),
                          (.40, .06, .23), amber, root)
            block("Process conduit", (side*.40, .69, -.24), (.10, .08, 1.9), cyan, root)
        block("Process controller", (0, .80, .72), (.55, .26, .45), ceramic, root)
        block("Controller glass", (0, .95, .72), (.36, .055, .27), cyan, root)
    elif kind == "equipment":
        for side in [-1, 1]:
            block("Manipulator armor", (side*1.7, .86, 1.5), (.45, .18, .42), amber, motion)
            block("Assembly luminous guide", (side*.8, .42, 2.4), (.12, 1.2, .10), cyan, root)
            block("Factory shoulder", (side*1.35, .57, -.8), (.40, .08, .80), cyan, root)
        block("Assembly console", (0, .88, -.5), (.52, .11, .44), ceramic, root)
        block("Assembly console display", (0, .96, -.5), (.35, .045, .25), cyan, root)
    else:
        for side in [-1, 1]:
            for z in [-2.4, -1.2, 0, 1.2, 2.4]:
                block("Dock amber service marks", (side*1.75, -.43, z-.15),
                      (.46, .06, .10), amber, root)
            for z in [-2.0, 1.8]:
                block("Dock collar beacon", (side*1.4, 1.45, z), (.36, .20, .45), cyan, root)
        block("Moving cradle guide", (0, .1, 0), (.48, .08, 1.4), cyan, motion)
    # Join into the existing two meshes; active mesh keeps its transform and parent.
    for parent, name in [(root, "StaticHull"), (motion, "AnimatedHardware")]:
        target = bpy.data.objects[name]
        objects = [o for o in parent.children if o.type == "MESH"]
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = target
        bpy.ops.object.join()
        slots = list(target.data.materials)
        unique = list(dict.fromkeys(slots))
        indices = [unique.index(slots[p.material_index]) for p in target.data.polygons]
        target.data.materials.clear()
        for material in unique:
            target.data.materials.append(material)
        for face, index in zip(target.data.polygons, indices):
            face.material_index = index
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .50
    bpy.data.objects["Warm rim"].data.color = (.72, .90, 1)
    scene.render.film_transparent = True
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / (kind + ".blend")))
