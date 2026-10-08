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
  for obj in [game,ship_view,ship_view.body_baker,hyperspace_visual]:obj.cost_us.clear();obj.cost_calls.clear();obj.cost_writes=0
  super._process(delta)
  var row=totals.duplicate();row.merge({"process_us":Time.get_ticks_usec()-t,"wall_ms":float(t-previous_frame)/1000.0,"engine_delta":delta,"clamped_dt":minf(delta,0.1),"tick_us":game.tick_us,"weapon_entries_us_nested":game.entries_us,"weapon_entries_calls":game.entries_count,"targets_us_nested":game.targets_us,"targets_calls":game.targets_count,"steps":game.tick_count,"sim_seconds":float(game.tick_count)/60.0,"speed":game.speed,"particles":game.profile.chronoParticles,"stage":game.stage,"state":game.state,"paused":game.paused,"cache":game.stat_cache_enabled,"enemies":game.enemies.size(),"projectiles":game.projectiles.size(),"root_gpu":RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),"ship_gpu":RenderingServer.viewport_get_measured_render_time_gpu(ship_view.viewport.get_viewport_rid()),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)},true)
  for pair in [[game,"core"],[ship_view,"ship"],[ship_view.body_baker,"baker"],[hyperspace_visual,"drone"]]:
   row[pair[1]+"_us"]=pair[0].cost_us.duplicate();row[pair[1]+"_calls"]=pair[0].cost_calls.duplicate();row[pair[1]+"_writes"]=pair[0].cost_writes
  previous_frame=t;samples.append(row)
  if Time.get_ticks_usec()-wall_started>8000000 or samples.size()>=45 or game.paused:sampling=false;set_process(false)

func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1600,1000);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0;OS.low_processor_usage_mode=false
 var records:Array=[]
 for count in [0,1,5]:
  seed(777)
  var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[];scene.set_process(false)
  var g=scene.game;g.save_enabled=false;g.stat_cache_enabled=true;g.rng.seed=111;g.profile.onboarding.completed=true;g.profile.cleared=range(1,17);g.profile.highestLevel=17;g.rebuild_unlocks();g.pending_unlocks.clear();g.load_hyperspace_routes()
  g.profile.loadout.weapons=[{"key":"longLaser","level":14},{"key":"missile","level":14},{"key":"laser","level":14}];g.profile.loadout.defence=[{"key":"armour","level":14},{"key":"shield","level":14}];g.invalidate_stat_cache()
  var rng=RandomNumberGenerator.new();rng.seed=5
  var ids:Array=[]
  for i in count:
   var d=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"cost:%d"%i,"gold",["laser","missile","cannon","longLaser","laser"][i],5,"1")
   preload("res://scripts/drone_inventory.gd").insert(g.profile.hyperspace.inventory,d,g.hyperspace.config);ids.append(d.id)
  if count>0:g.profile.hyperspace.inventory.equipped=ids;g.profile.hyperspace.inventory.generation+=1;g.invalidate_stat_cache()
  g.start(16,false);g.spawn_group();g.profile.hyperspace.history.delta={"1":60.0,"2":60.0}
  if not g.start_hyperspace_challenge("delta"):printerr("FIXTURE START FAILED ",g.manual_hyperspace.last_error);quit(2);return
  g.state=BattleGame.State.COMBAT;g.spawn_group();g.speed=1.0
  for enemy in g.enemies:enemy.hp=1e100
  g.player.armour=1e100;g.paused=false;scene.music_on=true;scene.music.play();scene.sound_on=true
  scene.refresh_structure();scene.refresh_navigation();scene._process(0);scene.set_process(false)
  RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);RenderingServer.viewport_set_measure_render_time(scene.ship_view.viewport.get_viewport_rid(),true)
  for ignored in 12:await process_frame
  scene.previous_frame=Time.get_ticks_usec();scene.wall_started=scene.previous_frame;scene.sampling=true;scene.set_process(true)
  while scene.sampling:await process_frame
  records.append({"source":"ea7b1a2","drone_count":count,"normal_delta":true,"music":true,"equipment_tab":scene.equipment_tabs.current_tab,"samples":scene.samples,"scope":"synthetic Delta3 first wave, armour inflated to avoid transition; no player save or natural-clear evidence"})
  var f=FileAccess.open("/workspace/bug-qa/performance-20261008/whole-frame-logic.json",FileAccess.WRITE);f.store_string(JSON.stringify(records));f.close()
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/bug-qa/performance-20261008/whole-frame-logic-"+str(count)+".png")
  print("SEGMENT_DONE drones=",count," frames=",scene.samples.size()," actual_stage=",g.stage," actual_route=",g.profile.hyperspace.active.route," music=",scene.music.playing)
  scene.queue_free();await process_frame
 print("DONE instrumented GUI short locating checks; nested timers overlap")
 quit()
