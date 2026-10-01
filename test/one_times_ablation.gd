## Opt-in diagnostic only. Production launch never loads this script.
extends SceneTree
class Meter extends RefCounted:
 var enabled=true
 var times={}
 func record(key,us):
  if not enabled:return
  if not times.has(key):times[key]=[0,0,0]
  times[key][0]+=1;times[key][1]+=us;times[key][2]=max(times[key][2],us)
class NoEnhancementBranches extends "res://scripts/enhancement_branches.gd":
 func active(_g,_entry:Dictionary,_effect:String,_node:int,_choice:String)->bool:return false
 func reconcile(_g)->void:pass
 func advance_weapons(_g,_dt:float)->void:pass
 func advance_defense(_g,_dt:float)->void:pass
class NoEnhancementGame extends "res://scripts/presented_battle_game.gd":
 func enhancement_effects(_entry:Dictionary)->Array:return []
 func memory_effect(_entry:Dictionary)->Dictionary:return {}
class UI extends "res://scripts/battlefield.gd":
 var off=OS.get_environment("PERF_OFF")
 var render_views=[]
 func find_views(node:Node)->void:
  if node is SubViewport:render_views.append(node)
  for child in node.get_children():find_views(child)
 func create_battle_game(_persist:bool)->BattleGame:
  if off!="enhancement":return super.create_battle_game(false)
  var prototype=NoEnhancementGame.new(db,false)
  prototype.enhancement_branches=NoEnhancementBranches.new()
  db=prototype.db;prototype.launch_provider=_prototype_launch_pose;prototype.target_provider=_prototype_target_point
  return prototype
 func advance_game_time(seconds:float)->void:
  if off!="combat":super.advance_game_time(seconds)
 func refresh_visible_cards(delta:=0.0)->void:
  if off!="ui":super.refresh_visible_cards(delta)
 func refresh_navigation()->void:
  if off!="ui":super.refresh_navigation()
 func _draw_muzzle_cues()->void:
  if off!="vfx":super._draw_muzzle_cues()
 func draw_projectile_fx(shot:Dictionary,pos:Vector2,offset:Vector2,core:=true,visual:Dictionary={},trail_budget:=-1)->float:
  if off=="vfx":return float(visual.get("angle",Vector2(shot.direction).angle()))
  return super.draw_projectile_fx(shot,pos,offset,core,visual,trail_budget)
 func draw_projectile_body_override(shot:Dictionary,pos:Vector2,angle:float)->bool:
  return true if off=="vfx" else super.draw_projectile_body_override(shot,pos,angle)
 func draw_beam_override(shot:Dictionary,offset:Vector2,core:bool=true)->bool:
  return true if off=="vfx" else super.draw_beam_override(shot,offset,core)
 func draw_battle_particles(offset:Vector2,core:bool)->void:
  if off!="vfx":super.draw_battle_particles(offset,core)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 var rows=[]
 var previous={}
 var began=0
 var frames=0
 func _process(dt:float)->void:
  var now=Time.get_ticks_usec()
  var meter=Engine.get_meta("saved_perf")
  if not previous.is_empty():
   previous.frame_us=now-began;previous.timings=meter.times.duplicate(true)
   if frames>0:rows.append(previous)
  meter.times.clear();began=now;frames+=1
  var start=Time.get_ticks_usec()
  super._process(dt)
  if off=="3d":
   for view in render_views:view.render_target_update_mode=SubViewport.UPDATE_DISABLED
  var elapsed=Time.get_ticks_usec()-start
  previous={"frame":frames,"dt":dt,"main_us":elapsed,"speed":game.speed,"paused":game.paused,"page":equipment_tabs.current_tab,"projectiles":game.projectiles.size(),"missile_queue":game.missile_queue.size(),"repeats":game.jewel_repeats.size(),"deferred_buckets":game.enhancement_deferred.size(),"attacks":game.profile.enhancementAttacks,"hits":game.profile.enhancementHits,"memory":OS.get_static_memory_usage(),"nodes":get_tree().get_node_count(),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
var meter=Meter.new()
func _initialize():
 Engine.set_meta("saved_perf",meter)
 call_deferred("run")
func run():
 var mode=OS.get_environment("PERF_OFF")
 if mode not in ["","3d","vfx","ui","enhancement","combat"]:
  printerr("Unknown PERF_OFF; use empty/control, 3d, vfx, ui, enhancement or combat");quit(1);return
 seed(1701)
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game
 g.save_enabled=false;g.stat_cache_enabled=true;g.rng.seed=1701;g.speed=1
 g.profile.onboarding.completed=true
 if is_instance_valid(scene.beginner_guide):scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.profile.highestLevel=101
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 for p in g.profile.planets.values():p.conquered=true
 g.rebuild_unlocks();g.pending_unlocks.clear();g.galaxy.refresh_unlocks(g)
 g.profile.scientists=49
 for key in g.db.data.hightech:
  g.profile.scientistAssignments[key]=11
  g.profile.techPoints[key]=g.hightech_required(key)*0.45
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://../test/fixtures/galaxy_1_complete.json"))
 g.galaxy.load_state(g,{"galaxy_1":fixture.save})
 if true:
  g.profile.selectedShip="Heavy_Battleship"
  var balance=float(OS.get_environment("PERF_BALANCE")) if not OS.get_environment("PERF_BALANCE").is_empty() else 1e80
  g.profile.resources={"1":balance,"2":balance}
  g.profile.jewelFragments=1e40;g.profile.enhancementLevel=479
  g.profile.enhancementAttacks=1000000;g.profile.enhancementHits=1000000
  g.profile.loadout={"weapons":[],"defence":[]}
  for key in ["laser","missile","cannon","longLaser","laser","missile","cannon","longLaser"]:g.profile.loadout.weapons.append({"key":key,"level":150})
  for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":150})
  for crew in g.profile.crew:crew.level=103;crew.exp=13159583000.0
  for key in g.db.data.hightech:g.profile.hightechLevels[key]=303
  g.planet_buildings.sync(g,"1")
  for item in g.profile.planets["1"].buildings.values():item.status="built"
  g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
  var template=g.enemies[0].duplicate(true);g.enemies.clear()
  for i in 3:
   var enemy=template.duplicate(true);enemy.uid=100+i;enemy.slot=i;enemy.x=200+80*i;enemy.y=230-2*i;enemy.hp=1e100;enemy.max_hp=1e100
   g.enemies.append(enemy)
 if true:
  g.profile.enhancementLevel=479-g.enhancement_level_bonus()
  g.invalidate_stat_cache();g.reset_player()
 g.invalidate_stat_cache()
 scene.refresh_structure();scene.refresh_tab_visibility()
 print("ENV ",JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"method":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"resolution":str(root.size),"cap":Engine.max_fps,"low_processor":OS.low_processor_usage_mode}))

 scene.equipment_panel.set_upgrade_amount(1)
 scene.select_system(0)
 await process_frame
 scene._process(0.0)
 scene.rows.clear();scene.previous={};scene.frames=0
 scene.background_unfocused=false
 g.speed=1;g.paused=false
 print("FIXTURE ",JSON.stringify({"upgrade_amount":scene.equipment_panel.upgrade_amount,"speed":g.speed,"effective_enhancement":g.enhancement_effective_level(),"weapons":g.weapon_entries().size(),"drones":scene.ship_view.carriers.size(),"enhancement_branches":g.profile.enhancementBranches,"save_enabled":g.save_enabled}))
 scene.find_views(scene)
 # Warm only the rendering pipeline. Combat stays at the same seeded initial state.
 for ignored in 15:await process_frame
 scene.rows.clear();scene.previous={};scene.frames=0
 scene.set_process(true)
 var deadline=Time.get_ticks_usec()+6000000
 while Time.get_ticks_usec()<deadline:await process_frame
 scene.set_process(false)
 var stamp=Time.get_datetime_string_from_system().replace(":","-")
 var path="res://.runtime/ablation-"+(mode if not mode.is_empty() else "control")+"-"+stamp+".json"
 var metadata={"mode":mode,"duration_seconds":6,"seed":1701,"speed":g.speed,"upgrade_amount":scene.equipment_panel.upgrade_amount,"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"rendering_method":RenderingServer.get_current_rendering_method(),"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"window_size":DisplayServer.window_get_size(),"game_sha256":FileAccess.get_sha256("res://scripts/game.gd"),"branches_sha256":FileAccess.get_sha256("res://scripts/enhancement_branches.gd"),"note":"Synthetic fresh seeded fixture; never loads/saves player progress. Ablation is diagnostic, not an equivalent gameplay result. Enhancement/combat modes change state evolution; frame pacing changes simulated time because production delta clamp remains intact."}
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"metadata":metadata,"rows":scene.rows}))
 print("ABLATION REPORT: ",ProjectSettings.globalize_path(path))
 print("DONE rows=",scene.rows.size()," speed=",g.speed," paused=",g.paused)
 g.launch_provider=Callable();g.target_provider=Callable()
 scene.queue_free();await process_frame;await process_frame
 Engine.remove_meta("saved_perf")
 quit()
