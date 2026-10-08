extends SceneTree
var checks=0
var failures=0
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear()
 g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.load_hyperspace_routes();g.profile.hyperspace.history={"alpha":{"1":12.0},"beta":{"1":12.0},"gamma":{"1":12.0},"delta":{"1":12.0}}
 g.start(8,false);g.spawn_group();scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;var u=p.route_ui;var h=g.hyperspace
 check(g.start_hyperspace_idle("alpha"),"Existing domain starts owning background task")
 h.advance(g,3.0);p.route="beta";u.refresh()
 check(u.queue_info.visible and u.queue_info.text.contains(p.t("alpha")) and u.queue_info.text.contains(p.t("layer_queue_background")),"Other route shows exact shared owner and task")
 check(u.idle_button.disabled and u.challenge_button.disabled and u.reason("queue_busy").contains(p.t("alpha")),"Disabled actions use authoritative queue reason")
 var run_id=g.profile.hyperspace.idle.run_id;u.queue_action.pressed.emit()
 check(g.profile.hyperspace.idle.is_empty() and g.profile.hyperspace.paused[0].run_id==run_id and g.profile.hyperspace.paused[0].work==3.0,"Explicit stop pauses owning route without discarding progress")
 p.route="alpha";u.refresh()
 check(u.paused_info.visible and u.paused_info.text.contains("9.0") and u.idle_button.text==p.t("layer_resume"),"Paused route exposes actual remaining work and resume action")
 u.idle_button.pressed.emit()
 check(g.profile.hyperspace.idle.run_id==run_id and g.profile.hyperspace.idle.work==3.0,"Resume button uses existing domain continuation")
 g.profile.hyperspace.idle.work=g.profile.hyperspace.idle.duration
 check(h.complete(g,int(g.profile.hyperspace.idle.round_id),int(run_id),true),"Domain creates pending reward receipt")
 p.route="beta";u.refresh();var before=JSON.stringify(g.profile);u.queue_action.pressed.emit()
 check(p.route=="alpha" and u.claim_background_button.visible and JSON.stringify(g.profile)==before,"Pending action navigates to exact claim without silently claiming or cancelling")
 print("Queue UI: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
