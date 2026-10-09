extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.cleared=range(1,9);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 scene.refresh_tab_visibility();scene.equipment_panel.refresh()
 scene.defeat_feedback.record(g,"encounter",{})
 scene.defeat_feedback.record(g,"hit",{"player":true,"type":1,"amount":1000})
 scene.on_event("battle_defeated",{"manual":false,"remaining":2,"stage":8,"wave":3})
 check(scene.last_defeat_cause=="energy" and scene.defeat_recall.tooltip_text.contains("抗能量"),"Known defeat freezes an actual incoming-type recommendation")
 scene.defeat_feedback.record(g,"encounter",{})
 check(scene.defeat_feedback.cause(g)=="unknown" and scene.last_defeat_cause=="energy","Later encounter cannot reinterpret previous defeat")
 var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 scene.defeat_recall.gui_input.emit(click);await process_frame
 var p=scene.equipment_panel
 check(scene.equipment_tabs.current_tab==scene.equipment_tabs.get_tab_idx_from_control(p) and p.detail_frame.visible,"Actual recall click opens existing equipment inspector")
 var item:Dictionary=p.items[p.selected]
 var entry:Dictionary=g.module_entry(item.category,item.index)
 check(item.category=="defence","Missing energy-resistant equipment still opens defence comparison")
 scene.defeat_feedback.record(g,"hit",{"player":true,"type":2,"amount":1000})
 scene.on_event("battle_defeated",{"manual":false,"remaining":2})
 scene.defeat_recall.gui_input.emit(click)
 item=p.items[p.selected];entry=g.module_entry(item.category,item.index)
 check(item.category=="defence" and int(scene.db.equip(entry.key,entry.level).dmgtype)==2,"Known physical cause selects matching existing resistance")
 scene.defeat_feedback.record(g,"encounter",{})
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Opening comparison does not change equipment, resources or RNG")
 scene.on_event("battle_defeated",{"manual":false,"remaining":1,"stage":9,"wave":2})
 check(scene.last_defeat_cause=="unknown" and not scene.defeat_recall.tooltip_text.contains("抗能量") and not scene.defeat_recall.tooltip_text.contains("抗物理"),"Unknown actual cause replaces old direction with neutral comparison")
 scene.queue_free();await process_frame
 print("DEFEAT COMPARISON: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
