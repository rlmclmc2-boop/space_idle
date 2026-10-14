extends SceneTree
# Direct lifecycle and rendered-state regression; no second combat simulation.
class Session extends RefCounted:
 var kernel
 var handed_off:=false
class GameView extends RefCounted:
 var native_execution
 var projectiles:Array=[]
class Painter extends Node2D:
 var game
 var native
 var projectile_visuals:Array=[]
 var particles:Array=[]
 var missile_density:=0
 var prototype_enabled:=true
 var missile_vfx_enabled:=true
 var pulse_vfx_enabled:=true
 var enemy_vfx_enabled:=true
 var accelerated_visual_mode:=false
 var draw_surface
 var frame
 func _draw():
  draw_surface=self
  frame=native.prepare_flights(self,[] if accelerated_visual_mode else game.projectiles,Vector2.ZERO)
  # A translucent intervening hull distinguishes background and foreground.
  draw_rect(Rect2(170,175,220,50),Color(0.3,0.2,0.4,0.4))
  native.draw_flights(self,frame,Vector2.ZERO)
  draw_line(Vector2(0,225),Vector2(640,225),Color(0.9,0.2,0.3,0.6),2)
 func flush_projectile_packet_batch():pass
 func _advance_projectile_visual_record(_visual,_dt):pass
func _initialize():call_deferred("run")
func weapon(kind:int,slot:int,hostile:=false)->Dictionary:
 return {"kind":kind,"type":2 if kind==2 or hostile else 1,"slot":slot,"source":0,"hostile":hostile,"damage":10.0,"interval":0.4,"remaining":0.0,"speed":720.0,"charge":0.0,"ramp":1.0,"maximum":1.0,"salvo":1,"muzzle":Vector2(25+(slot%28)*20,350+(slot/28)*2),"chain_count":2 if slot==0 else 0,"entry":{"key":["laser","cannon","missile","longLaser"][kind]},"row":{"cd":0.4,"para1":1.0,"para2":1.0,"para3":0.0}}
func descriptor()->Dictionary:
 var enemies:Array=[]
 for i in 3:enemies.append({"uid":100+i,"slot":i,"x":200+i*70,"y":80,"hp":1e12,"max_hp":1e12,"armourType":2,"shieldType":1,"shield":0.0,"max_shield":0.0})
 var weapons:Array=[weapon(0,0,true),weapon(1,1,true)]
 for i in 280:weapons.append(weapon(0,i))
 weapons.append(weapon(2,280))
 return {"clock":127.8,"rng_state":418,"resistance":0.5,"player":{"x":300.0,"y":350.0,"armour":1e12,"shield":1e12,"armour_type":2,"shield_type":1},"enemies":enemies,"weapons":weapons}
func install_geometry(kernel,d):
 var hulls:Array=[];var points:=PackedVector2Array();var muzzles:=PackedVector2Array()
 for e in d.enemies:
  var center=Vector2(e.x,e.y);points.append(center);hulls.append(PackedVector2Array([center+Vector2(-20,-20),center+Vector2(20,-20),center+Vector2(20,20),center+Vector2(-20,20)]))
 for w in d.weapons:muzzles.append(w.muzzle)
 kernel.input_ballistic_geometry(hulls,points,muzzles)
func run():
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 var kernel=ClassDB.instantiate("SpaceCombatKernel");var d=descriptor();assert(kernel.configure(d));install_geometry(kernel,d)
 var session=Session.new();session.kernel=kernel
 var game=GameView.new();game.native_execution=session;game.projectiles=kernel.projectile_views()
 var views:Array=[];var painters:Array=[]
 for gpu in [false,true]:
  var viewport=SubViewport.new();viewport.size=Vector2i(640,480);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);views.append(viewport)
  var painter=Painter.new();painter.game=game;painter.native=ClassDB.instantiate("SpaceCombatPresentation");painter.draw_surface=painter;viewport.add_child(painter);painters.append(painter)
  if gpu:
   var material=ShaderMaterial.new();material.shader=load("res://shaders/retained_flights.gdshader");painter.native.configure_retained_gpu(material)
 var retired_lease
 var retired_shot:Dictionary={}
 var saw_over_cap:=false;var saw_chain:=false;var max_error:=0.0
 var summary:Array=[]
 for step in 65:
  if step==5:
   for shot in game.projectiles:
    if not shot.hostile and shot.key=="laser":shot.motion_lease.set_speed(360.0);break
  assert(kernel.advance(1.0/60.0))
  for e in kernel.take_feedback():
   if int(e.kind)!=0:continue
   var shot:Dictionary=e.shot
   for painter in painters:
    if painter.projectile_visuals.size()>=256:continue
    var visual:Dictionary=painter.native.create_visual(shot,Vector2(e.direction).angle(),0,e.position,e.position,0)
    if shot.has("fixed_screen_step"):
     visual.fixed_origin=shot.fixed_screen_origin;visual.fixed_step=shot.fixed_screen_step;visual.fixed_direction=e.direction;visual.angle=Vector2(shot.fixed_screen_step).angle()
    elif shot.hostile:
     visual.fixed_origin=Vector2(shot.launch_point)+Vector2(0,50);visual.fixed_step=Vector2(0.8,1.1);visual.fixed_direction=e.direction;visual.angle=Vector2(visual.fixed_step).angle()
    painter.projectile_visuals.append(visual);painter.native.register_visual(shot,visual,0);painter.native.bind_visual(visual)
  for shot in game.projectiles:
   saw_chain=saw_chain or bool(shot.chain_hop)
   if retired_lease==null:retired_shot=shot;retired_lease=shot.motion_lease
  for painter in painters:painter.native.advance_visuals(painter,1.0/60.0);painter.queue_redraw()
  await process_frame;await RenderingServer.frame_post_draw
  var rows:Array=painters[1].frame.to_array();assert(rows.size()==game.projectiles.size())
  saw_over_cap=saw_over_cap or rows.size()>256
  for i in rows.size():
   assert(is_same(rows[i].shot,game.projectiles[i]),"kernel swap-retirement order must be retained")
   var shot:Dictionary=rows[i].shot
   if shot.hostile:
    for visual in painters[1].projectile_visuals:
     if is_same(visual.shot,shot) and visual.has("fixed_step"):
      var expected:Vector2=Vector2(visual.fixed_origin)+Vector2(visual.fixed_step)*((shot.motion_lease.position()-Vector2(visual.logical_origin)).dot(visual.fixed_direction))
      assert(Vector2(rows[i].pos).distance_to(expected)<0.01,"enemy fixed visual mapping retained")
   if shot.has("fixed_screen_step") and not shot.chain_hop:
    var logical:Vector2=shot.motion_lease.position();var direction:Vector2=shot.motion_lease.direction()
    var expected:Vector2=Vector2(shot.fixed_screen_origin)+Vector2(shot.fixed_screen_step)*((logical-Vector2(shot.launch_point)).dot(direction))
    max_error=maxf(max_error,Vector2(rows[i].pos).distance_to(expected));assert(max_error<0.05,"GPU analytic pulse must follow the authoritative fixed ray")
  if step in [3,25,60]:
   for i in 2:views[i].get_texture().get_image().save_png("res://.runtime/retained-unit-%s-%s.png"%[step,i])
  if step==25:
   var before=views[1].get_texture().get_image().get_data()
   for painter in painters:painter.native.advance_visuals(painter,0.0);painter.queue_redraw()
   await process_frame;await RenderingServer.frame_post_draw
   assert(before==views[1].get_texture().get_image().get_data(),"paused simulation must freeze analytic pulses")
  summary.append({"step":step,"live":rows.size()})
 assert(saw_over_cap and saw_chain and retired_shot.dead)
 assert(retired_lease!=null,"held retired motion storage must not imply liveness")
 var metric:Dictionary=painters[1].native.retained_metrics();assert(metric.old_advance==0 and metric.old_prepare==0 and metric.old_draw==0)
 # Handoff preserves every surviving body through the legacy route.
 session.handed_off=true
 for painter in painters:painter.native.advance_visuals(painter,0.0);painter.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 assert(painters[1].frame.size()==game.projectiles.size())
 assert(painters[1].native.retained_metrics().old_prepare>0)
 # Cancel plus same-kernel reconfigure must not reuse an old descriptor/lease.
 kernel.cancel();session.handed_off=false
 for painter in painters:painter.native.advance_visuals(painter,0.0);painter.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 assert(painters[1].frame.size()==0)
 assert(kernel.configure(d));install_geometry(kernel,d);game.projectiles=kernel.projectile_views();assert(kernel.advance(1.0/60.0));kernel.take_feedback()
 for painter in painters:painter.native.advance_visuals(painter,1.0/60.0);painter.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 assert(painters[1].frame.size()==game.projectiles.size() and painters[1].frame.size()>256)
 for row in painters[1].frame.to_array():assert(not is_same(row.shot,retired_shot))
 # Different live kernel, restarted serials: stale visuals must not cross owners.
 var previous_kernel=kernel
 for i in 2:
  var old:Dictionary=game.projectiles[i]
  var stale:Dictionary=painters[1].native.create_visual(old,0,0,Vector2.ZERO,Vector2.ZERO,0)
  painters[1].projectile_visuals.append(stale);painters[1].native.register_visual(old,stale,0)
 kernel=ClassDB.instantiate("SpaceCombatKernel");assert(kernel.configure(d));install_geometry(kernel,d)
 session.kernel=kernel;game.projectiles=kernel.projectile_views();assert(kernel.advance(1.0/60.0));kernel.take_feedback()
 var fresh:Dictionary=painters[1].native.create_visual(game.projectiles[0],0,0,Vector2.ZERO,Vector2.ZERO,0)
 painters[1].projectile_visuals.append(fresh);painters[1].native.register_visual(game.projectiles[0],fresh,0)
 for painter in painters:painter.native.advance_visuals(painter,0.0);painter.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 var switched:Array=painters[1].frame.to_array()
 assert(is_same(switched[0].visual,fresh),"keep newly registered same-serial record")
 assert(switched[1].visual.is_empty(),"unregistered replacement must not inherit old visual")
 for row in switched:assert(row.visual.is_empty() or is_same(row.visual.shot,row.shot))
 previous_kernel.cancel()
 # Real fast-display entry skips advance_projectile_visuals entirely. Prepare
 # must drop the retained frame even in that route; direct advance also falls back.
 var calls:Dictionary=painters[1].native.retained_metrics()
 painters[1].accelerated_visual_mode=true;painters[1].queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 assert(painters[1].frame.size()==0 and painters[1].native.retained_metrics().live==0)
 painters[1].native.advance_visuals(painters[1],0.0)
 assert(painters[1].native.retained_metrics().old_advance==calls.old_advance+1)
 painters[1].accelerated_visual_mode=false;painters[1].native.advance_visuals(painters[1],0.0);painters[1].queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 assert(painters[1].frame.size()==game.projectiles.size())
 painters[1].native.configure_retained_gpu(null)
 FileAccess.open("res://.runtime/retained-unit.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"max_fixed_ray_error_pixels":max_error,"pre_handoff_metrics":metric,"samples":summary,"over_cap":saw_over_cap,"chain":saw_chain,"pause_exact":true,"handoff":true,"reset":true,"kernel_identity":true,"accelerated_display_roundtrip":true}))
 print("RETAINED_FLIGHTS_UNIT_OK error=",max_error)
 kernel.cancel();quit()
