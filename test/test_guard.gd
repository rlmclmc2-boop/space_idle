extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	call_deferred("run")
func fixture() -> BattleGame:
	var db := ShipDatabase.new()
	db.config.movement = 20
	db.config.backRange = 150
	db.levels[0].length = 1000
	db.levels[0].groups = [{"id":1,"position":0.1},{"id":1,"position":0.3},{"id":1,"position":0.9}]
	var g := BattleGame.new(db,false)
	g.profile.cleared = [1,2]
	g.rebuild_unlocks()
	g.start(1,false)
	return g
func empty_wave(g: BattleGame) -> void:
	for enemy in g.enemies:
		enemy.hp = 0
	g.projectiles.clear()
func run() -> void:
	var g := fixture()
	g.toggle_loop()
	check(g.state == BattleGame.State.TRAVEL and not g.guarding_here(), "Cruise arms next encounter")
	g.tick(5)
	check(g.guarding_here() and g.distance == 100 and g.group_index == 1, "Arrive and guard first encounter")
	check(g.guard_interval() == 5, "First interval starts at stage origin")
	g.profile.unlocked = []
	for enemy in g.enemies:
		enemy.equipment = []
	g.tick(8)
	check(g.guard_elapsed == 0 and g.distance == 100, "No timer or movement while enemies remain")
	empty_wave(g)
	g.tick(4)
	check(g.targets().is_empty() and g.guard_elapsed == 4, "Timer begins only once empty")
	g.paused = true
	g.tick(100)
	check(g.guard_elapsed == 4, "Pause freezes respawn timer")
	g.paused = false
	g.tick(1)
	check(not g.targets().is_empty() and g.group_index == 1 and g.distance == 100, "Respawn same group without moving")
	g.toggle_loop()
	empty_wave(g)
	g.tick(0.01)
	check(g.state == BattleGame.State.TRAVEL, "Disable resumes progression")
	g.group_index = 1
	g.spawn_group()
	g.toggle_loop()
	check(g.guard_interval() == 10 and g.distance == 300, "Unequal adjacent spacing controls interval")
	g.db.config.movement = 40
	check(g.guard_interval() == 5, "Movement speed controls interval")
	for mode in [0,1,2]:
		g = fixture()
		g.group_index = 1
		g.spawn_group()
		g.toggle_loop()
		g.set_guard_death(mode)
		g.begin_retreat()
		g.tick(2)
		check(g.distance == 150, "Death preserves retreat distance mode %s" % mode)
		if mode == 0:
			check(not g.profile.loop and g.state == BattleGame.State.TRAVEL, "Cancel guard on death")
		elif mode == 1:
			check(g.profile.loop and not g.guarding_here(), "Return mode cruises back")
			g.tick(7.5)
			check(g.guarding_here() and g.distance == 300, "Return reaches original guard point")
		else:
			check(g.guarding_here() and g.profile.guardDistance == 150, "Stay mode guards retreat location")
			g.tick(g.guard_interval())
			check(g.distance == 150 and not g.targets().is_empty(), "Stay mode respawns without returning")
	g = fixture()
	g.group_index = 2
	# Cross-stage retreat must preserve the return destination or re-anchor locally.
	for mode in [1,2]:
		var crossing := fixture()
		crossing.db.levels[1].length = 1000
		crossing.db.levels[1].groups = crossing.db.levels[0].groups.duplicate(true)
		crossing.start(2,false)
		crossing.spawn_group()
		crossing.toggle_loop()
		crossing.set_guard_death(mode)
		crossing.begin_retreat()
		crossing.tick(2)
		if mode == 1:
			crossing.tick(0.01)
			empty_wave(crossing)
			crossing.tick(0.01)
			crossing.acknowledge_unlocks()
			crossing.advance_after_clear()
			crossing.tick(5)
			check(crossing.stage == 2 and crossing.guarding_here() and crossing.distance == 100, "Cross-stage return reaches original point")
		else:
			crossing.tick(crossing.guard_interval())
			check(crossing.stage == 1 and crossing.guarding_here() and crossing.distance == 950 and not crossing.retreat_boss_pending, "Cross-stage stay keeps retreat point")
	g.spawn_group()
	g.toggle_loop()
	empty_wave(g)
	g.tick(0.01)
	check(g.state == BattleGame.State.LEVEL_CLEAR and g.clear_timer == 30, "Final wave preserves clear flow and guard interval")
	g.acknowledge_unlocks()
	g.tick(30)
	check(g.state == BattleGame.State.COMBAT and g.stage == 1 and g.distance == 900, "Final wave repeats at guard point")
	check(g.select_loop_level(2) and g.stage == 2 and not g.profile.loop, "Warp independently moves to cleared stage")
	check(not g.select_loop_level(3), "Warp rejects uncleared stage")
	g = fixture()
	g.spawn_group()
	g.toggle_loop()
	g.set_guard_death(2)
	g.save_enabled = true
	g.save_progress()
	var restored := BattleGame.new(g.db,true)
	restored.start(int(restored.profile.guardStage),true)
	restored.resume_guard()
	check(restored.guarding_here() and restored.distance == 100 and restored.profile.guardDeath == 2, "Save restores guard point and death choice")
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.set_guard_death(1)
	scene.build_ui()
	check(scene.loop_button.text.contains("驻守") and scene.loop_select.get_item_text(0).contains("跃迁"), "UI labels")
	await process_frame
	scene.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://guard.png")
	for child in scene.ui.get_children():
		if child is MenuButton and child.tooltip_text == "驻守死亡处理":
			check(child.get_popup().item_count == 3, "Three death submenu choices")
			child.get_popup().id_pressed.emit(2)
	check(scene.game.profile.guardDeath == 2, "Actual death settings signal")
	print("Guard: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
