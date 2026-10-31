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


def projected_socket_axis(p, axis, z):
    """Invert the camera's planar projection so the inlet follows the pipe axis on screen."""
    scene=bpy.context.scene
    camera=scene.camera
    def screen(x,y):
        q=world_to_camera_view(scene,camera,Vector((x,-y,z)))
        return Vector((q.x*W,(1-q.y)*H))
    origin=screen(p.x,p.y)
    ex=screen(p.x+1,p.y)-origin
    ey=screen(p.x,p.y+1)-origin
    determinant=ex.x*ey.y-ex.y*ey.x
    assert abs(determinant)>.1
    result=Vector(((axis.x*ey.y-axis.y*ey.x)/determinant,
                   (ex.x*axis.y-ex.y*axis.x)/determinant)).normalized()
    assert (screen(p.x+result.x,p.y+result.y)-origin).normalized().dot(axis)>.99999
    return result


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
        "steel": material("titanium armor", (.22,.31,.36), .69,.22,.06),
        "dark": material("recessed gunmetal", (.065,.12,.16), .58,.32,.025),
        "black": material("glass interior", (.025,.055,.075), .12,.16,.025),
        "silver": material("brushed silver edges", (.62,.72,.73), .73,.17,.10),
        "brass": material("copper brass contacts", (.66,.34,.10), .75,.20,.12),
        "blue": material("shield blue glass", (.015,.14,.30), .18,.14,.24),
        "blue_lit": material("shield field filaments", (.025,.40,.85), .05,.2,1.3),
        "orange": material("furnace liner", (.42,.15,.035), .25,.3,.22),
        "orange_lit": material("molten charge", (1.0,.28,.025), .04,.22,1.0),
        "violet": material("crystal glass", (.22,.07,.36), .18,.14,.2),
        "violet_lit": material("crystal facet", (.34,.11,.57), .12,.19,.42),
        "violet_glint": material("crystal cleavage glint", (.43,.25,.65), .42,.13,.12),
        "worklamp": material("warm bay service emitter", (1.0,.66,.27), .05,.25,3.0),
        "ice": material("blue instrument emitter", (.16,.66,1.0), .05,.2,2.3),
    }
    world = bpy.context.scene.world
    world.use_nodes = True
    environment = world.node_tree.nodes.new("ShaderNodeTexEnvironment")
    environment.image = bpy.data.images.load(str(ROOT / "modular-bay-background.png"), check_existing=True)
    world.node_tree.links.new(environment.outputs["Color"],world.node_tree.nodes["Background"].inputs["Color"])
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = .68
    for loc, energy, size in [((220,-110,470),105000,360),((950,-390,380),95000,320),((600,200,330),51000,440)]:
        ld = bpy.data.lights.new("bay softbox", "AREA")
        ld.energy, ld.shape, ld.size = energy, "DISK", size
        ob = bpy.data.objects.new("bay softbox", ld)
        bpy.context.collection.objects.link(ob)
        ob.location = loc
    # Small practicals cut hard specular edges into each machine, like the
    # warm service lights in the host bay. They are absent from transparent pixels.
    for x,y in ((155,195),(1010,170),(150,510),(1000,520)):
        ld=bpy.data.lights.new("service strip highlight","AREA")
        ld.energy,ld.shape,ld.size=32000,"DISK",85
        ld.color=(1.0,.73,.43)
        ob=bpy.data.objects.new("service strip highlight",ld)
        bpy.context.collection.objects.link(ob)
        ob.location=(x,-y,165)
    camera_data = bpy.data.cameras.new("source orthographic")
    camera = bpy.data.objects.new("source orthographic", camera_data)
    bpy.context.collection.objects.link(camera)
    tilt = float(os.environ.get("REACTOR_CAMERA_TILT", "24"))
    yaw = float(os.environ.get("REACTOR_CAMERA_YAW", "-21"))
    camera.rotation_euler = (math.radians(tilt),math.radians(yaw),0)
    forward = camera.rotation_euler.to_matrix() @ Vector((0,0,-1))
    camera.location = Vector((W/2,-H/2,0))-forward*1000
    camera_data.type, camera_data.ortho_scale = "ORTHO", H
    camera_data.clip_end = 4000
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 20
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


def cast_plate(name,outline,z,depth,mat,bevel=3):
    count=len(outline)
    verts=[(x,-y,z+depth/2) for x,y in outline]
    verts += [(x,-y,z-depth/2) for x,y in outline]
    faces=[tuple(range(count)),tuple(range(2*count-1,count-1,-1))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.materials.append(mat)
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(ob)
    if bevel:
        mod=ob.modifiers.new("cast arris","BEVEL")
        mod.width,mod.segments=bevel,3
        ob.modifiers.new("weighted normals","WEIGHTED_NORMAL")
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


def tubular_sleeve(name, a, b, outer, inner, mat, vertices=32):
    start,end=Vector((a[0],-a[1],0)),Vector((b[0],-b[1],0))
    axis=(end-start).normalized()
    side=Vector((-axis.y,axis.x,0))
    up=Vector((0,0,1))
    verts=[]
    for origin,radius in ((start,outer),(end,outer),(start,inner),(end,inner)):
        for i in range(vertices):
            angle=math.tau*i/vertices
            verts.append(origin+radius*(side*math.cos(angle)+up*math.sin(angle)))
    faces=[]
    for i in range(vertices):
        j=(i+1)%vertices
        faces.extend(((i,j,vertices+j,vertices+i),
                      (2*vertices+j,2*vertices+i,3*vertices+i,3*vertices+j),
                      (i,2*vertices+i,2*vertices+j,j),
                      (vertices+j,3*vertices+j,3*vertices+i,vertices+i)))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.materials.append(mat)
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(ob)
    for face in mesh.polygons: face.use_smooth=True
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


def convex_lens(name,x,y,r,z,mat):
    verts=[(x,-y,z+13)]
    radii=(14,28,42,r)
    for radius in radii:
        rise=13*(1-(radius/r)**2)
        for i in range(48):
            angle=math.tau*i/48
            verts.append((x+radius*math.cos(angle),-y-radius*math.sin(angle),z+rise))
    faces=[]
    for i in range(48): faces.append((0,1+i,1+(i+1)%48))
    for level in range(len(radii)-1):
        a=1+48*level;b=a+48
        for i in range(48): faces.append((a+i,b+i,b+(i+1)%48,a+(i+1)%48))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.materials.append(mat)
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(ob)
    for face in mesh.polygons: face.use_smooth=True
    return ob


def jewel(name, x,y,rx,ry,z,mat,glint):
    # A raised five-sided prism grown from a socket. The broad front face is
    # split around a ridge, and its actual side walls catch a separate light.
    outline=[(x-rx*.66,y+ry*.58),(x+rx*.62,y+ry*.58),
             (x+rx,y-ry*.31),(x+rx*.28,y-ry),(x-rx*.81,y-ry*.47)]
    verts=[(px,-py,z+6) for px,py in outline]
    verts += [(x+rx*.07,-y,z+rx*.92)]
    verts += [(px,-py,z-13) for px,py in outline]
    faces=[(i,(i+1)%5,5) for i in range(5)]
    faces += [(i,i+6,(i+1)%5+6,(i+1)%5) for i in range(5)]
    faces.append((6,7,8,9,10))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.materials.append(mat)
    mesh.materials.append(glint)
    for i,face in enumerate(mesh.polygons): face.material_index=1 if i in (1,3,7,9) else 0
    ob=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(ob)
    return ob


def socket(name,spec,m):
    p=Vector(spec["device_port"])
    axis=projected_socket_axis(p,Vector(spec["axis_to_device"]).normalized(),spec["socket_depth"])
    radius=spec["socket_radius"]
    # p is the visible meeting plane. Its front lip is on the same source
    # plane as the conduit front collar; the barrel continues into the body.
    reach = 98 if name == "crystal" else (62 if name == "shield" else 38)
    # The pipe jacket itself continues through this hollow sleeve; leaving the
    # bore open lets its real glass lumen show through at the meeting plane.
    rod(name+" energized throat",p-axis*18,p+axis*(reach-5),3,22,m["blue_lit"],12)
    tubular_sleeve(name+" receiving barrel",p+axis*12,p+axis*(reach-5),33,27.5,m["steel"])
    for distance in (13,reach-13):
        tubular_sleeve(name+" cast locking ferrule",p+axis*distance,p+axis*(distance+5),35,32,m["brass"])
    rod(name+" exposed sleeve crown",p+axis*13,p+axis*(reach-4),5,34,m["silver"],16)
    normal=Vector((-axis.y,axis.x))
    for side in (-1,1):
        edge=p+normal*side*24
        rod(name+" inlet load rail",edge-axis*11,edge+axis*(reach-4),4,27,m["brass"],12)
    for t in range(23,reach-10,21):
        disc(name+" sleeve index",(p+axis*t).x,(p+axis*t).y,3.2,3,34,m["brass"],12)
    # The conduit terminates directly in the extruded barrel. No front-facing
    # painted circle or cap conceals a separation at the meeting plane.
    for side in (-1,1):
        q=p+normal*side*(radius-3)
        disc(name+" keyed bolt",q.x,q.y,2.8,3,spec["socket_depth"]+4,m["brass"],12)


def foot(name,x,y,w,m):
    cube(name+" plinth",x,y,w,33,20,16,m["dark"],5)
    cube(name+" silver skirt",x,y-13,w-12,12,14,27,m["steel"],3)
    cube(name+" brass rail",x,y+15,w-24,3,4,30,m["brass"],1)
    for sx in (-1,1):
        cube(name+" recessed plinth lamp",x+sx*w*.31,y-16,28,3,2,32,m["worklamp"],1)
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
    for yy in (267,312):
        rod("weapon wall bearing",(51,yy),(118,yy+13),13,18,m["steel"])
        cube("weapon wall anchor lug",55,yy,19,29,28,28,m["silver"],4)
    rod("weapon lower load strut",(83,302),(154,328),15,16,m["dark"])
    cast_plate("weapon turret scalloped armor",[(135,180),(171,161),(269,168),(303,194),
                                                 (300,261),(272,283),(154,281),(130,253)],36,43,m["steel"],5)
    cube("turret yoke",218,253,122,86,53,35,m["steel"],12)
    for sx in (-1,1):
        cube("weapon stepped shoulder",218+sx*66,249,25,84,43,48,m["dark"],5)
        cube("weapon shoulder bright chine",218+sx*76,249,4,75,16,74,m["silver"],2)
        for yy in (222,249,276):
            disc("weapon shoulder bolt",218+sx*76,yy,2.8,2,84,m["brass"],12)
    disc("rotary breech",217,212,59,28,45,m["dark"])
    ring("breech brass lock",217,212,56,4,63,m["brass"])
    cube("upper armor",235,143,92,38,21,59,m["steel"],8)
    cube("weapon crown service lamp",235,121,62,3,2,74,m["worklamp"],1)
    cube("turret inset armored panel",231,240,77,38,3,65,m["dark"],4)
    for ix in range(5):
        cube("turret heat vent",201+ix*15,240,6,27,4,70,m["silver"],2)
    for yy in (133,152):
        cube("upper armor etched rail",235,yy,69,2,2,73,m["brass"],1)
    corner_fasteners("upper armor",235,143,92,38,74,m)
    for offset in (-25,25):
        y=190+offset
        rod("twin gun barrel",(62,y-16),(215,y),18,56,m["dark"])
        rod("cooled rifled casing",(69,y-14),(203,y-1),13,65,m["steel"])
        rod("charge rail",(86,y-10),(182,y-1),3.5,79,m["brass"])
        ring("muzzle crown",65,y-14,20,4,75,m["silver"])
        disc("muzzle bore",65,y-14,10,3,78,m["black"])
        ring("muzzle firing coil",65,y-14,10,2.2,91,m["orange_lit"])
        rod("dual charger",(75,y-13),(125,y-8),3.5,84,m["orange_lit"],10)
        for bx in (77,110,145,178):
            ring("barrel cooling collar",bx,y-12,18,2.8,77,m["silver"])
            disc("barrel fastener",bx,y-12,2,2,81,m["brass"],10)
        for bx in (65,98,131,164):
            cube("barrel side vent",bx,y+5,11,3,3,83,m["black"],1)
        cube("weapon barrel armor rib",142,y-19,124,10,13,72,m["steel"],3)
        cube("weapon barrel lower shadow",142,y+20,126,7,9,67,m["dark"],2)
    cube("weapon recoil carriage",160,216,152,18,24,39,m["steel"],4)
    for bx in (92,131,170):
        cube("recoil housing dark tooth",bx,216,19,10,5,55,m["dark"],2)
        cube("recoil housing hot tooth",bx,215,7,3,2,59,m["brass"],1)
    cube("rear power junction",285,207,58,58,38,52,m["dark"],7)
    cube("weapon power input indicator",285,189,29,3,2,77,m["ice"],1)
    corner_fasteners("rear power junction",285,207,58,58,75,m)
    tubing("side supply",[(160,279),(165,253),(202,239),(234,232)],4,65,m["brass"])
    for i in range(7):
        cube("breech radial vent",195+i*7,207,2.5,20,3,72,m["silver"],1)
    socket("weapon",spec,m)


def defence(spec,m):
    foot("shield",1030,288,224,m)
    for yy in (258,307):
        rod("shield wall bearing",(1085,yy),(1140,yy-10),13,18,m["steel"])
        cube("shield wall anchor lug",1137,yy-9,18,28,27,29,m["silver"],4)
    rod("shield lower load strut",(1060,295),(1115,325),16,15,m["dark"])
    cast_plate("shield drive cast side armor",[(905,156),(938,135),(996,138),(1018,160),
                                               (1012,232),(995,253),(933,251),(907,232)],31,45,m["steel"],5)
    cube("field drive",974,197,92,112,50,29,m["steel"],11)
    cube("field drive bridge service lamp",974,140,53,3,2,61,m["worklamp"],1)
    corner_fasteners("field drive",974,197,92,112,61,m)
    rod("field transmission",(969,196),(1030,172),35,18,m["dark"])
    disc("field emitter barrel",1050,172,75,18,43,m["dark"])
    disc("recessed dielectric well",1050,172,68,4,53,m["black"])
    convex_lens("convex glass force face",1050,172,57,53,m["blue"])
    for i in range(12):
        a=i*math.tau/12
        r=58
        x0,y0=1050+r*math.cos(a),172+r*math.sin(a)
        x1,y1=1050+(r+23)*math.cos(a),172+(r+23)*math.sin(a)
        rod("shield segmented ceramic blade",(x0,y0),(x1,y1),7,62,m["steel"],8)
        disc("shield blade root",x0,y0,3,3,72,m["brass"],12)
    disc("shield emitter inner hub",1050,172,20,5,65,m["dark"],24)
    ring("hub contact",1050,172,18,2.5,69,m["brass"])
    ring("field lens bearing",1050,172,75,3,55,m["silver"])
    for i in range(10):
        a=i*math.tau/10
        left,right=a-.22,a+.22
        panel=[(1050+r*math.cos(t),172+r*math.sin(t))
               for r,t in ((58,left),(79,left),(81,right),(58,right))]
        cast_plate("shield segmented projector shoe",panel,62,11,m["steel"],2)
        q=Vector((1050+68*math.cos(a),172+68*math.sin(a)))
        disc("shoe bronze radial pivot",q.x,q.y,3.7,3,70,m["brass"],12)
    for sx in (-1,1):
        cube("field-drive lateral heat exchanger",969+sx*50,193,15,93,29,51,m["steel"],4)
        for iy in range(5):
            cube("heat exchanger grille",969+sx*50,158+iy*17,13,4,3,68,m["dark"],1)
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
    for sx in (-1,1):
        x=201+sx*107
        rod("furnace deck compression leg",(x,622),(x+sx*7,685),15,16,m["steel"])
        cube("furnace visible load column",x+sx*3,661,24,70,20,40,m["steel"],4)
        cube("furnace load column spine",x+sx*3,661,5,61,3,53,m["silver"],2)
        cube("furnace deck bearing",x+sx*7,689,42,23,25,18,m["dark"],5)
        cube("furnace bearing bright lip",x+sx*7,684,36,4,3,32,m["silver"],2)
    cube("heat jacket",177,517,182,176,48,32,m["steel"],15)
    for sx in (-1,1):
        cast_plate("furnace outer heat shield",[(177+sx*86,438),(177+sx*108,461),
                                               (177+sx*111,565),(177+sx*95,598),
                                               (177+sx*67,586),(177+sx*66,464)],30,34,m["steel"],4)
    for sx in (-1,1):
        cube("furnace shoulder service lamp",177+sx*77,459,3,45,2,75,m["worklamp"],1)
    for sx in (-1,1):
        cube("furnace heavy buttress",177+sx*97,523,28,153,47,45,m["dark"],8)
        cube("furnace silver corner chine",177+sx*106,523,5,134,12,72,m["silver"],2)
        for iy in range(5):
            cube("furnace buttress radiator",177+sx*101,471+iy*24,17,6,5,75,m["brass"],1)
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
    cube("recessed tap well",179,541,38,33,5,84,m["black"],6)
    for i,(xx,yy,rr) in enumerate(((169,545,9),(181,540,10),(190,547,7),(175,553,9))):
        disc("moving melt pool %d"%i,xx,yy,rr,3,88,m["orange_lit"],20)
    rod("furnace pour seam",(181,553),(197,574),4,88,m["orange_lit"],12)
    for sx in (-1,1):
        cube("refractory throat jamb",179+sx*40,536,14,76,13,86,m["silver"],3)
        cube("jamb black heat slot",179+sx*40,535,4,57,3,94,m["dark"],1)
    for yy in (500,518,554,572):
        cube("cast refractory course",179,yy,84,7,8,88,m["steel"],2)
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
    for sx in (-1,1):
        x=1003+sx*93
        rod("pressure vessel deck leg",(x,615),(x+sx*8,684),14,17,m["steel"])
        cube("vessel visible load column",x+sx*4,658,23,75,20,40,m["steel"],4)
        cube("vessel load column spine",x+sx*4,658,5,65,3,53,m["silver"],2)
        cube("vessel deck bearing",x+sx*8,690,42,23,25,18,m["dark"],5)
        cube("vessel bearing bright lip",x+sx*8,684,35,4,3,32,m["silver"],2)
    cube("growth vessel back",1020,518,152,188,44,20,m["dark"],14)
    cube("growth vessel crown service lamp",1020,422,78,3,2,73,m["worklamp"],1)
    cube("growth chamber glass",1020,517,118,170,5,53,m["black"],10)
    for sx in (-1,1):
        cube("vessel side pressure bank",1020+sx*81,516,23,158,39,43,m["steel"],6)
        for iy in range(6):
            cube("vessel bank gill",1020+sx*83,453+iy*23,19,6,4,69,m["dark"],1)
            cube("vessel bank gill trim",1020+sx*83,455+iy*23,15,2,2,73,m["brass"],1)
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
    for i,(x,y,rx,ry) in enumerate(((983,565,11,30),(1002,548,12,40),(1021,541,13,47),
                                     (1042,553,11,36),(1061,567,10,28),(971,585,8,21),(1077,586,8,20))):
        jewel("growth crystal %d"%i,x,y,rx,ry,70,m["violet"] if i%2 else m["violet_lit"],m["violet_glint"])
    for y in (476,522,568):
        cube("growth chamber laminated glass rail",1020,y,107,2,2,85,m["silver"],1)
        for x in (974,1066):
            disc("glass rail pin",x,y,2,2,89,m["brass"],10)
    for sx in (-1,1):
        rod("growth chamber diagonal brace",(1020+sx*51,442),(1020+sx*58,590),4,76,m["silver"])
        disc("growth chamber clamp",1020+sx*55,506,7,5,83,m["brass"],16)
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
            for i,mat in enumerate(slots):
                if mat == mats["violet_glint"]: ob.material_slots[i].material=mats["black"]
        bpy.context.scene.render.filepath=str(BUILD / ("r6-"+name+"-work-full.png"))
        bpy.ops.render.render(write_still=True)
        print("RENDERED",name,"port",spec["device_port"],"axis",spec["axis_to_device"],"rect",spec["rect"])


run()
