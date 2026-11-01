extends SceneTree
const OUT := "/tmp/space-idle-runtime472/planet-subject-clearance/"
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
	await click(game.planet_scene._facility_button)
	assert(game.planet_scene._open_section == "facilities")
	print("SUBJECT facilities=",game.planet_scene._visual.get_rect()," dock=",game.planet_scene._drawer.get_rect())
	await shot("planet-facilities.png")
	await click(game.planet_scene._crew_button)
	assert(game.planet_scene._open_section == "crew")
	print("SUBJECT crew=",game.planet_scene._visual.get_rect()," dock=",game.planet_scene._drawer.get_rect())
	await shot("planet-crew.png")
	await click(game.planet_scene._task_button)
	assert(game.planet_scene._open_section == "exploration")
	await shot("planet-exploration.png")
	for child in game.planet_scene._drawer_body.get_children():
		if child is Button and child.text.begins_with("征服奖励"):
			await click(child)
			break
	await frames(5)
	assert(game.planet_scene._conquest_open)
	print("SUBJECT conquest=",game.planet_scene._visual.get_rect()," dock=",game.planet_scene._drawer.get_rect())
	await shot("planet-conquest-expanded.png")
	var scroll = game.planet_scene._drawer_scroll
	if scroll.get_v_scroll_bar().visible:
		for i in 8:
			var event := InputEventMouseButton.new()
			event.position = scroll.get_global_rect().get_center()
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN
			event.pressed = true
			Input.parse_input_event(event)
			event = event.duplicate()
			event.pressed = false
			Input.parse_input_event(event)
			await frames(2)
		assert(scroll.scroll_vertical > 0)
		await shot("planet-conquest-scroll.png")
	print("DOCK before_close section=",game.planet_scene._open_section," rect=",game.planet_scene._task_button.get_global_rect())
	await click(game.planet_scene._task_button)
	print("DOCK after_close section=",game.planet_scene._open_section," hovered=",game.planet_scene._task_button.is_hovered())
	await shot("planet-closed.png")
	assert(game.planet_scene._open_section.is_empty())
	await click(game.planet_scene.world_planet_picker)
	assert(game.planet_scene.world_planet_picker.get_popup().visible)
	await shot("planet-picker-open.png")
	game.planet_scene.world_planet_picker.get_popup().hide()
	await frames(3)
	game._zone_shell._route_buttons["equipment"].pressed.emit()
	await frames(5)
	await shot("equipment-return.png")
	print("PLANET_COMMON_CONTROLS actual_mouse_tabs=facilities,crew,exploration,closed picker_click_open=true route_equipment=true")
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
