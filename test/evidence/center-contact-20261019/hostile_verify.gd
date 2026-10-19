extends SceneTree
class UI extends "res://scripts/battlefield.gd":
 var impacts:Dictionary={}
 func weapon_impact(shot:Dictionary,point:Vector2)->void:
  impacts[int(shot.serial)]=battle_point(point)
  super.weapon_impact(shot,point)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func create_battle_game(_persist:bool)->BattleGame:
  var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
  g.stat_cache_enabled=true;g.invalidate_stat_cache()
  db=g.db;g.native_execution_auto=false
  g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
  battle_read_model.setup(self);g.target_spatial_source=battle_read_model
  g.target_provider=_prototype_target_point;g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
  g.enable_compiled_combat_rules()
  return g
var checks:=0
var failures:=0
var cases:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.max_fps=0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 for native_mode in [true,false]:
  for hull in ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]:
   var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
   scene.automation_args=["--capture"];scene.music_on=false
   root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
   var g=scene.game;g.save_enabled=false;g.rng.seed=1975;g.profile.onboarding.completed=true;scene.beginner_guide.hide();g.pending_unlocks.clear()
   g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.selectedShip=hull
   g.profile.loadout={"weapons":[{"key":"laser","level":1}],"defence":[{"key":"armour","level":20}]}
   g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
   var enemy:Dictionary=g.enemies[0].duplicate(true);g.enemies.clear()
   enemy.uid=501;enemy.slot=0;enemy.x=286.0;enemy.y=250.0;enemy.hp=1e12;enemy.max_hp=1e12;enemy.explicit_formation=true;enemy.formation_count=1
   enemy.equipment=[];enemy.cooldowns=[]
   for key in ["laser_mon","missile-mon","cannon-mon","longLaser-mon"]:
    enemy.equipment.append({"name":key,"level":1});enemy.cooldowns.append(0.0)
   g.enemies.append(enemy);g.publish_encounter_geometry()
   scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
   var rt=null
   if native_mode:
    check(g.admit_native_compiled_execution("native_low_contract"),"native admission")
    rt=preload("res://scripts/battle_slice_runtime.gd").new();scene.battle_slice_runtime=rt;rt.install(scene);g.native_execution_auto=true
   var hits:Dictionary={}
   var callback=func(kind:String,info:Dictionary):
    if not info.has("shot") or not bool(info.shot.get("hostile",false)):return
    if kind=="projectile_impact":
     var at:Vector2=scene.battle_point(info.pos)
     check(at.distance_to(scene.player_contact_screen_position())<0.1,"enemy projectile resolves at player centre: "+str(info.shot.key))
     hits[str(info.shot.key)]=true
    elif kind=="beam_hit":
     check(scene.shot_target_screen_position(info.shot).distance_to(scene.player_render_position())<0.1,"enemy beam ends at player centre")
     hits[str(info.shot.key)]=true
   g.event.connect(callback)
   for step in 900:
    scene._process(1.0/60.0)
    if hits.size()>=4:break
   check(hits.size()>=4,"all four enemy weapons observed: "+str(native_mode)+hull+str(hits.keys()))
   cases.append({"native":native_mode,"hull":hull,"weapons":hits.keys()})
   g.event.disconnect(callback)
   if rt!=null:rt.close();scene.battle_slice_runtime=null
   scene.queue_free();await process_frame
 DirAccess.make_dir_recursive_absolute("res://.runtime")
 var f=FileAccess.open("res://.runtime/hostile-center.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"));f.close()
 print("HOSTILE_CENTER ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
