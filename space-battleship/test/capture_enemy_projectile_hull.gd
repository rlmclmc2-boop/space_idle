extends SceneTree
# Graphical evidence only: one authored hostile laser approaching the player hull.
class UI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame: return super.create_battle_game(false)
	func show_qa_tools() -> void: pass
	func show_chrono_login_report() -> void: pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.set_script(UI)
	scene.automation_args = ["--capture"]
	scene.music_on = false
	root.add_child(scene)
	current_scene = scene
	scene.automation_args = []
	scene.set_process(false)
	var game: BattleGame = scene.game
	game.save_enabled = false
	game.profile.onboarding.completed = true
	if is_instance_valid(scene.beginner_guide): scene.beginner_guide.hide()
	scene.set_intro_pause(false)
	game.paused = false
	game.native_execution_requested = false
	game.state = BattleGame.State.COMBAT
	game.projectiles.clear()
	var weapon: Dictionary = game.db.enemy_weapon("laser_mon")
	var source := {"x":float(game.player.x),"y":float(game.player.y)-90.0,"uid":999999,"hp":1.0}
	var armour_before: float = float(game.player.armour)
	game.fire(source,game.player,weapon,10.0,true,"laser_mon")
	if game.projectiles.size() != 1:
		push_error("HOSTILE_PROJECTILE_CAPTURE no projectile")
		quit(1)
		return
	var aim: Vector2 = game.projectile_target_point(game.projectiles[0])
	print("HOSTILE_PROJECTILE_AIM ",aim," direction=",game.projectiles[0].direction," render_center=",scene.player_render_position()," nose_offset=",scene.player_visible_nose()," contact_screen=",scene.player_contact_screen_position())
	if scene.battle_slice_runtime != null:
		print("HOSTILE_PROJECTILE_NATIVE_AIM ",scene.battle_slice_runtime.geometry.target_point(game.player))
	var step := 12.0 / maxf(1.0,float(game.projectiles[0].speed))
	var folder := ProjectSettings.globalize_path("res://.runtime/enemy-projectile-hull")
	DirAccess.make_dir_recursive_absolute(folder)
	var rows: Array = []
	var contact_screen: Vector2 = scene.player_contact_screen_position()
	for frame in range(20):
		scene.refresh_draw_layers(0.0)
		scene.battle_layer.queue_redraw()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/frame-%02d.png" % frame)
		var screen_y = null
		if not game.projectiles.is_empty():
			var shot: Dictionary = game.projectiles[0]
			var visual: Dictionary = scene.projectile_visual(shot)
			screen_y = scene.battle_point(scene.missile_visual_position(shot,0.0,Vector2(visual.get("origin",scene.visual_muzzle(shot))),visual)).y
		rows.append({"frame":frame,"shot_count":game.projectiles.size(),"shot_y":float(game.projectiles[0].y) if not game.projectiles.is_empty() else null,"screen_y":screen_y,"player_y":float(game.player.y),"logical_hit_y":aim.y,"contact_y":scene.battle_logical_point(contact_screen).y,"contact_screen_y":contact_screen.y,"armour_loss":armour_before-float(game.player.armour)})
		if not game.projectiles.is_empty(): game.tick_projectiles(step)
	var output := FileAccess.open(folder+"/trace.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"step_seconds":step,"rows":rows},"  "))
	print("HOSTILE_PROJECTILE_CAPTURE ",folder," frames=",rows.size()," final_loss=",armour_before-float(game.player.armour))
	var crosses_hull := rows.any(func(row):return row.screen_y != null and float(row.screen_y)>contact_screen.y+1.0)
	quit(1 if crosses_hull or armour_before-float(game.player.armour)<=0.0 else 0)
