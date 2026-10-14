extends SceneTree
const Renderer=preload("res://scripts/retained_beam_foreground.gd")
const Reference=preload("res://qa_beam_reference.gdshader")
class OldQuad extends Node2D:
 func _draw()->void:draw_rect(Rect2(-128,-128,2304,256),Color.WHITE)
 func publish(a:Vector2,b:Vector2,state:Vector4,clock:float,cue:float,link:bool)->void:
  position=a;rotation=(b-a).angle() if a.distance_squared_to(b)>=0.25 else -PI/2
  material=ShaderMaterial.new();material.shader=Reference
  material.set_shader_parameter("beam_length",a.distance_to(b));material.set_shader_parameter("state",state)
  material.set_shader_parameter("timing",Vector4(clock,cue,rotation,1.0 if link else 0.0))
func _initialize()->void:call_deferred("run")
func viewport()->SubViewport:
 var v=SubViewport.new();v.size=Vector2i(512,512);v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v);return v
func run()->void:
 var rows:Array=[];var failures=0
 for mode in 5:
  var old=viewport();var fresh=viewport();var batch=Renderer.BeamBatch.new();fresh.add_child(batch)
  var rays:Array=[]
  for i in 4:
   var a=Vector2(40+i*75,430);var b=Vector2(460-i*100,60)
   var state=Vector4(3.7,0.7,0.6,-1)
   if mode==1:state.w=0.55
   if mode==2:state=Vector4(5,1,1,-1)
   if mode==3:state=Vector4(1,0,0,-1)
   if mode==4:b=a+Vector2(0,-700)
   rays.append([a,b,state,0.06 if mode==2 else -1.0,mode==3])
  batch.begin(rays.size(),2.731)
  for ray in rays:
   var q=OldQuad.new();old.add_child(q);q.publish(ray[0],ray[1],ray[2],2.731,ray[3],ray[4]);batch.append_ray(ray[0],ray[1],ray[2],ray[3],ray[4])
  batch.finish()
  await process_frame;await RenderingServer.frame_post_draw;await process_frame;await RenderingServer.frame_post_draw
  var a=old.get_texture().get_image();var b=fresh.get_texture().get_image();var total=0.0;var maximum=0.0;var changed=0;var colored=0
  for y in 512:
   for x in 512:
    var ac=a.get_pixel(x,y);var bc=b.get_pixel(x,y)
    var error=maxf(maxf(absf(ac.r-bc.r),absf(ac.g-bc.g)),maxf(absf(ac.b-bc.b),absf(ac.a-bc.a)))
    total+=error;maximum=maxf(maximum,error)
    if error>2.0/255:changed+=1
    if ac.a>0.01:colored+=1
  var mean=total/(512*512);var pass_case=mean<0.001 and changed<512*512*0.005 and colored>100
  if not pass_case:failures+=1
  rows.append({"case":mode,"mean_max_channel_error":mean,"maximum":maximum,"pixels_over_2_255":changed,"reference_colored_pixels":colored,"pass":pass_case})
  a.save_png("res://.runtime/beam-ref-%d.png"%mode);b.save_png("res://.runtime/beam-new-%d.png"%mode)
  old.queue_free();fresh.queue_free();await process_frame
 FileAccess.open("res://.runtime/beam-render-check.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"failures":failures}))
 print("BEAM_RENDER_CHECK ",JSON.stringify(rows));quit(failures)
