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
	var g := BattleGame.new(db, false)
	g.profile.unlocked = []
	# Current mon |2 projection must create two independent base-damage mounts.
	g.start(1, false)
	for eid in ["5", "6"]:
		db.groups["count_test"] = {"slots":[int(eid)]}
		db.levels[0].groups = [{"id":"count_test", "position":0.0}]
		# spawn_group expects numeric group IDs.
		db.groups["999"] = db.groups["count_test"]
		db.levels[0].groups[0].id = 999
		g.group_index = 0
		g.spawn_group()
		var spawned: Dictionary = g.enemies[0]
		check(spawned.equipment.size() == 2 and spawned.cooldowns.size() == 2, "Quantity 2 spawns two independent mounts")
		spawned.cooldowns = [0.0, 0.0]
		g.projectiles.clear()
		g.tick(0.0)
		check(g.projectiles.size() == 2, "Quantity 2 fires two shots")
		for shot in g.projectiles:
			var base := db.equip(shot.key, 1)
			check(shot.damage == ceilf(float(base.dmg) * float(spawned.dmgMultiple) * g.ratio("atkRatio")), "Each shot uses enemy base damage")
	for boss in [false, true]:
		for count in [1, 2, 3, 6]:
			var equipment: Array = []
			for i in range(count):
				equipment.append({"name":"laser_mon"})
				equipment.append({"name":"cannon_mon"})
			var enemy := {"x":1130.0,"y":400.0,"hp":1000.0,"boss":boss,"equipment":equipment,"cooldowns":[],"dmgMultiple":1.0}
			for entry in equipment:
				enemy.cooldowns.append(0.0)
			g.enemies.assign([enemy])
			g.projectiles.clear()
			g.state = BattleGame.State.COMBAT
			g.tick(0.0)
			check(g.projectiles.size() == count * 2, "One shot per equipment entry")
			for kind in range(2):
				var first: Dictionary = g.projectiles[kind]
				var last: Dictionary = g.projectiles[(count - 1) * 2 + kind]
				check(is_equal_approx(first.y + last.y, 800.0), "Symmetric mounts")
				check(is_equal_approx(first.y, 400.0) if count == 1 else first.y < last.y, "Single centered or duplicates separated")
				for i in range(count):
					var shot: Dictionary = g.projectiles[i * 2 + kind]
					check(is_equal_approx(shot.y, lerpf(first.y, last.y, float(i) / maxf(1, count - 1))), "Even spacing independent of interleaved type")
					check(shot.direction.is_equal_approx((Vector2(g.player.x,g.player.y)-Vector2(shot.x,shot.y)).normalized()), "Aim follows actual mount")
					var weapon := db.enemy_weapon(equipment[kind].name)
					check(enemy.cooldowns[i * 2 + kind] == float(weapon.cd) and shot.damage == ceilf(float(weapon.dmg) * g.ratio("atkRatio")), "Cooldown and damage preserved")
	var weapon := db.equip("laser", 1)
	g.fire(g.player, g.enemies[0], weapon, 1, false, "laser")
	check(g.projectiles.back().x == g.player.x + 70 and g.projectiles.back().y == g.player.y, "Player origin preserved")
	print("Enemy weapon positions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
