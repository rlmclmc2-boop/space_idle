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
	scene.game.profile.selectedShip = "Heavy_Battleship"
	scene.game.profile.loadout = scene.game.empty_loadout("Heavy_Battleship")
	scene.refresh_structure()
	for key in ["missile","cannon","laser"]:
		scene.game.profile.loadout.weapons[0] = {"key":key,"level":1}
		scene.game.projectiles.clear()
		scene.projectile_visuals.clear()
		scene.particles.clear()
		scene.turret_visuals.clear()
		scene.game.jewel_fire(0,scene.game.enemies[0],scene.db.equip(key,1),scene.game.player_weapon_offset(0))
		var shot: Dictionary = scene.game.projectiles.back()
		var visual: Dictionary = scene.projectile_visuals.back()
		# Remove launch flashes/recoil so only the departing bullet and its trail change pixels.
		scene.particles.clear()
		scene.turret_visuals[0].recoil = 0.0
		visual.age = 0.08 # Exclude the independent muzzle streak from the image assertion.
		scene.battle_layer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var hull := root.get_texture().get_image()
		for i in 3:
			scene.game.tick_projectiles(0.004)
			scene.advance_projectile_visuals(0.004)
		var snapshot: Dictionary = shot.duplicate(true)
		scene.battle_layer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		var changed := 0
		for x in range(20,550):
			for y in range(80,690):
				var a := frame.get_pixel(x,y)
				var b := hull.get_pixel(x,y)
				if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()>0.2:changed += 1
		check(changed>=3,key+" departing body remains visible over the hull without flash")
		check(shot==snapshot,key+" layer change never alters combat projectile")
		frame.save_png("res://.runtime/muzzle-visible-"+key+".png")
	scene.queue_free()
	await process_frame
	print("Muzzle visibility: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
