extends SceneTree
const Game = preload("res://scripts/balance_game.gd")
const Database = preload("res://scripts/balance_database.gd")
const Runner = preload("res://scripts/balance_runner.gd")
const Metrics = preload("res://scripts/balance_metrics.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func fixture(mode: String, weapon: String):
	var game = Game.new(Database.new())
	game.simulation_mode = mode
	game.rng.seed = 888
	game.profile.highestLevel = game.db.levels.size()
	game.profile.cleared = range(1,game.db.levels.size()+1)
	game.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	game.db.config.equipmentSocket = 20
	game.equip_slot("weapons",0,weapon)
	for index in range(1,game.weapon_entries().size()):game.unequip_slot("weapons",index)
	for id in game.db.data.jewel:
		var gem: Dictionary = game.new_jewel(str(id),2)
		game.profile.jewels.append(gem)
		var category := "weapons" if game.jewel_allowed(str(id),"weapons") else "defence"
		var entry: Dictionary = game.slot_entry(category,0)
		game.socket_jewel(category,0,entry.get("sockets",[]).size(),int(gem.token))
	game.metrics = Metrics.new()
	game.metrics.initialize(game)
	game.start(1,false)
	return game
func run() -> void:
	var runner = Runner.new()
	check(runner.start({"simulation_mode":"bad"}) == "invalid_simulation_mode","invalid mode rejected")
	for weapon in BattleGame.WEAPON_KEYS:
		var exact = fixture("exact",weapon)
		var fast = fixture("fast",weapon)
		for step in 3600:
			exact.tick(1.0/60.0)
			fast.tick(1.0/60.0)
		check(exact.profile == fast.profile,"all compatible gems/charge/upgrade resources "+weapon)
		check(exact.metrics.damage == fast.metrics.damage,"damage and AOE once "+weapon)
		check(exact.metrics.kills == fast.metrics.kills and exact.metrics.deaths == fast.metrics.deaths,"kills/deaths "+weapon)
		check(exact.rng.state == fast.rng.state,"critical/drop RNG "+weapon)
		check(fast.fast_scheduled > 0,"ordinary projectiles scheduled "+weapon)
		if weapon in ["missile","longLaser"]:check(fast.fast_fallback > 0,"special weapon fallback "+weapon)
	# Heap ordering, cancellation and target removal are explicit boundary tests.
	var game = fixture("fast","laser")
	game.start(1,false)
	game.spawn_group()
	var enemy: Dictionary = game.enemies[0]
	var weapon: Dictionary = game.db.equip("laser",1)
	game.fire(game.player,enemy,weapon,1,false,"laser")
	game.tick_projectiles(1.0/60.0)
	check(game.pending_hits.size() == 1 and game.projectiles.is_empty(),"flight leaves active array")
	var hp: float = enemy.hp
	game.enemies.clear()
	for step in 300:game.tick_projectiles(1.0/60.0)
	check(enemy.hp == hp and game.pending_hits.is_empty(),"removed target never hit or retargeted")
	game.spawn_group()
	game.fire(game.enemies[0],game.player,weapon,1,true,"laser-mon")
	game.tick_projectiles(1.0/60.0)
	game.begin_retreat()
	check(game.pending_hits.is_empty(),"death cancels pending before player reset")
	game.start(1,false)
	game.spawn_group()
	game.fire(game.player,game.enemies[0],weapon,1,false,"laser")
	game.tick_projectiles(1.0/60.0)
	game.leave(BattleGame.State.TRAVEL)
	check(game.pending_hits.is_empty(),"leave clears pending")
	for serial in [8,1,9,3,2]:game.push_hit({"due":serial%2,"shot":{"serial":serial}})
	var order := []
	while not game.pending_hits.is_empty():order.append(game.pop_hit().shot.serial)
	check(order == [2,8,1,3,9],"heap due and serial order")
	# A hostile ordinary projectile survives shooter death and normal wave end.
	game = fixture("fast","laser")
	game.spawn_group()
	var shooter: Dictionary = game.enemies[0]
	game.player.shield = 0
	game.fire(shooter,game.player,weapon,1,true,"laser_mon")
	game.tick_projectiles(1.0/60.0)
	var health: float = game.player.armour
	for target in game.enemies:target.hp = 0
	game.change_state(BattleGame.State.TRAVEL)
	for step in 300:game.tick_projectiles(1.0/60.0)
	check(game.player.armour < health,"dead shooter still hits after ordinary wave clear")
	# Retargeting remains in the original missile implementation.
	game = fixture("fast","missile")
	game.spawn_group()
	var original: Dictionary = game.enemies[0]
	game.fire(game.player,original,game.db.equip("missile",1),1,false,"missile")
	var missile: Dictionary = game.projectiles.back()
	original.hp = 0
	game.tick_projectiles(1.0/60.0)
	check(game.pending_hits.is_empty() and not missile.target.is_empty() and not is_same(missile.target,original),"missile fallback retargets")
	# Boss clear cancels both future and same-step impacts in original order.
	for mode in ["exact","fast"]:
		game = fixture(mode,"laser")
		game.group_index = game.db.levels[0].groups.size()-1
		game.spawn_group()
		var boss: Dictionary = game.enemies[0]
		game.enemies.assign([boss])
		boss.hp = 1
		game.player.shield = 0
		game.player.armour = 1
		game.fire(game.player,boss,weapon,1000000,false,"laser")
		game.projectiles.back().x = boss.x
		game.projectiles.back().y = boss.y
		game.fire(boss,game.player,weapon,1000000,true,"laser_mon")
		game.projectiles.back().x = game.player.x
		game.projectiles.back().y = game.player.y
		game.fire(boss,game.player,weapon,1000000,true,"laser_mon")
		game.tick_projectiles(1.0/60.0)
		check(boss.hp == 0 and game.player.armour == 1 and game.pending_hits.is_empty() and game.projectiles.is_empty(),"boss clears future and same-tick shots "+mode)
	check(runner.start({"duration":30,"simulation_mode":"fast","performance_diagnostics":false}) == "","FAST runner starts")
	runner.game.spawn_group()
	runner.game.fire(runner.game.player,runner.game.enemies[0],weapon,1,false,"laser")
	runner.game.tick_projectiles(1.0/60.0)
	check(not runner.game.pending_hits.is_empty(),"reset fixture owns pending hit")
	var reference: WeakRef = weakref(runner.game)
	runner.reset()
	check(reference.get_ref() == null,"reset releases game and heap target references")
	for special in ["piercing","missile","longLaser"]:
		game = fixture("fast","laser")
		game.spawn_group()
		var special_weapon: Dictionary = game.db.equip(special,1) if special in BattleGame.WEAPON_KEYS else weapon
		game.fire(game.player,game.enemies[0],special_weapon,1,false,special)
		game.tick_projectiles(1.0/60.0)
		check(game.fast_scheduled == 0 and game.fast_fallback == 1,"unapproved attack retains original projectile: "+special)
	game = fixture("fast","laser")
	game.spawn_group()
	game.fire(game.player,game.enemies[0],weapon,1,false,"laser")
	game.projectiles.back().speed = 0
	game.tick_projectiles(1.0/60.0)
	check(game.pending_hits.is_empty() and game.projectiles.size() == 1,"zero speed is not scheduled or deleted")
	print("FAST checks=",checks," failures=",failures)
	quit(1 if failures else 0)
