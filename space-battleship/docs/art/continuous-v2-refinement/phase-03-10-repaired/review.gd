extends SceneTree
## Continuous V2 first transition. Production scenery shader; no combat state.
const PULSE=preload("res://dev/toon_ship/pulse_vfx.gd")
const MISSILE=preload("res://dev/toon_ship/missile_vfx.gd")
const RAIL=preload("res://dev/toon_ship/rail_vfx.gd")
class Backdrop extends Node2D:
 var mesh:ArrayMesh
 func _init()->void:
  mesh=ArrayMesh.new()
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(0,0,0),Vector3(572,0,0),Vector3(572,960,0),Vector3(0,960,0)])
  arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
  arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color(0,0,0,0),Color(0,0,0,0),Color(0,0,0,0),Color(0,0,0,0)])
  arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 func _draw()->void:draw_mesh(mesh,null)
class Specimens extends Node2D:
 var ships:Texture2D
 var rail=RAIL.new()
 var enabled:=true
 var regions=[Rect2(26,145,608,614),Rect2(638,125,568,635),Rect2(1220,140,536,635)]
 func _draw()->void:
  if not enabled:return
  var positions=[Vector2(100,160),Vector2(286,160),Vector2(470,160),Vector2(100,450),Vector2(286,450),Vector2(470,450),Vector2(100,790),Vector2(286,790),Vector2(470,790)]
  for row in 3:
   for col in 3:
    var region:Rect2=regions[col]
    var h:float=[30.0,50.0,80.0][row]/(400.0/572.0)
    var size=Vector2(region.size.x/region.size.y,1)*h
    draw_texture_rect_region(ships,Rect2(positions[row*3+col]-size*0.5,size),region)
  PULSE.flight(self,Vector2(240,360),Vector2.UP)
  PULSE.impact(self,positions[1]+Vector2(0,18),Vector2.UP,0.05,false)
  MISSILE.flight(self,Vector2(435,615),Vector2(-0.3,-1).normalized(),0.5,7,1.0,true,true)
  MISSILE.impact(self,positions[5]+Vector2(0,28),Vector2.UP,0.14,false,1.0,7)
  rail.penetration(self,Vector2(330,940),positions[7],Vector2.UP,0.09,1.0,Vector2(572,960))
  rail.impact(self,positions[7]+Vector2(0,50),Vector2.UP,0.02,false,1.0)
class Labels extends Node2D:
 var title="SOURCE JOIN / SAME VIEWPORT BEFORE AND AFTER"
 var captions=["98372699 / JOIN FAILED","REPAIRED / SAME STAGE 3 END","STAGE 4 END / CONTINUATION"]
 func _draw()->void:
  draw_string(ThemeDB.fallback_font,Vector2(20,32),title,HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("d9e5ea"))
  draw_string(ThemeDB.fallback_font,Vector2(20,61),"Production scenery shader / identical 30–50–80px ships and existing VFX / art review only",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
  for i in 3:draw_string(ThemeDB.fallback_font,Vector2(20+i*420,96),captions[i],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
  draw_string(ThemeDB.fallback_font,Vector2(20,812),"First two stages unchanged. New art uses offline grading + registered mast; no gameplay changes.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
func _initialize()->void:call_deferred("run")
func sample(texture:Texture2D)->Vector3:
 var h:float=texture.get_height()
 return Vector3(2.0/h,960.0/h,(h-964.0)/h)
func run()->void:
 var dir=OS.get_environment("OPENING_REVIEW_DIR");var project=OS.get_environment("OPENING_PROJECT_DIR")
 root.size=Vector2i(1280,850);root.content_scale_size=root.size
 var labels=Labels.new();root.add_child(labels)
 var textures=[]
 for stage in range(1,11):textures.append(ImageTexture.create_from_image(Image.load_from_file(dir+"/review/stage_%02d.png"%stage)))
 var old=ImageTexture.create_from_image(Image.load_from_file(project+"/docs/art/continuous-v2-refinement/phase-03-10/review/stage-3-candidate.png"))
 var ships=ImageTexture.create_from_image(Image.load_from_file(project+"/docs/art/opening-three/revision-03/enemies-topdown-source.png"))
 var materials=[];var clips=[];var backs=[];var actors=[]
 for i in 3:
  var clip=Control.new();clip.position=Vector2(20+i*420,110);clip.size=Vector2(400,672);clip.clip_contents=true;root.add_child(clip);clips.append(clip)
  var back=Backdrop.new();back.scale=Vector2.ONE*(400.0/572.0)
  var mat=ShaderMaterial.new();mat.shader=load("res://scripts/starfield.gdshader")
  var texture=old if i==0 else textures[2 if i==1 else 3]
  mat.set_shader_parameter("opening_enabled",true);mat.set_shader_parameter("opening_progress",1.0)
  mat.set_shader_parameter("opening_texture",texture);mat.set_shader_parameter("opening_sample",sample(texture))
  back.material=mat;clip.add_child(back);materials.append(mat);backs.append(back)
  var specimens=Specimens.new();specimens.ships=ships;specimens.scale=back.scale;clip.add_child(specimens);actors.append(specimens)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(dir+"/review/join-before-after.png")
 for page in [[3,4,5],[6,7,8],[8,9,10]]:
  labels.title="CONTINUOUS WORLD / STAGE-END VIEWPORTS"
  for i in 3:
   var stage:int=page[i];var texture:Texture2D=textures[stage-1]
   materials[i].set_shader_parameter("opening_texture",texture);materials[i].set_shader_parameter("opening_sample",sample(texture))
   labels.captions[i]="STAGE %02d / END"%stage
  labels.queue_redraw()
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(dir+"/review/stages-%d-%d.png"%[page[0],page[2]])
 DirAccess.make_dir_recursive_absolute("/tmp/opening-v2/full-frames")
 # No dissolve or cut: travel through all eight candidate stages, same actors.
 for frame in 321:
  var phase:float=float(frame)/40.0
  var index:int=mini(7,int(phase));var progress:float=phase-float(index)
  var texture:Texture2D=textures[index+2]
  materials[0].set_shader_parameter("opening_texture",texture);materials[0].set_shader_parameter("opening_sample",sample(texture));materials[0].set_shader_parameter("opening_progress",progress)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().get_region(Rect2i(20,110,400,672)).save_png("/tmp/opening-v2/full-frames/%03d.png"%frame)
 # Actual GPU overlap checks at both physical sampling scales.
 for actor in actors:actor.enabled=false;actor.queue_redraw()
 DirAccess.make_dir_recursive_absolute("/tmp/opening-v2/full-seams")
 for width in [400,572]:
  var height:int=int(width*960.0/572.0)
  root.size=Vector2i((width+20)*3+20,height+160);root.content_scale_size=root.size
  for i in 3:
   clips[i].position=Vector2(20+i*(width+20),110);clips[i].size=Vector2(width,width*960.0/572.0);backs[i].scale=Vector2.ONE*(float(width)/572.0)
  for boundary in range(1,10):
   for i in 2:
    var texture:Texture2D=textures[boundary-1+i]
    materials[i].set_shader_parameter("opening_texture",texture);materials[i].set_shader_parameter("opening_sample",sample(texture));materials[i].set_shader_parameter("opening_progress",1.0 if i==0 else 0.0)
   await process_frame
   await RenderingServer.frame_post_draw
   var shot=root.get_texture().get_image()
   for i in 2:shot.get_region(Rect2i(20+i*(width+20),110,width,height)).save_png("/tmp/opening-v2/full-seams/%02d-%d-%d.png"%[boundary,width,i])
 print("FULL_ART_RENDER_OK / 321 continuous frames / 9 boundaries at 2 scales / NO_GAMEPLAY")
 quit()
