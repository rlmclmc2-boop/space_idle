"""Editable replacement planet architecture. Blender source -> GLB; no gameplay data.
Y-up model convention is exported from Blender Z-up. Facility root/Motion retained.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
OUT=ROOT.parents[1]/'assets/planets/facilities_v4'

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
 navy=material('Deep teal structural metal',(.085,.14,.16),.35,.42)
 mid=material('Teal secondary panels',(.14,.23,.24),.25,.46)
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

  for x in [-1.5,1.5]:
   for y in [-.95,.95]:
    cyl('Terrain embedded socket',(x,y,.05),.27,.80,ivory,root,verts=16)
  box('Central pump enclosure',(0,.15,.78),(1.0,2.05,1.32),ivory,root,.20)
  box('Pump stepped armoured roof',(0,.15,1.5),(1.08,1.8,.18),ivory,root,.09)
  for y in [-.65,.65]:cyl('Pump ground socket',(0,y,.04),.20,.76,ivory,root,verts=16)
  box('Pump lower recess',(0,-.905,.55),(.76,.035,.44),mid,root,.035)
  box('Operator cyan window',(0,-.90,1.07),(.76,.045,.20),cyan,root,.025)
  for i in range(5):box('Heat exchanger intake',(0,-.93,.43+i*.09),(.72,.07,.035),mid,root,.01)
  for x in [-1.08,1.08]:
   cyl('Horizontal process tank',(x,0,.79),.50,2.0,ivory,root,(math.pi/2,0,0),32)
   for y in [-1.02,1.02]:
    cyl('Dark pressure vessel end',(x,y,.79),.46,.10,mid,root,(math.pi/2,0,0),32)
    cyl('Layered inspection cap',(x,y*1.05,.79),.43,.13,ivory,root,(math.pi/2,0,0),32)
    cyl('Copper pressure valve',(x,y*1.13,.79),.13,.12,copper,root,(math.pi/2,0,0),16)
   for y in [-.7,.7]:
    cyl('Tank supporting collar',(x,y,.79),.535,.14,mid,root,(math.pi/2,0,0),32)
    box('Vessel saddle foot',(x,y,.29),(.83,.30,.26),mid,root,.045)
   box('Recessed tank cyan panel',(x+.47,0,.93),(.035,.64,.14),cyan,root,.018)
   tube('Process riser',(x,.58,1.03),(x,.58,1.61),.065,copper,root)
   tube('Manifold crossfeed',(x,.58,1.61),(0,.58,1.61),.065,copper,root)

  for x in [-.23,.23]:
   cyl('Pump exhaust tower',(x,.62,1.78),.095,.57,navy,root)
   cyl('Tower heat shield',(x,.62,1.83),.12,.12,mid,root)
   cyl('Tower amber beacon',(x,.62,2.1),.035,.11,amber,root,verts=12)
  box('Service platform',(0,-1.27,.23),(.84,.5,.12),mid,root)
  for x in [-.34,0,.34]:box('Service stair rib',(x,-1.30,.32),(.06,.42,.035),ivory,root,.015)
 elif kind=='equipment':
  for x in [-1.1,1.1]:
   for y in [-.8,.8]:cyl('Terrain embedded socket',(x,y,.05),.26,.80,ivory,root,verts=16)
  assembly_shell(ivory,root)
  box('Assembly bay',(-.25,-.93,.62),(1.45,.08,.63),navy,root)
  box('Bay energy strip',(-.25,-.99,.94),(1.4,.02,.07),cyan,root,.01)

  for x in [-1.5,1.5]:
   box('Gantry pillar',(x,-.2,.87),(.18,.2,1.6),navy,root)
  for x in [-1.5,1.5]:cyl('Gantry ground socket',(x,-.2,.02),.18,.78,ivory,root,verts=16)
  box('Gantry crossbeam',(0,-.2,1.72),(3.2,.28,.22),ivory,root)
  box('Tool trolley',(.5,-.2,1.58),(.45,.45,.35),amber,motion)
  tube('Press spindle',(.5,-.2,1.44),(.5,-.2,1.02),.07,navy,motion)

 else:
  # Slender open drydock: repeated ribs and narrow rails, not solid U arms.
  for sign in [-1,1]:
   box('Slender docking rail',(sign*1.48,0,-.25),(.14,3.85,.16),mid,root,.035)
   box('Inner cyan guidance line',(sign*1.39,0,-.18),(.035,3.5,.035),cyan,root,.009)
   for y in [-1.45,-.55,.35,1.25]:
    points=[(sign*1.48,y,-.25),(sign*1.48,y,.73),(sign*1.12,y,1.10)]
    for i in range(2):tube('Open dock rib',points[i],points[i+1],.055,ivory,root)
    cyl('Rib heel',(sign*1.48,y,-.23),.095,.18,ivory,root)
    box('Amber berth marker',(sign*1.43,y,.5),(.04,.09,.05),amber,root,.008)
   cyl('Dockside service capsule',(sign*1.88,.95,.12),.23,.85,ivory,root,(math.pi/2,0,0),24)
   tube('Pod support',(sign*1.48,.95,-.15),(sign*1.88,.95,.12),.045,mid,root)
   for y in [-1.45,-.55,.35]:tube('Low diagonal brace',(sign*1.48,y,-.33),(sign*1.48,y+.9,-.13),.022,copper,root)
  for y in [-1.45,-.55,.35,1.25]:tube('Crown spanning rib',(-1.12,y,1.10),(1.12,y,1.10),.045,ivory,root)
  box('Compact rear control pod',(0,1.7,.65),(1.12,.56,.42),ivory,root,.13)
  box('Control glazing',(0,1.40,.68),(.84,.035,.17),cyan,root,.022)
  tube('Rear bridge support',(-1.48,1.25,.73),(0,1.7,.44),.045,mid,root)
  tube('Rear bridge support',(1.48,1.25,.73),(0,1.7,.44),.045,mid,root)
 # Additional layered construction and material breaks are authored geometry.
 if kind=='auto_explore':
  bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=.55,location=(0,0,.33));o=bpy.context.object;o.scale.z=.65;finish(o,'Rounded command shell',ivory,root,0)
  for i in range(4):
   a=i*math.tau/4
   o=box('Broad command view port',(math.cos(a)*.49,math.sin(a)*.49,.40),(.36,.065,.13),cyan,root,.035);o.rotation_euler.z=a+math.pi/2
 elif kind=='equipment':
  box('Broad glazed skylight',(.05,-.40,1.53),(1.35,.50,.10),cyan,root,.06)
  box('Rounded service annex',(1.22,.55,.59),(.65,.98,.96),ivory,root,.20)
  box('Single annex intake',(1.23,.04,.55),(.43,.035,.28),mid,root,.04)
  for x in [-1.5,1.5]:cyl('Gantry pivot',(x,-.2,1.6),.14,.22,copper,root,(math.pi/2,0,0),16)
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
 atlas.filepath='//../../assets/planets/facilities_v4/material-atlas.png'
 textured=[]
 for mat in [solar,copper]:
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
