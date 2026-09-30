extends SceneTree
class DisplayUI extends "res://scripts/main.gd":
	func create_battle_game(_persist: bool) -> BattleGame:
		return BattleGame.new(db,false)
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(label)
# Focused display-only regression for a full loadout previewed on a smaller hull.
func run() -> void:
	var scene := DisplayUI.new()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.profile.cleared=range(1,76)
	scene.game.rebuild_unlocks()
	scene.game.switch_ship("Heavy_Battleship")
	for category in ["weapons","defence"]:
		for index in scene.game.active_slot_count(category):
			scene.game.equip_slot(category,index,scene.game.WEAPON_KEYS[index%4] if category=="weapons" else scene.game.DEFENSE_KEYS[index%2])
			scene.game.module_entry(category,index).level=40
	scene.refresh_tab_visibility()
	scene.equipment_tabs.current_tab=3
	await process_frame
	var panel=scene.ship_controls.page
	var mounts: Dictionary=panel.mounts.duplicate()
	await process_frame
	await process_frame
	var before: Dictionary=scene.game.profile.duplicate(true)
	panel.candidate="Frigate"
	panel.refresh()
	await process_frame
	await process_frame
	check(panel.mounts.size()==12 and panel.candidate=="Frigate" and scene.game.profile.selectedShip=="Heavy_Battleship","Full loadout remains read-only when previewing Frigate")
	check(scene.game.profile.loadout==before.loadout,"Display refresh preserves every module and socket")
	var scroll: Rect2=panel.mount_scroll.get_global_rect()
	check(scroll.end.x<=panel.get_global_rect().end.x,"Mount scroll stays inside workspace")
	for category in ["weapons","defence"]:
		var capacity=scene.game.active_slot_count(category,"Frigate")
		for index in scene.game.module_entries(category).size():
			var id=scene.game.slot_id(category,index)
			var button: Button=panel.mounts[id]
			check(button==mounts[id] and button.visible,"Mount instance and ID retained: "+id)
			if category=="defence" or index>=capacity:
				var rect=button.get_global_rect()
				check(rect.position.x>=scroll.position.x and rect.end.x<=scroll.end.x+0.1,"Long row stays within right column: "+id)
				var name=scene.NAMES[str(scene.game.module_entry(category,index).key)]
				check(button.text.contains(name) and button.tooltip_text.contains(name) and button.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART,"Full name wraps and remains in tooltip: "+id)
	panel.mount_scroll.scroll_vertical=10000
	await process_frame
	check(panel.mount_scroll.scroll_vertical>0,"Overflow has vertical scrolling")
	var last: Rect2=panel.mounts.weapons_7.get_global_rect()
	check(last.position.y>=scroll.position.y and last.end.y<=scroll.end.y+0.1,"Final inactive ID is reachable by scrolling")
	panel.refresh()
	check(panel.mount_scroll.scroll_vertical>0 and panel.candidate=="Frigate","Refresh preserves scroll and candidate")
	panel.candidate="Heavy_Battleship"
	panel.refresh()
	await process_frame
	check(panel.mounts.weapons_7.get_parent()==panel.preview and not panel.mounts.weapons_7.disabled,"Returning to current hull restores active weapon action")
	panel.mounts.weapons_7.pressed.emit()
	check(scene.equipment_tabs.current_tab==0 and scene.equipment_panel.selected=="weapons_7","Same mount opens its original module")
	print("SHIP_MOUNT_BOUNDS ",checks," checks, ",failures," failures")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
