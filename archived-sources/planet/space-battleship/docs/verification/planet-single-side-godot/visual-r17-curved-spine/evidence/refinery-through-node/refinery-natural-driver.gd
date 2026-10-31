extends SceneTree
const OUT := "/tmp/planet-refinery-through-natural"
const WALL_SECONDS := 8.0
const SAMPLE_SECONDS := 1.0 / 7.0
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
	for state in planets.planets.values():
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
	for id in ["1"]:
		panel.set_process(true)
		panel.select_planet(id)
		panel.refresh()
		for i in 150:
			await process_frame
			if panel._visual.planet_id == id and not panel._visual.preparing: break
		assert(panel._visual.planet_id == id and not panel._visual.preparing)
		panel.set_process(false)
		var visual = panel._visual
		DirAccess.make_dir_recursive_absolute(OUT.path_join("type_" + id))
		await RenderingServer.frame_post_draw
		var began := Time.get_ticks_usec()
		var last := began
		var next_sample := 0.0
		var index := 0
		var stamps: Array = []
		while true:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			var elapsed := float(now - began) / 1000000.0
			var dt := float(now - last) / 1000000.0
			last = now
			visual.advance(dt, false)
			if elapsed < next_sample: continue
			assert(root.get_texture().get_image().save_jpg(OUT.path_join("type_%s/frame_%03d.jpg" % [id,index]), 0.92) == OK)
			stamps.append({"frame":index,"wall_seconds":elapsed,"ring_phase":visual.phase,"surface_phase":visual.globe.phases.x,"surface_clock":visual.globe.visual_clock,"body_radius":visual._body_radius()})
			index += 1
			next_sample += SAMPLE_SECONDS
			if elapsed >= WALL_SECONDS: break
		var file := FileAccess.open(OUT.path_join("type_%s-timestamps.json" % id), FileAccess.WRITE)
		file.store_string(JSON.stringify({"wall_target_seconds":WALL_SECONDS,"sampling_target_seconds":SAMPLE_SECONDS,"frames":stamps}, "  "))
		file.close()
		print("DYNAMIC ",id," frames=",index," wall=",stamps[-1].wall_seconds," phase=",stamps[-1].ring_phase)
	if session.save_files != null: session.save_files.close(2000)
	game.queue_free()
	await process_frame
	quit()
