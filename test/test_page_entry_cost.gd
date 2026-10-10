extends SceneTree
# Isolated graphical fixture: copy into runner-owned project with exact checkpoint.json.
# Use whole_game_perf.run_guarded and isolated userdata; never production saves.
# First-entry wall time includes preparation and final draw; real1x battle keeps running.
# Fullquality cap0/vsyncoff diagnostic; not natural-player or clean-throughput qualification.
class UI extends "res://scripts/battlefield.gd":
 var ticks=0
 var main_us=0
 var input_delta=0.0
 func _process(dt:float)->void:
  input_delta=dt
  var began=Time.get_ticks_usec();super._process(dt);main_us=Time.get_ticks_usec()-began
 func create_battle_game(_persist:bool)->BattleGame:
  var g=super.create_battle_game(false)
  g.stat_cache_enabled=true
  g.load_progress_data(JSON.parse_string(FileAccess.get_file_as_string("res://checkpoint.json")))
  g.save_enabled=false
  return g
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func before_logical_game_tick(dt:float)->void:ticks+=1;super.before_logical_game_tick(dt)
var failures=0
func _initialize():
 Engine.max_fps=0;OS.low_processor_usage_mode=false
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 DisplayServer.window_set_size(Vector2i(1373,883))
 call_deferred("run")
func run():
 var started=Time.get_ticks_usec()
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI);root.add_child(scene);current_scene=scene
 var ready_at=Time.get_ticks_usec();var g=scene.game
 g.profile.reactorAutomation.upgrade=false
 for item in g.profile.crew:
  if str(item.assignmentType)=="equipment_upgrade":g.crew.assign(g,str(item.crewId),"","")
 await process_frame;await RenderingServer.frame_post_draw
 var first_display=Time.get_ticks_usec()-started
 g.profile.highestLevel=20;scene.refresh_tab_visibility()
 var requested=Time.get_ticks_usec();var before_ticks=scene.ticks;var before_game=g.motion_clock
 var inventory=g.profile.hyperspace.inventory.duplicate(true)
 scene.select_system(9)
 var call_us=Time.get_ticks_usec()-requested
 var frames=[]
 while true:
  var frame_start=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw
  frames.append(Time.get_ticks_usec()-frame_start)
  if scene.equipment_tabs.current_tab==9:break
  if Time.get_ticks_usec()-requested>5000000:failures+=1;break
 var first_entry=Time.get_ticks_usec()-requested
 var ticks=scene.ticks-before_ticks;var game_elapsed=g.motion_clock-before_game
 var p=scene.hyperspace_panel
 if scene.equipment_tabs.current_tab!=9 or p.sections.size()!=4 or p.cards.size()!=8:failures+=1
 if inventory!=g.profile.hyperspace.inventory:failures+=1
 if scene.equipment_tabs.get_tab_idx_from_control(scene.save_panel)!=10:failures+=1
 scene.select_system(0);await process_frame;await RenderingServer.frame_post_draw
 var repeat_start=Time.get_ticks_usec();await scene.select_system(9)
 var repeat_call=Time.get_ticks_usec()-repeat_start
 await process_frame;await RenderingServer.frame_post_draw
 var repeat_display=Time.get_ticks_usec()-repeat_start
 print("PAGE_ENTRY_COST ",JSON.stringify({"failures":failures,"startup_to_ready_us":ready_at-started,"startup_to_first_display_us":first_display,"first_entry_us":first_entry,"first_entry_frame_us":frames,"first_entry_call_us":call_us,"repeat_call_us":repeat_call,"repeat_display_us":repeat_display,"battle_ticks_during_firstentry":ticks,"game_seconds_during_firstentry":game_elapsed,"scope":"exactQA runtime,no saves; unpaused1x fullquality; initial startup and first display included; UI fixture unlock only; not natural-player throughput"}))
 scene.queue_free();await process_frame;await process_frame
 quit(1 if failures else 0)
