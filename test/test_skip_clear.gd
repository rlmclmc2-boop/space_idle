extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	var g: BattleGame = scene.game
	g.save_enabled = false
	g.start(1,false)
	check(not g.advance_after_clear(), "Cannot skip active stage")
	g.clear_level()
	g.pending_unlocks.assign(["laser"])
	check(not g.advance_after_clear(), "Unlock acknowledgment is preserved")
	g.tick(1.0)
	check(is_equal_approx(g.clear_timer,3.0), "Unlock acknowledgment pauses the countdown")
	g.acknowledge_unlocks()
	scene.build_ui()
	var skip: Button
	for child in scene.ui.get_children():
		if child is Button and child.text == "立即过关":
			skip = child
	check(skip != null and is_equal_approx(g.clear_timer,3.0), "Button starts a three-second countdown")
	await process_frame
	check(skip.get_global_rect().get_center().distance_to(scene.battle_clip.get_global_rect().get_center())<1.0, "Advance button stays at battlefield center")
	check(not skip.get_global_rect().intersects(scene.workspace_frame.get_global_rect()) and not skip.get_global_rect().intersects(scene.system_nav.get_global_rect()), "Advance button never covers system content or navigation")
	check(scene.advance_countdown_label.text=="3秒后自动过关" and is_zero_approx(scene.advance_progress.value), "Countdown and progress start together")
	g.tick(1.5)
	scene.refresh_navigation()
	check(scene.advance_countdown_label.text=="2秒后自动过关" and is_equal_approx(scene.advance_progress.value,1.5), "Countdown and progress follow game timer")
	g.paused = true
	g.tick(1.0)
	check(is_equal_approx(g.clear_timer,1.5), "Pause freezes the countdown")
	g.paused = false
	scene.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://skip-clear.png")
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=scene.advance_button.get_global_rect().get_center()*Vector2(root.size)/Vector2(2048,1280)
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
	check(g.stage == 2 and g.state == BattleGame.State.TRAVEL, "Button immediately advances")
	check(not g.advance_after_clear() and g.stage == 2, "Repeated click cannot skip another stage")
	g.select_loop_level(1)
	g.spawn_group()
	g.toggle_loop()
	g.clear_level()
	g.acknowledge_unlocks()
	scene.refresh_navigation()
	check(not g.first_clear and not scene.advance_button.visible and not scene.advance_countdown_label.visible and not scene.advance_progress.visible, "Replayed clear hides one-time advance controls")
	check(g.advance_after_clear() and g.stage == 2 and not g.profile.loop, "Immediate advance leaves guard for next stage")
	g.clear_level()
	while not g.pending_unlocks.is_empty():g.acknowledge_unlocks()
	scene.refresh_navigation()
	check(g.first_clear and scene.advance_button.visible and scene.advance_countdown_label.visible and scene.advance_progress.visible, "New stage shows one-time advance controls")
	check(is_equal_approx(g.clear_timer,3.0), "Next clear resets three-second countdown")
	g.tick(2.9)
	check(g.state == BattleGame.State.LEVEL_CLEAR and g.stage == 2, "Automatic advance waits for three seconds")
	g.tick(0.2)
	check(g.state == BattleGame.State.TRAVEL and g.stage == 3, "Automatic advance starts next stage after three seconds")
	print("Skip clear: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
