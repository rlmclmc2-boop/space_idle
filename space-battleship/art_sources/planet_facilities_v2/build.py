"""Editable replacement planet architecture. Blender source -> GLB; no gameplay data.
Y-up model convention is exported from Blender Z-up. Facility root/Motion retained.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
OUT=ROOT.parents[1]/'assets/planets/facilities_v2'

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
 return obj

def box(name,loc,scale,mat,parent,bevel=.06):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,mat,parent,bevel)
def cyl(name,loc,radius,depth,mat,parent,rotation=(0,0,0),verts=24):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=loc,rotation=rotation);return finish(bpy.context.object,name,mat,parent,.045)
def tube(name,a,b,r,mat,parent):
 a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,mat,parent);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
stats=[]
for kind in ['auto_explore','refinery','equipment','shipyard']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 ivory=material('Ivory ceramic armour',(.83,.80,.69),.15,.38)
 navy=material('Deep teal structural metal',(.045,.10,.13),.55,.4)
 mid=material('Teal secondary panels',(.12,.24,.26),.45,.45)
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
  box('Foundation contact plinth',(0,0,.10),(3.4,2.8,.20),navy,root,.1)
  box('Ceramic perimeter',(0,0,.24),(3.25,2.65,.14),ivory,root,.08)
  box('Process hall',(-.78,0,.78),(1.2,2.14,1.0),ivory,root,.14)
  box('Control window',(-1.395,-.2,.89),(.04,1.22,.26),cyan,root,.02)
  box('Recessed hall roof',(-.78,0,1.33),(1.02,1.94,.12),mid,root)
  for y in [-.72,.72]:
   cyl('Processing vessel',(.73,y,.86),.48,1.2,ivory,root)
   cyl('Tank dark collar',(.73,y,.43),.50,.16,navy,root)
   cyl('Tank armoured head',(.73,y,1.5),.44,.14,ivory,root)
   cyl('Tank amber inspection port',(.73,y,1.59),.15,.04,amber,root)
   tube('Supply pipe',(.73,y,.32),(1.4,y,.32),.075,copper,root)
  tube('Distribution manifold',(1.4,-.8,.32),(1.4,.8,.32),.085,copper,root)
  for i in range(4):box('Vent slat',(-.78,-.65+i*.4,1.42),(.65,.15,.08),navy,root,.025)
  box('Service hatch',(0,-1.37,.54),(.72,.08,.6),mid,root)
  box('Status band',(0,-1.42,.75),(.5,.025,.065),cyan,root,.01)
 elif kind=='equipment':
  box('Workshop foot',(0,0,.1),(3.6,2.7,.2),navy,root,.1)
  box('Assembly hall',(-.25,.15,.76),(2.65,2.1,1.15),ivory,root,.15)
  box('Assembly bay',(-.25,-.93,.62),(1.45,.08,.63),navy,root)
  box('Bay energy strip',(-.25,-.99,.94),(1.4,.02,.07),cyan,root,.01)
  box('Roof service platform',(-.25,.15,1.39),(2.2,1.7,.12),mid,root)
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
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/(kind+'.blend')),compress=True)
 bpy.ops.object.select_all(action='DESELECT')
 for o in [root,*root.children_recursive]:o.select_set(True)
 bpy.context.view_layer.objects.active=root
 bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
 meshes=[o for o in root.children_recursive if o.type=='MESH']
 stats.append({'kind':kind,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'objects':len(meshes)})
(OUT/'model-stats.json').write_text(json.dumps(stats,indent=2))
