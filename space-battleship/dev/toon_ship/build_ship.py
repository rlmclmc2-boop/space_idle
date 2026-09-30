"""Blender generator: separate hull and interchangeable pulse-laser assets.

Blender +Y exports to Godot -Z. Hull origin is its center; weapon origin is its mount.
"""
import json
import math
import re
import subprocess
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

OUT = Path(__file__).resolve().parent
MATERIALS = {}


def material(name, rgb, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*rgb, 1)
    node.inputs["Metallic"].default_value = 0.0
    node.inputs["Roughness"].default_value = 0.8
    node.inputs["Emission Color"].default_value = (*rgb, 1)
    node.inputs["Emission Strength"].default_value = emission
    MATERIALS[name] = mat


def empty(name, xyz=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = xyz
    obj.parent = parent
    return obj


def finish(obj, name, mat, parent, bevel=0.06, segments=2):
    obj.name = name
    obj.data.materials.append(MATERIALS[mat])
    if bevel:
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new("Broad armor chamfer", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.harden_normals = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        for edge in bm.edges:
            if edge.is_manifold and edge.calc_face_angle() > math.radians(48):
                edge.smooth = False
        bm.to_mesh(obj.data)
        bm.free()
        normal = obj.modifiers.new("Stable armor normals", "WEIGHTED_NORMAL")
        normal.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=normal.name)
    obj.parent = parent
    return obj


def box(name, xyz, size, mat, parent, bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, bevel)


def slab(name, outline, bottom, top, mat, parent, bevel=0.08):
    # Enforce outward winding, including reflected port-side armor.
    area = sum(outline[i][0]*outline[(i+1)%len(outline)][1]-outline[(i+1)%len(outline)][0]*outline[i][1] for i in range(len(outline)))
    if area < 0:
        outline = list(reversed(outline))
    n = len(outline)
    verts = [(x, y, bottom) for x, y in outline] + [(x, y, top) for x, y in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1) % n, (i+1) % n+n, i+n) for i in range(n)]
    if mat == "ProtoIvory":
        # Broad sloping armor, not a flat extruded silhouette: reads in the real top view.
        center_x = sum(p[0] for p in outline)/n
        center_y = sum(p[1] for p in outline)/n
        verts[n:] = [(x,y,top-0.18) for x,y in outline]
        verts += [(center_x+(x-center_x)*0.68,center_y+(y-center_y)*0.96,top) for x,y in outline]
        faces[1] = tuple(range(2*n,3*n))
        faces += [(i+n,(i+1)%n+n,(i+1)%n+2*n,i+2*n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent, bevel)


def cylinder(name, xyz, radius, depth, mat, parent, sideways=False, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    obj = bpy.context.object
    if sideways:
        obj.rotation_euler.x = math.pi / 2
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(obj, name, mat, parent, 0.035, 2)


def armor_mass(name, stations, mat, parent, offset_x=0, bevel=0.08):
    """One clean longitudinal armor mass, broad roof and sloped shoulders.

    Station: y, half-width, floor, roof. No seams, texture or separate detail plates.
    """
    vertices = []
    for y, width, bottom, top in stations:
        side = bottom+(top-bottom)*0.42
        vertices += [(offset_x+x,y,z) for x,z in [
            (-width*0.76,bottom),(-width,side),(-width*0.91,top-0.22),
            (-width*0.53,top),(width*0.53,top),(width*0.91,top-0.22),
            (width,side),(width*0.76,bottom)]]
    faces = [tuple(reversed(range(8)))]
    for station in range(len(stations)-1):
        base = station*8
        faces += [(base+i,base+(i+1)%8,base+(i+1)%8+8,base+i+8) for i in range(8)]
    faces += [tuple(range((len(stations)-1)*8,len(stations)*8))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj = finish(obj,name,mat,parent,bevel)
    # Keep the large armor planes stable under cel thresholds. Interpolated
    # weighted normals can introduce small false lighting islands on a flat roof.
    normals = [(0,0,0)]*len(obj.data.loops)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
        for index in polygon.loop_indices:
            normals[index] = tuple(polygon.normal)
    obj.data.normals_split_custom_set(normals)
    return obj


def merge_under(parent, name):
    objects = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.parent == parent]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = parent.matrix_world.translation
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return obj


def descendants(root):
    objects = [root]
    for child in root.children:
        objects.extend(descendants(child))
    return objects


def normalize_names(root):
    for obj in descendants(root):
        name=re.sub(r"\.\d+$","",obj.name)
        other=bpy.data.objects.get(name)
        if other is not None and other!=obj:
            other.name="Unused_"+other.name
        obj.name=name


def export_asset(root, glb_path, blend_path):
    normalize_names(root)
    objects = descendants(root)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format="GLB",
                              use_selection=True, export_yup=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False, export_animations=False)
    meshes = [obj for obj in objects if obj.type=="MESH"]
    points = []
    tris = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        tris += len(obj.data.loop_triangles)
        points += [obj.matrix_world @ Vector(vertex) for vertex in obj.bound_box]
    low = [min(v[i] for v in points) for i in range(3)]
    high = [max(v[i] for v in points) for i in range(3)]
    return {"path":"res://"+str(glb_path.relative_to(OUT.parents[1])).replace("\\","/"),
            "source":str(blend_path.relative_to(OUT)).replace("\\","/"),
            "triangles":tris,"mesh_nodes":len(meshes),
            "godot_aabb_min":[low[0],low[2],-high[1]],
            "godot_aabb_max":[high[0],high[2],-low[1]]}


def build():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    material("ProtoIvory", (0.78, 0.77, 0.72))
    material("ProtoNavy", (0.025, 0.055, 0.085))
    material("ProtoGraphite", (0.11, 0.16, 0.20))
    material("ProtoCyan", (0.025, 0.42, 0.57), 0.3)
    material("ProtoEngine", (0.025, 0.42, 0.57), 1.4)
    root = empty("PlayerHull")
    hull = empty("Hull", parent=root)
    slab("WideKeel", [(-2.6,4.35),(-3.65,3.35),(-3.65,-3.7),(-2.8,-4.35),
                       (2.8,-4.35),(3.65,-3.7),(3.65,3.35),(2.6,4.35)],
         -0.6,0.18,"ProtoNavy",hull,0.12)
    slab("ShortProw",[(-2.6,4.35),(-1.6,4.9),(1.6,4.9),(2.6,4.35)],
         -0.32,0.5,"ProtoIvory",hull,0.06)
    box("ClearDeck",(0,0,0.26),(6.6,8.1,0.22),"ProtoGraphite",hull,0.08)
    for side in (-1,1):
        armor_mass("EdgeArmor",[(-3.85,0.18,0.14,0.50),(-3.25,0.34,0.12,0.64),(2.90,0.34,0.12,0.64),(3.70,0.16,0.14,0.47)],"ProtoIvory",hull,offset_x=side*3.22,bevel=0.055)
    box("CenterSpine",(0,0,0.35),(0.32,7.8,0.22),"ProtoNavy",hull,0.05)
    box("AftBridge",(0,-4.12,0.51),(1.6,0.53,0.45),"ProtoIvory",hull,0.09)
    box("BridgeGlass",(0,-3.88,0.70),(0.85,0.10,0.06),"ProtoCyan",hull,0.025)
    mounts=[]
    for row,y in enumerate((3.05,1.02,-1.02,-3.05)):
        for col,x in enumerate((-1.72,1.72)):
            slot=(5,7,0,6,1,2,3,4)[row*2+col]
            box("InstallDeck%02d"%(slot+1),(x,y,0.43),(2.62,1.82,0.20),"ProtoNavy",hull,0.08)
            mounts.append(empty("WeaponMount%02d"%(slot+1),(x,y,0.57),root))
    weapons={}
    for kind in ("pulse_laser","missile","cannon","long_laser"):
        weapon=empty(kind+"Weapon")
        turret=empty("TurretPivot",parent=weapon)
        cylinder("RotationBearing",(0,0,0.045),0.40,0.09,"ProtoNavy",weapon,vertices=12)
        box("RotationYoke",(0,0,0.15),(0.76,0.65,0.19),"ProtoGraphite",turret,0.045)
        if kind=="missile":
            box("PodCradle",(0,0,0.28),(1.26,1.10,0.30),"ProtoNavy",turret,0.08)
            for x in (-0.34,0.34):
                box("MissileBay",(x,-0.06,0.48),(0.51,1.03,0.35),"ProtoIvory",turret,0.08)
                box("LaunchOpening",(x,0.47,0.48),(0.35,0.04,0.19),"ProtoNavy",turret,0.015)
                box("BayRecess",(x,0.22,0.663),(0.27,0.35,0.015),"ProtoGraphite",turret,0.015)
            empty("Muzzle",(-0.34,0.52,0.48),turret)
            empty("Muzzle02",(0.34,0.52,0.48),turret)
        elif kind=="cannon":
            box("GunHousing",(0,-0.13,0.42),(1.10,0.87,0.47),"ProtoIvory",turret,0.1)
            cylinder("BarrelRoot",(0,0.30,0.42),0.24,0.30,"ProtoGraphite",turret,True,12)
            cylinder("Barrel",(0,0.67,0.42),0.14,0.62,"ProtoNavy",turret,True,12)
            box("MuzzleBrake",(0,0.98,0.42),(0.40,0.21,0.29),"ProtoGraphite",turret,0.04)
            box("Bore",(0,1.092,0.42),(0.21,0.018,0.12),"ProtoNavy",turret,0)
            empty("Muzzle",(0,1.11,0.42),turret)
        elif kind=="pulse_laser":
            slab("EnergyHousing",[(-0.61,-0.40),(0.61,-0.40),(0.48,0.36),(0,0.64),(-0.48,0.36)],
                 0.24,0.63,"ProtoIvory",turret,0.05)
            cylinder("EmitterRoot",(0,0.41,0.43),0.27,0.30,"ProtoNavy",turret,True,12)
            cylinder("EnergyBarrel",(0,0.66,0.43),0.20,0.24,"ProtoGraphite",turret,True,12)
            cylinder("EmitterLens",(0,0.79,0.43),0.15,0.025,"ProtoCyan",turret,True,12)
            box("EnergyTrack",(0,0.08,0.65),(0.20,0.66,0.04),"ProtoCyan",turret,0.02)
            empty("Muzzle",(0,0.82,0.43),turret)
        else:
            box("BeamCapacitor",(0,-0.18,0.40),(0.70,1.00,0.42),"ProtoGraphite",turret,0.08)
            for x in (-0.41,0.41):
                box("BeamFork",(x,0.19,0.46),(0.25,1.22,0.39),"ProtoIvory",turret,0.045)
            box("BeamChannel",(0,0.22,0.48),(0.21,0.92,0.15),"ProtoNavy",turret,0.025)
            box("BeamLens",(0,0.71,0.48),(0.20,0.045,0.13),"ProtoCyan",turret,0.015)
            box("CapacitorLight",(0,-0.42,0.62),(0.28,0.16,0.03),"ProtoCyan",turret,0.015)
            empty("Muzzle",(0,0.76,0.48),turret)
        weapons[kind]=weapon
    for i, x in enumerate((-2.7,-0.90,0.90,2.7),1):
        y = -4.15
        engine = empty(f"Engine{i:02}", (x,y,-0.08), root)
        cylinder("NozzleHousing", (0,0.28,0), 0.43, 1.09, "ProtoGraphite", engine, True, 24)
        cylinder("NozzleLip", (0,-0.30,0), 0.445, 0.14, "ProtoGraphite", engine, True, 24)
        cylinder("EngineLens", (0,-0.38,0), 0.325, 0.025, "ProtoEngine", engine, True, 24)
        empty(f"ExhaustSocket{i:02}", (0,-0.42,0), engine)
        merge_under(engine, f"Engine{i:02}Mesh")
    merge_under(hull, "HullArmor")
    bpy.context.view_layer.update()
    OUT.joinpath("source").mkdir(exist_ok=True)
    OUT.joinpath("weapons").mkdir(exist_ok=True)
    source_kind = sys.argv[sys.argv.index("--source-kind")+1] if "--source-kind" in sys.argv else ""
    if source_kind:
        save_source(weapons[source_kind],OUT/("source/"+source_kind+".blend"))
        return
    hull_meta=export_asset(root,OUT/"player_hull.glb",OUT/"source/player_hull.blend")
    assets={"hull":hull_meta}
    for kind,weapon in weapons.items():
        assets[kind]=export_asset(weapon,OUT/("weapons/"+kind+".glb"),OUT/("source/"+kind+".blend"))
    manifest={"assets":assets,"godot_aabb_min":hull_meta["godot_aabb_min"],
              "godot_aabb_max":hull_meta["godot_aabb_max"],"forward":"-Z","pivot":"hull center","units":"meters",
              "weapon_mounts":[{"node":m.name,"slot":int(m.name[-2:])-1,"position":[m.location.x,m.location.z,-m.location.y],
                                "rotation_axis":"Y","forward":"-Z"} for i,m in enumerate(mounts)],
              "weapon_contract":{"pivot":"mount origin","aim_node":"TurretPivot","muzzle_node":"Muzzle"}}
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    save_source(root,OUT/"source/player_hull.blend")
    for kind in weapons:
        subprocess.run([bpy.app.binary_path,"--background","--factory-startup","--python-exit-code","1",
                        "--python",str(Path(__file__).resolve()),"--","--source-kind",kind],check=True)


def save_source(root, path):
    normalize_names(root)
    keep = set(descendants(root))
    for obj in list(bpy.data.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj,do_unlink=True)
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)


if __name__ == "__main__":
    build()
