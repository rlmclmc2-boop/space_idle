extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared = []
	scene.game.profile.unlocked = ["armour", "shield", "laser", "cannon", "missile"]
	scene.build_ui()
	check(scene.equipment_tabs.is_tab_hidden(4), "Ship tab hidden before second ship unlock")
	scene.game.profile.cleared = [10]
	scene.build_ui()
	check(not scene.equipment_tabs.is_tab_hidden(4), "Ship tab appears with second ship")
	var ship_page: Control = scene.equipment_tabs.get_child(4)
	var picker: OptionButton = ship_page.get_child(0)
	check(picker.item_count == 2, "Only unlocked ships are listed")
	var runtime_before: Dictionary = scene.game.profile.duplicate(true)
	picker.select(1)
	picker.item_selected.emit(1)
	await process_frame
	check(scene.game.profile.selectedShip == "Frigate", "Selecting a ship does not switch immediately")
	scene.ship_candidate_loadout.weapons[0].key = "cannon"
	check(scene.game.profile==runtime_before,"Editing candidate never mutates runtime loadout or resources")
	var draft: Dictionary = scene.ship_candidate_loadout.duplicate(true)
	scene.build_ui()
	check(scene.ship_candidate=="Destroyer" and scene.ship_candidate_loadout==draft,"UI rebuild preserves uncommitted ship draft")
	check(scene.game.profile==runtime_before,"Draft rebuild does not commit or refund equipment")
	scene.equipment_tabs.current_tab = 4
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://ship-tab.png")
	var target: Dictionary = scene.game.empty_loadout("Destroyer")
	target.weapons[0].key = "cannon"
	target.defence[0].key = "armour"
	check(scene.game.valid_loadout("Destroyer",target), "Candidate loadout validates")
	var before: String = scene.game.profile.selectedShip
	check(scene.game.switch_ship("Destroyer",target), "Switch accepts selected loadout")
	check(before == "Frigate" and scene.game.profile.selectedShip == "Destroyer", "Switch commits selected ship")
	check(scene.game.slot_entry("weapons",0).key == "cannon" and scene.game.slot_entry("defence",0).key == "armour", "Switch commits equipment selection")
	print("Ship tab: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
