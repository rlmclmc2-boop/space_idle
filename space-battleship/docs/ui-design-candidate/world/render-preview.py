"""Offline layout evidence from existing meshes/maps; never exports runtime assets or game data.
Run: blender --background --python world/render-preview.py from ui-design-candidate.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent/'assets'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=False
scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
scene.world.color=(.45,.45,.45);scene.view_settings.view_transform='Standard'
def mat(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*color,1);return m
def cube(name,loc,scale,m):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m);b=o.modifiers.new('soft','BEVEL');b.width=.5;b.segments=2;o.modifiers.new('normals','WEIGHTED_NORMAL');return o
def light(loc,power,size):
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
light((10,-25,65),55000,70);light((-50,15,35),25000,60)
bpy.ops.object.camera_add(location=(74,-92,84));camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=100;scene.camera=camera
ivory=mat('preview-platform',(.62,.70,.66));blue=mat('preview-support',(.12,.23,.29))
def model(path,x,y,scale):
 old=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/path));new=set(bpy.data.objects)-old;empt=bpy.data.objects.new('preview-anchor',None);scene.collection.objects.link(empt)
 for o in new:
  if o.parent not in new:o.parent=empt
 pts=[o.matrix_world@Vector(c) for o in new if o.type=='MESH' for c in o.bound_box]
 if pts:
  lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
  empt.location=(x-(lo.x+hi.x)*scale/2,y-(lo.y+hi.y)*scale/2,1-lo.z*scale);empt.scale=(scale,)*3
 return new|{empt}
entries=[('hq','core/galaxy_core.glb',0,0,.85),('n1','buildings/colony_ring/colony_ring_lv2.glb',-27,-22,1.2),('n2','buildings/interstellar_refinery/interstellar_refinery_lv2.glb',0,-30,1.2),('n3','buildings/orbital_shipyard/orbital_shipyard_lv2.glb',27,-22,1.2),('n4','buildings/stellar_energy_array/stellar_energy_array_lv2.glb',-30,4,1.2),('n5','buildings/crystal_refinery/crystal_refinery_lv2.glb',30,4,1.2),('n6','buildings/heavy_element_refinery/heavy_element_refinery_lv2.glb',-20,27,1.2),('n7','buildings/colony_ring/colony_ring_lv1.glb',8,30,1.2)]
groups={};anchors={}
for key,path,x,y,scale in entries:
 size=25 if key=='hq' else 14;cube('preview foundation '+key,(x,y,-.1),(size,size,1.3),ivory);cube('preview collar '+key,(x,y,-1),(size*.83,size*.83,1),blue)
 groups[key]=model(Path('assets/galaxy/v3')/path,x,y,scale)
 uv=world_to_camera_view(scene,camera,Vector((x,y,3)));anchors[key]=[round(uv.x*1600,2),round((1-uv.y)*1000,2)]
# Layout-only connectors; not a gameplay blueprint or an asset replacement.
for key,path,x,y,scale in entries[1:]:
 length=math.hypot(x,y);o=cube('preview connector '+key,(x/2,y/2,-.2),(2.7,length,1),blue);o.rotation_euler.z=-math.atan2(x,y)
scene.render.filepath=str(OUT/'galaxy-developed.png');bpy.ops.render.render(write_still=True)
for o in groups['n3']:o.hide_render=True
scene.render.filepath=str(OUT/'galaxy-foundation.png');bpy.ops.render.render(write_still=True)
(OUT/'galaxy-anchors.json').write_text(json.dumps({'scope':'offline layout sample; not runtime blueprint','canvas':[1600,1000],'anchors':anchors,'source':'assets/galaxy/v3/manifest.json'},indent=2)+'\n')
# Planet uses the existing toon albedo, not newly generated artwork; runtime retains its own shader.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene.render.resolution_x=900;scene.render.resolution_y=900
bpy.ops.mesh.primitive_uv_sphere_add(segments=96,ring_count=48,radius=4);o=bpy.context.object
m=mat('existing-origin-map',(.6,.7,.6));nodes=m.node_tree.nodes;tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load('/tmp/origin-surface.png');m.node_tree.links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color']);nodes.get('Principled BSDF').inputs['Roughness'].default_value=.9;o.data.materials.append(m)
for p in o.data.polygons:p.use_smooth=True
light((-8,-12,18),4200,14);light((12,8,8),1800,12)
bpy.ops.object.camera_add(location=(6,-10,6));camera=bpy.context.object;camera.rotation_euler=(-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=9.5;scene.camera=camera
scene.render.filepath=str(OUT/'origin-planet-preview.png');bpy.ops.render.render(write_still=True)
