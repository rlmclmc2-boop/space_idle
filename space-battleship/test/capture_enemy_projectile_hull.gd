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
	var step := 12.0 / maxf(1.0,float(game.projectiles[0].speed))
	var folder := ProjectSettings.globalize_path("res://.runtime/enemy-projectile-hull")
	DirAccess.make_dir_recursive_absolute(folder)
	var rows: Array = []
	for frame in range(12):
		scene.refresh_draw_layers(0.0)
		scene.battle_layer.queue_redraw()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/frame-%02d.png" % frame)
		rows.append({"frame":frame,"shot_count":game.projectiles.size(),"shot_y":float(game.projectiles[0].y) if not game.projectiles.is_empty() else null,"player_y":float(game.player.y),"armour_loss":armour_before-float(game.player.armour)})
		if not game.projectiles.is_empty(): game.tick_projectiles(step)
	var output := FileAccess.open(folder+"/trace.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"step_seconds":step,"rows":rows},"  "))
	print("HOSTILE_PROJECTILE_CAPTURE ",folder," frames=",rows.size()," final_loss=",armour_before-float(game.player.armour))
	quit(0)
