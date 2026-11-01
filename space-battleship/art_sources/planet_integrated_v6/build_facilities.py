"""Generate four new shared-ring facility forms with the existing animation ports.

Blender X is the orbital tangent for the station, furnace and workshop. The
shipyard uses Blender Y as its tangent and -X as the launch direction. Blender
Z becomes Godot Y on glTF export. No v5 geometry or meshes are imported.
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parents[1] / "assets/planets/facilities_v6"
OUT.mkdir(parents=True, exist_ok=True)


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    colors = {
        "armor": ((.68, .66, .58), .22, .58),
        "edge": ((.49, .50, .46), .25, .52),
        "pressure": ((.055, .15, .20), .22, .64),
        "machinery": ((.12, .29, .36), .26, .53),
        "work": ((.63, .32, .11), .18, .56),
        "signal": ((.92, .39, .09), .14, .46),
        "service": ((.06, .52, .62), .12, .42),
        "glass": ((.035, .22, .32), .28, .39),
    }
    mats = {}
    for name, (rgb, metal, rough) in colors.items():
        m = bpy.data.materials.new("V6 " + name)
        m.use_nodes = True
        m.diffuse_color = (*rgb, 1)
        p = m.node_tree.nodes.get("Principled BSDF")
        p.inputs["Base Color"].default_value = (*rgb, 1)
        p.inputs["Metallic"].default_value = metal
        p.inputs["Roughness"].default_value = rough
        if name in ("service", "signal"):
            p.inputs["Emission Color"].default_value = (*rgb, 1)
            p.inputs["Emission Strength"].default_value = .30
        mats[name] = m
    return mats


def empty(name, parent=None, pos=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = pos
    return obj


def finish(obj, name, mat, parent, bevel=.025):
    obj.name = name
    obj.parent = parent
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    if bevel:
        mod = obj.modifiers.new("Cut armor edge", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def box(name, pos, size, mat, parent, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, bevel)


def beam(name, a, b, width, depth, mat, parent):
    delta = Vector(b) - Vector(a)
    obj = box(name, (Vector(a) + Vector(b)) * .5,
              (width, depth, delta.length), mat, parent, min(width, depth) * .14)
    obj.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    return obj


def cylinder(name, pos, radius, depth, mat, parent, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                        depth=depth, location=pos)
    return finish(bpy.context.object, name, mat, parent, .018)


def cone(name, pos, bottom, top, depth, mat, parent, vertices=24):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=bottom,
                                    radius2=top, depth=depth, location=pos)
    return finish(bpy.context.object, name, mat, parent, .015)


def torus(name, pos, major, minor, mat, parent):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=48, minor_segments=12,
                                    location=pos)
    return finish(bpy.context.object, name, mat, parent, 0)


def ellipsoid(name, pos, radii, mat, parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=pos)
    obj = bpy.context.object
    obj.scale = radii
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, parent, 0)


def loft_x(name, slices, mat, parent, bevel=.025):
    """Chamfered closed load body: (x, center_y, center_z, half_y, half_z)."""
    verts = []
    outline = ((-1,-.68),(-.68,-1),(.68,-1),(1,-.68),
               (1,.68),(.68,1),(-.68,1),(-1,.68))
    for x, cy, cz, hy, hz in slices:
        verts.extend((x, cy + u*hy, cz + v*hz) for u, v in outline)
    faces = [tuple(reversed(range(8)))]
    for section in range(len(slices)-1):
        for i in range(8):
            faces.append((section*8+i, section*8+(i+1)%8,
                          (section+1)*8+(i+1)%8, (section+1)*8+i))
    faces.append(tuple((len(slices)-1)*8+i for i in range(8)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, parent, bevel)


def ring_transition(root, m, half_length=1.18):
    # These four facets continue the ring's broad top and dark lower course.
    for side in (-1, 1):
        loft_x("Shared-ring pressure haunch", [
            (-half_length, side*.68, .14, .16, .21),
            (-.78, side*.73, .19, .25, .32),
            (.78, side*.73, .19, .25, .32),
            (half_length, side*.68, .14, .16, .21),
        ], m["armor"], root)
        box("Continuous dark lower course", (0, side*.86, -.08),
            (1.61, .29, .22), m["pressure"], root)
        box("Outer service seam", (0, side*1.006, .02),
            (1.42, .018, .032), m["service"], root, .005)


def station(root, m):
    ring_transition(root, m, 1.10)
    # A low annular junction opens the orbital tangent instead of raising a box.
    cylinder("Radial bearing lower drum", (0, 0, .23), .91, .29, m["pressure"], root, 40)
    torus("Ivory annular pressure rim", (0, 0, .46), .75, .13, m["armor"], root)
    torus("Blue inner bearing race", (0, 0, .51), .50, .055, m["machinery"], root)
    for x in (-.78, .78):
        beam("Tangential ring transfer rib", (x, -.71, .30),
             (x, .71, .30), .18, .20, m["armor"], root)
    spin = empty("HabitatRingSpin", root, (0, 0, .57))
    torus("Rotating open habitat collar", (0, 0, .12), .42, .075, m["armor"], spin)
    torus("Rotating inner glass", (0, 0, .12), .31, .028, m["glass"], spin)
    cylinder("Circular command lens", (0, 0, .18), .15, .045, m["service"], spin)
    for side, name in ((-1, "SolarHingeLeft"), (1, "SolarHingeRight")):
        hinge = empty(name, root, (0, side*.92, .40))
        box("Folded solar vane", (0, side*.33, 0), (.62, .53, .045), m["machinery"], hinge)
        box("Vane bright root", (0, side*.09, .025), (.49, .07, .045), m["edge"], hinge)


def refinery(root, m):
    ring_transition(root, m, 1.13)
    # The furnace is a horizontal heat vault with exposed paired intakes.
    loft_x("Ring-through furnace vault", [
        (-.94,0,.36,.52,.25),(-.58,0,.46,.69,.35),
        (.63,0,.46,.69,.35),(.95,0,.36,.52,.25),
    ], m["pressure"], root)
    ellipsoid("Single hot pressure crown", (.24,0,.72),(.67,.62,.45),m["work"],root)
    box("Crown receiving lip",(.83,0,.54),(.09,.71,.20),m["edge"],root)
    for side in (-1, 1):
        y = side*.48
        cone("Twin open charge hopper", (-.29,y,1.13), .18,.40,.70,m["work"],root)
        cylinder("Hopper dark receiving mouth", (-.29,y,1.49),.26,.035,m["pressure"],root)
        torus("Hopper armored mouth rim",(-.29,y,1.50),.27,.035,m["armor"],root)
        beam("Hopper pressure duct", (-.29,y,.77),(.20,y,.48),.21,.21,m["edge"],root)
        pivot=empty("IntakeWheelLeft" if side<0 else "IntakeWheelRight",root,(.51,side*.73,.48))
        torus("Exposed intake rotor",(0,0,0),.18,.05,m["armor"],pivot)
        box("Rotor status blade",(0,0,.02),(.28,.045,.04),m["signal"],pivot)
    shutters=empty("CoolingShutters",root,(.67,0,.69))
    for y in (-.38,0,.38):
        box("Heat shutter",(0,y,0),(.30,.19,.07),m["armor"],shutters)
    box("Front receiving aperture",(.91,0,.33),(.055,.68,.28),m["work"],root)
    box("Recessed receiving slit",(.945,0,.34),(.016,.52,.13),m["signal"],root,.004)


def workshop(root,m):
    ring_transition(root,m,1.23)
    # One airy manufacturing gateway: paired low girders, two spanning
    # portals and a visible moving tool, with no enclosing side boxes.
    for side in (-1,1):
        y=side*.68
        loft_x("Continuous manufacturing side girder",[
            (-1.20,y,.46,.15,.20),(-.88,y,.50,.24,.27),
            (.88,y,.50,.24,.27),(1.20,y,.46,.15,.20),
        ],m["work"],root)
        box("Inner running rail",(0,side*.47,.70),(1.69,.085,.08),m["machinery"],root)
        box("Rail power key",(0,side*.42,.75),(1.38,.018,.03),m["service"],root,.004)
    for x in (-.88,.88):
        for side in (-1,1):
            beam("Inclined portal load leg",(x,side*.75,.47),
                 (x,side*.68,1.25),.17,.18,m["armor"],root)
        beam("Open portal overhead truss",(x,-.72,1.28),
             (x,.72,1.28),.13,.16,m["work"],root)
    gantry=empty("GantrySlide",root,(0,0,0))
    box("Sliding bridge",(0,0,1.20),(.39,1.16,.11),m["machinery"],gantry)
    arm=empty("ToolArmSweep",gantry,(0,0,1.16))
    beam("Downward work tool",(0,0,0),(0,0,-.56),.14,.16,m["edge"],arm)
    box("Active manufacturing jaw",(0,0,-.60),(.27,.33,.10),m["service"],arm)


def shipyard(root,m):
    # Local Y is the ring tangent and local -X is the radial launch direction.
    for side in (-1,1):
        y=side*.72
        loft_x("Ring-to-dock continuous fork",[
            (-2.42,y,.35,.13,.17),(-2.05,y,.37,.21,.23),
            (-.54,y,.38,.25,.27),(.48,y,.35,.22,.25),
            (.91,y,.25,.13,.16),
        ],m["armor"],root)
        loft_x("Fork dark understructure",[
            (-2.23,y,.17,.12,.12),(-.52,y,.16,.19,.16),
            (.56,y,.15,.17,.14),
        ],m["pressure"],root)
        box("Launch rail channel",(-1.25,side*.52,.53),(2.08,.045,.035),m["service"],root,.006)
        beam("Pressure fork return brace",(-.47,y,.20),(.57,side*.78,.47),.16,.17,m["machinery"],root)
    for x in (-1.99,-.39):
        beam("Dock open overhead portal",(x,-.77,1.02),(x,.77,1.02),.14,.16,m["work"],root)
        for side in (-1,1):
            beam("Dock portal riser",(x,side*.76,.40),(x,side*.76,1.02),.13,.15,m["armor"],root)
    shuttle=empty("Docked small craft",root,(-.76,0,.18))
    loft_x("Shuttle new tapered hull",[
        (-2.36,0,.65,.04,.06),(-1.95,0,.64,.17,.12),
        (-1.25,0,.66,.26,.17),(-.75,0,.64,.19,.12),
    ],m["armor"],shuttle)
    loft_x("Shuttle glass canopy",[
        (-1.92,0,.79,.09,.035),(-1.56,0,.84,.16,.07),
        (-1.22,0,.80,.13,.04),
    ],m["glass"],shuttle)
    for side in (-1,1):
        box("Shuttle sweep wing",(-1.13,side*.27,.59),(.57,.35,.055),m["edge"],shuttle)
        box("Shuttle engine",(-.70,side*.19,.63),(.07,.12,.11),m["service"],shuttle,.008)
    crane=empty("CraneSlide",root)
    box("Open moving hoist",(-1.18,.76,1.10),(.26,.23,.12),m["machinery"],crane)
    beam("Hoist arm",(-1.18,.76,1.08),(-1.58,.76,.76),.09,.09,m["work"],crane)
    collar=empty("DockCollarSpin",root,(-1.65,0,.66))
    torus("Dock rotating collar",(0,0,0),.21,.055,m["machinery"],collar)


BUILDERS = {"auto_explore":station,"refinery":refinery,
            "equipment":workshop,"shipyard":shipyard}
for kind, build in BUILDERS.items():
    mats=setup()
    root=empty("Facility")
    build(root,mats)
    bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / (kind + ".blend")),compress=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in (root,*root.children_recursive): obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT / (kind + ".glb")),
                              export_format="GLB",use_selection=True,
                              export_animations=False,export_cameras=False,
                              export_lights=False,export_yup=True)
