extends SceneTree
const VFX=preload("res://dev/toon_ship/missile_vfx.gd")
const BODY=preload("res://dev/toon_ship/missile_body_mesh.gd")
func _initialize():call_deferred("run")
func run():
 var mesh=BODY.new().build();var views=[]
 for cached in [false,true]:
  var view=SubViewport.new();view.size=Vector2i(512,512);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(view);views.append(view)
  var surface=Node2D.new();view.add_child(surface)
  surface.draw.connect(func():
   var index=0
   for angle in [-PI/2,-1.17,-0.2,0.7,PI/2,2.18,PI,4.9]:
    for age in [0.0,0.1,0.22,0.4,0.65,1.2]:
     var position=Vector2(28.25+(index%8)*64,36.625+(index/8)*76)
     VFX.flight(surface,position,Vector2.from_angle(angle),age,index,1.0,true,index%2==0,mesh if cached else null)
     index+=1
   # Preserve primitive/alpha order when complete bodies overlap.
   for i in 9:VFX.flight(surface,Vector2(150.5+i*0.3,487.125),Vector2.from_angle(-1.1+i*0.01),0.8,i,1.0,true,true,mesh if cached else null))
 await process_frame;await RenderingServer.frame_post_draw
 var original=views[0].get_texture().get_image();var candidate=views[1].get_texture().get_image()
 var a=original.get_data();var b=candidate.get_data();var changed=0;var maximum=0;var error=0.0
 for i in a.size():
  var diff=absi(int(a[i])-int(b[i]));maximum=maxi(maximum,diff);error+=diff*diff
  if diff>0:changed+=1
 original.save_png("res://.runtime/missile-body-original.png");candidate.save_png("res://.runtime/missile-body-mesh.png")
 print("MISSILE_BODY_MESH channels=",a.size()," changed=",changed," max_channel_error=",maximum," rmse=",sqrt(error/a.size())," triangles=",mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3)
 for view in views:view.queue_free()
 await process_frame;quit(0 if maximum<=1 else 1)
