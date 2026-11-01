extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	var main: Node2D = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await process_frame
	if main.startup_error != "":
		push_error(main.startup_error)
		quit(2)
		return
	var planet = main.session.planet_system
	planet._available["1"] = true
	main.session.campaign_system._grants["planet:1"] = true
	for key in planet._state["1"].buildings:
		planet._state["1"].buildings[key] = {"state": "built", "work": int(planet._buildings[key].build_explore)}
	planet._facility_fact_cache.clear()
	main._set_page("growth")
	main._left_module = "planet"
	main._refresh_left_module()
	main.equipment_scene.visible = false
	main.reactor_scene.visible = false
	main.planet_scene.visible = true
	main.planet_scene.select_planet("1")
	for i in 36: await process_frame
	main._guidance_panel.hide()
	main._skip_tutorial = true
	main._sync_guidance()
	main._save_warning.hide()
	for node in main.find_children("*", "Button", true, false):
		if node.text == "关闭面板":
			print("CLOSE_PANEL_PARENT ", node.get_parent().get_path(), " ", node.get_parent().get_class())
			node.emit_signal("pressed")
	for i in 4: await process_frame
	main.planet_scene._facility_button.emit_signal("pressed")
	for i in 5: await process_frame
	if main.planet_scene._open_section != "facilities":
		push_error("Facility drawer did not open")
		quit(3)
		return
	var count: int = main.planet_scene.world_building_picker.item_count
	if count != 4:
		push_error("Expected four facility facts, got %d" % count)
		quit(4)
		return
	for index in count:
		var picker = main.planet_scene.world_building_picker
		var target: String = str(picker.get_item_metadata(index))
		picker.emit_signal("item_selected", index)
		for i in 3: await process_frame
		if main.planet_scene._selected_facility != target:
			push_error("Facility selection failed: " + target)
			quit(5)
			return
		print("FACILITY_SELECTED ", target)
	root.get_texture().get_image().save_png("/tmp/planet-v20-page.png")
	quit()
