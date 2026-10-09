extends SceneTree
## Real event path with an in-memory profile; independent of player saves.
class IsolatedUI extends "res://scripts/battlefield.gd":
	var writes: Array = []
	var previews := 0
	func create_battle_game(_persist: bool) -> BattleGame:
		return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:writes.append(control)
		super.set_ui_value(control,property,value)
	func equipment_display_snapshot(entry: Dictionary, level := -1) -> Dictionary:
		if level>=0:previews+=1
		return super.equipment_display_snapshot(entry,level)
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func choose(panel: Control, key: String) -> void:
	var index: int=panel.slot_options.find(key)
	panel.detail.slots.select(index)
	panel.detail.slots.item_selected.emit(index)
func click(control: Control, offset: Vector2) -> void:
	if DisplayServer.get_name()=="headless":
		if control is OptionButton:control.show_popup()
		else:control.pressed.emit()
		await process_frame
		return
	var point := root.get_final_transform()*control.get_global_transform_with_canvas()*offset
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		event.position=point
		Input.parse_input_event(event)
		await process_frame
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.set_script(IsolatedUI)
	scene.automation_args=["--capture"]
	root.add_child(scene)
	current_scene=scene
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,90)
	scene.game.profile.highestLevel=90
	scene.game.rebuild_unlocks()
	scene.game.pending_unlocks.clear()
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.game.profile.resources={"1":1e28,"2":1e28}
	scene.game.profile.onboarding.completed=true
	scene.game.switch_ship("Heavy_Battleship")
	scene.game.equip_slot("weapons",0,"laser")
	scene.game.equip_slot("weapons",1,"cannon")
	scene.refresh_tab_visibility()
	scene.equipment_tabs.current_tab=0
	await process_frame
	await process_frame
	var panel: Control=scene.equipment_panel
	var name_button: OptionButton=panel.cards.weapons_1.name_button
	await click(name_button,Vector2(name_button.size.x-4,17))
	check((name_button.get_popup().visible or DisplayServer.get_name()=="headless") and not panel.detail_frame.visible,"Actual title click opens inline slot menu without inspector")
	var refit_level: int=scene.game.module_entry("weapons",1).level
	name_button.get_popup().hide()
	name_button.select(panel.cards.weapons_1.equipment_options.find("missile"))
	name_button.item_selected.emit(name_button.selected)
	check(scene.game.module_entry("weapons",1).key=="missile" and scene.game.module_entry("weapons",1).level==refit_level,"Picker selection immediately equips and preserves slot level")
	check(not panel.detail_frame.visible,"Inline choice requires no confirmation or inspector")
	check(scene.game.module_entry("weapons",0).key=="laser","Refit leaves other slot unchanged")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../name-refit.png")
	panel.detail_frame.hide()
	await click(panel.cards.weapons_1.upgrade_button,panel.cards.weapons_1.upgrade_button.size/2)
	check(scene.game.module_entry("weapons",1).level==refit_level+1 and not panel.detail_frame.visible,"Independent actual upgrade click upgrades exact slot without opening picker")
	panel.open_picker("weapons_1")
	if DisplayServer.get_name()!="headless":
		var popup: PopupMenu=name_button.get_popup()
		check(popup.visible,"Actual mouse expands native replacement menu")
		var picker_ref: OptionButton=name_button
		scene.game.crew.auto_upgrade(scene.game,{"upgradeMode":"1"})
		panel.refresh()
		check(popup.visible and is_same(picker_ref,panel.cards.weapons_1.name_button),"Auto-upgrade and refresh preserve open picker popup instance")
		for down in [true,false]:
			var event:=InputEventKey.new()
			event.keycode=KEY_DOWN
			event.pressed=down
			Input.parse_input_event(event)
			await process_frame
		var chosen: int=popup.get_focused_item()
		var expected_key: String=str(panel.cards.weapons_1.equipment_options[chosen]) if chosen>=0 else "invalid"
		check(chosen>=0 and expected_key!=scene.game.module_entry("weapons",1).key,"Native menu focuses a different replacement option")
		for down in [true,false]:
			var event:=InputEventKey.new()
			event.keycode=KEY_ENTER
			event.pressed=down
			Input.parse_input_event(event)
			await process_frame
		check(scene.game.module_entry("weapons",1).key==expected_key and not popup.visible,"Native popup keyboard selection immediately equips after auto-upgrade")
	check(panel.footer_buttons.size()==1 and panel.footer_buttons.has("details"),"Main footer contains only details")
	check(panel.footer_buttons.details.text==UIText.t("equipment.inspect") and panel.footer_buttons.details.text.contains("比较") and panel.summary.text.contains("先看差异"),"Comparison entry states its purpose before a quick refit")
	name_button.get_popup().hide()
	panel.change_card_equipment("weapons_1","cannon")
	panel.select_item("weapons_1")
	panel.show_inspector()
	choose(panel,"missile")
	var missile_projection: Dictionary=scene.EQUIPMENT_DISPLAY.refit_snapshot(scene.game,scene.game.module_entry("weapons",1),"missile")
	check(panel.detail.description.text.contains(panel.rate_title(missile_projection)+" "+panel.rate_value(missile_projection)) and panel.detail.description.text.contains(UIText.t("equipment.refit_rate_scope")),"Weapon draft uses card DPS title/value and explicit baseline scope")
	check(panel.detail.description.tooltip_text.contains(panel.rate_notes(missile_projection)),"Candidate conditions remain available before confirmation")
	check(panel.detail.description.text.contains(UIText.t("equipment.description.missile")),"Candidate core role is available without first equipping")
	check(panel.detail_actions.position.y>=panel.detail.description.position.y+panel.detail.description.get_minimum_size().y,"Comparison content does not overlap the following actions")
	var cards: Dictionary=panel.cards.duplicate()
	var tabs: int=scene.equipment_tabs.get_instance_id()
	# Scrolling and preservation checks require an explicitly expanded inspector.
	if not panel.details_open:panel.toggle_details()
	panel.detail.slots.grab_focus()
	await process_frame
	panel.detail_scroll.scroll_vertical=60
	await process_frame
	var scroll: int=panel.detail_scroll.scroll_vertical
	check(scroll>0,"Fixture exercises actual nonzero inspector scroll")
	scene.writes.clear()
	check(scene.game.upgrade_slot("weapons",0),"Upgrade unrelated A succeeds")
	check(panel.pending_key=="missile" and panel.detail.slots.selected==panel.slot_options.find("missile"),"Upgrade A preserves B replacement draft")
	check(not scene.writes.has(panel.detail.title) and not scene.writes.has(panel.detail.stats),"Upgrade A does not rewrite unrelated B detail")
	var level: int=scene.game.module_entry("weapons",1).level
	scene.game.crew.auto_upgrade(scene.game,{"upgradeMode":"1"})
	check(scene.game.module_entry("weapons",1).level==level+1,"Actual crew auto-upgrade includes selected B")
	check(panel.pending_key=="missile" and panel.detail.slots.selected==panel.slot_options.find("missile"),"Auto-upgrade batch preserves selected B draft")
	check(panel.detail.slots.has_focus() and panel.detail_scroll.scroll_vertical==scroll and panel.details_open,"Auto-upgrade preserves focus, expanded state and scroll")
	check(panel.cards==cards and scene.equipment_tabs.get_instance_id()==tabs,"Auto-upgrade retains card and workspace instances")
	check(panel.detail.meta.text.contains(scene.game.permanent_level_text(level+1,"equipment")),"Selected detail catches up to upgraded level")
	panel.toggle_details()
	scene.game.crew.auto_upgrade(scene.game,{"upgradeMode":"1"})
	check(not panel.details_open and not panel.detail.stats.visible and panel.pending_key=="missile","Collapsed detail survives auto-upgrade")
	panel.detail_frame.hide()
	scene.previews=0
	scene.game.crew.auto_upgrade(scene.game,{"upgradeMode":"1"})
	check(scene.previews==0 and panel.detail_dirty,"Closed inspector defers next-level projection")
	panel.show_inspector()
	check(panel.pending_key=="missile" and scene.previews>0 and not panel.detail_dirty,"Reopen catches up and preserves valid draft")
	scene.equipment_tabs.current_tab=3
	await process_frame
	scene.game.crew.auto_upgrade(scene.game,{"upgradeMode":"1"})
	check(panel.dirty,"Hidden equipment page is lazy")
	scene.equipment_tabs.current_tab=0
	await process_frame
	panel.refresh_pending()
	check(not panel.dirty and panel.pending_key=="missile","Reveal keeps valid draft")
	panel.select_item("weapons_0")
	check(panel.pending_key=="laser","Selecting a different slot initializes its equipped key")
	choose(panel,"missile")
	scene.game.unequip_slot("weapons",0)
	check(panel.pending_key.is_empty() and panel.detail.slots.selected==0,"Actual module removal resets stale identity draft")
	panel.select_item("weapons_7")
	choose(panel,"longLaser")
	scene.game.switch_ship("Frigate")
	check(panel.items.weapons_7.locked and panel.pending_key==panel.items.weapons_7.key and panel.detail.equip.disabled,"Ship capacity removal invalidates draft safely")
	for index in range(scene.game.active_slot_count("weapons"),scene.game.module_entries("weapons").size()):
		var id := "weapons_%d" % index
		check(panel.items.has(id) and panel.items[id].id==id and panel.items[id].locked and is_same(panel.cards[id],cards[id]),"Each dormant weapon retains its unique locked card: "+id)
	check(not panel.items.has("drone:invalid"),"Dormant module cards do not use a combat drone placeholder")
	scene.game.switch_ship("Heavy_Battleship")
	check(is_same(panel.cards.weapons_7,cards.weapons_7) and not panel.items.weapons_7.locked,"Restoring hull capacity reactivates the same W08 card")
	panel.select_item("weapons_1")
	panel.show_inspector()
	choose(panel,"missile")
	# Revoke the authoritative progress condition, not only its derived cache.
	var old_cleared: Array=scene.game.profile.cleared.duplicate()
	var old_highest: int=scene.game.profile.highestLevel
	var old_grants: Array=scene.game.profile.grantedUnlocks.duplicate()
	var missile_unlock: String=scene.game.db.unlock_id("equipment","missile")
	var missile_row: Dictionary=scene.game.db.data.unlock[missile_unlock]
	scene.game.profile.grantedUnlocks.erase(missile_unlock)
	if missile_row.get("mode","cleared")=="reached":scene.game.profile.highestLevel=int(missile_row.level)
	else:scene.game.profile.cleared.erase(int(missile_row.level))
	scene.game.profile.unlocked.erase("missile")
	check(not scene.game.content_unlocked("equipment","missile"),"Fixture truly revokes missile availability")
	panel.refresh()
	check(panel.pending_key=="cannon","Unavailable candidate restores equipped choice")
	scene.game.profile.cleared=old_cleared
	scene.game.profile.highestLevel=old_highest
	scene.game.profile.grantedUnlocks=old_grants
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	panel.refresh()
	panel.detail_frame.hide()
	panel.grid_scroll.ensure_control_visible(panel.cards.defence_1)
	await process_frame
	await process_frame
	await click(panel.cards.defence_1.name_button,Vector2(20,17))
	# D01 is fixed armour; exercise the native refit menu on replaceable D02.
	check((panel.cards.defence_1.name_button.get_popup().visible or DisplayServer.get_name()=="headless") and not panel.detail_frame.visible,"Defence title opens inline menu")
	panel.cards.defence_1.name_button.get_popup().hide()
	panel.cards.defence_1.name_button.item_selected.emit(panel.cards.defence_1.equipment_options.find(BattleGame.DEFENSE_KEYS[0]))
	check(scene.game.module_entry("defence",1).key==BattleGame.DEFENSE_KEYS[0],"Defence selection immediately equips category-valid module")
	check(not panel.detail.has("enhancement") and panel.get_action_anchor("enhancement")==null,"Equipment picker and inspector have no enhancement navigation")
	# Inspector draft compares the selected type at this slot's current level.
	scene.game.equip_slot("defence",1,"shield")
	scene.game.module_entry("defence",1).level=80
	scene.game.invalidate_stat_cache()
	panel.refresh()
	panel.select_item("defence_1")
	panel.show_inspector()
	var original_profile: Dictionary=scene.game.profile.duplicate(true)
	var original_rng: int=scene.game.rng.state
	var original_armour=scene.game.player.armour
	var original_shield=scene.game.player.shield
	choose(panel,"armour")
	var target_entry: Dictionary=scene.game.module_entry("defence",1).duplicate(true)
	target_entry.key="armour"
	var target_value=scene.equipment_display_snapshot(target_entry).expected
	check(panel.detail.description.text.contains(scene.NAMES.shield) and panel.detail.description.text.contains(scene.NAMES.armour) and panel.detail.description.text.contains(scene.number(target_value)),"Draft shows current shield and same-level replacement armour value")
	check(panel.detail.description.text.contains(UIText.t("equipment.energy")) and panel.detail.description.text.contains(UIText.t("equipment.physical")) and panel.detail.description.text.contains("80"),"Draft distinguishes resistance and retained level")
	check(panel.detail.description.text.contains(UIText.t("equipment.description.armour")),"Defence preview includes candidate core role")
	check(scene.game.profile==original_profile and scene.game.rng.state==original_rng and scene.game.player.armour==original_armour and scene.game.player.shield==original_shield,"Selecting and calculating preview cannot change profile, RNG or live health")
	var description_control: Label=panel.detail.description
	panel.refresh_detail()
	check(is_same(description_control,panel.detail.description),"Draft reuses comparison control")
	check(scene.game.profile==original_profile and scene.game.rng.state==original_rng,"Repeated refresh remains read-only")
	panel.confirm_equipment()
	check(scene.game.module_entry("defence",1).key=="armour" and scene.game.module_entry("defence",1).level==80 and GrowthNumber.compare(scene.equipment_display_snapshot(scene.game.module_entry("defence",1)).expected,target_value)==0,"Confirmed same-level armour matches preview")
	panel.show_inspector()
	choose(panel,"")
	check(panel.detail.description.text.contains(UIText.t("equipment.refit_empty")) and scene.game.module_entry("defence",1).key=="armour","Empty-slot preview is safe and does not unload")
	choose(panel,"armour")
	check(panel.detail.description.text==panel.items.defence_1.description and panel.detail_actions.position.y==414,"Returning to current type restores description and compact layout")

	scene.select_system(4)
	check(scene.enhancement_panel.visible,"Independent enhancement main page entry remains available")
	check(not scene.game.save_enabled,"No player save writes")
	print("Equipment picker refresh: %d checks, %d failures"%[checks,failures])
	if "--interactive" in OS.get_cmdline_user_args():
		scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
		if not panel.details_open:panel.toggle_details()
		panel.open_picker("weapons_1")
		root.size=Vector2i(1180,812)
		var timer:=Timer.new()
		timer.wait_time=5
		timer.timeout.connect(func():
			scene.game.crew.auto_upgrade(scene.game,{"upgradeMode":"1"})
			print("AUTO tick: selected=%s pending=%s dropdown=%s level=%s expanded=%s scroll=%s"%[panel.selected,panel.pending_key,panel.detail.slots.selected,scene.game.module_entry("weapons",1).level,panel.details_open,panel.detail_scroll.scroll_vertical]))
		root.add_child(timer)
		timer.start()
	else:
		scene.queue_free()
		await process_frame
		quit.call_deferred(1 if failures else 0)
