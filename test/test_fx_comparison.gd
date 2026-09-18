extends SceneTree
var scene
var results: Array = []
func _initialize() -> void:
	call_deferred("run")
func capture(label: String) -> void:
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/compare-"+label+".png")
	var health: Array = []
	for enemy in scene.game.enemies:health.append(enemy.hp)
	results.append({"phase":label,"health":health,"player":scene.game.player.duplicate(true),"projectiles":scene.game.projectiles.size(),"rng":str(scene.game.rng.state)})
func advance(dt: float) -> void:
	scene.game.tick_projectiles(dt)
	scene.advance_projectile_visuals(dt)
	scene.sync_beam_visuals()
	for p in scene.particles:
		p.life -= dt
		p.pos += p.vel*dt
		p.vel *= 0.97
	scene.particles = scene.particles.filter(func(p):return p.life>0)
func run() -> void:
	seed(24680)
	scene = load("res://main.tscn").instantiate()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.rng.seed = 13579
	scene.game.start(1,false)
	scene.game.spawn_group()
	scene.show_damage_numbers = false
	scene.wave_hint = 0
	for enemy in scene.game.enemies:
		enemy.hp = 100000
		enemy.max_hp = 100000
		enemy.equipment = []
	scene.game.profile.unlocked = ["missile","cannon","laser","longLaser"]
	scene.game.profile.loadout.weapons = [{"key":"missile","level":1},{"key":"cannon","level":1},{"key":"laser","level":1}]
	scene.refresh_structure()
	for i in 3:
		var key: String = ["missile","cannon","laser"][i]
		scene.game.fire(scene.game.player,scene.game.enemies[i],scene.db.equip(key,1),10,false,key,scene.game.player_weapon_offset(i))
	await capture("launch")
	for i in 12:advance(1.0/60)
	await capture("flight")
	# Actual damage event at each existing target; equal placement in both versions.
	for shot in scene.game.projectiles:
		shot.x = shot.target.x-1
		shot.y = shot.target.y
	advance(0.016)
	await capture("hit")
	for i in 5:advance(1.0/60)
	await capture("hit-fade")
	scene.particles.clear()
	scene.game.hit_enemy(scene.game.enemies[1],200000,2)
	await capture("kill-flash")
	for i in 8:advance(1.0/60)
	await capture("kill-debris")
	scene.game.profile.loadout.weapons = [{"key":"longLaser","level":1},{"key":"","level":1},{"key":"","level":1}]
	scene.refresh_structure()
	var weapon: Dictionary = scene.db.equip("longLaser",1)
	scene.game.lock_long_laser(scene.game.player,weapon,false,0,scene.game.slot_entry("weapons",0))
	var beam: Dictionary = scene.game.projectiles.back()
	var first: float = beam.charge if beam.charge>=0 else beam.weapon.cd
	advance(first)
	await capture("beam-pulse")
	advance(minf(0.2,float(beam.weapon.cd)*0.5))
	await capture("beam-hold")
	var f := FileAccess.open("res://.runtime/combat-snapshot.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"\t"))
	print("FX comparison: level 1; fixed seed, loadout and timings; 8 captures; damage numbers hidden")
	scene.queue_free()
	await process_frame
	quit()
