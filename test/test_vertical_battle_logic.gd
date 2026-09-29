extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := preload("res://scripts/main.gd").new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.pending_unlocks.clear()
	scene.game.start(1,false)
	scene.game.spawn_group()
	scene.game.paused=true
	await process_frame
	check(scene.game.player.x==BattleGame.PLAYER_POSITION.x and scene.game.player.y==BattleGame.PLAYER_POSITION.y,"Player uses vertical battlefield coordinates")
	check(scene.game.enemies.all(func(enemy):return enemy.y<scene.game.player.y and enemy.x>=0 and enemy.x<BattleGame.BATTLE_SIZE.x),"Enemies spawn across upper battlefield")
	var nearest_y: float = float(scene.game.enemies.map(func(enemy):return float(enemy.y)).max())
	check(is_equal_approx(float(scene.game.targets()[0].y),float(nearest_y)),"Target order follows vertical proximity")
	check(is_zero_approx(scene.battle_layer.rotation) and scene.battle_layer.scale==Vector2.ONE,"Battlefield is not rotated or squeezed")
	check(scene.battle_clip.size==scene.BATTLE_VIEW_SIZE and BattleGame.BATTLE_SIZE==Vector2(572,696),"Display corridor expands inside existing left column without changing simulation")
	for point in [Vector2(20,60),Vector2(286,320),Vector2(286,520),Vector2(500,680)]:
		check(scene.battle_logical_point(scene.battle_point(point)).distance_to(point)<0.001,"Displayed pickup position maps back to simulation")
	check(scene.equipment_tabs.size.x==1364 and scene.equipment_tabs.get_global_rect().position.x>=600,"Original width pages sit to the right")
	check(scene.battle_layer.visible and scene.equipment_panel.detail_frame.visible,"Battle stays visible beside equipment inspector")
	var player_mount: Vector2=scene.game.player_weapon_offset(0)
	check(player_mount.y<0 and scene.game.enemy_weapon_offset(scene.game.enemies[0],0).y>0,"Both weapon mounts face their opponents")
	var enemy: Dictionary=scene.game.enemies[0]
	var weapon: Dictionary=scene.db.equip("missile",1)
	scene.game.fire(scene.game.player,enemy,weapon,1.0,false,"missile")
	check(scene.game.projectiles.back().direction==Vector2.UP,"Player missile starts upward")
	var player_shot: Dictionary=scene.game.projectiles.back()
	scene.game.fire(enemy,scene.game.player,weapon,1.0,true,"missile")
	check(scene.game.projectiles.back().direction==Vector2.DOWN,"Enemy missile starts downward")
	var enemy_shot: Dictionary=scene.game.projectiles.back()
	player_shot.speed=50.0
	enemy_shot.speed=50.0
	var player_y: float=player_shot.y
	var enemy_y: float=enemy_shot.y
	scene.game.tick_projectiles(0.1)
	check(player_shot.y<player_y and enemy_shot.y>enemy_y,"Projectile simulation advances vertically")
	var ore := {"uid":999999,"x":200.0,"y":100.0,"age":0.0,"id":"2","amount":1.0,"speed":50.0,"auto_gen":true}
	scene.game.drops.append(ore)
	scene.game.advance_auto_gen(0.1)
	check(ore.y>100.0 and ore.x==200.0,"Generated resource travels downward")
	ore.y=340.0
	scene.game.paused=false
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=pressed
		click.position=(scene.BATTLE_ORIGIN+scene.battle_point(Vector2(ore.x,ore.y)))*Vector2(root.size)/Vector2(2048,1280)
		Input.parse_input_event(click)
		await process_frame
	check(not scene.game.drops.has(ore),"Clicking remapped drop collects the original logical drop")
	scene.game.paused=true
	scene.refresh_draw_layers(0)
	await process_frame
	await RenderingServer.frame_post_draw
	scene.get_viewport().get_texture().get_image().save_png("res://.runtime/vertical-combat-wide-page.png")
	scene.game.profile.cleared=range(1,51)
	scene.game.profile.highestLevel=51
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.refresh_structure()
	for index in scene.equipment_tabs.get_tab_count():
		if scene.equipment_tabs.is_tab_hidden(index):continue
		scene.equipment_tabs.current_tab=index
		await process_frame
		check(scene.battle_layer.visible and scene.equipment_tabs.get_global_rect().position.x>=600 and scene.equipment_tabs.size.x==1364,"Full page %d remains beside battle" % index)
		await RenderingServer.frame_post_draw
		scene.get_viewport().get_texture().get_image().save_png("res://.runtime/vertical-full-page-%d.png" % index)
	scene.equipment_tabs.current_tab=0
	scene.game.switch_ship("Heavy_Battleship")
	scene.game.start(1,false)
	scene.game.group_index=scene.db.levels[0].groups.size()-1
	scene.game.spawn_group()
	scene.game.paused=true
	var simulation: Dictionary={"player":scene.game.player.duplicate(true),"enemies":scene.game.enemies.duplicate(true)}
	scene.refresh_draw_layers(0)
	await process_frame
	await RenderingServer.frame_post_draw
	check(simulation.player==scene.game.player and simulation.enemies==scene.game.enemies,"Visual remapping never mutates combat entities")
	check(scene.player_render_position().y+scene.player_visible_tail()+float(scene.battle_visual.player_hud_gap)<=1132.0-scene.BATTLE_ORIGIN.y,"Largest rendered player hull fits above bottom HUD")
	scene.get_viewport().get_texture().get_image().save_png("res://.runtime/vertical-boss-hud.png")
	print("Vertical combat logic: ",checks," checks, ",failures," failures")
	scene.queue_free()
	quit(0 if failures==0 else 1)
