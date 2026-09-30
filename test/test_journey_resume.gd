extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func restore(g: BattleGame) -> BattleGame:
	g.save_enabled = true
	g.save_progress()
	var loaded := BattleGame.new(g.db, true)
	loaded.resume_progress()
	return loaded

func run() -> void:
	var db := ShipDatabase.new()
	db.config.offlineMax = 0
	for i in 3:
		db.levels[i].length = 1000
		db.levels[i].groups = [{"id":1,"position":0.1},{"id":1,"position":0.3},{"id":1,"position":0.9}]
	var g := BattleGame.new(db, false)
	g.profile.cleared = [1,2]
	g.rebuild_unlocks()
	g.start(2, false)
	g.group_index = 1
	g.distance = 220
	var loaded := restore(g)
	check(loaded.stage == 2 and loaded.group_index == 1 and loaded.distance == 220 and loaded.state == BattleGame.State.TRAVEL, "Cruise restores selected stage, completed nodes and distance instead of highest stage")
	loaded = restore(loaded)
	check(loaded.distance == 220 and loaded.group_index == 1, "Repeated manual save preserves checkpoint")
	g.spawn_group()
	g.enemies[0].hp = 1
	g.cooldowns["weapons_0"] = 123
	loaded = restore(g)
	check(loaded.stage == 2 and loaded.group_index == 2 and loaded.distance == 300 and loaded.state == BattleGame.State.COMBAT, "Combat resumes same node")
	check(not loaded.targets().is_empty() and loaded.enemies[0].hp == loaded.enemies[0].max_hp and loaded.projectiles.is_empty() and loaded.cooldowns.get("weapons_0", 0) != 123, "Combat entities and cooldowns start fresh")
	g.start(3, false)
	g.group_index = 1
	g.distance = 250
	loaded = restore(g)
	check(loaded.stage == 3 and loaded.distance == 250, "Uncleared current stage restores")
	check(loaded.select_loop_level(3) and loaded.distance == 0 and loaded.group_index == 0 and not loaded.profile.loop, "Warp to current uncleared stage resets progress")
	loaded.distance = 200
	check(loaded.select_loop_level(3) and loaded.distance == 0, "Repeat warp to same stage resets again")
	check(not loaded.select_loop_level(4), "Warp rejects other uncleared stage")
	loaded = restore(loaded)
	check(loaded.stage == 3 and loaded.distance == 0, "Warp origin replaces previous checkpoint on disk")
	g.start(2, false)
	g.group_index = 2
	g.spawn_group()
	g.clear_level()
	g.pending_unlocks.assign([str(g.profile.unlocked[0])])
	loaded = restore(g)
	check(loaded.state == BattleGame.State.LEVEL_CLEAR and loaded.group_index == 3 and loaded.distance == 900, "Cleared final node remains cleared")
	check(loaded.pending_unlocks == g.pending_unlocks and not loaded.advance_after_clear(), "Reload preserves unacknowledged unlock gate")
	g.toggle_loop()
	loaded = restore(g)
	check(loaded.state == BattleGame.State.LEVEL_CLEAR and loaded.guarding_here() and loaded.pending_unlocks == g.pending_unlocks, "Final-node guard preserves clear state and unlock confirmation")
	loaded.acknowledge_unlocks()
	loaded.tick(loaded.guard_interval())
	check(loaded.state == BattleGame.State.COMBAT and loaded.group_index == 3 and loaded.distance == 900, "Restored final-node guard repeats same node after confirmation")
	g.start(2, false)
	g.group_index = 1
	g.spawn_group()
	g.toggle_loop()
	loaded = restore(g)
	check(loaded.guarding_here() and loaded.group_index == 2 and loaded.distance == 300, "Guard remains at its node")
	g.toggle_loop()
	g.distance = 210
	g.group_index = 1
	g.change_state(BattleGame.State.TRAVEL)
	g.toggle_loop()
	loaded = restore(g)
	check(loaded.profile.loop and not loaded.guarding_here() and loaded.distance == 210, "Armed guard resumes journey before destination")
	g.set_guard_death(0)
	g.begin_retreat()
	var target := g.retreat_target
	loaded = restore(g)
	check(loaded.stage == g.stage and loaded.distance == target and loaded.state == BattleGame.State.RETREAT, "Retreat reload preserves target instead of defeated position")
	loaded.tick(float(db.defaults.get("deathRetreatDuration", 1.2)))
	check(loaded.distance == target and loaded.state == BattleGame.State.TRAVEL, "Restored retreat completes normally")
	for mode in [1,2]:
		g.start(2, false)
		g.spawn_group()
		g.toggle_loop()
		g.set_guard_death(mode)
		g.db.config.backRange = 150
		g.begin_retreat()
		loaded = restore(g)
		loaded.tick(float(db.defaults.get("deathRetreatDuration", 1.2)))
		check(loaded.stage == 1 and loaded.distance == 950 and loaded.profile.loop, "Cross-stage guarded retreat restores destination mode %s" % mode)
		if mode == 1:
			check(loaded.retreat_boss_pending and loaded.profile.guardStage == 2 and not loaded.guarding_here(), "Return guard retains future destination and prior boss replay")
		else:
			check(loaded.guarding_here() and loaded.profile.guardStage == 1 and not loaded.retreat_boss_pending, "Stay guard anchors at restored retreat point")
	var raw := g.fresh_profile()
	raw.cleared = [1,2]
	for bad in [{}, {"stage":99,"groupIndex":1,"distance":20,"state":2}, {"stage":2,"groupIndex":99,"distance":20,"state":2}, {"stage":2,"groupIndex":1,"distance":-1,"state":2}, {"stage":2,"groupIndex":0,"distance":20,"state":3}]:
		raw.journey = bad
		var file := FileAccess.open(BattleGame.SAVE_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify(raw))
		file.close()
		loaded = BattleGame.new(db, true)
		loaded.resume_progress()
		check(loaded.stage == 3 and loaded.group_index == 0 and loaded.distance == 0, "Missing/invalid checkpoint safely uses legacy startup")
	# Exercise actual scene startup and QA reload using isolated user data.
	change_scene_to_file("res://main.tscn")
	await scene_changed
	current_scene.set_process(false)
	current_scene.game.start(2, false)
	current_scene.game.group_index = 1
	current_scene.game.spawn_group()
	current_scene.game.paused = true
	var saved_distance: float = current_scene.game.distance
	current_scene.manual_save()
	var saved_bytes := FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)
	current_scene.game.start(1,false)
	current_scene._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var exited := BattleGame.new(current_scene.db, true)
	exited.resume_progress()
	check(FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==saved_bytes and exited.stage == 2 and exited.group_index == 2 and exited.distance == saved_distance, "Window close leaves the last manually saved node unchanged")
	current_scene.show_qa_tools()
	var panel := root.get_node("QATools")
	var previous := current_scene.get_instance_id()
	panel.restart_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 10000
	while panel.restarting and Time.get_ticks_msec() < deadline:
		await process_frame
	current_scene.set_process(false)
	check(FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==saved_bytes and current_scene.get_instance_id() != previous and current_scene.game.stage == 2 and current_scene.game.group_index == 2 and current_scene.game.distance == saved_distance, "Actual QA restart reads the previous manual checkpoint without saving unsaved progress")
	print("Journey resume: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
