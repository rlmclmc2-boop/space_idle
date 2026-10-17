extends SceneTree
class UI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame: return super.create_battle_game(false)
	func show_qa_tools() -> void: pass
	func show_chrono_login_report() -> void: pass

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.set_script(UI)
	scene.automation_args = ["--capture"]
	scene.music_on = false
	root.add_child(scene)
	scene.automation_args = []
	scene.set_process(false)
	var game: BattleGame = scene.game
	game.save_enabled = false
	game.state = BattleGame.State.COMBAT
	game.paused = false
	scene.fx_time = 1.0 # Nonzero idle rotation must agree across legacy and native aim.
	var screen: Vector2 = scene.player_contact_screen_position()
	var legacy: Vector2 = scene._prototype_target_point(game.player)
	check(screen.y<scene.player_render_position().y,"contact is ahead of visible player center")
	check(scene.battle_point(legacy).distance_to(scene.player_render_position())<0.01,"legacy logical aim remains at player center")
	var geometry = preload("res://scripts/simulation_geometry_authority.gd").new()
	geometry.prepare(scene,game)
	var native: Vector2 = geometry.target_point(game.player)
	check(geometry.battle_point(native).distance_to(scene.player_render_position())<0.01,"native logical aim remains at player center")
	var source := {"x":float(game.player.x),"y":float(game.player.y)-90.0,"uid":999999,"hp":1.0}
	var armour_before := float(game.player.armour)
	game.fire(source,game.player,game.db.enemy_weapon("laser_mon"),10.0,true,"laser_mon")
	check(game.projectiles.size()==1 and game.projectiles[0].direction.y>0.0,"hostile logical bolt still aims at center")
	var shot: Dictionary = game.projectiles[0]
	var visual: Dictionary = scene.projectile_visual(shot)
	var projected_end: Vector2 = Vector2(visual.fixed_origin)+Vector2(visual.fixed_step)*game.projectile_position(shot).distance_to(Vector2(game.player.x,game.player.y))
	check(projected_end.distance_to(screen)<0.01,"rendered bolt stops at visible hull front")
	var impacts: Array = []
	game.event.connect(func(kind,info):
		if kind=="projectile_impact":impacts.append(info.pos))
	for i in range(10):game.tick_projectiles(12.0/float(game.db.enemy_weapon("laser_mon").para1)/game.db.projectile_pixels_per_unit(true))
	check(impacts.size()==1 and Vector2(impacts[0]).distance_to(Vector2(game.player.x,game.player.y))<0.01,"one logical impact at original player point")
	check(is_equal_approx(armour_before-float(game.player.armour),10.0),"single damage application")
	print("ENEMY_PROJECTILE_CONTACT checks=",checks," failures=",failures)
	geometry.close()
	geometry = null
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
