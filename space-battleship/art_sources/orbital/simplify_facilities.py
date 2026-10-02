"""Rebuild station/workshop/dock with the approved refinery's chunky matte style.
Blender --background --python this_file; preserves Facility/Motion and studio.
Only these three .blend/GLB/icon files and their statistics are replaced.
"""
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
OUT=ROOT.parents[1]/'assets/planets/orbital/models'
def xyz(p):return Vector((p[0],-p[2],p[1]))
def material(name,color):
 m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
 rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
 rgb=tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in rgb)
 m.diffuse_color=(*rgb,1);bsdf=m.node_tree.nodes.get('Principled BSDF')
 for key,value in [('Base Color',(*rgb,1)),('Metallic',0),('Roughness',.88),('Specular IOR Level',.08)]:bsdf.inputs[key].default_value=value
 return m
def attach(o,parent):
 world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world;o.select_set(False);return o
def block(name,p,d,mat,parent,bevel=.15):
 bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object;o.name=name
 o.dimensions=(d[0],d[2],d[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.data.materials.append(mat);mod=o.modifiers.new('Broad chamfer','BEVEL');mod.width=bevel;mod.segments=1
 bpy.ops.object.modifier_apply(modifier=mod.name);return attach(o,parent)
def footprint(name,polygon,low,high,mats,parent):
 # Single outward-facing silhouette; pale top/sides and navy underside.
 n=len(polygon);verts=[xyz((x,y,z)) for y in (low,high) for x,z in polygon]
 faces=[tuple(range(n)),tuple(reversed(range(n,n*2)))]
 faces.extend((i,i+n,(i+1)%n+n,(i+1)%n) for i in range(n))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces)
 for mat in mats:mesh.materials.append(mat)
 for face in mesh.polygons:face.material_index=min(1,len(mats)-1) if face.index==0 else 0
 mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return attach(o,parent)
stats=json.loads((OUT/'model-stats.json').read_text())
kinds=['auto_explore','equipment','shipyard']
selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else kinds
assert selected and all(kind in kinds for kind in selected)
for kind in selected:
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/(kind+'.blend')))
 root,motion=bpy.data.objects['Facility'],bpy.data.objects['Motion']
 for o in list(root.children_recursive):
  if o.type=='MESH':bpy.data.objects.remove(o,do_unlink=True)
 cream=material('Orbital pale ceramic','f5efd9');navy=material('Orbital navy structure','264756')
 amber=material('Orbital amber hardware','fbc455');cyan=material('Orbital broad cyan glass','49cfb7');blue=material('Orbital solid solar blue','4087ac')
 if kind=='auto_explore':
  # Habitat + two uninterrupted paddles, no grid, struts or antennae.
  block('Chunky habitat',(0,0,0),(2.25,1.80,3.30),cream,root,.28)
  for x in [-2.05,2.05]:block('Broad solar paddle',(x,-.12,0),(1.90,.34,2.90),blue,root,.13)
  block('Single habitat window',(0,.12,-1.65),(1.50,.68,.06),cyan,root,.02)
  block('Broad radar head',(0,1.08,0),(1.25,.42,1.25),navy,motion,.13)
  block('Radar face',(0,1.30,0),(.92,.06,.92),cyan,motion,.02)
 elif kind=='equipment':
  # Squat workshop and oversized moving press define the contour.
  block('Workshop plinth',(0,-.65,0),(4.40,.70,3.60),navy,root,.23)
  block('Workshop housing',(0,.30,-.40),(3.40,1.65,2.80),cream,root,.25)
  block('Wide workshop window',(0,.30,-1.82),(2.25,.62,.07),cyan,root,.02)
  block('Press support',(-1.30,.62,1.08),(.72,1.85,.90),cream,root,.10)
  block('Oversized press head',(0,1.60,1.08),(2.65,.72,1.65),amber,motion,.22)
 else:
  # Thick open U cradle around one hull, no gantry lattice.
  footprint('Open docking cradle',[(-2.10,-2.55),(2.10,-2.55),(2.10,2.55),(1.05,2.55),(1.05,-1.35),(-1.05,-1.35),(-1.05,2.55),(-2.10,2.55)],-.85,-.10,[cream,navy],root)
  for x in [-1.58,1.58]:block('Amber docking end',(x,-.08,2.12),(.98,.22,.72),amber,root,.07)
  footprint('Single docked hull',[(0,-1.68),(.78,-.60),(.78,1.10),(.40,1.52),(-.40,1.52),(-.78,1.10),(-.78,-.60)],-.02,.66,[cream,navy],motion)
  block('Wide docked hull glass',(0,.69,-.12),(1.02,.07,.98),cyan,motion,.04)
 for parent,name in [(root,'StaticHull'),(motion,'AnimatedHardware')]:
  objects=[o for o in parent.children if o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
  original=list(o.data.materials);unique=list(dict.fromkeys(original));indices=[unique.index(original[f.material_index]) for f in o.data.polygons]
  o.data.materials.clear()
  for mat in unique:o.data.materials.append(mat)
  for face,slot in zip(o.data.polygons,indices):face.material_index=slot
 objects=[root,*root.children_recursive];bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=root
 bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
 meshes=[o for o in objects if o.type=='MESH'];row=next(r for r in stats if r['kind']==kind)
 row.update(triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in meshes),mesh_objects=len(meshes),material_surfaces=sum(len(o.data.materials) for o in meshes))
 scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.film_transparent=True;scene.render.filepath=str(OUT/(kind+'-icon.png'))
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/(kind+'.blend')));bpy.ops.render.render(write_still=True);print('FAMILY MODEL',row)
(OUT/'model-stats.json').write_text(json.dumps(stats,indent=2))
