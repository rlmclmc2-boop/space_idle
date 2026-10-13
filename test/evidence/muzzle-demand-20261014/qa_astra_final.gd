extends SceneTree
## Existing real-1x acceptance driver, with diagnostics only after the timed sample.
## Copy this file and test/combat_stress_fixture.gd to an isolated project root;
## run it with the matching native DLL loaded and PERF_NATIVE=1. No player save.
class UI extends "res://scripts/battlefield.gd":
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func create_battle_game(_persist:bool)->BattleGame:
  var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
  g.stat_cache_enabled=true;g.invalidate_stat_cache()
  assert(g.stat_cache_enabled and not g.save_enabled,"QA save false, production stat cache true")
  db=g.db;g.native_execution_auto=false
  g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
  g.target_provider=_prototype_target_point;g.target_spatial_source=battle_read_model
  g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
  g.enable_compiled_combat_rules()
  return g
 var straight_shots:Array=[]
 var impacted:Dictionary={}
 var verify_geometry:=false
 var verified_hits:=0
 var ballistic_hits:=0
 var ballistic_outside:=0
 var aim_mismatches:=0
 var aim_thefts:=0
 var locks:Dictionary={}
 var lock_changes:=0
 var invalid_escapes:=0
 var counted:Dictionary={}
 var fire_count:=0
 var hit_count:=0
 var purchase_trace:Array=[]
 var observed_frames:Array=[]
 var track_frames:=false
 var batch_start:=0
 var batch_residences:Array=[]
 var phase_cost:Dictionary={}
 var process_begin_us:=0
 var process_end_us:=0
 var active_frame:=0
 var legacy_started_steps:=0
 func before_logical_game_tick(dt:float)->void:
  super.before_logical_game_tick(dt)
  legacy_started_steps+=1
 func logical_step_count(in_tick:bool=false)->int:
  if battle_slice_runtime!=null:return battle_slice_runtime.logical_steps
  return legacy_started_steps-1 if in_tick else legacy_started_steps
 func watch(kind:String,info:Dictionary)->void:
  if kind=="fire":
   fire_count+=1
   if verify_geometry:
    var shot:Dictionary=info.shot
    if shot.has("fixed_screen_step"):straight_shots.append(shot)
    if battle_slice_runtime!=null and not bool(shot.get("hostile",false)):
     var mount=battle_slice_runtime.geometry.shot_mount(shot)
     if mount>=0:
      var pose=battle_slice_runtime.geometry.turret_pose(mount)
      var uid=int(pose.target.get("uid",-1))
      if not bool(shot.get("owns_primary_aim",true)) and locks.has(mount) and uid!=locks[mount]:aim_thefts+=1
      if locks.has(mount) and uid!=locks[mount]:lock_changes+=1
      if bool(shot.get("owns_primary_aim",false)) and uid!=int(shot.get("primary_target",shot.target).get("uid",-1)):aim_mismatches+=1
      locks[mount]=uid
  elif verify_geometry and kind=="projectile_impact" and info.shot.has("fixed_screen_step"):
   impacted[int(info.shot.serial)]=true;ballistic_hits+=1
   if verify_geometry:
    verified_hits+=1
    var geometry=battle_slice_runtime.geometry
    var shot:Dictionary=info.shot;var target:Dictionary=shot.target
    var packet:Dictionary=geometry.enemy_recognition_geometry(target,geometry.enemy_render_width(target))
    var polygon=PackedVector2Array();var center:Vector2=geometry.enemy_render_position(target)
    for vertex in packet.inner:polygon.append(center+Vector2(vertex).rotated(PI+geometry.enemy_render_angle(target)))
    var screen:Vector2=shot.fixed_screen_origin+shot.fixed_screen_step*(Vector2(info.pos)-Vector2(shot.launch_point)).dot(game.projectile_direction(shot))
    var near=false
    for i in polygon.size():
     if screen.distance_to(Geometry2D.get_closest_point_to_segment(screen,polygon[i],polygon[(i+1)%polygon.size()]))<1.0:near=true
    if not Geometry2D.is_point_in_polygon(screen,polygon) and not near:ballistic_outside+=1
  elif kind=="hit":hit_count+=1
  elif kind=="upgrades_completed":
   purchase_trace.append({"clock":game.production_time(),"steps":logical_step_count(true),"slots":info.slots.duplicate(),"frame":active_frame})
 func _process(delta:float)->void:
  process_begin_us=Time.get_ticks_usec()
  active_frame+=1
  super._process(delta)
  if track_frames:observed_frames.append({"logic_steps":logical_step_count(),"clock":game.production_time(),"delta":delta,"projectiles":game.projectiles.size(),"floats":floats.size(),"pending":damage_pending.size(),"unfocused":background_unfocused,"fires":fire_count,"hits":hit_count,"purchases":levels()})
  process_end_us=Time.get_ticks_usec()
  phase_cost["main_process_us"]=process_end_us-process_begin_us
 func levels()->int:
  var total=0
  for entry in game.loadout_entries("weapons")+game.loadout_entries("defence"):total+=int(entry.level)
  return total
 func advance_game_time(seconds:float)->void:
  var began=Time.get_ticks_usec()
  super.advance_game_time(seconds)
  phase_cost["advance_game_time_us"]=int(phase_cost.get("advance_game_time_us",0))+Time.get_ticks_usec()-began
 func draw_battle()->void:
  var began=Time.get_ticks_usec()
  super.draw_battle()
  phase_cost["draw_battle_us"]=int(phase_cost.get("draw_battle_us",0))+Time.get_ticks_usec()-began
 func draw_battle_foreground(flights:Variant,shots:Array,offset:Vector2)->void:
  var began=Time.get_ticks_usec()
  super.draw_battle_foreground(flights,shots,offset)
  phase_cost["draw_battle_foreground_us"]=int(phase_cost.get("draw_battle_foreground_us",0))+Time.get_ticks_usec()-began
 func _draw_muzzle_cues()->void:
  var began=Time.get_ticks_usec()
  super._draw_muzzle_cues()
  phase_cost["_draw_muzzle_cues_us"]=int(phase_cost.get("_draw_muzzle_cues_us",0))+Time.get_ticks_usec()-began
func inheritance(g)->Array:
 var rows:Array=[]
 for entry in g.combat_weapon_entries():
  if not entry.has("drone_id"):continue
  var drone:Dictionary=g.profile.hyperspace.inventory.drones[entry.drone_id]
  var maximum:=1
  for ordinary in g.module_entries("weapons"):
   if ordinary.key==drone.weapon:maximum=maxi(maximum,int(ordinary.level))
  var bonus:int=preload("res://scripts/drone_effect_aggregator.gd").weapon_bonus(drone,g.hyperspace.config)
  assert(int(entry.level)==maximum+bonus,"highest same-type ordinary module level remains inherited")
  rows.append({"id":entry.drone_id,"key":entry.key,"level":entry.level,"highest_ordinary":maximum,"bonus":bonus})
 assert(rows.size()==5,"all five equipped drone attack sources remain")
 return rows
func render_times(scene)->Dictionary:
 var result:Dictionary={}
 for pair in [["root",root],["ship",scene.ship_view.viewport]]:
  var rid:RID=pair[1].get_viewport_rid()
  result[pair[0]]={"cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),"gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid)}
 return result
var process_signal_us:=0
var pre_draw_us:=0
func _initialize()->void:
 process_frame.connect(func():process_signal_us=Time.get_ticks_usec())
 RenderingServer.frame_pre_draw.connect(func():pre_draw_us=Time.get_ticks_usec())
 call_deferred("run")
func snapshot(scene)->Dictionary:
 return {"steps":scene.logical_step_count(),"game":scene.game.production_time(),"fires":scene.fire_count,"hits":scene.hit_count,"purchases":scene.levels(),"handoffs":scene.game.native_handoff_count}
func config(scene)->Dictionary:
 var g=scene.game
 return {"stat_cache_enabled":g.stat_cache_enabled,"save_enabled":g.save_enabled,"compiled_rules":g.compiled_combat_rules!=null,"independent_qualification_plan":("enhancement_plan" in g),"combat_presentation":g.combat_presentation!=null,"native_auto":g.native_execution_auto,"native_active":g.native_execution!=null,"retained":scene.retained_contacts_enabled,"speed":g.speed,"engine_max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"time_scale":Engine.time_scale,"fixed_logic_hz":60,"window":str(DisplayServer.window_get_size()),"accelerated_visual_mode":scene.accelerated_visual_mode,"pulse_fx":scene.pulse_vfx_enabled,"missile_fx":scene.missile_vfx_enabled,"enemy_fx":scene.enemy_vfx_enabled,"old_pipeline_class":ClassDB.class_exists("SpaceNativePipeline")}
func pause_input(scene)->Dictionary:
 var before=snapshot(scene)
 var press=InputEventKey.new();press.keycode=KEY_SPACE;press.physical_keycode=KEY_SPACE;press.pressed=true
 Input.parse_input_event(press)
 await process_frame
 assert(scene.game.paused,"actual Space input pauses")
 scene.set_process(true)
 for frame in 3:await RenderingServer.frame_post_draw
 scene.set_process(false)
 var paused=snapshot(scene)
 assert(before.steps==paused.steps and before.game==paused.game,"paused rendered frames never advance logical time")
 var release=InputEventKey.new();release.keycode=KEY_SPACE;release.physical_keycode=KEY_SPACE;release.pressed=false
 Input.parse_input_event(release)
 Input.parse_input_event(press)
 await process_frame
 assert(not scene.game.paused,"actual Space input resumes")
 Input.parse_input_event(release)
 return {"pause_input":true,"resume_input":true,"paused_render_frames":3,"logical_steps_while_paused":paused.steps-before.steps,"default_max_fps":Engine.max_fps}
func finish(scene,stress,row:Dictionary,label:String)->void:
 var g=scene.game
 row.verified_hits=scene.verified_hits
 row.ballistic_hits=scene.ballistic_hits;row.ballistic_outside=scene.ballistic_outside
 row.aim_mismatches=scene.aim_mismatches
 row.aim_thefts=scene.aim_thefts;row.lock_changes=scene.lock_changes
 for shot in scene.straight_shots:
  if bool(shot.dead) and not scene.impacted.has(int(shot.serial)):scene.invalid_escapes+=1
 row.invalid_straight_retirements=scene.invalid_escapes
 row.straight_launches=scene.straight_shots.size()
 row.enemy_positions=[]
 for enemy in g.enemies:row.enemy_positions.append(str(scene.battle_slice_runtime.geometry.enemy_render_position(enemy)))
 assert(row.ballistic_hits>0 and row.ballistic_outside==0 and row.aim_thefts==0 and row.aim_mismatches==0,"screen hull impacts and primary lock agree")
 row.input_check=await pause_input(scene)
 row.runtime_config_end=config(scene)
 row.stress=stress.finish(g)
 row.drone_inheritance=inheritance(g)
 row.window_focused=root.has_focus()
 row.rendering_method=RenderingServer.get_current_rendering_method()
 row.video_adapter=RenderingServer.get_video_adapter_name()
 row.window_mode=root.mode
 assert(g.stat_cache_enabled and not g.save_enabled and g.compiled_combat_rules!=null and g.combat_presentation!=null,"configuration remains production-equivalent cache/frontend")
 row.merge({"fire_total":scene.fire_count,"hit_total":scene.hit_count,"purchase_trace":scene.purchase_trace,"batch_residences_us":scene.batch_residences,"rng_state":str(g.rng.state),"native_active":g.native_execution!=null,"engine_max_fps":Engine.max_fps,"vsync_mode":DisplayServer.window_get_vsync_mode(),"speed":g.speed,"viewport":str(root.size),"window":str(DisplayServer.window_get_size()),"held_frame":scene.retained_contacts.frame.size() if scene.retained_contacts_enabled else 0,"background_unfocused":scene.background_unfocused})
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.runtime/"+label+".png")
 FileAccess.open("res://.runtime/clean-sample-acceptance.json",FileAccess.WRITE).store_string(JSON.stringify(row))
 print("CACHE_ON_COMPLETE ",label," steps ",row.sample_steps," frames ",row.frames_us_raw.size()," fires ",row.fires," hits ",row.hits," purchases ",row.purchases," handoffs ",row.handoffs," config ",JSON.stringify(row.runtime_config_end))
 assert(row.handoffs==0 and row.native_active==(OS.get_environment("PERF_NATIVE")=="1"),"whole window keeps chosen owner")
 stress.finish(g);g.begin_retreat();scene.queue_free();await process_frame;await process_frame
 quit()
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1701
 g.profile.onboarding.completed=true;scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.selectedShip="Heavy_Battleship"
 g.profile.resources={"1":1e80,"2":1e80};g.profile.loadout={"weapons":[],"defence":[]}
 for key in ["missile","missile","cannon","longLaser","laser","missile","cannon","longLaser"]:g.profile.loadout.weapons.append({"key":key,"level":150})
 for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":150})
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
 var template=g.enemies[0].duplicate(true);g.enemies.clear()
 for i in 15:
  var e=template.duplicate(true);e.uid=100+i;e.slot=i;e.x=80+80*(i%5);e.y=150+80*(i/5);e.hp=1e100;e.max_hp=1e100
  g.enemies.append(e)
 var stress=preload("res://combat_stress_fixture.gd").new();assert(stress.configure(g,2))
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)

 assert(g.assign_crew("navigator","equipment_upgrade","equipment"),"normal main batch scheduler enabled")
 var native=OS.get_environment("PERF_NATIVE")=="1"
 g.native_execution_auto=native
 if native:
  assert(g.admit_native_compiled_execution("native_rich15_layer2"),"integrated native contract admitted")
  assert(scene.attach_native_display(),"direct native display attached")
 scene.retained_contacts_enabled=true
 assert(g.stat_cache_enabled and not g.save_enabled and g.compiled_combat_rules!=null and g.combat_presentation!=null,"startup cache/compiled/presentation contract")
 assert(Engine.max_fps==60 and is_equal_approx(g.speed,1.0) and is_equal_approx(Engine.time_scale,1.0),"default frequency/cap/speed intact")
 var startup_config=config(scene)
 startup_config.accessibility_enabled=is_accessibility_enabled()
 startup_config.accessibility_setting=ProjectSettings.get_setting("accessibility/general/accessibility_support",0)
 startup_config.cmdline=OS.get_cmdline_args()
 startup_config.engine_version=Engine.get_version_info()
 startup_config.frame_delay=ProjectSettings.get_setting("application/run/frame_delay_msec",0)
 startup_config.low_processor_mode=OS.low_processor_usage_mode
 Engine.set_meta("phase_cost",scene.phase_cost)
 print("CACHE_ON_START ",JSON.stringify(startup_config))
 g.event.connect(scene.watch)
 var begin=snapshot(scene);var warm_start=Time.get_ticks_usec()
 scene.set_process(true)
 while scene.logical_step_count()-begin.steps<240:await RenderingServer.frame_post_draw
 scene.set_process(false)
 var baseline=snapshot(scene);var sample_start=Time.get_ticks_usec();var warm_wall=sample_start-warm_start
 scene.track_frames=true;scene.set_process(true)
 var phase_rows:Array=[]
 scene.phase_cost.clear()
 var render_rows:Array=[]
 var frames:Array=[];var bodies:Array=[];var floats_raw:Array=[];var pending_raw:Array=[];var primitives:Array=[];var drawcalls:Array=[];var previous=sample_start
 while scene.logical_step_count()-baseline.steps<240:
  await RenderingServer.frame_post_draw
  var now=Time.get_ticks_usec()
  phase_rows.append({"frame_us":now-previous,"post_to_process_signal_us":process_signal_us-previous,"process_signal_to_pre_draw_us":pre_draw_us-process_signal_us,"pre_to_post_draw_us":now-pre_draw_us,"signal_to_main_us":scene.process_begin_us-process_signal_us,"main_to_pre_draw_us":pre_draw_us-scene.process_end_us,"costs":scene.phase_cost.duplicate(),"physics_monitor_us":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000000.0,"process_monitor_us":Performance.get_monitor(Performance.TIME_PROCESS)*1000000.0})
  scene.phase_cost.clear()
  frames.append(now-previous);previous=now
  bodies.append(g.projectiles.size());floats_raw.append(scene.floats.size());pending_raw.append(scene.damage_pending.size())
  primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME));drawcalls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 scene.set_process(false);scene.track_frames=false
 var wall=Time.get_ticks_usec()-sample_start;var final=snapshot(scene);var seconds=final.game-baseline.game;var ratio=seconds/(wall/1000000.0)
 var row={"engine_render_times":render_rows,"runtime_config_start":startup_config,"mode":"cache_on_actual1x_default60fps_auto","retained":true,"frames_us_raw":frames,"projectiles_raw":bodies,"floats_raw":floats_raw,"pending_raw":pending_raw,"primitives_raw":primitives,"drawcalls_raw":drawcalls,"frame_trace":scene.observed_frames,"warm_steps":baseline.steps-begin.steps,"sample_steps":final.steps-baseline.steps,"warm_game_seconds":baseline.game-begin.game,"game_seconds":seconds,"warm_wall_seconds":warm_wall/1000000.0,"wall_seconds":wall/1000000.0,"game_wall_ratio":ratio,"logic_hz":(final.steps-baseline.steps)/(wall/1000000.0),"render_hz":frames.size()/(wall/1000000.0),"actual_1x_pass":absf(ratio-1.0)<0.035,"warm_fires":baseline.fires-begin.fires,"fires":final.fires-baseline.fires,"warm_hits":baseline.hits-begin.hits,"hits":final.hits-baseline.hits,"warm_purchases":baseline.purchases-begin.purchases,"purchases":final.purchases-baseline.purchases,"purchases_total":final.purchases-begin.purchases,"handoffs":final.handoffs-begin.handoffs}
 row.accessibility_enabled_end=is_accessibility_enabled()
 row.runtime_config_end=config(scene)
 row.phases=phase_rows
 FileAccess.open("res://.runtime/astra-final-"+OS.get_environment("PERF_SIDE")+".json",FileAccess.WRITE).store_string(JSON.stringify(row))
 root.get_texture().get_image().save_png("res://.runtime/astra-final-"+OS.get_environment("PERF_SIDE")+".png")
 print("PHASES_DONE ",row.render_hz)
 # GPU timestamp collection is diagnostic work, outside the clean sample.
 for viewport in [root,scene.ship_view.viewport]:
  RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
 row.engine_render_times_scope="post_sample_geometry_diagnostic"
 scene.verify_geometry=true
 scene.set_process(true)
 var observe_start=Time.get_ticks_msec();var next_capture=0
 while Time.get_ticks_msec()-observe_start<6000:
  await RenderingServer.frame_post_draw
  render_rows.append(render_times(scene))
  if Time.get_ticks_msec()-observe_start>=next_capture:
   root.get_texture().get_image().save_png("res://.runtime/clean-flight-%02d.png"%(next_capture/500))
   next_capture+=500
 scene.set_process(false)
 await finish(scene,stress,row,"cache-on-"+OS.get_environment("PERF_SIDE"))
