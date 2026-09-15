extends SceneTree

const V = preload("res://scripts/ship_visuals.gd")
var failures := 0
var checks := 0
var last_fire: Dictionary = {}

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
	var game = scene.game
	game.save_enabled = false
	game.pending_unlocks.clear()
	game.profile.unlocked = ["armour", "shield", "laser", "cannon", "missile"]
	game.event.connect(func(kind, info):
		if kind == "fire": last_fire = info)
	for key in scene.db.ships:
		game.profile.selectedShip = key
		game.ensure_loadout()
		var row: Dictionary = scene.db.ship(key)
		check(is_equal_approx(V.scale_for(row) * V.CANVAS.y, float(row.size) * 44), key + " occupancy")
		check(V.SOCKETS[key].size() == int(row.weaponSlots), key + " sockets")
		for index in range(int(row.weaponSlots)):
			game.profile.loadout.weapons[index].key = ["laser", "cannon", "missile"][index % 3]
			for weapon_key in ["laser", "cannon", "missile"]:
				var expected: Vector2 = Vector2(game.player.x,game.player.y) + V.muzzle(key,index)*V.scale_for(row)
				game.fire(game.player,{"x":1100.0,"y":400.0},scene.db.equip(weapon_key,1),1,false,weapon_key,game.player_weapon_offset(index))
				var shot: Dictionary = game.projectiles.back()
				check(Vector2(shot.x,shot.y).is_equal_approx(expected), key + " muzzle")
				check(Vector2(last_fire.x,last_fire.y).is_equal_approx(expected), key + " effect")
		game.projectiles.clear()
		scene.particles.clear()
		scene.build_ui()
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://visual-"+key+".png")
	check(V.scale_for({"size":4}) == V.scale_for({"size":1}) * 4, "live size scaling")
	print("Ship visuals: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
