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
	for i in 8:scene.game.profile.loadout.weapons[i] = {"key":["cannon","missile","laser","longLaser"][i%4],"level":1}
	scene.refresh_structure()
	var top: Dictionary = scene.game.enemies[0]
	var bottom: Dictionary = scene.game.enemies[1]
	top.x = 80.0
	top.y = 225.0
	bottom.x = 500.0
	bottom.y = 225.0
	for enemy in scene.game.enemies:
		enemy.hp = 100000
		enemy.equipment = []
	# Slot scatter is presentation-only: place the visible targets at opposite
	# edges so this still checks independent left/right aiming after repacking.
	top.x += 80.0-scene.enemy_render_position(top).x
	bottom.x += 500.0-scene.enemy_render_position(bottom).x
	for i in 8:scene.turret_pose(i).target = top if i<4 else bottom
	var enemies: Array = scene.game.enemies.duplicate(true)
	var cooldowns: Dictionary = scene.game.cooldowns.duplicate(true)
	var rng_state: int = scene.game.rng.state
	scene.advance_turrets(0.01)
	check(scene.turret_angle(0)<0 and scene.turret_angle(4)>0,"mounts independently turn toward left and right targets")
	check(absf(scene.turret_angle(0))<=deg_to_rad(2.4)+0.00001,"turn speed bounded without snapping")
	for i in 20:scene.advance_turrets(0.05)
	check(scene.game.enemies==enemies and scene.game.cooldowns==cooldowns and scene.game.rng.state==rng_state,"rotation leaves combat data and RNG untouched")
	check(absf(scene.turret_angle(0))<=deg_to_rad(85),"rotation respects presentation arc")
	scene.game.paused = true
	var frozen: float = scene.turret_angle(0)
	scene.advance_turrets(0.1)
	check(scene.turret_angle(0)==frozen,"paused mount pose freezes")
	scene.game.paused = false
	var muzzle: Vector2 = scene.turret_muzzle(1)
	for n in 3:scene.game.jewel_fire(1,top,scene.db.equip("missile",1),scene.game.player_weapon_offset(1),1.0,scene.game.missile_visual_spread(n,3))
	check(scene.projectile_visuals.all(func(v):return v.origin.is_equal_approx(muzzle)),"all volley shots share rotated muzzle")
	check(scene.projectile_visuals.all(func(v):return is_equal_approx(v.angle,-PI/2+scene.player_idle_angle()+scene.turret_angle(1))),"missiles initially face the upright rotated barrel")
	check(scene.game.projectiles.all(func(p):return p.direction==Vector2.UP),"logical missile direction points toward enemy line")
	var logical: Array = scene.game.projectiles.duplicate(true)
	scene.advance_projectile_visuals(0.03)
	check(scene.game.projectiles==logical,"visible launch and tail cannot alter actual trajectory")
	var normal_muzzle: Vector2 = scene.game.player_weapon_offset(1)
	check(not muzzle.is_equal_approx(Vector2(scene.game.player.x,scene.game.player.y)+normal_muzzle*1.25),"visible muzzle moves with rotation")
	scene.game.lock_long_laser(scene.game.player,scene.db.equip("longLaser",1),false,3,scene.game.slot_entry("weapons",3))
	var beam: Dictionary = scene.game.projectiles.back()
	scene.advance_turrets(0.1)
	scene.sync_beam_visuals()
	check(scene.beam_visuals.back().start.is_equal_approx(scene.turret_muzzle(3)),"beam and charge source track rotated muzzle")
	check(is_same(scene.turret_visuals[3].target,beam.target),"main beam owns mount aim")
	# Finish initial scene/UI drawing before counting unrelated redraws.
	await process_frame
	await RenderingServer.frame_post_draw
	var tabs = scene.equipment_tabs
	var background := [0]
	scene.background_layer.draw.connect(func():background[0]+=1)
	scene.particles.clear()
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/turret-rotation.png")
	check(scene.equipment_tabs==tabs and background[0]==0,"rotation redraw preserves UI and static background")
	top.hp = 0
	scene.advance_turrets(0.05)
	check(not is_same(scene.turret_visuals[0].target,top),"dead target is released")
	scene.game.profile.loadout.weapons[0] = {"key":"laser","level":1}
	check(scene.turret_angle(0)==0,"replaced equipment cannot inherit old pose")
	scene.game.profile.loadout.weapons[0] = {"key":"","level":1}
	scene.advance_turrets(0.01)
	check(not scene.turret_visuals.has(0),"empty mount releases pose")
	scene.game.state = BattleGame.State.TRAVEL
	for i in 20:scene.advance_turrets(0.05)
	check(is_zero_approx(scene.turret_angle(4)),"no combat smoothly returns to forward")
	scene.game.profile.selectedShip = "Frigate"
	scene.game.profile.loadout = scene.game.empty_loadout("Frigate")
	scene.game.profile.loadout.weapons[0] = {"key":"cannon","level":1}
	scene.advance_turrets(0.01)
	check(scene.turret_visuals.size()==1 and scene.turret_angle(0)==0,"ship change clears old mount poses")
	for key in scene.SHIP_VISUALS.SOCKETS:
		var dimensions: Vector2 = scene.SHIP_VISUALS.CANVAS*scene.SHIP_VISUALS.player_display_scale(scene.db.ship(key))
		var width: float = scene.SHIP_VISUALS.module_width(key)
		var scale_value: float = scene.SHIP_VISUALS.player_display_scale(scene.db.ship(key))
		# Bound every rotated corner, including the laser's tallest module and backing.
		var radius: float = Vector2(width/2+4,width*0.42/2+4).length()*scale_value
		var sockets: Array = scene.SHIP_VISUALS.SOCKETS[key]
		for i in sockets.size():
			var pivot: Vector2 = Vector2(scene.game.player.x,scene.game.player.y)+scene.SHIP_VISUALS.center(key,i)*scale_value
			check(pivot.y-radius>200 and pivot.y+radius<maxf(489,scene.game.player.y+dimensions.y/2+18)-18,"rotation sweep avoids name and HUD "+key+str(i))
			for j in range(i+1,sockets.size()):
				check(sockets[i].distance_to(sockets[j])*scale_value>radius*2,"neighbor mount rotation envelopes do not overlap "+key+str(i)+":"+str(j))
	scene.queue_free()
	await process_frame
	print("Turret rotation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
