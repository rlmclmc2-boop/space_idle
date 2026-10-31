"""Author the station as a tangent-local through node on its owned ring section.

X is the orbital passage, Y crosses the deck, and Z points away from the
planet. The two pressure cheeks grow down around the real section; the crown
and rotating observatory are carried by them, leaving both passage mouths open.
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parents[1] / "assets/planets/facilities_v5/auto_explore.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgb, metallic=0.12, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = 0.55
    if emission:
        shader.inputs["Emission Color"].default_value = (*rgb, 1)
        shader.inputs["Emission Strength"].default_value = emission
    return mat


ivory = material("Station warm load armor", (.66, .61, .50))
edge = material("Station bevel shadow", (.48, .48, .44))
navy = material("Station deep pressure hull", (.035, .105, .15))
blue = material("Station blue structural steel", (.08, .22, .29))
cyan = material("Station inset cyan power", (.04, .56, .64), emission=.32)
amber = material("Station amber beacons", (.91, .42, .11), emission=.42)
ochre = material("Station warm equipment plating", (.46, .27, .13))


def node(name, parent=None, at=(0, 0, 0)):
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
        mod = obj.modifiers.new("Machined edge", "BEVEL")
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


def cylinder(name, at, radius, depth, mat, parent, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=at)
    return finish(bpy.context.object, name, mat, parent)


def beam(name, a, b, width, depth, mat, parent):
    delta = Vector(b) - Vector(a)
    obj = box(name, (Vector(a) + Vector(b)) * .5,
              (width, depth, delta.length), mat, parent, min(width, depth) * .16)
    obj.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    return obj


def loft(name, sections, mat, parent):
    verts = []
    for x, y, z, half_width, half_height in sections:
        for u, v in ((-1,-.70),(-.70,-1),(.70,-1),(1,-.70),
                     (1,.70),(.70,1),(-.70,1),(-1,.70)):
            verts.append((x, y + u * half_width, z + v * half_height))
    faces = [tuple(reversed(range(8)))]
    for section in range(len(sections)-1):
        for side in range(8):
            faces.append((section*8+side, section*8+(side+1)%8,
                          (section+1)*8+(side+1)%8, (section+1)*8+side))
    faces.append(tuple((len(sections)-1)*8+side for side in range(8)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent, .035)


root = node("Facility")
# The real ring deck runs in the open central channel. Pressure shoes overlap
# its outer walls and descend below its deck, so they do not read as a pad.
for side in (-1, 1):
    y = side * .73
    loft("Continuous deep load cheek", [
        (-1.22,y,-.31,.27,.24), (-.93,y,-.31,.37,.31),
        (.93,y,-.31,.37,.31), (1.22,y,-.31,.27,.24),
    ], navy, root)
    loft("Tapered station pressure wall", [
        (-1.16,y,.17,.26,.42), (-.82,y,.25,.34,.57),
        (.82,y,.25,.34,.57), (1.16,y,.17,.26,.42),
    ], blue, root)
    for end in (-1, 1):
        x = end * .96
        beam("Portal ivory load upright", (x,side*.80,-.24),
             (x,side*.66,1.22), .27, .27, ivory, root)
        box("Foot armor socket", (x,side*.83,-.27), (.39,.44,.25), ivory, root)
        box("Foot pressure face", (x,side*1.057,-.25), (.25,.022,.13), ochre, root, .01)
        box("Inset portal guide", (x,side*.55,.57), (.08,.045,.61), cyan, root, .009)
        box("Portal cut edge", (x,side*.53,1.25), (.25,.22,.08), edge, root)
    loft("Upper ivory side armor", [
        (-.98,y,.92,.35,.17),(-.68,y,1.04,.38,.18),
        (.68,y,1.04,.38,.18),(.98,y,.92,.35,.17),
    ], ivory, root)
    box("Inset longitudinal window", (0,side*.495,.55), (1.48,.035,.30), navy, root, .01)
    for x in (-.58,-.19,.19,.58):
        box("Observation glazing", (x,side*.471,.55), (.29,.016,.18), cyan, root, .007)
        box("Window mullion", (x+.18,side*.46,.55), (.035,.025,.31), edge, root, .004)
    box("Buried continuous power slit", (0,side*1.115,-.09), (1.59,.016,.055), cyan, root, .006)
    for x in (-.65,-.22,.22,.65):
        box("Warm cheek armor tile", (x,side*1.005,.74), (.31,.06,.24),
            ivory if abs(x) < .4 else ochre,root,.016)
        box("Cheek recessed service slot", (x,side*1.038,.36), (.21,.022,.06),navy,root,.007)

for end in (-1, 1):
    x = end * 1.03
    beam("Cross portal armored lintel", (x,-.76,1.16),
         (x,.76,1.16), .24,.26, ivory, root)
    box("Open passage soffit", (x,0,1.03), (.10,.91,.06), navy, root, .01)
    for side in (-1, 1):
        box("Corner amber status", (x,side*.75,1.31), (.11,.11,.06), amber, root, .014)

# This elevated observation block is carried by both longitudinal walls.
# It has an actual underside above the channel and a small central dock.
loft("Station elevated command hull", [
    (-.70,0,1.34,.74,.20),(-.45,0,1.54,.88,.27),
    (.45,0,1.54,.88,.27),(.70,0,1.34,.74,.20),
], navy, root)
box("Command deck crown armor", (0,0,1.78), (.92,1.15,.16), ivory, root, .055)
for x in (-.36,0,.36):
    box("Crown service rib", (x,0,1.875), (.11,.81,.035),ochre,root,.008)
for side in (-1, 1):
    box("Command bridge glazing", (0,side*.82,1.51), (.83,.03,.22), cyan, root, .012)
    for x in (-.29,0,.29):
        box("Bridge frame", (x,side*.85,1.51), (.035,.045,.30), edge, root, .005)

spin = node("HabitatRingSpin", root, (0,0,1.82))
bpy.ops.mesh.primitive_torus_add(major_radius=.82, minor_radius=.09,
                                major_segments=48, minor_segments=10,
                                location=(0,0,0))
finish(bpy.context.object, "Turning observation annulus", ivory, spin, 0)
for i in range(8):
    angle = i*math.tau/8
    box("Rotating navy sector", (.82*math.cos(angle),.82*math.sin(angle),0),
        (.16,.14,.08), navy, spin, .012).rotation_euler.z = angle
cylinder("Central docking rim", (0,0,1.89), .34,.11,ivory,root)
cylinder("Dark open docking well", (0,0,1.95), .24,.025,navy,root)
cylinder("Cyan docking beacon", (0,0,1.97), .095,.028,cyan,root)

for side in (-1,1):
    hinge = node("SolarHingeLeft" if side < 0 else "SolarHingeRight",
                 root, (0,side*1.01,1.07))
    box("Power fin load hinge", (0,side*.17,0), (.19,.38,.14), navy, hinge)
    box("Short blue solar vane", (0,side*.42,.02), (.63,.37,.07),blue,hinge)
    box("Ivory solar vane border", (0,side*.42,.065), (.67,.40,.025),ivory,hinge,.007)
for x in (-.54,.54):
    cylinder("Attitude mast", (x,0,2.11), .035,.36,navy,root,12)
    cylinder("Amber mast lamp", (x,0,2.30), .071,.075,amber,root,12)

bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "auto_explore.blend"), compress=True)
bpy.ops.object.select_all(action="DESELECT")
for obj in (root, *root.children_recursive):
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB",
                          use_selection=True, export_animations=False,
                          export_cameras=False, export_lights=False, export_yup=True)
