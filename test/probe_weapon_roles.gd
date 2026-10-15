extends SceneTree

# Focused, non-playthrough probe. Run only in the agreed serial Godot window.
class ScaledGame extends "res://scripts/presented_battle_game.gd":
	var balance_scale := 1.0
	var measured := {"hp_loss":0.0,"shield_loss":0.0,"shield_regen":0.0,"overkill":0.0,"reported":0.0}
	func equipment_stat(key: String, level: int, galaxy_charge := -1.0) -> Variant:
		var derived = super.equipment_stat(key,level,galaxy_charge)
		return GrowthNumber.multiply(derived,balance_scale) if key in ["laser","missile","cannon","longLaser","armour","shield"] else derived
	func settle_enemy_shield(enemy: Dictionary, at: float) -> bool:
		var before := float(enemy.get("shield",0))
		var accepted := super.settle_enemy_shield(enemy,at)
		if accepted and float(enemy.get("shield",0)) > before:
			measured.shield_regen += (float(enemy.shield)-before)/balance_scale
		return accepted
	func hit_enemy(enemy: Dictionary, raw, type: int, effects: Array = [], critical: bool = false, context: Dictionary = {}) -> void:
		if not settle_enemy_shield(enemy,enemy_shield_time if enemy_shield_hit_time < 0 else enemy_shield_hit_time):return
		var before_hp := float(enemy.hp)
		var before_shield := float(enemy.get("shield",0))
		var before_reported := float(measured.reported)
		super.hit_enemy(enemy,raw,type,effects,critical,context)
		var hp_loss := maxf(0.0,before_hp-float(enemy.hp))/balance_scale
		var shield_loss := maxf(0.0,before_shield-float(enemy.get("shield",0)))/balance_scale
		measured.hp_loss += hp_loss
		measured.shield_loss += shield_loss
		measured.overkill += maxf(0.0,float(measured.reported)-before_reported-hp_loss-shield_loss)

const WEAPONS := ["laser", "missile", "cannon", "longLaser"]
const CASES := {
	"medium": {"count":5,"hp":300.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":false},
	"swarm": {"count":10,"hp":180.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":false},
	"heavy": {"count":2,"hp":5000.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":false},
	"reactive": {"count":2,"hp":5000.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":true},
	"recovering_plain": {"count":1,"hp":1700.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":false},
	"recovering": {"count":1,"hp":1100.0,"shield":600.0,"delay":0.8,"rate":0.35,"reactive":false},
	"candidate_a": {"count":1,"hp":1100.0,"shield":600.0,"delay":0.8,"rate":0.35,"reactive":false},
	"candidate_b": {"count":1,"hp":1100.0,"shield":1200.0,"delay":0.8,"rate":0.20,"reactive":false},
}

func frozen_db() -> ShipDatabase:
	var db := ShipDatabase.new()
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://qa/opening_frozen_contract.json"))
	for index in 3:db.levels[index] = original.levels[index]
	for id in original.groups:db.groups[id] = original.groups[id]
	return db

func run_case(weapon: String, case_name: String, scale: float, weapon_level := 1, mounts := 1, missile_base := 160.0) -> Dictionary:
	var settings: Dictionary = CASES[case_name]
	var db := frozen_db()
	db.data.enhance_config.base_critical_rate.value = 0.0
	if weapon == "missile":db.equipment.missile[0].dmg = missile_base
	var g: ScaledGame = ScaledGame.new(db, false)
	g.balance_scale = scale
	g.save_enabled = false
	g.stat_cache_enabled = true
	g.rng.seed = 1729
	g.start(1, false)
	g.spawn_group()
	g.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	g.profile.enhancementLevel = 0
	g.profile.loadout = g.empty_loadout(g.profile.selectedShip)
	for mount in mounts:g.profile.loadout.weapons[mount] = {"key":weapon,"level":weapon_level}
	g.profile.loadout.defence[0] = {"key":"armour","level":1}
	g.reset_player()
	var derived_normalized := float(g.equipment_stat(weapon,weapon_level)) / scale
	var actors: Array[Dictionary] = []
	for index in int(settings.count):
		var enemy: Dictionary = db.enemies["270001"].duplicate(true)
		enemy.uid = index + 1
		enemy.slot = index
		enemy.x = 70.0 + float(index % 5) * 105.0
		enemy.y = 100.0 + float(index / 5) * 125.0
		enemy.hp = float(settings.hp) * scale
		enemy.max_hp = enemy.hp
		enemy.shield = float(settings.shield) * scale
		enemy.max_shield = enemy.shield
		enemy.shieldDelay = float(settings.delay)
		enemy.shieldRecovery = float(settings.rate)
		enemy.shieldType = 2
		enemy.armourType = 0
		enemy.shield_hit_at = 0.0
		enemy.shield_updated_at = 0.0
		enemy.equipment = []
		enemy.cooldowns = []
		enemy.drops = []
		if bool(settings.reactive):enemy.reactiveReduction = 1
		actors.append(enemy)
	g.enemies.assign(actors)
	g.call("refresh_missile_target_registry")
	g.change_state(BattleGame.State.TRAVEL)
	g.change_state(BattleGame.State.COMBAT)
	var observed := {"first_fire":-1.0,"first_hit":-1.0,"hit_total":0.0,"hit_count":0}
	g.event.connect(func(kind: String, payload: Dictionary) -> void:
		if kind == "fire" and observed.first_fire < 0 and not bool(payload.get("shot",{}).get("hostile",false)):
			observed.first_fire = g.enemy_shield_time
		if kind == "hit" and not bool(payload.get("player",false)):
			if observed.first_hit < 0:observed.first_hit = g.enemy_shield_time
			observed.hit_total += float(payload.amount) / scale
			observed.hit_count += 1
			g.measured.reported += float(payload.amount) / scale
	)
	var elapsed := 0.0
	var max_reactive_stacks := 0
	for step in 3600:
		g.tick(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		for actor in actors:max_reactive_stacks = maxi(max_reactive_stacks,int(actor.get("reactive_stacks",0)))
		if actors.all(func(actor):return float(actor.hp) <= 0.0):break
	var cleared := actors.all(func(actor):return float(actor.hp) <= 0.0)
	return {"executor":"legacy_presented","production_stat_cache":g.stat_cache_enabled,"rng_seed":1729,"weapon":weapon,"weapon_level":weapon_level,"mounts":mounts,"case":case_name,"scale":scale,"authored_missile_base":missile_base if weapon=="missile" else null,"derived_base_normalized":derived_normalized,"first_fire":observed.first_fire,"first_hit":observed.first_hit,"kill_time":elapsed if cleared else -1.0,"hit_total_normalized":observed.hit_total,"effective_hp_loss":g.measured.hp_loss,"effective_shield_loss":g.measured.shield_loss,"shield_regen":g.measured.shield_regen,"overkill":g.measured.overkill,"max_reactive_stacks":max_reactive_stacks,"hit_count":observed.hit_count,"initial_pool_normalized":int(settings.count) * (float(settings.hp)+float(settings.shield)),"cleared":cleared}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("SPACE_BALANCE_CANDIDATES") == "1":
		for case_name in ["candidate_a","candidate_b"]:
			for weapon in WEAPONS:print(JSON.stringify(run_case(weapon,case_name,1.0)))
		print(JSON.stringify(run_case("laser","candidate_b",1.0,4)))
		print(JSON.stringify(run_case("laser","candidate_a",1.0,4)))
		for scale in [100.0,1000.0,100000.0,1.0e40]:
			for weapon in ["longLaser","laser"]:print(JSON.stringify(run_case(weapon,"candidate_a",scale)))
		for case_name in ["medium","swarm","heavy","reactive","candidate_a"]:
			print(JSON.stringify(run_case("missile",case_name,1.0,1,1,120.0)))
			print(JSON.stringify(run_case("missile",case_name,1.0,1,1,160.0)))
		quit()
		return
	for case_name in CASES:
		if str(case_name).begins_with("candidate_"):continue
		for weapon in WEAPONS:
			print(JSON.stringify(run_case(weapon,case_name,1.0)))
	# Check both expected specialist and nearest rival at each scale, with mechanics fixed.
	for scale in [100.0,1000.0,100000.0,1.0e40]:
		for pair in [["medium","laser"],["medium","missile"],["swarm","missile"],["swarm","laser"],["heavy","cannon"],["heavy","missile"],["reactive","cannon"],["reactive","missile"],["recovering","longLaser"],["recovering","laser"]]:
			print(JSON.stringify(run_case(str(pair[1]),str(pair[0]),scale)))
	print(JSON.stringify(run_case("cannon","reactive",1.0,1,2)))
	print(JSON.stringify(run_case("laser","reactive",1.0,6)))
	print(JSON.stringify(run_case("laser","recovering",1.0,4)))
	quit()
