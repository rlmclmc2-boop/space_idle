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
 check(p.detail.defeat_cause.visible and p.detail.defeat_cause.text=="上次8/3：能量损失为主","Frozen defeat source is visible inside the opened inspector")
 check(not p.detail.status.text.contains("上次") and p.detail.defeat_cause.position.y>=p.detail.status.position.y+p.detail.status.size.y and p.detail.defeat_cause.position.y+p.detail.defeat_cause.size.y<=p.detail.slots.position.y,"Short defeat cause has its own non-overlapping row above equipment choices")
 var item:Dictionary=p.items[p.selected]
 var entry:Dictionary=g.module_entry(item.category,item.index)
 check(item.category=="defence" and not g.slot_equipment_locked(item.category,item.index) and p.pending_key=="shield" and int(scene.db.equip(p.pending_key,entry.level).dmgtype)==1,"Missing installed energy resistance previews available shield in a refittable defence slot")
 check(p.detail.description.text.contains(scene.NAMES.shield) and str(g.module_entry("defence",0).key)=="armour" and not p.detail.equip.disabled,"Comparison exposes matching candidate without replacing fixed life armour")
 scene.defeat_feedback.record(g,"hit",{"player":true,"type":2,"amount":1000})
 scene.on_event("battle_defeated",{"manual":false,"remaining":2,"stage":14,"wave":6})
 scene.defeat_recall.gui_input.emit(click)
 item=p.items[p.selected];entry=g.module_entry(item.category,item.index)
 check(item.category=="defence" and int(scene.db.equip(entry.key,entry.level).dmgtype)==2,"Known physical cause selects matching existing resistance")
 check(p.detail.defeat_cause.text=="上次14/6：物理损失为主" and p.detail.defeat_cause.get_theme_font("font").get_string_size(p.detail.defeat_cause.text,HORIZONTAL_ALIGNMENT_LEFT,-1,p.detail.defeat_cause.get_theme_font_size("font_size")).x<=p.detail.defeat_cause.size.x,"Parent physical defeat source fits the standalone row")
 scene.defeat_feedback.record(g,"encounter",{})
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Opening comparison does not change equipment, resources or RNG")
 scene.on_event("battle_defeated",{"manual":false,"remaining":1,"stage":9,"wave":2})
 check(scene.last_defeat_cause=="unknown" and not scene.defeat_recall.tooltip_text.contains("抗能量") and not scene.defeat_recall.tooltip_text.contains("抗物理"),"Unknown actual cause replaces old direction with neutral comparison")
 p.select_item("weapons_0");p.show_inspector()
 check(p.comparison_context.is_empty() and p.detail.defeat_cause.text.is_empty() and not p.detail.defeat_cause.visible,"Normal object selection clears the defeat-specific context")
 scene.open_defeat_comparison();p.detail_frame.hide()
 check(p.comparison_context.is_empty() and p.detail.defeat_cause.text.is_empty() and not p.detail.defeat_cause.visible,"Closing the inspector clears source context")
 g.equip_slot("defence",1,"shield");p.refresh()
 scene.last_defeat_cause="energy";var equipped_before=JSON.stringify(g.profile)
 scene.open_defeat_comparison()
 check(p.selected==p.module_card_id("defence",1) and p.pending_key=="shield" and p.detail.equip.disabled,"Already installed matching shield takes priority without drafting a redundant refit")
 check(JSON.stringify(g.profile)==equipped_before,"Opening matching installed defence leaves equipment and resources unchanged")
 g.unequip_slot("defence",1)
 g.db.data.unlock.shield.level=99;g.profile.highestLevel=2;g.profile.cleared=[1]
 g.profile.grantedUnlocks=g.profile.grantedUnlocks.filter(func(id):return str(id)!="shield")
 g.rebuild_unlocks();g.pending_unlocks.clear();p.refresh()
 var early_before=JSON.stringify(g.profile);scene.open_defeat_comparison()
 check(p.detail.defeat_cause.text.contains("暂无抗能量换装") and not p.slot_options.has("shield") and p.pending_key=="armour","Before unlock, cause explicitly says no energy refit is available and offers no invented shield")
 check(p.selected==p.module_card_id("defence",0) and p.detail.slots.disabled and p.detail.remove.disabled and JSON.stringify(g.profile)==early_before,"Unavailable comparison keeps fixed life armour and never drafts its removal")
 var source_label:Label=p.detail.defeat_cause
 check(source_label.get_theme_font("font").get_string_size(source_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,source_label.get_theme_font_size("font_size")).x<=source_label.size.x,"Unavailable explanation fits the existing source row")
 scene.queue_free();await process_frame
 print("DEFEAT COMPARISON: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
