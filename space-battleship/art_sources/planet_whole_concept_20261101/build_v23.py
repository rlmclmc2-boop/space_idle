"""Standalone authored orbital architecture concept. No existing facility mesh import."""
from pathlib import Path
from math import sin, cos, pi, tau
import random
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
GAME = HERE.parents[1]
OUT = HERE / "concept-v23.png"
# The approved drawing keeps the planet size but places a fine guideway well
# outside it. All globally authored arcs share this radial offset.
ORBIT_SHIFT = 2.43
RING_RADIUS = 4.33 + ORBIT_SHIFT
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, metallic=.0, rough=.68, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


ARMOR = material("Warm faceted ivory armor", (.68,.64,.54), .05, .74)
ARMOR_FACE = material("Lit ivory armor facets", (.94,.87,.73), .04, .78)
ARMOR_SIDE = material("Recessed slate armor flanks", (.10,.17,.21), .09, .78)
ARMOR_MID = material("Midtone faceted pressure armor", (.40,.46,.45), .05, .78)
EDGE = material("Dark slate panel edge", (.085,.13,.16), .16, .75)
KEEL = material("Deep navy pressure keel", (.012,.035,.055), .10, .80)
MACHINE = material("Machine steel", (.043,.095,.115), .10, .72)
GLASS = material("Dark blue glass", (.025,.16,.22), .26, .34)
WINDOW = material("Habitat cyan window glass", (.025,.34,.43), .08, .50, .42)
CYAN = material("Contained cyan energy", (.025,.65,.84), .08, .40, 1.8)
AMBER = material("Contained amber heat", (.68,.21,.025), .04, .55, .65)
GOLD = material("Warm work marking", (.70,.40,.09), .24, .56)
CRANE_ORANGE = material("Factory safety orange machine enamel", (.90,.35,.035), .16, .55, .12)
DOME_GOLD = material("Heat chamber faceted gold armor", (.90,.56,.20), .20, .58)
DOME_SHADE = material("Heat dome recessed bronze facets", (.70,.39,.10), .24, .60)
DOME_LIGHT = material("Heat dome sunward gold facets", (1.0,.68,.20), .18, .50)
DOME_SEAM = material("Heat dome panel shadow seam", (.34,.16,.04), .18, .62)


def parent(name, xyz=(0,0,0), angle=0):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = xyz
    o.rotation_euler.z = angle
    return o


def finish(obj, name, mat, root=None, bevel=0):
    obj.name = name
    obj.data.materials.append(mat)
    if root: obj.parent = root
    bpy.context.view_layer.objects.active = obj
    if bevel:
        mod = obj.modifiers.new("Authored chamfer", 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    normal = obj.modifiers.new("Weighted planar normals", 'WEIGHTED_NORMAL')
    bpy.ops.object.modifier_apply(modifier=normal.name)
    return obj


def box(name, pos, size, mat, root=None, bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(obj, name, mat, root, bevel)
    if mat == ARMOR and size[0] > .55 and size[1] > .24 and size[2] < .75:
        armor_facets(obj)
    obj.location = pos
    return obj


def beam(name, start, end, width, depth, mat, root=None):
    a, b = Vector(start), Vector(end)
    if mat == ARMOR:
        width *= .84
        depth *= .84
    obj = box(name, (a+b)*.5, (width,depth,(b-a).length), mat, root, min(width,depth)*.16)
    obj.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    return obj


def cyl(name, pos, radius, depth, mat, root=None, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth)
    obj = finish(bpy.context.object, name, mat, root, .018)
    obj.location = pos
    return obj


def cone(name, pos, bottom, top, depth, mat, root=None, vertices=12):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=bottom, radius2=top, depth=depth)
    obj = finish(bpy.context.object, name, mat, root, .018)
    obj.location = pos
    return obj


def torus(name, pos, major, minor, mat, root=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                    major_segments=48, minor_segments=8)
    obj = finish(bpy.context.object, name, mat, root)
    obj.location = pos
    return obj


def faceted_dome(name, root, center, rings, sides=12):
    """Triangulated, stepped crown with individually lit armor facets."""
    verts=[]
    for height,radius in rings:
        for i in range(sides):
            a=tau*i/sides
            verts.append((center[0]+radius*cos(a),center[1]+radius*sin(a),height))
    faces=[]
    for band in range(len(rings)-1):
        for i in range(sides):
            j=(i+1)%sides
            a=band*sides+i; b=band*sides+j
            c=(band+1)*sides+j; d=(band+1)*sides+i
            faces.extend(((a,b,c),(a,c,d)))
    faces.append(tuple((len(rings)-1)*sides+i for i in range(sides)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj=finish(obj,name,DOME_GOLD,root)
    obj.data.materials.append(DOME_SHADE)
    obj.data.materials.append(DOME_LIGHT)
    for i,face in enumerate(obj.data.polygons):
        if i >= (len(rings)-1)*sides*2:
            face.material_index=0
            continue
        band=i//(sides*2); sector=(i//2)%sides
        face.material_index = 1 if (sector+band)%5==0 else 2 if (sector+band)%4==0 else 0
    return obj


def annular_band(name, inner, outer, zlo, zhi, mat, begin=0, end=tau, n=128):
    verts=[]
    for i in range(n+1):
        a=begin+(end-begin)*i/n
        for r,z in ((inner,zhi),(outer,zhi),(inner,zlo),(outer,zlo)):
            verts.append((r*cos(a),r*sin(a),z))
    faces=[]
    for i in range(n):
        j=4*i
        faces.extend(((j,j+4,j+5,j+1),(j+2,j+3,j+7,j+6),
                      (j,j+2,j+6,j+4),(j+1,j+5,j+7,j+3)))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    finish(obj,name,mat)
    return obj


def armor_prism(name, outline, bottom, top, mat, root=None):
    """One thick faceted load/pressure plate; outline is authored in node space."""
    count=len(outline)
    vertices=[(x,y,z) for z in (bottom,top) for x,y in outline]
    faces=[tuple(range(count-1,-1,-1)),tuple(range(count,2*count))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    obj=finish(obj,name,mat,root,.025)
    return armor_facets(obj) if mat == ARMOR else obj


def slope_shell(name, outline, top_heights, thickness, mat, root=None):
    """One continuous angled armor plate with an authored roof plane."""
    count=len(outline)
    assert count == len(top_heights)
    vertices=[(x,y,z-thickness) for (x,y),z in zip(outline,top_heights)]
    vertices += [(x,y,z) for (x,y),z in zip(outline,top_heights)]
    faces=[tuple(range(count-1,-1,-1)),tuple(range(count,2*count))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj=finish(obj,name,mat,root,.025)
    return armor_facets(obj) if mat == ARMOR else obj


def wall_prism(name, outline_xz, near_y, far_y, mat, root=None):
    """Faceted vertical pressure wall or load gusset with a real dark side."""
    count=len(outline_xz)
    verts=[(x,y,z) for y in (near_y,far_y) for x,z in outline_xz]
    faces=[tuple(range(count-1,-1,-1)),tuple(range(count,2*count))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish(obj,name,mat,root,.018)


def armor_facets(obj):
    """Color the broad upper armor plane separately from its load-bearing flanks."""
    obj.data.materials.append(ARMOR_FACE)
    obj.data.materials.append(ARMOR_SIDE)
    for polygon in obj.data.polygons:
        polygon.material_index = 1 if polygon.normal.z > .45 else 2
    return obj


# A single occupied upper crescent is split at the independent construction
# seam. Each facility owns its load-bearing portion of the shared section.
def owned_arc(root, name, begin, end, inner, outer, bottom, top, mat):
    inner += ORBIT_SHIFT
    outer += ORBIT_SHIFT
    bpy.context.view_layer.update()
    inverse = root.matrix_world.inverted()
    steps = max(16, int(abs(end-begin)*2))
    vertices = []
    for i in range(steps+1):
        angle_degrees = begin+(end-begin)*i/steps
        angle = angle_degrees*pi/180
        # The approved guideway is a single planar ellipse through all nodes.
        rise = 0.0
        for radius,z in ((inner,top),(outer,top),(inner,bottom),(outer,bottom)):
            vertices.append(tuple(inverse @ Vector((radius*cos(angle),radius*sin(angle),z+rise))))
    faces=[]
    for i in range(steps):
        j=i*4
        faces.extend(((j,j+1,j+5,j+4),(j+2,j+6,j+7,j+3),
                      (j,j+4,j+6,j+2),(j+1,j+3,j+7,j+5)))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    return finish(obj,name,mat,root)


def curved_shell(root, name, begin, end, inner, outer, bottom, top, mat):
    """Tapered pressure hull whose roof, walls and floor all follow one arc."""
    bpy.context.view_layer.update()
    inverse = root.matrix_world.inverted()
    steps = max(24, int(abs(end-begin)*3))
    vertices=[]
    center=(inner+outer)*.5
    for i in range(steps+1):
        t=i/steps
        edge=max(0,min(1,t/.16,(1-t)/.16))
        edge=edge*edge*(3-2*edge)
        angle_degrees=begin+(end-begin)*t
        angle=angle_degrees*pi/180
        rise=.68*sin(pi*(angle_degrees-25)/130) if 25<=angle_degrees<=155 else 0
        rin=center-.19+(inner-center+.19)*edge
        rout=center+.19+(outer-center-.19)*edge
        high=bottom+.18+(top-bottom-.18)*edge
        for radius,z in ((rin,high+.06),(rout,high-.07),(rin,bottom),(rout,bottom)):
            vertices.append(tuple(inverse @ Vector((radius*cos(angle),radius*sin(angle),z+rise))))
    faces=[]
    for i in range(steps):
        j=i*4
        faces.extend(((j,j+1,j+5,j+4),(j+2,j+6,j+7,j+3),
                      (j,j+4,j+6,j+2),(j+1,j+3,j+7,j+5)))
    faces.extend(((0,1,3,2),tuple(range(steps*4,steps*4+4))))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    obj=finish(obj,name,mat,root)
    return armor_facets(obj) if mat==ARMOR else obj


def root_at(name,degrees):
    angle=degrees*pi/180
    return parent(name,(RING_RADIUS*cos(angle),RING_RADIUS*sin(angle),.03),angle+pi/2)


# A variable-section architectural band. Four ownership roots hold different
# portions of one continuous mass, while the open dock is cut out of its band.
# The whole-band profile, not a row of facility boxes, determines the silhouette.
def arc_profile(angle):
    keys = [
        (-205,4.18,4.67,.39),(-190,4.08,4.92,.53),
        (-175,4.06,5.04,.61),
        (-160,4.20,4.57,.35),(-151,4.10,5.08,.69),
        (-138,3.98,5.42,.80),(-122,4.03,5.37,.76),
        (-109,4.11,4.91,.51),(-94,4.17,4.70,.40),
        (-78,4.14,4.76,.44),(-67,4.08,4.98,.58),
        (-57,3.94,5.27,1.08),(-42,3.92,5.40,1.37),
        (-29,3.99,5.17,1.08),(-20,4.10,4.94,.53),
        (0,4.06,5.06,.60),(25,4.12,4.98,.54),(34,4.12,5.02,.62),
        (45,3.96,5.43,1.14),(57,3.96,5.46,1.19),
        (68,4.10,5.02,.73),(75,4.16,4.87,.58),
        (86,4.10,5.02,.73),(102,3.92,5.47,1.24),
        (119,3.91,5.61,1.42),(134,4.02,5.36,1.09),
        (148,4.12,4.87,.60),(155,4.18,4.67,.39)]
    for left,right in zip(keys,keys[1:]):
        if left[0] <= angle <= right[0]:
            t=(angle-left[0])/(right[0]-left[0])
            t=t*t*(3-2*t)
            return tuple(a+(b-a)*t for a,b in zip(left[1:],right[1:]))
    return keys[0][1:] if angle < keys[0][0] else keys[-1][1:]


def profiled_band(root,name,begin,end,roof_shift=0,inner_shift=0,outer_shift=0,mat=ARMOR):
    bpy.context.view_layer.update()
    inverse=root.matrix_world.inverted()
    steps=max(12,int((end-begin)*2))
    verts=[]
    for i in range(steps+1):
        angle_deg=begin+(end-begin)*i/steps
        a=angle_deg*pi/180
        rin,rout,roof=arc_profile(angle_deg)
        rin+=inner_shift; rout+=outer_shift; roof+=roof_shift
        radius_mid=(rin+rout)*.5
        rise=.68*sin(pi*(angle_deg-25)/130) if 25<=angle_deg<=155 else 0
        for r,z in ((rin,roof-.12),(radius_mid,roof+.04),(rout,roof-.17),
                    (rin,.18),(radius_mid,-.16),(rout,.18)):
            verts.append(tuple(inverse @ Vector((r*cos(a),r*sin(a),z+rise))))
    faces=[]
    roof_faces=[]
    for i in range(steps):
        j=i*6
        faces.extend(((j,j+6,j+7,j+1),(j+1,j+7,j+8,j+2),
                      (j,j+3,j+9,j+6),(j+2,j+8,j+11,j+5),
                      (j+3,j+4,j+10,j+9),(j+4,j+5,j+11,j+10)))
        roof_faces.extend((len(faces)-6,len(faces)-5))
    faces.extend((tuple(range(5,-1,-1)),tuple(range(steps*6,steps*6+6))))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj=finish(obj,name,mat,root)
    if mat==ARMOR:
        obj.data.materials.append(ARMOR_FACE)
        obj.data.materials.append(ARMOR_SIDE)
        for index,poly in enumerate(obj.data.polygons):
            poly.material_index=1 if index in roof_faces else 2
    return obj


def deck_plate(root, begin, end):
    """A shallow, planar-feeling armor tile over the continuous pressure hull."""
    bpy.context.view_layer.update()
    inverse=root.matrix_world.inverted()
    steps=max(3,int((end-begin)*1.4))
    verts=[]
    for i in range(steps+1):
        degrees=begin+(end-begin)*i/steps
        a=degrees*pi/180
        rin,rout,roof=arc_profile(degrees)
        mid=(rin+rout)*.5
        rise=.68*sin(pi*(degrees-25)/130) if 25<=degrees<=155 else 0
        for thickness in (0,-.055):
            for r,z in ((rin+.10,roof-.12),(mid,roof+.04),(rout-.10,roof-.17)):
                verts.append(tuple(inverse @ Vector((r*cos(a),r*sin(a),z+rise+.045+thickness))))
    faces=[]
    for i in range(steps):
        j=i*6
        faces.extend(((j,j+6,j+7,j+1),(j+1,j+7,j+8,j+2),
                      (j+3,j+4,j+10,j+9),(j+4,j+5,j+11,j+10),
                      (j,j+3,j+9,j+6),(j+2,j+8,j+11,j+5)))
    faces.extend((tuple(range(5,-1,-1)),tuple(range(steps*6,steps*6+6))))
    mesh=bpy.data.meshes.new("Continuous deck armor tile")
    mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new("Continuous deck armor tile",mesh)
    bpy.context.collection.objects.link(obj)
    obj=finish(obj,obj.name,ARMOR_FACE,root)
    obj.data.materials.append(ARMOR_SIDE)
    for i,face in enumerate(obj.data.polygons):
        face.material_index = 1 if i%6 in (2,3,4,5) else 0
    return obj


def profiled_outer_ribbon(root,name,begin,end):
    """A thin contained service light follows the real outer hull profile."""
    bpy.context.view_layer.update()
    inverse=root.matrix_world.inverted()
    steps=max(12,int((end-begin)*2))
    verts=[]
    for i in range(steps+1):
        degrees=begin+(end-begin)*i/steps
        a=degrees*pi/180
        radius=arc_profile(degrees)[1]+.018
        rise=.68*sin(pi*(degrees-25)/130) if 25<=degrees<=155 else 0
        for z in (.32,.36):
            verts.append(tuple(inverse @ Vector((radius*cos(a),radius*sin(a),z+rise))))
    faces=[(2*i,2*i+2,2*i+3,2*i+1) for i in range(steps)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish(obj,name,CYAN,root)

# The twin track has a compact structural web, two pale rail heads and a
# restrained cyan guide. The four exported ownership roots below carry their
# own stretches; this global copy appears only in the Blender concept.
annular_band("Dark continuous track web",RING_RADIUS-.105,RING_RADIUS+.105,-.09,.055,KEEL)
for radial in (-.085,.085):
    annular_band("Ivory rail head",RING_RADIUS+radial-.021,RING_RADIUS+radial+.021,.055,.125,ARMOR_FACE)
annular_band("Contained track guide",RING_RADIUS-.011,RING_RADIUS+.011,.075,.105,CYAN)
for i in range(32):
    a=i*tau/32
    annular_band("Track pressure clamp",RING_RADIUS-.135,RING_RADIUS+.135,-.10,.15,ARMOR_SIDE,a-.008,a+.008,2)

station=root_at("01 / Command district of the orbital city",140)
station.location.z=-.95
refinery=root_at("02 / Heat district of the orbital city",35)
refinery.location.z=-.93
workshop=root_at("03 / Manufacturing district of the orbital city",-43)
shipyard=root_at("04 / Open launch district of the orbital city",-130)

# Every facility exports its own closed section of the shared fine guideway.
# The local functional bays below carry the large building masses.
for root,lo,hi in ((refinery,25,75),(station,75,155),
                   (workshop,-65,25),(shipyard,-205,-65)):
    owned_arc(root,"Fine orbital pressure web",lo,hi,4.225,4.435,-.09,.055,KEEL)
    for radial in (-.085,.085):
        owned_arc(root,"Fine ivory rail head",lo,hi,
                  4.33+radial-.021,4.33+radial+.021,.055,.125,ARMOR_FACE)
    owned_arc(root,"Orbital tram guide",lo,hi,4.319,4.341,.075,.105,CYAN)
    for degree in range(lo+10,hi,18):
        owned_arc(root,"Orbital track joint clamp",degree-.5,degree+.5,
                  4.195,4.465,-.10,.16,ARMOR_SIDE)

# Local pressure floors under the large work nodes, distinct from the guideway.
owned_arc(shipyard,"Dock open bay inner transfer floor",-138,-122,
          4.17,4.68,.18,.34,MACHINE)
bpy.context.view_layer.update()
front_node = shipyard.matrix_world.inverted() @ Vector((0,-(4.47+ORBIT_SHIFT),.60))
cyl("Low flush front attitude collar",front_node,.18,.10,EDGE,shipyard,10)
front_core = shipyard.matrix_world.inverted() @ Vector((0,-(4.47+ORBIT_SHIFT),.66))
cyl("Front attitude cyan inset",front_core,.075,.025,CYAN,shipyard,10)

# The observation platform bears down onto the actual guideway; no second
# unsupported ribbon floats between the station and its owned track section.
cyl("Command dark structural foundation",(0,-.32,1.22),1.25,.28,KEEL,station,12)
cyl("Command lower faceted load deck",(0,-.32,1.35),1.20,.14,ARMOR_SIDE,station,12)
cyl("Command stepped ivory observation deck",(0,-.32,1.48),1.11,.15,ARMOR,station,12)
torus("Command continuous observation sill",(0,-.32,1.52),1.04,.06,ARMOR_FACE,station)
cyl("Command lower occupied tier dark hull",(0,-.32,1.66),1.055,.22,KEEL,station,12)
torus("Command lower occupied tier upper sill",(0,-.32,1.78),1.06,.055,ARMOR_FACE,station)
for i in range(12):
    a=i*tau/12
    x=1.11*cos(a); y=-.32+1.11*sin(a)
    window=box("Command observation window bay",(x,y,1.66),(.30,.095,.16),WINDOW,station,.01)
    window.rotation_euler.z=a+pi/2
    if i%3==0:
        pylon=box("Command exterior armor buttress",(1.21*cos(a),-.32+1.21*sin(a),1.29),
                  (.17,.22,.37),ARMOR,station,.02)
        pylon.rotation_euler.z=a
for side in (-1,1):
    for radial in (-1,1):
        box("Command through-track armored socket cheek",
            (side*1.19,radial*.33,1.13),(.43,.23,.66),ARMOR,station)
        box("Command socket shadow inset",
            (side*1.42,radial*.25,1.09),(.045,.14,.34),KEEL,station,.008)
    box("Command through-track overhead lintel",
        (side*1.19,0,1.48),(.44,.89,.15),ARMOR_SIDE,station)
    box("Command socket cyan guidance notch",
        (side*1.39,0,1.46),(.035,.14,.045),CYAN,station,.004)
cyl("Command rotating bearing",(0,-.32,1.60),.72,.16,EDGE,station,10)
torus("Command bearing cyan collar",(0,-.32,2.19),.62,.045,CYAN,station)
cyl("Command second occupied tier dark hull",(0,-.32,1.94),.78,.30,KEEL,station,12)
torus("Command second tier lower pressure rim",(0,-.32,1.79),.80,.055,ARMOR_FACE,station)
torus("Command second tier upper ivory sill",(0,-.32,2.10),.80,.055,ARMOR_FACE,station)
for i in range(12):
    a=i*tau/12
    x=.785*cos(a);y=-.32+.785*sin(a)
    window=box("Command upper-tier occupied window",(x,y,1.95),
               (.29,.055,.16),WINDOW,station,.006)
    window.rotation_euler.z=a+pi/2
    if i%3==0:
        rib=box("Command upper-tier load pier",(.82*cos(a),-.32+.82*sin(a),1.94),
                (.10,.11,.30),ARMOR_FACE,station,.008)
        rib.rotation_euler.z=a+pi/2
cyl("Command upper observation cap",(0,-.32,2.15),.67,.10,ARMOR,station,12)
cone("Command faceted core",(0,-.32,2.31),.45,.20,.29,ARMOR,station,8)
cyl("Command blue canopy",(0,-.32,2.48),.23,.09,GLASS,station,8)
cone("Command short beacon",(0,-.32,2.63),.10,.02,.20,ARMOR,station,8)
beam("Command tall navigation mast",(.12,-.32,2.66),(.12,-.32,3.21),.055,.055,ARMOR_SIDE,station)
cyl("Command mast amber signal",(.12,-.32,3.23),.055,.09,AMBER,station,8)
for side in (-1,1):
    beam("Command secondary bearing mast",(side*.75,-.32,2.14),
         (side*.75,-.32,2.61),.045,.045,ARMOR_SIDE,station)
    cyl("Command secondary amber signal",(side*.75,-.32,2.63),
        .045,.075,AMBER,station,8)

# Heat is a working aperture in the band, marked by a low furnace clamp.
cyl("Heat chamber dark integrated foundation",(0,-.32,1.06),1.27,.25,KEEL,refinery,12)
cyl("Heat chamber lower armored ring deck",(0,-.32,1.22),1.21,.14,ARMOR,refinery,12)
torus("Heat chamber recessed observation band",(0,-.32,1.32),1.13,.07,GLASS,refinery)
for i in range(16):
    a=(i+.5)*tau/16
    window=box("Heat chamber skirt blue occupied window",
               (1.165*cos(a),-.32+1.165*sin(a),1.31),
               (.14,.048,.11),WINDOW,refinery,.006)
    window.rotation_euler.z=a+pi/2
    if i%4==0:
        pier=box("Heat chamber skirt armor pier",
                 (1.18*cos(a),-.32+1.18*sin(a),1.31),
                 (.08,.09,.22),ARMOR_FACE,refinery,.008)
        pier.rotation_euler.z=a+pi/2
cyl("Heat chamber upper armored ring deck",(0,-.32,1.42),1.06,.12,ARMOR_SIDE,refinery,12)
torus("Heat chamber gold dome bearing",(0,-.32,1.49),.99,.05,EDGE,refinery)
for side in (-1,1):
    for radial in (-1,1):
        box("Heat node through-track socket cheek",
            (side*1.17,radial*.34,1.15),(.50,.24,.62),ARMOR,refinery)
        box("Heat socket dark inner lining",
            (side*1.43,radial*.24,1.11),(.045,.14,.35),KEEL,refinery,.008)
    box("Heat node track portal lintel",
        (side*1.17,0,1.48),(.50,.91,.15),ARMOR_SIDE,refinery)
    box("Heat portal amber service lamp",
        (side*1.43,0,1.46),(.025,.12,.045),AMBER,refinery,.004)
faceted_dome("Heat chamber gold faceted crown",refinery,(0,-.32),
             ((1.47,.96),(1.68,.99),(1.94,.80),(2.13,.46),(2.21,.19)))
for i in range(12):
    a=tau*i/12
    for z0,r0,z1,r1 in ((1.68,1.005,1.94,.82),(1.94,.82,2.13,.48)):
        beam("Heat dome faceted radial pressure seam",
             (r0*cos(a),-.32+r0*sin(a),z0),
             (r1*cos(a),-.32+r1*sin(a),z1),
             .014,.014,DOME_SEAM,refinery)
cyl("Contained furnace dark collar",(0,-.32,2.22),.19,.08,EDGE,refinery,12)
cyl("Contained furnace amber aperture",(0,-.32,2.27),.15,.04,AMBER,refinery,12)
torus("Furnace retaining ring",(0,-.32,2.29),.20,.035,ARMOR_SIDE,refinery)
for side in (-1,1):
    beam("Heat node navigation mast",(side*1.20,-.32,1.59),
         (side*1.20,-.32,2.34),.045,.045,ARMOR_SIDE,refinery)
    cyl("Heat node amber signal",(side*1.20,-.32,2.37),
        .045,.07,AMBER,refinery,8)
for i in range(8):
    a=i*tau/8
    window=box("Heat ring amber machinery port",(1.17*cos(a),-.32+1.17*sin(a),1.24),
               (.14,.075,.09),AMBER,refinery,.008)
    window.rotation_euler.z=a+pi/2
for x in (-.58,-.22,.22,.58):
    box("Heat exchange outer exhaust slit",(x,-.99,.88),(.085,.045,.25),AMBER,refinery,.008)

# A straight, complete factory work platform meets the curved orbital guideway
# through two compact rail collars. This keeps the approved deck broad and flat.
box("Manufacturing full pressure sole",(0,-.89,.25),
    (2.80,1.65,.22),KEEL,workshop)
box("Manufacturing continuous ivory work deck",(0,-.89,.39),
    (2.70,1.55,.10),ARMOR_FACE,workshop)
box("Manufacturing recessed machine lane",(0,-.62,.448),
    (2.35,.38,.025),MACHINE,workshop,.007)
box("Manufacturing open assembly well",(0,-1.10,.453),
    (1.55,.68,.026),KEEL,workshop,.008)
for side in (-1,1):
    box("Manufacturing assembly well ivory lip",(side*.78,-1.10,.49),
        (.055,.68,.055),ARMOR_FACE,workshop,.006)
    for y in (-1.32,-.90):
        box("Manufacturing amber work-bay light",(side*.69,y,.485),
            (.10,.035,.022),AMBER,workshop,.003)
box("Manufacturing outer dark pressure sidewall",(0,-1.71,.46),
    (2.82,.17,.38),KEEL,workshop)
box("Manufacturing outer ivory sill",(0,-1.72,.68),
    (2.86,.20,.09),ARMOR_SIDE,workshop)
for x in (-1.02,-.34,.34,1.02):
    box("Manufacturing plated deck seam",(x,-.89,.446),
        (.025,1.52,.016),ARMOR_SIDE,workshop,.003)
for x,y in ((-.48,-1.18),(.05,-1.08),(.55,-1.25)):
    box("Manufacturing secured cargo cassette",(x,y,.56),
        (.31,.40,.22),ARMOR_FACE,workshop,.02)
    box("Manufacturing cassette dark top seam",(x,y,.68),
        (.21,.31,.025),ARMOR_SIDE,workshop,.004)
    box("Manufacturing cassette amber lock",(x,y-.215,.59),
        (.10,.012,.045),AMBER,workshop,.004)
for side in (-1,1):
    for radial in (-1,1):
        box("Manufacturing track entry armor cheek",
            (side*1.32,radial*.29,.65),(.33,.18,.78),ARMOR,workshop)
        box("Manufacturing track entry dark return",
            (side*1.50,radial*.23,.63),(.035,.13,.43),KEEL,workshop,.006)
    box("Manufacturing track entry lintel",(side*1.32,0,1.09),
        (.35,.78,.13),ARMOR_SIDE,workshop)
for y in (-.19,-1.54):
    box("Manufacturing amber guided transfer rail",(0,y,.52),
        (2.42,.065,.08),CRANE_ORANGE,workshop,.008)
for x in (-.76,0,.76):
    box("Manufacturing transverse crane datum",(x,-.85,.56),
        (.065,1.27,.075),CRANE_ORANGE,workshop,.008)
for radial_y in (-.78,.08):
    box("Manufacturing high gantry travel rail",(0,radial_y,1.44),
        (1.75,.055,.075),CRANE_ORANGE,workshop,.012)
    for tangent_x in (-.85,.85):
        beam("Manufacturing gantry support post",
             (tangent_x,radial_y,.45),(tangent_x,radial_y,1.45),
             .055,.075,ARMOR_SIDE,workshop)
for x in (-1.12,1.12):
    for y in (-.75,.20):
        beam("Manufacturing armored portal upright",(x,y,.37),(x,y,1.50),.16,.19,ARMOR,workshop)
        box("Manufacturing portal dark bearing foot",(x,y,.41),(.25,.31,.18),EDGE,workshop)
        sign=-1 if x<0 else 1
        wall_prism("Manufacturing sloped load shoulder",
                   [(x-sign*.10,.81),(x+sign*.20,.81),(x+sign*.20,1.29),
                    (x+sign*.06,1.57),(x-sign*.10,1.57)],
                   y-.10,y+.10,ARMOR_FACE,workshop)
        box("Manufacturing dark inner jamb",(x-sign*.19,y,1.03),
            (.048,.20,.62),MACHINE,workshop,.012)
box("Manufacturing outer pressure cavity wall",(0,-.89,.51),(1.92,.13,.52),ARMOR_SIDE,workshop)
for x in (-.58,0,.58):
    box("Manufacturing vented cavity inset",(x,-.97,.55),(.31,.026,.15),KEEL,workshop,.006)
    box("Manufacturing amber working status",(x,-.99,.58),(.12,.012,.025),AMBER,workshop,.003)
box("Manufacturing recessed machine bed",(0,-.25,.53),(1.18,.70,.24),ARMOR_SIDE,workshop)
box("Manufacturing central workpiece",(0,-.25,.72),(.55,.44,.19),MACHINE,workshop)
box("Manufacturing active work face",(0,-.25,.83),(.40,.25,.025),CYAN,workshop,.008)
for x in (-.43,.43):
    box("Manufacturing tool base",(x,.02,.62),(.18,.19,.26),EDGE,workshop,.012)
    box("Manufacturing machine jaw",(x,-.17,.84),(.19,.23,.07),ARMOR_FACE,workshop,.008)
beam("Overhead fabrication gantry",(-.65,0,1.55),(.66,0,1.55),.14,.22,MACHINE,workshop)
for side in (-1,1):
    beam("Fabrication gantry load leg",(side*.68,0,.56),(side*.68,0,1.57),.095,.13,ARMOR_SIDE,workshop)
    box("Fabrication gantry armored foot",(side*.68,0,.58),(.23,.29,.19),ARMOR,workshop)
box("Fabrication gantry hanging crane rail",(0,0,1.63),(.99,.10,.08),CRANE_ORANGE,workshop)
beam("Downward working tool",(.17,0,1.48),(.17,0,.66),.07,.08,EDGE,workshop)
box("Work site contained welding line",(.17,0,.76),(.15,.18,.04),CYAN,workshop,.01)

# The two pressure workshops are complete machine rooms either side of the
# open fabrication lane. Their dark recesses and roof plates read at page size.
for side in (-1,1):
    x=side*1.02
    box("Fabrication room continuous dark hull",(x,-.91,.73),(.44,1.32,.58),KEEL,workshop,.035)
    box("Fabrication room armored inner wall",(side*.73,-.91,.73),(.075,1.18,.44),ARMOR_MID,workshop,.014)
    slope_shell("Fabrication room chamfered roof",
                [(x-.28,-1.60),(x+.28,-1.60),(x+.28,-.21),(x-.28,-.21)],
                [1.08,1.08,1.00,1.00],.11,ARMOR_FACE,workshop)
    box("Fabrication room roof dark expansion joint",(x,-.93,1.08),(.075,1.23,.025),EDGE,workshop,.004)
    for y in (-1.37,-.97,-.57):
        box("Fabrication room removable armor cassette",(side*1.30,y,.91),
            (.055,.29,.46),ARMOR,workshop,.012)
        box("Fabrication room inset service window",(side*1.337,y,1.03),
            (.022,.20,.09),WINDOW,workshop,.004)
        box("Fabrication room lower cooling louver",(side*1.34,y,.70),
            (.023,.20,.055),MACHINE,workshop,.003)
        box("Fabrication room roof amber access mark",(x,y,1.095),
            (.09,.13,.015),GOLD,workshop,.002)
    for y in (-1.53,-.24):
        box("Fabrication room end-frame corner",(side*1.32,y,.87),
            (.15,.10,.80),ARMOR_FACE,workshop,.012)
    beam("Fabrication room exposed service conduit",
         (side*.68,-1.47,1.03),(side*.68,-.35,1.03),.045,.045,GOLD,workshop)
for y in (-1.23,-.55):
    box("Factory traveling bridge dark undercarriage",(0,y,1.48),
        (1.76,.17,.10),EDGE,workshop,.012)
    box("Factory traveling bridge gold load beam",(0,y,1.58),
        (1.67,.075,.08),CRANE_ORANGE,workshop,.01)
    box("Factory traveling winch",(.22,y,1.37),(.25,.28,.28),MACHINE,workshop,.018)
    beam("Factory hanging articulated tool",(.22,y,1.29),(.22,y,1.02),.055,.07,ARMOR_SIDE,workshop)
    box("Factory hanging tool amber tip",(.22,y,.98),(.08,.08,.06),AMBER,workshop,.008)
for x in (-.48,.48):
    for y in (-1.30,-.82):
        box("Factory floor load bearing cassette",(x,y,.51),(.35,.34,.065),ARMOR_SIDE,workshop,.008)
        box("Factory cassette center machine top",(x,y,.56),(.21,.22,.045),MACHINE,workshop,.006)

# Two outer launch arms reach from the band's missing section; the void is
# wider than the shuttle and reads as a bay, not as a self-contained block.
for side in (-1,1):
    beam("Dock outer launch arm",(side*.76,-.25,.58),(side*.83,-1.72,.58),.15,.18,ARMOR,shipyard)
    beam("Dock inner dark girder",(side*.76,-.25,.35),(side*.83,-1.68,.35),.16,.18,EDGE,shipyard)
    box("Contained dock approach guide",(side*.66,-.94,.70),(.032,1.24,.022),CYAN,shipyard,.004)
    box("Dock armored entry cheek",(side*.90,-.62,.72),(.31,.72,.70),ARMOR,shipyard)
    box("Dock inset service wall",(side*.70,-1.13,.49),(.16,1.18,.37),ARMOR_SIDE,shipyard)
    box("Dock exterior pressure foot",(side*.87,-1.49,.35),(.34,.52,.25),EDGE,shipyard)
    box("Dock inner bay shadow liner",(side*.68,-.63,.84),(.075,.71,.67),KEEL,shipyard,.012)
    wall_prism("Dock sloped outer entrance shoulder",
               [(side*.67,.31),(side*1.13,.31),(side*1.13,1.10),
                (side*.96,1.40),(side*.69,1.40)],-.27,.03,ARMOR_FACE,shipyard)
    box("Dock launch clamp actuator",(side*.57,-1.24,.61),(.21,.30,.21),MACHINE,shipyard,.012)
    box("Dock launch clamp jaw",(side*.48,-1.24,.73),(.12,.25,.08),ARMOR_FACE,shipyard,.008)
    box("Dock contained service light",(side*.85,-1.01,.58),(.028,.20,.025),CYAN,shipyard,.004)
box("Dock dark load-bearing keel",(0,-1.02,.26),(1.95,1.83,.19),KEEL,shipyard)
box("Dock continuous ivory landing deck",(0,-1.02,.38),(1.81,1.72,.08),ARMOR_FACE,shipyard)
box("Dock recessed central landing lane",(0,-1.05,.43),(1.12,1.55,.028),ARMOR_SIDE,shipyard,.006)
for side in (-1,1):
    for y in (-1.49,-1.02,-.55):
        box("Dock amber recessed landing lamp",(side*.54,y,.45),
            (.07,.05,.015),AMBER,shipyard,.003)
for y in (-.58,-1.04,-1.50):
    box("Dock landing deck panel seam",(0,y,.428),(1.79,.025,.018),ARMOR_SIDE,shipyard,.003)
for side in (-1,1):
    box("Dock illuminated side guide",(side*.78,-1.06,.44),(.025,1.45,.019),CYAN,shipyard,.003)
    box("Dock outer service module",(side*.91,-1.53,.71),(.42,.53,.58),ARMOR,shipyard)
    box("Dock service module dark entry",(side*.91,-1.83,.72),(.26,.028,.30),KEEL,shipyard,.007)
    box("Dock service module cyan operating slit",(side*.91,-1.85,.85),(.15,.013,.035),CYAN,shipyard,.003)
box("Dock inner machine service bed",(0,-.75,.41),(.60,.71,.10),ARMOR_SIDE,shipyard)
box("Dock entrance dark pressure threshold",(0,-.35,.39),(1.46,.32,.16),EDGE,shipyard,.015)
beam("Dock portal gantry",(-.83,-.40,1.00),(.83,-.40,1.00),.14,.18,ARMOR,shipyard)
beam("Dock armored entrance canopy",(-.94,-.35,1.25),(.94,-.35,1.25),.23,.25,ARMOR,shipyard)
slope_shell("Dock faceted entry roof",
            [(-1.06,-.39),(1.06,-.39),(1.01,.04),(-1.01,.04)],
            [1.36,1.36,1.22,1.22],.13,ARMOR,shipyard)
for side in (-1,1):
    wall_prism("Dock deep armored portal fascia",
               [(side*.55,.37),(side*1.14,.37),(side*1.14,1.14),
                (side*.93,1.43),(side*.70,1.43),(side*.55,1.16)],
               -.58,-.35,ARMOR_FACE,shipyard)
    box("Dock black recessed portal return",(side*.52,-.60,.81),
        (.075,.17,.75),KEEL,shipyard,.009)
box("Dock portal upper pressure hood",(0,-.47,1.44),
    (1.61,.32,.17),ARMOR_FACE,shipyard,.02)
box("Dock portal recessed soffit",(0,-.64,1.28),
    (1.33,.075,.10),KEEL,shipyard,.01)
for side in (-1,1):
    beam("Dock entrance upright",(side*.85,-.39,.34),(side*.85,-.39,1.29),.25,.27,ARMOR,shipyard)
    beam("Dock outer service portal upright",(side*.82,-1.39,.35),(side*.82,-1.39,1.02),.16,.19,ARMOR_SIDE,shipyard)
beam("Dock outer service portal header",(-.83,-1.39,1.04),(.83,-1.39,1.04),.16,.19,ARMOR,shipyard)
for a in (-146,-119):
    owned_arc(shipyard,"Dock armored entry threshold",a,a+2.2,
              4.08,5.29,.33,1.03,ARMOR_SIDE)
    owned_arc(shipyard,"Dock threshold ivory shoulder",a,a+2.2,
              4.18,5.18,1.02,1.13,ARMOR)
box("Docked shuttle fuselage",(0,-1.33,.91),(.61,1.30,.22),ARMOR_FACE,shipyard,.04)
armor_prism("Docked shuttle swept nose",[(0,-2.30),(.31,-1.84),(-.31,-1.84)],.85,1.04,ARMOR_FACE,shipyard)
box("Docked shuttle canopy",(0,-1.42,1.045),(.33,.44,.06),GLASS,shipyard,.01)
for side in (-1,1):
    box("Docked shuttle engine nacelle",(side*.38,-1.50,.83),
        (.19,.73,.18),ARMOR_SIDE,shipyard,.02)
    box("Docked shuttle cyan exhaust",(side*.38,-1.91,.83),
        (.12,.035,.10),CYAN,shipyard,.006)

# Dock pressure housing stays open at the nose, but has a legible occupied
# cross-section: layered outer armor, black bay lining, service machinery.
for side in (-1,1):
    x=side*.88
    for bay_y in (-1.63,-.54):
        box("Dock separated service bay dark hull",(x,bay_y,.76),
            (.30,.44,.59),KEEL,shipyard,.018)
        slope_shell("Dock separated service bay roof",
                    [(x-.20,bay_y-.24),(x+.20,bay_y-.24),
                     (x+.20,bay_y+.24),(x-.20,bay_y+.24)],
                    [1.16,1.16,1.10,1.10],.11,ARMOR_FACE,shipyard)
    for y in (-1.53,-.71):
        box("Dock removable sloped armor bay",(side*1.07,y,.93),
            (.10,.31,.52),ARMOR,shipyard,.012)
        box("Dock navy machinery recess",(side*1.131,y,.93),
            (.018,.21,.23),MACHINE,shipyard,.003)
        box("Dock cyan status slit",(side*1.144,y,1.00),
            (.011,.17,.035),CYAN,shipyard,.002)
        box("Dock lower pressure flange",(side*1.06,y,.57),
            (.22,.32,.07),ARMOR_SIDE,shipyard,.006)
    for y in (-1.68,-.39):
        wall_prism("Dock angled end armor cheek",
                   [(side*.66,.42),(side*1.16,.42),(side*1.16,1.16),
                    (side*.99,1.42),(side*.70,1.42)],y-.06,y+.06,
                   ARMOR_FACE,shipyard)
    box("Dock service pipe housed beneath sill",(side*.62,-1.05,.48),
        (.045,1.32,.045),GOLD,shipyard,.006)
    box("Dock edge beacon armor base",(side*1.06,-1.70,1.43),
        (.13,.13,.12),EDGE,shipyard,.01)
    cyl("Dock edge amber beacon",(side*1.06,-1.70,1.53),.038,.10,AMBER,shipyard,8)
    box("Shuttle swept broad wing",(side*.50,-1.35,.94),
        (.54,.40,.085),ARMOR_FACE,shipyard,.018)
    box("Shuttle wing navy control surface",(side*.70,-1.37,.990),
        (.23,.24,.016),ARMOR_SIDE,shipyard,.004)
    box("Shuttle engine pale upper nacelle",(side*.39,-1.69,.95),
        (.18,.49,.08),ARMOR_FACE,shipyard,.012)
    box("Shuttle engine dark rear nozzle",(side*.39,-2.00,.88),
        (.16,.07,.13),EDGE,shipyard,.008)
for y in (-1.65,-.85):
    box("Dock transverse maintenance threshold",(0,y,.46),
        (1.48,.075,.04),ARMOR_SIDE,shipyard,.006)
    box("Dock amber guidance chevron",(0,y,.487),
        (.19,.045,.014),GOLD,shipyard,.002)
box("Shuttle segmented cockpit frame",(0,-1.52,1.09),
    (.37,.06,.04),ARMOR_FACE,shipyard,.005)
armor_prism("Shuttle visible swept pressure hull",
            [(-.34,-.72),(.34,-.72),(.43,-1.36),(.28,-1.95),
             (0,-2.42),(-.28,-1.95),(-.43,-1.36)],
            1.20,1.31,ARMOR_FACE,shipyard)
for side in (-1,1):
    armor_prism("Shuttle broad lifting wing",
                [(side*.26,-1.35),(side*.93,-1.67),
                 (side*.87,-1.92),(side*.25,-1.81)],
                1.23,1.29,ARMOR_FACE,shipyard)
    box("Shuttle exposed navy wing flap",(side*.70,-1.79,1.315),
        (.27,.095,.018),ARMOR_SIDE,shipyard,.003)
    box("Shuttle upper engine cowling",(side*.39,-1.31,1.34),
        (.18,.46,.13),ARMOR_FACE,shipyard,.014)
    box("Shuttle engine dark air intake",(side*.39,-1.01,1.35),
        (.14,.035,.08),GLASS,shipyard,.004)
box("Shuttle visible blue faceted cockpit",(0,-1.35,1.35),
    (.38,.47,.08),GLASS,shipyard,.018)
for y in (-1.52,-1.32):
    box("Shuttle cockpit segmented white rib",(0,y,1.40),
        (.40,.025,.025),ARMOR_FACE,shipyard,.003)

# Give the parked ship breathing room inside the berth. Keeping its parts
# under one pivot preserves the swept body and engine alignment as a unit.
shuttle_shell=parent("Open berth shuttle silhouette",(0,-1.35,1.02))
shuttle_shell.parent=shipyard
bpy.context.view_layer.update()
for child in list(shipyard.children):
    if child==shuttle_shell or not child.name.startswith(("Shuttle","Docked shuttle")):
        continue
    world_matrix=child.matrix_world.copy()
    child.parent=shuttle_shell
    child.matrix_parent_inverse.identity()
    child.matrix_world=world_matrix
bpy.context.view_layer.update()
shuttle_shell.scale=(.79,.78,.87)

# The reference manufacturing platform is compact beside the planet, while
# its independently owned track remains the full approved orbital radius.
workshop_shell=bpy.data.objects.new("Compact manufacturing work architecture",None)
bpy.context.collection.objects.link(workshop_shell)
workshop_shell.parent=workshop
bpy.context.view_layer.update()
for child in list(workshop.children):
    if child==workshop_shell or child.name.startswith((
            "Fine orbital pressure web","Fine ivory rail head",
            "Orbital tram guide","Orbital track joint clamp")):
        continue
    world_matrix=child.matrix_world.copy()
    child.parent=workshop_shell
    child.matrix_parent_inverse.identity()
    child.matrix_world=world_matrix
bpy.context.view_layer.update()
workshop_shell.scale=(1.04,.80,.72)

# The approved launch district reads as a broad, low open berth. Keep the
# rail-bearing geometry in the shared orbit while widening only the occupied
# dock architecture; its shuttle and service bays retain their relative fit.
shipyard_shell=bpy.data.objects.new("Broad low open shipyard architecture",None)
bpy.context.collection.objects.link(shipyard_shell)
shipyard_shell.parent=shipyard
bpy.context.view_layer.update()
for child in list(shipyard.children):
    if child==shipyard_shell or child.name.startswith((
            "Fine orbital pressure web","Fine ivory rail head",
            "Orbital tram guide","Orbital track joint clamp",
            "Dock armored entry threshold","Dock threshold ivory shoulder",
            "Low flush front attitude collar","Front attitude cyan inset")):
        continue
    world_matrix=child.matrix_world.copy()
    child.parent=shipyard_shell
    child.matrix_parent_inverse.identity()
    child.matrix_world=world_matrix
bpy.context.view_layer.update()
shipyard_shell.scale=(1.12,1.04,.78)

# Author-view tram follows the same fine orbital track. Runtime motion is
# implemented by planet_orbital_spine.gd and appears only on a completed loop.
tram=parent("Track-constrained orbital tram",(0,-RING_RADIUS,.24))
box("Tram dark captured bogie",(0,0,-.075),(.64,.21,.09),KEEL,tram,.016)
box("Tram faceted ivory cabin",(0,0,.035),(.55,.24,.18),ARMOR_FACE,tram,.035)
box("Tram cyan forward screen",(.23,0,.055),(.025,.18,.105),CYAN,tram,.006)


# Painted planet texture is existing source art; the new architecture above
# remains a standalone concept and does not write any runtime assets.
bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=2.51)
globe=bpy.context.object
globe.name="Existing painted planet for proportion only"
globe.location.z=1.45
for polygon in globe.data.polygons: polygon.use_smooth=True
planet_mat=material("Painted planet surface",(.8,.8,.8),0,1)
tex=planet_mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image=bpy.data.images.load(str(GAME/'assets/planets/painted-v4/surface.png'))
planet_mat.node_tree.links.new(tex.outputs['Color'],planet_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
globe.data.materials.append(planet_mat)
globe.rotation_euler.z=.45

random.seed(184)
for i in range(150):
    x=random.uniform(-10,10); y=random.uniform(-10,10)
    if abs(x)<5 and abs(y)<5: continue
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=random.uniform(.010,.028), location=(x,y,-9))
    bpy.context.object.data.materials.append(CYAN if i%11==0 else material("Star %d"%i,(.28,.48,.63),0,1,.8))

world=bpy.context.scene.world
if world is None:
    world=bpy.data.worlds.new("Deep-space illumination")
    bpy.context.scene.world=world
world.color=(.003,.012,.025)
world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.003,.012,.027,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45

def light(name, xyz, power, color, size):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.color=color; data.shape='DISK'; data.size=size
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj)
    obj.location=xyz; obj.rotation_euler=(Vector((0,0,0))-obj.location).to_track_quat('-Z','Y').to_euler()

light("Wide warm ship lighting",(-4,-6,9),1250,(1.0,.84,.67),8)
light("Cold back rim",(5,5,7),1450,(.38,.72,1.0),7)
light("Controlled front fill",(0,-3,7),400,(.72,.86,1.0),8)

camera_data=bpy.data.cameras.new("Concept orthographic camera")
camera=bpy.data.objects.new("Concept orthographic camera",camera_data)
bpy.context.collection.objects.link(camera)
camera.location=(0,-12.0,7.0)
camera.rotation_euler=(Vector((0,0,.42))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'; camera_data.ortho_scale=18.6
bpy.context.scene.camera=camera

scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=24
bpy.context.view_layer.cycles.use_denoising=False
scene.render.resolution_x=1600
scene.render.resolution_y=900
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT)
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.camera.data.lens=50
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'concept-v23.blend'),compress=True)
bpy.ops.render.render(write_still=True)
