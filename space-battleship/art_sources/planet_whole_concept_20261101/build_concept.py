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


# The four large authored structures are the ring's bearing segments. Between
# them only a slim enclosed service beam crosses the open orbital span.
annular_band("Slim orbital through-pressure beam",4.22,4.44,-.23,.10,KEEL)
annular_band("Through-beam lower armor",4.24,4.42,-.31,-.23,EDGE)
annular_band("Narrow upper conduit",4.29,4.37,.10,.17,MACHINE)
for center in (pi/4,3*pi/4,5*pi/4,7*pi/4):
    annular_band("Node-contained energy guide",4.43,4.45,-.04,.01,CYAN,center-.15,center+.15,12)
for i in range(24):
    a0=i*tau/24+.008
    a1=(i+1)*tau/24-.008
    annular_band("Thin segmented dark armor cover",4.25,4.41,.13,.18,ARMOR_SIDE,a0,a1,4)
    if i % 3 == 0:
        a=(a0+a1)*.5
        annular_band("Through-beam pressure coupling",4.18,4.48,-.30,.22,EDGE,a-.012,a+.012,2)


def section(name, degrees):
    """Each facility is an occupied arc segment, not a building on a pad."""
    a=degrees*pi/180
    root=parent(name,(4.33*cos(a),4.33*sin(a),.05),a+pi/2)
    box("Through-node enclosed machine spine",(0,0,.06),(3.72,.19,.25),MACHINE,root,.035)
    for side in (-1,1):
        armor_prism("Swept node load wall",
                    [(-1.87,side*.15),(-1.48,side*.67),(-.84,side*.82),
                     (.84,side*.82),(1.48,side*.67),(1.87,side*.15)],
                    -.08,.38,ARMOR,root)
        box("Inset midtone pressure armor",(0,side*.85,.22),(1.52,.055,.25),ARMOR_MID,root,.025)
        box("Dark inner pressure channel",(0,side*.48,.27),(2.42,.09,.16),EDGE,root,.02)
        box("Node-contained service trace",(0,side*.59,.39),(2.22,.025,.024),CYAN,root,.006)
    for x in (-1.63,1.63):
        beam("Connector enters occupied arc",(x*.88,0,.20),(x*1.18,0,.12),.27,.29,EDGE,root)
    return root


station=section("01 / Annular command and habitation bearing",135)
for side in (-1,1):
    armor_prism("Swept inhabited arc wing",
                [(side*.35,-.40),(side*1.49,-.66),(side*1.80,-.16),(side*.52,.40)],
                .37,.89,ARMOR,station)
    slope_shell("Habitation wing inclined upper armor",
                [(side*.48,-.31),(side*1.42,-.53),(side*1.65,-.13),(side*.52,.27)],
                [1.08,.90,.82,1.02],.13,ARMOR,station)
    box("Long hab pressure window",(side*1.03,-.59,.72),(.70,.035,.10),GLASS,station,.012)
    box("Habitation broad outer pressure cassette",(side*1.02,-.69,.57),(.74,.10,.24),ARMOR_MID,station,.035)
    box("Outboard wing armor end cap",(side*1.66,-.13,.70),(.24,.34,.22),ARMOR,station,.035)
cyl("Closed command bearing integrated in arc",(0,0,.61),.62,.40,KEEL,station,12)
torus("Habitat upper pressure collar",(0,0,.84),.60,.12,ARMOR,station)
torus("Inboard turquoise bearing",(0,0,.92),.38,.042,CYAN,station)
cone("Eight-sided raised command citadel",(0,0,1.20),.43,.25,.61,KEEL,station,8)
torus("Continuous command glazing band",(0,0,1.27),.32,.035,CYAN,station)
cyl("Command dark glass crown",(0,0,1.52),.26,.12,GLASS,station,8)
cone("Short command beacon",(0,0,1.73),.13,.05,.28,ARMOR,station,8)
cyl("Amber signal cap",(0,0,1.90),.065,.07,AMBER,station,8)


refinery=section("02 / Faceted heat refinery fortress",45)
for side in (-1,1):
    armor_prism("Ore transfer arc chamber",
                [(side*.48,-.58),(side*1.42,-.62),(side*1.78,-.13),(side*.60,.46)],
                .36,1.02,ARMOR,refinery)
    slope_shell("Ore chamber sloped pressure roof",
                [(side*.61,-.48),(side*1.36,-.52),(side*1.56,-.12),(side*.65,.34)],
                [1.19,1.11,.89,1.04],.14,ARMOR,refinery)
    box("Ore intake dark face",(side*1.07,-.60,.72),(.53,.055,.23),EDGE,refinery,.025)
    box("Ore chamber outer armor cassette",(side*1.14,-.67,.80),(.72,.10,.28),ARMOR_MID,refinery,.035)
    box("Visible hot ore feed",(side*1.07,-.642,.73),(.39,.02,.055),AMBER,refinery,.008)
    beam("Ore duct enters central furnace",(side*1.08,-.35,.79),(side*.42,-.12,.88),.18,.20,MACHINE,refinery)
cyl("Twelve-facet heat chamber",(0,0,.93),.53,.94,MACHINE,refinery,12)
cyl("Contained amber furnace core",(0,0,1.43),.34,.055,AMBER,refinery,12)
torus("Heavy furnace upper clamp",(0,0,1.44),.46,.11,EDGE,refinery)
for side in (-1,1):
    box("Contained vertical furnace vent",(0,side*.56,.96),(.11,.055,.48),AMBER,refinery,.014)
for side in (-1,1):
    beam("Furnace load buttress",(side*.65,-.48,.40),(side*.34,0,1.39),.24,.25,ARMOR,refinery)
    box("Heat transfer socket",(side*.68,.48,.60),(.30,.42,.26),EDGE,refinery,.035)
box("Rear crucible return throat",(0,.67,.55),(.60,.57,.24),EDGE,refinery,.035)
box("Contained hot transfer path",(0,.67,.69),(.16,.48,.035),AMBER,refinery,.008)


workshop=section("03 / Open manufacturing hall",-45)
box("Recessed arc manufacturing work floor",(0,0,.37),(2.75,.83,.16),MACHINE,workshop,.035)
for side in (-1,1):
    armor_prism("Continuous production pressure wall",
                [(-1.56,side*.48),(-1.27,side*.78),(1.27,side*.78),(1.56,side*.48)],
                .43,1.27,EDGE,workshop)
    slope_shell("Production wall faceted canopy",
                [(-1.38,side*.43),(1.38,side*.43),(1.27,side*.76),(-1.27,side*.76)],
                [1.65,1.65,1.26,1.26],.15,ARMOR,workshop)
    box("Manufacturing lateral dark hatch",(0,side*.83,.92),(2.12,.07,.53),KEEL,workshop,.025)
    for x in (-.67,0,.67):
        box("Three manufacturing door leaves",(x,side*.88,.92),(.56,.07,.41),ARMOR_SIDE,workshop,.025)
    for x in (-.335,.335):
        box("Manufacturing door pressure pier",(x,side*.93,.94),(.09,.10,.53),ARMOR,workshop,.018)
    box("Manufacturing sill is arc wall",(0,side*.91,.66),(2.52,.12,.12),ARMOR,workshop,.025)
    box("Manufacturing upper pressure fascia",(0,side*.83,1.35),(2.30,.12,.15),ARMOR,workshop,.028)
for x in (-1.16,1.16):
    for side in (-1,1):
        beam("Hall load post into ring arc",(x,side*.60,.43),(x,side*.50,1.51),.20,.23,ARMOR,workshop)
        beam("Hall roof compression member",(x,side*.50,1.51),(x,0,1.80),.20,.23,ARMOR,workshop)
for lo,hi,rise in ((-1.32,-.42,0),(-.41,.42,.11),(.43,1.32,0)):
    slope_shell("Stepped fabrication roof vault",
                [(lo,.06),(hi,.06),(hi-.04,.69),(lo+.04,.69)],
                [1.57+rise,1.57+rise,1.83+rise,1.83+rise],.16,ARMOR,workshop)
box("Unfinished armored module",(0,0,.65),(1.22,.49,.25),EDGE,workshop,.055)
for x in (-.43,0,.43):
    box("Visible module rib in hall",(x,0,.81),(.08,.48,.06),ARMOR,workshop,.015)
box("Suspended gantry travel bridge",(.19,0,1.38),(.30,1.02,.17),MACHINE,workshop,.025)
beam("Downward working tool",(.19,0,1.34),(.19,0,.91),.12,.14,EDGE,workshop)
box("Tool work glow",(.19,0,.92),(.20,.24,.055),CYAN,workshop,.01)
beam("Visible contained welding column",(.19,0,1.38),(.19,0,.96),.043,.05,CYAN,workshop)


shipyard=section("04 / Gated launch dock",-135)
box("Dock arc transfer keel",(0,.08,.36),(2.92,.46,.26),EDGE,shipyard,.045)
for side in (-1,1):
    armor_prism("Dock root forms occupied ring section",
                [(side*.44,-.24),(side*1.34,-.53),(side*1.67,.12),(side*.55,.58)],
                .25,.83,ARMOR,shipyard)
    beam("Dock outboard launch arm",(side*.74,-.22,.70),(side*.76,-2.12,.70),.32,.38,ARMOR,shipyard)
    beam("Launch arm dark lower girder",(side*.74,-.22,.42),(side*.76,-2.02,.42),.22,.27,EDGE,shipyard)
    box("Dock contained approach guide",(side*.49,-.91,.78),(.04,1.80,.035),CYAN,shipyard,.004)
    beam("Dock compression branch into arc",(side*.68,-.08,.39),(side*1.43,.41,.18),.23,.25,ARMOR,shipyard)
    beam("Dock open portal pillar",(side*.75,-.43,.68),(side*.75,-.43,1.43),.22,.25,ARMOR,shipyard)
beam("Dock open portal cross member",(-.76,-.43,1.44),(.76,-.43,1.44),.21,.25,ARMOR,shipyard)
box("Docked shuttle fuselage",(0,-1.04,1.26),(.48,1.17,.25),EDGE,shipyard,.07)
armor_prism("Pointed shuttle nose beyond open clamp",[(0,-2.02),(.23,-1.56),(-.23,-1.56)],1.17,1.35,EDGE,shipyard)
box("Docked blue canopy",(0,-1.28,1.42),(.29,.47,.08),GLASS,shipyard,.025)
for side in (-1,1):
    armor_prism("Shuttle swept armored wing",[(side*.15,-1.42),(side*.53,-1.08),(side*.53,-.62),(side*.17,-.79)],1.22,1.34,EDGE,shipyard)
    box("Shuttle contained engine",(side*.17,-.43,1.31),(.12,.07,.11),CYAN,shipyard,.012)


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
