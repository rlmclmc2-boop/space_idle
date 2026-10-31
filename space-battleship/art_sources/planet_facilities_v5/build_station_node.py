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


ivory = material("Station warm load armor", (.74, .68, .55))
edge = material("Station bevel shadow", (.48, .48, .44))
navy = material("Station deep pressure hull", (.035, .105, .15))
lower_steel = material("Station lower load steel", (.11, .22, .27))
blue = material("Station blue structural steel", (.08, .22, .29))
cyan = material("Station inset cyan power", (.04, .56, .64), emission=.32)
amber = material("Station amber beacons", (.91, .42, .11), emission=.42)
ochre = material("Station warm equipment plating", (.58, .31, .12))


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
        (-1.22,y,-.27,.27,.18), (-.93,y,-.27,.37,.23),
        (.93,y,-.27,.37,.23), (1.22,y,-.27,.27,.18),
    ], lower_steel, root)
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
        # The end-on view exposes the through-node pressure cheeks. Armoring
        # their outer end faces makes each inlet read as a framed load socket.
        box("Portal end pressure armor", (end*1.195,side*.80,.20),
            (.075,.43,.83), ochre, root, .045)
        box("Portal end ivory spine", (end*1.238,side*.80,.34),
            (.027,.34,.11), ivory, root, .009)
        box("Portal end recessed slot", (end*1.238,side*.80,-.07),
            (.028,.22,.065), blue, root, .007)
        box("Portal lower pressure end cap", (end*1.248,side*.76,-.36),
            (.085,.46,.33), ivory, root, .035)
        box("Portal lower end cap service inset", (end*1.297,side*.76,-.36),
            (.018,.23,.11), ochre, root, .006)
        beam("Portal lower diagonal load heel", (end*.93,side*.99,-.15),
             (end*1.17,side*.88,-.51), .13,.12, ivory, root)
        # The side silhouette descends as a faceted pressure gusset into the
        # curved deck node. Its inner edge stops at the existing load cheek;
        # the central passage and independently owned arc remain exposed.
        gusset_sections = [
            (end*.68,side*.93,-.34,.10,.19),
            (end*.91,side*.96,-.39,.17,.27),
            (end*1.18,side*.92,-.43,.13,.23),
        ]
        loft("Portal lower faceted load gusset",
             gusset_sections if end > 0 else list(reversed(gusset_sections)), ivory, root)
        box("Portal gusset blue bearing key", (end*.96,side*1.115,-.36),
            (.18,.018,.12), blue, root, .007)
        beam("Portal inner chamfer load lining", (end*1.12,side*.47,-.23),
             (end*.93,side*.49,.94), .17,.13, ivory, root)
        box("Portal inner warm pressure socket", (end*1.15,side*.46,-.19),
            (.18,.16,.17), ochre, root, .021)
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
    # The lower pressure cheek is an exposed load hull, not an empty dark
    # skirt. Stepped armor bays cross its full length and taper into the four
    # portal feet while keeping the central ring passage clear.
    for x in (-.77, -.26, .26, .77):
        loft("Lower stepped pressure bay", [
            (x-.21,side*1.085,-.31,.082,.15),
            (x-.15,side*1.13,-.32,.10,.18),
            (x+.15,side*1.13,-.32,.10,.18),
            (x+.21,side*1.085,-.31,.082,.15),
        ], ivory, root)
        box("Lower bay ochre core", (x,side*1.236,-.34),
            (.25,.018,.12), ochre, root, .008)
        box("Lower bay cyan inspection light", (x,side*1.247,-.25),
            (.13,.014,.025), cyan, root, .004)
    for x in (-.51,0,.51):
        beam("Lower bay pressure web", (x,side*1.17,-.14),
             (x,side*1.17,-.53), .075,.09, blue, root)
    # The exposed mouth previously read as one black void under the command
    # deck. These two stepped inner cheeks continue the real pressure wall
    # toward the ring deck, while leaving its central transit channel open.
    loft("Portal throat stepped inner armor", [
        (-1.18,side*.37,.14,.20,.40),
        (-.82,side*.34,.15,.21,.43),
        (.82,side*.34,.15,.21,.43),
        (1.18,side*.37,.14,.20,.40),
    ], ivory, root)
    box("Portal throat recessed service way", (0,side*.375,.08),
        (1.79,.028,.055), blue, root, .009)
    for x in (-.79,0,.79):
        box("Portal throat amber load key", (x,side*.388,.10),
            (.17,.018,.045), amber, root, .006)
    # Faceted service armor grows out of the real pressure wall. The slanted
    # load ribs lead into the buried shoe and keep the ring passage open.
    for x in (-.70, -.23, .23, .70):
        box("Lower pressure armor cassette", (x,side*1.112,.045),
            (.37,.105,.30), ochre, root, .028)
        box("Cassette upper lip", (x,side*1.124,.205),
            (.36,.12,.065), ivory, root, .012)
        box("Cassette inspection inset", (x,side*1.178,.045),
            (.20,.018,.075), blue, root, .006)
    for x in (-.81,.81):
        beam("Diagonal outer load rib", (x,side*1.145,.55),
             (x*1.22,side*1.13,-.30), .12,.10, ivory, root)
        box("Lower load rib heel", (x*1.22,side*1.13,-.31),
            (.23,.15,.13), ochre, root, .016)
    for x in (-.65,-.22,.22,.65):
        box("Warm cheek armor tile", (x,side*1.005,.74), (.31,.06,.24),
            ivory if abs(x) < .4 else ochre,root,.016)
        box("Cheek recessed service slot", (x,side*1.038,.36), (.21,.022,.06),navy,root,.007)

for end in (-1, 1):
    x = end * 1.03
    beam("Cross portal armored lintel", (x,-.76,1.16),
         (x,.76,1.16), .24,.26, ivory, root)
    box("Open passage soffit", (x,0,1.03), (.10,.91,.06), navy, root, .01)
    # A second, recessed compression arch lowers the apparent black crown of
    # the inlet while maintaining clear height above the deck transit path.
    beam("Recessed portal compression arch", (x,-.43,.84),
         (x,.43,.84), .15,.13, ivory, root)
    box("Compression arch blue underside", (x,0,.76),
        (.095,.58,.035), blue, root, .008)
    # Close the command hull's upper shadow with a structural header. The
    # ring deck remains visible through the lower, independently owned slot.
    box("Portal upper pressure header", (x,0,.70),
        (.20,.60,.26), ivory, root, .035)
    # A shallow faceted arch makes the inlet's bearing frame legible from
    # oblique views without capping the open passage or masking the ring.
    for side in (-1, 1):
        beam("Portal chamfered upper bearing", (x,side*.52,.86),
             (x,side*.25,1.12), .13,.12, ivory, root)
        # A lower diagonal carries the inner throat into its actual deck-side
        # pressure shoe while preserving a central open transit slot.
        beam("Portal lower inner bearing", (x,side*.43,-.15),
             (x,side*.21,.59), .18,.15, ivory, root)
    for side in (-1, 1):
        box("Corner amber status", (x,side*.75,1.31), (.11,.11,.06), amber, root, .014)

# This elevated observation block is carried by both longitudinal walls.
# It has an actual underside above the channel and a small central dock.
loft("Station elevated command hull", [
    (-.70,0,1.34,.74,.20),(-.45,0,1.54,.88,.27),
    (.45,0,1.54,.88,.27),(.70,0,1.34,.74,.20),
], navy, root)
# The real load walls carry a broad, shallow command pressure saucer. Its
# annular edge links the observation crown to those walls without a loose pod.
cylinder("Command load saucer", (0,0,1.44), 1.04,.18, blue, root, 48)
bpy.ops.mesh.primitive_torus_add(major_radius=1.00, minor_radius=.055,
                                major_segments=48, minor_segments=8,
                                location=(0,0,1.43))
finish(bpy.context.object, "Command saucer ivory pressure seam", ivory, root, 0)
for angle_index in range(8):
    a=angle_index*math.tau/8
    box("Saucer amber service port", (.99*math.cos(a),.99*math.sin(a),1.49),
        (.08,.08,.045), amber, root, .007)
box("Command deck crown armor", (0,0,1.78), (.92,1.15,.16), ivory, root, .055)
for x in (-.36,0,.36):
    box("Crown service rib", (x,0,1.875), (.11,.81,.035),ochre,root,.008)
for side in (-1, 1):
    box("Command bridge glazing", (0,side*.82,1.51), (.83,.03,.22), cyan, root, .012)
    for x in (-.29,0,.29):
        box("Bridge frame", (x,side*.85,1.51), (.035,.045,.30), edge, root, .005)
    # Four roof service clusters are fastened to the two load walls below the
    # turning annulus. Their broad dark tops remain legible at page scale.
    for x in (-.57,.57):
        box("Wall borne avionics block", (x,side*1.04,1.27),
            (.43,.34,.35),blue,root,.035)
        box("Avionics ivory upper armor", (x,side*1.04,1.47),
            (.47,.38,.075),ivory,root,.02)
        box("Avionics dark top inset", (x,side*1.04,1.52),
            (.30,.23,.024),navy,root,.008)
        box("Avionics cyan guide", (x,side*1.235,1.30),
            (.21,.018,.055),cyan,root,.006)
        box("Avionics amber status", (x,side*1.04,1.55),
            (.08,.08,.035),amber,root,.009)

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
