extends SceneTree

class ScaledGame extends "res://scripts/game.gd":
	var balance_scale := 1.0
	func equipment_stat(key: String, level: int, galaxy_charge := -1.0) -> Variant:
		var derived = super.equipment_stat(key,level,galaxy_charge)
		return GrowthNumber.multiply(derived,balance_scale) if key in ["laser","missile","cannon","longLaser","armour","shield"] else derived

var checks := 0
var failures := 0
var unresolved_extreme := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func close_ratio(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= 0.000001

func frozen_db() -> ShipDatabase:
	var db := ShipDatabase.new()
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://qa/opening_frozen_contract.json"))
	for index in 3:db.levels[index] = original.levels[index]
	for id in original.groups:db.groups[id] = original.groups[id]
	return db

func fixture(scale: float) -> BattleGame:
	var db := frozen_db()
	db.config.dmgReduce = 0.0
	var g := BattleGame.new(db, false)
	g.save_enabled = false
	g.start(1, false)
	g.spawn_group()
	var enemy: Dictionary = db.enemies["270007"].duplicate(true)
	enemy.uid = 991
	enemy.slot = 7
	enemy.x = 286.0
	enemy.y = 100.0
	enemy.hp = 1000.0 * scale
	enemy.max_hp = enemy.hp
	enemy.shield = 600.0 * scale
	enemy.max_shield = enemy.shield
	enemy.shieldDelay = 0.5
	enemy.shieldRecovery = 0.08
	enemy.shieldType = 2
	enemy.armourType = 0
	enemy.shield_hit_at = 0.0
	enemy.shield_updated_at = 0.0
	enemy.equipment = []
	enemy.cooldowns = []
	enemy.drops = []
	g.enemies.assign([enemy])
	g.enemy_shield_time = 0.0
	return g

func defence_fixture(scale: float) -> ScaledGame:
	var db := frozen_db()
	db.data.enhance_config.threshold_2.value = 1000
	db.data.enhance_config.threshold_3.value = 2000
	var g := ScaledGame.new(db,false)
	g.balance_scale = scale
	g.save_enabled = false
	g.start(1,false)
	g.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	g.profile.grantedUnlocks = [db.unlock_id("feature","jewels")]
	g.profile.enhancementLevel = 10
	g.profile.enhancementOrder.defence = ["memory_material","adaptation","delayed_damage"]
	g.profile.loadout = {"weapons":[],"defence":[{"key":"armour","level":1},{"key":"shield","level":1}]}
	g.reset_player()
	g.state = BattleGame.State.COMBAT
	return g

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var defence_baseline := {}
	for scale in [1.0, 100.0, 1000.0, 100000.0, 1.0e40]:
		var g := fixture(scale)
		var enemy: Dictionary = g.enemies[0]
		g.hit_enemy(enemy, 200.0 * scale, 1)
		check(close_ratio(float(enemy.shield) / scale, 400.0), "shield absorption scale=" + str(scale))
		g.advance_enemy_shields(1.2)
		check(close_ratio(float(enemy.shield) / scale, 433.6), "fractional shield repair scale=" + str(scale))
		g.hit_enemy(enemy, 200.0 * scale, 1)
		check(close_ratio(float(enemy.shield) / scale, 233.6), "second hit scale=" + str(scale))
		enemy.shield = 0.0
		enemy.max_shield = 0.0
		enemy.hp = 1000.0 * scale
		enemy.max_hp = enemy.hp
		enemy.reactiveReduction = 1
		for sample in [[1.3, 0, 1.0], [1.35, 0, 1.0], [2.3, 1, 0.8], [2.35, 1, 0.8], [5.0, 0, 1.0]]:
			g.enemy_shield_time = float(sample[0])
			g.hit_enemy(enemy, 100.0 * scale, 1)
			check(int(enemy.reactive_stacks) == int(sample[1]) and close_ratio(float(enemy.reactive_multiplier), float(sample[2])), "reactive volley scale=" + str(scale) + " t=" + str(sample[0]))
		check(close_ratio(float(enemy.hp) / scale, 540.0), "reactive normalized HP scale=" + str(scale))
		var defence := defence_fixture(scale)
		defence.advance_jewel_repair(20.0)
		var buffer_before: float = float(defence.enhancement_protection_current()) / scale
		defence.hit_player(100.0 * scale, 2)
		var buffer_after: float = float(defence.enhancement_protection_current()) / scale
		defence.hit_player(1000.0 * scale, 2)
		var result := {"buffer_before":buffer_before,"buffer_after":buffer_after,"shield":float(defence.player.shield)/scale,"armour":float(defence.player.armour)/scale}
		if defence_baseline.is_empty():defence_baseline = result
		for key in result:
			check(close_ratio(float(result[key]),float(defence_baseline[key])), "bilateral protection/defence scale=" + str(scale) + " field=" + key)
	var real_remainder := fixture(1.0)
	var real_enemy: Dictionary = real_remainder.enemies[0]
	real_enemy.hp = 1.0e15
	real_enemy.max_hp = 1.0e20
	real_enemy.shield = 0.0
	real_enemy.max_shield = 0.0
	real_enemy.reactiveReduction = 0
	real_remainder.hit_enemy(real_enemy,1.0e15-5.0e7,1)
	check(float(real_enemy.hp) == 5.0e7,"legacy preserves representable 50-million HP remainder")
	var boundary := fixture(1.0e40)
	var boundary_enemy: Dictionary = boundary.enemies[0]
	boundary_enemy.hp = 5000.0 * 1.0e40
	boundary_enemy.max_hp = boundary_enemy.hp
	boundary_enemy.shield = 0.0
	boundary_enemy.max_shield = 0.0
	boundary_enemy.reactiveReduction = 0
	for shot in 25:boundary.hit_enemy(boundary_enemy,200.0 * 1.0e40,1)
	var residual: float = float(boundary_enemy.hp) / 1.0e40
	print("LEGACY_BOUNDARY 1e40 residual_normalized=",residual)
	if residual != 0.0:
		unresolved_extreme += 1
		printerr("UNRESOLVED legacy exact-25-hit boundary at 1e40: ",residual)
	print("WEAPON SCALE CONTRACT: ", checks, " checked, ", failures, " failures, ",unresolved_extreme," unresolved extreme boundary")
	quit(1 if failures or unresolved_extreme else 0)
