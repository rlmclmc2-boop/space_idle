extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func fixture(gem: bool, reduction := 0.0) -> BattleGame:
	var db := ShipDatabase.new()
	db.config.dmgReduce = reduction
	db.config.equipmentSocket = 10
	db.equipment.shield[0].para1 = 20
	db.equipment.shield[0].dmgtype = 1
	db.equipment.armour[0].para1 = 100
	db.equipment.armour[0].dmgtype = 2
	var g := BattleGame.new(db,false)
	g.start(1,false)
	g.spawn_group()
	g.profile.unlocked = ["armour","shield"]
	g.profile.loadout.defence = [{"key":"shield","level":1},{"key":"armour","level":1}]
	if gem:
		g.profile.loadout.defence[0].sockets = [g.new_jewel("10",1)]
	g.reset_player()
	return g
func _initialize() -> void:
	for gem in [false,true]:
		for sample in [[15,5,100],[20,0,100],[35,0,85],[150,0,0]]:
			var g := fixture(gem)
			g.hit_player(sample[0],1)
			check(g.player.shield==sample[1] and g.player.armour==sample[2], "shield/health allocation gem=%s damage=%s" % [gem,sample[0]])
			if sample[0]==150:
				check(g.state==BattleGame.State.RETREAT, "overflow lethal damage triggers retreat")
		var energy := fixture(gem,0.5)
		energy.hit_player(60,1)
		check(energy.player.shield==0 and energy.player.armour==80, "shield resistance consumes 40 raw then transfers 20")
		var physical := fixture(gem,0.5)
		physical.hit_player(60,2)
		check(physical.player.shield==0 and physical.player.armour==80, "overflow applies armour resistance after shield")
		for key in ["laser","cannon","missile"]:
			var g := fixture(gem)
			g.fire(g.enemies[0],g.player,g.db.equip(key,1),35,true,key)
			g.projectiles[0].x = g.player.x
			g.projectiles[0].y = g.player.y
			g.tick_projectiles(0.01)
			check(g.player.shield==0 and g.player.armour==85, key+" projectile transfers overflow")
		var beam := fixture(gem)
		var enemy: Dictionary = beam.enemies[0]
		enemy.dmgMultiple = 1.0
		enemy.equipment = [{"name":"longLaser-mon"}]
		beam.db.levels[0].atkRatio = 1.0
		beam.db.equipment["longLaser-mon"] = [{"level":1,"name":"longLaser-mon","dmg":35,"cd":0.2,"dmgtype":1,"para1":1,"para2":1,"para3":0.2}]
		beam.lock_long_laser(enemy,beam.db.enemy_weapon("longLaser-mon"),true,0,enemy.equipment[0])
		beam.tick_projectiles(0.2)
		check(beam.player.shield==0 and beam.player.armour==85,"beam periodic hit transfers overflow")
	print("Shield overflow: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
