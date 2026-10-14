extends SceneTree
## Single uncapped QA-only full-wall-frame acceptance; four disjoint wall spans.
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
 var main_started_us:=0
 var main_finished_us:=0
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
  main_started_us=Time.get_ticks_usec()
  active_frame+=1
  super._process(delta)
  if track_frames:observed_frames.append({"logic_steps":logical_step_count(),"clock":game.production_time(),"delta":delta,"projectiles":game.projectiles.size(),"floats":floats.size(),"pending":damage_pending.size(),"unfocused":background_unfocused,"window_focused":get_tree().root.has_focus(),"engine_max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"fires":fire_count,"hits":hit_count,"purchases":levels()})
  main_finished_us=Time.get_ticks_usec()
 func levels()->int:
  var total=0
  for entry in game.loadout_entries("weapons")+game.loadout_entries("defence"):total+=int(entry.level)
  return total
var sample_events:Dictionary={}
func count_event(kind:String,_info:Dictionary)->void:
 sample_events[kind]=int(sample_events.get(kind,0))+1
func scalar_copy(value):
 if value is RandomNumberGenerator:return {"class":"RandomNumberGenerator","state":str(value.state),"seed":str(value.seed)}
 if value is Object:return {"class":value.get_class()}
 if value is Dictionary:
  var out:Dictionary={}
  for key in value:out[key]=scalar_copy(value[key])
  return out
 if value is Array:
  var out:Array=[]
  for item in value:out.append(scalar_copy(item))
  return out
 return value
func state_digest(g)->Dictionary:
 var kernel:Dictionary=g.native_execution.kernel.export_handoff() if g.native_execution!=null else {}
 # Export carries mutable display views and live RNG/lease objects. Keep typed
 # motion/queues/defence/attack state; replace redundant flight display views
 # with identity/target fields, and serialize actual RNG state instead of IDs.
 for flight in kernel.get("flights",[]):
  var view:Dictionary=flight.view
  flight.view={"serial":view.get("serial"),"target_uid":view.get("target",{}).get("uid",-1),"source_uid":view.get("source",{}).get("uid",-1),"primary_uid":view.get("primary_target",{}).get("uid",-1)}
 var canonical=scalar_copy(kernel)
 var enemies:Array=[]
 for e in g.enemies:enemies.append([e.get("uid"),e.get("hp"),e.get("shield"),e.get("x"),e.get("y")])
 return {"kernel_hash":JSON.stringify(canonical).sha256_text(),"kernel_rng":str(g.native_execution.kernel.rng_source().state) if g.native_execution!=null else "","game_rng":str(g.rng.state),"clock":g.production_time(),"player":g.player.duplicate(true),"enemies":enemies,"resources":g.profile.resources.duplicate(true),"loadout":g.profile.loadout.duplicate(true),"drops":g.drops.size(),"projectiles":g.projectiles.size(),"state":g.state,"stage":g.stage,"group":g.group_index,"canonical_kernel":canonical}
var pre_draw_us:=0
func _initialize()->void:
 RenderingServer.frame_pre_draw.connect(func():pre_draw_us=Time.get_ticks_usec())
 call_deferred("run")
func snapshot(scene)->Dictionary:
 return {"steps":scene.logical_step_count(),"game":scene.game.production_time(),"fires":scene.fire_count,"hits":scene.hit_count,"purchases":scene.levels(),"handoffs":scene.game.native_handoff_count}
func config(scene)->Dictionary:
 var g=scene.game
 return {"stat_cache_enabled":g.stat_cache_enabled,"save_enabled":g.save_enabled,"compiled_rules":g.compiled_combat_rules!=null,"independent_qualification_plan":("enhancement_plan" in g),"combat_presentation":g.combat_presentation!=null,"native_auto":g.native_execution_auto,"native_active":g.native_execution!=null,"retained":scene.retained_contacts_enabled,"speed":g.speed,"engine_max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"time_scale":Engine.time_scale,"fixed_logic_hz":60,"window":str(DisplayServer.window_get_size()),"accelerated_visual_mode":scene.accelerated_visual_mode,"pulse_fx":scene.pulse_vfx_enabled,"missile_fx":scene.missile_vfx_enabled,"enemy_fx":scene.enemy_vfx_enabled,"old_pipeline_class":ClassDB.class_exists("SpaceNativePipeline")}
func run()->void:
 Engine.max_fps=0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
 assert(Engine.max_fps==0 and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED and is_equal_approx(g.speed,1.0) and is_equal_approx(Engine.time_scale,1.0),"QA uncapped/VSync-off, actual speed 1, fixed logic unchanged")
 var startup_config=config(scene)
 print("CACHE_ON_START ",JSON.stringify(startup_config))
 g.event.connect(scene.watch)
 g.event.connect(count_event)
 var begin=snapshot(scene);var warm_start=Time.get_ticks_usec()
 scene.set_process(true)
 while scene.logical_step_count()-begin.steps<240:await RenderingServer.frame_post_draw
 scene.set_process(false)
 assert(Engine.max_fps==0 and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED,"Sampling requires uncapped and VSync off")
 var sampling_config=config(scene)
 var sampling_focus=root.has_focus()
 var state_before=state_digest(g)
 var beams_before:Dictionary=scene.retained_contacts.beam_layer.metrics() if "retained_gpu_beams_enabled" in scene else {}
 sample_events.clear()
 var sample_start_unix=Time.get_unix_time_from_system()
 var baseline=snapshot(scene);var sample_start=Time.get_ticks_usec();var warm_wall=sample_start-warm_start
 scene.track_frames=true;scene.set_process(true)
 var render_rows:Array=[]
 var phases:Array=[]
 var last_steps:int=baseline.steps
 var frames:Array=[];var bodies:Array=[];var floats_raw:Array=[];var pending_raw:Array=[];var primitives:Array=[];var drawcalls:Array=[];var previous=sample_start
 while scene.logical_step_count()-baseline.steps<480:
  await RenderingServer.frame_post_draw
  var now=Time.get_ticks_usec()
  var steps_now:int=scene.logical_step_count()
  phases.append({"previous_post_us":previous,"main_begin_us":scene.main_started_us,"main_end_us":scene.main_finished_us,"pre_draw_us":pre_draw_us,"post_draw_us":now,"logic_steps":steps_now-last_steps})
  last_steps=steps_now
  frames.append(now-previous);previous=now
  bodies.append(g.projectiles.size());floats_raw.append(scene.floats.size());pending_raw.append(scene.damage_pending.size())
  primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME));drawcalls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 scene.set_process(false);scene.track_frames=false
 var wall=Time.get_ticks_usec()-sample_start;var final=snapshot(scene);var seconds=final.game-baseline.game;var ratio=seconds/(wall/1000000.0)
 var row={"engine_render_times":render_rows,"runtime_config_start":startup_config,"mode":"uncapped_qa_actual1x_full_wall_frame_v1","phases":phases,"retained":true,"frames_us_raw":frames,"projectiles_raw":bodies,"floats_raw":floats_raw,"pending_raw":pending_raw,"primitives_raw":primitives,"drawcalls_raw":drawcalls,"frame_trace":scene.observed_frames,"warm_steps":baseline.steps-begin.steps,"sample_steps":final.steps-baseline.steps,"warm_game_seconds":baseline.game-begin.game,"game_seconds":seconds,"warm_wall_seconds":warm_wall/1000000.0,"wall_seconds":wall/1000000.0,"game_wall_ratio":ratio,"logic_hz":(final.steps-baseline.steps)/(wall/1000000.0),"render_hz":frames.size()/(wall/1000000.0),"actual_1x_pass":absf(ratio-1.0)<0.035,"warm_fires":baseline.fires-begin.fires,"fires":final.fires-baseline.fires,"warm_hits":baseline.hits-begin.hits,"hits":final.hits-baseline.hits,"warm_purchases":baseline.purchases-begin.purchases,"purchases":final.purchases-baseline.purchases,"purchases_total":final.purchases-begin.purchases,"handoffs":final.handoffs-begin.handoffs}
 row.sampling_config=sampling_config
 row.sampling_focus=sampling_focus
 row.performance_sample_valid=sampling_focus and scene.observed_frames.all(func(f):return f.window_focused and not f.unfocused and f.engine_max_fps==0 and f.vsync==DisplayServer.VSYNC_DISABLED)
 row.state_before=state_before
 row.state_after=state_digest(g)
 row.events=sample_events
 row.sample_start_unix=sample_start_unix
 row.sample_end_unix=Time.get_unix_time_from_system()
 row.gpu_beams_enabled=scene.retained_gpu_beams_enabled if "retained_gpu_beams_enabled" in scene else false
 row.beam_metrics_before=beams_before
 row.beam_metrics_after=scene.retained_contacts.beam_layer.metrics() if "retained_gpu_beams_enabled" in scene else {}
 row.runtime_config_end=config(scene)
 row.stress=stress.finish(g)
 row.window_focused=root.has_focus()
 row.background_unfocused=scene.background_unfocused
 row.rendering_method=RenderingServer.get_current_rendering_method()
 row.video_adapter=RenderingServer.get_video_adapter_name()
 row.rng_state=str(g.rng.state)
 row.kernel_metrics=g.native_execution.kernel.metrics()
 row.enemy_supported=[]
 for record in scene.retained_contacts.records.values():row.enemy_supported.append(record.supported)
 row.engine_version=Engine.get_version_info()
 row.accessibility_enabled=is_accessibility_enabled()
 FileAccess.open("res://.runtime/uncapped-port.json",FileAccess.WRITE).store_string(JSON.stringify(row))
 root.get_texture().get_image().save_png("res://.runtime/uncapped-port.png")
 print("PORT_PERF_DONE steps=",row.sample_steps," frames=",frames.size()," actual_1x=",row.actual_1x_pass," stress=",JSON.stringify(row.stress.counts))
 g.begin_retreat();scene.queue_free();await process_frame;await process_frame
 quit()
