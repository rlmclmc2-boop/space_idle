extends SceneTree
class TimedGame extends "res://scripts/presented_battle_game.gd":
 var tick_us:=0
 var tick_count:=0
 var entries_us:=0
 var entries_count:=0
 var targets_us:=0
 var targets_count:=0
 func weapon_entries()->Array:
  var t=Time.get_ticks_usec();var value=super.weapon_entries();entries_us+=Time.get_ticks_usec()-t;entries_count+=1;return value
 func targets(damage_type:int=0)->Array[Dictionary]:
  var t=Time.get_ticks_usec();var value=super.targets(damage_type);targets_us+=Time.get_ticks_usec()-t;targets_count+=1;return value
 func tick(dt:float)->void:
  var t=Time.get_ticks_usec();super.tick(dt);tick_us+=Time.get_ticks_usec()-t;tick_count+=1
class IsolatedUI extends "res://scripts/battlefield.gd":
 var sampling:=false
 var samples:Array=[]
 var totals:Dictionary={}
 var previous_frame:=0
 var wall_started:=0
 func add(key:String,us:int)->void:totals[key]=int(totals.get(key,0))+us
 func create_battle_game(_persist:bool)->BattleGame:
  var prototype=TimedGame.new(db,false);db=prototype.db
  prototype.launch_provider=_prototype_launch_pose;prototype.drone_launch_provider=_prototype_drone_launch_pose;prototype.target_provider=_prototype_target_point;prototype.rail_geometry_provider=_rail_geometry;prototype.rail_target_point_provider=entity_render_position
  prototype.stat_cache_enabled=true;return prototype
 func before_logical_game_tick(dt:float)->void:
  var t=Time.get_ticks_usec();super.before_logical_game_tick(dt);add("logical_pose_us",Time.get_ticks_usec()-t)
 func advance_game_time(seconds:float)->void:
  var t=Time.get_ticks_usec();super.advance_game_time(seconds);add("advance_total_us",Time.get_ticks_usec()-t)
 func advance_turrets(dt:float)->void:
  var t=Time.get_ticks_usec();super.advance_turrets(dt);add("turrets_us_nested",Time.get_ticks_usec()-t)
 func enemy_pose(enemy:Dictionary)->Dictionary:
  var t=Time.get_ticks_usec();var value=super.enemy_pose(enemy);add("enemy_pose_us_nested",Time.get_ticks_usec()-t);return value
 func enemy_render_position(enemy:Dictionary)->Vector2:
  var t=Time.get_ticks_usec();var value=super.enemy_render_position(enemy);add("enemy_render_position_us_nested",Time.get_ticks_usec()-t);add("enemy_render_position_calls",1);return value
 func player_art_scale()->float:
  var t=Time.get_ticks_usec();var value=super.player_art_scale();add("player_art_scale_us_nested",Time.get_ticks_usec()-t);add("player_art_scale_calls",1);return value
 func refresh_visible_cards(delta:=0.0)->void:
  var t=Time.get_ticks_usec();super.refresh_visible_cards(delta);add("cards_us",Time.get_ticks_usec()-t)
 func refresh_navigation()->void:
  var t=Time.get_ticks_usec();super.refresh_navigation();add("navigation_us",Time.get_ticks_usec()-t)
 func refresh_draw_layers(dt:float)->void:
  var t=Time.get_ticks_usec();super.refresh_draw_layers(dt);add("draw_layer_refresh_us",Time.get_ticks_usec()-t)
 func _process(delta:float)->void:
  if not sampling:super._process(delta);return
  var t=Time.get_ticks_usec();totals.clear();game.tick_us=0;game.tick_count=0;game.entries_us=0;game.entries_count=0;game.targets_us=0;game.targets_count=0
  super._process(delta)
  var row=totals.duplicate();row.merge({"process_us":Time.get_ticks_usec()-t,"wall_ms":float(t-previous_frame)/1000.0,"engine_delta":delta,"clamped_dt":minf(delta,0.1),"tick_us":game.tick_us,"weapon_entries_us_nested":game.entries_us,"weapon_entries_calls":game.entries_count,"targets_us_nested":game.targets_us,"targets_calls":game.targets_count,"steps":game.tick_count,"sim_seconds":float(game.tick_count)/60.0,"speed":game.speed,"particles":game.profile.chronoParticles,"stage":game.stage,"state":game.state,"paused":game.paused,"cache":game.stat_cache_enabled,"enemies":game.enemies.size(),"projectiles":game.projectiles.size(),"root_gpu":RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),"ship_gpu":RenderingServer.viewport_get_measured_render_time_gpu(ship_view.viewport.get_viewport_rid()),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)},true)
  previous_frame=t;samples.append(row)
  if Time.get_ticks_usec()-wall_started>8000000 or samples.size()>=100 or game.paused or game.stage>34:sampling=false;set_process(false)
var records:Array=[]
func _initialize()->void:call_deferred("run")
func measure(scene,label:String)->void:
 for ignored in 15:await process_frame
 var rows:Array=[]
 var previous=Time.get_ticks_usec()
 for ignored in 119:
  await process_frame
  var now=Time.get_ticks_usec()
  rows.append({"wall_ms":float(now-previous)/1000.0,"root_gpu":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"ship_gpu":RenderingServer.viewport_get_measured_render_time_gpu(scene.ship_view.viewport.get_viewport_rid()),"root_cpu":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"ship_cpu":RenderingServer.viewport_get_measured_render_time_cpu(scene.ship_view.viewport.get_viewport_rid()),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
  previous=now
 var summary:Dictionary={}
 for key in rows[0]:
  var total=0.0
  for row in rows:total+=float(row[key])
  summary[key]=total/rows.size()
 records.append({"mode":label,"rows":rows,"mean":summary});print(label," ",JSON.stringify(summary)," scale=",scene.ship_view.viewport.scaling_3d_scale," tab=",scene.equipment_tabs.current_tab," window=",root.size)
 var file=FileAccess.open("/workspace/bug-qa/performance-20261008/solid-background.json",FileAccess.WRITE);file.store_string(JSON.stringify(records));file.close()
func run()->void:
 if DisplayServer.get_name()=="headless":quit(2);return
 root.size=Vector2i(1180,812);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0;OS.low_processor_usage_mode=false
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.stat_cache_enabled=true;g.profile.onboarding.completed=true;g.profile.cleared=range(1,34);g.profile.highestLevel=34;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.resources={"1":1e9,"2":1e9}
 for i in 3:g.equip_slot("weapons",i,"laser");g.upgrade_slot("weapons",i,33)
 g.upgrade_slot("defence",0,33);g.equip_slot("defence",1,"shield");g.upgrade_slot("defence",1,33)
 g.start(34,false);g.state=BattleGame.State.COMBAT;g.spawn_group();g.paused=false;scene.refresh_structure();scene.refresh_navigation();scene._process(0.0);scene.set_process(false)
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);RenderingServer.viewport_set_measure_render_time(scene.ship_view.viewport.get_viewport_rid(),true)
 print("STARTING FIXTURE cache=",g.stat_cache_enabled," source=43842f56 stage=",g.profile.highestLevel," enemies=",g.enemies.size()," frozen_process=true scale=",scene.ship_view.viewport.scaling_3d_scale," engine=",Engine.get_version_info().string)
 for ignored in 15:await process_frame
 g.profile.chronoParticles=120.0
 print("NORMAL SPEED requested10 accepted=",g.set_speed(10.0)," cost=",g.chrono_cost(10.0)," statcache=",g.stat_cache_enabled," grant120particles=diagnostic_fixture")
 scene._process(0.0)
 for ignored in 15:await process_frame
 scene.previous_frame=Time.get_ticks_usec();scene.wall_started=scene.previous_frame;scene.sampling=true;scene.set_process(true)
 while scene.sampling:await process_frame
 var file=FileAccess.open("/workspace/bug-qa/performance-20261008/normal-x10-hotpath-warm.json",FileAccess.WRITE);file.store_string(JSON.stringify(scene.samples));file.close()
 print("SAMPLES ",scene.samples.size()," wall_seconds=",float(Time.get_ticks_usec()-scene.wall_started)/1000000.0," source43842f56 active_short_segment_initial_stage34_final_stage=",g.stage," paused=",g.paused," cache=",g.stat_cache_enabled," scale=",scene.ship_view.viewport.scaling_3d_scale," normal_x10_existing_accelerated_quality=",scene.ship_view.accelerated_quality)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/workspace/bug-qa/performance-20261008/normal-x10-hotpath-warm.png")
 print("DONE diagnostic only; hidden/frozen modes are not production optimizations or gameplay acceptance")
 quit()
