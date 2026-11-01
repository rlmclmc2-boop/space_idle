"""Standalone authored orbital architecture concept. No existing facility mesh import."""
from pathlib import Path
from math import sin, cos, pi, tau
import random
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
GAME = HERE.parents[1]
OUT = HERE / "concept-complete.png"
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


ARMOR = material("Warm faceted ivory armor", (.35,.32,.26), .05, .74)
EDGE = material("Dark slate panel edge", (.18,.24,.27), .28, .68)
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
    obj.location = pos
    return obj


def beam(name, start, end, width, depth, mat, root=None):
    a, b = Vector(start), Vector(end)
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
    return finish(obj,name,mat,root,.025)


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
    return finish(obj,name,mat,root,.025)


# The ring is one dark pressure system with two armored bank beams, a work
# trough and four built nodes. Short plate gaps expose the same keel below.
annular_band("Continuous central pressure keel",3.80,4.89,-.43,.12,KEEL)
annular_band("Deep lower pressure hull",3.92,4.75,-.77,-.43,EDGE)
annular_band("Outer beveled side armor course",4.81,4.96,-.56,-.05,ARMOR)
annular_band("Inner beveled side armor course",3.71,3.86,-.56,-.05,ARMOR)
annular_band("Recessed machine conduit",4.13,4.56,.13,.15,MACHINE)
annular_band("Contained upper cyan service line",4.10,4.13,.16,.18,CYAN)
annular_band("Contained lower cyan service line",4.85,4.88,-.29,-.25,CYAN)
for i in range(36):
    a0=i*tau/36+.009
    a1=(i+1)*tau/36-.009
    annular_band("Segmented inner load armor",3.84,3.99,.13,.26,ARMOR,a0,a1,5)
    annular_band("Segmented outer load armor",4.71,4.87,.13,.26,ARMOR,a0,a1,5)
    if i % 3 == 0:
        a=(a0+a1)*.5
        annular_band("Deep pressure joint clamp",3.72,4.96,-.63,.31,EDGE,a-.016,a+.016,2)
for i in range(12):
    a=(i+.5)*tau/12
    annular_band("Radial charcoal bulkhead",3.83,4.88,.19,.26,EDGE,a-.008,a+.008,2)


def socket(name, deg):
    a=deg*pi/180
    o=parent(name,(4.33*cos(a),4.33*sin(a),.05),a+pi/2)
    armor_prism("Integrated tapered pressure socket",
                [(-1.55,-.45),(-1.08,-.91),(1.08,-.91),(1.55,-.45),
                 (1.55,.45),(1.08,.91),(-1.08,.91),(-1.55,.45)],-.27,.21,KEEL,o)
    box("Continuous exposed central service spine",(0,0,.22),(2.86,.43,.075),MACHINE,o,.03)
    box("Common through-running enclosed service trace",(0,0,.27),(2.75,.025,.016),CYAN,o,.005)
    for side in (-1,1):
        armor_prism("Common flared primary load bank",
                    [(-1.47,side*.38),(-1.02,side*.90),(1.02,side*.90),(1.47,side*.38)],
                    .20,.46,ARMOR,o)
        box("Continuous machine side course",(0,side*.83,-.07),(2.33,.12,.23),EDGE,o,.03)
        box("Contained socket service way",(0,side*.899,.05),(2.1,.025,.034),CYAN,o,.006)
    for x in (-1.00,1.00):
        armor_prism("Visible heavy socket-to-ring shear key",
                    [(x*.90,-.49),(x*1.47,-.42),(x*1.61,.42),(x*.90,.49)],.02,.33,EDGE,o)
        for side in (-1,1):
            armor_prism("Four flared armored spine transitions",
                        [(x*.91,side*.43),(x*1.48,side*.43),
                         (x*1.63,side*.84),(x*.69,side*.86)],.13,.42,ARMOR,o)
    return o


station=socket("01 / Annular command and habitation bearing",135)
cyl("Closed annular lower bearing",(0,0,.57),.90,.35,KEEL,station,16)
torus("Habitat upper pressure collar",(0,0,.86),.78,.16,ARMOR,station)
torus("Inboard turquoise bearing",(0,0,.92),.46,.042,CYAN,station)
cyl("Command dark glass crown",(0,0,.94),.36,.14,GLASS,station,16)
for i in range(6):
    a=i*tau/6
    x,y=.80*cos(a),.80*sin(a)
    block=box("Six deep armored habitation sectors",(x,y,.65),(.35,.31,.35),ARMOR,station,.055)
    block.rotation_euler.z=a
for i in range(12):
    a=i*tau/12
    x,y=.88*cos(a),.88*sin(a)
    plate=box("Radial pressure bulkhead over habitat ring",(x,y,.91),(.11,.32,.12),EDGE,station,.01)
    plate.rotation_euler.z=a
for side in (-1,1):
    armor_prism("Swept habitat wing",
                [(side*.63,-.25),(side*1.22,-.38),(side*1.34,.05),(side*.68,.35)],.39,.76,ARMOR,station)
    box("Blue glazed observation slit",(side*1.05,-.28,.73),(.36,.025,.055),GLASS,station,.01)
cone("Short command beacon",(0,0,1.15),.16,.05,.34,ARMOR,station,8)
cyl("Amber signal cap",(0,0,1.34),.07,.07,AMBER,station,8)


refinery=socket("02 / Faceted heat refinery fortress",45)
box("One furnace lower pressure foundation",(0,0,.54),(1.65,1.40,.46),KEEL,refinery,.18)
cyl("Twelve-facet heat chamber",(0,0,1.03),.59,.76,MACHINE,refinery,12)
cyl("Contained amber furnace core",(0,0,1.44),.36,.05,AMBER,refinery,12)
for i in range(8):
    a=i*tau/8
    box("Heat escaping through armored slit",(.59*cos(a),.59*sin(a),1.00),(.028,.09,.37),AMBER,refinery,.004).rotation_euler.z=a
torus("Heavy furnace upper clamp",(0,0,1.44),.49,.10,EDGE,refinery)
for side in (-1,1):
    armor_prism("Tall angled chamber armor",
                [(side*.24,-.53),(side*.74,-.51),(side*.87,.36),(side*.34,.48)],.74,1.26,ARMOR,refinery)
    armor_prism("Furnace lower buttress shell",
                [(side*.70,-.80),(side*1.04,-.67),(side*.86,.70),(side*.54,.73)],.45,.91,EDGE,refinery)
for side in (-1,1):
    beam("Twin chamfered furnace load legs",(side*.87,-.62,.37),(side*.49,0,1.48),.28,.31,ARMOR,refinery)
    beam("Twin return load legs",(side*.87,.62,.37),(side*.49,0,1.48),.28,.31,ARMOR,refinery)
    cone("Closed faceted ore tower",(side*.56,-.38,1.44),.29,.22,.70,ARMOR,refinery,4)
    box("Ore pressure mouth",(side*.56,-.38,1.81),(.42,.43,.07),EDGE,refinery,.025)
    box("Visible hot charge",(side*.56,-.38,1.86),(.28,.29,.022),GOLD,refinery,.006)
    beam("Ore feed duct into heat chamber",(side*.56,-.38,1.18),(side*.21,0,1.15),.21,.24,MACHINE,refinery)
    box("Outer heat louver bank",(side*.83,.15,.85),(.24,.68,.34),EDGE,refinery,.04)
for x in (-.46,.46):
    box("Front furnace clamp foot",(x,-.77,.55),(.38,.27,.43),ARMOR,refinery,.06)
armor_prism("Open crucible trough returning into ring service bay",
            [(-.31,.35),(.31,.35),(.45,.90),(-.45,.90)],.57,.74,EDGE,refinery)
box("Dark narrow molten transfer well",(0,.67,.75),(.35,.65,.035),KEEL,refinery,.015)
box("Contained hot metal path",(0,.66,.78),(.17,.55,.021),AMBER,refinery,.008)
for x in (-.43,.43):
    beam("Crucible shield shoulder",(x,.32,.67),(x,.87,.88),.13,.17,ARMOR,refinery)


workshop=socket("03 / Open manufacturing hall",-45)
box("Open recessed construction floor",(0,0,.48),(2.18,1.18,.22),MACHINE,workshop,.06)
for side in (-1,1):
    box("Lengthwise heavy manufacturing sill",(0,side*.68,.65),(2.66,.33,.39),ARMOR,workshop,.11)
    box("Traveling crane track",(0,side*.46,.88),(2.1,.10,.09),EDGE,workshop,.02)
    armor_prism("Twin long armored production hall sidewalls",
                [(-1.18,side*.55),(1.18,side*.55),(1.32,side*.85),(-1.32,side*.85)],
                .67,1.32,EDGE,workshop)
    slope_shell("Pitched armored production canopy around open work slot",
                [(-1.16,side*.43),(1.16,side*.43),(1.21,side*.79),(-1.21,side*.79)],
                [1.72,1.72,1.31,1.31],.17,ARMOR,workshop)
    box("Long upper dark daylight opening",(0,side*.47,1.73),(1.74,.045,.02),GLASS,workshop,.004)
for x in (-.97,.97):
    for side in (-1,1):
        beam("Hall inclined primary post",(x,side*.72,.58),(x,side*.61,1.54),.25,.27,ARMOR,workshop)
        beam("Hall pitched pressure roof",(x,side*.61,1.54),(x,0,1.86),.25,.28,ARMOR,workshop)
        beam("Hall diagonal dark gusset",(x,side*.71,.71),(x,side*.28,1.57),.15,.17,EDGE,workshop)
    armor_prism("Sloped armored end roof over production bay",
                [(x-.25,-.68),(x+.25,-.68),(x+.25,.68),(x-.25,.68)],1.55,1.70,ARMOR,workshop)
beam("Hall lengthwise raised ridge",(-.97,0,1.86),(.97,0,1.86),.20,.22,EDGE,workshop)
for side in (-1,1):
    armor_prism("Upper lengthwise pressure clerestory",
                [(-.73,side*.62),(.72,side*.62),(.60,side*.37),(-.60,side*.37)],
                1.37,1.58,ARMOR,workshop)
box("Unfinished armored module",(0,0,.78),(1.15,.58,.26),EDGE,workshop,.08)
for x in (-.41,0,.41):
    box("Three visible structural bays of module",(x,0,.94),(.09,.51,.06),ARMOR,workshop,.02)
for side in (-1,1):
    armor_prism("Open manufacture panel suspended over workpiece",
                [(-.44,side*.12),(.40,side*.12),(.51,side*.29),(-.38,side*.29)],
                .95,1.02,ARMOR,workshop)
box("Contained active weld seam",(0,0,.98),(.82,.045,.02),AMBER,workshop,.004)
box("Suspended gantry travel bridge",(.19,0,1.45),(.30,1.17,.19),MACHINE,workshop,.035)
beam("Downward working tool",(.19,0,1.39),(.19,0,1.02),.13,.15,EDGE,workshop)
box("Tool work glow",(.19,0,1.015),(.23,.29,.06),CYAN,workshop,.012)
beam("Visible contained welding column",(.19,0,1.42),(.19,0,1.06),.045,.05,CYAN,workshop)


shipyard=socket("04 / Gated launch dock",-135)
box("Dark launch trench",(0,-.84,.42),(1.56,2.91,.25),KEEL,shipyard,.10)
for side in (-1,1):
    armor_prism("Deep dock root hangar mass",
                [(side*.57,.82),(side*1.08,.68),(side*1.14,-.12),(side*.60,-.18)],.45,1.10,ARMOR,shipyard)
    armor_prism("Tapered pressure hangar shell framing launch void",
                [(side*.61,.55),(side*1.10,.49),(side*.98,-1.85),(side*.63,-2.17)],
                .55,1.20,EDGE,shipyard)
    slope_shell("Deep sloped armored dock shoulder around open launch void",
                [(side*.74,.43),(side*1.16,.43),(side*1.01,-1.74),(side*.70,-1.96)],
                [1.43,1.12,1.12,1.43],.19,ARMOR,shipyard)
box("Inner dock transfer jaw",(0,.34,.67),(1.76,.48,.53),ARMOR,shipyard,.095)
box("Blue dock throat",(0,.075,.78),(.78,.06,.16),CYAN,shipyard,.025)
for side in (-1,1):
    beam("Outboard cantilever pressure fork",(side*.68,.56,.72),(side*.74,-2.18,.72),.38,.45,ARMOR,shipyard)
    beam("Under-fork dark return girder",(side*.68,.56,.42),(side*.74,-2.08,.42),.23,.32,EDGE,shipyard)
    beam("Fork root triangle into ring",(side*.66,.70,.46),(side*.95,1.16,.20),.28,.28,ARMOR,shipyard)
    box("Contained launch guide",(side*.47,-.94,.83),(.045,2.21,.035),CYAN,shipyard,.005)
for y in (-1.82,-.38):
    for side in (-1,1):
        beam("Heavy dock open gate pillar",(side*.73,y,.69),(side*.73,y,1.53),.23,.28,ARMOR,shipyard)
        beam("Dock gate diagonal compression brace",(side*.73,y,.84),(side*.35,y,1.54),.14,.17,EDGE,shipyard)
    beam("Heavy dock overhead load arch",(-.75,y,1.55),(.75,y,1.55),.23,.30,ARMOR,shipyard)
box("Docked shuttle fuselage",(0,-1.09,1.36),(.53,1.34,.27),ARMOR,shipyard,.11)
box("Docked blue canopy",(0,-1.33,1.53),(.32,.53,.09),GLASS,shipyard,.04)
for side in (-1,1):
    armor_prism("Shuttle swept armored wing",
                [(side*.16,-1.50),(side*.57,-1.14),(side*.59,-.63),(side*.18,-.80)],
                1.33,1.42,ARMOR,shipyard)
    box("Shuttle contained engine",(side*.18,-.43,1.41),(.13,.08,.12),CYAN,shipyard,.018)


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
camera_data.type='ORTHO'; camera_data.ortho_scale=15.6
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
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'concept.blend'),compress=True)
bpy.ops.render.render(write_still=True)
