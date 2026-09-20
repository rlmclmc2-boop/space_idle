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
	var db := ShipDatabase.new()
	var g := BattleGame.new(db, false)
	g.profile.cleared = [1,2]
	g.rebuild_unlocks()
	g.start(3,false)
	g.distance = 100
	check(g.select_loop_level(3) and g.distance == 0, "Current uncleared stage can restart by warp")
	check(not g.select_loop_level(4), "Reject other uncleared stage")
	check(g.select_loop_level(2) and g.stage == 2, "Warp immediately enters selected cleared stage")
	g.toggle_loop()
	check(g.stage == 2 and g.profile.loop and not g.guarding_here(), "Enable arms next encounter")
	db.config.backRange = 300
	g.distance = 100
	g.begin_retreat()
	check(g.stage == 1 and g.retreat_target == float(db.levels[0].length)-200, "Cross boundary remaining distance")
	g.tick(2)
	check(g.distance == g.retreat_target and g.player.armour == g.stat("armour"), "Retreat finishes and heals")
	check(g.next_stage() == 2 and not g.profile.loop, "Default death cancels guard")
	g.tick(0.001)
	check(g.state == BattleGame.State.COMBAT and g.distance == 800, "Destination encounter replays")
	g.start(2,false)
	db.config.backRange = 125
	g.distance = 900
	g.begin_retreat()
	check(g.stage == 2 and g.retreat_target == 775, "Configured same-stage retreat")
	db.config.backRange = 0
	g.begin_retreat()
	check(g.retreat_target == 900, "Zero retreat distance")
	db.config.backRange = 300
	g.start(2,false)
	g.distance = 300
	g.begin_retreat()
	check(g.stage == 2 and g.retreat_target == 0, "Exact boundary stays in stage")
	g.start(1,false)
	g.distance = 100
	g.begin_retreat()
	check(g.stage == 1 and g.retreat_target == 0, "First stage clamps")
	g.start(2,false)
	g.distance = 250
	g.begin_retreat()
	g.tick(2)
	check(g.stage == 1 and g.distance == 950, "Retreat beyond prior boss preserves remaining distance")
	g.tick(0.001)
	check(g.state == BattleGame.State.COMBAT and g.distance == 950 and g.enemies.any(func(e):return e.boss), "Replay prior boss at retreat destination")
	g.save_enabled = true
	g.select_loop_level(2)
	g.toggle_loop()
	var loaded := BattleGame.new(db,true)
	check(loaded.profile.loop and loaded.profile.guardStage == 2, "Save restores guard destination")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	scene.game.save_enabled = false
	scene.game.profile.cleared = [1,2]
	scene.game.rebuild_unlocks()
	scene.game.start(3,false)
	scene.game.profile.erase("loopLevel")
	scene.build_ui()
	check(not scene.loop_button.disabled and scene.loop_select.item_count == 4 and scene.loop_select.get_item_index(3) >= 0, "Guard is independent of warp selector including current uncleared stage")
	scene.loop_select.select(2)
	scene.loop_select.item_selected.emit(2)
	scene.loop_button.pressed.emit()
	check(scene.game.stage == 2 and scene.game.profile.loop, "Actual selector and enable button")
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://loop-ui.png")
	scene.loop_button.pressed.emit()
	check(not scene.game.profile.loop, "Actual disable button")
	print("Loop/retreat: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
