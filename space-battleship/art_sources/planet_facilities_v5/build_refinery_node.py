"""Build the refinery as an open, tangent-local furnace and receiving node.

X is the ring passage. Two hopper shells grow from its pressure cheeks; the
ore tread enters a visible furnace mouth while the actual ring deck continues
through both ends. Named pivots retain the existing work-cycle animation.
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parents[1] / "assets/planets/facilities_v5/refinery.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgb, metallic=.13, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = .55
    if emission:
        shader.inputs["Emission Color"].default_value = (*rgb, 1)
        shader.inputs["Emission Strength"].default_value = emission
    return mat


ivory = material("Furnace warm ivory armor", (.74,.67,.54))
edge = material("Furnace cut armor edge", (.47,.43,.36))
navy = material("Furnace pressure interior", (.035,.10,.15))
lower_steel = material("Furnace lower load steel", (.10,.18,.23))
blue = material("Furnace blue machinery", (.075,.19,.27))
ochre = material("Furnace warm industrial plate", (.58,.27,.085))
ember = material("Furnace hot amber aperture", (.97,.41,.065), emission=.44)
cyan = material("Furnace inset cyan service light", (.045,.54,.62), emission=.35)


def node(name, parent=None, at=(0,0,0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = at
    return obj


def finish(obj, name, mat, parent, bevel=.025):
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    if bevel:
        mod = obj.modifiers.new("Machined bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("Face normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def box(name, at, size, mat, parent, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, bevel)


def cylinder(name, at, radius, depth, mat, parent, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                        depth=depth, location=at)
    return finish(bpy.context.object, name, mat, parent, .014)


def beam(name, a, b, width, depth, mat, parent):
    delta = Vector(b)-Vector(a)
    obj = box(name, (Vector(a)+Vector(b))*.5,
              (width,depth,delta.length),mat,parent,min(width,depth)*.16)
    obj.rotation_euler = delta.to_track_quat('Z','Y').to_euler()
    return obj


def longitudinal_hull(name, sections, mat, parent):
    verts=[]
    for x,y,z,hy,hz in sections:
        for u,v in ((-1,-.7),(-.7,-1),(.7,-1),(1,-.7),
                    (1,.7),(.7,1),(-.7,1),(-1,.7)):
            verts.append((x,y+u*hy,z+v*hz))
    faces=[tuple(reversed(range(8)))]
    for section in range(len(sections)-1):
        for side in range(8):
            faces.append((section*8+side,section*8+(side+1)%8,
                          (section+1)*8+(side+1)%8,(section+1)*8+side))
    faces.append(tuple((len(sections)-1)*8+side for side in range(8)))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj,name,mat,parent,.035)


def hopper(name, y, parent):
    """Deep open-topped octagonal bin, made from four thick sloped walls."""
    root=node(name,parent,(0,y,0))
    side=1 if y>0 else -1
    box("Hopper navy pressure cradle",(.08,0,.55),(1.58,.70,.55),navy,root,.08)
    box("Hopper ochre lower shell",(.08,0,.97),(1.40,.79,.42),ochre,root,.07)
    for rail in (-1,1):
        beam("Hopper outward flare",(-.67,rail*.34,1.12),
             (-.74,rail*.49,1.72),.13,.13,ivory,root)
        beam("Hopper far flare",(.72,rail*.34,1.12),
             (.78,rail*.49,1.72),.13,.13,ivory,root)
        box("Hopper raised side plate",(.02,rail*.46,1.45),
            (1.51,.16,.52),ivory,root,.055)
        box("Hopper service line",(.02,rail*.548,1.34),
            (1.09,.018,.06),cyan,root,.008)
    for end in (-1,1):
        box("Hopper beveled end",(end*.74,0,1.45),
            (.17,1.04,.54),ochre,root,.042)
    # The four existing load walls surround a recessed floor. Keeping its
    # dark face below the rim gives the receiving bin actual visible depth.
    box("Recessed hopper pressure floor",(.02,0,1.30),(1.18,.69,.045),navy,root,.012)
    for x in (-.62,.62):
        box("Hopper ivory mouth lip",(x,0,1.79),(.095,.90,.09),ivory,root,.016)
    for rail in (-1,1):
        box("Hopper ivory mouth lip",(0,rail*.405,1.79),
            (1.35,.095,.09),ivory,root,.016)
    for x in (-.52,-.12,.28):
        box("Ore chunk in receiving bin",(x,side*.10,1.38),
            (.22,.21,.10),blue,root,.02)


root=node("Facility")
# Ring-owned deck remains exposed in the central throat. These cheeks descend
# around both side walls, with two real portals along the orbital tangent.
for side in (-1,1):
    y=side*.72
    longitudinal_hull("Continuous refinery pressure cheek",[
        (-1.21,y,-.28,.27,.18),(-.89,y,-.28,.39,.23),
        (.89,y,-.28,.39,.23),(1.21,y,-.28,.27,.18),
    ],lower_steel,root)
    shoulder = longitudinal_hull("Rising ochre load shoulder",[
        (-1.17,y,.17,.28,.38),(-.88,y,.28,.37,.52),
        (.88,y,.28,.37,.52),(1.17,y,.17,.28,.38),
    ],ochre,root)
    # The upper bearing facet belongs to this same shoulder mesh. It links
    # the furnace's load path to the warm station/workshop/shipyard armor while
    # the lower ochre face still identifies the hot receiving node.
    shoulder.data.materials.append(ivory)
    for face in shoulder.data.polygons:
        if face.center.z > .54:
            face.material_index = 1
    for end in (-1,1):
        x=end*.99
        beam("Portal flared pressure upright",(x,side*.81,-.26),
             (x,side*.67,1.19),.27,.29,ivory,root)
        box("Portal deep foot",(x,side*.81,-.30),(.41,.45,.23),navy,root)
        box("Furnace portal lower pressure end cap",(end*1.245,side*.76,-.36),
            (.085,.46,.33),ochre,root,.035)
        box("Furnace portal end cap service inset",(end*1.294,side*.76,-.36),
            (.018,.23,.11),ivory,root,.006)
        beam("Furnace lower diagonal load heel",(end*.93,side*.99,-.15),
             (end*1.17,side*.88,-.51),.13,.12,ochre,root)
        box("Inner portal power strip",(x,side*.51,.55),
            (.075,.025,.55),cyan,root,.009)
    box("Long side armor inset",(0,side*1.064,.56),
        (1.55,.07,.35),ivory,root,.028)
    # Match the station's pressure-bay cadence while giving the furnace its
    # own hot industrial shell. The bays grow directly from the lower cheek.
    for x in (-.77,-.26,.26,.77):
        longitudinal_hull("Furnace lower stepped pressure bay",[
            (x-.21,side*1.075,-.34,.085,.15),
            (x-.15,side*1.125,-.35,.10,.18),
            (x+.15,side*1.125,-.35,.10,.18),
            (x+.21,side*1.075,-.34,.085,.15),
        ],ochre,root)
        box("Furnace lower bay pale service face",(x,side*1.23,-.36),
            (.25,.018,.12),ivory,root,.008)
        box("Furnace lower bay hot status",(x,side*1.242,-.26),
            (.13,.014,.025),ember,root,.004)
    for x in (-.51,0,.51):
        beam("Furnace lower pressure web",(x,side*1.16,-.16),
             (x,side*1.16,-.54),.075,.09,blue,root)
    for x in (-.53,0,.53):
        box("Side cooling louver",(x,side*1.106,.57),
            (.28,.021,.17),navy,root,.012)
        box("Hot louver slit",(x,side*1.119,.47),
            (.20,.013,.045),ember,root,.006)

for end in (-1,1):
    x=end*1.04
    beam("Ring passage armored crown",(x,-.76,1.22),
         (x,.76,1.22),.25,.24,ivory,root)
    box("Passage dark soffit",(x,0,1.08),(.09,1.0,.07),navy,root)
    for side in (-1,1):
        box("Portal amber warning",(x,side*.79,1.35),
            (.11,.12,.06),ember,root,.009)

# Two full hopper volumes are part of the cheeks, not detached containers.
for side in (-1,1):
    hopper("Left ore hopper" if side<0 else "Right ore hopper",side*.77,root)

# Furnace bridge sits on both load shoulders; the ore receiver remains visible
# through the opening between the hoppers and under its dark inner lip.
longitudinal_hull("Raised furnace pressure chamber",[
    (-.25,0,1.35,.48,.30),(.03,0,1.45,.57,.40),
    (.85,0,1.45,.57,.40),(1.04,0,1.32,.47,.28),
],blue,root)
crown=box("Furnace warm crown plate",(.47,0,1.85),
    (1.06,.90,.13),ivory,root,.04)
# The heat crown is a true open socket cut through its armor, with a recessed
# glowing inner well rather than a bright object placed on the roof.
bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.28,depth=.26,
                                    location=(.47,0,1.88))
heat_cut=bpy.context.object
bpy.context.view_layer.objects.active=crown
cut=crown.modifiers.new("Open top heat well","BOOLEAN")
cut.operation="DIFFERENCE"
cut.object=heat_cut
bpy.ops.object.modifier_apply(modifier=cut.name)
bpy.data.objects.remove(heat_cut,do_unlink=True)
cylinder("Top heat well dark floor",(.47,0,1.855),.255,.025,navy,root,24)
cylinder("Top heat well refractory lining",(.47,0,1.875),.225,.018,ochre,root,24)
cylinder("Top heat well ember core",(.47,0,1.889),.115,.012,ember,root,24)
for x in (-.04,.98):
    box("Crown heat armor rib",(x,0,1.93),
        (.11,.82,.06),ochre,root,.012)
box("Open dark receiving mouth",(-.30,0,1.18),
    (.08,.61,.60),navy,root,.025)
box("Hot furnace aperture",(-.352,0,1.19),
    (.024,.42,.40),ember,root,.01)
for side in (-1,1):
    beam("Receiver angled armor cheek",(-.48,side*.38,.39),
         (-.31,side*.37,1.46),.14,.15,ivory,root)
    box("Furnace side window",(.49,side*.585,1.45),
        (.71,.024,.25),ember,root,.015)
    box("Furnace blue side shroud",(.50,side*.625,1.19),
        (.91,.11,.17),navy,root,.025)

# The rail is a short receiving device inside the same open ring channel.
box("Recessed receiving tread",(-.67,0,.23),
    (1.08,.42,.09),blue,root,.02)
for side in (-1,1):
    box("Tread integrated load rail",(-.67,side*.27,.34),
        (1.20,.11,.21),ivory,root,.02)
    box("Tread power edge",(-.67,side*.332,.31),
        (.90,.014,.045),cyan,root,.006)
for x in (-1.08,-.75,-.42):
    box("Receiving tread cleat",(x,0,.30),
        (.10,.31,.035),ochre,root,.007)

for side in (-1,1):
    pivot=node("IntakeWheelLeft" if side<0 else "IntakeWheelRight",
               root,(-.56,side*.45,.78))
    cylinder("Intake drive rotor",(0,0,0),.22,.11,navy,pivot,20)
    cylinder("Rotor amber core",(0,0,.065),.11,.025,ember,pivot,20)
    for spoke in range(6):
        angle=spoke*math.tau/6
        box("Rotor radial tooth",(.17*math.cos(angle),.17*math.sin(angle),.06),
            (.07,.055,.035),ivory,pivot,.006).rotation_euler.z=angle

shutters=node("CoolingShutters",root,(.53,0,1.61))
for side in (-1,1):
    box("Moving cooling shutter",(0,side*.61,0),
        (.62,.12,.36),ivory,shutters,.03)
    for x in (-.20,0,.20):
        box("Shutter dark vent",(x,side*.68,0),
            (.085,.01,.22),navy,shutters,.008)
for x in (-.62,.67):
    cylinder("Furnace amber mast",(x,0,2.08),.045,.29,navy,root,12)
    cylinder("Furnace amber tip",(x,0,2.24),.075,.07,ember,root,12)

bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"refinery.blend"),compress=True)
bpy.ops.object.select_all(action="DESELECT")
for obj in (root,*root.children_recursive):
    obj.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format="GLB",
                          use_selection=True,export_animations=False,
                          export_cameras=False,export_lights=False,export_yup=True)
