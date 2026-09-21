extends SceneTree
class TimedUI extends "res://scripts/main.gd":
	var draws: Array = []
	var measuring := false
	func draw_battle() -> void:
		var started := Time.get_ticks_usec()
		super.draw_battle()
		if measuring:draws.append(Time.get_ticks_usec()-started)
func _initialize() -> void:call_deferred("run")
func median(values: Array) -> int:
	values.sort()
	return int(values[values.size()/2])
func run() -> void:
	var scene := TimedUI.new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.paused = true
	scene.game.pending_unlocks.clear()
	scene.game.profile.resources = {"1":1e20,"2":1e20}
	scene.game.profile.cleared = range(1,60)
	scene.game.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	scene.game.switch_ship("Heavy_Battleship")
	scene.refresh_structure()
	scene.equipment_tabs.current_tab = 0
	scene.refresh_visible_cards()
	await process_frame
	var refreshes: Array = []
	for sample in 100:
		var started := Time.get_ticks_usec()
		scene.refresh_visible_cards()
		refreshes.append(Time.get_ticks_usec()-started)
	scene.game.start(1,false)
	scene.game.spawn_group()
	scene.game.paused = true
	var target: Dictionary = scene.game.enemies[0]
	target.hp = 1e20
	for i in 128:
		scene.game.fire(scene.game.player,target,scene.db.equip("missile",1),1,false,"missile")
		scene.game.projectiles[-1].x += i*2.0
	for visual in scene.projectile_visuals:
		visual.samples = 14
		visual.age = 0.01
	scene.particles.clear()
	for i in 700:
		scene.particles.append({"pos":Vector2(1400,700),"vel":Vector2.ZERO,"life":1.0,"color":Color.WHITE,"size":1.0})
	var updates: Array = []
	for sample in 40:
		var started := Time.get_ticks_usec()
		scene.advance_projectile_visuals(0.001)
		updates.append(Time.get_ticks_usec()-started)
	scene.measuring = true
	for sample in 30:
		scene.battle_layer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
	print("HOT_PATH_PROBE ",JSON.stringify({"equipment_us":median(refreshes),"visual_update_us":median(updates),"draw_us":median(scene.draws)}))
	scene.queue_free()
	await process_frame
	quit()
