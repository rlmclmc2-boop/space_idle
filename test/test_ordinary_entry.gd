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
var checks=0
var failures=0
var reports:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func points(scene)->Dictionary:
 var out:Dictionary={}
 for enemy in scene.game.enemies:out[str(enemy.uid)]=scene.enemy_render_position(enemy)
 return out
func run()->void:
 for native in [false,true]:
  var scene=load("res://main.tscn").instantiate();scene.set_script(UI);scene.automation_args=["--capture"];scene.music_on=false
  root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
  var g=scene.game;g.save_enabled=false;g.profile.onboarding.completed=true;scene.beginner_guide.hide();g.pending_unlocks.clear();g.profile.loadout.weapons=[];g.invalidate_stat_cache()
  check(g.start(1,false),"real first-stage travel starts")
  g.native_execution_auto=native
  g.distance=float(g.db.levels[0].groups[0].position)*float(g.db.levels[0].length)-0.1
  scene._process(1.0/60.0)
  check(g.state==g.State.COMBAT and not g.enemies.is_empty(),"real first encounter spawns")
  var start=points(scene)
  scene.battle_layer.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.runtime/entry-"+str(native)+"-start.png")
  for i in 80:scene._process(1.0/60.0)
  var end=points(scene)
  for id in start:
   check(end.has(id) and float(end[id].y)-float(start[id].y)>45.0,"each real first-wave ship completes visible entry")
  for i in 30:scene._process(1.0/60.0)
  check(points(scene)==end,"resident ships remain fixed after entry")
  scene.battle_layer.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.runtime/entry-"+str(native)+"-end.png")
  reports.append({"native":native,"start":start,"end":end,"resident":points(scene),"count":g.enemies.size()})
  if scene.battle_slice_runtime!=null:scene.battle_slice_runtime.close();scene.battle_slice_runtime=null
  if g.native_execution!=null:g.native_execution.cancel(g);g.native_execution=null
  scene.queue_free();await process_frame
 var out=FileAccess.open("res://.runtime/ordinary-entry.json",FileAccess.WRITE);out.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":reports},"\t"));out.close()
 print("ORDINARY_ENTRY ",checks," checks ",failures," failures");quit(1 if failures else 0)
