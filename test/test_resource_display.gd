extends SceneTree
var checks := 0
var failures := 0
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
	scene.game.save_enabled = false
	scene.game.profile.resources["1"] = 123
	scene.game.profile.resources["2"] = 45
	check(scene.resource_display("1")=="123" and scene.resource_display("2")=="45", "Default displays use shared three-significant-digit totals")
	scene.resource_mode_button.pressed.emit()
	check(scene.resource_rate_mode and scene.resource_display("1")=="0.00/秒", "Button switches to empty rate")
	for manual in [true,false]:
		var drop := {"uid":90 if manual else 91,"x":500.0,"y":300.0,"age":0.0,"id":"1" if manual else "2","amount":60.0}
		scene.game.drops.append(drop)
		scene.game.collect(drop,manual)
	check(scene.resource_display("1")=="1.00/秒", "Manual credit divided by full minute")
	var auto_amount := ceilf(60.0*(1.0-float(scene.db.config.autoCollectReduce)))
	check(scene.resource_display("2")=="%.2f/秒" % (auto_amount/60.0) and scene.game.profile.resources["2"]==45+auto_amount, "Auto rate uses actual credit")
	scene.game.profile.resources["1"] -= 100
	check(scene.resource_display("1")=="1.00/秒", "Spending does not reduce acquisition rate")
	scene.build_ui()
	check(scene.resource_rate_mode and scene.resource_mode_button.text=="资源：每秒", "UI rebuild retains selected mode")
	scene.resource_samples.assign([{"time":40.0,"id":"1","amount":600.0},{"time":40.1,"id":"1","amount":30.0},{"time":99.0,"id":"2","amount":15.0}])
	check(scene.resource_display("1",100.0)=="0.50/秒" and scene.resource_display("2",100.0)=="0.25/秒", "Rolling window excludes exact 60-second boundary and separates resources")
	check(scene.resource_display("1",160.0)=="0.00/秒", "No recent income expires to zero")
	scene.resource_mode_button.pressed.emit()
	check(not scene.resource_rate_mode and scene.resource_display("1")=="83", "Second click restores current total")
	if DisplayServer.get_name() != "headless":
		scene.resource_mode_button.pressed.emit()
		scene.resource_samples.assign([{"time":Time.get_unix_time_from_system(),"id":"1","amount":75.0}])
		scene.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://resource-rate.png")
		scene.game.drops.append({"uid":92,"x":155.0,"y":300.0,"age":0.0,"id":"2","amount":5.0,"speed":40.0,"auto_gen":true})
		scene.game.drops.append({"uid":93,"x":330.0,"y":300.0,"age":0.6,"id":"1","amount":5.0,"speed":40.0})
		scene.battle_layer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://resource-drops.png")
	scene.game.profile.highestLevel = 13
	scene.game.start(13,false)
	scene.game.spawn_group()
	scene.game.paused = false
	var enemy: Dictionary = scene.game.enemies[0]
	enemy.hp = 1.0
	enemy.drops = [{"resourceId":1,"amount":5.0,"chance":1.0}]
	var ship_pos: Vector2 = scene.enemy_render_position(enemy)
	var ship_half: float = scene.enemy_render_width(enemy)
	scene.game.hit_enemy(enemy,1000000000.0,1)
	var killed_iron: Dictionary = scene.game.drops.filter(func(drop):return drop.get("source_uid",-1)==enemy.uid and drop.id=="1").front()
	# A display snapshot can be lost while the killed enemy remains in this wave.
	scene.death_drop_positions.clear()
	scene.game.tick(1.0/60.0)
	scene.refresh_draw_layers(1.0/60.0)
	var iron_pos: Vector2 = scene.drop_render_position(killed_iron)
	check(scene.death_drop_positions.has(int(enemy.uid)),"Killed enemy restores missing display anchor")
	check(iron_pos.distance_to(ship_pos+Vector2(0,ship_half+12.0))<0.01 and iron_pos.y>ship_pos.y+ship_half,"Killed iron appears below destroyed hull")
	check(Vector2(killed_iron.x,killed_iron.y)==Vector2(enemy.x,enemy.y+40),"Drop keeps gameplay coordinates")
	var old_hit := InputEventMouseMotion.new()
	old_hit.position = scene.battle_layer.to_global(scene.battle_point(Vector2(killed_iron.x,killed_iron.y)))
	scene._unhandled_input(old_hit)
	check(scene.game.drops.has(killed_iron),"Old invisible drop position does not collect")
	if DisplayServer.get_name() != "headless":
		killed_iron.age = 0.6
		scene.battle_layer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://kill-iron-drop.png")
	var before_pickup: float = float(scene.game.profile.resources["1"])
	var click := InputEventMouseButton.new()
	click.position = scene.battle_layer.to_global(iron_pos)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	scene._unhandled_input(click)
	check(not scene.game.drops.has(killed_iron) and float(scene.game.profile.resources["1"])==before_pickup+float(killed_iron.amount),"Visible iron position collects full amount")
	scene.refresh_draw_layers(0)
	check(not scene.death_drop_positions.has(int(enemy.uid)),"Collected drop releases display anchor")
	scene.fx_time += 2.0
	var left_enemy: Dictionary = {}
	for candidate in scene.game.enemies:
		if candidate.hp>0 and (left_enemy.is_empty() or scene.enemy_render_position(candidate).x<scene.enemy_render_position(left_enemy).x):
			left_enemy = candidate
	var left_pose: Dictionary = scene.enemy_pose(left_enemy)
	left_pose.target.x = float(left_enemy.x)+20.0
	left_enemy.hp = 1.0
	left_enemy.drops = [{"resourceId":1,"amount":5.0,"chance":1.0}]
	var left_ship_pos: Vector2 = scene.enemy_render_position(left_enemy)
	var left_ship_half: float = scene.enemy_render_width(left_enemy)
	scene.game.hit_enemy(left_enemy,1000000000.0,1)
	var left_iron: Dictionary = scene.game.drops.filter(func(drop):return drop.get("source_uid",-1)==left_enemy.uid and drop.id=="1").front()
	scene.death_drop_positions.erase(int(left_enemy.uid))
	scene.refresh_draw_layers(1.0/60.0)
	var left_iron_pos: Vector2 = scene.drop_render_position(left_iron)
	check(left_iron_pos.distance_to(left_ship_pos+Vector2(0,left_ship_half+12.0))<0.01,"Leftmost stage 13 iron stays under its ship")
	if DisplayServer.get_name() != "headless":
		left_iron.age = 0.6
		scene.battle_layer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://stage13-left-iron.png")
	scene.game.drops.clear()
	scene.game.pending_unlocks.clear()
	var furnace_iron := {"uid":9901,"x":135.0,"y":320.0,"age":2.0,"id":"1","amount":250.0,"hightech":true}
	var furnace_core := {"uid":9902,"x":218.0,"y":320.0,"age":2.0,"id":"jewel","amount":25.0,"hightech":true,"jewel":true}
	scene.game.drops.append_array([furnace_iron,furnace_core])
	check(scene.FURNACE_IRON_TEXTURE != scene.FURNACE_CORE_TEXTURE,"Furnace resources have distinct sprites")
	if DisplayServer.get_name() != "headless":
		scene.battle_layer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://furnace-resources.png")
	var core_motion := InputEventMouseMotion.new()
	core_motion.position = scene.battle_layer.to_global(scene.drop_render_position(furnace_core))
	scene._unhandled_input(core_motion)
	check(not scene.game.drops.has(furnace_core) and scene.game.drops.has(furnace_iron),"Core sweep collects only the core")
	var furnace_click := InputEventMouseButton.new()
	furnace_click.position = scene.battle_layer.to_global(scene.drop_render_position(furnace_iron))
	furnace_click.button_index = MOUSE_BUTTON_LEFT
	furnace_click.pressed = true
	var iron_before: float = float(scene.game.profile.resources["1"])
	scene._unhandled_input(furnace_click)
	check(not scene.game.drops.has(furnace_iron) and float(scene.game.profile.resources["1"])==iron_before+250.0,"Furnace iron click credits its amount")
	print("Resource display: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
