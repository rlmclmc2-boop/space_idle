extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.gui_embed_subwindows=true
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=101;g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true;g.profile.hyperspace.unlocked_drones=true
 var rng=RandomNumberGenerator.new();rng.seed=72
 var d=Rewards.create_drone(rng,g.hyperspace.config,"secondary-numbers","blue","laser",5,"1");d.hanging_slots=2;Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config)
 g.profile.hyperspace.hanging_modules.resource_collector.unlocked=true;g.profile.hyperspace.hanging_modules.resource_collector.exp=39100.0
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.refresh_manual_status();p.dirty=true;p.refresh();p.selected_id=d.id
 var commands=p.commands;var before=JSON.stringify(g.profile);var rng_before=g.rng.state
 commands.show_modules()
 var choice=commands.module_choices.filter(func(button):return button.get_meta("module_key")=="resource_collector")[0]
 check(choice.text.contains("39.1K") and not choice.text.contains("39100"),"Actual module manager uses shared XP suffix")
 var received=commands.received_rewards_text({"materials":{},"modules":{"resource_collector":{"copies":1,"newly_unlocked":false,"level":1,"experience_added":39100.0}}})
 check(received.contains("39.1K") and not received.contains("39100"),"Dismantle receipt formats actual module XP through the same ladder")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Module and receipt presentations preserve exact XP and RNG")
 commands.module_dialog.hide()
 g.profile.hyperspace.history[p.route]={"1":59.68};g.profile.hyperspace.auto.route=p.route;g.profile.hyperspace.auto.crew_id="navigator"
 var crew=g.crew.entry(g,"navigator");crew.level=int(39100/g.crew.config_value(g,"hyperspace_luck_per_level"))
 before=JSON.stringify(g.profile);p.route_ui.refresh()
 check(p.route_ui.record.text.contains("约") and p.route_ui.idle_time.text.contains("约") and g.profile.hyperspace.history[p.route]["1"]==59.68,"Rounded route record and loop duration identify estimates while keeping actual time")
 var luck=g.hyperspace.luck_snapshot(g,p.route)
 check(p.route_ui.luck.text.contains(NumberFormat.compact(roundf(luck.luck))) and p.route_ui.luck.tooltip_text.contains(NumberFormat.compact(roundf(luck.crew_luck))),"Actual route luck and its source breakdown use shared integer-point suffixes")
 p.route_ui.show_crew()
 check(p.route_ui.crew_info.text.contains("约") and p.route_ui.crew_info.text.contains(NumberFormat.compact(roundf(luck.luck))),"Existing hyperspace crew manager shows estimated duration and formatted configured luck")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Route and crew manager number presentation changes no assignment or task state")
 scene.queue_free();await process_frame
 print("Hyperspace secondary numbers: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
