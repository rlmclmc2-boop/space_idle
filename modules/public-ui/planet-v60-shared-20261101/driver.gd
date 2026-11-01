extends SceneTree
const OUT := "/tmp/space-idle-runtime472/planet-v60-shared/"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name)
func run() -> void:
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	var game = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	await frames(90)
	assert(game.startup_error.is_empty())
	game.set_process(false)
	game._skip_tutorial = true
	var session = game.session
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json"))
	var saved: Dictionary = session.campaign_system.save_state()
	for row in config.unlock.unlock: saved.grants[str(row.type) + ":" + str(row.target)] = true
	assert(session.campaign_system.restore_state(saved).ok)
	session.crew_system.refresh_availability(session.campaign_system.available)
	var planets: Dictionary = session.planet_system.save_state().duplicate(true)
	var first: Dictionary = planets.planets["1"]
	first.exploration = 240
	first.conquered = true
	for key in ["station", "refinery", "workshop", "shipyard"]:
		first.buildings[key].state = "built"
		for candidate in config.planet_build.planet_build:
			if str(candidate.id) == key: first.buildings[key].work = int(candidate.build_explore)
	assert(session.planet_system.restore_state(planets).ok)
	session.planet_system.refresh_availability(session.campaign_system.available)
	var pending: Dictionary = session.pending_guidance()
	while not pending.is_empty():
		assert(session.dismiss_guidance(str(pending.kind), str(pending.id)).ok)
		pending = session.pending_guidance()
	game._sync_guidance()
	game._refresh_feature_visibility()
	assert(game._zone_shell.is_route_available("planet"))
	game._zone_shell._route_buttons["planet"].pressed.emit()
	await frames(12)
	assert(game.planet_scene.visible and not game.equipment_scene.visible and not game.reactor_scene.visible)
	assert(game._zone_shell._active_route == "planet")
	assert(not game.planet_scene._wallet.visible)
	game.planet_scene.select_planet("1")
	await frames(12)
	await shot("planet-overview.png")
	var closed_start: int=Engine.get_process_frames()
	await frames(180)
	await RenderingServer.frame_post_draw
	var closed_file=FileAccess.open(OUT+"closed-movie-segment.json",FileAccess.WRITE)
	closed_file.store_string(JSON.stringify({"start_process_frame":closed_start,"end_process_frame":Engine.get_process_frames(),"fps":30,"speed":1,"simulated_seconds":6,"method":"Godot MovieMaker fixed30fps offline; closed overview shared subject fit"},"  "));closed_file.close()
	await shot("planet-overview-after-motion.png")
	await click(game.planet_scene._facility_button)
	var picker: OptionButton = game.planet_scene.world_building_picker
	for i in picker.item_count:
		if str(picker.get_item_metadata(i)) == "workshop":
			picker.select(i)
			picker.item_selected.emit(i)
			break
	await frames(5)
	await shot("planet-facilities.png")
	await record_motion(6.0)
	await click(game.planet_scene._crew_button)
	await shot("planet-crew.png")
	await click(game.planet_scene._task_button)
	for child in game.planet_scene._drawer_body.get_children():
		if child is Button and child.text.begins_with("征服奖励"):
			await click(child)
			break
	await frames(5)
	await shot("planet-conquest-expanded.png")
	print("V60_SHARED_CAPTURE source=be3a2b93 public-panel=host-safe-region scenes=overview,workshop,crew,conquest-expanded")
	if session.save_files != null: session.save_files.close(2000)
	game.queue_free()
	await frames(3)
	quit()

func click(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	Input.parse_input_event(motion)
	await frames(2)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = motion.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await frames(3)

func record_motion(_seconds: float) -> void:
	var first := Engine.get_process_frames()
	await frames(180)
	await RenderingServer.frame_post_draw
	var f := FileAccess.open(OUT + "movie-segment.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"start_process_frame":first,"end_process_frame":Engine.get_process_frames(),"fps":30,"speed":1,"simulated_seconds":6,"method":"Godot MovieMaker fixed30fps offline; full shared main scene"},"  "))
	f.close()
