extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame:
		return super.create_battle_game(false)
	func show_qa_tools() -> void:pass

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;printerr("FAIL: ",label)

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.set_script(IsolatedUI)
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	scene.music.stop();scene.music.stream=null
	var game: BattleGame=scene.game
	game.save_enabled=false
	game.native_execution_auto=false
	game.pending_unlocks.clear()
	game.profile.onboarding.completed=true
	game.profile.onboarding.dismissed=true
	game.profile.unlocked=["laser","armour","shield"]
	check(game.equip_slot("defence",0,"shield"),"main scene equips pure shield")
	check(game.start(1,false),"main scene starts first stage")
	game.spawn_group()
	check(game.state==BattleGame.State.COMBAT,"main scene enters combat")
	check(game.player.armour==0 and game.player.shield>0 and game.player_alive(),"pure shield is live in main scene")
	game.cooldowns[game.slot_id("weapons",0)]=0.0
	var shots:int=game.main_attack_serial
	for index in 12:
		scene._process(1.0/60.0)
		await process_frame
	print("Main scene attacks: %d to %d; turret count: %d" % [shots,game.main_attack_serial,scene.ship_view.modules.size()])
	check(game.main_attack_serial>shots,"visible one-slot ship attacks")
	check(scene.ship_view.modules.size()==1 and scene.ship_view.carriers.is_empty(),"one physical turret and no visual carrier")
	check(scene.ship_view.visible and scene.ship_view.shield.visible,"pure shield hull and shield visible")
	await RenderingServer.frame_post_draw
	var screenshot:=OS.get_environment("MAIN_PURE_SHIELD_OUTPUT")
	if not screenshot.is_empty():
		check(root.get_texture().get_image().save_png(screenshot)==OK,"main scene screenshot")
	game.hit_player(1.0e9,1)
	check(game.state==BattleGame.State.RETREAT and not game.player_alive(),"pure shield death retreats")
	game.tick(1.3)
	check(game.state==BattleGame.State.TRAVEL and game.player_alive() and game.player.armour==0,"pure shield restores after retreat")
	check(not game.save_enabled,"fixture never writes player save")
	print("Main pure shield: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	quit(1 if failures else 0)
