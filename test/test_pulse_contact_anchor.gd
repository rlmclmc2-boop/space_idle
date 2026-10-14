extends SceneTree
class UI extends "res://scripts/battlefield.gd":
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func create_battle_game(_persist:bool)->BattleGame:
  var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
  g.stat_cache_enabled=true;g.invalidate_stat_cache()
  db=g.db;g.native_execution_auto=false
  g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
  g.target_provider=_prototype_target_point;g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
  g.enable_compiled_combat_rules()
  return g
class CaptureRuntime extends "res://scripts/battle_slice_runtime.gd":
 var impacts:Dictionary={}
 func consume(e:Effect)->void:
  if e.kind==4 and e.style==1:impacts[e.serial]={"point":geometry.battle_point(e.position),"direction":e.direction}
  super.consume(e)
var checks:=0
var failures:=0
var rows:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
 var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1975
 g.profile.onboarding.completed=true;scene.beginner_guide.hide();g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.pending_unlocks.clear()
 g.profile.selectedShip="Heavy_Battleship"
 g.profile.loadout={"weapons":[{"key":"laser","level":1},{"key":"laser","level":1}],"defence":[{"key":"armour","level":1},{"key":"shield","level":1}]}
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
 var template:Dictionary=g.enemies[0].duplicate(true);g.enemies.clear()
 for i in 2:
  var enemy=template.duplicate(true);enemy.uid=500+i;enemy.slot=i;enemy.x=160+170*i;enemy.y=340
  enemy.hp=1e9;enemy.max_hp=1e9;enemy.size=4;enemy.explicit_formation=true;enemy.formation_count=4;enemy.equipment=[];enemy.cooldowns=[]
  g.enemies.append(enemy)
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
 check(g.admit_native_compiled_execution("native_low_contract"),"actual native pulse admission")
 var rt=CaptureRuntime.new();scene.battle_slice_runtime=rt;rt.install(scene);g.native_execution_auto=true
 var hit_rows:Array=[]
 var watch=func(kind:String,info:Dictionary):
  if kind!="projectile_impact" or bool(info.shot.hostile) or info.shot.get("chain_hop",false):return
  var shot:Dictionary=info.shot
  if not shot.has("fixed_screen_step"):return
  var direction:Vector2=g.projectile_direction(shot)
  var distance:float=(Vector2(info.pos)-Vector2(shot.launch_point)).dot(direction)
  var expected:Vector2=Vector2(shot.fixed_screen_origin)+Vector2(shot.fixed_screen_step)*distance
  var got:Vector2=rt.impacts[int(shot.serial)].point
  var hull:PackedVector2Array=rt.geometry.battle_read_model.ballistic_shape(shot.target).hull
  var edge_error=INF
  for i in hull.size():edge_error=minf(edge_error,expected.distance_to(Geometry2D.get_closest_point_to_segment(expected,hull[i],hull[(i+1)%hull.size()])))
  check(edge_error<0.1,"actual collision lies on visible protection contour")
  check(got.distance_to(expected)<0.05,"emitted contact anchor equals actual collision")
  check(Vector2(rt.impacts[int(shot.serial)].direction).distance_to(Vector2(shot.fixed_screen_step).normalized())<0.0001,"contact orientation follows fixed screen ray")
  hit_rows.append({"serial":int(shot.serial),"edge_error":edge_error,"anchor_error":got.distance_to(expected),"expected":str(expected),"actual":str(got)})
 g.event.connect(watch)
 for step in 300:
  scene._process(1.0/60.0)
  if hit_rows.size()>=4:break
 check(hit_rows.size()>=4,"actual pulse impacts observed")
 scene.battle_layer.queue_redraw();scene.pulse_layer.queue_redraw();scene.battle_hud_layer.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://.runtime")
 root.get_texture().get_image().save_png("res://.runtime/pulse-contact.png")
 # Recreate a delayed display record after the native body has advanced; damage is not replayed.
 var shot:Dictionary={}
 for step in 120:
  scene._process(1.0/60.0)
  for item in g.projectiles:
   if item.has("fixed_screen_step") and not bool(item.hostile) and g.projectile_position(item).distance_to(Vector2(item.launch_point))>1.0:shot=item;break
  if not shot.is_empty():break
 check(not shot.is_empty(),"live fixed-ray pulse available for delayed feedback regression")
 if not shot.is_empty():
  var e=rt.Effect.new();e.position=shot.launch_point;e.direction=g.projectile_direction(shot)
  rt.spawn_visual(shot,e)
  var visual:Dictionary=scene.projectile_visuals.back()
  check(Vector2(visual.logical_origin)==Vector2(shot.launch_point),"delayed visual retains birth logical origin")
  var logical:Vector2=Vector2(shot.launch_point)+g.projectile_direction(shot)*100.0
  var expected:Vector2=Vector2(shot.fixed_screen_origin)+Vector2(shot.fixed_screen_step)*100.0
  check(scene.battle_point(scene.straight_projectile_point(logical,visual)).distance_to(expected)<0.05,"fallback visual projects the same fixed ray")
  # Remove only this display lookup to cover exhausted presentation-record capacity.
  var old:Array[Dictionary]=scene.projectile_visuals.duplicate();scene.projectile_visuals.clear()
  var presentation=g.combat_presentation;g.combat_presentation=null
  rt.on_event("projectile_impact",{"shot":shot,"pos":logical})
  check(Vector2(rt.impacts[int(shot.serial)].point).distance_to(expected)<0.05,"impact anchor independent of optional visual record")
  scene.projectile_visuals.assign(old);g.combat_presentation=presentation
  scene._pulse_events.clear()
 var file=FileAccess.open("res://.runtime/pulse-contact.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"impacts":hit_rows},"\t"));file.close()
 g.event.disconnect(watch);rt.close();scene.battle_slice_runtime=null;scene.queue_free();await process_frame
 print("PULSE_CONTACT_ANCHOR ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
