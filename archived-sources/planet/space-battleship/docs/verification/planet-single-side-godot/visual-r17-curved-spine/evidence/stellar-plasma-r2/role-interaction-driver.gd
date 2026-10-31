extends SceneTree
const OUT := "/tmp/planet-role-interaction-r2"
var game
var session
var panel
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT.path_join(name + ".png"))
func click_at(viewport: Viewport, point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	viewport.push_input(move, true)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		viewport.push_input(event, true)
		await process_frame
func click(control: Control) -> void:
	assert(is_instance_valid(control) and control.visible and not control.disabled)
	await click_at(root, control.get_global_rect().get_center())
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440, 900)
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
	for row in config.unlock.unlock: saved.grants[str(row.type) + ":" + str(row.target)] = true
	assert(session.campaign_system.restore_state(saved).ok)
	session.crew_system.refresh_availability(session.campaign_system.available)
	var planets: Dictionary = session.planet_system.save_state()
	var first: Dictionary = planets.planets["1"]
	first.exploration = 240
	first.conquered = true
	for key in ["station", "refinery", "workshop", "shipyard"]:
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
	await shot("closed")
	await click(panel._facility_button)
	print("OPEN_FACILITIES ", panel._open_section)
	assert(panel._open_section == "facilities")
	await shot("facilities")
	await click(panel._drawer_box.get_child(0).get_child(1))
	assert(panel._open_section.is_empty())
	await shot("closed_after_facilities")
	await click(panel._crew_button)
	print("OPEN_CREW ", panel._open_section, " member=", panel._member_picker.item_count, " assignment=", panel._assignment_picker.item_count)
	assert(panel._open_section == "crew")
	await shot("crew")
	var member_id: String = str(panel._member_picker.get_item_metadata(panel._member_picker.selected))
	var assign_button: Button
	for child in panel._drawer_body.get_children():
		if child is Button and child.text == "派遣": assign_button = child
	assert(assign_button != null)
	await click(assign_button)
	var assigned: Dictionary = session.crew_system.member_facts([member_id])[0]
	print("ASSIGNED ", assigned.kind, " target=", assigned.target)
	assert(assigned.kind == "planet_explore" and assigned.target == "1")
	await shot("crew_assigned")
	await click(panel._drawer_box.get_child(0).get_child(1))
	assert(panel._open_section.is_empty())
	await click(panel._task_button)
	assert(panel._open_section == "exploration")
	await shot("exploration")
	print("AUTO_AVAILABLE ", not panel._auto_button.disabled)
	assert(not panel._auto_button.disabled)
	await click(panel._auto_button)
	print("AUTO_ENABLED ", panel._snapshot.automatic)
	assert(panel._snapshot.automatic)
	await shot("automatic_enabled")
	game.set_process(true)
	await create_timer(0.8).timeout
	print("TASK_RUNNING ", panel._snapshot.running, " stop=", panel._stop_button.visible, " cancel=", panel._cancel_button.visible)
	if panel._snapshot.running:
		await shot("running_real")
		assert(panel._stop_button.visible and panel._cancel_button.visible)
		await click(panel._stop_button)
		print("AUTO_STOPPED ", panel._snapshot.automatic, " running=", panel._snapshot.running)
		assert(not panel._snapshot.automatic)
		await click(panel._cancel_button)
		print("CANCELLED ", panel._snapshot.running)
		assert(not panel._snapshot.running)
		await shot("cancelled_real")
	game.set_process(false)
	var reward_button: Button
	for child in panel._drawer_body.get_children():
		if child is Button and child.text.begins_with("征服奖励"): reward_button = child
	assert(reward_button != null)
	await click(reward_button)
	print("OPEN_REWARDS ", panel._conquest_open)
	assert(panel._conquest_open)
	await shot("conquest")
	await click(panel._drawer_box.get_child(0).get_child(1))
	assert(panel._open_section.is_empty())
	print("PLANET_ITEMS ", panel.world_planet_picker.item_count, " selected=", panel.world_planet_picker.selected)
	await shot("closed_after_exploration")
	assert(panel.world_planet_picker.item_count > 1)
	await click(panel.world_planet_picker)
	var popup: PopupMenu = panel.world_planet_picker.get_popup()
	print("PLANET_POPUP ", popup.visible, " items=", popup.item_count)
	assert(popup.visible)
	print("POPUP_SIZE ", popup.size, " disabled1=", popup.is_item_disabled(1), " focus=", popup.has_focus())
	assert(not popup.is_item_disabled(1))
	popup.set_focused_item(1)
	popup.grab_focus()
	await process_frame
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = down
		key.window_id = popup.get_window_id()
		Input.parse_input_event(key)
		await process_frame
	print("SWITCHED ", panel._selected_id, " picker=", panel.world_planet_picker.selected, " popup=", popup.visible)
	assert(panel.world_planet_picker.selected == 1)
	if popup.visible: popup.hide()
	root.grab_focus()
	for i in 120:
		if panel._visual.planet_id == "2" and not panel._visual.preparing: break
		await process_frame
	print("SECOND_READY ", panel._visual.planet_id, " preparing=", panel._visual.preparing)
	assert(panel._visual.planet_id == "2" and not panel._visual.preparing)
	await create_timer(0.7).timeout
	print("SECOND_UI ", panel._selected_id, " picker=", panel.world_planet_picker.selected, " name=", panel.world_planet_picker.get_item_text(panel.world_planet_picker.selected), " exploration=", panel._snapshot.exploration, " line=", panel._task_line.text)
	await shot("second_planet")
	if session.save_files != null: session.save_files.close(2000)
	game.queue_free()
	await process_frame
	quit()
