import bpy,hashlib,json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[4];out=root/'docs/ui-redesign-plan/g1-internal/art/battle'
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=8;s.cycles.use_denoising=False;s.render.threads_mode='FIXED';s.render.threads=4;s.render.resolution_x=256;s.render.resolution_y=256;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.film_transparent=True
s.world=bpy.data.worlds.new('DesignWorld');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.8;s.view_settings.view_transform='Standard'
cd=bpy.data.cameras.new('Top');c=bpy.data.objects.new('Top',cd);s.collection.objects.link(c);s.camera=c;cd.type='ORTHO';cd.ortho_scale=2.6
for name,pos in [('Key',(-4,6,12)),('Fill',(5,-3,8))]:
 d=bpy.data.lights.new(name,'AREA');d.energy=900;d.size=8;o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=pos;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
record={'kind':'Design-only top-down base GLB derivatives; ornaments/ultimate and Godot toon shading not replicated; not runtime assets','projection':'orthographic top view, 2.6 model units across 256px, native GLB import axes','blender':bpy.app.version_string,'entries':[]}
for family in ['pulse','missile','rail','beam']:
 path=root/f'assets/hyperspace/models/{family}.glb';before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(path));objects=set(bpy.data.objects)-before
 pts=[o.matrix_world@Vector(p) for o in objects if o.type=='MESH' for p in o.bound_box];low=Vector([min(p[j] for p in pts) for j in range(3)]);high=Vector([max(p[j] for p in pts) for j in range(3)]);center=(low+high)/2;c.location=center+Vector((0,0,20));c.rotation_euler=(center-c.location).to_track_quat('-Z','Y').to_euler()
 s.render.filepath=str(out/f'{family}-top.png');bpy.ops.render.render(write_still=True)
 record['entries'].append({'family':family,'source':str(path.relative_to(root)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bounds_blender':[list(low),list(high)],'preview':f'{family}-top.png','preview_sha256':hashlib.sha256((out/f'{family}-top.png').read_bytes()).hexdigest(),'canvas':[256,256],'ortho':2.6})
 for o in objects:bpy.data.objects.remove(o,do_unlink=True)
(out/'drone-sources.json').write_text(json.dumps(record,indent=2)+'\n')
