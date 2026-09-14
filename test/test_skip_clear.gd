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
	root.add_child(scene)
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
	scene.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://skip-clear.png")
	# Deferred UI rebuild may replace the button; find the current instance.
	for child in scene.ui.get_children():
		if child is Button and child.text == "立即过关":
			child.pressed.emit()
	check(g.stage == 2 and g.state == BattleGame.State.TRAVEL, "Button immediately advances")
	check(not g.advance_after_clear() and g.stage == 2, "Repeated click cannot skip another stage")
	g.select_loop_level(1)
	g.spawn_group()
	g.toggle_loop()
	g.clear_level()
	g.acknowledge_unlocks()
	check(g.advance_after_clear() and g.stage == 2 and not g.profile.loop, "Immediate advance leaves guard for next stage")
	g.clear_level()
	g.acknowledge_unlocks()
	g.tick(float(g.db.defaults.loopDelay)+0.1)
	check(g.state == BattleGame.State.TRAVEL and g.stage == 3, "Automatic countdown still advances")
	print("Skip clear: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
