"""Standalone authored orbital architecture concept. No existing facility mesh import."""
from pathlib import Path
from math import sin, cos, pi, tau
import random
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
GAME = HERE.parents[1]
OUT = HERE / "concept-v19.png"
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, metallic=.0, rough=.68, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


ARMOR = material("Warm faceted ivory armor", (.52,.47,.36), .05, .74)
ARMOR_FACE = material("Lit ivory armor facets", (.90,.78,.60), .04, .78)
ARMOR_SIDE = material("Recessed slate armor flanks", (.10,.17,.21), .09, .78)
ARMOR_MID = material("Midtone faceted pressure armor", (.40,.46,.45), .05, .78)
EDGE = material("Dark slate panel edge", (.085,.13,.16), .16, .75)
KEEL = material("Deep navy pressure keel", (.012,.035,.055), .10, .80)
MACHINE = material("Machine steel", (.043,.095,.115), .10, .72)
GLASS = material("Dark blue glass", (.025,.16,.22), .26, .34)
CYAN = material("Contained cyan energy", (.025,.65,.84), .08, .40, 1.8)
AMBER = material("Contained amber heat", (.68,.21,.025), .04, .55, .65)
GOLD = material("Warm work marking", (.47,.25,.075), .24, .56)


def parent(name, xyz=(0,0,0), angle=0):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = xyz
    o.rotation_euler.z = angle
    return o


def finish(obj, name, mat, root=None, bevel=0):
    obj.name = name
    obj.data.materials.append(mat)
    if root: obj.parent = root
    bpy.context.view_layer.objects.active = obj
    if bevel:
        mod = obj.modifiers.new("Authored chamfer", 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    normal = obj.modifiers.new("Weighted planar normals", 'WEIGHTED_NORMAL')
    bpy.ops.object.modifier_apply(modifier=normal.name)
    return obj


def box(name, pos, size, mat, root=None, bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(obj, name, mat, root, bevel)
    if mat == ARMOR and size[0] > .55 and size[1] > .24 and size[2] < .75:
        armor_facets(obj)
    obj.location = pos
    return obj


def beam(name, start, end, width, depth, mat, root=None):
    a, b = Vector(start), Vector(end)
    if mat == ARMOR:
        width *= .84
        depth *= .84
    obj = box(name, (a+b)*.5, (width,depth,(b-a).length), mat, root, min(width,depth)*.16)
    obj.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    return obj


def cyl(name, pos, radius, depth, mat, root=None, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth)
    obj = finish(bpy.context.object, name, mat, root, .018)
    obj.location = pos
    return obj


def cone(name, pos, bottom, top, depth, mat, root=None, vertices=12):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=bottom, radius2=top, depth=depth)
    obj = finish(bpy.context.object, name, mat, root, .018)
    obj.location = pos
    return obj


def torus(name, pos, major, minor, mat, root=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=48, minor_segments=8)
    obj = finish(bpy.context.object, name, mat, root)
    obj.location = pos
    return obj


def annular_band(name, inner, outer, zlo, zhi, mat, begin=0, end=tau, n=128):
    verts=[]
    for i in range(n+1):
        a=begin+(end-begin)*i/n
        for r,z in ((inner,zhi),(outer,zhi),(inner,zlo),(outer,zlo)):
            verts.append((r*cos(a),r*sin(a),z))
    faces=[]
    for i in range(n):
        j=4*i
        faces.extend(((j,j+4,j+5,j+1),(j+2,j+3,j+7,j+6),
                      (j,j+2,j+6,j+4),(j+1,j+5,j+7,j+3)))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    finish(obj,name,mat)
    return obj


def armor_prism(name, outline, bottom, top, mat, root=None):
    """One thick faceted load/pressure plate; outline is authored in node space."""
    count=len(outline)
    vertices=[(x,y,z) for z in (bottom,top) for x,y in outline]
    faces=[tuple(range(count-1,-1,-1)),tuple(range(count,2*count))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    obj=finish(obj,name,mat,root,.025)
    return armor_facets(obj) if mat == ARMOR else obj


def slope_shell(name, outline, top_heights, thickness, mat, root=None):
    """One continuous angled armor plate with an authored roof plane."""
    count=len(outline)
    assert count == len(top_heights)
    vertices=[(x,y,z-thickness) for (x,y),z in zip(outline,top_heights)]
    vertices += [(x,y,z) for (x,y),z in zip(outline,top_heights)]
    faces=[tuple(range(count-1,-1,-1)),tuple(range(count,2*count))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj=finish(obj,name,mat,root,.025)
    return armor_facets(obj) if mat == ARMOR else obj


def armor_facets(obj):
    """Color the broad upper armor plane separately from its load-bearing flanks."""
    obj.data.materials.append(ARMOR_FACE)
    obj.data.materials.append(ARMOR_SIDE)
    for polygon in obj.data.polygons:
        polygon.material_index = 1 if polygon.normal.z > .45 else 2
    return obj


# A single occupied upper crescent is split at the independent construction
# seam. Each facility owns its load-bearing portion of the shared section.
def owned_arc(root, name, begin, end, inner, outer, bottom, top, mat):
    bpy.context.view_layer.update()
    inverse = root.matrix_world.inverted()
    steps = max(16, int(abs(end-begin)*2))
    vertices = []
    for i in range(steps+1):
        angle_degrees = begin+(end-begin)*i/steps
        angle = angle_degrees*pi/180
        # Raise the middle of the occupied rear crescent above the sphere's
        # projection, while both independent arc ends meet the through-beam.
        rise = .68 * sin(pi * (angle_degrees-25) / 130) if 25 <= angle_degrees <= 155 else 0.0
        for radius,z in ((inner,top),(outer,top),(inner,bottom),(outer,bottom)):
            vertices.append(tuple(inverse @ Vector((radius*cos(angle),radius*sin(angle),z+rise))))
    faces=[]
    for i in range(steps):
        j=i*4
        faces.extend(((j,j+4,j+5,j+1),(j+2,j+3,j+7,j+6),
                      (j,j+2,j+6,j+4),(j+1,j+5,j+7,j+3)))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    return finish(obj,name,mat,root)


def root_at(name,degrees):
    angle=degrees*pi/180
    return parent(name,(4.33*cos(angle),4.33*sin(angle),.03),angle+pi/2)


# Slim full-orbit service beam; the occupied architecture rises from it.
annular_band("Through-orbit pressure line",4.22,4.43,-.24,.10,KEEL)
annular_band("Inboard service track",4.27,4.38,.10,.16,MACHINE)
for i in range(32):
    a=i*tau/32
    annular_band("Service beam joint",4.20,4.45,-.25,.17,EDGE,a-.011,a+.011,2)

station=root_at("01 / Annular command and habitation bearing",110)
refinery=root_at("02 / Faceted heat refinery fortress",48)
workshop=root_at("03 / Open manufacturing hall",-43)
shipyard=root_at("04 / Gated launch dock",-130)

# One 130-degree inhabited/industrial pressure crescent. The joint at 75
# degrees is a real construction seam, not a visible gap in the complete form.
for root,lo,hi in ((refinery,25,75),(station,75,155)):
    owned_arc(root,"Upper crescent deep pressure keel",lo,hi,4.18,5.28,-.33,.19,KEEL)
    owned_arc(root,"Upper crescent slate flank",lo,hi,4.16,5.30,.08,.42,ARMOR_SIDE)
    owned_arc(root,"Upper crescent recessed pressure gallery",lo+1,hi-1,4.33,4.72,.42,.57,EDGE)
    owned_arc(root,"Upper crescent faceted armor",lo+1,hi-1,4.73,5.16,.41,.56,ARMOR)
    owned_arc(root,"Continuous inhabited outer rail",lo+2,hi-2,5.15,5.26,.56,.67,ARMOR_FACE)
    owned_arc(root,"Inboard dark pressure gallery",lo+2,hi-2,4.23,4.34,.54,.66,EDGE)
    for a in range(lo+8,hi-4,15):
        owned_arc(root,"Crescent radial compression rib",a-1.2,a+1.2,4.13,5.36,-.35,.73,ARMOR_SIDE)
    for a in range(lo+5,hi-5,12):
        owned_arc(root,"Arc gallery aperture",a,a+7,4.34,4.41,.56,.68,GLASS)

# Command core grows from the long occupied crescent. Broad stepped roof and
# inhabited flanks read as one building with the upper arc at page size.
armor_prism("Command bridge dark pressure base",
            [(-1.06,-.58),(-.87,-1.05),(.87,-1.05),(1.06,-.58),(.74,.40),(-.74,.40)],
            .52,1.12,EDGE,station)
slope_shell("Command bridge faceted top",
            [(-.98,-.66),(-.76,-1.02),(.76,-1.02),(.98,-.66)],
            [1.42,1.37,1.37,1.42],.18,ARMOR,station)
box("Long bridge observation slit",(0,-1.045,1.16),(1.47,.055,.13),GLASS,station,.014)
for side in (-1,1):
    slope_shell("Habitat roof bay",
                [(side*.98,-.63),(side*1.56,-.67),(side*1.55,.14),(side*.91,.10)],
                [1.13,1.04,.86,1.08],.16,ARMOR,station)
    box("Habitat outboard armor cassette",(side*1.27,-.71,.78),(.48,.13,.26),ARMOR_MID,station,.02)
cyl("Closed command bearing integrated in arc",(0,-.34,.88),.47,.27,KEEL,station,10)
torus("Habitat upper pressure collar",(0,-.34,1.02),.45,.07,ARMOR,station)
torus("Inboard turquoise bearing",(0,-.34,1.11),.29,.035,CYAN,station)
cone("Eight-sided raised command citadel",(0,-.34,1.31),.31,.18,.36,KEEL,station,8)
torus("Continuous command glazing band",(0,-.34,1.37),.23,.025,CYAN,station)
cyl("Command dark glass crown",(0,-.34,1.52),.17,.07,GLASS,station,8)
cone("Short command beacon",(0,-.34,1.67),.09,.025,.22,ARMOR,station,8)
cyl("Amber signal cap",(0,-.34,1.80),.035,.05,AMBER,station,8)

# The heat process sits at the end of the same pressure structure. Its small
# furnace throat opens toward the outer edge; ore channels stay inside.
armor_prism("Heat throat integrated housing",
            [(-.78,-.60),(-.55,-1.00),(.56,-1.00),(.78,-.60),(.67,.30),(-.67,.30)],
            .45,.98,ARMOR,refinery)
slope_shell("Heat throat tapered shield",
            [(-.62,-.60),(-.48,-.92),(.48,-.92),(.62,-.60)],
            [1.12,1.03,1.03,1.12],.14,ARMOR,refinery)
cyl("Twelve-facet heat chamber",(0,-.47,.96),.35,.50,MACHINE,refinery,12)
cyl("Contained amber furnace core",(0,-.47,1.23),.25,.05,AMBER,refinery,12)
torus("Heavy furnace upper clamp",(0,-.47,1.25),.33,.065,EDGE,refinery)
for side in (-1,1):
    box("Contained vertical furnace vent",(side*.38,-.99,.79),(.10,.05,.31),AMBER,refinery,.012)
    beam("Furnace load buttress",(side*.73,-.42,.54),(side*.30,-.53,1.12),.19,.21,ARMOR,refinery)
    box("Ore intake dark face",(side*.59,-.80,.68),(.17,.32,.20),EDGE,refinery,.025)
box("Rear crucible return throat",(0,.46,.60),(.48,.47,.19),EDGE,refinery,.025)

# A compact forward manufacturing bay, with its actual work floor recessed
# within its owned arc, not a stand-alone block on a transit ring.
owned_arc(workshop,"Manufacturing occupied arc keel",-67,-12,3.89,4.83,-.25,.23,KEEL)
owned_arc(workshop,"Manufacturing occupied arc armor",-65,-14,3.94,4.79,.23,.45,ARMOR)
owned_arc(workshop,"Manufacturing inner dark work gallery",-61,-17,3.93,4.04,.45,.62,EDGE)
box("Recessed arc manufacturing work floor",(0,0,.48),(2.48,.69,.11),MACHINE,workshop,.025)
for side in (-1,1):
    armor_prism("Manufacturing pressure wall",
                [(-1.15,side*.42),(-.92,side*.68),(.92,side*.68),(1.15,side*.42)],
                .45,1.11,EDGE,workshop)
    slope_shell("Manufacturing sloping roof",
                [(-1.10,side*.38),(1.10,side*.38),(.88,side*.68),(-.88,side*.68)],
                [1.43,1.43,1.12,1.12],.13,ARMOR,workshop)
    box("Manufacturing lateral dark hatch",(0,side*.72,.86),(1.84,.06,.40),KEEL,workshop,.02)
    for x in (-.57,0,.57):
        box("Manufacturing segmented door",(x,side*.76,.86),(.46,.05,.31),ARMOR_SIDE,workshop,.018)
for x in (-.86,.86):
    beam("Manufacturing compression arch",(x,-.56,.55),(x,0,1.55),.16,.18,ARMOR,workshop)
box("Suspended gantry travel bridge",(.17,0,1.26),(.26,.80,.13),MACHINE,workshop,.02)
beam("Downward working tool",(.17,0,1.21),(.17,0,.77),.09,.10,EDGE,workshop)
box("Tool work glow",(.17,0,.78),(.16,.18,.04),CYAN,workshop,.01)
beam("Visible contained welding column",(.17,0,1.18),(.17,0,.80),.032,.04,CYAN,workshop)

# The dock's root belongs to its shorter arc. Its open outward branch creates
# a large readable void whose clear center contains the parked shuttle.
owned_arc(shipyard,"Dock occupied arc keel",-151,-109,3.91,4.80,-.25,.19,KEEL)
owned_arc(shipyard,"Dock occupied arc armor",-149,-111,3.94,4.76,.19,.42,ARMOR)
box("Dock arc transfer keel",(0,.05,.39),(2.15,.39,.19),EDGE,shipyard,.035)
for side in (-1,1):
    armor_prism("Dock branch load root",
                [(side*.25,-.27),(side*.78,-.50),(side*.92,.11),(side*.32,.47)],
                .34,.70,ARMOR,shipyard)
    beam("Dock outboard launch arm",(side*.59,-.25,.58),(side*.64,-2.10,.58),.24,.29,ARMOR,shipyard)
    beam("Launch arm dark lower girder",(side*.59,-.25,.34),(side*.64,-2.08,.34),.18,.19,EDGE,shipyard)
    box("Dock contained approach guide",(side*.42,-1.10,.69),(.035,1.70,.025),CYAN,shipyard,.004)
    beam("Dock compression branch into arc",(side*.62,-.13,.39),(side*.94,.37,.22),.18,.20,ARMOR,shipyard)
beam("Dock open portal cross member",(-.63,-.43,1.11),(.63,-.43,1.11),.17,.20,ARMOR,shipyard)
box("Docked shuttle fuselage",(0,-1.11,1.02),(.40,1.05,.20),EDGE,shipyard,.055)
armor_prism("Pointed shuttle nose beyond open clamp",[(0,-1.95),(.19,-1.51),(-.19,-1.51)],.95,1.10,EDGE,shipyard)
box("Docked blue canopy",(0,-1.29,1.14),(.25,.39,.065),GLASS,shipyard,.018)
for side in (-1,1):
    armor_prism("Shuttle swept armored wing",[(side*.12,-1.41),(side*.45,-1.03),(side*.45,-.69),(side*.15,-.82)],.97,1.08,EDGE,shipyard)
    box("Shuttle contained engine",(side*.15,-.46,1.04),(.10,.055,.09),CYAN,shipyard,.01)


# Painted planet texture is existing source art; the new architecture above
# remains a standalone concept and does not write any runtime assets.
bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=2.51)
globe=bpy.context.object
globe.name="Existing painted planet for proportion only"
for polygon in globe.data.polygons: polygon.use_smooth=True
planet_mat=material("Painted planet surface",(.8,.8,.8),0,1)
tex=planet_mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image=bpy.data.images.load(str(GAME/'assets/planets/painted-v4/surface.png'))
planet_mat.node_tree.links.new(tex.outputs['Color'],planet_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
globe.data.materials.append(planet_mat)
globe.rotation_euler.z=.45

random.seed(184)
for i in range(150):
    x=random.uniform(-10,10); y=random.uniform(-10,10)
    if abs(x)<5 and abs(y)<5: continue
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=random.uniform(.010,.028), location=(x,y,-9))
    bpy.context.object.data.materials.append(CYAN if i%11==0 else material("Star %d"%i,(.28,.48,.63),0,1,.8))

world=bpy.context.scene.world
if world is None:
    world=bpy.data.worlds.new("Deep-space illumination")
    bpy.context.scene.world=world
world.color=(.003,.012,.025)
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.003,.012,.027,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45

def light(name, xyz, power, color, size):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.color=color; data.shape='DISK'; data.size=size
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj)
    obj.location=xyz; obj.rotation_euler=(Vector((0,0,0))-obj.location).to_track_quat('-Z','Y').to_euler()

light("Wide warm ship lighting",(-4,-6,9),1250,(1.0,.84,.67),8)
light("Cold back rim",(5,5,7),1450,(.38,.72,1.0),7)
light("Controlled front fill",(0,-3,7),400,(.72,.86,1.0),8)

camera_data=bpy.data.cameras.new("Concept orthographic camera")
camera=bpy.data.objects.new("Concept orthographic camera",camera_data)
bpy.context.collection.objects.link(camera)
camera.location=(0,-10.0,11.5)
camera.rotation_euler=(Vector((0,0,.23))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'; camera_data.ortho_scale=17.4
bpy.context.scene.camera=camera

scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=24
bpy.context.view_layer.cycles.use_denoising=False
scene.render.resolution_x=1600
scene.render.resolution_y=900
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT)
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.camera.data.lens=50
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'concept-v19.blend'),compress=True)
bpy.ops.render.render(write_still=True)
