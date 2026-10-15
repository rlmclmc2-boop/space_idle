extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ShipDatabase.new()
	for level in [1, 2, 3]:
		check(db.levels[level - 1].groups.size() == level + 4, "authored point count level " + str(level))
	for id in range(270001, 270009):
		check(db.enemies.has(str(id)) and str(db.enemies[str(id)].get("archetype_id", "")) != "", "stable archetype " + str(id))
	check(is_equal_approx(float(db.equipment.laser[0].cd), 1.5) and is_equal_approx(float(db.equipment.laser[0].dmg), 350.0), "pulse timing and damage")
	var g := BattleGame.new(db, false)
	g.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	g.profile.loadout = {"weapons": [{"key":"missile","level":1}], "defence": [{"key":"armour","level":1},{"key":"shield","level":1}]}
	g.reset_player()
	g.change_state(BattleGame.State.TRAVEL)
	check(is_equal_approx(float(g.cooldowns.get(g.slot_id("weapons",0),99)),0.4), "missile first salvo after travel")
	g.change_state(BattleGame.State.COMBAT)
	g.invalidate_module_attack(0)
	check(float(g.cooldowns.get(g.slot_id("weapons",0),0)) > 0.4, "refit cannot refresh quick salvo")
	# Armour receives the hit when shield is empty; the empty shield must wait.
	g.player.shield = 0
	g.sync_jewel_defence_damage()
	g.since_hit = 0.0
	g.jewel_defence_times.clear()
	g.advance_jewel_repair(1.9)
	g.hit_player(5, 2)
	g.advance_jewel_repair(0.2)
	check(is_equal_approx(float(g.player.shield),0.0), "armour hit restarts shield delay")
	g.advance_jewel_repair(2.0)
	check(float(g.player.shield) > 0.0, "shield resumes after quiet delay")
	var e: Dictionary = db.enemies["270006"].duplicate(true)
	e.uid = 77
	e.x = 200.0
	e.y = 100.0
	e.hp = 1000.0
	e.max_hp = 1000.0
	e.shield = 0.0
	e.max_shield = 0.0
	e.drops = []
	e.armourType = 0
	g.enemies.assign([e])
	for sample in [[0.0,0,1.0],[0.05,0,1.0],[1.0,1,0.8],[1.05,1,0.8],[4.0,0,1.0]]:
		g.enemy_shield_time = float(sample[0])
		g.hit_enemy(e,100.0,2)
		check(int(e.get("reactive_stacks",-1)) == int(sample[1]) and is_equal_approx(float(e.get("reactive_multiplier",0)),float(sample[2])), "reactive volley " + str(sample[0]))
	check(is_equal_approx(float(e.hp),540.0), "same-volley hits share reduction; quiet window resets")
	print("OPENING BALANCE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
