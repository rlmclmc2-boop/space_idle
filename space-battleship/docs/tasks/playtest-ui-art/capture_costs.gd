extends SceneTree

const OUT := "res://docs/tasks/playtest-ui-art/evidence/"

func _initialize() -> void:
	call_deferred("record")

func record() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	for frame in 80: await process_frame
	var game = scene.game
	var entry: Dictionary = game.module_entry("weapons", 0)
	entry.level = 19
	game.profile.highestLevel = maxi(int(game.profile.highestLevel), int(game.hyperspace.config.unlock_stage))
	for amount in [1, 10]:
		for id in game.slot_upgrade_cost("weapons", 0, amount):
			if id == game.db.evolution_material_id():
				game.profile.hyperspace.materials[id] = 1000
			else:
				game.profile.resources[id] = 1.0e12
	game.resources_changed(game.profile.resources.keys())
	game.event.emit("hyperspace_changed", {"reason":"art_cost_capture"})
	scene.select_system(0)
	scene.equipment_panel.refresh()
	for index in 3:
		var amount: int = [1, 10, 0][index]
		scene.equipment_panel.amount_buttons[index].pressed.emit()
		for frame in 8: await process_frame
		assert(scene.equipment_panel.upgrade_amount == amount)
		var card: Control = scene.equipment_panel.cards.get("weapons_0")
		var count: int = game.max_upgrade_amount_slot("weapons", 0) if amount == 0 else amount
		var costs: Dictionary = game.slot_upgrade_cost("weapons", 0, count)
		print("ART_COST amount=", amount, " count=", count, " costs=", costs, " card_size=", card.size)
		for chip in card.cost_flow.get_children():
			print("ART_COST chip text=", chip.get_child(1).text, " rect=", chip.get_rect(), " flow=", card.cost_flow.size)
			assert(chip.position.x + chip.size.x <= card.cost_flow.size.x)
			assert(chip.position.y + chip.size.y <= card.cost_flow.size.y)
		if DisplayServer.get_name() != "headless":
			await capture("equipment-cost-%s.png" % ("max" if amount == 0 else str(amount)))
	quit()

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + filename))
	print("ART_COST ", filename, " result=", error)
