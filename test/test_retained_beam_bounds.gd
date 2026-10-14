extends SceneTree
const Beams=preload("res://scripts/retained_beam_foreground.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func draw_frame()->void:
 await process_frame
 await RenderingServer.frame_post_draw
func run()->void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(128,128)
 viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var quad=Beams.Quad.new();viewport.add_child(quad)
 var start:=Vector2(-5000,64);var end:=Vector2(5000,64)
 quad.publish(start,end,Vector4(3.4,1,1,-1),1.0,-1,false)
 await draw_frame()
 check(quad.cull_bounds.encloses(Rect2(-28.36,-28.36,10056.72,56.72)),"long beam bounds include shader quad")
 check(viewport.get_texture().get_image().get_pixel(64,64).a>0.1,"offscreen source long beam remains visible through viewport")
 var builds:int=quad.builds
 quad.publish(start,end,Vector4(100,1,1,-1),1.1,-1,false)
 await draw_frame()
 check(quad.cull_bounds.encloses(Rect2(-550,-550,11100,1100)),"large width expands both axes")
 check(quad.builds==builds,"culling growth does not rebuild retained draw commands")
 var state:Vector4=quad.values[1];var clock:float=quad.values[2].x
 var bad:Array=[Vector2(INF,0),Vector2(NAN,0)]
 for point in bad:
  quad.publish(point,end,state,clock,-1,false)
  check(not quad.visible and quad.position.is_finite(),"invalid start hidden without publishing invalid transform")
  quad.publish(start,point,state,clock,-1,false)
  check(not quad.visible,"invalid target hidden")
 quad.publish(start,end,Vector4(NAN,1,1,-1),clock,-1,false)
 check(not quad.visible,"invalid style hidden")
 quad.publish(start,end,state,INF,-1,false)
 check(not quad.visible,"invalid animation clock hidden")
 quad.publish(start,end,state,clock,NAN,false)
 check(not quad.visible,"invalid cue hidden")
 quad.publish(Vector2(-3e30,0),Vector2(3e30,0),state,clock,-1,false)
 check(not quad.visible,"overflowed finite-coordinate distance hidden")
 await draw_frame()
 check(viewport.get_texture().get_image().get_pixel(64,64).a==0.0,"invalid publication cannot leave stale beam visible")
 quad.publish(start,end,state,clock,-1,false)
 await draw_frame()
 check(quad.visible and viewport.get_texture().get_image().get_pixel(64,64).a>0.1,"valid identical publication restores beam")
 viewport.queue_free();await process_frame
 print("BEAM_BOUNDS_RESULT ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
