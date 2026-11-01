"""Render small transparent deep-space bodies for the approved orbit scene."""
from pathlib import Path
from math import exp
from random import Random

import bpy
from mathutils import Vector, noise


OUTPUT = Path(__file__).resolve().parents[2] / "assets/planets/backdrop"
OUTPUT.mkdir(parents=True, exist_ok=True)


def material(name, color):
    item = bpy.data.materials.new(name)
    item.diffuse_color = (*color, 1)
    item.use_nodes = True
    node = item.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, 1)
    node.inputs["Roughness"].default_value = .96
    return item


def scene_setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = False
    bpy.context.view_layer.cycles.use_denoising = False
    scene.render.film_transparent = True
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "AgX"
    scene.world = bpy.data.worlds.new("Deep-space ambient")
    scene.world.color = (.012, .018, .025)
    bpy.ops.object.camera_add(location=(0, -4.3, 2.0))
    camera = bpy.context.object
    direction = Vector((0, 0, 0)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.8
    scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(-3.5, -2.0, 4.5))
    bpy.context.object.data.energy = 450
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = 3.0
    bpy.ops.object.light_add(type="AREA", location=(2.0, 2.0, 1.5))
    bpy.context.object.data.energy = 65
    bpy.context.object.data.color = (.40, .67, 1.0)
    bpy.context.object.data.size = 4.0
    return scene


scene = scene_setup()
bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=24, radius=1.0)
moon = bpy.context.object
moon.name = "Small cratered moon"
moon_surface = material("Moon warm gray dust", (.38, .36, .35))
moon.data.materials.append(moon_surface)
nodes = moon_surface.node_tree.nodes
links = moon_surface.node_tree.links
grain = nodes.new("ShaderNodeTexNoise")
grain.inputs["Scale"].default_value = 10.0
grain.inputs["Detail"].default_value = 4.0
palette = nodes.new("ShaderNodeValToRGB")
palette.color_ramp.elements[0].position = .25
palette.color_ramp.elements[0].color = (.14, .16, .18, 1)
palette.color_ramp.elements[1].position = .77
palette.color_ramp.elements[1].color = (.50, .48, .45, 1)
links.new(grain.outputs["Fac"], palette.inputs["Fac"])
links.new(palette.outputs["Color"], nodes.get("Principled BSDF").inputs["Base Color"])
craters = [(Vector(v).normalized(), width, depth) for v, width, depth in [
    ((-.48, -.72, .39), .15, .09), ((.22, -.87, .42), .12, .065),
    ((-.10, -.79, -.60), .18, .055), ((.52, -.68, -.38), .11, .075),
]]
for vertex in moon.data.vertices:
    direction = vertex.co.normalized()
    roughness = noise.noise_vector(direction * 7.5).x * .018
    depression = sum(depth * exp(-((direction - center).length / width) ** 2)
                     for center, width, depth in craters)
    vertex.co = direction * (1.0 + roughness - depression)
for face in moon.data.polygons:
    face.use_smooth = True
scene.render.filepath = str(OUTPUT / "small_moon.png")
bpy.ops.render.render(write_still=True)

bpy.data.objects.remove(moon, do_unlink=True)
rng = Random(81)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0)
rock = bpy.context.object
rock.name = "Faceted nearby asteroid"
for vertex in rock.data.vertices:
    vertex.co *= rng.uniform(.76, 1.12)
rock.scale = (1.10, .82, .91)
for color in ((.23, .25, .28), (.34, .32, .32), (.42, .39, .36), (.16, .20, .24)):
    rock.data.materials.append(material("Asteroid facet", color))
for face in rock.data.polygons:
    face.material_index = rng.choices(range(4), weights=(4, 3, 2, 2))[0]
rock.rotation_euler = (.22, -.38, .14)
scene.render.filepath = str(OUTPUT / "faceted_asteroid.png")
bpy.ops.render.render(write_still=True)
