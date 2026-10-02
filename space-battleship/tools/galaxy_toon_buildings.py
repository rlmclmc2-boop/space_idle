"""Reproducible rounded GalaxyToon buildings. Blender 4.3+, no outside assets.

blender -b --python tools/galaxy_toon_buildings.py -- --family colony_ring interstellar_refinery --levels 1 5 --preview-dir /tmp/galaxy-toon
Filters replace only matching manifest entries. The accepted core stays untouched.
"""
import argparse
from array import array
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/galaxy/v3'
MATS = {}
FAMILIES = ('colony_ring', 'orbital_shipyard', 'stellar_energy_array', 'interstellar_refinery', 'crystal_refinery', 'heavy_element_refinery')
# Large, matte color masses stay distinct in the normal whole-galaxy view.
PALETTE = {
    'Armor': ((0.86, 0.88, 0.83), 0.04, 0.64, 0),
    'Panel': ((0.25, 0.38, 0.49), 0.08, 0.62, 0),
    'Navy': ((0.055, 0.095, 0.15), 0.08, 0.62, 0),
    'Metal': ((0.12, 0.20, 0.28), 0.16, 0.58, 0),
    'Glass': ((0.025, 0.46, 0.57), 0.08, 0.43, 0.015),
    'Reflection': ((0.30, 0.70, 0.75), 0.05, 0.48, 0.02),
    'Amber': ((0.95, 0.46, 0.10), 0.04, 0.52, 0.06),
    'Mark': ((0.62, 0.31, 0.08), 0.04, 0.60, 0),
    'Crystal': ((0.18, 0.65, 0.75), 0.10, 0.40, 0.02),
    'Solar': ((0.035, 0.32, 0.64), 0.06, 0.48, 0),
    'Foundry': ((0.78, 0.39, 0.14), 0.08, 0.62, 0),
    'Pressure': ((0.20, 0.37, 0.47), 0.10, 0.58, 0),
}

def materials():
    for name, (rgb, metal, roughness, emission) in PALETTE.items():
        m = bpy.data.materials.new('GalaxyToon' + name)
        m.diffuse_color = (*rgb, 1)
        m.use_nodes = True
        bs = m.node_tree.nodes.get('Principled BSDF')
        bs.inputs['Base Color'].default_value = (*rgb, 1)
        bs.inputs['Metallic'].default_value = metal
        bs.inputs['Roughness'].default_value = roughness
        bs.inputs['Emission Color'].default_value = (*rgb, 1)
        bs.inputs['Emission Strength'].default_value = emission
        MATS[name] = m

def empty(name, xyz=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = xyz
    obj.parent = parent
    return obj

def surface(name, verts, faces, mat, parent, smooth=True):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    mesh.materials.append(MATS[mat])
    for p in mesh.polygons:
        p.use_smooth = smooth
    return obj

def finish(obj, name, mat, parent, bevel=0):
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(MATS[mat])
    bpy.context.view_layer.objects.active = obj
    if bevel:
        mod = obj.modifiers.new('BroadRoundedEdge', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in obj.data.polygons:
        p.use_smooth = True
    mod = obj.modifiers.new('WeightedSurfaceNormals', 'WEIGHTED_NORMAL')
    mod.keep_sharp = True
    mod.weight = 50
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

def box(name, xyz, dims, mat, parent, bevel=0.16, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z = angle
    return finish(obj, name, mat, parent, min(bevel, min(dims) * 0.46))

def cyl(name, xyz, r, h, mat, parent, segments=32, bevel=0.09):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=r, depth=h, location=xyz)
    return finish(bpy.context.object, name, mat, parent, min(bevel, h * 0.23))

def lathe(name, profile, mat, parent, segments=36):
    verts = [(r * math.cos(i * math.tau / segments), r * math.sin(i * math.tau / segments), z) for r, z in profile for i in range(segments)]
    faces = []
    for row in range(len(profile) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            a = row * segments
            b = (row + 1) * segments
            faces.append((a + i, a + j, b + j, b + i))
    return surface(name, verts, faces, mat, parent)

def arc(name, r, w, h, z, mat, parent, start=0, end=math.tau):
    """Rounded-square sections give broad quiet caps and soft edges."""
    count = max(5, math.ceil((end - start) * r * 2))
    cross = 12
    verts = []
    for i in range(count + 1):
        a = start + (end - start) * i / count
        for j in range(cross):
            t = j * math.tau / cross
            c = math.cos(t)
            s = math.sin(t)
            rr = r + w * 0.5 * math.copysign(abs(c) ** 0.5, c)
            zz = z + h * 0.5 * math.copysign(abs(s) ** 0.5, s)
            verts.append((rr * math.cos(a), rr * math.sin(a), zz))
    faces = []
    for i in range(count):
        for j in range(cross):
            k = (j + 1) % cross
            faces.append((i * cross + j, (i + 1) * cross + j, (i + 1) * cross + k, i * cross + k))
    if end - start < math.tau - 0.001:
        faces.extend([tuple(reversed(range(cross))), tuple((count * cross + j for j in range(cross)))])
    return surface(name, verts, faces, mat, parent)

def local_arc(name, xy, r, w, h, z, mat, parent, **kwargs):
    obj = arc(name, r, w, h, z, mat, parent, **kwargs)
    obj.location.x = xy[0]
    obj.location.y = xy[1]
    return obj

def sphere(name, xyz, scale, mat, parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1, location=xyz)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent)

def pipe(name, points, r, mat, parent):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = r
    curve.bevel_resolution = 2
    curve.resolution_u = 8
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points) - 1)
    for p, co in zip(spline.bezier_points, points):
        p.co = co
        p.handle_left_type = 'AUTO'
        p.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.data.materials.append(MATS[mat])
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target='MESH')
    obj.select_set(False)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj

def window(name, xyz, dims, parent, angle=0):
    box(name + 'Recess', xyz, (dims[0] * 1.1, dims[1] * 1.12, dims[2] * 1.1), 'Metal', parent, 0.12, angle)
    box(name, (xyz[0], xyz[1], xyz[2] + 0.018), dims, 'Glass', parent, 0.12, angle)

def hull_plate(name, width, depth, z0, z1, mat, root, taper=0.86):
    outline = [(-0.5, -0.31), (-0.31, -0.5), (0.31, -0.5), (0.5, -0.31), (0.5, 0.31), (0.31, 0.5), (-0.31, 0.5), (-0.5, 0.31)]
    verts = [(x * width * taper, y * depth * taper, z0) for x, y in outline] + [(x * width, y * depth, z1) for x, y in outline]
    faces = [tuple(reversed(range(8))), tuple(range(8, 16))] + [(i, (i + 1) % 8, (i + 1) % 8 + 8, i + 8) for i in range(8)]
    obj = surface(name, verts, faces, mat, root, False)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new('RoundedOrbitalHullEdge', 'BEVEL')
    mod.width = 0.1
    mod.segments = 3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new('HullSurfaceNormals', 'WEIGHTED_NORMAL')
    mod.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj

def pad(root, width, depth):
    """An octagonal floating hull with a broad, quiet armor rim."""
    hull_plate('FloatingNavyHull', width, depth, 0, 0.72, 'Navy', root, 0.76)
    hull_plate('PearlHullArmor', width * 0.99, depth * 0.99, 0.7, 0.9, 'Armor', root, 0.97)
    hull_plate('IntegratedWorkingBay', width * 0.85, depth * 0.82, 0.9, 0.98, 'Metal', root, 0.98)

def horizontal_vessel(root, xyz, r, length):
    """A low enclosed pressure barrel aligned along the station transfer axis."""
    frame = empty('HorizontalVesselFrame', xyz, root)
    frame.rotation_euler.x = math.pi / 2
    lathe('HorizontalPressureShell', [(0, -length * 0.5), (r * 0.66, -length * 0.5), (r, -length * 0.38), (r, length * 0.38), (r * 0.66, length * 0.5), (0, length * 0.5)], 'Navy', frame, 28)
    for sign in (-1, 1):
        local_arc('PressureBarrelCollar', (0, 0), r, 0.15, 0.23, sign * length * 0.32, 'Armor', frame)
        cap = lathe('PressureBarrelEnd', [(0, sign * length * 0.41), (r * 0.94, sign * length * 0.41), (r * 0.83, sign * length * 0.52), (0, sign * length * 0.55)], 'Armor', frame, 28)

def tower(root, xyz, r, height):
    x, y, z = xyz
    hull = lathe('ObservationHull', [(0, z), (r * 0.82, z), (r, z + 0.16), (r, z + height * 0.45), (r * 0.92, z + height * 0.54), (0, z + height * 0.54)], 'Navy', root)
    hull.location.x = x
    hull.location.y = y
    local_arc('TowerCollar', (x, y), r, 0.18, 0.22, z + height * 0.48, 'Armor', root)
    glass = lathe('PanoramicGlass', [(r * 0.9, z + height * 0.52), (r * 0.94, z + height * 0.63), (r * 0.88, z + height * 0.82), (r * 0.69, z + height * 0.93)], 'Glass', root)
    glass.location.x = x
    glass.location.y = y
    cap = lathe('RoundedTowerHood', [(0, z + height * 0.92), (r * 0.7, z + height * 0.92), (r * 0.9, z + height * 0.96), (r * 0.93, z + height * 1.01), (r * 0.78, z + height * 1.09), (0, z + height * 1.12)], 'Armor', root)
    cap.location.x = x
    cap.location.y = y
    for a in (-1.5, -0.65):
        local_arc('TowerReflection', (x, y), r * 0.91, 0.035, height * 0.15, z + height * 0.72, 'Reflection', root, start=a, end=a + 0.14)
    box('BeaconSocket', (x, y, z + height * 1.14), (0.36, 0.36, 0.18), 'Metal', root, 0.07)
    box('AmberBeacon', (x, y, z + height * 1.26), (0.18, 0.18, 0.22), 'Amber', root, 0.065)

def habitat_band(root, r, z, w, clasps):
    arc('HabitatNavyHull', r, w, 1.04, z, 'Navy', root)
    arc('HabitatPanoramicBand', r + w * 0.485, 0.1, 0.35, z + 0.12, 'Glass', root)
    arc('HabitatPearlRoof', r, w + 0.12, 0.39, z + 0.57, 'Armor', root)
    arc('HabitatLowerLip', r, w + 0.05, 0.17, z - 0.53, 'Panel', root)
    for i in range(clasps):
        a = i * math.tau / clasps
        arc('SoftHabitatClasp', r, w + 0.4, 1.28, z + 0.05, 'Armor', root, start=a - 0.095, end=a + 0.095)

def colony(root, level):
    r = 3.3 + 0.12 * (level - 1)
    habitat_band(root, r, 1.12, 1.08 + 0.055 * (level - 1), 4)
    for i in range(2 + (level >= 2)):
        a = i * math.tau / (2 + (level >= 2)) + math.pi / 6
        box('TransitSpoke', (r * 0.43 * math.cos(a), r * 0.43 * math.sin(a), 1.22), (r * 0.94, 0.54, 0.46), 'Navy', root, 0.18, a)
        box('TransitRoof', (r * 0.43 * math.cos(a), r * 0.43 * math.sin(a), 1.5), (r * 0.92, 0.56, 0.17), 'Armor', root, 0.07, a)
    tower(root, (0, 0, 0.18), 0.93 + (level - 1) * 0.035, 2.35 + 0.25 * (level - 1))
    if level >= 2:
        for a in (-math.pi / 2, math.pi / 2):
            x, y = ((r + 0.16) * math.cos(a), (r + 0.16) * math.sin(a))
            box('ArrivalBerth', (x, y, 0.9), (1.7, 1.25, 0.5), 'Armor', root, 0.23, a)
            box('BerthInset', (x, y, 1.18), (1.35, 0.87, 0.09), 'Navy', root, 0.08, a)
    if level >= 3:
        for a in [math.pi] if level == 3 else [math.pi, 0]:
            x, y = (1.8 * math.cos(a), 1.8 * math.sin(a))
            cyl('EcologyPodBase', (x, y, 0.81), 0.76, 0.48, 'Armor', root)
            sphere('EcologyCanopy', (x, y, 1.04), (0.69, 0.69, 0.48), 'Glass', root)
            local_arc('EcologyFrame', (x, y), 0.7, 0.11, 0.15, 1.08, 'Armor', root)
    if level >= 4:
        habitat_band(root, 2.4 + (level - 4) * 0.17, 2.65, 0.63, 4)
    if level == 5:
        local_arc('CrownObservationBand', (0, 0), 1.14, 0.29, 0.38, 3.85, 'Glass', root)
        local_arc('CrownRoof', (0, 0), 1.14, 0.37, 0.22, 4.12, 'Armor', root)
    empty('DockSocket', (0, -(r + 0.65), 1.15), root)

def foundry(root, level):
    width = 6 + 0.48 * (level - 1)
    depth = 5.3 + 0.3 * (level - 1)
    pad(root, width, depth)
    box('CompactFurnaceHull', (-0.55, 0, 1.77), (3.3, 3.85, 1.83), 'Navy', root, 0.36)
    box('BroadFurnaceArmor', (-0.55, 0, 2.77), (3.48, 4, 0.49), 'Foundry', root, 0.23)
    box('HeatVentRecess', (-0.55, 0, 3.04), (2.2, 2.35, 0.11), 'Navy', root, 0.05)
    for x in (-1.15, 0.05):
        box('WarmHeatSlot', (x, 0, 3.1), (0.4, 2.05, 0.09), 'Mark', root, 0.03)
    box('FurnaceMouth', (-0.55, -1.97, 1.6), (1.94, 0.16, 0.7), 'Metal', root, 0.14)
    box('AmberSmeltOpening', (-0.55, -2.065, 1.6), (1.43, 0.055, 0.35), 'Amber', root, 0.045)
    box('CargoIntakeHull', (-0.55, -2.48, 0.81), (2.12, 1.18, 0.7), 'Navy', root, 0.25)
    box('CargoIntakeArmor', (-0.55, -2.47, 1.18), (2.16, 1.16, 0.19), 'Armor', root, 0.085)
    box('CargoIntakeRecess', (-0.55, -2.51, 1.3), (1.48, 0.75, 0.07), 'Metal', root, 0.03)
    for i in range(1 + (level >= 3)):
        x = -0.55 if level < 3 else -1.36 + i * 1.62
        horizontal_vessel(root, (x, 0.31, 3.33), 0.4 + 0.02 * (level - 1), 2.76 + 0.1 * (level - 1))
    box('SideControlModule', (2.06, -0.15, 1.49), (1.22, 2.5, 1.22), 'Armor', root, 0.24)
    window('ControlGlazing', (2.06, -0.3, 2.14), (0.97, 1.39, 0.19), root)
    pipe('HeatRecoveryPipe', [(0.6, 0.95, 2.05), (1.1, 1.45, 2.08), (1.97, 1.4, 1.88)], 0.15, 'Metal', root)
    if level >= 2:
        cyl('SmeltVat', (2.08, 1.65, 1.58), 0.68, 1.2 + 0.15 * (level - 2), 'Navy', root)
        local_arc('VatArmor', (2.08, 1.65), 0.68, 0.18, 0.27, 2.23 + 0.15 * (level - 2), 'Armor', root)
        cyl('VatLid', (2.08, 1.65, 2.36 + 0.15 * (level - 2)), 0.63, 0.15, 'Armor', root)
    if level >= 3:
        box('InputHopper', (-2.35, 0.1, 1.78), (1.05, 2.2, 1.42), 'Panel', root, 0.23)
        box('HopperCap', (-2.35, 0.1, 2.53), (1.13, 2.28, 0.21), 'Armor', root, 0.09)
        box('HopperDarkWell', (-2.35, 0.1, 2.66), (0.75, 1.76, 0.06), 'Navy', root, 0.02)
    if level >= 4:
        box('TransferHousing', (0, 2.51, 1.61), (4.18, 0.95, 1.21), 'Navy', root, 0.23)
        box('TransferRoof', (0, 2.51, 2.27), (4.35, 1.03, 0.23), 'Armor', root, 0.1)
        window('TransferGlazing', (0, 2.5, 2.42), (2.8, 0.61, 0.13), root)
    if level == 5:
        pipe('OverheadRecoveryLoop', [(-1.36, 1.25, 3.55), (-1.36, 2.06, 3.58), (1.95, 2.12, 3.15), (2.08, 1.65, 2.7)], 0.21, 'Panel', root)
        for x in (-3.25, 3.25):
            box('IndustrialCornerArmor', (x, -2.54, 1.06), (0.5, 0.68, 0.61), 'Armor', root, 0.16)
    empty('DockSocket', (-0.55, -depth * 0.5 - 0.3, 1.13), root)

def ship_hull(root, xyz=(0, 0, 0), scale=1):
    """Small weapon-free cream/navy hull based on the accepted ship silhouettes."""
    x, y, z = xyz
    outline = [(-0.7, -1.8), (0.7, -1.8), (1.08, -1.1), (0.72, 0.5), (0, 2.3), (-0.72, 0.5), (-1.08, -1.1)]
    verts = [(x + xx * scale, y + yy * scale, z) for xx, yy in outline]
    top = [(xx, yy, zz + 0.63 * scale) for xx, yy, zz in verts]
    faces = [tuple(reversed(range(7))), tuple(range(7, 14))] + [(i, (i + 1) % 7, (i + 1) % 7 + 7, i + 7) for i in range(7)]
    obj = surface('AcceptedStyleHull', verts + top, faces, 'Navy', root, False)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new('HullRoundedEdge', 'BEVEL')
    mod.width = 0.16 * scale
    mod.segments = 3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for sign in (-1, 1):
        box('HullIvoryShoulder', (x + sign * 0.62 * scale, y - 0.52 * scale, z + 0.57 * scale), (0.34 * scale, 2.27 * scale, 0.29 * scale), 'Armor', root, 0.13 * scale, sign * -0.14)
        box('HullEngine', (x + sign * 0.56 * scale, y - 1.77 * scale, z + 0.28 * scale), (0.39 * scale, 0.55 * scale, 0.34 * scale), 'Panel', root, 0.13 * scale)
        box('EngineTealFace', (x + sign * 0.56 * scale, y - 2.03 * scale, z + 0.3 * scale), (0.25 * scale, 0.055 * scale, 0.17 * scale), 'Glass', root, 0.02 * scale)
    box('IvoryBow', (x, y + 1.22 * scale, z + 0.62 * scale), (0.41 * scale, 1.34 * scale, 0.28 * scale), 'Armor', root, 0.12 * scale)
    window('HullCanopy', (x, y + 0.11 * scale, z + 0.79 * scale), (0.58 * scale, 1.16 * scale, 0.24 * scale), root)

def shipyard(root, level):
    width = 7.4 + 0.38 * (level - 1)
    length = 7.6 + 0.3 * (level - 1)
    for x in (-width * 0.44, width * 0.44):
        box('OpenDockNavyRail', (x, 0, 0.63), (0.89, length, 1.14), 'Navy', root, 0.31)
        box('OpenDockRailArmor', (x, 0, 1.28), (0.99, length * 0.97, 0.27), 'Armor', root, 0.12)
        window('DockRailGlazing', (x, 0, 1.46), (0.59, length * 0.56, 0.13), root)
    box('DockCrossSpine', (0, length * 0.43, 0.78), (width, 1.18, 1.23), 'Navy', root, 0.26)
    box('DockCrossArmor', (0, length * 0.43, 1.49), (width, 1.28, 0.29), 'Armor', root, 0.14)
    count = 2 + (level >= 4)
    for i in range(count):
        y = -length * 0.32 + i * (length * 0.64 / max(1, count - 1))
        for sign in (-1, 1):
            x = sign * width * 0.43
            box('BerthSupport', (x * 0.82, y, 0.97), (1.87, 0.44, 0.46), 'Metal', root, 0.14)
            box('GantryFoot', (x, y, 1.45), (0.58, 0.69, 0.43), 'Panel', root, 0.14)
            box('GantryUpright', (x, y, 2.25), (0.55, 0.55, 1.54), 'Armor', root, 0.13)
            box('GantryReach', (x * 0.8, y, 3.06), (width * 0.29, 0.62, 0.55), 'Armor', root, 0.15)
    ship_hull(root, (0, -0.35, 1.03), 0.88 + 0.07 * (level - 1))
    tower(root, (0, length * 0.43, 1.52), 0.68, 1.36 + 0.16 * (level - 1))
    if level >= 3:
        for sign in (-1, 1):
            box('DockSupplyPod', (sign * 2.12, length * 0.4, 1.87), (1.24, 0.98, 0.63), 'Armor', root, 0.22)
    if level == 5:
        box('RearMaintenanceBridge', (0, length * 0.32, 3.73), (width * 0.74, 0.47, 0.34), 'Panel', root, 0.14)
        box('BridgePearlRail', (0, length * 0.32, 3.94), (width * 0.77, 0.48, 0.15), 'Armor', root, 0.065)
    empty('DockSocket', (0, -length * 0.55, 1.1), root)

def energy(root, level):
    count = (3, 3, 4, 4, 5)[level - 1]
    outer = 3.65 + 0.19 * (level - 1)
    cyl('ArrayHub', (0, 0, 0.7), 1.15, 1.4, 'Navy', root)
    arc('ArrayHubRoof', 1.01, 0.53, 0.34, 1.57, 'Armor', root)
    tower(root, (0, 0, 0.97), 0.64, 1.6 + 0.13 * (level - 1))
    for i in range(count):
        a = i * math.tau / count
        start = a + 0.11
        end = a + min(1.15, math.tau / count - 0.20)
        box('PanelRadialSpar', (outer * 0.6 * math.cos(a + 0.36), outer * 0.6 * math.sin(a + 0.36), 0.76), (outer * 1.04, 0.31, 0.37), 'Panel', root, 0.12, a + 0.36)
        arc('IvoryPaddleFrame', outer - 0.64, 2.08, 0.3, 1, 'Armor', root, start=start, end=end)
        arc('BroadTealSolarPane', outer - 0.64, 1.79, 0.13, 1.21, 'Solar', root, start=start + 0.025, end=end - 0.025)
    if level >= 3:
        arc('HubInductionCollar', 1.12, 0.29, 0.33, 1.99, 'Panel', root)
    if level == 5:
        arc('CrownCollector', 0.77, 0.18, 0.2, 3.05, 'Armor', root)
    empty('DockSocket', (0, -1.53, 0.83), root)

def crystal(root, level):
    pad(root, 5.8 + 0.42 * (level - 1), 5.3 + 0.34 * (level - 1))
    cyl('PrismProcessBed', (0, 0, 1.15), 1.54, 0.7, 'Navy', root)
    local_arc('PrismCreamCradle', (0, 0), 1.45, 0.39, 0.35, 1.55, 'Armor', root)
    positions = [(0, 0.1, 0.98, 2.45 + 0.27 * (level - 1))]
    if level >= 2:
        positions.append((-1.9, -0.54, 0.60, 1.83 + 0.1 * (level - 1)))
    if level >= 3:
        positions.append((1.82, -0.63, 0.60, 2.04 + 0.12 * (level - 1)))
    if level >= 4:
        positions.append((0.12, 1.9, 0.42, 1.64 + 0.1 * (level - 1)))
    for x, y, r, height in positions:
        cyl('BilletSocket', (x, y, 1.27), r * 1.22, 0.52, 'Panel', root, 16)
        verts = []
        for zz, rr, phase in [(1.45, r * 0.73, 0), (1.72, r, 0), (1.45 + height * 0.76, r * 0.9, 0.04), (1.45 + height, 0, 0.04)]:
            verts.extend(((x + rr * math.cos(i * math.tau / 6 + phase), y + rr * math.sin(i * math.tau / 6 + phase), zz) for i in range(6)))
        faces = [(row * 6 + i, row * 6 + (i + 1) % 6, (row + 1) * 6 + (i + 1) % 6, (row + 1) * 6 + i) for row in range(3) for i in range(6)]
        surface('FacetedCrystalBillet', verts, faces, 'Crystal', root, False)
        for sign in (-1, 1):
            box('CrystalClamp', (x + sign * r * 0.98, y, 1.75), (0.38, r * 0.93, 0.62), 'Armor', root, 0.1)
    for x in (-2.55, 2.55):
        box('ProcessorUpright', (x, 1.7, 1.67), (0.66, 0.72, 1.42 + 0.12 * (level - 1)), 'Navy', root, 0.18)
        box('ProcessorOuterArmor', (x, 1.7, 1.7), (0.70, 0.5, 1.1 + 0.12 * (level - 1)), 'Armor', root, 0.15)
    box('ProcessingCrosshead', (0, 1.7, 2.40 + 0.12 * (level - 1)), (5.6, 0.78, 0.54), 'Armor', root, 0.24)
    box('CrystalControl', (0, -2.16, 1.48), (2.71, 1.05, 1.08), 'Armor', root, 0.23)
    window('CrystalControlPane', (0, -2.19, 2.1), (1.87, 0.67, 0.19), root)
    if level == 5:
        for sign in (-1, 1):
            box('SecondaryScanner', (sign * 1.93, -0.51, 3.22), (0.61, 0.76, 0.53), 'Panel', root, 0.2)
    empty('DockSocket', (0, -3.24, 1.12), root)

def tank(root, x, y, r, h):
    z = 0.93
    body = lathe('PressureVessel', [(0, z), (r * 0.7, z), (r, z + 0.3), (r, z + h - 0.38), (r * 0.91, z + h - 0.12), (r * 0.58, z + h + 0.19), (0, z + h + 0.25)], 'Pressure', root)
    body.location.x = x
    body.location.y = y
    cap = lathe('PearlPressureCap', [(0, z + h - 0.12), (r * 0.96, z + h - 0.12), (r * 1.01, z + h + 0.03), (r * 0.92, z + h + 0.27), (r * 0.62, z + h + 0.46), (0, z + h + 0.5)], 'Armor', root)
    cap.location.x = x
    cap.location.y = y
    local_arc('BroadPressureCollar', (x, y), r, 0.26, 0.48, z + h * 0.48, 'Armor', root)

def heavy(root, level):
    pad(root, 6.1 + 0.41 * (level - 1), 5.5 + 0.3 * (level - 1))
    positions = [(-1.22, 0, 0.91, 2.43 + 0.17 * (level - 1)), (1.2, 0.42, 0.9, 2.97 + 0.2 * (level - 1))]
    if level >= 2:
        positions.append((0.17, -1.91, 0.61, 1.78 + 0.12 * (level - 1)))
    if level >= 4:
        positions.append((-0.26, 2.02, 0.67, 2.13 + 0.12 * (level - 1)))
    for x, y, r, h in positions:
        tank(root, x, y, r, h)
    pipe('PressureManifold', [(-1.22, -0.83, 1.5), (-1.16, -1.2, 1.2), (0.95, -1.23, 1.2), (1.2, -0.4, 1.57)], 0.18, 'Panel', root)
    box('PressureControlHousing', (-2.38, -1.44, 1.31), (1.11, 1.33, 0.8), 'Armor', root, 0.22)
    window('PressureControlGlazing', (-2.38, -1.44, 1.78), (0.77, 0.87, 0.16), root)
    if level >= 3:
        for x in (-2.67, 2.67):
            box('PressureSafetyRail', (x, 0.27, 1.38), (0.29, 3.3, 0.98), 'Armor', root, 0.14)
            box('RailInset', (x, 0.25, 1.47), (0.31, 2.32, 0.25), 'Navy', root, 0.1)
    if level == 5:
        pipe('HighPressureReturn', [(-1.22, 0.61, 3.58), (-1.22, 1.21, 4.01), (1.2, 1.42, 4.42), (1.2, 0.42, 4.43)], 0.2, 'Panel', root)
        box('ValveBridge', (0, 1.64, 3.43), (3.4, 0.47, 0.34), 'Armor', root, 0.14)
    empty('DockSocket', (0, -3.45, 1.07), root)

def shuttle(root):
    ship_hull(root, (0, -0.02, 0.03), 0.38)
    for x in (-0.47, 0.47):
        box('TransportPod', (x, -0.3, 0.18), (0.32, 0.82, 0.3), 'Panel', root, 0.12)
        box('TransportThrusterPort', (x, -0.72, 0.18), (0.21, 0.06, 0.16), 'Glass', root, 0.025)
    box('CargoBack', (0, -0.27, 0.42), (0.45, 0.51, 0.34), 'Armor', root, 0.14)
    empty('DockSocket', (0, -0.84, 0.24), root)
BUILDERS = dict(zip(FAMILIES, (colony, shipyard, energy, foundry, crystal, heavy)))

def bake_shading(obj):
    """Local eight-ray AO and material tint in portable GLB COLOR_0."""
    mesh = obj.data
    mesh.update()
    tree = BVHTree.FromPolygons([v.co.copy() for v in mesh.vertices], [tuple(p.vertices) for p in mesh.polygons])
    occlusion = []
    for v in mesh.vertices:
        n = v.normal.normalized()
        t = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((0, 1, 0))).normalized()
        b = n.cross(t)
        blocked = 0
        for i in range(8):
            zz = math.sqrt((i + 0.5) / 8)
            rr = math.sqrt(1 - zz * zz)
            a = i * 2.39996323
            d = n * zz + t * (rr * math.cos(a)) + b * (rr * math.sin(a))
            hit, _, _, distance = tree.ray_cast(v.co + n * 0.018, d, 1)
            if hit is not None:
                blocked += 1 - distance
        occlusion.append(1 - 0.38 * blocked / 8)
    attr = mesh.color_attributes.new(name='GalaxyToonAO', type='FLOAT_COLOR', domain='CORNER')
    values = array('f', [0]) * (len(mesh.loops) * 4)
    for face in mesh.polygons:
        mat = mesh.materials[face.material_index]
        color = PALETTE[mat.name.replace('GalaxyToon', '').split('.')[0]][0]
        for idx in face.loop_indices:
            ao = occlusion[mesh.loops[idx].vertex_index]
            for axis in range(3):
                values[idx * 4 + axis] = color[axis] * ao
            values[idx * 4 + 3] = 1
    attr.data.foreach_set('color', values)
    mesh.color_attributes.active_color = attr
    for mat in mesh.materials:
        if not any((n.type == 'VERTEX_COLOR' for n in mat.node_tree.nodes)):
            node = mat.node_tree.nodes.new('ShaderNodeVertexColor')
            node.layer_name = 'GalaxyToonAO'
            mat.node_tree.links.new(node.outputs['Color'], mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])

def export_asset(key, level, builder, no_ao=False):
    """Export one merged static Structure and a bottom-centered DockSocket."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    root = empty(key)
    builder(root)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.context.view_layer.update()
    points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    anchor = Vector(((max((p.x for p in points)) + min((p.x for p in points))) * 0.5, (max((p.y for p in points)) + min((p.y for p in points))) * 0.5, min((p.z for p in points))))
    for child in list(root.children):
        child.location -= anchor
    bpy.context.view_layer.update()
    points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    bounds = [round(max((v[i] for v in points)) - min((v[i] for v in points)), 3) for i in range(3)]
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = 'Structure'
    for frame in [o for o in bpy.context.scene.objects if o.type == 'EMPTY' and o != root and (o.name != 'DockSocket')]:
        bpy.data.objects.remove(frame, do_unlink=True)
    if not no_ao:
        bake_shading(obj)
    triangles = sum((len(p.vertices) - 2 for p in obj.data.polygons))
    relative = f'buildings/{key}/{key}_lv{level}.glb' if level else 'ships/transport_shuttle.glb'
    path = OUT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', export_yup=True, export_cameras=False, export_lights=False, export_animations=False, export_extras=False, export_attributes=True)
    row = {'key': key, 'level': level, 'path': str(path.relative_to(ROOT)), 'bounds_godot_xyz': [bounds[0], bounds[2], bounds[1]], 'triangles': triangles, 'bytes': path.stat().st_size}
    print('GALAXY_ASSET ' + json.dumps(row), flush=True)
    return row

def preview(records, directory, include_core=False):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    rows = list(records)
    if include_core:
        rows.insert(0, {'key': 'galaxy_core', 'level': 0, 'path': 'assets/galaxy/v3/core/galaxy_core.glb'})
    columns = 2 if len(rows) <= 5 else 5
    countrows = math.ceil(len(rows) / columns)
    gap = 12.5
    right = Vector((36, 24, 0)).normalized()
    back = Vector((-24, 36, 0)).normalized()
    elevation = math.sin(math.atan2(41.3, math.sqrt(24 ** 2 + 36 ** 2)))
    for i, row in enumerate(rows):
        bpy.ops.import_scene.gltf(filepath=str(ROOT / row['path']))
        roots = [o for o in bpy.context.selected_objects if o.parent is None]
        for obj in roots:
            if row['key'] == 'galaxy_core':
                obj.scale = (0.4,) * 3
            if row['key'] == 'transport_shuttle':
                obj.scale = (4,) * 3
            obj.location += right * ((i % columns - (columns - 1) * 0.5) * gap) + back * (((countrows - 1) * 0.5 - i // columns) * gap / elevation)
    scene = bpy.context.scene
    bpy.ops.object.camera_add(location=(24, -36, 43))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 1.7)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = max(columns * gap, countrows * gap) * 1.32
    scene.camera = camera
    world = bpy.data.worlds.new('GalaxyReviewWorld')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.028, 0.038, 0.061, 1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.55
    scene.world = world
    for angles, power in [((0.35, -0.50, -0.55), 2.7), ((0.65, 0.40, 2.10), 0.8)]:
        bpy.ops.object.light_add(type='SUN', rotation=angles)
        light = bpy.context.object
        light.data.energy = power
        light.data.angle = 0.32
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 1600 if len(rows) <= 5 else 2400
    scene.render.resolution_y = 1400 if len(rows) <= 5 else max(1200, countrows * 360)
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'AgX'
    directory.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(directory / 'galaxy-toon-lineup.png')
    bpy.ops.render.render(write_still=True)
    (directory / 'lineup-order.json').write_text(json.dumps([{'key': r['key'], 'level': r['level']} for r in rows], indent=2))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--family', nargs='+', choices=FAMILIES, default=list(FAMILIES))
    parser.add_argument('--levels', nargs='+', type=int, choices=range(1, 6), default=list(range(1, 6)))
    parser.add_argument('--preview-dir', type=Path)
    parser.add_argument('--preview-only', action='store_true', help='Render existing filtered GLBs without rebuilding')
    parser.add_argument('--include-core-preview', action='store_true')
    parser.add_argument('--shuttle', action='store_true')
    parser.add_argument('--shuttle-only', action='store_true')
    parser.add_argument('--no-ao', action='store_true', help='Modeling review only; final assets should bake AO')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    if args.preview_only:
        manifest = json.loads((OUT / 'manifest.json').read_text())
        records = [row for row in manifest['assets'] if row['key'] in args.family and row['level'] in args.levels and not args.shuttle_only]
        if args.shuttle or args.shuttle_only:
            records += [row for row in manifest['assets'] if row['key'] == 'transport_shuttle']
        if args.preview_dir:
            preview(records, args.preview_dir, args.include_core_preview)
        return
    materials()
    records = []
    for family in [] if args.shuttle_only else args.family:
        for level in args.levels:
            records.append(export_asset(family, level, lambda r, f=family, l=level: BUILDERS[f](r, l), args.no_ao))
    if args.shuttle or args.shuttle_only:
        records.append(export_asset('transport_shuttle', 0, shuttle, args.no_ao))
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'assets': []}
    changed = {(r['key'], r['level']) for r in records}
    manifest['assets'] = [r for r in manifest['assets'] if (r['key'], r['level']) not in changed] + records
    order = {'galaxy_core': -1, **{key: i for i, key in enumerate(FAMILIES)}, 'transport_shuttle': 10}
    manifest['assets'].sort(key=lambda r: (order.get(r['key'], 99), r['level']))
    manifest.update({'generator': 'tools/galaxy_toon_buildings.py (buildings/shuttle); tools/galaxy_assets_blender.py (core)', 'up_axis': 'Y', 'anchor': 'bottom center'})
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    if args.preview_dir:
        preview(records, args.preview_dir, args.include_core_preview)
if __name__ == '__main__':
    main()
