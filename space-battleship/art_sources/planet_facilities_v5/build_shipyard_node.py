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


def craft_hull(name, stations, mat, parent):
    """Closed chamfered craft shell along the actual launch direction (X)."""
    vertices = []
    for x, cy, cz, hy, hz in stations:
        for u, v in ((-1,-.72),(-.72,-1),(.72,-1),(1,-.72),(1,.72),(.72,1),(-.72,1),(-1,.72)):
            vertices.append((x, cy+u*hy, cz+v*hz))
    faces = [tuple(reversed(range(8)))]
    for k in range(len(stations)-1):
        for n in range(8):
            faces.append((k*8+n,k*8+(n+1)%8,(k+1)*8+(n+1)%8,(k+1)*8+n))
    faces.append(tuple((len(stations)-1)*8+n for n in range(8)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent, 0.022)


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

# One broad launch cavity crosses the ring node. Two transverse pressure
# portals tie its paired rails into the same keel; the craft remains visible
# through the cavity rather than sitting beside a second decorative fork.
box("Dock load pan", (-1.32,0,.24), (2.12,1.25,.18), navy, root, .06)
box("Dock recessed service bed", (-1.36,0,.35), (1.85,.83,.045), blue, root, .012)
for side in (-1,1):
    y = side*.70
    box("Dock deep load rail", (-1.39,y,.52), (2.38,.27,.34), navy, root, .05)
    box("Dock armor rail crest", (-1.39,y,.74), (2.20,.25,.10), ivory, root, .018)
    box("Dock inner launch guide", (-1.41,side*.55,.59), (2.12,.028,.045), cyan, root, .005)
    for x in (-2.23,-1.48,-.73):
        box("Dock rail armor break", (x,y,.80), (.045,.24,.018), edge, root, .005)
    strut("Dock diagonal load brace", (.20,side*.82,.16), (-1.77,side*.80,.26), .13, orange, root)
for x, top in ((-.36,1.18),(-2.31,1.06)):
    for side in (-1,1):
        box("Dock portal pressure leg", (x,side*.78,(.39+top)*.5), (.24,.28,top-.39), ivory, root, .035)
        box("Dock portal joint", (x,side*.79,.59), (.27,.30,.16), blue, root, .025)
        box("Dock portal amber lock", (x,side*.94,.65), (.045,.025,.09), amber, root, .008)
    box("Dock portal roof truss", (x,0,top), (.28,1.78,.17), orange, root, .03)
    box("Dock portal upper armor", (x,0,top+.09), (.20,1.48,.055), ivory, root, .01)
box("Dock terminal armored nose", (-2.61,0,.42), (.24,1.38,.32), ivory, root, .04)
box("Dock nose inset", (-2.75,0,.42), (.028,.75,.14), blue, root, .008)

# One readable shuttle sits inside the lower open berth. The pointed nose,
# large glass canopy and twin cyan exhausts are actual geometry at orbital
# depth, not a camera-facing billboard or another independently orbiting icon.
craft = node("Docked small craft", root)
craft_hull("Ivory shuttle pressure shell", [
    (-2.42,0,.79,.06,.06),(-2.23,0,.78,.17,.11),
    (-1.91,0,.79,.26,.18),(-1.25,0,.80,.27,.19),
    (-.86,0,.77,.19,.14),
], ivory, craft)
craft_hull("Deep blue shuttle belly", [
    (-2.25,0,.64,.14,.07),(-1.76,0,.63,.27,.09),
    (-1.00,0,.63,.24,.09),(-.84,0,.65,.13,.06),
], navy, craft)
craft_hull("Faceted blue cockpit canopy", [
    (-2.17,0,.90,.10,.04),(-1.97,0,.94,.17,.09),
    (-1.60,0,.94,.19,.09),(-1.47,0,.92,.12,.05),
], glass, craft)
box("Shuttle ivory rear armor", (-1.10,0,.99), (.42,.37,.09), ivory, craft, .035)
for side in (-1,1):
    y = side*.28
    craft_hull("Shuttle swept ivory wing", [
        (-1.81,y,.72,.08,.055),(-1.48,y+side*.08,.73,.17,.08),
        (-1.03,y+side*.05,.72,.14,.06),
    ], ivory, craft)
    box("Blue engine fairing", (-.91,side*.20,.76), (.28,.19,.20), blue, craft, .04)
    box("Cyan rear nozzle", (-.745,side*.20,.76), (.03,.13,.13), cyan, craft, .008)
    box("Warm docked status", (-1.36,side*.28,.78), (.10,.04,.09), amber, craft, .014)

# Existing runtime animation names are preserved; no new clock or business path.
crane = node("CraneSlide", root)
box("Crane sliding armored saddle", (-1.02,.81,1.26), (.35,.30,.21), ivory, crane, .045)
box("Crane dark folding jib", (-1.24,.81,1.31), (.65,.12,.12), blue, crane, .025)
box("Crane amber hook", (-1.54,.81,1.15), (.12,.13,.26), amber, crane, .024)
collar = node("DockCollarSpin", root, (-1.78,0,.65))
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
