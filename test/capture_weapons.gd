extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.spawn_group()
	scene.game.projectiles.clear()
	var keys := ["laser","cannon","missile"]
	for i in range(3):
		var key: String = keys[i]
		assert(scene.PROJECTILE_TEXTURES[key].get_width()>0)
		for hostile in [false,true]:
			scene.game.fire(scene.game.player,scene.game.enemies[0],scene.db.equip(key,1),1,hostile,key+"_mon" if hostile else key)
			var shot: Dictionary = scene.game.projectiles.back()
			shot.x = 850 if hostile else 550
			shot.y = 310+i*95
			shot.direction = Vector2(-1,-0.2).normalized() if hostile else Vector2.RIGHT
			shot.target = {}
		var label := Label.new()
		label.text = scene.NAMES[key]
		label.position = Vector2(620,292+i*95)
		label.add_theme_font_override("font",scene.font)
		scene.add_child(label)
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://weapons-preview.png")
	print("Weapon textures loaded; six player/enemy projectiles rendered with empty targets.")
	quit()
