extends SceneTree
const OUT := "/tmp/planet-shipyard-through-r1"
var game
var session
var panel
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT.path_join(name + ".png"))
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440, 900)
	assert(GDExtensionManager.load_extension("/tmp/planet-native-472/planet.gdextension") == GDExtensionManager.LOAD_STATUS_OK)
	game = load("res://src/main.gd").new()
	root.add_child(game)
	await process_frame
	print("STARTUP_ERROR ", game.startup_error)
	assert(game.startup_error.is_empty())
	game.set_process(false)
	game._skip_tutorial = true
	session = game.session
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json"))
	var saved: Dictionary = session.campaign_system.save_state()
	for row in config.unlock.unlock: saved.grants[str(row.type)+":"+str(row.target)] = true
	assert(session.campaign_system.restore_state(saved).ok)
	session.crew_system.refresh_availability(session.campaign_system.available)
	var base_planets: Dictionary = session.planet_system.save_state()
	game._sync_guidance()
	game._refresh_feature_visibility()
	game._left_buttons.planet.pressed.emit()
	panel = game.planet_scene
	panel.select_planet("1")
	var order := ["station", "refinery", "workshop", "shipyard"]
	for count in [3, 4]:
		var planets: Dictionary = base_planets.duplicate(true)
		var a: Dictionary = planets.planets["1"]
		a.exploration = 240
		a.conquered = true
		for index in count:
			var key: String = order[index]
			a.buildings[key].state = "built"
			for candidate in config.planet_build.planet_build:
				if str(candidate.id) == key: a.buildings[key].work = int(candidate.build_explore)
		assert(session.planet_system.restore_state(planets).ok)
		session.planet_system.refresh_availability(session.campaign_system.available)
		panel.refresh()
		await create_timer(0.25).timeout
		await shot("stage_%d" % count)
	panel._visual.phase = PI / (2.0 * 0.045)
	panel._visual.architecture.update_pose(panel._visual.phase, panel._visual.globe.phases.x, panel._visual._body_radius(), panel._visual.globe.visual_clock)
	await shot("quarter_simulated")
	panel._facility_button.pressed.emit()
	panel._selected_facility = "workshop"
	panel._rebuild_drawer()
	await shot("facilities")
	panel._crew_button.pressed.emit()
	await shot("crew")
	panel._task_button.pressed.emit()
	await shot("exploration")
	for child in panel._drawer_body.get_children():
		if child is Button and child.text.begins_with("征服奖励"):
			child.pressed.emit()
			break
	await shot("conquest_open")
	for child in panel._drawer_body.get_children():
		if child is Button and child.text.begins_with("征服奖励"):
			child.pressed.emit()
			break
	# Isolate the existing task controls in active/automatic and active/manual
	# visual states without submitting a gameplay command.
	panel.set_process(false)
	panel._snapshot.running = true
	panel._snapshot.automatic = true
	panel._snapshot.duration = 120.0
	panel._snapshot.elapsed = 45.0
	panel._update_task()
	await shot("running_automatic")
	panel._snapshot.automatic = false
	panel._update_task()
	await shot("running_manual")
	panel._visual.set_exploration(true, 240, 20.0)
	panel._visual.advance(2.0, false)
	await shot("scout_separate")
	if session.save_files != null: session.save_files.close(2000)
	game.queue_free()
	await process_frame
	quit()
