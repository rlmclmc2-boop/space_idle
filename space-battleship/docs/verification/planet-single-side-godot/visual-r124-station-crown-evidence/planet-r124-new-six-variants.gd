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
	var rows: Array = config["planet"]["planet"]
	var entries := []
	for kind in ["auto_explore", "refinery", "equipment", "shipyard"]:
		entries.append({"type": kind, "owned": true})
	for row in rows:
		var id := str(int(row["id"]))
		visual.configure(id, {"visual": row.get("visual", {}), "visualFacilities": entries})
		for frame in 120:
			await process_frame
			if visual.planet_id == id and not visual.preparing and visual.globe.visible:
				break
		visual.phase = 0.0
		if visual.architecture != null:
			visual.architecture.update_pose(0.0, 0.0, visual._body_radius())
		for frame in 12: await process_frame
		viewport.get_texture().get_image().save_png("/tmp/planet-r124-new-variant-%s.png" % id)
	quit()
