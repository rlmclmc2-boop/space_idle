"""Rebuild Galaxy's first 3D asset set with Blender, without external packages.

blender --background --python tools/galaxy_assets_blender.py -- --preview-dir PATH
GLB is the runtime authority; no .blend import is needed by Godot.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
OUT = ROOT / "assets/galaxy/v3"
MATS = {}


def material(name, color, emission=0.0, metal=0.65):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Metallic"].default_value = metal
    bs.inputs["Roughness"].default_value = 0.38
    bs.inputs["Emission Color"].default_value = (*color, 1)
    bs.inputs["Emission Strength"].default_value = emission
    MATS[name] = m


def setup_materials():
    material("GalaxyNavy", (.025, .065, .105))
    material("GalaxyArmor", (.48, .55, .64), metal=.32)
    material("GalaxySteel", (.12, .20, .25))
    material("GalaxyCyan", (.05, .48, .72), .8, .25)
    material("GalaxyAmber", (.95, .26, .025), 1.5, .25)
    material("GalaxyViolet", (.50, .09, .9), 1.1, .35)
    material("GalaxyLime", (.25, .75, .07), 1.2, .25)
    material("GalaxySolar", (.025, .16, .32), .1)
    material("GalaxyWindow", (.95, .65, .25), .65, .1)


def finish(obj, name, mat, parent, bevel=0):
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(MATS[mat])
    if bevel:
        mod = obj.modifiers.new("BroadEdge", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def box(name, xyz, dims, mat="GalaxyArmor", parent=None, angle=0, bevel=.09):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z = angle
    return finish(obj, name, mat, parent, bevel)


def cyl(name, xyz, radius, depth, mat="GalaxySteel", parent=None, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    return finish(bpy.context.object, name, mat, parent, .035)


def ring(name, radius, width, z, height, mat="GalaxyArmor", parent=None, segments=48):
    vertices = []
    for h in (z-height/2, z+height/2):
        for r in (radius-width/2, radius+width/2):
            vertices.extend((r*math.cos(i*math.tau/segments), r*math.sin(i*math.tau/segments), h) for i in range(segments))
    faces = []
    n = segments
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,n+j,n+i), (2*n+i,3*n+i,3*n+j,2*n+j),
                  (i,2*n+i,2*n+j,j), (n+i,n+j,3*n+j,3*n+i)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj=bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj,name,mat,parent)


def empty(name, xyz=(0,0,0), parent=None):
    obj=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(obj)
    obj.location=xyz
    obj.parent=parent
    return obj


def radial_pods(root, count, radius, size, z, phase=0):
    for i in range(count):
        a=i*math.tau/count+phase
        x,y=radius*math.cos(a),radius*math.sin(a)
        box("Habitat",(x,y,z),size,parent=root,angle=a)
        box("HabitatWindow",(x,y,z+size[2]/2+.025),(size[0]*.6,size[1]*.6,.055),"GalaxyCyan",root,angle=a,bevel=.02)


def arc(name, radius, width, z, height, start, end, mat, parent, segments=8):
    verts=[]
    for h in (z-height/2,z+height/2):
        for r in (radius-width/2,radius+width/2):
            verts.extend((r*math.cos(start+(end-start)*i/segments),r*math.sin(start+(end-start)*i/segments),h) for i in range(segments+1))
    n=segments+1
    faces=[]
    for i in range(segments):
        j=i+1
        faces.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
    faces.extend([(0,n,3*n,2*n),(n-1,3*n-1,4*n-1,2*n-1)])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish(obj,name,mat,parent,.025)


def windows(root,radius,z,count=32):
    for i in range(count):
        a=i*math.tau/count
        arc("Window",radius,.035,z,.095,a,a+.035,"GalaxyWindow" if i%4 else "GalaxyCyan",root,1)


def habitat(root,r,z,width=.85,count=12):
    ring("DarkRing",r,width,z,.72,"GalaxyNavy",root,64)
    ring("InnerLight",r-width/2,.08,z+.13,.16,"GalaxyCyan",root,64)
    for i in range(count):
        a=i*math.tau/count
        arc("ArmorSegment",r,width+.10,z+.43,.16,a+.018,a+math.tau/count-.018,"GalaxyArmor",root)
        arc("LowerLip",r,width+.14,z-.35,.09,a+.025,a+math.tau/count-.025,"GalaxySteel",root)
    windows(root,r+width/2+.015,z+.13,count*3)


def spire(root,xyz,height,radius):
    x,y,z=xyz
    cyl("TowerBase",(x,y,z+height*.17),radius,height*.34,"GalaxyNavy",root,24)
    cyl("TowerCollar",(x,y,z+height*.32),radius*1.07,.18,"GalaxyArmor",root,24)
    bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=radius*.8,radius2=radius*.22,depth=height*.60,location=(x,y,z+height*.61))
    finish(bpy.context.object,"TowerArmor","GalaxyArmor",root,.04)
    for a in (0,math.pi/2,math.pi,math.pi*1.5):
        box("TowerRib",(x+math.cos(a)*radius*.7,y+math.sin(a)*radius*.7,z+height*.54),(.12,.12,height*.45),"GalaxySteel",root,bevel=.02)
    cyl("Antenna",(x,y,z+height*.97),.035,height*.3,"GalaxyArmor",root,8)


def core(root):
    from galaxy_core_stylized import build
    build(root, sys.modules[__name__])


def colony(root,level):
    radius=3.1+level*.15
    habitat(root,radius,1.1,1.0,12)
    cyl("HabitatHub",(0,0,1.5),1.05,2.5,"GalaxyNavy",root,24)
    for a in (0,math.pi/2):box("TransitSpine",(0,0,.8),(radius*2,.30,.32),"GalaxySteel",root,angle=a)
    spire(root,(0,0,2.0),1.8+level*.48,.62)
    for i in range(4+level):
        a=i*math.tau/(4+level)
        box("RimPier",(radius*math.cos(a),radius*math.sin(a),1.55),(.5,.65,.38),"GalaxySteel",root,angle=a)
    if level>=2:habitat(root,2.25,2.3,.55,10)
    if level>=3:
        for x in (-1.5,1.5):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.72,location=(x,0,1.4))
            obj=bpy.context.object;obj.scale.z=.6;finish(obj,"EcologyGlass","GalaxySolar",root)
            ring("GlassFrame",.74,.08,1.4,.12,"GalaxyArmor",root).location.x=x
    if level>=4:habitat(root,4.8,.55,.5,16)
    if level>=5:
        for x in (-1.8,1.8):spire(root,(x,1.8,1.7),2.8,.40)
    ring("ActivityRing",1.25,.08,2.0,.12,"GalaxyCyan",root)


def pressure_tank(root,x,y,r,h):
    cyl("PressureVessel",(x,y,h/2+.6),r,h,"GalaxyNavy",root,24)
    for z in (.8,h*.5+.6,h+.35):
        collar=ring("TankCollar",r+.06,.14,z,.15,"GalaxyArmor",root,32);collar.location.x=x;collar.location.y=y
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=r,location=(x,y,h+.5))
    obj=bpy.context.object;obj.scale.z=.6;finish(obj,"PressureCap","GalaxyArmor",root)
    for a in (0,math.pi/2,math.pi,math.pi*1.5):
        box("TankRib",(x+(r+.03)*math.cos(a),y+(r+.03)*math.sin(a),h/2+.6),(.16,.16,h*.85),"GalaxyArmor",root,bevel=.02)
    cyl("Valve",(x,y,h+.6+r*.6),r*.25,.4,"GalaxySteel",root,12)


def blockout(root,key):
    # First production-style trial for the remaining families; level mapping stays unchanged.
    if key=="orbital_shipyard":
        box("DockSpine",(0,3.8,1.0),(9.4,1.1,1.0),"GalaxyNavy",root)
        for x in (-3.6,3.6):
            box("DockRail",(x,0,.7),(1.0,9.5,1.2),"GalaxyNavy",root)
            box("DockArmor",(x,0,1.35),(1.1,9.2,.22),"GalaxyArmor",root)
            for y in (-3,-1,1,3):
                box("DockPier",(x*.82,y,1.0),(2.0,.5,.45),"GalaxySteel",root)
                box("GantryPost",(x,y,2.0),(.18,.18,2.5),"GalaxySteel",root,bevel=.02)
                box("GantryArm",(x*.8,y,3.2),(1.6,.16,.16),"GalaxyArmor",root,bevel=.02)
                box("DockLamp",(x*.68,y,1.27),(.25,.3,.1),"GalaxyCyan",root,bevel=.01)
        box("VesselKeel",(0,0,1.0),(1.3,6.8,.65),"GalaxySteel",root)
        for y in (-2,-.8,.4,1.6):box("VesselHull",(0,y,1.5),(2.0,1.0,.65),"GalaxyArmor",root,bevel=.20)
        spire(root,(0,3.8,1.2),2.3,.6)
    elif key=="stellar_energy_array":
        cyl("EnergyHub",(0,0,1),1.25,2,"GalaxyNavy",root,24)
        habitat(root,1.4,1.2,.35,10)
        for i in range(8):
            a=i*math.tau/8
            box("PanelSpar",(2.9*math.cos(a),2.9*math.sin(a),.65),(4.3,.16,.20),"GalaxySteel",root,angle=a,bevel=.02)
            arc("SolarFan",3.7,2.9,.9,.12,a+.07,a+.68,"GalaxySolar",root,5)
            for r in (2.35,3.1,3.85,4.6,5.1):arc("SolarLattice",r,.025,.98,.025,a+.07,a+.68,"GalaxyArmor",root,5)
            for offset in (.07,.27,.48,.68):
                box("PanelSeam",(3.7*math.cos(a+offset),3.7*math.sin(a+offset),.99),(2.9,.025,.025),"GalaxySteel",root,angle=a+offset,bevel=0)
        spire(root,(0,0,1.8),1.6,.4)
    elif key=="crystal_refinery":
        habitat(root,3.55,.7,.7,12)
        cyl("ReactorBed",(0,0,.55),2.9,.7,"GalaxyNavy",root,32)
        for x,y,r,h in [(0,0,.7,5),(-1.7,-.8,.5,3.1),(1.4,-1,.55,3.8),(0,1.7,.45,2.7)]:
            cyl("PrismSocket",(x,y,1.0),r*1.35,.6,"GalaxyArmor",root,12)
            bpy.ops.mesh.primitive_cone_add(vertices=5,radius1=r,radius2=0,depth=h,location=(x,y,1.3+h/2))
            finish(bpy.context.object,"CrystalPrism","GalaxyViolet",root)
        for i in range(6):
            a=i*math.tau/6;spire(root,(3.4*math.cos(a),3.4*math.sin(a),1),1.5,.25)
        ring("ActivityRing",2.7,.07,1.5,.1,"GalaxyCyan",root)
    elif key=="heavy_element_refinery":
        box("ShieldDeck",(0,0,.45),(8.5,6.8,.7),"GalaxySteel",root)
        for x,y,h in [(-2.2,0,4.0),(1.2,-1.6,5.2),(1.2,1.8,3.5)]:pressure_tank(root,x,y,1.3,h)
        for x in (-3.9,3.9):box("ShieldEdge",(x,0,.9),(.3,6.6,.6),"GalaxyArmor",root)
    else:
        box("RefineryDeck",(0,0,.5),(8.6,6.5,.8),"GalaxySteel",root)
        box("Furnace",(0,0,1.8),(3.1,4.8,2.2),"GalaxyNavy",root)
        for x in (-1.2,0,1.2):box("HeatVent",(x,0,3.0),(.18,3.7,.1),"GalaxyAmber",root,bevel=.01)
        for x in (-2.8,2.8):
            for y in (-1.7,1.7):pressure_tank(root,x,y,.78,2.5)
        for y in (-3.0,3.0):box("TransferPipe",(0,y,1.2),(8,.22,.22),"GalaxyArmor",root,bevel=.04)


def shuttle(root):
    box("Fuselage",(0,0,.28),(.65,1.5,.5),"GalaxyArmor",root,bevel=.14)
    box("Cargo",(0,.1,.60),(.5,.7,.3),"GalaxyNavy",root)
    for x in (-.51,.51):
        box("Engine",(x,-.25,.23),(.3,1.1,.4),"GalaxySteel",root)
        box("EngineGlow",(x,-.84,.23),(.21,.12,.23),"GalaxyCyan",root,bevel=.02)
    box("Cockpit",(0,.47,.56),(.4,.4,.1),"GalaxyCyan",root)


def export_asset(key, level, relative, builder):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    root=empty(key)
    builder(root)
    if not any(obj.name=="DockSocket" for obj in bpy.context.scene.objects):
        empty("DockSocket",(0,-4.5,1.0) if key!="galaxy_core" else (0,-10,1.2),root)
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    # Update matrices before reading bounds and applying the bottom anchor.
    bpy.context.view_layer.update()
    coords=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    minimum=min(v.z for v in coords)
    for child in list(root.children): child.location.z-=minimum
    bpy.context.view_layer.update()
    coords=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    bounds=[round(max(v[i] for v in coords)-min(v[i] for v in coords),3) for i in range(3)]
    static=[o for o in meshes if o.name!="ActivityRing"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in static:o.select_set(True)
    bpy.context.view_layer.objects.active=static[0]
    bpy.ops.object.join()
    static[0].name="Structure"
    if key=="galaxy_core":
        from galaxy_core_detail import bake_vertex_shading
        bake_vertex_shading(static[0])
    triangles=sum(len(p.vertices)-2 for o in bpy.context.scene.objects if o.type=="MESH" for p in o.data.polygons)
    path=OUT/relative
    path.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",export_yup=True,export_cameras=False,export_lights=False,export_animations=False,export_extras=False)
    return {"key":key,"level":level,"path":str(path.relative_to(ROOT)).replace("\\","/"),"bounds_godot_xyz":[bounds[0],bounds[2],bounds[1]],"triangles":triangles,"bytes":path.stat().st_size}


def preview(records, directory):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for i,record in enumerate(records):
        bpy.ops.import_scene.gltf(filepath=str(ROOT/record["path"]))
        roots=[o for o in bpy.context.selected_objects if o.parent is None]
        col=i%4; row=i//4
        for obj in roots:
            if record["key"]=="galaxy_core":obj.scale=(.45,)*3
            if record["key"]=="transport_shuttle":obj.scale=(3,)*3
            obj.location+=(Vector(((col-1.5)*13,(1-row)*13,0)))
    bpy.ops.object.camera_add(location=(0,-32,62))
    camera=bpy.context.object
    camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.type="ORTHO";camera.data.ortho_scale=55
    bpy.context.scene.camera=camera
    bpy.ops.object.light_add(type="AREA",location=(-10,-12,25))
    bpy.context.object.data.energy=4000;bpy.context.object.data.shape="DISK";bpy.context.object.data.size=20
    bpy.ops.object.light_add(type="AREA",location=(15,10,20))
    bpy.context.object.data.energy=2500;bpy.context.object.data.size=20
    scene=bpy.context.scene
    scene.world.color=(.09,.09,.09)
    scene.render.engine="CYCLES";scene.cycles.samples=16
    scene.render.resolution_x=1800;scene.render.resolution_y=1250;scene.render.resolution_percentage=100
    directory.mkdir(parents=True,exist_ok=True)
    scene.render.filepath=str(directory/"galaxy-glb-lineup.png")
    bpy.ops.render.render(write_still=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--preview-dir",type=Path)
    parser.add_argument("--core-only",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    setup_materials()
    records=[export_asset("galaxy_core",0,"core/galaxy_core.glb",core)]
    if args.core_only:
        manifest_path=OUT/"manifest.json"
        manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["assets"]=[records[0] if row["key"]=="galaxy_core" else row for row in manifest["assets"]]
        manifest_path.write_text(json.dumps(manifest,indent=2),encoding="utf-8")
        return
    for level in range(1,6):
        records.append(export_asset("colony_ring",level,f"buildings/colony_ring/colony_ring_lv{level}.glb",lambda r,n=level:colony(r,n)))
    for key in ("orbital_shipyard","stellar_energy_array","interstellar_refinery","crystal_refinery","heavy_element_refinery"):
        records.append(export_asset(key,1,f"buildings/{key}/{key}_lv1.glb",lambda r,k=key:blockout(r,k)))
    records.append(export_asset("transport_shuttle",0,"ships/transport_shuttle.glb",shuttle))
    (OUT/"manifest.json").write_text(json.dumps({"generator":"tools/galaxy_assets_blender.py","up_axis":"Y","anchor":"bottom center","assets":records},indent=2),encoding="utf-8")
    if args.preview_dir:preview(records,args.preview_dir)


if __name__=="__main__":main()

