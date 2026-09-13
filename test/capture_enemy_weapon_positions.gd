extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var g: BattleGame = scene.game
	g.save_enabled = false
	g.pending_unlocks.clear()
	g.profile.unlocked = []
	for key in ["laser_mon", "cannon_mon", "missile_mon"]:
		g.enemies.clear()
		g.projectiles.clear()
		for boss in [false, true]:
			for row in range(3):
				var count: int = [2, 3, 6][row]
				var enemy := {"x":1150.0 if boss else 800.0,"y":290.0+130.0*row,"hp":1000.0,"max_hp":1000.0,"boss":boss,"armourType":1,"des":"发射位置验证","equipment":[],"cooldowns":[],"dmgMultiple":1.0,"slot":row,"size":3 if boss else 1}
				for i in range(count):
					enemy.equipment.append({"name":key,"level":1})
					enemy.cooldowns.append(0.0)
				g.enemies.append(enemy)
		g.state = BattleGame.State.COMBAT
		g.tick(0.0)
		for phase in ["origin", "flight"]:
			if phase == "flight":
				g.tick_projectiles(0.08)
			scene.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://mounts-%s-%s.png" % [key, phase]
			var error := root.get_texture().get_image().save_png(path)
			if error != OK:
				quit(1)
				return
			print("Captured ", path)
	quit(0)

