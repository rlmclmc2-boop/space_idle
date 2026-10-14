extends SceneTree
class UI extends "res://scripts/battlefield.gd":
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func create_battle_game(_persist:bool)->BattleGame:
  var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
  g.stat_cache_enabled=true;g.invalidate_stat_cache()
  db=g.db;g.native_execution_auto=false
  g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
  g.target_provider=_prototype_target_point;g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
  g.enable_compiled_combat_rules()
  return g
var checks:=0
var failures:=0
var rows:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func capture(scene,label:String)->void:
 scene.stars_layer.queue_redraw();scene.battle_layer.queue_redraw();scene.pulse_layer.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.runtime/return-"+label+".png")
 rows.append({"label":label,"blocked":scene.battle_transition_blocked(),"transition":scene.encounter_presentation.transition,"scenery":scene.encounter_presentation.scenery_presence,"ship_visible":scene.ship_view.visible,"ship_update_mode":scene.ship_view.viewport.render_target_update_mode,"enemy_count":scene.game.enemies.size(),"game_time":scene.game.production_time(),"distance":scene.game.distance,"paused":scene.game.paused})
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 DirAccess.make_dir_recursive_absolute("res://.runtime")
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI);scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
 var g=scene.game;g.save_enabled=false;g.profile.cleared=range(1,41);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true;scene.beginner_guide.hide()
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}];g.invalidate_stat_cache()
 check(g.start(1,false),"mainline started")
 g.distance=float(g.db.levels[0].groups[0].position)*float(g.db.levels[0].length)-0.1
 check(g.load_hyperspace_routes(),"production routes loaded")
 check(g.start_hyperspace("alpha",g.hyperspace.current_layer(g,"alpha")+1),"real manual session started")
 if not g.manual_hyperspace.active:quit(1);return
 scene._process(0.0)
 for i in 20:scene.encounter_presentation.sync(g,0.1)
 check(g.exit_hyperspace_challenge(),"normal manual exit restores saved mainline")
 check(scene.battle_transition_blocked(),"departure owns a finite presentation gate")
 var clock=g.production_time();var distance=g.distance;var rng=g.rng.state
 await capture(scene,"start")
 for i in 8:scene._process(0.1)
 check(g.production_time()==clock and g.distance==distance and g.rng.state==rng and g.enemies.is_empty(),"restored main battle does not advance or spawn during exit")
 check(not scene.ship_view.visible and scene.ship_view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not scene.retained_contacts.visible and not scene.pulse_layer.visible,"actual scene owners hidden and viewport stopped")
 await capture(scene,"middle")
 var steps=0
 while scene.battle_transition_blocked() and steps<30:scene._process(0.1);steps+=1
 check(not scene.battle_transition_blocked() and g.production_time()==clock,"animation ends without consuming old battle time")
 g.native_execution_auto=true;scene._process(1.0/60.0)
 check(g.enemies.size()>0 and scene.ship_view.visible,"old encounter may spawn and render only after exit")
 check(g.native_execution!=null,"normal restored encounter can admit native execution")
 await capture(scene,"complete")
 # A paused mainline battle must restore without forcing an unpause or hanging the gate.
 g.paused=true
 var paused_actors=preload("res://scripts/hyperspace_battle_return.gd").capture(g)
 check(g.start_hyperspace("alpha",g.hyperspace.current_layer(g,"alpha")+1),"manual entry from paused native main battle")
 scene._process(0.0)
 check(g.exit_hyperspace_challenge(),"manual exit restores paused main battle")
 check(g.paused and not scene.battle_transition_blocked(),"paused return does not unpause or deadlock departure")
 check(preload("res://scripts/hyperspace_battle_return.gd").capture(g)==paused_actors,"restored actors and in-flight carriers retain their serialized state")
 var file=FileAccess.open("res://.runtime/return-check.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":rows},"\t"));file.close()
 if scene.battle_slice_runtime!=null:scene.battle_slice_runtime.close();scene.battle_slice_runtime=null
 scene.queue_free();await process_frame
 print("HYPERSPACE_DEPARTURE_GATE ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
