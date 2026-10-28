"""Editable replacement planet architecture. Blender source -> GLB; no gameplay data.
Y-up model convention is exported from Blender Z-up. Facility root/Motion retained.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
OUT=ROOT.parents[1]/'assets/planets/facilities_v3'

def material(name, color, metal=0, rough=.45, emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*color,1);n.inputs['Metallic'].default_value=metal;n.inputs['Roughness'].default_value=rough
 if emission:n.inputs['Emission Color'].default_value=(*color,1);n.inputs['Emission Strength'].default_value=emission
 return m

def finish(obj,name,mat,parent,bevel=.06):
 obj.name=name;obj.data.materials.append(mat);obj.parent=parent
 if bevel:
  mod=obj.modifiers.new('Machined soft edge','BEVEL');mod.width=bevel;mod.segments=3
  bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
 for p in obj.data.polygons:p.use_smooth=True
 mod=obj.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');mod.keep_sharp=True
 bpy.ops.object.modifier_apply(modifier=mod.name)
 # One shared runtime atlas: UV islands stay within their authored material cell.
 key=mat.name.lower()
 tile=(0,0) if 'ivory' in key else (1,0) if 'teal' in key else (0,1) if 'photovoltaic' in key else (1,1) if 'copper' in key else None
 if tile is not None:
  project_uv=not obj.data.uv_layers
  if project_uv:obj.data.uv_layers.new(name='UVMap')
  uv=obj.data.uv_layers.active.data
  for face in obj.data.polygons:
   for li in face.loop_indices:
    value=uv[li].uv.copy()
    if project_uv:
     v=obj.data.vertices[obj.data.loops[li].vertex_index].co
     value.x=(v.x+1.6)/3.2;value.y=(v.y+1.6)/3.2
    uv[li].uv=(tile[0]*.5+.02+value.x*.46,1.0-(tile[1]*.5+.02+value.y*.46))
 return obj

def box(name,loc,scale,mat,parent,bevel=.06):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat,parent,bevel)
def cyl(name,loc,radius,depth,mat,parent,rotation=(0,0,0),verts=24):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=loc,rotation=rotation);return finish(bpy.context.object,name,mat,parent,.045)
def tube(name,a,b,r,mat,parent):
 a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,mat,parent);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def assembly_shell(mat,parent):
 profile=[(-1.325,.18),(-1.325,.90),(-1.16,1.18),(-.85,1.45),(.85,1.45),(1.16,1.18),(1.325,.90),(1.325,.18)]
 vertices=[(x-.25,y+.15,z) for y in [-1.05,1.05] for x,z in profile]
 faces=[tuple(range(7,-1,-1)),tuple(range(8,16))]
 for i in range(8):faces.append((i,(i+1)%8,(i+1)%8+8,i+8))
 mesh=bpy.data.meshes.new('Arched production hall mesh');mesh.from_pydata(vertices,[],faces);mesh.update()
 obj=bpy.data.objects.new('Arched production hall shell',mesh);bpy.context.collection.objects.link(obj)
 finish(obj,'Arched production hall shell',mat,parent,.07)

stats=[]
for kind in ['auto_explore','refinery','equipment','shipyard']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 ivory=material('Ivory ceramic armour',(.66,.62,.52),.28,.32)
 navy=material('Deep teal structural metal',(.025,.055,.075),.55,.33)
 mid=material('Teal secondary panels',(.07,.16,.19),.45,.36)
 cyan=material('Cyan status glass',(.09,.62,.59),.25,.25,.5)
 amber=material('Amber process indicators',(.87,.43,.10),.3,.4,.2)
 copper=material('Copper pipework',(.49,.25,.12),.65,.42)
 solar=material('Blue photovoltaic panels',(.035,.16,.28),.35,.3)
 root=bpy.data.objects.new('Facility',None);bpy.context.collection.objects.link(root)
 motion=bpy.data.objects.new('Motion',None);bpy.context.collection.objects.link(motion);motion.parent=root
 if kind=='auto_explore':
  # Habitat ring, paired structural booms and panel wings make a station silhouette.
  bpy.ops.mesh.primitive_torus_add(major_radius=1.22,minor_radius=.26,major_segments=48,minor_segments=12,location=(0,0,.05));finish(bpy.context.object,'Pressurized habitat ring',ivory,root,.0)
  cyl('Command core',(0,0,.10),.52,.62,navy,root)
  cyl('Armoured command cap',(0,0,.45),.48,.18,ivory,root)
  cyl('Observation glass',(0,0,.57),.25,.09,cyan,root)
  for a in range(4):
   angle=a*math.pi/2
   o=box('Ring connecting truss',(math.cos(angle)*.72,math.sin(angle)*.72,0),(.9,.16,.16),navy,root);o.rotation_euler.z=angle
   o=box('Docking collar',(math.cos(angle)*1.57,math.sin(angle)*1.57,.0),(.44,.43,.28),ivory,root);o.rotation_euler.z=angle
  for sign in [-1,1]:
   box('Solar boom',(sign*2.0,0,-.08),(1.4,.18,.18),navy,root)
   for row in [-1,1]:
    box('Panel frame',(sign*2.42,row*.70,-.1),(1.15,1.16,.10),ivory,root,.025)
    box('Photovoltaic field',(sign*2.42,row*.70,-.035),(1.03,1.04,.025),solar,root,.015)
    for i in range(3):box('Broad solar cell divider',(sign*2.42+(i-1)*.32,row*.70,-.012),(.018,1.02,.013),mid,root,.0)
  tube('Comms mast',(0,.3,.58),(0,.3,1.15),.045,navy,motion)
  cyl('Communication dish',(0,.3,1.18),.27,.07,ivory,motion,(.3,0,0))
 elif kind=='refinery':
  box('Recessed structural footing',(0,0,.08),(3.7,3.0,.16),navy,root,.09)
  for x in [-1.5,1.5]:
   for y in [-1.15,1.15]:
    box('Separate ceramic foundation foot',(x,y,.18),(.55,.5,.25),ivory,root,.08)
  box('Central pump enclosure',(0,.15,.78),(1.0,2.05,1.32),navy,root,.17)
  box('Pump stepped armoured roof',(0,.15,1.5),(1.08,1.8,.18),ivory,root,.09)
  box('Operator cyan window',(0,-.90,1.07),(.76,.045,.20),cyan,root,.025)
  for i in range(5):box('Heat exchanger intake',(0,-.93,.43+i*.09),(.72,.07,.035),mid,root,.01)
  for x in [-1.08,1.08]:
   cyl('Horizontal process tank',(x,0,.79),.50,2.0,ivory,root,(math.pi/2,0,0),32)
   for y in [-1.02,1.02]:
    cyl('Dark pressure vessel end',(x,y,.79),.46,.13,navy,root,(math.pi/2,0,0),32)
    cyl('Layered inspection cap',(x,y*1.05,.79),.32,.14,ivory,root,(math.pi/2,0,0),24)
    cyl('Copper pressure valve',(x,y*1.13,.79),.13,.12,copper,root,(math.pi/2,0,0),16)
   for y in [-.7,.7]:
    cyl('Tank supporting collar',(x,y,.79),.535,.14,mid,root,(math.pi/2,0,0),32)
    box('Vessel saddle foot',(x,y,.29),(.83,.30,.26),mid,root,.045)
   box('Recessed tank cyan panel',(x+.47,0,.93),(.035,.64,.14),cyan,root,.018)
   tube('Process riser',(x,.58,1.03),(x,.58,1.61),.065,copper,root)
   tube('Manifold crossfeed',(x,.58,1.61),(0,.58,1.61),.065,copper,root)
   for y in [-.47,.22]:
    box('Tank ceramic side segment',(x-.03,y,1.23),(.60,.52,.11),ivory,root,.055)
  for x in [-.23,.23]:
   cyl('Pump exhaust tower',(x,.62,1.78),.095,.57,navy,root)
   cyl('Tower heat shield',(x,.62,1.83),.12,.12,mid,root)
   cyl('Tower amber beacon',(x,.62,2.1),.035,.11,amber,root,verts=12)
  box('Service platform',(0,-1.27,.23),(.84,.5,.12),mid,root)
  for x in [-.34,0,.34]:box('Service stair rib',(x,-1.30,.32),(.06,.42,.035),ivory,root,.015)
 elif kind=='equipment':
  box('Workshop foot',(0,0,.1),(3.6,2.7,.2),navy,root,.1)
  assembly_shell(ivory,root)
  box('Assembly bay',(-.25,-.93,.62),(1.45,.08,.63),navy,root)
  box('Bay energy strip',(-.25,-.99,.94),(1.4,.02,.07),cyan,root,.01)
  box('Roof service platform',(-.25,.15,1.47),(1.8,1.5,.08),mid,root)
  for x in [-1.5,1.5]:
   box('Gantry pillar',(x,-.2,.87),(.18,.2,1.6),navy,root)
  box('Gantry crossbeam',(0,-.2,1.72),(3.2,.28,.22),ivory,root)
  box('Tool trolley',(.5,-.2,1.58),(.45,.45,.35),amber,motion)
  tube('Press spindle',(.5,-.2,1.44),(.5,-.2,1.02),.07,navy,motion)
  for i in range(4):box('Roof cooler',(-.7+i*.35,.6,1.53),(.14,.65,.16),ivory,root,.025)
 else:
  # An open cradle, not a filled box; layered collars retain a clear empty berth.
  box('Dock rear spine',(0,1.25,0),(4.1,.6,.4),navy,root,.12)
  box('Dock control bridge',(0,1.27,.36),(1.5,.58,.4),ivory,root)
  box('Bridge glazing',(0,.96,.40),(1.1,.04,.17),cyan,root,.015)
  for sign in [-1,1]:
   box('Dock arm',(sign*1.7,-.05,0),(.52,3.35,.42),ivory,root,.12)
   box('Inward service rail',(sign*1.4,-.05,.06),(.14,3.0,.14),navy,root,.03)
   for y in [-1.2,-.3,.6]:
    box('Service collar',(sign*1.67,y,.28),(.73,.35,.24),mid,root)
    box('Dock marker',(sign*1.39,y,.27),(.06,.20,.10),cyan,root,.015)
   box('Service pod',(sign*2.12,.5,-.08),(.5,1.0,.52),ivory,root)
   box('Pose actuator',(sign*1.75,-1.5,.45),(.16,.35,.45),navy,motion)
 # Additional layered construction and material breaks are authored geometry.
 if kind=='auto_explore':
  for i in range(16):
   a=i*math.tau/16
   o=box('Segmented habitat armour',(math.cos(a)*1.24,math.sin(a)*1.24,.24),(.40,.27,.15),ivory,root,.045);o.rotation_euler.z=a+math.pi/2
   o=box('Habitat cyan inset',(math.cos(a)*1.47,math.sin(a)*1.47,.06),(.18,.035,.07),cyan,root,.012);o.rotation_euler.z=a+math.pi/2
  bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=.55,location=(0,0,.33));o=bpy.context.object;o.scale.z=.65;finish(o,'Rounded command shell',ivory,root,0)
  for i in range(8):
   a=i*math.tau/8
   o=box('Command view port',(math.cos(a)*.49,math.sin(a)*.49,.40),(.24,.07,.13),cyan,root,.025);o.rotation_euler.z=a+math.pi/2
  for sign in [-1,1]:
   for y in [-.7,.7]:
    for i in range(6):
     box('Solar copper bus',(sign*2.42+(.43-i*.17),y,-.005),(.013,1.0,.015),copper,root,.003)
   cyl('Docking hub collar',(sign*1.7,0,.02),.24,.24,mid,root,(0,math.pi/2,0),24)
  for x,y in [(.28,.3),(-.22,.3),(.05,-.15)]:
   tube('Comms aerial',(x,y,.6),(x,y,1.1),.025,navy,motion)
   cyl('Aerial amber tip',(x,y,1.13),.03,.07,amber,motion,verts=12)
 elif kind=='equipment':
  for i in range(5):
   x=-1.10+i*.43;z=1.53-max(0,abs(x+.25)-.76)*.65
   o=box('Separated curved roof armour',(x,.02,z),(.37,1.45,.13),ivory,root,.055)
   if abs(x+.25)>.76:o.rotation_euler.y=(-.48 if x<-.25 else .48)
  box('Raised glazed assembly skylight',(.18,-.46,1.62),(1.46,.52,.12),cyan,root,.055)
  for x in [-1.26,1.26]:
   box('Service side annex',(x,.63,.59),(.60,1.02,.95),ivory,root,.14)
   for i in range(5):box('Annex cooler rib',(x,.19,.37+i*.12),(.46,.05,.045),navy,root,.01)
  for x in [-.76,-.25,.26]:
   box('Bay rolling shutter strip',(x,-.99,.53),(.40,.05,.45),mid,root,.03)
   box('Bay amber inspection marker',(x,-1.03,.76),(.25,.03,.035),amber,root,.008)
  for x in [-1.5,1.5]:
   cyl('Gantry joint',(x,-.2,1.6),.15,.24,copper,root,(math.pi/2,0,0),16)
   box('Gantry layered panel',(x,-.22,1.12),(.28,.27,.65),ivory,root,.05)
  tube('Articulated tool link',(.50,-.2,1.45),(.85,-.38,1.18),.075,mid,motion)
  cyl('Tool head',(.85,-.38,1.04),.16,.28,navy,motion)
 elif kind=='shipyard':
  for sign in [-1,1]:
   for i in range(6):
    y=-1.38+i*.49
    box('Segmented dock outer armour',(sign*1.76,y,.34),(.55,.41,.16),ivory,root,.05)
    tube('Diagonal skeletal brace',(sign*1.70,y-.20,-.36),(sign*1.70,y+.20,-.02),.05,mid,root)
    box('Dock outer rib',(sign*1.99,y,-.02),(.12,.13,.62),navy,root,.025)
    box('Dock amber approach light',(sign*1.45,y,.36),(.04,.10,.05),amber,root,.008)
   box('Continuous inner docking rail',(sign*1.36,-.05,.16),(.055,2.9,.055),cyan,root,.014)
   for y in [-1.45,1.16]:
    box('Layered docking head',(sign*1.76,y,.14),(.75,.46,.75),ivory,root,.1)
    box('Docking head recessed vent',(sign*1.76,y-.24,.15),(.48,.025,.34),navy,root,.03)
   tube('Berth overhead arch support',(sign*1.55,.6,.15),(sign*1.4,.6,1.1),.055,mid,root)
  tube('Berth overhead arch',(-1.4,.6,1.1),(1.4,.6,1.1),.065,ivory,root)
  for sign in [-1,1]:
   tube('End antenna',(sign*2.10,.60,.24),(sign*2.10,.60,1.0),.025,navy,motion)
   cyl('End navigation beacon',(sign*2.1,.6,1.03),.035,.08,amber,motion,verts=12)
 # Join static geometry and moving hardware separately, retaining material slots.
 for parent in [root,motion]:
  group=[o for o in parent.children if o.type=='MESH']
  if len(group)>1:
   bpy.ops.object.select_all(action='DESELECT')
   for o in group:o.select_set(True)
   bpy.context.view_layer.objects.active=group[0]
   bpy.ops.object.join()
   group[0].name='Architecture' if parent==root else 'Hardware'
 # Keep editable sources, export only runtime hierarchy.
 bpy.context.view_layer.update()
 atlas=bpy.data.images.load(str(OUT/'material-atlas.png'),check_existing=True)
 atlas.filepath='//../../assets/planets/facilities_v3/material-atlas.png'
 textured=[]
 for mat in [ivory,navy,mid,solar,copper]:
  node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=atlas
  link=mat.node_tree.links.new(node.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
  textured.append((mat,node,link))
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/(kind+'.blend')),compress=True)
 # Geometry-only GLB; Godot shares a single external atlas across all facilities.
 for mat,node,link in textured:mat.node_tree.links.remove(link)
 bpy.ops.object.select_all(action='DESELECT')
 for o in [root,*root.children_recursive]:o.select_set(True)
 bpy.context.view_layer.objects.active=root
 bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
 meshes=[o for o in root.children_recursive if o.type=='MESH']
 stats.append({'kind':kind,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'objects':len(meshes)})
(OUT/'model-stats.json').write_text(json.dumps(stats,indent=2))
