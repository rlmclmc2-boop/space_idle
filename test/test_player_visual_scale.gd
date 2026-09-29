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
	var original_player_scale: float = scene.player_art_scale()
	var enemy = scene.game.enemies[0]
	var original_enemy_size: int = int(enemy.size)
	var original_enemy_width: float = scene.enemy_render_width(enemy)
	for key in visuals.SOCKETS:
		var config_key: String = "playerVisualScale"+str(key)
		var configured_scale: float = float(scene.db.config[config_key])
		var own_scale: float = scene.player_art_scale_for(key)
		var other_key := "Frigate" if key!="Frigate" else "Destroyer"
		var other_scale: float = scene.player_art_scale_for(other_key)
		scene.db.config[config_key] = configured_scale*0.5
		check(is_equal_approx(scene.player_art_scale_for(key),own_scale*0.5),"player scale reads own config "+key)
		check(is_equal_approx(scene.player_art_scale_for(other_key),other_scale),"player scale leaves other hull unchanged "+key)
		check(is_equal_approx(scene.enemy_render_width(enemy),original_enemy_width),"player scale leaves enemy unchanged "+key)
		scene.db.config[config_key] = configured_scale
	for size in range(1,7):
		enemy.size = size
		var config_key := "enemyVisualScaleSize"+str(size)
		var configured_scale: float = float(scene.db.config[config_key])
		var width: float = scene.enemy_render_width(enemy)
		var other_size := 2 if size==1 else 1
		var other_scale: float = scene.enemy_config_visual_scale(other_size)
		scene.db.config[config_key] = configured_scale*0.5
		check(scene.enemy_render_width(enemy)<width*0.75,"enemy scale reads own size config "+str(size))
		check(is_equal_approx(scene.enemy_config_visual_scale(other_size),other_scale),"enemy scale leaves other size unchanged "+str(size))
		check(is_equal_approx(scene.player_art_scale(),original_player_scale),"enemy scale leaves player unchanged "+str(size))
		scene.db.config[config_key] = configured_scale
	enemy.size = original_enemy_size
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
		var dimensions: Vector2 = scene.SHIP_ART_CANVAS*scene.battle_visual.player_core_scale*scene.player_art_scale()
		check(scene.game.player.x-dimensions.x/2>8 and scene.game.player.x+dimensions.x/2<BattleGame.BATTLE_SIZE.x-8,"hull fits vertical battlefield width "+key)
		check(scene.player_render_position().y+scene.player_visible_tail()+absf(float(scene.battle_visual.player_idle_y))<=1132.0-scene.BATTLE_ORIGIN.y-float(scene.battle_visual.player_hud_gap)+0.01,"visible hull clears bottom UI "+key)
		for i in scene.game.weapon_entries().size():
			scene.game.projectiles.clear()
			scene.projectile_visuals.clear()
			var entry: Dictionary = scene.game.slot_entry("weapons",i)
			scene.game.jewel_fire(i,scene.game.enemies[0],scene.db.equip(entry.key,1),scene.game.player_weapon_offset(i))
			var shot: Dictionary = scene.game.projectiles[0]
			var visual: Dictionary = scene.projectile_visuals[0]
			var component = scene.player_component_for_slot(i)
			var size_class := str(component.hardpoint.visual_size_class)
			var class_scale: float = {"small":0.72,"medium":0.9,"large":1.1}[size_class]
			var muzzle_fraction: float = float(component.profile.muzzle[0][0])
			var local: Vector2 = scene.player_mount_center(key,i)+Vector2(visuals.module_width(key)*class_scale*muzzle_fraction,0).rotated(scene.weapon_visual_angle(component.owner_slot))
			var expected: Vector2 = scene.battle_logical_point(scene.player_render_position()+local.rotated(-PI/2+scene.player_idle_angle())*scene.player_art_scale())
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
		scene.draw_ship(Vector2(140,440),0.24,false,1,false)
		scene.draw_ship(Vector2(430,440),0.24,false,1,false)
	scene.battle_layer.draw.connect(fleet_draw)
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/player-fleet-layout.png")
	check(scene.SHIP_ART_CANVAS.x*scene.battle_visual.player_core_scale*scene.player_art_scale()<BattleGame.BATTLE_SIZE.x-16,"largest hull fits vertical battlefield")
	scene.battle_layer.draw.disconnect(fleet_draw)
	ProjectSettings.set_setting("visuals/player_ship_scale",1.7)
	scene.game.profile.cleared = [10,20,30,50]
	scene.game.rebuild_unlocks()
	scene.equipment_tabs.current_tab=3
	var ship_page = scene.ship_controls.page
	for key in ["Destroyer","Cruiser","Battleship","Heavy_Battleship"]:
		ship_page.candidate=key
		ship_page.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/preview-"+key+".png")
	scene.queue_free()
	await process_frame
	print("Player visual scale: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
