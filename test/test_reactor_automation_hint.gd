extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func capture(label:String) -> void:
 var directory:=OS.get_environment("REACTOR_HINT_EVIDENCE")
 if directory.is_empty() or DisplayServer.get_name()=="headless":return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory.path_join(label+".png"))
func run() -> void:
 root.size=Vector2i(1178,814);root.gui_embed_subwindows=true
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.cleared=range(1,7);g.profile.highestLevel=7;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 scene.refresh_tab_visibility();scene.select_system(2)
 var ui=scene.reactor_panel.automation_ui;ui.refresh();await process_frame
 var profile_before=JSON.stringify(g.profile);var rng_before=g.rng.state
 check(not g.profile.crew.any(func(item):return g.crew.unlocked(g,str(item.crewId))),"Early-game fixture has no unlocked crew")
 check(ui.crew_hint.visible and ui.crew_hint.text==UIText.t("reactor.automation.no_dispatch"),"No dispatch shows short status")
 check(ui.crew_hint.get_parent()==ui.bar and ui.crew_hint.get_rect().end.y<=ui.bar.size.y and ui.crew_hint.get_rect().end.x<=ui.bar.size.x,"Status stays inside the first row without adding height")
 check(ui.bar.get_combined_minimum_size().x<=522 and ui.crew_hint.get_rect().position.x>=ui.allocate.get_rect().end.x,"Status and switches fit without overlap")
 check(ui.crew_hint.tooltip_text==UIText.t("reactor.automation.requires_crew") and ui.crew_hint.mouse_filter==Control.MOUSE_FILTER_PASS,"Complete condition remains available on hover")
 ui.refresh();check(JSON.stringify(g.profile)==profile_before and g.rng.state==rng_before,"Status refresh changes no profile or RNG")
 await capture("no-dispatch-1178")
 g.profile.cleared=range(1,41);g.profile.highestLevel=41;g.rebuild_unlocks();g.pending_unlocks.clear();scene.refresh_tab_visibility()
 check(g.crew.assign(g,"navigator","reactor_upgrade","reactor"),"Fixture dispatches an eligible crew member")
 var preference=g.profile.reactorAutomation.duplicate(true);ui.refresh();await process_frame
 check(not ui.crew_hint.visible and g.profile.reactorAutomation==preference,"Dispatch removes only the hint, retaining automatic preferences")
 await capture("dispatched-1178")
 check(g.crew.assign(g,"navigator","",""),"Fixture recalls crew")
 ui.refresh();await process_frame
 check(ui.crew_hint.visible and g.profile.reactorAutomation==preference,"Recall restores the hint without changing automatic preferences")
 scene.queue_free();await process_frame
 print("Reactor automation hint: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
