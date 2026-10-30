extends SceneTree
const OUT := "/tmp/planet-stellar-plasma-r2"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440, 900)
	assert(GDExtensionManager.load_extension("/tmp/planet-native-472/planet.gdextension") == GDExtensionManager.LOAD_STATUS_OK)
	var game = load("res://src/main.gd").new()
	root.add_child(game)
	await process_frame
	assert(game.startup_error.is_empty())
	game.set_process(false)
	game._skip_tutorial = true
	var session = game.session
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json"))
	var saved: Dictionary = session.campaign_system.save_state()
	for row in config.unlock.unlock: saved.grants[str(row.type) + ":" + str(row.target)] = true
	assert(session.campaign_system.restore_state(saved).ok)
	var planets: Dictionary = session.planet_system.save_state()
	for id in planets.planets:
		var state: Dictionary = planets.planets[id]
		state.conquered = true
		state.exploration = 240
		for key in state.buildings:
			state.buildings[key].state = "built"
			for candidate in config.planet_build.planet_build:
				if str(candidate.id) == key: state.buildings[key].work = int(candidate.build_explore)
	assert(session.planet_system.restore_state(planets).ok)
	session.planet_system.refresh_availability(session.campaign_system.available)
	game._sync_guidance()
	game._refresh_feature_visibility()
	game._left_buttons.planet.pressed.emit()
	var panel = game.planet_scene
	panel.refresh()
	await process_frame
	await process_frame
	print("AVAILABLE ", panel.world_planet_picker.item_count, " system=", session.planet_system.planet_options().size())
	assert(panel.world_planet_picker.item_count == 6)
	for index in range(2, 4):
		var id := str(index + 1)
		panel.select_planet(id)
		for i in 150:
			await process_frame
			if panel._visual.planet_id == id and not panel._visual.preparing: break
		assert(panel._visual.planet_id == id and not panel._visual.preparing)
		await create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT.path_join("type_%s.png" % id))
		print("TYPE ",id," name=",panel._snapshot.row.name," radius=",panel._visual._body_radius()," extent=",panel._visual.globe.extent," facilities=",panel._visual.facilities.size()," visual=",panel._visual.appearance.keys())
		if id == "4":
			panel._facility_button.pressed.emit()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT.path_join("type_4_open.png"))
			panel._facility_button.pressed.emit()
	if session.save_files != null: session.save_files.close(2000)
	game.queue_free()
	await process_frame
	quit()
