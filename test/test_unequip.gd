extends SceneTree

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var game = scene.game
	scene.db.ships[game.profile.selectedShip].sameEquipmentLimit = 2
	game.save_enabled = false
	game.profile.unlocked = ["laser","cannon","missile","armour","shield"]
	game.profile.resources = {"1":10000000.0,"2":10000000.0}
	game.profile.loadout.weapons = [{"key":"laser","level":1},{"key":"laser","level":1},{"key":"","level":1}]
	game.first_equipment_entry("laser").level = 1
	var initial: Dictionary = game.profile.resources.duplicate()
	check(game.upgrade_slot("weapons",0,2), "upgrade first")
	check(game.upgrade_slot("weapons",1), "upgrade duplicate")
	var second_cost: Dictionary = game.upgrade_costs_for_level("laser",1,1)
	var before: Dictionary = game.profile.resources.duplicate()
	# Only the lower-level duplicate is affordable; UI queries must keep slot identity.
	var next_second: Dictionary = game.slot_upgrade_cost("weapons",1)
	game.profile.resources = {"1":float(next_second.get("1",0)),"2":float(next_second.get("2",0))}
	game.paused = true
	scene.build_ui()
	scene._process(0)
	check(scene.upgrade_buttons.laser.disabled and not scene.upgrade_buttons.weapons_1.disabled, "duplicate UI affordability belongs to each slot")
	check(scene.upgrade_buttons.laser.get_meta("slot")=="weapons_0" and scene.upgrade_buttons.weapons_1.get_meta("slot")=="weapons_1", "duplicate buttons retain distinct slot identities")
	game.paused = false
	game.profile.resources = before.duplicate()
	check(not game.equip_slot("weapons",0,"cannon"), "reject direct replacement")
	check(game.profile.resources == before, "replacement cannot refund")
	scene.confirm_unequip("weapons",0)
	var dialog: ConfirmationDialog = scene.get_child(scene.get_child_count()-1)
	check(dialog.visible, "confirmation shown")
	dialog.canceled.emit()
	await process_frame
	check(game.slot_entry("weapons",0).level == 3 and game.profile.resources == before, "cancel preserves equipment and resources")
	scene.confirm_unequip("weapons",0)
	dialog = scene.get_child(scene.get_child_count()-1)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://unequip-confirm.png")
	dialog.confirmed.emit()
	await process_frame
	check(game.slot_entry("weapons",0).key == "", "confirmed removal leaves empty slot")
	check(game.slot_entry("weapons",1).level == 2, "duplicate retains level")
	for id in initial:
		check(game.profile.resources[id] == initial[id] - second_cost.get(id,0), "full refund " + id)
	before = game.profile.resources.duplicate()
	check(not game.unequip_slot("weapons",0) and game.profile.resources == before, "no double refund")
	check(game.equip_slot("weapons",0,"laser"), "re-equip same type")
	check(game.slot_entry("weapons",0).level == 1 and game.slot_entry("weapons",1).level == 2, "independent new level one")
	check(game.unequip_slot("weapons",0) and game.equip_slot("weapons",0,"cannon"), "replace via empty slot")
	check(game.slot_entry("weapons",0).key == "cannon" and game.slot_entry("weapons",0).level == 1, "new type persisted")
	check(game.profile.resources == before, "level one removal free")
	game.profile.loadout.defence = [{"key":"armour","level":1},{"key":"shield","level":1}]
	game.first_equipment_entry("armour").level = 1
	game.first_equipment_entry("shield").level = 1
	for index in range(2):
		before = game.profile.resources.duplicate()
		check(game.upgrade_slot("defence",index), "defence upgrade")
		check(game.unequip_slot("defence",index), "defence removal")
		check(game.profile.resources == before, "defence refund")
		check(game.slot_entry("defence",index).key == "", "defence stays empty")
	game.ensure_loadout()
	check(game.slot_entry("weapons",2).key == "", "normalization does not auto-equip")
	scene.build_ui()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://unequip-empty.png")
	print("Unequip: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
