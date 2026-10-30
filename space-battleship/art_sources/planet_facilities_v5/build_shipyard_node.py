"""Editable R5 shipyard load node, authored in local orbital-section space.

Blender uses Z up. The exported glTF maps that to Godot Y up. The main root,
two open berths, docked craft, and named work pivots form one rotating object.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parents[1] / "assets/planets/facilities_v5"
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, emission=0.0, metal=0.12):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = 0.58
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return m


ivory = material("Ivory armor", (0.78, 0.70, 0.55))
edge = material("Warm armor bevel", (0.56, 0.52, 0.43))
navy = material("Deep teal load shell", (0.085, 0.17, 0.22))
blue = material("Blue service housing", (0.16, 0.29, 0.35))
mid = material("Mid-tone teal joint", (0.25, 0.39, 0.42))
cyan = material("Recessed cyan channel", (0.07, 0.48, 0.55), emission=0.42)
amber = material("Small warm status lens", (0.85, 0.29, 0.045), emission=0.36)
orange = material("Shipyard structural ochre", (0.62, 0.24, 0.075))
glass = material("Shuttle cockpit glass", (0.035, 0.20, 0.31), metal=0.23)


def node(name, parent=None, at=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = at
    return obj


def finish(obj, name, mat, parent, bevel=0.025):
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    if bevel:
        mod = obj.modifiers.new("Armor edge radius", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    normal = obj.modifiers.new("Weighted armor normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=normal.name)
    return obj


def box(name, at, size, mat, parent, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, bevel)


def cylinder(name, at, radius, length, mat, parent, rot=(0, 0, 0), vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length,
                                        location=at, rotation=rot)
    return finish(bpy.context.object, name, mat, parent, 0.018)


def torus(name, at, major, minor, mat, parent, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=32, minor_segments=10,
                                    location=at, rotation=rot)
    return finish(bpy.context.object, name, mat, parent, 0)


def strut(name, start, end, width, mat, parent):
    direction = Vector(end) - Vector(start)
    midpoint = (Vector(start) + Vector(end)) * .5
    obj = box(name, midpoint, (width, width, direction.length), mat, parent, width*.27)
    obj.rotation_euler = direction.to_track_quat('Z','Y').to_euler()
    return obj


def hull(name, rings, mat, parent):
    """Closed eight-sided armor loft; rings are (height, half-x, half-y, x-offset)."""
    vertices = []
    for z, hx, hy, cx in rings:
        for u, v in ((-.72,-1),(.72,-1),(1,-.72),(1,.72),(.72,1),(-.72,1),(-1,.72),(-1,-.72)):
            vertices.append((cx + u*hx, v*hy, z))
    faces = [tuple(reversed(range(8)))]
    for k in range(len(rings)-1):
        for n in range(8):
            faces.append((k*8+n,k*8+(n+1)%8,(k+1)*8+(n+1)%8,(k+1)*8+n))
    faces.append(tuple((len(rings)-1)*8+n for n in range(8)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent, 0.035)


root = node("Facility")
# Owned ring deck passes inside the root. The spine load path remains visible
# through the two short ends, while the central bay is deliberately open.
hull("Ring-coupled tapered keel", [(-.48,.48,.89,.22),(-.36,.61,.98,.22),(.12,.56,.94,.22),(.25,.40,.81,.22)], navy, root)
box("Continuous recessed transfer way", (.23,0,.20), (.28,1.95,.07), blue, root, .025)
box("Recessed power line", (.23,0,.25), (.055,1.83,.025), cyan, root, .006)
for side in (-1,1):
    y = side*.89
    box("Coupling jaw under deck", (.22,y,-.14), (.66,.17,.45), blue, root, .045)
    box("Coupling jaw ivory cap", (.22,side*.99,.12), (.68,.14,.11), ivory, root, .025)
    box("Small coupling beacon", (.19,side*1.06,.17), (.08,.035,.08), cyan, root, .008)

# A faceted, stepped pressure hull gives the spine a pointed crown in both
# face and quarter views. Dark load core dominates; armor is split into
# narrow cheeks instead of hiding it behind a broad rectangular white wall.
core = hull("Tapering shipyard load core", [(.06,.63,.79,.48),(.32,.64,.82,.47),(.91,.50,.70,.48),(1.34,.34,.48,.51),(1.60,.13,.20,.54)], navy, root)
shoulder = hull("Inset blue machinery shoulder", [(.24,.48,.67,.44),(.47,.55,.72,.43),(.98,.37,.55,.46),(1.24,.20,.32,.49)], blue, root)
# Cut a real transverse service aperture through both nested shells. It leaves
# paired load legs and a pointed crown; the previous solid back read as a tomb.
bpy.ops.mesh.primitive_cube_add(size=1, location=(.47, 0, .72))
aperture = bpy.context.object
aperture.name = "Temporary service aperture cutter"
aperture.dimensions = (2.8, .72, .62)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
for target in (core, shoulder):
    bpy.context.view_layer.objects.active = target
    mod = target.modifiers.new("Open working throat", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = aperture
    bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.data.objects.remove(aperture, do_unlink=True)
bpy.ops.mesh.primitive_cube_add(size=1, location=(.47, 0, .72))
cross_aperture = bpy.context.object
cross_aperture.name = "Temporary cross aperture cutter"
cross_aperture.dimensions = (.68, 2.8, .62)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
for target in (core, shoulder):
    bpy.context.view_layer.objects.active = target
    mod = target.modifiers.new("Open lateral service bay", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cross_aperture
    bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.data.objects.remove(cross_aperture, do_unlink=True)
# Both exposed end faces carry armor arches. This reads as a pressure frame
# from either side of the orbit instead of a featureless black back wall.
for x_side in (-1,1):
    x0 = .48 + x_side*.69
    x1 = .48 + x_side*.51
    x2 = .50 + x_side*.28
    for y_side in (-1,1):
        strut("Exposed load arch lower", (x0,y_side*.52,.31),
              (x1,y_side*.42,1.00), .13, ivory, root)
        strut("Exposed load arch crown", (x1,y_side*.42,1.00),
              (x2,y_side*.19,1.44), .12, orange, root)
    strut("Cross-face lower pressure bar", (x0,-.52,.31),(x0,.52,.31), .10, ivory, root)
    strut("Cross-face upper pressure bar", (x1,-.42,1.00),(x1,.42,1.00), .12, orange, root)
    box("Cross-face cyan status lens", (x0+x_side*.04,0,.52), (.035,.18,.075), cyan, root, .01)
for side in (-1,1):
    y = side*.88
    box("Split ivory root cheek", (.47,y,.66), (.58,.14,.83), ivory, root, .06)
    box("Cheek dark service slit", (.43,side*.959,.75), (.27,.02,.44), navy, root, .01)
    box("Cheek cyan service key", (.40,side*.975,.63), (.07,.015,.21), cyan, root, .004)
    box("Root upper armor rib", (.52,side*.73,1.09), (.48,.14,.52), ivory, root, .055)
    box("Tapered crown ochre truss", (.53,side*.45,1.39), (.34,.16,.29), orange, root, .05)
    for x_side in (-1,1):
        box("Cross-face armor toe", (.48+x_side*.53,side*.58,.40), (.12,.42,.17), ivory, root, .035)
box("Crown dark sensor socket", (.54,0,1.57), (.18,.24,.09), blue, root, .02)
cylinder("Crown warm signal", (.54,0,1.65), .073,.13,amber,root,vertices=12)

# Two open cantilevers, one high and one low, emerge from the same core.
# Narrow parallel rails plus end clamps frame a visible empty service bay.
for side, length, level in ((-1,2.02,.45),(1,1.75,.92)):
    y = side*.57
    xmid = -.54 - length*.5
    for rail in (-1,1):
        ry = y + rail*.22
        box("Berth deep structural rail", (xmid,ry,level), (length,.22,.34), navy, root, .055)
        box("Berth segmented armor crest", (xmid,ry,level+.20), (length-.11,.21,.11), ivory, root, .018)
        box("Berth cyan inner guide", (xmid,ry-rail*.104,level+.055), (length-.25,.025,.034), cyan, root, .004)
        for n in range(3):
            x = -.69 - n*(length-.34)/3
            box("Rail armor break", (x,ry,level+.26), (.042,.21,.017), edge, root, .004)
    tip = -.54-length
    box("Open berth end bridge", (tip+.055,y,level+.08), (.20,.65,.34), ivory, root, .04)
    box("Recessed end face", (tip-.034,y,level+.07), (.028,.31,.15), blue, root, .008)
    for x in (-.65, tip+.18):
        box("Amber berth socket", (x,y-side*.28,level+.24), (.08,.07,.09), amber, root, .014)
    strut("Ochre berth load truss", (.18,y,level-.25), (tip+.22,y,level-.26), .16, orange, root)
    box("Cantilever triangular underbrace", (-.70,y,level-.24), (.83,.30,.24), mid, root, .045)

# The craft stays physically within the lower open berth.
craft = node("Docked small craft", root)
craft.location.y = .57
craft.location.z = .23
craft_shell = hull("Craft tapered hull", [(.51,.52,.18,-1.51),(.68,.58,.20,-1.47),(.79,.38,.15,-1.49),(.85,.12,.08,-1.67)], blue, craft)
craft_shell.location.y = -.57
box("Craft ivory dorsal spine", (-1.52,-.57,.82), (.82,.13,.055), ivory, craft, .025)
box("Craft dark belly", (-1.45,-.57,.48), (1.02,.30,.12), navy, craft, .04)
box("Craft cockpit", (-1.64,-.57,.81), (.38,.24,.065), glass, craft, .025)
for side in (-1,1):
    box("Craft swept short wing", (-1.22,-.57+side*.22,.62), (.53,.23,.07), edge, craft, .034)
    cylinder("Craft aft cyan thruster", (-.94,-.57+side*.11,.55), .065,.09, cyan, craft,
             rot=(0, math.pi/2, 0), vertices=12)

# Existing runtime animation names are preserved; no new clock or business path.
crane = node("CraneSlide", root)
box("Crane sliding armored saddle", (-1.02,.57,1.26), (.35,.43,.21), ivory, crane, .045)
box("Crane dark folding jib", (-1.24,.57,1.31), (.65,.12,.12), blue, crane, .025)
box("Crane amber hook", (-1.54,.57,1.15), (.12,.13,.26), amber, crane, .024)
collar = node("DockCollarSpin", root, (-1.78,-.57,.65))
torus("Berth working collar", (0,0,0), .22,.060, navy, collar, rot=(math.pi/2,0,0))
torus("Berth cyan collar aperture", (0,0,0), .22,.022, cyan, collar, rot=(math.pi/2,0,0))

bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "shipyard.blend"), compress=True)
bpy.ops.object.select_all(action="DESELECT")
for obj in (root, *root.children_recursive):
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=str(OUT / "shipyard.glb"), export_format="GLB",
                          use_selection=True, export_animations=False, export_cameras=False,
                          export_lights=False, export_yup=True)
