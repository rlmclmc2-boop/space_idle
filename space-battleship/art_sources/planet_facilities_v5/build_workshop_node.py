"""Build the workshop as an open, ring-local load node.

Blender Z is Godot Y. Blender X is the tangent of the orbital section and the
uncovered center is a real through bay, not a camera-facing painted opening.
The two named pivots remain the existing work-cycle ports.
"""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parents[1] / "assets/planets/facilities_v5/equipment.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, rgb, metallic=0.12, emission=0.0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*rgb, 1)
    result.use_nodes = True
    p = result.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*rgb, 1)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = 0.58
    if emission:
        p.inputs["Emission Color"].default_value = (*rgb, 1)
        p.inputs["Emission Strength"].default_value = emission
    return result


ivory = material("Warm ivory load armor", (0.82, 0.75, 0.62))
ivory_edge = material("Ivory cut edge", (0.55, 0.50, 0.42))
orange = material("Ochre structural cheeks", (0.68, 0.24, 0.065))
orange_lit = material("Warm inner bay", (0.92, 0.36, 0.07), emission=0.12)
navy = material("Deep teal pressure shell", (0.045, 0.13, 0.18))
blue = material("Blue steel machinery", (0.14, 0.27, 0.33))
cyan = material("Recessed service light", (0.05, 0.47, 0.55), emission=0.4)


def node(name, parent=None, at=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = at
    return obj


def finish(obj, name, mat, parent, bevel=0.035):
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    if bevel:
        modifier = obj.modifiers.new("Soft armor radius", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    normals = obj.modifiers.new("Weighted face normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=normals.name)
    return obj


def box(name, at, size, mat, parent, bevel=0.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, bevel)


def cylinder(name, at, radius, depth, mat, parent):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=depth, location=at)
    return finish(bpy.context.object, name, mat, parent, .014)


def beam(name, a, b, width, depth, mat, parent):
    v = Vector(b) - Vector(a)
    obj = box(name, (Vector(a) + Vector(b)) * .5, (width, depth, v.length), mat, parent, min(width, depth) * .16)
    obj.rotation_euler = v.to_track_quat('Z', 'Y').to_euler()
    return obj


def loft(name, slices, mat, parent):
    """An eight-sided closed pressure hull, with x-directed sections."""
    verts = []
    for x, cy, cz, hy, hz in slices:
        for u, v in ((-1,-.72),(-.72,-1),(.72,-1),(1,-.72),(1,.72),(.72,1),(-.72,1),(-1,.72)):
            verts.append((x, cy + u * hy, cz + v * hz))
    faces = [tuple(reversed(range(8)))]
    for s in range(len(slices)-1):
        for i in range(8):
            faces.append((s*8+i, s*8+(i+1)%8, (s+1)*8+(i+1)%8, (s+1)*8+i))
    faces.append(tuple((len(slices)-1)*8+i for i in range(8)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent, .04)


root = node("Facility")
# The deck and recessed center passage come from the owned orbital section.
# These two cheek shells clamp it from both radial sides at two tangent portals.
for side in (-1, 1):
    y = side * .87
    cheek = loft("Continuous orange load cheek", [
        (-1.08, y, .59, .26, .37), (-.88, y, .70, .32, .53),
        (.81, y, .70, .32, .53), (1.08, y, .59, .26, .37),
    ], orange, root)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, y, .74))
    window_cut = bpy.context.object
    window_cut.name = "Temporary open side service window"
    window_cut.dimensions = (1.27, .84, .48)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.objects.active = cheek
    cut = cheek.modifiers.new("Open working side", "BOOLEAN")
    cut.operation = "DIFFERENCE"
    cut.object = window_cut
    bpy.ops.object.modifier_apply(modifier=cut.name)
    bpy.data.objects.remove(window_cut, do_unlink=True)
    loft("Deep pressure foot wrapped around section", [
        (-1.12, side*.86, .06, .35, .18), (-.86, side*.86, .14, .41, .24),
        (.86, side*.86, .14, .41, .24), (1.12, side*.86, .06, .35, .18),
    ], navy, root)
    box("Inset inner bay wall", (0, side*.575, .70), (1.70, .065, .68), navy, root, .025)
    box("Warm working recess", (0, side*.532, .80), (1.42, .014, .31), orange_lit, root, .01)
    for x in (-.66, .66):
        box("Window jamb inner armor", (x, side*.655, .78), (.12, .07, .40), ivory_edge, root, .012)
        box("Window jamb amber signal", (x, side*.61, .79), (.06, .012, .14), orange_lit, root, .005)
    box("Upper bevel armor", (0, side*.99, 1.22), (1.76, .23, .14), ivory_edge, root, .03)
    box("Buried cyan power slit", (0, side*1.221, .55), (1.37, .016, .055), cyan, root, .006)
    # Four full-height end columns define two actual openings along the ring.
    for end in (-1, 1):
        x = end * .89
        beam("Portal tapered pressure upright", (x, side*.88, .22),
             (x, side*.70, 1.49), .24, .25, ivory, root)
        box("Dark foot socket", (x, side*.86, .16), (.38, .45, .22), navy, root, .035)
        box("Deep blue load shoe", (x, side*1.12, .18), (.43, .30, .35), blue, root, .04)
        box("Ivory load shoe face", (x, side*1.30, .21), (.29, .075, .25), ivory, root, .03)
        box("Portal inner amber inset", (end*.894, side*.55, 1.01), (.065, .065, .35), orange_lit, root, .016)
        cylinder("Amber corner mast", (x, side*.86, 1.65), .065, .20, orange_lit, root)

# Two armored head rails leave the moving tool and orbital work path open to
# view. Their end frames carry load across the section without a painted roof.
for side in (-1, 1):
    loft("Open bay orange head rail", [
        (-1.03, side*.76, 1.46, .24, .18),
        (-.78, side*.76, 1.57, .28, .21),
        (.78, side*.76, 1.57, .28, .21),
        (1.03, side*.76, 1.46, .24, .18),
    ], orange, root)
    box("Head rail ivory edge", (0, side*.78, 1.79), (1.52, .20, .08), ivory, root, .02)
    box("Inner head rail dark guide", (0, side*.43, 1.55), (1.26, .06, .06), navy, root, .012)
    for x in (-.47, 0, .47):
        box("Broad ochre crown tile", (x, side*.75, 1.82), (.36, .40, .11), orange, root, .025)
    for x in (-.58, .58):
        box("Recessed cyan gantry guide", (x, side*.449, 1.54), (.25, .025, .055), cyan, root, .008)
for end in (-1, 1):
    x = end * 1.02
    beam("End portal ivory shoulder left", (x, -.91, 1.23), (x, -.42, 1.63), .17, .17, ivory, root)
    beam("End portal ivory shoulder right", (x, .91, 1.23), (x, .42, 1.63), .17, .17, ivory, root)
    box("Portal crown edge", (x, 0, 1.65), (.16, .91, .14), orange, root, .025)
    box("Portal soffit", (x, 0, 1.52), (.09, .72, .07), navy, root, .014)

# Named animation ports from the original runtime. The carriage moves along
# the local tangent; the actual tool stays within the genuinely open center.
gantry = node("GantrySlide", root)
box("Moving dark overhead carriage", (0, 0, 1.40), (.62, .52, .28), blue, gantry, .05)
box("Carriage ivory upper face", (0, 0, 1.57), (.58, .48, .10), ivory, gantry, .025)
for side in (-1, 1):
    box("Carriage bearing", (0, side*.39, 1.39), (.26, .16, .18), navy, gantry, .025)
arm = node("ToolArmSweep", gantry, (0, 0, 1.27))
box("Tool moving mast", (0, 0, -.23), (.25, .28, .57), blue, arm, .035)
box("Tool ivory collar", (0, 0, -.54), (.43, .40, .22), ivory, arm, .04)
loft("Broad service tool", [(-.29, 0, -.75, .24, .14),
                            (0, 0, -.82, .31, .19),
                            (.29, 0, -.75, .24, .14)], blue, arm)
box("Active work jaw", (0, 0, -1.00), (.39, .35, .12), cyan, arm, .025)

bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "equipment.blend"), compress=True)
bpy.ops.object.select_all(action="DESELECT")
for obj in (root, *root.children_recursive):
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                          export_animations=False, export_cameras=False,
                          export_lights=False, export_yup=True)
