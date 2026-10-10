extends SceneTree
class QuietUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
var scene
var checks=0
var failures=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;print("FAIL ",label)
func state()->String:return JSON.stringify([scene.floats,scene.damage_pending,scene.damage_history])
func run_sequence(scoped:bool,scenario:int)->Array:
 scene.step_geometry_enabled=scoped
 scene.floats.clear();scene.damage_pending.clear();scene.damage_history.clear()
 scene.fx_time=5.0;scene.enemy_entry_distance_time=-INF
 scene.step_geometry.begin(scoped)
 for enemy in scene.game.enemies:enemy.hp=1e100;scene.enemy_pose(enemy).born=0.0 if scenario!=1 else 4.9
 var result=[]
 for i in 24:
  if i==12:
   scene.step_geometry.invalidate();result.append(state());scene.fx_time+=0.21
  var enemy=scene.game.enemies[i%scene.game.enemies.size()]
  if scenario==2 and i%4==0:enemy.hp=0.0
  var info={"player":i%3==0,"uid":enemy.uid,"type":1+i%2,"amount":1234.0*(i+1),"absorbed":7.0,"critical":i%4==0}
  scene.on_event("hit",info)
  if scenario==3 and i%5==0:
   scene.on_event("presentation_test_barrier",{})
   enemy.y+=3.0
  if i%7==0:
   scene.on_event("presentation_test_barrier",{});result.append(state())
 scene.step_geometry.invalidate();result.append(state())
 for f in scene.floats:
  f.life-=0.0166666666666667
  if f.get("damage",false) and not f.get("incoming_lane",false):f.pos.y-=0.2
 scene.floats=scene.floats.filter(func(f):return f.life>0)
 scene.flush_damage_numbers();result.append(state())
 scene.step_geometry.finish()
 check(scene.step_geometry.positions.is_empty() and not scene.step_geometry.active,"scope released")
 return result
func _initialize()->void:call_deferred("run")
func run()->void:
 scene=load("res://main.tscn").instantiate();scene.set_script(QuietUI)
 scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[];scene.set_process(false);scene.hide()
 var g=scene.game;g.save_enabled=false;g.paused=true;g.stage=20;g.group_index=0;g.state=BattleGame.State.COMBAT;g.rng.seed=1701;g.spawn_group()
 for enemy in g.enemies:enemy.hp=1e100;enemy.max_hp=1e100;scene.enemy_pose(enemy)
 var original=g.enemies.duplicate(true)
 for scenario in 4:
  for i in g.enemies.size():g.enemies[i].merge(original[i],true)
  var rng=g.rng.state;var a=run_sequence(false,scenario)
  for i in g.enemies.size():g.enemies[i].merge(original[i],true)
  var b=run_sequence(true,scenario)
  check(a==b,"synchronous labels and history scenario%d"%scenario)
  check(g.rng.state==rng,"combat RNG unchanged scenario%d"%scenario)
  if a!=b:
   for i in a.size():
    if a[i]!=b[i]:print("DIFF scenario",scenario," boundary",i," A=",a[i]," B=",b[i]);break
 scene.step_geometry.begin(true)
 var enemy=g.enemies[0];var p=scene.enemy_render_position(enemy)
 var replacement=enemy.duplicate(true);replacement.x+=13.0
 var q=scene.enemy_render_position(replacement)
 check(p!=q,"same UID replacement identity checked")
 var context=scene.damage_layout_context();context.marker=true
 var original_entity=g.enemies[0];g.enemies[0]=replacement
 check(not scene.damage_layout_context().has("marker"),"same UID replacement releases obstacle snapshot")
 g.enemies[0]=original_entity
 scene.step_geometry.finish()
 g.launch_provider=Callable();g.target_provider=Callable();scene.queue_free();await process_frame;await process_frame
 print("CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
