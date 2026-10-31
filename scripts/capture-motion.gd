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
	var entries := []
	for kind in ["auto_explore", "refinery", "equipment", "shipyard"]:
		entries.append({"type": kind, "owned": true})
	var appearance := {"radiusScale": 1.0, "axisRatio": 1.0, "atmosphereColor": "5ac8f0"}
	visual.configure("1", {"visual": appearance, "visualFacilities": entries})
	for i in 20: await process_frame
	visual.phase = 0.0
	visual.architecture.update_pose(0.0, 0.0, visual._body_radius())
	for frame in 25:
		if frame > 0: visual.advance(0.25, false)
		for i in 2: await process_frame
		viewport.get_texture().get_image().save_png("/tmp/planet-station-saucer-%03d.png" % frame)
	quit()
