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

# One monocoque pressure shell is the shipyard's load junction. It wraps the
# ring passage and the radial launch way in one tapered body; the former tall
# gray tower, nested shoulder and external arches no longer stack around it.
core = hull("Ring-to-berth pressure shell", [
    (-.08,.81,.93,.04), (.20,.89,1.02,.04),
    (.62,.83,.98,.02), (1.04,.63,.74,-.02),
    (1.27,.36,.46,-.04),
], ivory, root)
# A radial through cavity accepts the ship and both real berth rails. A second
# tangent cavity lets the owned curved ring deck cross the same shell.
bpy.ops.mesh.primitive_cube_add(size=1, location=(-.35, 0, .64))
berth_cut = bpy.context.object
berth_cut.name = "Temporary radial launch cavity"
berth_cut.dimensions = (3.30, .94, .68)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.context.view_layer.objects.active = core
mod = core.modifiers.new("Open radial launch cavity", "BOOLEAN")
mod.operation = "DIFFERENCE"
mod.object = berth_cut
bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.data.objects.remove(berth_cut, do_unlink=True)
bpy.ops.mesh.primitive_cube_add(size=1, location=(.02, 0, .48))
ring_cut = bpy.context.object
ring_cut.name = "Temporary tangent ring cavity"
ring_cut.dimensions = (.86, 2.80, .56)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.context.view_layer.objects.active = core
mod = core.modifiers.new("Open owned spine passage", "BOOLEAN")
mod.operation = "DIFFERENCE"
mod.object = ring_cut
bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.data.objects.remove(ring_cut, do_unlink=True)
# The freshly cut walls are the dark pressure interior of the same mesh, not
# extra boxes placed over the shell. Small real bevels catch the port edges.
core.data.materials.append(blue)
core.data.materials.append(navy)
core.data.update()
for polygon in core.data.polygons:
    center = polygon.center
    if center.z < .19:
        polygon.material_index = 2
    elif (.29 < center.z < 1.00 and abs(abs(center.y) - .47) < .08) or \
         (.20 < center.z < .77 and abs(center.x - .02) < .53):
        polygon.material_index = 1
bpy.context.view_layer.objects.active = core
port_bevel = core.modifiers.new("Machined port cut edge", "BEVEL")
port_bevel.width = .032
port_bevel.segments = 2
port_bevel.limit_method = "ANGLE"
bpy.ops.object.modifier_apply(modifier=port_bevel.name)
# Local machined insets follow the shell's load faces. They mark a pressurized
# shipyard node without covering the two structural openings with new frames.
for side in (-1,1):
    box("Pressure shell blue service recess", (.03,side*1.025,.53), (.66,.025,.25), blue, root, .015)
    box("Pressure shell cyan power key", (.02,side*1.046,.53), (.22,.015,.055), cyan, root, .005)
    # The shell's lower load edge meets the same armored pressure language as
    # the station and workshop feet, but leaves both launch and ring cuts open.
    for x in (-.51, .49):
        strut("Shell diagonal lower bearing", (x,side*.94,.35),
              (x+.11,side*.88,.02), .13, ivory, root)
        box("Shell bearing blue inset", (x+.10,side*.99,.08),
            (.16,.028,.075), blue, root, .007)
    for x in (-.60,.57):
        box("Shell warm locking socket", (x,side*.83,.30), (.12,.075,.10), amber, root, .012)
box("Pressure shell dorsal service ridge", (-.02,0,1.28), (.40,.62,.13), blue, root, .027)
cylinder("Pressure shell warm signal", (-.02,0,1.39), .075,.13,amber,root,vertices=12)

# One broad launch cavity crosses the ring node. Two transverse pressure
# portals tie its paired rails into the same keel; the craft remains visible
# through the cavity rather than sitting beside a second decorative fork.
box("Dock load pan", (-1.32,0,.24), (2.12,1.25,.18), navy, root, .06)
box("Dock recessed service bed", (-1.36,0,.35), (1.85,.83,.045), blue, root, .012)
for side in (-1,1):
    y = side*.70
    cheek = craft_hull("Continuous ochre berth pressure cheek", [
        (-2.57,y,.55,.15,.18), (-2.36,y,.62,.22,.28),
        (-1.52,y,.65,.25,.34), (-.49,y,.67,.28,.37),
        (.22,y,.63,.25,.34), (.56,y,.52,.18,.20),
    ], orange, root)
    # Two real service windows make each cheek a load frame. Both the upper
    # and lower orange members continue into the common pressure shell.
    for x in (-1.98, -1.12):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x,y,.68))
        window = bpy.context.object
        window.name = "Temporary berth cheek service opening"
        window.dimensions = (.60,.90,.39)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bpy.context.view_layer.objects.active = cheek
        cut = cheek.modifiers.new("Open load-frame service window", "BOOLEAN")
        cut.operation = "DIFFERENCE"
        cut.object = window
        bpy.ops.object.modifier_apply(modifier=cut.name)
        bpy.data.objects.remove(window, do_unlink=True)
    box("Berth lower load web", (-1.34,side*.69,.33), (2.37,.31,.17), navy, root, .035)
    box("Berth recessed dark crown", (-1.43,side*.70,1.015), (1.86,.25,.045), navy, root, .012)
    for x, length in ((-2.13,.43),(-1.42,.50),(-.69,.49)):
        box("Upper armor cassette on pressure cheek", (x,side*.70,1.055), (length,.22,.055), ivory, root, .012)
        box("Pressure cassette blue key", (x,side*.70,1.089), (length*.37,.08,.012), blue, root, .004)
    box("Dock inner launch guide", (-1.41,side*.55,.59), (2.12,.028,.045), cyan, root, .005)
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
