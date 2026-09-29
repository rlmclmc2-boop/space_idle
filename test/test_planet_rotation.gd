extends SceneTree
var failures := 0
var background_draws := 0
var globe_draws := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2048, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen := TextureRect.new()
	screen.texture = viewport.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	var scene = load("res://scripts/main.gd").new()
	scene.automation_args = ["--capture"]
	viewport.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.paused = true
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared = range(1, 31)
	scene.game.profile.highestLevel = 30
	scene.refresh_structure()
	scene.equipment_tabs.current_tab = 6
	scene.planet_panel.refresh()
	var card: Dictionary = scene.planet_panel.cards["1"]
	var visual = card.visual
	var globe = visual.globe
	visual.set_exploration(true, 0)
	await process_frame
	await process_frame
	visual.background_layer.draw.connect(func():background_draws += 1)
	globe.draw.connect(func():globe_draws += 1)
	var initial_nodes := get_node_count()
	var start_phase: Vector2 = globe.phases
	var start := Time.get_ticks_usec()
	var last := start
	var capture := 0
	var frames := 0
	var frame_times: Array[float] = []
	while Time.get_ticks_usec() - start < 20000000:
		await process_frame
		var now := Time.get_ticks_usec()
		var delta := float(now - last) / 1000000.0
		last = now
		visual.advance(delta, false)
		frames += 1
		frame_times.append(delta * 1000.0)
		if float(now - start) / 1000000.0 >= capture * 10.0:
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png("res://.runtime/rotation-%02d.png" % (capture * 10))
			capture += 1
	check(globe.phases.x > start_phase.x + 0.05, "Surface visibly advances over twenty seconds")
	check(globe.phases.y > globe.phases.x, "Independent clouds rotate at differential speed")
	check(is_zero_approx(globe.rotation), "Sphere quad never rotates")
	check(get_node_count() == initial_nodes, "Animation allocates no nodes")
	check(background_draws == 0 and globe_draws == 0, "Static background and sphere quad never redraw during rotation")
	var frozen: Vector2 = globe.phases
	var writes: int = globe.parameter_writes
	scene.equipment_tabs.current_tab = 5
	visual.advance(1.0, false)
	globe.advance(1.0, false)
	check(globe.phases == frozen and globe.parameter_writes == writes, "Hidden page freezes surface and cloud uniforms")
	scene.equipment_tabs.current_tab = 6
	visual.advance(1.0, true)
	check(globe.phases == frozen, "Pause freezes rotation")
	visual.advance(0.1, false)
	check(globe.phases.x > frozen.x and globe.phases.x < frozen.x + 0.001, "Reveal resumes without time jump")
	globe.phases = Vector2(0.99999, 0.99999)
	globe.advance(0.1)
	check(globe.phases.x < 0.001 and globe.phases.y < 0.001, "Phases wrap without accumulated precision loss")
	frame_times.sort()
	print("Rotation: failures=%d frames=%d mean_ms=%.2f p95_ms=%.2f nodes=%d background_redraws=%d sphere_redraws=%d" % [failures, frames, 20000.0 / frames, frame_times[int(frame_times.size()*0.95)], initial_nodes, background_draws, globe_draws])
	quit(1 if failures else 0)
