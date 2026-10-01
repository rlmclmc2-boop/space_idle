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
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.set_script(IsolatedUI)
	root.add_child(scene)
	current_scene=scene
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,90)
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.game.profile.resources={"1":1e28,"2":1e28}
	scene.game.profile.onboarding.completed=true
	scene.game.switch_ship("Heavy_Battleship")
	scene.game.equip_slot("weapons",0,"laser")
	scene.game.equip_slot("weapons",1,"cannon")
	scene.equipment_tabs.current_tab=0
	await process_frame
	await process_frame
	var panel: Control=scene.equipment_panel
	panel.open_picker("weapons_1")
	choose(panel,"missile")
	var cards: Dictionary=panel.cards.duplicate()
	var tabs: int=scene.equipment_tabs.get_instance_id()
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
	panel.open_picker("weapons_0")
	check(panel.pending_key=="laser","Selecting a different slot initializes its equipped key")
	choose(panel,"missile")
	scene.game.unequip_slot("weapons",0)
	check(panel.pending_key.is_empty() and panel.detail.slots.selected==0,"Actual module removal resets stale identity draft")
	panel.open_picker("weapons_7")
	choose(panel,"longLaser")
	scene.game.switch_ship("Frigate")
	check(panel.items.weapons_7.locked and panel.pending_key==panel.items.weapons_7.key and panel.detail.equip.disabled,"Ship capacity removal invalidates draft safely")
	scene.game.switch_ship("Heavy_Battleship")
	panel.open_picker("weapons_1")
	choose(panel,"missile")
	scene.game.profile.unlocked.erase("missile")
	panel.refresh()
	check(panel.pending_key=="cannon","Unavailable candidate restores equipped choice")
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
