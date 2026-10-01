extends SceneTree
# Real CanvasItem boundary regression; run logs must also contain no rendering errors.
class FlashCanvas extends Node2D:
 var fx:Script
 func _draw()->void:
  # Ordinary flashes remain visible, with their original concave silhouette.
  for i in 6:
   for j in 3:
    fx.flash(self,Vector2(40+i*70,40+j*65),Vector2.RIGHT.rotated(i*PI/3.0),[0.0,0.03,0.07][j])
  # Event lifetime extends beyond the visual lifetime. These must be transparent.
  for age in [0.075,0.10,0.139]:fx.flash(self,Vector2(80,260),Vector2.RIGHT,age)
  fx.flash(self,Vector2(180,260),Vector2.ZERO,0.0)
  for age in [NAN,INF,-INF]:fx.flash(self,Vector2(180,260),Vector2.RIGHT,age)
  fx.flash(self,Vector2(INF,260),Vector2.RIGHT,0.0)
  fx.flash(self,Vector2(180,260),Vector2(NAN,0),0.0)
  # Just-before-expiry rounding, at representative and large screen coordinates.
  for point in [Vector2(320,260),Vector2(2048,1280),Vector2(65536,65536)]:
   for angle in [0.0,0.1,PI/4.0,PI/2.0,PI]:
    for age in [0.074,0.07499,0.074999999,0.075]:
     fx.flash(self,point,Vector2.RIGHT.rotated(angle),age)
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(480,320)
 root.content_scale_size=Vector2i(480,320)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var canvas=FlashCanvas.new()
 canvas.fx=load("res://pulse_reference.gd" if OS.get_environment("PULSE_REFERENCE")=="1" else "res://dev/toon_ship/pulse_vfx.gd")
 root.add_child(canvas)
 await process_frame
 await RenderingServer.frame_post_draw
 var picture=root.get_texture().get_image()
 DirAccess.make_dir_recursive_absolute("res://.runtime")
 picture.save_png("res://.runtime/pulse-flash.png")
 var background=picture.get_pixel(5,5)
 var visible=0
 for x in range(20,440):
  for y in range(20,185):
   if picture.get_pixel(x,y)!=background:visible+=1
 if visible<100:
  printerr("FAIL: ordinary flashes disappeared");quit(1);return
 for x in range(60,200):
  for y in range(240,280):
   if picture.get_pixel(x,y)!=background:
    printerr("FAIL: expired or zero-direction flash draws");quit(1);return
 print("PASS pulse flash ordinary silhouette visible; expiry and zero direction transparent; endpoint cases submitted")
 canvas.queue_free();await process_frame
 quit()
