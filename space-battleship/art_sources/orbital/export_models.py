"""Export edited Facility geometry and studio icons from the four .blend files.
Run with Blender --background --python export_models.py. Does not regenerate geometry.
"""
import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
OUT=ROOT.parents[1]/'assets/planets/orbital/models'
stats=[]
for kind in ['auto_explore','refinery','equipment','shipyard']:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/(kind+'.blend')))
 root=bpy.data.objects['Facility']
 objects=[root,*root.children_recursive]
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objects:obj.select_set(True)
 bpy.context.view_layer.objects.active=root
 bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
 meshes=[obj for obj in objects if obj.type=='MESH']
 stats.append({'kind':kind,'triangles':sum(sum(len(face.vertices)-2 for face in obj.data.polygons) for obj in meshes),'mesh_objects':len(meshes),'material_surfaces':sum(len(obj.data.materials) for obj in meshes)})
 bpy.context.scene.render.filepath=str(OUT/(kind+'-icon.png'))
 bpy.ops.render.render(write_still=True)
(OUT/'model-stats.json').write_text(json.dumps(stats,indent=2),encoding='utf-8')
