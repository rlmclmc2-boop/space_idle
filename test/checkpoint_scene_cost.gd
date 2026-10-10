extends SceneTree
# Bounded attribution on the named natural QA checkpoint copy, never a player save.
# Copy this script to the isolated project; checkpoint20.json comes from the authorized Git QA checkpoint.
# Validate the exact source encounter before any explicitly synthetic wave setup.
class UI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var g=super.create_battle_game(false)
  g.stat_cache_enabled=true
  var raw=JSON.parse_string(FileAccess.get_file_as_string(Engine.get_meta("checkpoint_path","res://checkpoint20.json")))
  g.rng.seed=1701
  g.load_progress_data(raw)
  g.save_enabled=false
  return g
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 var logical_ticks:=0
 func before_logical_game_tick(dt:float)->void:
  logical_ticks+=1;super.before_logical_game_tick(dt)
 var last_process_us=0
 func _process(dt:float)->void:
  var began=Time.get_ticks_usec();super._process(dt);last_process_us=Time.get_ticks_usec()-began
class Meter extends RefCounted:
 var enabled=false;var times={};var draw_us=0
 func record(key,us):
  if not enabled:return
  if not times.has(key):times[key]=[0,0,0]
  times[key][0]+=1;times[key][1]+=us;times[key][2]=max(times[key][2],us)
  if key=="main.draw_battle":draw_us+=us
var meter=Meter.new()
func _initialize():Engine.set_meta("saved_perf",meter);call_deferred("run")
func stats(a):
 a=a.duplicate();a.sort();var total=0.0
 for v in a:total+=v
 return {"mean":total/a.size(),"p50":a[a.size()/2],"p95":a[int(a.size()*.95)],"p99":a[int(a.size()*.99)],"max":a[-1]}
func views(node,rows):
 if node is SubViewport:rows.append({"path":str(node.get_path()),"size":str(node.size),"mode":node.render_target_update_mode,"scale_3d":node.scaling_3d_scale,"msaa_3d":node.msaa_3d,"calls":node.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":node.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)})
 for child in node.get_children():views(child,rows)
func fail(reason):printerr("CHECKPOINT_FAILURE ",reason);Engine.remove_meta("saved_perf");quit(2)
func inject_test_missile_burst(g,count):
 # One explicitly synthetic transient. Use the actual equipped missile and
 # its production firing path, payload, speed, target references and visuals.
 for mount in g.weapon_entries().size():
  var entry:Dictionary=g.weapon_entries()[mount]
  if entry.key!="missile":continue
  for i in count:
   g.jewel_fire(mount,g.enemies[i%g.enemies.size()],g.db.equip(entry.key,int(entry.level)),g.player_weapon_offset(mount),1.0,g.missile_visual_spread(i%3,3))
  return true
 return false
func run():
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var save_path = str(Engine.get_meta("checkpoint_path","res://checkpoint20.json"))
 var save_hash=FileAccess.get_sha256(save_path)
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI);scene.automation_args=[];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 var g=scene.game
 if not g.startup_error.is_empty() or g.stage!=int(Engine.get_meta("checkpoint_stage",20)) or g.group_index!=int(Engine.get_meta("checkpoint_group",1)) or str(g.profile.selectedShip)!=str(Engine.get_meta("checkpoint_ship","Destroyer")) or not g.stat_cache_enabled:
  fail({"startup":g.startup_error,"stage":g.stage,"group":g.group_index,"ship":g.profile.get("selectedShip"),"cache":g.stat_cache_enabled});return
 if OS.get_environment("PERF_SUSTAIN_TEST_HEALTH")=="1":
  var selected_wave=int(OS.get_environment("PERF_CHECKPOINT_WAVE"))
  if selected_wave>0:
   if selected_wave>g.db.levels[g.stage-1].groups.size():fail("selected wave outside authored stage");return
   g.group_index=selected_wave-1
   g.spawn_group()
  # Apply only after the final scene-owned fleet exists. Do not alter weapon
  # parameters, launch cadence, paths, RNG, source save, or production tables.
  for enemy in g.enemies:enemy.hp=1e100;enemy.max_hp=1e100
  g.player.armour=1e100
 print("ENV ",JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method(),"resolution":str(root.size),"display":DisplayServer.get_name(),"cap":Engine.max_fps}))
 print("CHECKPOINT_INIT ",JSON.stringify({"synthetic_test_health":OS.get_environment("PERF_SUSTAIN_TEST_HEALTH")=="1","save_sha256":save_hash,"combat_seed":1701,"stage":g.stage,"group":g.group_index,"state":g.state,"loop":g.profile.loop,"speed":g.speed,"resources":g.profile.resources,"ship":g.profile.selectedShip,"inventory_count":g.profile.hyperspace.inventory.drones.size(),"equipped_count":g.profile.hyperspace.inventory.equipped.size(),"loaded_chrono_login":g.login_chrono_particles,"save_enabled":g.save_enabled,"stat_cache_enabled":g.stat_cache_enabled,"flat_enabled":scene.ship_view.flat_compositor.enabled}))
 if OS.get_environment("PERF_QA_TRANSITIONS")=="1":await observe_transitions(scene,g,save_hash)
 else:await measure(scene,g,save_hash)
 print("CHECKPOINT_END ",JSON.stringify({"source_save_unchanged":FileAccess.get_sha256(str(Engine.get_meta("checkpoint_path","res://checkpoint20.json")))==save_hash}))
 scene.queue_free();await process_frame;Engine.remove_meta("saved_perf");quit()
func measure(scene,g,save_hash):
 var frame_trace=[];var entry_trace=[];var alive=[];var frames=[];var cpu=[];var drawing=[];var calls=[];var primitives=[];var stages=[];var groups=[];var states=[];var enemies=[];var projectiles=[]
 await process_frame;await RenderingServer.frame_post_draw
 var sample_frames = clampi(int(OS.get_environment("PERF_FRAMES")),1,600) if OS.has_environment("PERF_FRAMES") else 30
 var warmup_frames = clampi(int(OS.get_environment("PERF_WARMUP_FRAMES")),1,600) if OS.has_environment("PERF_WARMUP_FRAMES") else 15
 print("MEASUREMENT_BEGIN ",JSON.stringify({"warmup_frames":warmup_frames,"sample_frames":sample_frames,"step_seconds":1.0/60.0}))
 for i in warmup_frames+sample_frames:
  if g.stage>20:fail("measurement crossedstage20");return
  if i==warmup_frames:
   var burst=int(OS.get_environment("PERF_TEST_MISSILE_BURST"))
   if burst>0 and not inject_test_missile_burst(g,burst):fail("QA has no missile mount");return
   meter.enabled=true;meter.times.clear()
   print("MEASUREMENT_SAMPLES_BEGIN ",JSON.stringify({"sample_frames":sample_frames}))
  meter.draw_us=0
  var began=Time.get_ticks_usec();scene._process(1.0/60.0)
  await process_frame;await RenderingServer.frame_post_draw
  if i<warmup_frames:
   var living=0
   for enemy in g.enemies:
    if float(enemy.get("hp",0))>0:living+=1
   entry_trace.append([i,Time.get_ticks_usec()-began,scene.last_process_us,living,g.projectiles.size()])
  if i>=warmup_frames:
   frames.append(Time.get_ticks_usec()-began);cpu.append(scene.last_process_us);drawing.append(meter.draw_us)
   calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
   var living=0
   for enemy in g.enemies:
    if float(enemy.get("hp",0))>0:living+=1
   alive.append(living)
   frame_trace.append([i,frames[-1],cpu[-1],living,g.projectiles.size()])
   stages.append(g.stage);groups.append(g.group_index);states.append(g.state);enemies.append(g.enemies.size());projectiles.append(g.projectiles.size())
 meter.enabled=false
 print("ENTRY_ROW ",JSON.stringify({"entry_trace":entry_trace,"synthetic_test_health":OS.get_environment("PERF_SUSTAIN_TEST_HEALTH")=="1","selected_authored_wave":int(OS.get_environment("PERF_CHECKPOINT_WAVE"))}))
 var inventory=[];views(root,inventory)
 print("ROW ",JSON.stringify({"frame_trace":frame_trace,"alive":alive,"rng_state":str(g.rng.state),"combat_sha256":JSON.stringify({"enemies":g.enemies,"projectiles":g.projectiles,"player":g.player,"rng":str(g.rng.state)}).sha256_text(),"frames_us":stats(frames),"host_process_us":stats(cpu),"battle_draw_us":stats(drawing) if meter.times.has("main.draw_battle") else null,"draw_command_instrumented":meter.times.has("main.draw_battle"),"timings":meter.times,"calls":stats(calls),"primitives":stats(primitives),"stages":stages,"groups":groups,"states":states,"enemies":enemies,"projectiles":projectiles,"views":inventory,"source_save_unchanged":FileAccess.get_sha256(str(Engine.get_meta("checkpoint_path","res://checkpoint20.json")))==save_hash,"warmup_frames":warmup_frames,"sample_frames":sample_frames,"logical_elapsed_seconds":float(warmup_frames+sample_frames)/60.0,"save_enabled":g.save_enabled,"ship_body_records":scene.ship_view.body_baker.records.size(),"flat_enabled":scene.ship_view.flat_compositor.enabled}))
 root.get_texture().get_image().save_png("res://.runtime/checkpoint20-scene.png")

func transition_snapshot(scene,g,at: int,phase: String)->Dictionary:
 var stale:=0;var contacts=scene.get("retained_contacts")
 if is_instance_valid(contacts):
  for record in contacts.records.values():
   if record.root.is_visible_in_tree() and not g.enemies.any(func(enemy):return int(enemy.uid)==int(record.entity.uid)):stale+=1
 return {"us":at,"phase":phase,"memory":OS.get_static_memory_usage(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"nodes":get_node_count(),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"projectiles":g.projectiles.size(),"queue":g.missile_queue.size(),"visuals":scene.projectile_visuals.size(),"state":g.state,"stage":g.stage,"group":g.group_index,"paused":g.paused,"battle_visible":scene.battle_layer.is_visible_in_tree(),"stale_visible_contacts":stale}

func observe_transitions(scene,g,save_hash):
 # Existing authorized QA scene, real production accumulator. No fixture,
 # artificial health, burst, loadout substitution, purchase or direct tick.
 var max_seconds:=clampf(float(OS.get_environment("PERF_QA_SECONDS")),35.0,180.0)
 var original_reactor_auto: bool=g.profile.reactorAutomation.upgrade
 g.profile.reactorAutomation.upgrade=false
 g.speed=1.0
 var initial_loadout: Dictionary=g.profile.loadout.duplicate(true)
 var frames=[];var cpu=[];var trace=[];var times=[];var launch=[];var snapshots=[];var events=[]
 var phase:="natural";var natural_end={};var exit_at:=-1;var reenter_at:=-1;var restart_ok:=false
 var started:=Time.get_ticks_usec();var ticks_start: int=scene.logical_ticks;var game_start: float=g.motion_clock
 var last_state: int=g.state;var last_stage: int=g.stage;var last_group: int=g.group_index
 var next_snapshot:=0
 var observed={"player":0,"enemy":0}
 g.event.connect(func(kind,info):
  if kind=="fire":
   if bool(info.get("shot",{}).get("hostile",false)):observed.enemy+=1
   else:observed.player+=1
  elif kind in ["state","wave_clear","level_clear","battle_blocked","unlocks_changed","planet_changed","reactor_changed","hightech_changed"]:
   events.append({"us":Time.get_ticks_usec()-started,"kind":kind,"state":g.state,"stage":g.stage,"group":g.group_index}))
 print("QA_TRANSITION_BEGIN ",JSON.stringify({"max_seconds":max_seconds,"speed":g.speed,"source_sha256":save_hash,"initial_loadout":initial_loadout,"reactor_auto_upgrade_source":original_reactor_auto,"reactor_auto_upgrade_runtime":false,"stage":g.stage,"group":g.group_index,"state":g.state,"save_enabled":g.save_enabled,"noncombat_omitted":false}))
 scene.set_process(true)
 var wall_end:=started
 while float(wall_end-started)/1000000.0<max_seconds:
  observed.player=0;observed.enemy=0
  var began:=Time.get_ticks_usec()
  await process_frame;await RenderingServer.frame_post_draw
  wall_end=Time.get_ticks_usec();var at:=wall_end-started
  var frame_us:=wall_end-began
  frames.append(frame_us);cpu.append(scene.last_process_us);times.append(at)
  var living:=0
  for enemy in g.enemies:
   if _enemy_alive(enemy):living+=1
  trace.append([at,frame_us,scene.last_process_us,g.state,g.stage,g.group_index,living,g.projectiles.size(),g.missile_queue.size(),g.paused,phase,scene.logical_ticks-ticks_start])
  launch.append([at,observed.player,observed.enemy])
  if at>=next_snapshot:
   var snapshot=transition_snapshot(scene,g,at,phase)
   snapshots.append(snapshot);next_snapshot+=10000000
   print("QA_TRANSITION_SNAPSHOT ",JSON.stringify(snapshot))
   events.append({"us":at,"kind":"observer_snapshot_log"})
  if g.state!=last_state or g.stage!=last_stage or g.group_index!=last_group:
   var snapshot=transition_snapshot(scene,g,at,"state_transition")
   snapshots.append(snapshot)
   print("QA_TRANSITION_STATE ",JSON.stringify(snapshot))
   last_state=g.state;last_stage=g.stage;last_group=g.group_index
  if phase=="natural" and natural_end.is_empty() and g.state in [g.State.LEVEL_CLEAR,g.State.RETREAT,g.State.DEFEAT,g.State.LEVEL_SELECT]:
   natural_end={"us":at,"state":g.state,"stage":g.stage,"victory":g.state==g.State.LEVEL_CLEAR and g.profile.cleared.has(20)}
  var natural_wait_done:=not natural_end.is_empty() and at-int(natural_end.us)>=2000000
  var bounded_wait_done:=at>=mini(120000000,int((max_seconds-35.0)*1000000.0))
  if phase=="natural" and (natural_wait_done or bounded_wait_done):
   phase="exit";exit_at=at
   events.append({"us":at,"kind":"observer_manual_exit","natural_end_seen":not natural_end.is_empty(),"state":g.state,"stage":g.stage})
   print("QA_TRANSITION_EXIT ",JSON.stringify(events[-1]))
   g.leave(g.State.LEVEL_SELECT)
  elif phase=="exit" and at-exit_at>=2000000:
   phase="reenter";reenter_at=at
   restart_ok=g.start(20,false)
   events.append({"us":at,"kind":"observer_manual_reenter","ok":restart_ok,"stage":g.stage,"group":g.group_index})
   print("QA_TRANSITION_REENTER ",JSON.stringify(events[-1]))
  elif phase=="reenter" and at-reenter_at>=30000000:break
 scene.set_process(false)
 snapshots.append(transition_snapshot(scene,g,wall_end-started,"end"))
 var clock={"wall_seconds":float(wall_end-started)/1000000.0,"game_seconds":g.motion_clock-game_start,"logical_ticks":scene.logical_ticks-ticks_start,"logic_hz":float(scene.logical_ticks-ticks_start)*1000000.0/float(wall_end-started),"mode":"normal1x full-system QA including legitimate menu/retreat/pause phases; phase tick rate reported separately","valid":g.speed==1.0}
 var inventory=[];views(root,inventory)
 print("ROW ",JSON.stringify({"qa_transition_observation":true,"frame_trace":trace,"sample_time_us":times,"launch_trace":launch,"frames_us":stats(frames),"main_us":stats(cpu),"clock_validation":clock,"snapshots":snapshots,"events":events,"natural_end":natural_end,"manual_exit_us":exit_at,"manual_reenter_us":reenter_at,"restart_ok":restart_ok,"initial_loadout":initial_loadout,"final_loadout":g.profile.loadout,"loadout_unchanged":g.profile.loadout==initial_loadout,"reactor_auto_upgrade_source":original_reactor_auto,"reactor_auto_upgrade_runtime":false,"source_save_unchanged":FileAccess.get_sha256(str(Engine.get_meta("checkpoint_path","res://checkpoint20.json")))==save_hash,"save_enabled":g.save_enabled,"flat_enabled":scene.ship_view.flat_compositor.enabled,"views":inventory,"screenshot_scope":"after observation only; excluded from frame samples"}))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.runtime/checkpoint20-transition-end.png")

func _enemy_alive(enemy: Dictionary)->bool:
 return preload("res://scripts/growth_number.gd").compare(enemy.get("hp",0),0)>0
