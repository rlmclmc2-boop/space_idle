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
	g.acknowledge_unlocks()
	scene.build_ui()
	var skip: Button
	for child in scene.ui.get_children():
		if child is Button and child.text == "立即过关":
			skip = child
	check(skip != null and g.clear_timer > 0, "Button exists before countdown expires")
	await process_frame
	check(Rect2(30,100,552,98).encloses(skip.get_global_rect()), "Advance button stays in the left battlefield header")
	check(not skip.get_global_rect().intersects(scene.workspace_frame.get_global_rect()) and not skip.get_global_rect().intersects(scene.system_nav.get_global_rect()), "Advance button never covers system content or navigation")
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
	check(g.advance_after_clear() and g.stage == 2 and not g.profile.loop, "Immediate advance leaves guard for next stage")
	g.clear_level()
	while not g.pending_unlocks.is_empty():g.acknowledge_unlocks()
	g.tick(float(g.db.defaults.loopDelay)+0.1)
	check(g.state == BattleGame.State.TRAVEL and g.stage == 3, "Automatic countdown still advances")
	print("Skip clear: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
