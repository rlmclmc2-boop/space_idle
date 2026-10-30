extends SceneTree

const OUT := "/tmp/planet-natural-motion-final"
const WALL_SECONDS := 32.0
const SAMPLE_SECONDS := 1.0 / 12.0
var game
var session
var panel

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(OUT.path_join("frames"))
	root.size = Vector2i(1440,900)
	assert(GDExtensionManager.load_extension("/tmp/planet-native-472/planet.gdextension") == GDExtensionManager.LOAD_STATUS_OK)
	game = load("res://src/main.gd").new()
	root.add_child(game)
	await process_frame
	assert(game.startup_error.is_empty())
	game.set_process(false)
	game._skip_tutorial = true
	session = game.session
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json"))
	var saved: Dictionary = session.campaign_system.save_state()
	for row in config.unlock.unlock:
		saved.grants[str(row.type)+":"+str(row.target)] = true
	assert(session.campaign_system.restore_state(saved).ok)
	session.crew_system.refresh_availability(session.campaign_system.available)
	var planets: Dictionary = session.planet_system.save_state()
	var first: Dictionary = planets.planets["1"]
	first.exploration = 240
	first.conquered = true
	for key in ["station","refinery","workshop","shipyard"]:
		first.buildings[key].state = "built"
		for candidate in config.planet_build.planet_build:
			if str(candidate.id) == key: first.buildings[key].work = int(candidate.build_explore)
	assert(session.planet_system.restore_state(planets).ok)
	session.planet_system.refresh_availability(session.campaign_system.available)
	game._sync_guidance()
	game._refresh_feature_visibility()
	game._left_buttons.planet.pressed.emit()
	panel = game.planet_scene
	panel.select_planet("1")
	panel.refresh()
	await create_timer(0.5).timeout
	# Keep the game and planet panel fixture still, then advance only the visual
	# by actual elapsed wall time. This prevents a later panel refresh from
	# resetting the scout to the fixture's non-exploring save state.
	panel.set_process(false)
	var visual = panel._visual
	visual.set_exploration(true,240,20.0)
	visual.advance(0.05,false)
	await RenderingServer.frame_post_draw
	var stamps: Array = []
	var began := Time.get_ticks_usec()
	var last_advance := began
	var next_sample := 0.0
	var index := 0
	while true:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		var elapsed := float(now - began) / 1000000.0
		var step := float(now - last_advance) / 1000000.0
		last_advance = now
		if elapsed < next_sample:
			visual.advance(step,false)
			continue
		var image := root.get_texture().get_image()
		assert(image.save_jpg(OUT.path_join("frames/frame_%03d.jpg" % index),0.95) == OK)
		var parts := {}
		for kind in visual.architecture._owned:
			var moving := {}
			for label in visual.architecture._parts[kind]:
				var node: Node3D = visual.architecture._parts[kind][label]
				moving[label] = {"position":str(node.position),"rotation":str(node.rotation)}
			parts[kind] = moving
		stamps.append({"frame":index,"wall_seconds":elapsed,"visual_phase":visual.phase,"surface_phase":visual.globe.phases.x,"scout_age":visual.exploration_age,"scout_front":visual._scout_in_front(),"parts":parts})
		if index % 30 == 0: print("NATURAL ",index," wall=",elapsed," phase=",visual.phase," surface=",visual.globe.phases.x)
		index += 1
		next_sample += SAMPLE_SECONDS
		if elapsed >= WALL_SECONDS: break
		visual.advance(step,false)
	var file := FileAccess.open(OUT.path_join("timestamps.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"wall_target_seconds":WALL_SECONDS,"sampling_target_seconds":SAMPLE_SECONDS,"frames":stamps},"  "))
	file.close()
	if session.save_files != null: session.save_files.close(2000)
	game.queue_free()
	await process_frame
	quit()
