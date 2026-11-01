"""Render four independent pipe shells from the shared device-port contract.

Run with Blender, then assemble_reactor_pipes.py to crop the contract rectangles.
"""
from __future__ import annotations

import math
import json
import os
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
CONTRACT = json.loads((ROOT / "reactor_ports.json").read_text())
W, H = CONTRACT["source_size"]
BUILD = Path(os.environ.get("REACTOR_BUILD_DIR", "/tmp/reactor-r6-build"))
BUILD.mkdir(parents=True, exist_ok=True)
# The first endpoint is the core outlet; the last is the module inlet.
# Device and conduit renders consume one source-space contract.
PORTS = CONTRACT["devices"]
PATHS = {name: tuple([tuple(spec["core_port"])] + [tuple(p) for p in spec["controls"]] + [tuple(spec["device_port"])])
         for name, spec in PORTS.items()}
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
    spec=PORTS[name]
    start=Vector(spec["device_port"])
    direction=Vector(spec["axis_to_device"]).normalized()
    depth=spec["insert_depth"]
    # A straight, full section continues past the shared meeting plane into
    # the device's hollow sleeve. The original Bezier still ends exactly at it.
    inserted=tuple(tuple(start+direction*depth*f) for f in (0.0,1/3,2/3,1.0))
    tube(name+"_insert_jacket",inserted,20,0,MATS["metal"],steps=24)
    surface_strip(name+"_insert_glass",inserted,13,21.5,MATS["glass"],steps=30)
    # The short section visible in front of the sleeve mouth is rendered as
    # the same three-dimensional conduit, then composited above the device.
    # Beyond the mouth, the long inserted section is occluded by the barrel.
    tip=tuple(tuple(start+direction*(30*f-18)) for f in (0.0,1/3,2/3,1.0))
    tube(name+"_insertfront_jacket",tip,20,0,MATS["metal"],steps=16)
    surface_strip(name+"_insertfront_glass",tip,13,21.5,MATS["glass"],steps=20)
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




def setup():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    MATS.update({
        "metal": material("gunmetal jacket", METAL, 0.82, 0.27),
        "ridge": material("steel rim", RIDGE, 0.78, 0.2),
        "gold": material("brass collar edge", GOLD, 0.85, 0.25),
        "glass": material("deep glass lumen", GLASS, 0.18, 0.1, 0.13),
    })
    bpy.context.scene.world.color = (0.20,0.25,0.34)
    for loc, power, size in (((320,-150,500),80000,500),((960,-320,450),60000,450)):
        light_data = bpy.data.lights.new("bay softbox", "AREA")
        light_data.energy,light_data.shape,light_data.size = power,"DISK",size
        light = bpy.data.objects.new("bay softbox",light_data)
        bpy.context.collection.objects.link(light)
        light.location=loc
    camera_data=bpy.data.cameras.new("source orthographic")
    camera=bpy.data.objects.new("source orthographic",camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location=(W/2,-H/2,1000)
    camera_data.type,camera_data.ortho_scale="ORTHO",H
    bpy.context.scene.camera=camera
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.samples=16
    scene.cycles.use_denoising=False
    bpy.context.view_layer.cycles.use_denoising=False
    scene.render.resolution_x,scene.render.resolution_y=W,H
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.view_settings.view_transform="Standard"


setup()
for pipe_id, anchors in PATHS.items():
    generated=set(bpy.data.objects)
    build_pipe(pipe_id,anchors)
    parts=set(bpy.data.objects)-generated
    tips={ob for ob in parts if "_insertfront_" in ob.name}
    fronts={ob for ob in parts if "_collar" in ob.name or "_lip" in ob.name}
    for layer,shown in (("shell",parts-fronts-tips),("front",fronts),("insert",tips)):
        for ob in parts: ob.hide_render=ob not in shown
        bpy.context.scene.render.filepath=str(BUILD/("modular-pipe-"+pipe_id+"-"+layer+"-full.png"))
        bpy.ops.render.render(write_still=True)
    for ob in parts: bpy.data.objects.remove(ob,do_unlink=True)
