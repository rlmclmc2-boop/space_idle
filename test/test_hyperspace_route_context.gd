extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.gui_embed_subwindows=true
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.load_hyperspace_routes();g.profile.hyperspace.history.alpha={"1":90.0}
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.route="alpha";p.select_section(0);p.route_ui.show_crew()
 check(p.route_ui.crew_dialog.title==p.t("crew_route_title",{"route":p.t("alpha")}) and p.route_ui.crew_enable.text==p.t("crew_route_start",{"route":p.t("alpha")}),"Existing crew dialog and commit button explicitly name Alpha target")
 p.route_ui.crew_dialog.hide()
 check(g.set_hyperspace_auto("alpha","navigator",true) and g.hyperspace.start_auto(g),"Actual domain starts Alpha continuous crew exploration")
 g.paused=false;g.hyperspace.advance(g,3.0);g.paused=true
 var before=JSON.stringify(g.profile);var rng=g.rng.state;p.route_ui.refresh()
 check(not p.route_ui.queue_info.visible and not p.route_ui.queue_action.visible and p.route_ui.stop_button.visible and not p.route_ui.stop_button.disabled,"Own running route uses one real stop entry and hides duplicate conflict banner/action")
 check(p.route_ui.background_status.visible and p.route_ui.progress.visible and p.route_ui.progress.value>0,"Own route retains actual running task and progress")
 check(p.route_ui.challenge_button.disabled and not p.route_ui.challenge_button.tooltip_text.contains("占用"),"Single queue still blocks another operation with current-route context")
 p.route="beta";p.route_ui.refresh()
 check(p.route_ui.queue_info.visible and p.route_ui.queue_info.text.contains(p.t("alpha")) and p.route_ui.queue_action.visible and not p.route_ui.stop_button.visible,"Other route retains clear Alpha occupancy and existing task action")
 p.route_ui.show_crew()
 check(p.route_ui.crew_dialog.title.contains(p.t("beta")) and p.route_ui.crew_enable.text.contains(p.t("beta")),"Reused crew dialog updates target when route changes")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng,"Context rendering and dialog reopening do not alter queue, crew, task work or RNG")
 scene.queue_free();await process_frame
 print("Hyperspace route context: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
