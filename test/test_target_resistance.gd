extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	var db := ShipDatabase.new()
	for key in ["laser", "cannon", "missile"]:
		var g := BattleGame.new(db,false)
		g.start(1,false)
		g.spawn_group()
		g.profile.unlocked = [key]
		var weapon := db.equip(key,1)
		var damage_type := int(weapon.dmgtype)
		var base := g.enemies[0].duplicate(true)
		g.enemies.clear()
		for i in range(4):
			var enemy := base.duplicate(true)
			enemy.uid = i + 100
			enemy.x = 800.0 + i * 50
			enemy.hp = 1000000.0
			enemy.equipment = []
			enemy.armourType = damage_type if i < 2 else 3 - damage_type
			g.enemies.append(enemy)
		check(g.targets()[0].uid == 100,key+" default ordering unchanged")
		var ordered := g.targets(damage_type)
		check(ordered[0].uid == 102 and ordered[1].uid == 103 and ordered[2].uid == 100,key+" non-resistant first, positional ties retained")
		if key == "missile":
			weapon.para1 = 3
		g.cooldowns[key] = 0
		g.tick(0.001)
		check(g.projectiles[0].target.uid == 102,key+" actual firing prefers non-resistant")
		if key == "missile":
			check(g.projectiles.size() == 3 and g.projectiles[1].target.uid == 103 and g.projectiles[2].target.uid == 100,"Missile distinct targets fill from resistant enemies")
			g.enemies[2].hp = 0
			g.tick_projectiles(0.001)
			check(g.projectiles[0].target.uid == 101,"Missile retarget prioritizes an unlocked target")
		for enemy in g.enemies:
			enemy.armourType = damage_type
		check(g.targets(damage_type)[0].uid == 100,key+" all resistant falls back to position")
		g.projectiles.clear()
		g.cooldowns[key] = 0
		g.tick(0.001)
		check(g.projectiles[0].target.uid == 100,key+" all resistant still fires")
		if key == "missile":
			g.projectiles.clear()
			g.enemies.resize(1)
			g.cooldowns[key] = 0
			g.tick(0.001)
			check(g.projectiles.size()==3 and g.projectiles.all(func(shot):return shot.target.uid==100) and g.projectiles[0].y < g.projectiles[1].y and g.projectiles[1].y < g.projectiles[2].y,"Missile salvo remains visible with one target")
		for enemy in g.enemies:
			enemy.hp = 0
		check(g.targets(damage_type).is_empty(),key+" dead enemies excluded")
	print("Target resistance: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
