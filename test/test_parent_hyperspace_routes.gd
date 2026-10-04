extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
var failures:=0
func check(ok:bool,label:String)->void:
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var results:Array=[]
 for route in ["alpha","beta","gamma","delta"]:
  var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);root.add_child(scene);current_scene=scene;scene.set_process(false)
  var g=scene.game;g.save_enabled=false;g.paused=true;scene.music.stop();scene.music.stream=null
  g.profile.cleared=range(1,7);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
  var base=g.db;var group_count=base.groups.size();var enemy_count=base.enemies.size()
  check(g.load_hyperspace_routes(),"actual accepted loader "+route)
  var energy:float=g.profile.hyperspace.energy
  check(g.start_hyperspace(route,5),"actual route starts "+route)
  check(g.manual_hyperspace.active,"manual session active "+route)
  g.paused=false
  for step in 600:
   scene.advance_game_time(1.0/60.0)
   if not g.manual_hyperspace.active:break
  var row:Dictionary={"route":route,"selected_level":5,"elapsed_x1":g.profile.hyperspace.active.get("work",0),"enemy_count":g.enemies.size(),"state":g.state,"projectiles":g.projectiles.size(),"session_active":g.manual_hyperspace.active,"manual_ready":g.hyperspace.snapshot(g).manual_ready}
  if g.manual_hyperspace.active:g.begin_retreat()
  check(is_same(g.db,base) and base.groups.size()==group_count and base.enemies.size()==enemy_count,"main registry restored "+route)
  check(g.profile.highestLevel==7,"no main progression from smoke "+route)
  check(g.profile.hyperspace.energy>=energy,"refund once after exit/failure "+route)
  results.append(row);scene.queue_free();await process_frame
 print("PARENT_ACTUAL_ROUTES ",JSON.stringify(results)," failures=",failures,"; four <=10s X1 fragments, not balance or 60-stage acceptance")
 quit(1 if failures else 0)
