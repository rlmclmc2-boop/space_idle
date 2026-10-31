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
	var appearance := {"radiusScale": 1.0, "axisRatio": 1.0, "atmosphereColor": "5ac8f0"}
	var entries := []
	for kind in ["auto_explore", "refinery", "equipment", "shipyard"]:
		entries.append({"type": kind, "owned": true})
	visual.configure("1", {"visual": appearance, "visualFacilities": [entries[0]]})
	for i in 20: await process_frame
	var clock := deg_to_rad(70.0) / 0.045
	for count in [1, 4]:
		visual.configure("1", {"visual": appearance, "visualFacilities": entries.slice(0, count)})
		visual.phase = clock
		visual.architecture.update_pose(clock, 0.0, visual._body_radius())
		for i in 8: await process_frame
		viewport.get_texture().get_image().save_png("/tmp/planet-refinery-heatwell/planet-pressure-joint-side70-%d.png" % count)
	quit()
