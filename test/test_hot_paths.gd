extends SceneTree

class TrackedUI extends "res://scripts/main.gd":
	var details_built := 0
	var budget_queries := 0
	func equipment_stat_text(entry: Dictionary) -> String:
		details_built += 1
		return super.equipment_stat_text(entry)
	func decoration_budget(pos: Vector2, count: int) -> int:
		budget_queries += 1
		return super.decoration_budget(pos,count)

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene := TrackedUI.new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.paused = true
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared = range(1,60)
	scene.game.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	scene.game.profile.resources = {"1":1e20,"2":1e20}
	scene.refresh_structure()
	scene.equipment_tabs.current_tab = 0
	scene.refresh_visible_cards()
	await process_frame
	var panel = scene.equipment_panel
	panel.select_item("weapons_0")
	var item: Dictionary = panel.items.weapons_0
	var order: Array = panel.sorted_ids
	var details: int = scene.details_built
	for i in 30:scene.refresh_visible_cards()
	check(is_same(item,panel.items.weapons_0) and is_same(order,panel.sorted_ids),"Idle frames retain item projection and sort array")
	check(scene.details_built==details,"Paused idle frames do not regenerate details")
	scene.game.profile.resources = {"1":0.0,"2":0.0}
	scene.refresh_visible_cards()
	check(not panel.items.weapons_0.upgradeable and panel.detail.upgrade.disabled,"Resource change updates affordability while paused")
	check(scene.details_built==details and is_same(item,panel.items.weapons_0),"Resource-only update does not rebuild stats or detail")
	var entry: Dictionary = scene.game.module_entry("weapons",0)
	var charge_key := "攻击充能"
	scene.game.profile.charge[charge_key].level += 1
	scene.game.event.emit("equipment_stats",{"category":"weapons"})
	scene.refresh_visible_cards()
	check(panel.items.weapons_0.mainStatNumber==scene.game.jewel_equipment_stat(entry),"Charge stat event refreshes affected value")
	check(panel.stats_dirty.is_empty() and not panel.sort_dirty,"Local dirty flags clear after refresh")
	scene.return_to_battle()
	scene.game.profile.charge[charge_key].level += 1
	scene.game.event.emit("equipment_stats",{"category":"weapons"})
	check(panel.dirty,"Hidden stat event defers work")
	scene.equipment_tabs.current_tab = 0
	scene.refresh_visible_cards()
	check(not panel.dirty and panel.items.weapons_0.mainStatNumber==scene.game.jewel_equipment_stat(entry),"Showing page catches up hidden stats")
	# Identical shot trajectories still have distinct serial identities.
	scene.game.start(1,false)
	scene.game.spawn_group()
	scene.game.paused = true
	var target: Dictionary = scene.game.enemies[0]
	target.hp = 1e12
	scene.game.projectiles.clear()
	scene.projectile_visuals.clear()
	for i in 16:
		scene.game.fire(scene.game.player,target,scene.db.equip("missile",1),1,false,"missile")
	for visual in scene.projectile_visuals:
		visual.samples = 14
		visual.age = 0.01
	var index: Dictionary = scene.projectile_visual_index()
	for visual in scene.projectile_visuals:
		check(is_same(scene.projectile_visual(visual.shot,index),visual),"Frame index preserves shot identity")
	scene.particles.clear()
	scene.budget_queries = 0
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(scene.budget_queries==16,"Each missile queries particle budget once across both draw passes")
	scene.game.projectiles.clear()
	scene.advance_projectile_visuals(0)
	check(scene.projectile_visuals.is_empty(),"Removed projectiles release visual records")
	var qa = load("res://scripts/config_panel.gd").new()
	root.add_child(qa)
	qa.hide()
	check(not qa.is_processing(),"Hidden idle QA stops processing")
	var poll: float = qa.control_poll
	var text: String = qa.pause_button.text
	qa._process(1.0)
	check(qa.control_poll==poll and qa.pause_button.text==text,"Hidden QA neither polls nor rewrites controls")
	qa.worker = Thread.new()
	qa.worker.start(func():return 0)
	qa.update_processing()
	check(qa.is_processing(),"Hidden QA keeps unfinished worker checks")
	while qa.worker!=null:await process_frame
	check(not qa.is_processing(),"Worker completion returns hidden QA to idle")
	qa.show()
	check(qa.is_processing(),"Reopening QA resumes control updates")
	qa.queue_free()
	check(scene.game.has_alive_enemy(),"Live enemy existence returns true")
	for enemy in scene.game.enemies:enemy.hp = 0
	check(not scene.game.has_alive_enemy(),"Dead enemies do not count as live")
	scene.queue_free()
	await process_frame
	print("Hot paths: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
