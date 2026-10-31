"""Render four independent B01 machines with exact, built-in pipe sockets.

Each device lives on the 1187x1326 source canvas. The JSON contract supplies
its inlet center, tangent, radius, depth and crop origin to this script, the
conduit renderer and Godot. No port is inferred from an illustration.

Usage: blender -b -t 2 --python generate_reactor_devices.py [-- --only smelting]
"""
from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


ROOT = Path(__file__).resolve().parent
BUILD = Path(os.environ.get("REACTOR_BUILD_DIR", "/tmp/reactor-r6-build"))
BUILD.mkdir(parents=True, exist_ok=True)
CONTRACT = json.loads((ROOT / "reactor_ports.json").read_text())
W, H = CONTRACT["source_size"]
SPECS = CONTRACT["devices"]


def material(name, color, metallic=0.0, roughness=.35, emission=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, alpha)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, alpha)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    if metallic > .3:
        noise = mat.node_tree.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 76.0
        noise.inputs["Detail"].default_value = 2.0
        bump = mat.node_tree.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = .11
        bump.inputs["Distance"].default_value = .08
        mat.node_tree.links.new(noise.outputs["Fac"],bump.inputs["Height"])
        mat.node_tree.links.new(bump.outputs["Normal"],bsdf.inputs["Normal"])
    return mat


def setup():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    mats = {
        "steel": material("titanium armor", (.30,.38,.42), .63,.27,.04),
        "dark": material("recessed gunmetal", (.065,.11,.15), .58,.34,.015),
        "black": material("glass interior", (.018,.039,.055), .16,.12,.015),
        "silver": material("brushed silver edges", (.63,.72,.75), .72,.19,.08),
        "brass": material("copper brass contacts", (.66,.31,.085), .72,.24,.10),
        "blue": material("shield blue glass", (.015,.14,.30), .18,.14,.24),
        "blue_lit": material("shield field filaments", (.025,.40,.85), .05,.2,1.3),
        "orange": material("furnace liner", (.42,.15,.035), .25,.3,.22),
        "orange_lit": material("molten charge", (1.0,.28,.025), .04,.22,1.0),
        "violet": material("crystal glass", (.22,.07,.36), .18,.14,.2),
        "violet_lit": material("crystal facet", (.48,.15,.76), .05,.17,.85),
    }
    world = bpy.context.scene.world
    world.color = (.11,.15,.22)
    for loc, energy, size in [((220,-110,470),52000,360),((950,-390,380),43000,320)]:
        ld = bpy.data.lights.new("bay softbox", "AREA")
        ld.energy, ld.shape, ld.size = energy, "DISK", size
        ob = bpy.data.objects.new("bay softbox", ld)
        bpy.context.collection.objects.link(ob)
        ob.location = loc
    camera_data = bpy.data.cameras.new("source orthographic")
    camera = bpy.data.objects.new("source orthographic", camera_data)
    bpy.context.collection.objects.link(camera)
    tilt = float(os.environ.get("REACTOR_CAMERA_TILT", "15"))
    yaw = float(os.environ.get("REACTOR_CAMERA_YAW", "-16"))
    camera.rotation_euler = (math.radians(tilt),math.radians(yaw),0)
    forward = camera.rotation_euler.to_matrix() @ Vector((0,0,-1))
    camera.location = Vector((W/2,-H/2,0))-forward*1000
    camera_data.type, camera_data.ortho_scale = "ORTHO", H
    camera_data.clip_end = 4000
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = False
    bpy.context.view_layer.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = W,H
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    return mats


def cube(name, x,y,w,h,d,z,mat, bevel=3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x,-y,z))
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = (w,h,d)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    if bevel:
        mod = ob.modifiers.new("machined chamfer", "BEVEL")
        mod.width, mod.segments = bevel, 3
        ob.modifiers.new("face normals", "WEIGHTED_NORMAL")
    return ob


def rod(name, a, b, radius, z, mat, vertices=20):
    start, end = Vector((a[0],-a[1],z)), Vector((b[0],-b[1],z))
    axis = end-start
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=axis.length, location=(start+end)/2)
    ob = bpy.context.object
    ob.name = name
    ob.rotation_euler = axis.to_track_quat("Z","Y").to_euler()
    ob.data.materials.append(mat)
    bevel = ob.modifiers.new("turned lip", "BEVEL")
    bevel.width, bevel.segments = min(radius*.18,3), 2
    ob.modifiers.new("face normals", "WEIGHTED_NORMAL")
    return ob


def disc(name,x,y,r,depth,z,mat,vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=(x,-y,z))
    ob=bpy.context.object
    ob.name=name
    ob.data.materials.append(mat)
    mod=ob.modifiers.new("circular chamfer","BEVEL")
    mod.width,mod.segments=min(depth*.35,3.0),2
    ob.modifiers.new("face normals","WEIGHTED_NORMAL")
    return ob


def ring(name,x,y,r,t,z,mat):
    bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=8,location=(x,-y,z),major_radius=r,minor_radius=t)
    ob=bpy.context.object
    ob.name=name
    ob.data.materials.append(mat)
    return ob


def jewel(name, x,y,rx,ry,z,mat):
    # A small faceted crystal, not a wave-shaped transparency overlay.
    verts=[(x,-y-ry,z),(x+rx,-y,z),(x,-y+ry,z),(x-rx,-y,z),
           (x,-y,z+rx*.75),(x,-y,z-rx*.3)]
    faces=[(0,1,4),(1,2,4),(2,3,4),(3,0,4),
           (1,0,5),(2,1,5),(3,2,5),(0,3,5)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.materials.append(mat)
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(ob)
    return ob


def socket(name,spec,m):
    p=Vector(spec["device_port"])
    axis=Vector(spec["axis_to_device"]).normalized()
    radius=spec["socket_radius"]
    # p is the visible meeting plane. Its front lip is on the same source
    # plane as the conduit front collar; the barrel continues into the body.
    reach = 98 if name == "crystal" else (62 if name == "shield" else 38)
    rod(name+" keyed inlet",p,p+axis*reach,radius,0,m["dark"])
    rod(name+" machined sleeve",p+axis*5,p+axis*(reach-10),radius+4,0,m["steel"])
    for t in range(23,reach-10,21):
        disc(name+" sleeve index",(p+axis*t).x,(p+axis*t).y,3.2,3,34,m["brass"],12)
    disc(name+" visible mouth",p.x,p.y,radius-7,5,spec["socket_depth"]-7,m["black"])
    ring(name+" inlet face",p.x,p.y,radius-3,4,spec["socket_depth"],m["silver"])
    for side in (-1,1):
        normal=Vector((-axis.y,axis.x))
        q=p+normal*side*(radius-3)
        disc(name+" keyed bolt",q.x,q.y,2.8,3,spec["socket_depth"]+4,m["brass"],12)


def foot(name,x,y,w,m):
    cube(name+" plinth",x,y,w,33,20,16,m["dark"],5)
    cube(name+" silver skirt",x,y-13,w-12,12,14,27,m["steel"],3)
    cube(name+" brass rail",x,y+15,w-24,3,4,30,m["brass"],1)
    for sx in (-1,1):
        cube(name+" anchor",x+sx*(w*.41),y-4,17,35,25,28,m["silver"],2)
    for i in range(11):
        bx=x-w*.42+i*w*.084
        cube(name+" vent",bx,y+8,7,6,3,36,m["black"],1)
        disc(name+" deck rivet",bx,y-14,1.6,2,38,m["brass"],10)


def corner_fasteners(name,x,y,w,h,z,m):
    for sx in (-1,1):
        for sy in (-1,1):
            disc(name+" panel bolt",x+sx*w*.43,y+sy*h*.41,3.1,3,z,m["brass"],12)
            disc(name+" bolt centre",x+sx*w*.43,y+sy*h*.41,1.1,1,z+3,m["dark"],10)


def tubing(name,points,r,z,m):
    for i in range(len(points)-1):
        rod(name+" segment",points[i],points[i+1],r,z,m)
    for p in points[1:-1]:
        disc(name+" elbow",p[0],p[1],r*1.15,r*.8,z,m,16)


def weapon(spec,m):
    foot("weapon",176,316,244,m)
    cube("turret yoke",218,253,122,86,53,35,m["steel"],12)
    disc("rotary breech",217,212,59,28,45,m["dark"])
    ring("breech brass lock",217,212,56,4,63,m["brass"])
    cube("upper armor",235,143,92,38,21,59,m["steel"],8)
    cube("turret inset armored panel",231,240,77,38,3,65,m["dark"],4)
    for ix in range(5):
        cube("turret heat vent",201+ix*15,240,6,27,4,70,m["silver"],2)
    for yy in (133,152):
        cube("upper armor etched rail",235,yy,69,2,2,73,m["brass"],1)
    corner_fasteners("upper armor",235,143,92,38,74,m)
    for offset in (-18,18):
        y=190+offset
        rod("twin gun barrel",(35,y-16),(215,y),13,59,m["dark"])
        rod("cooled rifled casing",(54,y-14),(203,y-1),8,67,m["steel"])
        rod("charge rail",(80,y-10),(182,y-1),3,76,m["brass"])
        ring("muzzle crown",48,y-14,16,3,75,m["silver"])
        disc("muzzle bore",48,y-14,9,3,78,m["black"])
        ring("muzzle firing coil",48,y-14,9,1.9,91,m["orange_lit"])
        rod("dual charger",(64,y-13),(118,y-8),2.8,84,m["orange_lit"],10)
        for bx in (77,110,145,178):
            ring("barrel cooling collar",bx,y-12,14,2,77,m["silver"])
            disc("barrel fastener",bx,y-12,2,2,81,m["brass"],10)
        for bx in (65,98,131,164):
            cube("barrel side vent",bx,y+5,11,3,3,83,m["black"],1)
    cube("rear power junction",285,207,58,58,38,52,m["dark"],7)
    corner_fasteners("rear power junction",285,207,58,58,75,m)
    tubing("side supply",[(160,279),(165,253),(202,239),(234,232)],4,65,m["brass"])
    for i in range(7):
        cube("breech radial vent",195+i*7,207,2.5,20,3,72,m["silver"],1)
    socket("weapon",spec,m)


def defence(spec,m):
    foot("shield",1030,288,224,m)
    cube("field drive",974,197,92,112,50,29,m["steel"],11)
    corner_fasteners("field drive",974,197,92,112,61,m)
    rod("field transmission",(969,196),(1030,172),35,18,m["dark"])
    disc("field emitter barrel",1050,172,75,18,43,m["dark"])
    disc("glass force face",1050,172,70,3,58,m["blue"])
    disc("shield emitter inner hub",1050,172,20,5,65,m["dark"],24)
    ring("hub contact",1050,172,18,2.5,69,m["brass"])
    ring("inner field rim",1050,172,66,6,68,m["silver"])
    ring("outer brass retaining ring",1050,172,78,3,61,m["brass"])
    ring("inner glass boundary",1050,172,43,1.8,69,m["blue_lit"])
    for radius in (24,47):
        for i in range(8):
            a=i*math.tau/8+radius*.01
            x0=1050+radius*math.cos(a);y0=172+radius*math.sin(a)
            x1=1050+(radius+13)*math.cos(a+.06);y1=172+(radius+13)*math.sin(a+.06)
            rod("field lattice conductor",(x0,y0),(x1,y1),1.4,71,m["blue_lit"],8)
    for i in range(12):
        a=i*math.tau/12
        x=1050+80*math.cos(a);y=172+80*math.sin(a)
        disc("shield radial fastener",x,y,3.4,4,66,m["silver"],12)
    for y in (155,177,199,221):
        cube("field-drive cooling line",962,y,58,4,4,63,m["dark"],1)
        cube("field-drive copper trace",962,y+3,42,2,2,67,m["brass"],1)
    tubing("drive coolant",[(945,143),(956,111),(985,101),(1007,116)],4,45,m["brass"])
    socket("shield",spec,m)


def smelting(spec,m):
    foot("furnace",201,633,280,m)
    cube("heat jacket",177,517,182,176,48,32,m["steel"],15)
    disc("domed refractory crown",177,431,77,17,37,m["dark"])
    ring("furnace crown retainer",177,431,74,4,47,m["silver"])
    for i in range(10):
        a=i*math.tau/10
        disc("crown stud",177+73*math.cos(a),431+73*math.sin(a),2.5,3,51,m["brass"],10)
    cube("refractory inner slab",177,529,112,106,11,62,m["dark"],8)
    for x in (112,242):
        cube("furnace jacket service panel",x,531,25,84,5,62,m["dark"],4)
        for y in (508,525,542,559):
            cube("furnace jacket louver",x,y,16,4,4,67,m["silver"],1)
    cube("molten aperture",179,532,84,76,5,71,m["black"],6)
    cube("firebrick throat",179,536,56,57,6,78,m["orange"],5)
    cube("tap-hole",179,541,33,31,4,84,m["orange_lit"],6)
    for y in (510,523,547,560):
        cube("refractory courses",179,y,76,2,2,83,m["brass"],1)
    corner_fasteners("heat jacket",177,517,182,176,64,m)
    cube("throat crown",179,493,104,10,10,83,m["silver"],3)
    cube("throat sill",179,572,104,9,9,83,m["brass"],3)
    rod("exhaust riser",(104,487),(104,412),16,36,m["dark"])
    rod("exhaust ferrule",(104,419),(104,405),19,39,m["silver"])
    rod("molten delivery",(196,569),(282,617),13,39,m["dark"])
    rod("molten slot",(196,569),(282,617),6,49,m["orange"])
    tubing("left cooling coil",[(88,534),(74,534),(70,581),(82,603)],5,44,m["brass"])
    tubing("right pressure return",[(254,463),(284,466),(299,488),(298,520)],5,45,m["dark"])
    for x in (106,145,217,251):
        cube("furnace cooling rib",x,465,7,107,17,62,m["silver"],2)
    for i in range(9):
        cube("side louver",95+i*18,598,10,3,4,68,m["silver"],1)
    socket("furnace",spec,m)


def condensation(spec,m):
    foot("crystal",1003,626,242,m)
    cube("growth vessel back",1020,518,152,188,44,20,m["dark"],14)
    cube("growth chamber glass",1020,517,118,170,5,53,m["black"],10)
    for y in (452,480,555,580):
        cube("vessel retaining glass seam",1020,y,101,2,2,62,m["violet"],1)
    corner_fasteners("growth vessel back",1020,518,152,188,53,m)
    for x in (957,1083):
        cube("chamber silver column",x,516,10,185,18,65,m["silver"],4)
        for y in (461,497,534,570):
            cube("column machined collar",x,y,14,5,5,72,m["brass"],2)
    for y in (429,605):
        cube("vessel retention band",1020,y,149,13,18,67,m["steel"],4)
        cube("band brass trace",1020,y+5,119,2,3,78,m["brass"],1)
    for i,(x,y,rx,ry) in enumerate(((987,564,19,52),(1020,535,25,76),(1050,565,17,52),
                                     (969,585,11,30),(1080,588,13,29))):
        jewel("growth crystal %d"%i,x,y,rx,ry,70,m["violet"] if i%2 else m["violet_lit"])
    cube("vessel crown",1020,414,118,27,25,55,m["steel"],7)
    corner_fasteners("vessel crown",1020,414,118,27,72,m)
    tubing("crystal coolant",[(1101,454),(1119,467),(1119,565),(1096,583)],4,55,m["brass"])
    for x in (981,1001,1021,1041,1061):
        disc("growth seed socket",x,601,4,3,81,m["violet_lit"],12)
        rod("growth guide needle",(x,596),(x,570),1.5,78,m["silver"],8)
    socket("crystal",spec,m)


BUILDERS = {"weapons":weapon,"defence":defence,"smelting":smelting,"condensation":condensation}


def run():
    only = None
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only")+1]
        assert only in BUILDERS
    for name in ([only] if only else BUILDERS):
        mats=setup()
        spec=SPECS[name]
        p=Vector(spec["device_port"])
        prev=Vector(spec["controls"][-1])
        assert (p-prev).normalized().dot(Vector(spec["axis_to_device"]).normalized()) > .998
        BUILDERS[name](spec,mats)
        p2 = world_to_camera_view(bpy.context.scene,bpy.context.scene.camera,Vector((p.x,-p.y,spec["socket_depth"])))
        print("PORT_PROJECTION",name,tuple(round(v,4) for v in p2))
        (BUILD / ("r6-"+name+"-projection.json")).write_text(json.dumps({
            "port_screen": [p2.x*W,(1-p2.y)*H],
            "contract_port": spec["device_port"],
        },indent=2))
        work_mats={mats["blue_lit"],mats["orange_lit"],mats["violet_lit"]}
        original_slots={ob:[slot.material for slot in ob.material_slots]
                        for ob in bpy.context.scene.objects if ob.type == "MESH"}
        work_objects={ob for ob,slots in original_slots.items() if any(mat in work_mats for mat in slots)}
        for ob,slots in original_slots.items():
            for i,mat in enumerate(slots):
                if mat == mats["blue_lit"]: ob.material_slots[i].material=mats["blue"]
                if mat == mats["orange_lit"]: ob.material_slots[i].material=mats["orange"]
                if mat == mats["violet_lit"]: ob.material_slots[i].material=mats["violet"]
        bpy.context.scene.render.filepath=str(BUILD / ("r6-"+name+"-full.png"))
        bpy.ops.render.render(write_still=True)
        for ob,slots in original_slots.items():
            ob.hide_render=ob not in work_objects
            for i,mat in enumerate(slots): ob.material_slots[i].material=mat
        bpy.context.scene.render.filepath=str(BUILD / ("r6-"+name+"-work-full.png"))
        bpy.ops.render.render(write_still=True)
        print("RENDERED",name,"port",spec["device_port"],"axis",spec["axis_to_device"],"rect",spec["rect"])


run()
