extends SceneTree

# Focused, non-playthrough probe. Run only in the agreed serial Godot window.
const WEAPONS := ["laser", "missile", "cannon", "longLaser"]
const BASE_DAMAGE := {"laser":300.0,"missile":200.0,"cannon":1500.0,"longLaser":35.0}
const CASES := {
	"medium": {"count":5,"hp":300.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":false},
	"swarm": {"count":10,"hp":180.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":false},
	"heavy": {"count":2,"hp":5000.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":false},
	"reactive": {"count":2,"hp":5000.0,"shield":0.0,"delay":0.0,"rate":0.0,"reactive":true},
	"recovering": {"count":1,"hp":1100.0,"shield":600.0,"delay":1.8,"rate":0.08,"reactive":false},
}

func run_case(weapon: String, case_name: String, scale: float) -> Dictionary:
	var settings: Dictionary = CASES[case_name]
	var db := ShipDatabase.new()
	db.data.enhance_config.base_critical_rate.value = 0.0
	db.equipment[weapon][0].dmg = BASE_DAMAGE[weapon] * scale
	var g: BattleGame = load("res://scripts/presented_battle_game.gd").new(db, false)
	g.save_enabled = false
	g.start(1, false)
	g.spawn_group()
	g.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	g.profile.enhancementLevel = 0
	g.profile.loadout = g.empty_loadout(g.profile.selectedShip)
	g.profile.loadout.weapons[0] = {"key":weapon,"level":1}
	g.profile.loadout.defence[0] = {"key":"armour","level":1}
	g.reset_player()
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
	var observed := {"first_hit":-1.0,"hit_total":0.0,"hit_count":0}
	g.event.connect(func(kind: String, payload: Dictionary) -> void:
		if kind == "hit" and not bool(payload.get("player",false)):
			if observed.first_hit < 0:observed.first_hit = g.enemy_shield_time
			observed.hit_total += float(payload.amount) / scale
			observed.hit_count += 1
	)
	var elapsed := 0.0
	for step in 3600:
		g.tick(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		if actors.all(func(actor):return float(actor.hp) <= 0.0):break
	var cleared := actors.all(func(actor):return float(actor.hp) <= 0.0)
	return {"weapon":weapon,"case":case_name,"scale":scale,"first_hit":observed.first_hit,"kill_time":elapsed if cleared else -1.0,"hit_total_normalized":observed.hit_total,"hit_count":observed.hit_count,"initial_pool_normalized":int(settings.count) * (float(settings.hp)+float(settings.shield)),"cleared":cleared}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for case_name in CASES:
		for weapon in WEAPONS:
			print(JSON.stringify(run_case(weapon,case_name,1.0)))
	# Check both expected specialist and nearest rival at each scale, with mechanics fixed.
	for scale in [100.0,1000.0,100000.0,1.0e40]:
		for pair in [["medium","laser"],["medium","missile"],["swarm","missile"],["swarm","laser"],["heavy","cannon"],["heavy","missile"],["reactive","cannon"],["reactive","missile"],["recovering","longLaser"],["recovering","laser"]]:
			print(JSON.stringify(run_case(str(pair[1]),str(pair[0]),scale)))
	quit()
