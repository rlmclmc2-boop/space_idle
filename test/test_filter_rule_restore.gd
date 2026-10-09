extends SceneTree
const RulesPanel=preload("res://scripts/hyperspace_panel.gd")
const Codec=preload("res://scripts/hyperspace_filter.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.cleared=range(1,20);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 var p=scene.hyperspace_panel
 p.filter_enabled.button_pressed=true;p.filter_action.select(1);p.filter_kinds[0].select(p.KINDS.find("quality"));p.configure_condition(0);p.condition_values[0].select(0);p.save_filter()
 var saved:Dictionary=g.profile.hyperspace.filter.duplicate(true)
 check(saved.enabled and saved.action=="clear_matches" and saved.conditions==[{"field":"quality","value":"white"}],"Explicit save persists actual white auto-dismantle rule")
 var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 var rebuilt=RulesPanel.new();root.add_child(rebuilt);rebuilt.setup(scene);rebuilt.set_process(false);rebuilt.select_section(3);await process_frame
 check(rebuilt.filter_enabled.button_pressed and rebuilt.filter_action.get_item_metadata(rebuilt.filter_action.selected)=="clear_matches","Fresh panel restores enabled state and saved action")
 check(rebuilt.filter_kinds[0].get_item_metadata(rebuilt.filter_kinds[0].selected)=="quality" and rebuilt.condition_values[0].get_item_metadata(rebuilt.condition_values[0].selected)=="white","Fresh panel restores saved white condition")
 check(Codec.import_string(rebuilt.filter_text.text,g.hyperspace.config)==saved and rebuilt.filter_result.text.contains(rebuilt.t("filter_action_clear_matches")),"String and visible policy summary agree with restored controls")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Panel creation and rule-page opening never write profile or RNG")
 rebuilt.filter_enabled.button_pressed=false;rebuilt.condition_values[0].select(2)
 rebuilt.refresh();rebuilt.on_event("hyperspace_changed",{"reason":"claimed"});rebuilt.refresh();rebuilt.select_section(0);rebuilt.select_section(3)
 check(not rebuilt.filter_enabled.button_pressed and rebuilt.condition_values[0].get_item_metadata(rebuilt.condition_values[0].selected)=="gold","Refresh, reward event and section re-entry preserve an unsaved draft")
 rebuilt.show_strings();rebuilt.filter_text.text="invalid draft";rebuilt.string_dialog.hide()
 check(g.profile.hyperspace.filter==saved,"Canceling a string draft does not alter saved processing")
 var imported:Dictionary={"version":2,"enabled":true,"action":"keep_matches","mode":"any","conditions":[{"field":"weapon","value":"missile"},{"field":"quality","value":"blue"},{"field":"minimum_level","value":40},{"field":"affix","key":"shield_capacity","tier":3},{"field":"legendary_effect","value":"drone_master"}]}
 imported=Codec.import_string(Codec.export_string(imported,g.hyperspace.config),g.hyperspace.config)
 rebuilt.filter_text.text=Codec.export_string(imported,g.hyperspace.config);rebuilt.import_filter_draft();rebuilt.build_filter_draft()
 check(Codec.import_string(rebuilt.filter_text.text,g.hyperspace.config)==imported,"Import restores all five condition kinds, OR, enabled and action")
 check(g.profile.hyperspace.filter==saved,"Imported controls remain a draft until explicit save")
 rebuilt.save_filter();check(g.profile.hyperspace.filter==imported,"Explicit save alone commits imported multiple conditions")
 var final_panel=RulesPanel.new();root.add_child(final_panel);final_panel.setup(scene);final_panel.set_process(false);final_panel.build_filter_draft()
 check(Codec.import_string(final_panel.filter_text.text,g.hyperspace.config)==imported,"Rebuilt panel restores the subsequently saved multiple-condition rule")
 final_panel.queue_free();rebuilt.queue_free();scene.queue_free();await process_frame
 print("FILTER RULE RESTORE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
