extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.pending_unlocks.clear()
	for size in range(1,7):
		var enemy: Dictionary = scene.db.enemies.values()[0].duplicate(true)
		enemy.merge({"size":size,"x":1050.0,"y":400.0,"hp":100.0,"max_hp":100.0,"slot":0,"uid":1,"boss":size>1},true)
		scene.game.enemies.assign([enemy])
		var offset: Vector2 = scene.game.enemy_weapon_offset(enemy,0)
		var height := 32.0+(size-1)*2.4
		assert(is_equal_approx(-45+offset.x,-height*2*0.45),"Launch tracks left hull edge")
		assert(absf(offset.y)<height/2,"Mount remains inside visible height")
		scene.build_ui()
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://enemy-size-%d.png" % size)
	var id: String = scene.db.enemies.keys()[0]
	scene.db.enemies[id].size = 100
	scene.db.groups["999"] = {"slots":[int(id),int(id),int(id),int(id),int(id),int(id),int(id),int(id),int(id),int(id)]}
	scene.db.levels[0].groups = [{"id":999,"position":0.0}]
	scene.game.start(1,false)
	scene.game.spawn_group()
	assert(scene.game.enemies.size()==10,"Ten large ships fit ten slots")
	for index in range(10):
		assert(scene.game.enemies[index].y==198+index*44,"Size cannot move slot center")
	assert(scene.game.targets()[0].slot==4,"Target priority uses single-slot centers")
	scene.build_ui()
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://enemy-ten-large.png")
	print("Enemy ship visuals: 24 checks passed; seven screenshots")
	quit()
