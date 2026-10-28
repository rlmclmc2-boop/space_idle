"""R5 approved silhouettes as compact, editable Blender 3D assemblies.

Geometry-only GLB. Named child pivots carry runtime work-cycle animation.
Blender is Z-up; glTF exports Y-up for Godot. No game state is authored here.
"""
import bpy
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parents[1] / "assets/planets/facilities_v5"
OUT.mkdir(parents=True, exist_ok=True)


def mat(name, rgb, glow=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = 0.03
    bsdf.inputs["Roughness"].default_value = 0.88
    if glow:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = glow
    return m


def empty(name, parent=None, at=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    o.location = at
    return o


def done(o, name, material, parent, bevel=0.06):
    o.name = name
    o.parent = parent
    o.data.materials.append(material)
    if bevel:
        b = o.modifiers.new("Soft illustration edge", "BEVEL")
        b.width = bevel
        b.segments = 2
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=b.name)
    n = o.modifiers.new("Broad face normals", "WEIGHTED_NORMAL")
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=n.name)
    return o


def box(name, at, size, material, parent, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    o = bpy.context.object
    o.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return done(o, name, material, parent, bevel)


def cyl(name, at, radius, depth, material, parent, rot=(0, 0, 0), vertices=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                        location=at, rotation=rot)
    return done(bpy.context.object, name, material, parent, 0.035)


def torus(name, at, major, minor, material, parent):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=32, minor_segments=8, location=at)
    return done(bpy.context.object, name, material, parent, 0)


stats = []
for kind in ("auto_explore", "refinery", "equipment", "shipyard"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cream = mat("Warm ivory broad armor", (0.86, 0.79, 0.62))
    dark = mat("Deep navy silhouette", (0.035, 0.10, 0.19))
    blue = mat("Blue structural panel", (0.075, 0.18, 0.34))
    cyan = mat("Cyan energy aperture", (0.05, 0.71, 0.86), 0.8)
    amber = mat("Amber working bay", (0.95, 0.42, 0.07), 0.5)
    solar = mat("Broad blue solar field", (0.07, 0.25, 0.48))
    root = empty("Facility")

    if kind == "auto_explore":
        # One ring, an obvious docking aperture and two broad wings.
        ring = empty("HabitatRingSpin", root)
        torus("Navy inhabited ring", (0, 0, 0), 1.08, 0.21, dark, ring)
        for i in range(4):
            a = i * math.pi / 2
            o = box("Ivory ring quadrant", (1.08 * math.cos(a), 1.08 * math.sin(a), 0.02),
                    (0.87, 0.43, 0.27), cream, ring, 0.1)
            o.rotation_euler.z = a + math.pi / 2
        cyl("Dock core", (0, 0, 0.08), 0.48, 0.53, cream, root)
        cyl("Deep docking mouth", (0, 0, 0.38), 0.31, 0.04, dark, root)
        cyl("Dock guidance circle", (0, 0, 0.41), 0.16, 0.02, cyan, root)
        for sign in (-1, 1):
            hinge = empty("SolarHingeLeft" if sign < 0 else "SolarHingeRight", root,
                          (sign * 1.46, 0, 0))
            box("Wing boom", (sign * 0.44, 0, 0), (0.9, 0.14, 0.16), dark, hinge)
            box("Broad solar wing", (sign * 1.05, 0, 0), (1.05, 1.1, 0.09), solar, hinge)
            box("Wing edge", (sign * 1.05, 0, 0.07), (1.1, 1.15, 0.04), cream, hinge, 0.02)
            box("Visible blue field", (sign * 1.05, 0, 0.10), (0.93, 0.98, 0.025), solar, hinge, 0.01)

    elif kind == "refinery":
        # The furnace sits between two raised ore hoppers; the belt enters its mouth.
        for x in (-1.06, 1.06):
            for y in (-0.65, 0.65):
                box("Conforming landing foot", (x, y, 0.12), (0.43, 0.44, 0.24), dark, root)
        box("Wide navy furnace plinth", (0, 0.22, 0.48), (2.10, 1.60, 0.70), dark, root, 0.15)
        box("Ivory furnace chamber", (0, 0.31, 0.94), (1.95, 1.51, 1.14), cream, root, 0.19)
        box("Raised furnace shoulders left", (-0.74, 0.12, 1.55), (0.39, 1.18, 0.65), cream, root, 0.10)
        box("Raised furnace shoulders right", (0.74, 0.12, 1.55), (0.39, 1.18, 0.65), cream, root, 0.10)
        box("Dark furnace throat", (0, -0.49, 1.24), (0.82, 0.07, 0.80), dark, root, 0.08)
        box("Amber furnace core", (0, -0.54, 1.26), (0.53, 0.035, 0.55), amber, root, 0.04)
        box("Open furnace crown", (0, 0.10, 1.57), (0.78, 0.81, 0.11), dark, root, 0.04)
        box("Hot furnace top", (0, 0.10, 1.65), (0.55, 0.57, 0.05), amber, root, 0.02)
        for sign in (-1, 1):
            box("Raised navy ore hopper", (sign * 1.43, 0.54, 1.52),
                (0.99, 1.02, 1.02), blue, root, 0.13)
            box("Pale ore hopper rim", (sign * 1.43, 0.54, 2.07), (1.04, 1.08, 0.12), cream, root)
            box("Visible dark ore fill", (sign * 1.43, 0.54, 2.15), (0.74, 0.78, 0.07), dark, root)
            box("Hopper cyan status", (sign * 1.43, -0.01, 1.64), (0.38, 0.035, 0.12), cyan, root, 0.02)
            wheel = empty("IntakeWheelLeft" if sign < 0 else "IntakeWheelRight", root,
                          (sign * 0.76, -0.70, 0.59))
            cyl("Intake drive wheel", (0, 0, 0), 0.20, 0.13, dark, wheel,
                (math.pi / 2, 0, 0), 16)
            for j in range(4):
                a = j * math.pi / 2
                box("Large wheel spoke", (0.12 * math.cos(a), 0, 0.12 * math.sin(a)),
                    (0.12, 0.04, 0.06), cyan, wheel, 0.01)
        box("Long navy input conveyor", (0, -1.35, 0.35), (0.71, 1.65, 0.26), dark, root, 0.04)
        box("Conveyor ivory side left", (-0.43, -1.35, 0.49), (0.15, 1.65, 0.23), cream, root, 0.03)
        box("Conveyor ivory side right", (0.43, -1.35, 0.49), (0.15, 1.65, 0.23), cream, root, 0.03)
        shutters = empty("CoolingShutters", root, (0, 0.63, 1.10))
        for x in (-0.35, 0.35):
            box("Broad cooler flap", (x, 0, 0), (0.45, 0.10, 0.42), cream, shutters)

    elif kind == "equipment":
        # Open floor and separated side shells keep the working bay visible from above.
        box("Navy contact floor", (0, 0, 0.12), (3.02, 2.20, 0.24), dark, root, 0.07)
        box("Broad exposed workshop deck", (0, -0.16, 0.27), (2.36, 1.65, 0.08), blue, root, 0.04)
        box("Low warm rear work wall", (0, 0.92, 0.51), (2.88, 0.38, 0.42), cream, root, 0.08)
        box("Amber lit work floor", (0, 0.32, 0.33), (1.45, 0.57, 0.04), amber, root, 0.02)
        for sign in (-1, 1):
            box("Ivory side machine housing", (sign * 1.30, -0.02, 0.71),
                (0.62, 1.91, 0.92), cream, root, 0.13)
            box("Navy side inner face", (sign * 0.94, -0.18, 0.65),
                (0.08, 1.54, 0.62), dark, root, 0.02)
        box("Navy forward work lip", (0, -1.10, 0.27), (2.58, 0.18, 0.19), dark, root)
        gantry = empty("GantrySlide", root)
        for x in (-1.02, 1.02):
            box("Tall navy gantry upright", (x, -0.48, 1.16), (0.35, 0.38, 1.72), blue, gantry, 0.07)
            box("Ivory gantry foot", (x, -0.53, 0.45), (0.49, 0.52, 0.37), cream, gantry, 0.06)
        box("Heavy navy overhead beam", (0, -0.48, 2.04), (2.42, 0.43, 0.38), dark, gantry, 0.07)
        box("Broad beam blue face", (0, -0.72, 2.04), (2.06, 0.06, 0.21), blue, gantry, 0.02)
        arm = empty("ToolArmSweep", gantry, (0, 0.10, 1.89))
        box("Ivory tool shoulder", (0, -0.08, -0.15), (0.70, 0.59, 0.45), cream, arm, 0.07)
        box("Forward navy articulated arm", (0, -0.55, -0.39), (0.45, 1.06, 0.33), blue, arm, 0.06)
        box("Broad ivory working claw", (0, -1.04, -0.89), (0.82, 0.48, 0.72), cream, arm, 0.06)
        box("Cyan work tip", (0, -1.29, -1.14), (0.47, 0.08, 0.21), cyan, arm, 0.02)

    else:
        # One high armored spine carries two unequal, open cantilever berths.
        box("Tall single navy service spine", (-1.24, 0, 1.02), (0.82, 2.76, 2.20), dark, root, 0.13)
        box("Broad ivory spine armor", (-1.51, 0, 1.10), (0.35, 2.51, 2.04), cream, root, 0.09)
        box("Ivory front spine silhouette", (-1.22, -1.48, 1.15), (0.75, 0.24, 2.27), cream, root, 0.08)
        box("Deep navy front spine recess", (-1.22, -1.62, 1.21), (0.29, 0.035, 1.39), dark, root, 0.02)
        box("Spine crown", (-1.18, 0, 2.18), (0.86, 0.75, 0.30), cream, root, 0.07)
        box("Long lower navy berth", (0.21, -0.94, 0.45), (2.45, 0.56, 0.70), dark, root, 0.08)
        box("Lower berth ivory armor", (0.20, -0.94, 0.79), (2.19, 0.44, 0.15), cream, root, 0.03)
        box("Short raised upper cantilever", (-0.04, 0.94, 1.21), (1.96, 0.53, 0.59), blue, root, 0.07)
        box("Upper cantilever ivory armor", (-0.10, 0.94, 1.53), (1.80, 0.42, 0.15), cream, root, 0.03)
        box("Cyan lower berth end", (1.48, -0.94, 0.45), (0.11, 0.38, 0.20), cyan, root)
        box("Cyan upper berth end", (0.96, 0.94, 1.19), (0.11, 0.35, 0.16), cyan, root)
        crane = empty("CraneSlide", root)
        box("Ivory moving crane carriage", (-0.12, 0.94, 1.87), (0.72, 0.69, 0.46), cream, crane, 0.07)
        box("Navy crane boom", (0.53, 0.94, 1.94), (0.82, 0.20, 0.22), dark, crane, 0.04)
        box("Amber crane work head", (0.94, 0.94, 1.60), (0.26, 0.25, 0.43), amber, crane)
        collar = empty("DockCollarSpin", root, (1.14, 0.94, 1.18))
        torus("Round cyan berth collar", (0, 0, 0), 0.45, 0.13, cyan, collar)
        box("Collar ivory guide", (0, 0, 0.47), (0.29, 0.17, 0.10), cream, collar)

    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / (kind + ".blend")), compress=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (root, *root.children_recursive):
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=str(OUT / (kind + ".glb")), export_format="GLB",
                              use_selection=True, export_animations=False, export_cameras=False,
                              export_lights=False, export_yup=True)
    meshes = [o for o in root.children_recursive if o.type == "MESH"]
    stats.append({"kind": kind, "meshes": len(meshes),
                  "triangles": sum(sum(len(p.vertices) - 2 for p in o.data.polygons)
                                   for o in meshes)})
(OUT / "model-stats.json").write_text(json.dumps(stats, indent=2))
