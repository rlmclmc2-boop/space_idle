extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	var cases := [[0,"0"],[9,"9"],[99,"99"],[123,"120"],[999,"990"],[1000,"1K"],[1230,"1.2K"],[12999,"12K"],[999999,"990K"],[1000000,"1M"],[1234567,"1.2M"],[1234567890,"1.2B"],[1234567890123,"1.2T"]]
	var failures := 0
	for item in cases:
		if scene.enemy_health(float(item[0])) != item[1]:
			failures += 1
			printerr(item)
	scene.game.start(1,false)
	scene.game.spawn_group()
	for enemy in scene.game.enemies:
		enemy.hp = 1230.0
		enemy.max_hp = 1234567.0
	await process_frame
	scene.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://normal.png")
	scene.game.group_index = scene.db.levels[0].groups.size()-1
	scene.game.spawn_group()
	for enemy in scene.game.enemies:
		enemy.hp = 1234567890.0
		enemy.max_hp = 1234567890123.0
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://boss.png")
	print("Health format: %d cases, %d failures" % [cases.size(),failures])
	quit(1 if failures else 0)
