"""Blender 4.3+: blender -b -t 4 --python build_enemies.py (no external dependencies)."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
PROJECT=OUT.parents[3]
NAMES=['enemy-scout-1slot','enemy-medium-1slot','enemy-medium-2slot','enemy-large-4slot','enemy-large-6slot','enemy-super-8slot']
LABELS=['compact wedge / single drive','forked twin hull / twin drive','wide swept shoulders / twin drive','hammerhead / twin drive','long armored outriggers / triple drive','citadel / four drive']
PAL={'frame':(.028,.044,.060),'armor':(.12,.16,.19),'edge':(.29,.34,.37),'rust':(.28,.055,.023),'amber':(.95,.32,.045),'glass':(.075,.15,.17)}
def slab(name,pts,z,h,mat):
 # Keep the exact footprint. Broad sloped armor edges expose side planes even
 # under the unchanged vertical camera; consistent winding gives real normals.
 area=sum(pts[i][0]*pts[(i+1)%len(pts)][1]-pts[(i+1)%len(pts)][0]*pts[i][1] for i in range(len(pts)))
 if area<0:pts=list(reversed(pts))
 n=len(pts);cx=sum(x for x,y in pts)/n;cy=sum(y for x,y in pts)/n
 width=max(x for x,y in pts)-min(x for x,y in pts);length=max(y for x,y in pts)-min(y for x,y in pts)
 rim=min(.19,min(width,length)*.16,h*.48)
 roof=[(cx+(x-cx)*(1-2*rim/width),cy+(y-cy)*(1-2*rim/length)) for x,y in pts]
 verts=[(x,y,z) for x,y in pts]+[(x,y,z+h*.25) for x,y in pts]+[(x,y,z+h) for x,y in roof]
 faces=[tuple(reversed(range(n))),tuple(range(2*n,3*n))]
 faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 faces += [(i+n,(i+1)%n+n,(i+1)%n+2*n,i+2*n) for i in range(n)]
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);ob.data.materials.append(M[mat])
 # Lower skirt is deliberately darker; slopes retain the top material and lighting.
 ob.data.materials.append(M['frame'])
 for poly in me.polygons:
  if 2<=poly.index<2+n:poly.material_index=1
 mod=ob.modifiers.new('Small edge glints','BEVEL');mod.width=.016;mod.segments=1
 ob.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');return ob
def box(name,x,y,w,l,z,h,mat):
 c=min(w,l)*.16
 return slab(name,[(x-w/2+c,y-l/2),(x+w/2-c,y-l/2),(x+w/2,y-l/2+c),(x+w/2,y+l/2-c),(x+w/2-c,y+l/2),(x-w/2+c,y+l/2),(x-w/2,y+l/2-c),(x-w/2,y-l/2+c)],z,h,mat)
def hull(points):
 slab('Graphite keel',points,-.3,.5,'frame');slab('Armored deck',[(x*.94,y*.96) for x,y in points],.18,.32,'armor')
def drive(x,y,w=.6):
 box('Engine cowling',x,y,w,.8,-.12,.58,'armor');box('Engine inset',x,y-.05,w*.54,.48,.47,.035,'frame');box('Exhaust lip',x,y-.35,w*.95,.2,.04,.26,'edge');box('Amber exhaust',x,y-.45,w*.7,.14,.07,.18,'amber')
def build(t):
 if t==1:
  hull([(-.55,2.5),(.55,2.5),(1.25,.1),(.9,-2.1),(-.9,-2.1),(-1.25,.1)])
  for s in [-1,1]:box('Rust shoulder',s*.76,-.4,.43,1.6,.52,.17,'rust')
  slab('Faceted nose shield',[(-.42,2.2),(.42,2.2),(.65,1.05),(-.65,1.05)],.51,.11,'edge')
  drive(0,-2.12,.95)
 elif t==2:
  box('Transverse bridge',0,-.5,3.9,1.8,-.25,.6,'frame')
  for s in [-1,1]:
   slab('Twin prow',[(s*.45,-2.55),(s*1.75,-2.55),(s*1.75,1.55),(s*1.1,2.7),(s*.5,2.25)],0,.5,'armor');box('Rust prow',s*1.1,1.45,.85,.8,.51,.13,'rust');drive(s*1.08,-2.55,.85)
 elif t==3:
  hull([(-.55,2.45),(.55,2.45),(1,1.2),(2.3,.4),(2.1,-1.7),(.85,-2.65),(-.85,-2.65),(-2.1,-1.7),(-2.3,.4),(-1,1.2)])
  for s in [-1,1]:
   slab('Swept rust plate',[(s*1,.65),(s*2.1,.15),(s*1.85,-.8),(s*1,-1.35)],.52,.18,'rust');drive(s*1.15,-2.0,.75)
 elif t==4:
  hull([(-1.0,3), (1,3),(1,-2.75),(.7,-3),(-.7,-3),(-1,-2.75)])
  box('Hammerhead cross armor',0,1.65,4.6,1.5,.16,.52,'armor')
  for s in [-1,1]:box('Hammerhead rust tip',s*1.8,1.7,.6,1.25,.69,.15,'rust');box('Aft hip',s*1.3,-1.65,.8,1.8,.1,.45,'armor');drive(s*1.3,-2.45,.7)
 elif t==5:
  hull([(-.65,3.65),(.65,3.65),(1.05,2.4),(1.05,-3.2),(-1.05,-3.2),(-1.05,2.4)])
  box('Outrigger bridge',0,0,4.3,2.8,-.2,.45,'frame')
  for s in [-1,1]:
   box('Long sponson',s*1.7,-.2,.88,5.55,.1,.48,'armor');box('Rust prow panel',s*1.7,1.4,.65,1.7,.59,.14,'rust');box('Aft segmented plate',s*1.7,-1.4,.64,1.25,.59,.13,'edge');drive(s*1.7,-2.9,.73)
  drive(0,-3.22,.7)
 else:
  hull([(-1.2,3.7),(1.2,3.7),(2.3,2.4),(2.3,-2.7),(1.55,-3.6),(-1.55,-3.6),(-2.3,-2.7),(-2.3,2.4)])
  for s in [-1,1]:
   box('Forward armored tower',s*1.55,1.75,1.08,2.2,.51,.30,'rust');box('Citadel side plate',s*1.6,-1.25,1.03,2.7,.51,.2,'edge')
  box('Blunt bow cap',0,3.15,1.8,.55,.51,.18,'edge')
  for x in [-1.5,-.5,.5,1.5]:drive(x,-3.35,.66)
 # A few broad steps, kept within each original outline (no extra silhouette clutter).
 if t in [3,4,5]:
  y={3:1.65,4:2.48,5:2.68}[t]
  box('Raised bow shield',0,y,.93,1.05,.51,.30,'armor')
 if t==6:
  box('Citadel forward shelf',0,2.25,1.55,.9,.51,.28,'armor')
  box('Citadel aft recess',0,-2.45,1.75,.65,.51,.04,'frame')
 box('Recessed command well',0,-.3,1.00 if t<4 else 1.4,2.3 if t<4 else 3.7,.505,.035,'frame')
 # Raised axial command spine; no installed weapons, turrets, or projectiles.
 box('Command spine',0,-.3,.72 if t<4 else 1.08,2 if t<4 else 3.4,.52,.37,'edge')
 box('Recessed bridge glass',0,.28,.49 if t<4 else .78,.63,.9,.05,'glass')
 box('Amber forward marker',0,.76,.3,.15,.91,.04,'amber')
 box('Rust axial stripe',0,-.95,.26,.65,.9,.04,'rust')

records=[]
visuals=json.load(open(PROJECT/'data/ship_weapon_visuals.json'))['ships']
data=json.load(open(PROJECT/'data/game_data.json'))
for t,name in enumerate(NAMES,1):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 M={}
 for key,rgb in PAL.items():
  m=bpy.data.materials.new(key);m.diffuse_color=(*rgb,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Roughness'].default_value=.72
  if key=='amber':p.inputs['Emission Color'].default_value=(*rgb,1);p.inputs['Emission Strength'].default_value=.55
  M[key]=m
 build(t)
 # GLB exports only reusable geometry; +Y bow converts to Godot -Z, origin at canvas center.
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=False
 scene.render.resolution_x=887;scene.render.resolution_y=1774;scene.render.resolution_percentage=100
 scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
 scene.world.use_nodes=True;scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.48,.53,.60,1);scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.18;scene.view_settings.view_transform='Standard';scene.view_settings.look='Medium High Contrast' if False else 'None'
 bpy.ops.object.camera_add(location=(0,0,20));cam=bpy.context.object;cam.name='Top down sprite camera';cam.data.type='ORTHO';cam.data.ortho_scale=10.8;scene.camera=cam
 # Godot key rotation (-35,-50,0), transformed to Blender and pre-rotated
 # by PI so the downward-facing runtime sprite receives the same world light.
 # Preserve the true top-down camera; only geometry and illumination change.
 bpy.ops.object.light_add(type='SUN',location=(6.275,5.265,5.736));o=bpy.context.object
 o.name='Prototype directional key';o.data.energy=2.0;o.data.angle=math.radians(5);o.data.color=(1,.956,.88)
 o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(name+'.blend')));bpy.ops.render.render(write_still=True)
 rec={'id':'enemy_'+str(t),'size':t,'silhouette':LABELS[t-1],'glb':name+'.glb','sprite':name+'.png','original_texture':visuals['enemy_'+str(t)]['texture'],'slot_map':visuals['enemy_'+str(t)]['slot_map'],'hardpoints':visuals['enemy_'+str(t)]['hardpoints'],'configured_enemy_ids':[e['id'] for e in data['enemies'].values() if int(e['size'])==t]};records.append(rec)
(OUT/'manifest.json').write_text(json.dumps({'base_commit':'5fd7473d81f7340dc7e075c6c51d62e1c8478b4a','canvas':[887,1774],'pivot':[.5,.5],'sprite_bow':'up','runtime_rotation_radians':math.pi,'blender_bow':'+Y','glb_godot_bow':'-Z','units':'meters','camera_vertical_span':10.8,'ships':records},indent=2)+'\n')
