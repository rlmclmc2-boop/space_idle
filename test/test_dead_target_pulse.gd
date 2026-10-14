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
var checks:=0
var failures:=0
var reports:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 for native in [false,true]:
  var scene=load("res://main.tscn").instantiate();scene.set_script(UI);scene.automation_args=["--capture"];scene.music_on=false
  root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
  var g=scene.game;g.save_enabled=false;g.rng.seed=163;g.profile.onboarding.completed=true;scene.beginner_guide.hide();g.pending_unlocks.clear()
  g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.loadout={"weapons":[{"key":"laser","level":1},{"key":"laser","level":1}],"defence":[{"key":"armour","level":1},{"key":"shield","level":1}]}
  g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
  var template:Dictionary=g.enemies[0].duplicate(true);g.enemies.clear()
  for i in 2:
   var enemy=template.duplicate(true);enemy.uid=700+i;enemy.slot=i;enemy.x=160.0+200*i;enemy.y=300.0-90*i;enemy.size=1;enemy.hp=100.0 if i==0 else 1e9;enemy.max_hp=enemy.hp;enemy.shield=0.0;enemy.max_shield=0.0;enemy.equipment=[];enemy.cooldowns=[];enemy.explicit_formation=true;enemy.formation_count=2;g.enemies.append(enemy)
  g.publish_encounter_geometry();scene.refresh_structure();scene.select_system(0)
  scene.battle_read_model.setup(scene);g.target_spatial_source=scene.battle_read_model
  if native:
   check(g.admit_native_compiled_execution("native_low_contract"),"native pulse admission")
   g.native_execution_auto=true;scene.attach_native_display()
  else:g.combat_presentation=null
  var dead:Dictionary={};var births:Array=[];var bad:Array=[];var lingering:Dictionary={}
  var callback=func(kind:String,info:Dictionary):
   if kind=="explode" and int(info.get("uid",-1))>=700:dead[int(info.uid)]=g.production_time()
   if kind=="fire" and not bool(info.shot.hostile):
    var shot:Dictionary=info.shot;var uid=int(shot.target.get("uid",-1));var derived=bool(shot.get("repeated",false)) or bool(shot.get("chain_hop",false)) or bool(shot.get("combat_context",{}).get("derived",false))
    births.append({"serial":int(shot.serial),"target":uid,"clock":g.production_time(),"derived":derived,"after_target_death":dead.has(uid)})
    if dead.has(uid) and not derived:bad.append(int(shot.serial))
  g.event.connect(callback)
  for step in 480:
   scene._process(1.0/60.0)
   if dead.has(700):
    for shot in g.projectiles:
     if not bool(shot.hostile) and not bool(shot.get("dead",false)):
      var old=false
      for born in births:
       if born.serial==int(shot.serial) and born.target==700 and born.clock<=float(dead[700]):old=true;break
      if old:lingering[int(shot.serial)]=true
  check(dead.has(700),"target dies through actual pulse damage")
  check(bad.is_empty(),"no fresh primary attack targets an already-dead actor")
  check(not lingering.is_empty(),"already-fired straight pulses survive target death")
  check(births.any(func(b):return b.target==701 and dead.has(700) and b.clock>float(dead[700])),"future primary attacks acquire remaining live target")
  reports.append({"native":native,"deaths":dead,"births":births,"invalid_new_primary":bad,"surviving_birth_serials":lingering.keys()})
  g.event.disconnect(callback)
  if scene.battle_slice_runtime!=null:scene.battle_slice_runtime.close();scene.battle_slice_runtime=null
  if g.native_execution!=null:g.native_execution.cancel(g);g.native_execution=null
  scene.queue_free();await process_frame
 var f=FileAccess.open("res://.runtime/dead-target-pulse.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":reports},"\t"));f.close()
 print("DEAD_TARGET_PULSE ",checks," checks ",failures," failures");quit(1 if failures else 0)
