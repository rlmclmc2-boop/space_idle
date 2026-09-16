extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func stats(values: Array) -> Dictionary:
	values.sort()
	return {"median_us": values[values.size()/2], "max_us": values[-1]}

func run() -> void:
	var scene = load("res://scripts/main.gd").new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.paused = true
	scene.game.pending_unlocks.clear()
	scene.game.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	scene.game.profile.cleared = range(1, 51)
	scene.game.profile.selectedShip = "Heavy_Battleship"
	scene.game.profile.loadout = scene.game.empty_loadout("Heavy_Battleship")
	for category in ["weapons", "defence"]:
		var keys = BattleGame.WEAPON_KEYS if category == "weapons" else BattleGame.DEFENSE_KEYS
		for i in scene.game.profile.loadout[category].size():
			scene.game.profile.loadout[category][i] = {"key":keys[i % keys.size()], "level":1}
	var reports := []
	for budget in [1e6, 1e100]:
		scene.game.profile.resources = {"1":budget, "2":budget}
		scene.build_ui()
		await process_frame
		for repeat in range(3):
			var frames := []
			var builds := []
			var clicks := []
			for i in range(12):
				var started := Time.get_ticks_usec()
				scene._process(0.0)
				frames.append(Time.get_ticks_usec() - started)
				started = Time.get_ticks_usec()
				scene.build_ui()
				builds.append(Time.get_ticks_usec() - started)
				started = Time.get_ticks_usec()
				scene.upgrade_buttons.laser.pressed.emit()
				clicks.append(Time.get_ticks_usec() - started)
				await process_frame
			var report := {"budget":budget,"repeat":repeat,"process":stats(frames),"build":stats(builds),"click":stats(clicks)}
			reports.append(report)
			print(JSON.stringify(report))
	scene.equipment_page = 1
	scene.build_ui()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/ui-before.png")
	scene.on_event("state", {})
	scene.on_event("hightech_complete", {"key":BattleGame.ENERGY_FOCUS})
	scene.on_event("state", {})
	for frame in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/ui-burst-%d.png" % frame)
	var file := FileAccess.open("res://.runtime/upgrade-ui.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(reports))
	scene.queue_free()
	await process_frame
	quit()
