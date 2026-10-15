extends SceneTree
## Frozen mixed GL zero-step publication diagnosis; all gameplay and wall-time visuals remain active.
const QAPub=preload("res://qa_publication_cost.gd")
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
 return {"game_clock":g.production_time(),"steps":steps(scene),"feedback_rows":session.feedback_rows,"kernel":session.kernel.metrics(),"rng":str(g.rng.state),"kernel_rng":str(session.kernel.rng_source().state),"player":g.player.duplicate(true),"resources":g.profile.resources.duplicate(true),"levels":levels,"loadout":g.profile.loadout.duplicate(true),"drops":g.drops.size(),"enemies_alive":g.enemies.filter(func(e):return GrowthNumber.compare(e.hp,0)>0).size(),"history_size":scene.damage_history.size(),"floats":scene.floats.size(),"pending":scene.damage_pending.size(),"compact_membership":session.kernel.presentation_membership().compact_laser_serials.size(),"native_handoffs":g.native_handoff_count,"accelerated":scene.accelerated_visual_mode}

func run()->void:
 assert(ClassDB.class_exists("SpaceCombatPresentation") and ClassDB.class_exists("SpaceCombatKernel"))
 assert(GDExtensionManager.get_extension("res://space_native.gdextension").is_library_open())
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1701
 var case_name=OS.get_environment("PUBLICATION_CASE")
 assert(case_name=="mixed")
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
 assert(stress.configure(g,2))
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
 assert(Engine.max_fps==0 and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED)
 assert(is_equal_approx(g.speed,1.0) and is_equal_approx(Engine.time_scale,1.0))
 var initial=work(scene)
 scene.set_process(true)
 var warm_steps=120
 var sample_steps=240
 while steps(scene)-int(initial.steps)<warm_steps:await RenderingServer.frame_post_draw
 scene.set_process(false)
 var before=work(scene)
 QAPub.reset();QAPub.enabled=OS.get_environment("PUBLICATION_TIMER")=="on"
 var focus_start=root.has_focus()
 var last=Time.get_ticks_usec();var last_steps=steps(scene)
 var frames_us=[];var frame_steps=[];var valid=[];var qa_frames=[];var wall_state=[]
 scene.set_process(true)
 while steps(scene)-int(before.steps)<sample_steps:
  await RenderingServer.frame_post_draw
  var now=Time.get_ticks_usec();var next_steps=steps(scene)
  frames_us.append(now-last);last=now
  frame_steps.append(next_steps-last_steps);last_steps=next_steps
  qa_frames.append(QAPub.take_frame())
  wall_state.append([scene.fx_time,scene.star_travel,scene.shake,scene.particles.size(),scene.floats.size(),scene.encounter_presentation.scenery_time])
  valid.append(root.has_focus() and not scene.background_unfocused and Engine.max_fps==0 and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED and is_equal_approx(g.speed,1.0) and is_equal_approx(Engine.time_scale,1.0))
 scene.set_process(false)
 QAPub.enabled=false
 var after=work(scene)
 var result={"run":OS.get_environment("PUBLICATION_RUN"),"case":case_name,"timer":OS.get_environment("PUBLICATION_TIMER"),"method":"Frozen mixed fixture, GL postdraw full-frame; 120 warm / 240 sampled logical steps at actual 1x; QA wrappers always present","warm_target":warm_steps,"sample_target":sample_steps,"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"window":DisplayServer.window_get_size(),"focus_start":focus_start,"valid_frames":valid.count(true),"frames_us":frames_us,"frame_steps":frame_steps,"qa_frames":qa_frames,"wall_state":wall_state,"initial":initial,"before":before,"after":after,"loadout_manifest":stress.manifest,"native_active":g.native_execution!=null}
 FileAccess.open("res://.runtime/perf.json",FileAccess.WRITE).store_string(JSON.stringify(result))
 print("PUBLICATION_COST ",JSON.stringify({"run":result.run,"timer":result.timer,"valid":result.valid_frames,"frames":frames_us.size(),"sample_steps":int(after.steps)-int(before.steps)}))
 g.begin_retreat();scene.queue_free();await process_frame;quit()
