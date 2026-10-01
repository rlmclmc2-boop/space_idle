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
func run() -> void:
	var scene := DisplayUI.new()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	scene.game.profile.cleared=range(1,76)
	scene.game.profile.highestLevel=76
	scene.game.rebuild_unlocks()
	var entry=scene.game.module_entry("weapons",0)
	entry.level=40
	entry.attacks=1000
	entry.sockets=[]
	var gem=scene.game.new_jewel("1",1)
	scene.game.profile.jewels=[gem]
	scene.refresh_tab_visibility()
	scene.equipment_tabs.current_tab=4
	var panel=scene.jewel_panel
	panel.open("weapons",0)
	await process_frame
	var before: Dictionary=entry.duplicate(true)
	var after: Dictionary=entry.duplicate(true)
	after.sockets=[gem.duplicate(true)]
	var old=scene.game.jewel_equipment_stat(before)
	var value=scene.game.jewel_equipment_stat(after)
	var delta=GrowthNumber.subtract(value,old)
	var preview: String=panel.preview_socket(gem,0)
	check(preview.contains("("+NumberFormat.signed_difference(value,old)+")"),"Gem preview uses signed compact difference")
	check(preview.contains(scene.number(old)) and preview.contains(scene.number(value)),"Both comparison endpoints retain magnitude formatting")
	check(not preview.contains(GrowthNumber.text(delta)),"Late-game delta is not a raw integer")
	check(entry==before and scene.game.profile.jewels[0]==gem,"Preview preserves module and inventory")
	panel.selected=[gem.token]
	panel.operate_socket(0)
	check(scene.message.contains(preview),"Socket battlefield toast reuses the exact preview comparison")
	check(entry.sockets[0].token==gem.token and scene.game.profile.jewels.is_empty(),"Actual socket retains original token ownership")
	check(panel.stat_comparison(after,before).contains("(-"+NumberFormat.compact(delta)+")"),"Decreasing comparison preserves negative sign")
	print("JEWEL_SIGNED_PREVIEW ",checks," checks, ",failures," failures")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
