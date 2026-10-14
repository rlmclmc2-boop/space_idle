extends SceneTree
class Painter extends Node2D:
 var native
 var clock:=0.0
 func _draw():
  draw_line(Vector2(20,110),Vector2(620,110),Color(0.2,0.1,0.6,0.3),2.0,true)
  native.draw_contacts(get_canvas_item(),clock,true)
  draw_rect(Rect2(50,278,560,2),Color(0.8,0.2,0.5,0.4))
func _initialize():call_deferred("run")
func run():
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=60
 var topology=load("res://scripts/gpu_contact_mesh.gd")
 var views:Array=[];var painters:Array=[]
 for gpu in [false,true]:
  var viewport:=SubViewport.new();viewport.size=Vector2i(640,400);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(viewport);views.append(viewport)
  var painter:=Painter.new();painter.native=ClassDB.instantiate("SpaceCombatPresentation");viewport.add_child(painter);painters.append(painter)
  if gpu:
   var material:=ShaderMaterial.new();material.shader=topology.SHADER;painter.material=material
   painter.native.configure_contact_gpu([topology.build(0),topology.build(1)],painter.get_canvas_item(),material)
  for category in 2:
   for launch in [false,true]:
    for physical in [false,true]:
     for critical in [false,true]:
      var index=category*8+int(launch)*4+int(physical)*2+int(critical)
      var point=Vector2(60+(index%8)*75,110+(index/8)*150)
      # Position given in logical coordinates, compare identical native mapping.
      var angle=0.43+float(index)*0.37
      painter.native.record_contact(category,point,Vector2.from_angle(angle),0.0,launch,critical,2 if physical else 0)
 var summary:Array=[]
 for age in [0.0,0.02,0.05849,0.05851,0.0749,0.075,0.10,0.1199,0.12,0.139,0.14]:
  for painter in painters:painter.clock=age;painter.native.prune_contacts(age,false);painter.queue_redraw()
  await process_frame;await RenderingServer.frame_post_draw
  var images:Array=[]
  for i in 2:
   var image=views[i].get_texture().get_image();image.save_png("res://.runtime/contact-%s-%s.png"%[str(age),str(i)]);images.append(image)
  summary.append({"age":age,"metrics":painters[1].native.contact_gpu_metrics()})
 # Clearing removes retained commands' instances immediately, without a repaint.
 painters[1].native.clear_contacts()
 await process_frame;await RenderingServer.frame_post_draw
 views[1].get_texture().get_image().save_png("res://.runtime/contact-cleared.png")
 FileAccess.open("res://.runtime/contact-unit.json",FileAccess.WRITE).store_string(JSON.stringify(summary))
 # Clock rebase and identical-clock repaint (pause) retain event appearance.
 for painter in painters:
  painter.native.clear_contacts();painter.native.record_contact(1,Vector2(320,110),Vector2.from_angle(0.7),1000000.0,false,true,0);painter.clock=1000000.02;painter.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 for i in 2:views[i].get_texture().get_image().save_png("res://.runtime/contact-rebase-%s.png"%str(i))
 var uploads:int=painters[1].native.contact_gpu_metrics().uploads
 for painter in painters:painter.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 assert(int(painters[1].native.contact_gpu_metrics().uploads)==uploads)
 views[1].get_texture().get_image().save_png("res://.runtime/contact-paused.png")
 print("GPU_CONTACT_UNIT_OK");quit()
