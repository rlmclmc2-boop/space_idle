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
 var mode:="baseline"
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
  var t=Time.get_ticks_usec()
  if mode!="logic_off":super.advance_game_time(seconds)
  add("advance_total_us",Time.get_ticks_usec()-t)
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
  if mode in ["ship_gpu_off","all_render_off"]:ship_view.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
  if mode=="battle_draw_off":
   for layer in [battle_layer,drop_layer,battle_hud_layer,pulse_layer]:layer.hide()
  var row=totals.duplicate();row.merge({"process_us":Time.get_ticks_usec()-t,"wall_ms":float(t-previous_frame)/1000.0,"engine_delta":delta,"clamped_dt":minf(delta,0.1),"tick_us":game.tick_us,"weapon_entries_us_nested":game.entries_us,"weapon_entries_calls":game.entries_count,"targets_us_nested":game.targets_us,"targets_calls":game.targets_count,"steps":game.tick_count,"sim_seconds":float(game.tick_count)/60.0,"speed":game.speed,"particles":game.profile.chronoParticles,"stage":game.stage,"state":game.state,"paused":game.paused,"cache":game.stat_cache_enabled,"enemies":game.enemies.size(),"projectiles":game.projectiles.size(),"root_gpu":RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),"ship_gpu":RenderingServer.viewport_get_measured_render_time_gpu(ship_view.viewport.get_viewport_rid()),"ship_update_mode":ship_view.viewport.render_target_update_mode,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)},true)
  previous_frame=t;samples.append(row)
  if Time.get_ticks_usec()-wall_started>8000000 or samples.size()>=28 or game.stage>34:sampling=false;set_process(false)

var records:Array=[]
func _initialize()->void:call_deferred("run")
func run()->void:
 if DisplayServer.get_name()=="headless":quit(2);return
 root.size=Vector2i(1180,812);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0;OS.low_processor_usage_mode=false
 for paused in [false,true]:
  for mode in ["baseline","logic_off","battle_draw_off","workspace_off","ship_gpu_off","all_render_off"]:
   seed(123456)
   var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[];scene.set_process(false)
   var g=scene.game;g.rng.seed=123456;g.save_enabled=false;g.stat_cache_enabled=true;g.profile.onboarding.completed=true;g.profile.cleared=range(1,34);g.profile.highestLevel=34;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.resources={"1":1e9,"2":1e9}
   for i in 3:g.equip_slot("weapons",i,"laser");g.upgrade_slot("weapons",i,33)
   g.upgrade_slot("defence",0,33);g.equip_slot("defence",1,"shield");g.upgrade_slot("defence",1,33)
   g.start(34,false);g.state=BattleGame.State.COMBAT;g.spawn_group();
   for enemy in g.enemies:enemy.hp=1e100
   g.player.armour=1e100;g.paused=paused;g.set_speed(1.0);scene.refresh_structure();scene.refresh_navigation();scene._process(0.0);scene.set_process(false)
   var saved=g.portable_save_data()
   for field in ["hightechSavedAt","chronoSavedAt"]:saved[field]=0.0
   var initial={"full_save":saved,"battle_graph":preload("res://scripts/hyperspace_battle_return.gd").capture(g),"rng_state":g.rng.state,"paused":g.paused,"stage":g.stage,"speed":g.speed}
   var fingerprint=var_to_bytes(initial).hex_encode().sha256_text()
   RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);RenderingServer.viewport_set_measure_render_time(scene.ship_view.viewport.get_viewport_rid(),true)
   for ignored in 8:await process_frame
   scene.mode=mode
   if mode=="workspace_off":scene.equipment_tabs.hide()
   if mode in ["ship_gpu_off","all_render_off"]:scene.ship_view.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
   if mode=="all_render_off":RenderingServer.set_render_loop_enabled(false)
   scene.previous_frame=Time.get_ticks_usec();scene.wall_started=scene.previous_frame;scene.sampling=true;scene.set_process(true)
   while scene.sampling:await process_frame
   var rows=scene.samples.slice(5);var means:Dictionary={}
   for row in rows:
    for key in row:
     if row[key] is int or row[key] is float:means[key]=float(means.get(key,0.0))+float(row[key])/rows.size()
   var record={"paused":paused,"mode":mode,"initial_fingerprint":fingerprint,"samples":scene.samples,"mean":means,"wall_seconds":float(Time.get_ticks_usec()-scene.wall_started)/1e6,"source":"31fe8c9/be430bd2 UI + e3cdefd crew + cd680ec config","cache":g.stat_cache_enabled}
   records.append(record);print("COST ",paused," ",mode," ",JSON.stringify(means)," fingerprint=",fingerprint)
   if mode=="baseline":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/workspace/bug-qa/performance-20261008/x1-pause-"+str(paused)+".png")
   var f=FileAccess.open("/workspace/bug-qa/performance-20261008/x1-pause-cost.json",FileAccess.WRITE);f.store_string(JSON.stringify(records));f.close()
   scene.queue_free();await process_frame
   RenderingServer.set_render_loop_enabled(true)
   for ignored in 3:await process_frame
 print("DONE short synthetic level34 GUI diagnostic; no player save, normal X1 delta; GPU counters stale when disabled; all_render_off retains scripts but suppresses rendering")
 quit()
