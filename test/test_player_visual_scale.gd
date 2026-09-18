extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.start(1,false)
	scene.game.spawn_group()
	scene.show_damage_numbers = false
	var visuals = scene.SHIP_VISUALS
	var enemy_scale: float = visuals.enemy_scale_for(scene.game.enemies[0])
	for key in visuals.SOCKETS:
		scene.game.profile.selectedShip = key
		scene.game.profile.loadout = scene.game.empty_loadout(key)
		for i in scene.game.profile.loadout.weapons.size():
			scene.game.profile.loadout.weapons[i] = {"key":["cannon","missile","laser"][i%3],"level":1}
		scene.refresh_structure()
		ProjectSettings.set_setting("visuals/player_ship_scale",1.0)
		var original: Vector2 = scene.game.player_weapon_offset(0)
		scene.game.projectiles.clear()
		scene.projectile_visuals.clear()
		scene.particles.clear()
		for factor in [1.0,1.25]:
			ProjectSettings.set_setting("visuals/player_ship_scale",factor)
			check(scene.game.player_weapon_offset(0)==original,"display scale leaves logical muzzle unchanged "+key)
			check(is_equal_approx(visuals.player_display_scale(scene.db.ship(key)),visuals.scale_for(scene.db.ship(key))*factor),"uniform ship/module scale "+key)
			scene.battle_layer.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/player-"+key+"-"+str(factor)+".png")
		var dimensions: Vector2 = visuals.CANVAS*visuals.player_display_scale(scene.db.ship(key))
		check(scene.game.player.x-dimensions.x/2>35 and scene.game.player.y-dimensions.y/2>200,"hull inside battlefield "+key)
		var name_y: float = maxf(489,scene.game.player.y+dimensions.y/2+18)
		check(name_y+26<580,"name and model clear bottom health/controls "+key)
		for i in scene.game.weapon_entries().size():
			scene.game.projectiles.clear()
			scene.projectile_visuals.clear()
			var entry: Dictionary = scene.game.slot_entry("weapons",i)
			scene.game.jewel_fire(i,scene.game.enemies[0],scene.db.equip(entry.key,1),scene.game.player_weapon_offset(i))
			var shot: Dictionary = scene.game.projectiles[0]
			var visual: Dictionary = scene.projectile_visuals[0]
			var expected: Vector2 = Vector2(scene.game.player.x,scene.game.player.y)+visuals.muzzle(key,i)*visuals.player_display_scale(scene.db.ship(key))
			check(visual.origin.is_equal_approx(expected),"visible shot and flash match scaled mount "+key+str(i))
			check(scene.missile_visual_position(shot,0,visual.origin).is_equal_approx(expected),"projectile born at visible muzzle "+key+str(i))
			var snapshot: Dictionary = shot.duplicate(true)
			scene.advance_projectile_visuals(0.03)
			check(shot==snapshot,"visual scaling cannot alter trajectory or damage "+key+str(i))
	check(visuals.enemy_scale_for(scene.game.enemies[0])==enemy_scale,"enemy size unchanged")
	scene.game.projectiles.clear()
	scene.projectile_visuals.clear()
	scene.particles.clear()
	scene.game.enemies.clear()
	# Layout-only preview: runtime currently has one friendly ship, no fleet or turret rotation.
	var fleet_draw := func():
		scene.draw_surface = scene.battle_layer
		scene.draw_ship(Vector2(730,405),0.24,false,1,false)
		scene.draw_ship(Vector2(1180,405),0.24,false,1,false)
	scene.battle_layer.draw.connect(fleet_draw)
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/player-fleet-layout.png")
	check(visuals.CANVAS.x*visuals.player_display_scale(scene.db.ship("Heavy_Battleship"))<450,"three largest hulls fit at 450px spacing")
	scene.battle_layer.draw.disconnect(fleet_draw)
	scene.queue_free()
	await process_frame
	print("Player visual scale: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
