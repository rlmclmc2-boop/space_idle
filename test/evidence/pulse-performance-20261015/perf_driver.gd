extends SceneTree
## Full GL postdraw wall-frame comparison. QA-only, no game event observer.
class UI extends "res://scripts/battlefield.gd":
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func create_battle_game(_persist:bool)->BattleGame:
  var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
  g.stat_cache_enabled=true;g.invalidate_stat_cache()
  db=g.db;g.native_execution_auto=false
  g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
  g.target_provider=_prototype_target_point;g.target_spatial_source=battle_read_model
  g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
  g.enable_compiled_combat_rules()
  return g

func _initialize()->void:call_deferred("run")

func steps(scene)->int:
 return scene.battle_slice_runtime.logical_steps if scene.battle_slice_runtime!=null else -1

func work(scene)->Dictionary:
 var g=scene.game;var session=g.native_execution
 var levels=0
 for entry in g.loadout_entries("weapons")+g.loadout_entries("defence"):levels+=int(entry.level)
 return {"game_clock":g.production_time(),"steps":steps(scene),"feedback_rows":session.feedback_rows,"qa_hot_batches":session.qa_hot_batches,"qa_hot_rows":session.qa_hot_rows,"qa_cold_batches":session.qa_cold_batches,"qa_cold_rows":session.qa_cold_rows,"kernel":session.kernel.metrics(),"rng":str(g.rng.state),"kernel_rng":str(session.kernel.rng_source().state),"player":g.player.duplicate(true),"resources":g.profile.resources.duplicate(true),"levels":levels,"loadout":g.profile.loadout.duplicate(true),"drops":g.drops.size(),"enemies_alive":g.enemies.filter(func(e):return GrowthNumber.compare(e.hp,0)>0).size(),"history_size":scene.damage_history.size(),"floats":scene.floats.size(),"pending":scene.damage_pending.size(),"compact_membership":session.kernel.presentation_membership().compact_laser_serials.size(),"native_owned":session.pulse_feedback_owned,"native_handoffs":g.native_handoff_count,"accelerated":scene.accelerated_visual_mode}

func run()->void:
 assert(ClassDB.class_exists("SpaceCombatPresentation") and ClassDB.class_exists("SpaceCombatKernel"))
 assert(GDExtensionManager.get_extension("res://space_native.gdextension").is_library_open())
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1701
 var case_name=OS.get_environment("PULSE_PERF_CASE")
 assert(case_name in ["laser","mixed"])
 g.profile.onboarding.completed=true;scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.selectedShip="Heavy_Battleship"
 g.profile.resources={"1":1e80,"2":1e80};g.profile.loadout={"weapons":[],"defence":[]}
 for key in ["laser","laser","laser","laser","laser","laser","laser","laser"]:g.profile.loadout.weapons.append({"key":key,"level":150})
 for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":150})
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
 var template=g.enemies[0].duplicate(true);g.enemies.clear()
 for i in 15:
  var e=template.duplicate(true);e.uid=100+i;e.slot=i;e.x=80+80*(i%5);e.y=150+80*(i/5);e.hp=1e100;e.max_hp=1e100
  g.enemies.append(e)
 var stress=preload("res://combat_stress_fixture.gd").new()
 assert(stress.configure(g,1 if case_name=="laser" else 2))
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
 assert(g.assign_crew("navigator","equipment_upgrade","equipment"))
 g.native_execution_auto=true
 var admission=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_rich15_layer2")
 assert(g.admit_native_compiled_execution("native_rich15_layer2"),JSON.stringify(admission.get("error","")))
 assert(scene.attach_native_display())
 scene.retained_contacts_enabled=true
 if g.event.is_connected(Callable(stress,"on_event")):g.event.disconnect(Callable(stress,"on_event"))
 await process_frame
 if DisplayServer.has_method("window_move_to_foreground"):DisplayServer.window_move_to_foreground()
 if root.has_method("grab_focus"):root.grab_focus()
 if OS.get_environment("PULSE_PERF_FOCUS_ONLY")=="1":
  var focus_samples=[]
  for i in 30:
   await RenderingServer.frame_post_draw
   focus_samples.append(root.has_focus())
  FileAccess.open("res://.runtime/focus.json",FileAccess.WRITE).store_string(JSON.stringify({"focus_samples":focus_samples,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"window":DisplayServer.window_get_size()}))
  g.begin_retreat();scene.queue_free();await process_frame;quit();return
 assert(g.native_execution.reviewed_pulse_listeners(g),"production listeners only; QA observer detached")
 assert(g.combat_presentation.supports_compact_lasers(scene))
 assert(Engine.max_fps==0 and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED)
 assert(is_equal_approx(g.speed,1.0) and is_equal_approx(Engine.time_scale,1.0))
 var initial=work(scene)
 scene.set_process(true)
 while steps(scene)-int(initial.steps)<240:await RenderingServer.frame_post_draw
 scene.set_process(false)
 var before=work(scene)
 var focus_start=root.has_focus()
 var last=Time.get_ticks_usec();var last_steps=steps(scene)
 var frames_us=[];var frame_steps=[];var valid=[]
 scene.set_process(true)
 while steps(scene)-int(before.steps)<480:
  await RenderingServer.frame_post_draw
  var now=Time.get_ticks_usec();var next_steps=steps(scene)
  frames_us.append(now-last);last=now
  frame_steps.append(next_steps-last_steps);last_steps=next_steps
  valid.append(root.has_focus() and not scene.background_unfocused and Engine.max_fps==0 and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED and is_equal_approx(g.speed,1.0) and is_equal_approx(Engine.time_scale,1.0))
 scene.set_process(false)
 var after=work(scene)
 var result={"run":OS.get_environment("PULSE_PERF_RUN"),"case":case_name,"gate":preload("res://scripts/native_execution_session.gd").PULSE_FEEDBACK_PROTOTYPE,"method":"GL full postdraw wall frame; 240 warm logical steps, 480 sample logical steps, actual 1x","engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"window":DisplayServer.window_get_size(),"focus_start":focus_start,"valid_frames":valid.count(true),"frames_us":frames_us,"frame_steps":frame_steps,"initial":initial,"before":before,"after":after,"loadout_manifest":stress.manifest,"listener_compatibility":g.native_execution.pulse_feedback_compatibility,"native_active":g.native_execution!=null}
 if OS.get_environment("PULSE_PERF_SCREENSHOT")=="1":
  await RenderingServer.frame_post_draw
  result.screenshot_ok=root.get_texture().get_image().save_png("res://.runtime/full-frame.png")==OK
 FileAccess.open("res://.runtime/perf.json",FileAccess.WRITE).store_string(JSON.stringify(result))
 print("PULSE_PERF ",JSON.stringify({"run":result.run,"case":case_name,"gate":result.gate,"valid":result.valid_frames,"frames":frames_us.size(),"sample_steps":int(after.steps)-int(before.steps),"hot":int(after.qa_hot_batches)-int(before.qa_hot_batches),"cold":int(after.qa_cold_batches)-int(before.qa_cold_batches)}))
 g.begin_retreat();scene.queue_free();await process_frame;quit()
