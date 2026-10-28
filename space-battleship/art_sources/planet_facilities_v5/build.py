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
        # Surface contact is four isolated pads, not a black rectangular plate.
        for x in (-1.06, 1.06):
            for y in (-0.65, 0.65):
                box("Conforming landing foot", (x, y, 0.12), (0.43, 0.44, 0.24), dark, root)
        cyl("Low processing vessel", (0, 0, 0.78), 0.84, 1.20, cream, root)
        cyl("Furnace crown", (0, 0, 1.39), 0.54, 0.15, dark, root)
        cyl("Visible hot top", (0, 0, 1.49), 0.32, 0.04, amber, root)
        box("Amber furnace opening", (0, -0.86, 0.89), (0.52, 0.06, 0.43), amber, root)
        for sign in (-1, 1):
            box("Broad navy ore hopper", (sign * 1.27, -0.08, 1.29),
                (0.82, 0.89, 0.81), blue, root, 0.1)
            box("Ore load rim", (sign * 1.27, -0.08, 1.72), (0.87, 0.93, 0.09), cream, root)
            box("Visible dark ore mass", (sign * 1.27, -0.08, 1.78), (0.55, 0.55, 0.06), dark, root)
            wheel = empty("IntakeWheelLeft" if sign < 0 else "IntakeWheelRight", root,
                          (sign * 0.78, -0.47, 0.47))
            cyl("Intake drive wheel", (0, 0, 0), 0.20, 0.13, dark, wheel,
                (math.pi / 2, 0, 0), 16)
            for j in range(4):
                a = j * math.pi / 2
                box("Large wheel spoke", (0.12 * math.cos(a), 0, 0.12 * math.sin(a)),
                    (0.12, 0.04, 0.06), cyan, wheel, 0.01)
        box("Wide input belt", (0, -1.05, 0.34), (0.56, 0.94, 0.21), dark, root)
        shutters = empty("CoolingShutters", root, (0, 0.63, 1.10))
        for x in (-0.35, 0.35):
            box("Broad cooler flap", (x, 0, 0), (0.45, 0.10, 0.42), cream, shutters)

    elif kind == "equipment":
        # Wide warm bay, one gantry and a single readable working arm.
        box("Low navy contact feet", (0, 0, 0.12), (2.55, 1.52, 0.24), dark, root)
        box("Warm ivory workshop shell", (0, 0.36, 0.72), (2.85, 1.25, 1.28), cream, root, 0.17)
        box("Broad navy roof band", (0, 0.36, 1.41), (2.48, 0.88, 0.13), blue, root, 0.08)
        box("Amber work skylight", (0, 0.12, 1.49), (0.96, 0.40, 0.035), amber, root, 0.02)
        box("Deep working aperture", (0, -0.30, 0.72), (1.82, 0.08, 0.76), dark, root)
        box("Amber bay interior", (0, -0.36, 0.78), (1.48, 0.025, 0.55), amber, root, 0.02)
        gantry = empty("GantrySlide", root)
        for x in (-1.02, 1.02):
            box("Gantry upright", (x, -0.56, 1.12), (0.25, 0.24, 1.65), blue, gantry)
        box("Single gantry beam", (0, -0.56, 1.91), (2.25, 0.25, 0.23), blue, gantry)
        arm = empty("ToolArmSweep", gantry, (0, -0.70, 1.77))
        box("Jointed tool arm", (0, 0, -0.38), (0.20, 0.22, 0.72), cream, arm)
        box("Bright tool head", (0, -0.02, -0.78), (0.29, 0.30, 0.18), cyan, arm)

    else:
        # An E-like open berth: one heavy keel, two jaws and one working carriage.
        box("One heavy navy keel", (-1.19, 0, 0.57), (0.66, 2.65, 1.34), dark, root, 0.13)
        box("Ivory keel armor", (-1.38, 0, 0.65), (0.19, 2.20, 1.20), cream, root)
        for y in (-0.91, 0.91):
            box("Open load-bearing jaw", (0.13, y, 0.39), (2.40, 0.43, 0.70), blue, root)
            box("Ivory jaw face", (0.16, y, 0.78), (2.24, 0.34, 0.13), cream, root)
            box("Cyan berth end", (1.34, y, 0.42), (0.09, 0.30, 0.13), cyan, root)
        crane = empty("CraneSlide", root)
        box("One broad moving crane", (0.10, 0, 1.12), (0.75, 0.30, 0.37), cream, crane)
        box("Amber crane work head", (0.10, 0, 0.82), (0.27, 0.22, 0.26), amber, crane)
        collar = empty("DockCollarSpin", root, (1.25, 0, 0.55))
        torus("Round cyan berth collar", (0, 0, 0), 0.37, 0.12, cyan, collar)
        box("Collar ivory guide", (0, 0, 0.43), (0.26, 0.16, 0.08), cream, collar)

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
