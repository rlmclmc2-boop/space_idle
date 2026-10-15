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
 func _draw()->void:
  draw_string(ThemeDB.fallback_font,Vector2(20,32),"STAGES 3–4 DRAFT / SOURCE JOIN FAILED / NOT IN RUNTIME",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("f0bd8b"))
  draw_string(ThemeDB.fallback_font,Vector2(20,61),"Same production shader + 30/50/80px specimens. Review only; source seam remains visible.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
  for i in 3:
   draw_string(ThemeDB.fallback_font,Vector2(20+i*420,96),["02 END / LOCKED EXISTING ART","03 END / JOIN CROSSES VIEW","04 END / TRUSS AND ROCKS"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
  draw_string(ThemeDB.fallback_font,Vector2(20,812),"The original stage 1/2 textures are unchanged. Pixel overlap alone does not certify painted continuity.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
func _initialize()->void:call_deferred("run")
func run()->void:
 var dir=OS.get_environment("OPENING_REVIEW_DIR")
 var project=OS.get_environment("OPENING_PROJECT_DIR")
 root.size=Vector2i(1280,850);root.content_scale_size=root.size
 root.add_child(Labels.new())
 var textures=[]
 for stage in [3,4]:textures.append(ImageTexture.create_from_image(Image.load_from_file(dir+"/review/stage-%d-candidate.png"%stage)))
 var ships=ImageTexture.create_from_image(Image.load_from_file(project+"/docs/art/opening-three/revision-03/enemies-topdown-source.png"))
 var materials=[]
 for i in 3:
  var clip=Control.new();clip.position=Vector2(20+i*420,110);clip.size=Vector2(400,672);clip.clip_contents=true;root.add_child(clip)
  var back=Backdrop.new();back.scale=Vector2.ONE*(400.0/572.0)
  var mat=ShaderMaterial.new();mat.shader=load("res://scripts/starfield.gdshader")
  mat.set_shader_parameter("opening_enabled",true);mat.set_shader_parameter("opening_progress",0.0 if i==0 else 1.0)
  mat.set_shader_parameter("opening_texture",textures[0 if i<2 else 1]);mat.set_shader_parameter("opening_sample",Vector3(2.0/1444.0,960.0/1444.0,480.0/1444.0))
  back.material=mat;clip.add_child(back);materials.append(mat)
  var specimens=Specimens.new();specimens.ships=ships;specimens.scale=back.scale;clip.add_child(specimens)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(dir+"/review/stage-viewports.png")
 DirAccess.make_dir_recursive_absolute("/tmp/opening-v2/draft-frames")
 for frame in 81:
  var p:float=float(frame)/40.0
  var next:int=0 if p<=1.0 else 1
  materials[0].set_shader_parameter("opening_texture",textures[next]);materials[0].set_shader_parameter("opening_progress",p-float(next))
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().get_region(Rect2i(20,110,400,672)).save_png("/tmp/opening-v2/draft-frames/%03d.png"%frame)
 print("DRAFT_RENDER_OK / SOURCE_JOIN_FAILED / NO_RUNTIME_EXPORT")
 quit()
