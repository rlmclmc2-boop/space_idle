"""Render four independent reactor conduits from shared 3-D tube geometry.

Source coordinates are 1187x1326 pixels. The four paths differ only in their
socket/tangent contract; material, section, collar and UV placement are shared.
Run with Blender 4.3: blender -b -t 2 --python generate_modular_pipes.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parent
W, H = 1187, 1326
# The first endpoint is the core outlet; the last is the module inlet.
PATHS = {
    "weapons": ((448, 249), (408, 220), (370, 195), (318, 208)),
    "defence": ((741, 247), (789, 205), (848, 184), (916, 199)),
    "smelting": ((463, 450), (410, 479), (360, 533), (313, 517)),
    "condensation": ((729, 446), (776, 482), (819, 530), (889, 518)),
}
METAL = (0.21, 0.23, 0.26, 1)
RIDGE = (0.39, 0.40, 0.42, 1)
GOLD = (0.69, 0.41, 0.18, 1)
GLASS = (0.10, 0.22, 0.28, 1)


def material(name, color, metallic=0.0, roughness=0.38, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


MATS = {}


def point(path, t):
    p0, p1, p2, p3 = [Vector((x, -y)) for x, y in path]
    u = 1 - t
    return p0*u*u*u + p1*3*u*u*t + p2*3*u*t*t + p3*t*t*t


def tangent(path, t):
    p0, p1, p2, p3 = [Vector((x, -y)) for x, y in path]
    u = 1 - t
    return ((p1-p0)*3*u*u + (p2-p1)*6*u*t + (p3-p2)*3*t*t).normalized()


def tube(name, path, radius, zcenter, mat, start=0.0, end=1.0,
         sides=20, steps=72, theta0=0.0, theta1=2*math.pi):
    verts, faces = [], []
    for j in range(steps + 1):
        t = start + (end-start)*j/steps
        p, v = point(path, t), tangent(path, t)
        n = Vector((-v.y, v.x))
        for i in range(sides + 1):
            a = theta0 + (theta1-theta0)*i/sides
            q = p + n * (radius*math.cos(a))
            verts.append((q.x, q.y, zcenter + radius*math.sin(a)))
    stride = sides + 1
    for j in range(steps):
        for i in range(sides):
            k = j*stride+i
            faces.append((k,k+1,k+1+stride,k+stride))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    for poly in mesh.polygons: poly.use_smooth = True
    return ob


def surface_strip(name, path, half_width, z, mat, start=0.01, end=0.99, steps=90):
    verts, faces = [], []
    for j in range(steps + 1):
        t = start + (end-start)*j/steps
        p, v = point(path, t), tangent(path, t)
        n = Vector((-v.y, v.x))
        for side in (-1, 1):
            q = p + n * (half_width*side)
            verts.append((q.x, q.y, z))
    for j in range(steps):
        k = j*2
        faces.append((k,k+1,k+3,k+2))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    return ob


def build_pipe(name, path):
    # The section is a shadowed metal outer jacket with a separately visible
    # glass slot. The inset lumen and discrete energy packets are independent.
    tube(name+"_jacket", path, 20, 0, MATS["metal"])
    tube(name+"_ridge", path, 22, 0, MATS["ridge"], theta0=0.02, theta1=0.38)
    tube(name+"_ridge2", path, 22, 0, MATS["ridge"], theta0=math.pi-0.38, theta1=math.pi-0.02)
    surface_strip(name+"_glass", path, 13, 21.5, MATS["glass"])
    for t in (0.0, 0.14, 0.43, 0.72, 0.93, 0.985):
        shoulder = 0.030 if t in (0.0, 0.985) else 0.018
        s, e = max(0.0,t-shoulder), min(1.0,t+shoulder)
        tube(name+"_collar", path, 25, 0, MATS["metal"], s, e, steps=5)
        tube(name+"_lip", path, 26, 0, MATS["gold"], s, min(1.0,s+0.007), steps=2)
        tube(name+"_lip", path, 26, 0, MATS["gold"], max(0.0,e-0.007), e, steps=2)
        # A short raised window keeps the luminous lumen legible across each
        # physical clamp. It is still subordinate to the clamp's front lip.
        if t not in (0.0, 0.985):
            surface_strip(name+"_collar_glass", path, 9, 26.2, MATS["glass"], s+0.003, e-0.003, 5)
            p, tangent_2d = point(path, t), tangent(path, t)
            n = Vector((-tangent_2d.y, tangent_2d.x))
            for side in (-1, 1):
                q = p + n * (22.0 * side)
                bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8,
                                                    radius=2.5, location=(q.x, q.y, 28))
                bolt = bpy.context.object
                bolt.name = name+"_collar_bolt"
                bolt.data.materials.append(MATS["gold"])


def beveled_plate(name, cx, cy, width, height, depth, z, mat, bevel=2.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(cx,-cy,z))
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = (width,height,depth)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    modifier = ob.modifiers.new("machined chamfer", "BEVEL")
    modifier.width, modifier.segments = bevel, 3
    ob.modifiers.new("weighted face normals", "WEIGHTED_NORMAL")
    return ob


def clamp_half(name, start_x):
    # A guided mechanical jaw sits above, but apart from, the core glass.
    # The runtime translates the two jaws toward each other, then holds.
    center_x = start_x + (106 if name.endswith("right") else 82)
    beveled_plate(name+"_base", center_x,323,150,24,8,43,MATS["metal"],4)
    beveled_plate(name+"_rail", center_x,314,138,4,3,49,MATS["ridge"],1)
    beveled_plate(name+"_brass", center_x,333,142,3,3,49,MATS["gold"],1)
    for cx in (center_x-65,center_x-33,center_x,center_x+33,center_x+65):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=3.2, depth=2.5, location=(cx,-323,50))
        ob = bpy.context.object
        ob.name = name+"_bolt"
        ob.data.materials.append(MATS["ridge"])


def local_softbox(name, location, energy, size):
    light_data = bpy.data.lights.new(name, "AREA")
    light_data.energy, light_data.shape, light_data.size = energy, "DISK", size
    light = bpy.data.objects.new(name, light_data)
    bpy.context.collection.objects.link(light)
    light.location = location


def core_gimbal(phase):
    center = (595, -330, 63)
    local_softbox("gimbal angled key", (455,-240,230), 26000, 130)
    for radius, thickness, metal, pitch, roll, name in (
        (143, 6.0, MATS["gimbal"], 0.55+0.40*math.sin(phase), 0.24*math.cos(phase), "outer containment hoop"),
        (143, 2.2, MATS["gold"], 0.55+0.40*math.sin(phase), 0.24*math.cos(phase), "outer brass tracking lip"),
    ):
        bpy.ops.mesh.primitive_torus_add(major_segments=96, minor_segments=8,
                                        location=center, major_radius=radius, minor_radius=thickness)
        ob = bpy.context.object
        ob.name = name
        ob.data.materials.append(metal)
        ob.rotation_euler = (pitch, roll, phase*0.16)
        if name == "outer containment hoop":
            orientation = ob.rotation_euler.to_matrix()
            for plate_index in range(16):
                angle = 2*math.pi*plate_index/16
                local = Vector((radius*math.cos(angle), radius*math.sin(angle), 11.0))
                p = Vector(center) + orientation @ local
                bpy.ops.mesh.primitive_cube_add(size=1, location=p)
                plate = bpy.context.object
                plate.name = "machined containment shoe"
                plate.dimensions = (24, 11, 7)
                bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
                plate.rotation_euler = (orientation @ Matrix.Rotation(angle+math.pi/2, 3, 'Z')).to_euler()
                plate.data.materials.append(MATS["gold"] if plate_index % 4 == 0 else MATS["gimbal_plate"])
                bevel = plate.modifiers.new("chamfered shoe", "BEVEL")
                bevel.width, bevel.segments = 1.6, 2
                plate.modifiers.new("weighted shoe normals", "WEIGHTED_NORMAL")
            for bolt_index in range(12):
                angle = 2*math.pi*bolt_index/12
                local = Vector((radius*math.cos(angle), radius*math.sin(angle), 8.5))
                p = Vector(center) + orientation @ local
                bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8,
                                                    radius=3.5, location=p)
                bolt = bpy.context.object
                bolt.name = "containment hoop set bolt"
                bolt.data.materials.append(MATS["gold"] if bolt_index % 3 == 0 else MATS["ridge"])


def setup():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    MATS.update({
        "metal": material("gunmetal jacket", METAL, 0.82, 0.27),
        "ridge": material("steel rim", RIDGE, 0.78, 0.2),
        "gimbal": material("brushed machined containment hoop", (0.49,0.56,0.56,1), 0.64, 0.22, 0.03),
        "gimbal_plate": material("machined radial shoes", (0.43,0.49,0.49,1), 0.42, 0.23),
        "gold": material("brass collar edge", GOLD, 0.85, 0.25),
        "glass": material("deep glass lumen", GLASS, 0.18, 0.1, 0.13),
    })
    # Fine physical roughness on the independently rendered bearing keeps its
    # volume readable beside the detailed bay art.
    for mat_name, scale, strength in (("gimbal", 22.0, 0.12),):
        mat = MATS[mat_name]
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = scale
        noise.inputs["Detail"].default_value = 3.0
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = strength
        bump.inputs["Distance"].default_value = 0.17
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], nodes.get("Principled BSDF").inputs["Normal"])
    world = bpy.context.scene.world
    world.color = (0.20,0.25,0.34)
    for loc, power, size in (((320, -150, 500), 80000, 500), ((960, -320, 450), 60000, 450)):
        light_data = bpy.data.lights.new("bay softbox", "AREA")
        light_data.energy, light_data.shape, light_data.size = power, "DISK", size
        light = bpy.data.objects.new("bay softbox", light_data)
        bpy.context.collection.objects.link(light)
        light.location = loc
    camera_data = bpy.data.cameras.new("source orthographic")
    camera = bpy.data.objects.new("source orthographic", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (W/2, -H/2, 1000)
    camera.rotation_euler = (0, 0, 0)
    camera_data.type, camera_data.ortho_scale = "ORTHO", H
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = False
    bpy.context.view_layer.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = W, H
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"


setup()
only_core = "--only-core" in sys.argv
for pipe_id, anchors in ({} if only_core else PATHS).items():
    generated = set(bpy.data.objects)
    build_pipe(pipe_id, anchors)
    parts = set(bpy.data.objects)-generated
    # The lumen's arc-length mesh is rendered by Godot between these two
    # physical layers; collars always occlude its light at the correct depth.
    fronts = {ob for ob in parts if "_collar" in ob.name or "_lip" in ob.name}
    for layer, shown in (("shell", parts-fronts), ("front", fronts)):
        for ob in parts: ob.hide_render = ob not in shown
        bpy.context.scene.render.filepath = str(ROOT / ("modular-pipe-"+pipe_id+"-"+layer+".png"))
        bpy.ops.render.render(write_still=True)
    for ob in parts:
        bpy.data.objects.remove(ob, do_unlink=True)
for side, start_x in (() if only_core else (("left",395),("right",603))):
    generated = set(bpy.data.objects)
    clamp_half("core_clamp_"+side,start_x)
    bpy.context.scene.render.filepath = str(ROOT / ("modular-core-clamp-"+side+".png"))
    bpy.ops.render.render(write_still=True)
    for ob in set(bpy.data.objects)-generated:
        bpy.data.objects.remove(ob, do_unlink=True)
for frame in range(12):
    generated = set(bpy.data.objects)
    core_gimbal(2*math.pi*frame/12)
    bpy.context.scene.render.filepath = str(ROOT / ("modular-core-gimbal-%02d.png" % frame))
    bpy.ops.render.render(write_still=True)
    for ob in set(bpy.data.objects)-generated:
        bpy.data.objects.remove(ob, do_unlink=True)
