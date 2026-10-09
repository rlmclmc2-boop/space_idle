extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.cleared=range(1,9);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.profile.hyperspace.unlocked_drones=true;g.profile.hyperspace.history.alpha={"1":105.88}
 var rng:=RandomNumberGenerator.new();rng.seed=419
 var d:Dictionary=Rewards.create_drone(rng,g.hyperspace.config,"hint-white","white","laser",1,"1");d.hanging_slots=0
 check(Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config),"valid white zero-slot fixture")
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;var c=p.commands
 p.refresh_manual_status();p.route="alpha";p.select_section(0);p.route_ui.refresh()
 check(p.route_ui.background_status.text==p.t("layer_idle_none") and not p.route_ui.background_status.text.contains("尚未开始"),"Idle receipt absence states current status, not false never-started history")
 check(p.route_ui.hint.text.contains("10") and p.route_ui.crew_requirement().contains("通关"),"Early no-crew condition comes from next actual unlock gate")
 p.route_ui.show_crew()
 check(p.route_ui.crew_enable.disabled and p.route_ui.crew_reason.text.contains("10"),"Unavailable auto crew explicitly explains acquisition condition")
 p.route_ui.crew_dialog.hide();p.selected_id=d.id;p.select_section(1);p.refresh()
 check(p.details.text.contains(p.t("module_no_slots")),"Object details explain how zero current hanging slots can be opened")
 c.show_modules()
 check(c.module_dialog.find_children("*","Label",true,false).any(func(node):return node.text==p.t("module_no_slots")),"Mount dialog repeats applicable opening method")
 c.module_dialog.hide()
 var projection:Dictionary=d.duplicate(true);projection.origin_quality="blue"
 var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 var forecast:String=c.add_affix_forecast(projection)
 check(forecast.contains("67.2%") and forecast.contains(p.affix_name("attack_speed")),"Expanded forecast states configured weighted odds and compatible affix ranges")
 g.hyperspace.config.tier_weights={"1":0.0,"2":0.0,"3":0.0,"4":0.0,"5":201.0}
 check(c.add_affix_forecast(projection).contains("100.0%"),"Forecast updates from configuration rather than hard-coded odds")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Range preview preserves profile and combat RNG")
 check(not c.error_text("legendary_repeat_policy_required").contains("尚未确定") and c.error_text("legendary_repeat_policy_required").contains("重掷数值"),"Unsupported repeat legendary action states executable alternative")
 scene.queue_free();await process_frame
 print("HYPERSPACE HINTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
