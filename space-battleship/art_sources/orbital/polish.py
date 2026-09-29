"""Blender 4.5: refine approved orbital silhouettes and export runtime GLBs/icons.
Run with blender --background --python polish.py. Sources are local base-*.glb.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
OUT=ROOT.parents[1]/'assets/planets/orbital/models'
OUT.mkdir(parents=True,exist_ok=True)
KINDS=['auto_explore','refinery','equipment','shipyard']
def linear(v):return v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4
def mat(name,hexcode,metal,rough,emission=0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 rgb=tuple(linear(int(hexcode[i:i+2],16)/255) for i in (0,2,4))
 m.diffuse_color=(*rgb,1);p=m.node_tree.nodes.get('Principled BSDF')
 p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if emission:p.inputs['Emission Color'].default_value=(*rgb,1);p.inputs['Emission Strength'].default_value=emission
 return m
def xyz(v):return Vector((v[0],-v[2],v[1]))
def attach(obj,parent):
 world=obj.matrix_world.copy();obj.parent=parent;obj.matrix_world=world
 return obj
def block(name,pos,size,material,parent,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(pos));o=bpy.context.object;o.name=name
 o.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(material);attach(o,parent)
 if bevel:finish(o,bevel)
 return o
def finish(o,amount=.025):
 bpy.context.view_layer.objects.active=o;o.select_set(True)
 mod=o.modifiers.new('Machined edge radii','BEVEL');mod.width=amount;mod.segments=2;mod.limit_method='ANGLE';mod.angle_limit=.52
 bpy.ops.object.modifier_apply(modifier=mod.name)
 for face in o.data.polygons:face.use_smooth=True
 mod=o.modifiers.new('Weighted machining normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=40
 bpy.ops.object.modifier_apply(modifier=mod.name);o.select_set(False)
def ancestor(o,parent):
 while o:
  if o==parent:return True
  o=o.parent
 return False
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
def lamp(name,loc,power,color,size):
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
 o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.location=loc;aim(o,(0,0,0))
 return o
stats=[]
for kind in KINDS:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/('base-'+kind+'.glb')))
 root=next(o for o in bpy.context.scene.objects if o.parent is None);root.name='Facility'
 motion=bpy.data.objects.get('Motion')
 ceramic=mat('01 Ceramic titanium','c1ced3',.48,.32)
 navy=mat('02 Structural graphite','23394b',.72,.39)
 copper=mat('03 Copper thermal hardware','997552',.75,.3)
 blue=mat('04 Photovoltaic glass','174974',.65,.26)
 glow=mat('05 Cyan navigation glass','6edce7',.25,.24,.8)
 white=mat('06 Service markings','ecf0e8',.18,.46)
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH':continue
  o.data=o.data.copy()
  for i,slot in enumerate(o.material_slots):
   old=slot.material;rgb=old.diffuse_color[:3]
   emission=old.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value
   if emission>.01 and max(old.node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value[:3])>.01:replacement=glow
   elif rgb[0]>.3 and rgb[0]>rgb[2]*2:replacement=copper
   elif max(rgb)>.3:replacement=ceramic
   elif rgb[2]>rgb[0]*3.8:replacement=blue
   else:replacement=navy
   o.data.materials[i]=replacement
  bpy.ops.object.select_all(action='DESELECT')
  finish(o,min(.025,min(o.dimensions)*.15))
 # Large, legible hardware and seams; no noise that disappears at orbital size.
 if kind=='auto_explore':
  for i in range(8):
   a=i*math.tau/8;x=math.cos(a)*1.8;z=math.sin(a)*1.8
   o=block('Habitat segmented armor',(x,.27,z),(.55,.12,.55),navy,motion)
   o.rotation_euler.z=-a
   block('Habitat service stripe',(x,.345,z),(.18,.026,.38),white,motion,.006)
  for y in [-.75,-.3,.3,.75]:
   block('Command hull access',(0,y,-.38),(.30,.28,.06),navy,root,.012)
  for side in [-1,1]:
   block('Array hinge',(side*1.2,-.7,0),(.48,.30,.4),ceramic,root)
   block('Array hinge light',(side*1.2,-.51,0),(.23,.055,.12),glow,root,.01)
 elif kind=='refinery':
  for side in [-1,1]:
   for y in [-.65,.65]:
    block('Tank longitudinal insulation',(side*1.28,y+.39,-.25),(.47,.08,1.65),ceramic,root)
    for z in [-.70,.23]:block('Tank caution band',(side*1.28,y+.44,z),(.48,.03,.12),navy,root,.008)
   block('Thermal manifold',(side*.68,0,1.7),(.40,.52,.30),navy,root)
   block('Manifold indicator',(side*.68,.28,1.7),(.18,.04,.12),glow,root,.006)
  for z in [-1.15,-.55,.05,.65]:block('Core service panel',(0,.645,z),(.5,.055,.36),navy,root,.012)
 elif kind=='equipment':
  for side in [-1,1]:
   block('Manufacturing module armor',(side*1.35,.46,-.8),(.58,.12,1.35),navy,root)
   for z in [-1.2,-.7,-.2]:block('Module identification stripe',(side*1.35,.535,z),(.40,.025,.08),white,root,.005)
   for y in [-.8,.8]:
    block('Assembly clamp',(side*.8,y,2.4),(.27,.27,.36),ceramic,root)
    block('Clamp lamp',(side*.8,y+.16,2.4),(.10,.045,.18),glow,root,.006)
  for z in [-1.1,-.5,.1]:block('Central armored hatch',(0,.8,z),(.65,.08,.38),navy,root)
  for side in [-1,1]:block('Manipulator joint',(side*1.7,.8,1.5),(.33,.32,.33),navy,motion)
 elif kind=='shipyard':
  for side in [-1,1]:
   for z in [-2.4,-1.2,0,1.2,2.4]:
    block('Truss armored coupling',(side*1.75,-.8,z),(.66,.60,.34),navy,root)
    block('Docking guidance strip',(side*1.75,-.455,z),(.42,.075,.13),glow,root,.008)
   for z in [-2.0,1.8]:
    for a in [.30*math.pi,.70*math.pi,1.18*math.pi,1.65*math.pi]:
     x=2*math.cos(a);y=2*math.sin(a)
     block('Segmented docking collar',(x,y,z),(.28,.30,.42),ceramic,root)
  block('Traffic control observation',(0,-1.59,1.5),(.52,.10,.72),navy,root)
  block('Traffic control glazing',(0,-1.52,1.5),(.36,.05,.48),glow,root,.01)
 # Keep only two mesh objects: stationary shell and animated hardware.
 for parent,name in [(motion,'AnimatedHardware'),(root,'StaticHull')]:
  objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and (ancestor(o,motion) if parent==motion else not ancestor(o,motion))]
  if not objects:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
  obj=bpy.context.object;obj.name=name;attach(obj,parent)
  # Collapse duplicate material slots after joining, without changing face assignments.
  old=list(obj.data.materials);unique=[];mapping={}
  for i,m in enumerate(old):
   if m not in unique:unique.append(m)
   mapping[i]=unique.index(m)
  indices=[mapping[p.material_index] for p in obj.data.polygons]
  obj.data.materials.clear()
  for m in unique:obj.data.materials.append(m)
  for p,index in zip(obj.data.polygons,indices):p.material_index=index
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
 stats.append({'kind':kind,'triangles':triangles,'mesh_objects':len(meshes),'material_surfaces':sum(len(o.data.materials) for o in meshes)})
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
 # Source files contain the editable model and a separate studio setup.
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
 scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
 scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
 scene.world=bpy.data.worlds.new('Studio ambient');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.17,.22,.30,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
 lamp('Key',(4,-6,8),1100,(.80,.90,1),5)
 lamp('Warm rim',(-5,3,4),1400,(1,.76,.47),4)
 lamp('Soft fill',(-4,-2,3),500,(.48,.68,1),4)
 camera=bpy.data.objects.new('StudioCamera',bpy.data.cameras.new('StudioCamera'));scene.collection.objects.link(camera)
 camera.location=(7,-10,7);aim(camera,(0,0,0));camera.data.type='ORTHO';camera.data.ortho_scale=8.0;scene.camera=camera
 scene.view_settings.view_transform='AgX'
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/(kind+'.blend')))
 scene.render.filepath=str(OUT/(kind+'-icon.png'));bpy.ops.render.render(write_still=True)
 print('FINISHED',kind,triangles,flush=True)
(OUT/'model-stats.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
