extends SceneTree
const A=preload("res://scripts/reactor_automation.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.profile.cleared=range(1,41);g.profile.highestLevel=41;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.resources["2"]=0
 g.set_reactor_allocation("weapons",70);g.set_reactor_allocation("defence",20);g.crew.assign(g,"navigator","reactor_upgrade","reactor");A.set_enabled(g,"upgrade",false);A.set_enabled(g,"allocate",true)
 A.save_slot(g,0,A.capture(g));var slots=g.profile.reactorAutomation.presets.duplicate(true)
 g.set_reactor_allocation("weapons",30);var manual=g.profile.reactorAllocation.duplicate(true);g.crew.advance(g,1)
 check(g.profile.reactorAllocation==manual and g.profile.reactorAutomation.ratio==A.capture(g),"Enabled allocation maintains the user's newly dragged distribution")
 g.equalize_reactor_allocation();manual=g.profile.reactorAllocation.duplicate(true);g.crew.advance(g,1)
 check(g.profile.reactorAllocation==manual and g.profile.reactorAutomation.ratio==A.capture(g),"Manual equalize updates the target instead of being undone next second")
 check(g.profile.reactorAutomation.presets==slots,"Manual edits never silently overwrite a saved preset")
 var target=g.profile.reactorAutomation.ratio.duplicate(true);g.profile.resources["2"]=g.reactor_upgrade_cost();g.upgrade_reactor(1)
 check(g.profile.reactorAutomation.ratio==target,"Capacity upgrade is not mistaken for a user target edit")
 A.apply(g,target,false);check(g.profile.reactorAutomation.ratio==target,"Internal automatic application does not capture its rounded output as a new target")
 g.crew.assign(g,"navigator","","");scene.refresh_tab_visibility();scene.select_system(2);await process_frame
 var ui=scene.reactor_panel.automation_ui;ui.refresh()
 check(ui.crew_hint.visible and ui.allocate.button_pressed,"No-crew state exposes a nearby explanation while retaining saved preference")
 print("LAYOUT ",ui.bar.position," ",ui.bar.size," min=",ui.bar.get_combined_minimum_size()," hint=",ui.crew_hint.position," ",ui.crew_hint.size)
 check(ui.bar.position.y+ui.bar.size.y<=1200 and ui.crew_hint.position.y+ui.crew_hint.size.y<=1200 and ui.bar.get_combined_minimum_size().x<=522,"Compact automation strip and no-crew sentence fit the existing logical canvas")
 g.crew.assign(g,"navigator","reactor_upgrade","reactor");ui.refresh();check(not ui.crew_hint.visible,"Actual dispatch removes the inactive explanation")
 ui.show_settings();await process_frame
 ui.draft={"total":49222,"weights":{"weapons":22838,"defence":21190,"smelting":5194}};var precise=ui.draft.duplicate(true);ui.refresh_draft()
 check(ui.idle.text.ends_with("0%") and ui.captions.weapons.text.ends_with("46%") and ui.captions.defence.text.ends_with("43%") and ui.captions.smelting.text.ends_with("11%"),"Largest remainder display sums to 100 with zero actual idle")
 check(ui.draft==precise,"Opening/refreshing settings preserves exact captured weights")
 ui.edit_ratio("weapons",45.0)
 check(ui.draft.weights.defence==21190 and ui.draft.weights.smelting==5194 and ui.draft.total==49222,"Dragging one share preserves untouched weights and denominator")
 ui.allocate.set_pressed_no_signal(true)
 check(ui.allocate.get_theme_color("font_pressed_color")==scene.reactor_panel.INK,"Selected checkbox remains readable on pale plate")
 check(scene.reactor_panel.allocation_scroll.position.y+scene.reactor_panel.allocation_scroll.size.y<=1010 and ui.bar.position.y>=1072,"Allocation list, total plate and automation rows do not overlap")
 ui.dialog.hide()
 scene.queue_free();await process_frame
 print("Reactor manual target: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
