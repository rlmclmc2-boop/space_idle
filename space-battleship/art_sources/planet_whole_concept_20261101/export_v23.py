"""Export four independently owned sections in one shared orbital frame."""
from pathlib import Path
import bpy

HERE=Path(__file__).resolve().parent
OUT=HERE.parents[1]/"assets/planets/facilities_v9"
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(HERE/"concept-v23.blend"))

roots={
    "auto_explore":"01 / Command district of the orbital city",
    "refinery":"02 / Heat district of the orbital city",
    "equipment":"03 / Manufacturing district of the orbital city",
    "shipyard":"04 / Open launch district of the orbital city",
}


def pivot(root,name,position=(0,0,0)):
    obj=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(obj)
    obj.parent=root
    obj.location=position
    return obj


def transfer(root,p,name):
    for obj in list(root.children_recursive):
        if obj.name==name:
            bpy.context.view_layer.update()
            local_to_new_parent=p.matrix_world.inverted() @ obj.matrix_world.copy()
            obj.parent=p
            obj.matrix_parent_inverse.identity()
            obj.matrix_basis=local_to_new_parent
            bpy.context.view_layer.update()
            return obj
    raise RuntimeError(f"Missing concept part: {root.name}/{name}")


def part(name,mesh,mat,p):
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    obj.parent=p
    return obj


station=bpy.data.objects[roots["auto_explore"]]
spin=pivot(station,"HabitatRingSpin")
for name in ("Command bearing cyan collar","Command faceted core",
             "Command blue canopy"):
    transfer(station,spin,name)
for side,label in ((-1,"SolarHingeLeft"),(1,"SolarHingeRight")):
    hinge=pivot(station,label,(side*.62,-.32,1.44))
    bpy.ops.mesh.primitive_cube_add(size=1)
    vane=bpy.context.object
    vane.name="Articulated habitat power wing"
    vane.parent=hinge
    vane.location=(side*.10,0,.03)
    vane.dimensions=(.22,.28,.045)
    vane.data.materials.append(bpy.data.materials["Dark blue glass"])

refinery=bpy.data.objects[roots["refinery"]]
for side,label in ((-1,"IntakeWheelLeft"),(1,"IntakeWheelRight")):
    wheel=pivot(refinery,label,(side*.58,-.45,1.16))
    bpy.ops.mesh.primitive_torus_add(major_radius=.13,minor_radius=.035,
                                    major_segments=24,minor_segments=8)
    rotor=bpy.context.object
    rotor.name="Animated intake ring"
    rotor.parent=wheel
    rotor.location=(0,0,0)
    rotor.data.materials.append(bpy.data.materials["Warm faceted ivory armor"])
shutters=pivot(refinery,"CoolingShutters",(0,-.25,1.22))
for x in (-.30,0,.30):
    bpy.ops.mesh.primitive_cube_add(size=1)
    shutter=bpy.context.object
    shutter.name="Animated heat shutter"
    shutter.parent=shutters
    shutter.location=(x,0,0)
    shutter.dimensions=(.22,.08,.06)
    shutter.data.materials.append(bpy.data.materials["Warm faceted ivory armor"])

workshop=bpy.data.objects[roots["equipment"]]
gantry=pivot(workshop,"GantrySlide")
transfer(workshop,gantry,"Overhead fabrication gantry")
arm=pivot(gantry,"ToolArmSweep",(.19,0,1.40))
for name in ("Downward working tool","Work site contained welding line"):
    transfer(workshop,arm,name)

shipyard=bpy.data.objects[roots["shipyard"]]
crane=pivot(shipyard,"CraneSlide",(.60,-.60,1.35))
bpy.ops.mesh.primitive_cube_add(size=1)
hoist=bpy.context.object
hoist.name="Animated shipyard hoist"
hoist.parent=crane
hoist.location=(0,0,0)
hoist.dimensions=(.23,.45,.13)
hoist.data.materials.append(bpy.data.materials["Machine steel"])
collar=pivot(shipyard,"DockCollarSpin",(0,-.77,.81))
bpy.ops.mesh.primitive_torus_add(major_radius=.23,minor_radius=.048,
                                major_segments=32,minor_segments=8)
ring=bpy.context.object
ring.name="Animated dock collar"
ring.parent=collar
ring.data.materials.append(bpy.data.materials["Warm faceted ivory armor"])

for kind,root_name in roots.items():
    root=bpy.data.objects[root_name]
    original_location=root.location.copy()
    original_rotation=root.rotation_euler.copy()
    original_name=root.name
    bpy.context.view_layer.update()
    child_world={child:child.matrix_world.copy() for child in root.children}
    root.location=(0,0,0)
    root.rotation_euler=(0,0,0)
    bpy.context.view_layer.update()
    for child,world in child_world.items():
        child.matrix_world=world
    root.name="Facility"
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in (root,*root.children_recursive): obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+".glb")),
        export_format="GLB",use_selection=True,export_animations=False,
        export_cameras=False,export_lights=False,export_yup=True)
    root.name=original_name
    root.location=original_location
    root.rotation_euler=original_rotation
    print("EXPORTED",kind,OUT/(kind+".glb"))
