extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	var texture_misses: Array[String] = []
	var bounds_misses := 0
	func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
	func show_chrono_login_report() -> void:pass
	func visual_texture(path: String) -> Texture2D:
		if not path.is_empty() and not visual_textures.has(path):texture_misses.append(path)
		return super.visual_texture(path)
	func enemy_hull_bounds(texture: Texture2D) -> Rect2:
		if not hull_opaque_bounds.has(texture.get_instance_id()):bounds_misses+=1
		return super.enemy_hull_bounds(texture)
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene=load("res://main.tscn").instantiate()
	scene.set_script(IsolatedUI)
	scene.automation_args=["--capture"];scene.music_on=false
	root.add_child(scene);current_scene=scene;scene.set_process(false)
	scene.game.speed=1;scene.equipment_panel.set_upgrade_amount(1)
	check(scene.bounds_misses==6,"six hull bounds ready before the first process frame")
	var profile=scene.game.profile.duplicate(true)
	var player=scene.game.player.duplicate(true)
	var rng_state=scene.game.rng.state
	scene.texture_misses.clear();scene.bounds_misses=0
	for size_class in range(1,7):
		var texture=scene.ship_hull_texture("enemy_"+str(size_class))
		var pixels=texture.get_image().get_used_rect()
		var expected=Rect2(Vector2(pixels.position)/texture.get_size()-Vector2(0.5,0.5),Vector2(pixels.size)/texture.get_size())
		check(scene.enemy_hull_bounds(texture)==expected,"original silhouette formula "+str(size_class))
	check(scene.texture_misses.is_empty() and scene.bounds_misses==0,"all hulls and bounds reused")
	check(scene.game.profile==profile and scene.game.player==player and scene.game.rng.state==rng_state,"preparation reads cannot change gameplay state or RNG")
	scene.game.rng.seed=1701;scene.game.state=BattleGame.State.COMBAT;scene.game.spawn_group()
	var enemy=scene.game.enemies[0].duplicate(true)
	enemy.size=6
	scene.game.enemies.clear();scene.game.enemies.append(enemy)
	scene._process(0.0)
	await process_frame
	await process_frame
	check(scene.bounds_misses==0,"previously unseen encounter performs no hull readback or scan")
	for path in scene.texture_misses:check(not path.contains("assets/ships/enemy/"),"previously unseen encounter does not load a hull")
	scene.game.launch_provider=Callable();scene.game.target_provider=Callable()
	scene.queue_free();await process_frame;await process_frame
	print("ENEMY HULL WARMUP: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
