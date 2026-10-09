extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func gameplay_snapshot(g) -> String:
 var snapshot:Dictionary=g.profile.duplicate(true)
 snapshot.erase("hyperspaceReceipt") # The sole authorized UI-read marker.
 return JSON.stringify(snapshot)
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear()
 g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 scene.refresh_tab_visibility();scene.select_system(9)
 await process_frame
 var p=scene.hyperspace_panel;var f=p.reward_feedback
 var route_ui=p.route_ui
 var initial_profile=gameplay_snapshot(g);var initial_rng=g.rng.state
 p.refresh();f.show_receipt()
 check(not route_ui.history_box.visible and not route_ui.task_box.visible and not route_ui.summaries.visible,"First entry hides empty record and task surfaces")
 check(not f.card.visible and not p.exploration_receipt_area.visible,"First entry reserves no empty reward-receipt area")
 check(p.first_win.visible and p.first_win.text.contains("有机会得到无人机") and p.first_win.text.contains("后台探索"),"First entry explains rewards and the next unlocked action without promising a drone")
 check(route_ui.challenge_button.custom_minimum_size==Vector2(420,74) and route_ui.challenge_button.get_theme_font_size("font_size")==26 and route_ui.challenge_button.disabled==not str(route_ui.view().reasons.challenge).is_empty(),"First challenge preserves domain availability and uses the prominent size")
 check(gameplay_snapshot(g)==initial_profile and g.rng.state==initial_rng,"First-entry projection changes no progress, inventory or RNG")
 g.profile.hyperspace.history[p.route]={"1":12.0};p.refresh()
 check(route_ui.history_box.visible and route_ui.summaries.visible and not route_ui.task_box.visible and not p.first_win.visible,"Real cleared-layer record remains visible without an empty task frame")
 g.profile.hyperspace.history.erase(p.route);p.refresh()
 var rng=RandomNumberGenerator.new();rng.seed=419
 var d=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"feedback:white","white","laser",5,"1")
 g.profile.hyperspace.unlocked_drones=false
 g.profile.hyperspace.active={"status":"completed_pending","reward":{"drone":d,"materials":{"degenerate_matter":3},"ultimate_cores":0}}
 var before=gameplay_snapshot(g)
 p.on_event("hyperspace_changed",{"reason":"completed_pending"})
 check(gameplay_snapshot(g)==before and not f.card.visible,"Pending feedback does not settle or reveal unclaimed reward")
 g.profile.hyperspace.active={};g.profile.hyperspace.unlocked_drones=true
 var bag:Dictionary=g.profile.hyperspace.inventory
 bag.drones[d.id]=d;bag.warehouse.append(d.id);bag.generation+=1
 p.on_event("hyperspace_changed",{"reason":"claimed"})
 await process_frame
 check(f.card.visible and p.exploration_receipt_area.visible and f.view_button.visible and f.summary.text.contains("等级 5"),"Settled drone receives visible receipt and action")
 check(f.notice!=null and f.notice.visible,"First acquired drone opens actionable notice")
 p.select_section(1)
 check(not p.exploration_receipt_area.visible,"Other sections do not reserve the exploration receipt area")
 p.select_section(0);f.show_receipt()
 check(p.exploration_receipt_area.visible,"Returning to exploration preserves the actual reward receipt")
 print("Hyperspace first entry: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
