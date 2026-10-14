extends SceneTree
const Renderer=preload("res://scripts/retained_missile_events.gd")
const FX=preload("res://dev/toon_ship/missile_vfx.gd")
class Old extends Node2D:
 var rays:Array=[]
 func _draw()->void:
  for r in rays:
   if r[5]:FX.flash(self,r[0],r[1],r[2],r[3])
   else:FX.impact(self,r[0],r[1],r[2],r[4],r[3],0)
func _initialize()->void:call_deferred("run")
func viewport()->SubViewport:
 var v=SubViewport.new();v.size=Vector2i(256,256);v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v);return v
func run()->void:
 var rows:Array=[];var failures:=0
 for mode in 8:
  var old=viewport();var fresh=viewport();var painter=Old.new();old.add_child(painter)
  var batch=Renderer.Batch.new();fresh.add_child(batch);batch.begin(9)
  for i in 9:
   var point=Vector2(44+(i%3)*80,44+(i/3)*80)
   var age:float=[0.0,0.025,0.064,0.10,0.129,0.18,0.219,0.22][mode]
   var direction=Vector2.from_angle(float(i)*0.713)
   var row=[point,direction,age,0.45 if i%2==0 else 1.0,i%3==0,i%3==2]
   painter.rays.append(row);batch.append_event(row[0],row[1],row[2],row[3],row[4],row[5])
  batch.finish()
  await process_frame;await RenderingServer.frame_post_draw;await process_frame;await RenderingServer.frame_post_draw;await process_frame;await RenderingServer.frame_post_draw
  var a=old.get_texture().get_image();var b=fresh.get_texture().get_image();var total:=0.0;var changed:=0;var colored:=0;var roi_error:=0.0
  for y in 256:
   for x in 256:
    var ac=a.get_pixel(x,y);var bc=b.get_pixel(x,y)
    var error=maxf(maxf(absf(ac.r-bc.r),absf(ac.g-bc.g)),maxf(absf(ac.b-bc.b),absf(ac.a-bc.a)))
    total+=error
    if error>2.0/255:changed+=1
    if ac.a>0.01 or bc.a>0.01:colored+=1;roi_error+=error
  var mean:=total/(256*256);var pass_case:=mean<0.001 and changed<256*256*0.005
  if not pass_case:failures+=1
  rows.append({"case":mode,"mean_max_channel_error":mean,"pixels_over_2_255":changed,"colored_union":colored,"colored_mean_error":roi_error/maxi(colored,1),"pass":pass_case})
  a.save_png("res://.runtime/missile-ref-%d.png"%mode);b.save_png("res://.runtime/missile-new-%d.png"%mode)
  old.queue_free();fresh.queue_free();await process_frame
 FileAccess.open("res://.runtime/missile-render-check.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"failures":failures}))
 print("MISSILE_RENDER_CHECK ",JSON.stringify(rows));quit(failures)
