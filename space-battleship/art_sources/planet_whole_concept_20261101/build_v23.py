"""Standalone authored orbital architecture concept. No existing facility mesh import."""
from pathlib import Path
from math import sin, cos, pi, tau
import random
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
GAME = HERE.parents[1]
OUT = HERE / "concept-v23.png"
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


ARMOR = material("Warm faceted ivory armor", (.52,.47,.36), .05, .74)
ARMOR_FACE = material("Lit ivory armor facets", (.90,.78,.60), .04, .78)
ARMOR_SIDE = material("Recessed slate armor flanks", (.10,.17,.21), .09, .78)
ARMOR_MID = material("Midtone faceted pressure armor", (.40,.46,.45), .05, .78)
EDGE = material("Dark slate panel edge", (.085,.13,.16), .16, .75)
KEEL = material("Deep navy pressure keel", (.012,.035,.055), .10, .80)
MACHINE = material("Machine steel", (.043,.095,.115), .10, .72)
GLASS = material("Dark blue glass", (.025,.16,.22), .26, .34)
CYAN = material("Contained cyan energy", (.025,.65,.84), .08, .40, 1.8)
AMBER = material("Contained amber heat", (.68,.21,.025), .04, .55, .65)
GOLD = material("Warm work marking", (.47,.25,.075), .24, .56)
DOME_GOLD = material("Heat chamber faceted gold armor", (.80,.48,.17), .20, .58)


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
    """Broad polygonal crown with sloping gold panels instead of a cone."""
    verts=[]
    for height,radius in rings:
        for i in range(sides):
            a=tau*i/sides
            verts.append((center[0]+radius*cos(a),center[1]+radius*sin(a),height))
    faces=[]
    for band in range(len(rings)-1):
        for i in range(sides):
            j=(i+1)%sides
            faces.append((band*sides+i,band*sides+j,(band+1)*sides+j,(band+1)*sides+i))
    faces.append(tuple((len(rings)-1)*sides+i for i in range(sides)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj=finish(obj,name,DOME_GOLD,root)
    obj.data.materials.append(GOLD)
    for i,face in enumerate(obj.data.polygons):
        face.material_index = 1 if i%sides in (0,1,6,7) else 0
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
    bpy.context.view_layer.update()
    inverse = root.matrix_world.inverted()
    steps = max(16, int(abs(end-begin)*2))
    vertices = []
    for i in range(steps+1):
        angle_degrees = begin+(end-begin)*i/steps
        angle = angle_degrees*pi/180
        # Raise the middle of the occupied rear crescent above the sphere's
        # projection, while both independent arc ends meet the through-beam.
        rise = .68 * sin(pi * (angle_degrees-25) / 130) if 25 <= angle_degrees <= 155 else 0.0
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
    return parent(name,(4.33*cos(angle),4.33*sin(angle),.03),angle+pi/2)


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

# The service beam remains visible only across the two narrow transfer spans.
annular_band("Deep continuous pressure datum",4.18,4.45,-.22,.13,KEEL)
annular_band("Inboard service rail",4.22,4.33,.13,.19,MACHINE)
for i in range(32):
    a=i*tau/32
    annular_band("Pressure beam joint",4.17,4.46,-.23,.18,EDGE,a-.010,a+.010,2)

station=root_at("01 / Command district of the orbital city",140)
station.location.x=5.22*cos(140*pi/180)
station.location.y=5.22*sin(140*pi/180)
refinery=root_at("02 / Heat district of the orbital city",35)
workshop=root_at("03 / Manufacturing district of the orbital city",-43)
shipyard=root_at("04 / Open launch district of the orbital city",-130)

# Each built district owns a closed part of the same variable-section band.
for root,lo,hi in ((refinery,25,75),(station,75,155),
                   (workshop,-65,25)):
    if root==workshop:
        # Manufacturing opens through the roof without breaking the deep
        # continuous load-bearing section beneath its work channel.
        for part_lo,part_hi in ((-65,-64),(-32,25)):
            profiled_band(root,"Continuous variable-section armored building band",part_lo,part_hi)
        for part_lo,part_hi in ((-65,-64),(-32,25)):
            profiled_band(root,"Continuous deep load-bearing underside",part_lo,part_hi,
                          roof_shift=-.55,inner_shift=-.05,outer_shift=.05,mat=KEEL)
        owned_arc(root,"Recessed load floor beneath fabrication opening",-64,-32,
                  4.03,5.16,-.16,.25,KEEL)
        continue
    profiled_band(root,"Continuous variable-section armored building band",lo,hi)
    profiled_band(root,"Continuous deep load-bearing underside",lo,hi,
                  roof_shift=-.55,inner_shift=-.05,outer_shift=.05,mat=KEEL)

# The dock opens a wide radial bay in the fourth section of the building.
# Its two curved abutments share the band profile and hold the outward arms.
for lo,hi in ((-205,-143),(-119,-65)):
    profiled_band(shipyard,"Dock district curved pressure abutment",lo,hi)
    profiled_band(shipyard,"Dock district deep support",lo,hi,
                  roof_shift=-.52,inner_shift=-.05,outer_shift=.05,mat=KEEL)
owned_arc(shipyard,"Dock open bay inner transfer floor",-144,-118,4.17,4.68,.18,.34,MACHINE)
bpy.context.view_layer.update()
front_node = shipyard.matrix_world.inverted() @ Vector((0,-4.47,.60))
cyl("Low flush front attitude collar",front_node,.28,.14,EDGE,shipyard,10)
front_core = shipyard.matrix_world.inverted() @ Vector((0,-4.47,.69))
cyl("Front attitude cyan inset",front_core,.12,.035,CYAN,shipyard,10)
for root,lo,hi in ((shipyard,-205,-143),(shipyard,-119,-65),
                   (workshop,-65,25),(refinery,25,75),(station,75,155)):
    profiled_outer_ribbon(root,"Continuous contained outer gallery line",lo,hi)

# Regular hard armor panels cover the long hull. The service reveals stay
# narrow and continuous; the work and launch openings remain genuine voids.
for root,spans in ((station,((75,155),)),(refinery,((25,75),)),
                   (workshop,((-32,25),)),
                   (shipyard,((-205,-143),(-119,-65)))):
    for lo,hi in spans:
        for begin in range(lo,hi,10):
            finish_angle=min(begin+10,hi)
            if finish_angle-begin>2:
                deck_plate(root,begin+.42,finish_angle-.42)

# The arc's inward facing observation ribbon is continuous through command.
owned_arc(station,"Command district observation pressure ribbon",89,140,3.96,4.06,.62,.74,GLASS)
for a in (95,104,113,122,131):
    owned_arc(station,"Command observation dark mullion",a,a+.7,3.94,4.10,.60,.77,EDGE)
armor_prism("Command full-width embedded structural plinth",
            [(-.82,-.42),(.82,-.42),(.62,1.43),(-.62,1.43)],.91,1.18,ARMOR,station)
cyl("Command dark structural foundation",(0,-.32,1.22),1.04,.28,KEEL,station,12)
cyl("Command lower faceted load deck",(0,-.32,1.35),1.00,.14,ARMOR_SIDE,station,12)
cyl("Command stepped ivory observation deck",(0,-.32,1.48),.91,.15,ARMOR,station,12)
torus("Command continuous observation sill",(0,-.32,1.52),.85,.06,ARMOR_FACE,station)
for i in range(12):
    a=i*tau/12
    x=.91*cos(a); y=-.32+.91*sin(a)
    window=box("Command observation window bay",(x,y,1.36),(.27,.085,.12),GLASS,station,.01)
    window.rotation_euler.z=a+pi/2
    if i%3==0:
        pylon=box("Command exterior armor buttress",(1.01*cos(a),-.32+1.01*sin(a),1.29),
                  (.17,.22,.37),ARMOR,station,.02)
        pylon.rotation_euler.z=a
for side in (-1,1):
    beam("Command platform load rib into orbital band",
         (side*.46,.02,1.13),(side*.38,1.27,.77),.19,.22,ARMOR_SIDE,station)
beam("Command platform broad pressure bridge",
     (0,.12,1.28),(0,1.24,.91),.58,.40,ARMOR,station)
cyl("Command rotating bearing",(0,-.32,1.60),.62,.16,EDGE,station,10)
torus("Command bearing cyan collar",(0,-.32,1.70),.52,.045,CYAN,station)
cone("Command faceted core",(0,-.32,1.86),.39,.20,.29,ARMOR,station,8)
cyl("Command blue canopy",(0,-.32,2.04),.23,.09,GLASS,station,8)
cone("Command short beacon",(0,-.32,2.20),.10,.02,.20,ARMOR,station,8)

# Heat is a working aperture in the band, marked by a low furnace clamp.
cyl("Heat chamber dark integrated foundation",(0,-.32,1.06),.91,.25,KEEL,refinery,12)
cyl("Heat chamber lower armored ring deck",(0,-.32,1.22),.86,.14,ARMOR,refinery,12)
torus("Heat chamber recessed observation band",(0,-.32,1.32),.79,.07,GLASS,refinery)
cyl("Heat chamber upper armored ring deck",(0,-.32,1.42),.74,.12,ARMOR_SIDE,refinery,12)
torus("Heat chamber gold dome bearing",(0,-.32,1.49),.70,.05,EDGE,refinery)
faceted_dome("Heat chamber gold faceted crown",refinery,(0,-.32),
             ((1.47,.68),(1.68,.70),(1.94,.57),(2.13,.33),(2.21,.14)))
cyl("Contained furnace dark collar",(0,-.32,2.22),.19,.08,EDGE,refinery,12)
cyl("Contained furnace amber aperture",(0,-.32,2.27),.15,.04,AMBER,refinery,12)
torus("Furnace retaining ring",(0,-.32,2.29),.20,.035,ARMOR_SIDE,refinery)
for i in range(8):
    a=i*tau/8
    window=box("Heat ring amber machinery port",(.84*cos(a),-.32+.84*sin(a),1.24),
               (.14,.075,.09),AMBER,refinery,.008)
    window.rotation_euler.z=a+pi/2
for x in (-.58,-.22,.22,.58):
    box("Heat exchange outer exhaust slit",(x,-.99,.88),(.085,.045,.25),AMBER,refinery,.008)

# Manufacturing uses a large opening cut between two roof plate groups.
# An overhead crane visibly spans the work void inside the curved band.
owned_arc(workshop,"Manufacturing open work floor",-64,-32,4.17,5.03,.34,.40,MACHINE)
for a in (-64,-56,-48,-40):
    owned_arc(workshop,"Amber fabrication transverse working rib",a,a+1.1,
              4.20,5.02,.42,.51,GOLD)
owned_arc(workshop,"Manufacturing inner orange service rail",-66,-34,
          4.16,4.22,.53,.63,AMBER)
owned_arc(workshop,"Manufacturing outer orange service rail",-66,-34,
          5.05,5.11,.53,.63,AMBER)
for a in (-67,-34):
    owned_arc(workshop,"Manufacturing work portal ring",a,a+1.8,4.07,5.19,.37,1.20,ARMOR_SIDE)
for a in (-59,-43):
    owned_arc(workshop,"Manufacturing orange overhead gate",a,a+1.4,
              4.18,5.08,1.16,1.28,AMBER)
for x in (-1.12,1.12):
    for y in (-.75,.20):
        beam("Manufacturing armored portal upright",(x,y,.37),(x,y,1.62),.24,.28,ARMOR,workshop)
        box("Manufacturing portal dark bearing foot",(x,y,.41),(.32,.39,.24),EDGE,workshop)
    beam("Manufacturing broad entrance lintel",(x,-.83,1.64),(x,.28,1.64),.29,.34,ARMOR,workshop)
    box("Manufacturing lintel pressure cap",(x,-.28,1.81),(.39,1.34,.13),ARMOR_SIDE,workshop)
box("Manufacturing recessed machine bed",(0,-.25,.53),(1.18,.70,.24),ARMOR_SIDE,workshop)
box("Manufacturing central workpiece",(0,-.25,.72),(.55,.44,.19),MACHINE,workshop)
box("Manufacturing active work face",(0,-.25,.83),(.40,.25,.025),CYAN,workshop,.008)
beam("Overhead fabrication gantry",(-.65,0,1.55),(.66,0,1.55),.14,.22,MACHINE,workshop)
for side in (-1,1):
    beam("Fabrication gantry load leg",(side*.68,0,.56),(side*.68,0,1.57),.15,.20,ARMOR_SIDE,workshop)
    box("Fabrication gantry armored foot",(side*.68,0,.58),(.31,.39,.25),ARMOR,workshop)
box("Fabrication gantry hanging crane rail",(0,0,1.63),(.99,.17,.13),GOLD,workshop)
beam("Downward working tool",(.17,0,1.48),(.17,0,.66),.07,.08,EDGE,workshop)
box("Work site contained welding line",(.17,0,.76),(.15,.18,.04),CYAN,workshop,.01)

# Two outer launch arms reach from the band's missing section; the void is
# wider than the shuttle and reads as a bay, not as a self-contained block.
for side in (-1,1):
    beam("Dock outer launch arm",(side*.76,-.25,.58),(side*.83,-2.16,.58),.20,.23,ARMOR,shipyard)
    beam("Dock inner dark girder",(side*.76,-.25,.35),(side*.83,-2.08,.35),.16,.18,EDGE,shipyard)
    box("Contained dock approach guide",(side*.66,-1.10,.70),(.032,1.67,.022),CYAN,shipyard,.004)
    box("Dock armored entry cheek",(side*.90,-.62,.72),(.38,.88,.84),ARMOR,shipyard)
    box("Dock inset service wall",(side*.70,-1.13,.49),(.16,1.18,.37),ARMOR_SIDE,shipyard)
    box("Dock exterior pressure foot",(side*.87,-1.49,.35),(.34,.52,.25),EDGE,shipyard)
box("Dock recessed launch deck",(0,-1.00,.29),(1.40,1.48,.16),KEEL,shipyard)
box("Dock inner machine service bed",(0,-.75,.41),(.60,.71,.10),ARMOR_SIDE,shipyard)
beam("Dock portal gantry",(-.83,-.40,1.00),(.83,-.40,1.00),.14,.18,ARMOR,shipyard)
beam("Dock armored entrance canopy",(-.94,-.35,1.25),(.94,-.35,1.25),.30,.32,ARMOR,shipyard)
for side in (-1,1):
    beam("Dock entrance upright",(side*.85,-.39,.34),(side*.85,-.39,1.29),.25,.27,ARMOR,shipyard)
    beam("Dock outer service portal upright",(side*.82,-1.39,.35),(side*.82,-1.39,1.02),.16,.19,ARMOR_SIDE,shipyard)
beam("Dock outer service portal header",(-.83,-1.39,1.04),(.83,-1.39,1.04),.16,.19,ARMOR,shipyard)
for a in (-146,-119):
    owned_arc(shipyard,"Dock armored entry threshold",a,a+2.2,
              4.08,5.29,.33,1.03,ARMOR_SIDE)
    owned_arc(shipyard,"Dock threshold ivory shoulder",a,a+2.2,
              4.18,5.18,1.02,1.13,ARMOR)
box("Docked shuttle fuselage",(0,-1.15,.93),(.37,.96,.18),ARMOR_FACE,shipyard,.04)
armor_prism("Docked shuttle swept nose",[(0,-1.88),(.18,-1.53),(-.18,-1.53)],.87,1.04,ARMOR_FACE,shipyard)
box("Docked shuttle canopy",(0,-1.27,1.05),(.22,.31,.055),GLASS,shipyard,.01)


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
