extends SceneTree
const Game = preload("res://scripts/balance_game.gd")
const Database = preload("res://scripts/balance_database.gd")
const Scan = preload("res://scripts/balance_scan.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	# Deliberately invalid scan fixture, not an ordinary game run.
	var database := Database.new()
	for actor in ["player","enemy"]:database.data.weapon_motion[actor+"_projectile_pixels_per_unit"].value=0.0
	var game := Game.new(database)
	game.rng.seed = 12345
	game.start(1,false)
	game.spawn_group()
	game.change_state(BattleGame.State.COMBAT)
	print("ZERO_SPEED_SCAN_ACCEPTED ",Scan.valid_value(["weapon_motion","player_projectile_pixels_per_unit","value"],0))
	for window in 4:
		var started := Time.get_ticks_usec()
		for step in 300:game.tick(1.0/60.0)
		print("STATIONARY sim=",game.simulated_time," projectiles=",game.projectiles.size()," steps/s=",300000000.0/(Time.get_ticks_usec()-started))
	quit()
