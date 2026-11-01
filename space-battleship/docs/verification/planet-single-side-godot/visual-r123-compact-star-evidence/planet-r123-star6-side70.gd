extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2048, 768)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var visual: Control = load("res://scripts/planet_visual.gd").new()
	visual.size = Vector2(2048, 768)
	viewport.add_child(visual)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json"))
	var appearance: Dictionary = JSON.parse_string(str(config["planet"]["planet"][5]["visual"]))
	var entries := []
	for kind in ["auto_explore", "refinery", "equipment", "shipyard"]:
		entries.append({"type": kind, "owned": true})
	visual.configure("6", {"visual": appearance, "visualFacilities": [entries[0]]})
	for i in 20: await process_frame
	var clock := deg_to_rad(70.0) / 0.045
	for count in [1, 4]:
		visual.configure("6", {"visual": appearance, "visualFacilities": entries.slice(0, count)})
		visual.phase = clock
		visual.architecture.update_pose(clock, 0.0, visual._body_radius())
		for i in 8: await process_frame
		viewport.get_texture().get_image().save_png("/tmp/planet-r123-star6-side70-%d.png" % count)
	quit()
