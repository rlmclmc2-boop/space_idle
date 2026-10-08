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
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;var f=p.reward_feedback
 f.latest={"drone":{},"materials":{"glueball":10},"ultimate_cores":0};f.show_receipt()
 var reward_before=f.summary.text;var profile_before=JSON.stringify(g.profile)
 g.manual_hyperspace.last_result={"route":"beta","level":2,"reason":"defeat"};p.route_ui.refresh()
 check(p.challenge_result_area.visible and p.recent_result.text.contains("第 2 层") and p.recent_result.text.contains("战舰战败"),"Failed next-layer challenge has fixed independent result")
 check(f.card.visible and f.summary.text==reward_before,"Earlier reward receipt remains separate from failure")
 f.latest={"drone":{},"materials":{"glueball":20},"ultimate_cores":0};f.show_receipt();p.route_ui.refresh()
 check(p.recent_result.text.contains("战舰战败") and f.summary.text!=reward_before,"New background receipts do not replace challenge result")
 p.route="alpha";p.route_ui.refresh()
 check(p.recent_result.text.contains(p.t("beta")),"Changing current route preserves the actual challenged route")
 p.select_section(1);check(not p.challenge_result_area.visible,"Inventory page hides exploration result region")
 p.select_section(0);check(p.challenge_result_area.visible and p.recent_result.text.contains("战舰战败"),"Returning to exploration retains failure")
 for reason in ["success","user_exit","setup_failed","formation_invalid"]:
  g.manual_hyperspace.last_result.reason=reason;p.route_ui.refresh()
  check(not p.recent_result.text.contains("战舰战败") and not p.recent_result.text.contains("{"),reason+" uses its own resolved result")
 check(JSON.stringify(g.profile)==profile_before,"Reading results does not alter progress or receipt state")
 g.manual_hyperspace.last_result={};p.route_ui.refresh();check(not p.challenge_result_area.visible,"A new session invents no challenge history")
 print("Recent challenge: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
